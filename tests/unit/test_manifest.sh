#!/bin/sh
# Unit tests for scripts/lib/manifest.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/manifest-workspace"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/manifest.sh"
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

setup_ws() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_WS"
}

test_manifest_init_and_read() {
    setup_ws
    manifest_init "$TEST_WS" || return 1
    manifest_read "$TEST_WS" || return 1
    mp=$(manifest_path_for "$TEST_WS")
    [ -f "$mp" ] || return 1
    jq -e '.version == 1' < "$mp" >/dev/null || return 1
}

test_managed_roundtrip() {
    setup_ws
    manifest_init "$TEST_WS" || return 1
    manifest_read "$TEST_WS" || return 1
    manifest_add_managed "/tmp/foo" "abc123" || return 1
    manifest_read "$TEST_WS" || return 1
    cs=$(manifest_is_managed "/tmp/foo") || return 1
    assert_equals "abc123" "$cs" "managed checksum"
}

test_protected_modified() {
    setup_ws
    manifest_init "$TEST_WS" || return 1
    manifest_read "$TEST_WS" || return 1
    manifest_add_protected "_bmad/custom/x.toml" "tplcs" "tplcs" || return 1
    manifest_read "$TEST_WS" || return 1
    manifest_file_modified "_bmad/custom/x.toml" "tplcs"
    rc=$?
    assert_equals 1 "$rc" "unmodified returns 1" || return 1
    manifest_file_modified "_bmad/custom/x.toml" "devchanged"
    rc=$?
    assert_equals 0 "$rc" "modified returns 0"
}

run_test "manifest_init" test_manifest_init_and_read
run_test "managed" test_managed_roundtrip
run_test "protected_modified" test_protected_modified

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All manifest.sh tests passed\n'
exit 0
