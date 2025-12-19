#!/bin/bash
#
# run_tests.sh - Run all shql tests
#
# Usage:
#   ./test/run_tests.sh           # Run all tests
#   ./test/run_tests.sh tokenizer # Run only tokenizer tests
#   ./test/run_tests.sh shql      # Run only shql function tests
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
if [ -t 1 ]; then
    BOLD='\033[1m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    BOLD=''
    GREEN=''
    RED=''
    NC=''
fi

total_passed=0
total_failed=0
total_tests=0

run_test_file() {
    local test_file="$1"
    local name
    name=$(basename "$test_file" .sh)

    printf "\n${BOLD}=== %s ===${NC}\n" "$name"

    # Run the test file and capture its output
    local output
    local exit_code
    if output=$("$test_file" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    echo "$output"

    # Parse the summary line for counts
    local tests passed failed
    if echo "$output" | grep -q "^Tests:"; then
        tests=$(echo "$output" | grep "^Tests:" | sed 's/.*Tests: \([0-9]*\).*/\1/')
        passed=$(echo "$output" | grep "^Tests:" | sed 's/.*Passed: \([0-9]*\).*/\1/')
        failed=$(echo "$output" | grep "^Tests:" | sed 's/.*Failed: \([0-9]*\).*/\1/')

        total_tests=$((total_tests + tests))
        total_passed=$((total_passed + passed))
        total_failed=$((total_failed + failed))
    fi

    return $exit_code
}

# Find and run test files
if [ $# -eq 0 ]; then
    # Run all tests
    test_files=("$SCRIPT_DIR"/test_*.sh)
else
    # Run specific tests
    test_files=()
    for pattern in "$@"; do
        for file in "$SCRIPT_DIR"/test_*"$pattern"*.sh; do
            [ -f "$file" ] && test_files+=("$file")
        done
    done
fi

if [ ${#test_files[@]} -eq 0 ]; then
    echo "No test files found"
    exit 1
fi

printf "${BOLD}Running shql test suite${NC}\n"
printf "========================\n"

all_passed=true
for test_file in "${test_files[@]}"; do
    if ! run_test_file "$test_file"; then
        all_passed=false
    fi
done

# Final summary
printf "\n${BOLD}========================${NC}\n"
printf "${BOLD}Total Summary${NC}\n"
printf "========================\n"
printf "Tests: %d | " "$total_tests"

if [ "$total_passed" -gt 0 ]; then
    printf "${GREEN}Passed: %d${NC} | " "$total_passed"
else
    printf "Passed: %d | " "$total_passed"
fi

if [ "$total_failed" -gt 0 ]; then
    printf "${RED}Failed: %d${NC}\n" "$total_failed"
else
    printf "Failed: %d\n" "$total_failed"
fi

if $all_passed; then
    printf "\n${GREEN}All tests passed!${NC}\n"
    exit 0
else
    printf "\n${RED}Some tests failed.${NC}\n"
    exit 1
fi
