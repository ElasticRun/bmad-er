# Architecture: dont-b-mad

**Generated:** 2026-04-26

## Executive summary

`dont-b-mad` is a **content distribution + measurement** system. It has three independent runtime concerns that share no in-process state:

1. **Skills** — markdown workflows the agent reads at runtime to drive multi-step tasks.
2. **Trailer hook** — a `prepare-commit-msg` shim that injects three trailers per commit.
3. **Adoption dashboard** — an awk-based aggregator over `git log` that surfaces phase-level adoption rates.

Glue is provided by **`install.sh`**, which is the only "control plane" in the system.

There is no server, no database, no API. State is git history (for trailers) and the filesystem (for installed skills/rules).

---

## Component model

```
                ┌──────────────────────────────────────────────────┐
                │                bmad-er repo (source)             │
                │                                                  │
                │   claude/skills/   cursor/skills/   templates/   │
                │        │                │              │         │
                │        └────────┬───────┘              │         │
                │                 │                      │         │
                │           hooks/prepare-commit-msg     │         │
                │                 │                      │         │
                │           scripts/install.sh ──────────┘         │
                │                 │                                │
                │           scripts/adoption-dashboard.sh          │
                └─────────────────┼────────────────────────────────┘
                                  │
                                  ▼ (user runs install.sh <workspace>)
                ┌─────────────────────────────────────────────────────┐
                │                Target workspace                     │
                │  ~/Workspace/  (or any path the user passes)        │
                │                                                     │
                │  .claude/skills/    ← symlinks (in-repo) or copies  │
                │  .cursor/skills/    ← symlinks (in-repo) or copies  │
                │  .claude/rules/     ← copies of templates/*.md      │
                │  .cursor/rules/     ← copies of templates/*.md      │
                │  _bmad/_config/team.yaml         ← copy of template │
                │  _bmad/workspace.yaml            ← auto-generated   │
                │  scripts/adoption-dashboard.sh   ← copy             │
                │                                                     │
                │  project-A/.git/hooks/prepare-commit-msg ← copy     │
                │  project-B/.git/hooks/prepare-commit-msg ← copy     │
                │  project-C/.git/hooks/prepare-commit-msg ← copy     │
                └─────────────────────────────────────────────────────┘
                                  │
                                  ▼ (user commits in project-A)
                          ┌───────────────────┐
                          │  prepare-commit-  │
                          │  msg runs         │
                          │  appends trailers │
                          └───────┬───────────┘
                                  │
                                  ▼ (later, user runs dashboard)
                          ┌───────────────────┐
                          │  adoption-        │
                          │  dashboard.sh     │
                          │  reads git log    │
                          │  via awk, prints  │
                          │  phase rollup     │
                          └───────────────────┘
```

---

## Component 1: install.sh

**File:** `scripts/install.sh` (335 LOC)

### Argument surface

| Flag | Effect |
|---|---|
| `[workspace-path]` (positional) | Target workspace (defaults to `.`) |
| `--skills-only` | Skips git hook installation |
| `--hooks-only` | Skips skill/rules/config installation |
| `--global` | Publishes skills to `~/.claude/skills`, `~/.cursor/skills`, and `~/.claude/commands` (independent of any workspace) |
| `--dev-link` | (with `--global`) Symlinks instead of copies for live edits |
| `--force` | Overwrites existing `_bmad/workspace.yaml` and `_bmad/_config/team.yaml` |
| `--help / -h` | Prints usage |

### Modes (exclusive)

`MODE` is one of `all | skills | hooks | global`. The `all` mode is the default — runs both the skills branch and the hooks branch.

### Skills branch (when MODE=all|skills)

1. Detects `IN_REPO` (workspace path == repo root).
2. For each skill directory under `claude/skills/` matching `bmad-*` or `dontbmad-*`:
   - If `IN_REPO`: removes target and creates a relative symlink `../../{src_dir}/{name}`.
   - Else: removes target and copies the directory.
3. Repeats for `cursor/skills/`.
4. If `scripts/adoption-dashboard.sh` exists in the source repo: copies it into `<workspace>/scripts/` and chmods +x.
5. Copies four rule files into `<workspace>/.cursor/rules/` and `<workspace>/.claude/rules/`.
6. Copies `templates/team.yaml` to `<workspace>/_bmad/_config/team.yaml` (skips if exists unless `--force`).
7. Generates `<workspace>/_bmad/workspace.yaml` by:
   - Checking if `<workspace>/_bmad/{bmm,cis,core}` exists → adds `.` as a project.
   - Scanning `<workspace>/*/` (one level) for any dir with `_bmad/{bmm,cis,core}` → adds it.
   - Adding commented-out entries for sibling git repos that don't yet have `_bmad/`.
   - If exactly one project found, fills `default_project` to it.

### Hooks branch (when MODE=all|hooks)

1. Resolves the git dir of `<workspace>` itself (handles both `.git` directory and `.git` file for worktrees).
2. If workspace itself is a git repo, installs hook there.
3. Scans `<workspace>/*/` one level deep for git repos and installs hook in each.
4. Installs by:
   - If existing `prepare-commit-msg` exists, copies to `prepare-commit-msg.bak`.
   - Copies source `hooks/prepare-commit-msg` and chmods +x.

### Global branch (when MODE=global)

1. Cleans up broken symlinks in `~/.claude/commands/`.
2. For each skill (claude + cursor), publishes to `~/.{claude,cursor}/skills/` either as copy (default) or symlink (`--dev-link`).
3. For each Claude skill, creates `~/.claude/commands/<name>.md` symlink pointing to the skill's `SKILL.md` (so it's available as a `/` command).

### Side-effect inventory (test-relevant)

| Path written | Condition |
|---|---|
| `<ws>/.claude/skills/*` | MODE=all\|skills |
| `<ws>/.cursor/skills/*` | MODE=all\|skills |
| `<ws>/.claude/rules/*.md` | MODE=all\|skills (4 files) |
| `<ws>/.cursor/rules/*.md` | MODE=all\|skills (4 files) |
| `<ws>/_bmad/_config/team.yaml` | MODE=all\|skills, only if missing or `--force` |
| `<ws>/_bmad/workspace.yaml` | MODE=all\|skills, only if missing or `--force` |
| `<ws>/scripts/adoption-dashboard.sh` | MODE=all\|skills |
| `<repo>/.git/hooks/prepare-commit-msg` | MODE=all\|hooks, per repo found |
| `<repo>/.git/hooks/prepare-commit-msg.bak` | If existing hook present |
| `~/.claude/skills/*`, `~/.cursor/skills/*`, `~/.claude/commands/*.md` | MODE=global only |

---

## Component 2: prepare-commit-msg hook

**File:** `hooks/prepare-commit-msg` (31 LOC)

### Inputs

| `$1` | Path to commit message file (git contract) |
| `$2` | Commit source (`""`, `"merge"`, `"squash"`, `"message"`, `"template"`, `"commit"`) |

### Decision tree

```
START
├── If $2 == "merge" OR $2 == "squash" → exit 0
├── If grep "^AI-Phase:" found in commit msg → exit 0
└── Else:
    ├── STORY_REF = git branch --show-current | sed 's|.*/||'
    │   (strips any prefix like feature/, fix/, hotfix/)
    └── Append three lines to commit msg:
        AI-Phase: code
        AI-Tool: manual
        Story-Ref: ${STORY_REF:-unknown}
```

### Test surface (deterministic, high value)

- `$2 == merge` → no-op
- `$2 == squash` → no-op
- Existing `AI-Phase:` trailer → no-op
- Branch `feature/wave-planning-1-1` → trailer `Story-Ref: wave-planning-1-1`
- Branch `main` (no slash) → trailer `Story-Ref: main`
- Detached HEAD (no current branch) → trailer `Story-Ref: unknown`
- Empty commit message file → trailers appended at top of empty file (need to verify behavior is acceptable)

---

## Component 3: adoption-dashboard.sh

**File:** `scripts/adoption-dashboard.sh` (216 LOC)

### Argument surface

| Args | Effect |
|---|---|
| (none) | Aggregates current repo's `git log --all` |
| `<filter>` | Filters by `Story-Ref` glob (e.g. `"1-*"`) |
| `--workspace [path]` | Aggregates all git repos found under `<path>` (default `.`) |
| `--workspace [path] <filter>` | Both |
| `--repo /path/to/repo` | Aggregates one specific repo |
| `--help / -h` | Prints usage |

### Pipeline

```
git log --all --format="%H<F>%(trailers:key=AI-Phase,valueonly)<F>%(trailers:key=AI-Tool,valueonly)<F>%(trailers:key=Story-Ref,valueonly)<END>"
                       │
                       ▼
              awk (RS=<END>, FS=<F>)
                       │
            ┌──────────┴──────────────┐
            │                         │
        if filter pattern,        else count all
        glob_match Story-Ref           │
            │                         │
            └──────────┬──────────────┘
                       ▼
        per-phase counters:
          phase_total[phase]++
          if (tool != "manual" && tool != "") phase_ai[phase]++
                       │
                       ▼
        render PLANNING (prd, architecture, ux-design, epics, sprint-plan, story)
        render DEVELOPMENT (code, test, review, deploy)
        print TOTAL
```

### Targets (hard-coded in awk)

| Phase | Target |
|---|---|
| prd, architecture, ux-design, epics, sprint-plan, story | 90% |
| review | 95% |
| test | 85% |
| code, deploy | 80% |

### Workspace discovery (--workspace mode)

The `discover_repos` function uses `find` to locate every `.git` directory under the workspace root, prunes noise (`node_modules`, `vendor`, `.venv`, etc.), and **deduplicates nested git repos** (a submodule inside a repo is not double-counted).

### Test surface

- Empty repo (no commits) → "No commits with AI trailers found."
- Only manual commits → all phases at 0% AI
- Mix of manual + AI commits → percentages match arithmetic
- Multi-line trailers (multiple `AI-Phase:` lines on one commit) → behavior?
- `--workspace` over a directory with submodules → no double-counting
- `--workspace` over a directory with no git repos → error message
- Glob filter `"1-*"` matches `Story-Ref: 1-1-foo`, doesn't match `2-1-bar`
- Glob filter with literal special chars → handled by glob_match's regex escaping

---

## Component 4: skills (the content layer)

Skills have **no runtime in this repo** — they are markdown files that the agent reads when invoked. Their "tests" can only be:

1. **Structural checks**: Does every skill directory have a `SKILL.md`? Does the YAML frontmatter parse? Does `workflow.md` reference files that exist (no broken `Read fully and follow:` paths)?
2. **Cross-mirror checks**: Does `cursor/skills/<name>` match `claude/skills/<name>` (with documented diffs)?
3. **Content lint**: No skill should reference a path with leading `/Users/...` (would break for other users).

These are static-analysis tests, not runtime tests. See test-suite-prd.md for specifics.

---

## Component 5: templates and rules (static content)

| File | Purpose |
|---|---|
| `templates/bmad-workspace-resolution.md` | Tells agent: when a skill says `{project-root}`, look up `default_project` in `_bmad/workspace.yaml` |
| `templates/bmad-team-customization.md` | Tells agent: read display names from `_bmad/_config/team.yaml` |
| `templates/dontbmad-graph-first.md` | Tells agent: prefer reading `graphify-out/graph.json` over scanning source |
| `templates/dontbmad-caveman-activate.md` | Tells agent: speak in terse caveman mode by default |
| `templates/team.yaml` | Default agent display names |
| `templates/workspace.yaml` | Workspace registry template (mostly rewritten by installer) |

Tests: file presence, valid YAML where applicable, installer copies them correctly.

---

## Architectural risks

1. **install.sh has no rollback.** If it fails midway, a partial state is left. Test should verify the failure modes leave the workspace in a recoverable state, or document explicit rollback steps.
2. **Hook backup strategy is single-slot.** A second install over a backed-up hook would clobber the original `prepare-commit-msg.bak`. (Verify; this is testable.)
3. **Workspace discovery is one-level-deep.** Sibling projects nested two-deep are ignored. Either confirm intentional (it is — see comments in install.sh) or document.
4. **Branch-name parsing in hook strips one segment.** A branch like `feature/team-x/wave-planning` would yield `Story-Ref: wave-planning`, dropping `team-x`. Confirm this is intentional.
5. **Dashboard treats empty `AI-Tool` and `manual` identically** for non-AI counting. If trailer is mis-typed (e.g. `Manual`), it would count as AI. Confirm.
6. **No CI gate.** Anyone can push a broken `install.sh` and only catch it post-hoc.

---

## Testing strategy implication

This architecture maps cleanly to **three test categories**:

| Category | Target | Tool fit |
|---|---|---|
| Bash unit tests | Functions in install.sh, dashboard.sh, hook | bats-core (with stubbed git/fs) |
| Bash integration tests | install.sh end-to-end against a tmp workspace, dashboard against synthetic git history | bats-core + tmp dirs + git init |
| Static checks on skills | Frontmatter, links, mirror parity | shellcheck + yamllint + a custom Python/Node script |
| Python unit tests | bmad-distillator | pytest (already in place) |

This drives the test-suite PRD.
