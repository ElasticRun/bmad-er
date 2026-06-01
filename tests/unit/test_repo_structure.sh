#!/bin/sh
# Story 1.1 — repository structure and foundation layout

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

test_required_directories() {
    for dir in scripts scripts/lib templates/customize docs; do
        [ -d "$REPO_ROOT/$dir" ] || return 1
    done
    return 0
}

test_shellcheck_config() {
    [ -f "$REPO_ROOT/.shellcheckrc" ] || return 1
    grep -q 'shell=sh' "$REPO_ROOT/.shellcheckrc" || return 1
    return 0
}

test_markdownlint_config() {
    [ -f "$REPO_ROOT/.markdownlint-cli2.yaml" ] || return 1
}

test_gitignore_patterns() {
    grep -q '.lets-b-mad/' "$REPO_ROOT/.gitignore" || return 1
    return 0
}

test_install_shebang() {
    head -n 1 "$REPO_ROOT/scripts/install.sh" | grep -q '#!/bin/sh' || return 1
    return 0
}

run_test "directories" test_required_directories
run_test "shellcheckrc" test_shellcheck_config
run_test "markdownlint" test_markdownlint_config
run_test "gitignore" test_gitignore_patterns
run_test "install_shebang" test_install_shebang

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All repo structure tests passed\n'
exit 0
