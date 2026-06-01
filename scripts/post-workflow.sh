#!/bin/sh
# post-workflow.sh — runtime post-workflow hook (self-contained stub)
# Invoked by BMAD on_complete hooks; non-blocking on internal failures.

POST_WORKFLOW_GAMIFICATION_ENDPOINT="${POST_WORKFLOW_GAMIFICATION_ENDPOINT:-$HOME/.lets-b-mad/gamification-endpoint}"

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

_post_workflow_url_protocol() {
    url="$1"
    case "$url" in
        http://*) printf '%s\n' "http" ;;
        https://*) printf '%s\n' "https" ;;
        *) return 1 ;;
    esac
}

_post_workflow_url_host() {
    url="$1"
    case "$url" in
        http://*) rest="${url#http://}" ;;
        https://*) rest="${url#https://}" ;;
        *) return 1 ;;
    esac
    host="${rest%%/*}"
    host="${host%%#*}"
    if [ -z "$host" ]; then
        return 1
    fi
    printf '%s\n' "$host"
}

_post_workflow_resolve_user() {
    user=""
    if command -v git >/dev/null 2>&1; then
        user=$(git config user.email 2>/dev/null) || true
        if [ -z "$user" ]; then
            user=$(git config user.name 2>/dev/null) || true
        fi
    fi
    if [ -z "$user" ]; then
        user="unknown"
    fi
    printf '%s\n' "$user"
}

_post_workflow_json_escape() {
    printf '%s' "$1" | tr -d '\n\r' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

_post_workflow_read_endpoint() {
    endpoint_file="$POST_WORKFLOW_GAMIFICATION_ENDPOINT"
    if [ ! -f "$endpoint_file" ]; then
        return 1
    fi
    url=$(tr -d '\r\n' <"$endpoint_file")
    if [ -z "$url" ]; then
        return 1
    fi
    printf '%s\n' "$url"
}

_post_workflow_credential_fill() {
    proto="$1"
    host="$2"
    cred_file="$3"

    if [ -n "${POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD:-}" ]; then
        # shellcheck disable=SC2086
        eval "$POST_WORKFLOW_TEST_CREDENTIAL_FILL_CMD" >"$cred_file"
        return $?
    fi

    if ! command -v git >/dev/null 2>&1; then
        return 1
    fi

    GIT_TERMINAL_PROMPT=0 git credential fill >"$cred_file" 2>/dev/null <<EOF
protocol=$proto
host=$host

EOF
}

_post_workflow_credential_approve() {
    cred_file="$1"
    if [ ! -s "$cred_file" ]; then
        return 1
    fi
    if ! command -v git >/dev/null 2>&1; then
        return 1
    fi
    GIT_TERMINAL_PROMPT=0 git credential approve <"$cred_file" 2>/dev/null
}

_post_workflow_push_gamification() {
    workflow_name="$1"
    url=""
    url=$(_post_workflow_read_endpoint) || {
        _post_workflow_log "WARN: gamification endpoint not configured; event push skipped"
        return 0
    }

    proto=$(_post_workflow_url_protocol "$url") || {
        _post_workflow_log "WARN: gamification URL has unsupported scheme; event push skipped"
        return 0
    }
    host=$(_post_workflow_url_host "$url") || {
        _post_workflow_log "WARN: gamification URL host could not be parsed; event push skipped"
        return 0
    }

    cred_file=$(mktemp) || {
        _post_workflow_log "WARN: gamification credential temp file failed; event push skipped"
        return 0
    }

    if ! _post_workflow_credential_fill "$proto" "$host" "$cred_file"; then
        rm -f "$cred_file"
        _post_workflow_log "WARN: no GitLab credential for $host; event push skipped"
        return 0
    fi

    password=$(sed -n 's/^password=//p' "$cred_file" | head -n 1)
    if [ -z "$password" ]; then
        rm -f "$cred_file"
        _post_workflow_log "WARN: credential fill returned no token; event push skipped"
        return 0
    fi

    _post_workflow_credential_approve "$cred_file" || true
    rm -f "$cred_file"

    user=$(_post_workflow_resolve_user)
    wf_esc=$(_post_workflow_json_escape "$workflow_name")
    user_esc=$(_post_workflow_json_escape "$user")
    host_esc=$(_post_workflow_json_escape "$host")
    payload="{\"workflow\":\"$wf_esc\",\"user\":\"$user_esc\",\"host\":\"$host_esc\"}"

    if [ "${POST_WORKFLOW_SKIP_CURL:-0}" = "1" ]; then
        _post_workflow_log "gamification push skipped (test mode) for workflow: $workflow_name"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        _post_workflow_log "WARN: curl not found; gamification event push skipped"
        return 0
    fi

    if ! curl -sf --max-time 5 \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $password" \
        -d "$payload" \
        "$url" >/dev/null 2>&1; then
        _post_workflow_log "WARN: gamification event push failed (fail-open)"
        return 0
    fi

    _post_workflow_log "gamification event pushed for workflow: $workflow_name"
    return 0
}

_post_workflow_run_extensions() {
    workflow_name="$1"

    _post_workflow_push_gamification "$workflow_name"

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
