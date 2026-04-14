#!/usr/bin/env bash
#
# Pulse — AI Adoption Dashboard
# Reads AI-Phase / AI-Tool / Story-Ref trailers from git history
# and shows adoption rates grouped by phase.
#
# Usage:
#   bash adoption-dashboard.sh                          # current repo
#   bash adoption-dashboard.sh "1-*"                    # filter by Story-Ref
#   bash adoption-dashboard.sh --workspace [path]       # all repos in workspace
#   bash adoption-dashboard.sh --workspace [path] "1-*" # workspace + filter
#   bash adoption-dashboard.sh --repo /path/to/repo     # specific repo

set -euo pipefail

WORKSPACE_MODE=false
WORKSPACE_PATH=""
REPO_PATH=""
FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)
      WORKSPACE_MODE=true
      if [ "${2:-}" != "" ] && [[ ! "$2" =~ ^- ]]; then
        WORKSPACE_PATH="$2"; shift
      fi
      ;;
    --repo)
      REPO_PATH="${2:-.}"; shift
      ;;
    --help|-h)
      head -n 11 "$0" | tail -n +2 | sed 's/^# *//'
      exit 0
      ;;
    *)
      FILTER="$1"
      ;;
  esac
  shift
done

DELIM="---COMMIT---"

declare -A phase_total
declare -A phase_ai
total_tracked=0
repos_scanned=0

collect_from_repo() {
  local repo_dir="$1"
  local raw

  raw=$(git -C "$repo_dir" log --all --format="%H${DELIM}%(trailers:key=AI-Phase,valueonly)${DELIM}%(trailers:key=AI-Tool,valueonly)${DELIM}%(trailers:key=Story-Ref,valueonly)" 2>/dev/null || true)
  [ -z "$raw" ] && return 0

  repos_scanned=$((repos_scanned + 1))

  while IFS= read -r line; do
    [ -z "$line" ] && continue

    phase=$(echo "$line" | awk -F"$DELIM" '{print $2}' | xargs 2>/dev/null || true)
    tool=$(echo "$line" | awk -F"$DELIM" '{print $3}' | xargs 2>/dev/null || true)
    ref=$(echo "$line" | awk -F"$DELIM" '{print $4}' | xargs 2>/dev/null || true)

    [ -z "$phase" ] && continue

    if [ -n "$FILTER" ]; then
      case "$ref" in
        $FILTER) ;;
        *) continue ;;
      esac
    fi

    total_tracked=$((total_tracked + 1))
    phase_total[$phase]=$(( ${phase_total[$phase]:-0} + 1 ))

    if [ "$tool" != "manual" ] && [ -n "$tool" ]; then
      phase_ai[$phase]=$(( ${phase_ai[$phase]:-0} + 1 ))
    fi
  done <<< "$raw"
}

# Determine which repos to scan
if $WORKSPACE_MODE; then
  ws="${WORKSPACE_PATH:-.}"
  ws="$(cd "$ws" && pwd)"

  # Workspace root itself may be a repo
  if [ -d "$ws/.git" ] || [ -f "$ws/.git" ]; then
    collect_from_repo "$ws"
  fi

  # Scan one level deep for repos
  for dir in "$ws"/*/; do
    [ -d "$dir" ] || continue
    if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
      collect_from_repo "${dir%/}"
    fi
  done
elif [ -n "$REPO_PATH" ]; then
  collect_from_repo "$(cd "$REPO_PATH" && pwd)"
else
  collect_from_repo "."
fi

if [ "$total_tracked" -eq 0 ]; then
  echo "No commits with AI trailers found."
  [ -n "$FILTER" ] && echo "  (filter: Story-Ref = $FILTER)"
  $WORKSPACE_MODE && echo "  (scanned $repos_scanned repo(s) in workspace)"
  exit 0
fi

declare -a PLANNING_PHASES=("prd" "architecture" "ux-design" "epics" "sprint-plan" "story")
declare -a DEV_PHASES=("code" "test" "review" "deploy")

declare -A TARGETS=(
  ["prd"]="90" ["architecture"]="90" ["ux-design"]="90" ["epics"]="90"
  ["sprint-plan"]="90" ["story"]="90"
  ["code"]="80" ["test"]="85" ["review"]="95" ["deploy"]="80"
)

pct() {
  local ai=${1:-0}
  local tot=${2:-0}
  if [ "$tot" -eq 0 ]; then echo "—"; else echo "$(( ai * 100 / tot ))%"; fi
}

echo ""
echo "======================================"
echo "  Pulse — AI Adoption Dashboard"
echo "======================================"
[ -n "$FILTER" ] && echo "  Filter: Story-Ref = $FILTER"
$WORKSPACE_MODE && echo "  Repos scanned: $repos_scanned"
echo ""

planning_count=0
has_planning=false
for p in "${PLANNING_PHASES[@]}"; do
  if [ "${phase_total[$p]:-0}" -gt 0 ]; then
    has_planning=true
    planning_count=$((planning_count + ${phase_total[$p]}))
  fi
done

if $has_planning; then
  echo "  PLANNING ($planning_count commits)"
  echo "  --------------------------------"
  for p in "${PLANNING_PHASES[@]}"; do
    tot=${phase_total[$p]:-0}
    [ "$tot" -eq 0 ] && continue
    ai=${phase_ai[$p]:-0}
    rate=$(pct "$ai" "$tot")
    target=${TARGETS[$p]:-"—"}
    printf "  %-20s %5s  (target: %s%%)  [%d/%d]\n" "$p" "$rate" "$target" "$ai" "$tot"
  done
  echo ""
fi

dev_count=0
has_dev=false
for p in "${DEV_PHASES[@]}"; do
  if [ "${phase_total[$p]:-0}" -gt 0 ]; then
    has_dev=true
    dev_count=$((dev_count + ${phase_total[$p]}))
  fi
done

if $has_dev; then
  echo "  DEVELOPMENT ($dev_count commits)"
  echo "  --------------------------------"
  for p in "${DEV_PHASES[@]}"; do
    tot=${phase_total[$p]:-0}
    [ "$tot" -eq 0 ] && continue
    ai=${phase_ai[$p]:-0}
    rate=$(pct "$ai" "$tot")
    target=${TARGETS[$p]:-"—"}
    printf "  %-20s %5s  (target: %s%%)  [%d/%d]\n" "$p" "$rate" "$target" "$ai" "$tot"
  done
  echo ""
fi

echo "  TOTAL: $total_tracked tracked commits"
echo "======================================"
echo ""
