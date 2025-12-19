#!/bin/bash
#
# test_shql_functions.sh - Unit tests for shql core functions
#
# These tests verify the behavior of functions in the main shql script.
# We source shql in a controlled way to get access to its functions.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHQL_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/framework.sh"

# Create a temp directory for test databases
TEST_DB=""
setup_test_db() {
    TEST_DB=$(mktemp -d)
    cd "$TEST_DB" || exit 1
}

teardown_test_db() {
    if [ -n "$TEST_DB" ] && [ -d "$TEST_DB" ]; then
        rm -rf "$TEST_DB"
    fi
}

# Source just the functions from shql (not the main loop)
# We extract everything from line 1 to just before the main loop
source_shql_functions() {
    _IFS="$IFS"
    NL='
'
    TAB='	'
    QUIET=""
    DEBUG="N"
    NOCR1='-n'
    NOCR2=""

    clean_up() {
        rm -f /tmp/$$ /tmp/$$row /tmp/$$join*
    }

    # Extract lines from syntax() up to (but not including) the main while loop
    # The main loop starts at "while :" after the "# main" comment
    eval "$(sed -n '/^syntax()/,/^while :$/{ /^while :$/d; p; }' "$SHQL_DIR/shql")"
}

#-----------------------------------------------------------------------------
# lookup_field tests
#-----------------------------------------------------------------------------

test_lookup_field_found() {
    setup_test_db
    source_shql_functions

    # Create a mock schema file
    printf 'name\t30\nage\t3\nstatus\t1\n' > "users@"
    TABLE="users"

    lookup_field "name"
    local result=$?

    assert_eq "$result" "0" "lookup_field finds existing field"
    assert_eq "$OUTFIELDNUM" "1" "name is field 1"
    assert_eq "$OUTFIELD" "\$1" "OUTFIELD is \$1"

    teardown_test_db
}

test_lookup_field_second_field() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\nstatus\t1\n' > "users@"
    TABLE="users"

    lookup_field "age"

    assert_eq "$OUTFIELDNUM" "2" "age is field 2"
    assert_eq "$OUTFIELD" "\$2" "OUTFIELD is \$2"

    teardown_test_db
}

test_lookup_field_not_found() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\n' > "users@"
    TABLE="users"

    lookup_field "nonexistent"
    local result=$?

    assert_eq "$result" "1" "lookup_field returns 1 for missing field"
    assert_eq "$OUTFIELD" "nonexistent" "OUTFIELD is literal value when not found"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# create tests
#-----------------------------------------------------------------------------

test_create_table_simple() {
    setup_test_db
    source_shql_functions

    create "create" "table" "users" "(" "name" "30" "age" "3" ")"

    assert_ok "schema file exists" test -f "users@"
    assert_ok "data file exists" test -f "users~"

    local schema
    schema=$(cat "users@")
    assert_contains "$schema" "name" "schema has name"
    assert_contains "$schema" "age" "schema has age"

    teardown_test_db
}

test_create_table_already_exists() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\n' > "users@"
    touch "users~"

    local output
    output=$(create "create" "table" "users" "(" "name" "30" ")" 2>&1)

    assert_contains "$output" "already exists" "error on duplicate table"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# drop tests
#-----------------------------------------------------------------------------

test_drop_table() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\n' > "users@"
    touch "users~"

    drop "drop" "table" "users"

    assert_fail "schema file should not exist" test -f "users@"
    assert_fail "data file should not exist" test -f "users~"

    teardown_test_db
}

test_drop_nonexistent() {
    setup_test_db
    source_shql_functions

    local output
    output=$(drop "drop" "table" "nonexistent" 2>&1)

    assert_contains "$output" "No such table" "error on missing table"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# insert tests
#-----------------------------------------------------------------------------

test_insert_single_row() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\n' > "users@"
    touch "users~"

    # The insert function expects '(' and ')' as literal tokens
    insert "insert" "into" "users" "values" "(" "Fred" "32" ")"

    local data
    data=$(cat "users~")
    assert_contains "$data" "Fred" "data has Fred"
    assert_contains "$data" "32" "data has 32"

    teardown_test_db
}

test_insert_multiple_rows() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\n' > "users@"
    touch "users~"

    # Two rows: (Fred, 32), (Barney, 29)
    insert "insert" "into" "users" "values" "(" "Fred" "32" "Barney" "29" ")"

    local count
    count=$(wc -l < "users~" | tr -d ' ')
    assert_eq "$count" "2" "two rows inserted"

    teardown_test_db
}

test_insert_into_nonexistent() {
    setup_test_db
    source_shql_functions

    local output
    output=$(insert "insert" "into" "nonexistent" "values" "(" "x" ")" 2>&1)

    assert_contains "$output" "does not exist" "error on missing table"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# delete tests
#-----------------------------------------------------------------------------

test_delete_with_where() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\n' > "users@"
    printf 'Fred\t32\nBarney\t29\nWilma\t28\n' > "users~"

    TABLE="users"
    delete "delete" "from" "users" "where" "age" "=" "32"

    local data
    data=$(cat "users~")
    assert_fail "Fred should be gone" printf '%s' "$data" | grep -q "Fred"
    assert_contains "$data" "Barney" "Barney still there"
    assert_contains "$data" "Wilma" "Wilma still there"

    teardown_test_db
}

test_delete_all() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\n' > "users@"
    printf 'Fred\nBarney\nWilma\n' > "users~"

    delete "delete" "from" "users"

    local count
    count=$(wc -l < "users~" | tr -d ' ')
    assert_eq "$count" "0" "all rows deleted"

    teardown_test_db
}

test_delete_reports_correct_count() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\n' > "users@"
    printf 'Fred\t32\nBarney\t29\nWilma\t28\n' > "users~"

    # Delete one row (Fred, age 32)
    local output
    output=$(delete "delete" "from" "users" "where" "age" "=" "32" 2>&1)

    # Should report 1 row deleted (not empty or error)
    assert_contains "$output" "(1 rows)" "reports 1 row deleted"

    # Verify 2 rows remain
    local count
    count=$(wc -l < "users~" | tr -d ' ')
    assert_eq "$count" "2" "2 rows remain"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# update tests
#-----------------------------------------------------------------------------

test_update_with_where() {
    setup_test_db
    source_shql_functions

    printf 'name\t30\nage\t3\n' > "users@"
    printf 'Fred\t32\nBarney\t29\n' > "users~"

    TABLE="users"
    update "update" "users" "set" "age" "=" "99" "where" "name" "=" "\"Fred\""

    local data
    data=$(cat "users~")
    assert_contains "$data" "99" "Fred's age updated to 99"
    assert_contains "$data" "29" "Barney's age unchanged"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# select tests (basic)
#-----------------------------------------------------------------------------

test_select_star() {
    setup_test_db
    source_shql_functions
    SUBSELECT="Y"  # Suppress headers for easier testing

    printf 'name\t30\nage\t3\n' > "users@"
    printf 'Fred\t32\nBarney\t29\n' > "users~"

    local output
    output=$(select_ "select" "*" "from" "users")

    assert_contains "$output" "Fred" "output has Fred"
    assert_contains "$output" "Barney" "output has Barney"

    teardown_test_db
}

test_select_single_column() {
    setup_test_db
    source_shql_functions
    SUBSELECT="Y"

    printf 'name\t30\nage\t3\n' > "users@"
    printf 'Fred\t32\nBarney\t29\n' > "users~"

    local output
    output=$(select_ "select" "name" "from" "users")

    assert_contains "$output" "Fred" "output has Fred"
    assert_contains "$output" "Barney" "output has Barney"
    # Should NOT have ages (unless they happen to be in the output format)

    teardown_test_db
}

test_select_with_where() {
    setup_test_db
    source_shql_functions
    SUBSELECT="Y"

    printf 'name\t30\nage\t3\n' > "users@"
    printf 'Fred\t32\nBarney\t29\nWilma\t28\n' > "users~"

    local output
    output=$(select_ "select" "name" "from" "users" "where" "age" ">" "29")

    assert_contains "$output" "Fred" "Fred (32) matches"
    # Note: 29 is not > 29, so Barney should not match

    teardown_test_db
}

test_select_from_nonexistent() {
    setup_test_db
    source_shql_functions

    local output
    output=$(select_ "select" "*" "from" "nonexistent" 2>&1)

    assert_contains "$output" "does not exist" "error on missing table"

    teardown_test_db
}

#-----------------------------------------------------------------------------
# syntax tests
#-----------------------------------------------------------------------------

test_syntax_select() {
    source_shql_functions

    local output
    output=$(syntax "select")

    assert_contains "$output" "SELECT" "syntax shows SELECT"
    assert_contains "$output" "WHERE" "syntax shows WHERE"
}

test_syntax_create() {
    source_shql_functions

    local output
    output=$(syntax "create")

    assert_contains "$output" "CREATE TABLE" "syntax shows CREATE TABLE"
}

test_syntax_unknown() {
    source_shql_functions

    syntax "nonexistent"
    local result=$?

    assert_eq "$result" "1" "syntax returns 1 for unknown command"
}

#-----------------------------------------------------------------------------
# Run all tests
#-----------------------------------------------------------------------------

run_tests
