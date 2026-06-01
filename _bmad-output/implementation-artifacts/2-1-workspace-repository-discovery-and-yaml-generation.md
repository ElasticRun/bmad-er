---
story_id: 2.1
story_key: 2-1-workspace-repository-discovery-and-yaml-generation
status: done
---

# Story 2.1: Workspace Repository Discovery & YAML Generation

Status: done

## Story

As a developer,
I want my workspace to auto-discover all git repositories and generate a YAML manifest,
so that BMAD workflows know which repositories are available for targeting.

## Acceptance Criteria

1. **Given** `scripts/lib/workspace.sh` is sourced  
   **When** `workspace_discover` is called with the workspace root path  
   **Then** it recursively scans for directories containing a `.git/` folder up to depth 3  
   **And** excludes well-known directories: `node_modules`, `.git`, `vendor`, `dist`, `build`, `.venv`, `__pycache__`  
   **And** completes within 5 seconds for workspaces with up to 50 repositories

2. **Given** repositories are discovered  
   **When** `workspace_generate_yaml` is called  
   **Then** a `workspace.yaml` file is created at the workspace root  
   **And** the schema includes: `workspace.name`, `workspace.root`, and `repos[]` with `path` (relative), `name`, `graphify_initialized` (boolean, default false)  
   **And** `yq` is used for all YAML operations

3. **Given** `workspace.yaml` is generated  
   **When** a developer opens it in an editor  
   **Then** the file is human-readable and manually editable  
   **And** entries use relative paths from workspace root

4. **Given** `workspace.yaml` exists  
   **When** a BMAD workflow reads it  
   **Then** it can determine available repositories and their relative paths

## Tasks / Subtasks

- [x] Task 1: Implement `scripts/lib/workspace.sh` discovery (AC: #1)
  - [x] Subtask 1.1: Constants — `WORKSPACE_YAML_NAME=workspace.yaml`, `WORKSPACE_MAX_DEPTH=3` (root=0; repos discoverable at depths 0–3 inclusive), exclude-dir list
  - [x] Subtask 1.1b: `workspace_path_for`, `workspace_is_excluded_dir`, `workspace_discover_file_for` (temp path helper)
  - [x] Subtask 1.2: `workspace_discover` — depth-limited recursive scan; detect `$dir/.git`; write sorted relative paths (`.` for workspace-root repo) to `$workspace_root/.lets-b-mad/.workspace-discovered`
  - [x] Subtask 1.3: `workspace_discovered_count` — prints count to stdout for tests; returns 0 on success
- [x] Task 2: Implement YAML generation (AC: #2, #3, #4)
  - [x] Subtask 2.1: `workspace_generate_yaml` — verify `yq` on PATH first; build YAML via `yq` `strenv()`; set `workspace.name` = basename of root, `workspace.root` = absolute path
  - [x] Subtask 2.2: Each repo entry: `path` (relative; `.` for workspace root repo), `name` = basename or workspace name when path is `.`, `graphify_initialized: false`
  - [x] Subtask 2.3: Write atomically to `$workspace_root/workspace.yaml` via `.tmp` + `mv`; on first run overwrite is acceptable (merge deferred to Story 2.2)
- [x] Task 3: Unit tests and quality gates (AC: all)
  - [x] Subtask 3.1: `tests/unit/test_workspace.sh` — fixture tree with nested repos, excluded dirs, depth limit
  - [x] Subtask 3.2: Assert schema fields via `yq`; assert relative paths; assert `graphify_initialized` defaults
  - [x] Subtask 3.3: `shellcheck -s sh scripts/lib/workspace.sh` — zero errors/warnings
- [x] Task 4: Project hygiene
  - [x] Subtask 4.1: Add `workspace.yaml` to `.gitignore` (generated at install time, not in repo)

## Dev Notes

### Architecture Context

- **Module:** `scripts/lib/workspace.sh` — sourced by `install.sh` (wired in Story 2.2 / install integration)
- **Requires:** `common.sh` sourced first; `yq` v4.53.2 on PATH (prerequisite from Epic 1)
- **POSIX sh only:** use `$3` for recursion depth directly (global `current_depth` clobbers parent frames)
- **yq v4 API:** use `strenv(VAR)` with `export VAR=...` before command substitution (not `--arg`)

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Notes:** Fixed recursion depth via positional `$3`; yq v4 `strenv` + export pattern; unset exported vars after YAML write.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 2-1-workspace-repository-discovery-and-yaml-generation |
| code | cursor/composer-2.5-fast | 2-1-workspace-repository-discovery-and-yaml-generation |
| test | cursor/composer-2.5-fast | 2-1-workspace-repository-discovery-and-yaml-generation |
| review | cursor/composer-2.5-fast | 2-1-workspace-repository-discovery-and-yaml-generation |

## Dev Agent Record

### Completion Notes

- Implemented workspace discovery with depth-limited recursion and exclude-dir skipping
- YAML generation via mikefarah yq v4 `strenv()` pattern
- Unit tests cover depth limit, exclusions, and schema validation

### File List

- scripts/lib/workspace.sh (NEW)
- tests/unit/test_workspace.sh (NEW)
- .gitignore (MODIFIED)

## Change Log

- 2026-06-01: Story 2.1 implementation complete

## Status

done
