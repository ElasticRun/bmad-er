# Test Automation Summary

**Project:** lets-b-mad  
**Date:** 2026-06-01  
**Framework:** POSIX `sh` unit tests (`tests/unit/test_*.sh`)

## Generated / Updated Tests

### Epic 1 — Foundation & Installation

| Story | Test file | Coverage |
| --- | --- | --- |
| 1.1 Repository structure | `test_repo_structure.sh`, `test_common.sh` | Dirs, shellcheckrc, logging, checksums, exit codes, summary table |
| 1.2 Install manifest | `test_manifest.sh` | Init, managed/protected, modified detection |
| 1.3 Prerequisites | `test_prerequisites.sh` | Version compare, check-all, brew-missing exit |
| 1.4 BMAD & skills | `test_bmad.sh` | Skill deploy, workspace preserve, TOML paths, IDE warning |
| 1.5 Install orchestrator | `test_install.sh` | Help, version pins, lib sourcing, continue-on-failure |

### Epic 2 — Workspace Discovery

| Story | Test file | Coverage |
| --- | --- | --- |
| 2.1 YAML generation | `test_workspace.sh` | Discovery depth, schema, relative paths |
| 2.2 Merge semantics | `test_workspace.sh` | Annotations, graphify flag, missing paths |

### Epic 3 — git-ai

| Story | Test file | Coverage |
| --- | --- | --- |
| 3.1 Global install | `test_dependencies.sh` | Pin/skip, upgrade, failure exit 30-39 |
| 3.2 AI stats | `test_ai_stats_summary.sh` | Per-repo output, missing YAML |

### Epic 4 — graphify

| Story | Test file | Coverage |
| --- | --- | --- |
| 4.1 Install & init | `test_dependencies.sh`, `test_graphify_init.sh` | Install skip/fail, YAML flag |
| 4.2 Hooks | `test_hooks.sh` | Conflicts, verify, idempotent install |

### Epic 5 — Context & hooks

| Story | Test file | Coverage |
| --- | --- | --- |
| 5.1 Context clone | `test_context.sh` | Clone, pull, failures |
| 5.2 Pre-workflow | `test_pre_workflow.sh` | Pull, retry, hard block, self-contained |
| 5.3 Post-workflow | `test_post_workflow.sh` | Stub, non-blocking, extensions |

### Epic 6 — Documentation

| Story | Test file | Coverage |
| --- | --- | --- |
| 6.1 README | `test_docs.sh` | Preflight, install, do-not, success criteria |
| 6.2 Guide | `test_docs.sh` | Contributing, upgrade, markdownlint (optional) |

### Epic 7 — Gamification & validation

| Story | Test file | Coverage |
| --- | --- | --- |
| 7.1 Event push | `test_post_workflow.sh` | Credentials, fail-open, endpoint config |
| 7.2 Health check | `test_validate_installation.sh` | Pass/fail fixture, pin reader |

## Coverage

- **Stories epics 1–7:** 18/18 story files mapped to unit tests
- **Test suites:** 16 files under `tests/unit/`
- **Run command:** `for f in tests/unit/test_*.sh; do sh "$f"; done`

## Fixes Applied During Run

- **`scripts/lib/bmad.sh`:** `skills_changed` now uses exit code from `bmad_skills_checksum_changed` (fixes `integer expression expected` and restores IDE restart warning).

## E2E Tests (shuru sandbox)

| Test | Runner | Coverage |
| --- | --- | --- |
| Developer onboarding | `tests/e2e/run-developer-onboarding-shuru.sh` | Clone `dont-b-mad@lets-b-mad`, workspace, `install.sh`, global skills, `validate-installation.sh` in Linux VM via [shuru](https://shuru.run/) |

**Checkpoint (one-time per machine):** `tests/e2e/create-shuru-checkpoint.sh` → `lets-b-mad-linux-prereqs` (apt + jq + yq + uv). Recipe in repo: `tests/e2e/shuru-bootstrap-prereqs.sh`.

**Run:** `tests/e2e/run-developer-onboarding-shuru.sh` uses `shuru run --from lets-b-mad-linux-prereqs` when the checkpoint exists (~3–4 min); without it, slow path installs prereqs each run (~5–6 min).

**Latest run:** `_bmad-output/implementation-artifacts/tests/runs/developer-onboarding-shuru-2026-06-01.md`

## Next Steps

- Run suites in CI on every PR
- Add `markdownlint-cli2` to CI for doc tests when tool is available
- Linux onboarding: fix `yq --version` parsing for mikefarah binary; optional HTTPS central-context on fresh machines
