# Tests

Plain-bash test suite for the shell scripts and skill structure in this repo.
No external dependencies — every test runs with the system `bash`, `git`,
and `awk`.

## Running

```bash
# Whole suite
bash tests/run.sh

# One folder or file (substring match against the test path)
bash tests/run.sh e2e
bash tests/run.sh prepare-commit-msg
```

Exit code is non-zero if any file fails.

## Layout

```
tests/
  lib/assert.sh                       # tiny assertion helpers
  run.sh                              # discovers and runs all *.test.sh

  e2e/                                # exercise the scripts end-to-end
    install.test.sh                   # scripts/install.sh
    install-layouts.test.sh           # scripts/install.sh workspace shapes
    adoption-dashboard.test.sh        # scripts/adoption-dashboard.sh
    prepare-commit-msg.test.sh        # hooks/prepare-commit-msg

  structural/                         # repo-shape invariants
    skill-frontmatter.test.sh         # SKILL.md frontmatter is valid + matches dir
    skill-mirror.test.sh              # claude/ and cursor/ skill sets agree
    skill-workflow-refs.test.sh       # workflow.md exists where SKILL.md says it does
    install-templates.test.sh         # templates/ files referenced by install.sh exist
```

## How tests stay isolated

- `e2e/install.test.sh` and `e2e/install-layouts.test.sh` run `install.sh`
  against a fresh `mktemp -d` workspace and always redirect `HOME` to a
  tmp dir. Skills now publish user-level (`~/.claude/skills`,
  `~/.cursor/skills`), so this redirect protects your real home from
  being touched.
- `e2e/adoption-dashboard.test.sh` builds throwaway git repos with
  hand-crafted commit trailers and calls the dashboard via `--repo` /
  `--workspace` against those.
- `e2e/prepare-commit-msg.test.sh` invokes the hook with a tmp message
  file inside a tmp git repo.

## Writing a new test

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

test_something() {
  local out; out=$(... 2>&1)
  assert_contains "behaves correctly" "$out" "expected substring"
}

run_test test_something
finish
```

Helpers available in `lib/assert.sh`: `assert_eq`, `assert_ne`,
`assert_contains`, `assert_not_contains`, `assert_file`, `assert_dir`,
`assert_symlink`, `assert_executable`, `assert_zero`, `assert_nonzero`,
plus `mktempdir`.
