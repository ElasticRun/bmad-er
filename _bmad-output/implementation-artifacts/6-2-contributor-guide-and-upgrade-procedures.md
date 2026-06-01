---
story_id: 6.2
story_key: 6-2-contributor-guide-and-upgrade-procedures
status: done
---

# Story 6.2: Contributor Guide & Upgrade Procedures

Status: done

## Story

As a workspace maintainer,
I want documented procedures for contributing to lets-b-mad and upgrading BMAD versions,
so that any team member can maintain the tool and upgrades are safe and predictable.

## Acceptance Criteria

1. **Given** a developer opens `docs/guide.md`  
   **When** they read the Contributing section  
   **Then** it documents: repository structure explanation, how to add/modify customize.toml templates, how to add new lib modules, and testing procedures

2. **Given** a workspace maintainer reads `docs/guide.md`  
   **When** they follow the Upgrading BMAD section  
   **Then** it provides: version bump procedure (change one value in install.sh), test-then-rollout process, compatibility checklist, and rollback steps

3. **Given** `docs/guide.md` exists  
   **When** validated by `markdownlint-cli2`  
   **Then** zero formatting violations are reported

4. **Given** a maintainer follows the upgrade procedure  
   **When** they change the BMAD version pin and re-run install.sh  
   **Then** the documented process matches actual system behavior (no undocumented manual steps)

## Tasks / Subtasks

- [x] Task 1: Author `docs/guide.md` Contributing section (AC: #1)
  - [x] Subtask 1.1: Repository structure
  - [x] Subtask 1.2: customize.toml workflow
  - [x] Subtask 1.3: New lib module procedure
  - [x] Subtask 1.4: Testing procedures
- [x] Task 2: Author Upgrading BMAD section (AC: #2, #4)
  - [x] Subtask 2.1: `BMAD_VERSION` pin in install.sh
  - [x] Subtask 2.2: Test-then-rollout
  - [x] Subtask 2.3: Compatibility checklist
  - [x] Subtask 2.4: Rollback steps
- [x] Task 3: markdownlint (AC: #3)
  - [x] Subtask 3.1: `npx markdownlint-cli2 --no-globs docs/guide.md` exits 0

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Findings addressed:**

- Upgrade section documents separate `GITAI_VERSION` / `GRAPHIFY_VERSION` pins so maintainers do not assume BMAD-only rollback restores all tools.
- Rollback explicitly mentions IDE restart after global skills redeploy.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 6-2-contributor-guide-and-upgrade-procedures |
| code | cursor/composer-2.5-fast | 6-2-contributor-guide-and-upgrade-procedures |
| test | cursor/composer-2.5-fast | 6-2-contributor-guide-and-upgrade-procedures |
| review | cursor/composer-2.5-fast | 6-2-contributor-guide-and-upgrade-procedures |

## Dev Agent Record

### Agent Model Used

cursor/composer-2.5-fast

### Completion Notes List

- Added `docs/guide.md` with Contributing and Upgrading BMAD sections aligned to `install.sh` and `bmad.sh` behavior.
- markdownlint-cli2 passes with `--no-globs`.

### File List

- docs/guide.md (NEW)

## Change Log

- 2026-06-01: Story 6.2 complete — contributor guide and upgrade procedures

## Status

done
