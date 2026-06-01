#!/bin/sh
# E2E: fresh Linux user onboarding for lets-b-mad (runs inside shuru VM as root, then devuser).
# Steps: create user → install prereqs (apt + pinned jq/yq) → clone repo → workspace → install → validate.

set -u

E2E_USER="${E2E_USER:-devuser}"
E2E_USER_HOME="${E2E_USER_HOME:-/home/$E2E_USER}"
E2E_REPO_URL="${E2E_REPO_URL:-https://github.com/elasticrun/dont-b-mad}"
E2E_REPO_BRANCH="${E2E_REPO_BRANCH:-lets-b-mad}"
E2E_WORKSPACE_NAME="${E2E_WORKSPACE_NAME:-my-bmad-workspace}"
E2E_LETS_B_MAD_CLONE="${E2E_LETS_B_MAD_CLONE:-$E2E_USER_HOME/tools/lets-b-mad}"
E2E_WORKSPACE_ROOT="${E2E_WORKSPACE_ROOT:-$E2E_USER_HOME/workspaces/$E2E_WORKSPACE_NAME}"

failures=0
log() { printf '[e2e] %s\n' "$*"; }
assert() {
    name="$1"
    shift
    if "$@"; then
        log "PASS: $name"
    else
        log "FAIL: $name"
        failures=$((failures + 1))
    fi
}

install_linux_prereqs() {
    log "Installing base packages (apt)..."
    export HOME="${HOME:-/root}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq git curl ca-certificates python3 python3-venv nodejs npm \
        build-essential wget >/dev/null

    log "Installing jq 1.8.1, yq 4.53.2, and uv to /usr/local/bin..."
    wget -qO /usr/local/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-arm64
    chmod +x /usr/local/bin/jq
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.53.2/yq_linux_arm64
    chmod +x /usr/local/bin/yq

    if ! command -v /usr/local/bin/uv >/dev/null 2>&1; then
        HOME=/root /usr/bin/curl -fsSL https://astral.sh/uv/install.sh | HOME=/root /bin/sh
        if [ -x /root/.local/bin/uv ]; then
            cp /root/.local/bin/uv /usr/local/bin/uv
            chmod +x /usr/local/bin/uv
        fi
    fi
}

create_dev_user() {
    if ! id "$E2E_USER" >/dev/null 2>&1; then
        log "Creating user $E2E_USER..."
        useradd -m -s /bin/sh "$E2E_USER"
    fi
    mkdir -p "$E2E_USER_HOME/tools" "$E2E_USER_HOME/workspaces" "$E2E_USER_HOME/.local/bin"
    chown -R "$E2E_USER:$E2E_USER" "$E2E_USER_HOME"
}

run_as_devuser() {
  su - "$E2E_USER" -c "export HOME='$E2E_USER_HOME' PATH='/usr/local/bin:\$HOME/.local/bin:/usr/bin:/bin'; $1"
}

step_clone_lets_b_mad() {
    run_as_devuser "
        set -u
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        if [ -d '$E2E_LETS_B_MAD_CLONE/.git' ]; then
            echo '[e2e] lets-b-mad clone exists; fetching'
            cd '$E2E_LETS_B_MAD_CLONE' && git fetch origin '$E2E_REPO_BRANCH' && git checkout '$E2E_REPO_BRANCH'
        else
            echo '[e2e] Cloning $E2E_REPO_URL (branch $E2E_REPO_BRANCH)'
            git clone --branch '$E2E_REPO_BRANCH' --depth 1 '$E2E_REPO_URL' '$E2E_LETS_B_MAD_CLONE'
        fi
        test -f '$E2E_LETS_B_MAD_CLONE/scripts/install.sh'
    "
}

step_create_workspace() {
    run_as_devuser "
        set -u
        WS='$E2E_WORKSPACE_ROOT'
        mkdir -p \"\$WS/projects/sample-app\"
        if [ ! -d \"\$WS/projects/sample-app/.git\" ]; then
            git -C \"\$WS/projects/sample-app\" init
            git -C \"\$WS/projects/sample-app\" config user.email 'dev@example.com'
            git -C \"\$WS/projects/sample-app\" config user.name 'Dev User'
            printf '# sample\n' > \"\$WS/projects/sample-app/README.md\"
            git -C \"\$WS/projects/sample-app\" add README.md
            git -C \"\$WS/projects/sample-app\" commit -m 'init'
        fi
        test -d \"\$WS/projects/sample-app/.git\"
    "
}

step_run_install() {
    run_as_devuser "
        set -u
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        cd '$E2E_WORKSPACE_ROOT'
        bash '$E2E_LETS_B_MAD_CLONE/scripts/install.sh' > /tmp/install-stdout.txt 2> /tmp/install-stderr.txt
        ec=\$?
        echo \"[e2e] install.sh exit code: \$ec\"
        tail -30 /tmp/install-stderr.txt
        tail -20 /tmp/install-stdout.txt
        exit \$ec
    "
}

step_validate_artifacts() {
    run_as_devuser "
        set -u
        export PATH=\"\$HOME/.local/bin:\$PATH\"
        WS='$E2E_WORKSPACE_ROOT'
        test -f \"\$WS/workspace.yaml\"
        test -f \"\$WS/.lets-b-mad/install-manifest.json\"
        test -d \"\$WS/_bmad\"
        test -d \"\$HOME/.cursor/skills\"
        test -d \"\$HOME/.claude/skills\"
        ls \"\$HOME/.cursor/skills\" | grep -q '^bmad-'
        ls \"\$HOME/.claude/skills\" | grep -q '^bmad-'
        cd \"\$WS\"
        bash '$E2E_LETS_B_MAD_CLONE/scripts/validate-installation.sh' > /tmp/validate-stdout.txt 2> /tmp/validate-stderr.txt
        ec=\$?
        echo \"[e2e] validate-installation.sh exit code: \$ec\"
        cat /tmp/validate-stdout.txt
        cat /tmp/validate-stderr.txt >&2
        exit \$ec
    "
}

# --- main ---
log "E2E developer onboarding (VM)"
log "User=$E2E_USER workspace=$E2E_WORKSPACE_ROOT"

if [ "$(id -u)" -eq 0 ]; then
    install_linux_prereqs
    create_dev_user
else
    log "WARN: not running as root; skipping user creation and apt bootstrap"
fi

assert "clone lets-b-mad repository" step_clone_lets_b_mad
assert "create workspace with git repo" step_create_workspace

install_rc=0
step_run_install || install_rc=$?
log "install.sh completed with exit $install_rc (0 = all steps passed per installer)"

assert "workspace.yaml and manifest exist" run_as_devuser "
    test -f '$E2E_WORKSPACE_ROOT/workspace.yaml' &&
    test -f '$E2E_WORKSPACE_ROOT/.lets-b-mad/install-manifest.json'
"

assert "global bmad skills in ~/.cursor and ~/.claude" run_as_devuser "
    test -d '$E2E_USER_HOME/.cursor/skills' &&
    test -d '$E2E_USER_HOME/.claude/skills' &&
    ls '$E2E_USER_HOME/.cursor/skills' | grep -q '^bmad-' &&
    ls '$E2E_USER_HOME/.claude/skills' | grep -q '^bmad-'
"

validate_rc=0
step_validate_artifacts || validate_rc=$?
log "validate-installation.sh exit $validate_rc"

if [ "$failures" -gt 0 ]; then
    log "E2E finished with $failures assertion failure(s)"
    exit 1
fi

if [ "$install_rc" -ne 0 ]; then
    log "E2E assertions passed but install.sh reported failures (see install summary)"
    exit 2
fi

if [ "$validate_rc" -ne 0 ]; then
    log "E2E core onboarding passed; validate-installation exit $validate_rc"
    log "Common on fresh VMs: central-context needs git@github.com SSH; graphify needs uv on PATH"
    exit 3
fi

log "E2E developer onboarding: all checks passed"
exit 0
