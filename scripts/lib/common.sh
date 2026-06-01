# common.sh — shared logging, checksums, exit codes, install summary collector
# POSIX sh only; source from install scripts and tests.

# --- Exit code constants (range-based, NFR16) ---
# shellcheck disable=SC2034  # used by scripts that source this file
EXIT_PREREQ_MISSING=10
EXIT_PREREQ_INSTALL_FAILED=11
EXIT_PREREQ_VERSION_MISMATCH=12

EXIT_BMAD_INSTALL_FAILED=20
EXIT_BMAD_DEPLOY_FAILED=21

EXIT_DEP_GITAI_FAILED=30
EXIT_DEP_GRAPHIFY_FAILED=31

EXIT_CONTEXT_CLONE_FAILED=40
EXIT_CONTEXT_PULL_FAILED=41

EXIT_HOOK_INSTALL_FAILED=50
EXIT_HOOK_CONFLICT=51

# --- Summary collector state ---
SUMMARY_ENTRIES=""

# Reset summary entries (call at install start)
summary_reset() {
    SUMMARY_ENTRIES=""
}

summary_add_pass() {
    step_name="$1"
    details="${2:-}"
    SUMMARY_ENTRIES="${SUMMARY_ENTRIES}${step_name}|PASS|${details}
"
}

summary_add_fail() {
    step_name="$1"
    details="${2:-}"
    SUMMARY_ENTRIES="${SUMMARY_ENTRIES}${step_name}|FAIL|${details}
"
}

# Print fixed-width table to stdout: Step Name | Status | Details
summary_print() {
    printf '%s\n' "Step Name                | Status | Details"
    printf '%s\n' "-------------------------|--------|----------------------------------------"
    if [ -n "$SUMMARY_ENTRIES" ]; then
        printf '%s' "$SUMMARY_ENTRIES" | while IFS= read -r line; do
            [ -z "$line" ] && continue
            step_name=$(printf '%s' "$line" | cut -d'|' -f1)
            status=$(printf '%s' "$line" | cut -d'|' -f2)
            details=$(printf '%s' "$line" | cut -d'|' -f3-)
            printf '%-24s | %-6s | %s\n' "$step_name" "$status" "$details"
        done
    fi
}

# --- Logging (stderr only) ---
_common_color_start() {
    color_code="$1"
    if [ -t 2 ]; then
        printf '\033[%sm' "$color_code" >&2
    fi
}

_common_color_reset() {
    if [ -t 2 ]; then
        printf '\033[0m' >&2
    fi
}

_log_emit() {
    level="$1"
    color="$2"
    msg="$3"
    _common_color_start "$color"
    printf '[%s] %s\n' "$level" "$msg" >&2
    _common_color_reset
}

log_info() {
    _log_emit "INFO" "0" "$1"
}

log_warn() {
    _log_emit "WARN" "33" "$1"
}

log_error() {
    _log_emit "ERROR" "31" "$1"
}

log_success() {
    _log_emit "PASS" "32" "$1"
}

# SHA-256 checksum on stdout (macOS Darwin primary)
compute_checksum() {
    file_path="$1"
    if [ ! -f "$file_path" ]; then
        log_error "compute_checksum: file not found: $file_path"
        return 1
    fi
    case "$(uname -s)" in
        Darwin*)
            shasum -a 256 "$file_path" | cut -d' ' -f1
            ;;
        Linux*)
            sha256sum "$file_path" | cut -d' ' -f1
            ;;
        *)
            shasum -a 256 "$file_path" | cut -d' ' -f1
            ;;
    esac
}
