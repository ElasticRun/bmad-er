#!/bin/sh
# graphify-init-repo.sh — manual per-repo graphify init and re-init (FR18a)
# Usage: graphify-init-repo.sh [--hooks] <repo-relative-path>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/workspace.sh"
. "$LIB_DIR/dependencies.sh"

_gir_usage() {
    printf 'Usage: %s [--hooks] <repo-relative-path>\n' "$(basename "$0")" >&2
    printf '  Example: %s projects/api\n' "$(basename "$0")" >&2
    printf '  Standalone layout: %s .\n' "$(basename "$0")" >&2
}

_gir_resolve_workspace() {
    if [ -n "${LETS_B_MAD_WORKSPACE:-}" ]; then
        printf '%s\n' "$LETS_B_MAD_WORKSPACE"
        return 0
    fi
    pwd
}

_gir_main() {
    install_hooks=0
    repo_path=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --hooks)
                install_hooks=1
                shift
                ;;
            -h|--help)
                _gir_usage
                return 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "graphify-init-repo: unknown option: $1"
                _gir_usage
                return 1
                ;;
            *)
                if [ -n "$repo_path" ]; then
                    log_error "graphify-init-repo: unexpected extra argument: $1"
                    _gir_usage
                    return 1
                fi
                repo_path="$1"
                shift
                ;;
        esac
    done

    if [ -z "$repo_path" ]; then
        log_error "graphify-init-repo: repository path required"
        _gir_usage
        return 1
    fi

    repo_path=${repo_path%/}
    if [ -z "$repo_path" ]; then
        repo_path="."
    fi

    workspace_root=$(_gir_resolve_workspace)

    if ! graphify_init_target_repo "$workspace_root" "$repo_path"; then
        return 1
    fi

    if [ "$install_hooks" -eq 1 ]; then
        . "$LIB_DIR/hooks.sh"
        root_abs=$(cd "$workspace_root" && pwd) || {
            log_error "graphify-init-repo: cannot resolve workspace path"
            return 1
        }
        disk_path=$(_workspace_repo_disk_path "$root_abs" "$repo_path") || {
            log_error "graphify-init-repo: cannot resolve disk path for $repo_path"
            return 1
        }
        if ! hooks_install_repo "$disk_path"; then
            log_error "graphify-init-repo: hook install failed for $repo_path"
            return 1
        fi
    fi

    return 0
}

_gir_main "$@" || exit 1
exit 0
