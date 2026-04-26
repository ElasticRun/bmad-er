#!/usr/bin/env bash
# When a SKILL.md has YAML frontmatter, it must declare a non-empty `name`
# and `description`, and `name` must match the directory. SKILL.md without
# frontmatter is allowed (Claude Code falls back to the H1 title); those
# files are listed as warnings, not failures.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

# Extracts the value for a given top-level YAML key inside the leading
# `---` ... `---` frontmatter block of $1. Strips wrapping quotes.
fm_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { in_fm = 0; seen_open = 0 }
    /^---[[:space:]]*$/ {
      if (!seen_open) { seen_open = 1; in_fm = 1; next }
      else            { exit }
    }
    in_fm {
      if (match($0, "^" k ":[[:space:]]*")) {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]+$/, "", v)
        # strip a single pair of wrapping single or double quotes
        if (v ~ /^".*"$/) { v = substr(v, 2, length(v) - 2) }
        else if (v ~ /^'\''.*'\''$/) { v = substr(v, 2, length(v) - 2) }
        print v
        exit
      }
    }
  ' "$file"
}

has_frontmatter() {
  # True iff the file's first non-empty line is `---`.
  awk 'NF { if ($0 ~ /^---[[:space:]]*$/) exit 0; else exit 1 }' "$1"
}

WARNINGS=()

check_skill_tree() {
  local tree="$1"
  local d skill_name fm_name fm_desc
  for d in "$REPO_ROOT/$tree"/*/; do
    [ -d "$d" ] || continue
    skill_name="$(basename "$d")"
    [[ "$skill_name" == bmad-* || "$skill_name" == dontbmad-* ]] || continue

    if [ ! -f "$d/SKILL.md" ]; then
      _fail "$tree/$skill_name has SKILL.md" "missing $d/SKILL.md"
      continue
    fi

    if ! has_frontmatter "$d/SKILL.md"; then
      WARNINGS+=("$tree/$skill_name: SKILL.md has no YAML frontmatter (Claude Code falls back to H1)")
      continue
    fi

    fm_name="$(fm_value "$d/SKILL.md" name)"
    fm_desc="$(fm_value "$d/SKILL.md" description)"

    assert_ne "$tree/$skill_name: frontmatter has name"        "$fm_name" ""
    assert_ne "$tree/$skill_name: frontmatter has description" "$fm_desc" ""
    assert_eq "$tree/$skill_name: name matches directory"      "$fm_name" "$skill_name"
  done
}

print_warnings() {
  [ "${#WARNINGS[@]}" -gt 0 ] || return 0
  printf "\n  notes (not failures):\n"
  local w
  for w in "${WARNINGS[@]}"; do
    printf "    - %s\n" "$w"
  done
}

test_claude_skills() { check_skill_tree "claude/skills"; }
test_cursor_skills() { check_skill_tree "cursor/skills"; }

run_test test_claude_skills
run_test test_cursor_skills
print_warnings
finish
