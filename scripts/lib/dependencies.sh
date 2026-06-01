# dependencies.sh — external tool installation (git-ai, graphify)
# Requires: common.sh sourced first; manifest.sh for version recording.

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
