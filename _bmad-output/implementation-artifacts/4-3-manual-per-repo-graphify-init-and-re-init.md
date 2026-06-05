---
story_id: 4.3
story_key: 4-3-manual-per-repo-graphify-init-and-re-init
status: done
baseline_commit: fb4ff941a8699cacc3d3f4bfa63e37c69309a1d8
---

# Story 4.3: Manual Per-Repo graphify Init & Re-Init

Status: done

## Story

As a developer,
I want to manually initialize or re-initialize graphify for a specific repository after adding a repo mid-sprint,
so that new repos become first-class graphify targets without re-running the full installer.

## Acceptance Criteria

1. **Given** `scripts/graphify-init-repo.sh` exists and is executable  
   **When** a developer invokes it with a repository path relative to workspace root (e.g., `bash scripts/graphify-init-repo.sh projects/api`)  
   **Then** it resolves workspace root via `LETS_B_MAD_WORKSPACE` or current working directory  
   **And** validates the path exists in `workspace.yaml` `repos[].path` (FR18a)  
   **And** validates the path is a valid graphify target for the active layout  
   **And** runs `deps_graphify_init` on the resolved disk path (reuses `graphify update . --no-cluster`)  
   **And** on success sets `graphify_initialized: true` via `workspace_set_graphify_initialized`

2. **Given** manual init succeeds on a repo with `graphify_initialized: false`  
   **When** the command completes  
   **Then** that repo's YAML entry shows `graphify_initialized: true`

3. **Given** a repo already has `graphify_initialized: true`  
   **When** manual init is invoked again (re-init)  
   **Then** it still runs `deps_graphify_init` (does not skip)  
   **And** refreshes `graphify-out/graph.json`  
   **And** leaves `graphify_initialized: true`

4. **Given** a developer adds a new nested repo via re-discovery (Story 2.2) with `graphify_initialized: false`  
   **When** they invoke manual init with optional `--hooks`  
   **Then** graphify indexes the repo and YAML reflects initialized state  
   **And** with `--hooks`, `hooks_install_repo` runs for that repo only after successful init

5. **Given** manual init is run with path `.` in **multi-repo** layout (any nested repo exists in YAML)  
   **When** validation runs  
   **Then** it rejects with a clear error: workspace root is not a graphify target in multi-repo layout  
   **And** exits non-zero without running graphify

6. **Given** path `.` in **standalone** layout (only workspace-root repo entry)  
   **When** manual init is invoked  
   **Then** it initializes graphify at workspace root successfully

7. **Given** graphify is not on PATH, path not in YAML, or path is not a git repo  
   **When** manual init runs  
   **Then** it logs a clear error and exits non-zero without partial YAML updates

8. **Given** the script and any new lib helpers  
   **When** analyzed by `shellcheck -s sh`  
   **Then** zero errors or warnings

## Tasks / Subtasks

- [x] Task 1: Layout + target validation helpers in `scripts/lib/workspace.sh` (AC: #5, #6)
  - [x] Subtask 1.1: `workspace_get_layout` — read `workspace.layout` from YAML; if missing, infer `multi-repo` when any `repos[].path != "."`, else `standalone`
  - [x] Subtask 1.2: `workspace_yaml_has_repo_path` — returns 0 when `rel_path` exists in `repos[].path`
  - [x] Subtask 1.3: `workspace_is_graphify_target` — multi-repo rejects `.`; standalone allows `.`; path must exist in YAML
- [x] Task 2: `graphify_init_target_repo` in `scripts/lib/dependencies.sh` (AC: #1–#3, #5–#7)
  - [x] Subtask 2.1: Validate layout + membership via workspace helpers; resolve disk path via `_workspace_repo_disk_path`
  - [x] Subtask 2.2: Call `deps_graphify_init`; on success call `workspace_set_graphify_initialized`; return non-zero if init ok but YAML update fails
- [x] Task 3: CLI `scripts/graphify-init-repo.sh` (AC: #1, #4)
  - [x] Subtask 3.1: Parse `--hooks` and repo path args; usage message on invalid input
  - [x] Subtask 3.2: Source lib modules; call `graphify_init_target_repo`; on success with `--hooks`, source `hooks.sh` and call `hooks_install_repo`
- [x] Task 4: Unit tests and quality gates (AC: all)
  - [x] Subtask 4.1: `tests/unit/test_graphify_init_repo.sh` — multi-repo init, re-init, reject `.`, standalone `.`, `--hooks`, missing path
  - [x] Subtask 4.2: Extend `tests/unit/test_workspace.sh` for layout helpers
  - [x] Subtask 4.3: `shellcheck -s sh` on new/changed scripts

### Review Findings

- [x] [Review][Patch] Normalize trailing slashes on repo path argument [scripts/graphify-init-repo.sh] — applied `${repo_path%/}`

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-05

**Notes:** Reuses deps_graphify_init and workspace_set_graphify_initialized; layout validation rejects workspace root in multi-repo before YAML lookup; `--hooks` isolated in CLI to avoid circular lib deps; re-init always runs graphify update.

## Dev Notes

### Architecture Context

- **Reuse:** `deps_graphify_init`, `workspace_set_graphify_initialized`, `hooks_install_repo`
- **Layout rules:** standalone → target is workspace root (`path: "."`); multi-repo → nested repos only
- **Workspace env:** `LETS_B_MAD_WORKSPACE` overrides cwd

## Dev Agent Record

### Agent Model Used

cursor/composer-2.5-fast

### Completion Notes

- Added workspace layout helpers and `graphify_init_target_repo`
- Created `scripts/graphify-init-repo.sh` with `--hooks` support
- Unit tests pass for story 4.3; shellcheck clean

### File List

- scripts/lib/workspace.sh (MODIFIED)
- scripts/lib/dependencies.sh (MODIFIED)
- scripts/graphify-init-repo.sh (NEW)
- tests/unit/test_graphify_init_repo.sh (NEW)
- tests/unit/test_workspace.sh (MODIFIED)

## Change Log

- 2026-06-05: Story 4.3 implementation complete; code review patch applied (path normalization)

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 4-3-manual-per-repo-graphify-init-and-re-init |
| review-story | cursor/composer-2.5-fast | 4-3-manual-per-repo-graphify-init-and-re-init |
| code | cursor/composer-2.5-fast | 4-3-manual-per-repo-graphify-init-and-re-init |
| review-code | cursor/composer-2.5-fast | 4-3-manual-per-repo-graphify-init-and-re-init |
