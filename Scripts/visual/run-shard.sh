#!/bin/bash
# Runs one shard of the snapshot gate on a hosted Mac and records its class in shard.json (19-10; D-15, owner msg 2263).
#
# usage: Scripts/visual/run-shard.sh --shard sNN --mode compare|candidate --products DIR [--attempt 1|2]
#            [--out DIR] [--fingerprints FILE]
#
# The shard is one entry of Scripts/visual/snapshot-shards.json: one device, one or more configurations, run as the
# entry's `invocations` (one xcodebuild each, one after another; 19-04 put each invocation's fixed cost at 7 to 10
# minutes, so a shard runs as few as it can). In order:
#
# 1. The rendering pin (Scripts/visual/regression-environment.json): this runner's Xcode build, simulator runtime
#    build and device type. On any mismatch the shard records `infra: drift`, captures nothing and exits 0.
# 2. Compare mode: the shard's baseline slices are fetched and checked against Baseline/fingerprints.json
#    (Scripts/visual/snapshot_fetch.py). A mismatch, or no fingerprints.json ("no approved baseline yet"), records
#    `infra: baseline-mismatch` and captures nothing.
# 3. The pinned simulator, made by Scripts/visual/hosted-simulator.sh with its limits and its retries; every
#    xcodebuild starts after the previous one's clones are gone (`clear-clones`).
# 4. Each invocation runs the SnapshotMatrixCase classes (not the Tracer ones) on the measured worker count of
#    clones, with XCTest's per-test allowance, a budget watchdog and a startup watchdog (no test begun after 20
#    minutes, Scripts/visual/snapshot_infra.py --started). An iPad process captures the orientation the device is
#    in, so the device is turned first with VisualCaptureOrientationUITests (the UITests products). The settings step
#    (hosted-simulator.sh settings) comes before the turn, so a device a parallel run shut down is booted and settled
#    first (one the turn's own xcodebuild booted was back in portrait by the capture), and after it, because its UI
#    test run leaves the app accessibility runtime off. Clones boot in portrait whatever the turned device shows
#    (19-10-PROOF.md), so an iPad landscape invocation runs on the turned device itself, without clones; the shard
#    plan's estimate counts it without the clone speedup.
# 5. An invocation that crashed or was stopped leaves classes without results (results.jsonl says which are done):
#    once all invocations have run, each such invocation runs once more for those classes only, after their partial
#    lines are dropped. Classes still unfinished after that record `infra: crash`, or `timeout` when the budget
#    stopped them; picture changes are results, never a re-run.
#
# shard.json is written first as `timeout`, so a step stopped by its limit still reads as an infrastructure error, and
# rewritten at the end. The script exits 0 whatever the pictures or the class are; it exits 1 only when the runner is
# unusable (no simulator, no products, the baseline could not be fetched), leaving no shard.json, which the
# aggregate reads as a lost runner and the gate retries. No result bundle is written to the output (D-14).
#
# For the hosted proof only (19-10 Task 4, never on the phase branch or main), EHPANDA_SNAPSHOT_FAULT injects
# `<shard>=crash` (every capture invocation of the attempt is killed after EHPANDA_SNAPSHOT_FAULT_SECONDS, 180 by
# default) or `<shard>=no-artifact` (the shard leaves no output at all), on attempt 1 unless `@every-attempt` is
# appended. The budget is the shard's timeout less 5 minutes (EHPANDA_SHARD_BUDGET_SECONDS overrides it), three
# quarters of it for the first pass.
set -euo pipefail

usage() {
    sed -n '4,5p' "$0" >&2
    exit 2
}

SHARD='' MODE='' PRODUCTS='' ATTEMPT=1 OUT='' FINGERPRINTS=''
while [ $# -gt 0 ]; do
    case "$1" in
        --shard) SHARD=${2:-}; shift 2 ;;
        --mode) MODE=${2:-}; shift 2 ;;
        --products) PRODUCTS=${2:-}; shift 2 ;;
        --attempt) ATTEMPT=${2:-}; shift 2 ;;
        --out) OUT=${2:-}; shift 2 ;;
        --fingerprints) FINGERPRINTS=${2:-}; shift 2 ;;
        *) usage ;;
    esac
done
case "$MODE" in compare | candidate) ;; *) usage ;; esac
case "$ATTEMPT" in 1 | 2) ;; *) usage ;; esac
[ -n "$SHARD" ] && [ -n "$PRODUCTS" ] || usage

HERE=$(CDPATH='' cd "$(dirname "$0")" && pwd)
ROOT=$(CDPATH='' cd "$HERE/../.." && pwd)
PLAN=${EHPANDA_SHARD_PLAN:-$HERE/snapshot-shards.json}
INVENTORY=${EHPANDA_SNAPSHOT_INVENTORY:-$ROOT/AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json}
ENVIRONMENT=${EHPANDA_SNAPSHOT_ENVIRONMENT:-$HERE/regression-environment.json}
SOURCES=${EHPANDA_SNAPSHOT_SOURCES:-$ROOT/AppPackage/Tests/VisualSnapshotTests}
SIMULATOR=${EHPANDA_HOSTED_SIMULATOR:-$HERE/hosted-simulator.sh}
FINGERPRINTS=${FINGERPRINTS:-$ROOT/AppPackage/Tests/VisualSnapshotTests/Baseline/fingerprints.json}
OUT=${OUT:-${RUNNER_TEMP:-$ROOT/build}/shard/$SHARD}
FAULT_SECONDS=${EHPANDA_SNAPSHOT_FAULT_SECONDS:-180}
STARTUP_SECONDS=${EHPANDA_SHARD_STARTUP_SECONDS:-1200}
NAME='EhPanda gate'
START=$SECONDS
STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

helper() {
    local command=$1
    shift
    python3 "$HERE/snapshot_shard.py" "$command" --shards "$PLAN" --inventory "$INVENTORY" \
        --environment "$ENVIRONMENT" "$@"
}

FAULT=$(helper fault --shard "$SHARD" --attempt "$ATTEMPT")
if [ "$FAULT" = no-artifact ]; then
    echo "fault: $SHARD leaves no artifact on attempt $ATTEMPT (EHPANDA_SNAPSHOT_FAULT)"
    rm -rf "$OUT"
    exit 0
fi

# The fetched baseline and scratch files stay beside the output, never in the uploaded directory.
WORK="$OUT.work"
rm -rf "$OUT" "$WORK"
mkdir -p "$OUT/logs" "$WORK"
OUT=$(CDPATH='' cd "$OUT" && pwd)
WORK=$(CDPATH='' cd "$WORK" && pwd)
RESULTS="$OUT/results.jsonl"
IFS=$'\t' read -r FAMILY DEVICE_TYPE RUNTIME WORKERS TIMEOUT ESTIMATE <<<"$(helper describe --shard "$SHARD")"
BUDGET=${EHPANDA_SHARD_BUDGET_SECONDS:-$(((TIMEOUT - 5) * 60))}
FIRST_PASS=$((BUDGET * 3 / 4))
RERUN=''

xcodebuild -version >"$WORK/xcode.txt"
XCODE=$(tr '\n' ' ' <"$WORK/xcode.txt" | sed 's/ *$//')

record() { # <infra or ""> [detail]
    helper record --shard "$SHARD" --out "$OUT/shard.json" --mode "$MODE" --attempt "$ATTEMPT" \
        --infra "$1" --detail "${2:-}" --started "$STARTED" --xcode "$XCODE" \
        --runner "${ImageOS:-unknown} ${ImageVersion:-unknown}" --rerun "$RERUN"
}

# The runner is unusable: no shard.json, so the aggregate counts the shard as lost and the gate retries it.
unusable() {
    echo "run-shard: $SHARD: $*" >&2
    rm -f "$OUT/shard.json"
    exit 1
}

xcrun simctl list runtimes -j >"$WORK/runtimes.json"
xcrun simctl list devicetypes -j >"$WORK/devicetypes.json"
if ! DRIFT=$(helper drift --shard "$SHARD" --xcode "$WORK/xcode.txt" --runtimes "$WORK/runtimes.json" \
    --devicetypes "$WORK/devicetypes.json"); then
    echo "drift: $DRIFT"
    record drift "$DRIFT"
    exit 0
fi
record timeout 'the shard step ended before the shard finished'

REFERENCES=''
if [ "$MODE" = compare ]; then
    STATUS=0
    python3 "$HERE/snapshot_fetch.py" --fingerprints "$FINGERPRINTS" --slices "$(helper slices --shard "$SHARD")" \
        --dest "$WORK/baseline" >"$OUT/logs/fetch.log" 2>&1 || STATUS=$?
    cat "$OUT/logs/fetch.log"
    case $STATUS in
        0) REFERENCES="$WORK/baseline" ;;
        3) record baseline-mismatch "$(grep -m 1 '^baseline-mismatch: ' "$OUT/logs/fetch.log")"; exit 0 ;;
        4) record baseline-mismatch 'no approved baseline yet'; exit 0 ;;
        *) unusable 'the baseline could not be fetched' ;;
    esac
fi

SNAPSHOT_RUN=$(find "$PRODUCTS" -name '*SnapshotMatrix*.xctestrun' | head -1)
UI_RUN=$(find "$PRODUCTS" -name '*UITests*.xctestrun' | head -1)
[ -n "$SNAPSHOT_RUN" ] || unusable "no SnapshotMatrix .xctestrun under $PRODUCTS"
[ "$FAMILY" = iphone ] || [ -n "$UI_RUN" ] || unusable "no UITests .xctestrun under $PRODUCTS to turn the iPad"
UDID=$("$SIMULATOR" create "$NAME" "$DEVICE_TYPE" "$RUNTIME" "$FAMILY" 2>"$OUT/logs/simulator.log") ||
    unusable "the simulator could not be made ($OUT/logs/simulator.log)"
# A new iPad starts in portrait.
CURRENT=portrait

CLASSES=$(helper classes --sources "$SOURCES" | tr '\n' ' ')
INVOCATION_CONFIGURATIONS=()
INVOCATION_ORIENTATIONS=()
while read -r CONFIGURATIONS ORIENTATIONS; do
    INVOCATION_CONFIGURATIONS+=("$CONFIGURATIONS")
    INVOCATION_ORIENTATIONS+=("$ORIENTATIONS")
done <<<"$(helper invocations --shard "$SHARD")"

# Locally only one xcodebuild runs on a host at a time (.planning/codebase/TESTING.md); a hosted runner has no other.
wait_for_host() {
    [ -n "${CI:-}" ] && return 0
    while pgrep -x xcodebuild >/dev/null; do sleep 15; done
}

stop_watcher() {
    pkill -P "$1" 2>/dev/null || true
    kill "$1" 2>/dev/null || true
    wait "$1" 2>/dev/null || true
}

# run_tests <xctestrun> <log> <seconds> <xcodebuild arguments…>: the one place a test run starts. TEST_ENV holds
# its TEST_RUNNER_ variables and KILL_AFTER the proof's crash delay (empty: none). Sets STOPPED to `budget` when the
# budget watchdog stopped it.
TEST_ENV=()
KILL_AFTER=''
STOPPED=''
run_tests() {
    local xctestrun=$1 log=$2 seconds=$3 status=0 baseline
    shift 3
    STOPPED=''
    wait_for_host
    "$SIMULATOR" clear-clones "$NAME" >>"$log" 2>&1 || true
    baseline=$(grep -c . "$RESULTS" 2>/dev/null || true)
    rm -f "$WORK/stopped"
    env ${TEST_ENV[@]+"${TEST_ENV[@]}"} xcodebuild test-without-building -xctestrun "$xctestrun" \
        -destination "platform=iOS Simulator,id=$UDID" "$@" >>"$log" 2>&1 &
    local pid=$!
    ( sleep "$seconds" && kill -TERM "$pid" 2>/dev/null && touch "$WORK/stopped" &&
        echo "watchdog: stopped at the shard budget after $seconds s" >>"$log" ) >/dev/null 2>&1 &
    local budget=$!
    # A clone that never launches the test runner leaves the invocation waiting with no test begun (19-04).
    ( sleep "$STARTUP_SECONDS" &&
        ! python3 "$HERE/snapshot_infra.py" --started "$log" "$RESULTS" --baseline "${baseline:-0}" &&
        kill -TERM "$pid" 2>/dev/null &&
        echo "watchdog: no test started after $STARTUP_SECONDS s" >>"$log" ) >/dev/null 2>&1 &
    local startup=$! fault=''
    if [ -n "$KILL_AFTER" ]; then
        ( sleep "$KILL_AFTER" && kill -KILL "$pid" 2>/dev/null &&
            echo "fault: killed after $KILL_AFTER s (EHPANDA_SNAPSHOT_FAULT=$SHARD=crash)" >>"$log" ) \
            >/dev/null 2>&1 &
        fault=$!
    fi
    wait "$pid" || status=$?
    stop_watcher "$budget"
    stop_watcher "$startup"
    [ -z "$fault" ] || stop_watcher "$fault"
    if [ -e "$WORK/stopped" ]; then
        STOPPED=budget
        rm -f "$WORK/stopped"
    fi
    return "$status"
}

# turn <orientation>: an iPad process captures the orientation the device is in (19-01-MEASURE.md).
turn() {
    local orientation=$1 method=testRotateToPortrait
    [ "$FAMILY" = ipad ] && [ "$CURRENT" != "$orientation" ] || return 0
    [ "$orientation" = landscape ] && method=testRotateToLandscape
    TEST_ENV=()
    KILL_AFTER=''
    "$SIMULATOR" settings "$UDID" >>"$OUT/logs/turn-$orientation.log" 2>&1 || return 1
    run_tests "$UI_RUN" "$OUT/logs/turn-$orientation.log" "$(remaining "$BUDGET")" \
        -parallel-testing-enabled NO \
        -only-testing:"EhPandaUITests/VisualCaptureOrientationUITests/$method" || return 1
    "$SIMULATOR" settings "$UDID" >>"$OUT/logs/turn-$orientation.log" 2>&1 || return 1
    CURRENT=$orientation
}

remaining() { # <deadline in seconds from the start>
    echo $(($1 - (SECONDS - START)))
}

# capture <index> <pass> <deadline> <classes…>: one invocation of the shard over the given classes.
TIMED_OUT=''
capture() {
    local index=$1 pass=$2 deadline=$3 seconds configuration name
    shift 3
    local log="$OUT/logs/xcodebuild-$((index + 1))-$pass.log"
    local orientations=${INVOCATION_ORIENTATIONS[$index]}
    seconds=$(remaining "$deadline")
    if [ "$seconds" -le 0 ]; then
        echo "watchdog: no budget left for invocation $((index + 1)) pass $pass" >>"$log"
        TIMED_OUT=1
        return 1
    fi
    if ! turn "$orientations"; then
        echo "turn: the iPad could not be turned to $orientations ($OUT/logs/turn-$orientations.log)" >>"$log"
        return 1
    fi
    local arguments=(-parallel-testing-enabled YES -parallel-testing-worker-count "$WORKERS")
    # A clone would boot in portrait: the iPad's landscape is captured on the turned device itself.
    [ "$FAMILY" != ipad ] || [ "$orientations" != landscape ] || arguments=(-parallel-testing-enabled NO)
    arguments+=(-test-timeouts-enabled YES -default-test-execution-time-allowance 300
        -maximum-test-execution-time-allowance 600)
    IFS=',' read -r -a NAMES <<<"${INVOCATION_CONFIGURATIONS[$index]}"
    for configuration in "${NAMES[@]}"; do
        arguments+=(-only-test-configuration "$configuration")
    done
    for name in "$@"; do
        arguments+=(-only-testing:"VisualSnapshotTests/$name")
    done
    TEST_ENV=(TEST_RUNNER_EHPANDA_SNAPSHOT_MODE="$MODE" TEST_RUNNER_EHPANDA_SNAPSHOT_OUTPUT="$OUT")
    [ -z "$REFERENCES" ] || TEST_ENV+=(TEST_RUNNER_EHPANDA_SNAPSHOT_REFERENCES="$REFERENCES")
    [ "$FAMILY" = iphone ] || TEST_ENV+=(TEST_RUNNER_EHPANDA_SNAPSHOT_ORIENTATIONS="$orientations")
    KILL_AFTER=''
    [ "$FAULT" != crash ] || KILL_AFTER=$FAULT_SECONDS
    local status=0
    run_tests "$SNAPSHOT_RUN" "$log" "$seconds" "${arguments[@]}" || status=$?
    [ "$STOPPED" != budget ] || TIMED_OUT=1
    echo "$SHARD invocation $((index + 1)) pass $pass (${INVOCATION_CONFIGURATIONS[$index]}, $orientations):" \
        "exit $status${STOPPED:+, stopped at the budget}"
    return "$status"
}

COUNT=${#INVOCATION_CONFIGURATIONS[@]}
INDEX=0
# shellcheck disable=SC2086 # CLASSES is a space-separated list of Swift class names.
while [ "$INDEX" -lt "$COUNT" ]; do
    capture "$INDEX" 1 "$FIRST_PASS" $CLASSES || true
    INDEX=$((INDEX + 1))
done
INDEX=0
while [ "$INDEX" -lt "$COUNT" ]; do
    PENDING=$(helper pending --shard "$SHARD" --invocation "$INDEX" --results "$RESULTS" --sources "$SOURCES" --prune)
    if [ -n "$PENDING" ]; then
        RERUN="$RERUN $PENDING"
        # shellcheck disable=SC2086
        capture "$INDEX" 2 "$BUDGET" $PENDING || true
    fi
    INDEX=$((INDEX + 1))
done

UNFINISHED=''
INDEX=0
while [ "$INDEX" -lt "$COUNT" ]; do
    PENDING=$(helper pending --shard "$SHARD" --invocation "$INDEX" --results "$RESULTS" --sources "$SOURCES")
    [ -z "$PENDING" ] || UNFINISHED="$UNFINISHED invocation $((INDEX + 1)): $PENDING;"
    INDEX=$((INDEX + 1))
done

# A changed picture's baseline beside its actual and difference, so the failure triplet travels with the shard.
if [ -n "$REFERENCES" ]; then
    for KIND in actual first-actual; do
        [ -d "$OUT/$KIND" ] || continue
        (cd "$OUT/$KIND" && find . -name '*.png') | while read -r PICTURE; do
            mkdir -p "$(dirname "$OUT/reference/$PICTURE")"
            cp "$REFERENCES/$PICTURE" "$OUT/reference/$PICTURE" 2>/dev/null || true
        done
    done
fi

if [ -z "$UNFINISHED" ]; then
    record ''
elif [ -n "$TIMED_OUT" ]; then
    record timeout "unfinished after one re-run:$UNFINISHED"
else
    record crash "unfinished after one re-run:$UNFINISHED"
fi
echo "$SHARD took $(((SECONDS - START) / 60)) min against an estimate of $ESTIMATE and a limit of $TIMEOUT"
