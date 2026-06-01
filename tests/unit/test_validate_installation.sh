#!/bin/sh
# Unit tests for scripts/validate-installation.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATE="$REPO_ROOT/scripts/validate-installation.sh"
TEST_ROOT="$REPO_ROOT/tests/tmp/validate-test"
TEST_HOME="$TEST_ROOT/home"
TEST_WS="$TEST_ROOT/workspace"
TEST_REPO="$TEST_WS/projects/api"

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

setup_pass_fixture() {
    rm -rf "$TEST_ROOT"
    mkdir -p "$TEST_HOME/.cursor/skills/bmad-test-skill"
    mkdir -p "$TEST_HOME/.claude/skills/bmad-test-skill"
    mkdir -p "$TEST_REPO/.git/hooks"
    mkdir -p "$TEST_WS/_bmad"
    mkdir -p "$TEST_WS/.lets-b-mad"

    BMAD_PIN=$(sed -n 's/^BMAD_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/scripts/install.sh" | head -n 1)
    GITAI_PIN=$(sed -n 's/^GITAI_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/scripts/install.sh" | head -n 1)
    GRAPHIFY_PIN=$(sed -n 's/^GRAPHIFY_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/scripts/install.sh" | head -n 1)

    cat > "$TEST_WS/.lets-b-mad/install-manifest.json" <<EOF
{
  "version": 1,
  "versions": {
    "bmad": "$BMAD_PIN",
    "gitai": "$GITAI_PIN",
    "graphify": "$GRAPHIFY_PIN"
  },
  "files": { "managed": [], "protected": [] },
  "workspace": {}
}
EOF

    TEST_WS_ABS=$(cd "$TEST_WS" && pwd)

    cat > "$TEST_WS/workspace.yaml" <<EOF
workspace:
  name: validate-test
  root: $TEST_WS_ABS
repos:
  - path: projects/api
    name: api
    graphify_initialized: true
EOF

    mkdir -p "$TEST_HOME/.lets-b-mad/central-context"
    if [ ! -d "$TEST_HOME/.lets-b-mad/central-context/.git" ]; then
        git init "$TEST_HOME/.lets-b-mad/central-context"
        (
            cd "$TEST_HOME/.lets-b-mad/central-context" || exit 1
            git config user.email "test@example.com"
            git config user.name "Test"
            printf 'x\n' >README.md
            git add README.md
            git commit -m "init"
        )
    fi

    TEST_BIN="$TEST_ROOT/bin"
    mkdir -p "$TEST_BIN"
    cat >"$TEST_BIN/git-ai" <<EOF
#!/bin/sh
printf '%s\n' '$GITAI_PIN'
EOF
    cat >"$TEST_BIN/graphify" <<EOF
#!/bin/sh
echo graphify $GRAPHIFY_PIN
EOF
    chmod +x "$TEST_BIN/git-ai" "$TEST_BIN/graphify"
}

test_fails_without_workspace() {
    empty_ws="$TEST_ROOT/empty-ws"
    rm -rf "$empty_ws"
    mkdir -p "$empty_ws"
    output=$(HOME="$TEST_HOME" LETS_B_MAD_WORKSPACE="$empty_ws" sh "$VALIDATE" 2>&1) || rc=$?
    rc=${rc:-0}
    assert_nonzero "$rc" "exit non-zero when unhealthy"
    assert_contains "$output" "FAIL" "reports failures"
}

test_passes_with_fixture() {
    setup_pass_fixture || return 1
    export HOOKS_GRAPHIFY_STATUS_CMD='return 0'
    export VALIDATE_SKIP_CONTEXT_CHECK=1
    TEST_HOME_ABS=$(cd "$TEST_HOME" && pwd)
    TEST_WS_ABS=$(cd "$TEST_WS" && pwd)
    rc=0
    output=$( \
        HOME="$TEST_HOME_ABS" \
        LETS_B_MAD_WORKSPACE="$TEST_WS_ABS" \
        PATH="$TEST_ROOT/bin:${PATH:-/usr/bin:/bin}" \
        sh "$VALIDATE" 2>&1 \
    ) || rc=$?
    unset HOOKS_GRAPHIFY_STATUS_CMD VALIDATE_SKIP_CONTEXT_CHECK
    assert_zero "$rc" "exit zero when healthy" || return 1
    assert_contains "$output" "PASS" "reports passes" || return 1
}

test_pin_reader_matches_install() {
    pin=$(sed -n 's/^BMAD_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/scripts/install.sh" | head -n 1)
    assert_contains "$pin" "6.8" "BMAD pin readable"
}

run_test "fails_unhealthy" test_fails_without_workspace
run_test "passes_fixture" test_passes_with_fixture
run_test "pin_reader" test_pin_reader_matches_install

if [ "$failures" -gt 0 ]; then
    printf '%d test(s) failed\n' "$failures" >&2
    exit 1
fi

printf 'All validate-installation tests passed\n'
exit 0
