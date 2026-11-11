#!/bin/bash
# The hosted simulator steps of the screenshot workflows, each under a time limit (19-04).
#
# usage: Scripts/visual/hosted-simulator.sh create <name> <device type> <runtime> <family>
#            Creates and boots the pinned simulator, sets it up for capture and prints its UDID. An attempt that
#            fails or overruns a limit is deleted, the simulator service is restarted, and the whole setup is made
#            again, up to three attempts while the setup is under 25 minutes.
#        Scripts/visual/hosted-simulator.sh settings <udid>
#            Boots the device if it is shut down and sets Reduce Motion and the app accessibility runtime again. A UI
#            test run (the iPad turn) leaves the runtime off, and a parallel run shuts the device down to clone it
#            (19-10-PROOF.md); the next capture needs both on.
#        Scripts/visual/hosted-simulator.sh clear-clones <name>
#            Waits until the parallel-testing clones of <name> ("Clone N of <name>") are shut down and deleted, so
#            the next xcodebuild makes fresh clones instead of reaching one still shutting down. No testing device
#            set yet means no clones. Exits 1 if any is left after 10 minutes.
#
# Run 42475531683 lost two jobs to `simctl create`/`boot`/`bootstatus` hanging until the 170-minute job limit, and
# compares to a test runner that could not launch on a clone still shutting down from the previous invocation.
# Every simctl call here has its own limit, so a hang becomes a failure that can be retried.
#
# Run 42533872440 then failed the setup in 7 of 8 jobs, both attempts, on limits too short for its runners: settings
# writes stopped at 60 s, `bootstatus` at 300 s, the iPad's reboot shutdown at 180 s, and three writes that found the
# device "not booted" right after `bootstatus` had returned. The limits below are longer, and a write that finds the
# device not booted waits, boots it again and is made once more.
#
# Run 42577585956 still lost 7 of 27 setups, both attempts, on the first `defaults write` after `bootstatus` hanging
# until its 180 s limit (the iPad's Full Screen Apps switch, or Reduce Motion) or on `bootstatus` itself hanging for
# 600 s. Now every boot is waited for with `bootstatus -b` and given a short settle before the first write, a write
# the limit stopped is asked again like one that found the device not booted, and a third attempt is made.
#
# Run 42727781967 lost a retry when the pinned runtime left mid-setup: the device's boot found no runtime bundle and
# both further attempts were refused at once ("Invalid runtime"). Each attempt now waits until the runtime is
# listed as available; if it does not come back, the pinned runtime build is downloaded and waited for again.
set -euo pipefail

CREATE_LIMIT=120
BOOT_LIMIT=180
BOOTSTATUS_LIMIT=600
SETTING_LIMIT=180
SHUTDOWN_LIMIT=360
NOT_BOOTED_WAIT=${HOSTED_SIMULATOR_NOT_BOOTED_WAIT:-15}
# After `bootstatus` returns, before the first write (run 42577585956).
SETTLE_WAIT=${HOSTED_SIMULATOR_SETTLE_WAIT:-20}
# How long an attempt waits for the pinned runtime to be listed as available, before and after downloading it.
RUNTIME_WAIT=300
DOWNLOAD_LIMIT=1200
ENVIRONMENT=$(cd "$(dirname "$0")" && pwd)/regression-environment.json
ATTEMPTS=3
# No attempt starts after this many seconds of setup: it would leave the shard too little of its budget.
ATTEMPT_DEADLINE=1500
# `simctl --set testing` is this directory; xcodebuild makes it with its first clones.
TESTING_SET=${HOSTED_SIMULATOR_TESTING_SET:-$HOME/Library/Developer/XCTestDevices}

usage() {
    sed -n '3,15p' "$0" >&2
    exit 2
}

# limit <seconds> <command...>: runs the command, stopped after <seconds>. The watchdog writes its note to stderr
# (fd 3) and nothing else anywhere, so a command substitution around it ends with the command and stopping the
# watchdog prints nothing.
limit() {
    local seconds=$1
    shift
    "$@" &
    local pid=$!
    (sleep "$seconds" && kill -TERM "$pid" && echo "limit: stopped '$*' after $seconds s" >&3) 3>&2 >/dev/null 2>&1 &
    local watchdog=$! status=0
    wait "$pid" || status=$?
    pkill -P "$watchdog" 2>/dev/null || true
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    return "$status"
}

# spawn <udid> <command...>: runs the command on the device under its limit and prints its output. A device found
# not booted (CoreSimulator's `Process spawn via launchd failed because device is not booted`, right after
# `bootstatus` returned in run 42533872440), or a command its limit stopped (run 42577585956), is given a moment,
# booted again if it needs it, and asked twice more.
spawn() {
    local udid=$1 errors status try
    shift
    errors=$(mktemp)
    for try in 1 2 3; do
        status=0
        limit "$SETTING_LIMIT" xcrun simctl spawn "$udid" "$@" 2>"$errors" || status=$?
        if [ "$status" = 0 ]; then
            rm -f "$errors"
            return 0
        fi
        cat "$errors" >&2
        [ "$try" -lt 3 ] || break
        if [ "$status" = 143 ]; then
            echo "hosted-simulator: '$*' on '$udid' was stopped at its limit; asking again" >&2
        elif grep -qE 'device is not booted|Bad or unknown session' "$errors"; then
            echo "hosted-simulator: '$udid' was not booted for '$*'; booting it again" >&2
        else
            break
        fi
        sleep "$NOT_BOOTED_WAIT"
        limit "$BOOTSTATUS_LIMIT" xcrun simctl bootstatus "$udid" -b >/dev/null || break
    done
    rm -f "$errors"
    return "$status"
}

# One attempt; prints the UDID. Called in a condition, where `set -e` does not apply, so every step checks itself.
create_once() {
    local name=$1 device=$2 runtime=$3 family=$4 udid
    udid=$(limit "$CREATE_LIMIT" xcrun simctl create "$name" "$device" "$runtime") || return 1
    echo "$udid" >"$ATTEMPT"
    limit "$BOOT_LIMIT" xcrun simctl boot "$udid" || return 1
    booted "$udid" || return 1
    # The iPad pin's 25 pt bottom inset is Full Screen Apps; a new iPad has Windowed Apps (20 pt), which failed every
    # iPad picture on geometry in run 42442366372. The setting takes effect after a reboot.
    if [ "$family" = ipad ]; then
        spawn "$udid" defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO || return 1
        limit "$SHUTDOWN_LIMIT" xcrun simctl shutdown "$udid" || return 1
        limit "$BOOT_LIMIT" xcrun simctl boot "$udid" || return 1
        booted "$udid" || return 1
    fi
    # Before any clone is made, so every clone inherits them (19-01-MEASURE.md), and after the last boot, which can
    # reset Reduce Motion (Scripts/visual/README.md).
    capture_settings "$udid" || return 1
    echo "$udid"
}

# booted <udid>: waits until the device has booted (booting it if it went down) and lets it settle.
booted() {
    limit "$BOOTSTATUS_LIMIT" xcrun simctl bootstatus "$1" -b >/dev/null || return 1
    sleep "$SETTLE_WAIT"
}

# capture_settings <udid>: both switches on, each read back.
capture_settings() {
    local udid=$1 key
    for key in ReduceMotionEnabled ApplicationAccessibilityEnabled; do
        spawn "$udid" defaults write com.apple.Accessibility "$key" -bool true || return 1
        [ "$(spawn "$udid" defaults read com.apple.Accessibility "$key")" = 1 ] || return 1
    done
}

settings() {
    [ $# -eq 1 ] || usage
    # `-b` boots the device first when a parallel run left it shut down.
    limit "$BOOTSTATUS_LIMIT" xcrun simctl bootstatus "$1" -b >/dev/null || return 1
    capture_settings "$1"
}

# After a failed attempt: its device is deleted and, on a hosted runner (CI set), the simulator service restarted
# (it is started again on the next simctl call). Nothing else runs simulators on a hosted runner; on any other Mac
# the service is shared with other processes' simulators and UI-test sessions, so it is left alone.
reset_simulators() {
    local udid
    udid=$(cat "$ATTEMPT" 2>/dev/null || true)
    if [ -n "$udid" ]; then
        limit 120 xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
        limit 120 xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    fi
    if [ -n "${CI:-}" ]; then
        killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
    else
        echo "hosted-simulator: not restarting the simulator service outside CI" >&2
    fi
    sleep 10
}

# runtime_available <runtime>: whether simctl lists the runtime identifier as available.
runtime_available() {
    limit 60 xcrun simctl list runtimes -j 2>/dev/null | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["runtimes"]
sys.exit(0 if any(r.get("identifier") == sys.argv[1] and r.get("isAvailable") for r in runtimes) else 1)' "$1"
}

# wait_for_runtime <runtime>: up to RUNTIME_WAIT seconds for the runtime to be listed as available.
wait_for_runtime() {
    local deadline=$((SECONDS + RUNTIME_WAIT))
    until runtime_available "$1"; do
        [ "$SECONDS" -lt "$deadline" ] || return 1
        sleep 10
    done
}

# ensure_runtime <runtime>: the runtime is available, waited for and, if it does not come back, downloaded again by its
# pinned build (regression-environment.json).
ensure_runtime() {
    local build
    wait_for_runtime "$1" && return 0
    echo "hosted-simulator: '$1' is not available after $RUNTIME_WAIT s; downloading it again" >&2
    build=$(python3 -c 'import json, sys
runtime = json.load(open(sys.argv[1]))["runtime"]
print(runtime["buildVersion"] if runtime["identifier"] == sys.argv[2] else "")' "$ENVIRONMENT" "$1") || return 1
    [ -n "$build" ] || return 1
    limit "$DOWNLOAD_LIMIT" xcodebuild -downloadPlatform iOS -buildVersion "$build" >&2 || return 1
    wait_for_runtime "$1"
}

create() {
    [ $# -eq 4 ] || usage
    ATTEMPT=$(mktemp)
    local attempt udid
    for attempt in $(seq "$ATTEMPTS"); do
        : >"$ATTEMPT"
        if ! ensure_runtime "$3"; then
            echo "hosted-simulator: '$3' is not available on attempt $attempt after $SECONDS s" >&2
        elif udid=$(create_once "$@"); then
            echo "$udid"
            return 0
        fi
        echo "hosted-simulator: creating '$1' failed on attempt $attempt after $SECONDS s" >&2
        reset_simulators
        if [ "$SECONDS" -ge "$ATTEMPT_DEADLINE" ]; then
            echo "hosted-simulator: no attempt starts after $ATTEMPT_DEADLINE s of setup" >&2
            break
        fi
    done
    return 1
}

# "<udid> <state>" of every clone of <name> in the parallel-testing device set. Before the first xcodebuild made a
# clone the set does not exist, `simctl --set testing` fails ("Provided set path does not exist"), and there is no
# clone; run 42533872440 read that as unreadable and waited the full 10 minutes.
clones() {
    [ -d "$TESTING_SET" ] || return 0
    limit 60 xcrun simctl --set testing list devices -j 2>/dev/null | python3 -c '
import json, sys
suffix = " of " + sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"].endswith(suffix):
            print(device["udid"], device["state"].replace(" ", "-"))' "$1"
}

clear_clones() {
    [ $# -eq 1 ] || usage
    local deadline=$((SECONDS + 600)) list udid state
    while :; do
        list=$(clones "$1") || list='unreadable'
        [ -z "$list" ] && return 0
        if [ "$list" != unreadable ]; then
            while read -r udid state; do
                case $state in
                    Shutdown) limit 120 xcrun simctl --set testing delete "$udid" >/dev/null 2>&1 || true ;;
                    Booted) limit 120 xcrun simctl --set testing shutdown "$udid" >/dev/null 2>&1 || true ;;
                    # Creating, Booting, Shutting-Down: still on its way; read again.
                    *) ;;
                esac
            done <<<"$list"
        fi
        if [ "$SECONDS" -ge "$deadline" ]; then
            echo "hosted-simulator: clones of '$1' left after 10 minutes: $(echo "$list" | tr '\n' ' ')" >&2
            return 1
        fi
        sleep 5
    done
}

[ $# -ge 1 ] || usage
command=$1
shift
case "$command" in
    create) create "$@" ;;
    settings) settings "$@" ;;
    clear-clones) clear_clones "$@" ;;
    *) usage ;;
esac
