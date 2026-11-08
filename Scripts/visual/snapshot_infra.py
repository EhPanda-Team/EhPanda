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

usage: snapshot_infra.py --status <exit status> <xcodebuild log>
Prints the reason and exits 0 when the invocation is infra; exits 1 otherwise.
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


def classify(text, status):
    """The infra reason of an invocation's log and exit status, or `None`."""
    if status == 0:
        return None
    for reason, pattern in SIGNATURES:
        if re.search(pattern, text, re.MULTILINE):
            return reason
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--status', type=int, required=True)
    parser.add_argument('log', type=Path)
    args = parser.parse_args(argv)
    text = args.log.read_text(errors='replace') if args.log.exists() else ''
    reason = classify(text, args.status)
    if reason is None:
        return 1
    print(reason)
    return 0


if __name__ == '__main__':
    sys.exit(main())
