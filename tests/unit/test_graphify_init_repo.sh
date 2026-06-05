#!/bin/sh
# Unit tests for manual per-repo graphify init (Story 4.3)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/graphify-init-repo-workspace"
TEST_REPO="$TEST_WS/projects/api"
CLI="$REPO_ROOT/scripts/graphify-init-repo.sh"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/workspace.sh"
. "$LIB_DIR/dependencies.sh"
. "$LIB_DIR/hooks.sh"
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

setup_multi_repo_fixture() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_REPO/.git" "$TEST_REPO/graphify-out"
    printf '{}' > "$TEST_REPO/graphify-out/graph.json"

    cat > "$TEST_WS/workspace.yaml" <<EOF
workspace:
  name: gir-test
  root: $TEST_WS
  layout: multi-repo
repos:
  - path: projects/api
    name: api
    graphify_initialized: false
EOF
}

setup_standalone_fixture() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_WS/.git" "$TEST_WS/graphify-out"
    printf '{}' > "$TEST_WS/graphify-out/graph.json"

    cat > "$TEST_WS/workspace.yaml" <<EOF
workspace:
  name: gir-standalone
  root: $TEST_WS
  layout: standalone
repos:
  - path: .
    name: gir-standalone
    graphify_initialized: false
EOF
}

_mock_graphify_path() {
    bin_dir="$REPO_ROOT/tests/tmp/graphify-init-repo-bin"
    rm -rf "$bin_dir"
    mkdir -p "$bin_dir"
    printf '#!/bin/sh\necho graphify 0.8.27\n' > "$bin_dir/graphify"
    chmod +x "$bin_dir/graphify"
    PATH="$bin_dir:$PATH"
    export PATH
}

test_manual_init_multi_repo() {
    setup_multi_repo_fixture || return 1
    _mock_graphify_path || return 1
    export DEPS_GRAPHIFY_INIT_CMD='return 0'
    export LETS_B_MAD_WORKSPACE="$TEST_WS"

    if ! graphify_init_target_repo "$TEST_WS" "projects/api"; then
        return 1
    fi

    flag=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$TEST_WS/workspace.yaml")
    assert_equals "true" "$flag" "graphify_initialized after manual init"
}

test_reinit_runs_again() {
    setup_multi_repo_fixture || return 1
    _mock_graphify_path || return 1
    export LETS_B_MAD_WORKSPACE="$TEST_WS"
    export DEPS_GRAPHIFY_INIT_CMD='return 0'

    yq eval -i '(.repos[] | select(.path == "projects/api") | .graphify_initialized) = true' \
        "$TEST_WS/workspace.yaml" || return 1

    if ! graphify_init_target_repo "$TEST_WS" "projects/api"; then
        return 1
    fi

    flag=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$TEST_WS/workspace.yaml")
    assert_equals "true" "$flag" "graphify_initialized remains true after re-init"
}

test_reject_workspace_root_multi_repo() {
    setup_multi_repo_fixture || return 1
    _mock_graphify_path || return 1
    export LETS_B_MAD_WORKSPACE="$TEST_WS"
    export DEPS_GRAPHIFY_INIT_CMD='return 0'

    if graphify_init_target_repo "$TEST_WS" "."; then
        return 1
    fi
    return 0
}

test_standalone_root_init() {
    setup_standalone_fixture || return 1
    _mock_graphify_path || return 1
    export LETS_B_MAD_WORKSPACE="$TEST_WS"
    export DEPS_GRAPHIFY_INIT_CMD='return 0'

    if ! graphify_init_target_repo "$TEST_WS" "."; then
        return 1
    fi

    flag=$(yq eval '.repos[] | select(.path == ".") | .graphify_initialized' "$TEST_WS/workspace.yaml")
    assert_equals "true" "$flag" "standalone root initialized"
}

test_cli_with_hooks() {
    setup_multi_repo_fixture || return 1
    _mock_graphify_path || return 1
    export LETS_B_MAD_WORKSPACE="$TEST_WS"
    export DEPS_GRAPHIFY_INIT_CMD='return 0'
    export HOOKS_GRAPHIFY_INSTALL_CMD='return 0'
    export HOOKS_GRAPHIFY_STATUS_CMD='return 0'

    if ! sh "$CLI" --hooks projects/api; then
        return 1
    fi

    flag=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$TEST_WS/workspace.yaml")
    assert_equals "true" "$flag" "CLI init with hooks updates yaml"
}

test_missing_path_fails() {
    setup_multi_repo_fixture || return 1
    _mock_graphify_path || return 1
    export LETS_B_MAD_WORKSPACE="$TEST_WS"
    export DEPS_GRAPHIFY_INIT_CMD='return 0'

    if graphify_init_target_repo "$TEST_WS" "missing/repo"; then
        return 1
    fi
    return 0
}

run_test "manual_init_multi_repo" test_manual_init_multi_repo
run_test "reinit_runs_again" test_reinit_runs_again
run_test "reject_root_multi_repo" test_reject_workspace_root_multi_repo
run_test "standalone_root_init" test_standalone_root_init
run_test "cli_with_hooks" test_cli_with_hooks
run_test "missing_path_fails" test_missing_path_fails

if [ "$failures" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All graphify init repo tests passed\n'
exit 0
