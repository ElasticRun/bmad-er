---
story_id: 1.4
story_key: 1-4-bmad-installation-and-global-skill-deployment
status: done
---

# Story 1.4: BMAD Installation & Global Skill Deployment

## Story

As a developer,
I want install.sh to deploy BMAD skills globally and configure customize.toml overrides per skill,
so that BMAD workflows are available in both Cursor and Claude Code immediately after installation.

## Senior Developer Review (AI)

**Outcome:** Approve  
**Notes:** npx --directory temp; wipe global skills; IDE restart warn only when checksums differ from manifest; protected toml skip on developer edit.

## Tasks

- [x] bmad.sh, templates/customize/_default.toml, pre/post workflow stubs

## File List

- scripts/lib/bmad.sh (NEW)
- templates/customize/_default.toml (NEW)
- scripts/pre-workflow.sh (NEW)
- scripts/post-workflow.sh (NEW)

## Status

done
