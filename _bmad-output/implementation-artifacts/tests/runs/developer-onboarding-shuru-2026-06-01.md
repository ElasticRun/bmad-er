# E2E Run: Developer onboarding (shuru VM)

**Target:** Fresh Linux developer — clone `dont-b-mad` (`lets-b-mad` branch), workspace setup, `install.sh`, skill placement, `validate-installation.sh`

**Agent:** cursor/composer-2.5-fast  
**Sandbox:** [shuru](https://shuru.run/) 0.6.3 (ephemeral VM, `--allow-net`, 4 CPU / 4096 MB)  
**Run timestamp:** 2026-06-01 (UTC logs: `developer-onboarding-shuru-2026-06-01T091238Z.log`)

## Commands

```sh
tests/e2e/run-developer-onboarding-shuru.sh
# → shuru run --allow-net --mount tests/e2e:/e2e:ro -- sh /e2e/developer-onboarding-vm.sh
```

## Scenario

1. Root creates user `devuser` with home `/home/devuser`
2. Apt bootstrap + pinned `jq`/`yq`/`uv` under `/usr/local/bin`
3. `git clone https://github.com/elasticrun/dont-b-mad --branch lets-b-mad` → `~/tools/lets-b-mad`
4. Workspace `~/workspaces/my-bmad-workspace` with sample git repo
5. `bash ~/tools/lets-b-mad/scripts/install.sh` from workspace root
6. Assert `workspace.yaml`, `.lets-b-mad/install-manifest.json`, `_bmad/`, global `bmad-*` skills
7. `bash ~/tools/lets-b-mad/scripts/validate-installation.sh`

## Results

| Step | Result |
| --- | --- |
| Clone lets-b-mad | **PASS** |
| Create workspace + sample repo | **PASS** |
| `install.sh` exit code | **0** (continue-on-failure; see partial step failures below) |
| `workspace.yaml` + manifest | **PASS** |
| Global skills `~/.cursor/skills`, `~/.claude/skills` | **PASS** (54 `bmad-*` each) |
| `_bmad/` at workspace root | **PASS** |
| `validate-installation.sh` | **FAIL** (exit 1) — 10 pass, 2 fail |

### install.sh step summary (Linux VM)

| Step | Status | Notes |
| --- | --- | --- |
| Prerequisites | FAIL | `uv`/`yq` — installer uses Homebrew paths; Linux needs manual/apt bootstrap |
| BMAD Install | PASS | 6.8.0 |
| Global Skills | PASS | Cursor + Claude |
| BMAD Workspace | PASS | `_bmad/` deployed |
| Customize TOML | PASS | |
| git-ai | PASS | 1.5.2 |
| Workspace YAML | PASS | 1 repo discovered |
| graphify | FAIL | `uv not found` on PATH during install |
| Central Context | FAIL | `git@github.com:elasticrun/central-context.git` — SSH host key / no keys |

### validate-installation failures

- **graphify binary** — not on PATH (install step failed)
- **Central context** — clone requires GitHub SSH access

## Exit codes (E2E harness)

| Code | Meaning |
| --- | --- |
| 0 | All assertions + full validation pass |
| 1 | Assertion failure (clone, workspace, skills) |
| 2 | `install.sh` non-zero |
| 3 | Core onboarding OK; `validate-installation.sh` incomplete |

**Last run exit:** 3

## Findings for DX

1. **Documented platform is macOS + Homebrew** — Linux/shuru runs need explicit prereq bootstrap (see `tests/e2e/developer-onboarding-vm.sh`).
2. **Central context** requires SSH to `elasticrun/central-context` — fresh machines need `ssh-keyscan` + deploy keys or HTTPS fallback.
3. **graphify** depends on `uv` — must be on PATH before install on Linux (`/usr/local/bin` bootstrap added in E2E script).
4. **yq version check** may not parse mikefarah `yq` Linux `--version` string (shows as FAIL in prereqs even when binary is 4.53.2).
5. **Core BMAD onboarding works on Linux** without Docker: clone → workspace → install → 54 global skills per IDE.

## Pass/fail counts

- E2E assertions: **4/4 pass**
- `validate-installation`: **10 pass / 2 fail**
