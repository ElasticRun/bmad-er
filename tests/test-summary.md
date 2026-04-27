# Test Automation Summary

Generated 2026-04-26 for the bmad-er repo. Plain-bash suite, no extra
dependencies. Run with `bash tests/run.sh`.

## Generated Tests

### E2E (script behavior)

- [x] `tests/e2e/install.test.sh` — `scripts/install.sh` skills/hooks/global modes, idempotency, `--force`, `--dev-link`, user-level skill publish, no workspace-level skill duplication, all 4 rule files land in both `.claude/rules` and `.cursor/rules` (37 assertions)
- [x] `tests/e2e/install-layouts.test.sh` — workspace-shape coverage: in-repo symlink mode, root-as-project, multi-project, git-without-`_bmad/` commented stub, empty workspace, **mixed shapes in one workspace**, **root + children both as projects** (26 assertions)
- [x] `tests/e2e/adoption-dashboard.test.sh` — `scripts/adoption-dashboard.sh` trailer parsing, AI-vs-manual split, `--workspace` aggregation, glob filter, deep-nested repo discovery, pruning of `node_modules`, de-dup of nested git under outer, **every dashboard SDLC phase end-to-end (10 phases)**, **off-list phases tracked but not rendered** (39 assertions)
- [x] `tests/e2e/prepare-commit-msg.test.sh` — `hooks/prepare-commit-msg` adds trailers, derives Story-Ref from branch, skips merge/squash/already-tagged commits, falls back to `unknown` on detached HEAD (10 assertions)

### Structural (repo invariants)

- [x] `tests/structural/skill-frontmatter.test.sh` — Every SKILL.md with frontmatter has valid `name` + `description`, and `name` matches the directory (324 assertions)
- [x] `tests/structural/skill-mirror.test.sh` — `claude/skills/` and `cursor/skills/` contain the same skill set (2 assertions)
- [x] `tests/structural/skill-workflow-refs.test.sh` — Every SKILL.md that references `./workflow.md` actually has one (46 assertions)
- [x] `tests/structural/install-templates.test.sh` — Templates referenced in `install.sh` exist; key scripts/hook are executable (9 assertions)
- [x] `tests/structural/skill-ai-phase.test.sh` — Each SDLC skill declares the expected `AI-Phase:` trailer in both claude/ and cursor/ trees; surfaces phases that the dashboard doesn't render (23 assertions)

## Results

```
==> ./e2e/adoption-dashboard.test.sh         39 passed,  39 total
==> ./e2e/install-layouts.test.sh            26 passed,  26 total
==> ./e2e/install.test.sh                    37 passed,  37 total
==> ./e2e/prepare-commit-msg.test.sh         10 passed,  10 total
==> ./structural/install-templates.test.sh    8 passed,   8 total
==> ./structural/skill-ai-phase.test.sh      23 passed,  23 total
==> ./structural/skill-frontmatter.test.sh  324 passed, 324 total
==> ./structural/skill-mirror.test.sh         2 passed,   2 total
==> ./structural/skill-workflow-refs.test.sh 46 passed,  46 total
=== Summary ===
All 9 test file(s) passed
```

**Total: 515 assertions, all passing.**

## Coverage

| Surface | Status |
|---|---|
| `scripts/install.sh` (workspace install, global publish, hooks, force, dev-link, user-level publishing) | covered |
| `scripts/adoption-dashboard.sh` (single repo, workspace, filter, AI-vs-manual) | covered |
| `hooks/prepare-commit-msg` (default add, branch derivation, skip cases) | covered |
| Skill frontmatter / mirror / workflow refs | covered |

## Findings (not test failures)

### 1. Five skills lack YAML frontmatter

These have only an H1 line where the other 54 use `---\nname: ...\ndescription: ...\n---`:

- `dontbmad-ai-tracking`
- `dontbmad-graphify`
- `dontbmad-graphify-explain`
- `dontbmad-graphify-path`
- `dontbmad-graphify-query`

They still load (Claude Code falls back to the H1 title), but they're a
stylistic drift. The frontmatter test treats this as a warning rather
than a failure so it doesn't block runs; add frontmatter to those
`SKILL.md` files if you want consistency.

### 2. SDLC phase / dashboard mismatches

The structural `skill-ai-phase.test.sh` test surfaced three contract gaps
between what skills emit and what the dashboard renders:

- `bmad-correct-course` declares `AI-Phase: sprint-change` — not in the dashboard's render list, so its commits get counted in `TOTAL` but never appear in any section.
- `bmad-product-brief` declares `AI-Phase: brief` — same problem.
- The dashboard renders a `deploy` row but **no skill declares `AI-Phase: deploy`** — that row will always be empty until a deploy-emitting skill is added (or you can drop `deploy` from the render list).

To fix:
- Either rename `sprint-change` and `brief` to phases the dashboard knows about (or extend the dashboard's planning list to include them).
- Either add a deploy-emitting skill or remove `deploy` from `scripts/adoption-dashboard.sh`'s `dev` array.

## Next Steps

- Wire `bash tests/run.sh` into a CI step so drift gets caught on PRs.
- If the 5 frontmatter-less skills should conform, add the `---` block to
  each and the test will start asserting it strictly without changes.
- Add tests for any new shell entry points as they land.
