#!/usr/bin/env bash
# claude/skills/ and cursor/skills/ must contain the same set of skill
# directories. install.sh treats them symmetrically, so any divergence is
# a bug.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

list_skills() {
  local tree="$1"
  ( cd "$REPO_ROOT/$tree" 2>/dev/null && ls -1 | grep -E '^(bmad-|dontbmad-)' || true ) | sort
}

test_skill_sets_match() {
  local claude cursor only_in_claude only_in_cursor
  claude="$(list_skills claude/skills)"
  cursor="$(list_skills cursor/skills)"
  only_in_claude="$(comm -23 <(printf '%s\n' "$claude") <(printf '%s\n' "$cursor"))"
  only_in_cursor="$(comm -13 <(printf '%s\n' "$claude") <(printf '%s\n' "$cursor"))"
  assert_eq "no skills only in claude/skills"  "$only_in_claude" ""
  assert_eq "no skills only in cursor/skills"  "$only_in_cursor" ""
}

run_test test_skill_sets_match
finish
