#!/usr/bin/env bash
# Run check-skill-symlinks.sh against synthetic repo layouts to verify each
# drift class is detected and the clean case passes.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/check-skill-symlinks.sh"
. "$SCRIPT_DIR/../lib/assert.sh"

# The script computes REPO_ROOT as "<dir of script>/..". Copying it to
# <tmp>/scripts/ makes <tmp> the synthetic repo root.
make_fake_repo() {
  local root; root=$(mktempdir)
  mkdir -p "$root/scripts" "$root/claude/skills" "$root/cursor/skills" \
           "$root/.claude/skills" "$root/.cursor/skills" "$root/.claude/commands"
  cp "$SCRIPT_UNDER_TEST" "$root/scripts/check-skill-symlinks.sh"
  printf '%s' "$root"
}

# Add a canonical skill on the claude side and its expected mirror symlink.
seed_clean_claude_skill() {
  local root="$1" name="$2"
  mkdir -p "$root/claude/skills/$name"
  printf '# x' > "$root/claude/skills/$name/SKILL.md"
  ( cd "$root/.claude/skills" && ln -s "../../claude/skills/$name" "$name" )
}

run_check() {
  local root="$1"
  bash "$root/scripts/check-skill-symlinks.sh"
}

test_clean_state_passes() {
  local root; root=$(make_fake_repo)
  seed_clean_claude_skill "$root" "bmad-foo"
  local out rc
  out=$(run_check "$root" 2>&1); rc=$?
  rm -rf "$root"
  assert_zero    "exit code 0 on clean state" "$rc"
  assert_contains "OK message printed"        "$out" "OK: skill mirrors are clean"
}

test_missing_mirror_dir_flags() {
  local root; root=$(make_fake_repo)
  mkdir -p "$root/claude/skills/bmad-foo"
  rm -rf "$root/.claude/skills"
  local out rc
  out=$(run_check "$root" 2>&1); rc=$?
  rm -rf "$root"
  assert_nonzero  "exit non-zero when mirror dir missing" "$rc"
  assert_contains "MISSING reported"                      "$out" "MISSING: .claude/skills"
}

test_not_a_symlink_flags() {
  local root; root=$(make_fake_repo)
  mkdir -p "$root/claude/skills/bmad-foo" "$root/.claude/skills/bmad-foo"
  printf '# real dir not symlink' > "$root/.claude/skills/bmad-foo/SKILL.md"
  local out rc
  out=$(run_check "$root" 2>&1); rc=$?
  rm -rf "$root"
  assert_nonzero  "exit non-zero when mirror is real dir"  "$rc"
  assert_contains "NOT-A-SYMLINK reported"                 "$out" "NOT-A-SYMLINK: .claude/skills/bmad-foo"
}

test_broken_symlink_flags() {
  local root; root=$(make_fake_repo)
  mkdir -p "$root/claude/skills/bmad-foo"
  ( cd "$root/.claude/skills" && ln -s "../../claude/skills/does-not-exist" "bmad-foo" )
  local out rc
  out=$(run_check "$root" 2>&1); rc=$?
  rm -rf "$root"
  assert_nonzero  "exit non-zero on broken mirror symlink" "$rc"
  assert_contains "BROKEN-SYMLINK reported"                "$out" "BROKEN-SYMLINK: .claude/skills/bmad-foo"
}

test_broken_command_symlink_flags() {
  local root; root=$(make_fake_repo)
  seed_clean_claude_skill "$root" "bmad-foo"
  ( cd "$root/.claude/commands" && ln -s "../skills/bmad-gone/SKILL.md" "bmad-gone.md" )
  local out rc
  out=$(run_check "$root" 2>&1); rc=$?
  rm -rf "$root"
  assert_nonzero  "exit non-zero on broken command symlink" "$rc"
  assert_contains "BROKEN-SYMLINK on command file"          "$out" "BROKEN-SYMLINK: .claude/commands/bmad-gone.md"
}

test_real_repo_has_no_drift() {
  # Sanity: the repo's own state should be clean. Catches drift before commit.
  local out rc
  out=$(bash "$SCRIPT_UNDER_TEST" 2>&1); rc=$?
  assert_zero    "real repo is clean"     "$rc"
  assert_contains "OK message in real repo" "$out" "OK"
}

run_test test_clean_state_passes
run_test test_missing_mirror_dir_flags
run_test test_not_a_symlink_flags
run_test test_broken_symlink_flags
run_test test_broken_command_symlink_flags
run_test test_real_repo_has_no_drift
finish
