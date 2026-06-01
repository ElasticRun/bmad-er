---
story_id: 5.1
story_key: 5-1-central-context-repository-cloning
status: done
---

# Story 5.1: Central Context Repository Cloning

Status: done

## Story

As a developer,
I want the central context repository cloned during installation,
so that organizational standards, ADRs, and data dictionary are available locally for every BMAD workflow.

## Acceptance Criteria

1. **Given** `scripts/lib/context.sh` is sourced  
   **When** `context_clone` is called with the repo URL from `install.sh`  
   **Then** it clones the central context git repository to `~/.lets-b-mad/central-context/`  
   **And** uses the developer's existing git SSH keys or credential manager (NFR7)  
   **And** the repo URL is declared in the version configuration block of `install.sh`

2. **Given** `~/.lets-b-mad/central-context/` already exists from a previous install  
   **When** `context_clone` is called  
   **Then** it performs `git pull --ff-only` instead of a fresh clone (idempotent)  
   **And** logs a pass if pull succeeds

3. **Given** the central context clone fails (network error, auth failure)  
   **When** the install function returns  
   **Then** it returns `$EXIT_CONTEXT_CLONE_FAILED` (40)  
   **And** logs the failure for the summary table  
   **And** does not prevent other installation steps from proceeding (orchestrator uses `|| true`)

4. **Given** a central context author commits a new ADR to the central repo  
   **When** the next developer's install or context pull runs  
   **Then** the new ADR is available locally in `~/.lets-b-mad/central-context/`

## Tasks / Subtasks

- [x] Task 1: Implement `scripts/lib/context.sh` (AC: #1, #2, #3)
  - [x] Subtask 1.1: `context_dir` — returns `$HOME/.lets-b-mad/central-context`
  - [x] Subtask 1.2: `context_clone repo_url` — clone if missing, else `git pull --ff-only`
  - [x] Subtask 1.3: If path exists but is not a git repo, log error and return 40 (do not silently overwrite)
  - [x] Subtask 1.4: Test hooks `CONTEXT_CLONE_CMD` / `CONTEXT_PULL_CMD` for unit tests (no network)
  - [x] Subtask 1.5: Return `$EXIT_CONTEXT_CLONE_FAILED` (40) on failure; log via `log_success` on pass
- [x] Task 2: Wire into `scripts/install.sh` (AC: #1, #3)
  - [x] Subtask 2.1: Add `CENTRAL_CONTEXT_REPO_URL` pin alongside other version pins
  - [x] Subtask 2.2: Source `context.sh`; add `install_step_context` with summary pass/fail
  - [x] Subtask 2.3: Call after graphify steps, before summary (continue-on-failure via `|| true`)
- [x] Task 3: Unit tests `tests/unit/test_context.sh` (AC: all)
  - [x] Subtask 3.1: Fresh clone path (mock git)
  - [x] Subtask 3.2: Existing dir → pull idempotency
  - [x] Subtask 3.3: Failure returns exit 40

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

No blocking findings after implementation review.

## Dev Notes

### Architecture Context

- **Module:** `scripts/lib/context.sh` — install-time only; requires `common.sh` sourced first
- **Exit code:** `$EXIT_CONTEXT_CLONE_FAILED` = 40 (already defined in `common.sh`)
- **Global path:** `$HOME/.lets-b-mad/central-context/` — fixed, not workspace-relative
- **Repo URL pin:** `CENTRAL_CONTEXT_REPO_URL="git@github.com:elasticrun/central-context.git"` in `install.sh` version block
- **Auth:** Use plain `git clone` / `git pull --ff-only` — no custom credential layer (NFR7)
- **Non-git path:** If `context_dir` exists but `.git` is missing, fail with exit 40 and actionable log message (never `rm -rf` user data)

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 5-1-central-context-repository-cloning |
| code | cursor/composer-2.5-fast | 5-1-central-context-repository-cloning |
| test | cursor/composer-2.5-fast | 5-1-central-context-repository-cloning |
| review | cursor/composer-2.5-fast | 5-1-central-context-repository-cloning |

## Dev Agent Record

### Completion Notes

- Implemented context_dir, context_clone with clone/pull idempotency and test hooks
- Wired install_step_context with continue-on-failure
- Added unit tests for clone, pull, non-git dir, and failure exit codes

### File List

- scripts/lib/context.sh (NEW)
- scripts/install.sh (MODIFIED)
- tests/unit/test_context.sh (NEW)

## Change Log

- 2026-06-01: Story 5.1 implementation complete

## Status

done
