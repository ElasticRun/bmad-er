# Skills Inventory

**Generated:** 2026-04-26
**Total skills:** 59 (51 `bmad-*` + 8 `dontbmad-*`)
**Mirror parity:** `claude/skills/` and `cursor/skills/` are byte-identical (verified via `diff` — empty diff).

## Categorization

### Planning workflows (PRDs, epics, stories, sprints)

| Skill | Structure | Notes |
|---|---|---|
| `bmad-create-prd` | steps-c/ (12 steps) | Full PRD authoring; auto-commits with AI-Phase: prd |
| `bmad-edit-prd` | workflow.md | Edits existing PRD |
| `bmad-validate-prd` | workflow.md | Validation checklist |
| `bmad-create-epics-and-stories` | workflow.md + templates | Breaks PRD into epics + stories |
| `bmad-create-story` | workflow.md | Single-story creation |
| `bmad-create-architecture` | workflow.md | Architecture solution doc |
| `bmad-create-ux-design` | workflow.md | UX patterns + specs |
| `bmad-product-brief` | workflow.md | Product brief authoring |
| `bmad-prfaq` | workflow.md | Working Backwards PRFAQ |
| `bmad-sprint-planning` | workflow.md | Sprint plan from epics |
| `bmad-sprint-status` | workflow.md | Sprint status summary |
| `bmad-correct-course` | workflow.md | Mid-sprint changes |
| `bmad-check-implementation-readiness` | workflow.md | Validates spec completeness |

### Development workflows

| Skill | Structure | Notes |
|---|---|---|
| `bmad-dev-story` | XML workflow.md (~23KB) | Story execution, AI Engineering Record table updates |
| `bmad-quick-dev` | step-NN-*.md (4 steps, flat) | Lightweight impl flow |
| `bmad-code-review` | steps/ (6 steps) | Multi-layer adversarial review |
| `bmad-retrospective` | workflow.md | Queries git trailers for adoption metrics |
| `bmad-qa-generate-e2e-tests` | workflow.md | E2E test generation |

### Agent personas

| Skill | Default name | Role |
|---|---|---|
| `bmad-agent-pm` | Chaitanya | Product manager |
| `bmad-agent-dev` | Tejas | Senior software engineer |
| `bmad-agent-architect` | Siddharth | System architect |
| `bmad-agent-analyst` | Nishtha | Business analyst |
| `bmad-agent-tech-writer` | Sakshi | Tech writer |
| `bmad-agent-ux-designer` | Sai | UX designer |

(Names overrideable in `_bmad/_config/team.yaml`.)

### CIS (Collaborative Innovation Studio) personas + skills

| Persona skill | Default name | Companion workflow |
|---|---|---|
| `bmad-cis-agent-brainstorming-coach` | Vaibhav | `bmad-brainstorming` |
| `bmad-cis-agent-creative-problem-solver` | Navneet | `bmad-cis-problem-solving` |
| `bmad-cis-agent-design-thinking-coach` | Monik | `bmad-cis-design-thinking` |
| `bmad-cis-agent-innovation-strategist` | Swapnil | `bmad-cis-innovation-strategy` |
| `bmad-cis-agent-presentation-master` | Suraj | (none — persona only) |
| `bmad-cis-agent-storyteller` | Tanay | `bmad-cis-storytelling` |

### Research

| Skill | Notes |
|---|---|
| `bmad-domain-research` | Industry/domain research |
| `bmad-market-research` | Competition + customers |
| `bmad-technical-research` | Technology + architecture research |

### Editorial & review

| Skill | Notes |
|---|---|
| `bmad-editorial-review-prose` | Copy edit |
| `bmad-editorial-review-structure` | Structural edit |
| `bmad-review-adversarial-general` | Cynical critical review |
| `bmad-review-edge-case-hunter` | Exhaustive edge-case analysis |
| `bmad-advanced-elicitation` | Socratic / first-principles / pre-mortem / red-team prompting |

### Documentation & knowledge curation

| Skill | Notes |
|---|---|
| `bmad-document-project` | This skill — produces project-knowledge/ documentation |
| `bmad-distillator` | Lossless LLM-optimized compression. **Has Python helpers + pytest tests.** |
| `bmad-shard-doc` | Splits long markdowns by L2 headings |
| `bmad-index-docs` | Generates folder index.md |
| `bmad-generate-project-context` | Creates project-context.md with AI rules |

### Utilities

| Skill | Notes |
|---|---|
| `bmad-help` | Recommends next skill based on state |
| `bmad-checkpoint-preview` | Human-in-the-loop review of recent changes |
| `bmad-party-mode` | Multi-agent roundtable orchestration |
| `bmad-brainstorming` | Ideation facilitator |

### `dontbmad-*` extensions (this fork's additions)

| Skill | Structure | Purpose |
|---|---|---|
| `dontbmad-ai-tracking` | SKILL.md (rule-only) | Reference doc + dashboard usage |
| `dontbmad-caveman` | SKILL.md (rule-only) | Terse output mode (~75% token reduction) |
| `dontbmad-compress-artifacts` | SKILL.md + workflow.md | Compresses planning docs (~46% input savings) |
| `dontbmad-auto-sprint` | workflow.md | Spawns subagents to auto-implement ready stories with multi-model cross-verification |
| `dontbmad-graphify` | workflow.md | Builds codebase knowledge graph |
| `dontbmad-graphify-query` | workflow.md | Searches knowledge graph |
| `dontbmad-graphify-path` | workflow.md | Traces node connections |
| `dontbmad-graphify-explain` | workflow.md | Explains a node's role |

## Structural patterns observed

| Pattern | Count (approx) | Examples |
|---|---|---|
| **steps-c/ subfolder** (lettered/numbered step files) | 1 | `bmad-create-prd` |
| **steps/ subfolder** (numbered step files) | several | `bmad-code-review`, `bmad-quick-dev` |
| **XML inline workflow.md** | 1+ | `bmad-dev-story` |
| **Single workflow.md routing to dynamic content** | majority | most agents and research skills |
| **Rule-only (no workflow.md)** | a few | `dontbmad-caveman`, `dontbmad-ai-tracking` |
| **Bundles helper scripts** | 1 | `bmad-distillator` (Python + pytest) |

## Files every skill should have (validation rules)

- `SKILL.md` — required, with YAML frontmatter (`name`, `description`)
- `workflow.md` — required for non-rule-only skills
- Any reference `Read fully and follow: ./<path>` should resolve to an existing file
- No reference should contain absolute paths from a contributor's machine (`/Users/...`, `/home/...`)
- For agent-persona skills: should reference `_bmad/_config/team.yaml` for display name overrides

These rules are testable via static analysis — see `test-suite-prd.md`.
