#!/bin/sh
# Unit tests for scripts/lib/workspace.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"
TEST_WS="$REPO_ROOT/tests/tmp/workspace-discovery"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/manifest.sh"
. "$LIB_DIR/workspace.sh"
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

_init_git_repo() {
    dir="$1"
    mkdir -p "$dir" || return 1
    git -C "$dir" init -q 2>/dev/null || return 1
}

setup_fixture_tree() {
    rm -rf "$TEST_WS"
    mkdir -p "$TEST_WS/projects/api" \
        "$TEST_WS/projects/web" \
        "$TEST_WS/deep/level1/level2/repo" \
        "$TEST_WS/node_modules/fake" \
        "$TEST_WS/excluded/.venv/nested" || return 1

    _init_git_repo "$TEST_WS" || return 1
    _init_git_repo "$TEST_WS/projects/api" || return 1
    _init_git_repo "$TEST_WS/projects/web" || return 1
    _init_git_repo "$TEST_WS/deep/level1/level2/repo" || return 1
    _init_git_repo "$TEST_WS/node_modules/fake" || return 1
}

test_discovery_counts_and_depth() {
    setup_fixture_tree || return 1
    workspace_discover "$TEST_WS" || return 1
    count=$(workspace_discovered_count "$TEST_WS") || return 1
    assert_equals "2" "$count" "repo count" || return 1

    discover_file=$(workspace_discover_file_for "$TEST_WS")
    assert_contains "$(cat "$discover_file")" "projects/api" "contains api" || return 1
    assert_contains "$(cat "$discover_file")" "projects/web" "contains web" || return 1

    if grep -Fx '.' "$discover_file" >/dev/null 2>&1; then
        return 1
    fi

    case "$(cat "$discover_file")" in
        *deep/level1/level2/repo*) return 1 ;;
    esac
    case "$(cat "$discover_file")" in
        *node_modules*) return 1 ;;
    esac
    return 0
}

test_yaml_schema_and_paths() {
    setup_fixture_tree || return 1
    workspace_discover "$TEST_WS" || return 1
    workspace_generate_yaml "$TEST_WS" || return 1

    yaml_path=$(workspace_path_for "$TEST_WS")
    [ -f "$yaml_path" ] || return 1

    if ! command -v yq >/dev/null 2>&1; then
        log_warn "yq missing — skipping YAML schema assertions"
        return 0
    fi

    ws_name=$(yq eval '.workspace.name' "$yaml_path")
    ws_root=$(yq eval '.workspace.root' "$yaml_path")
    repo_count=$(yq eval '.repos | length' "$yaml_path")

    assert_equals "$(basename "$TEST_WS")" "$ws_name" "workspace.name" || return 1
    assert_equals "$(cd "$TEST_WS" && pwd)" "$ws_root" "workspace.root" || return 1
    assert_equals "2" "$repo_count" "repos length" || return 1

    graphify_default=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$yaml_path")
    assert_equals "false" "$graphify_default" "graphify_initialized default" || return 1

    api_path=$(yq eval '.repos[] | select(.name == "api") | .path' "$yaml_path")
    assert_equals "projects/api" "$api_path" "relative path" || return 1
    return 0
}

test_merge_preserves_annotations() {
    setup_fixture_tree || return 1
    workspace_discover "$TEST_WS" || return 1
    workspace_generate_yaml "$TEST_WS" || return 1

    yaml_path=$(workspace_path_for "$TEST_WS")
    yq eval -i '.repos[] |= select(.path == "projects/api") |= . + {"team": "platform"}' "$yaml_path" || return 1
    yq eval -i '.repos[] |= select(.path == "projects/api") |= .graphify_initialized = true' "$yaml_path" || return 1

    mkdir -p "$TEST_WS/projects/newsvc" || return 1
    git -C "$TEST_WS/projects/newsvc" init -q || return 1

    workspace_rediscover "$TEST_WS" || return 1

    team_val=$(yq eval '.repos[] | select(.path == "projects/api") | .team' "$yaml_path")
    assert_equals "platform" "$team_val" "custom annotation preserved" || return 1

    graphify_val=$(yq eval '.repos[] | select(.path == "projects/api") | .graphify_initialized' "$yaml_path")
    assert_equals "true" "$graphify_val" "graphify_initialized preserved" || return 1

    newsvc=$(yq eval '.repos[] | select(.path == "projects/newsvc") | .path' "$yaml_path")
    assert_equals "projects/newsvc" "$newsvc" "new repo appended" || return 1

    repo_count=$(yq eval '.repos | length' "$yaml_path")
    assert_equals "3" "$repo_count" "repo count after merge" || return 1
    return 0
}

test_merge_preserves_missing_path() {
    setup_fixture_tree || return 1
    workspace_discover "$TEST_WS" || return 1
    workspace_generate_yaml "$TEST_WS" || return 1

    yaml_path=$(workspace_path_for "$TEST_WS")
    yq eval -i '.repos += [{"path": "removed/repo", "name": "removed", "graphify_initialized": false}]' "$yaml_path" || return 1

    stderr_out=$(workspace_rediscover "$TEST_WS" 2>&1 >/dev/null) || return 1
    assert_contains "$stderr_out" "repo path no longer exists: removed/repo" "missing path warning" || return 1

    removed=$(yq eval '.repos[] | select(.path == "removed/repo") | .path' "$yaml_path")
    assert_equals "removed/repo" "$removed" "missing repo entry preserved" || return 1
    return 0
}

test_excluded_dir_helper() {
    workspace_is_excluded_dir "node_modules"
    assert_zero $? "node_modules excluded" || return 1
    workspace_is_excluded_dir "src"
    rc=$?
    assert_equals 1 "$rc" "src not excluded"
}

test_nested_repo_path_helper() {
    workspace_is_nested_repo_path "projects/api"
    assert_zero $? "nested path accepted" || return 1
    workspace_is_nested_repo_path "."
    rc=$?
    assert_equals 1 "$rc" "workspace root path rejected"
}

test_layout_helpers() {
    layout_ws="$REPO_ROOT/tests/tmp/layout-workspace"
    rm -rf "$layout_ws"
    mkdir -p "$layout_ws"

    cat > "$layout_ws/workspace.yaml" <<EOF
workspace:
  name: layout-test
  root: $layout_ws
  layout: multi-repo
repos:
  - path: projects/api
    name: api
    graphify_initialized: false
EOF

    layout=$(workspace_get_layout "$layout_ws")
    assert_equals "multi-repo" "$layout" "explicit multi-repo layout" || return 1

    if workspace_is_graphify_target "$layout_ws" "."; then
        return 1
    fi

    workspace_is_graphify_target "$layout_ws" "projects/api"
    assert_zero $? "nested repo is graphify target" || return 1

    cat > "$layout_ws/workspace.yaml" <<EOF
workspace:
  name: layout-test
  root: $layout_ws
repos:
  - path: .
    name: layout-test
    graphify_initialized: false
EOF

    layout=$(workspace_get_layout "$layout_ws")
    assert_equals "standalone" "$layout" "inferred standalone layout" || return 1

    workspace_is_graphify_target "$layout_ws" "."
    assert_zero $? "standalone root is graphify target" || return 1
    return 0
}

run_test "excluded_dir" test_excluded_dir_helper
run_test "nested_repo_path" test_nested_repo_path_helper
run_test "layout_helpers" test_layout_helpers
run_test "discovery" test_discovery_counts_and_depth
run_test "yaml_schema" test_yaml_schema_and_paths
run_test "merge_annotations" test_merge_preserves_annotations
run_test "merge_missing_path" test_merge_preserves_missing_path

if [ "$failures" -ne 0 ]; then
    exit 1
fi
printf 'All workspace.sh tests passed\n'
exit 0
