#!/bin/sh
# Story 1.5 — install orchestrator structure and CLI

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_SH="$REPO_ROOT/scripts/install.sh"

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

test_help_exits_zero() {
    sh "$INSTALL_SH" --help >/dev/null 2>&1
    assert_zero $? "help exit"
}

test_version_pins_block() {
    grep -q 'BMAD_VERSION="6.8.0"' "$INSTALL_SH" || return 1
    grep -q 'GITAI_VERSION="1.5.2"' "$INSTALL_SH" || return 1
    grep -q 'GRAPHIFY_VERSION="0.8.27"' "$INSTALL_SH" || return 1
    return 0
}

test_sources_lib_modules() {
    for lib in common.sh manifest.sh prerequisites.sh bmad.sh workspace.sh dependencies.sh hooks.sh context.sh; do
        grep -q "$lib" "$INSTALL_SH" || return 1
    done
    return 0
}

test_continue_on_failure_pattern() {
    grep -q '|| true' "$INSTALL_SH" || return 1
    grep -q 'INSTALL_WORST_EXIT' "$INSTALL_SH" || return 1
    return 0
}

test_trap_cleanup() {
    grep -q 'trap install_cleanup EXIT' "$INSTALL_SH" || return 1
    grep -q 'mktemp -d' "$INSTALL_SH" || return 1
    return 0
}

test_summary_print() {
    grep -q 'summary_print' "$INSTALL_SH" || return 1
    return 0
}

test_workspace_prompt() {
    grep -q 'install_validate_workspace_path' "$INSTALL_SH" || return 1
    grep -q 'Workspace folder path' "$INSTALL_SH" || return 1
    return 0
}

test_workspace_cli_arg() {
    grep -q 'INSTALL_WORKSPACE_ARG' "$INSTALL_SH" || return 1
    grep -q -- '--workspace' "$INSTALL_SH" || return 1
    return 0
}

test_help_shows_workspace_option() {
    sh "$INSTALL_SH" --help 2>&1 | grep -q -- '--workspace'
}

run_test "help" test_help_exits_zero
run_test "version_pins" test_version_pins_block
run_test "lib_sources" test_sources_lib_modules
run_test "continue_on_failure" test_continue_on_failure_pattern
run_test "trap_cleanup" test_trap_cleanup
run_test "summary_table" test_summary_print
run_test "workspace_prompt" test_workspace_prompt
run_test "workspace_cli_arg" test_workspace_cli_arg
run_test "help_workspace_option" test_help_shows_workspace_option

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All install.sh tests passed\n'
exit 0
