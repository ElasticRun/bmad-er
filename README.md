# bmad-er

A fork of [BMAD v6.3.0](https://github.com/bmad-code-org) with AI tracking baked into every workflow. Measures AI adoption across the full SDLC without adding any overhead to developers.

Works with **Cursor** and **Claude Code**.

## What This Adds

Every git commit gets three trailers recording what phase of work it represents and whether AI was involved:

```
feat: implement wave planning task assignment

AI-Phase: code
AI-Tool: cursor/claude-sonnet-4-20250514
Story-Ref: 1-1-wave-planning
```

Trailers are appended automatically. BMAD workflows fill them with the actual tool/model used. A git hook catches manual commits and tags them with `AI-Tool: manual`. Nobody types trailers by hand.

A dashboard script (Pulse) reads git history and prints adoption rates grouped by phase:

```
======================================
  Pulse — AI Adoption Dashboard
======================================

  PLANNING (3 commits)
  --------------------------------
  prd                  100%  (target: 90%)  [2/2]
  story                100%  (target: 90%)  [1/1]

  DEVELOPMENT (8 commits)
  --------------------------------
  code                  75%  (target: 80%)  [6/8]
  test                  50%  (target: 85%)  [2/4]
  review                62%  (target: 95%)  [5/8]

  TOTAL: 11 tracked commits
======================================
```

## Install

```bash
git clone https://github.com/ElasticRun/bmad-er.git
bash bmad-er/scripts/install.sh /path/to/your/project
```

This copies skills into `.cursor/skills/` and `.claude/skills/`, installs the `prepare-commit-msg` hook, and drops the dashboard script into `scripts/`.

If you already have a `prepare-commit-msg` hook, the installer backs it up to `.bak` before replacing.

## What Gets Installed

| Location | What |
|---|---|
| `.cursor/skills/bmad-*` | All BMAD skills (Cursor) |
| `.claude/skills/bmad-*` | All BMAD skills (Claude Code) |
| `.git/hooks/prepare-commit-msg` | Auto-tags manual commits with AI trailers |
| `scripts/adoption-dashboard.sh` | Reads git trailers, prints adoption rates |

## Dashboard Usage

```bash
# All commits
bash scripts/adoption-dashboard.sh

# Filter by story ref pattern (e.g. epic 1)
bash scripts/adoption-dashboard.sh "1-*"
```

## Trailers Reference

Three trailers per commit. One commit = one phase of work.

| Trailer | Records | Values |
|---|---|---|
| `AI-Phase` | What phase this commit belongs to | `prd`, `architecture`, `ux-design`, `epics`, `sprint-plan`, `story`, `code`, `test`, `review`, `deploy` |
| `AI-Tool` | AI tool/model used, or manual | Tool/model identifier (e.g. `cursor/claude-sonnet-4-20250514`), or `manual` |
| `Story-Ref` | What story or artifact this belongs to | Story key (e.g. `1-1-wave-planning`) or artifact ref (e.g. `prd-aieye`) |

## How It Flows

```
create-story  -->  commits with AI-Phase: story
     |
  dev-story   -->  commits with AI-Phase: code
     |
 code-review  -->  commits with AI-Phase: review
     |
 retrospective --> queries git trailers; surfaces adoption metrics by phase
```

Manual commits (hotfixes, config changes) get auto-tagged by the git hook with `AI-Tool: manual`.

## Modified Workflows (from upstream BMAD v6.3.0)

**Planning workflows** (auto-commit artifacts with AI trailers on completion):
- `bmad-create-prd` -- commits PRD
- `bmad-create-epics-and-stories` -- commits epics
- `bmad-create-architecture` -- commits architecture doc
- `bmad-create-ux-design` -- commits UX design
- `bmad-sprint-planning` -- commits sprint status

**Development workflows** (AI Engineering Record + commit trailers):
- `bmad-create-story` -- AI Engineering Record table in template, commits story on creation
- `bmad-dev-story` -- fills record rows, creates commits with trailers, checklist updated
- `bmad-code-review` -- fills review row, creates review commit with trailers
- `bmad-quick-dev` -- appends trailers to commits (both step-05 and one-shot paths)
- `bmad-retrospective` -- queries git for AI adoption metrics by phase, includes in retro output
- `bmad-ai-tracking` -- new skill: hook template, dashboard, install instructions
- `bmad-graphify` -- new skill: knowledge graph setup, query reference, workflow integration docs

## Credits

Built on [BMAD](https://github.com/bmad-code-org) v6.3.0 by the BMAD community. This fork adds the AI tracking layer. All upstream skills are included unmodified except where noted above.

## License

MIT. See [LICENSE](LICENSE).
