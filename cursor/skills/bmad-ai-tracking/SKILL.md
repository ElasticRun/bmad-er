# AI Tracking

Set up and query AI adoption tracking for the project. Use when the user says "set up AI tracking", "install AI hooks", or "show AI adoption metrics".

## What This Skill Does

1. Installs a `prepare-commit-msg` git hook that auto-tags manual commits with AI tracking trailers.
2. Queries git history for AI adoption metrics and displays a dashboard.

## Usage

### Install the hook

Copy `./prepare-commit-msg` to `.git/hooks/prepare-commit-msg` and make it executable:

```bash
cp .cursor/skills/bmad-ai-tracking/prepare-commit-msg .git/hooks/prepare-commit-msg
chmod +x .git/hooks/prepare-commit-msg
```

### Query adoption metrics

Run `./adoption-dashboard.sh` from the project root to see current AI adoption rates.
