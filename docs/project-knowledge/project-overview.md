# Project Overview: dont-b-mad (bmad-er)

**Generated:** 2026-04-26
**Repository:** `/Users/Sachin/Workspace/bmad-er`
**Repository type:** Monolith
**Primary purpose:** A fork of [BMAD v6.3.0](https://github.com/bmad-code-org) that bakes AI adoption tracking into every SDLC workflow. Distributes a curated set of agent "skills" for Claude Code and Cursor, plus a git hook and dashboard that measure AI usage across phases (PRD, architecture, code, test, review, etc.).

## What this repo is

`dont-b-mad` is **not application code** — it is a distribution of:

1. **Skills** — markdown-driven agent workflows (e.g. `bmad-create-prd`, `bmad-dev-story`, `bmad-code-review`) that get installed into `.claude/skills/` and `.cursor/skills/`.
2. **A git hook** (`prepare-commit-msg`) that auto-appends three trailers (`AI-Phase`, `AI-Tool`, `Story-Ref`) to every commit.
3. **An adoption dashboard** (`adoption-dashboard.sh`) that reads those trailers from git history and prints adoption rates per SDLC phase.
4. **An installer** (`install.sh`) that wires all of the above into a workspace.
5. **A handful of "rules" and templates** that the agent loads at session start to resolve `{project-root}`, custom team names, etc.

The repo's user is a **developer or team lead** who wants to roll BMAD into their workspace and start measuring AI adoption without asking anyone to type trailers by hand.

## Tech stack

| Category | Technology | Version | Justification |
|---|---|---|---|
| Installer | Bash | 3.2+ (portable) | Mac default ships with bash 3.2; install.sh + dashboard avoid associative arrays |
| Aggregation | AWK | POSIX | Dashboard delegates phase grouping to awk for portability |
| Skill workflows | Markdown + light XML | n/a | Skills are read by the agent at runtime; XML used in `bmad-dev-story` for conditional flow |
| Skill scripts (rare) | Python 3 | — | Only `bmad-distillator` ships a Python helper + pytest tests |
| Trailer convention | git interpret-trailers / `%(trailers:key=...)` | git ≥ 2.32 | Required for keyed trailer extraction in dashboard |
| Test framework (current) | pytest | — | Single test file: `bmad-distillator/scripts/tests/test_analyze_sources.py` |

## Architectural classification

- **Monolith**: single cohesive codebase, no client/server split, no monorepo-style parts.
- **Distribution-style tooling**: install.sh is the entry point that publishes content into target workspaces.
- **Data flow**: Source-of-truth lives in `claude/skills/` and `cursor/skills/`. The installer either symlinks (in-repo, dev-link) or copies (external workspace) into `.claude/skills/` and `.cursor/skills/` at the workspace root.

## Repository layout (top-level)

```
bmad-er/
├── README.md                # User-facing install + AI tracking docs
├── CHANGELOG.md             # v2.0.0 trailer simplification, v1.1.0 checkpoints, v1.0.0 initial
├── LICENSE                  # MIT, 2026 ElasticRun
├── claude/skills/           # 67 skills, source of truth for Claude Code
├── cursor/skills/           # 67 skills, source of truth for Cursor (mirrors claude/)
├── scripts/                 # install.sh, adoption-dashboard.sh, check-skill-symlinks.sh
├── hooks/                   # prepare-commit-msg (the only hook)
├── templates/               # 4 rules + team.yaml + workspace.yaml templates
└── docs/                    # Presentations + this generated documentation
```

## Existing documentation found

- `README.md` — Comprehensive install instructions, AI tracking introduction, dashboard sample output
- `CHANGELOG.md` — Version history (v2.0.0 simplified trailers, v1.1.0 added checkpoints, v1.0.0 initial)
- `docs/why-bmad-presentation.md` — Marp deck on context curation rationale
- `docs/why-bmad-presentation-concise.md` — Condensed version
- `docs/story-2026-04-15.md` — Story file example

## What this overview is NOT covering

- **Per-skill semantics**: see `skills-inventory.md`
- **Install + hook + dashboard internals**: see `architecture.md`
- **How to test the surface area**: see `test-suite-prd.md` (the primary deliverable of this scan)

## Test surface (high-level — driving the PRD)

| Surface | LOC | Test coverage today | Risk if broken |
|---|---|---|---|
| `scripts/install.sh` | 335 | 0% | High — installs across user's whole workspace; symlinks, file copies, hook deployment |
| `scripts/adoption-dashboard.sh` | 216 | 0% | Medium — reports drive team behavior; wrong numbers erode trust |
| `hooks/prepare-commit-msg` | 31 | 0% | High — fires on every commit; bug = corrupt commit messages |
| `scripts/check-skill-symlinks.sh` | 66 | 0% | Low — diagnostic only |
| `claude/skills/bmad-distillator/*.py` | ~? | partial (pytest) | Medium — already tested, expand |
| Skill workflow files (Markdown) | thousands | 0% (executed by agent at runtime) | Variable — testable via lint/structure checks |

The test-suite PRD prioritizes the bash surface because it's deterministic, side-effecting, and runs on every contributor's machine.
