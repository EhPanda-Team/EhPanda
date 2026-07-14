#!/bin/sh

set -eu

# Cookie names and value-bearing Swift identifiers. Keep this inventory centralized.
COOKIE_VALUE_TOKENS='ipb_member_id ipb_pass_hash igneous ipbMemberId ipbMemberID ipbPassHash memberID memberId passHash cookie cookieValue cookiesDescription getCookiesDescription'

SCRIPT_DIRECTORY=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd "$SCRIPT_DIRECTORY/.." && pwd)
SOURCE_ROOT="$PROJECT_ROOT/AppPackage/Sources"
DESCRIPTION_DECLARATION="$SOURCE_ROOT/CookieClient/CookieClient.swift"
DESCRIPTION_CONSUMER="$SOURCE_ROOT/SettingFeature/AccountSetting/AccountSettingReducer.swift"
VIOLATIONS_FILE=$(mktemp "${TMPDIR:-/tmp}/ehpanda-cookie-logging.XXXXXX")
REFERENCES_FILE=$(mktemp "${TMPDIR:-/tmp}/ehpanda-cookie-references.XXXXXX")

trap 'rm -f "$VIOLATIONS_FILE" "$REFERENCES_FILE"' EXIT HUP INT TERM

find "$SOURCE_ROOT" -type f -name '*.swift' -exec awk \
    -v cookie_tokens="$COOKIE_VALUE_TOKENS" '
    BEGIN {
        token_count = split(cookie_tokens, tokens, " ")
    }

    FNR == 1 {
        collecting = 0
        statement = ""
        statement_depth = 0
    }

    function parenthesis_delta(text,    character, cursor, delta) {
        delta = 0
        for (cursor = 1; cursor <= length(text); cursor += 1) {
            character = substr(text, cursor, 1)
            if (character == "(") {
                delta += 1
            } else if (character == ")") {
                delta -= 1
            }
        }
        return delta
    }

    function carries_cookie_value(interpolation,    cursor, pattern) {
        for (cursor = 1; cursor <= token_count; cursor += 1) {
            pattern = "(^|[^[:alnum:]_])" tokens[cursor] "([^[:alnum:]_]|$)"
            if (interpolation ~ pattern) {
                return 1
            }
        }
        return 0
    }

    function inspect_logger_statement(text, file, line,    character, content, cursor, depth, offset, relative_offset) {
        offset = 1
        while (offset <= length(text)) {
            relative_offset = index(substr(text, offset), "\\(")
            if (relative_offset == 0) {
                return
            }

            cursor = offset + relative_offset + 1
            depth = 1
            content = ""
            while (cursor <= length(text) && depth > 0) {
                character = substr(text, cursor, 1)
                if (character == "(") {
                    depth += 1
                } else if (character == ")") {
                    depth -= 1
                }
                if (depth > 0) {
                    content = content character
                }
                cursor += 1
            }

            if (carries_cookie_value(content) &&
                content !~ /privacy[[:space:]]*:[[:space:]]*[.]private/) {
                print file ":" line ": cookie-bearing logger interpolation is not private"
                return
            }
            offset = cursor
        }
    }

    {
        if (!collecting &&
            $0 ~ /logger[.](debug|info|notice|warning|error|fault|trace)[[:space:]]*[(]/) {
            collecting = 1
            statement = ""
            statement_depth = 0
            statement_line = FNR
        }

        if (collecting) {
            statement = statement $0 "\n"
            statement_depth += parenthesis_delta($0)
            if (statement_depth <= 0) {
                inspect_logger_statement(statement, FILENAME, statement_line)
                collecting = 0
                statement = ""
            }
        }
    }
' {} + > "$VIOLATIONS_FILE"

grep -R -n --include='*.swift' 'getCookiesDescription' "$SOURCE_ROOT" > "$REFERENCES_FILE" || true

consumer_count=0
while IFS= read -r reference; do
    case "$reference" in
        "$DESCRIPTION_DECLARATION":*'func getCookiesDescription'*)
            ;;
        "$DESCRIPTION_CONSUMER":*'.getCookiesDescription'*)
            consumer_count=$((consumer_count + 1))
            ;;
        *)
            printf '%s\n' "$reference: getCookiesDescription is outside its declaration or clipboard consumer" \
                >> "$VIOLATIONS_FILE"
            ;;
    esac
done < "$REFERENCES_FILE"

if [ "$consumer_count" -ne 1 ]; then
    printf '%s\n' \
        "$DESCRIPTION_CONSUMER: expected exactly one getCookiesDescription clipboard consumer; found $consumer_count" \
        >> "$VIOLATIONS_FILE"
fi

if [ -s "$VIOLATIONS_FILE" ]; then
    printf '%s\n' 'Cookie logging audit failed:' >&2
    sed 's/^/  /' "$VIOLATIONS_FILE" >&2
    exit 1
fi

printf '%s\n' 'Cookie logging audit passed.'
