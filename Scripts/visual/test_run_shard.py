"""One shard of the snapshot gate (19-10), against fake `xcodebuild`, `xcrun` and simulator steps, so no simulator,
network or real test run is touched: the pins, the proof's faults, the in-job re-run of unfinished classes, the iPad
turns and the shard record (19-CONTEXT D-15; 19-RESEARCH §5)."""
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

import snapshot_matrix
from test_snapshot_shard import INVENTORY, PLAN, SOURCE

SCRIPT = Path(__file__).resolve().parent / 'run-shard.sh'

# `xcodebuild -version` and `xcodebuild test-without-building`: a snapshot run writes one result line per coordinate
# of its classes, configurations and orientations, as the real writer does, and can crash once after N lines.
FAKE_XCODEBUILD = r'''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
fake = Path(os.environ['FAKE'])
args = sys.argv[1:]
if args == ['-version']:
    print(os.environ['FAKE_XCODE'])
    sys.exit(0)
assert args[0] == 'test-without-building', args
xctestrun = args[args.index('-xctestrun') + 1]
with open(fake / 'calls', 'a') as calls:
    calls.write(json.dumps({'kind': 'ui' if 'UITests' in xctestrun else 'snapshot', 'args': args,
                            'orientations': os.environ.get('TEST_RUNNER_EHPANDA_SNAPSHOT_ORIENTATIONS'),
                            'mode': os.environ.get('TEST_RUNNER_EHPANDA_SNAPSHOT_MODE'),
                            'references': os.environ.get('TEST_RUNNER_EHPANDA_SNAPSHOT_REFERENCES')}) + '\n')
if 'UITests' in xctestrun:
    print("Test case 'VisualCaptureOrientationUITests.turn()' passed")
    sys.exit(0)
only = [arg.split('/', 1)[1] for arg in args if arg.startswith('-only-testing:')]
configurations = [args[index + 1] for index, arg in enumerate(args) if arg == '-only-test-configuration']
output = Path(os.environ['TEST_RUNNER_EHPANDA_SNAPSHOT_OUTPUT'])
orientations = (os.environ.get('TEST_RUNNER_EHPANDA_SNAPSHOT_ORIENTATIONS') or 'portrait,landscape').split(',')
classes = json.loads((fake / 'classes.json').read_text())
family = (fake / 'family').read_text().strip()
crash = fake / 'crash-after'
left = int(crash.read_text()) if crash.exists() else -1
delay = float(os.environ.get('FAKE_CLASS_SECONDS', '0'))
output.mkdir(parents=True, exist_ok=True)
for configuration in configurations:
    locale, size = configuration.rsplit('-', 1)
    for name in only:
        time.sleep(delay)
        print(f"Test case '{name}.test()' started")
        for scenario in classes[name]:
            for orientation in orientations:
                for theme in ('light', 'dark'):
                    if left == 0:
                        crash.unlink()
                        print('Restarting after unexpected exit, crash, or test timeout')
                        sys.exit(65)
                    left -= 1
                    key = '__'.join((scenario, locale, size, orientation, family, theme))
                    with open(output / 'results.jsonl', 'a') as lines:
                        lines.write(json.dumps({'key': key, 'status': 'recorded'}) + '\n')
                    picture = output / family / locale / size / scenario / f'{orientation}-{theme}.png'
                    picture.parent.mkdir(parents=True, exist_ok=True)
                    picture.write_bytes(b'png')
print('** TEST EXECUTE SUCCEEDED **')
'''
FAKE_XCRUN = r'''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
env = json.loads(open(os.environ['FAKE_ENVIRONMENT']).read())
if args == ['simctl', 'list', 'runtimes', '-j']:
    runtime = env['runtime']
    print(json.dumps({'runtimes': [{'identifier': runtime['identifier'], 'buildversion': runtime['buildVersion'],
                                    'version': runtime['version'], 'isAvailable': True}]}))
elif args == ['simctl', 'list', 'devicetypes', '-j']:
    print(json.dumps({'devicetypes': [{'identifier': device['deviceTypeIdentifier']}
                                      for device in env['devices'].values()]}))
else:
    sys.exit(f'unexpected xcrun {args}')
'''
FAKE_SIMULATOR = '''#!/bin/sh
echo "$*" >> "$FAKE/simulator"
printf '{"kind": "simulator", "args": "%s"}\\n' "$*" >> "$FAKE/calls"
[ "$1" = create ] && echo FAKE-UDID
exit 0
'''


class RunShardTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.fake = self.root / 'fake'
        (self.root / 'bin').mkdir()
        self.fake.mkdir()
        for name, body in (('xcodebuild', FAKE_XCODEBUILD), ('xcrun', FAKE_XCRUN)):
            self.executable(self.root / 'bin' / name, body)
        self.executable(self.root / 'simulator.sh', FAKE_SIMULATOR)
        sources = self.root / 'sources/Matrix'
        sources.mkdir(parents=True)
        (sources / 'HomeSnapshotTests.swift').write_text(SOURCE)
        (self.root / 'scenarios.json').write_text(json.dumps(INVENTORY))
        (self.root / 'shards.json').write_text(json.dumps(PLAN))
        (self.fake / 'classes.json').write_text(json.dumps({
            'HomeSnapshotTests': ['home-populated', 'home-loading'], 'ShellSnapshotTests': ['library-sidebar'],
            'TracerSnapshotTests': ['home-populated']}))
        products = self.root / 'products/Products'
        products.mkdir(parents=True)
        (products / 'EhPanda_SnapshotMatrix_iphonesimulator27.0-arm64.xctestrun').write_text('')
        (products / 'EhPanda_UITests_iphonesimulator27.0-arm64.xctestrun').write_text('')
        _, self.env = snapshot_matrix.load()
        self.out = self.root / 'out'

    def tearDown(self):
        self.directory.cleanup()

    @staticmethod
    def executable(path, body):
        path.write_text(body)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def run_shard(self, shard, mode='candidate', attempt='1', **variables):
        family = next(entry['family'] for entry in PLAN['shards'] if entry['id'] == shard)
        (self.fake / 'family').write_text(family)
        environment = {
            **os.environ, 'PATH': f"{self.root / 'bin'}:{os.environ['PATH']}", 'CI': '1', 'FAKE': str(self.fake),
            'FAKE_ENVIRONMENT': str(snapshot_matrix.ENVIRONMENT), 'FAKE_XCODE': self.env['toolchain']['xcode'],
            'EHPANDA_SHARD_PLAN': str(self.root / 'shards.json'),
            'EHPANDA_SNAPSHOT_INVENTORY': str(self.root / 'scenarios.json'),
            'EHPANDA_SNAPSHOT_SOURCES': str(self.root / 'sources'),
            'EHPANDA_HOSTED_SIMULATOR': str(self.root / 'simulator.sh'),
            'EHPANDA_SNAPSHOT_FAULT': '', **variables}
        return subprocess.run(
            ['bash', str(SCRIPT), '--shard', shard, '--mode', mode, '--products', str(self.root / 'products'),
             '--out', str(self.out), '--attempt', attempt, '--fingerprints', str(self.root / 'fingerprints.json')],
            env=environment, capture_output=True, text=True, timeout=120)

    def calls(self, kind=None):
        path = self.fake / 'calls'
        rows = [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
        return [row for row in rows if kind is None or row['kind'] == kind]

    def record(self):
        return json.loads((self.out / 'shard.json').read_text())

    def keys(self):
        return [json.loads(line)['key'] for line in (self.out / 'results.jsonl').read_text().splitlines()]

    def expected(self, shard_id):
        shard = next(entry for entry in PLAN['shards'] if entry['id'] == shard_id)
        runs = {(run['configuration'], orientation) for run in shard['runs'] for orientation in run['orientations']}
        return sorted(row.key for row, _ in snapshot_matrix.coordinates(INVENTORY, self.env)
                      if row.family == shard['family'] and (row.configuration, row.orientation) in runs)

    @staticmethod
    def values(args, flag):
        return [args[index + 1] for index, arg in enumerate(args) if arg == flag]

    def test_an_iphone_shard_runs_its_configurations_in_one_invocation_and_records_no_error(self):
        result = self.run_shard('s01')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.record()
        self.assertIsNone(record['infra'], record)
        self.assertEqual(record['rerunClasses'], [])
        self.assertEqual(sorted(self.keys()), self.expected('s01'))
        [call] = self.calls('snapshot')
        args = call['args']
        self.assertEqual(self.values(args, '-only-test-configuration'), ['de-accessibility5', 'zh-Hans-large'])
        self.assertEqual(self.values(args, '-parallel-testing-worker-count'), ['2'])
        self.assertEqual([arg for arg in args if arg.startswith('-only-testing:')],
                         ['-only-testing:VisualSnapshotTests/HomeSnapshotTests',
                          '-only-testing:VisualSnapshotTests/ShellSnapshotTests'])
        self.assertNotIn('-resultBundlePath', args)
        self.assertIsNone(call['orientations'])
        self.assertEqual(call['mode'], 'candidate')
        simulator = (self.fake / 'simulator').read_text().splitlines()
        self.assertEqual(simulator[0], 'create EhPanda gate ' + self.env['devices']['iphone']['deviceTypeIdentifier']
                         + ' ' + self.env['runtime']['identifier'] + ' iphone')
        self.assertIn('clear-clones EhPanda gate', simulator)

    def test_a_crash_reruns_only_the_unfinished_classes_and_the_ipad_turns_for_each_orientation(self):
        # 19-10, checked on iOS 27.2: parallel-testing clones boot in portrait whatever the turned device shows, and the
        # turn's UI test run leaves the app accessibility runtime off. So every turn is followed by the settings again,
        # and a landscape invocation runs on the turned device itself, without clones.
        # ko-large portrait: HomeSnapshotTests writes 4 lines, then the run crashes before ShellSnapshotTests.
        (self.fake / 'crash-after').write_text('4')
        result = self.run_shard('s09')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.record()
        self.assertIsNone(record['infra'], record)
        self.assertEqual(record['rerunClasses'], ['ShellSnapshotTests'])
        keys = self.keys()
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(sorted(keys), self.expected('s09'))
        steps = []
        for row in self.calls():
            if row['kind'] == 'simulator':
                if row['args'].startswith('settings'):
                    steps.append(('simulator', row['args'], []))
                continue
            steps.append((row['kind'], row['orientations'] if row['kind'] == 'snapshot'
                          else [arg for arg in row['args'] if arg.startswith('-only-testing:')][0].rsplit('/', 1)[1],
                          [arg.split('/')[1] for arg in row['args']
                           if arg.startswith('-only-testing:VisualSnapshotTests/')]))
        self.assertEqual(steps, [
            ('snapshot', 'portrait', ['HomeSnapshotTests', 'ShellSnapshotTests']),
            ('ui', 'testRotateToLandscape', []),
            ('simulator', 'settings FAKE-UDID', []),
            ('snapshot', 'landscape', ['HomeSnapshotTests', 'ShellSnapshotTests']),
            ('ui', 'testRotateToPortrait', []),
            ('simulator', 'settings FAKE-UDID', []),
            ('snapshot', 'portrait', ['ShellSnapshotTests']),
        ])
        turn = self.calls('ui')[0]['args']
        self.assertEqual(self.values(turn, '-parallel-testing-enabled'), ['NO'])
        parallel = [(row['orientations'], self.values(row['args'], '-parallel-testing-enabled'),
                     self.values(row['args'], '-parallel-testing-worker-count')) for row in self.calls('snapshot')]
        self.assertEqual(parallel, [('portrait', ['YES'], ['2']), ('landscape', ['NO'], []),
                                    ('portrait', ['YES'], ['2'])])

    def test_the_crash_fault_crashes_both_runs_of_the_first_attempt_only(self):
        variables = {'EHPANDA_SNAPSHOT_FAULT': 's01=crash,s09=no-artifact', 'EHPANDA_SNAPSHOT_FAULT_SECONDS': '1',
                     'FAKE_CLASS_SECONDS': '4'}
        result = self.run_shard('s01', **variables)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.record()
        self.assertEqual(record['infra'], 'crash', record)
        self.assertIn('HomeSnapshotTests', record['detail'])
        self.assertEqual(len(self.calls('snapshot')), 2)
        self.assertIn('fault', (self.out / 'logs').joinpath('xcodebuild-1-1.log').read_text())
        (self.fake / 'calls').unlink()
        result = self.run_shard('s01', attempt='2', **{**variables, 'FAKE_CLASS_SECONDS': '0'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNone(self.record()['infra'])
        self.assertEqual(self.record()['attempt'], 2)

    def test_the_no_artifact_fault_leaves_nothing_to_upload(self):
        result = self.run_shard('s09', EHPANDA_SNAPSHOT_FAULT='s09=no-artifact')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.out.exists())
        self.assertEqual(self.calls(), [])

    def test_drift_records_the_class_and_captures_nothing(self):
        result = self.run_shard('s01', FAKE_XCODE='Xcode 27.2\nBuild version 27B52')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.record()
        self.assertEqual(record['infra'], 'drift')
        self.assertIn('27B52', record['detail'])
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.fake / 'simulator').exists())

    def test_compare_without_fingerprints_fails_as_no_approved_baseline_yet(self):
        result = self.run_shard('s01', mode='compare')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.record()
        self.assertEqual(record['infra'], 'baseline-mismatch')
        self.assertEqual(record['detail'], 'no approved baseline yet')
        self.assertEqual(self.calls(), [])

    def test_a_run_past_the_budget_is_stopped_rerun_once_and_recorded_as_a_timeout(self):
        result = self.run_shard('s01', EHPANDA_SHARD_BUDGET_SECONDS='12', FAKE_CLASS_SECONDS='20')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.record()
        self.assertEqual(record['infra'], 'timeout', record)
        self.assertEqual(len(self.calls('snapshot')), 2)
        self.assertIn('watchdog', (self.out / 'logs').joinpath('xcodebuild-1-1.log').read_text())


if __name__ == '__main__':
    unittest.main()
