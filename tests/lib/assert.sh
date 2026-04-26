#!/usr/bin/env bash
# Tiny assertion helpers for plain-bash test scripts.
# Source from a *.test.sh, write tests as functions, call run_test for each.

TESTS_TOTAL=0
TESTS_FAILED=0
CURRENT_FILE="${CURRENT_FILE:-tests}"

if [ -t 1 ]; then
  C_RED='\033[31m'; C_GREEN='\033[32m'; C_DIM='\033[2m'; C_OFF='\033[0m'
else
  C_RED=''; C_GREEN=''; C_DIM=''; C_OFF=''
fi

_pass() {
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  printf "  ${C_GREEN}ok${C_OFF}   %s\n" "$1"
}

_fail() {
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf "  ${C_RED}FAIL${C_OFF} %s\n" "$1"
  if [ -n "${2:-}" ]; then
    printf "       ${C_DIM}%s${C_OFF}\n" "$2"
  fi
}

assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    _pass "$desc"
  else
    _fail "$desc" "expected: $(printf %q "$expected") | actual: $(printf %q "$actual")"
  fi
}

assert_ne() {
  local desc="$1" actual="$2" unexpected="$3"
  if [ "$actual" != "$unexpected" ]; then
    _pass "$desc"
  else
    _fail "$desc" "value should not equal $(printf %q "$unexpected")"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    _pass "$desc"
  else
    _fail "$desc" "output did not contain: $needle"
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    _fail "$desc" "output unexpectedly contained: $needle"
  else
    _pass "$desc"
  fi
}

assert_file() {
  local desc="$1" path="$2"
  if [ -f "$path" ]; then _pass "$desc"; else _fail "$desc" "not a regular file: $path"; fi
}

assert_dir() {
  local desc="$1" path="$2"
  if [ -d "$path" ]; then _pass "$desc"; else _fail "$desc" "not a directory: $path"; fi
}

assert_symlink() {
  local desc="$1" path="$2"
  if [ -L "$path" ]; then _pass "$desc"; else _fail "$desc" "not a symlink: $path"; fi
}

assert_executable() {
  local desc="$1" path="$2"
  if [ -x "$path" ]; then _pass "$desc"; else _fail "$desc" "not executable: $path"; fi
}

assert_zero() {
  local desc="$1" code="$2"
  if [ "$code" = "0" ]; then _pass "$desc"; else _fail "$desc" "exit code $code"; fi
}

assert_nonzero() {
  local desc="$1" code="$2"
  if [ "$code" != "0" ]; then _pass "$desc"; else _fail "$desc" "exit code was 0, expected non-zero"; fi
}

# Run a test function in a subshell so a failed assertion (or `set -e`) inside
# the test never aborts the whole file. The function name is shown as a header.
run_test() {
  local fn="$1"
  printf -- "${C_DIM}--- %s${C_OFF}\n" "$fn"
  if ! "$fn"; then
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf "  ${C_RED}FAIL${C_OFF} %s exited non-zero\n" "$fn"
  fi
}

finish() {
  printf "\n"
  if [ "$TESTS_FAILED" -eq 0 ]; then
    printf "${C_GREEN}%d passed${C_OFF}, %d total\n" "$TESTS_TOTAL" "$TESTS_TOTAL"
    exit 0
  else
    printf "${C_RED}%d failed${C_OFF}, %d passed, %d total\n" \
      "$TESTS_FAILED" "$((TESTS_TOTAL - TESTS_FAILED))" "$TESTS_TOTAL"
    exit 1
  fi
}

mktempdir() {
  mktemp -d "${TMPDIR:-/tmp}/bmad-test.XXXXXX"
}
