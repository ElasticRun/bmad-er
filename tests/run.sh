#!/usr/bin/env bash
# Test runner. Discovers tests/**/*.test.sh and runs each in its own bash.
# Aggregates exit codes; non-zero overall if any file fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -t 1 ]; then
  C_RED='\033[31m'; C_GREEN='\033[32m'; C_BOLD='\033[1m'; C_OFF='\033[0m'
else
  C_RED=''; C_GREEN=''; C_BOLD=''; C_OFF=''
fi

FILTER="${1:-}"
files=$(find . -name '*.test.sh' -type f | sort)

total_files=0
failed_files=0

for f in $files; do
  if [ -n "$FILTER" ] && ! printf '%s' "$f" | grep -qF "$FILTER"; then
    continue
  fi
  total_files=$((total_files + 1))
  printf "${C_BOLD}==> %s${C_OFF}\n" "$f"
  if bash "$f"; then
    :
  else
    failed_files=$((failed_files + 1))
  fi
  printf "\n"
done

printf "${C_BOLD}=== Summary ===${C_OFF}\n"
if [ "$failed_files" -eq 0 ]; then
  printf "${C_GREEN}All %d test file(s) passed${C_OFF}\n" "$total_files"
  exit 0
else
  printf "${C_RED}%d/%d test file(s) failed${C_OFF}\n" "$failed_files" "$total_files"
  exit 1
fi
