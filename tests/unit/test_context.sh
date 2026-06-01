#!/bin/sh
# Unit tests for scripts/lib/context.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_ROOT="$REPO_ROOT/tests/tmp/context-test"
TEST_HOME="$TEST_ROOT/home"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/context.sh"
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

setup_home() {
    rm -rf "$TEST_ROOT"
    mkdir -p "$TEST_HOME"
    HOME="$TEST_HOME"
    export HOME
    unset CONTEXT_CLONE_CMD
    unset CONTEXT_PULL_CMD
}

test_fresh_clone() {
    setup_home || return 1
    dest=$(context_dir)

    export CONTEXT_CLONE_CMD='mkdir -p "'"$dest"'" && mkdir -p "'"$dest"'/.git"'

    if ! context_clone "git@example.com:org/central-context.git"; then
        return 1
    fi

    [ -d "$dest/.git" ] || return 1
}

test_existing_pull_idempotent() {
    setup_home || return 1
    dest=$(context_dir)
    mkdir -p "$dest/.git"

    export CONTEXT_PULL_CMD='return 0'

    if ! context_clone "git@example.com:org/central-context.git"; then
        return 1
    fi
}

test_non_git_directory_fails() {
    setup_home || return 1
    dest=$(context_dir)
    mkdir -p "$dest"
    printf 'not a repo\n' > "$dest/README.md"

    context_clone "git@example.com:org/central-context.git"
    rc=$?
    assert_equals "$EXIT_CONTEXT_CLONE_FAILED" "$rc" "non-git dir exit 40"
}

test_clone_failure_exit_code() {
    setup_home || return 1
    export CONTEXT_CLONE_CMD='return 1'

    context_clone "git@example.com:org/central-context.git"
    rc=$?
    assert_equals "$EXIT_CONTEXT_CLONE_FAILED" "$rc" "clone failure exit 40"
}

test_pull_failure_exit_code() {
    setup_home || return 1
    dest=$(context_dir)
    mkdir -p "$dest/.git"
    export CONTEXT_PULL_CMD='return 1'

    context_clone "git@example.com:org/central-context.git"
    rc=$?
    assert_equals "$EXIT_CONTEXT_CLONE_FAILED" "$rc" "pull failure exit 40"
}

run_test "fresh_clone" test_fresh_clone
run_test "existing_pull" test_existing_pull_idempotent
run_test "non_git_dir" test_non_git_directory_fails
run_test "clone_failure" test_clone_failure_exit_code
run_test "pull_failure" test_pull_failure_exit_code

if [ "$failures" -gt 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'All context tests passed\n'
exit 0
