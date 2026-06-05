---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-05-29'
lastEdited: '2026-06-05'
editHistory:
  - date: '2026-06-05'
    changes: 'Aligned with updated PRD — dual workspace layout modes (standalone/multi-repo), workspace-local central context, per-target-repo customize.toml and graphify hooks, MVP credential handling (FR34-FR35), workspace folder prompt (FR1a), layout detection (FR9a), per-repo graphify init (FR18a), bash runtime'
  - date: '2026-05-29'
    changes: 'Initial architecture complete'
inputDocuments:
  - 'prd.md'
  - 'prd-validation-report.md'
  - 'references.md'
  - 'uploads/BMAD-METHOD.md'
  - 'uploads/git-ai.md'
  - 'uploads/graphify.md'
workflowType: 'architecture'
project_name: 'lets-b-mad'
user_name: 'Ajit'
date: '2026-05-29'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
43 FRs across 10 categories (including FR1a, FR9a, FR18a). The system is a workspace-level orchestration layer — not an application with runtime logic. The FR surface breaks into three functional pillars:
1. **Bootstrap & Install (FR1-FR8, FR1a):** Idempotent single-command setup with workspace folder prompt at startup, prerequisite detection/installation, managed-vs-protected file tracking via install manifest, `--force` for clean reset.
2. **Integration Wiring (FR9-FR33, FR9a, FR18a):** Layout-aware workspace YAML auto-discovery (standalone vs multi-repo), git-ai global install + per-commit tracking, graphify init + git hooks on layout-appropriate target repos, central context clone at workspace root + pre-workflow pull via `activation_steps_prepend`, global skill deployment to both IDEs, per-target-repo `customize.toml` override management, `on_complete` hook execution.
3. **Enablement & Observability (FR34-FR40):** GitLab credential retrieval/storage via native git credential store (MVP), agent-readable README, contributor/upgrade guide, Phase 2 gamification event push and installation validation.

**Non-Functional Requirements:**
20 NFRs define the quality envelope:
- **Performance (NFR1-4):** Strict time budgets — install < 5min, context pull < 10s, graphify hook < 30s (100K LOC), YAML scan < 5s (50 repos).
- **Security (NFR5-8):** Zero plaintext credentials anywhere — git credential store only, no logging of tokens, no sensitive data in manifest.
- **Integration (NFR9-12):** Exact version pins (no floating), continue-on-failure during install, hook coexistence verification, hard-block on stale context.
- **Reliability (NFR13-16):** Full idempotency, graceful hook failure (never corrupt git state), distinct exit codes per failure category.
- **Maintainability (NFR17-20):** Single-value version bump for upgrades, single-file template addition for new overrides, centralized version declarations, zero BMAD source code.

**Scale & Complexity:**

- Primary domain: CLI / DevOps tooling (bash, git hooks, file system, YAML/TOML)
- Complexity level: Medium
- Estimated architectural components: 7 (install orchestrator, prerequisite manager, dependency installer, workspace discoverer + layout detector, file manifest tracker, hook manager, credential helper)

### Technical Constraints & Dependencies

| Constraint | Impact |
|-----------|--------|
| macOS Apple Silicon only | No cross-platform abstractions needed; bash and Homebrew assumptions are safe |
| Bash shell (not POSIX sh) | PRD specifies bash pre-installed on macOS; bash arrays and `[[ ]]` are acceptable |
| Workspace folder prompt at install startup | install.sh prompts once for workspace folder path before any steps; all subsequent operations use that path as workspace root |
| Dual workspace layout modes | **Standalone:** workspace root is sole git repo (YAML entry path `.`); graphify/hooks at workspace root. **Multi-repo:** one or more nested git repos; workspace root holds orchestration assets (`_bmad/`, `workspace.yaml`, central context) but is never a graphify/hook target when nested repos exist — even if workspace root is also a git repo |
| BMAD v6.8.0 pinned, zero source modifications | All integration through `customize.toml` hooks (`on_complete`, `activation_steps_prepend`) and shared scripts — architecture must never require BMAD source changes |
| git-ai installs globally via curl | Global hooks auto-track AI attribution; no per-repo configuration needed |
| graphify installs globally via uv, hooks are layout-aware per target repo | post-commit and post-checkout hooks installed only in target repos per active layout mode; hook conflict detection required |
| Central context is a git repo of markdown at workspace root | Cloned to `<workspace-root>/central-context/` at install; freshness guaranteed by `git pull` before every workflow; pull failure = hard block |
| Global skills deployed to two paths simultaneously | `~/.cursor/skills/` and `~/.claude/skills/` — wiped and recreated on every install run |
| `_bmad/custom/*.toml` per target repo | Full `_bmad/` at workspace root; `customize.toml` templates copied to `_bmad/custom/` in each target repo (standalone: workspace root; multi-repo: each nested repo). Protected on re-install, overwritten only with `--force` |
| GitLab credentials via git credential system | MVP requirement — retrieve via `git credential fill`, store via `git credential approve`; never plaintext |

### Cross-Cutting Concerns Identified

1. **Idempotency & State Tracking:** Every install operation must check current state (via `.lets-b-mad/install-manifest.json` with checksums) before acting. Running install N times = same result as running once. This concern spans every component.

2. **File Ownership Model:** Three-tier ownership — managed (wiped/recreated freely), protected (preserved on re-install, overwritten with `--force`), and external (central context, git-ai, graphify — state lives outside lets-b-mad). Architecture must make this distinction explicit and enforceable.

3. **Failure Strategy Duality:** Install-time failures are tolerant (continue and report all in summary — NFR10). Runtime (workflow-start) failures on context freshness are strict (hard block — NFR12). Graphify hook failures are graceful (never corrupt git — NFR14-15). The architecture must implement three distinct failure strategies.

4. **Hook Coexistence:** git-ai global hooks and graphify per-repo hooks (post-commit, post-checkout) must coexist without conflict. Install must detect existing hooks and warn (FR20, NFR11).

5. **Version Pin Centralization:** All dependency versions (BMAD, git-ai, graphify) declared in a single configuration section of install.sh (NFR19). Upgrade = change one value (NFR17).

6. **Layout-Aware Targeting:** graphify init, graphify hooks, and customize.toml deployment all resolve target repositories from the detected layout mode. The same discovery algorithm drives workspace YAML generation and downstream install steps — standalone and multi-repo must never diverge in detection logic.

## Starter Template Evaluation

### Primary Technology Domain

CLI / DevOps tooling — bash scripts, YAML/TOML configuration, markdown documentation. No application runtime, no build system, no framework. The "starter" is the repository structure itself.

### Starter Options Considered

| Option | Description | Verdict |
|--------|-------------|---------|
| Framework starter (oclif, commander) | CLI frameworks for structured command-line tools | **Rejected** — lets-b-mad is an install orchestrator + config layer, not a user-facing CLI with subcommands. A framework adds dependency weight with no benefit. |
| Makefile task runner | Use `make` to organize install steps as targets | **Rejected** — direct script invocation is simpler, and `make` adds indirection without value for a single-entry-point tool (`install.sh`). |
| Bare repository with conventions | Bash scripts, directory conventions, linting tools | **Selected** — minimal dependencies, aligned with PRD macOS/bash target and project's nature as a thin orchestration layer. |

### Selected Starter: Bare Repository with Conventions

**Rationale for Selection:**
lets-b-mad ships bash scripts, config templates, and documentation. It needs no build step, no package manager, no framework. The architecture is defined by directory structure, scripting conventions, and toolchain choices — not by a starter template.

**Project Structure:**

```
lets-b-mad/
├── scripts/
│   ├── install.sh                    # Entry point — orchestrates all steps
│   ├── lib/
│   │   ├── common.sh                 # Shared functions (logging, checksum, platform detection)
│   │   ├── prerequisites.sh          # Prerequisite detection and installation
│   │   ├── bmad.sh                   # BMAD install + global skill deployment
│   │   ├── dependencies.sh           # git-ai + graphify installation
│   │   ├── context.sh                # Central context repo clone/pull to workspace root
│   │   ├── workspace.sh              # Workspace YAML auto-discovery + layout detection
│   │   ├── hooks.sh                  # Graphify init + hook install per layout-appropriate target repo
│   │   └── manifest.sh               # Install manifest tracking (checksums, managed vs protected)
│   └── ai-stats-summary.sh           # Local git-ai metrics summary
├── templates/
│   └── customize/                    # customize.toml override templates
│       └── *.toml
├── docs/
│   └── guide.md                      # Contributor guidelines + upgrade procedures
├── .shellcheckrc                     # shellcheck configuration
├── .markdownlint-cli2.yaml           # markdownlint configuration
├── README.md                         # Agent-readable installation guide
└── .gitignore
```

**Architectural Decisions Provided by Structure:**

**Language & Runtime:**
- Bash (`#!/usr/bin/env bash`) for all scripts — PRD specifies bash on macOS; enables arrays and robust string handling for repo discovery
- `set -euo pipefail` in orchestrator (`install.sh`); library modules use guard-clause returns, not global errexit
- `shellcheck` v0.11.0 for static analysis with bash compliance enforcement

**Data Processing Tools:**
- `jq` v1.8.1 for JSON manipulation (install manifest, git-ai stats)
- `yq` v4.53.2 (mikefarah) for YAML manipulation (workspace manifest)
- Both installed via Homebrew as prerequisites; version-pinned in the version configuration block

**Checksum Strategy (Cross-Platform):**
Portable wrapper function using platform detection:

```sh
compute_checksum() {
    case "$(uname -s)" in
        Linux*)  sha256sum "$1" | cut -d' ' -f1 ;;
        Darwin*) shasum -a 256 "$1" | cut -d' ' -f1 ;;
        CYGWIN*|MINGW*|MSYS*) sha256sum "$1" | cut -d' ' -f1 ;;
        *)       shasum -a 256 "$1" | cut -d' ' -f1 ;;
    esac
}
```

**Documentation Linting:**
- `markdownlint-cli2` v0.22.1 for markdown quality enforcement
- Configuration via `.markdownlint-cli2.yaml` in repository root

**Code Organization:**
- Single entry point (`install.sh`) sources library modules from `scripts/lib/`
- Each library module is a self-contained concern (single responsibility)
- Shared utilities (logging, checksum, platform detection) in `common.sh`
- No circular dependencies between library modules

**Development Experience:**
- `shellcheck` runs locally during development; can integrate into pre-commit or CI
- `markdownlint-cli2` validates documentation
- No build step required — scripts are executable as-is

**Note:** Project initialization is simply creating this directory structure and the foundational files. The first implementation story.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Script communication: return codes + stdout/stderr separation
- Logging with summary collector for FR6 compliance
- Install manifest schema with dual-checksum tracking
- Workspace folder prompt as install step 0 (FR1a)
- Layout detection: standalone vs multi-repo drives all downstream targeting (FR9a)
- `activation_steps_prepend` via shared `pre-workflow.sh`
- Central context at workspace-local `<workspace-root>/central-context/`

**Important Decisions (Shape Architecture):**
- Range-based exit code schema
- Smart merge detection for protected files
- Stub `post-workflow.sh` wired from day one
- Per-skill customize.toml generated from single default template, deployed per target repo
- Recursive repo discovery (depth 3, well-known excludes) with layout mode selection
- GitLab credential helper via `git credential fill` / `git credential approve` (FR34-FR35)

**Deferred Decisions (Post-MVP):**
- Multi-org central context support
- Global state cleanup/purge command
- `--force` granularity flags (`--force-skills`, `--force-config`)

### Script Communication & Error Handling

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Inter-module communication | Return codes + stdout for data, stderr for logging | Standard POSIX convention; modules return data on stdout, human messages on stderr |
| Logging standard | Structured functions (`log_info`, `log_warn`, `log_error`, `log_success`) with summary collector | FR6 requires per-step summary table; collector built into logging layer gives it for free |
| Exit code schema | Range-based grouping (10-19: prerequisites, 20-29: BMAD, 30-39: dependencies, 40-49: context, 50-59: hooks) | NFR16 requires distinct codes; ranges allow sub-codes and immediate category identification |

### File Ownership & Manifest Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Manifest schema | JSON with `version`, `versions`, `files.managed`, `files.protected` (dual checksum), `workspace` | Tracks managed vs protected files, installed dependency versions, and workspace state |
| Protected file updates | Smart merge detection — auto-update if file matches template checksum, warn and preserve if developer modified | Handles common case (untouched = safe to update) and rare case (customized = preserve + warn) |

### Credential & Security Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Central context repo URL | Hardcoded in install.sh version configuration block | Single org, single source of truth alongside version pins |
| Credential management | `git credential fill` to retrieve, `git credential approve` to store; never log or persist in config files | FR34-FR35 MVP requirement; establishes auth pattern for Phase 2 gamification endpoint; NFR5-6 compliance |
| Credential scope | GitLab OAuth tokens only; central context uses existing SSH/credential helper | No separate auth mechanism for context repo (NFR7) |

### Workspace Layout Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Layout detection | After repo discovery, select **standalone** (workspace root is only git repo, no nested repos) or **multi-repo** (one or more nested git repos under workspace root) | FR9a; single detection pass drives YAML, graphify, hooks, and customize.toml targets |
| Standalone targeting | Single YAML entry (path `.`); graphify init/hooks at workspace root; customize.toml at workspace root `_bmad/custom/` | Typical single-project install |
| Multi-repo targeting | One YAML entry per nested repo (relative paths, not `.`); graphify init/hooks only in nested repos; workspace root excluded from graphify/hooks even if it is a git repo | FR18, FR19; workspace root holds shared orchestration only |
| Workspace root role | Always holds `_bmad/`, `workspace.yaml`, `central-context/`, `.lets-b-mad/`; may or may not be a git repository | Multi-repo container pattern from PRD user journeys |
| On-demand re-discovery | `scripts/discover-repos.sh` (or equivalent) merges new repos into YAML without overwriting existing entries (FR11) | Arjun edge-case journey; Phase 2 may add richer auto-sync |

### BMAD Integration Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| `activation_steps_prepend` | Delegate to shared `scripts/pre-workflow.sh`; absolute path written into customize.toml at install time | Single source of truth for pre-workflow logic; avoids runtime path resolution |
| `on_complete` | Stub `scripts/post-workflow.sh` with extension points, wired in templates from day one | Templates ship complete; Phase 2 gamification is a single-file change, no template updates needed |
| customize.toml granularity | Single default template (`templates/customize/_default.toml`); install.sh generates per-skill `.toml` files from it, copied to `_bmad/custom/` in each target repo | One template to maintain; per-skill files allow future skill-specific overrides; NFR18 satisfied; FR28 per-target-repo deployment |

### Hook Management Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hook installation | Delegate to `graphify hook install` in each layout-appropriate target repo with post-install verification via `graphify hook status` | graphify manages its own hooks; lets-b-mad never installs graphify hooks at workspace root in multi-repo mode |
| Hook conflict detection | Rely on graphify's behavior + status check; warn if status reports issues | Avoids lets-b-mad understanding hook file internals; graphify is the source of truth for its own hooks |

### Workspace Discovery & Configuration

| Decision | Choice | Rationale |
|----------|--------|-----------|
| YAML manifest schema | `workspace.name`, `workspace.root`, `workspace.layout` (`standalone` \| `multi-repo`), `repos[].path` (relative), `repos[].name`, `repos[].graphify_initialized` | Portable, extensible, human-editable; layout field drives runtime validation |
| Auto-discovery algorithm | Recursive scan from workspace root, depth limit 3, exclude well-known directories; then apply layout selection rules | Handles nested repo structures while avoiding false positives; FR9, FR9a |
| Central context location | Workspace-local: `<workspace-root>/central-context/` | FR21 — cloned within workspace, not global; each developer workspace is self-contained |
| Target repo resolution | Shared function `get_target_repos()` returns repo paths based on `workspace.layout` from YAML or fresh detection | Single source of truth used by hooks.sh, bmad.sh (customize.toml copy), and graphify init |

### Decision Impact Analysis

**Implementation Sequence:**
0. `install.sh` workspace prompt — validate path, export `WORKSPACE_ROOT` (FR1a)
1. `common.sh` — logging, checksum, platform detection, exit codes (foundation for everything)
2. `manifest.sh` — install manifest CRUD (needed by all subsequent install steps)
3. `prerequisites.sh` — prerequisite detection (gates all dependency installs)
4. `bmad.sh` — BMAD install + skill deployment + customize.toml generation per target repo
5. `dependencies.sh` — git-ai + graphify installation + credential helper setup
6. `context.sh` — central context clone to `<workspace-root>/central-context/`
7. `workspace.sh` — repo discovery, layout detection, YAML generation
8. `hooks.sh` — graphify init + hook install per layout-appropriate target repo
9. `install.sh` — orchestrator wiring all modules + summary table
10. `pre-workflow.sh` + `post-workflow.sh` — runtime scripts
11. `discover-repos.sh` — on-demand repo re-discovery with merge-not-overwrite (FR11)

**Cross-Component Dependencies:**
- All modules depend on `common.sh` (logging, exit codes)
- Workspace prompt (step 0) must complete before any workspace-scoped operation
- `workspace.sh` must run before `hooks.sh` and customize.toml copy in `bmad.sh` (repo list and layout mode must be known)
- `bmad.sh` must run before `hooks.sh` (skills must exist before hooks reference them)
- `context.sh` is independent — can run in any order relative to other dependency installs
- `manifest.sh` is used by `bmad.sh` and `context.sh` to track installed files
- `get_target_repos()` in `workspace.sh` is the shared layout resolver for hooks, graphify, and customize.toml deployment

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:** 4 areas where AI agents could make different choices — naming, structure, format, and process patterns.

### Naming Patterns

**Script & File Naming:**

| Type | Convention | Example |
|------|-----------|---------|
| Executable scripts | `kebab-case.sh` | `ai-stats-summary.sh`, `pre-workflow.sh` |
| Library modules (sourced) | `snake_case.sh` | `common.sh`, `prerequisites.sh` |
| Templates | Match target filename | `_default.toml` |
| Documentation | `kebab-case.md` | `guide.md` |

**Function Naming:**

| Convention | Example |
|-----------|---------|
| `snake_case` for all functions | `log_info`, `compute_checksum` |
| Module prefix for exported functions | `manifest_read`, `manifest_write`, `hooks_install`, `hooks_verify` |

**Variable Naming:**

| Type | Convention | Example |
|------|-----------|---------|
| Constants (versions, exit codes, paths) | `UPPER_SNAKE_CASE` | `BMAD_VERSION`, `EXIT_PREREQ_MISSING`, `CONTEXT_REPO_URL` |
| Local/working variables | `lower_snake_case` | `repo_path`, `checksum_value` |
| No single-letter variables | Exception: loop counters only | — |

**Config Key Naming:**

| Format | Convention |
|--------|-----------|
| YAML (workspace manifest) | `snake_case` |
| JSON (install manifest) | `snake_case` |
| TOML (customize overrides) | Follow BMAD's existing convention |

### Structure Patterns

**Library Module Sourcing:**
- Resolve script directory: `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`
- Source with absolute path: `. "$SCRIPT_DIR/lib/common.sh"`
- Source order: `common.sh` always first
- Modules must be side-effect-free at top level — only function definitions and constant declarations

**Function Structure:**
- Guard clauses with early return (never nested if/else chains)
- Library functions return non-zero on failure — never call `exit` (only `install.sh` exits)
- Data to stdout, status messages to stderr

**Temp File Discipline:**
- Single temp directory via `mktemp -d` at install start
- Cleanup via `trap cleanup EXIT` in `install.sh` only
- Library modules never create their own cleanup traps

**Quoting Discipline:**
- All variable expansions double-quoted: `"$var"`, `"${var}"`
- All command substitutions double-quoted: `"$(command)"`
- No `# shellcheck disable` without an explaining comment

### Format Patterns

**Logging Format:**
- Prefix: `[LEVEL] message` — levels: `INFO`, `WARN`, `ERROR`, `PASS`, `FAIL`
- No timestamps (scripts are short-lived)
- Color when stderr is a terminal (`[ -t 2 ]`), plain text otherwise
- Summary table at end: fixed-width columns `Step Name | Status | Details`

### Process Patterns

**Error Handling:**
- Guard clause style: `command || { log_error "..."; return 1; }`
- Network operations get one retry with 3-second sleep before failure
- Destructive operations verify source exists before deleting target

**Idempotency Enforcement:**
- Every function checks current state before acting (already installed? right version? right checksum?)
- Install manifest is source of truth; filesystem verification as fallback

**Shell Compliance:**
- `#!/usr/bin/env bash` on every script
- `shellcheck` with `shell=bash` in `.shellcheckrc`
- Prefer portable bash constructs; avoid bash 4+ features not available on macOS default bash 3.2 where possible (e.g., use `readarray` alternatives)
- `local` and `[[ ]]` allowed

### Enforcement Guidelines

**All AI Agents MUST:**
- Follow naming conventions exactly — no camelCase functions, no unquoted variables
- Use guard clauses, never nested conditionals for error paths
- Never call `exit` from library modules — return codes only
- Never create temp files outside the shared temp directory
- Never add `# shellcheck disable` without justification

**Pattern Enforcement:**
- `shellcheck` validates bash compliance and quoting discipline on every script
- `markdownlint-cli2` validates documentation formatting
- Code review checks naming conventions and function structure

### Pattern Examples

**Good:**

```sh
manifest_write() {
    local manifest_path="$1"
    local content="$2"

    [ -z "$manifest_path" ] && { log_error "manifest_write: path required"; return 1; }

    printf '%s\n' "$content" > "$manifest_path" || { log_error "Failed to write manifest"; return 1; }
    log_info "Manifest written to $manifest_path"
}
```

**Anti-Patterns:**

```sh
# BAD: nested conditionals, unquoted vars, exit from library, no module prefix
writeManifest() {
    if [ -n $1 ]; then
        echo $2 > $1
        if [ $? -ne 0 ]; then
            echo "ERROR: failed"
            exit 1
        fi
    fi
}
```

## Project Structure & Boundaries

### Complete Project Directory Structure

```
lets-b-mad/
├── scripts/
│   ├── install.sh                        # Orchestrator — entry point; prompts for workspace folder (step 0)
│   ├── pre-workflow.sh                   # Runtime — central context pull before BMAD workflows
│   ├── post-workflow.sh                  # Runtime — stub with extension points for Phase 2
│   ├── discover-repos.sh                 # Utility — on-demand repo re-discovery with merge-not-overwrite (FR11)
│   ├── ai-stats-summary.sh              # Utility — local git-ai metrics per repo
│   └── lib/
│       ├── common.sh                     # Foundation — logging, checksum, platform detection, exit codes, constants
│       ├── prerequisites.sh              # Step — detect/install Node.js, Python, uv, git, curl, jq, yq
│       ├── bmad.sh                       # Step — BMAD install via npx, global skill deployment, customize.toml per target repo
│       ├── dependencies.sh               # Step — git-ai install (curl), graphify install (uv), credential helper
│       ├── context.sh                    # Step — central context repo clone/pull to <workspace-root>/central-context/
│       ├── workspace.sh                  # Step — recursive repo discovery, layout detection, YAML generation, get_target_repos()
│       ├── hooks.sh                      # Step — graphify init + hook install per layout-appropriate target repo
│       └── manifest.sh                   # Support — install manifest CRUD, checksum comparison, managed/protected logic
├── templates/
│   └── customize/
│       └── _default.toml                 # Source template — activation_steps_prepend + on_complete hooks
├── docs/
│   └── guide.md                          # Contributor guidelines + BMAD upgrade procedures
├── .shellcheckrc                         # shellcheck config: shell=bash
├── .markdownlint-cli2.yaml              # markdownlint config
├── .gitignore                            # Exclude .lets-b-mad/, temp files, OS artifacts
├── README.md                             # Agent-readable install guide: preflight, single-command, verification
└── LICENSE
```

**Generated at install time (not in repo):**

```
<workspace-root>/                          # Developer-supplied workspace folder
├── .lets-b-mad/
│   └── install-manifest.json             # Tracks managed/protected files, versions, workspace state
├── workspace.yaml                        # Auto-discovered repo listing with layout mode
├── central-context/                      # Cloned org context repo (workspace-local)
│   ├── standards/
│   ├── data-dictionary/
│   ├── domain-glossary/
│   └── adrs/
└── _bmad/                                # Generated by npx bmad-method (BMAD-owned, at workspace root)
    ├── bmm/                              # BMAD Method module config
    ├── cis/                              # Creative Intelligence Suite config
    ├── wds/                              # Web Design Studio config
    └── custom/                           # customize.toml in standalone mode only (workspace root is target repo)

# Standalone layout — workspace root is the sole target repo:
<workspace-root>/_bmad/custom/*.toml      # Per-skill customize.toml overrides

# Multi-repo layout — each nested repo is a target:
<workspace-root>/<nested-repo>/_bmad/custom/*.toml   # Per-skill overrides per nested repo
<workspace-root>/<nested-repo>/graphify-out/graph.json

~/.cursor/skills/                         # Global BMAD skills (wiped+recreated per install)
~/.claude/skills/                         # Global BMAD skills (wiped+recreated per install)
```

### Architectural Boundaries

**Boundary 1: Repository (what ships in git) vs. Generated (created at install time)**
- Repository contains only source scripts, templates, docs, and config
- Everything under `.lets-b-mad/`, `_bmad/`, `workspace.yaml`, `central-context/`, global skill paths is generated
- Agents implementing features must never assume generated files exist at development time

**Boundary 2: Install-time (scripts/lib/) vs. Runtime (pre-workflow.sh, post-workflow.sh)**
- `scripts/lib/*.sh` modules run only during `install.sh` execution
- `pre-workflow.sh` and `post-workflow.sh` run independently during BMAD workflows
- Runtime scripts must not source install-time library modules — they are self-contained
- Runtime scripts can read the install manifest but must not write to it

**Boundary 3: lets-b-mad owned vs. BMAD owned vs. External tool owned**
- lets-b-mad owns: `scripts/`, `templates/`, `docs/`, `.lets-b-mad/`, `workspace.yaml`, `central-context/`
- BMAD owns: `_bmad/` at workspace root (except per-repo `_bmad/custom/`), `~/.cursor/skills/`, `~/.claude/skills/`
- `_bmad/custom/` is a shared boundary: generated by lets-b-mad per target repo, editable by developer, consumed by BMAD
- git-ai owns: its global hooks and per-commit Git Notes
- graphify owns: its per-repo hooks, `graphify-out/` directories

### Requirements to Structure Mapping

| FR Group | Primary File(s) | Supporting Files |
|----------|-----------------|-----------------|
| **FR1-FR3, FR1a** (Install modes) | `scripts/install.sh` | `scripts/lib/common.sh` (flags parsing, workspace prompt) |
| **FR4-FR5** (Prerequisites) | `scripts/lib/prerequisites.sh` | `scripts/lib/common.sh` (exit codes) |
| **FR6** (Summary table) | `scripts/lib/common.sh` (summary collector) | `scripts/install.sh` (prints table) |
| **FR7-FR8** (Idempotency, manifest) | `scripts/lib/manifest.sh` | `.lets-b-mad/install-manifest.json` |
| **FR9-FR12, FR9a** (Repo management) | `scripts/lib/workspace.sh` | `workspace.yaml`, `scripts/discover-repos.sh` |
| **FR13-FR16** (git-ai) | `scripts/lib/dependencies.sh` | `scripts/ai-stats-summary.sh` |
| **FR17-FR20, FR18a** (graphify) | `scripts/lib/dependencies.sh`, `scripts/lib/hooks.sh` | `workspace.sh` (`get_target_repos()`) |
| **FR21-FR24** (Central context) | `scripts/lib/context.sh`, `scripts/pre-workflow.sh` | `<workspace-root>/central-context/` |
| **FR25-FR30** (Skills & config) | `scripts/lib/bmad.sh` | `templates/customize/_default.toml` |
| **FR31-FR33** (Workflow hooks) | `scripts/pre-workflow.sh`, `scripts/post-workflow.sh` | `_bmad/custom/*.toml` (per target repo) |
| **FR34-FR35** (Credentials) | `scripts/lib/dependencies.sh` (credential helper) | git credential store |
| **FR36** (README) | `README.md` | — |
| **FR37** (Guide) | `docs/guide.md` | — |
| **FR38-FR40** (Phase 2) | `scripts/post-workflow.sh` (future) | — |

### Integration Points

**Internal Communication (install-time):**

```
install.sh
  ├── prompts → workspace folder path (FR1a)
  ├── sources → common.sh (logging, constants, exit codes)
  ├── sources → manifest.sh (read/write manifest)
  ├── calls → prerequisites.sh functions (detect, install prereqs)
  ├── calls → bmad.sh functions (install BMAD, deploy skills, generate+copy toml per target repo)
  ├── calls → dependencies.sh functions (install git-ai, graphify, credential helper)
  ├── calls → context.sh functions (clone central context to workspace root)
  ├── calls → workspace.sh functions (discover repos, detect layout, generate YAML)
  └── calls → hooks.sh functions (graphify init + install hooks per layout-appropriate target repo)
```

**External Integrations:**

| Integration | Direction | Interface |
|------------|-----------|-----------|
| BMAD (npx) | lets-b-mad → BMAD | `npx bmad-method@6.8.0 install --modules bmm,cis,wds --tools cursor --yes` |
| git-ai | lets-b-mad → git-ai | `curl -sSL https://usegitai.com/install.sh \| bash` |
| graphify | lets-b-mad → graphify | `uv tool install graphifyy`, `graphify hook install`, `graphify hook status` |
| Central context | lets-b-mad → git | `git clone <url>`, `git pull --ff-only` |
| BMAD workflows | BMAD → lets-b-mad | `activation_steps_prepend` → `pre-workflow.sh`, `on_complete` → `post-workflow.sh` |

**Data Flow:**

```
Install flow:
  install.sh → [workspace prompt] → [prereqs check] → [BMAD install] → [skill deploy]
             → [toml generate + copy per target repo] → [git-ai install] → [graphify install]
             → [context clone to workspace root] → [repo discover + layout detect] → [YAML write]
             → [graphify init per target repo] → [hooks install per target repo] → [manifest write]
             → [summary table]

Runtime flow (per BMAD workflow):
  BMAD skill start → activation_steps_prepend → pre-workflow.sh
                   → git pull <workspace-root>/central-context/
                   → success: workflow proceeds | failure: hard block

  BMAD skill end → on_complete → post-workflow.sh → (stub, Phase 2: event push)
```

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
- All technology choices are compatible: bash + jq + yq + shellcheck form a coherent, minimal toolchain with no conflicts
- Version pins are independent — BMAD (npm), git-ai (curl/binary), graphify (uv/Python) have no shared dependency conflicts
- The customize.toml integration pattern (absolute paths written at install time) is compatible with workspace-local central context and per-target-repo deployment
- Layout detection drives consistent targeting across workspace YAML, graphify, hooks, and customize.toml — no conflicting repo resolution logic

**Pattern Consistency:**
- Naming conventions are internally consistent: snake_case functions/variables, UPPER_SNAKE_CASE constants, kebab-case executables
- The stdout/stderr separation pattern aligns with the summary collector design — logging goes to stderr, collector captures step results independently
- Guard clause pattern + return-not-exit rule + single orchestrator exit point form a coherent error handling architecture

**Structure Alignment:**
- Project structure maps 1:1 to the library module decisions from step 4
- The install-time vs. runtime boundary cleanly separates `scripts/lib/` from `pre-workflow.sh`/`post-workflow.sh`
- The three-tier file ownership model (managed/protected/external) is reflected in the directory structure and manifest schema
- Standalone and multi-repo layout artifacts are explicitly documented in generated structure

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:**

| FR Range | Status | Notes |
|----------|--------|-------|
| FR1-FR8, FR1a (Install) | ✅ Fully covered | `install.sh` workspace prompt + `manifest.sh` + `common.sh` (flags, idempotency, manifest) |
| FR9-FR12, FR9a (Repos) | ✅ Fully covered | `workspace.sh` with layout detection, depth-3 recursive scan, `discover-repos.sh` for FR11 |
| FR13-FR16 (git-ai) | ✅ Fully covered | `dependencies.sh` + `ai-stats-summary.sh` |
| FR17-FR20, FR18a (graphify) | ✅ Fully covered | `dependencies.sh` + `hooks.sh` with layout-aware `get_target_repos()` |
| FR21-FR24 (Context) | ✅ Fully covered | `context.sh` + `pre-workflow.sh` + workspace-local `central-context/` |
| FR25-FR30 (Skills) | ✅ Fully covered | `bmad.sh` (skill deploy, toml generation per target repo, IDE restart notification) |
| FR31-FR33 (Hooks) | ✅ Fully covered | `pre-workflow.sh` + `post-workflow.sh` + customize.toml templates |
| FR34-FR35 (Credentials) | ✅ Fully covered | `dependencies.sh` credential helper via git credential store |
| FR36-FR37 (Docs) | ✅ Fully covered | `README.md` + `docs/guide.md` |
| FR38-FR40 (Phase 2) | ⏸ Deferred | Extension point exists (`post-workflow.sh` stub) |

**Non-Functional Requirements Coverage:**

| NFR | Status | Architectural Support |
|-----|--------|----------------------|
| NFR1 (Install < 5min) | ✅ | Sequential steps with no unnecessary work (idempotency skips) |
| NFR2 (Context pull < 10s) | ✅ | Single `git pull --ff-only` on local clone — bounded by network |
| NFR3 (Graphify hook < 30s) | ✅ | Delegated to graphify — performance is graphify's concern |
| NFR4 (YAML scan < 5s) | ✅ | Recursive find with depth limit 3 + excludes — fast by design |
| NFR5-8 (Security) | ✅ | Git credential store for GitLab; no plaintext credential storage; manifest contains only paths/checksums; git native auth for context repo |
| NFR9 (Version pins) | ✅ | All versions in single config block in install.sh |
| NFR10 (Continue on failure) | ✅ | Summary collector pattern — each step logs pass/fail, orchestrator continues |
| NFR11 (Hook coexistence) | ✅ | Delegated to graphify + post-install verification |
| NFR12 (Hard block on stale) | ✅ | `pre-workflow.sh` exits non-zero on pull failure — BMAD blocks |
| NFR13 (Idempotency) | ✅ | Manifest-based state tracking + checksum verification |
| NFR14-15 (Hook safety) | ✅ | Delegated to graphify — lets-b-mad doesn't manage hook internals |
| NFR16 (Exit codes) | ✅ | Range-based schema defined (10-59) |
| NFR17 (Single-value upgrade) | ✅ | Version config block — change one constant |
| NFR18 (Single-file override) | ✅ | Add one template to `templates/customize/` |
| NFR19 (Centralized pins) | ✅ | All in install.sh config block |
| NFR20 (Zero BMAD source) | ✅ | All integration via customize.toml + shared scripts |

### Implementation Readiness Validation ✅

**Decision Completeness:** All critical and important decisions documented with versions, rationale, and affected components. Phase 2 deferred decisions (`--force` granularity, multi-org context) are explicitly documented with triggers.

**Structure Completeness:** Complete file tree defined for both repository content and generated artifacts. Every file has a purpose annotation. FR-to-file mapping is complete.

**Pattern Completeness:** Naming, structure, format, and process patterns cover all identified conflict points. Good/anti-pattern examples provided.

### Gap Analysis Results

**Critical Gaps:** 0

**Important Gaps:** 2 (resolved)

1. **FR30 (IDE restart notification):** `bmad.sh` compares checksums of deployed skills against previous install manifest. If any changed, prints `[WARN] Global skills updated. Restart Cursor and Claude Code to pick up changes.`

2. **`pre-workflow.sh` context pull:** Resolves `<workspace-root>/central-context/` from install manifest or `workspace.yaml` parent. Uses standard network retry — one retry with 3-second sleep. If git lock file error detected (`unable to lock`), retry once. If pull fails after retry, hard block.

3. **Multi-repo customize.toml path resolution:** `pre-workflow.sh` and customize.toml absolute paths must resolve correctly when BMAD skill runs from a nested repo — install writes workspace-root-relative paths into each target repo's customize.toml.

**Nice-to-Have Gaps:** 1

1. **`.editorconfig`:** Not included in project structure but would help maintain consistent formatting across contributors. Can be added in any implementation story.

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**✅ Architectural Decisions**
- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**✅ Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**✅ Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High — all 43 FRs and 20 NFRs are architecturally covered (3 Phase 2 FRs deferred with extension points in place). Zero critical gaps. Layout mode targeting and workspace-local context aligned with updated PRD.

**Key Strengths:**
- Clean separation between install-time and runtime concerns
- Layout-aware targeting prevents graphify/hook misconfiguration in multi-repo workspaces
- Three-tier file ownership model prevents accidental overwrites
- Delegation to external tools (graphify hooks, git-ai) avoids fragile reimplementation
- Manifest-based idempotency gives every install step state awareness
- Single default template + per-skill generation + per-target-repo copy minimizes maintenance burden

**Areas for Future Enhancement:**
- Phase 2: gamification event push, installation validation command, workspace YAML auto-sync
- Phase 2: `--force-skills` / `--force-config` granularity, BMAD version drift warning
- Phase 2: multi-org central context support
- Phase 2: `.editorconfig` and additional developer experience tooling

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all scripts
- Respect project structure and architectural boundaries
- Refer to this document for all architectural questions
- When in doubt about a convention, check the Pattern Examples section

**First Implementation Priority:**
Create the repository structure, `common.sh` foundation module (logging, checksum, exit codes, platform detection), and `.shellcheckrc` — these unblock all subsequent implementation stories.
