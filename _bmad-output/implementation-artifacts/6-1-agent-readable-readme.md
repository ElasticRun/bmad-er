---
story_id: 6.1
story_key: 6-1-agent-readable-readme
status: done
---

# Story 6.1: Agent-Readable README

Status: done

## Story

As a developer (or AI coding agent),
I want a README that serves as a complete, executable installation guide,
so that Cursor or Claude Code can drive the full setup autonomously without human guidance.

## Acceptance Criteria

1. **Given** a developer or AI agent opens the lets-b-mad repository  
   **When** they read `README.md`  
   **Then** it contains: preflight checks (required OS, prerequisites), single-command install (`bash scripts/install.sh`), success verification criteria, and a do-not list (common pitfalls)

2. **Given** an AI coding agent reads `README.md`  
   **When** it parses the installation section  
   **Then** the structure enables autonomous execution: clear command, expected output, success/failure criteria, and next steps  
   **And** no ambiguous prose that requires human judgment to interpret

3. **Given** `README.md` exists  
   **When** validated by `markdownlint-cli2`  
   **Then** zero formatting violations are reported

4. **Given** the installation has completed  
   **When** the README's verification section is followed  
   **Then** it lists specific checks (e.g., `ls ~/.cursor/skills/`, verify `workspace.yaml` exists, confirm git-ai version) that confirm success

## Tasks / Subtasks

- [x] Task 1: Author agent-executable `README.md` (AC: #1, #2, #4)
  - [x] Subtask 1.1: Preflight — macOS/Darwin primary, Homebrew path, required tools
  - [x] Subtask 1.2: Install — workspace root, `bash scripts/install.sh`, `--force`, `LETS_B_MAD_WORKSPACE`
  - [x] Subtask 1.3: Expected output — summary table, exit 0 vs non-zero
  - [x] Subtask 1.4: Verification — concrete shell commands with pass/fail interpretation
  - [x] Subtask 1.5: Do-not list and troubleshooting exit ranges
- [x] Task 2: Run `markdownlint-cli2` on `README.md` (AC: #3)
  - [x] Subtask 2.1: `npx markdownlint-cli2 --no-globs README.md` exits 0

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-05

### Review Findings

- [x] [Review][Patch] README verification missing layout mode check — added `workspace.layout` section with standalone vs multi-repo criteria [`README.md`]

**Findings addressed (2026-06-01):**

- Verification section uses code blocks (not table cells) so shell pipes do not break MD056.
- Documentation quality section documents `--no-globs` so lint targets only `README.md`.

## AI Engineering Record

| AI-Phase | AI-Tool | Story-Ref |
|---|---|---|
| story | cursor/composer-2.5-fast | 6-1-agent-readable-readme |
| code | cursor/composer-2.5-fast | 6-1-agent-readable-readme |
| test | cursor/composer-2.5-fast | 6-1-agent-readable-readme |
| review | cursor/composer-2.5-fast | 6-1-agent-readable-readme |

## Dev Agent Record

### Agent Model Used

cursor/composer-2.5-fast

### Completion Notes List

- Added agent-executable `README.md` with preflight, install, expected output, verification, do-not, troubleshooting.
- markdownlint-cli2 passes with `--no-globs README.md`.
- All existing unit tests pass.

### File List

- README.md (NEW)

## Change Log

- 2026-06-01: Story 6.1 complete — agent-readable README

## Status

done
