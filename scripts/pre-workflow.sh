#!/bin/sh
# pre-workflow.sh — runtime pre-workflow hook (self-contained, no lib sourcing)
# Pulls latest central context before BMAD workflows; hard-blocks on failure (NFR12).

PRE_WORKFLOW_CONTEXT_DIR="${HOME}/.lets-b-mad/central-context"
PRE_WORKFLOW_EXIT_PULL_FAILED=41
PRE_WORKFLOW_RETRY_SLEEP=3

_pre_workflow_log() {
    printf '[pre-workflow] %s\n' "$1" >&2
}

_pre_workflow_hard_block() {
    _pre_workflow_log "ERROR: $1"
    _pre_workflow_log "WARN: Workflow cannot proceed with stale organizational context."
    _pre_workflow_log "WARN: Fix network/auth or run: bash scripts/install.sh"
    exit "$PRE_WORKFLOW_EXIT_PULL_FAILED"
}

_pre_workflow_is_lock_error() {
    err_text="$1"
    case "$err_text" in
        *"unable to lock"*) return 0 ;;
        *"Unable to create"*) return 0 ;;
        *"index.lock"*) return 0 ;;
    esac
    return 1
}

_pre_workflow_run_pull() {
    context_dir="$1"
    err_file="$2"

    if [ -n "${PRE_WORKFLOW_TEST_PULL_CMD:-}" ]; then
        # Test hook — avoids network in unit tests
        # shellcheck disable=SC2086
        eval "$PRE_WORKFLOW_TEST_PULL_CMD" 2>"$err_file"
        return $?
    fi

    if ! command -v git >/dev/null 2>&1; then
        printf 'git not found\n' >"$err_file"
        return 1
    fi

    (
        cd "$context_dir" || exit 1
        git pull --ff-only
    ) 2>"$err_file"
}

_pre_workflow_pull_with_retry() {
    context_dir="$1"
    attempt=1
    err_file=$(mktemp) || {
        _pre_workflow_hard_block "internal error: mktemp failed"
    }

    while [ "$attempt" -le 2 ]; do
        _pre_workflow_run_pull "$context_dir" "$err_file"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            rm -f "$err_file"
            return 0
        fi

        err_text=$(cat "$err_file" 2>/dev/null || true)

        if [ "$attempt" -eq 2 ]; then
            rm -f "$err_file"
            if _pre_workflow_is_lock_error "$err_text"; then
                _pre_workflow_hard_block "central context pull failed after retry (git lock): $err_text"
            fi
            _pre_workflow_hard_block "central context pull failed after retry: $err_text"
        fi

        if _pre_workflow_is_lock_error "$err_text"; then
            _pre_workflow_log "WARN: git lock detected; retrying in ${PRE_WORKFLOW_RETRY_SLEEP}s..."
        else
            _pre_workflow_log "WARN: context pull failed (exit $rc); retrying in ${PRE_WORKFLOW_RETRY_SLEEP}s..."
        fi

        sleep "$PRE_WORKFLOW_RETRY_SLEEP"
        attempt=$((attempt + 1))
    done

    rm -f "$err_file"
    return 1
}

if [ ! -d "$PRE_WORKFLOW_CONTEXT_DIR" ]; then
    _pre_workflow_hard_block "central context not found at $PRE_WORKFLOW_CONTEXT_DIR"
fi

if [ ! -d "$PRE_WORKFLOW_CONTEXT_DIR/.git" ]; then
    _pre_workflow_hard_block "central context path is not a git repository: $PRE_WORKFLOW_CONTEXT_DIR"
fi

_pre_workflow_log "Pulling latest organizational context..."
if _pre_workflow_pull_with_retry "$PRE_WORKFLOW_CONTEXT_DIR"; then
    _pre_workflow_log "Context pull succeeded."
    exit 0
fi

_pre_workflow_hard_block "central context pull failed"
