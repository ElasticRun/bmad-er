#!/bin/sh
# Unit tests for scripts/lib/hooks.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/hooks-workspace"
TEST_REPO="$TEST_WS/projects/api"

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

setup_fixture() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_REPO/.git/hooks"
    printf '#!/bin/sh\necho custom\n' > "$TEST_REPO/.git/hooks/post-commit"
    chmod +x "$TEST_REPO/.git/hooks/post-commit"

    cat > "$TEST_WS/workspace.yaml" <<EOF
workspace:
  name: hooks-test
  root: $TEST_WS
repos:
  - path: projects/api
    name: api
    graphify_initialized: true
EOF
}

test_detect_conflicts_warns() {
    setup_fixture || return 1
    if ! hooks_detect_conflicts "$TEST_REPO"; then
        return 1
    fi
}

test_install_and_verify() {
    setup_fixture || return 1
    export HOOKS_GRAPHIFY_INSTALL_CMD='return 0'
    export HOOKS_GRAPHIFY_STATUS_CMD='return 0'
    TEST_BIN_DIR="$REPO_ROOT/tests/tmp/hooks-bin"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho graphify 0.8.27\n' > "$TEST_BIN_DIR/graphify"
    chmod +x "$TEST_BIN_DIR/graphify"
    PATH="$TEST_BIN_DIR:${PATH:-/usr/bin:/bin}"
    export PATH

    if ! hooks_install_repo "$TEST_REPO"; then
        return 1
    fi
    unset HOOKS_GRAPHIFY_INSTALL_CMD HOOKS_GRAPHIFY_STATUS_CMD
}

test_install_all_idempotent() {
    setup_fixture || return 1
    export HOOKS_GRAPHIFY_INSTALL_CMD='return 0'
    export HOOKS_GRAPHIFY_STATUS_CMD='return 0'
    TEST_BIN_DIR="$REPO_ROOT/tests/tmp/hooks-bin2"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho graphify 0.8.27\n' > "$TEST_BIN_DIR/graphify"
    chmod +x "$TEST_BIN_DIR/graphify"
    PATH="$TEST_BIN_DIR:${PATH:-/usr/bin:/bin}"
    export PATH

    if ! hooks_install_all "$TEST_WS"; then
        return 1
    fi
    if ! hooks_install_all "$TEST_WS"; then
        return 1
    fi
    unset HOOKS_GRAPHIFY_INSTALL_CMD HOOKS_GRAPHIFY_STATUS_CMD
}

test_install_all_skips_without_graphify() {
    setup_fixture || return 1
    saved_path="$PATH"
    PATH="/usr/bin:/bin"
    export PATH
    if ! hooks_install_all "$TEST_WS"; then
        PATH="$saved_path"
        export PATH
        return 1
    fi
    PATH="$saved_path"
    export PATH
}

test_install_all_skips_workspace_root_entry() {
    setup_fixture || return 1
    yq eval -i '.repos = [{"path": ".", "name": "root", "graphify_initialized": true}, {"path": "projects/api", "name": "api", "graphify_initialized": true}]' \
        "$TEST_WS/workspace.yaml" || return 1
    yq eval -i '.workspace.layout = "multi-repo"' "$TEST_WS/workspace.yaml" || return 1

    export HOOKS_GRAPHIFY_INSTALL_CMD='return 0'
    export HOOKS_GRAPHIFY_STATUS_CMD='return 0'
    TEST_BIN_DIR="$REPO_ROOT/tests/tmp/hooks-bin3"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho graphify 0.8.27\n' > "$TEST_BIN_DIR/graphify"
    chmod +x "$TEST_BIN_DIR/graphify"
    PATH="$TEST_BIN_DIR:${PATH:-/usr/bin:/bin}"
    export PATH

    stderr_out=$(hooks_install_all "$TEST_WS" 2>&1) || return 1
    assert_contains "$stderr_out" "skipping non-target" "skips path ." || return 1
    assert_contains "$stderr_out" "installing hooks for projects/api" "hooks nested repo" || return 1
    unset HOOKS_GRAPHIFY_INSTALL_CMD HOOKS_GRAPHIFY_STATUS_CMD
}

run_test "detect_conflicts" test_detect_conflicts_warns
run_test "install_verify" test_install_and_verify
run_test "install_all_idempotent" test_install_all_idempotent
run_test "skip_no_graphify" test_install_all_skips_without_graphify
run_test "skip_workspace_root" test_install_all_skips_workspace_root_entry

if [ "$failures" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All hooks.sh tests passed\n'
exit 0
