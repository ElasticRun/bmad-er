#!/usr/bin/env bash
# Skills that produce SDLC artifacts must declare the right `AI-Phase:`
# trailer in their workflow, so the adoption dashboard groups commits
# correctly. This test pins the contract: skill name -> expected phase.
#
# Two checks per skill:
#   1. The skill's workflow files contain `AI-Phase: <expected>`
#   2. The same declaration exists in both claude/skills/ and cursor/skills/
#      (mirror parity — they should never disagree on the phase)
#
# Phases that the dashboard renders (must be one of these for the skill's
# commits to show up in a section):
#   PLANNING:    prd architecture ux-design epics sprint-plan story
#   DEVELOPMENT: code test review deploy
#
# Skills declaring an off-list phase are surfaced as warnings.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

# skill -> expected phase. Derived from the actual declarations in repo.
EXPECTED_MAP=(
  "bmad-create-prd|prd"
  "bmad-edit-prd|prd"
  "bmad-create-architecture|architecture"
  "bmad-create-ux-design|ux-design"
  "bmad-create-epics-and-stories|epics"
  "bmad-sprint-planning|sprint-plan"
  "bmad-create-story|story"
  "bmad-quick-dev|code"
  "bmad-dev-story|code"
  "bmad-qa-generate-e2e-tests|test"
  "bmad-code-review|review"
)

# Phases the dashboard's render() actually prints. Anything outside this
# set still counts toward TOTAL but never appears as a row.
DASHBOARD_PHASES_REGEX='^(prd|architecture|ux-design|epics|sprint-plan|story|code|test|review|deploy)$'

# Returns the first AI-Phase value declared anywhere under the skill dir.
declared_phase() {
  local skill_dir="$1"
  grep -rhE 'AI-Phase:[[:space:]]*[a-zA-Z-]+' "$skill_dir" 2>/dev/null \
    | head -1 \
    | grep -oE 'AI-Phase:[[:space:]]*[a-zA-Z-]+' \
    | sed -E 's/AI-Phase:[[:space:]]*//'
}

WARNINGS=()

test_known_skills_declare_correct_phase() {
  local entry skill expected actual_claude actual_cursor
  for entry in "${EXPECTED_MAP[@]}"; do
    skill="${entry%%|*}"
    expected="${entry##*|}"
    actual_claude=$(declared_phase "$REPO_ROOT/claude/skills/$skill")
    actual_cursor=$(declared_phase "$REPO_ROOT/cursor/skills/$skill")
    assert_eq "claude/$skill declares AI-Phase: $expected" "$actual_claude" "$expected"
    assert_eq "cursor/$skill declares AI-Phase: $expected" "$actual_cursor" "$expected"
  done
}

# Find any skill declaring an AI-Phase that isn't in the dashboard's render
# list. These get tracked in TOTAL but never show up in a section, which is
# almost always a bug or a typo in the skill's commit template.
test_phases_match_dashboard_render_list() {
  local skill_dir name phase
  for skill_dir in "$REPO_ROOT/claude/skills"/*/; do
    name="$(basename "$skill_dir")"
    phase=$(declared_phase "$skill_dir")
    [ -n "$phase" ] || continue
    if ! printf '%s\n' "$phase" | grep -qE "$DASHBOARD_PHASES_REGEX"; then
      WARNINGS+=("$name declares AI-Phase: $phase — not in dashboard render list, commits will be invisible in PLANNING/DEVELOPMENT sections")
    fi
  done

  # Coverage gap: dashboard renders 'deploy' but no skill emits it.
  local found_deploy=""
  for skill_dir in "$REPO_ROOT/claude/skills"/*/; do
    [ "$(declared_phase "$skill_dir")" = "deploy" ] && { found_deploy=1; break; }
  done
  if [ -z "$found_deploy" ]; then
    WARNINGS+=("no skill declares AI-Phase: deploy — the dashboard's deploy row will always be empty")
  fi

  # The actual assertion: surface warnings but don't fail the test (these
  # are findings, not bugs in the test framework). Pass if the loop ran.
  _pass "phase-vs-dashboard scan completed (${#WARNINGS[@]} finding(s))"
}

print_warnings() {
  [ "${#WARNINGS[@]}" -gt 0 ] || return 0
  printf "\n  notes (not failures):\n"
  local w
  for w in "${WARNINGS[@]}"; do
    printf "    - %s\n" "$w"
  done
}

run_test test_known_skills_declare_correct_phase
run_test test_phases_match_dashboard_render_list
print_warnings
finish
