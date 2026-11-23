#!/bin/bash
# Runs chosen snapshot matrix classes on the local iPhone or iPad simulator in one configuration and mode, and
# fails on a failed or empty run or on any changed, missing (compare mode), timeout or error picture (19-02).
#
# usage: Scripts/visual/run-snapshot-local.sh --device phone|pad --config <locale>-<size>[,...] --classes A,B
#            --mode candidate|compare | --measure-heights [--refs DIR] [--orientation portrait|landscape]
#            [--workers N] [--simulator NAME] --out DIR
#
# Only one xcodebuild runs on this host at a time (.planning/codebase/TESTING.md): the script waits for any other
# run to finish first. The simulator settings follow 19-01-MEASURE.md: Reduce Motion and the app accessibility
# runtime on before every run. An iPad process captures one orientation (iPadOS refuses in-process rotation), so
# on iPad the device is turned first with VisualCaptureOrientationUITests; the iPhone captures both in process.
# Several configurations run in one invocation, one after another. --workers N runs the classes on N simulator clones;
# without it the run is not parallel, as on the hosted check. Clones boot in portrait whatever the turned iPad shows
# (19-10-PROOF.md), so an iPad landscape run takes no --workers.
#
# The simulator is found by its exact name (the default is `EhPanda iPhone Air` or `EhPanda iPad Pro 11-inch (M5)`;
# --simulator NAME names another for either --device), never by a prefix: other sessions on this host keep their own
# `EhPanda iPhone Air (<suffix>)`, which a prefix match picked up. Every xcodebuild gets `-collect-test-diagnostics
# never`, so a failing run does not idle in `simctl diagnose` (19-18).
#
# --measure-heights runs the chosen classes in the measuring mode (19-20, design section 3) instead of --mode: no
# picture is taken, and each coordinate gets one line in `<out>/heights.jsonl` with the page height its window needs
# (`measured`), or `cannot-cover` (a scroll view that keeps its height while the window grows, `cannot-cover:<class>`, or
# one that avoids a keyboard that is up, `cannot-cover:keyboard`, or a popover whose source lies outside the scene's
# bounds, `cannot-cover:popover`), `did-not-converge`, `error` or `notApplicable`. The
# page is hosted again at each taller height, in the capture's order (19-30). The summary counts the lines per status
# and the run fails when the file is missing or empty or holds an `error` or `did-not-converge` line.
# `Scripts/visual/snapshot_heights.py` turns such runs into the committed heights.
# Local only: the hosted gate never runs this mode (`Scripts/visual/test_snapshot_gate.py`).
set -euo pipefail

usage() {
    sed -n '5,7p' "$0" >&2
    exit 2
}

DEVICE='' CONFIG='' CLASSES='' MODE='' REFS='' OUT='' ORIENTATION='' WORKERS='' SIMULATOR='' MEASURE=''
while [ $# -gt 0 ]; do
    case "$1" in
        --device) DEVICE=${2:-}; shift 2 ;;
        --config) CONFIG=${2:-}; shift 2 ;;
        --classes) CLASSES=${2:-}; shift 2 ;;
        --mode) MODE=${2:-}; shift 2 ;;
        --refs) REFS=${2:-}; shift 2 ;;
        --out) OUT=${2:-}; shift 2 ;;
        --orientation) ORIENTATION=${2:-}; shift 2 ;;
        --workers) WORKERS=${2:-}; shift 2 ;;
        --simulator) SIMULATOR=${2:-}; shift 2 ;;
        --measure-heights) MEASURE=1; shift ;;
        *) usage ;;
    esac
done
case "$DEVICE" in
    phone) NAME='EhPanda iPhone Air' ;;
    pad) NAME='EhPanda iPad Pro 11-inch (M5)'; ORIENTATION=${ORIENTATION:-portrait} ;;
    *) usage ;;
esac
NAME=${SIMULATOR:-$NAME}
if [ -n "$MEASURE" ]; then
    if [ -n "$MODE" ]; then
        echo '--measure-heights replaces --mode.' >&2
        exit 2
    fi
    MODE=measure
else
    case "$MODE" in candidate | compare) ;; *) usage ;; esac
fi
case "$ORIENTATION" in '' | portrait | landscape) ;; *) usage ;; esac
case "$WORKERS" in '' | [1-9]) ;; *) usage ;; esac
[ -n "$CONFIG" ] && [ -n "$CLASSES" ] && [ -n "$OUT" ] || usage
if [ "$DEVICE" = pad ] && [ "$ORIENTATION" = landscape ] && [ -n "$WORKERS" ]; then
    echo 'An iPad landscape run takes no --workers: clones boot in portrait, not in the turned orientation.' >&2
    exit 2
fi
if [ "$MODE" = compare ] && [ -z "$REFS" ]; then
    echo 'Compare mode needs --refs.' >&2
    exit 2
fi

ROOT=$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
MATCHES=$(xcrun simctl list devices available -j | python3 -c '
import json
import sys

name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"] == name and device.get("isAvailable", True):
            print(device["udid"])
' "$NAME")
case "$(printf '%s' "$MATCHES" | grep -c .)" in
    0) echo "No simulator named $NAME." >&2; exit 2 ;;
    1) UDID=$MATCHES ;;
    *) echo "Several simulators named $NAME." >&2; exit 2 ;;
esac
mkdir -p "$OUT"
OUT=$(CDPATH='' cd "$OUT" && pwd)
LOG="$OUT/xcodebuild.log"
RESULTS="$OUT/results.jsonl"
HEIGHTS="$OUT/heights.jsonl"
rm -rf "$RESULTS" "$HEIGHTS" "$OUT/run.xcresult"

wait_for_host() {
    while pgrep -x xcodebuild >/dev/null; do sleep 15; done
}

prepare_simulator() {
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" >/dev/null
    xcrun simctl spawn "$UDID" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
    xcrun simctl spawn "$UDID" defaults write com.apple.Accessibility ApplicationAccessibilityEnabled -bool true
}

if [ "$DEVICE" = pad ]; then
    TURN=testRotateToPortrait
    [ "$ORIENTATION" = landscape ] && TURN=testRotateToLandscape
    wait_for_host
    prepare_simulator
    # The turn must act on the device that captures: a parallel-testing clone boots in portrait and turns itself, not
    # this device. Serial for this one UI test only, approved by the owner on 2026-11-22; every other test stays
    # parallel.
    if ! xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
        -destination "platform=iOS Simulator,id=$UDID" -collect-test-diagnostics never \
        -parallel-testing-enabled NO \
        -only-testing:"EhPandaUITests/VisualCaptureOrientationUITests/$TURN" >"$OUT/orientation.log" 2>&1; then
        echo "Could not turn the iPad ($OUT/orientation.log)." >&2
        exit 1
    fi
fi

ONLY=()
IFS=',' read -r -a NAMES <<<"$CLASSES"
for CLASS in "${NAMES[@]}"; do
    ONLY+=(-only-testing:"VisualSnapshotTests/$CLASS")
done

CONFIGURATIONS=()
IFS=',' read -r -a NAMES <<<"$CONFIG"
for NAME_ in "${NAMES[@]}"; do
    CONFIGURATIONS+=(-only-test-configuration "$NAME_")
done
PARALLEL=(-parallel-testing-enabled NO)
if [ -n "$WORKERS" ]; then
    PARALLEL=(-parallel-testing-enabled YES -parallel-testing-worker-count "$WORKERS")
fi

wait_for_host
prepare_simulator
VARIABLES=(TEST_RUNNER_EHPANDA_SNAPSHOT_MODE="$MODE" TEST_RUNNER_EHPANDA_SNAPSHOT_OUTPUT="$OUT")
if [ -n "$REFS" ]; then
    VARIABLES+=(TEST_RUNNER_EHPANDA_SNAPSHOT_REFERENCES="$(CDPATH='' cd "$REFS" && pwd)")
fi
if [ -n "$ORIENTATION" ]; then
    VARIABLES+=(TEST_RUNNER_EHPANDA_SNAPSHOT_ORIENTATIONS="$ORIENTATION")
fi
STATUS=0
env "${VARIABLES[@]}" xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan SnapshotMatrix \
    "${CONFIGURATIONS[@]}" -destination "platform=iOS Simulator,id=$UDID" -collect-test-diagnostics never \
    -resultBundlePath "$OUT/run.xcresult" ${PARALLEL[@]+"${PARALLEL[@]}"} "${ONLY[@]}" >"$LOG" 2>&1 || STATUS=$?

grep -E 'Executed [0-9]+ test|TEST (SUCCEEDED|FAILED)' "$LOG" | sort -u || true
if [ "$MODE" = measure ]; then
    python3 - "$HEIGHTS" <<'PY' || STATUS=1
import collections
import json
import sys

# A coordinate's later line replaces an earlier `error` of the same run.
last = {}
try:
    with open(sys.argv[1]) as lines:
        for line in lines:
            row = json.loads(line)
            last[row['key']] = row['status']
except FileNotFoundError:
    pass
counts = collections.Counter(last.values())
names = ['measured', 'cannot-cover', 'did-not-converge', 'error', 'notApplicable']
print(' '.join(f'{name}={counts[name]}' for name in names))
if not sum(counts[name] for name in names) or counts['error'] or counts['did-not-converge']:
    sys.exit(1)
PY
else
    python3 - "$RESULTS" "$MODE" <<'PY' || STATUS=1
import collections
import json
import sys

path, mode = sys.argv[1], sys.argv[2]
counts = collections.Counter()
try:
    with open(path) as lines:
        for line in lines:
            row = json.loads(line)
            counts[row['status']] += 1
            counts['flaky'] += bool(row.get('flaky'))
except FileNotFoundError:
    pass
names = ['passed', 'recorded', 'flaky', 'changed', 'missing-baseline', 'timeout', 'error', 'notApplicable']
labels = {'missing-baseline': 'missing'}
print(' '.join(f'{labels.get(name, name)}={counts[name]}' for name in names))
failing = ['changed', 'timeout', 'error'] + (['missing-baseline'] if mode == 'compare' else [])
if not sum(counts[name] for name in names if name != 'flaky') or any(counts[name] for name in failing):
    sys.exit(1)
PY
fi
if [ "$STATUS" -ne 0 ] || grep -qE 'TEST FAILED|Executed 0 tests' "$LOG"; then
    echo "Snapshot run failed ($LOG)." >&2
    exit 1
fi
