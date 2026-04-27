#!/usr/bin/env bash
# install.sh copies a fixed list of templates. Each one must exist in
# templates/, otherwise installs silently skip files that should ship.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

EXPECTED_TEMPLATES=(
  "bmad-workspace-resolution.md"
  "bmad-team-customization.md"
  "dontbmad-graph-first.md"
  "dontbmad-caveman-activate.md"
  "team.yaml"
)

test_referenced_templates_exist() {
  local f
  for f in "${EXPECTED_TEMPLATES[@]}"; do
    assert_file "templates/$f exists" "$REPO_ROOT/templates/$f"
  done
}

# Shipped scripts must remain executable
test_scripts_executable() {
  assert_executable "scripts/install.sh executable"             "$REPO_ROOT/scripts/install.sh"
  assert_executable "scripts/adoption-dashboard.sh executable"  "$REPO_ROOT/scripts/adoption-dashboard.sh"
  assert_executable "hooks/prepare-commit-msg executable"       "$REPO_ROOT/hooks/prepare-commit-msg"
}

run_test test_referenced_templates_exist
run_test test_scripts_executable
finish
