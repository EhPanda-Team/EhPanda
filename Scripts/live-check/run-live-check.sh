#!/bin/bash
# The daily live-parsing check's one entry point for both runners (19-15; 19-CONTEXT D-20 to D-25).
#
#   run-live-check.sh --mode hosted|local [--dry-run] [--gh PATH] [--repo OWNER/NAME] [--output DIR]
#                     [--state-dir DIR] [--simulator NAME] [--results FILE]
#
# It builds and runs the LiveCheck test plan's DailyLiveCheckTests, which writes results.json, then hands that file
# to report_issues.py with the previous runs' results:
# - hosted: the last two successful runs' `live-check-results` artifacts, read with `gh run list` / `gh run download`;
# - local: the state directory ($HOME/Library/Application Support/EhPanda live check/), which holds result files
#   only and keeps the last three. In local mode the script first waits up to 2 h for any other xcodebuild to finish
#   (one xcodebuild at a time on a machine, .planning/codebase/TESTING.md), and otherwise skips the day with a note.
#
# The xcodebuild console log is discarded except its final status line: the URL loading system logs a failed
# request with its URL, and the hosted run's log is public (D-22). `--dry-run` passes through to the reporter, which
# then only lists issues; a dry run also leaves the state directory unchanged. `--results FILE` skips the build and
# test and reports an existing results file. `--gh` names the gh to use (tests pass fake-gh/gh).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
REPORTER="$SCRIPT_DIR/report_issues.py"

MODE=
DRY_RUN=
GH=gh
REPO=${EHPANDA_LIVE_CHECK_REPO:-${GITHUB_REPOSITORY:-}}
OUTPUT=
STATE_DIR="$HOME/Library/Application Support/EhPanda live check"
SIMULATOR=
RESULTS=
WAIT_SECONDS=${EHPANDA_LIVE_CHECK_WAIT_SECONDS:-7200}
KEEP_RESULTS=3
PREVIOUS_RUNS=2

note() {
    printf '%s live check: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

usage() {
    sed -n '4,5p' "$0" | sed 's/^# *//' >&2
    exit 64
}

while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE=${2:-}; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --gh) GH=${2:-}; shift 2 ;;
        --repo) REPO=${2:-}; shift 2 ;;
        --output) OUTPUT=${2:-}; shift 2 ;;
        --state-dir) STATE_DIR=${2:-}; shift 2 ;;
        --simulator) SIMULATOR=${2:-}; shift 2 ;;
        --results) RESULTS=${2:-}; shift 2 ;;
        -h|--help) usage ;;
        *) note "unknown argument"; usage ;;
    esac
done

case "$MODE" in
    hosted) SIMULATOR=${SIMULATOR:-iPhone Air} ;;
    local) SIMULATOR=${SIMULATOR:-EhPanda iPhone Air} ;;
    *) note "--mode must be hosted or local"; usage ;;
esac

case "$GH" in
    */*) GH=$(cd "$(dirname "$GH")" && pwd)/$(basename "$GH") ;;
esac

if [ "$MODE" = local ]; then
    # Local runs use the Mac's own gh sign-in, never a token handed to this shell by another tool.
    unset GH_TOKEN GITHUB_TOKEN
fi

if [ -z "$REPO" ]; then
    # OWNER/NAME of the checkout's origin, read from the local git configuration.
    REPO=$(git -C "$ROOT" remote get-url origin 2>/dev/null \
        | sed -E 's#^(https://([^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##; s#/$##')
fi
if ! printf '%s' "$REPO" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+$'; then
    note "no repository: pass --repo OWNER/NAME"
    exit 64
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/ehpanda-live-check.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
OUTPUT=${OUTPUT:-$WORK/output}
mkdir -p "$OUTPUT"

wait_for_other_xcodebuild() {
    local waited=0
    while pgrep -x xcodebuild >/dev/null; do
        if [ "$waited" -ge "$WAIT_SECONDS" ]; then
            note "skipped today: another xcodebuild was still running after $((WAIT_SECONDS / 60)) min"
            exit 0
        fi
        if [ "$waited" -eq 0 ]; then
            note "waiting for another xcodebuild to finish (up to $((WAIT_SECONDS / 60)) min)"
        fi
        sleep 60
        waited=$((waited + 60))
    done
}

destination() {
    if [ "$MODE" = hosted ]; then
        printf 'platform=iOS Simulator,name=%s,OS=27.0' "$SIMULATOR"
        return
    fi
    local udid
    udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = [device for runtime, found in json.load(sys.stdin)["devices"].items() if "iOS" in runtime
           for device in found if device["name"] == name]
print(devices[0]["udid"] if devices else "")
' "$SIMULATOR")
    if [ -z "$udid" ]; then
        note "no available simulator named $SIMULATOR"
        exit 1
    fi
    printf 'platform=iOS Simulator,id=%s' "$udid"
}

run_check() {
    local log="$WORK/xcodebuild.log" status=0 dest
    dest=$(destination)
    note "running DailyLiveCheckTests ($MODE)"
    rm -f "$OUTPUT/results.json"
    TEST_RUNNER_EHPANDA_LIVE_CHECK=1 \
    TEST_RUNNER_EHPANDA_LIVE_CHECK_MODE="$MODE" \
    TEST_RUNNER_EHPANDA_LIVE_CHECK_OUTPUT="$OUTPUT" \
        xcodebuild test \
            -project "$ROOT/EhPanda.xcodeproj" \
            -scheme EhPanda \
            -testPlan LiveCheck \
            -destination "$dest" \
            -only-testing:LiveCheckTests/DailyLiveCheckTests \
            -skipMacroValidation \
            -skipPackagePluginValidation \
            -onlyUsePackageVersionsFromResolvedFile >"$log" 2>&1 || status=$?
    grep -E '\*\* (TEST|BUILD) (SUCCEEDED|FAILED) \*\*' "$log" | tail -1 || true
    rm -f "$log"
    if [ ! -f "$OUTPUT/results.json" ]; then
        note "no results were written (xcodebuild exit status $status)"
        exit 1
    fi
    RESULTS="$OUTPUT/results.json"
}

previous_hosted() {
    local previous="$WORK/previous" ids
    mkdir -p "$previous"
    ids=$("$GH" run list --repo "$REPO" --workflow live-check.yml --status success --limit 10 \
        --json databaseId 2>/dev/null | python3 -c '
import json, os, sys
current = os.environ.get("GITHUB_RUN_ID", "")
try:
    runs = json.load(sys.stdin)
except ValueError:
    runs = []
ids = [str(run["databaseId"]) for run in runs if isinstance(run, dict) and str(run.get("databaseId", "")).isdigit()
       and str(run["databaseId"]) != current]
print(" ".join(ids[:int(sys.argv[1])]))
' "$PREVIOUS_RUNS") || ids=
    for id in $ids; do
        "$GH" run download "$id" --repo "$REPO" --name live-check-results --dir "$previous/$id" >/dev/null 2>&1 \
            || note "run $id has no results artifact any more"
    done
    PREVIOUS="$previous"
}

store_local() {
    local stamp
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    mkdir -p "$STATE_DIR"
    cp "$RESULTS" "$STATE_DIR/results-$stamp.json"
    # Keep the newest three result files; the directory holds nothing else.
    ls -1 "$STATE_DIR" | grep -E '^results-[0-9]{8}T[0-9]{6}Z\.json$' | sort -r | tail -n +$((KEEP_RESULTS + 1)) \
        | while read -r old; do rm -f "$STATE_DIR/$old"; done
}

if [ -z "$RESULTS" ]; then
    if [ "$MODE" = local ]; then
        wait_for_other_xcodebuild
    fi
    run_check
fi

if [ "$MODE" = hosted ]; then
    previous_hosted
else
    PREVIOUS="$STATE_DIR"
fi

status=0
python3 "$REPORTER" --results "$RESULTS" --previous "$PREVIOUS" --repo "$REPO" --gh "$GH" ${DRY_RUN:+--dry-run} \
    || status=$?

if [ "$MODE" = local ] && [ "$status" -ne 2 ]; then
    if [ -n "$DRY_RUN" ]; then
        note "dry run: results not stored"
    else
        store_local
    fi
fi
exit "$status"
