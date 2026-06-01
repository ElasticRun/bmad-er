#!/bin/sh
# ai-stats-summary.sh — local git-ai metrics summary per workspace repo
# Self-contained runtime script; does not source scripts/lib/ install modules.

WORKSPACE_YAML="workspace.yaml"

_aistats_log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

_aistats_resolve_workspace() {
    if [ -n "${LETS_B_MAD_WORKSPACE:-}" ]; then
        printf '%s\n' "$LETS_B_MAD_WORKSPACE"
        return 0
    fi
    pwd
}

_aistats_repo_disk_path() {
    workspace_root="$1"
    rel_path="$2"

    if [ "$rel_path" = "." ]; then
        printf '%s\n' "$workspace_root"
        return 0
    fi

    printf '%s/%s' "$workspace_root" "$rel_path"
}

_aistats_compute_ai_pct() {
    json_blob="$1"
    printf '%s\n' "$json_blob" | jq -r '
        (.ai_additions // 0) as $ai |
        (.human_additions // 0) as $human |
        (.unknown_additions // 0) as $unknown |
        ($ai + $human + $unknown) as $total |
        if $total > 0 then (($ai * 100) / $total | floor) else 0 end
    '
}

_aistats_print_repo_row() {
    repo_label="$1"
    repo_path="$2"
    stats_json="$3"

    ai_pct=$(_aistats_compute_ai_pct "$stats_json")
    ai_lines=$(printf '%s\n' "$stats_json" | jq -r '.ai_additions // 0')
    ai_accepted=$(printf '%s\n' "$stats_json" | jq -r '.ai_accepted // 0')

    printf '%-28s | %3s%% | %6s | %6s | %s\n' \
        "$repo_label" "$ai_pct" "$ai_lines" "$ai_accepted" "$repo_path"
}

_aistats_process_repo() {
    workspace_root="$1"
    rel_path="$2"
    repo_name="$3"

    disk_path=$(_aistats_repo_disk_path "$workspace_root" "$rel_path")

    if [ ! -d "$disk_path/.git" ]; then
        printf '%-28s | %3s | %6s | %6s | %s\n' \
            "$repo_name" "-" "-" "-" "not a git repo ($rel_path)"
        return 0
    fi

    stats_json=$(cd "$disk_path" && git ai stats --json 2>/dev/null) || stats_json=""
    if [ -z "$stats_json" ] || ! printf '%s\n' "$stats_json" | jq empty 2>/dev/null; then
        printf '%-28s | %3s | %6s | %6s | %s\n' \
            "$repo_name" "-" "-" "-" "No git-ai data"
        return 0
    fi

    _aistats_print_repo_row "$repo_name" "$rel_path" "$stats_json"
    return 0
}

_aistats_main() {
    workspace_root=$(_aistats_resolve_workspace)
    yaml_path="$workspace_root/$WORKSPACE_YAML"

    if [ ! -f "$yaml_path" ]; then
        _aistats_log_error "workspace.yaml not found at $yaml_path"
        exit 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        _aistats_log_error "yq not found on PATH"
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        _aistats_log_error "jq not found on PATH"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        _aistats_log_error "git not found on PATH"
        exit 1
    fi

    printf '%s\n' "Repository                  | AI% | AI Lns | Accptd | Path / Status"
    printf '%s\n' "----------------------------|-----|--------|--------|------------------"

    repo_count=$(yq eval '.repos | length' "$yaml_path" 2>/dev/null) || repo_count=0
    if [ "$repo_count" = "0" ] || [ -z "$repo_count" ] || [ "$repo_count" = "null" ]; then
        printf '%s\n' "(no repositories in workspace.yaml)"
        exit 0
    fi

    idx=0
    while [ "$idx" -lt "$repo_count" ]; do
        rel_path=$(yq eval ".repos[$idx].path" "$yaml_path")
        repo_name=$(yq eval ".repos[$idx].name" "$yaml_path")
        if [ -z "$rel_path" ] || [ "$rel_path" = "null" ]; then
            idx=$((idx + 1))
            continue
        fi
        if [ -z "$repo_name" ] || [ "$repo_name" = "null" ]; then
            repo_name="$rel_path"
        fi
        _aistats_process_repo "$workspace_root" "$rel_path" "$repo_name"
        idx=$((idx + 1))
    done

    exit 0
}

_aistats_main "$@"
