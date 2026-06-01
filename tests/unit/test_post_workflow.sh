#!/bin/sh
# Unit tests for scripts/post-workflow.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POST_WORKFLOW="$REPO_ROOT/scripts/post-workflow.sh"
TEST_ENDPOINT_DIR=$(mktemp -d) || exit 1
TEST_ENDPOINT_FILE="$TEST_ENDPOINT_DIR/gamification-endpoint"

cleanup() {
    rm -rf "$TEST_ENDPOINT_DIR"
}
trap cleanup EXIT

. "$SCRIPT_DIR/lib/test_helpers.sh"

export POST_WORKFLOW_GAMIFICATION_ENDPOINT="$TEST_ENDPOINT_FILE"
export POST_WORKFLOW_SKIP_CURL=1

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
    unset POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD
    printf '' >"$TEST_ENDPOINT_FILE"

    sh "$POST_WORKFLOW" "bmad-dev-story"
    rc=$?
    assert_zero "$rc" "success exit"
}

test_reads_arg_workflow_name() {
    unset POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD
    printf '' >"$TEST_ENDPOINT_FILE"
    output=$(sh "$POST_WORKFLOW" "bmad-create-story" 2>&1) || return 1
    assert_contains "$output" "bmad-create-story" "workflow arg in log"
}

test_reads_env_workflow_name() {
    unset POST_WORKFLOW_TEST_FAIL
    unset POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD
    printf '' >"$TEST_ENDPOINT_FILE"
    export BMAD_WORKFLOW_NAME="bmad-code-review"
    output=$(sh "$POST_WORKFLOW" 2>&1) || return 1
    assert_contains "$output" "bmad-code-review" "workflow env in log"
}

test_failure_still_exits_zero() {
    export POST_WORKFLOW_TEST_FAIL=1
    printf '' >"$TEST_ENDPOINT_FILE"
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

test_skip_when_endpoint_empty() {
    unset POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD
    printf '' >"$TEST_ENDPOINT_FILE"
    output=$(sh "$POST_WORKFLOW" "bmad-dev-story" 2>&1) || return 1
    assert_contains "$output" "gamification endpoint not configured" "empty endpoint warn"
}

test_skip_when_no_credential() {
    printf 'https://gitlab.example.com/api/v4/events' >"$TEST_ENDPOINT_FILE"
    export POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD=':'
    output=$(sh "$POST_WORKFLOW" "bmad-dev-story" 2>&1) || return 1
    unset POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD
    assert_contains "$output" "credential fill returned no token" "missing token warn"
}

test_push_with_mock_credential() {
    printf 'https://gitlab.example.com/api/v4/events' >"$TEST_ENDPOINT_FILE"
    export POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD='printf "protocol=https\nhost=gitlab.example.com\nusername=oauth2\npassword=secret-token-xyz\n"'
    output=$(sh "$POST_WORKFLOW" "bmad-dev-story" 2>&1) || return 1
    assert_contains "$output" "gamification push skipped (test mode)" "curl skipped in test"
    case "$output" in
        *secret-token-xyz*) printf 'FAIL credential leaked to logs\n' >&2; return 1 ;;
    esac
    return 0
}

test_curl_failure_is_fail_open() {
    printf 'https://gitlab.example.com/api/v4/events' >"$TEST_ENDPOINT_FILE"
    export POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD='printf "protocol=https\nhost=gitlab.example.com\npassword=tok\n"'
    export POST_WORKFLOW_SKIP_CURL=0
    # curl to invalid host — should warn and still exit 0
    output=$(sh "$POST_WORKFLOW" "bmad-dev-story" 2>&1) || return 1
    assert_contains "$output" "gamification event push failed" "fail-open warn"
    sh "$POST_WORKFLOW" "bmad-dev-story" >/dev/null 2>&1
    assert_zero "$?" "still exits zero from script"
    export POST_WORKFLOW_SKIP_CURL=1
}

run_test "success" test_success_exits_zero
run_test "arg_name" test_reads_arg_workflow_name
run_test "env_name" test_reads_env_workflow_name
run_test "non_blocking" test_failure_still_exits_zero
run_test "no_lib" test_no_lib_sourcing
run_test "empty_endpoint" test_skip_when_endpoint_empty
run_test "no_credential" test_skip_when_no_credential
run_test "mock_credential" test_push_with_mock_credential
run_test "curl_fail_open" test_curl_failure_is_fail_open

if [ "$failures" -gt 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'All post-workflow tests passed\n'
exit 0
