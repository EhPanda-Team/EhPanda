#!/usr/bin/env python3
"""Tells an `xcodebuild` invocation the hosted simulator failed (infra) from one whose tests ran (19-04).

Run 42475531683 lost 5 of 8 measurement jobs to the simulator, not to the pictures: clones that did not boot within
60 s, a test runner that could not launch on a clone still shutting down from the previous invocation, a lost
connection to the runner before launch, and an app launch that never returned while no test started. `xcodebuild`
reports all of them as a failed test run (exit 65). The workflows retry such an invocation once, and the reducer
reports a run that failed this way twice as `infra`, not as a measurement.

An invocation is infra when it exited non-zero and its log holds one of the simulator failures below, or the
workflow's startup watchdog stopped it before any test case began. A test that fails, hangs or crashes after tests
began is not infra.

A simulator service that died and came back is not infra either when xcodebuild still reported every test: in run
42533872440 a compare ran to its end (exit 65 for its changed pictures) with a recovered `(ipc/mig) server died` in
its log, was counted as infra and made again for nothing. Such a run ends in xcodebuild's test summary with no
`Testing failed:` section, which is where a run that lost tests to the simulator names the failure.

The startup watchdog asks `--started` whether a test has begun. The log alone is not enough: in run 42533872440 two
invocations had written 123 and 78 result lines but xcodebuild had printed no `Test case` line by 20 minutes, and the
watchdog stopped both. A test has begun when the log has a `Test case` line or the run's `results.jsonl` has grown
past the lines it had when the invocation started.

usage: snapshot_infra.py --status <exit status> <xcodebuild log>
           Prints the reason and exits 0 when the invocation is infra; exits 1 otherwise.
       snapshot_infra.py --started <xcodebuild log> <results.jsonl> [--baseline <lines>]
           Exits 0 when a test has begun, 1 otherwise.
"""

import argparse
from pathlib import Path
import re
import sys

# (reason, pattern), most specific first; each pattern is a fixed `xcodebuild` or CoreSimulator message.
SIGNATURES = (
    ('no-test-started', r'^watchdog: no test started'),
    ('clone-shutting-down', r'Unable to lookup in current state: Shutting Down'),
    ('boot-timeout', r'Timed out trying to boot simulator'),
    ('prepare-device', r'Failed to prepare device'),
    ('runner-connection', r'Lost pending connection to the test runner|operation never finished bootstrapping'
                          r'|Test runner never began executing tests'),
    ('simulator-service', r'\(ipc/mig\) server died'),
    ('runner-launch', r'Failed to install or launch the test runner'),
)


# Failures the simulator recovers from on its own; infra only when tests went unreported.
RECOVERABLE = {'simulator-service'}


def reported_every_test(text):
    """Whether xcodebuild ended in its test summary without naming a failure that cost tests."""
    summary = re.search(r'^\*\* TEST EXECUTE (FAILED|SUCCEEDED) \*\*', text, re.MULTILINE)
    return summary is not None and re.search(r'^Testing failed:', text, re.MULTILINE) is None


def classify(text, status):
    """The infra reason of an invocation's log and exit status, or `None`."""
    if status == 0:
        return None
    for reason, pattern in SIGNATURES:
        if re.search(pattern, text, re.MULTILINE):
            if reason in RECOVERABLE and reported_every_test(text):
                continue
            return reason
    return None


def started(text, results, baseline=0):
    """Whether a test has begun: a `Test case` line in the log, or result lines past `baseline`.

    A parallel destination prints `Test case '...' started on 'Clone N ...'`, a serial one `Test Case '-[...]' started.`
    """
    if re.search(r"Test [Cc]ase '", text):
        return True
    return sum(1 for line in results.splitlines() if line.strip()) > baseline


def read(path):
    return path.read_text(errors='replace') if path.exists() else ''


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--status', type=int)
    mode.add_argument('--started', action='store_true')
    parser.add_argument('log', type=Path)
    parser.add_argument('results', type=Path, nargs='?')
    parser.add_argument('--baseline', type=int, default=0)
    args = parser.parse_args(argv)
    if args.started:
        if args.results is None:
            parser.error('--started needs the results file')
        return 0 if started(read(args.log), read(args.results), args.baseline) else 1
    reason = classify(read(args.log), args.status)
    if reason is None:
        return 1
    print(reason)
    return 0


if __name__ == '__main__':
    sys.exit(main())
