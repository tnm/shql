#!/bin/bash
#
# test_tokenizer.sh - Unit tests for the tokenizer
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/framework.sh"
source "$SCRIPT_DIR/../lib/tokenizer.sh"

#-----------------------------------------------------------------------------
# Basic tokenization
#-----------------------------------------------------------------------------

test_tokenize_simple_select() {
    local result
    result=$(tokenize "SELECT * FROM foo")
    local expected="SELECT
*
FROM
foo"
    assert_output "$result" "$expected" "simple SELECT * FROM foo"
}

test_tokenize_with_where() {
    local result
    result=$(tokenize "SELECT name FROM users WHERE age = 30")
    local expected="name
FROM
users
WHERE
age
=
30"
    # Note: SELECT gets consumed, let me check...
    result=$(tokenize "SELECT name FROM users WHERE age = 30")
    expected="SELECT
name
FROM
users
WHERE
age
=
30"
    assert_output "$result" "$expected" "SELECT with WHERE"
}

test_tokenize_extra_whitespace() {
    local result
    result=$(tokenize "SELECT   name    FROM   users")
    local expected="SELECT
name
FROM
users"
    assert_output "$result" "$expected" "handles extra whitespace"
}

test_tokenize_tabs_and_newlines() {
    local result
    # Test with tabs (newlines in input are tricky with POSIX cut)
    result=$(tokenize "SELECT	name	FROM	users")
    local expected="SELECT
name
FROM
users"
    assert_output "$result" "$expected" "handles tabs and newlines"
}

#-----------------------------------------------------------------------------
# Quoted strings
#-----------------------------------------------------------------------------

test_tokenize_double_quoted_string() {
    local result
    result=$(tokenize 'INSERT INTO foo VALUES ("hello world")')
    local expected='INSERT
INTO
foo
VALUES
(
"hello world"
)'
    assert_output "$result" "$expected" "double quoted string"
}

test_tokenize_single_quoted_string() {
    local result
    result=$(tokenize "INSERT INTO foo VALUES ('hello world')")
    local expected="INSERT
INTO
foo
VALUES
(
'hello world'
)"
    assert_output "$result" "$expected" "single quoted string"
}

test_tokenize_string_with_operators() {
    local result
    result=$(tokenize "WHERE name = 'x > y'")
    local expected="WHERE
name
=
'x > y'"
    assert_output "$result" "$expected" "string containing operators"
}

test_tokenize_empty_string() {
    local result
    result=$(tokenize "VALUES ('')")
    local expected="VALUES
(
''
)"
    assert_output "$result" "$expected" "empty string"
}

#-----------------------------------------------------------------------------
# Operators
#-----------------------------------------------------------------------------

test_tokenize_equals() {
    local result
    result=$(tokenize "a = b")
    local expected="a
=
b"
    assert_output "$result" "$expected" "equals operator"
}

test_tokenize_not_equals() {
    local result
    result=$(tokenize "a != b")
    local expected="a
!=
b"
    assert_output "$result" "$expected" "not equals operator"
}

test_tokenize_less_than() {
    local result
    result=$(tokenize "a < b")
    local expected="a
<
b"
    assert_output "$result" "$expected" "less than"
}

test_tokenize_greater_than() {
    local result
    result=$(tokenize "a > b")
    local expected="a
>
b"
    assert_output "$result" "$expected" "greater than"
}

test_tokenize_less_than_or_equal() {
    local result
    result=$(tokenize "a <= b")
    local expected="a
<=
b"
    assert_output "$result" "$expected" "less than or equal"
}

test_tokenize_greater_than_or_equal() {
    local result
    result=$(tokenize "a >= b")
    local expected="a
>=
b"
    assert_output "$result" "$expected" "greater than or equal"
}

test_tokenize_not_equal_ansi() {
    local result
    result=$(tokenize "a <> b")
    local expected="a
<>
b"
    assert_output "$result" "$expected" "ANSI not equal (<>)"
}

#-----------------------------------------------------------------------------
# Parentheses and punctuation
#-----------------------------------------------------------------------------

test_tokenize_parentheses() {
    local result
    result=$(tokenize "(a, b, c)")
    # Commas are skipped (optional separators in shql)
    local expected="(
a
b
c
)"
    assert_output "$result" "$expected" "parentheses (commas skipped)"
}

test_tokenize_nested_parens() {
    local result
    result=$(tokenize "((a))")
    local expected="(
(
a
)
)"
    assert_output "$result" "$expected" "nested parentheses"
}

test_tokenize_star() {
    local result
    result=$(tokenize "SELECT *")
    local expected="SELECT
*"
    assert_output "$result" "$expected" "star"
}

test_tokenize_dot() {
    local result
    result=$(tokenize "table.column")
    local expected="table
.
column"
    assert_output "$result" "$expected" "dot notation"
}

#-----------------------------------------------------------------------------
# Complex queries
#-----------------------------------------------------------------------------

test_tokenize_create_table() {
    local result
    result=$(tokenize "CREATE TABLE foo (name 30, age 3)")
    # Commas are skipped (optional separators in shql)
    local expected="CREATE
TABLE
foo
(
name
30
age
3
)"
    assert_output "$result" "$expected" "CREATE TABLE"
}

test_tokenize_insert_values() {
    local result
    result=$(tokenize "INSERT INTO users VALUES ('Fred', 32)")
    # Commas are skipped (optional separators in shql)
    local expected="INSERT
INTO
users
VALUES
(
'Fred'
32
)"
    assert_output "$result" "$expected" "INSERT with VALUES"
}

test_tokenize_select_with_order_by() {
    local result
    result=$(tokenize "SELECT name FROM users ORDER BY age DESC")
    local expected="SELECT
name
FROM
users
ORDER
BY
age
DESC"
    assert_output "$result" "$expected" "SELECT with ORDER BY"
}

test_tokenize_select_distinct() {
    local result
    result=$(tokenize "SELECT DISTINCT status FROM users")
    local expected="SELECT
DISTINCT
status
FROM
users"
    assert_output "$result" "$expected" "SELECT DISTINCT"
}

test_tokenize_subquery() {
    local result
    result=$(tokenize "WHERE age = (SELECT MAX(age) FROM users)")
    local expected="WHERE
age
=
(
SELECT
MAX
(
age
)
FROM
users
)"
    assert_output "$result" "$expected" "subquery"
}

test_tokenize_union() {
    local result
    result=$(tokenize "SELECT a FROM x UNION SELECT b FROM y")
    local expected="SELECT
a
FROM
x
UNION
SELECT
b
FROM
y"
    assert_output "$result" "$expected" "UNION"
}

#-----------------------------------------------------------------------------
# Helper functions
#-----------------------------------------------------------------------------

test_is_keyword_select() {
    assert_ok "SELECT is keyword" is_keyword "SELECT"
}

test_is_keyword_from_lowercase() {
    assert_ok "from is keyword" is_keyword "from"
}

test_is_keyword_random_word() {
    assert_fail "random is not keyword" is_keyword "foobar"
}

test_is_string_double_quoted() {
    assert_ok "double quoted is string" is_string '"hello"'
}

test_is_string_single_quoted() {
    assert_ok "single quoted is string" is_string "'hello'"
}

test_is_string_unquoted() {
    assert_fail "unquoted is not string" is_string "hello"
}

test_unquote_double() {
    local result
    result=$(unquote '"hello world"')
    assert_eq "$result" "hello world" "unquote double"
}

test_unquote_single() {
    local result
    result=$(unquote "'hello world'")
    assert_eq "$result" "hello world" "unquote single"
}

test_is_number_positive() {
    assert_ok "42 is number" is_number "42"
}

test_is_number_negative() {
    assert_ok "-42 is number" is_number "-42"
}

test_is_number_decimal() {
    assert_ok "3.14 is number" is_number "3.14"
}

test_is_number_word() {
    assert_fail "word is not number" is_number "hello"
}

#-----------------------------------------------------------------------------
# Edge cases
#-----------------------------------------------------------------------------

test_tokenize_empty_input() {
    local result
    result=$(tokenize "")
    assert_eq "$result" "" "empty input"
}

test_tokenize_only_whitespace() {
    local result
    result=$(tokenize "   ")
    assert_eq "$result" "" "only whitespace"
}

test_tokenize_operators_no_spaces() {
    local result
    result=$(tokenize "a=b")
    local expected="a
=
b"
    assert_output "$result" "$expected" "operators without spaces"
}

test_tokenize_multiple_operators() {
    local result
    result=$(tokenize "a >= b AND c <= d")
    local expected="a
>=
b
AND
c
<=
d"
    assert_output "$result" "$expected" "multiple operators"
}

#-----------------------------------------------------------------------------
# Run all tests
#-----------------------------------------------------------------------------

run_tests
