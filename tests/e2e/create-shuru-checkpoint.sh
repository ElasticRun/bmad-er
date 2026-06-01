#!/bin/sh
# Build the local shuru checkpoint with Linux prerequisites pre-installed.
# Run once per machine (or after changing shuru-bootstrap-prereqs.sh).
#
# Usage: tests/e2e/create-shuru-checkpoint.sh
# Requires: shuru CLI, network (--allow-net)

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKPOINT_NAME="$(tr -d '[:space:]' <"$SCRIPT_DIR/shuru-checkpoint.name")"
BOOTSTRAP="$SCRIPT_DIR/shuru-bootstrap-prereqs.sh"

if ! command -v shuru >/dev/null 2>&1; then
    printf 'ERROR: shuru not found. Install from https://shuru.run/\n' >&2
    exit 127
fi

if [ ! -f "$BOOTSTRAP" ]; then
    printf 'ERROR: missing %s\n' "$BOOTSTRAP" >&2
    exit 1
fi

printf 'Creating shuru checkpoint "%s" (apt + jq + yq + uv)...\n' "$CHECKPOINT_NAME"
printf 'This may take several minutes.\n'

shuru checkpoint delete "$CHECKPOINT_NAME" 2>/dev/null || true

shuru checkpoint create "$CHECKPOINT_NAME" \
    --allow-net \
    --cpus 4 \
    --memory 4096 \
    --disk-size 4096 \
    --mount "$SCRIPT_DIR:/e2e:ro" \
    -- sh /e2e/shuru-bootstrap-prereqs.sh

printf '\nCheckpoint "%s" saved locally.\n' "$CHECKPOINT_NAME"
printf 'Verify:  shuru run --from %s -- /usr/local/bin/uv --version\n' "$CHECKPOINT_NAME"
printf 'Run E2E: tests/e2e/run-developer-onboarding-shuru.sh\n'
