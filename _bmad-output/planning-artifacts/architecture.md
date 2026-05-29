---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-05-29'
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
40 FRs across 10 categories. The system is a workspace-level orchestration layer — not an application with runtime logic. The FR surface breaks into three functional pillars:
1. **Bootstrap & Install (FR1-FR8):** Idempotent single-command setup, prerequisite detection/installation, managed-vs-protected file tracking via install manifest, `--force` for clean reset.
2. **Integration Wiring (FR9-FR33):** Workspace YAML auto-discovery, git-ai global install + per-commit tracking, graphify per-repo init + git hook setup, central context clone + pre-workflow pull via `activation_steps_prepend`, global skill deployment to both IDEs, `customize.toml` override management, `on_complete` hook execution.
3. **Enablement & Observability (FR34-FR40):** Credential management via native git credential store, agent-readable README, contributor/upgrade guide, Phase 2 gamification event push and installation validation.

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
- Estimated architectural components: 6 (install orchestrator, prerequisite manager, dependency installer, workspace discoverer, file manifest tracker, hook manager)

### Technical Constraints & Dependencies

| Constraint | Impact |
|-----------|--------|
| macOS Apple Silicon only | No cross-platform abstractions needed; bash and Homebrew assumptions are safe |
| BMAD v6.8.0 pinned, zero source modifications | All integration through `customize.toml` hooks (`on_complete`, `activation_steps_prepend`) and shared scripts — architecture must never require BMAD source changes |
| git-ai installs globally via curl | Global hooks auto-track AI attribution; no per-repo configuration needed |
| graphify installs globally via uv, hooks are per-repo | post-commit and post-checkout hooks must be installed per discovered repo; hook conflict detection required |
| Central context is a git repo of markdown | Freshness guaranteed by `git pull` before every workflow; pull failure = hard block |
| Global skills deployed to two paths simultaneously | `~/.cursor/skills/` and `~/.claude/skills/` — wiped and recreated on every install run |
| `_bmad/custom/*.toml` are developer-editable | Protected on re-install, overwritten only with `--force`; install manifest tracks managed vs. customized via checksums |

### Cross-Cutting Concerns Identified

1. **Idempotency & State Tracking:** Every install operation must check current state (via `.lets-b-mad/install-manifest.json` with checksums) before acting. Running install N times = same result as running once. This concern spans every component.

2. **File Ownership Model:** Three-tier ownership — managed (wiped/recreated freely), protected (preserved on re-install, overwritten with `--force`), and external (central context, git-ai, graphify — state lives outside lets-b-mad). Architecture must make this distinction explicit and enforceable.

3. **Failure Strategy Duality:** Install-time failures are tolerant (continue and report all in summary — NFR10). Runtime (workflow-start) failures on context freshness are strict (hard block — NFR12). Graphify hook failures are graceful (never corrupt git — NFR14-15). The architecture must implement three distinct failure strategies.

4. **Hook Coexistence:** git-ai global hooks and graphify per-repo hooks (post-commit, post-checkout) must coexist without conflict. Install must detect existing hooks and warn (FR20, NFR11).

5. **Version Pin Centralization:** All dependency versions (BMAD, git-ai, graphify) declared in a single configuration section of install.sh (NFR19). Upgrade = change one value (NFR17).

## Starter Template Evaluation

### Primary Technology Domain

CLI / DevOps tooling — POSIX shell scripts, YAML/TOML configuration, markdown documentation. No application runtime, no build system, no framework. The "starter" is the repository structure itself.

### Starter Options Considered

| Option | Description | Verdict |
|--------|-------------|---------|
| Framework starter (oclif, commander) | CLI frameworks for structured command-line tools | **Rejected** — lets-b-mad is an install orchestrator + config layer, not a user-facing CLI with subcommands. A framework adds dependency weight with no benefit. |
| Makefile task runner | Use `make` to organize install steps as targets | **Rejected** — direct script invocation is simpler, and `make` adds indirection without value for a single-entry-point tool (`install.sh`). |
| Bare repository with conventions | POSIX sh scripts, directory conventions, linting tools | **Selected** — minimal dependencies, maximum portability, aligned with project's nature as a thin orchestration layer. |

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
│   │   ├── context.sh                # Central context repo clone/pull
│   │   ├── workspace.sh              # Workspace YAML auto-discovery
│   │   ├── hooks.sh                  # Git hook installation + conflict detection
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
- POSIX sh (`#!/bin/sh`) for all scripts — maximum portability across shells
- No bash-specific features (no arrays, no `[[ ]]`, no `(( ))`)
- `shellcheck` v0.11.0 for static analysis with POSIX compliance enforcement

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
- `activation_steps_prepend` via shared `pre-workflow.sh`
- Central context at global `~/.lets-b-mad/central-context/`

**Important Decisions (Shape Architecture):**
- Range-based exit code schema
- Smart merge detection for protected files
- Stub `post-workflow.sh` wired from day one
- Per-skill customize.toml generated from single default template
- Recursive repo discovery (depth 3, well-known excludes)

**Deferred Decisions (Post-MVP):**
- Explicit credential management via `git credential fill/approve` (Phase 2 with gamification)
- Multi-org central context support
- Global state cleanup/purge command

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
| Credential management | Defer to Phase 2; rely on git's native auth (SSH keys, credential helper) for MVP | Every developer already has git auth configured; explicit management adds complexity for a problem that doesn't exist until gamification endpoint |

### BMAD Integration Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| `activation_steps_prepend` | Delegate to shared `scripts/pre-workflow.sh`; absolute path written into customize.toml at install time | Single source of truth for pre-workflow logic; avoids runtime path resolution |
| `on_complete` | Stub `scripts/post-workflow.sh` with extension points, wired in templates from day one | Templates ship complete; Phase 2 gamification is a single-file change, no template updates needed |
| customize.toml granularity | Single default template (`templates/customize/_default.toml`); install.sh generates per-skill `.toml` files from it | One template to maintain; per-skill files allow future skill-specific overrides; NFR18 satisfied |

### Hook Management Architecture

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hook installation | Delegate to `graphify hook install` per repo with post-install verification via `graphify hook status` | graphify manages its own hooks and merge driver; lets-b-mad avoids reimplementing fragile hook logic |
| Hook conflict detection | Rely on graphify's behavior + status check; warn if status reports issues | Avoids lets-b-mad understanding hook file internals; graphify is the source of truth for its own hooks |

### Workspace Discovery & Configuration

| Decision | Choice | Rationale |
|----------|--------|-----------|
| YAML manifest schema | Minimal: `workspace.name`, `workspace.root`, `repos[].path` (relative), `repos[].name`, `repos[].graphify_initialized` | Portable, extensible, human-editable |
| Auto-discovery algorithm | Recursive scan from workspace root, depth limit 3, exclude well-known directories (`node_modules`, `.git`, `vendor`, `dist`, `build`, `.venv`, `__pycache__`, etc.) | Handles nested repo structures while avoiding false positives |
| Central context location | Global: `~/.lets-b-mad/central-context/` | Shared across workspaces, fixed known path, mirrors global skills pattern, concurrent pull handled with retry |

### Decision Impact Analysis

**Implementation Sequence:**
1. `common.sh` — logging, checksum, platform detection, exit codes (foundation for everything)
2. `manifest.sh` — install manifest CRUD (needed by all subsequent install steps)
3. `prerequisites.sh` — prerequisite detection (gates all dependency installs)
4. `bmad.sh` — BMAD install + skill deployment (generates customize.toml files)
5. `dependencies.sh` — git-ai + graphify installation
6. `context.sh` — central context clone to `~/.lets-b-mad/central-context/`
7. `workspace.sh` — repo discovery + YAML generation
8. `hooks.sh` — graphify hook install per repo + verification
9. `install.sh` — orchestrator wiring all modules + summary table
10. `pre-workflow.sh` + `post-workflow.sh` — runtime scripts

**Cross-Component Dependencies:**
- All modules depend on `common.sh` (logging, exit codes)
- `bmad.sh` must run before `hooks.sh` (skills must exist before hooks reference them)
- `workspace.sh` must run before `hooks.sh` (repo list must be known before per-repo hook install)
- `context.sh` is independent — can run in any order relative to other dependency installs
- `manifest.sh` is used by `bmad.sh` and `context.sh` to track installed files

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

**POSIX Compliance:**
- `#!/bin/sh` on every script
- shellcheck with `shell=sh` in `.shellcheckrc`
- No `[[ ]]`, no arrays, no `(( ))`
- `local` allowed (de facto standard, supported by all target shells)

### Enforcement Guidelines

**All AI Agents MUST:**
- Follow naming conventions exactly — no camelCase functions, no unquoted variables
- Use guard clauses, never nested conditionals for error paths
- Never call `exit` from library modules — return codes only
- Never create temp files outside the shared temp directory
- Never add `# shellcheck disable` without justification

**Pattern Enforcement:**
- `shellcheck` validates POSIX compliance and quoting discipline on every script
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
│   ├── install.sh                        # Orchestrator — entry point for all install modes
│   ├── pre-workflow.sh                   # Runtime — central context pull before BMAD workflows
│   ├── post-workflow.sh                  # Runtime — stub with extension points for Phase 2
│   ├── ai-stats-summary.sh              # Utility — local git-ai metrics per repo
│   └── lib/
│       ├── common.sh                     # Foundation — logging, checksum, platform detection, exit codes, constants
│       ├── prerequisites.sh              # Step — detect/install Node.js, Python, uv, git, curl, jq, yq
│       ├── bmad.sh                       # Step — BMAD install via npx, global skill deployment, customize.toml generation
│       ├── dependencies.sh               # Step — git-ai install (curl), graphify install (uv)
│       ├── context.sh                    # Step — central context repo clone/pull to ~/.lets-b-mad/central-context/
│       ├── workspace.sh                  # Step — recursive repo discovery, YAML manifest generation
│       ├── hooks.sh                      # Step — graphify hook install per repo, verification, conflict detection
│       └── manifest.sh                   # Support — install manifest CRUD, checksum comparison, managed/protected logic
├── templates/
│   └── customize/
│       └── _default.toml                 # Source template — activation_steps_prepend + on_complete hooks
├── docs/
│   └── guide.md                          # Contributor guidelines + BMAD upgrade procedures
├── .shellcheckrc                         # shellcheck config: shell=sh
├── .markdownlint-cli2.yaml              # markdownlint config
├── .gitignore                            # Exclude .lets-b-mad/, temp files, OS artifacts
├── README.md                             # Agent-readable install guide: preflight, single-command, verification
└── LICENSE
```

**Generated at install time (not in repo):**

```
<workspace-root>/
├── .lets-b-mad/
│   └── install-manifest.json             # Tracks managed/protected files, versions, workspace state
├── workspace.yaml                        # Auto-discovered repo listing
└── _bmad/                                # Generated by npx bmad-method (BMAD-owned)
    ├── bmm/                              # BMAD Method module config
    ├── cis/                              # Creative Intelligence Suite config
    ├── wds/                              # Web Design Studio config
    └── custom/                           # Per-skill customize.toml files (generated from _default.toml)
        ├── bmad-dev-story.toml
        ├── bmad-create-story.toml
        ├── bmad-create-architecture.toml
        └── ...                           # One per installed BMAD skill

~/.lets-b-mad/
└── central-context/                      # Cloned org context repo (global, shared across workspaces)
    ├── standards/
    ├── data-dictionary/
    ├── domain-glossary/
    └── adrs/

~/.cursor/skills/                         # Global BMAD skills (wiped+recreated per install)
~/.claude/skills/                         # Global BMAD skills (wiped+recreated per install)
```

### Architectural Boundaries

**Boundary 1: Repository (what ships in git) vs. Generated (created at install time)**
- Repository contains only source scripts, templates, docs, and config
- Everything under `.lets-b-mad/`, `_bmad/`, `workspace.yaml`, global skill paths, and `~/.lets-b-mad/` is generated
- Agents implementing features must never assume generated files exist at development time

**Boundary 2: Install-time (scripts/lib/) vs. Runtime (pre-workflow.sh, post-workflow.sh)**
- `scripts/lib/*.sh` modules run only during `install.sh` execution
- `pre-workflow.sh` and `post-workflow.sh` run independently during BMAD workflows
- Runtime scripts must not source install-time library modules — they are self-contained
- Runtime scripts can read the install manifest but must not write to it

**Boundary 3: lets-b-mad owned vs. BMAD owned vs. External tool owned**
- lets-b-mad owns: `scripts/`, `templates/`, `docs/`, `.lets-b-mad/`, `workspace.yaml`
- BMAD owns: `_bmad/` (except `_bmad/custom/`), `~/.cursor/skills/`, `~/.claude/skills/`
- `_bmad/custom/` is a shared boundary: generated by lets-b-mad, editable by developer, consumed by BMAD
- git-ai owns: its global hooks and per-commit Git Notes
- graphify owns: its per-repo hooks, `graphify-out/` directories

### Requirements to Structure Mapping

| FR Group | Primary File(s) | Supporting Files |
|----------|-----------------|-----------------|
| **FR1-FR3** (Install modes) | `scripts/install.sh` | `scripts/lib/common.sh` (flags parsing) |
| **FR4-FR5** (Prerequisites) | `scripts/lib/prerequisites.sh` | `scripts/lib/common.sh` (exit codes) |
| **FR6** (Summary table) | `scripts/lib/common.sh` (summary collector) | `scripts/install.sh` (prints table) |
| **FR7-FR8** (Idempotency, manifest) | `scripts/lib/manifest.sh` | `.lets-b-mad/install-manifest.json` |
| **FR9-FR12** (Repo management) | `scripts/lib/workspace.sh` | `workspace.yaml` |
| **FR13-FR16** (git-ai) | `scripts/lib/dependencies.sh` | `scripts/ai-stats-summary.sh` |
| **FR17-FR20** (graphify) | `scripts/lib/dependencies.sh`, `scripts/lib/hooks.sh` | — |
| **FR21-FR24** (Central context) | `scripts/lib/context.sh`, `scripts/pre-workflow.sh` | `~/.lets-b-mad/central-context/` |
| **FR25-FR30** (Skills & config) | `scripts/lib/bmad.sh` | `templates/customize/_default.toml` |
| **FR31-FR33** (Workflow hooks) | `scripts/pre-workflow.sh`, `scripts/post-workflow.sh` | `_bmad/custom/*.toml` |
| **FR34-FR35** (Credentials) | Deferred to Phase 2 | — |
| **FR36** (README) | `README.md` | — |
| **FR37** (Guide) | `docs/guide.md` | — |
| **FR38-FR40** (Phase 2) | `scripts/post-workflow.sh` (future) | — |

### Integration Points

**Internal Communication (install-time):**

```
install.sh
  ├── sources → common.sh (logging, constants, exit codes)
  ├── sources → manifest.sh (read/write manifest)
  ├── calls → prerequisites.sh functions (detect, install prereqs)
  ├── calls → bmad.sh functions (install BMAD, deploy skills, generate toml)
  ├── calls → dependencies.sh functions (install git-ai, graphify)
  ├── calls → context.sh functions (clone/pull central context)
  ├── calls → workspace.sh functions (discover repos, generate YAML)
  └── calls → hooks.sh functions (install graphify hooks per repo)
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
  install.sh → [prereqs check] → [BMAD install] → [skill deploy] → [toml generate]
             → [git-ai install] → [graphify install] → [context clone]
             → [repo discover] → [YAML write] → [hooks install] → [manifest write]
             → [summary table]

Runtime flow (per BMAD workflow):
  BMAD skill start → activation_steps_prepend → pre-workflow.sh
                   → git pull ~/.lets-b-mad/central-context/
                   → success: workflow proceeds | failure: hard block

  BMAD skill end → on_complete → post-workflow.sh → (stub, Phase 2: event push)
```

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
- All technology choices are compatible: POSIX sh + jq + yq + shellcheck form a coherent, minimal toolchain with no conflicts
- Version pins are independent — BMAD (npm), git-ai (curl/binary), graphify (uv/Python) have no shared dependency conflicts
- The customize.toml integration pattern (absolute paths written at install time) is compatible with the global central context location decision

**Pattern Consistency:**
- Naming conventions are internally consistent: snake_case functions/variables, UPPER_SNAKE_CASE constants, kebab-case executables
- The stdout/stderr separation pattern aligns with the summary collector design — logging goes to stderr, collector captures step results independently
- Guard clause pattern + return-not-exit rule + single orchestrator exit point form a coherent error handling architecture

**Structure Alignment:**
- Project structure maps 1:1 to the library module decisions from step 4
- The install-time vs. runtime boundary cleanly separates `scripts/lib/` from `pre-workflow.sh`/`post-workflow.sh`
- The three-tier file ownership model (managed/protected/external) is reflected in the directory structure and manifest schema

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:**

| FR Range | Status | Notes |
|----------|--------|-------|
| FR1-FR8 (Install) | ✅ Fully covered | `install.sh` + `manifest.sh` + `common.sh` (flags, idempotency, manifest) |
| FR9-FR12 (Repos) | ✅ Fully covered | `workspace.sh` with depth-3 recursive scan + well-known excludes |
| FR13-FR16 (git-ai) | ✅ Fully covered | `dependencies.sh` + `ai-stats-summary.sh` |
| FR17-FR20 (graphify) | ✅ Fully covered | `dependencies.sh` + `hooks.sh` (delegated install + verification) |
| FR21-FR24 (Context) | ✅ Fully covered | `context.sh` + `pre-workflow.sh` + global `~/.lets-b-mad/central-context/` |
| FR25-FR30 (Skills) | ✅ Fully covered | `bmad.sh` (skill deploy, toml generation, IDE restart notification) |
| FR31-FR33 (Hooks) | ✅ Fully covered | `pre-workflow.sh` + `post-workflow.sh` + customize.toml templates |
| FR34-FR35 (Credentials) | ⏸ Deferred | Explicitly deferred to Phase 2 — architectural decision documented |
| FR36-FR37 (Docs) | ✅ Fully covered | `README.md` + `docs/guide.md` |
| FR38-FR40 (Phase 2) | ⏸ Deferred | Extension point exists (`post-workflow.sh` stub) |

**Non-Functional Requirements Coverage:**

| NFR | Status | Architectural Support |
|-----|--------|----------------------|
| NFR1 (Install < 5min) | ✅ | Sequential steps with no unnecessary work (idempotency skips) |
| NFR2 (Context pull < 10s) | ✅ | Single `git pull --ff-only` on local clone — bounded by network |
| NFR3 (Graphify hook < 30s) | ✅ | Delegated to graphify — performance is graphify's concern |
| NFR4 (YAML scan < 5s) | ✅ | Recursive find with depth limit 3 + excludes — fast by design |
| NFR5-8 (Security) | ✅ | No credential storage; manifest contains only paths/checksums; git native auth |
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

**Decision Completeness:** All critical and important decisions documented with versions, rationale, and affected components. Three deferred decisions are explicitly documented with Phase 2 triggers.

**Structure Completeness:** Complete file tree defined for both repository content and generated artifacts. Every file has a purpose annotation. FR-to-file mapping is complete.

**Pattern Completeness:** Naming, structure, format, and process patterns cover all identified conflict points. Good/anti-pattern examples provided.

### Gap Analysis Results

**Critical Gaps:** 0

**Important Gaps:** 2 (resolved)

1. **FR30 (IDE restart notification):** `bmad.sh` compares checksums of deployed skills against previous install manifest. If any changed, prints `[WARN] Global skills updated. Restart Cursor and Claude Code to pick up changes.`

2. **`pre-workflow.sh` concurrent pull handling:** Uses the standard network retry pattern — one retry with 3-second sleep. If git lock file error detected (`unable to lock`), retry once. If pull fails after retry, hard block.

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

**Confidence Level:** High — all 40 FRs and 20 NFRs are architecturally covered (2 MVP FRs explicitly deferred to Phase 2 with extension points in place). Zero critical gaps. Two important gaps resolved inline.

**Key Strengths:**
- Clean separation between install-time and runtime concerns
- Three-tier file ownership model prevents accidental overwrites
- Delegation to external tools (graphify hooks, git-ai) avoids fragile reimplementation
- Manifest-based idempotency gives every install step state awareness
- Single default template + per-skill generation minimizes maintenance burden

**Areas for Future Enhancement:**
- Phase 2: credential management, gamification event push, installation validation command
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
