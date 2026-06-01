#!/bin/sh
# Story 1.3 — prerequisite detection and installation

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_BIN="$REPO_ROOT/tests/tmp/prereq-bin"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/prerequisites.sh"
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

test_version_ge() {
    _version_ge "3.12" "3.10" || return 1
    _version_ge "3.9" "3.10" && return 1
    _version_ge "1.8.1" "1.8.1" || return 1
    return 0
}

test_check_all_when_present() {
    if ! command -v node >/dev/null 2>&1 || \
       ! command -v python3 >/dev/null 2>&1 || \
       ! command -v jq >/dev/null 2>&1 || \
       ! command -v yq >/dev/null 2>&1; then
        log_warn "Skipping check_all_present — host missing baseline tools"
        return 0
    fi
    _prereq_check_jq || {
        log_warn "Skipping check_all_present — jq version not pinned on host"
        return 0
    }
    _prereq_check_yq || {
        log_warn "Skipping check_all_present — yq version not pinned on host"
        return 0
    }
    prereqs_check_all
}

test_jq_version_mismatch() {
    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi
    jq_ver=$(jq --version 2>/dev/null | sed 's/jq-//')
    case "$jq_ver" in
        "$REQUIRED_JQ_VERSION") return 0 ;;
    esac
    _prereq_check_jq && return 1
    return 0
}

test_brew_missing_exit_code() {
    rm -rf "$TEST_BIN"
    mkdir -p "$TEST_BIN"
    PATH="$TEST_BIN"
    export PATH
    _prereq_brew_install "jq" "brew install jq"
    rc=$?
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"
    export PATH
    assert_equals "$EXIT_PREREQ_INSTALL_FAILED" "$rc" "brew missing exit"
}

run_test "version_ge" test_version_ge
run_test "check_all_present" test_check_all_when_present
run_test "jq_version_mismatch" test_jq_version_mismatch
run_test "brew_missing" test_brew_missing_exit_code

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All prerequisites tests passed\n'
exit 0
