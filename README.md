# lets-b-mad

Workspace orchestration for BMAD Method, git-ai, graphify, and central context. This README is written for **human developers and AI coding agents** — follow sections in order; each step has explicit commands and pass/fail criteria.

## Preflight

Run these checks from a terminal. **Supported platform: macOS (Darwin).** Prerequisites are installed via Homebrew when missing.

| # | Check | Command | Pass when |
| --- | --- | --- | --- |
| 1 | macOS | `uname -s` | output is `Darwin` |
| 2 | Homebrew | `command -v brew` | path printed (install from [brew.sh](https://brew.sh) if missing) |
| 3 | Git | `git --version` | version string printed |
| 4 | Node / npx | `node --version && npx --version` | both print versions |
| 5 | Python 3.10+ | `python3 -c 'import sys; assert sys.version_info[:2] >= (3,10)'` | no error |
| 6 | uv | `uv --version` | version printed |
| 7 | curl | `curl --version` | version printed |
| 8 | jq ≥ 1.8.1 | `jq --version` | version printed |
| 9 | yq ≥ 4.53.2 | `yq --version` | version printed |
| 10 | GitHub SSH | `ssh -T git@github.com` | authenticated (or access to clone `git@github.com:elasticrun/central-context.git`) |
| 11 | Workspace layout | identify your **workspace root** — the folder that contains (or should contain) your git repositories | you know the absolute path |

**Version pins** (installed by `scripts/install.sh`): BMAD **6.8.0**, git-ai **1.5.2**, graphify **0.8.27**.

## Install

1. Clone this repository (or ensure `scripts/install.sh` is available).
2. Run the installer from any directory:

```sh
bash /path/to/lets-b-mad/scripts/install.sh
```

3. When prompted, enter your **workspace root** — the directory where `workspace.yaml` should live (typically your monorepo or projects folder). Press Enter to accept the default (`pwd`).

Or pass the path on the command line (skips the prompt):

```sh
bash /path/to/lets-b-mad/scripts/install.sh --workspace /path/to/your/workspace
# or
bash /path/to/lets-b-mad/scripts/install.sh /path/to/your/workspace
```

Optional:

- `--force` — redeploy global skills even when checksums match (wipes `~/.cursor/skills` and `~/.claude/skills` before copy).
- `LETS_B_MAD_WORKSPACE=/absolute/path` — skip the prompt and install against that workspace root (for agents and automation).

**Success criterion:** command exits with code **0**.

**Failure criterion:** non-zero exit code. Installation uses continue-on-failure; inspect the summary table for failed steps.

## Expected output

On success you should see:

- Log lines on stderr prefixed with `[INFO]`, `[SUCCESS]`, etc.
- A fixed-width summary table on stdout:

```text
Step Name                | Status | Details
```

- Final message: `Installation complete — all steps passed`
- Exit code **0**

On partial or full failure:

- One or more rows show `FAIL` in the Status column
- Final message: `Installation finished with failures (exit N)`
- Exit code **N** (non-zero). Use [Troubleshooting](#troubleshooting) below.

**Next step after success:** run [Verify installation](#verify-installation).

## Verify installation

Run from your **workspace root** (same directory used for install). Every check below must pass.

**Automated validation** (runs all checks below plus version pins, hook verification, and context freshness):

```sh
bash /path/to/lets-b-mad/scripts/validate-installation.sh
```

**Pass when:** exits **0** and summary shows all checks `PASS`. **Fail when:** non-zero exit; each failure prints expected state, actual state, and suggested fix.

### Global Cursor skills

```sh
test -d "$HOME/.cursor/skills" && ls "$HOME/.cursor/skills" | head -1
```

**Pass when:** directory exists and is non-empty.

### Global Claude skills

```sh
test -d "$HOME/.claude/skills" && ls "$HOME/.claude/skills" | head -1
```

**Pass when:** directory exists and is non-empty.

### Workspace manifest

```sh
test -f workspace.yaml
```

**Pass when:** file exists.

### Repo discovery

```sh
yq '.repos | length' workspace.yaml
```

**Pass when:** integer is **≥ 1** if your workspace contains git repos; **0** means no repos were found (fix workspace path or add repos).

### Workspace layout

```sh
yq '.workspace.layout' workspace.yaml
```

**Pass when:** value is **`standalone`** (single git repo at workspace root; YAML includes `repos[].path: .`) or **`multi-repo`** (nested git repos; workspace root is not a graphify/hook target).

**Standalone:** graphify hooks and init run at workspace root only.

**Multi-repo:** graphify hooks and init run in each nested repo listed in `workspace.yaml`, not at workspace root.

### Install manifest

```sh
test -f .lets-b-mad/install-manifest.json
```

**Pass when:** file exists.

### BMAD workspace

```sh
test -d _bmad
```

**Pass when:** `_bmad/` directory exists.

### git-ai

```sh
git-ai --version 2>/dev/null || command -v git-ai
```

**Pass when:** binary on PATH; version **1.5.2** when `--version` is supported.

### graphify

```sh
graphify --version 2>/dev/null || command -v graphify
```

**Pass when:** binary on PATH.

### Central context

```sh
test -d "$HOME/.lets-b-mad/central-context/.git"
```

**Pass when:** cloned git repository is present.

**Overall pass:** every check above passes for your workspace; install exit code was **0**.

## Do not

- Do not run install from a directory that is not your intended workspace root unless you set `LETS_B_MAD_WORKSPACE`.
- Do not manually edit generated `_bmad/` trees — re-run install to regenerate.
- Do not expect interactive prompts; the installer is non-interactive.
- Do not assume Linux is supported for prerequisite auto-install (macOS + Homebrew only).
- Do not commit `.lets-b-mad/` or generated `workspace.yaml` secrets — they are local workspace state.
- Do not skip SSH setup for central context; clone failures exit in the **40–49** range.

## Troubleshooting

| Exit range | Category | Action |
| --- | --- | --- |
| 10–19 | Prerequisites | Install missing tools via Homebrew; re-run install |
| 20–29 | BMAD / skills | Check `npx` and network; verify Node.js |
| 30–39 | git-ai / graphify | Check `curl` / `uv` and network |
| 40–49 | Central context | Verify SSH to GitHub; check `~/.lets-b-mad/central-context/` |
| 50–59 | graphify hooks | Ensure graphify installed and `workspace.yaml` lists repos |

Contributor and BMAD upgrade procedures: [docs/guide.md](docs/guide.md).

## Documentation quality

```sh
npx markdownlint-cli2 --no-globs README.md
```

Must exit **0** (uses `.markdownlint-cli2.yaml`).
