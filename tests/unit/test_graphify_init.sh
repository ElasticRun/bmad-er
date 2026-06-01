#!/bin/sh
# Unit tests for graphify per-repo initialization

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/graphify-init-workspace"
TEST_REPO="$TEST_WS/projects/api"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/workspace.sh"
. "$LIB_DIR/dependencies.sh"
. "$SCRIPT_DIR/lib/test_helpers.sh"

failures=0

run_test() {
    name="$1"
    if "$2"; then
        printf 'PASS %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name" >&2
        failures=$((failures + 1))
    fi
}

setup_fixture() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_REPO/.git" "$TEST_REPO/graphify-out"
    printf 'graphify-out placeholder' > "$TEST_REPO/graphify-out/graph.json"

    cat > "$TEST_WS/workspace.yaml" <<EOF
workspace:
  name: graphify-init-test
  root: $TEST_WS
repos:
  - path: projects/api
    name: api
    graphify_initialized: false
EOF
}

test_graphify_init_sets_yaml_flag() {
    setup_fixture || return 1
    export DEPS_GRAPHIFY_INIT_CMD='return 0'

    if ! deps_graphify_init "$TEST_REPO"; then
        return 1
    fi

    if ! workspace_set_graphify_initialized "$TEST_WS" "projects/api"; then
        return 1
    fi

    flag=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$TEST_WS/workspace.yaml")
    assert_equals "true" "$flag" "graphify_initialized true"
}

test_graphify_init_all_skips_initialized() {
    setup_fixture || return 1
    yq eval -i '(.repos[] | select(.path == "projects/api") | .graphify_initialized) = true' \
        "$TEST_WS/workspace.yaml" || return 1

    export DEPS_GRAPHIFY_INIT_CMD='return 1'
    TEST_BIN_DIR="$REPO_ROOT/tests/tmp/graphify-bin"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho graphify 0.8.27\n' > "$TEST_BIN_DIR/graphify"
    chmod +x "$TEST_BIN_DIR/graphify"
    PATH="$TEST_BIN_DIR:$PATH"
    export PATH

    if ! deps_graphify_init_all "$TEST_WS"; then
        return 1
    fi
}

test_graphify_init_all_initializes_repo() {
    setup_fixture || return 1
    export DEPS_GRAPHIFY_INIT_CMD='return 0'
    TEST_BIN_DIR="$REPO_ROOT/tests/tmp/graphify-bin2"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho graphify 0.8.27\n' > "$TEST_BIN_DIR/graphify"
    chmod +x "$TEST_BIN_DIR/graphify"
    PATH="$TEST_BIN_DIR:$PATH"
    export PATH

    if ! deps_graphify_init_all "$TEST_WS"; then
        return 1
    fi

    flag=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$TEST_WS/workspace.yaml")
    assert_equals "true" "$flag" "graphify_initialized after init_all"
}

run_test "init_sets_yaml" test_graphify_init_sets_yaml_flag
run_test "init_all_skips_done" test_graphify_init_all_skips_initialized
run_test "init_all_updates_yaml" test_graphify_init_all_initializes_repo

if [ "$failures" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All graphify init tests passed\n'
exit 0
