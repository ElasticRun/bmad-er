#!/usr/bin/env bash
#
# AI Adoption Dashboard
# Reads git commit trailers and prints adoption rates.
# Run from project root: bash .cursor/skills/bmad-ai-tracking/adoption-dashboard.sh
#
# Optional: pass a story prefix to filter (e.g. "1-" for epic 1)
#   bash adoption-dashboard.sh 1-

FILTER="${1:-}"

TOTAL=0
AI_STORY=0
AI_CODE=0
AI_TEST=0
AI_REVIEW=0
AI_DEPLOY_AUTO=0
AI_DEPLOY_TOTAL=0
FULL_PIPELINE=0

# Use commit-boundary delimiter to parse multi-line trailer output
while IFS= read -r line; do
  # Each block is one commit's trailers as key: value lines
  if [ "$line" = "---COMMIT---" ]; then
    # Process the accumulated trailer values for this commit
    if [ -n "$_code" ]; then
      # Apply story-ref filter
      if [ -n "$FILTER" ] && [[ "$_storyref" != ${FILTER}* ]]; then
        _story="" ; _code="" ; _test="" ; _review="" ; _deploy="" ; _storyref=""
        continue
      fi

      TOTAL=$((TOTAL + 1))

      [ "$_story" != "manual" ] && AI_STORY=$((AI_STORY + 1))
      [ "$_code" != "manual" ] && AI_CODE=$((AI_CODE + 1))
      [ "$_test" != "manual" ] && AI_TEST=$((AI_TEST + 1))
      [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && AI_REVIEW=$((AI_REVIEW + 1))

      if [ -n "$_deploy" ] && [ "$_deploy" != "pending" ]; then
        AI_DEPLOY_TOTAL=$((AI_DEPLOY_TOTAL + 1))
        [ "$_deploy" = "auto" ] && AI_DEPLOY_AUTO=$((AI_DEPLOY_AUTO + 1))
      fi

      if [ "$_story" != "manual" ] && [ "$_code" != "manual" ] && [ "$_test" != "manual" ] && \
         [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && [ "$_deploy" = "auto" ]; then
        FULL_PIPELINE=$((FULL_PIPELINE + 1))
      fi
    fi

    _story="" ; _code="" ; _test="" ; _review="" ; _deploy="" ; _storyref=""
    continue
  fi

  # Parse trailer key-value pairs
  key="${line%%:*}"
  val="$(echo "${line#*: }" | xargs)"

  case "$key" in
    AI-Story)   _story="$val" ;;
    AI-Code)    _code="$val" ;;
    AI-Test)    _test="$val" ;;
    AI-Review)  _review="$val" ;;
    AI-Deploy)  _deploy="$val" ;;
    Story-Ref)  _storyref="$val" ;;
  esac
done < <(git log --format='---COMMIT---%n%(trailers:key=AI-Story)%(trailers:key=AI-Code)%(trailers:key=AI-Test)%(trailers:key=AI-Review)%(trailers:key=AI-Deploy)%(trailers:key=Story-Ref)')

# Process the last commit (no trailing ---COMMIT--- after it)
if [ -n "$_code" ]; then
  if [ -z "$FILTER" ] || [[ "$_storyref" == ${FILTER}* ]]; then
    TOTAL=$((TOTAL + 1))
    [ "$_story" != "manual" ] && AI_STORY=$((AI_STORY + 1))
    [ "$_code" != "manual" ] && AI_CODE=$((AI_CODE + 1))
    [ "$_test" != "manual" ] && AI_TEST=$((AI_TEST + 1))
    [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && AI_REVIEW=$((AI_REVIEW + 1))
    if [ -n "$_deploy" ] && [ "$_deploy" != "pending" ]; then
      AI_DEPLOY_TOTAL=$((AI_DEPLOY_TOTAL + 1))
      [ "$_deploy" = "auto" ] && AI_DEPLOY_AUTO=$((AI_DEPLOY_AUTO + 1))
    fi
    if [ "$_story" != "manual" ] && [ "$_code" != "manual" ] && [ "$_test" != "manual" ] && \
       [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && [ "$_deploy" = "auto" ]; then
      FULL_PIPELINE=$((FULL_PIPELINE + 1))
    fi
  fi
fi

if [ "$TOTAL" -eq 0 ]; then
  echo "No commits with AI trailers found."
  [ -n "$FILTER" ] && echo "Filter applied: Story-Ref starting with '$FILTER'"
  exit 0
fi

pct() {
  echo $(( ($1 * 100) / $2 ))
}

echo "======================================"
echo "  AI Adoption Dashboard"
echo "======================================"
[ -n "$FILTER" ] && echo "  Filter: Story-Ref = ${FILTER}*"
echo "  Total tracked commits: $TOTAL"
echo "--------------------------------------"
printf "  AI Story Rate:    %3d%%  (target: 90%%)\n" "$(pct $AI_STORY $TOTAL)"
printf "  AI Code Rate:     %3d%%  (target: 80%%)\n" "$(pct $AI_CODE $TOTAL)"
printf "  AI Test Rate:     %3d%%  (target: 85%%)\n" "$(pct $AI_TEST $TOTAL)"
printf "  AI Review Rate:   %3d%%  (target: 95%%)\n" "$(pct $AI_REVIEW $TOTAL)"
if [ "$AI_DEPLOY_TOTAL" -gt 0 ]; then
  printf "  AI Deploy Rate:   %3d%%  (target: 80%%)\n" "$(pct $AI_DEPLOY_AUTO $AI_DEPLOY_TOTAL)"
else
  echo "  AI Deploy Rate:   N/A  (no deploy-tagged commits)"
fi
printf "  Full Pipeline:    %3d%%  (target: 70%%)\n" "$(pct $FULL_PIPELINE $TOTAL)"
echo "======================================"
