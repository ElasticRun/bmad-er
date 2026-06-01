# bmad.sh — BMAD install, global skill deploy, workspace _bmad/, customize.toml generation

BMAD_NPX_PACKAGE="bmad-method"
BMAD_DEFAULT_MODULES="bmm,cis,wds"
BMAD_DEFAULT_TOOLS="cursor"

# Install BMAD into temp_dir via npx
bmad_install() {
    temp_dir="$1"
    bmad_version="$2"

    if [ -z "$temp_dir" ] || [ -z "$bmad_version" ]; then
        log_error "bmad_install: temp_dir and version required"
        return "$EXIT_BMAD_INSTALL_FAILED"
    fi

    if ! command -v npx >/dev/null 2>&1; then
        log_error "bmad_install: npx not found"
        return "$EXIT_BMAD_INSTALL_FAILED"
    fi

    log_info "Installing BMAD $bmad_version into $temp_dir..."
    if npx "${BMAD_NPX_PACKAGE}@${bmad_version}" install \
        --modules "$BMAD_DEFAULT_MODULES" \
        --tools "$BMAD_DEFAULT_TOOLS" \
        --yes \
        --directory "$temp_dir" >/dev/null 2>&1; then
        log_success "BMAD installed to $temp_dir"
        return 0
    fi

    log_error "bmad_install: npx bmad-method install failed"
    return "$EXIT_BMAD_INSTALL_FAILED"
}

# Find skills directory under temp BMAD output
_bmad_find_skills_src() {
    bmad_root="$1"
    if [ -d "$bmad_root/.cursor/skills" ]; then
        printf '%s\n' "$bmad_root/.cursor/skills"
        return 0
    fi
    if [ -d "$bmad_root/skills" ]; then
        printf '%s\n' "$bmad_root/skills"
        return 0
    fi
    find "$bmad_root" -type d -name skills 2>/dev/null | head -n 1
}

_bmad_wipe_dir() {
    target_dir="$1"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"
}

_bmad_copy_skills_tree() {
    src_dir="$1"
    dest_dir="$2"
    if [ ! -d "$src_dir" ]; then
        return 1
    fi
    mkdir -p "$dest_dir"
    # Copy contents (POSIX: cp -R)
    if [ -d "$src_dir" ]; then
        for item in "$src_dir"/*; do
            [ -e "$item" ] || continue
            cp -R "$item" "$dest_dir/" 2>/dev/null || return 1
        done
    fi
    return 0
}

# Wipe and deploy global skills; record in manifest; warn on checksum change
bmad_deploy_skills() {
    temp_dir="$1"
    force_mode="${2:-0}"

    cursor_skills="${HOME}/.cursor/skills"
    claude_skills="${HOME}/.claude/skills"

    skills_src=$(_bmad_find_skills_src "$temp_dir")
    if [ -z "$skills_src" ] || [ ! -d "$skills_src" ]; then
        log_error "bmad_deploy_skills: skills source not found under $temp_dir"
        return "$EXIT_BMAD_DEPLOY_FAILED"
    fi

    skills_changed=0
    if [ -n "$MANIFEST_CURRENT_PATH" ] && [ -f "$MANIFEST_CURRENT_PATH" ]; then
        skills_changed=$(bmad_skills_checksum_changed "$skills_src")
    fi

    _bmad_wipe_dir "$cursor_skills"
    _bmad_wipe_dir "$claude_skills"

    _bmad_copy_skills_tree "$skills_src" "$cursor_skills" || {
        log_error "bmad_deploy_skills: failed copying to $cursor_skills"
        return "$EXIT_BMAD_DEPLOY_FAILED"
    }
    _bmad_copy_skills_tree "$skills_src" "$claude_skills" || {
        log_error "bmad_deploy_skills: failed copying to $claude_skills"
        return "$EXIT_BMAD_DEPLOY_FAILED"
    }

    if [ -n "$MANIFEST_CURRENT_PATH" ]; then
        for skill_dir in "$cursor_skills"/*; do
            [ -d "$skill_dir" ] || continue
            for f in "$skill_dir"/*; do
                [ -f "$f" ] || continue
                rel_path="${f#"${HOME}"/}"
                cs=$(compute_checksum "$f") || continue
                manifest_add_managed "$rel_path" "$cs" || true
            done
        done
    fi

    if [ "$skills_changed" -eq 1 ] && [ "$force_mode" != "1" ]; then
        log_warn "Global skills updated. Restart Cursor and Claude Code to pick up changes."
    fi

    log_success "Global skills deployed"
    return 0
}

# Returns 1 if any skill file checksum differs from manifest (0 if fresh or unchanged)
bmad_skills_checksum_changed() {
    skills_src="$1"
    changed=0

    if [ ! -f "$MANIFEST_CURRENT_PATH" ]; then
        return 0
    fi

    for skill_dir in "$skills_src"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        for f in "$skill_dir"/*; do
            [ -f "$f" ] || continue
            rel_path=".cursor/skills/${skill_name}/$(basename "$f")"
            new_cs=$(compute_checksum "$f") || continue
            old_cs=$(manifest_is_managed "$rel_path" 2>/dev/null) || {
                changed=1
                continue
            }
            if [ "$new_cs" != "$old_cs" ]; then
                changed=1
            fi
        done
    done

    return "$changed"
}

bmad_deploy_workspace() {
    temp_dir="$1"
    workspace_root="$2"
    force_mode="${3:-0}"

    src_bmad=""
    if [ -d "$temp_dir/_bmad" ]; then
        src_bmad="$temp_dir/_bmad"
    elif [ -d "$temp_dir/.bmad" ]; then
        src_bmad="$temp_dir/.bmad"
    else
        found=$(find "$temp_dir" -maxdepth 3 -type d -name '_bmad' 2>/dev/null | head -n 1)
        src_bmad="$found"
    fi

    if [ -z "$src_bmad" ] || [ ! -d "$src_bmad" ]; then
        log_error "bmad_deploy_workspace: _bmad not found in temp output"
        return "$EXIT_BMAD_DEPLOY_FAILED"
    fi

    dest="$workspace_root/_bmad"

    if [ -d "$dest" ] && [ "$force_mode" != "1" ]; then
        log_info "bmad_deploy_workspace: preserving existing $dest"
        return 0
    fi

    if [ -d "$dest" ]; then
        rm -rf "$dest"
    fi

    cp -R "$src_bmad" "$dest" || {
        log_error "bmad_deploy_workspace: copy failed"
        return "$EXIT_BMAD_DEPLOY_FAILED"
    }

    log_success "bmad_deploy_workspace: deployed to $dest"
    return 0
}

bmad_generate_toml() {
    repo_root="$1"
    workspace_root="$2"
    force_mode="${3:-0}"

    template_file="$repo_root/templates/customize/_default.toml"
    custom_dir="$workspace_root/_bmad/custom"
    pre_script="$repo_root/scripts/pre-workflow.sh"
    post_script="$repo_root/scripts/post-workflow.sh"

    if [ ! -f "$template_file" ]; then
        log_error "bmad_generate_toml: template not found"
        return "$EXIT_BMAD_DEPLOY_FAILED"
    fi

    mkdir -p "$custom_dir"

    if [ ! -d "$workspace_root/_bmad" ]; then
        log_warn "bmad_generate_toml: _bmad not present, skipping"
        return 0
    fi

    cursor_skills="${HOME}/.cursor/skills"
    skill_count=0

    for skill_path in "$cursor_skills"/*; do
        [ -d "$skill_path" ] || continue
        skill_base=$(basename "$skill_path")
        case "$skill_base" in
            bmad-*) ;;
            *) continue ;;
        esac

        out_file="$custom_dir/${skill_base}.toml"

        if [ -f "$out_file" ] && [ "$force_mode" != "1" ]; then
            live_cs=$(compute_checksum "$out_file") || live_cs=""
            if [ -n "$live_cs" ] && manifest_file_modified "$out_file" "$live_cs"; then
                log_info "bmad_generate_toml: skipped developer-customized $out_file"
                continue
            fi
        fi

        sed \
            -e "s|{{PRE_WORKFLOW_PATH}}|$pre_script|g" \
            -e "s|{{POST_WORKFLOW_PATH}}|$post_script|g" \
            "$template_file" > "$out_file" || return "$EXIT_BMAD_DEPLOY_FAILED"

        tpl_cs=$(compute_checksum "$out_file")
        manifest_add_protected "$out_file" "$tpl_cs" "$tpl_cs" 2>/dev/null || true
        skill_count=$((skill_count + 1))
    done

    if [ "$skill_count" -eq 0 ]; then
        out_file="$custom_dir/_default-generated.toml"
        sed \
            -e "s|{{PRE_WORKFLOW_PATH}}|$pre_script|g" \
            -e "s|{{POST_WORKFLOW_PATH}}|$post_script|g" \
            "$template_file" > "$out_file"
        tpl_cs=$(compute_checksum "$out_file")
        manifest_add_protected "$out_file" "$tpl_cs" "$tpl_cs" 2>/dev/null || true
    fi

    log_success "bmad_generate_toml: generated customize.toml files"
    return 0
}
