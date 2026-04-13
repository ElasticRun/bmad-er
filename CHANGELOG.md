# Changelog

## 2.0.0 (2026-04-13)

Simplified trailer scheme. Every commit now gets exactly three trailers (`AI-Phase`, `AI-Tool`, `Story-Ref`) instead of 5-7. One commit = one phase.

### Breaking Changes

- Old trailers (`AI-Story`, `AI-Code`, `AI-Test`, `AI-Review`, `AI-Deploy`, `AI-Model`, `AI-Artifact`, `AI-Author`) are replaced by `AI-Phase` + `AI-Tool`.
- Dashboard no longer recognizes old trailer format. Re-run workflows to generate new-format commits, or manually add trailers to existing commits.

### Changed

- All planning workflows (`create-prd`, `create-epics-and-stories`, `create-architecture`, `create-ux-design`, `sprint-planning`, `create-story`) now commit with `AI-Phase: {type}`, `AI-Tool: {model}`, `Story-Ref: {ref}`.
- All development workflows (`dev-story`, `quick-dev`, `code-review`) now commit with the same three trailers.
- `prepare-commit-msg` hook detects `AI-Phase:` instead of `AI-Code:` or `AI-Artifact:`. Tags manual commits with `AI-Phase: code`, `AI-Tool: manual`.
- `adoption-dashboard.sh` (Pulse) groups commits by `AI-Phase` value and shows per-phase adoption rates.
- Story template AI Engineering Record table uses `AI-Phase | AI-Tool | Story-Ref` columns.
- Retrospective workflow queries the new trailer format and reports adoption by phase.

## 1.1.0 (2026-04-13)

Added git checkpoints with AI trailers to all planning workflows.

### Added

- `bmad-create-prd` (step-12-complete) -- auto-commits PRD with AI trailers on completion
- `bmad-create-epics-and-stories` (step-04-final-validation) -- auto-commits epics with AI trailers on completion
- `bmad-create-architecture` (step-08-complete) -- auto-commits architecture doc with AI trailers on completion
- `bmad-create-ux-design` (step-14-complete) -- auto-commits UX design with AI trailers on completion
- `bmad-sprint-planning` (workflow step 5) -- auto-commits sprint status with AI trailers on completion
- `bmad-create-story` (workflow step 6) -- auto-commits story file with AI trailers on creation

## 1.0.0 (2026-04-12)

Initial release. Fork of BMAD v6.3.0 with AI tracking extensions.

### Added

- **AI Engineering Record** table in story template (`bmad-create-story/template.md`).
- **Git commit trailers** auto-appended by `dev-story`, `quick-dev`, and `code-review` workflows.
- **`prepare-commit-msg` hook** that auto-tags manual commits.
- **`adoption-dashboard.sh`** script that reads git trailers and prints AI adoption rates vs. targets.
- **Retrospective AI metrics**: `bmad-retrospective` workflow queries git for trailer data during the retro.
- **Definition of Done update**: `bmad-dev-story` checklist includes AI tracking validation.
