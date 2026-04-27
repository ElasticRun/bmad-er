# Development Guide: dont-b-mad

**Generated:** 2026-04-26

## Prerequisites

- **bash** 3.2 or newer (Mac default works)
- **git** 2.32+ (for `%(trailers:key=...,valueonly)` format)
- **awk** (POSIX or GNU)
- **Python 3** (only required for `bmad-distillator` skill development)

No package manager, no language runtime, no build step.

## Local development workflow

This repo IS the source of truth for skills. There are two ways to develop:

### 1. Live editing in this repo (recommended)

```bash
# From inside the repo:
bash scripts/install.sh .
```

When `TARGET == REPO_ROOT`, the installer creates **symlinks** under `.claude/skills/` and `.cursor/skills/` pointing into `claude/skills/` and `cursor/skills/`. Edits to source files apply immediately to the agent in this repo's session.

### 2. Live editing globally

```bash
bash scripts/install.sh --global --dev-link
```

Symlinks every skill into `~/.claude/skills/` and `~/.cursor/skills/`. Every project on the machine sees edits immediately. Use this when iterating on a skill while testing it across multiple projects.

## Adding a new skill

1. Create a new directory under `claude/skills/<name>/`. Name MUST start with `bmad-` or `dontbmad-` (the installer's glob expects this).
2. Add a `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-new-skill
   description: One-line trigger description starting with "Use when the user says…"
   ---
   ```
3. Add a `workflow.md` if multi-step.
4. Mirror the directory under `cursor/skills/<name>/`. (`structural/skill-mirror.test.sh` enforces parity.)
5. Run `bash scripts/install.sh .` from the repo root. With TARGET equal to REPO_ROOT, the installer symlinks `~/.claude/skills/<name>` and `~/.cursor/skills/<name>` back to this repo's source — edits apply live.

## Modifying the git hook

Source: `hooks/prepare-commit-msg`

After editing, contributors who already ran the installer must **re-install** the hook (existing copies in `.git/hooks/` will not auto-update):

```bash
bash scripts/install.sh ~/Workspace --hooks-only
```

## Running the dashboard during development

```bash
# From a repo with commits that have AI trailers:
bash scripts/adoption-dashboard.sh
bash scripts/adoption-dashboard.sh "1-*"          # filter by Story-Ref glob
bash scripts/adoption-dashboard.sh --workspace ~/Workspace
```

To generate test data: make commits in a throwaway repo with crafted trailers, then run dashboard against it.

## Testing

**Today:** the only tests live under `claude/skills/bmad-distillator/scripts/tests/`:

```bash
cd claude/skills/bmad-distillator/scripts
python3 -m pytest tests/
```

**Planned:** see `test-suite-prd.md` for the full test framework introduction.

## Release flow

There is no automated release pipeline today. Versions are tracked in `CHANGELOG.md`.

To cut a release:
1. Bump version in `CHANGELOG.md`.
2. Tag with `git tag v<version>` and push.
3. Users update by `git pull` in their cloned `bmad-er` and re-running `install.sh`.

## Common dev tasks

| Task | Command |
|---|---|
| Re-install everything in this repo (live symlinks) | `bash scripts/install.sh .` |
| Re-install hooks only across all repos in `~/Workspace` | `bash scripts/install.sh ~/Workspace --hooks-only` |
| Run distillator tests | `cd claude/skills/bmad-distillator/scripts && python3 -m pytest tests/` |
| View dashboard output | `bash scripts/adoption-dashboard.sh` |
| Force-overwrite workspace.yaml | `bash scripts/install.sh <ws> --force` |

## Coding conventions

- **Bash:** `set -euo pipefail` everywhere. Prefer POSIX-friendly constructs (the dashboard explicitly avoids associative arrays for bash 3.2 compatibility).
- **Markdown skills:** Use `{project-root}` as a placeholder, never absolute paths. Reference the workspace-resolution rule.
- **Trailer keys:** Always `AI-Phase`, `AI-Tool`, `Story-Ref` — exact case, with hyphen, with colon. The hook and dashboard both depend on this.
- **Skill names:** Always prefixed `bmad-` or `dontbmad-`. The installer's glob filters on these prefixes.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Skill doesn't appear in agent | Skill not published to `~/.claude/skills` (or `~/.cursor/skills`) | Run `install.sh <ws>` (or `install.sh --global` for skills only) |
| Edit to skill doesn't take effect | User-level skill is a copy, not a symlink | Re-run `install.sh .` from inside this repo (auto-detects IN_REPO and symlinks), or use `install.sh --global --dev-link` |
| Commits not getting trailers | Hook not installed or backed up by another tool | Run `install.sh <ws> --hooks-only` |
| Dashboard says "no commits" | Repo has no commits with `AI-Phase:` trailer (e.g. only old commits before install) | Make a new commit; the hook will tag it |
