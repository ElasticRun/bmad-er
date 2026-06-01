#!/bin/sh
# Stories 6.1, 6.2 — README and contributor guide

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

test_readme_sections() {
    readme="$REPO_ROOT/README.md"
    [ -f "$readme" ] || return 1
    assert_contains "$(cat "$readme")" "## Preflight" "preflight" || return 1
    assert_contains "$(cat "$readme")" "scripts/install.sh" "install command" || return 1
    assert_contains "$(cat "$readme")" "## Do not" "do-not list" || return 1
    assert_contains "$(cat "$readme")" "Success criterion" "success criteria" || return 1
    return 0
}

test_guide_sections() {
    guide="$REPO_ROOT/docs/guide.md"
    [ -f "$guide" ] || return 1
    assert_contains "$(cat "$guide")" "Contributing" "contributing" || return 1
    assert_contains "$(cat "$guide")" "Upgrading BMAD" "upgrade" || return 1
    assert_contains "$(cat "$guide")" "BMAD_VERSION" "version pin doc" || return 1
    return 0
}

test_markdownlint() {
    if ! command -v markdownlint-cli2 >/dev/null 2>&1; then
        printf 'SKIP markdownlint (cli not installed)\n'
        return 0
    fi
    markdownlint-cli2 "$REPO_ROOT/README.md" "$REPO_ROOT/docs/guide.md" >/dev/null 2>&1
}

run_test "readme_sections" test_readme_sections
run_test "guide_sections" test_guide_sections
run_test "markdownlint" test_markdownlint

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All documentation tests passed\n'
exit 0
