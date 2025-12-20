#!/bin/bash
#
# test_integration.sh - Integration tests that run the actual shql script
#
# These tests execute shql as a subprocess with piped SQL commands,
# verifying the real end-to-end behavior.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHQL="$SCRIPT_DIR/../shql"

source "$SCRIPT_DIR/framework.sh"

# Create a temp database directory
TEST_DB=""
setup_db() {
    TEST_DB=$(mktemp -d)
}

teardown_db() {
    if [ -n "$TEST_DB" ] && [ -d "$TEST_DB" ]; then
        rm -rf "$TEST_DB"
    fi
}

# Run shql with given SQL commands (quiet mode)
run_shql() {
    echo "$1" | "$SHQL" -q "$TEST_DB" 2>&1
}

# Run shql and get just data output (filter out prompts/noise)
run_shql_data() {
    echo "$1" | "$SHQL" -q "$TEST_DB" 2>&1 | grep -v "^Database:" | grep -v "^Exiting"
}

# Run shql WITHOUT quiet mode (to test header behavior)
run_shql_verbose() {
    echo "$1" | "$SHQL" "$TEST_DB" 2>&1 | grep -v "^Database:" | grep -v "^Exiting"
}

#-----------------------------------------------------------------------------
# Basic operations
#-----------------------------------------------------------------------------

test_create_and_print_table() {
    setup_db

    # Run without -q to see headers
    local output
    output=$(echo "
create table users (
    name 20,
    age 3
)
/g
print users
/g
/q
" | "$SHQL" "$TEST_DB" 2>&1 | grep -v "^Database:" | grep -v "^Exiting")

    assert_contains "$output" "OK" "create returns OK"
    assert_contains "$output" "name" "print shows name column"
    assert_contains "$output" "age" "print shows age column"
    assert_contains "$output" "(0 rows)" "empty table has 0 rows"

    teardown_db
}

test_insert_and_select() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30 )
/g
insert into users values ( 'Bob', 25 )
/g
select * from users
/g
/q
")

    assert_contains "$output" "Alice" "select shows Alice"
    assert_contains "$output" "Bob" "select shows Bob"
    assert_contains "$output" "30" "select shows age 30"
    assert_contains "$output" "(2 rows)" "2 rows in result"

    teardown_db
}

test_select_with_where() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25, 'Carol', 35 )
/g
select name from users where age > 28
/g
/q
")

    assert_contains "$output" "Alice" "Alice (30) matches"
    assert_contains "$output" "Carol" "Carol (35) matches"
    # Bob (25) should not appear in the where result
    # Can't easily assert "not contains" for just the select output

    teardown_db
}

test_select_order_by() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25, 'Carol', 35 )
/g
select name from users order by age num
/g
/q
")

    # Check that Bob comes before Alice (ordered by age ascending)
    local bob_line alice_line
    bob_line=$(echo "$output" | grep -n "Bob" | head -1 | cut -d: -f1)
    alice_line=$(echo "$output" | grep -n "Alice" | head -1 | cut -d: -f1)

    # Bob (25) should come before Alice (30)
    if [ -n "$bob_line" ] && [ -n "$alice_line" ]; then
        assert_ok "Bob before Alice in age order" [ "$bob_line" -lt "$alice_line" ]
    else
        assert_ok "Both names found" false
    fi

    teardown_db
}

test_update() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30 )
/g
update users set age = 31 where name = 'Alice'
/g
select * from users
/g
/q
")

    assert_contains "$output" "31" "age updated to 31"
    assert_contains "$output" "(1 rows)" "update reports 1 row"

    teardown_db
}

test_update_string_with_spaces() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30 )
/g
update users set name = 'Alice Smith' where age = 30
/g
select * from users
/g
/q
")

    assert_contains "$output" "Alice Smith" "name updated to 'Alice Smith'"
    assert_contains "$output" "(1 rows)" "update reports 1 row"
    assert_not_contains "$output" "syntax error" "no awk syntax error"

    teardown_db
}

test_update_multiple_fields() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3, status 1 )
/g
insert into users values ( 'Bob', 25, 'A' )
/g
update users set name = 'Bob Jones', status = 'B' where age = 25
/g
select * from users
/g
/q
")

    assert_contains "$output" "Bob Jones" "name updated to 'Bob Jones'"
    assert_contains "$output" "B" "status updated to B"
    assert_contains "$output" "(1 rows)" "update reports 1 row"

    teardown_db
}

test_delete() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25 )
/g
delete from users where name = 'Alice'
/g
select * from users
/g
/q
")

    assert_contains "$output" "Bob" "Bob remains"
    assert_contains "$output" "(1 rows)" "1 row remains after delete"

    teardown_db
}

test_drop_table() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20 )
/g
drop table users
/g
select * from users
/g
/q
")

    assert_contains "$output" "OK" "drop returns OK"
    assert_contains "$output" "does not exist" "select fails after drop"

    teardown_db
}

#-----------------------------------------------------------------------------
# Advanced features
#-----------------------------------------------------------------------------

test_select_distinct() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, status 1 )
/g
insert into users values ( 'Alice', 'A', 'Bob', 'A', 'Carol', 'B' )
/g
select distinct status from users
/g
/q
")

    assert_contains "$output" "A" "has status A"
    assert_contains "$output" "B" "has status B"
    assert_contains "$output" "(2 rows)" "distinct gives 2 rows"

    teardown_db
}

test_aggregate_count() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25, 'Carol', 35 )
/g
select count(age) from users
/g
/q
")

    assert_contains "$output" "3" "count returns 3"

    teardown_db
}

test_aggregate_sum() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 20 )
/g
select sum(age) from users
/g
/q
")

    assert_contains "$output" "50" "sum of 30+20 = 50"

    teardown_db
}

test_aggregate_avg() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 20 )
/g
select avg(age) from users
/g
/q
")

    assert_contains "$output" "25" "avg of 30,20 = 25"

    teardown_db
}

test_union() {
    setup_db

    local output
    output=$(run_shql_data "
create table users1 ( name 20 )
/g
create table users2 ( name 20 )
/g
insert into users1 values ( 'Alice' )
/g
insert into users2 values ( 'Bob' )
/g
select name from users1 union select name from users2
/g
/q
")

    assert_contains "$output" "Alice" "union has Alice"
    assert_contains "$output" "Bob" "union has Bob"

    teardown_db
}

test_join_two_tables() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, dept_id 3 )
/g
create table depts ( id 3, dept_name 20 )
/g
insert into users values ( 'Alice', 1, 'Bob', 2 )
/g
insert into depts values ( 1, 'Engineering', 2, 'Sales' )
/g
select name, dept_name from users, depts where dept_id = id
/g
/q
")

    assert_contains "$output" "Alice" "join shows Alice"
    assert_contains "$output" "Engineering" "join shows Engineering"
    assert_contains "$output" "Bob" "join shows Bob"
    assert_contains "$output" "Sales" "join shows Sales"

    teardown_db
}

test_subquery_in_where() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25, 'Carol', 35 )
/g
select name from users where age = select max(age) from users
/g
/q
")

    assert_contains "$output" "Carol" "subquery finds max age (Carol, 35)"
    assert_contains "$output" "(1 rows)" "subquery returns exactly 1 row"

    teardown_db
}

test_subquery_min() {
    setup_db

    # Use verbose mode to catch the NR==1 header bug
    local output
    output=$(run_shql_verbose "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25, 'Carol', 20 )
/g
select name from users where age = select min(age) from users
/g
/q
")

    assert_contains "$output" "Carol" "subquery finds min age (Carol, 20)"
    assert_not_contains "$output" "Alice" "Alice (30) should not match min"
    assert_not_contains "$output" "Bob" "Bob (25) should not match min"
    assert_contains "$output" "(1 rows)" "subquery returns exactly 1 row"

    teardown_db
}

#-----------------------------------------------------------------------------
# Views
#-----------------------------------------------------------------------------

test_create_view() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, dept_id 3 )
/g
create table depts ( id 3, dept_name 20 )
/g
insert into users values ( 'Alice', 1 )
/g
insert into depts values ( 1, 'Engineering' )
/g
create view user_depts ( users.dept_id = depts.id )
/g
select * from user_depts
/g
/q
")

    assert_contains "$output" "OK" "create view returns OK"
    assert_contains "$output" "Alice" "view shows Alice"
    assert_contains "$output" "Engineering" "view shows Engineering"

    teardown_db
}

#-----------------------------------------------------------------------------
# Edge cases and error handling
#-----------------------------------------------------------------------------

test_empty_table_select() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20 )
/g
select * from users
/g
/q
")

    assert_contains "$output" "(0 rows)" "empty table shows 0 rows"

    teardown_db
}

test_select_nonexistent_table() {
    setup_db

    local output
    output=$(run_shql_data "
select * from nonexistent
/g
/q
")

    assert_contains "$output" "does not exist" "error for missing table"

    teardown_db
}

test_insert_wrong_column_count() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3, status 1 )
/g
insert into users values ( 'Alice', 30 )
/g
/q
")

    assert_contains "$output" "Incorrect number" "error on wrong column count"

    teardown_db
}

test_help_command() {
    setup_db

    local output
    output=$(run_shql_data "
help commands
/g
/q
")

    assert_contains "$output" "/g is go" "help shows /g"
    assert_contains "$output" "/q is quit" "help shows /q"

    teardown_db
}

test_help_table() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30 )
/g
help users
/g
/q
")

    assert_contains "$output" "<users>" "help shows table name"
    assert_contains "$output" "name" "help shows columns"
    assert_contains "$output" "Rows:" "help shows row count"

    teardown_db
}

#-----------------------------------------------------------------------------
# Subquery: in / not in
#-----------------------------------------------------------------------------

test_in_subquery() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, status 1 )
/g
insert into users values ( 'Alice', 'A', 'Bob', 'B', 'Carol', 'C' )
/g
create table valid ( code 1 )
/g
insert into valid values ( 'A', 'B' )
/g
select name from users where status in select code from valid
/g
/q
")

    assert_contains "$output" "Alice" "Alice (A) is in valid codes"
    assert_contains "$output" "Bob" "Bob (B) is in valid codes"
    assert_not_contains "$output" "Carol" "Carol (C) is not in valid codes"
    assert_contains "$output" "(2 rows)" "in subquery returns 2 rows"

    teardown_db
}

test_not_in_subquery() {
    setup_db

    local output
    output=$(run_shql_data "
create table users ( name 20, status 1 )
/g
insert into users values ( 'Alice', 'A', 'Bob', 'B', 'Carol', 'C' )
/g
create table valid ( code 1 )
/g
insert into valid values ( 'A', 'B' )
/g
select name from users where status not in select code from valid
/g
/q
")

    assert_not_contains "$output" "Alice" "Alice (A) should not appear"
    assert_not_contains "$output" "Bob" "Bob (B) should not appear"
    assert_contains "$output" "Carol" "Carol (C) not in valid codes"
    assert_contains "$output" "(1 rows)" "not in subquery returns 1 row"

    teardown_db
}

#-----------------------------------------------------------------------------
# Verbose mode tests (non-quiet, to catch header bugs)
#-----------------------------------------------------------------------------

test_select_where_verbose() {
    setup_db

    # Use verbose mode to ensure WHERE filtering works with headers
    local output
    output=$(run_shql_verbose "
create table users ( name 20, age 3 )
/g
insert into users values ( 'Alice', 30, 'Bob', 25, 'Carol', 20 )
/g
select name from users where age > 25
/g
/q
")

    assert_contains "$output" "Alice" "Alice (30) matches age > 25"
    assert_not_contains "$output" "Bob" "Bob (25) should not match"
    assert_not_contains "$output" "Carol" "Carol (20) should not match"
    assert_contains "$output" "(1 rows)" "where returns 1 row"

    teardown_db
}

#-----------------------------------------------------------------------------
# The demo.shql script (full integration)
#-----------------------------------------------------------------------------

test_demo_script() {
    setup_db

    # Run the demo script (it creates and cleans up its own tables)
    local output
    output=$("$SHQL" -q "$TEST_DB" < "$SCRIPT_DIR/../demo.shql" 2>&1)

    # Demo should complete without errors and clean up
    assert_contains "$output" "OK" "demo creates tables"
    assert_contains "$output" "Fred" "demo inserts Fred"
    assert_contains "$output" "Barney" "demo inserts Barney"

    # After demo, all tables should be dropped
    local remaining
    remaining=$(ls "$TEST_DB"/*@ 2>/dev/null | wc -l | tr -d ' ')
    assert_eq "$remaining" "0" "demo cleans up all tables"

    teardown_db
}

#-----------------------------------------------------------------------------
# Run all tests
#-----------------------------------------------------------------------------

run_tests
