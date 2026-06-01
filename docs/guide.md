# lets-b-mad contributor and maintainer guide

This document covers **contributing** to the lets-b-mad repository and **upgrading BMAD** safely. Installation for end users is in [README.md](../README.md).

## Contributing

### Repository structure

```text
lets-b-mad/
├── scripts/
│   ├── install.sh              # Orchestrator (entry point)
│   ├── pre-workflow.sh         # Runtime: central context pull
│   ├── post-workflow.sh        # Runtime: post-workflow hooks
│   ├── ai-stats-summary.sh     # Utility: git-ai metrics
│   └── lib/                    # Install-time modules (sourced by install.sh only)
│       ├── common.sh           # Logging, checksums, exit codes, summary table
│       ├── prerequisites.sh    # Homebrew prerequisite detection/install
│       ├── bmad.sh             # BMAD npx install, skills, customize.toml
│       ├── dependencies.sh     # git-ai and graphify
│       ├── context.sh          # Central context clone/pull
│       ├── workspace.sh        # workspace.yaml discovery
│       ├── hooks.sh            # graphify git hooks
│       └── manifest.sh         # .lets-b-mad/install-manifest.json
├── templates/customize/        # Source templates for BMAD overrides
├── docs/                       # Maintainer documentation (this file)
└── tests/unit/                 # POSIX sh unit tests
```

**Boundaries:**

- **In git:** `scripts/`, `templates/`, `docs/`, config files.
- **Generated at install:** `workspace.yaml`, `.lets-b-mad/`, `_bmad/`, `~/.cursor/skills/`, `~/.claude/skills/`, `~/.lets-b-mad/central-context/`.
- **Runtime scripts** (`pre-workflow.sh`, `post-workflow.sh`) must not source `scripts/lib/*`.

### customize.toml templates

BMAD skill hooks are customized via TOML files under `<workspace>/_bmad/custom/`.

**Source of truth:** `templates/customize/_default.toml`

Placeholders `{{PRE_WORKFLOW_PATH}}` and `{{POST_WORKFLOW_PATH}}` are replaced at install time with absolute paths to `scripts/pre-workflow.sh` and `scripts/post-workflow.sh`.

**Generation:** `bmad_generate_toml` in `scripts/lib/bmad.sh`:

- Emits one `<skill-name>.toml` per `bmad-*` skill in `~/.cursor/skills/`.
- On re-install, skips files the developer changed (protected manifest entry with checksum drift).
- Use `bash scripts/install.sh --force` to regenerate all customize files.

**Adding a new override (NFR18):**

1. Add or edit a file under `templates/customize/` (usually extend `_default.toml`).
2. Do **not** change `install.sh` logic for template copying.
3. Re-run install from a test workspace and confirm `_bmad/custom/*.toml` updates.

### Adding a new lib module

1. Create `scripts/lib/<module>.sh` using POSIX `#!/bin/sh` conventions (functions only at top level; no `local`, no `[[`).
2. Define exit codes in `scripts/lib/common.sh` if the module needs a new range.
3. Source the module in `scripts/install.sh`:

   ```sh
   . "$LIB_DIR/<module>.sh"
   ```

4. Add an `install_step_<name>` function and call it from `install_main` with `|| true` (continue-on-failure).
5. Add `tests/unit/test_<module>.sh` using `tests/unit/lib/test_helpers.sh`.

Existing suites cover epics 1–7: `test_repo_structure.sh`, `test_prerequisites.sh`, `test_bmad.sh`, `test_install.sh`, `test_docs.sh`, plus module tests for manifest, workspace, dependencies, hooks, context, workflows, and validation.
6. Run shellcheck on all scripts.

### Testing procedures

**Unit tests** (from repository root):

```sh
for f in tests/unit/test_*.sh; do sh "$f"; done
```

**Static analysis:**

```sh
shellcheck -s sh scripts/lib/*.sh scripts/*.sh
```

**Documentation lint:**

```sh
npx markdownlint-cli2 --no-globs docs/guide.md README.md
```

**Manual smoke test** after script changes:

1. Use a disposable workspace directory with at least one git repository.
2. Run `bash /path/to/lets-b-mad/scripts/install.sh`.
3. Follow verification steps in [README.md](../README.md#verify-installation).

## Upgrading BMAD

BMAD is installed via `npx bmad-method@<version>`. Other dependencies use separate pins in the same file.

### Version bump procedure

Edit **one line** in `scripts/install.sh`:

```sh
BMAD_VERSION="6.8.0"   # increment to target BMAD Method release
```

Related pins (upgrade only when intentionally changing those tools):

```sh
GITAI_VERSION="1.5.2"
GRAPHIFY_VERSION="0.8.27"
```

No other files need changes for a BMAD-only upgrade.

### Test-then-rollout

1. **Pilot workspace:** Choose one developer machine or CI workspace.
2. Update `BMAD_VERSION` on a branch; run `bash scripts/install.sh` from that workspace root.
3. **Verify:**
   - Install exits **0**.
   - README verification commands pass.
   - Run a representative BMAD workflow (e.g. create-story) and confirm `pre-workflow.sh` / `post-workflow.sh` run.
4. **Team rollout:** Merge the version bump; ask each developer to pull and re-run `bash scripts/install.sh` from their workspace root.
5. Announce that Cursor and Claude Code should be **restarted** after global skills change.

### Compatibility checklist

Before merging a BMAD version bump, confirm:

| Item | Check |
| --- | --- |
| npx install | `npx bmad-method@<new-version> install --help` succeeds |
| Modules | Default modules `bmm,cis,wds` still valid for the release |
| Skills layout | `bmad_deploy_skills` finds skills under temp install output |
| `_bmad/` tree | `bmad_deploy_workspace` deploys without error |
| customize.toml | `bmad_generate_toml` produces `_bmad/custom/*.toml` |
| Protected overrides | Developer-edited customize files still respected without `--force` |
| Manifest | `.lets-b-mad/install-manifest.json` records new `bmad` version |
| Unit tests | All `tests/unit/test_*.sh` pass in CI or locally |

### Rollback steps

If the new BMAD version fails in production:

1. Revert `BMAD_VERSION` in `scripts/install.sh` to the last known good value (git revert or manual edit).
2. From each affected workspace root, run:

   ```sh
   bash /path/to/lets-b-mad/scripts/install.sh
   ```

3. Restart Cursor and Claude Code (global skills are wiped and redeployed on install).
4. If `_bmad/` was corrupted, remove `_bmad/` and re-run install (or use `--force` for skill/toml regeneration per README).
5. Confirm `manifest` shows the previous `bmad` version in `.lets-b-mad/install-manifest.json`.

**Note:** Rollback does not automatically downgrade git-ai or graphify unless you also revert `GITAI_VERSION` / `GRAPHIFY_VERSION` and re-run install.

## Gamification endpoint configuration

Phase 2 workflow gamification pushes completion events from `scripts/post-workflow.sh` to a GitLab OAuth-protected HTTP endpoint (office TV dashboard).

**Pin the URL** in `scripts/install.sh` (version block):

```sh
GAMIFICATION_EVENT_URL="https://gitlab.example.com/api/v4/projects/<id>/events"
```

Leave empty to disable pushes. Re-run `bash scripts/install.sh` to write `~/.lets-b-mad/gamification-endpoint` (mode `600`, URL only — no tokens).

**Credentials:** OAuth tokens live in the native git credential store (`git credential fill` / `approve`). Configure GitLab auth with your team's credential helper before expecting events to flow. Tokens are never written to lets-b-mad files or logs (NFR5, NFR6).

## Installation health validation

Run from the workspace root at any time:

```sh
bash /path/to/lets-b-mad/scripts/validate-installation.sh
```

Checks: global `bmad-*` skills, `_bmad/` workspace, `workspace.yaml`, manifest version pins, git-ai/graphify versions, central context freshness, graphify hooks per repo, and gamification endpoint file (when enabled). Exit **0** when healthy; **1** with remediation hints when not.

## Documentation quality

```sh
npx markdownlint-cli2 --no-globs docs/guide.md
```

Must exit **0**.
