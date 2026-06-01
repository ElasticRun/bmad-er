#!/bin/sh
# validate-installation.sh — installation health checks (FR40)
# Invoke from workspace root: bash /path/to/lets-b-mad/scripts/validate-installation.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/manifest.sh"
. "$LIB_DIR/workspace.sh"
. "$LIB_DIR/dependencies.sh"
. "$LIB_DIR/hooks.sh"

VALIDATE_WORKSPACE_ROOT=""
VALIDATE_FAIL_COUNT=0
VALIDATE_PASS_COUNT=0

validate_read_pin() {
    key="$1"
    sed -n "s/^${key}=\"\\(.*\\)\"/\\1/p" "$REPO_ROOT/scripts/install.sh" | head -n 1
}

VALIDATE_BMAD_PIN=$(validate_read_pin BMAD_VERSION)
VALIDATE_GITAI_PIN=$(validate_read_pin GITAI_VERSION)
VALIDATE_GRAPHIFY_PIN=$(validate_read_pin GRAPHIFY_VERSION)
VALIDATE_GAMIFICATION_URL=$(validate_read_pin GAMIFICATION_EVENT_URL)

validate_resolve_workspace() {
    VALIDATE_WORKSPACE_ROOT="$(pwd)"
    if [ -n "${LETS_B_MAD_WORKSPACE:-}" ]; then
        VALIDATE_WORKSPACE_ROOT="$LETS_B_MAD_WORKSPACE"
    fi
}

validate_record_pass() {
    name="$1"
    details="$2"
    VALIDATE_PASS_COUNT=$((VALIDATE_PASS_COUNT + 1))
    printf '%-28s | PASS | %s\n' "$name" "$details"
}

validate_record_fail() {
    name="$1"
    expected="$2"
    actual="$3"
    fix="$4"
    VALIDATE_FAIL_COUNT=$((VALIDATE_FAIL_COUNT + 1))
    printf '%-28s | FAIL | %s\n' "$name" "$actual" >&2
    printf '  Expected: %s\n' "$expected" >&2
    printf '  Actual:   %s\n' "$actual" >&2
    printf '  Fix:      %s\n' "$fix" >&2
}

validate_check_skills_dir() {
    label="$1"
    skills_dir="$2"

    if [ ! -d "$skills_dir" ]; then
        validate_record_fail "$label" "directory exists with bmad-* skills" "missing: $skills_dir" \
            "Run: bash $REPO_ROOT/scripts/install.sh"
        return 1
    fi

    bmad_count=0
    for skill_path in "$skills_dir"/*; do
        [ -d "$skill_path" ] || continue
        skill_base=$(basename "$skill_path")
        case "$skill_base" in
            bmad-*) bmad_count=$((bmad_count + 1)) ;;
        esac
    done

    if [ "$bmad_count" -eq 0 ]; then
        validate_record_fail "$label" "at least one bmad-* skill" "0 skills in $skills_dir" \
            "Re-run install or use --force to redeploy global skills"
        return 1
    fi

    validate_record_pass "$label" "$bmad_count bmad-* skill(s)"
    return 0
}

validate_check_global_skills() {
    validate_check_skills_dir "Cursor global skills" "${HOME}/.cursor/skills"
    validate_check_skills_dir "Claude global skills" "${HOME}/.claude/skills"
}

validate_check_workspace_yaml() {
    yaml_path=$(workspace_path_for "$VALIDATE_WORKSPACE_ROOT")

    if [ ! -f "$yaml_path" ]; then
        validate_record_fail "Workspace YAML" "workspace.yaml at workspace root" "not found: $yaml_path" \
            "Run install from workspace root or set LETS_B_MAD_WORKSPACE"
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        validate_record_fail "Workspace YAML" "yq available to parse YAML" "yq not on PATH" \
            "Install yq (brew install yq) and re-run validation"
        return 1
    fi

    if ! yq eval '.' "$yaml_path" >/dev/null 2>&1; then
        validate_record_fail "Workspace YAML" "valid YAML document" "parse error" \
            "Fix syntax in workspace.yaml or re-run install"
        return 1
    fi

    repo_count=$(yq eval '.repos | length' "$yaml_path" 2>/dev/null) || repo_count=0
    case "$repo_count" in
        ''|*[!0-9]*) repo_count=0 ;;
    esac

    validate_record_pass "Workspace YAML" "$repo_count repo(s) listed"
    return 0
}

validate_check_manifest_versions() {
    manifest_path=$(manifest_path_for "$VALIDATE_WORKSPACE_ROOT")

    if [ ! -f "$manifest_path" ]; then
        validate_record_fail "Install manifest" "file exists" "missing: $manifest_path" \
            "Run: bash $REPO_ROOT/scripts/install.sh"
        return 1
    fi

    if ! manifest_read "$VALIDATE_WORKSPACE_ROOT"; then
        validate_record_fail "Install manifest" "valid JSON" "manifest_read failed" \
            "Delete corrupt manifest and re-run install"
        return 1
    fi

    for tool in bmad gitai graphify; do
        case "$tool" in
            bmad) expected="$VALIDATE_BMAD_PIN" ;;
            gitai) expected="$VALIDATE_GITAI_PIN" ;;
            graphify) expected="$VALIDATE_GRAPHIFY_PIN" ;;
        esac
        actual=$(jq -r ".versions.${tool} // empty" "$MANIFEST_CURRENT_PATH" 2>/dev/null)
        if [ -z "$actual" ]; then
            validate_record_fail "Manifest $tool version" "$expected" "not recorded" \
                "Re-run install to record versions"
            continue
        fi
        if ! _deps_version_matches "$expected" "$actual"; then
            validate_record_fail "Manifest $tool version" "$expected" "$actual" \
                "Re-run install to sync $tool to pinned version"
            continue
        fi
        validate_record_pass "Manifest $tool version" "$actual"
    done
}

validate_check_gitai() {
    if ! gitai_ver=$(deps_gitai_installed_version 2>/dev/null); then
        validate_record_fail "git-ai binary" "on PATH" "not found" \
            "Run install or install git-ai manually (pinned $VALIDATE_GITAI_PIN)"
        return 1
    fi
    if ! _deps_version_matches "$VALIDATE_GITAI_PIN" "$gitai_ver"; then
        validate_record_fail "git-ai version" "$VALIDATE_GITAI_PIN" "$gitai_ver" \
            "Re-run install to upgrade git-ai"
        return 1
    fi
    validate_record_pass "git-ai version" "$gitai_ver"
}

validate_check_graphify() {
    if ! graphify_ver=$(deps_graphify_installed_version 2>/dev/null); then
        validate_record_fail "graphify binary" "on PATH" "not found" \
            "Run install or: uv tool install graphifyy==$VALIDATE_GRAPHIFY_PIN"
        return 1
    fi
    if ! _deps_version_matches "$VALIDATE_GRAPHIFY_PIN" "$graphify_ver"; then
        validate_record_fail "graphify version" "$VALIDATE_GRAPHIFY_PIN" "$graphify_ver" \
            "Re-run install to upgrade graphify"
        return 1
    fi
    validate_record_pass "graphify version" "$graphify_ver"
}

validate_check_central_context() {
    if [ "${VALIDATE_SKIP_CONTEXT_CHECK:-0}" = "1" ]; then
        validate_record_pass "Central context" "skipped (test mode)"
        return 0
    fi

    ctx_dir="${HOME}/.lets-b-mad/central-context"

    if [ ! -d "$ctx_dir/.git" ]; then
        validate_record_fail "Central context" "git clone at $ctx_dir" "not present" \
            "Run install to clone central-context repository"
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        validate_record_fail "Central context freshness" "git available" "git not on PATH" \
            "Install git and re-run validation"
        return 1
    fi

    if ! git -C "$ctx_dir" fetch -q 2>/dev/null; then
        validate_record_fail "Central context freshness" "reachable remote" "git fetch failed" \
            "Check SSH/network access to central-context remote"
        return 1
    fi

    status_line=$(git -C "$ctx_dir" status -sb 2>/dev/null | head -n 1)
    case "$status_line" in
        *"[behind"*)
            validate_record_fail "Central context freshness" "up to date with upstream" "$status_line" \
                "Run: git -C $ctx_dir pull --ff-only (or re-run pre-workflow)"
            return 1
            ;;
    esac

    validate_record_pass "Central context" "clone present and current"
}

validate_check_graphify_hooks() {
    if ! deps_graphify_binary >/dev/null 2>&1; then
        validate_record_pass "graphify hooks" "skipped (graphify not on PATH)"
        return 0
    fi

    yaml_path=$(workspace_path_for "$VALIDATE_WORKSPACE_ROOT")
    if [ ! -f "$yaml_path" ]; then
        validate_record_fail "graphify hooks" "workspace.yaml present" "missing" \
            "Run install to generate workspace.yaml"
        return 1
    fi

    root_abs=$(cd "$VALIDATE_WORKSPACE_ROOT" && pwd) || return 1
    repo_count=$(yq eval '.repos | length' "$yaml_path" 2>/dev/null) || repo_count=0
    case "$repo_count" in
        ''|*[!0-9]*) repo_count=0 ;;
    esac

    if [ "$repo_count" -eq 0 ]; then
        validate_record_pass "graphify hooks" "no repos in workspace.yaml"
        return 0
    fi

    hook_fail=0
    idx=0
    while [ "$idx" -lt "$repo_count" ]; do
        rel_path=$(yq eval ".repos[$idx].path" "$yaml_path" 2>/dev/null)
        idx=$((idx + 1))
        [ -z "$rel_path" ] || [ "$rel_path" = "null" ] && continue

        disk_path=$(_workspace_repo_disk_path "$root_abs" "$rel_path") || {
            validate_record_fail "graphify hooks ($rel_path)" "resolvable repo path" "path error" \
                "Fix workspace.yaml entry for $rel_path"
            hook_fail=1
            continue
        }

        if hooks_verify_repo "$disk_path"; then
            validate_record_pass "graphify hooks ($rel_path)" "post-commit + post-checkout"
        else
            validate_record_fail "graphify hooks ($rel_path)" "graphify hooks installed" "verification failed" \
                "Run: graphify hook install (from repo) or re-run install"
            hook_fail=1
        fi
    done

    if [ "$hook_fail" -ne 0 ]; then
        return 1
    fi
    return 0
}

validate_check_gamification_config() {
    endpoint_file="${HOME}/.lets-b-mad/gamification-endpoint"

    if [ -z "$VALIDATE_GAMIFICATION_URL" ]; then
        validate_record_pass "Gamification endpoint" "disabled (empty pin)"
        return 0
    fi

    if [ ! -f "$endpoint_file" ]; then
        validate_record_fail "Gamification endpoint" "file at $endpoint_file" "missing" \
            "Re-run install after setting GAMIFICATION_EVENT_URL in install.sh"
        return 1
    fi

    actual_url=$(tr -d '\r\n' <"$endpoint_file")
    if [ "$actual_url" != "$VALIDATE_GAMIFICATION_URL" ]; then
        validate_record_fail "Gamification endpoint" "$VALIDATE_GAMIFICATION_URL" "$actual_url" \
            "Re-run install to refresh gamification-endpoint file"
        return 1
    fi

    validate_record_pass "Gamification endpoint" "configured"
}

validate_check_bmad_workspace() {
    if [ ! -d "$VALIDATE_WORKSPACE_ROOT/_bmad" ]; then
        validate_record_fail "BMAD workspace" "_bmad/ directory" "missing" \
            "Run install to deploy BMAD workspace"
        return 1
    fi
    validate_record_pass "BMAD workspace" "_bmad/ present"
}

validate_main() {
    validate_resolve_workspace

    log_info "validate-installation: workspace $VALIDATE_WORKSPACE_ROOT"
    printf '%s\n' 'Check Name                    | Status | Details' >&2
    printf '%s\n' '------------------------------|--------|----------------------------------------' >&2

    validate_check_global_skills
    validate_check_bmad_workspace
    validate_check_workspace_yaml
    validate_check_manifest_versions
    validate_check_gitai
    validate_check_graphify
    validate_check_central_context
    validate_check_graphify_hooks
    validate_check_gamification_config

    printf '\n' >&2
    if [ "$VALIDATE_FAIL_COUNT" -eq 0 ]; then
        log_success "Validation complete — $VALIDATE_PASS_COUNT check(s) passed"
        exit 0
    fi

    log_error "Validation failed — $VALIDATE_FAIL_COUNT failure(s), $VALIDATE_PASS_COUNT passed"
    exit 1
}

validate_main "$@"
