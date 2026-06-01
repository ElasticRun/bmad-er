#!/bin/sh
# install.sh — lets-b-mad workspace orchestration entry point (POSIX sh)
# Continue-on-failure: no set -e; explicit return checking (NFR10)

# --- Version pins (NFR9, NFR17, NFR19) ---
BMAD_VERSION="6.8.0"
GITAI_VERSION="1.5.2"
GRAPHIFY_VERSION="0.8.27"

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

INSTALL_FORCE=0
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
            -h|--help)
                printf 'Usage: %s [--force]\n' "$0" >&2
                exit 0
                ;;
            *)
                log_warn "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

install_resolve_workspace() {
    INSTALL_WORKSPACE_ROOT="$(pwd)"
    if [ -n "${LETS_B_MAD_WORKSPACE:-}" ]; then
        INSTALL_WORKSPACE_ROOT="$LETS_B_MAD_WORKSPACE"
    fi
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

    summary_print

    if [ "$INSTALL_WORST_EXIT" -eq 0 ]; then
        log_success "Installation complete — all steps passed"
        exit 0
    fi

    log_error "Installation finished with failures (exit $INSTALL_WORST_EXIT)"
    exit "$INSTALL_WORST_EXIT"
}

install_main "$@"
