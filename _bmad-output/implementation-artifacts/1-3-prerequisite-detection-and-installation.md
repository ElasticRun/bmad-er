---
story_id: 1.3
story_key: 1-3-prerequisite-detection-and-installation
status: done
---

# Story 1.3: Prerequisite Detection & Installation

## Story

As a developer,
I want install.sh to detect missing prerequisites and attempt automatic installation,
so that I don't need to manually figure out what tools to install.

## Senior Developer Review (AI)

**Outcome:** Approve  
**Notes:** Version checks for jq/yq; Python 3.10+ via _version_ge; brew install with manual fallback messages and EXIT_PREREQ_INSTALL_FAILED.

## Tasks

- [x] Task 1: prerequisites.sh
- [x] All AC satisfied via install.sh integration

## File List

- scripts/lib/prerequisites.sh (NEW)

## Status

done
