---
story_id: 7.1
story_key: 7-1-gamification-event-push-and-credential-management
status: done
---

# Story 7.1: Gamification Event Push & Credential Management

Status: done

## Story

As a developer,
I want workflow completion events pushed to the team dashboard after every BMAD workflow,
so that my contributions are visible on the office TV and team engagement is gamified.

## Acceptance Criteria

1. **Given** `post-workflow.sh` is extended with gamification logic  
   **When** a BMAD workflow completes successfully  
   **Then** it pushes an event (workflow name + user auth context) to the configured GitLab OAuth-protected endpoint

2. **Given** the gamification endpoint requires authentication  
   **When** `post-workflow.sh` needs credentials  
   **Then** it retrieves them via `git credential fill` (never stored in plaintext — NFR5, NFR6)  
   **And** stores approved credentials via `git credential approve` for future use

3. **Given** the event push fails (network error, endpoint down, auth failure)  
   **When** the failure is detected  
   **Then** the script logs a warning but continues (fail-open, non-blocking — FR39)  
   **And** the developer's workflow is not affected  
   **And** no retry loop is attempted (fire-and-forget)

4. **Given** the gamification endpoint URL  
   **When** inspected in the configuration  
   **Then** it is declared in the version/config block of `install.sh` or a dedicated config file  
   **And** is never hardcoded in `post-workflow.sh` directly

5. **Given** credential retrieval via `git credential fill`  
   **When** no stored credential exists  
   **Then** the event push is skipped with a warning (not a blocking error)  
   **And** no interactive prompt is displayed

## Tasks / Subtasks

- [x] Task 1: Declare gamification endpoint in install config (AC: #4)
  - [x] Subtask 1.1: Add `GAMIFICATION_EVENT_URL` to `install.sh` version pins block (empty string = disabled)
  - [x] Subtask 1.2: Add `install_write_gamification_config()` called from `install.sh` main flow; write URL-only to `~/.lets-b-mad/gamification-endpoint` with mode `600`
  - [x] Subtask 1.3: Document variable in `docs/guide.md` (Configuration section)
- [x] Task 2: Implement gamification push in `post-workflow.sh` (AC: #1–#3, #5)
  - [x] Subtask 2.1–2.7: Gamification push with git credential fill/approve, fail-open curl
- [x] Task 3: Unit tests `tests/unit/test_post_workflow.sh` (AC: all)
- [x] Task 4: `shellcheck` on changed shell scripts

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Findings addressed:**

- JSON payload fields strip control characters before escaping.
- Unit test for missing credentials uses empty fill stub (avoids `exit` in eval killing the script).

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 7-1-gamification-event-push-and-credential-management |
| code | cursor/composer-2.5-fast | 7-1-gamification-event-push-and-credential-management |
| test | cursor/composer-2.5-fast | 7-1-gamification-event-push-and-credential-management |
| review | cursor/composer-2.5-fast | 7-1-gamification-event-push-and-credential-management |

## Dev Agent Record

### Agent Model Used

cursor/composer-2.5-fast

### Completion Notes List

- Implemented `_post_workflow_push_gamification` with endpoint file, git credential fill/approve, and fail-open curl POST.
- `install.sh` writes `~/.lets-b-mad/gamification-endpoint` from `GAMIFICATION_EVENT_URL` pin.
- Extended unit tests; all `tests/unit/test_*.sh` pass.

### File List

- scripts/install.sh (MODIFIED)
- scripts/post-workflow.sh (MODIFIED)
- tests/unit/test_post_workflow.sh (MODIFIED)
- docs/guide.md (MODIFIED)

## Change Log

- 2026-06-01: Story 7.1 complete — gamification event push and credential management

## Status

done
