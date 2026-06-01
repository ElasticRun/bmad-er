#!/bin/sh
# Unit tests for scripts/pre-workflow.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRE_WORKFLOW="$REPO_ROOT/scripts/pre-workflow.sh"
TEST_ROOT="$REPO_ROOT/tests/tmp/pre-workflow-test"
TEST_HOME="$TEST_ROOT/home"

. "$SCRIPT_DIR/lib/test_helpers.sh"

failures=0
attempt=0

run_test() {
    name="$1"
    if "$2"; then
        printf 'PASS %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name" >&2
        failures=$((failures + 1))
    fi
}

setup_context_dir() {
    rm -rf "$TEST_ROOT"
    mkdir -p "$TEST_HOME/.lets-b-mad/central-context/.git"
    HOME="$TEST_HOME"
    export HOME
    unset PRE_WORKFLOW_TEST_PULL_CMD
    attempt=0
}

run_pre_workflow() {
    sh "$PRE_WORKFLOW"
}

test_success_exits_zero() {
    setup_context_dir || return 1
    export PRE_WORKFLOW_TEST_PULL_CMD='return 0'

    run_pre_workflow
    rc=$?
    assert_zero "$rc" "success exit"
}

test_retry_then_success() {
    setup_context_dir || return 1
    COUNTER_FILE="$TEST_ROOT/pull-count"
    printf '0' > "$COUNTER_FILE"
    export PRE_WORKFLOW_TEST_PULL_CMD='c=$(cat '"$COUNTER_FILE"'); n=$((c + 1)); echo "$n" > '"$COUNTER_FILE"'; [ "$c" -ge 1 ]'

    run_pre_workflow
    rc=$?
    assert_zero "$rc" "retry success exit"
}

test_double_failure_exits_41() {
    setup_context_dir || return 1
    export PRE_WORKFLOW_TEST_PULL_CMD='return 1'

    run_pre_workflow
    rc=$?
    assert_equals "41" "$rc" "hard block exit 41"
}

test_missing_dir_exits_41() {
    setup_context_dir || return 1
    rm -rf "$TEST_HOME/.lets-b-mad/central-context"

    run_pre_workflow
    rc=$?
    assert_equals "41" "$rc" "missing dir exit 41"
}

test_no_lib_sourcing() {
    if grep -q 'scripts/lib/' "$PRE_WORKFLOW" || grep -q '\. .*lib/' "$PRE_WORKFLOW"; then
        printf 'FAIL pre-workflow sources lib modules\n' >&2
        return 1
    fi
    return 0
}

run_test "success" test_success_exits_zero
run_test "retry_success" test_retry_then_success
run_test "hard_block" test_double_failure_exits_41
run_test "missing_dir" test_missing_dir_exits_41
run_test "no_lib_sourcing" test_no_lib_sourcing

if [ "$failures" -gt 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'All pre-workflow tests passed\n'
exit 0
