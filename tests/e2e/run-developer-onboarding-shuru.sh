#!/bin/sh
# Host wrapper: run developer-onboarding-vm.sh inside an ephemeral shuru sandbox.
# Requires: shuru CLI (https://shuru.run/)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_SCRIPT="$SCRIPT_DIR/developer-onboarding-vm.sh"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)/_bmad-output/implementation-artifacts/tests/runs}"
RUN_STAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
RUN_LOG="$ARTIFACTS_DIR/developer-onboarding-shuru-$RUN_STAMP.log"

if ! command -v shuru >/dev/null 2>&1; then
    printf 'ERROR: shuru not found. Install from https://shuru.run/\n' >&2
    exit 127
fi

mkdir -p "$ARTIFACTS_DIR"

printf 'Running E2E in shuru VM (network enabled)...\n'
printf 'Log: %s\n' "$RUN_LOG"

set +e
shuru run --allow-net --cpus 4 --memory 4096 \
    --mount "$SCRIPT_DIR:/e2e:ro" \
    -- sh /e2e/developer-onboarding-vm.sh 2>&1 | tee "$RUN_LOG"
rc=${PIPESTATUS[0]}
set -e

printf '\nshuru E2E exit code: %s\n' "$rc"
printf 'Full log: %s\n' "$RUN_LOG"
exit "$rc"
