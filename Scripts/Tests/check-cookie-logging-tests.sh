#!/bin/sh

set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd "$SCRIPT_DIRECTORY/../.." && pwd)
GATE="$PROJECT_ROOT/Scripts/check-cookie-logging.sh"
FIXTURES="$SCRIPT_DIRECTORY/fixtures"
COOKIE_VIOLATION='cookie-bearing logger interpolation is not private'

fail() {
    printf '%s\n' "Cookie logging gate test failed: $1" >&2
    exit 1
}

expect_pass() {
    description=$1
    shift

    if output=$("$@" 2>&1); then
        case "$output" in
            *'Cookie logging audit passed.'*) ;;
            *) fail "$description did not print the pass message" ;;
        esac
    else
        status=$?
        printf '%s\n' "$output" >&2
        fail "$description exited with status $status"
    fi
}

expect_cookie_rejection() {
    description=$1
    fixture_root=$2

    if output=$("$GATE" "$fixture_root" 2>&1); then
        printf '%s\n' "$output" >&2
        fail "$description was accepted"
    fi

    case "$output" in
        *"$COOKIE_VIOLATION"*) ;;
        *)
            printf '%s\n' "$output" >&2
            fail "$description failed without the cookie-logging violation"
            ;;
    esac
}

expect_pass 'clean source scan' "$GATE"
expect_cookie_rejection 'aliased cookie value' "$FIXTURES/aliased-value"
expect_cookie_rejection 'alternate Logger receiver' "$FIXTURES/alternate-logger"
expect_pass 'private cookie interpolation' "$GATE" "$FIXTURES/private"

printf '%s\n' 'Cookie logging gate fixtures passed.'
