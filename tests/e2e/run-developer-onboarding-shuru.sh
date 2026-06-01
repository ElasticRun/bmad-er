#!/bin/sh
# Host wrapper: run developer-onboarding-vm.sh inside a shuru sandbox.
# Uses checkpoint lets-b-mad-linux-prereqs when present (see create-shuru-checkpoint.sh).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VM_SCRIPT="$SCRIPT_DIR/developer-onboarding-vm.sh"
CHECKPOINT_NAME="$(tr -d '[:space:]' <"$SCRIPT_DIR/shuru-checkpoint.name")"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$REPO_ROOT/_bmad-output/implementation-artifacts/tests/runs}"
RUN_STAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
RUN_LOG="$ARTIFACTS_DIR/developer-onboarding-shuru-$RUN_STAMP.log"
SHURU_CONFIG="$SCRIPT_DIR/shuru.json"

if ! command -v shuru >/dev/null 2>&1; then
    printf 'ERROR: shuru not found. Install from https://shuru.run/\n' >&2
    exit 127
fi

mkdir -p "$ARTIFACTS_DIR"

FROM_ARGS=""
if shuru checkpoint list 2>/dev/null | grep -q "$CHECKPOINT_NAME"; then
    FROM_ARGS="--from $CHECKPOINT_NAME"
    printf 'Using shuru checkpoint: %s\n' "$CHECKPOINT_NAME"
else
    printf 'WARN: checkpoint "%s" not found — slow path (apt on every run).\n' "$CHECKPOINT_NAME" >&2
    printf '      Run: tests/e2e/create-shuru-checkpoint.sh\n' >&2
fi

printf 'Running E2E in shuru VM (network enabled)...\n'
printf 'Log: %s\n' "$RUN_LOG"

set +e
# shellcheck disable=SC2086
shuru run --allow-net --config "$SHURU_CONFIG" --cpus 4 --memory 4096 \
    $FROM_ARGS \
    --mount "$SCRIPT_DIR:/e2e:ro" \
    -- sh /e2e/developer-onboarding-vm.sh 2>&1 | tee "$RUN_LOG"
rc=${PIPESTATUS[0]}
set -e

printf '\nshuru E2E exit code: %s\n' "$rc"
printf 'Full log: %s\n' "$RUN_LOG"
exit "$rc"
