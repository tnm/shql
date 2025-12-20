#!/bin/bash
#
# framework.sh - Minimal shell unit test framework for shql
#
# Usage:
#   source test/framework.sh
#
#   test_something() {
#       assert_eq "actual" "expected" "test name"
#   }
#
#   run_tests

# Colors (if terminal supports them)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Counters
_TESTS_RUN=0
_TESTS_PASSED=0
_TESTS_FAILED=0
_CURRENT_TEST=""

# Assert two values are equal
assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-assertion}"

    _TESTS_RUN=$((_TESTS_RUN + 1))

    if [ "$actual" = "$expected" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        return 0
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "${RED}FAIL${NC}: %s\n" "$msg"
        printf "  expected: %s\n" "$expected"
        printf "  actual:   %s\n" "$actual"
        return 1
    fi
}

# Assert command succeeds (exit code 0)
assert_ok() {
    local msg="${1:-command should succeed}"
    shift

    _TESTS_RUN=$((_TESTS_RUN + 1))

    if "$@"; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        return 0
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "${RED}FAIL${NC}: %s\n" "$msg"
        printf "  command: %s\n" "$*"
        return 1
    fi
}

# Assert command fails (exit code non-zero)
assert_fail() {
    local msg="${1:-command should fail}"
    shift

    _TESTS_RUN=$((_TESTS_RUN + 1))

    if "$@"; then
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "${RED}FAIL${NC}: %s\n" "$msg"
        printf "  command should have failed: %s\n" "$*"
        return 1
    else
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        return 0
    fi
}

# Assert string contains substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-should contain}"

    _TESTS_RUN=$((_TESTS_RUN + 1))

    if printf '%s' "$haystack" | grep -qF "$needle"; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        return 0
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "${RED}FAIL${NC}: %s\n" "$msg"
        printf "  expected to contain: %s\n" "$needle"
        printf "  actual: %s\n" "$haystack"
        return 1
    fi
}

# Assert string does NOT contain substring
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-should not contain}"

    _TESTS_RUN=$((_TESTS_RUN + 1))

    if printf '%s' "$haystack" | grep -qF "$needle"; then
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "${RED}FAIL${NC}: %s\n" "$msg"
        printf "  should not contain: %s\n" "$needle"
        printf "  actual: %s\n" "$haystack"
        return 1
    else
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        return 0
    fi
}

# Assert output matches expected (multiline friendly)
assert_output() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-output mismatch}"

    _TESTS_RUN=$((_TESTS_RUN + 1))

    if [ "$actual" = "$expected" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        return 0
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        printf "${RED}FAIL${NC}: %s\n" "$msg"
        printf "  expected:\n"
        printf '%s\n' "$expected" | sed 's/^/    /'
        printf "  actual:\n"
        printf '%s\n' "$actual" | sed 's/^/    /'
        return 1
    fi
}

# Run a single test function
run_test() {
    local test_fn="$1"
    _CURRENT_TEST="$test_fn"

    # Run the test
    if "$test_fn"; then
        printf "${GREEN}.${NC}"
    else
        printf "${RED}F${NC}"
    fi
}

# Discover and run all test functions
run_tests() {
    local test_fns
    local start_time end_time duration

    printf "Running tests...\n\n"

    start_time=$(date +%s)

    # Find all functions starting with "test_"
    test_fns=$(declare -F | awk '{print $3}' | grep '^test_')

    for fn in $test_fns; do
        run_test "$fn"
    done

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    printf "\n\n"
    printf "Tests: %d | " "$_TESTS_RUN"
    printf "${GREEN}Passed: %d${NC} | " "$_TESTS_PASSED"

    if [ "$_TESTS_FAILED" -gt 0 ]; then
        printf "${RED}Failed: %d${NC}" "$_TESTS_FAILED"
    else
        printf "Failed: %d" "$_TESTS_FAILED"
    fi

    printf " | Time: %ds\n" "$duration"

    # Return non-zero if any tests failed
    [ "$_TESTS_FAILED" -eq 0 ]
}

# Skip a test
skip_test() {
    local reason="${1:-no reason given}"
    printf "${YELLOW}SKIP${NC}: %s - %s\n" "$_CURRENT_TEST" "$reason"
    return 0
}
