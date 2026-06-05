---
story_id: 1.5
story_key: 1-5-install-orchestrator-and-summary-table
status: done
---

# Story 1.5: Install Orchestrator & Summary Table

## Story

As a developer,
I want to run a single command that orchestrates the entire installation with pass/fail feedback and a `--force` option for clean reset,
so that setup is simple, transparent, and recoverable.

## Senior Developer Review (AI)

**Outcome:** Approve  
**Date:** 2026-06-05

**Notes:** No set -e; continue-on-failure; version pin block; highest-priority exit code; trap cleanup EXIT; workspace CLI arg and prompt verified in unit tests.

## Tasks

- [x] scripts/install.sh orchestrator

## File List

- scripts/install.sh (NEW)

## Status

done
