#!/usr/bin/env bash
# Drive scripts/adoption-dashboard.sh against synthetic git repos to verify
# trailer parsing, AI-vs-manual classification, --workspace aggregation,
# and the Story-Ref filter glob.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DASHBOARD="$REPO_ROOT/scripts/adoption-dashboard.sh"
. "$SCRIPT_DIR/../lib/assert.sh"

# Make a commit whose message body contains the requested trailers.
# Args: repo_path, subject, phase, tool, story_ref
add_commit() {
  local repo="$1" subject="$2" phase="$3" tool="$4" ref="$5"
  local n; n=$(date +%s%N 2>/dev/null || gdate +%s%N 2>/dev/null || echo $RANDOM)
  printf '%s' "$n" >> "$repo/log.txt"
  (
    cd "$repo"
    git add log.txt
    git commit -q -m "$subject" \
      -m "AI-Phase: $phase
AI-Tool: $tool
Story-Ref: $ref"
  )
}

# Initialize a fresh git repo with sane identity.
init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q -b main 2>/dev/null || git init -q
    git config user.email t@t.t
    git config user.name t
  )
}

test_no_trailers_repo_reports_empty() {
  local tmp; tmp=$(mktempdir)
  init_repo "$tmp"
  ( cd "$tmp" && printf seed > seed && git add seed && git commit -q -m "seed (no trailers)" )
  local out; out=$(bash "$DASHBOARD" --repo "$tmp" 2>&1)
  rm -rf "$tmp"
  assert_contains "empty result message" "$out" "No commits with AI trailers found"
}

test_single_repo_counts_ai_vs_manual() {
  local tmp; tmp=$(mktempdir)
  init_repo "$tmp"
  add_commit "$tmp" "code: a" "code" "cursor/claude-sonnet" "1-foo"
  add_commit "$tmp" "code: b" "code" "manual"               "1-foo"
  add_commit "$tmp" "code: c" "code" "cursor/claude-opus"   "2-bar"
  add_commit "$tmp" "review"  "review" "cursor/claude-opus" "1-foo"
  local out; out=$(bash "$DASHBOARD" --repo "$tmp" 2>&1)
  rm -rf "$tmp"
  assert_contains "DEVELOPMENT section present" "$out" "DEVELOPMENT"
  assert_contains "code line shows 2/3 ai"      "$out" "[2/3]"
  assert_contains "review line shows 1/1"       "$out" "[1/1]"
  assert_contains "TOTAL count includes all"    "$out" "TOTAL: 4 tracked commits"
}

test_filter_restricts_to_matching_story_ref() {
  local tmp; tmp=$(mktempdir)
  init_repo "$tmp"
  add_commit "$tmp" "x" "code" "cursor/claude" "1-alpha"
  add_commit "$tmp" "y" "code" "cursor/claude" "1-beta"
  add_commit "$tmp" "z" "code" "cursor/claude" "2-gamma"
  local out; out=$(bash "$DASHBOARD" --repo "$tmp" "1-*" 2>&1)
  rm -rf "$tmp"
  assert_contains "filter line shown"          "$out" "Filter: Story-Ref = 1-*"
  assert_contains "totals reflect filter only" "$out" "TOTAL: 2 tracked commits"
}

test_workspace_mode_aggregates_repos() {
  local ws; ws=$(mktempdir)
  init_repo "$ws/r1"
  init_repo "$ws/r2"
  add_commit "$ws/r1" "x" "code"  "cursor/claude" "1-alpha"
  add_commit "$ws/r2" "y" "test"  "cursor/claude" "1-alpha"
  add_commit "$ws/r2" "z" "review" "manual"       "1-alpha"
  local out; out=$(bash "$DASHBOARD" --workspace "$ws" 2>&1)
  rm -rf "$ws"
  assert_contains "scanned 2 repos"    "$out" "Repos scanned: 2"
  assert_contains "TOTAL aggregates"   "$out" "TOTAL: 3 tracked commits"
  assert_contains "review row present" "$out" "review"
}

test_planning_phases_render() {
  local tmp; tmp=$(mktempdir)
  init_repo "$tmp"
  add_commit "$tmp" "p1" "prd"          "cursor/claude" "1-x"
  add_commit "$tmp" "p2" "architecture" "cursor/claude" "1-x"
  add_commit "$tmp" "p3" "story"        "manual"        "1-x"
  local out; out=$(bash "$DASHBOARD" --repo "$tmp" 2>&1)
  rm -rf "$tmp"
  assert_contains "PLANNING section present" "$out" "PLANNING"
  assert_contains "prd row present"          "$out" "prd"
  assert_contains "architecture row present" "$out" "architecture"
  assert_contains "story row present"        "$out" "story"
}

test_workspace_finds_deeply_nested_repos() {
  # Real workspaces have repos at varying depths. discover_repos walks any
  # depth, just pruning common noise dirs.
  local ws; ws=$(mktempdir)
  init_repo "$ws/team-a/svc/api"
  init_repo "$ws/team-b/lib"
  add_commit "$ws/team-a/svc/api" "x" "code" "cursor/claude" "1-x"
  add_commit "$ws/team-b/lib"     "y" "test" "cursor/claude" "1-x"
  local out; out=$(bash "$DASHBOARD" --workspace "$ws" 2>&1)
  rm -rf "$ws"
  assert_contains "scanned 2 deep-nested repos" "$out" "Repos scanned: 2"
  assert_contains "TOTAL aggregates depth"      "$out" "TOTAL: 2 tracked commits"
}

test_workspace_skips_pruned_dirs() {
  # discover_repos prunes node_modules, .venv, vendor, etc. so vendored
  # checkouts of other people's repos don't pollute the dashboard.
  local ws; ws=$(mktempdir)
  init_repo "$ws/app"
  add_commit "$ws/app" "real" "code" "cursor/claude" "1-x"
  init_repo "$ws/app/node_modules/some-lib"
  add_commit "$ws/app/node_modules/some-lib" "vendored" "code" "cursor/claude" "9-noise"
  local out; out=$(bash "$DASHBOARD" --workspace "$ws" 2>&1)
  rm -rf "$ws"
  assert_contains "only the real repo counted"  "$out" "Repos scanned: 1"
  assert_contains "TOTAL excludes node_modules" "$out" "TOTAL: 1 tracked commits"
  assert_not_contains "vendored ref absent"     "$out" "9-noise"
}

test_workspace_dedupes_nested_git_under_outer() {
  # If an inner git repo sits inside an outer git repo (submodule-style
  # checkout), discover_repos should drop the inner so the outer's commits
  # aren't double-counted from both perspectives.
  local ws; ws=$(mktempdir)
  init_repo "$ws/outer"
  add_commit "$ws/outer" "outer-a" "code" "cursor/claude" "1-x"
  add_commit "$ws/outer" "outer-b" "code" "cursor/claude" "1-x"
  init_repo "$ws/outer/inner"
  add_commit "$ws/outer/inner" "inner-only" "code" "cursor/claude" "2-y"
  local out; out=$(bash "$DASHBOARD" --workspace "$ws" 2>&1)
  rm -rf "$ws"
  assert_contains "exactly one repo scanned (outer)" "$out" "Repos scanned: 1"
  # Outer has 2 commits. Inner's 1 should be dropped.
  assert_contains "TOTAL = outer's commits only"     "$out" "TOTAL: 2 tracked commits"
}

test_all_known_sdlc_phases_render_end_to_end() {
  # The dashboard's render() iterates two fixed phase lists. For every phase
  # in those lists, a commit with that AI-Phase trailer must show up as a
  # row in the right section. This is the contract between skill commits
  # and the dashboard.
  local tmp; tmp=$(mktempdir)
  init_repo "$tmp"
  local p
  for p in prd architecture ux-design epics sprint-plan story; do
    add_commit "$tmp" "plan: $p" "$p" "cursor/claude" "1-x"
  done
  for p in code test review deploy; do
    add_commit "$tmp" "dev: $p"  "$p" "cursor/claude" "1-x"
  done
  local out; out=$(bash "$DASHBOARD" --repo "$tmp" 2>&1)
  rm -rf "$tmp"

  assert_contains "PLANNING header"           "$out" "PLANNING (6 commits)"
  assert_contains "DEVELOPMENT header"        "$out" "DEVELOPMENT (4 commits)"
  # Every planning phase row must appear with [1/1]
  local phase
  for phase in prd architecture ux-design epics sprint-plan story; do
    assert_contains "planning row: $phase"    "$out" "$phase"
  done
  for phase in code test review deploy; do
    assert_contains "development row: $phase" "$out" "$phase"
  done
  assert_contains "TOTAL counts all 10 commits" "$out" "TOTAL: 10 tracked commits"
}

test_off_list_phases_count_in_total_but_not_rendered() {
  # bmad-correct-course declares phase "sprint-change" and bmad-product-brief
  # declares "brief". Neither is in the dashboard's render list, so they
  # don't appear in PLANNING/DEVELOPMENT but DO show in TOTAL.
  local tmp; tmp=$(mktempdir)
  init_repo "$tmp"
  add_commit "$tmp" "cc"    "sprint-change" "cursor/claude" "1-x"
  add_commit "$tmp" "brief" "brief"         "cursor/claude" "1-x"
  add_commit "$tmp" "code"  "code"          "cursor/claude" "1-x"
  local out; out=$(bash "$DASHBOARD" --repo "$tmp" 2>&1)
  rm -rf "$tmp"

  assert_contains "TOTAL includes off-list phases" "$out" "TOTAL: 3 tracked commits"
  assert_contains "DEVELOPMENT renders code"        "$out" "code"
  # Header text "PLANNING" should not appear because none of its phases hit
  assert_not_contains "PLANNING section absent"     "$out" "PLANNING ("
  # The off-list phase strings should not appear as rendered rows
  assert_not_contains "sprint-change not rendered"  "$out" "sprint-change"
  assert_not_contains "brief not rendered"          "$out" "brief "
}

run_test test_no_trailers_repo_reports_empty
run_test test_single_repo_counts_ai_vs_manual
run_test test_filter_restricts_to_matching_story_ref
run_test test_workspace_mode_aggregates_repos
run_test test_planning_phases_render
run_test test_workspace_finds_deeply_nested_repos
run_test test_workspace_skips_pruned_dirs
run_test test_workspace_dedupes_nested_git_under_outer
run_test test_all_known_sdlc_phases_render_end_to_end
run_test test_off_list_phases_count_in_total_but_not_rendered
finish
