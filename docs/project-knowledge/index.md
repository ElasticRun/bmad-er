# dont-b-mad — Project Knowledge Index

**Generated:** 2026-04-26
**Run:** Initial scan, deep level
**Project root:** `/Users/Sachin/Workspace/bmad-er`

This is the master index of generated documentation. Every document below was produced from a structural scan of the repo on the date above. Treat this as the **AI-context entry point** when working on the project: open the docs that match your task.

---

## Project at a glance

- **Type:** Monolith (skill distribution + AI tracking tooling)
- **Primary language:** Bash
- **Target platforms:** macOS, Linux
- **Test infrastructure today:** minimal (1 pytest file inside `bmad-distillator`)
- **Skill count:** 59 (51 `bmad-*` + 8 `dontbmad-*`)
- **Mirror parity:** `claude/skills/` and `cursor/skills/` are byte-identical

---

## Generated documentation

| Document | Purpose | Read when… |
|---|---|---|
| [Project Overview](./project-overview.md) | What `dont-b-mad` is, tech stack, repo classification | Onboarding new contributors |
| [Source Tree Analysis](./source-tree-analysis.md) | Annotated directory tree, entry points, critical paths | Getting oriented for any task |
| [Architecture](./architecture.md) | Component model, install/hook/dashboard internals, side effects, risks | Modifying install.sh, the hook, or the dashboard |
| [Skills Inventory](./skills-inventory.md) | Categorized listing of all 59 skills, structural patterns | Adding/modifying a skill, planning a refactor |
| [Development Guide](./development-guide.md) | Local dev workflow, prereqs, `--dev-link`, troubleshooting | Setting up a dev environment |
| **[Test Suite PRD](./test-suite-prd.md)** 🎯 | **PRIMARY DELIVERABLE** — full PRD for introducing comprehensive test coverage | When you're ready to implement the test suite |
| [Project Scan Report](./project-scan-report.json) | Machine-readable scan state | Tooling/automation that consumes scan output |

---

## Existing documentation (pre-existing in the repo)

| Document | Purpose |
|---|---|
| [README.md](../../README.md) | User-facing install instructions and AI tracking overview |
| [CHANGELOG.md](../../CHANGELOG.md) | v2.0.0 → v1.0.0 release history |
| [docs/why-bmad-presentation.md](../why-bmad-presentation.md) | Long-form Marp deck on context curation rationale |
| [docs/why-bmad-presentation-concise.md](../why-bmad-presentation-concise.md) | Condensed version |

---

## Getting started

**To implement the test suite (the reason this scan was run):**

1. Read [test-suite-prd.md](./test-suite-prd.md) end to end.
2. Cross-reference [architecture.md](./architecture.md) §"Component model" for the side-effect inventory of every script — this is what the tests assert against.
3. Start with Sprint 2 (hook tests) per the PRD's implementation plan — smallest surface, fastest validation that the framework works end to end.
4. CI configuration is provided as a copy-pasteable YAML snippet in PRD §FR10.

**To understand the system without the test focus:**

1. [project-overview.md](./project-overview.md) → 5 minutes of context.
2. [source-tree-analysis.md](./source-tree-analysis.md) → 10 minutes for layout.
3. [architecture.md](./architecture.md) → 20 minutes for the runtime story.

---

## Verification recap

- **Tests/extractions executed:** Live grep + `ls` + skill-count verification + diff between `claude/skills/` and `cursor/skills/` (empty diff confirmed).
- **Outstanding risks or follow-ups:** Six open questions in `test-suite-prd.md` §9 require product/engineering decisions during implementation.
- **Recommended next checks before PR:** None — these docs are read-only artifacts. Before opening a PR to implement the test suite, validate the PRD with the team and resolve Q1–Q6.

---

## Brownfield PRD command

Other agent-driven workflows (e.g. PRD revisions, sprint planning) can point at this index as their context source:

```
/bmad-create-prd  # then provide docs/project-knowledge/index.md as the input doc
```

Or, when ready to implement, point an agent at the test-suite PRD directly:

```
/bmad-dev-story   # using docs/project-knowledge/test-suite-prd.md as the story spec
```
