#!/bin/sh
# install.sh — lets-b-mad workspace orchestration entry point (POSIX sh)
# Continue-on-failure: no set -e; explicit return checking (NFR10)

# --- Version pins (NFR9, NFR17, NFR19) ---
BMAD_VERSION="6.8.0"
GITAI_VERSION="1.5.2"
GRAPHIFY_VERSION="0.8.27"
CENTRAL_CONTEXT_REPO_URL="git@github.com:elasticrun/central-context.git"
# GitLab OAuth-protected gamification endpoint (URL only; credentials via git credential store)
GAMIFICATION_EVENT_URL=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source foundation first, then all lib modules
. "$LIB_DIR/common.sh"
. "$LIB_DIR/manifest.sh"
. "$LIB_DIR/prerequisites.sh"
. "$LIB_DIR/bmad.sh"
. "$LIB_DIR/workspace.sh"
. "$LIB_DIR/dependencies.sh"
. "$LIB_DIR/hooks.sh"
. "$LIB_DIR/context.sh"

INSTALL_FORCE=0
INSTALL_WORKSPACE_ARG=""
INSTALL_TEMP_DIR=""
INSTALL_WORKSPACE_ROOT=""
INSTALL_WORST_EXIT=0
GRAPHIFY_INSTALL_OK=0

install_record_failure() {
    code="${1:-1}"
    case "$code" in
        ''|*[!0-9]*) code=1 ;;
    esac
    if [ "$code" -gt "$INSTALL_WORST_EXIT" ]; then
        INSTALL_WORST_EXIT="$code"
    fi
}

install_cleanup() {
    if [ -n "$INSTALL_TEMP_DIR" ] && [ -d "$INSTALL_TEMP_DIR" ]; then
        rm -rf "$INSTALL_TEMP_DIR"
        INSTALL_TEMP_DIR=""
    fi
}

install_parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --force)
                INSTALL_FORCE=1
                ;;
            --workspace)
                if [ $# -lt 2 ]; then
                    log_error "--workspace requires a path argument"
                    exit 1
                fi
                INSTALL_WORKSPACE_ARG="$2"
                shift
                ;;
            --workspace=*)
                INSTALL_WORKSPACE_ARG="${1#--workspace=}"
                ;;
            -h|--help)
                printf 'Usage: %s [--force] [--workspace PATH] [PATH]\n' "$0" >&2
                printf '\n  PATH  workspace root directory (optional; prompts if omitted)\n' >&2
                exit 0
                ;;
            --*)
                log_warn "Unknown argument: $1"
                ;;
            *)
                if [ -n "$INSTALL_WORKSPACE_ARG" ]; then
                    log_warn "Ignoring extra argument: $1"
                else
                    INSTALL_WORKSPACE_ARG="$1"
                fi
                ;;
        esac
        shift
    done
}

install_validate_workspace_path() {
    path="$1"
    [ -n "$path" ] || return 1
    [ -d "$path" ] || return 1
    INSTALL_WORKSPACE_ROOT="$(cd "$path" && pwd)" || return 1
    return 0
}

install_expand_home_path() {
    path="$1"
    case "$path" in
        ~/*)
            printf '%s%s' "$HOME" "${path#~}"
            ;;
        ~)
            printf '%s' "$HOME"
            ;;
        *)
            printf '%s' "$path"
            ;;
    esac
}

install_set_workspace_from_path() {
    path="$(install_expand_home_path "$1")"
    if install_validate_workspace_path "$path"; then
        return 0
    fi
    log_error "Invalid workspace folder: $path (must exist and be a directory)"
    exit 1
}

install_resolve_workspace() {
    if [ -n "$INSTALL_WORKSPACE_ARG" ]; then
        install_set_workspace_from_path "$INSTALL_WORKSPACE_ARG"
        return 0
    fi

    if [ -n "${LETS_B_MAD_WORKSPACE:-}" ]; then
        install_set_workspace_from_path "$LETS_B_MAD_WORKSPACE"
        return 0
    fi

    default="$(pwd)"
    workspace_input=""

    if [ -t 0 ]; then
        printf 'Workspace folder path [%s]: ' "$default" >&2
        IFS= read -r workspace_input || workspace_input=""
    else
        IFS= read -r workspace_input || workspace_input=""
    fi

    if [ -z "$workspace_input" ]; then
        workspace_input="$default"
    fi

    install_set_workspace_from_path "$workspace_input"
}

install_step_prerequisites() {
    step_name="Prerequisites"
    if prereqs_check_all; then
        summary_add_pass "$step_name" "all prerequisites present"
        return 0
    fi

    if prereqs_install; then
        summary_add_pass "$step_name" "installed missing prerequisites"
        return 0
    fi

    rc=$?
    summary_add_fail "$step_name" "exit $rc — see logs for manual install commands"
    install_record_failure "$rc"
    return "$rc"
}

install_step_bmad() {
    step_name="BMAD Install"
    if bmad_install "$INSTALL_TEMP_DIR" "$BMAD_VERSION"; then
        summary_add_pass "$step_name" "bmad-method@$BMAD_VERSION"
    else
        rc=$?
        summary_add_fail "$step_name" "npx install failed (exit $rc)"
        install_record_failure "$rc"
        return "$rc"
    fi
    return 0
}

install_step_skills() {
    step_name="Global Skills"
    if bmad_deploy_skills "$INSTALL_TEMP_DIR" "$INSTALL_FORCE"; then
        summary_add_pass "$step_name" "deployed to ~/.cursor and ~/.claude"
    else
        rc=$?
        summary_add_fail "$step_name" "skill deploy failed (exit $rc)"
        install_record_failure "$rc"
        return "$rc"
    fi
    return 0
}

install_step_workspace() {
    step_name="BMAD Workspace"
    if bmad_deploy_workspace "$INSTALL_TEMP_DIR" "$INSTALL_WORKSPACE_ROOT" "$INSTALL_FORCE"; then
        summary_add_pass "$step_name" "_bmad/ at workspace root"
    else
        rc=$?
        summary_add_fail "$step_name" "workspace deploy failed (exit $rc)"
        install_record_failure "$rc"
        return "$rc"
    fi
    return 0
}

install_step_toml() {
    step_name="Customize TOML"
    if bmad_generate_toml "$REPO_ROOT" "$INSTALL_WORKSPACE_ROOT" "$INSTALL_FORCE"; then
        summary_add_pass "$step_name" "_bmad/custom/*.toml"
    else
        rc=$?
        summary_add_fail "$step_name" "toml generation failed (exit $rc)"
        install_record_failure "$rc"
        return "$rc"
    fi
    return 0
}

install_step_gitai() {
    step_name="git-ai Install"
    if deps_install_gitai "$GITAI_VERSION"; then
        summary_add_pass "$step_name" "git-ai@$GITAI_VERSION"
        return 0
    fi

    rc=$?
    summary_add_fail "$step_name" "exit $rc — see logs"
    install_record_failure "$rc"
    return "$rc"
}

install_step_workspace_yaml() {
    step_name="Workspace YAML"
    if workspace_rediscover "$INSTALL_WORKSPACE_ROOT"; then
        summary_add_pass "$step_name" "workspace.yaml merged"
    else
        rc=$?
        summary_add_fail "$step_name" "workspace discovery failed (exit $rc)"
        install_record_failure "$rc"
        return "$rc"
    fi
    return 0
}

install_step_graphify() {
    step_name="graphify Install"
    if deps_install_graphify "$GRAPHIFY_VERSION"; then
        GRAPHIFY_INSTALL_OK=1
        summary_add_pass "$step_name" "graphify@$GRAPHIFY_VERSION"
        return 0
    fi

    rc=$?
    GRAPHIFY_INSTALL_OK=0
    summary_add_fail "$step_name" "exit $rc — see logs"
    install_record_failure "$rc"
    return "$rc"
}

install_step_graphify_init() {
    step_name="graphify Init"

    if [ "$GRAPHIFY_INSTALL_OK" -ne 1 ]; then
        summary_add_pass "$step_name" "skipped (graphify install failed)"
        return 0
    fi

    if deps_graphify_init_all "$INSTALL_WORKSPACE_ROOT"; then
        summary_add_pass "$step_name" "per-repo knowledge graphs"
        return 0
    fi

    rc=$?
    summary_add_fail "$step_name" "all repo inits failed (exit $rc)"
    install_record_failure "$rc"
    return "$rc"
}

install_step_hooks() {
    step_name="graphify Hooks"

    if [ "$GRAPHIFY_INSTALL_OK" -ne 1 ]; then
        summary_add_pass "$step_name" "skipped (graphify install failed)"
        return 0
    fi

    if hooks_install_all "$INSTALL_WORKSPACE_ROOT"; then
        summary_add_pass "$step_name" "post-commit + post-checkout"
        return 0
    fi

    rc=$?
    summary_add_fail "$step_name" "hook install failed (exit $rc)"
    install_record_failure "$rc"
    return "$rc"
}

install_step_context() {
    step_name="Central Context"
    if context_clone "$CENTRAL_CONTEXT_REPO_URL"; then
        summary_add_pass "$step_name" "cloned/updated at ~/.lets-b-mad/central-context/"
        return 0
    fi

    rc=$?
    summary_add_fail "$step_name" "exit $rc — see logs"
    install_record_failure "$rc"
    return "$rc"
}

install_write_gamification_config() {
    config_dir="${HOME}/.lets-b-mad"
    endpoint_file="$config_dir/gamification-endpoint"
    mkdir -p "$config_dir" || return 1
    printf '%s' "$GAMIFICATION_EVENT_URL" >"$endpoint_file" || return 1
    chmod 600 "$endpoint_file" 2>/dev/null || true
    return 0
}

install_step_gamification() {
    step_name="Gamification Config"
    if install_write_gamification_config; then
        if [ -n "$GAMIFICATION_EVENT_URL" ]; then
            summary_add_pass "$step_name" "endpoint at ~/.lets-b-mad/gamification-endpoint"
        else
            summary_add_pass "$step_name" "endpoint disabled (empty GAMIFICATION_EVENT_URL)"
        fi
        return 0
    fi

    rc=$?
    summary_add_fail "$step_name" "could not write gamification-endpoint (exit $rc)"
    install_record_failure "$rc"
    return "$rc"
}

install_main() {
    install_parse_args "$@"
    install_resolve_workspace

    summary_reset
    INSTALL_TEMP_DIR=$(mktemp -d) || {
        log_error "install: mktemp failed"
        exit 1
    }
    trap install_cleanup EXIT

    log_info "lets-b-mad install starting (workspace: $INSTALL_WORKSPACE_ROOT)"

    manifest_init "$INSTALL_WORKSPACE_ROOT" || {
        summary_add_fail "Manifest" "manifest_init failed"
        install_record_failure 1
    }
    manifest_read "$INSTALL_WORKSPACE_ROOT" || {
        summary_add_fail "Manifest" "manifest_read failed"
        install_record_failure 1
    }

    manifest_set_version "bmad" "$BMAD_VERSION" 2>/dev/null || true
    manifest_set_version "gitai" "$GITAI_VERSION" 2>/dev/null || true
    manifest_set_version "graphify" "$GRAPHIFY_VERSION" 2>/dev/null || true

    install_step_prerequisites || true

    install_step_bmad || true
    install_step_skills || true
    install_step_workspace || true
    install_step_toml || true
    install_step_gitai || true
    install_step_workspace_yaml || true
    install_step_graphify || true
    install_step_graphify_init || true
    install_step_hooks || true
    install_step_context || true
    install_step_gamification || true

    summary_print

    if [ "$INSTALL_WORST_EXIT" -eq 0 ]; then
        log_success "Installation complete — all steps passed"
        exit 0
    fi

    log_error "Installation finished with failures (exit $INSTALL_WORST_EXIT)"
    exit "$INSTALL_WORST_EXIT"
}

install_main "$@"
