---
story_id: 4.1
story_key: 4-1-graphify-global-installation-and-per-repo-initialization
status: done
---

# Story 4.1: graphify Global Installation & Per-Repo Initialization

Status: done

## Story

As a developer,
I want graphify installed and initialized for my repositories,
so that AI agents have an always-current knowledge graph of my codebase to produce better code.

## Acceptance Criteria

1. **Given** `scripts/lib/dependencies.sh` is sourced  
   **When** `deps_install_graphify` is called with the pinned version from `install.sh`  
   **Then** it installs graphify via `uv tool install 'graphifyy=={version}'` (PyPI package `graphifyy`, CLI `graphify`)  
   **And** the installed version is recorded in the install manifest under `versions.graphify`

2. **Given** graphify is already installed at the correct pinned version  
   **When** `deps_install_graphify` is called again  
   **Then** the installation is skipped (idempotent)  
   **And** a pass is logged indicating graphify is already present

2b. **Given** graphify is installed at a different version than the pin  
   **When** `deps_install_graphify` is called  
   **Then** it re-runs the pinned `uv tool install --force`  
   **And** verifies the post-install version matches the pin

3. **Given** graphify is installed and `workspace.yaml` exists with discovered repos  
   **When** `deps_graphify_init_all` is called with the workspace root  
   **Then** for each repo where `graphify_initialized` is not `true`, it runs `deps_graphify_init` with that repo's disk path  
   **And** skips repos already marked `graphify_initialized: true`

4. **Given** graphify is installed  
   **When** `deps_graphify_init` is called with a repository path  
   **Then** it runs `graphify update . --no-cluster` in that repo (AST-only extraction, no LLM/API keys required at install time)  
   **And** treats success as presence of `graphify-out/graph.json` after the command  
   **And** updates the workspace YAML entry for that repo: `graphify_initialized: true` via `workspace_set_graphify_initialized`

5. **Given** graphify installation fails (uv missing, network failure, uv error)  
   **When** the install function returns  
   **Then** it returns a non-zero code `$EXIT_DEP_GRAPHIFY_FAILED` (31)  
   **And** logs the failure for the summary table  
   **And** does not prevent other installation steps from proceeding (orchestrator uses `|| true`)

6. **Given** graphify init fails for one repo (graphify error, permissions)  
   **When** `deps_graphify_init_all` processes repos  
   **Then** it logs a warning for that repo and continues with remaining repos  
   **And** does not set `graphify_initialized: true` for failed repos  
   **And** returns 0 if at least one repo initialized successfully OR all repos were already `graphify_initialized: true`  
   **And** returns non-zero only when every repo needing init failed (none succeeded)

7. **Given** `workspace.yaml` does not exist or graphify is not on PATH  
   **When** `deps_graphify_init_all` is called  
   **Then** it logs a warning and returns 0 (no-op) without failing the install orchestrator

## Tasks / Subtasks

- [x] Task 1: Implement `deps_install_graphify` in `scripts/lib/dependencies.sh` (AC: #1, #2, #2b, #5)
- [x] Task 2: Per-repo init + YAML flag (AC: #3, #4, #6, #7)
- [x] Task 3: Wire into `scripts/install.sh` (AC: #1, #3, #5)
- [x] Task 4: Unit tests and quality gates (AC: all)

## Senior Developer Review (AI)

**Outcome:** Approve (after fixes)  
**Date:** 2026-06-01

**Action items addressed:**
- Added `uv tool install --force` on version mismatch reinstall (AC 2b)
- Documented workspace.sh sourcing requirement for graphify init helpers
- Fixed unit test PATH isolation regression in `test_install_failure_exit_code`

## Dev Notes

### Architecture Context

- **Module:** `scripts/lib/dependencies.sh` + `scripts/lib/workspace.sh`
- **Exit code:** `$EXIT_DEP_GRAPHIFY_FAILED` = 31
- **Version pin:** `GRAPHIFY_VERSION="0.8.27"` in `install.sh`

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 4-1-graphify-global-installation-and-per-repo-initialization |
| code | cursor/composer-2.5-fast | 4-1-graphify-global-installation-and-per-repo-initialization |
| test | cursor/composer-2.5-fast | 4-1-graphify-global-installation-and-per-repo-initialization |
| review | cursor/composer-2.5-fast | 4-1-graphify-global-installation-and-per-repo-initialization |

## Dev Agent Record

### Completion Notes

- Implemented deps_install_graphify, deps_graphify_init, deps_graphify_init_all with test hooks
- Added workspace_set_graphify_initialized
- Wired install_step_graphify and install_step_graphify_init after workspace YAML

### File List

- scripts/lib/dependencies.sh (MODIFIED)
- scripts/lib/workspace.sh (MODIFIED)
- scripts/install.sh (MODIFIED)
- tests/unit/test_dependencies.sh (MODIFIED)
- tests/unit/test_graphify_init.sh (NEW)

## Change Log

- 2026-06-01: Story 4.1 implementation complete

## Status

done
