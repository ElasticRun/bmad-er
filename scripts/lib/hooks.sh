# hooks.sh — graphify per-repo git hook installation and verification
# Requires: common.sh, workspace.sh, dependencies.sh (deps_graphify_binary).

HOOK_GRAPHIFY_MARKER="graphify-hook-start"
HOOK_POST_COMMIT="post-commit"
HOOK_POST_CHECKOUT="post-checkout"

hooks_detect_conflicts() {
    repo_abs="$1"

    if [ -z "$repo_abs" ] || [ ! -d "$repo_abs/.git" ]; then
        return 0
    fi

    hooks_dir="$repo_abs/.git/hooks"
    for hook_name in $HOOK_POST_COMMIT $HOOK_POST_CHECKOUT; do
        hook_file="$hooks_dir/$hook_name"
        if [ ! -f "$hook_file" ]; then
            continue
        fi
        if ! grep -q "$HOOK_GRAPHIFY_MARKER" "$hook_file" 2>/dev/null; then
            log_warn "hooks_detect_conflicts: $repo_abs has existing $hook_name not managed by graphify"
        fi
    done

    return 0
}

hooks_verify_repo() {
    repo_abs="$1"

    if [ -n "${HOOKS_GRAPHIFY_STATUS_CMD:-}" ]; then
        export HOOKS_GRAPHIFY_STATUS_REPO="$repo_abs"
        # shellcheck disable=SC2086
        eval "$HOOKS_GRAPHIFY_STATUS_CMD"
        rc=$?
        unset HOOKS_GRAPHIFY_STATUS_REPO
        return "$rc"
    fi

    graphify_bin=$(deps_graphify_binary) || return 1
    status_out=$(cd "$repo_abs" && "$graphify_bin" hook status 2>/dev/null) || return 1

    case "$status_out" in
        *"post-commit: installed"*) ;;
        *)
            log_warn "hooks_verify_repo: post-commit not installed in $repo_abs"
            return 1
            ;;
    esac

    case "$status_out" in
        *"post-checkout: installed"*) ;;
        *)
            log_warn "hooks_verify_repo: post-checkout not installed in $repo_abs"
            return 1
            ;;
    esac

    return 0
}

hooks_install_repo() {
    repo_abs="$1"

    if [ -z "$repo_abs" ] || [ ! -d "$repo_abs/.git" ]; then
        log_error "hooks_install_repo: not a git repo: ${repo_abs:-empty}"
        return 1
    fi

    hooks_detect_conflicts "$repo_abs" || true

    if hooks_verify_repo "$repo_abs"; then
        log_info "hooks_install_repo: hooks already installed in $repo_abs"
        return 0
    fi

    if [ -n "${HOOKS_GRAPHIFY_INSTALL_CMD:-}" ]; then
        export HOOKS_GRAPHIFY_INSTALL_REPO="$repo_abs"
        # shellcheck disable=SC2086
        eval "$HOOKS_GRAPHIFY_INSTALL_CMD"
        rc=$?
        unset HOOKS_GRAPHIFY_INSTALL_REPO
        if [ "$rc" -ne 0 ]; then
            return "$rc"
        fi
    else
        graphify_bin=$(deps_graphify_binary) || return 1
        if ! (cd "$repo_abs" && "$graphify_bin" hook install); then
            log_warn "hooks_install_repo: graphify hook install failed for $repo_abs"
            return 1
        fi
    fi

    if ! hooks_verify_repo "$repo_abs"; then
        log_warn "hooks_install_repo: verification failed for $repo_abs"
        return 1
    fi

    log_success "hooks_install_repo: graphify hooks installed in $repo_abs"
    return 0
}

hooks_install_all() {
    workspace_root="$1"

    if [ -z "$workspace_root" ]; then
        log_error "hooks_install_all: workspace path required"
        return 1
    fi

    if ! deps_graphify_binary >/dev/null 2>&1; then
        log_warn "hooks_install_all: graphify not on PATH, skipping"
        return 0
    fi

    yaml_path=$(workspace_path_for "$workspace_root")
    if [ ! -f "$yaml_path" ]; then
        log_warn "hooks_install_all: no workspace.yaml at $yaml_path, skipping"
        return 0
    fi

    if ! command -v yq >/dev/null 2>&1; then
        log_error "hooks_install_all: yq not found on PATH"
        return 1
    fi

    root_abs=$(cd "$workspace_root" && pwd) || {
        log_error "hooks_install_all: cannot resolve workspace path"
        return 1
    }

    repo_count=$(yq eval '.repos | length' "$yaml_path" 2>/dev/null) || repo_count=0
    case "$repo_count" in
        ''|*[!0-9]*) repo_count=0 ;;
    esac

    if [ "$repo_count" -eq 0 ]; then
        log_info "hooks_install_all: no repos in workspace.yaml"
        return 0
    fi

    success_count=0
    fail_count=0
    idx=0

    while [ "$idx" -lt "$repo_count" ]; do
        rel_path=$(yq eval ".repos[$idx].path" "$yaml_path" 2>/dev/null)
        idx=$((idx + 1))

        if [ -z "$rel_path" ] || [ "$rel_path" = "null" ]; then
            continue
        fi

        disk_path=$(_workspace_repo_disk_path "$root_abs" "$rel_path") || {
            log_warn "hooks_install_all: cannot resolve path for $rel_path"
            fail_count=$((fail_count + 1))
            continue
        }

        log_info "hooks_install_all: installing hooks for $rel_path"
        if hooks_install_repo "$disk_path"; then
            success_count=$((success_count + 1))
        else
            log_warn "hooks_install_all: hook install failed for $rel_path"
            fail_count=$((fail_count + 1))
        fi
    done

    if [ "$success_count" -gt 0 ]; then
        return 0
    fi

    if [ "$fail_count" -gt 0 ]; then
        return "$EXIT_HOOK_INSTALL_FAILED"
    fi

    return 0
}
