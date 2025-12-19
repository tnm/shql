#!/bin/sh
#
# test_posix_compliance.sh - Validate scripts are 1991 Bourne shell compatible
#
# This checks for bashisms and features that didn't exist in 1991.
# Target: SVR4 Bourne shell (circa 1989-1991)
#

SCRIPT_DIR="$(dirname "$0")"
SHQL_DIR="$(dirname "$SCRIPT_DIR")"

# Colors (might not work on old terminals, but tests run on modern systems)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

check_file() {
    file="$1"
    name="$(basename "$file")"

    echo "Checking $name..."

    # === FATAL: These break on 1991 shells ===

    # [[ ]] - bash/ksh93 only (ignore comments)
    if grep -n '\[\[' "$file" 2>/dev/null | grep -v '^[0-9]*:\s*#'; then
        echo "  ${RED}ERROR${NC}: [[ ]] is bash-only. Use [ ]"
        ERRORS=$((ERRORS + 1))
    fi

    # $(...) command substitution - POSIX but not original Bourne
    # Be careful: $(( )) arithmetic is different from $( ) subshell
    # Ignore comments
    if grep -n '\$([^(]' "$file" 2>/dev/null | grep -v '^[0-9]*:\s*#'; then
        echo "  ${RED}ERROR${NC}: \$(...) not in original Bourne. Use backticks \`...\`"
        ERRORS=$((ERRORS + 1))
    fi

    # ${var:n:m} substring - bash only
    if grep -n '\${[^}]*:[0-9]' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: \${var:n:m} substring is bash-only"
        ERRORS=$((ERRORS + 1))
    fi

    # ${#var} string length - not in original Bourne (ksh/POSIX)
    if grep -n '\${#' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: \${#var} length is ksh/POSIX, not original Bourne"
        ERRORS=$((ERRORS + 1))
    fi

    # Arrays
    if grep -n '[a-zA-Z_][a-zA-Z0-9_]*\[' "$file" 2>/dev/null | grep -v '\$' | grep -v 'awk' | grep -v '#'; then
        echo "  ${RED}ERROR${NC}: Arrays are bash/ksh only"
        ERRORS=$((ERRORS + 1))
    fi

    # local keyword - bash only
    if grep -n '^\s*local ' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: 'local' keyword is bash-only"
        ERRORS=$((ERRORS + 1))
    fi

    # == in test (should be =)
    # Exclude lines where == is inside quotes (awk code, etc.)
    if grep -n '\[ .* == ' "$file" 2>/dev/null | grep -v '".*==.*"' | grep -v "'.*==.*'"; then
        echo "  ${RED}ERROR${NC}: Use '=' not '==' in [ ] tests"
        ERRORS=$((ERRORS + 1))
    fi

    # &> redirection - bash only
    if grep -n '&>' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: &> is bash-only. Use >file 2>&1"
        ERRORS=$((ERRORS + 1))
    fi

    # |& pipe - bash only
    if grep -n '|\&' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: |& is bash-only"
        ERRORS=$((ERRORS + 1))
    fi

    # function keyword (bash style)
    if grep -n '^function ' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: 'function' keyword is bash/ksh. Use name() { }"
        ERRORS=$((ERRORS + 1))
    fi

    # select statement - ksh/bash only
    if grep -n '^\s*select ' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: 'select' is ksh/bash only"
        ERRORS=$((ERRORS + 1))
    fi

    # $RANDOM - bash/ksh only
    if grep -n '\$RANDOM' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: \$RANDOM is bash/ksh only"
        ERRORS=$((ERRORS + 1))
    fi

    # $LINENO - may not exist
    if grep -n '\$LINENO' "$file" 2>/dev/null; then
        echo "  ${RED}WARNING${NC}: \$LINENO may not exist on all systems"
        WARNINGS=$((WARNINGS + 1))
    fi

    # === WARNINGS: Might work but risky ===

    # $(( )) arithmetic - ksh88 has it, but check context
    if grep -n '\$((' "$file" 2>/dev/null; then
        echo "  ${RED}WARNING${NC}: \$((...)) arithmetic is ksh88+, not original Bourne"
        echo "           Use expr or awk for maximum portability"
        WARNINGS=$((WARNINGS + 1))
    fi

    # printf - exists in SVR4 but not all old systems
    # Actually printf is fine for 1991, SVR4 had it

    # Here-string <<< - bash only
    if grep -n '<<<' "$file" 2>/dev/null; then
        echo "  ${RED}ERROR${NC}: <<< here-string is bash-only"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "========================================"
echo "1991 Bourne Shell Compatibility Check"
echo "========================================"
echo ""
echo "Target: SVR4 Bourne shell (1989-1991)"
echo "Features allowed: functions, #comments, trap, \"\$@\", getopts"
echo "Features banned: [[ ]], \$(...), arrays, local, \${#}, \${:}"
echo ""

# Check main shql script
check_file "$SHQL_DIR/shql"

# Check lib files (if they claim to be POSIX)
for f in "$SHQL_DIR"/lib/*.sh; do
    [ -f "$f" ] || continue
    # Check shebang - if it says /bin/sh, we check it
    head -1 "$f" | grep -q '/bin/sh' && check_file "$f"
done

echo ""

# Try to run under dash if available (either locally or via docker)
run_dash_test() {
    echo "Testing shql under dash (POSIX shell)..."

    if command -v dash >/dev/null 2>&1; then
        # dash is installed locally
        echo "  (using local dash)"
        TESTDB=$(mktemp -d)
        result=$(dash "$SHQL_DIR/shql" "$TESTDB" <<EOF
create table test (x 5)
/g
insert into test values (1)
/g
select * from test
/g
drop table test
/g
/q
EOF
        2>&1)
        rm -rf "$TESTDB"

        if echo "$result" | grep -q "(1 rows)"; then
            echo "  ${GREEN}PASSED${NC}: shql runs correctly under dash"
            return 0
        else
            echo "  ${RED}FAILED${NC}: shql failed under dash"
            echo "$result" | head -20
            return 1
        fi
    elif command -v docker >/dev/null 2>&1; then
        # Use docker
        echo "  (using docker debian:latest)"
        result=$(docker run --rm -v "$SHQL_DIR":/shql debian:latest dash -c '
            mkdir -p /tmp/testdb
            cd /shql
            dash ./shql /tmp/testdb <<EOF
create table test (x 5)
/g
insert into test values (1)
/g
select * from test
/g
drop table test
/g
/q
EOF
        ' 2>&1)

        if echo "$result" | grep -q "(1 rows)"; then
            echo "  ${GREEN}PASSED${NC}: shql runs correctly under dash"
            return 0
        else
            echo "  ${RED}FAILED${NC}: shql failed under dash"
            echo "$result" | head -20
            return 1
        fi
    else
        echo "  ${YELLOW}SKIPPED${NC}: neither dash nor docker available"
        return 0
    fi
}

echo "========================================"
if [ "$ERRORS" -gt 0 ]; then
    echo "${RED}FAILED${NC}: $ERRORS errors, $WARNINGS warnings"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo "${GREEN}PASSED${NC} with $WARNINGS warnings"
    run_dash_test
    exit $?
else
    echo "${GREEN}PASSED${NC}: 1991 Bourne shell compatible!"
    run_dash_test
    exit $?
fi
