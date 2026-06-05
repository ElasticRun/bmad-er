# dependencies.sh — external tool installation (git-ai, graphify)
# Requires: common.sh sourced first; manifest.sh for version recording.
# Graphify init helpers require workspace.sh sourced (install.sh sources both).

GITAI_INSTALL_URL="https://usegitai.com/install.sh"

deps_gitai_binary() {
    if command -v git-ai >/dev/null 2>&1; then
        command -v git-ai
        return 0
    fi

    if [ -x "${HOME}/.git-ai/bin/git-ai" ]; then
        printf '%s\n' "${HOME}/.git-ai/bin/git-ai"
        return 0
    fi

    return 1
}

deps_gitai_installed_version() {
    gitai_bin=$(deps_gitai_binary) || return 1
    version_out=$("$gitai_bin" --version 2>/dev/null | head -n 1 | tr -d '[:space:]')
    if [ -z "$version_out" ]; then
        return 1
    fi
    printf '%s\n' "$version_out"
    return 0
}

_deps_normalize_version() {
    ver="$1"
    case "$ver" in
        v*) ver="${ver#v}" ;;
        V*) ver="${ver#V}" ;;
    esac
    printf '%s\n' "$ver"
}

_deps_version_matches() {
    expected="$1"
    actual="$2"

    if [ -z "$expected" ] || [ -z "$actual" ]; then
        return 1
    fi

    norm_expected=$(_deps_normalize_version "$expected")
    norm_actual=$(_deps_normalize_version "$actual")

    [ "$norm_expected" = "$norm_actual" ]
}

_deps_gitai_run_install() {
    pinned_version="$1"
    release_tag="v$(_deps_normalize_version "$pinned_version")"

    if [ -n "${DEPS_GITAI_INSTALL_CMD:-}" ]; then
        # Test hook — avoids network in unit tests
        # shellcheck disable=SC2086
        eval "$DEPS_GITAI_INSTALL_CMD"
        return $?
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_error "deps_install_gitai: curl not found"
        return 1
    fi

    log_info "Installing git-ai $pinned_version..."
    if GIT_AI_RELEASE_TAG="$release_tag" curl -sSL "$GITAI_INSTALL_URL" | bash; then
        return 0
    fi

    log_error "deps_install_gitai: curl install failed"
    return 1
}

deps_install_gitai() {
    pinned_version="$1"

    if [ -z "$pinned_version" ]; then
        log_error "deps_install_gitai: pinned version required"
        return "$EXIT_DEP_GITAI_FAILED"
    fi

    current_version=$(deps_gitai_installed_version 2>/dev/null || true)
    if [ -n "$current_version" ] && _deps_version_matches "$pinned_version" "$current_version"; then
        log_success "git-ai $current_version already installed (pinned: $pinned_version)"
        if [ -n "$MANIFEST_CURRENT_PATH" ]; then
            manifest_set_version "gitai" "$pinned_version" || true
        fi
        return 0
    fi

    if [ -n "$current_version" ]; then
        log_warn "git-ai $current_version installed; upgrading/reinstalling to $pinned_version"
    fi

    if ! _deps_gitai_run_install "$pinned_version"; then
        log_error "deps_install_gitai: installation failed"
        return "$EXIT_DEP_GITAI_FAILED"
    fi

    installed_version=$(deps_gitai_installed_version 2>/dev/null || true)
    if [ -z "$installed_version" ] || ! _deps_version_matches "$pinned_version" "$installed_version"; then
        log_error "deps_install_gitai: post-install version mismatch (expected $pinned_version, got ${installed_version:-none})"
        return "$EXIT_DEP_GITAI_FAILED"
    fi

    log_success "git-ai $installed_version installed"
    if [ -n "$MANIFEST_CURRENT_PATH" ]; then
        manifest_set_version "gitai" "$pinned_version" || true
    fi
    return 0
}

deps_graphify_binary() {
    if command -v graphify >/dev/null 2>&1; then
        command -v graphify
        return 0
    fi
    return 1
}

deps_graphify_installed_version() {
    graphify_bin=$(deps_graphify_binary) || return 1
    version_out=$("$graphify_bin" --version 2>/dev/null | head -n 1)
    version_out=$(printf '%s' "$version_out" | awk '{print $NF}' | tr -d '[:space:]')
    if [ -z "$version_out" ]; then
        return 1
    fi
    printf '%s\n' "$version_out"
    return 0
}

_deps_graphify_run_install() {
    pinned_version="$1"
    force_reinstall="${2:-0}"

    if [ -n "${DEPS_GRAPHIFY_INSTALL_CMD:-}" ]; then
        # shellcheck disable=SC2086
        eval "$DEPS_GRAPHIFY_INSTALL_CMD"
        return $?
    fi

    if ! command -v uv >/dev/null 2>&1; then
        log_error "deps_install_graphify: uv not found"
        return 1
    fi

    norm_version=$(_deps_normalize_version "$pinned_version")
    log_info "Installing graphify $pinned_version..."
    if [ "$force_reinstall" -eq 1 ]; then
        if uv tool install --force "graphifyy==$norm_version"; then
            return 0
        fi
    elif uv tool install "graphifyy==$norm_version"; then
        return 0
    fi

    log_error "deps_install_graphify: uv tool install failed"
    return 1
}

deps_install_graphify() {
    pinned_version="$1"

    if [ -z "$pinned_version" ]; then
        log_error "deps_install_graphify: pinned version required"
        return "$EXIT_DEP_GRAPHIFY_FAILED"
    fi

    current_version=$(deps_graphify_installed_version 2>/dev/null || true)
    if [ -n "$current_version" ] && _deps_version_matches "$pinned_version" "$current_version"; then
        log_success "graphify $current_version already installed (pinned: $pinned_version)"
        if [ -n "$MANIFEST_CURRENT_PATH" ]; then
            manifest_set_version "graphify" "$pinned_version" || true
        fi
        return 0
    fi

    force_flag=0
    if [ -n "$current_version" ]; then
        log_warn "graphify $current_version installed; upgrading/reinstalling to $pinned_version"
        force_flag=1
    fi

    if ! _deps_graphify_run_install "$pinned_version" "$force_flag"; then
        log_error "deps_install_graphify: installation failed"
        return "$EXIT_DEP_GRAPHIFY_FAILED"
    fi

    installed_version=$(deps_graphify_installed_version 2>/dev/null || true)
    if [ -z "$installed_version" ] || ! _deps_version_matches "$pinned_version" "$installed_version"; then
        log_error "deps_install_graphify: post-install version mismatch (expected $pinned_version, got ${installed_version:-none})"
        return "$EXIT_DEP_GRAPHIFY_FAILED"
    fi

    log_success "graphify $installed_version installed"
    if [ -n "$MANIFEST_CURRENT_PATH" ]; then
        manifest_set_version "graphify" "$pinned_version" || true
    fi
    return 0
}

_deps_graphify_run_init() {
    repo_abs="$1"

    if [ -n "${DEPS_GRAPHIFY_INIT_CMD:-}" ]; then
        export DEPS_GRAPHIFY_INIT_REPO="$repo_abs"
        # shellcheck disable=SC2086
        eval "$DEPS_GRAPHIFY_INIT_CMD"
        rc=$?
        unset DEPS_GRAPHIFY_INIT_REPO
        return "$rc"
    fi

    graphify_bin=$(deps_graphify_binary) || return 1
    if (cd "$repo_abs" && "$graphify_bin" update . --no-cluster); then
        return 0
    fi
    return 1
}

deps_graphify_init() {
    repo_abs="$1"

    if [ -z "$repo_abs" ] || [ ! -d "$repo_abs" ]; then
        log_error "deps_graphify_init: invalid repo path: ${repo_abs:-empty}"
        return 1
    fi

    if ! _deps_graphify_run_init "$repo_abs"; then
        log_warn "deps_graphify_init: graphify update failed for $repo_abs"
        return 1
    fi

    if [ ! -f "$repo_abs/graphify-out/graph.json" ]; then
        log_warn "deps_graphify_init: graphify-out/graph.json missing for $repo_abs"
        return 1
    fi

    return 0
}

deps_graphify_init_all() {
    workspace_root="$1"

    if [ -z "$workspace_root" ]; then
        log_error "deps_graphify_init_all: workspace path required"
        return 1
    fi

    if ! deps_graphify_binary >/dev/null 2>&1; then
        log_warn "deps_graphify_init_all: graphify not on PATH, skipping"
        return 0
    fi

    yaml_path=$(workspace_path_for "$workspace_root")
    if [ ! -f "$yaml_path" ]; then
        log_warn "deps_graphify_init_all: no workspace.yaml at $yaml_path, skipping"
        return 0
    fi

    if ! command -v yq >/dev/null 2>&1; then
        log_error "deps_graphify_init_all: yq not found on PATH"
        return 1
    fi

    root_abs=$(cd "$workspace_root" && pwd) || {
        log_error "deps_graphify_init_all: cannot resolve workspace path"
        return 1
    }

    repo_count=$(yq eval '.repos | length' "$yaml_path" 2>/dev/null) || repo_count=0
    case "$repo_count" in
        ''|*[!0-9]*) repo_count=0 ;;
    esac

    if [ "$repo_count" -eq 0 ]; then
        log_info "deps_graphify_init_all: no repos in workspace.yaml"
        return 0
    fi

    need_init=0
    success_count=0
    fail_count=0
    idx=0

    while [ "$idx" -lt "$repo_count" ]; do
        rel_path=$(yq eval ".repos[$idx].path" "$yaml_path" 2>/dev/null)
        initialized=$(yq eval ".repos[$idx].graphify_initialized" "$yaml_path" 2>/dev/null)
        idx=$((idx + 1))

        if [ -z "$rel_path" ] || [ "$rel_path" = "null" ]; then
            continue
        fi

        if ! workspace_should_process_repo "$workspace_root" "$rel_path"; then
            log_info "deps_graphify_init_all: skipping non-target repo for layout: $rel_path"
            continue
        fi

        if [ "$initialized" = "true" ]; then
            continue
        fi

        need_init=$((need_init + 1))
        disk_path=$(_workspace_repo_disk_path "$root_abs" "$rel_path") || {
            log_warn "deps_graphify_init_all: cannot resolve path for $rel_path"
            fail_count=$((fail_count + 1))
            continue
        }

        if [ ! -d "$disk_path/.git" ]; then
            log_warn "deps_graphify_init_all: not a git repo, skipping $rel_path"
            fail_count=$((fail_count + 1))
            continue
        fi

        log_info "deps_graphify_init_all: initializing $rel_path"
        if deps_graphify_init "$disk_path"; then
            if workspace_set_graphify_initialized "$workspace_root" "$rel_path"; then
                success_count=$((success_count + 1))
                log_success "deps_graphify_init_all: initialized $rel_path"
            else
                log_warn "deps_graphify_init_all: init ok but YAML update failed for $rel_path"
                fail_count=$((fail_count + 1))
            fi
        else
            log_warn "deps_graphify_init_all: init failed for $rel_path"
            fail_count=$((fail_count + 1))
        fi
    done

    if [ "$need_init" -eq 0 ]; then
        log_info "deps_graphify_init_all: all repos already graphify_initialized"
        return 0
    fi

    if [ "$success_count" -gt 0 ]; then
        return 0
    fi

    return 1
}

graphify_init_target_repo() {
    workspace_root="$1"
    rel_path="$2"

    if [ -z "$workspace_root" ] || [ -z "$rel_path" ]; then
        log_error "graphify_init_target_repo: workspace root and repo path required"
        return 1
    fi

    if ! deps_graphify_binary >/dev/null 2>&1; then
        log_error "graphify_init_target_repo: graphify not on PATH"
        return 1
    fi

    if ! workspace_is_graphify_target "$workspace_root" "$rel_path"; then
        return 1
    fi

    root_abs=$(cd "$workspace_root" && pwd) || {
        log_error "graphify_init_target_repo: cannot resolve workspace path"
        return 1
    }

    disk_path=$(_workspace_repo_disk_path "$root_abs" "$rel_path") || {
        log_error "graphify_init_target_repo: cannot resolve disk path for $rel_path"
        return 1
    }

    if [ ! -d "$disk_path/.git" ]; then
        log_error "graphify_init_target_repo: not a git repo: $rel_path"
        return 1
    fi

    log_info "graphify_init_target_repo: initializing $rel_path"
    if ! deps_graphify_init "$disk_path"; then
        log_error "graphify_init_target_repo: graphify init failed for $rel_path"
        return 1
    fi

    if ! workspace_set_graphify_initialized "$workspace_root" "$rel_path"; then
        log_error "graphify_init_target_repo: init ok but YAML update failed for $rel_path"
        return 1
    fi

    log_success "graphify_init_target_repo: initialized $rel_path"
    return 0
}
