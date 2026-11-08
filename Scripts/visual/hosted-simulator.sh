#!/bin/bash
# The hosted simulator steps of the screenshot workflows, each under a time limit (19-04).
#
# usage: Scripts/visual/hosted-simulator.sh create <name> <device type> <runtime> <family>
#            Creates and boots the pinned simulator, sets it up for capture and prints its UDID. An attempt that
#            fails or overruns a limit is deleted, the simulator service is restarted, and the whole setup is made
#            once more.
#        Scripts/visual/hosted-simulator.sh clear-clones <name>
#            Waits until the parallel-testing clones of <name> ("Clone N of <name>") are shut down and deleted, so
#            the next xcodebuild makes fresh clones instead of reaching one still shutting down. Exits 1 if any is
#            left after 10 minutes.
#
# Run 42475531683 lost two jobs to `simctl create`/`boot`/`bootstatus` hanging until the 170-minute job limit, and
# compares to a test runner that could not launch on a clone still shutting down from the previous invocation.
# Every simctl call here has its own limit, so a hang becomes a failure that can be retried.
set -euo pipefail

usage() {
    sed -n '3,12p' "$0" >&2
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

# One attempt; prints the UDID. Called in a condition, where `set -e` does not apply, so every step checks itself.
create_once() {
    local name=$1 device=$2 runtime=$3 family=$4 udid
    udid=$(limit 120 xcrun simctl create "$name" "$device" "$runtime") || return 1
    echo "$udid" >"$ATTEMPT"
    limit 180 xcrun simctl boot "$udid" || return 1
    limit 300 xcrun simctl bootstatus "$udid" >/dev/null || return 1
    # The iPad pin's 25 pt bottom inset is Full Screen Apps; a new iPad has Windowed Apps (20 pt), which failed every
    # iPad picture on geometry in run 42442366372. The setting takes effect after a reboot.
    if [ "$family" = ipad ]; then
        limit 60 xcrun simctl spawn "$udid" defaults write com.apple.springboard SBMedusaMultitaskingEnabled \
            -bool NO || return 1
        limit 180 xcrun simctl shutdown "$udid" || return 1
        limit 180 xcrun simctl boot "$udid" || return 1
        limit 300 xcrun simctl bootstatus "$udid" >/dev/null || return 1
    fi
    # Before any clone is made, so every clone inherits them (19-01-MEASURE.md), and after the last boot, which can
    # reset Reduce Motion (Scripts/visual/README.md).
    limit 60 xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true ||
        return 1
    limit 60 xcrun simctl spawn "$udid" defaults write com.apple.Accessibility ApplicationAccessibilityEnabled \
        -bool true || return 1
    [ "$(limit 60 xcrun simctl spawn "$udid" defaults read com.apple.Accessibility ReduceMotionEnabled)" = 1 ] ||
        return 1
    echo "$udid"
}

# After a failed attempt: its device is deleted and the simulator service restarted (it is started again on the
# next simctl call). Nothing else runs simulators on a hosted runner.
reset_simulators() {
    local udid
    udid=$(cat "$ATTEMPT" 2>/dev/null || true)
    if [ -n "$udid" ]; then
        limit 120 xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
        limit 120 xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    fi
    killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
    sleep 10
}

create() {
    [ $# -eq 4 ] || usage
    ATTEMPT=$(mktemp)
    local attempt udid
    for attempt in 1 2; do
        : >"$ATTEMPT"
        if udid=$(create_once "$@"); then
            echo "$udid"
            return 0
        fi
        echo "hosted-simulator: creating '$1' failed on attempt $attempt" >&2
        reset_simulators
    done
    return 1
}

# "<udid> <state>" of every clone of <name> in the parallel-testing device set.
clones() {
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
    clear-clones) clear_clones "$@" ;;
    *) usage ;;
esac
