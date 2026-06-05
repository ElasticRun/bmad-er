#!/bin/sh
# Unit tests for scripts/lib/dependencies.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/deps-workspace"
TEST_BIN_DIR="$REPO_ROOT/tests/tmp/deps-bin"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/manifest.sh"
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

setup_ws() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_WS"
    manifest_init "$TEST_WS" || return 1
    manifest_read "$TEST_WS" || return 1
}

setup_mock_gitai() {
    version="$1"
    rm -rf "$TEST_BIN_DIR"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho %s\n' "$version" > "$TEST_BIN_DIR/git-ai"
    chmod +x "$TEST_BIN_DIR/git-ai"
    PATH="$TEST_BIN_DIR:$PATH"
    export PATH
}

test_version_match_skip() {
    setup_ws || return 1
    setup_mock_gitai "1.5.2" || return 1
    unset DEPS_GITAI_INSTALL_CMD

    if ! deps_install_gitai "1.5.2"; then
        return 1
    fi

    recorded=$(jq -r '.versions.gitai' < "$MANIFEST_CURRENT_PATH")
    assert_equals "1.5.2" "$recorded" "manifest version"
}

test_version_mismatch_installs() {
    setup_ws || return 1
    setup_mock_gitai "1.5.1" || return 1
    export DEPS_GITAI_INSTALL_CMD='printf "#!/bin/sh\necho 1.5.2\n" > '"$TEST_BIN_DIR"'/git-ai && chmod +x '"$TEST_BIN_DIR"'/git-ai'

    if ! deps_install_gitai "1.5.2"; then
        return 1
    fi

    installed=$(deps_gitai_installed_version) || return 1
    assert_equals "1.5.2" "$installed" "upgraded version"
}

test_install_failure_exit_code() {
    setup_ws || return 1
    setup_mock_gitai "1.5.1" || return 1
    export DEPS_GITAI_INSTALL_CMD='return 1'

    deps_install_gitai "1.5.2"
    rc=$?
    unset DEPS_GITAI_INSTALL_CMD
    assert_equals "$EXIT_DEP_GITAI_FAILED" "$rc" "exit code 30"
}

test_version_matches_helper() {
    _deps_version_matches "1.5.2" "v1.5.2"
    rc=$?
    assert_equals 0 "$rc" "v prefix match" || return 1
    _deps_version_matches "1.5.2" "1.5.1"
    rc=$?
    assert_equals 1 "$rc" "mismatch"
}

setup_mock_graphify() {
    version="$1"
    rm -rf "$TEST_BIN_DIR"
    mkdir -p "$TEST_BIN_DIR"
    printf '#!/bin/sh\necho graphify %s\n' "$version" > "$TEST_BIN_DIR/graphify"
    chmod +x "$TEST_BIN_DIR/graphify"
    PATH="$TEST_BIN_DIR:${PATH:-/usr/bin:/bin}"
    export PATH
}

test_graphify_skip_when_pinned() {
    setup_ws || return 1
    setup_mock_graphify "0.8.27" || return 1
    unset DEPS_GRAPHIFY_INSTALL_CMD

    if ! deps_install_graphify "0.8.27"; then
        return 1
    fi

    recorded=$(jq -r '.versions.graphify' < "$MANIFEST_CURRENT_PATH")
    assert_equals "0.8.27" "$recorded" "manifest graphify version"
}

test_graphify_install_failure_exit_code() {
    setup_ws || return 1
    setup_mock_graphify "0.8.26" || return 1
    export DEPS_GRAPHIFY_INSTALL_CMD='return 1'

    deps_install_graphify "0.8.27"
    rc=$?
    unset DEPS_GRAPHIFY_INSTALL_CMD
    assert_equals "$EXIT_DEP_GRAPHIFY_FAILED" "$rc" "exit code 31"
}

run_test "version_matches" test_version_matches_helper
run_test "skip_when_pinned" test_version_match_skip
run_test "upgrade_on_mismatch" test_version_mismatch_installs
run_test "install_failure" test_install_failure_exit_code
run_test "graphify_skip_when_pinned" test_graphify_skip_when_pinned
run_test "graphify_install_failure" test_graphify_install_failure_exit_code

if [ "$failures" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All dependencies.sh tests passed\n'
exit 0
