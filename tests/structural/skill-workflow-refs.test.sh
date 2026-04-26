#!/usr/bin/env bash
# When a SKILL.md says "Follow the instructions in ./workflow.md", that file
# must exist next to it. Catches broken skill installs after renames/moves.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

check_workflow_refs() {
  local tree="$1" skill_md skill_dir
  for skill_md in "$REPO_ROOT/$tree"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_dir="$(dirname "$skill_md")"
    if grep -qE 'Follow the instructions in \./workflow\.md' "$skill_md"; then
      assert_file "$tree/$(basename "$skill_dir")/workflow.md exists" "$skill_dir/workflow.md"
    fi
  done
}

test_claude_workflow_refs() { check_workflow_refs claude/skills; }
test_cursor_workflow_refs() { check_workflow_refs cursor/skills; }

run_test test_claude_workflow_refs
run_test test_cursor_workflow_refs
finish
