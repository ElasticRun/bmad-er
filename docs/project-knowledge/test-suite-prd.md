# PRD: Comprehensive Test Suite for dont-b-mad

**Author:** Sachin Mane
**Date:** 2026-04-26
**Status:** Draft
**Scope:** Introduce a test suite that covers the bash surface (install.sh, prepare-commit-msg hook, adoption-dashboard.sh, check-skill-symlinks.sh) and adds static validation for skills (frontmatter, mirror parity, link integrity). Wire it into CI so every PR is gated.

This PRD is the primary deliverable of the `/bmad-document-project` run on 2026-04-26. It is intentionally written so an agent (or human) can implement the full suite from this document plus the supporting docs in `docs/project-knowledge/`.

---

## 1. Problem & motivation

`dont-b-mad` exists to do exactly two things that upstream BMAD doesn't:

1. **Track AI adoption via git commit trailers** — every commit in every repo gets `AI-Phase`, `AI-Tool`, `Story-Ref` trailers, then a dashboard rolls them up. This is the load-bearing feature; if trailers don't reliably attach, the entire value proposition breaks.
2. **Layer fork-specific enhancements on top of BMAD** — graphify integration (codebase knowledge graph) and caveman mode (token-cheap output) are the headline additions. They need to install correctly, activate by default, and not be silently dropped by upstream BMAD updates.

The test suite focuses **primarily on these two surfaces**, in this order of priority:

### Primary: trailer pipeline integrity across project topologies

The trailer pipeline (hook → commit → dashboard read) must work identically regardless of the project's git topology:

| Topology | Why it matters |
|---|---|
| **Flat** — single git repo, no nesting | The simplest case; should always work |
| **Nested** — workspace with N child repos, hooks installed per-repo | The recommended layout in README; most common in real teams |
| **Monorepo** — single `.git` at root, multiple sub-projects under it | Common pattern for platform teams |
| **Worktree** — `.git` is a file, not a directory | Devs who use `git worktree add` for feature branches |
| **Submodules** — nested `.git` dirs inside a parent repo | Vendored deps; dashboard must not double-count |
| **Bare/empty repo** — no commits yet | First commit must still get trailers |
| **Detached HEAD** — no branch | `Story-Ref: unknown` fallback |
| **Branch with multiple slashes** — `feature/team-x/wave-planning` | Story-Ref derivation must be predictable |

Today, none of these scenarios are validated. A regression in `prepare-commit-msg` or `adoption-dashboard.sh` would corrupt or under-count adoption metrics across all of them.

### Secondary: fork enhancement integrity (graphify + caveman)

Both enhancements ship as a combination of skills + rule files + installer behavior. They're easy to break silently when:
- Upstream BMAD changes the skill installation pattern.
- A merge from upstream drops `templates/dontbmad-*.md` rule files.
- A skill rename in `claude/skills/` doesn't get mirrored to `cursor/skills/`.
- The installer's glob (`bmad-*` and `dontbmad-*`) misses a new prefix variant.

These regressions wouldn't surface until a user reports "caveman stopped working" or "graphify isn't being suggested anymore."

### Tertiary: install.sh general surface, skill validation, shellcheck

Necessary but not the headline. Covered in later sections.

**Today, none of this is tested.** The only test file in the repo is `bmad-distillator/scripts/tests/test_analyze_sources.py`, scoped to one skill's Python helper.

## 2. Goals

| # | Goal | Measure |
|---|---|---|
| **G1** | **Trailer pipeline is verified end-to-end across every project topology** | At least one bats test per topology in §FR-Trailer; each runs install → commit → dashboard read and asserts the expected trailers appear |
| **G2** | **Fork enhancements (graphify + caveman) install correctly and survive upstream merges** | Dedicated test files in `tests/enhancements/` that assert skill presence, rule activation, and installer wiring |
| G3 | Hook unit tests cover every branch of `prepare-commit-msg` | All 8 hook-decision branches in §FR-Hook have a bats `@test` |
| G4 | Dashboard correctness across topologies | Dashboard tests in §FR-Dashboard cover single repo, workspace mode, submodule dedupe, filter glob, edge cases |
| G5 | Static skill validation runs on every PR | `scripts/lint-skills.sh` validates frontmatter, mirror parity, link integrity for all 59 skills |
| G6 | CI gates every PR | `.github/workflows/ci.yml` runs the suite; PRs cannot merge red |
| G7 | Suite runs in under 90 seconds locally | Measured by `time bash scripts/test.sh` |
| G8 | Existing pytest tests for `bmad-distillator` keep running from the same CI run | Single GitHub Actions job invokes both bats and pytest |

## 3. Non-goals

- **End-to-end tests of agent workflows** (i.e., booting Claude Code and running a skill). Out of scope: too slow, too flaky, requires API access and a live model.
- **Cross-shell portability tests** (zsh, fish). Bash is the contract.
- **Windows support.** All tests target macOS and Linux only.
- **Performance benchmarks.** Not a goal until functionality is locked.

## 4. User journeys

### J1: Contributor opens a PR
1. Edits `scripts/install.sh` to add a new flag.
2. Pushes the branch.
3. CI runs the test suite within 90 seconds.
4. If a test fails, the PR is blocked with a clear failure message pointing at the assertion.
5. If all tests pass, the PR is mergeable.

### J2: Developer iterates locally
1. Edits `hooks/prepare-commit-msg`.
2. Runs `bash scripts/test.sh hook` (or equivalent scoped invocation).
3. Sees pass/fail in <10 seconds for that scope.
4. Iterates without round-tripping CI.

### J3: Reviewer audits a regression
1. A bug is reported: dashboard shows wrong adoption rate when a commit has multiple Story-Ref trailers.
2. Reviewer adds a regression test in `tests/dashboard/test_multiple_trailers.bats` first.
3. Pushes; CI confirms the test fails on `main`.
4. Reviewer fixes `adoption-dashboard.sh`; CI confirms green.
5. PR merges with both the fix and the regression test.

## 5. Functional requirements

### FR1: Test framework

- **Bash tests:** [bats-core](https://github.com/bats-core/bats-core) is the framework of record. Reasons:
  - De-facto standard for bash testing.
  - TAP output works with most CI systems.
  - Already used by major projects (e.g., docker, pulumi, supercronic).
  - Reasonably hermetic: each `@test` runs in its own subshell.
- **Python tests:** keep `pytest` (already present for `bmad-distillator`).
- **Shell linting:** `shellcheck` for static analysis on every `.sh` and `.bash` file.
- **Static skill validation:** a custom script under `scripts/lint-skills.sh` that walks `claude/skills/` and `cursor/skills/`, parses YAML frontmatter, and verifies references.

### FR2: Test directory layout

The directory structure mirrors the goal hierarchy: trailer-pipeline tests come first, fork-enhancement tests second, then unit tests, then static validation.

```
bmad-er/
├── tests/
│   ├── README.md                          # How to run tests locally
│   ├── helpers/                           # Shared bats helpers
│   │   ├── setup.bash                     # Common setup: mktemp workspace, isolated HOME, fixed git author
│   │   ├── topology_fixtures.bash         # Builders: flat_repo, nested_workspace, monorepo, worktree, submodule_setup, etc.
│   │   ├── trailer_helpers.bash           # commit_with_trailers, assert_trailer_equals, count_phase_in_log
│   │   └── assertions.bash                # Custom asserts: assert_file_exists, assert_executable, assert_symlink_to
│   │
│   ├── trailer_pipeline/                  # 🎯 PRIMARY — end-to-end trailer integrity per topology
│   │   ├── test_flat_repo.bats            # FR-Trailer.1
│   │   ├── test_nested_workspace.bats     # FR-Trailer.2
│   │   ├── test_monorepo.bats             # FR-Trailer.3
│   │   ├── test_worktree.bats             # FR-Trailer.4
│   │   ├── test_submodules.bats           # FR-Trailer.5
│   │   ├── test_empty_repo.bats           # FR-Trailer.6
│   │   ├── test_detached_head.bats        # FR-Trailer.7
│   │   └── test_branch_naming.bats        # FR-Trailer.8
│   │
│   ├── enhancements/                      # 🎯 SECONDARY — fork-specific additions
│   │   ├── test_graphify_install.bats     # FR-Graphify.1–4
│   │   ├── test_graphify_skills.bats      # FR-Graphify.5–7
│   │   ├── test_caveman_install.bats      # FR-Caveman.1–3
│   │   └── test_caveman_skill.bats        # FR-Caveman.4–6
│   │
│   ├── hook/                              # Unit tests for prepare-commit-msg
│   │   ├── test_skip_merge_squash.bats    # FR-Hook.1
│   │   ├── test_existing_trailer.bats     # FR-Hook.2
│   │   ├── test_branch_parsing.bats       # FR-Hook.3
│   │   └── test_trailer_format.bats       # FR-Hook.4
│   │
│   ├── dashboard/                         # Unit tests for adoption-dashboard.sh
│   │   ├── test_no_commits.bats           # FR-Dashboard.1
│   │   ├── test_aggregation.bats          # FR-Dashboard.2
│   │   ├── test_targets_table.bats        # FR-Dashboard.3
│   │   ├── test_filter_glob.bats          # FR-Dashboard.4
│   │   ├── test_workspace_mode.bats       # FR-Dashboard.5
│   │   ├── test_submodule_dedupe.bats     # FR-Dashboard.6
│   │   └── test_edge_cases.bats           # FR-Dashboard.7
│   │
│   ├── install/                           # Tertiary — install.sh general surface
│   │   ├── test_args_and_modes.bats       # FR-Install.1
│   │   ├── test_skills_and_rules.bats     # FR-Install.2
│   │   ├── test_workspace_yaml.bats       # FR-Install.3
│   │   ├── test_global_mode.bats          # FR-Install.4
│   │   ├── test_force_and_idempotency.bats # FR-Install.5
│   │   └── test_in_repo_symlinks.bats     # FR-Install.6
│   │
│   ├── check_symlinks/
│   │   └── test_drift_detection.bats      # FR-Check
│   │
│   └── lint_skills/
│       └── test_skill_validators.bats     # FR-Lint
│
├── scripts/
│   ├── test.sh                            # Local test runner
│   └── lint-skills.sh                     # Static skill validation
│
└── .github/
    └── workflows/
        └── ci.yml                         # GitHub Actions config
```

### FR3: Local test runner — `scripts/test.sh`

Behavior:

```
bash scripts/test.sh                  # Runs everything
bash scripts/test.sh trailer          # Runs only trailer_pipeline/ tests (the headline suite)
bash scripts/test.sh enhancements     # Runs only enhancements/ tests (graphify + caveman)
bash scripts/test.sh hook             # Runs only hook/ unit tests
bash scripts/test.sh dashboard        # Runs only dashboard/ unit tests
bash scripts/test.sh install          # Runs only install/ tests
bash scripts/test.sh lint             # Runs only lint-skills.sh
bash scripts/test.sh shellcheck       # Runs only shellcheck on all *.sh
bash scripts/test.sh python           # Runs only pytest under bmad-distillator
bash scripts/test.sh --quick          # Skips slow integration tests (the workspace creation ones)
```

Exit code: 0 if all green, non-zero if any failed. Prints one-line summary at end (e.g. `42 passed, 0 failed, 1 skipped in 47s`).

### FR-Trailer: end-to-end trailer pipeline across project topologies (PRIMARY)

This is the headline test suite. Each test exercises the full pipeline:

1. Build a fresh project of the specified topology (using helpers from `topology_fixtures.bash`).
2. Run `install.sh` against it.
3. Make commits using a real `git commit` (so the hook fires for real).
4. Run `adoption-dashboard.sh` against the result.
5. Assert that trailers are present, correctly formatted, and counted in the dashboard output.

These tests use **real git operations** (no mocks) inside `mktemp -d` directories. `HOME` is overridden so the user's real `~/.claude` is never touched. `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, and `GIT_COMMITTER_*` are pinned so commits are deterministic.

#### FR-Trailer.1: Flat repo

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.1.a | `git init <tmp>`; cd in; `install.sh .`; commit "feat: x" on branch `main` | Commit message contains all three trailers; `Story-Ref: main` |
| FR-Trailer.1.b | Same setup; commit on branch `feature/auth-1-2` | `Story-Ref: auth-1-2` |
| FR-Trailer.1.c | Same setup; run `adoption-dashboard.sh` after 3 commits (1 manual + 2 with crafted AI-Tool) | Dashboard shows `code 66%  [2/3]` (or 67% — pin actual rounding) |
| FR-Trailer.1.d | Verify the trailers parse cleanly with `git interpret-trailers --parse` | All three keys are recognized as valid trailers (no malformed format) |

#### FR-Trailer.2: Nested workspace (the README-recommended layout)

```
<tmp>/
├── repoA/.git/
├── repoB/.git/
└── repoC/.git/
```

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.2.a | Build above structure; run `install.sh <tmp>` | All 3 repos receive `prepare-commit-msg` |
| FR-Trailer.2.b | Commit in each repo on its own branch | Each commit has trailers with the correct per-repo `Story-Ref` derived from that repo's branch |
| FR-Trailer.2.c | Run `adoption-dashboard.sh --workspace <tmp>` | Output shows `Repos scanned: 3`; total reflects sum across all 3 |
| FR-Trailer.2.d | Run dashboard from inside `repoA` (no `--workspace`) | Output shows only `repoA`'s commits |
| FR-Trailer.2.e | One repo (`repoB`) has zero commits | Dashboard handles gracefully, shows scanned=3 with `repoB` contributing 0 |

#### FR-Trailer.3: Monorepo (single `.git` at root, deep tree)

```
<tmp>/.git/
<tmp>/services/api/...
<tmp>/services/web/...
<tmp>/packages/shared/...
```

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.3.a | `install.sh <tmp>` against monorepo | Single `prepare-commit-msg` installed at `<tmp>/.git/hooks/` |
| FR-Trailer.3.b | Commit from `<tmp>/services/api/` (subdir) | Hook fires; trailers attached |
| FR-Trailer.3.c | Commit from `<tmp>/packages/shared/` | Hook fires; trailers attached |
| FR-Trailer.3.d | All commits land in one git log; dashboard rolls up across the whole monorepo | `--workspace <tmp>` and no-arg invocation produce same result |
| FR-Trailer.3.e | Workspace mode does NOT report monorepo as multiple repos (no double-counting from finding nested dirs) | `Repos scanned: 1` |

#### FR-Trailer.4: Worktree (`.git` is a file, not a directory)

A worktree has a primary repo at `/path/main/.git/` (directory) and additional checkouts at `/path/feature-x/.git` (file pointing back).

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.4.a | Build a primary repo + a worktree via `git worktree add <tmp>/feature-x branch-x` | Worktree's `.git` is a file with `gitdir:` pointer |
| FR-Trailer.4.b | `install.sh <tmp>/main` and `install.sh <tmp>/feature-x` | Hook installs to the resolved git dir for both (uses `git rev-parse --git-dir`) |
| FR-Trailer.4.c | Commit from worktree | Hook fires; trailers attached |
| FR-Trailer.4.d | Dashboard from primary repo with `--workspace` | Worktree commits are NOT double-counted (primary and worktree share the same object DB) |

#### FR-Trailer.5: Submodules

```
<tmp>/parent/.git/
<tmp>/parent/vendor/sub/.git/   ← submodule with its own commits
```

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.5.a | `install.sh <tmp>` | Both parent AND submodule get hooks (current behavior — confirm if intentional, document in Q-section if not) |
| FR-Trailer.5.b | Commit in parent | Hook fires |
| FR-Trailer.5.c | Commit in submodule | Hook fires |
| FR-Trailer.5.d | `adoption-dashboard.sh --workspace <tmp>` | Submodule commits are NOT double-counted against the parent (the dashboard's `discover_repos` dedupe must work — see `architecture.md` §Component 3) |

#### FR-Trailer.6: Empty / first-commit repo

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.6.a | Fresh `git init`, install hook, immediately commit (first commit ever) | Trailers attached; commit succeeds |
| FR-Trailer.6.b | Same scenario but on default branch (`main` or `master` depending on git version) | `Story-Ref` matches the actual current branch name |
| FR-Trailer.6.c | Run dashboard against repo with only this one commit | Output reflects 1 commit |

#### FR-Trailer.7: Detached HEAD

| ID | Test | Expected behavior |
|---|---|---|
| FR-Trailer.7.a | Repo with commits, then `git checkout <sha>` to detach | `git branch --show-current` returns empty |
| FR-Trailer.7.b | Commit on detached HEAD (e.g. via `git commit --allow-empty`) | Hook fires; trailer is `Story-Ref: unknown` (the script's documented fallback) |

#### FR-Trailer.8: Branch naming variants

| ID | Branch | Expected `Story-Ref` |
|---|---|---|
| FR-Trailer.8.a | `main` | `main` |
| FR-Trailer.8.b | `feature/wave-planning-1-1` | `wave-planning-1-1` |
| FR-Trailer.8.c | `fix/team-x/some-bug` (multi-slash) | `some-bug` (current behavior; pin via test) |
| FR-Trailer.8.d | `release/2026-04` | `2026-04` |
| FR-Trailer.8.e | `hotfix/PROD-1234` | `PROD-1234` |
| FR-Trailer.8.f | Branch with spaces or special chars (e.g. `feat: foo`) | Document and pin behavior — git allows some unusual names |

---

### FR-Graphify: graphify integration tests (SECONDARY — fork enhancement)

Graphify is a knowledge-graph builder that the fork integrates via 4 skills (`dontbmad-graphify`, `dontbmad-graphify-query`, `dontbmad-graphify-path`, `dontbmad-graphify-explain`) and 1 rule (`templates/dontbmad-graph-first.md`). The integration is **fragile**: it can be silently broken by an upstream merge that changes how skills/rules install.

| ID | Test | Expected behavior |
|---|---|---|
| FR-Graphify.1 | `install.sh <tmp>` then assert all 4 graphify skill directories exist under `<tmp>/.claude/skills/` AND `<tmp>/.cursor/skills/` | Each has a `SKILL.md` |
| FR-Graphify.2 | Each graphify skill's `SKILL.md` parses as valid YAML frontmatter with required `name` and `description` keys | Parse with a small Python helper or `yq` |
| FR-Graphify.3 | After install, `<tmp>/.cursor/rules/dontbmad-graph-first.md` AND `<tmp>/.claude/rules/dontbmad-graph-first.md` both exist and equal `templates/dontbmad-graph-first.md` | Byte-identical |
| FR-Graphify.4 | `dontbmad-graph-first.md` content references `graphify-out/graph.json` (the runtime artifact) | grep substring match — guards against accidental edit that breaks the rule |
| FR-Graphify.5 | Each graphify skill's `workflow.md` (if present) does NOT contain absolute paths starting with `/Users/`, `/home/`, `C:\` | grep -rE; covered by FR-Lint but called out separately for tracking |
| FR-Graphify.6 | The `bmad-create-prd`, `bmad-document-project`, and `bmad-dev-story` skills do NOT reference graphify by absolute path; if they reference graphify at all, the path is workspace-relative | Manual review codified as a grep test |
| FR-Graphify.7 | Mirror parity: `claude/skills/dontbmad-graphify*` directory tree equals `cursor/skills/dontbmad-graphify*` (recursive `diff -r`) | Empty diff |

---

### FR-Caveman: caveman mode integration tests (SECONDARY — fork enhancement)

Caveman is the fork's headline output-compression feature. It integrates via:
- The skill `dontbmad-caveman` (rule-only — `SKILL.md` is the entire instruction set)
- The activation rule `templates/dontbmad-caveman-activate.md` (turns caveman on by default)
- An optional `--caveman` flag in `bmad-party-mode` (referenced in the README)
- A separate compression skill `dontbmad-compress-artifacts`

| ID | Test | Expected behavior |
|---|---|---|
| FR-Caveman.1 | `install.sh <tmp>` then assert `<tmp>/.cursor/rules/dontbmad-caveman-activate.md` AND `<tmp>/.claude/rules/dontbmad-caveman-activate.md` both exist | Byte-identical to source |
| FR-Caveman.2 | The activation rule contains the substring `caveman` (case-insensitive) | Cheap content sanity check |
| FR-Caveman.3 | `<tmp>/.claude/skills/dontbmad-caveman/SKILL.md` AND `<tmp>/.cursor/skills/dontbmad-caveman/SKILL.md` both exist after install | Each has YAML frontmatter |
| FR-Caveman.4 | The caveman `SKILL.md` declares `name: dontbmad-caveman` (matches dir name) | YAML key match |
| FR-Caveman.5 | `dontbmad-compress-artifacts` skill is also installed (sister enhancement) | Directory + SKILL.md present |
| FR-Caveman.6 | `bmad-party-mode/SKILL.md` or its workflow references `--caveman` flag (or, if removed, this test is updated to match the actual integration shape) | grep substring match |
| FR-Caveman.7 | Removing `<tmp>/.cursor/rules/dontbmad-caveman-activate.md` and re-running `install.sh <tmp>` re-installs it | Idempotency for rule files |
| FR-Caveman.8 | Mirror parity for all caveman/compression skills (recursive `diff -r`) | Empty diff |

---

### FR-Install: install.sh general surface (TERTIARY)

These cover behaviors not already exercised by the trailer pipeline and enhancement tests. The trailer tests above already prove the hook installation works in real topologies; this section covers the **other** install responsibilities.

| ID | Test | Expected behavior |
|---|---|---|
| FR-Install.1.a | `bash install.sh --help` | Exits 0, prints usage |
| FR-Install.1.b | `bash install.sh -h` | Same as `--help` |
| FR-Install.1.c | `bash install.sh <bad-flag>` | Argument is treated as TARGET (current behavior); document if intentional |
| FR-Install.2.a | `install.sh <tmp>` from outside repo | `<tmp>/.claude/skills/` and `<tmp>/.cursor/skills/` populated as **copies** (regular dirs); count matches `ls claude/skills/ \| wc -l` (do not hardcode) |
| FR-Install.2.b | All 4 rule files exist in both rules directories | Byte-identical to `templates/*.md` |
| FR-Install.2.c | `<tmp>/scripts/adoption-dashboard.sh` is copied and executable | `[ -x ]` and byte-identical to source |
| FR-Install.3.a | Empty workspace → `<tmp>/_bmad/workspace.yaml` exists; `default_project: ''`; no project entries | YAML parse |
| FR-Install.3.b | Workspace with `<tmp>/projectA/_bmad/bmm/` → `default_project: 'projectA'` | |
| FR-Install.3.c | Workspace with `<tmp>/projectA/_bmad/cis/` AND `<tmp>/projectB/_bmad/core/` → both listed; default empty | |
| FR-Install.3.d | Workspace with `<tmp>/projectC/.git/` (no `_bmad`) → commented-out entry for `projectC` | |
| FR-Install.3.e | Existing workspace.yaml without `--force` → preserved | |
| FR-Install.3.f | Existing workspace.yaml with `--force` → regenerated | |
| FR-Install.4.a | `install.sh --global` with `HOME=<tmp>` | `<tmp>/.claude/skills/`, `<tmp>/.cursor/skills/`, `<tmp>/.claude/commands/` populated |
| FR-Install.4.b | `<tmp>/.claude/commands/<name>.md` are symlinks to corresponding `SKILL.md` | `readlink` resolves |
| FR-Install.4.c | `--global --dev-link` produces symlinks to source repo | |
| FR-Install.4.d | Pre-existing broken symlink in `<tmp>/.claude/commands/` is cleaned up on install | |
| FR-Install.5.a | `--force` overwrites pre-existing team.yaml AND workspace.yaml | |
| FR-Install.5.b | Two consecutive `install.sh <tmp>` runs produce identical state | Deep `diff -r` is empty |
| FR-Install.6.a | `install.sh .` from inside source repo creates SYMLINKS (not copies) under `.claude/skills/` and `.cursor/skills/` | `readlink` resolves to `../../{claude,cursor}/skills/{name}` |
| FR-Install.6.b | After FR-Install.6.a, `check-skill-symlinks.sh` exits 0 | |
| FR-Install.7.a | `--skills-only` with a git-enabled `<tmp>` does NOT install hooks | `<tmp>/.git/hooks/prepare-commit-msg` absent |
| FR-Install.7.b | `--hooks-only` with a workspace containing repos does NOT install skills/rules | `<tmp>/.claude/skills/` absent |

### FR-Hook: prepare-commit-msg unit tests

These are **fast, mock-friendly unit tests** that complement FR-Trailer. They invoke the hook directly without going through `git commit`: `bash hooks/prepare-commit-msg <tmp_msg_file> <source>`. Branch detection is exercised by `cd`-ing into a fixture repo first.

The topology coverage lives in FR-Trailer; this section locks down the script's internal decision tree.

| ID | Test | Expected behavior |
|---|---|---|
| FR-Hook.1.a | `<source> = "merge"` | Hook exits 0, file unchanged |
| FR-Hook.1.b | `<source> = "squash"` | Hook exits 0, file unchanged |
| FR-Hook.1.c | `<source> = ""` (regular commit) | Hook appends 3 trailers |
| FR-Hook.1.d | `<source> = "message"` | Hook appends 3 trailers |
| FR-Hook.2 | Commit message file already contains `AI-Phase: prd` | Hook exits 0, file unchanged (no double-append) |
| FR-Hook.3.a | Branch `main` (single segment) | Trailer `Story-Ref: main` |
| FR-Hook.3.b | Branch `feature/x` (one slash) | Trailer `Story-Ref: x` |
| FR-Hook.3.c | Branch `fix/team-x/some-bug` (multi-slash) | Trailer `Story-Ref: some-bug` (current behavior — verify intent in Q-section) |
| FR-Hook.3.d | Detached HEAD | Trailer `Story-Ref: unknown` |
| FR-Hook.4.a | Trailer block has exact format: blank line then 3 trailers | Asserted via regex match |
| FR-Hook.4.b | Existing message ends without trailing newline | Trailer block is preceded by a blank line; result parses via `git interpret-trailers --parse` |
| FR-Hook.4.c | Empty commit-msg file | Hook produces a file with only the 3 trailers — verify this is acceptable for `git commit` (or document and pin "abort" behavior) |

### FR-Dashboard: adoption-dashboard.sh unit tests

These tests use a **synthetic git history** — commits crafted with explicit trailer values via `git commit -m "msg" -m "AI-Phase: prd"`-style blocks. They do not exercise the hook; they exercise the dashboard's read/parse/aggregate logic.

Topology coverage (workspace, monorepo, submodules) is in FR-Trailer; this section pins arithmetic and edge cases.

| ID | Test | Expected behavior |
|---|---|---|
| FR-Dashboard.1.a | Repo with 0 commits | Exits 0, prints "No commits with AI trailers found." |
| FR-Dashboard.1.b | Repo with commits but no `AI-Phase:` trailers | Same as FR-Dashboard.1.a |
| FR-Dashboard.2.a | 2 prd commits (1 manual, 1 AI), 4 code commits (3 AI, 1 manual) | Output shows `prd 50% [1/2]`, `code 75% [3/4]` |
| FR-Dashboard.2.b | `TOTAL: 6 tracked commits` line matches | Exact substring |
| FR-Dashboard.3 | Targets row matches hard-coded values (90% prd, 80% code, 95% review, 85% test, 90% architecture/ux-design/epics/sprint-plan/story, 80% deploy) | Exact substring match per phase |
| FR-Dashboard.4.a | Filter `"1-*"` over commits with `Story-Ref` `1-1-foo, 1-2-bar, 2-1-baz` | Only first two counted |
| FR-Dashboard.4.b | Filter `"*"` | All commits counted (degenerate but valid) |
| FR-Dashboard.4.c | Filter `"unknown"` (literal) | Only commits with `Story-Ref` exactly `unknown` |
| FR-Dashboard.4.d | Filter that contains regex special chars (e.g. `"1.2"`) | Treated as glob, NOT regex (current behavior — `glob_match` escapes) |
| FR-Dashboard.5.a | `--workspace <tmp>` with 3 repos | Output shows `Repos scanned: 3` |
| FR-Dashboard.5.b | `--workspace <tmp>` with no repos | Stderr says "No git repositories found" |
| FR-Dashboard.6.a | `--workspace` over a tree with a submodule | Submodule commits NOT double-counted (dedupe in `discover_repos`) |
| FR-Dashboard.6.b | `--workspace` over a tree with `node_modules`, `.venv`, `vendor` containing fake `.git` dirs | Pruned, NOT scanned |
| FR-Dashboard.7.a | Commit with `AI-Tool:` empty | Counted toward phase total, NOT toward AI |
| FR-Dashboard.7.b | Commit with `AI-Tool: manual` | Counted toward phase total, NOT toward AI |
| FR-Dashboard.7.c | Commit with `AI-Tool: cursor/claude-sonnet-4-20250514` | Counted toward both |
| FR-Dashboard.7.d | Commit with multiple `AI-Phase:` lines (malformed) | Pin actual behavior — likely takes last; test asserts it |
| FR-Dashboard.7.e | `--repo <path>` | Aggregates only that repo regardless of CWD |

### FR-Check: check-skill-symlinks.sh test cases

| ID | Test | Expected behavior |
|---|---|---|
| FR-Check.1 | Clean install (after `install.sh .`) | Exits 0, prints "OK: skill mirrors are clean symlinks" |
| FR-Check.2 | One skill mirror missing | Exits 1, prints `MISSING: ...` |
| FR-Check.3 | One skill mirror is a regular dir, not symlink | Exits 1, prints `NOT-A-SYMLINK: ...` |
| FR-Check.4 | One symlink target removed (broken symlink) | Exits 1, prints `BROKEN-SYMLINK: ...` |
| FR-Check.5 | A broken symlink in `.claude/commands/` | Exits 1, prints `BROKEN-SYMLINK: ...` |

### FR-Lint: static skill validation — `scripts/lint-skills.sh`

A new script (introduced as part of this work) that asserts:

| ID | Rule | Implementation hint |
|---|---|---|
| FR-Lint.1 | Every directory under `claude/skills/` and `cursor/skills/` matching `bmad-*` or `dontbmad-*` has a `SKILL.md` | shell glob + `[ -f ]` |
| FR-Lint.2 | Every `SKILL.md` has YAML frontmatter with `name` and `description` keys | head + grep, or a small Python helper |
| FR-Lint.3 | The `name` field matches the directory name | string compare |
| FR-Lint.4 | No skill file contains an absolute path starting with `/Users/`, `/home/`, or `C:\` | grep -rE |
| FR-Lint.5 | Every `Read fully and follow: <relative-path>` reference in `workflow.md` resolves to an existing file relative to the workflow file | grep + path resolution loop |
| FR-Lint.6 | `claude/skills/` and `cursor/skills/` have identical directory listings | `diff <(ls claude/skills/) <(ls cursor/skills/)` returns no output |
| FR-Lint.7 | For each shared skill, `claude/skills/<name>` and `cursor/skills/<name>` produce identical content | recursive `diff -r` (acceptable to defer to a separate slow test job if too slow) |
| FR-Lint.8 | All `dontbmad-*` skills are present in both `claude/skills/` and `cursor/skills/` (fork-enhancement parity) | Explicit allowlist check |

Exit code: 0 if clean, 1 if any rule fails. Prints which file/rule failed, never just a generic error.

### FR-Shellcheck: shellcheck

Run `shellcheck` on:
- `scripts/install.sh`
- `scripts/adoption-dashboard.sh`
- `scripts/check-skill-symlinks.sh`
- `scripts/test.sh` (new)
- `scripts/lint-skills.sh` (new)
- `hooks/prepare-commit-msg`

Configuration: `.shellcheckrc` at repo root, with reasonable suppressions documented inline.

### FR-CI: CI configuration

`.github/workflows/ci.yml`:

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: |
          if [ "$RUNNER_OS" = "Linux" ]; then
            sudo apt-get install -y bats shellcheck
          else
            brew install bats-core shellcheck
          fi
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Run test suite
        run: bash scripts/test.sh
      - name: Upload test logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs-${{ matrix.os }}
          path: tests/.logs/
```

The `test.sh` runner writes intermediate logs to `tests/.logs/` so CI can attach them on failure.

## 6. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR1 | Test suite must complete in < 90s on a modern laptop (M1/M2 or equivalent) |
| NFR2 | Test suite must NOT modify the user's `~/.claude/`, `~/.cursor/`, or any path outside `mktemp -d` results |
| NFR3 | Tests must be hermetic: no network, no real-user git config, no inherited `GIT_*` env vars (set `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, etc. in `setup.bash`) |
| NFR4 | Tests must work on both macOS (bash 3.2) and Ubuntu (bash 5.x) — same constraint as the production code |
| NFR5 | A failing test must print enough context to reproduce locally (workspace path is preserved on failure for inspection; pass `BMAD_TEST_KEEP_TMP=1` to keep tmp dirs) |
| NFR6 | Coverage measurement is best-effort using `bashcov` if it works; if not, manual inspection against the FR matrix is the gate |
| NFR7 | The test suite is itself shellchecked (no broken bash in tests) |

## 7. Acceptance criteria

The test-suite project is **done** when:

1. ✅ `tests/` directory exists with the layout from FR2.
2. ✅ **Every topology in FR-Trailer (1–8) has at least one passing bats test** that goes hook→commit→dashboard end to end.
3. ✅ **Every fork enhancement test in FR-Graphify and FR-Caveman is implemented** and passes against a fresh install.
4. ✅ Every test in FR-Hook, FR-Dashboard, FR-Install, FR-Check is a real `@test` and runs via `bash scripts/test.sh`.
5. ✅ `scripts/lint-skills.sh` exists and implements FR-Lint.1–FR-Lint.8.
6. ✅ `scripts/test.sh` exists and routes subcommands (`trailer`, `enhancements`, `hook`, `dashboard`, `install`, `lint`, `shellcheck`, `python`).
7. ✅ `.github/workflows/ci.yml` exists, runs on pull requests, gates merging on macOS + Ubuntu.
8. ✅ **Regression demo**: a deliberate break (e.g. corrupt the `Story-Ref:` parsing in the hook) fails the `tests/trailer_pipeline/` suite in CI.
9. ✅ **Fork-enhancement regression demo**: deleting `templates/dontbmad-caveman-activate.md` fails `tests/enhancements/test_caveman_install.bats`.
10. ✅ `tests/README.md` documents how to run the suite locally and how to add a new topology fixture.
11. ✅ All existing scripts pass shellcheck (with documented suppressions where intentional).
12. ✅ Total suite < 90s on macOS-latest GitHub runner; no individual test > 5s.

## 8. Implementation plan (proposed sequencing)

The sequencing is deliberately ordered so the **headline goals (G1, G2) ship first**. Install.sh general tests come later because real-topology trailer tests already exercise the install flow.

### Sprint 1: Foundation
1. Add `tests/helpers/setup.bash`, `topology_fixtures.bash`, `trailer_helpers.bash`, `assertions.bash`.
2. Add `scripts/test.sh` skeleton with subcommand routing.
3. Add `.github/workflows/ci.yml` running an empty pass on macOS + Ubuntu.
4. Add `shellcheck` step.

### Sprint 2: Trailer pipeline (PRIMARY — G1)
1. FR-Trailer.1 (flat repo) — proves the helper machinery works end to end.
2. FR-Trailer.2 (nested workspace) — proves multi-repo fan-out.
3. FR-Trailer.3 (monorepo) — proves single-`.git`/deep-tree behavior.
4. FR-Trailer.6, FR-Trailer.7 (empty repo, detached HEAD) — proves edge cases.
5. FR-Trailer.4 (worktree), FR-Trailer.5 (submodules) — proves dedupe + git-dir resolution.
6. FR-Trailer.8 (branch naming variants) — pins Story-Ref derivation.
7. **Regression demo**: deliberately break the hook on a branch, prove CI fails.

### Sprint 3: Fork enhancements (SECONDARY — G2)
1. FR-Caveman.1–8 (rule installation, skill presence, mirror parity).
2. FR-Graphify.1–7 (rule installation, 4 skills present, no absolute paths).
3. **Regression demo**: delete `templates/dontbmad-caveman-activate.md`, prove CI fails.

### Sprint 4: Hook unit tests (G3)
1. FR-Hook.1–4 — covers all decision branches not already exercised by FR-Trailer.

### Sprint 5: Dashboard unit tests (G4)
1. FR-Dashboard.1–4 (no-commits, aggregation, targets, filter).
2. FR-Dashboard.5–6 (workspace mode, submodule dedupe — light overlap with FR-Trailer.2/5; keep both).
3. FR-Dashboard.7 (edge cases — empty AI-Tool, malformed trailers).

### Sprint 6: install.sh general surface (G3 supplement)
1. FR-Install.1–7 — only tests not already exercised by FR-Trailer/FR-Graphify/FR-Caveman.

### Sprint 7: Static checks (G5)
1. `scripts/lint-skills.sh` implementing FR-Lint.1–8.
2. FR-Check tests for `check-skill-symlinks.sh`.
3. Wire into `test.sh` and CI.

### Sprint 8: Polish
1. Coverage audit against `architecture.md` Components 1–3.
2. Add any missing edge cases surfaced during implementation.
3. Document everything in `tests/README.md`, including the topology fixture cookbook.
4. Tag a v3.0.0 release noting the test gate is now mandatory.

## 9. Open questions

These were surfaced during the scan and need product/engineering decisions before/during implementation:

| # | Question | Why it matters |
|---|---|---|
| Q1 | When `prepare-commit-msg.bak` already exists and we're installing again, do we clobber, refuse, or rotate (`.bak.1`, `.bak.2`)? | FR4.6.c — current behavior is clobber, may surprise users |
| Q2 | When a branch name has multiple slashes (`fix/team-x/some-bug`), is `Story-Ref: some-bug` correct? | FR5.3.c — affects how teams structure branches |
| Q3 | Empty commit message file gets only trailers — is that valid for `git commit`? Should the hook abort instead? | FR5.4.c — could break edge-case commits |
| Q4 | Multiple `AI-Phase:` trailers on one commit — which wins? | FR6.11 — no spec today; pin behavior |
| Q5 | Should the dashboard error or skip when a commit has malformed trailers (e.g. `AI-Phase` without value)? | FR6.x — affects trust |
| Q6 | What's the policy for a contributor adding a skill to `claude/skills/` but forgetting `cursor/skills/`? Linter blocker, warning, or autoclone? | FR-Lint.6 — currently no enforcement |
| Q7 | Should `install.sh` install hooks into git submodules, or only into top-level repos? | FR-Trailer.5 — current behavior recurses one level; submodules at deeper paths are missed |
| Q8 | If a user deletes `templates/dontbmad-caveman-activate.md` to opt out of caveman default-on, should `install.sh` respect that, or always re-install it? | FR-Caveman.7 — current behavior re-installs; users wanting opt-out must delete after every install |
| Q9 | If upstream BMAD adds a new skill prefix (e.g. `bmm-*`), does the installer pick it up? | FR-Lint — current globs are `bmad-*` and `dontbmad-*` only |

## 10. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| bats-core syntax learning curve slows initial sprint | Med | Low | Provide cookbook in `tests/README.md`; pair on first 5 tests |
| macOS bash 3.2 vs Ubuntu bash 5.x divergence | Med | Med | Matrix CI on both; `setup.bash` enforces bash version detection |
| Test flakiness from filesystem races (`mktemp` collisions, find ordering) | Low | Med | Always sort find output; never rely on glob ordering for assertions |
| Test data drift when skill count changes from 59 to 60+ | High | Low | FR4.2.a should compute expected count from `ls claude/skills/ \| wc -l`, not hardcode 59 |
| `shellcheck` finds many warnings, sprint balloons | Med | Med | Allowlist existing warnings up front; only NEW warnings block CI |

## 11. Out of scope (revisit later)

- Property-based testing (e.g. fuzzing branch names for the hook).
- Snapshot testing of dashboard output (reasonable but adds ergonomic drag — defer until output stabilizes).
- Performance benchmarks (e.g. dashboard latency on a 10k-commit repo).
- Skill-runtime tests (booting an agent and running a skill — out of scope per §3).

## 12. Appendix: example test (illustrative)

```bash
# tests/hook/test_branch_parsing.bats
load '../helpers/setup'

@test "hook adds Story-Ref derived from branch with slash prefix" {
  setup_tmp_repo
  git -C "$TMP_REPO" checkout -b feature/wave-planning-1-1

  msg_file="$(mktemp)"
  echo "feat: implement wave planning" > "$msg_file"

  cd "$TMP_REPO"
  bash "$REPO_ROOT/hooks/prepare-commit-msg" "$msg_file" ""

  run grep -E "^Story-Ref: wave-planning-1-1$" "$msg_file"
  [ "$status" -eq 0 ]
}

@test "hook leaves message alone when AI-Phase trailer already present" {
  setup_tmp_repo
  git -C "$TMP_REPO" checkout -b main

  msg_file="$(mktemp)"
  cat > "$msg_file" <<EOF
chore: bump version

AI-Phase: deploy
AI-Tool: cursor/claude-sonnet-4-20250514
Story-Ref: deploy-v3
EOF

  before="$(cat "$msg_file")"

  cd "$TMP_REPO"
  bash "$REPO_ROOT/hooks/prepare-commit-msg" "$msg_file" ""

  after="$(cat "$msg_file")"
  [ "$before" = "$after" ]
}
```

This pattern (use `setup_tmp_repo`, exercise the script, assert on a side effect) repeats throughout the suite.

---

**End of PRD.** This document and the accompanying `architecture.md`, `source-tree-analysis.md`, and `skills-inventory.md` provide everything an agent needs to implement the test suite end-to-end.
