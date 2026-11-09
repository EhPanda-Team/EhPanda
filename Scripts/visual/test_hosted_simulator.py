"""The hosted simulator steps (19-04), against a fake `xcrun simctl` so no real simulator or service is touched.

Run 42533872440 failed the setup in 7 of 8 jobs on limits too short for its runners and on writes that found the
device not booted right after `bootstatus`; its first `clear-clones` waited 10 minutes for a testing device set that
did not exist yet.
"""
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parent / 'hosted-simulator.sh'

# `xcrun simctl …` as the hosted runner answered it; state and the call log live in $FAKE_SIMCTL.
FAKE_XCRUN = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
state = Path(os.environ['FAKE_SIMCTL'])
args = sys.argv[1:]
with open(state / 'calls', 'a') as calls:
    calls.write(' '.join(args) + '\n')
assert args[0] == 'simctl'
args = args[1:]
if args[:2] == ['--set', 'testing']:
    clones = state / 'clones.json'
    if not clones.exists():
        print('Provided set path does not exist', file=sys.stderr)
        sys.exit(1)
    devices = json.loads(clones.read_text())
    if args[2] == 'list':
        print(json.dumps({'devices': {'iOS-27-0': devices}}))
    elif args[2] == 'delete':
        clones.write_text(json.dumps([d for d in devices if d['udid'] != args[3]]))
    sys.exit(0)
command = args[0]
if command == 'create':
    print('FAKE-UDID')
elif command == 'spawn':
    not_booted = state / 'not-booted'
    left = int(not_booted.read_text()) if not_booted.exists() else 0
    if left > 0:
        not_booted.write_text(str(left - 1))
        print('An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, '
              'code=405):\nProcess spawn via launchd failed because device is not booted.', file=sys.stderr)
        sys.exit(149)
    if args[2:4] == ['defaults', 'read']:
        print('1')
sys.exit(0)
'''
# The service restart of a failed attempt is recorded, never done.
FAKE_KILLALL = '#!/bin/sh\necho "killall $*" >> "$FAKE_SIMCTL/calls"\n'
# The script's own waits (the not-booted wait, the restart's 10 s, the clone poll's 5 s) pass at once; the limits'
# watchdogs (60 s and more) still sleep, so a command is never stopped early.
FAKE_SLEEP = '#!/bin/sh\n[ "$1" -le 15 ] 2>/dev/null && exit 0\nexec /bin/sleep "$@"\n'


class HostedSimulatorTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.state = Path(self.directory.name)
        bin_directory = self.state / 'bin'
        bin_directory.mkdir()
        for name, body in (('xcrun', FAKE_XCRUN), ('killall', FAKE_KILLALL), ('sleep', FAKE_SLEEP)):
            path = bin_directory / name
            path.write_text(body)
            path.chmod(path.stat().st_mode | stat.S_IEXEC)
        self.testing_set = self.state / 'XCTestDevices'
        self.env = dict(os.environ, PATH=f'{bin_directory}:{os.environ["PATH"]}', FAKE_SIMCTL=str(self.state),
                        HOSTED_SIMULATOR_TESTING_SET=str(self.testing_set))

    def tearDown(self):
        self.directory.cleanup()

    def run_script(self, *args):
        return subprocess.run(['bash', str(SCRIPT), *args], env=self.env, capture_output=True, text=True,
                              timeout=60)

    def calls(self):
        path = self.state / 'calls'
        return path.read_text().splitlines() if path.exists() else []

    def create(self, family='iphone'):
        return self.run_script('create', 'EhPanda measure', 'iPhone-Air', 'iOS-27-0', family)

    def test_create_sets_up_the_simulator_once(self):
        result = self.create()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'FAKE-UDID\n')
        self.assertEqual(sum(call.startswith('simctl create') for call in self.calls()), 1)

    def test_a_write_that_finds_the_device_not_booted_boots_it_again(self):
        (self.state / 'not-booted').write_text('2')
        result = self.create(family='ipad')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'FAKE-UDID\n')
        calls = self.calls()
        self.assertEqual(sum(call.startswith('simctl create') for call in calls), 1)
        self.assertEqual(calls.count('simctl bootstatus FAKE-UDID -b'), 2)
        self.assertNotIn('killall', ' '.join(calls))
        self.assertIn('was not booted', result.stderr)

    def test_a_device_that_stays_not_booted_fails_the_attempt(self):
        (self.state / 'not-booted').write_text('99')
        result = self.create()
        self.assertEqual(result.returncode, 1)
        calls = self.calls()
        # Three tries per write, then the attempt is deleted, the service restarted and the setup made once more.
        self.assertEqual(sum(call.startswith('simctl create') for call in calls), 2)
        self.assertEqual(sum(call.startswith('killall') for call in calls), 2)
        self.assertEqual(calls.count('simctl bootstatus FAKE-UDID -b'), 4)

    def test_the_limits_are_longer_than_the_ones_run_42533872440_overran(self):
        text = SCRIPT.read_text()
        limits = {name: int(value) for name, value in re.findall(r'^([A-Z_]+_LIMIT)=(\d+)$', text, re.MULTILINE)}
        self.assertGreater(limits['SETTING_LIMIT'], 60)
        self.assertGreater(limits['BOOTSTATUS_LIMIT'], 300)
        self.assertGreater(limits['SHUTDOWN_LIMIT'], 180)
        # Every simctl call of the setup goes through a named limit or the not-booted retry.
        self.assertNotRegex(text, r'limit [0-9]+ xcrun simctl (spawn|bootstatus|boot|create) ')

    def test_clear_clones_with_no_testing_set_is_done_at_once(self):
        started = time.monotonic()
        result = self.run_script('clear-clones', 'EhPanda measure')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(time.monotonic() - started, 10)
        self.assertEqual(self.calls(), [])

    def test_clear_clones_deletes_the_clones_of_the_name(self):
        self.testing_set.mkdir()
        (self.state / 'clones.json').write_text(json.dumps([
            {'udid': 'CLONE-1', 'name': 'Clone 1 of EhPanda measure', 'state': 'Shutdown'},
            {'udid': 'OTHER', 'name': 'Clone 1 of Something else', 'state': 'Shutdown'},
        ]))
        result = self.run_script('clear-clones', 'EhPanda measure')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('simctl --set testing delete CLONE-1', self.calls())
        left = json.loads((self.state / 'clones.json').read_text())
        self.assertEqual([device['udid'] for device in left], ['OTHER'])


if __name__ == '__main__':
    unittest.main()
