---
story_id: 7.2
story_key: 7-2-installation-health-validation-command
status: done
---

# Story 7.2: Installation Health Validation Command

Status: done

## Story

As a developer,
I want to validate my installation health at any time,
so that I can diagnose issues without re-running the full installer.

## Acceptance Criteria

1. **Given** a validation script or command exists  
   **When** a developer invokes it  
   **Then** it checks: global skills are resolved correctly, graphify hooks are active per repo, dependency versions match pins, central context is current (not stale), workspace YAML exists and is valid

2. **Given** all checks pass  
   **When** the validation completes  
   **Then** it prints a summary showing all checks as PASS  
   **And** exits with code 0

3. **Given** one or more checks fail  
   **When** the validation completes  
   **Then** it prints each failure with: what failed, expected state, actual state, and suggested fix  
   **And** exits with non-zero code

4. **Given** the validation command  
   **When** run on a fresh install immediately after `install.sh` completes  
   **Then** all checks pass (validates that install.sh leaves the system in a healthy state)

## Tasks / Subtasks

- [x] Task 1: Create `scripts/validate-installation.sh` (AC: #1–#3)
- [x] Task 2: Unit tests `tests/unit/test_validate_installation.sh`
- [x] Task 3: Document in README and `docs/guide.md`
- [x] Task 4: `shellcheck` on new script

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01

**Findings addressed:**

- Fixed `printf` header line that tripped POSIX `--` parsing (SC3045).
- Unit test resets `rc` before success-path validate invocation.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 7-2-installation-health-validation-command |
| code | cursor/composer-2.5-fast | 7-2-installation-health-validation-command |
| test | cursor/composer-2.5-fast | 7-2-installation-health-validation-command |
| review | cursor/composer-2.5-fast | 7-2-installation-health-validation-command |

## Dev Agent Record

### Agent Model Used

cursor/composer-2.5-fast

### Completion Notes List

- Added `scripts/validate-installation.sh` with PASS/FAIL table, remediation hints, exit 0/1.
- Reuses lib modules for manifest, deps versions, and hook verification.
- `VALIDATE_SKIP_CONTEXT_CHECK` test hook avoids network in unit tests.

### File List

- scripts/validate-installation.sh (NEW)
- tests/unit/test_validate_installation.sh (NEW)
- README.md (MODIFIED)
- docs/guide.md (MODIFIED)

## Change Log

- 2026-06-01: Story 7.2 complete — installation health validation command

## Status

done
