---
story_id: 3.1
story_key: 3-1-git-ai-global-installation
status: done
---

# Story 3.1: git-ai Global Installation

Status: done

## Story

As a developer,
I want git-ai installed globally at a pinned version during workspace setup,
so that every commit I make automatically tracks AI code attribution with no manual action required.

## Acceptance Criteria

1. **Given** `scripts/lib/dependencies.sh` is sourced  
   **When** `deps_install_gitai` is called with the pinned version from `install.sh`  
   **Then** it installs git-ai via `curl -sSL https://usegitai.com/install.sh | bash` with `GIT_AI_RELEASE_TAG=v{version}` exported for the install subprocess  
   **And** the installed version is recorded in the install manifest under `versions.gitai`

2. **Given** git-ai is installed successfully  
   **When** a developer makes a commit in any repository  
   **Then** git-ai automatically tracks AI code attribution per commit via its global hooks  
   **And** no per-workflow or per-repo configuration from lets-b-mad is required (delegated to git-ai install — verify binary on PATH after install)

3. **Given** git-ai is already installed at the correct pinned version  
   **When** `deps_install_gitai` is called again  
   **Then** the installation is skipped (idempotent)  
   **And** a pass is logged indicating git-ai is already present

3b. **Given** git-ai is installed at a different version than the pin  
   **When** `deps_install_gitai` is called  
   **Then** it re-runs the pinned install (same curl path with `GIT_AI_RELEASE_TAG`)  
   **And** verifies the post-install version matches the pin

4. **Given** git-ai installation fails (network error, curl failure)  
   **When** the install function returns  
   **Then** it returns a non-zero code in the 30-39 range (`EXIT_DEP_GITAI_FAILED=30`)  
   **And** logs the failure details for the summary table  
   **And** does not prevent other installation steps from proceeding (orchestrator uses `|| true`)

5. **Given** git-ai is installed  
   **When** its attribution data is inspected  
   **Then** it is stored in a format consumable by external aggregation projects without additional lets-b-mad configuration (git-ai native Git Notes / `git ai stats --json` — no lets-b-mad wrapper needed)

## Tasks / Subtasks

- [x] Task 1: Implement `scripts/lib/dependencies.sh` git-ai install (AC: #1, #3, #4, #5)
- [x] Task 2: Wire into `scripts/install.sh` (AC: #1, #4)
- [x] Task 3: Unit tests and quality gates (AC: all)

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Notes:** Replaced sed with POSIX case-strip for version normalize (minimal PATH safe). `DEPS_GITAI_INSTALL_CMD` test hook documented. Install step uses continue-on-failure pattern.

## Dev Notes

### Architecture Context

- **Module:** `scripts/lib/dependencies.sh` — install-time only; sourced by `install.sh`
- **Requires:** `common.sh` + `manifest.sh` sourced first
- **Version pin:** `GITAI_VERSION="1.5.2"` in install.sh
- **Exit code:** `$EXIT_DEP_GITAI_FAILED` (30)

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 3-1-git-ai-global-installation |
| code | cursor/composer-2.5-fast | 3-1-git-ai-global-installation |
| test | cursor/composer-2.5-fast | 3-1-git-ai-global-installation |
| review | cursor/composer-2.5-fast | 3-1-git-ai-global-installation |

## Dev Agent Record

### Completion Notes

- Implemented deps_install_gitai with version check, GIT_AI_RELEASE_TAG pinning, manifest update
- Wired install_step_gitai into install.sh orchestrator
- Unit tests with DEPS_GITAI_INSTALL_CMD mock hook

### File List

- scripts/lib/dependencies.sh (NEW)
- scripts/install.sh (MODIFIED)
- tests/unit/test_dependencies.sh (NEW)

## Change Log

- 2026-06-01: Story 3.1 implementation complete

## Status

done
