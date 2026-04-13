#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

echo "bmad-er installer"
echo "Target project: $TARGET"
echo ""

# Validate target is a git repo
if [ ! -d "$TARGET/.git" ]; then
  echo "Error: $TARGET is not a git repository."
  echo "Initialize one first: cd $TARGET && git init"
  exit 1
fi

cursor_count=0
claude_count=0
hook_installed=false
dashboard_installed=false

# Install Cursor skills
if [ -d "$REPO_ROOT/cursor/skills" ]; then
  mkdir -p "$TARGET/.cursor/skills"
  cp -r "$REPO_ROOT/cursor/skills/bmad-"* "$TARGET/.cursor/skills/"
  cursor_count=$(ls -d "$REPO_ROOT/cursor/skills/bmad-"* | wc -l | xargs)
  echo "  Cursor skills:  $cursor_count folders -> .cursor/skills/"
fi

# Install Claude Code skills
if [ -d "$REPO_ROOT/claude/skills" ]; then
  mkdir -p "$TARGET/.claude/skills"
  cp -r "$REPO_ROOT/claude/skills/bmad-"* "$TARGET/.claude/skills/"
  claude_count=$(ls -d "$REPO_ROOT/claude/skills/bmad-"* | wc -l | xargs)
  echo "  Claude skills:  $claude_count folders -> .claude/skills/"
fi

# Install git hook
if [ -f "$REPO_ROOT/hooks/prepare-commit-msg" ]; then
  mkdir -p "$TARGET/.git/hooks"
  if [ -f "$TARGET/.git/hooks/prepare-commit-msg" ]; then
    echo "  Git hook:       .git/hooks/prepare-commit-msg exists, backing up to .bak"
    cp "$TARGET/.git/hooks/prepare-commit-msg" "$TARGET/.git/hooks/prepare-commit-msg.bak"
  fi
  cp "$REPO_ROOT/hooks/prepare-commit-msg" "$TARGET/.git/hooks/prepare-commit-msg"
  chmod +x "$TARGET/.git/hooks/prepare-commit-msg"
  hook_installed=true
  echo "  Git hook:       prepare-commit-msg installed"
fi

# Install dashboard
if [ -f "$REPO_ROOT/scripts/adoption-dashboard.sh" ]; then
  mkdir -p "$TARGET/scripts"
  cp "$REPO_ROOT/scripts/adoption-dashboard.sh" "$TARGET/scripts/adoption-dashboard.sh"
  chmod +x "$TARGET/scripts/adoption-dashboard.sh"
  dashboard_installed=true
  echo "  Dashboard:      scripts/adoption-dashboard.sh installed"
fi

echo ""
echo "Done. $cursor_count Cursor skills, $claude_count Claude skills."
if $hook_installed; then
  echo "Manual commits will be auto-tagged with AI trailers."
fi
if $dashboard_installed; then
  echo "Run 'bash scripts/adoption-dashboard.sh' to see AI adoption metrics."
fi
