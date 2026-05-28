---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish']
inputDocuments:
  - 'uploads/BMAD-METHOD-1.md'
  - 'uploads/git-ai-2.md'
  - 'uploads/graphify-3.md'
workflowType: 'prd'
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 0
  projectDocs: 0
classification:
  projectType: developer_tool
  domain: general
  complexity: medium
  projectContext: greenfield
---

# Product Requirements Document - lets-b-mad

**Author:** Ajit
**Date:** 2026-05-27

## Executive Summary

lets-b-mad is a workspace-level orchestration layer that transforms an engineering team's development model from manual code-first to specification-first AI-assisted development. Built as a customization and integration layer atop BMAD Method v6.8.0, it wires together three external tools — git-ai (AI code attribution and quality metrics), graphify (queryable codebase knowledge graphs), and a centralized organizational context repository — into a single, measurable, upgrade-safe developer environment deployed via slash commands in Cursor and Claude Code.

The primary user is the individual developer — new hire or veteran — who should be fully onboarded in under 5 minutes via a single install script or agent-driven README. The system targets 70-80% AI-generated code within 90 days, with developers shifting from writing code and tests to authoring detailed functional specifications, reviewing agent output for design quality, and maintaining test coverage. The driving business constraint is cost-to-revenue ratio control: development costs must not scale linearly with feature demand or platform growth.

### What Makes This Special

Three context layers feed every agent session, each kept automatically current: **org-wide** (coding standards, data dictionary, domain glossary, and ADRs from a central git repository, pulled fresh before every workflow), **workspace-wide** (multi-repo manifest, BMAD skill customizations via `customize.toml`), and **per-repo** (graphify knowledge graph, rebuilt on every commit via git hooks). Combined with git-ai's line-level AI attribution, the team gains a closed feedback loop — measuring code durability, agent autonomy, and session efficiency per the git-ai metrics framework, then tuning context, specifications, and agent rules to improve outcomes. The differentiation is not the individual tools but the **system-level integration** that makes AI-assisted development measurable and continuously improvable, while remaining fully upgrade-safe against upstream BMAD releases through BMAD's native `customize.toml` extension points and zero modification of BMAD source code.

## Project Classification

- **Project Type:** Developer Tool (CLI scripts, BMAD skill customizations, slash commands)
- **Domain:** General (internal DevOps/developer tooling)
- **Complexity:** Medium — four integration surfaces (BMAD, git-ai, graphify, central context repo) with upgrade-safe design constraints and multi-repo orchestration; no regulated-industry compliance
- **Project Context:** Greenfield — no existing code; fresh BMAD v6.8.0 scaffold with BMM, CIS, and WDS modules installed

## Success Criteria

### User Success

- **5-minute onboarding:** A new developer completes full workspace setup — BMAD, git-ai, graphify, central context — in under 5 minutes using only the repository README, with no external assistance. An AI coding agent (Cursor or Claude Code) can drive the installation autonomously from the README.
- **Specification-first workflow adoption:** Developers spend the majority of their working time authoring functional specifications, reviewing agent output, and maintaining test cases — not writing implementation code or unit tests manually.
- **Always-current agent context:** Every BMAD workflow starts with the latest organizational context (standards, data dictionary, domain glossary, ADRs) pulled from the central repository. Graphify knowledge graphs reflect committed code state via git hooks. Developers never need to manually refresh context.
- **Non-destructive re-installation:** Re-running install.sh never overwrites developer-customized files. Explicit `--force` flag required for full reset. Developers trust the upgrade path.

### Business Success

- **Deployment velocity (decreasing trend):** Average time from requirements to deployment starts at ~15 days in the first fortnight post-rollout and decreases by ~2 days per fortnight until reaching a steady-state optimum.
- **Story throughput (increasing trend):** Team-wide story throughput per fortnight shows a consistent upward trend of several percentage points over each previous fortnight.
- **AI code ratio:** 70-80% of newly written code is AI-generated within 90 days of rollout.
- **Cost control:** Development costs demonstrate sub-linear growth relative to feature demand and platform expansion.

### Technical Success

- **git-ai durability:** 30-day code durability of AI-generated code reaches 40-50% within 90 days, with an upward trend as context quality improves.
- **Unit test coverage:** Minimum 50% coverage for all newly developed or updated code.
- **Production quality parity:** Generated code performs at parity with existing systems and adheres to NFRs defined in each specification.
- **Installation reliability:** 95%+ of the 96-person team completes onboarding without manual intervention.
- **Context freshness SLA:** Central context is guaranteed current (latest commit) at the start of every BMAD workflow. Staleness between workflows is acceptable.
- **Upgrade safety:** BMAD version bumps (e.g., 6.8.0 → 6.9.x) do not require changes to lets-b-mad customization code. Zero BMAD source code modifications.

### Measurable Outcomes

| Metric | Target | Timeline |
|--------|--------|----------|
| Team adoption | 100% of 96 developers | 90 days |
| AI-generated code ratio | 70-80% | 90 days |
| git-ai 30-day durability | 40-50% | 90 days |
| Unit test coverage (new code) | ≥50% | Ongoing |
| Onboarding time | ≤5 minutes | Day one |
| Install success rate | ≥95% unassisted | Day one |
| Requirements-to-deployment | Decreasing trend (~15d → steady-state) | Per fortnight |
| Story throughput | Increasing trend | Per fortnight |
| Context freshness at workflow start | 100% (never stale) | Day one |

## Product Scope & Phased Development

### MVP Strategy

**Approach:** Problem-solving MVP — deliver the minimum instrumented agent environment that proves the core thesis: better context produces more durable AI code. The MVP must complete Priya's (day-one) and Arjun's (daily workflow) journeys end-to-end. Meera's (upgrade) journey is supported structurally but fully exercised only when a BMAD upgrade occurs.

**Resource Requirements:** Single developer (with Ajit as workspace maintainer and Kavita as central context author). No dedicated infrastructure — all local tooling, git-hosted context, existing GitLab for credentials.

**Core User Journeys Supported:** Priya (day-one), Arjun (daily + edge case), Kavita (context authoring — dependent on central context repo existing)

### MVP Feature Set (Phase 1)

| Capability | Description | Justification |
|-----------|-------------|---------------|
| `scripts/install.sh` | Idempotent bootstrap: pins BMAD v6.8.0 via npx (non-interactive), installs git-ai + graphify (version-pinned), sets up git hooks, deploys global skills, clones central context repo, auto-discovers repos and generates workspace YAML. Supports `--force`. Prints pass/fail per step. | Day-one journey fails without it |
| Workspace YAML manifest | Auto-discovered from workspace root (every initialized git repo = entry, relative paths). Developer-editable. Validated on every command invocation. | Multi-repo context unavailable without it |
| Central context integration | Git repo of markdown files (org standards, data dictionary, domain glossary, ADRs) cloned at install, pulled fresh via `activation_steps_prepend` before every BMAD workflow. Pull failure = hard block. | Mandatory workflow contract: context never stale at workflow start |
| git-ai integration | Global install, version-pinned. Tracks AI code attribution per commit. Data available for durability, autonomy, and efficiency metrics consumed by separate aggregation project. | Quality metrics are the primary MVP goal |
| graphify integration | Per-repo initialization. Post-commit/post-checkout hooks for automatic graph rebuild. Always-current knowledge graph reflecting committed code. | Always-current knowledge graph is core differentiator |
| Global skills | All BMAD skills (BMM, CIS, WDS) installed once centrally (`~/.cursor/skills/`, `~/.claude/skills/`), wiped and recreated on every install. Single upgrade point. | BMAD workflows unavailable without it |
| BMAD `customize.toml` overrides | `_bmad/custom/{skill-name}.toml` files for `on_complete` and `activation_steps_prepend` hooks. Shared scripts in `scripts/` as execution targets. Protected on re-install. | Integration surface for pre/post-workflow actions |
| Agent-readable README | Structured for autonomous installation by Cursor/Claude Code agents. Preflight checks, single-command install, exit-code-based success criteria. | Agent-driven installation is a day-one requirement |
| `docs/guide.md` | Contributor guidelines and BMAD upgrade procedures in a single document. | Meera's upgrade journey requires documentation |
| `.lets-b-mad/install-manifest.json` | Tracks managed vs developer-customized files with checksums for idempotent re-install. | Idempotent re-install depends on managed vs protected file tracking |
| `scripts/ai-stats-summary.sh` | Lightweight local git-ai metrics summary per repo. | Bridges gap until aggregation dashboard ships |
| GitLab credential handling | Retrieves via `git credential fill`, stores via `git credential approve`. Never in plaintext. | Establishes auth pattern for future event push |

### Growth Features (Phase 2)

| Feature | Description | Trigger for inclusion |
|---------|-------------|----------------------|
| Gamification event push | Fire workflow completion events (workflow name + auth) to GitLab OAuth-protected endpoint for office TV dashboard. Non-critical, fail-open, warn-and-continue. | After MVP stable + aggregation project ready |
| `validate-installation` command | Slash command or script to verify installation health (skills resolved, hooks active, versions correct, context current). | After first round of support tickets reveals common failure patterns |
| WDS workflow wrappers | Thin wrapper skills for WDS workflows lacking native `on_complete` support. | When team starts using WDS workflows actively |
| Workspace YAML auto-sync | On-demand re-discovery of repos added/removed, merge-not-overwrite semantics. | When team frequently adds/removes repos mid-sprint |
| `--force` granularity | Separate flags (`--force-skills`, `--force-config`) for targeted overwrite. | When upgrade scenarios reveal need for targeted overwrite |
| Version check on workflow start | Warn if installed BMAD version differs from lets-b-mad pin. | When BMAD version drift across team becomes a problem |
| Agent-optimized authoring guidelines | Structured format guidance for central context documents (rules over prose, examples over descriptions). | After initial durability data reveals context interpretation issues |
| Specification templates | Worked examples and templates for functional specifications in central context. | After specification quality variance observed via git-ai correlation |

### Vision Features (Phase 3)

| Feature | Strategic rationale |
|---------|-------------------|
| CI/CD integration | Extend BMAD + context refresh to pipelines |
| Cross-workspace metrics dashboard | Engineering leadership visibility across all teams |
| Central context wiki support (Confluence, GitLab wiki) | Organizations with non-git knowledge bases |
| Agent efficiency benchmarking | Compare git-ai metrics across repos/teams for optimization |
| Automated context quality scoring | Correlation engine: context completeness vs code durability |
| Specification quality metrics per developer | Close the loop from "spec quality → code quality" |

### Risk Mitigation

**Technical Risks:**
- Global skills resolving against workspace-root `_bmad/` when skills live in `~/.cursor/skills/`. Mitigation: test with BMAD's `resolve_config.py` and `resolve_customization.py` using `{project-root}` variable before full rollout.
- `customize.toml` `on_complete` and `activation_steps_prepend` reliability when skills are global but config is workspace-local. Mitigation: validate with a single developer before team rollout.
- BMAD upstream changes breaking `customize.toml` extension points. Mitigation: pin BMAD version; test upgrades on maintainer workspace before rollout; zero source modifications.

**Adoption Risks:**
- 96 developers, one shot at first impression — day-one install failure kills word-of-mouth. Mitigation: Meera tests on 3 different machines with varying prerequisite states before team announcement.
- Specification fatigue — developers accustomed to direct coding resist detailed specifications. Mitigation: lightweight spec templates; let durability data make the case over time.
- Developers bypass BMAD workflows for raw agent prompting. Mitigation: 100% adoption mandate + team-visible metrics create accountability. Post-MVP gamification amplifies.

**Context Quality Risks:**
- Poor initial context quality leads to low durability scores that discourage adoption. Mitigation: set realistic initial targets (40-50%); invest in Kavita's role as primary lever.
- Central context written for humans, not agents — inconsistent interpretation. Mitigation: agent-optimized authoring guidelines (Phase 2) with explicit rules, examples, machine-parseable criteria.
- Specification quality variance across 96 developers. Mitigation: templates and worked examples in central context; quality measurable via durability correlation.
- Context pull failure proceeds silently, breaking freshness SLA. Mitigation: hard-block on pull failure with warning, not silent degradation.

**Operational Risks:**
- Single developer building the tool (bus factor = 1). Mitigation: contributor documentation enables any team member to maintain install.sh and update version pins.
- git-ai metrics invisible during 90-day rollout due to delayed aggregation project. Mitigation: `scripts/ai-stats-summary.sh` bridges gap locally.
- Uncontrolled personal customization breaks mandatory workflow contract. Mitigation: contributor guide defines safe vs team-mandated customization boundaries.

### Launch Prerequisites (External Dependencies)

| Dependency | Owner | Must be ready by |
|-----------|-------|-----------------|
| Central context repo populated (ADRs, data dictionary, coding standards, domain glossary) | Kavita / architecture team | Before team rollout |
| GitLab OAuth endpoint accessible | DevOps team | Phase 2 (not MVP) |
| Aggregation project consuming git-ai data | Separate project team | Phase 2 (not MVP) |

## User Journeys

### Journey 1: Priya — New Developer, Day One

**Situation:** Priya joins the engineering team on Monday morning. She has 3 years of experience with Node.js and React but has never used BMAD, git-ai, or graphify. Her manager tells her: "Clone lets-b-mad, point Cursor at it, and tell the agent to set you up. You should be running your first workflow by lunch."

**Opening Scene:** Priya opens Cursor, clones the lets-b-mad repository, and opens it as her workspace. She reads the README — or more precisely, her Cursor agent reads it. The agent identifies `scripts/install.sh` and asks if she'd like to proceed with installation.

**Rising Action:** The install script runs. It detects her workspace folder, discovers 4 git repositories she's already cloned as siblings, pins and installs BMAD v6.8.0 via npx, installs git-ai globally, installs graphify via uv, clones the central context repo, generates her workspace YAML with all 4 repos listed, and deploys global skills to `~/.cursor`. Each step prints a pass/fail status. Total time: under 3 minutes.

**Climax:** Priya opens one of her assigned repos and invokes `/bmad-dev-story`. Before the workflow begins, `activation_steps_prepend` fires — pulling the latest org standards, data dictionary, and ADRs from the central context repo. The agent has rich context from graphify's knowledge graph and knows the organization's coding conventions. She writes a functional specification, the agent generates implementation code that follows the team's patterns, and she reviews it — finding the code clean, well-tested, and consistent with existing architecture.

**Resolution:** By lunch, Priya has completed her first story. git-ai has tracked the AI attribution on her commits. Her graphify graph updated automatically on commit. She didn't write a single line of implementation code — she authored a specification and reviewed the output. She messages her manager: "That was the smoothest onboarding I've ever had."

**Requirements revealed:** Agent-readable README, single-command install, workspace auto-discovery, global skill deployment, graphify hook setup, central context clone, YAML generation, pass/fail verification output, non-interactive execution.

### Journey 2: Arjun — Active Developer, Daily Workflow

**Situation:** Arjun is 6 weeks into using lets-b-mad. He works across 3 repositories — a backend API, a shared library, and a frontend app. He starts each morning by checking his sprint stories in BMAD and picking the next one to implement.

**Opening Scene:** Arjun opens Cursor with his workspace. He invokes `/bmad-create-story` on the backend API repo. Before the workflow starts, the agent pulls the latest central context — overnight, the context authoring team updated the data dictionary with new entity definitions for a feature Arjun is working on.

**Rising Action:** Arjun writes a detailed functional specification for a new API endpoint. The specification references the data dictionary entities, follows the org's API design standards from the ADRs, and includes NFRs for response time and error handling. He invokes `/bmad-dev-story`. The agent — armed with the graphify knowledge graph showing how the existing API is structured, the org standards for error handling patterns, and the data dictionary for field types — generates the implementation, unit tests (meeting the 50% coverage target), and integration tests.

**Climax:** Arjun reviews the generated code. He spots a design concern — the agent used a synchronous pattern where the ADR recommends async for external service calls. He flags it in the specification, the agent regenerates. The code now matches the team's architectural decisions. He commits. git-ai records the AI attribution. graphify rebuilds the knowledge graph to include the new endpoint. The graph now shows how this endpoint connects to the existing service mesh.

**Resolution:** Arjun completes 3 stories by end of day — a pace that would have taken a week of manual coding. His git-ai stats show 85% AI-generated code with improving durability scores. The specifications he wrote are detailed enough that the agent rarely needs steering corrections.

**Requirements revealed:** Multi-repo workspace context via YAML, per-workflow context pull (activation_steps_prepend), graphify always-current via git hooks, git-ai per-commit tracking, BMAD customize.toml on_complete integration, specification-to-code workflow support.

### Journey 3: Arjun — Active Developer, Edge Case (New Repo Added Mid-Sprint)

**Situation:** On Wednesday, Arjun's team lead asks him to start work on a new microservice. He clones the repo into his workspace folder.

**Opening Scene:** The new repo exists on disk but isn't in his workspace YAML. When Arjun tries to invoke a BMAD workflow on it, the workspace context is incomplete.

**Rising Action:** Arjun runs the repo discovery command (or asks his agent to). The tool scans the workspace root, finds the new git repo, and adds it to the YAML — preserving all existing entries and their customizations. He then runs graphify init on the new repo to build the initial knowledge graph.

**Climax:** The new repo is now a first-class citizen in his workspace. BMAD workflows resolve context correctly, graphify has indexed the existing code (it was a skeleton service with some boilerplate), and the central context feeds the same org standards to this repo as every other.

**Resolution:** Arjun starts his first story on the new repo. The agent's output follows the same patterns as the other repos because the same org context applies. No tribal knowledge transfer needed — the context layers did it.

**Requirements revealed:** On-demand repo discovery and YAML update, merge-not-overwrite semantics for existing entries, per-repo graphify init command, workspace YAML validation, idempotent operations.

### Journey 4: Meera — Workspace Maintainer, BMAD Upgrade

**Situation:** Meera is the tech lead responsible for lets-b-mad across the team's workspaces. BMAD v6.9.0 is released with new skills and improvements. She needs to upgrade 96 developers without breaking their customizations.

**Opening Scene:** Meera reads the lets-b-mad upgrade guide. It lists the steps: update the pinned BMAD version in install.sh, test the upgrade on her own workspace, then notify the team to re-run install.sh.

**Rising Action:** Meera updates the BMAD version pin in the lets-b-mad repo and runs install.sh on her workspace. The script detects existing installations — it updates managed files (BMAD skills, global skills) but preserves all `_bmad/custom/*.toml` overrides, workspace YAML entries, and developer-specific configurations. New skills from 6.9.0 are added alongside existing ones. The `on_complete` hooks in customize.toml still point to the same shared scripts.

**Climax:** Meera runs a BMAD workflow end-to-end on her workspace. Central context pulls correctly, graphify graph is current, git-ai tracks normally, and the new 6.9.0 features work. She pushes the version bump to the lets-b-mad repo.

**Resolution:** She messages the team: "BMAD 6.9.0 is ready. Re-run install.sh — no `--force` needed, your customizations are safe." Developers re-run over the next day. Zero support tickets. The upgrade guide + idempotent install + managed-vs-protected file distinction handled everything.

**Requirements revealed:** Version pin in install.sh as single source of truth, managed vs protected file manifest, idempotent re-run without --force, upgrade documentation, global skill update propagation, customize.toml preservation across upgrades.

### Journey 5: Kavita — Central Context Author

**Situation:** Kavita is a senior architect who maintains the organization's central context repository. She's responsible for keeping org standards, data dictionary, domain glossary, and ADRs current as the platform evolves.

**Opening Scene:** The team decides to adopt a new caching pattern. Kavita needs to write an ADR documenting the decision and update the coding standards to reference it, so that every developer's agent uses this pattern going forward.

**Rising Action:** Kavita writes the ADR in the central context git repo: `adrs/024-redis-caching-pattern.md`. She updates the coding standards document to reference the new pattern. She commits and pushes.

**Climax:** The next time any developer on the 96-person team starts a BMAD workflow, `activation_steps_prepend` runs `git pull` on the central context repo. The agent now knows about the caching pattern ADR. When a developer writes a specification that involves caching, the agent generates code using the approved Redis pattern — without the developer needing to know the ADR exists.

**Resolution:** Within 24 hours, three different developers across three repos have generated code using the new caching pattern — all consistent, all following the ADR. Kavita didn't need to schedule a knowledge-sharing session, write a Slack announcement, or review PRs for pattern compliance. The context distribution was automatic.

**Requirements revealed:** Central context repo as git-pullable markdown files, activation_steps_prepend for freshness guarantee, ADR format support, no manual distribution — automatic propagation on next workflow start.

### Journey 6: Vikram — Engineering Manager, Metrics Review

**Situation:** Vikram manages 4 teams (96 developers total). He presents a monthly report to the CTO on AI-assisted development adoption and impact. He needs data on code quality, team velocity, and adoption rates.

**Opening Scene:** Vikram runs `git ai stats --json` across the workspace repos (or the aggregation project provides a dashboard — out of scope for lets-b-mad but consumes git-ai data). He sees AI-generated code is at 72% across all repos.

**Rising Action:** He digs into the metrics. 30-day durability is at 43% — within the 40-50% target but with variance across teams. Team A's durability is 55% (they invested heavily in specifications and ADRs); Team B is at 31% (thinner specifications, less graphify coverage). Story throughput is up 18% over the previous fortnight. Requirements-to-deployment time is down to 11 days from 15 at rollout.

**Climax:** Vikram identifies that the durability gap correlates with graphify coverage — repos with richer knowledge graphs produce more durable AI code. He asks Kavita to prioritize ADRs for Team B's domain area and asks Team B's lead to run graphify on their legacy code.

**Resolution:** He presents to the CTO: "Development costs grew 8% while feature output grew 35%. AI code durability is trending up. The investment in context quality is the primary lever — not the AI model itself." The CTO asks for this analysis quarterly.

**Requirements revealed:** git-ai data availability per-repo (in-scope: setup and tracking; out-of-scope: aggregation dashboard), correlation between context richness and code quality (emergent property), per-repo graphify coverage as a health signal.

### Journey Requirements Summary

| Journey | User Type | Key Capabilities Revealed |
|---------|-----------|--------------------------|
| Priya (Day One) | New Developer | Agent-readable README, single-command install, auto-discovery, global skills, graphify hooks, context clone, YAML generation, verification output |
| Arjun (Daily) | Active Developer | Multi-repo YAML context, pre-workflow context pull, graphify git hooks, git-ai tracking, customize.toml on_complete, specification-first workflow |
| Arjun (Edge Case) | Active Developer | On-demand repo discovery, YAML merge-not-overwrite, per-repo graphify init, validation |
| Meera (Upgrade) | Workspace Maintainer | Version pin management, managed vs protected files, idempotent re-run, upgrade docs, customize.toml preservation |
| Kavita (Context) | Central Context Author | Central context as git repo, activation_steps_prepend, auto-propagation, ADR/standards/glossary format |
| Vikram (Metrics) | Engineering Manager | git-ai setup and per-repo tracking, data available for external aggregation, graphify as quality signal |

## Innovation & Novel Patterns

### Detected Innovation Areas

**An Organizational Learning System for AI Agents** — lets-b-mad is not a developer tool in the traditional sense. It is an organizational learning system where AI agents are the students and specifications are the curriculum. Developers become teachers — authoring functional specifications, curating ADRs, maintaining data dictionaries — while agents consume this structured knowledge to produce implementation code. When Kavita writes an ADR, 96 agents learn it simultaneously on their next workflow invocation. When one repo's git-ai durability scores improve after enriching its graphify graph, that's evidence applicable to every repo. The specification-first development model is not a workflow preference but a pedagogical necessity: agents without clear specifications and rich context produce code that doesn't hold up, just as students without clear instruction and reference material produce poor work.

**Opinionated Infrastructure That Eliminates the Practice Gap** — The industry has "best practices" for AI-assisted development: give agents rich context, write detailed specifications, track AI code quality, keep knowledge graphs current. In practice, these are optional — developers skip them under deadline pressure, and the resulting quality problems are invisible until production. lets-b-mad's innovation is the mandatory workflow contract: agents MUST have current org context before any workflow starts (activation_steps_prepend), every line of AI code MUST be attributed (git-ai), every commit MUST update the knowledge graph (graphify hooks). The system won't let you do AI development badly. It is opinionated infrastructure that closes the gap between what teams know they should do and what actually happens on Tuesday afternoon.

**Closed-Loop Environment Tuning** — Individual measurement tools (git-ai) and individual context tools (graphify) exist independently. The innovation is wiring them into a thermostat, not a thermometer: git-ai measures code durability and agent efficiency, graphify and central context define the environment, and the correlation between context quality and code quality creates an actionable feedback loop. Teams improve agent output by tuning the environment — not by switching models.

### Second-Order Effects

The closed-loop system creates cascading effects beyond its designed purpose. Specification quality becomes the highest-leverage developer skill, naturally incentivized by measurable durability outcomes. The central context repository becomes the most strategically important repo in the organization — whoever maintains it effectively programs 96 agents simultaneously. Cross-repo learning emerges without explicit design as shared context creates consistency across the workspace. Onboarding economics change fundamentally: a day-one developer's agent is as knowledgeable as a veteran's, decoupling productivity from tenure. Institutional knowledge becomes structurally durable rather than dependent on individual retention.

### Market Context & Competitive Landscape

The closest operational analog is the DevOps transformation: CI/CD pipelines turned deployment from a manual, inconsistent process into a measurable, repeatable, improvable pipeline. lets-b-mad applies the same pattern to AI-assisted development — turning ad-hoc agent usage into an instrumented, context-rich, measurable system. No existing tooling combines organizational context distribution, per-repo knowledge graphs, AI code attribution metrics, and structured development workflows into a single integrated workspace layer.

### Validation Approach

- **Context-quality correlation:** Measure git-ai durability scores across repos with varying graphify coverage and ADR completeness. If higher-context repos produce more durable code, the core thesis — environment over model — is validated.
- **Adoption velocity:** Track time-to-first-workflow across the 96-person rollout. If 95%+ complete setup unassisted, the adoption architecture works.
- **Specification-first shift:** Monitor the ratio of specification authoring time vs. manual coding time per developer over the 90-day rollout.

## Developer Tool Specific Requirements

### Project-Type Overview

lets-b-mad is a developer tool delivered as bash scripts, YAML configuration, BMAD `customize.toml` override templates, and documentation. It targets macOS with Apple Silicon (M1/M4) exclusively, deploying to both Cursor and Claude Code IDEs simultaneously. The tool chain has four external dependencies (BMAD via npx, git-ai via curl, graphify via uv, central context via git), each version-pinned and managed through a single idempotent install script. The lets-b-mad repository ships zero BMAD workflow, agent, or skill code — all BMAD content is generated at install time by `npx bmad-method`.

### Platform & Runtime

- **Target OS:** macOS (Apple Silicon — M1, M4). No Linux/WSL/Windows support required.
- **Shell:** Bash (pre-installed on macOS)
- **Prerequisites:** Node.js/npx, Python 3.10+, uv, git, curl
- **Prerequisite handling:** install.sh attempts to install missing prerequisites (e.g., via Homebrew). On failure, prints clear error message with manual install instructions and exits with non-zero code.

### IDE Integration

- **Target IDEs:** Cursor and Claude Code — both installed to simultaneously, always.
- **Global skill paths:** `~/.cursor/skills/` and `~/.claude/skills/` — identical BMAD skill sets deployed to both.
- **Post-install notification:** If global skill files changed during installation, print a message recommending IDE restart to pick up new/updated skills.
- **Workspace-level files:** `_bmad/` config directory, `_bmad/custom/*.toml` overrides, workspace YAML — shared across IDEs (IDE-agnostic paths).

### Installation Flow

| Step | Action | Output Location |
|------|--------|----------------|
| 1 | `npx bmad-method@6.8.0 install --directory <temp> --modules bmm,cis,wds --tools cursor --yes` | Temp directory |
| 2 | Delete and recreate global skills: wipe and copy `.agents/skills/*` from temp to `~/.cursor/skills/` and `~/.claude/skills/` | Global (per-machine) |
| 3 | Copy full `_bmad/` from temp to workspace root (preserved on re-install, recreated on fresh/`--force`) | Workspace root |
| 4 | Copy lets-b-mad `templates/customize/*.toml` to `_bmad/custom/` per repo (protected on re-install) | Per-repo |
| 5 | Clean up temp directory | — |

### Installation Modes

| Mode | Command | Global Skills | `_bmad/` | `_bmad/custom/` |
|------|---------|--------------|----------|-----------------|
| Fresh install | `bash scripts/install.sh` | Wipe + recreate | Create | Create from templates |
| Re-install / upgrade | `bash scripts/install.sh` | Wipe + recreate | Preserve | Preserve |
| Force re-install | `bash scripts/install.sh --force` | Wipe + recreate | Wipe + recreate | Wipe + recreate from templates |

### Dependency Version Pins

| Dependency | Version | Install Command |
|------------|---------|----------------|
| BMAD Method | 6.8.0 | `npx bmad-method@6.8.0 install --modules bmm,cis,wds --tools cursor --yes` |
| git-ai | Current (pin at implementation) | `curl -sSL https://usegitai.com/install.sh \| bash` |
| graphify (graphifyy) | Current (pin at implementation) | `uv tool install graphifyy` |
| Central context repo | HEAD of main branch | `git clone` / `git pull` |

### BMAD Modules

| Module | Code | Purpose |
|--------|------|---------|
| BMAD Method | bmm | Core planning, architecture, and implementation workflows (34+ workflows) |
| Creative Intelligence Suite | cis | Innovation, brainstorming, design thinking, storytelling workflows |
| Web Design Studio | wds | UX design, scenario-driven design, design system workflows |

### Customize.toml Override Strategy

- **Default override files** shipped in lets-b-mad repo under `templates/customize/`
- **install.sh copies** these to `_bmad/custom/{skill-name}.toml` in the workspace during installation
- **Same files across all repos** — identical `on_complete` hooks, `activation_steps_prepend` for context pull, shared script references
- **Protected on re-install** — once copied, developer modifications are preserved unless `--force` is used
- **Override content includes:** `on_complete` pointing to shared post-workflow scripts, `activation_steps_prepend` entries for central context git pull

### File Ownership

| Location | Contains | Managed By |
|----------|----------|-----------|
| lets-b-mad repo | scripts/, templates/, docs/, README.md | lets-b-mad maintainers |
| Workspace root `_bmad/` | Full BMAD config, module configs, scripts, manifests | BMAD installer (via install.sh) |
| Workspace root `_bmad/custom/` | customize.toml overrides | lets-b-mad templates + developer edits |
| `~/.cursor/skills/`, `~/.claude/skills/` | All BMAD skills | install.sh (wiped + recreated every run) |

### Documentation Structure

| File | Audience | Content |
|------|----------|---------|
| `README.md` | AI agents + developers | Agent-readable installation: preflight checks, single-command install, success verification, do-not list. Structured for autonomous agent execution. |
| `docs/guide.md` | Contributors + maintainers | Two sections: (1) Contributing — repo structure, adding/modifying customize.toml templates, testing. (2) Upgrading BMAD — version bump procedure, test-then-rollout, compatibility checklist. |

### Implementation Considerations

- **All scripts in `scripts/`** — single directory for all executable logic. install.sh orchestrates; sub-scripts handle individual concerns.
- **Exit codes** — every script exits with meaningful codes. install.sh prints a summary table (step name, status, error if any).
- **Idempotency** — every operation checks current state before acting. Already-installed dependencies are skipped. Manifest file (`.lets-b-mad/install-manifest.json`) tracks managed files with checksums.
- **Graphify hook ordering** — `graphify hook install` sets up post-commit and post-checkout hooks. git-ai hooks are global. Verify no hook conflicts during install; warn if existing hooks detected.
- **Credentials** — GitLab OAuth tokens retrieved via `git credential fill` / stored via `git credential approve`. Never stored in plaintext files. Never logged in install output.

## Functional Requirements

### Workspace Initialization & Setup

- **FR1:** Developer can install the complete lets-b-mad environment on a fresh macOS workspace using a single command (`bash scripts/install.sh`) with no interactive prompts
- **FR2:** AI coding agent (Cursor/Claude Code) can execute the installation autonomously by reading the repository README
- **FR3:** Developer can force a clean reinstallation of all components using the `--force` flag, overwriting all managed and protected files
- **FR4:** install.sh can detect missing prerequisites (Node.js/npx, Python 3.10+, uv, git, curl) and attempt automatic installation via Homebrew
- **FR5:** install.sh can report clear error messages with manual installation instructions and exit with a non-zero code when prerequisite installation fails
- **FR6:** Developer can see a per-step pass/fail summary table at the end of installation showing each step's name, status, and error details (if any)
- **FR7:** install.sh can re-run on an existing workspace without overwriting developer-customized files (idempotent re-install)
- **FR8:** install.sh can track which files it manages vs. which are developer-customized using a manifest file (`.lets-b-mad/install-manifest.json`)

### Repository Management

- **FR9:** install.sh can auto-discover all initialized git repositories under the workspace root and generate a workspace YAML manifest with relative paths
- **FR10:** Developer can manually edit the workspace YAML manifest to add, remove, or annotate repository entries
- **FR11:** Developer can re-run repository discovery to add newly cloned repos to the YAML without overwriting existing entries (merge-not-overwrite)
- **FR12:** BMAD workflows can read the workspace YAML to determine which repository to target for code and test generation

### AI Code Attribution

- **FR13:** install.sh can install git-ai globally at a pinned version
- **FR14:** git-ai can track AI code attribution per commit automatically after installation, with no per-workflow developer action required
- **FR15:** Developer can view local git-ai statistics per repository using a summary command (`scripts/ai-stats-summary.sh`)
- **FR16:** git-ai attribution data can be consumed by an external aggregation project without any additional lets-b-mad configuration

### Knowledge Graph Management

- **FR17:** install.sh can install graphify (graphifyy) globally via uv at a pinned version
- **FR18:** Developer can initialize graphify for a specific repository to build its initial knowledge graph
- **FR19:** install.sh can install graphify git hooks (post-commit, post-checkout) per discovered repository so that the knowledge graph rebuilds on every commit and branch switch
- **FR20:** install.sh can detect existing git hooks in a repository and warn the developer if hook conflicts are found during installation

### Organizational Context Distribution

- **FR21:** install.sh can clone the central context git repository to a configured location within the workspace
- **FR22:** BMAD workflows can pull the latest central context (git pull) before any workflow starts via `activation_steps_prepend` in customize.toml
- **FR23:** The system can block a BMAD workflow from proceeding and display a warning when the central context pull fails (hard block, not silent degradation)
- **FR24:** Central context author can update organizational context (standards, data dictionary, domain glossary, ADRs) by committing markdown files to the central repo, with changes propagated automatically to all developers on their next workflow invocation

### Skill & Configuration Management

- **FR25:** install.sh can deploy all BMAD skills (BMM, CIS, WDS modules) to global locations (`~/.cursor/skills/` and `~/.claude/skills/`) simultaneously
- **FR26:** install.sh can wipe and recreate global skills from the pinned BMAD version on every run (fresh, re-install, or `--force`)
- **FR27:** install.sh can deploy the full `_bmad/` directory (config, module configs, scripts, manifests) to the workspace root
- **FR28:** install.sh can copy default customize.toml override templates from `templates/customize/` to `_bmad/custom/` per repository
- **FR29:** install.sh can preserve existing `_bmad/custom/*.toml` files on re-install and overwrite them only when `--force` is specified
- **FR30:** install.sh can notify the developer to restart their IDE when global skill files have changed during installation

### Workflow Integration

- **FR31:** BMAD workflows can execute post-workflow actions via `on_complete` hooks defined in `_bmad/custom/*.toml` overrides
- **FR32:** `on_complete` hooks can invoke shared scripts from `scripts/` for post-workflow processing
- **FR33:** `activation_steps_prepend` hooks can execute pre-workflow actions (central context pull, workspace validation) before any BMAD workflow begins

### Credential Management

- **FR34:** install.sh can retrieve existing GitLab credentials using `git credential fill` without storing them in plaintext files
- **FR35:** install.sh can store GitLab credentials securely using `git credential approve` through the native git credential system

### Documentation & Guidance

- **FR36:** The README can serve as a complete, agent-executable installation guide with preflight checks, single-command install, success verification criteria, and a do-not list
- **FR37:** Developer can find contribution guidelines (repo structure, template modification, testing) and upgrade procedures (version bump, test-then-rollout, compatibility checklist) in `docs/guide.md`

### Phase 2: Gamification Event Push (Growth)

- **FR38:** The system can push a workflow completion event (workflow name + user auth context) to a GitLab OAuth-protected endpoint after any BMAD workflow completes
- **FR39:** The system can continue normal operation when the event push fails (fail-open, warn-and-continue, non-blocking)

### Phase 2: Installation Validation (Growth)

- **FR40:** Developer can validate their installation health at any time using a dedicated command that checks skill resolution, hook status, version correctness, and context freshness

## Non-Functional Requirements

### Performance

- **NFR1:** install.sh completes full workspace setup (prerequisites + BMAD + git-ai + graphify + context clone + YAML discovery) in under 5 minutes on a typical developer machine with stable network connectivity
- **NFR2:** Pre-workflow context pull (`activation_steps_prepend` git pull) adds no more than 10 seconds to workflow startup under normal network conditions
- **NFR3:** Graphify post-commit hook execution completes within 30 seconds for repositories under 100,000 lines of code, without blocking the developer's next git operation
- **NFR4:** Workspace YAML discovery scans and generates the manifest within 5 seconds for workspaces containing up to 50 repositories

### Security

- **NFR5:** GitLab credentials are never stored in plaintext files, environment variables, or lets-b-mad configuration files — only in the native git credential store
- **NFR6:** install.sh never logs, prints, or echoes credential values (tokens, passwords) in terminal output, log files, or error messages
- **NFR7:** Central context repository access uses the developer's existing git SSH keys or credential manager — lets-b-mad does not introduce a separate authentication mechanism
- **NFR8:** `.lets-b-mad/install-manifest.json` contains only file paths and checksums — no credentials, tokens, or sensitive configuration values

### Integration

- **NFR9:** All external dependencies (BMAD, git-ai, graphify, central context repo) are version-pinned with exact versions — no floating ranges, no "latest" resolution
- **NFR10:** Failure in any single integration (git-ai install, graphify install, context clone) does not prevent installation of remaining components — install.sh continues and reports all failures in the summary table
- **NFR11:** git-ai global hooks and graphify per-repo hooks coexist without conflict — install.sh verifies hook compatibility and warns on detected conflicts rather than silently overwriting
- **NFR12:** Central context git pull failure at workflow start is a hard block — the workflow must not proceed with stale context under any circumstances

### Reliability

- **NFR13:** install.sh is fully idempotent — running it N times on the same workspace produces the same result as running it once, with no accumulated side effects
- **NFR14:** Graphify git hooks fail gracefully — a graphify indexing error must not prevent the underlying git commit or checkout from completing
- **NFR15:** Git hook execution (post-commit, post-checkout) must not corrupt the git repository state under any failure condition (crash, timeout, disk full)
- **NFR16:** install.sh exits with distinct non-zero exit codes per failure category (prerequisite failure, BMAD install failure, dependency failure, context clone failure) to enable scripted error handling

### Maintainability

- **NFR17:** BMAD version upgrades (e.g., 6.8.0 to 6.9.x) require changing exactly one value (the version pin in install.sh) — no other code changes needed for standard upgrades
- **NFR18:** Adding a new customize.toml override for a BMAD skill requires adding one template file to `templates/customize/` and no changes to install.sh logic
- **NFR19:** All version pins (BMAD, git-ai, graphify) are declared in a single configuration section of install.sh — not scattered across multiple files or scripts
- **NFR20:** The lets-b-mad repository contains zero lines of BMAD workflow, agent, or skill code — all BMAD content is generated at install time from the pinned BMAD package
