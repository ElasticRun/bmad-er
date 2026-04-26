#!/usr/bin/env bash
# Verify that .claude/skills/, .cursor/skills/, and .claude/commands/ are
# clean symlinks into the canonical claude/skills/ and cursor/skills/ sources.
# Exits 0 if clean, 1 if drift is found.
#
# Run from any directory inside the repo:
#   bash scripts/check-skill-symlinks.sh
#
# To auto-fix drift, run scripts/install.sh from the repo root.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

issues=0

check_skills_mirror() {
  local src="$1"   # claude/skills or cursor/skills
  local mirror="$2"  # .claude/skills or .cursor/skills
  [ -d "$src" ] || return 0
  [ -d "$mirror" ] || { echo "MISSING: $mirror (run scripts/install.sh)"; issues=$((issues + 1)); return 0; }

  for skill_path in "$src/bmad-"* "$src/dontbmad-"*; do
    [ -d "$skill_path" ] || continue
    local name; name=$(basename "$skill_path")
    local mirror_path="$mirror/$name"
    if [ ! -e "$mirror_path" ] && [ ! -L "$mirror_path" ]; then
      echo "MISSING: $mirror_path (canonical exists at $skill_path)"
      issues=$((issues + 1))
    elif [ ! -L "$mirror_path" ]; then
      echo "NOT-A-SYMLINK: $mirror_path (should be symlink to ../../$src/$name)"
      issues=$((issues + 1))
    elif [ ! -e "$mirror_path" ]; then
      echo "BROKEN-SYMLINK: $mirror_path -> $(readlink "$mirror_path")"
      issues=$((issues + 1))
    fi
  done
}

check_commands_mirror() {
  local cmd_dir=".claude/commands"
  [ -d "$cmd_dir" ] || return 0
  for link in "$cmd_dir"/bmad-*.md "$cmd_dir"/dontbmad-*.md; do
    [ -e "$link" ] || [ -L "$link" ] || continue
    if [ -L "$link" ] && [ ! -e "$link" ]; then
      echo "BROKEN-SYMLINK: $link -> $(readlink "$link")"
      issues=$((issues + 1))
    fi
  done
}

check_skills_mirror "claude/skills" ".claude/skills"
check_skills_mirror "cursor/skills" ".cursor/skills"
check_commands_mirror

if [ "$issues" -eq 0 ]; then
  echo "OK: skill mirrors are clean symlinks into canonical sources"
  exit 0
else
  echo ""
  echo "$issues drift issue(s) found. Run 'bash scripts/install.sh --skills-only' to fix."
  exit 1
fi
