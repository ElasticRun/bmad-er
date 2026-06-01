# test_helpers.sh — minimal assertions for POSIX sh unit tests

assert_equals() {
    expected="$1"
    actual="$2"
    label="${3:-assert_equals}"
    if [ "$expected" != "$actual" ]; then
        printf 'FAIL %s: expected [%s] got [%s]\n' "$label" "$expected" "$actual" >&2
        return 1
    fi
    return 0
}

assert_zero() {
    rc="$1"
    label="${2:-assert_zero}"
    if [ "$rc" -ne 0 ]; then
        printf 'FAIL %s: expected exit 0 got %s\n' "$label" "$rc" >&2
        return 1
    fi
    return 0
}

assert_nonzero() {
    rc="$1"
    label="${2:-assert_nonzero}"
    if [ "$rc" -eq 0 ]; then
        printf 'FAIL %s: expected non-zero exit got 0\n' "$label" >&2
        return 1
    fi
    return 0
}

assert_contains() {
    haystack="$1"
    needle="$2"
    label="${3:-assert_contains}"
    case "$haystack" in
        *"$needle"*) return 0 ;;
    esac
    printf 'FAIL %s: [%s] does not contain [%s]\n' "$label" "$haystack" "$needle" >&2
    return 1
}
