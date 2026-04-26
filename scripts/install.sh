#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
dont-b-mad installer

Usage:
  bash install.sh [workspace-path]                  Install everything (workspace mode)
  bash install.sh [workspace-path] --skills-only    Skills only (no git required)
  bash install.sh [workspace-path] --hooks-only     Git hooks only (requires repos)
  bash install.sh [workspace-path] --force          Overwrite existing workspace.yaml
  bash install.sh --global                          Publish skills+commands to ~/.claude and ~/.cursor
  bash install.sh --global --dev-link               Same, but symlink to this repo (live edits)

Workspace mode (default): skills and rules install at the workspace root.
Git hooks install into every git repo found inside the workspace.
A workspace.yaml is generated listing discovered projects.

Global mode: publishes skills as copies (default) or symlinks (--dev-link)
into the user's home Claude/Cursor dirs. Slash commands are mirrored as
symlinks from ~/.claude/commands/ to each skill's SKILL.md so they're
available in every project.
EOF
  exit 0
}

MODE="all"  # all | skills | hooks | global
TARGET=""
FORCE=false
DEV_LINK=false
for arg in "$@"; do
  case "$arg" in
    --help|-h)     usage ;;
    --skills-only) MODE="skills" ;;
    --hooks-only)  MODE="hooks" ;;
    --global)      MODE="global" ;;
    --dev-link)    DEV_LINK=true ;;
    --force)       FORCE=true ;;
    *)             TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-.}"
TARGET="$(cd "$TARGET" && pwd)"

echo "dont-b-mad installer"
if [ "$MODE" = "global" ]; then
  echo "Mode:    global ($($DEV_LINK && echo "symlink to repo" || echo "copy to home"))"
else
  echo "Workspace: $TARGET"
fi
echo ""

cursor_count=0
claude_count=0
hook_repos=0
project_count=0
dashboard_installed=false

# --- Global publish: ~/.claude and ~/.cursor (independent of workspace) ---
if [ "$MODE" = "global" ]; then
  HOME_CLAUDE_SKILLS="$HOME/.claude/skills"
  HOME_CLAUDE_COMMANDS="$HOME/.claude/commands"
  HOME_CURSOR_SKILLS="$HOME/.cursor/skills"
  mkdir -p "$HOME_CLAUDE_SKILLS" "$HOME_CLAUDE_COMMANDS" "$HOME_CURSOR_SKILLS"

  publish_skills() {
    local src_dir="$1"        # claude/skills or cursor/skills
    local dst_skills="$2"     # ~/.claude/skills or ~/.cursor/skills
    local dst_commands="$3"   # ~/.claude/commands  or ""  (cursor has none)
    local label="$4"
    local count=0
    [ -d "$REPO_ROOT/$src_dir" ] || { echo "  $label  (no source dir)"; return 0; }
    for skill_path in "$REPO_ROOT/$src_dir/bmad-"* "$REPO_ROOT/$src_dir/dontbmad-"*; do
      [ -d "$skill_path" ] || continue
      local name; name=$(basename "$skill_path")
      rm -rf "$dst_skills/$name"
      if $DEV_LINK; then
        ln -s "$skill_path" "$dst_skills/$name"
      else
        cp -r "$skill_path" "$dst_skills/"
      fi
      if [ -n "$dst_commands" ]; then
        rm -f "$dst_commands/$name.md"
        ln -s "$dst_skills/$name/SKILL.md" "$dst_commands/$name.md"
      fi
      count=$((count + 1))
    done
    local mode_label; $DEV_LINK && mode_label="symlinks" || mode_label="copies"
    echo "  $label  $count $mode_label -> $dst_skills"
    [ -n "$dst_commands" ] && echo "  $label  $count command symlinks -> $dst_commands"
  }

  # Clean up any stale bmad-*/dontbmad-* command symlinks that no longer have a skill
  for f in "$HOME_CLAUDE_COMMANDS"/bmad-*.md "$HOME_CLAUDE_COMMANDS"/dontbmad-*.md; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    [ -L "$f" ] && [ ! -e "$f" ] && { rm -f "$f"; echo "  Cleaned broken: $(basename "$f")"; }
  done

  publish_skills "claude/skills" "$HOME_CLAUDE_SKILLS" "$HOME_CLAUDE_COMMANDS" "Claude:"
  publish_skills "cursor/skills" "$HOME_CURSOR_SKILLS" "" "Cursor:"

  echo ""
  echo "Globally published from $REPO_ROOT to ~/.claude and ~/.cursor."
  $DEV_LINK && echo "Live mode: edits to $REPO_ROOT/{claude,cursor}/skills/ apply immediately."
  $DEV_LINK || echo "Stable mode: re-run with --global to publish updates."
  exit 0
fi

# --- Skills: installed at workspace root (no git required) ---
# In-repo installs symlink so .claude/skills/ stays in sync with claude/skills/
# (single source of truth, no drift). External workspaces copy because they
# shouldn't depend on this repo's path being stable.
IN_REPO=false
if [ "$TARGET" = "$REPO_ROOT" ]; then
  IN_REPO=true
fi

install_skills_dir() {
  # Sets the global $INSTALL_SKILLS_COUNT after running. Prints summary line.
  local src_dir="$1"
  local dst_dir="$2"
  local label="$3"
  INSTALL_SKILLS_COUNT=0
  [ -d "$REPO_ROOT/$src_dir" ] || return 0
  mkdir -p "$dst_dir"
  for skill_path in "$REPO_ROOT/$src_dir/bmad-"* "$REPO_ROOT/$src_dir/dontbmad-"*; do
    [ -d "$skill_path" ] || continue
    local name; name=$(basename "$skill_path")
    if $IN_REPO; then
      rm -rf "$dst_dir/$name"
      ln -s "../../$src_dir/$name" "$dst_dir/$name"
    else
      rm -rf "$dst_dir/$name"
      cp -r "$skill_path" "$dst_dir/"
    fi
    INSTALL_SKILLS_COUNT=$((INSTALL_SKILLS_COUNT + 1))
  done
  local mode_label; $IN_REPO && mode_label="symlinks" || mode_label="folders"
  echo "  $label  $INSTALL_SKILLS_COUNT $mode_label -> ${dst_dir#"$TARGET"/}"
}

if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  install_skills_dir "cursor/skills" "$TARGET/.cursor/skills" "Cursor skills:"
  cursor_count=$INSTALL_SKILLS_COUNT
  install_skills_dir "claude/skills" "$TARGET/.claude/skills" "Claude skills:"
  claude_count=$INSTALL_SKILLS_COUNT

  if [ -f "$REPO_ROOT/scripts/adoption-dashboard.sh" ]; then
    mkdir -p "$TARGET/scripts"
    cp "$REPO_ROOT/scripts/adoption-dashboard.sh" "$TARGET/scripts/adoption-dashboard.sh"
    chmod +x "$TARGET/scripts/adoption-dashboard.sh"
    dashboard_installed=true
    echo "  Dashboard:      scripts/adoption-dashboard.sh installed"
  fi

  # --- Rules: installed to .cursor/rules/ and .claude/rules/ ---
  mkdir -p "$TARGET/.cursor/rules" "$TARGET/.claude/rules"
  for rule_file in bmad-workspace-resolution.md bmad-team-customization.md dontbmad-graph-first.md dontbmad-caveman-activate.md; do
    if [ -f "$REPO_ROOT/templates/$rule_file" ]; then
      cp "$REPO_ROOT/templates/$rule_file" "$TARGET/.cursor/rules/$rule_file"
      cp "$REPO_ROOT/templates/$rule_file" "$TARGET/.claude/rules/$rule_file"
    fi
  done
  echo "  Rules:          .cursor/rules/ + .claude/rules/"

  # --- Team config: default agent display names ---
  if [ -f "$REPO_ROOT/templates/team.yaml" ]; then
    mkdir -p "$TARGET/_bmad/_config"
    if [ ! -f "$TARGET/_bmad/_config/team.yaml" ] || $FORCE; then
      cp "$REPO_ROOT/templates/team.yaml" "$TARGET/_bmad/_config/team.yaml"
      echo "  Team config:    _bmad/_config/team.yaml"
    else
      echo "  Team config:    _bmad/_config/team.yaml exists, skipped (use --force to overwrite)"
    fi
  fi

  # --- Workspace config: auto-discover projects with _bmad/ ---
  # A project has _bmad/ with at least one module config dir (bmm/, cis/, core/)
  has_bmad_project() {
    local dir="$1"
    [ -d "$dir/_bmad/bmm" ] || [ -d "$dir/_bmad/cis" ] || [ -d "$dir/_bmad/core" ]
  }

  generate_workspace_config() {
    local ws="$1"
    local found_projects=""
    local count=0

    # Check workspace root itself (rare, but supports single-project layout)
    if has_bmad_project "$ws"; then
      found_projects="  .:
    path: .
    description: ''
"
      count=$((count + 1))
    fi

    # Scan one level deep for projects with _bmad/
    for dir in "$ws"/*/; do
      [ -d "$dir" ] || continue
      if has_bmad_project "$dir"; then
        local name
        name="$(basename "$dir")"
        found_projects="${found_projects}  ${name}:
    path: ${name}
    description: ''
"
        count=$((count + 1))
      fi
    done

    project_count=$count

    # Also detect git repos that don't have _bmad/ yet (they might get it later)
    for dir in "$ws"/*/; do
      [ -d "$dir" ] || continue
      local name
      name="$(basename "$dir")"
      if { [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; } && [ ! -d "$dir/_bmad" ]; then
        found_projects="${found_projects}  # ${name}:
  #   path: ${name}
  #   description: ''   # uncomment after running bmad init in this project
"
      fi
    done

    local default=""
    if [ "$count" -eq 1 ]; then
      default=$(echo "$found_projects" | head -1 | sed 's/:.*//' | xargs)
    fi

    cat <<ENDYAML
# BMad Workspace Configuration
#
# Maps project directories so BMAD skills resolve {project-root} to the
# correct project. Auto-generated by install.sh on $(date +%Y-%m-%d).
# Edit freely — the installer will not overwrite unless you pass --force.

default_project: '${default}'

projects:
${found_projects}
ENDYAML
  }

  if [ ! -f "$TARGET/_bmad/workspace.yaml" ] || $FORCE; then
    mkdir -p "$TARGET/_bmad"
    generate_workspace_config "$TARGET" > "$TARGET/_bmad/workspace.yaml"
    echo "  Workspace config: _bmad/workspace.yaml ($project_count project(s) discovered)"
  else
    echo "  Workspace config: _bmad/workspace.yaml exists, skipped (use --force to overwrite)"
  fi
fi

# --- Git hooks: installed per-repo inside the workspace ---
install_hook_to_repo() {
  local repo_dir="$1"
  local git_dir

  # Support both standard (.git dir) and worktree (.git file) layouts
  if [ -d "$repo_dir/.git" ]; then
    git_dir="$repo_dir/.git"
  elif [ -f "$repo_dir/.git" ]; then
    git_dir=$(git -C "$repo_dir" rev-parse --git-dir 2>/dev/null) || return 0
  else
    return 0
  fi

  mkdir -p "$git_dir/hooks"
  if [ -f "$git_dir/hooks/prepare-commit-msg" ]; then
    cp "$git_dir/hooks/prepare-commit-msg" "$git_dir/hooks/prepare-commit-msg.bak"
    echo "  Git hook:       ${repo_dir#"$TARGET"/} (backed up existing)"
  else
    echo "  Git hook:       ${repo_dir#"$TARGET"/}"
  fi
  cp "$REPO_ROOT/hooks/prepare-commit-msg" "$git_dir/hooks/prepare-commit-msg"
  chmod +x "$git_dir/hooks/prepare-commit-msg"
  hook_repos=$((hook_repos + 1))
}

if [ "$MODE" = "all" ] || [ "$MODE" = "hooks" ]; then
  if [ -f "$REPO_ROOT/hooks/prepare-commit-msg" ]; then
    # If the workspace root itself is a git repo, install there
    if [ -d "$TARGET/.git" ] || [ -f "$TARGET/.git" ]; then
      install_hook_to_repo "$TARGET"
    fi

    # Scan one level deep for git repos (typical workspace layout)
    for dir in "$TARGET"/*/; do
      [ -d "$dir" ] || continue
      if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
        install_hook_to_repo "${dir%/}"
      fi
    done

    if [ "$hook_repos" -eq 0 ] && [ "$MODE" = "hooks" ]; then
      echo "  No git repos found in $TARGET"
      echo "  Hooks are installed per-repo. Make sure repos exist inside the workspace."
    fi
  fi
fi

# --- Summary ---
echo ""
if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  echo "Skills:    $cursor_count Cursor, $claude_count Claude (workspace root)"
  echo "Projects:  $project_count discovered in _bmad/workspace.yaml"
fi
if [ "$MODE" = "all" ] || [ "$MODE" = "hooks" ]; then
  echo "Hooks:     $hook_repos repo(s) with prepare-commit-msg installed"
fi
if $dashboard_installed; then
  echo ""
  echo "Run 'bash scripts/adoption-dashboard.sh' to see AI adoption metrics."
  echo "  Use --workspace to aggregate across all repos."
fi
if [ "$project_count" -eq 0 ] && { [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; }; then
  echo ""
  echo "No projects with _bmad/ found yet. After initializing BMAD in a"
  echo "project, re-run the installer (or edit _bmad/workspace.yaml) to"
  echo "register it."
fi
if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  echo ""
  echo "Customize agent names: edit _bmad/_config/team.yaml"
fi
echo ""
echo "Optional: install graphify for codebase knowledge graph"
echo "  pip install graphifyy && graphify cursor install"
echo "  Then run '/graphify .' in Cursor to build the graph."
