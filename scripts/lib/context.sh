# context.sh — central context repository clone/pull (install-time)
# Requires: common.sh sourced first.

context_dir() {
    printf '%s\n' "${HOME}/.lets-b-mad/central-context"
}

_context_run_clone() {
    repo_url="$1"
    dest="$2"

    if [ -n "${CONTEXT_CLONE_CMD:-}" ]; then
        # Test hook — avoids network in unit tests
        # shellcheck disable=SC2086
        eval "$CONTEXT_CLONE_CMD"
        return $?
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "context_clone: git not found"
        return 1
    fi

    parent_dir=$(dirname "$dest")
    mkdir -p "$parent_dir" || {
        log_error "context_clone: cannot create $parent_dir"
        return 1
    }

    log_info "Cloning central context from $repo_url..."
    git clone "$repo_url" "$dest"
}

_context_run_pull() {
    dest="$1"

    if [ -n "${CONTEXT_PULL_CMD:-}" ]; then
        # Test hook — avoids network in unit tests
        # shellcheck disable=SC2086
        eval "$CONTEXT_PULL_CMD"
        return $?
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_error "context_clone: git not found"
        return 1
    fi

    log_info "Updating central context (git pull --ff-only)..."
    (
        cd "$dest" || exit 1
        git pull --ff-only
    )
}

context_clone() {
    repo_url="$1"
    dest=$(context_dir)

    if [ -z "$repo_url" ]; then
        log_error "context_clone: repo URL required"
        return "$EXIT_CONTEXT_CLONE_FAILED"
    fi

    if [ -d "$dest" ]; then
        if [ ! -d "$dest/.git" ]; then
            log_error "context_clone: $dest exists but is not a git repository"
            return "$EXIT_CONTEXT_CLONE_FAILED"
        fi

        if _context_run_pull "$dest"; then
            log_success "central context updated at $dest"
            return 0
        fi

        log_error "context_clone: git pull failed"
        return "$EXIT_CONTEXT_CLONE_FAILED"
    fi

    if _context_run_clone "$repo_url" "$dest"; then
        log_success "central context cloned to $dest"
        return 0
    fi

    log_error "context_clone: git clone failed"
    return "$EXIT_CONTEXT_CLONE_FAILED"
}
