# manifest.sh — install manifest CRUD (.lets-b-mad/install-manifest.json)
# Requires: common.sh sourced first; jq on PATH.

MANIFEST_DIR_NAME=".lets-b-mad"
MANIFEST_FILE_NAME="install-manifest.json"

# Resolve manifest path for workspace root
manifest_path_for() {
    workspace_root="$1"
    printf '%s/%s/%s' "$workspace_root" "$MANIFEST_DIR_NAME" "$MANIFEST_FILE_NAME"
}

# Initialize new manifest at workspace
manifest_init() {
    workspace_root="$1"
    manifest_path=$(manifest_path_for "$workspace_root")
    manifest_dir=$(dirname "$manifest_path")

    if [ -z "$workspace_root" ]; then
        log_error "manifest_init: workspace path required"
        return 1
    fi

    mkdir -p "$manifest_dir" || {
        log_error "manifest_init: cannot create $manifest_dir"
        return 1
    }

    if [ -f "$manifest_path" ]; then
        log_info "manifest_init: manifest already exists at $manifest_path"
        return 0
    fi

    printf '%s\n' '{
  "version": 1,
  "versions": {},
  "files": {
    "managed": [],
    "protected": []
  },
  "workspace": {}
}' | jq '.' > "$manifest_path" || {
        log_error "manifest_init: failed to write manifest"
        return 1
    }
    log_info "manifest_init: created $manifest_path"
    return 0
}

# Load manifest path into MANIFEST_CURRENT_PATH (global for module)
MANIFEST_CURRENT_PATH=""

manifest_read() {
    workspace_root="$1"
    manifest_path=$(manifest_path_for "$workspace_root")

    if [ ! -f "$manifest_path" ]; then
        log_error "manifest_read: manifest not found at $manifest_path"
        return 1
    fi

    if ! jq empty < "$manifest_path" 2>/dev/null; then
        log_error "manifest_read: invalid JSON at $manifest_path"
        return 1
    fi

    MANIFEST_CURRENT_PATH="$manifest_path"
    return 0
}

manifest_write_tmp() {
    manifest_path="$1"
    jq_data="$2"
    printf '%s\n' "$jq_data" | jq '.' > "${manifest_path}.tmp" && mv "${manifest_path}.tmp" "$manifest_path"
}

manifest_add_managed() {
    file_path="$1"
    checksum_value="$2"

    if [ -z "$MANIFEST_CURRENT_PATH" ]; then
        log_error "manifest_add_managed: call manifest_read first"
        return 1
    fi

    if [ -z "$file_path" ] || [ -z "$checksum_value" ]; then
        log_error "manifest_add_managed: path and checksum required"
        return 1
    fi

    new_json=$(jq \
        --arg path "$file_path" \
        --arg checksum "$checksum_value" \
        '.files.managed = (.files.managed | map(select(.path != $path)) + [{path: $path, checksum: $checksum}])' \
        < "$MANIFEST_CURRENT_PATH") || return 1

    manifest_write_tmp "$MANIFEST_CURRENT_PATH" "$new_json" || return 1
    return 0
}

# Returns 0 if managed; prints checksum on stdout
manifest_is_managed() {
    file_path="$1"

    if [ -z "$MANIFEST_CURRENT_PATH" ]; then
        log_error "manifest_is_managed: call manifest_read first"
        return 1
    fi

    checksum_out=$(jq -r --arg path "$file_path" \
        '.files.managed[] | select(.path == $path) | .checksum' \
        < "$MANIFEST_CURRENT_PATH" | head -n 1)

    if [ -z "$checksum_out" ] || [ "$checksum_out" = "null" ]; then
        return 1
    fi

    printf '%s\n' "$checksum_out"
    return 0
}

manifest_add_protected() {
    file_path="$1"
    template_checksum="$2"
    current_checksum="$3"

    if [ -z "$MANIFEST_CURRENT_PATH" ]; then
        log_error "manifest_add_protected: call manifest_read first"
        return 1
    fi

    new_json=$(jq \
        --arg path "$file_path" \
        --arg tc "$template_checksum" \
        --arg cc "$current_checksum" \
        '.files.protected = (.files.protected | map(select(.path != $path)) + [{
            path: $path,
            template_checksum: $tc,
            current_checksum: $cc
        }])' \
        < "$MANIFEST_CURRENT_PATH") || return 1

    manifest_write_tmp "$MANIFEST_CURRENT_PATH" "$new_json" || return 1
    return 0
}

# Returns 0 if developer modified (preserve); 1 if safe to update (matches template)
manifest_file_modified() {
    file_path="$1"
    live_checksum="$2"

    if [ -z "$MANIFEST_CURRENT_PATH" ]; then
        log_error "manifest_file_modified: call manifest_read first"
        return 1
    fi

    entry=$(jq -r --arg path "$file_path" \
        '.files.protected[] | select(.path == $path) | "\(.template_checksum)|\(.current_checksum)"' \
        < "$MANIFEST_CURRENT_PATH" | head -n 1)

    if [ -z "$entry" ]; then
        return 1
    fi

    template_cs=$(printf '%s' "$entry" | cut -d'|' -f1)
    stored_current=$(printf '%s' "$entry" | cut -d'|' -f2)

    if [ "$live_checksum" = "$template_cs" ]; then
        return 1
    fi

    if [ "$live_checksum" = "$stored_current" ]; then
        return 1
    fi

    return 0
}

manifest_set_version() {
    component="$1"
    version_value="$2"

    if [ -z "$MANIFEST_CURRENT_PATH" ]; then
        log_error "manifest_set_version: call manifest_read first"
        return 1
    fi

    new_json=$(jq \
        --arg comp "$component" \
        --arg ver "$version_value" \
        '.versions[$comp] = $ver' \
        < "$MANIFEST_CURRENT_PATH") || return 1

    manifest_write_tmp "$MANIFEST_CURRENT_PATH" "$new_json" || return 1
    return 0
}
