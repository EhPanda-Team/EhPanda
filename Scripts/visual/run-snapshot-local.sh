#!/bin/bash
# Runs chosen snapshot matrix classes on the local iPhone or iPad simulator in one configuration and mode, and
# fails on a failed or empty run or on any changed, missing (compare mode), timeout or error picture (19-02).
#
# usage: Scripts/visual/run-snapshot-local.sh --device phone|pad --config <locale>-<size>[,...] --classes A,B
#            --mode candidate|compare [--refs DIR] [--orientation portrait|landscape] [--workers N] --out DIR
#
# Only one xcodebuild runs on this host at a time (.planning/codebase/TESTING.md): the script waits for any other
# run to finish first. The simulator settings follow 19-01-MEASURE.md: Reduce Motion and the app accessibility
# runtime on before every run. An iPad process captures one orientation (iPadOS refuses in-process rotation), so
# on iPad the device is turned first with VisualCaptureOrientationUITests; the iPhone captures both in process.
# Several configurations run in one invocation, one after another. --workers N runs the classes on N simulator clones,
# as the hosted check does; without it the run is not parallel.
set -euo pipefail

usage() {
    sed -n '5,6p' "$0" >&2
    exit 2
}

DEVICE='' CONFIG='' CLASSES='' MODE='' REFS='' OUT='' ORIENTATION='' WORKERS=''
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
        *) usage ;;
    esac
done
case "$DEVICE" in
    phone) NAME='EhPanda iPhone Air' ;;
    pad) NAME='EhPanda iPad Pro 11-inch (M5)'; ORIENTATION=${ORIENTATION:-portrait} ;;
    *) usage ;;
esac
case "$MODE" in candidate | compare) ;; *) usage ;; esac
case "$ORIENTATION" in '' | portrait | landscape) ;; *) usage ;; esac
case "$WORKERS" in '' | [1-9]) ;; *) usage ;; esac
[ -n "$CONFIG" ] && [ -n "$CLASSES" ] && [ -n "$OUT" ] || usage
if [ "$MODE" = compare ] && [ -z "$REFS" ]; then
    echo 'Compare mode needs --refs.' >&2
    exit 2
fi

ROOT=$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
UDID=$(xcrun simctl list devices available | grep -F "$NAME (" | grep -Eo '[0-9A-F-]{36}' | head -1)
if [ -z "$UDID" ]; then
    echo "No simulator named $NAME." >&2
    exit 2
fi
mkdir -p "$OUT"
OUT=$(CDPATH='' cd "$OUT" && pwd)
LOG="$OUT/xcodebuild.log"
RESULTS="$OUT/results.jsonl"
rm -rf "$RESULTS" "$OUT/run.xcresult"

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
    if ! xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
        -destination "platform=iOS Simulator,id=$UDID" \
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
PARALLEL=()
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
    "${CONFIGURATIONS[@]}" -destination "platform=iOS Simulator,id=$UDID" \
    -resultBundlePath "$OUT/run.xcresult" ${PARALLEL[@]+"${PARALLEL[@]}"} "${ONLY[@]}" >"$LOG" 2>&1 || STATUS=$?

grep -E 'Executed [0-9]+ test|TEST (SUCCEEDED|FAILED)' "$LOG" | sort -u || true
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
if [ "$STATUS" -ne 0 ] || grep -qE 'TEST FAILED|Executed 0 tests' "$LOG"; then
    echo "Snapshot run failed ($LOG)." >&2
    exit 1
fi
