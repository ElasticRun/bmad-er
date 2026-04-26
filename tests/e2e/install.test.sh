#!/usr/bin/env bash
# Run scripts/install.sh against synthetic workspaces. Verifies skills-only,
# hooks-only, --global (with HOME redirected), --force, and workspace.yaml
# project discovery.
#
# Safety: every test runs install.sh with TARGET pointing at a tmp dir, and
# the --global test redirects HOME to a tmp dir. The user's real ~/.claude
# and ~/.cursor are never touched.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install.sh"
. "$SCRIPT_DIR/../lib/assert.sh"

run_install() {
  bash "$INSTALL" "$@" >/dev/null 2>&1
}

test_skills_only_populates_workspace() {
  local ws; ws=$(mktempdir)
  run_install --skills-only "$ws"

  assert_dir  "Claude skills dir created"        "$ws/.claude/skills"
  assert_dir  "Cursor skills dir created"        "$ws/.cursor/skills"
  assert_dir  "Claude rules dir created"         "$ws/.claude/rules"
  assert_dir  "Cursor rules dir created"         "$ws/.cursor/rules"
  assert_file "workspace.yaml generated"         "$ws/_bmad/workspace.yaml"
  assert_file "team.yaml seeded"                 "$ws/_bmad/_config/team.yaml"
  assert_file "adoption-dashboard.sh installed"  "$ws/scripts/adoption-dashboard.sh"

  # Each rule file install.sh copies must land in both .claude/rules and
  # .cursor/rules. Caveman's activator (dontbmad-caveman-activate.md) is
  # one of these — without it, /caveman doesn't get auto-applied.
  local rule
  for rule in bmad-workspace-resolution.md bmad-team-customization.md \
              dontbmad-graph-first.md dontbmad-caveman-activate.md; do
    assert_file ".claude/rules/$rule installed"  "$ws/.claude/rules/$rule"
    assert_file ".cursor/rules/$rule installed"  "$ws/.cursor/rules/$rule"
  done

  # Real repo has 59 skills per side; check that >= 10 made it across as a
  # smoke test (exact count would be brittle).
  local claude_count cursor_count
  claude_count=$(ls -1 "$ws/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')
  cursor_count=$(ls -1 "$ws/.cursor/skills" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${claude_count:-0}" -ge 10 ] && [ "${cursor_count:-0}" -ge 10 ]; then
    _pass "both skill trees populated (claude=$claude_count, cursor=$cursor_count)"
  else
    _fail "both skill trees populated" "got claude=$claude_count cursor=$cursor_count"
  fi

  # Out-of-repo install should produce real directories, not symlinks.
  local sample; sample=$(ls "$ws/.claude/skills" | head -1)
  if [ -n "$sample" ] && [ -d "$ws/.claude/skills/$sample" ] && [ ! -L "$ws/.claude/skills/$sample" ]; then
    _pass "out-of-repo install copies (not symlinks)"
  else
    _fail "out-of-repo install copies (not symlinks)" "expected real dir at $ws/.claude/skills/$sample"
  fi

  rm -rf "$ws"
}

test_skills_install_is_idempotent() {
  local ws; ws=$(mktempdir)
  run_install --skills-only "$ws"
  run_install --skills-only "$ws"
  assert_dir  "second install still has claude skills" "$ws/.claude/skills"
  assert_file "workspace.yaml not duplicated"          "$ws/_bmad/workspace.yaml"
  rm -rf "$ws"
}

test_workspace_yaml_discovers_project() {
  local ws; ws=$(mktempdir)
  mkdir -p "$ws/proj-alpha/_bmad/bmm"
  run_install --skills-only "$ws"
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  assert_contains "discovered project listed"          "$content" "proj-alpha:"
  assert_contains "default_project set when only one"  "$content" "default_project: 'proj-alpha'"
  rm -rf "$ws"
}

test_force_overwrites_workspace_yaml() {
  local ws; ws=$(mktempdir)
  run_install --skills-only "$ws"
  printf 'sentinel: true\n' > "$ws/_bmad/workspace.yaml"

  # Without --force, should preserve our edits
  run_install --skills-only "$ws"
  if grep -q '^sentinel: true$' "$ws/_bmad/workspace.yaml"; then
    _pass "no-force preserves user edits"
  else
    _fail "no-force preserves user edits" "sentinel was overwritten"
  fi

  # With --force, should regenerate
  run_install --skills-only --force "$ws"
  if grep -q '^sentinel: true$' "$ws/_bmad/workspace.yaml"; then
    _fail "--force regenerates workspace.yaml" "sentinel still present"
  else
    _pass "--force regenerates workspace.yaml"
  fi
  rm -rf "$ws"
}

test_hooks_only_installs_into_repo() {
  local ws; ws=$(mktempdir)
  ( cd "$ws" && git init -q sub-repo && cd sub-repo && \
      git config user.email t@t.t && git config user.name t )
  run_install --hooks-only "$ws"
  assert_file       "hook installed into sub-repo"      "$ws/sub-repo/.git/hooks/prepare-commit-msg"
  assert_executable "hook is executable"                "$ws/sub-repo/.git/hooks/prepare-commit-msg"
  rm -rf "$ws"
}

test_hooks_only_skips_when_no_repos() {
  local ws; ws=$(mktempdir)
  local out; out=$(bash "$INSTALL" --hooks-only "$ws" 2>&1)
  rm -rf "$ws"
  assert_contains "warns when no repos found" "$out" "No git repos"
}

test_global_publish_to_isolated_home() {
  # Redirect HOME so we never touch the real ~/.claude
  local fake_home; fake_home=$(mktempdir)
  HOME="$fake_home" run_install --global

  assert_dir  "global claude skills dir"             "$fake_home/.claude/skills"
  assert_dir  "global cursor skills dir"             "$fake_home/.cursor/skills"
  assert_dir  "global claude commands dir"           "$fake_home/.claude/commands"

  local sample; sample=$(ls "$fake_home/.claude/skills" 2>/dev/null | head -1)
  if [ -n "$sample" ]; then
    _pass "global publish populated skills (sample=$sample)"
    if [ -L "$fake_home/.claude/commands/$sample.md" ]; then
      _pass "command symlink created for $sample"
    else
      _fail "command symlink created" "missing $fake_home/.claude/commands/$sample.md"
    fi
  else
    _fail "global publish populated skills" "no skills in $fake_home/.claude/skills"
  fi

  rm -rf "$fake_home"
}

test_global_dev_link_uses_symlinks() {
  local fake_home; fake_home=$(mktempdir)
  HOME="$fake_home" run_install --global --dev-link

  local sample; sample=$(ls "$fake_home/.claude/skills" 2>/dev/null | head -1)
  if [ -n "$sample" ] && [ -L "$fake_home/.claude/skills/$sample" ]; then
    _pass "--dev-link creates symlink for skill"
    local target; target=$(readlink "$fake_home/.claude/skills/$sample")
    assert_contains "symlink targets repo's claude/skills" "$target" "$REPO_ROOT/claude/skills/$sample"
  else
    _fail "--dev-link creates symlink for skill" "expected symlink at $fake_home/.claude/skills/$sample"
  fi
  rm -rf "$fake_home"
}

run_test test_skills_only_populates_workspace
run_test test_skills_install_is_idempotent
run_test test_workspace_yaml_discovers_project
run_test test_force_overwrites_workspace_yaml
run_test test_hooks_only_installs_into_repo
run_test test_hooks_only_skips_when_no_repos
run_test test_global_publish_to_isolated_home
run_test test_global_dev_link_uses_symlinks
finish
