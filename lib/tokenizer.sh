#!/bin/sh
#
# tokenizer.sh - SQL tokenizer for shql (1991 Bourne shell compatible)
#
# Converts SQL input into a stream of tokens, one per line.
# Handles: quoted strings, operators, identifiers, numbers, keywords
#
# This version avoids bash-isms:
#   - No ${var:n:m} substring
#   - No $(...) command substitution (uses backticks)
#   - No [[ ]] (uses [ ])
#   - No local keyword
#   - No arrays
#
# Uses a single awk process for tokenization.
#

# Token types (for reference):
#   STRING  - 'quoted' or "quoted"
#   IDENT   - identifiers, keywords, numbers
#   OP      - operators: = != <> < > <= >=
#   LPAREN  - (
#   RPAREN  - )
#   STAR    - *
#   COMMA   - ,  (skipped - optional separator in shql)
#   DOT     - .

#
# Main tokenizer function
# Outputs tokens one per line
#
# Uses a single awk invocation for performance. AWK's substr() function
# has been available since original AWK (1977) and is in POSIX.
#
tokenize() {
    printf '%s\n' "$1" | awk '
    BEGIN {
        # Build input from all lines, normalizing newlines to spaces
        input = ""
    }
    {
        if (input != "") input = input " "
        input = input $0
    }
    END {
        len = length(input)
        i = 1

        while (i <= len) {
            char = substr(input, i, 1)

            # Whitespace - skip
            if (char == " " || char == "\t") {
                i++
                continue
            }

            # Single or double quoted string
            if (char == "\"" || char == "\047") {
                quote = char
                token = char
                i++
                while (i <= len) {
                    char = substr(input, i, 1)
                    token = token char
                    i++
                    if (char == quote) break
                }
                print token
                continue
            }

            # Parentheses
            if (char == "(") {
                print "("
                i++
                continue
            }
            if (char == ")") {
                print ")"
                i++
                continue
            }

            # Comma - skip (optional separator in shql)
            if (char == ",") {
                i++
                continue
            }

            # Star (for SELECT *)
            if (char == "*") {
                print "*"
                i++
                continue
            }

            # Dot (for table.column)
            if (char == ".") {
                print "."
                i++
                continue
            }

            # Less-than and variants: < <= <>
            if (char == "<") {
                i++
                if (i <= len) {
                    next_char = substr(input, i, 1)
                    if (next_char == "=") {
                        print "<="
                        i++
                        continue
                    }
                    if (next_char == ">") {
                        print "<>"
                        i++
                        continue
                    }
                }
                print "<"
                continue
            }

            # Greater-than and variants: > >=
            if (char == ">") {
                i++
                if (i <= len) {
                    next_char = substr(input, i, 1)
                    if (next_char == "=") {
                        print ">="
                        i++
                        continue
                    }
                }
                print ">"
                continue
            }

            # Not-equal: !=
            if (char == "!") {
                i++
                if (i <= len) {
                    next_char = substr(input, i, 1)
                    if (next_char == "=") {
                        print "!="
                        i++
                        continue
                    }
                }
                print "!"
                continue
            }

            # Equals
            if (char == "=") {
                print "="
                i++
                continue
            }

            # Identifiers, keywords, numbers - everything else
            token = ""
            while (i <= len) {
                char = substr(input, i, 1)
                # Stop at whitespace or special chars
                if (char == " " || char == "\t" || \
                    char == "(" || char == ")" || char == "," || \
                    char == "<" || char == ">" || char == "=" || \
                    char == "!" || char == "*" || char == ".") {
                    break
                }
                token = token char
                i++
            }
            if (token != "") print token
        }
    }'
}

#
# Lowercase a token (for keyword normalization)
#
lowercase() {
    printf '%s' "$1" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'
}

#
# Check if token is a SQL keyword
#
is_keyword() {
    _lower=`lowercase "$1"`
    case "$_lower" in
        select|from|where|order|by|insert|into|values|update|set|\
delete|create|drop|table|view|and|or|not|in|distinct|\
asc|desc|num|union|help|print|edit)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#
# Check if token is a quoted string
#
is_string() {
    case "$1" in
        \"*\"|\'*\')
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#
# Strip quotes from a string token
#
unquote() {
    printf '%s' "$1" | awk '{ print substr($0, 2, length($0) - 2) }'
}

#
# Check if token is a number
#
is_number() {
    case "$1" in
        ''|*[!0-9.-]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}
