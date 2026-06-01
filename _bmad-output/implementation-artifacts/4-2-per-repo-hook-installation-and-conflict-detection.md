---
story_id: 4.2
story_key: 4-2-per-repo-hook-installation-and-conflict-detection
status: done
---

# Story 4.2: Per-Repo Hook Installation & Conflict Detection

Status: done

## Story

As a developer,
I want graphify git hooks installed automatically in each discovered repository,
so that my knowledge graph rebuilds on every commit and branch switch without manual action.

## Acceptance Criteria

1. **Given** `scripts/lib/hooks.sh` is sourced and `workspace.yaml` lists discovered repos  
   **When** `hooks_install_all` is called with the workspace root  
   **Then** it runs `graphify hook install` for each repo entry in `workspace.yaml`  
   **And** verifies installation via `graphify hook status` per repo (both `post-commit` and `post-checkout` show `installed`)

2. **Given** a repository has existing non-graphify hooks (e.g., a custom `post-commit` without `graphify-hook-start`)  
   **When** `hooks_install_all` processes that repository  
   **Then** a warning is logged identifying the conflicting hook name and repo path  
   **And** graphify hook installation still proceeds (graphify chains existing hooks)

3. **Given** graphify hooks are already installed for a repository (`graphify hook status` reports both hooks installed)  
   **When** `hooks_install_all` is run again  
   **Then** it is idempotent — no duplicate hook errors, verification passes

4. **Given** graphify is not on PATH or `workspace.yaml` is missing  
   **When** `hooks_install_all` is called  
   **Then** it logs a warning and returns 0 (no-op) without failing the orchestrator

5. **Given** hook install fails for one repo  
   **When** `hooks_install_all` processes repos  
   **Then** it logs a warning, continues other repos, returns 0 if at least one repo succeeded  
   **And** returns `$EXIT_HOOK_INSTALL_FAILED` (50) only when every repo fails

6. **Given** NFR14–NFR15 (graceful hook failure, no git corruption)  
   **When** hooks run at commit/checkout time  
   **Then** behavior is delegated to graphify's hook scripts — lets-b-mad does not wrap or modify hook bodies (install + verify only)

## Tasks / Subtasks

- [x] Task 1: Implement `scripts/lib/hooks.sh` (AC: #1–#6)
- [x] Task 2: Wire `install_step_hooks` in `scripts/install.sh` after graphify init (AC: #1)
- [x] Task 3: Unit tests (AC: all)

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Notes:** Idempotent path verifies status before install; conflicts warn-only; test hooks for install/status; delegated runtime behavior to graphify per NFR14–15.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 4-2-per-repo-hook-installation-and-conflict-detection |
| code | cursor/composer-2.5-fast | 4-2-per-repo-hook-installation-and-conflict-detection |
| test | cursor/composer-2.5-fast | 4-2-per-repo-hook-installation-and-conflict-detection |
| review | cursor/composer-2.5-fast | 4-2-per-repo-hook-installation-and-conflict-detection |

## Dev Agent Record

### Completion Notes

- Implemented hooks.sh with conflict detection, install, verify, install_all
- Wired install_step_hooks after graphify init in install.sh

### File List

- scripts/lib/hooks.sh (NEW)
- scripts/install.sh (MODIFIED)
- tests/unit/test_hooks.sh (NEW)

## Change Log

- 2026-06-01: Story 4.2 implementation complete

## Status

done
