#!/bin/sh
# post-workflow.sh — runtime post-workflow hook (self-contained stub)
# Invoked by BMAD on_complete hooks; non-blocking on internal failures.

_post_workflow_log() {
    printf '[post-workflow] %s\n' "$1" >&2
}

_post_workflow_resolve_name() {
    if [ -n "${1:-}" ]; then
        printf '%s\n' "$1"
        return 0
    fi
    if [ -n "${BMAD_WORKFLOW_NAME:-}" ]; then
        printf '%s\n' "$BMAD_WORKFLOW_NAME"
        return 0
    fi
    if [ -n "${WORKFLOW_NAME:-}" ]; then
        printf '%s\n' "$WORKFLOW_NAME"
        return 0
    fi
    printf '%s\n' "unknown"
}

_post_workflow_run_extensions() {
    workflow_name="$1"

    # --- Phase 2: Gamification event push ---
    # POST_WORKFLOW_GAMIFICATION_URL — GitLab OAuth-protected endpoint (Epic 7)
    # POST_WORKFLOW_GAMIFICATION_TOKEN — retrieved from secure store, never hardcoded
    # Example (disabled):
    #   curl -sf -X POST "$POST_WORKFLOW_GAMIFICATION_URL" \
    #     -H "Authorization: Bearer $POST_WORKFLOW_GAMIFICATION_TOKEN" \
    #     -d "{\"workflow\":\"$workflow_name\"}"

    if [ "${POST_WORKFLOW_TEST_FAIL:-0}" = "1" ]; then
        _post_workflow_log "WARN: extension hook test failure (simulated)"
        return 1
    fi

    _post_workflow_log "extensions complete for workflow: $workflow_name"
    return 0
}

workflow_name=$(_post_workflow_resolve_name "${1:-}")
_post_workflow_log "Post-workflow hook started (workflow: $workflow_name)"

if ! _post_workflow_run_extensions "$workflow_name"; then
    _post_workflow_log "WARN: post-workflow extension failed; BMAD workflow result unchanged"
fi

_post_workflow_log "Post-workflow hook finished."
exit 0
