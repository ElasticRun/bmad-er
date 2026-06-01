#!/bin/sh
# Unit tests for scripts/post-workflow.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POST_WORKFLOW="$REPO_ROOT/scripts/post-workflow.sh"

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

test_success_exits_zero() {
    unset POST_WORKFLOW_TEST_FAIL
    unset BMAD_WORKFLOW_NAME
    unset WORKFLOW_NAME

    sh "$POST_WORKFLOW" "bmad-dev-story"
    rc=$?
    assert_zero "$rc" "success exit"
}

test_reads_arg_workflow_name() {
    output=$(sh "$POST_WORKFLOW" "bmad-create-story" 2>&1) || return 1
    assert_contains "$output" "bmad-create-story" "workflow arg in log"
}

test_reads_env_workflow_name() {
    unset POST_WORKFLOW_TEST_FAIL
    export BMAD_WORKFLOW_NAME="bmad-code-review"
    output=$(sh "$POST_WORKFLOW" 2>&1) || return 1
    assert_contains "$output" "bmad-code-review" "workflow env in log"
}

test_failure_still_exits_zero() {
    export POST_WORKFLOW_TEST_FAIL=1
    sh "$POST_WORKFLOW" "bmad-dev-story"
    rc=$?
    unset POST_WORKFLOW_TEST_FAIL
    assert_zero "$rc" "non-blocking exit on extension failure"
}

test_no_lib_sourcing() {
    if grep -q 'scripts/lib/' "$POST_WORKFLOW" || grep -q '\. .*lib/' "$POST_WORKFLOW"; then
        printf 'FAIL post-workflow sources lib modules\n' >&2
        return 1
    fi
    return 0
}

test_has_gamification_extension_point() {
    assert_contains "$(cat "$POST_WORKFLOW")" "Phase 2: Gamification" "extension point comment"
}

run_test "success" test_success_exits_zero
run_test "arg_name" test_reads_arg_workflow_name
run_test "env_name" test_reads_env_workflow_name
run_test "non_blocking" test_failure_still_exits_zero
run_test "no_lib" test_no_lib_sourcing
run_test "extension_point" test_has_gamification_extension_point

if [ "$failures" -gt 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'All post-workflow tests passed\n'
exit 0
