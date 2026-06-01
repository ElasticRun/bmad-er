---
story_id: 3.2
story_key: 3-2-local-ai-stats-summary-script
status: done
---

# Story 3.2: Local AI Stats Summary Script

Status: done

## Story

As a developer,
I want to view a summary of git-ai statistics for my repositories,
so that I can track AI code attribution and durability metrics locally without waiting for an external dashboard.

## Acceptance Criteria

1. **Given** `scripts/ai-stats-summary.sh` exists and is executable  
   **When** a developer runs it from the workspace root  
   **Then** it reads `workspace.yaml` to find all repositories  
   **And** runs `git ai stats --json` per repo  
   **And** outputs a formatted summary of AI attribution metrics

2. **Given** git-ai has no data for a repository (new repo, no AI commits, or stats command fails)  
   **When** the summary script processes that repo  
   **Then** it reports "No git-ai data" for that entry without failing  
   **And** continues processing remaining repos

3. **Given** the summary script is run  
   **When** it completes  
   **Then** it displays per-repo metrics including: AI-generated code percentage, AI-attributed lines, and accepted AI lines  
   **And** exits with 0 on success

4. **Given** the script file  
   **When** analyzed by `shellcheck`  
   **Then** zero errors or warnings are reported under POSIX sh rules

5. **Given** `workspace.yaml` is missing  
   **When** the script runs  
   **Then** it prints an error to stderr and exits non-zero

## Tasks / Subtasks

- [x] Task 1: Implement `scripts/ai-stats-summary.sh` (AC: #1, #2, #3, #5)
- [x] Task 2: Quality gates (AC: #4)
- [x] Task 3: Unit tests (AC: all)

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Notes:** Self-contained runtime script; per-repo failures degrade to "No git-ai data"; missing workspace.yaml exits 1.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 3-2-local-ai-stats-summary-script |
| code | cursor/composer-2.5-fast | 3-2-local-ai-stats-summary-script |
| test | cursor/composer-2.5-fast | 3-2-local-ai-stats-summary-script |
| review | cursor/composer-2.5-fast | 3-2-local-ai-stats-summary-script |

## Dev Agent Record

### Completion Notes

- Implemented ai-stats-summary.sh with yq/jq parsing and formatted table output
- Unit tests with mock git binary for stats JSON and failure paths

### File List

- scripts/ai-stats-summary.sh (NEW)
- tests/unit/test_ai_stats_summary.sh (NEW)

## Change Log

- 2026-06-01: Story 3.2 implementation complete

## Status

done
