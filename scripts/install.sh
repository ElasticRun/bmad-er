#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
bmad-er installer

Usage:
  bash install.sh [workspace-path]         Install skills + hooks for all repos
  bash install.sh [workspace-path] --skills-only   Skills only (no git required)
  bash install.sh [workspace-path] --hooks-only    Git hooks only (requires repos)

The workspace path defaults to the current directory.

Skills are installed at the workspace root (.cursor/skills/, .claude/skills/).
Git hooks are installed into every git repo found inside the workspace.
EOF
  exit 0
}

MODE="all"  # all | skills | hooks
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --help|-h)     usage ;;
    --skills-only) MODE="skills" ;;
    --hooks-only)  MODE="hooks" ;;
    *)             TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-.}"
TARGET="$(cd "$TARGET" && pwd)"

echo "bmad-er installer"
echo "Workspace: $TARGET"
echo ""

cursor_count=0
claude_count=0
hook_repos=0
dashboard_installed=false

# --- Skills: installed at workspace root (no git required) ---
if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  if [ -d "$REPO_ROOT/cursor/skills" ]; then
    mkdir -p "$TARGET/.cursor/skills"
    cp -r "$REPO_ROOT/cursor/skills/bmad-"* "$TARGET/.cursor/skills/"
    cursor_count=$(ls -d "$REPO_ROOT/cursor/skills/bmad-"* | wc -l | xargs)
    echo "  Cursor skills:  $cursor_count folders -> .cursor/skills/"
  fi

  if [ -d "$REPO_ROOT/claude/skills" ]; then
    mkdir -p "$TARGET/.claude/skills"
    cp -r "$REPO_ROOT/claude/skills/bmad-"* "$TARGET/.claude/skills/"
    claude_count=$(ls -d "$REPO_ROOT/claude/skills/bmad-"* | wc -l | xargs)
    echo "  Claude skills:  $claude_count folders -> .claude/skills/"
  fi

  if [ -f "$REPO_ROOT/scripts/adoption-dashboard.sh" ]; then
    mkdir -p "$TARGET/scripts"
    cp "$REPO_ROOT/scripts/adoption-dashboard.sh" "$TARGET/scripts/adoption-dashboard.sh"
    chmod +x "$TARGET/scripts/adoption-dashboard.sh"
    dashboard_installed=true
    echo "  Dashboard:      scripts/adoption-dashboard.sh installed"
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
  echo "Skills: $cursor_count Cursor, $claude_count Claude (workspace root)"
fi
if [ "$MODE" = "all" ] || [ "$MODE" = "hooks" ]; then
  echo "Hooks:  $hook_repos repo(s) with prepare-commit-msg installed"
fi
if $dashboard_installed; then
  echo ""
  echo "Run 'bash scripts/adoption-dashboard.sh' to see AI adoption metrics."
  echo "  Use --workspace to aggregate across all repos."
fi
echo ""
echo "Optional: install graphify for codebase knowledge graph"
echo "  pip install graphifyy && graphify cursor install"
echo "  Then run '/graphify .' in Cursor to build the graph."
