#!/bin/sh
# Unit tests for scripts/lib/common.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"

. "$LIB_DIR/common.sh"
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

test_compute_checksum() {
    tmpfile="$REPO_ROOT/tests/tmp/checksum-test.txt"
    mkdir -p "$REPO_ROOT/tests/tmp"
    printf 'hello' > "$tmpfile"
    expected=$(shasum -a 256 "$tmpfile" | cut -d' ' -f1)
    actual=$(compute_checksum "$tmpfile")
    assert_equals "$expected" "$actual" "checksum" && rm -f "$tmpfile"
}

test_logging_stderr_only() {
    out=$(log_info "test-msg" 2>&1 1>/dev/null)
    case "$out" in
        *"[INFO] test-msg"*) return 0 ;;
    esac
    return 1
}

test_summary_table() {
    summary_reset
    summary_add_pass "Prerequisites" "all ok"
    summary_add_fail "BMAD" "npx failed"
    table=$(summary_print)
    assert_contains "$table" "Step Name" "header" || return 1
    assert_contains "$table" "Prerequisites" "step1" || return 1
    assert_contains "$table" "FAIL" "fail status" || return 1
}

test_exit_constants() {
    assert_equals "10" "$EXIT_PREREQ_MISSING" "prereq missing" || return 1
    assert_equals "20" "$EXIT_BMAD_INSTALL_FAILED" "bmad" || return 1
    assert_equals "30" "$EXIT_DEP_GITAI_FAILED" "dep" || return 1
    assert_equals "40" "$EXIT_CONTEXT_CLONE_FAILED" "context" || return 1
    assert_equals "50" "$EXIT_HOOK_INSTALL_FAILED" "hook" || return 1
}

run_test "compute_checksum" test_compute_checksum
run_test "logging_stderr" test_logging_stderr_only
run_test "summary_table" test_summary_table
run_test "exit_constants" test_exit_constants

if [ "$failures" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All common.sh tests passed\n'
exit 0
