---
title: 'Dev Story DoD Checklist'
validation-target: 'Story markdown ({{story_path}})'
validation-criticality: 'HIGHEST'
required-inputs:
  - 'Story markdown with Dev Notes'
  - 'Tasks/Subtasks all marked [x]'
  - 'File List section updated'
  - 'Dev Agent Record with implementation notes'
optional-inputs:
  - 'Test results output'
  - 'CI logs'
  - 'Linting reports'
validation-rules:
  - 'Only permitted story sections modified: Tasks/Subtasks checkboxes, Dev Agent Record, File List, Change Log, Status'
  - 'All implementation requirements from Dev Notes satisfied'
  - 'DoD checklist passes completely'
---

# Definition of Done Checklist

Story ready for review only when ALL items pass.

## Context & Requirements
- [ ] Dev Notes contains all technical requirements and architecture guidance
- [ ] Implementation follows architectural requirements from Dev Notes
- [ ] Technical specs (libraries, frameworks, versions) implemented correctly
- [ ] Previous story learnings incorporated (if applicable)

## Implementation
- [ ] Every task and subtask marked [x]
- [ ] Implementation satisfies every Acceptance Criterion
- [ ] Edge cases and error conditions handled
- [ ] Only uses dependencies from story or project-context.md

## Testing
- [ ] Unit tests added/updated for all core functionality
- [ ] Integration tests added when story requires them
- [ ] E2E tests added for critical flows when story requires them
- [ ] All existing tests pass (no regressions)
- [ ] Linting and static checks pass (when configured)
- [ ] Tests use project's testing frameworks

## Documentation
- [ ] File List includes every changed file (relative paths)
- [ ] Dev Agent Record contains implementation notes / debug log
- [ ] Change Log summarises what changed and why
- [ ] Review follow-ups (marked [AI-Review]) completed (if applicable)
- [ ] Only permitted story sections modified

## AI Tracking
- [ ] AI Engineering Record: code and test rows filled with agent/model and story ref
- [ ] Git commit trailers present: AI-Phase, AI-Tool, Story-Ref

## Final Status
- [ ] Story Status set to "review"
- [ ] Sprint status synced (when sprint tracking is used)
- [ ] No HALT conditions remaining

## Output

`Definition of Done: PASS` or `Definition of Done: FAIL`.
- PASS → story ready for code review.
- FAIL → list specific failures and required actions.
