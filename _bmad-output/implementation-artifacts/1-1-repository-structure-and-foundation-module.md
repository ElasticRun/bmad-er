---
story_id: 1.1
story_key: 1-1-repository-structure-and-foundation-module
status: done
---

# Story 1.1: Repository Structure & Foundation Module

## Story

As a workspace maintainer,
I want the lets-b-mad repository structure with foundational scripting utilities (logging, checksums, exit codes, platform detection),
so that all install modules can be built consistently on a solid foundation.

## Acceptance Criteria

**Given** a freshly cloned lets-b-mad repository
**When** the developer inspects the directory structure
**Then** the following directories exist: `scripts/`, `scripts/lib/`, `templates/customize/`, `docs/`
**And** `.shellcheckrc` is configured with `shell=sh`
**And** `.markdownlint-cli2.yaml` exists with project markdown rules
**And** `.gitignore` excludes `.lets-b-mad/`, OS artifacts, and temp files

**Given** `scripts/lib/common.sh` is sourced by another script
**When** logging functions are called (`log_info`, `log_warn`, `log_error`, `log_success`)
**Then** messages are written to stderr with format `[LEVEL] message`
**And** output is colorized when stderr is a terminal, plain text otherwise

**Given** `scripts/lib/common.sh` is sourced
**When** `compute_checksum` is called with a file path
**Then** it returns the SHA-256 checksum of the file on stdout
**And** works correctly on macOS (Darwin) using `shasum -a 256`

**Given** `scripts/lib/common.sh` is sourced
**When** exit code constants are referenced
**Then** range-based constants are defined: `EXIT_PREREQ_*` (10-19), `EXIT_BMAD_*` (20-29), `EXIT_DEP_*` (30-39), `EXIT_CONTEXT_*` (40-49), `EXIT_HOOK_*` (50-59)

**Given** `scripts/lib/common.sh` is sourced
**When** the summary collector functions are called (`summary_add_pass`, `summary_add_fail`)
**Then** results are accumulated and `summary_print` outputs a fixed-width table: `Step Name | Status | Details`

**Given** any script in `scripts/lib/`
**When** analyzed by `shellcheck`
**Then** zero errors or warnings are reported under POSIX sh rules

## Dev Notes

### Architecture Context

- POSIX `#!/bin/sh` only — no `local`, no `[[`, no arrays, no `declare`
- Library modules: side-effect-free at top level (constants + functions only)
- Logging to stderr; `compute_checksum` and summary table to stdout
- macOS Darwin: `shasum -a 256` for checksums (no Linux branch required for MVP but Darwin path is primary)

### Technical Specifications

Exit codes (named constants):
- `EXIT_PREREQ_MISSING=10`, `EXIT_PREREQ_INSTALL_FAILED=11`, `EXIT_PREREQ_VERSION_MISMATCH=12`
- `EXIT_BMAD_INSTALL_FAILED=20`, `EXIT_BMAD_DEPLOY_FAILED=21`
- `EXIT_DEP_GITAI_FAILED=30`, `EXIT_DEP_GRAPHIFY_FAILED=31`
- `EXIT_CONTEXT_CLONE_FAILED=40`, `EXIT_CONTEXT_PULL_FAILED=41`
- `EXIT_HOOK_INSTALL_FAILED=50`, `EXIT_HOOK_CONFLICT=51`

Summary: pipe-delimited internal storage; `summary_print` prints header `Step Name | Status | Details` with columns ~24/8/40.

### Files to Create/Modify

- NEW: `scripts/`, `scripts/lib/`, `templates/customize/`, `docs/` (`.gitkeep` in empty dirs)
- NEW: `scripts/lib/common.sh`
- NEW: `.shellcheckrc`, `.markdownlint-cli2.yaml`, `.gitignore`
- NEW: `tests/unit/test_common.sh`, `tests/unit/lib/test_helpers.sh`

### Testing Strategy

Source `common.sh` and `test_helpers.sh`; assert logging does not pollute stdout; assert checksum matches known file; assert summary table format.

## Tasks

- [x] Task 1: Repository structure and config files (AC: directory structure)
  - [x] Subtask 1.1: Create directories and lint configs
  - [x] Subtask 1.2: Create `.gitignore`
- [x] Task 2: Implement `common.sh` (AC: logging, checksum, exit codes, summary)
  - [x] Subtask 2.1: Logging with TTY color detection
  - [x] Subtask 2.2: `compute_checksum`, exit constants, summary collector
- [x] Task 3: Unit tests and shellcheck (AC: shellcheck clean)
  - [x] Subtask 3.1: `tests/unit/test_common.sh`
  - [x] Subtask 3.2: Run `shellcheck -s sh` on all lib scripts

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer | 1-1-repository-structure-and-foundation-module |
| code | cursor/composer | 1-1-repository-structure-and-foundation-module |
| test | cursor/composer | 1-1-repository-structure-and-foundation-module |
| review | cursor/composer | 1-1-repository-structure-and-foundation-module |

## Dev Agent Record

### Implementation Plan

### Completion Notes

Foundation module complete: common.sh with logging, checksum, exit codes, summary collector; unit tests pass.

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-01  
No blocking findings after implementation review.

## File List

- scripts/lib/common.sh
- .shellcheckrc
- .markdownlint-cli2.yaml
- .gitignore
- scripts/, scripts/lib/, templates/customize/, docs/ (structure)
- tests/unit/test_common.sh
- tests/unit/lib/test_helpers.sh

## Change Log

- 2026-06-01: Story 1.1 implementation complete

## Status

done
