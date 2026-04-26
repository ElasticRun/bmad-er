#!/usr/bin/env bash
# Exercise hooks/prepare-commit-msg by giving it a fake commit message file
# and checking the trailers it appends.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/prepare-commit-msg"
. "$SCRIPT_DIR/../lib/assert.sh"

# Run the hook from inside a fresh git repo. $1 = initial message,
# $2 = commit source ("" for normal, "merge", "squash", "message", ...).
# $3 = optional branch to create. Echoes the resulting message file path.
run_hook() {
  local initial="$1" source="${2:-}" branch="${3:-}"
  local tmp; tmp=$(mktempdir)
  (
    cd "$tmp"
    git init -q
    git config user.email t@t.t
    git config user.name t
    if [ -n "$branch" ]; then
      # Need an initial commit before checkout -b sticks visibly to --show-current.
      printf seed > seed && git add seed && git commit -q -m seed
      git checkout -q -b "$branch"
    fi
    printf '%s' "$initial" > MSG
    bash "$HOOK" MSG "$source" >/dev/null 2>&1 || true
    cat MSG
  )
  rm -rf "$tmp"
}

test_appends_default_trailers() {
  local out; out="$(run_hook "fix something" "" "")"
  assert_contains "AI-Phase trailer added"  "$out" "AI-Phase: code"
  assert_contains "AI-Tool: manual added"   "$out" "AI-Tool: manual"
  assert_contains "Story-Ref present"       "$out" "Story-Ref:"
}

test_uses_branch_as_story_ref() {
  local out; out="$(run_hook "wip" "" "feature/123-payments")"
  assert_contains "Story-Ref derived from branch (suffix only)" "$out" "Story-Ref: 123-payments"
}

test_skips_when_phase_present() {
  local initial="fix something

AI-Phase: review
AI-Tool: cursor/claude-sonnet-4-6
Story-Ref: 5-1-checkout"
  local out; out="$(run_hook "$initial" "" "")"
  # Should NOT add a second AI-Phase line.
  local count; count=$(printf '%s\n' "$out" | grep -c '^AI-Phase:' || true)
  assert_eq "exactly one AI-Phase trailer remains" "$count" "1"
  assert_contains "original phase preserved"      "$out"   "AI-Phase: review"
  assert_not_contains "no manual trailer added"   "$out"   "AI-Tool: manual"
}

test_skips_merge_source() {
  local out; out="$(run_hook "Merge branch foo" "merge" "")"
  assert_not_contains "merge commit untouched" "$out" "AI-Phase:"
}

test_skips_squash_source() {
  local out; out="$(run_hook "Squashed" "squash" "")"
  assert_not_contains "squash commit untouched" "$out" "AI-Phase:"
}

test_unknown_branch_falls_back() {
  # Detached HEAD => no current branch => Story-Ref should be "unknown"
  local tmp; tmp=$(mktempdir)
  (
    cd "$tmp"
    git init -q
    git config user.email t@t.t
    git config user.name t
    printf seed > seed && git add seed && git commit -q -m seed
    git checkout -q --detach HEAD
    printf 'msg' > MSG
    bash "$HOOK" MSG "" >/dev/null 2>&1 || true
    cat MSG
  ) > "$tmp/out.txt"
  local out; out="$(cat "$tmp/out.txt")"
  rm -rf "$tmp"
  assert_contains "detached HEAD: Story-Ref unknown" "$out" "Story-Ref: unknown"
}

run_test test_appends_default_trailers
run_test test_uses_branch_as_story_ref
run_test test_skips_when_phase_present
run_test test_skips_merge_source
run_test test_skips_squash_source
run_test test_unknown_branch_falls_back
finish
