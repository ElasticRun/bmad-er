---
story_id: 2.2
story_key: 2-2-incremental-re-discovery-with-merge-semantics
status: done
---

# Story 2.2: Incremental Re-Discovery with Merge Semantics

Status: done

## Story

As a developer,
I want to re-run repository discovery after cloning new repos without losing existing YAML entries or customizations,
so that my workspace stays current as I add new projects.

## Acceptance Criteria

1. **Given** `workspace.yaml` exists with 4 repository entries (some with annotations)  
   **When** a developer clones a new repo and runs `workspace_discover`  
   **Then** the new repo is added to `workspace.yaml`  
   **And** all existing entries are preserved unchanged (merge-not-overwrite)  
   **And** developer-added annotations on existing entries are not removed

2. **Given** a repo was previously in `workspace.yaml` but the directory no longer exists  
   **When** `workspace_discover` runs  
   **Then** the missing repo entry is preserved in the YAML (not removed)  
   **And** a warning is logged that the path no longer exists

3. **Given** `workspace.yaml` has an entry for `repos/api` with `graphify_initialized: true`  
   **When** re-discovery finds the same repo  
   **Then** the existing `graphify_initialized: true` value is preserved (not reset to false)

## Tasks / Subtasks

- [x] Task 1: Merge-aware YAML generation (AC: #1, #2, #3)
- [x] Task 2: Orchestrate re-discovery entry point (AC: all)
- [x] Task 3: Unit tests (AC: all)

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Notes:** Merge preserves full repo objects for existing paths; missing paths warn via log_warn; install.sh wired with workspace_rediscover step.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 2-2-incremental-re-discovery-with-merge-semantics |
| code | cursor/composer-2.5-fast | 2-2-incremental-re-discovery-with-merge-semantics |
| test | cursor/composer-2.5-fast | 2-2-incremental-re-discovery-with-merge-semantics |
| review | cursor/composer-2.5-fast | 2-2-incremental-re-discovery-with-merge-semantics |

## Dev Agent Record

### Completion Notes

- Added workspace_merge_yaml, workspace_rediscover; refactored create vs merge paths
- install.sh sources workspace.sh and runs Workspace YAML install step
- Tests cover annotation preservation, graphify_initialized, missing path warn, new repo append

### File List

- scripts/lib/workspace.sh (MODIFIED)
- scripts/install.sh (MODIFIED)
- tests/unit/test_workspace.sh (MODIFIED)

## Change Log

- 2026-06-01: Story 2.2 implementation complete

## Status

done
