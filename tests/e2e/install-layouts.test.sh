#!/usr/bin/env bash
# Workspace-shape coverage for scripts/install.sh:
#   - in-repo install uses symlinks (TARGET == REPO_ROOT)
#   - workspace root is itself a BMAD project (`.:` entry, default = '.')
#   - multi-project workspace lists every child with _bmad/
#   - git repos without _bmad/ appear as commented stubs

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install.sh"
. "$SCRIPT_DIR/../lib/assert.sh"

# Make a minimal copy of this repo's shape: scripts, hooks, templates, and
# one skill on each side. install.sh resolves REPO_ROOT from $(dirname "$0"),
# so running the copied installer makes <fake_root> the synthetic repo.
make_fake_repo() {
  local root; root=$(mktempdir)
  mkdir -p "$root/scripts" "$root/hooks" "$root/templates" \
           "$root/claude/skills/bmad-foo" "$root/cursor/skills/bmad-foo"

  cp "$REPO_ROOT/scripts/install.sh"             "$root/scripts/install.sh"
  cp "$REPO_ROOT/scripts/adoption-dashboard.sh"  "$root/scripts/adoption-dashboard.sh"
  cp "$REPO_ROOT/hooks/prepare-commit-msg"       "$root/hooks/prepare-commit-msg"

  printf -- '---\nname: bmad-foo\ndescription: test skill\n---\n' \
    | tee "$root/claude/skills/bmad-foo/SKILL.md" \
    > "$root/cursor/skills/bmad-foo/SKILL.md"

  for f in bmad-workspace-resolution.md bmad-team-customization.md \
           dontbmad-graph-first.md dontbmad-caveman-activate.md; do
    printf '# %s stub\n' "$f" > "$root/templates/$f"
  done
  printf 'team:\n  defaults: stub\n' > "$root/templates/team.yaml"

  printf '%s' "$root"
}

test_in_repo_install_uses_symlinks() {
  local root fake_home
  root=$(make_fake_repo)
  fake_home=$(mktempdir)
  HOME="$fake_home" bash "$root/scripts/install.sh" --skills-only "$root" >/dev/null 2>&1

  # In-repo install publishes skills to ~/.claude and ~/.cursor (user level),
  # NOT to the workspace root. And because TARGET == REPO_ROOT, symlinks back
  # to the source so dev edits flow live.
  if [ ! -d "$root/.claude/skills" ] && [ ! -d "$root/.cursor/skills" ]; then
    _pass "in-repo: no workspace-level skills dirs created"
  else
    _fail "in-repo: no workspace-level skills dirs" \
      "unexpected $root/.claude/skills or $root/.cursor/skills"
  fi

  assert_dir     "in-repo: ~/.claude/skills exists"           "$fake_home/.claude/skills"
  assert_dir     "in-repo: ~/.cursor/skills exists"           "$fake_home/.cursor/skills"
  assert_symlink "in-repo: claude skill is a symlink"         "$fake_home/.claude/skills/bmad-foo"
  assert_symlink "in-repo: cursor skill is a symlink"         "$fake_home/.cursor/skills/bmad-foo"

  # Symlink target should be the canonical claude/skills/bmad-foo in the source repo.
  # Normalize $root the same way install.sh does (collapses // from $TMPDIR).
  local root_canonical; root_canonical=$(cd "$root" && pwd)
  local target; target=$(readlink "$fake_home/.claude/skills/bmad-foo")
  assert_contains "in-repo: symlink points at canonical source" "$target" "$root_canonical/claude/skills/bmad-foo"

  rm -rf "$root" "$fake_home"
}

test_workspace_root_as_project() {
  # Workspace root itself has _bmad/ → install.sh records a "." entry.
  local ws fake_home
  ws=$(mktempdir); fake_home=$(mktempdir)
  mkdir -p "$ws/_bmad/bmm"
  HOME="$fake_home" bash "$INSTALL" --skills-only "$ws" >/dev/null 2>&1
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  rm -rf "$ws" "$fake_home"

  assert_contains "root project listed as '.:'"       "$content" "  .:"
  assert_contains "root project path is '.'"          "$content" "    path: ."
  assert_contains "default_project = '.' for solo root" "$content" "default_project: '.'"
}

test_multi_project_workspace() {
  local ws fake_home
  ws=$(mktempdir); fake_home=$(mktempdir)
  mkdir -p "$ws/proj-alpha/_bmad/bmm" \
           "$ws/proj-beta/_bmad/cis"  \
           "$ws/proj-gamma/_bmad/core"
  HOME="$fake_home" bash "$INSTALL" --skills-only "$ws" >/dev/null 2>&1
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  rm -rf "$ws" "$fake_home"

  assert_contains "alpha listed"  "$content" "proj-alpha:"
  assert_contains "beta listed"   "$content" "proj-beta:"
  assert_contains "gamma listed"  "$content" "proj-gamma:"
  # With multiple projects, default_project is left empty.
  assert_contains "default empty under multi-project" "$content" "default_project: ''"
}

test_git_repo_without_bmad_appears_commented() {
  local ws fake_home
  ws=$(mktempdir); fake_home=$(mktempdir)
  ( cd "$ws" && git init -q legacy-app && cd legacy-app && \
      git config user.email t@t.t && git config user.name t )
  HOME="$fake_home" bash "$INSTALL" --skills-only "$ws" >/dev/null 2>&1
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  rm -rf "$ws" "$fake_home"

  # The git repo with no _bmad/ should appear as commented stub guiding the
  # user to run bmad init in it. Lines look like:
  #   # legacy-app:
  #   #   path: legacy-app
  assert_contains "commented project header"   "$content" "# legacy-app:"
  assert_contains "commented project hint"     "$content" "uncomment after running bmad init"
}

test_empty_workspace_yields_no_projects() {
  local ws fake_home
  ws=$(mktempdir); fake_home=$(mktempdir)
  HOME="$fake_home" bash "$INSTALL" --skills-only "$ws" >/dev/null 2>&1
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  rm -rf "$ws" "$fake_home"
  assert_contains "default_project empty"  "$content" "default_project: ''"
  # No project lines (only the `projects:` key)
  local proj_lines; proj_lines=$(printf '%s\n' "$content" | awk '/^projects:/{flag=1; next} flag' | grep -cE '^  [a-zA-Z]' || true)
  assert_eq "no concrete project entries" "$proj_lines" "0"
}

test_mixed_workspace_combines_all_shapes() {
  # All four shapes in one workspace:
  #   proj-alpha/   has _bmad/        (real project, listed)
  #   proj-beta/    has _bmad/        (real project, listed)
  #   legacy-app/   .git but no _bmad (git repo, commented stub)
  #   notes/        plain dir         (ignored)
  local ws fake_home
  ws=$(mktempdir); fake_home=$(mktempdir)
  mkdir -p "$ws/proj-alpha/_bmad/bmm" \
           "$ws/proj-beta/_bmad/cis"  \
           "$ws/notes"
  ( cd "$ws" && git init -q legacy-app && cd legacy-app && \
      git config user.email t@t.t && git config user.name t )

  HOME="$fake_home" bash "$INSTALL" --skills-only "$ws" >/dev/null 2>&1
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  rm -rf "$ws" "$fake_home"

  assert_contains "alpha listed (uncommented)"           "$content" "  proj-alpha:"
  assert_contains "beta listed (uncommented)"            "$content" "  proj-beta:"
  assert_contains "legacy-app appears commented"         "$content" "# legacy-app:"
  assert_not_contains "notes/ does not appear"           "$content" "notes:"
  assert_contains "default empty under multi-project"    "$content" "default_project: ''"
}

test_root_and_children_both_listed() {
  # Root itself is a BMAD project AND there are also child projects.
  # workspace.yaml should include both `.:` and the child entries.
  local ws fake_home
  ws=$(mktempdir); fake_home=$(mktempdir)
  mkdir -p "$ws/_bmad/bmm" "$ws/sub-a/_bmad/bmm" "$ws/sub-b/_bmad/cis"
  HOME="$fake_home" bash "$INSTALL" --skills-only "$ws" >/dev/null 2>&1
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  rm -rf "$ws" "$fake_home"

  assert_contains "root listed as '.:'"        "$content" "  .:"
  assert_contains "sub-a listed"               "$content" "  sub-a:"
  assert_contains "sub-b listed"               "$content" "  sub-b:"
  # Root + 2 children = 3 projects → no auto default
  assert_contains "no auto-default with 3 projects" "$content" "default_project: ''"
}

run_test test_in_repo_install_uses_symlinks
run_test test_workspace_root_as_project
run_test test_multi_project_workspace
run_test test_git_repo_without_bmad_appears_commented
run_test test_empty_workspace_yields_no_projects
run_test test_mixed_workspace_combines_all_shapes
run_test test_root_and_children_both_listed
finish
