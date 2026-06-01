# workspace.sh — git repo discovery and workspace.yaml generation
# Requires: common.sh sourced first; yq on PATH for YAML generation.

WORKSPACE_YAML_NAME="workspace.yaml"
WORKSPACE_MAX_DEPTH=3
WORKSPACE_DISCOVER_FILE_NAME=".workspace-discovered"

# Well-known directories to skip when scanning (exact name match)
workspace_is_excluded_dir() {
    dir_name="$1"
    case "$dir_name" in
        node_modules|.git|vendor|dist|build|.venv|__pycache__)
            return 0
            ;;
    esac
    return 1
}

workspace_path_for() {
    workspace_root="$1"
    printf '%s/%s' "$workspace_root" "$WORKSPACE_YAML_NAME"
}

workspace_discover_file_for() {
    workspace_root="$1"
    printf '%s/%s/%s' "$workspace_root" "$MANIFEST_DIR_NAME" "$WORKSPACE_DISCOVER_FILE_NAME"
}

_workspace_rel_path() {
    root_abs="$1"
    target_abs="$2"

    if [ "$target_abs" = "$root_abs" ]; then
        printf '%s\n' "."
        return 0
    fi

    case "$target_abs" in
        "$root_abs"/*)
            printf '%s\n' "${target_abs#"$root_abs"/}"
            return 0
            ;;
    esac

    log_error "_workspace_rel_path: $target_abs not under $root_abs"
    return 1
}

_workspace_record_repo() {
    discover_file="$1"
    rel_path="$2"

    if [ ! -f "$discover_file" ]; then
        : > "$discover_file" || return 1
    fi

    if [ -s "$discover_file" ]; then
        if grep -Fx "$rel_path" "$discover_file" >/dev/null 2>&1; then
            return 0
        fi
    fi

    printf '%s\n' "$rel_path" >> "$discover_file" || return 1
    return 0
}

_workspace_scan_dir() {
    root_abs="$1"
    current_abs="$2"
    # Use $3 (depth) directly — assigning to a global clobbers parent frames in POSIX sh

    if [ -d "$current_abs/.git" ]; then
        rel_path=$(_workspace_rel_path "$root_abs" "$current_abs") || return 1
        _workspace_record_repo "$4" "$rel_path" || return 1
    fi

    if [ "$3" -ge "$WORKSPACE_MAX_DEPTH" ]; then
        return 0
    fi

    for entry in "$current_abs"/*; do
        [ -e "$entry" ] || continue
        [ -d "$entry" ] || continue
        base_name=$(basename "$entry")
        if workspace_is_excluded_dir "$base_name"; then
            continue
        fi
        entry_abs=$(cd "$entry" && pwd) || continue
        _workspace_scan_dir "$root_abs" "$entry_abs" $(( $3 + 1 )) "$4" || return 1
    done

    return 0
}

workspace_discover() {
    workspace_root="$1"

    if [ -z "$workspace_root" ]; then
        log_error "workspace_discover: workspace path required"
        return 1
    fi

    if [ ! -d "$workspace_root" ]; then
        log_error "workspace_discover: not a directory: $workspace_root"
        return 1
    fi

    root_abs=$(cd "$workspace_root" && pwd) || {
        log_error "workspace_discover: cannot resolve workspace path"
        return 1
    }

    discover_file=$(workspace_discover_file_for "$root_abs")
    discover_dir=$(dirname "$discover_file")
    mkdir -p "$discover_dir" || {
        log_error "workspace_discover: cannot create $discover_dir"
        return 1
    }

    : > "$discover_file" || {
        log_error "workspace_discover: cannot write $discover_file"
        return 1
    }

    _workspace_scan_dir "$root_abs" "$root_abs" 0 "$discover_file" || return 1

    if [ -s "$discover_file" ]; then
        sort -u "$discover_file" > "${discover_file}.tmp" && mv "${discover_file}.tmp" "$discover_file"
    fi

    log_info "workspace_discover: found $(wc -l < "$discover_file" | tr -d ' ') repos under $root_abs"
    return 0
}

workspace_discovered_count() {
    workspace_root="$1"
    discover_file=$(workspace_discover_file_for "$workspace_root")

    if [ ! -f "$discover_file" ]; then
        log_error "workspace_discovered_count: run workspace_discover first"
        return 1
    fi

    if [ ! -s "$discover_file" ]; then
        printf '0\n'
        return 0
    fi

    wc -l < "$discover_file" | tr -d ' '
    return 0
}

_workspace_repo_disk_path() {
    root_abs="$1"
    rel_path="$2"

    if [ "$rel_path" = "." ]; then
        printf '%s\n' "$root_abs"
        return 0
    fi

    printf '%s/%s' "$root_abs" "$rel_path"
}

_workspace_yaml_has_path() {
    yaml_doc="$1"
    rel_path="$2"

    export MERGE_PATH="$rel_path"
    found=$(printf '%s\n' "$yaml_doc" | yq eval '.repos[] | select(.path == strenv(MERGE_PATH)) | .path' - | head -n 1)
    [ -n "$found" ] && [ "$found" != "null" ]
}

_workspace_yaml_write() {
    yaml_doc="$1"
    yaml_path="$2"
    yaml_tmp="${yaml_path}.tmp"

    printf '%s\n' "$yaml_doc" | yq eval '.' - > "$yaml_tmp" || {
        log_error "workspace yaml write: yq format failed"
        rm -f "$yaml_tmp"
        return 1
    }

    mv "$yaml_tmp" "$yaml_path" || {
        log_error "workspace yaml write: cannot write $yaml_path"
        rm -f "$yaml_tmp"
        return 1
    }

    return 0
}

_workspace_yaml_create() {
    workspace_root="$1"
    root_abs="$2"
    discover_file="$3"
    yaml_path="$4"

    ws_name=$(basename "$root_abs")

    export WS_NAME="$ws_name"
    export WS_ROOT="$root_abs"
    yaml_doc=$(yq eval -n \
        '.workspace.name = strenv(WS_NAME) | .workspace.root = strenv(WS_ROOT) | .repos = []') || {
        log_error "workspace yaml create: yq init failed"
        return 1
    }

    if [ -s "$discover_file" ]; then
        while IFS= read -r repo_path; do
            [ -z "$repo_path" ] && continue
            if [ "$repo_path" = "." ]; then
                repo_name="$ws_name"
            else
                repo_name=$(basename "$repo_path")
            fi
            export REPO_PATH="$repo_path"
            export REPO_NAME="$repo_name"
            yaml_doc=$(printf '%s\n' "$yaml_doc" | yq eval \
                '.repos += [{"path": strenv(REPO_PATH), "name": strenv(REPO_NAME), "graphify_initialized": false}]' -) || {
                log_error "workspace yaml create: yq append failed for $repo_path"
                return 1
            }
        done < "$discover_file"
    fi

    _workspace_yaml_write "$yaml_doc" "$yaml_path" || return 1
    unset WS_NAME WS_ROOT REPO_PATH REPO_NAME MERGE_PATH
    return 0
}

workspace_merge_yaml() {
    workspace_root="$1"

    if [ -z "$workspace_root" ]; then
        log_error "workspace_merge_yaml: workspace path required"
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        log_error "workspace_merge_yaml: yq not found on PATH"
        return 1
    fi

    root_abs=$(cd "$workspace_root" && pwd) || {
        log_error "workspace_merge_yaml: cannot resolve workspace path"
        return 1
    }

    discover_file=$(workspace_discover_file_for "$root_abs")
    if [ ! -f "$discover_file" ]; then
        log_error "workspace_merge_yaml: run workspace_discover first"
        return 1
    fi

    yaml_path=$(workspace_path_for "$root_abs")
    ws_name=$(basename "$root_abs")

    if [ ! -f "$yaml_path" ]; then
        _workspace_yaml_create "$workspace_root" "$root_abs" "$discover_file" "$yaml_path" || return 1
        log_success "workspace_merge_yaml: created $yaml_path"
        return 0
    fi

    merged_doc=$(cat "$yaml_path") || {
        log_error "workspace_merge_yaml: cannot read $yaml_path"
        return 1
    }

    export WS_NAME="$ws_name"
    export WS_ROOT="$root_abs"
    merged_doc=$(printf '%s\n' "$merged_doc" | yq eval \
        '.workspace.name = strenv(WS_NAME) | .workspace.root = strenv(WS_ROOT)' -) || {
        log_error "workspace_merge_yaml: yq workspace update failed"
        return 1
    }

    existing_paths=$(printf '%s\n' "$merged_doc" | yq eval '.repos[].path' -)
    if [ -n "$existing_paths" ]; then
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            disk_path=$(_workspace_repo_disk_path "$root_abs" "$path")
            if [ ! -d "$disk_path" ]; then
                log_warn "workspace merge: repo path no longer exists: $path"
            fi
        done <<EOF
$existing_paths
EOF
    fi

    if [ -s "$discover_file" ]; then
        while IFS= read -r repo_path; do
            [ -z "$repo_path" ] && continue
            if _workspace_yaml_has_path "$merged_doc" "$repo_path"; then
                continue
            fi
            if [ "$repo_path" = "." ]; then
                repo_name="$ws_name"
            else
                repo_name=$(basename "$repo_path")
            fi
            export REPO_PATH="$repo_path"
            export REPO_NAME="$repo_name"
            merged_doc=$(printf '%s\n' "$merged_doc" | yq eval \
                '.repos += [{"path": strenv(REPO_PATH), "name": strenv(REPO_NAME), "graphify_initialized": false}]' -) || {
                log_error "workspace_merge_yaml: yq append failed for $repo_path"
                return 1
            }
        done < "$discover_file"
    fi

    _workspace_yaml_write "$merged_doc" "$yaml_path" || return 1
    unset WS_NAME WS_ROOT REPO_PATH REPO_NAME MERGE_PATH

    log_success "workspace_merge_yaml: merged $yaml_path"
    return 0
}

workspace_rediscover() {
    workspace_root="$1"

    workspace_discover "$workspace_root" || return 1
    workspace_merge_yaml "$workspace_root" || return 1
    return 0
}

workspace_generate_yaml() {
    workspace_root="$1"

    if [ -z "$workspace_root" ]; then
        log_error "workspace_generate_yaml: workspace path required"
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        log_error "workspace_generate_yaml: yq not found on PATH"
        return 1
    fi

    root_abs=$(cd "$workspace_root" && pwd) || {
        log_error "workspace_generate_yaml: cannot resolve workspace path"
        return 1
    }

    discover_file=$(workspace_discover_file_for "$root_abs")
    if [ ! -f "$discover_file" ]; then
        log_error "workspace_generate_yaml: run workspace_discover first"
        return 1
    fi

    yaml_path=$(workspace_path_for "$root_abs")
    if [ -f "$yaml_path" ]; then
        workspace_merge_yaml "$workspace_root" || return 1
        return 0
    fi

    _workspace_yaml_create "$workspace_root" "$root_abs" "$discover_file" "$yaml_path" || return 1

    log_success "workspace_generate_yaml: wrote $yaml_path"
    return 0
}

workspace_set_graphify_initialized() {
    workspace_root="$1"
    rel_path="$2"

    if [ -z "$workspace_root" ] || [ -z "$rel_path" ]; then
        log_error "workspace_set_graphify_initialized: workspace root and repo path required"
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        log_error "workspace_set_graphify_initialized: yq not found on PATH"
        return 1
    fi

    yaml_path=$(workspace_path_for "$workspace_root")
    if [ ! -f "$yaml_path" ]; then
        log_error "workspace_set_graphify_initialized: $yaml_path not found"
        return 1
    fi

    export INIT_PATH="$rel_path"
    if ! yq eval -i \
        '(.repos[] | select(.path == strenv(INIT_PATH)) | .graphify_initialized) = true' \
        "$yaml_path"; then
        log_error "workspace_set_graphify_initialized: yq update failed for $rel_path"
        unset INIT_PATH
        return 1
    fi
    unset INIT_PATH

    return 0
}
