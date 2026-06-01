#!/bin/sh
# Unit tests for scripts/ai-stats-summary.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_WS="$REPO_ROOT/tests/tmp/ai-stats-workspace"
TEST_BIN_DIR="$REPO_ROOT/tests/tmp/ai-stats-bin"
AI_STATS_SCRIPT="$REPO_ROOT/scripts/ai-stats-summary.sh"

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

setup_workspace_fixture() {
    rm -rf "$TEST_WS" "$TEST_BIN_DIR"
    mkdir -p "$TEST_BIN_DIR" "$TEST_WS/projects/api/.git" "$TEST_WS/empty/.git"

    cat > "$TEST_WS/workspace.yaml" <<'EOF'
workspace:
  name: ai-stats-workspace
  root: /tmp/ws
repos:
  - path: projects/api
    name: api
    graphify_initialized: false
  - path: empty
    name: empty
    graphify_initialized: false
EOF

    printf '#!/bin/sh\ncase "$*" in\n  *stats*--json*)\n    if [ "$(basename "$(pwd)")" = "api" ]; then\n      echo '"'"'{"ai_additions":80,"human_additions":20,"unknown_additions":0,"ai_accepted":75}'"'"'\n    else\n      exit 1\n    fi\n    ;;\nesac\n' > "$TEST_BIN_DIR/git"
    chmod +x "$TEST_BIN_DIR/git"
}

test_summary_output() {
    setup_workspace_fixture || return 1
    PATH="$TEST_BIN_DIR:$PATH"
    export PATH
    output=$(LETS_B_MAD_WORKSPACE="$TEST_WS" sh "$AI_STATS_SCRIPT")
    assert_contains "$output" "api" "api repo" || return 1
    assert_contains "$output" "80" "ai lines" || return 1
    assert_contains "$output" "No git-ai data" "empty repo no data"
}

test_missing_yaml_exits_nonzero() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_WS"
    LETS_B_MAD_WORKSPACE="$TEST_WS" sh "$AI_STATS_SCRIPT" >/dev/null 2>&1
    rc=$?
    assert_equals 1 "$rc" "missing yaml exit 1"
}

run_test "summary_output" test_summary_output
run_test "missing_yaml" test_missing_yaml_exits_nonzero

if [ "$failures" -ne 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All ai-stats-summary tests passed\n'
exit 0
