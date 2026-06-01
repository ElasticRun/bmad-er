#!/bin/sh
# Installs Linux prerequisites for lets-b-mad E2E (run once via shuru checkpoint create).
# Matches scripts/lib/prerequisites.sh targets: git, curl, node, python3.10+, uv, jq 1.8.1, yq 4.53.2.

set -eu

export HOME="${HOME:-/root}"
export DEBIAN_FRONTEND=noninteractive

printf '[checkpoint] apt packages...\n'
apt-get update -qq
apt-get install -y -qq git curl ca-certificates python3 python3-dev python3-venv nodejs npm \
    build-essential wget

printf '[checkpoint] jq 1.8.1, yq 4.53.2, uv -> /usr/local/bin...\n'
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

# Marker for E2E runs booted from this checkpoint.
printf 'lets-b-mad-linux-prereqs\n' >/etc/lets-b-mad-e2e-prereqs-ready

command -v git >/dev/null
command -v node >/dev/null
command -v npx >/dev/null
command -v python3 >/dev/null
command -v /usr/local/bin/uv >/dev/null
/usr/local/bin/jq --version | grep -q 'jq-1.8.1'
/usr/local/bin/yq --version | grep -q '4.53.2'

printf '[checkpoint] prerequisites ready\n'
