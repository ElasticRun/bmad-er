---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation']
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/prd-validation-report.md'
---

# lets-b-mad - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for lets-b-mad, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Developer can install the complete lets-b-mad environment on a fresh macOS workspace using a single command (`bash scripts/install.sh`) with no interactive prompts
FR2: AI coding agent (Cursor/Claude Code) can execute the installation autonomously by reading the repository README
FR3: Developer can force a clean reinstallation of all components using the `--force` flag, overwriting all managed and protected files
FR4: install.sh can detect missing prerequisites (Node.js/npx, Python 3.10+, uv, git, curl) and attempt automatic installation via Homebrew
FR5: install.sh can report clear error messages with manual installation instructions and exit with a non-zero code when prerequisite installation fails
FR6: Developer can see a per-step pass/fail summary table at the end of installation showing each step's name, status, and error details (if any)
FR7: install.sh can re-run on an existing workspace without overwriting developer-customized files (idempotent re-install)
FR8: install.sh can track which files it manages vs. which are developer-customized using a manifest file (`.lets-b-mad/install-manifest.json`)
FR9: install.sh can auto-discover all initialized git repositories under the workspace root and generate a workspace YAML manifest with relative paths
FR10: Developer can manually edit the workspace YAML manifest to add, remove, or annotate repository entries
FR11: Developer can re-run repository discovery to add newly cloned repos to the YAML without overwriting existing entries (merge-not-overwrite)
FR12: BMAD workflows can read the workspace YAML to determine which repository to target for code and test generation
FR13: install.sh can install git-ai globally at a pinned version
FR14: git-ai can track AI code attribution per commit automatically after installation, with no per-workflow developer action required
FR15: Developer can view local git-ai statistics per repository using a summary command (`scripts/ai-stats-summary.sh`)
FR16: git-ai attribution data can be consumed by an external aggregation project without any additional lets-b-mad configuration
FR17: install.sh can install graphify (graphifyy) globally via uv at a pinned version
FR18: Developer can initialize graphify for a specific repository to build its initial knowledge graph
FR19: install.sh can install graphify git hooks (post-commit, post-checkout) per discovered repository so that the knowledge graph rebuilds on every commit and branch switch
FR20: install.sh can detect existing git hooks in a repository and warn the developer if hook conflicts are found during installation
FR21: install.sh can clone the central context git repository to a configured location within the workspace
FR22: BMAD workflows can pull the latest central context (git pull) before any workflow starts via `activation_steps_prepend` in customize.toml
FR23: The system can block a BMAD workflow from proceeding and display a warning when the central context pull fails (hard block, not silent degradation)
FR24: Central context author can update organizational context (standards, data dictionary, domain glossary, ADRs) by committing markdown files to the central repo, with changes propagated automatically to all developers on their next workflow invocation
FR25: install.sh can deploy all BMAD skills (BMM, CIS, WDS modules) to global locations (`~/.cursor/skills/` and `~/.claude/skills/`) simultaneously
FR26: install.sh can wipe and recreate global skills from the pinned BMAD version on every run (fresh, re-install, or `--force`)
FR27: install.sh can deploy the full `_bmad/` directory (config, module configs, scripts, manifests) to the workspace root
FR28: install.sh can copy default customize.toml override templates from `templates/customize/` to `_bmad/custom/` per repository
FR29: install.sh can preserve existing `_bmad/custom/*.toml` files on re-install and overwrite them only when `--force` is specified
FR30: install.sh can notify the developer to restart their IDE when global skill files have changed during installation
FR31: BMAD workflows can execute post-workflow actions via `on_complete` hooks defined in `_bmad/custom/*.toml` overrides
FR32: `on_complete` hooks can invoke shared scripts from `scripts/` for post-workflow processing
FR33: `activation_steps_prepend` hooks can execute pre-workflow actions (central context pull, workspace validation) before any BMAD workflow begins
FR34: install.sh can retrieve existing GitLab credentials using `git credential fill` without storing them in plaintext files
FR35: install.sh can store GitLab credentials securely using `git credential approve` through the native git credential system
FR36: The README can serve as a complete, agent-executable installation guide with preflight checks, single-command install, success verification criteria, and a do-not list
FR37: Developer can find contribution guidelines (repo structure, template modification, testing) and upgrade procedures (version bump, test-then-rollout, compatibility checklist) in `docs/guide.md`
FR38: The system can push a workflow completion event (workflow name + user auth context) to a GitLab OAuth-protected endpoint after any BMAD workflow completes
FR39: The system can continue normal operation when the event push fails (fail-open, warn-and-continue, non-blocking)
FR40: Developer can validate their installation health at any time using a dedicated command that checks skill resolution, hook status, version correctness, and context freshness

### NonFunctional Requirements

NFR1: install.sh completes full workspace setup (prerequisites + BMAD + git-ai + graphify + context clone + YAML discovery) in under 5 minutes on a typical developer machine with stable network connectivity
NFR2: Pre-workflow context pull (`activation_steps_prepend` git pull) adds no more than 10 seconds to workflow startup under normal network conditions
NFR3: Graphify post-commit hook execution completes within 30 seconds for repositories under 100,000 lines of code, without blocking the developer's next git operation
NFR4: Workspace YAML discovery scans and generates the manifest within 5 seconds for workspaces containing up to 50 repositories
NFR5: GitLab credentials are never stored in plaintext files, environment variables, or lets-b-mad configuration files — only in the native git credential store
NFR6: install.sh never logs, prints, or echoes credential values (tokens, passwords) in terminal output, log files, or error messages
NFR7: Central context repository access uses the developer's existing git SSH keys or credential manager — lets-b-mad does not introduce a separate authentication mechanism
NFR8: `.lets-b-mad/install-manifest.json` contains only file paths and checksums — no credentials, tokens, or sensitive configuration values
NFR9: All external dependencies (BMAD, git-ai, graphify, central context repo) are version-pinned with exact versions — no floating ranges, no "latest" resolution
NFR10: Failure in any single integration (git-ai install, graphify install, context clone) does not prevent installation of remaining components — install.sh continues and reports all failures in the summary table
NFR11: git-ai global hooks and graphify per-repo hooks coexist without conflict — install.sh verifies hook compatibility and warns on detected conflicts rather than silently overwriting
NFR12: Central context git pull failure at workflow start is a hard block — the workflow must not proceed with stale context under any circumstances
NFR13: install.sh is fully idempotent — running it N times on the same workspace produces the same result as running it once, with no accumulated side effects
NFR14: Graphify git hooks fail gracefully — a graphify indexing error must not prevent the underlying git commit or checkout from completing
NFR15: Git hook execution (post-commit, post-checkout) must not corrupt the git repository state under any failure condition (crash, timeout, disk full)
NFR16: install.sh exits with distinct non-zero exit codes per failure category (prerequisite failure, BMAD install failure, dependency failure, context clone failure) to enable scripted error handling
NFR17: BMAD version upgrades (e.g., 6.8.0 to 6.9.x) require changing exactly one value (the version pin in install.sh) — no other code changes needed for standard upgrades
NFR18: Adding a new customize.toml override for a BMAD skill requires adding one template file to `templates/customize/` and no changes to install.sh logic
NFR19: All version pins (BMAD, git-ai, graphify) are declared in a single configuration section of install.sh — not scattered across multiple files or scripts
NFR20: The lets-b-mad repository contains zero lines of BMAD workflow, agent, or skill code — all BMAD content is generated at install time from the pinned BMAD package

### Additional Requirements

- Starter template: Bare repository with conventions — no framework, no build system
- POSIX sh (`#!/bin/sh`) for all scripts — no bash-specific features (no arrays, no `[[ ]]`, no `(( ))`)
- shellcheck v0.11.0 for static analysis with POSIX compliance enforcement
- jq v1.8.1 for JSON manipulation (install manifest, git-ai stats) — installed via Homebrew as prerequisite
- yq v4.53.2 (mikefarah) for YAML manipulation (workspace manifest) — installed via Homebrew as prerequisite
- markdownlint-cli2 v0.22.1 for markdown quality enforcement
- Single entry point (`install.sh`) sources library modules from `scripts/lib/`
- Implementation sequence: common.sh → manifest.sh → prerequisites.sh → bmad.sh → dependencies.sh → context.sh → workspace.sh → hooks.sh → install.sh → pre-workflow.sh + post-workflow.sh
- Central context stored globally at `~/.lets-b-mad/central-context/`
- Range-based exit code schema (10-19: prerequisites, 20-29: BMAD, 30-39: dependencies, 40-49: context, 50-59: hooks)
- Script communication: return codes + stdout for data, stderr for logging
- Structured logging functions (`log_info`, `log_warn`, `log_error`, `log_success`) with summary collector
- Library modules sourced from `scripts/lib/` — must be side-effect-free at top level (only function definitions and constant declarations)
- Guard clauses with early return — never nested if/else chains
- Library functions never call `exit` — only return codes; only `install.sh` exits
- Single temp directory via `mktemp -d` at install start; cleanup via `trap cleanup EXIT` in `install.sh` only
- All variable expansions double-quoted: `"$var"`, `"${var}"`; all command substitutions double-quoted
- Smart merge detection for protected files: auto-update if file matches template checksum, warn and preserve if developer modified
- Single default template (`templates/customize/_default.toml`) → per-skill `.toml` files generated at install time
- Recursive repo discovery depth 3, exclude well-known directories (node_modules, .git, vendor, dist, build, .venv, __pycache__, etc.)
- `pre-workflow.sh` network retry: one retry with 3-second sleep; git lock file error → retry once; then hard block
- IDE restart notification: compare checksums of deployed skills against previous install manifest; if changed, warn user
- Runtime scripts (`pre-workflow.sh`, `post-workflow.sh`) are self-contained — must NOT source install-time library modules
- Runtime scripts can read the install manifest but must not write to it
- Hook management delegated to `graphify hook install` per repo with verification via `graphify hook status`
- Workspace YAML schema: `workspace.name`, `workspace.root`, `repos[].path` (relative), `repos[].name`, `repos[].graphify_initialized`
- Install manifest schema: JSON with `version`, `versions`, `files.managed`, `files.protected` (dual checksum), `workspace`
- Credential management deferred to Phase 2 (rely on git's native auth for MVP)
- PRD Validation findings: FR5 "clear" is subjective — implementation should include failed step name, error description, and manual resolution command

### UX Design Requirements

N/A — No UX Design specification exists for this project. lets-b-mad is a developer tool (CLI scripts, configuration, documentation) with no graphical user interface.

### FR Coverage Map

FR1: Epic 1 - Single-command install on fresh macOS workspace
FR2: Epic 6 - Agent-executable README for autonomous installation
FR3: Epic 1 - Force clean reinstallation with --force flag
FR4: Epic 1 - Prerequisite detection and auto-install via Homebrew
FR5: Epic 1 - Error messages with failed step, description, and manual resolution
FR6: Epic 1 - Per-step pass/fail summary table at end of installation
FR7: Epic 1 - Idempotent re-install preserving developer-customized files
FR8: Epic 1 - Install manifest tracking managed vs customized files
FR9: Epic 2 - Auto-discover git repos and generate workspace YAML
FR10: Epic 2 - Developer can manually edit workspace YAML
FR11: Epic 2 - Re-run discovery with merge-not-overwrite semantics
FR12: Epic 2 - BMAD workflows read workspace YAML for repo targeting
FR13: Epic 3 - Install git-ai globally at pinned version
FR14: Epic 3 - Automatic per-commit AI code attribution tracking
FR15: Epic 3 - Local git-ai stats summary per repo
FR16: Epic 3 - git-ai data consumable by external aggregation
FR17: Epic 4 - Install graphify globally via uv at pinned version
FR18: Epic 4 - Per-repo graphify initialization for knowledge graph
FR19: Epic 4 - Graphify git hooks per repo for auto-rebuild on commit/checkout
FR20: Epic 4 - Detect existing hooks and warn on conflicts
FR21: Epic 5 - Clone central context repo to configured location
FR22: Epic 5 - Pre-workflow context pull via activation_steps_prepend
FR23: Epic 5 - Hard block workflow on context pull failure
FR24: Epic 5 - Context updates propagate automatically on next workflow
FR25: Epic 1 - Deploy BMAD skills to ~/.cursor/skills/ and ~/.claude/skills/
FR26: Epic 1 - Wipe and recreate global skills on every install run
FR27: Epic 1 - Deploy full _bmad/ directory to workspace root
FR28: Epic 1 - Copy customize.toml templates to _bmad/custom/
FR29: Epic 1 - Preserve existing customize.toml files on re-install
FR30: Epic 1 - Notify developer to restart IDE when skills changed
FR31: Epic 5 - Execute on_complete hooks from customize.toml
FR32: Epic 5 - on_complete hooks invoke shared scripts from scripts/
FR33: Epic 5 - activation_steps_prepend executes pre-workflow actions
FR34: Epic 7 - Retrieve GitLab credentials via git credential fill
FR35: Epic 7 - Store credentials securely via git credential approve
FR36: Epic 6 - README as agent-executable install guide
FR37: Epic 6 - Contributor guidelines and upgrade procedures in docs/guide.md
FR38: Epic 7 - Push workflow completion event to GitLab OAuth endpoint
FR39: Epic 7 - Fail-open on event push failure (warn-and-continue)
FR40: Epic 7 - Validate installation health command

## Epic List

### Epic 1: Foundation & Single-Command Installation
Developer can run `bash scripts/install.sh` and get a fully working BMAD environment with global skills deployed, pass/fail feedback, idempotent re-runs, and `--force` for clean reset. Includes repository structure, foundational library modules (logging, checksums, exit codes, manifest tracking), prerequisite detection, BMAD installation, skill deployment, and customize.toml template management.
**FRs covered:** FR1, FR3, FR4, FR5, FR6, FR7, FR8, FR25, FR26, FR27, FR28, FR29, FR30

### Epic 2: Multi-Repo Workspace Discovery
Developer's workspace automatically discovers all git repositories and configures them in a YAML manifest, enabling BMAD workflows to target the correct repository. Supports manual editing and merge-not-overwrite on re-discovery.
**FRs covered:** FR9, FR10, FR11, FR12
**Depends on:** Epic 1

### Epic 3: AI Code Attribution & Metrics
Every AI-generated line of code is automatically tracked via git-ai, and developers can view local metrics per repository. Data is available for external aggregation without additional configuration.
**FRs covered:** FR13, FR14, FR15, FR16
**Depends on:** Epic 1

### Epic 4: Codebase Knowledge Graphs
graphify is installed with automatic per-repo hooks so the knowledge graph stays current on every commit and branch switch. Includes hook conflict detection and per-repo initialization.
**FRs covered:** FR17, FR18, FR19, FR20
**Depends on:** Epic 1, Epic 2

### Epic 5: Organizational Context & Workflow Hooks
Every BMAD workflow starts with guaranteed-fresh organizational context (standards, ADRs, data dictionary) via pre-workflow pull with hard-block on failure. Workflows can execute custom pre/post actions for team-specific extensibility.
**FRs covered:** FR21, FR22, FR23, FR24, FR31, FR32, FR33
**Depends on:** Epic 1

### Epic 6: Documentation & Agent-Driven Onboarding
Both human developers and AI agents can drive the full setup autonomously from documentation alone. Contributors and maintainers have upgrade procedures documented.
**FRs covered:** FR2, FR36, FR37
**Depends on:** Epics 1-5

### Epic 7: Phase 2 — Gamification, Credentials & Validation
Workflow completions push events to team dashboard for gamification (fail-open). Developers can validate installation health at any time. Credentials managed securely for external endpoints.
**FRs covered:** FR34, FR35, FR38, FR39, FR40
**Depends on:** Epic 5

## Epic 1: Foundation & Single-Command Installation

Developer can run `bash scripts/install.sh` and get a fully working BMAD environment with global skills deployed, pass/fail feedback, idempotent re-runs, and `--force` for clean reset. Includes repository structure, foundational library modules (logging, checksums, exit codes, manifest tracking), prerequisite detection, BMAD installation, skill deployment, and customize.toml template management.

### Story 1.1: Repository Structure & Foundation Module

As a workspace maintainer,
I want the lets-b-mad repository structure with foundational scripting utilities (logging, checksums, exit codes, platform detection),
So that all install modules can be built consistently on a solid foundation.

**Acceptance Criteria:**

**Given** a freshly cloned lets-b-mad repository
**When** the developer inspects the directory structure
**Then** the following directories exist: `scripts/`, `scripts/lib/`, `templates/customize/`, `docs/`
**And** `.shellcheckrc` is configured with `shell=sh`
**And** `.markdownlint-cli2.yaml` exists with project markdown rules
**And** `.gitignore` excludes `.lets-b-mad/`, OS artifacts, and temp files

**Given** `scripts/lib/common.sh` is sourced by another script
**When** logging functions are called (`log_info`, `log_warn`, `log_error`, `log_success`)
**Then** messages are written to stderr with format `[LEVEL] message`
**And** output is colorized when stderr is a terminal, plain text otherwise

**Given** `scripts/lib/common.sh` is sourced
**When** `compute_checksum` is called with a file path
**Then** it returns the SHA-256 checksum of the file on stdout
**And** works correctly on macOS (Darwin) using `shasum -a 256`

**Given** `scripts/lib/common.sh` is sourced
**When** exit code constants are referenced
**Then** range-based constants are defined: `EXIT_PREREQ_*` (10-19), `EXIT_BMAD_*` (20-29), `EXIT_DEP_*` (30-39), `EXIT_CONTEXT_*` (40-49), `EXIT_HOOK_*` (50-59)

**Given** `scripts/lib/common.sh` is sourced
**When** the summary collector functions are called (`summary_add_pass`, `summary_add_fail`)
**Then** results are accumulated and `summary_print` outputs a fixed-width table: `Step Name | Status | Details`

**Given** any script in `scripts/lib/`
**When** analyzed by `shellcheck`
**Then** zero errors or warnings are reported under POSIX sh rules

### Story 1.2: Install Manifest Tracking

As a developer,
I want the install process to track which files it manages vs. which I've customized,
So that re-installations never overwrite my custom configurations.

**Acceptance Criteria:**

**Given** `scripts/lib/manifest.sh` is sourced
**When** `manifest_init` is called with a workspace path
**Then** `.lets-b-mad/install-manifest.json` is created with schema: `version`, `versions` (object), `files.managed` (array), `files.protected` (array with dual checksum: `template_checksum` + `current_checksum`), `workspace` (object)

**Given** a file is registered as managed via `manifest_add_managed`
**When** `manifest_is_managed` is queried for that file path
**Then** it returns 0 (true) with the stored checksum on stdout

**Given** a file is registered as protected via `manifest_add_protected`
**When** the file's current checksum matches `template_checksum`
**Then** `manifest_file_modified` returns 1 (not modified — safe to update)

**Given** a protected file has been edited by the developer
**When** the file's current checksum differs from both `template_checksum` and `current_checksum`
**Then** `manifest_file_modified` returns 0 (modified — preserve and warn)

**Given** the manifest already exists from a previous install
**When** `manifest_read` is called
**Then** the existing manifest data is loaded without corruption or data loss
**And** `jq` is used for all JSON read/write operations

### Story 1.3: Prerequisite Detection & Installation

As a developer,
I want install.sh to detect missing prerequisites and attempt automatic installation,
So that I don't need to manually figure out what tools to install.

**Acceptance Criteria:**

**Given** `scripts/lib/prerequisites.sh` is sourced
**When** `prereqs_check_all` is called on a macOS system
**Then** it checks for: Node.js/npx, Python 3.10+, uv, git, curl, jq (v1.8.1), yq (v4.53.2)
**And** returns 0 if all prerequisites are present at required versions

**Given** a prerequisite is missing (e.g., `jq` not installed)
**When** `prereqs_install` is called
**Then** it attempts installation via `brew install jq`
**And** logs the installation attempt to stderr

**Given** a prerequisite installation via Homebrew fails
**When** the install function returns
**Then** an error message is printed containing: (1) which prerequisite failed, (2) the manual install command, (3) the specific exit code
**And** the function returns a non-zero code in the 10-19 range

**Given** all prerequisites are already installed at correct versions
**When** `prereqs_check_all` is called
**Then** it completes without attempting any installations (idempotent)
**And** logs each check as a pass

**Given** Python is installed but version is below 3.10
**When** `prereqs_check_all` is called
**Then** it reports the version mismatch with the installed version and required minimum

### Story 1.4: BMAD Installation & Global Skill Deployment

As a developer,
I want install.sh to deploy BMAD skills globally and configure customize.toml overrides per skill,
So that BMAD workflows are available in both Cursor and Claude Code immediately after installation.

**Acceptance Criteria:**

**Given** `scripts/lib/bmad.sh` is sourced and called with a temp directory path
**When** `bmad_install` executes
**Then** it runs `npx bmad-method@6.8.0 install --modules bmm,cis,wds --tools cursor --yes` into the temp directory
**And** returns non-zero with exit code in 20-29 range on failure

**Given** BMAD installed successfully to temp directory
**When** `bmad_deploy_skills` is called
**Then** it wipes `~/.cursor/skills/` and `~/.claude/skills/` completely
**And** copies all skills from the temp output to both global paths
**And** records deployed files in the manifest as managed

**Given** global skills were deployed
**When** the checksums of new skill files differ from the previous install manifest
**Then** a warning is printed: `[WARN] Global skills updated. Restart Cursor and Claude Code to pick up changes.`

**Given** skills are deployed and no previous manifest exists (fresh install)
**When** skill deployment completes
**Then** no IDE restart warning is printed (first install — no prior state to compare)

**Given** BMAD installed to temp directory
**When** `bmad_deploy_workspace` is called
**Then** the `_bmad/` directory is copied to the workspace root
**And** on fresh install or `--force`, it is created from scratch
**And** on re-install (exists already), it is preserved

**Given** `templates/customize/_default.toml` exists in the lets-b-mad repo
**When** `bmad_generate_toml` is called
**Then** a per-skill `.toml` file is generated in `_bmad/custom/` for each installed BMAD skill
**And** each `.toml` contains `activation_steps_prepend` and `on_complete` entries with absolute paths to `scripts/pre-workflow.sh` and `scripts/post-workflow.sh`

**Given** `_bmad/custom/bmad-dev-story.toml` was previously modified by the developer
**When** `bmad_generate_toml` runs on re-install (no `--force`)
**Then** the existing file is preserved (not overwritten)
**And** a log message notes the file was skipped as developer-customized

**Given** `--force` mode is active
**When** `bmad_generate_toml` runs
**Then** all `_bmad/custom/*.toml` files are overwritten from the template regardless of customization status

### Story 1.5: Install Orchestrator & Summary Table

As a developer,
I want to run a single command that orchestrates the entire installation with pass/fail feedback and a `--force` option for clean reset,
So that setup is simple, transparent, and recoverable.

**Acceptance Criteria:**

**Given** a developer runs `bash scripts/install.sh` on a fresh workspace
**When** the script executes
**Then** it sources `common.sh` first, then all library modules from `scripts/lib/`
**And** creates a temp directory via `mktemp -d`
**And** registers cleanup via `trap cleanup EXIT`

**Given** install.sh is running
**When** each install step completes (prerequisites, BMAD, skills, customize.toml)
**Then** the result (pass/fail + details) is recorded in the summary collector
**And** execution continues to the next step regardless of individual failures (NFR10)

**Given** all install steps have executed
**When** the script reaches completion
**Then** a summary table is printed to stdout with columns: `Step Name | Status | Details`
**And** the script exits with 0 if all steps passed, or the exit code of the highest-priority failure

**Given** a developer runs `bash scripts/install.sh --force`
**When** the `--force` flag is parsed
**Then** all managed AND protected files are treated as overwritable
**And** `_bmad/custom/*.toml` files are regenerated from templates
**And** global skills are wiped and recreated (same as normal)

**Given** install.sh is run a second time on the same workspace (no --force)
**When** all components are already installed at correct versions
**Then** the script completes idempotently — no files changed, all steps pass
**And** the manifest reflects unchanged state

**Given** the install.sh script file
**When** analyzed by `shellcheck`
**Then** zero errors or warnings are reported
**And** the script uses `#!/bin/sh` shebang (POSIX)

**Given** the version configuration block at the top of install.sh
**When** inspected
**Then** all version pins (BMAD_VERSION, GITAI_VERSION, GRAPHIFY_VERSION) are declared in a single block
**And** upgrading BMAD requires changing only the `BMAD_VERSION` value

## Epic 2: Multi-Repo Workspace Discovery

Developer's workspace automatically discovers all git repositories and configures them in a YAML manifest, enabling BMAD workflows to target the correct repository. Supports manual editing and merge-not-overwrite on re-discovery.

### Story 2.1: Workspace Repository Discovery & YAML Generation

As a developer,
I want my workspace to auto-discover all git repositories and generate a YAML manifest,
So that BMAD workflows know which repositories are available for targeting.

**Acceptance Criteria:**

**Given** `scripts/lib/workspace.sh` is sourced
**When** `workspace_discover` is called with the workspace root path
**Then** it recursively scans for directories containing a `.git/` folder up to depth 3
**And** excludes well-known directories: `node_modules`, `.git`, `vendor`, `dist`, `build`, `.venv`, `__pycache__`
**And** completes within 5 seconds for workspaces with up to 50 repositories

**Given** repositories are discovered
**When** `workspace_generate_yaml` is called
**Then** a `workspace.yaml` file is created at the workspace root
**And** the schema includes: `workspace.name`, `workspace.root`, and `repos[]` with `path` (relative), `name`, `graphify_initialized` (boolean, default false)
**And** `yq` is used for all YAML operations

**Given** `workspace.yaml` is generated
**When** a developer opens it in an editor
**Then** the file is human-readable and manually editable
**And** entries use relative paths from workspace root

**Given** `workspace.yaml` exists
**When** a BMAD workflow reads it
**Then** it can determine available repositories and their relative paths

### Story 2.2: Incremental Re-Discovery with Merge Semantics

As a developer,
I want to re-run repository discovery after cloning new repos without losing existing YAML entries or customizations,
So that my workspace stays current as I add new projects.

**Acceptance Criteria:**

**Given** `workspace.yaml` exists with 4 repository entries (some with annotations)
**When** a developer clones a new repo and runs `workspace_discover`
**Then** the new repo is added to `workspace.yaml`
**And** all existing entries are preserved unchanged (merge-not-overwrite)
**And** developer-added annotations on existing entries are not removed

**Given** a repo was previously in `workspace.yaml` but the directory no longer exists
**When** `workspace_discover` runs
**Then** the missing repo entry is preserved in the YAML (not removed)
**And** a warning is logged that the path no longer exists

**Given** `workspace.yaml` has an entry for `repos/api` with `graphify_initialized: true`
**When** re-discovery finds the same repo
**Then** the existing `graphify_initialized: true` value is preserved (not reset to false)

## Epic 3: AI Code Attribution & Metrics

Every AI-generated line of code is automatically tracked via git-ai, and developers can view local metrics per repository. Data is available for external aggregation without additional configuration.

### Story 3.1: git-ai Global Installation

As a developer,
I want git-ai installed globally at a pinned version during workspace setup,
So that every commit I make automatically tracks AI code attribution with no manual action required.

**Acceptance Criteria:**

**Given** `scripts/lib/dependencies.sh` is sourced
**When** `deps_install_gitai` is called
**Then** it installs git-ai via `curl -sSL https://usegitai.com/install.sh | bash`
**And** the installed version is recorded in the install manifest under `versions.gitai`

**Given** git-ai is installed successfully
**When** a developer makes a commit in any repository
**Then** git-ai automatically tracks AI code attribution per commit via its global hooks
**And** no per-workflow or per-repo configuration from lets-b-mad is required

**Given** git-ai is already installed at the correct version
**When** `deps_install_gitai` is called again
**Then** the installation is skipped (idempotent)
**And** a pass is logged indicating git-ai is already present

**Given** git-ai installation fails (network error, curl failure)
**When** the install function returns
**Then** it returns a non-zero code in the 30-39 range
**And** logs the failure details for the summary table
**And** does not prevent other installation steps from proceeding

**Given** git-ai is installed
**When** its attribution data is inspected
**Then** it is stored in a format consumable by external aggregation projects without additional lets-b-mad configuration

### Story 3.2: Local AI Stats Summary Script

As a developer,
I want to view a summary of git-ai statistics for my repositories,
So that I can track AI code attribution and durability metrics locally without waiting for an external dashboard.

**Acceptance Criteria:**

**Given** `scripts/ai-stats-summary.sh` exists and is executable
**When** a developer runs it from the workspace root
**Then** it reads the workspace YAML to find all repositories
**And** runs `git ai stats` (or equivalent) per repo
**And** outputs a formatted summary of AI attribution metrics

**Given** git-ai has no data for a repository (new repo, no AI commits)
**When** the summary script processes that repo
**Then** it reports "No git-ai data" for that entry without failing

**Given** the summary script is run
**When** it completes
**Then** it displays per-repo metrics including: AI-generated code percentage and commit count with attribution
**And** exits with 0 on success

**Given** the script file
**When** analyzed by `shellcheck`
**Then** zero errors or warnings are reported under POSIX sh rules

## Epic 4: Codebase Knowledge Graphs

graphify is installed with automatic per-repo hooks so the knowledge graph stays current on every commit and branch switch. Includes hook conflict detection and per-repo initialization.

### Story 4.1: graphify Global Installation & Per-Repo Initialization

As a developer,
I want graphify installed and initialized for my repositories,
So that AI agents have an always-current knowledge graph of my codebase to produce better code.

**Acceptance Criteria:**

**Given** `scripts/lib/dependencies.sh` is sourced
**When** `deps_install_graphify` is called
**Then** it installs graphify via `uv tool install graphifyy` at the pinned version
**And** the installed version is recorded in the install manifest under `versions.graphify`

**Given** graphify is already installed at the correct version
**When** `deps_install_graphify` is called again
**Then** the installation is skipped (idempotent)
**And** a pass is logged

**Given** graphify is installed
**When** `deps_graphify_init` is called with a repository path
**Then** it initializes graphify for that repository to build the initial knowledge graph
**And** updates the workspace YAML entry for that repo: `graphify_initialized: true`

**Given** graphify installation fails (uv error, network failure)
**When** the install function returns
**Then** it returns a non-zero code in the 30-39 range
**And** does not prevent other installation steps from proceeding

### Story 4.2: Per-Repo Hook Installation & Conflict Detection

As a developer,
I want graphify git hooks installed automatically in each discovered repository,
So that my knowledge graph rebuilds on every commit and branch switch without manual action.

**Acceptance Criteria:**

**Given** `scripts/lib/hooks.sh` is sourced and a list of discovered repos is available
**When** `hooks_install_all` is called
**Then** it runs `graphify hook install` for each repo in the workspace YAML
**And** verifies installation via `graphify hook status` per repo

**Given** a repository has existing non-graphify hooks (e.g., a custom post-commit hook)
**When** `hooks_install_all` processes that repository
**Then** a warning is logged identifying the conflicting hook
**And** the developer is informed which hooks conflict
**And** graphify hook installation proceeds (graphify handles hook chaining)

**Given** graphify hooks are installed in a repository
**When** the developer makes a commit
**Then** the graphify post-commit hook executes and rebuilds the knowledge graph
**And** completes within 30 seconds for repos under 100,000 LOC (NFR3)
**And** does not block the developer's next git operation

**Given** graphify hooks are installed
**When** the developer switches branches (`git checkout`)
**Then** the graphify post-checkout hook executes and updates the knowledge graph

**Given** a graphify hook encounters an indexing error during execution
**When** the hook completes
**Then** the underlying git operation (commit or checkout) succeeds regardless (NFR14)
**And** the git repository state is never corrupted (NFR15)

**Given** graphify hooks are already installed for a repository
**When** `hooks_install_all` is run again
**Then** it is idempotent — no duplicate hooks, no errors

## Epic 5: Organizational Context & Workflow Hooks

Every BMAD workflow starts with guaranteed-fresh organizational context (standards, ADRs, data dictionary) via pre-workflow pull with hard-block on failure. Workflows can execute custom pre/post actions for team-specific extensibility.

### Story 5.1: Central Context Repository Cloning

As a developer,
I want the central context repository cloned during installation,
So that organizational standards, ADRs, and data dictionary are available locally for every BMAD workflow.

**Acceptance Criteria:**

**Given** `scripts/lib/context.sh` is sourced
**When** `context_clone` is called
**Then** it clones the central context git repository to `~/.lets-b-mad/central-context/`
**And** uses the developer's existing git SSH keys or credential manager for authentication (NFR7)
**And** the repo URL is declared in the version configuration block of install.sh

**Given** `~/.lets-b-mad/central-context/` already exists from a previous install
**When** `context_clone` is called
**Then** it performs a `git pull --ff-only` instead of a fresh clone (idempotent)
**And** logs a pass if pull succeeds

**Given** the central context clone fails (network error, auth failure)
**When** the install function returns
**Then** it returns a non-zero code in the 40-49 range
**And** logs the failure for the summary table
**And** does not prevent other installation steps from proceeding (install-time is tolerant)

**Given** a central context author commits a new ADR to the central repo
**When** the next developer's install or context pull runs
**Then** the new ADR is available locally in `~/.lets-b-mad/central-context/`

### Story 5.2: Pre-Workflow Context Pull & Hard Block

As a developer,
I want every BMAD workflow to start with the latest organizational context and block if the pull fails,
So that my agent always has current org standards and never generates code against stale context.

**Acceptance Criteria:**

**Given** `scripts/pre-workflow.sh` exists as a self-contained runtime script
**When** it is invoked by BMAD via `activation_steps_prepend`
**Then** it runs `git pull --ff-only` on `~/.lets-b-mad/central-context/`
**And** adds no more than 10 seconds to workflow startup under normal network conditions (NFR2)

**Given** the context pull succeeds
**When** `pre-workflow.sh` completes
**Then** it exits with code 0
**And** the BMAD workflow proceeds normally with fresh context

**Given** the context pull fails (network error, merge conflict)
**When** `pre-workflow.sh` handles the failure
**Then** it retries once after a 3-second sleep
**And** if the retry fails, exits with non-zero code (hard block — NFR12)
**And** prints a warning explaining that the workflow cannot proceed with stale context

**Given** a git lock file error occurs (`unable to lock`)
**When** `pre-workflow.sh` detects it
**Then** it retries once after 3 seconds (concurrent pull handling)
**And** if retry fails, exits non-zero with an explanatory message

**Given** `pre-workflow.sh` is inspected
**When** checking its dependencies
**Then** it does NOT source any install-time library modules from `scripts/lib/`
**And** it does NOT write to the install manifest
**And** it is fully self-contained

### Story 5.3: Post-Workflow Hook Execution

As a developer,
I want BMAD workflows to execute custom post-workflow actions after completion,
So that the team can add automated post-processing (and future gamification) without modifying BMAD.

**Acceptance Criteria:**

**Given** `scripts/post-workflow.sh` exists as a self-contained runtime script
**When** it is invoked by BMAD via `on_complete` hook in `_bmad/custom/*.toml`
**Then** it executes successfully as a stub with extension points for future functionality
**And** exits with code 0

**Given** `post-workflow.sh` is the target of `on_complete` hooks in customize.toml
**When** any BMAD workflow completes
**Then** the post-workflow script is invoked automatically
**And** receives workflow context (workflow name) as arguments or environment variables

**Given** `post-workflow.sh` fails during execution
**When** the error is caught
**Then** it does not affect the BMAD workflow's reported success/failure
**And** logs a warning but does not block the developer

**Given** `post-workflow.sh` is inspected
**When** checking its dependencies
**Then** it does NOT source any install-time library modules
**And** it is fully self-contained
**And** contains clear extension points (commented sections) for Phase 2 gamification event push

## Epic 6: Documentation & Agent-Driven Onboarding

Both human developers and AI agents can drive the full setup autonomously from documentation alone. Contributors and maintainers have upgrade procedures documented.

### Story 6.1: Agent-Readable README

As a developer (or AI coding agent),
I want a README that serves as a complete, executable installation guide,
So that Cursor or Claude Code can drive the full setup autonomously without human guidance.

**Acceptance Criteria:**

**Given** a developer or AI agent opens the lets-b-mad repository
**When** they read `README.md`
**Then** it contains: preflight checks (required OS, prerequisites), single-command install (`bash scripts/install.sh`), success verification criteria (how to confirm install worked), and a do-not list (common pitfalls)

**Given** an AI coding agent reads `README.md`
**When** it parses the installation section
**Then** the structure enables autonomous execution: clear command, expected output, success/failure criteria, and next steps
**And** no ambiguous prose that requires human judgment to interpret

**Given** `README.md` exists
**When** validated by `markdownlint-cli2`
**Then** zero formatting violations are reported

**Given** the installation has completed
**When** the README's verification section is followed
**Then** it lists specific checks (e.g., `ls ~/.cursor/skills/`, verify `workspace.yaml` exists, confirm git-ai version) that confirm success

### Story 6.2: Contributor Guide & Upgrade Procedures

As a workspace maintainer,
I want documented procedures for contributing to lets-b-mad and upgrading BMAD versions,
So that any team member can maintain the tool and upgrades are safe and predictable.

**Acceptance Criteria:**

**Given** a developer opens `docs/guide.md`
**When** they read the Contributing section
**Then** it documents: repository structure explanation, how to add/modify customize.toml templates, how to add new lib modules, and testing procedures

**Given** a workspace maintainer reads `docs/guide.md`
**When** they follow the Upgrading BMAD section
**Then** it provides: version bump procedure (change one value in install.sh), test-then-rollout process (test on one workspace before team rollout), compatibility checklist, and rollback steps

**Given** `docs/guide.md` exists
**When** validated by `markdownlint-cli2`
**Then** zero formatting violations are reported

**Given** a maintainer follows the upgrade procedure
**When** they change the BMAD version pin and re-run install.sh
**Then** the documented process matches actual system behavior (no undocumented manual steps)

## Epic 7: Phase 2 — Gamification, Credentials & Validation

Workflow completions push events to team dashboard for gamification (fail-open). Developers can validate installation health at any time. Credentials managed securely for external endpoints.

### Story 7.1: Gamification Event Push & Credential Management

As a developer,
I want workflow completion events pushed to the team dashboard after every BMAD workflow,
So that my contributions are visible on the office TV and team engagement is gamified.

**Acceptance Criteria:**

**Given** `post-workflow.sh` is extended with gamification logic
**When** a BMAD workflow completes successfully
**Then** it pushes an event (workflow name + user auth context) to the configured GitLab OAuth-protected endpoint

**Given** the gamification endpoint requires authentication
**When** `post-workflow.sh` needs credentials
**Then** it retrieves them via `git credential fill` (never stored in plaintext — NFR5, NFR6)
**And** stores approved credentials via `git credential approve` for future use

**Given** the event push fails (network error, endpoint down, auth failure)
**When** the failure is detected
**Then** the script logs a warning but continues (fail-open, non-blocking — FR39)
**And** the developer's workflow is not affected
**And** no retry loop is attempted (fire-and-forget)

**Given** the gamification endpoint URL
**When** inspected in the configuration
**Then** it is declared in the version/config block of install.sh or a dedicated config file
**And** is never hardcoded in `post-workflow.sh` directly

**Given** credential retrieval via `git credential fill`
**When** no stored credential exists
**Then** the event push is skipped with a warning (not a blocking error)
**And** no interactive prompt is displayed

### Story 7.2: Installation Health Validation Command

As a developer,
I want to validate my installation health at any time,
So that I can diagnose issues without re-running the full installer.

**Acceptance Criteria:**

**Given** a validation script or command exists
**When** a developer invokes it
**Then** it checks: global skills are resolved correctly, graphify hooks are active per repo, dependency versions match pins, central context is current (not stale), workspace YAML exists and is valid

**Given** all checks pass
**When** the validation completes
**Then** it prints a summary showing all checks as PASS
**And** exits with code 0

**Given** one or more checks fail (e.g., graphify hooks missing from a repo)
**When** the validation completes
**Then** it prints each failure with: what failed, expected state, actual state, and suggested fix
**And** exits with non-zero code

**Given** the validation command
**When** run on a fresh install immediately after `install.sh` completes
**Then** all checks pass (validates that install.sh leaves the system in a healthy state)
