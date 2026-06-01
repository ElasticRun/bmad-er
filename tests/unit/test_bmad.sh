#!/bin/sh
# Story 1.4 — BMAD installation and global skill deployment (mocked)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/bmad-workspace"
TEST_TMP="$REPO_ROOT/tests/tmp/bmad-temp"
TEST_HOME="$REPO_ROOT/tests/tmp/bmad-home"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/manifest.sh"
. "$LIB_DIR/bmad.sh"
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

setup_fixture_bmad_output() {
    rm -rf "$TEST_TMP" "$TEST_WS" "$TEST_HOME"
    mkdir -p "$TEST_TMP/.cursor/skills/bmad-dev-story" \
        "$TEST_TMP/_bmad" \
        "$TEST_WS" \
        "$TEST_HOME/.cursor/skills" \
        "$TEST_HOME/.claude/skills" || return 1
    printf 'skill' > "$TEST_TMP/.cursor/skills/bmad-dev-story/SKILL.md" || return 1
    printf 'config' > "$TEST_TMP/_bmad/config.yaml" || return 1
    HOME="$TEST_HOME"
    export HOME
    manifest_init "$TEST_WS" || return 1
    manifest_read "$TEST_WS" || return 1
    MANIFEST_CURRENT_PATH="$TEST_WS/.lets-b-mad/install-manifest.json"
    export MANIFEST_CURRENT_PATH
}

test_install_missing_npx() {
    PATH="/usr/bin:/bin"
    export PATH
    bmad_install "$TEST_TMP" "6.8.0"
    rc=$?
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$PATH"
    export PATH
    assert_equals "$EXIT_BMAD_INSTALL_FAILED" "$rc" "missing npx"
}

test_deploy_skills() {
    setup_fixture_bmad_output || return 1
    bmad_deploy_skills "$TEST_TMP" 0 || return 1
    [ -f "$TEST_HOME/.cursor/skills/bmad-dev-story/SKILL.md" ] || return 1
    [ -f "$TEST_HOME/.claude/skills/bmad-dev-story/SKILL.md" ] || return 1
}

test_deploy_workspace_preserve() {
    setup_fixture_bmad_output || return 1
    mkdir -p "$TEST_WS/_bmad"
    printf 'custom' > "$TEST_WS/_bmad/preserve-me.txt" || return 1
    bmad_deploy_workspace "$TEST_TMP" "$TEST_WS" 0 || return 1
    grep -q 'custom' "$TEST_WS/_bmad/preserve-me.txt" || return 1
}

test_generate_toml_paths() {
    setup_fixture_bmad_output || return 1
    bmad_deploy_skills "$TEST_TMP" 0 || return 1
    bmad_deploy_workspace "$TEST_TMP" "$TEST_WS" 1 || return 1
    bmad_generate_toml "$REPO_ROOT" "$TEST_WS" 1 || return 1
    toml="$TEST_WS/_bmad/custom/bmad-dev-story.toml"
    [ -f "$toml" ] || return 1
    assert_contains "$(cat "$toml")" "$REPO_ROOT/scripts/pre-workflow.sh" "prepend path" || return 1
    assert_contains "$(cat "$toml")" "$REPO_ROOT/scripts/post-workflow.sh" "on_complete path" || return 1
}

test_skills_changed_warning() {
    setup_fixture_bmad_output || return 1
    bmad_deploy_skills "$TEST_TMP" 0 || return 1
    manifest_add_managed ".cursor/skills/bmad-dev-story/SKILL.md" "deadbeef" 2>/dev/null || true
    out=$(bmad_deploy_skills "$TEST_TMP" 0 2>&1) || return 1
    assert_contains "$out" "Restart Cursor" "ide restart warning" || return 1
}

run_test "missing_npx" test_install_missing_npx
run_test "deploy_skills" test_deploy_skills
run_test "preserve_workspace" test_deploy_workspace_preserve
run_test "generate_toml" test_generate_toml_paths
run_test "skills_warning" test_skills_changed_warning

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All bmad.sh tests passed\n'
exit 0
