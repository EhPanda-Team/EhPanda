"""The run-to-run comparison's pairs, report and compare commands (19-27) on synthetic sets and runs."""
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import snapshot_fetch  # noqa: E402
import snapshot_variation  # noqa: E402

LIST = 'front-page-list__en__large__portrait__iphone__light'
DARK = 'front-page-list__en__large__portrait__iphone__dark'
GRID = 'front-page-grid__de__xSmall__landscape__ipad__dark'
ALERT = 'app-wide-app-alert__ja__accessibility5__portrait__iphone__light'


def digest(data):
    return hashlib.sha256(data).hexdigest()


class VariationCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def make_set(self, name, pictures):
        """An assembled set: `fingerprints.json` and `pictures/` at the baseline paths."""
        directory = self.root / name
        for key, data in pictures.items():
            path = directory / 'pictures' / snapshot_fetch.key_path(key)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        directory.mkdir(parents=True, exist_ok=True)
        fingerprints = {key: digest(data) for key, data in pictures.items()}
        (directory / 'fingerprints.json').write_text(json.dumps({'count': len(pictures), 'pictures': fingerprints}))
        return directory

    def make_run(self, directory, pictures, extra=None):
        """A local run's output (or one artifact): `results.jsonl` and the pictures at the baseline paths."""
        lines = []
        for key, data in pictures.items():
            path = directory / snapshot_fetch.key_path(key)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            line = {'key': key, 'status': 'recorded', 'sha256': digest(data), 'attempts': 1, 'flaky': False}
            line.update((extra or {}).get(key, {}))
            lines.append(json.dumps(line))
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'results.jsonl').write_text('\n'.join(lines) + '\n')
        return directory

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = snapshot_variation.main([str(arg) for arg in args])
        return status, out.getvalue(), err.getvalue()


class PairsTests(VariationCase):
    def test_lists_only_the_keys_whose_digests_differ_with_both_paths(self):
        a = self.make_set('a', {LIST: b'1', DARK: b'2', GRID: b'3'})
        b = self.make_set('b', {LIST: b'1', DARK: b'x', GRID: b'y'})
        status, _, _ = self.run_main('pairs', '--a', a, '--b', b, '--out', self.root / 'out/pairs.jsonl')
        self.assertEqual(status, 0)
        lines = [json.loads(text) for text in (self.root / 'out/pairs.jsonl').read_text().splitlines()]
        self.assertEqual([line['key'] for line in lines], sorted([DARK, GRID]))
        dark = next(line for line in lines if line['key'] == DARK)
        self.assertEqual(Path(dark['a']), (a / 'pictures' / snapshot_fetch.key_path(DARK)).resolve())
        self.assertEqual(Path(dark['b']), (b / 'pictures' / snapshot_fetch.key_path(DARK)).resolve())
        self.assertEqual(json.loads((self.root / 'out/missing.json').read_text()), {'a': [], 'b': []})

    def test_paths_are_absolute_when_the_sides_are_named_relatively(self):
        self.make_set('a', {DARK: b'2'})
        self.make_set('b', {DARK: b'x'})
        previous = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, previous)
        status, _, _ = self.run_main('pairs', '--a', 'a', '--b', 'b', '--out', 'out/pairs.jsonl')
        self.assertEqual(status, 0)
        [line] = [json.loads(text) for text in (self.root / 'out/pairs.jsonl').read_text().splitlines()]
        self.assertEqual(Path(line['a']), (self.root / 'a/pictures' / snapshot_fetch.key_path(DARK)).resolve())
        self.assertEqual(Path(line['b']), (self.root / 'b/pictures' / snapshot_fetch.key_path(DARK)).resolve())

    def test_reads_a_local_run_as_a_side(self):
        a = self.make_set('a', {LIST: b'1', DARK: b'2'})
        run = self.make_run(self.root / 'run', {LIST: b'1', DARK: b'z'})
        status, _, _ = self.run_main('pairs', '--a', a, '--b', run, '--out', self.root / 'out/pairs.jsonl')
        self.assertEqual(status, 0)
        [line] = [json.loads(text) for text in (self.root / 'out/pairs.jsonl').read_text().splitlines()]
        self.assertEqual(line['key'], DARK)
        self.assertEqual(Path(line['b']), (run / snapshot_fetch.key_path(DARK)).resolve())

    def test_keys_on_one_side_only_are_listed_and_fail(self):
        a = self.make_set('a', {LIST: b'1', DARK: b'2'})
        b = self.make_set('b', {LIST: b'1', GRID: b'3'})
        status, _, err = self.run_main('pairs', '--a', a, '--b', b, '--out', self.root / 'out/pairs.jsonl')
        self.assertEqual(status, 1)
        self.assertIn(f'{DARK}: only in a', err)
        self.assertIn(f'{GRID}: only in b', err)
        self.assertEqual(json.loads((self.root / 'out/missing.json').read_text()), {'a': [DARK], 'b': [GRID]})

    def test_scenarios_limit_the_keys(self):
        a = self.make_set('a', {LIST: b'1', GRID: b'3'})
        b = self.make_set('b', {LIST: b'x', ALERT: b'4'})
        status, _, _ = self.run_main('pairs', '--a', a, '--b', b, '--scenarios', 'front-page-list',
                                     '--out', self.root / 'out/pairs.jsonl')
        self.assertEqual(status, 0)
        keys = [json.loads(text)['key'] for text in (self.root / 'out/pairs.jsonl').read_text().splitlines()]
        self.assertEqual(keys, [LIST])

    def test_a_directory_that_is_neither_side_fails(self):
        (self.root / 'empty').mkdir()
        a = self.make_set('a', {LIST: b'1'})
        status, _, err = self.run_main('pairs', '--a', a, '--b', self.root / 'empty',
                                       '--out', self.root / 'out/pairs.jsonl')
        self.assertEqual(status, 1)
        self.assertIn('neither an assembled set', err)


class ReportTests(VariationCase):
    def write_lines(self, name, lines):
        path = self.root / name
        path.write_text(''.join(json.dumps(line) + '\n' for line in lines))
        return path

    def setUp(self):
        super().setUp()
        keys = [LIST, DARK, GRID, ALERT, 'front-page-list__de__large__landscape__iphone__dark']
        self.keys = keys
        same = {'search-root-empty__en__large__portrait__ipad__light': b's'}
        self.a = self.make_set('a', {key: b'a' for key in keys} | same)
        self.b = self.make_set('b', {key: b'b' for key in keys} | same)
        self.pairs = self.write_lines('pairs.jsonl', [{'key': key, 'a': '', 'b': ''} for key in keys])
        classes = ['beyond-tolerance', 'within-tolerance', 'identical-pixels', 'size-differs', 'beyond-tolerance']
        self.outcomes = self.write_lines('outcomes.jsonl',
                                         [{'key': key, 'outcome': outcome} for key, outcome in zip(keys, classes)])

    def test_counts_every_class_and_groups_beyond_by_scenario(self):
        status, _, _ = self.run_main('report', '--a', self.a, '--b', self.b, '--pairs', self.pairs,
                                     '--outcomes', self.outcomes, '--out', self.root / 'report.json')
        self.assertEqual(status, 0)
        document = json.loads((self.root / 'report.json').read_text())
        self.assertEqual(document['counts'], {'identical-digest': 1, 'identical-pixels': 1, 'within-tolerance': 1,
                                              'beyond-tolerance': 2, 'size-differs': 1, 'unreadable': 0})
        self.assertEqual(list(document['beyond']), ['front-page-list'])
        entry = document['beyond']['front-page-list']
        self.assertEqual(entry['count'], 2)
        self.assertEqual(entry['families'], {'iphone': 2})
        self.assertEqual(entry['orientations'], {'portrait': 1, 'landscape': 1})
        self.assertEqual(entry['themes'], {'light': 1, 'dark': 1})
        self.assertEqual(entry['locales'], {'en': 1, 'de': 1})
        self.assertEqual(entry['sizes'], {'large': 2})
        self.assertEqual(document['flaky'], {'a': [], 'b': []})

    def test_lists_the_flaky_keys_of_the_chosen_attempt(self):
        artifacts = self.root / 'artifacts-b'
        self.make_run(artifacts / 'pictures-shard-s01', {LIST: b'b', DARK: b'b'}, {LIST: {'flaky': True}})
        # A later attempt re-recorded DARK after two attempts: the chosen line is that one.
        self.make_run(artifacts / 'pictures-retry-s01', {DARK: b'b'}, {DARK: {'attempts': 2}})
        status, _, _ = self.run_main('report', '--a', self.a, '--b', self.b, '--pairs', self.pairs,
                                     '--outcomes', self.outcomes, '--artifacts-b', artifacts,
                                     '--out', self.root / 'report.json')
        self.assertEqual(status, 0)
        self.assertEqual(json.loads((self.root / 'report.json').read_text())['flaky'],
                         {'a': [], 'b': sorted([LIST, DARK])})

    def test_a_pair_without_an_outcome_fails(self):
        outcomes = self.write_lines('short.jsonl', [{'key': LIST, 'outcome': 'within-tolerance'}])
        status, _, err = self.run_main('report', '--a', self.a, '--b', self.b, '--pairs', self.pairs,
                                       '--outcomes', outcomes, '--out', self.root / 'report.json')
        self.assertEqual(status, 1)
        self.assertIn(f'{DARK}: no outcome line', err)


UDID = '33333333-3333-3333-3333-333333333333'
STUB_XCODEBUILD = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
Path(os.environ['STUB_ARGUMENTS']).write_text(json.dumps({'argv': sys.argv[1:], 'pairs': os.environ.get(
    'TEST_RUNNER_EHPANDA_VARIATION_PAIRS'), 'output': os.environ.get('TEST_RUNNER_EHPANDA_VARIATION_OUTPUT')}))
pairs = [json.loads(l) for l in Path(os.environ['TEST_RUNNER_EHPANDA_VARIATION_PAIRS']).read_text().splitlines()]
keep = int(os.environ.get('STUB_KEEP', len(pairs)))
lines = ''.join(json.dumps({'key': p['key'], 'outcome': 'within-tolerance'}) + '\\n' for p in pairs[:keep])
Path(os.environ['TEST_RUNNER_EHPANDA_VARIATION_OUTPUT'], 'outcomes.jsonl').write_text(lines)
'''


class CompareTests(VariationCase):
    """`compare` runs with stub `xcrun`, `pgrep` and `xcodebuild` first on `PATH`: nothing touches a simulator."""

    def setUp(self):
        super().setUp()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        devices = {'devices': {'runtime': [
            {'name': 'EhPanda iPhone Air (phase19)', 'udid': UDID, 'isAvailable': True},
            {'name': 'EhPanda iPhone Air (other)', 'udid': '11111111-1111-1111-1111-111111111111', 'isAvailable': True},
        ]}}
        (self.root / 'devices.json').write_text(json.dumps(devices))
        self.stub('xcrun', f'#!/bin/bash\ncat "{self.root / "devices.json"}"\n')
        self.stub('pgrep', '#!/bin/bash\nexit 1\n')
        self.stub('xcodebuild', STUB_XCODEBUILD)
        self.arguments = self.root / 'arguments.json'
        self.pairs = self.root / 'pairs.jsonl'
        self.pairs.write_text(''.join(json.dumps({'key': key, 'a': 'a.png', 'b': 'b.png'}) + '\n'
                                      for key in (LIST, DARK)))

    def stub(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o755)

    def compare(self, *extra, keep=None):
        environment = {'PATH': f'{self.bin}:{os.environ["PATH"]}', 'STUB_ARGUMENTS': str(self.arguments)}
        if keep is not None:
            environment['STUB_KEEP'] = str(keep)
        with mock.patch.dict(os.environ, environment):
            return self.run_main('compare', '--pairs', self.pairs, '--out', self.root / 'out', *extra)

    def test_runs_the_comparison_on_the_exactly_named_simulator(self):
        stale = self.root / 'out/compare.xcresult'
        stale.mkdir(parents=True)
        (stale / 'old').write_text('old')
        status, out, _ = self.compare('--simulator', 'EhPanda iPhone Air (phase19)')
        self.assertEqual(status, 0)
        self.assertIn('2 pairs compared', out)
        recorded = json.loads(self.arguments.read_text())
        self.assertIn(f'platform=iOS Simulator,id={UDID}', recorded['argv'])
        self.assertIn('-only-testing:VisualSnapshotTests/VariationComparisonTests', recorded['argv'])
        self.assertEqual(recorded['argv'][recorded['argv'].index('-testPlan') + 1], 'FeatureTests')
        self.assertIn('-collect-test-diagnostics', recorded['argv'])
        self.assertEqual(recorded['pairs'], str(self.pairs.resolve()))
        self.assertEqual(recorded['output'], str((self.root / 'out').resolve()))
        self.assertFalse((stale / 'old').exists())

    def test_a_prefix_names_no_simulator(self):
        status, _, err = self.compare('--simulator', 'EhPanda iPhone Air')
        self.assertEqual(status, 1)
        self.assertIn('No simulators named EhPanda iPhone Air.', err)

    def test_a_missing_outcome_fails(self):
        status, _, err = self.compare('--simulator', 'EhPanda iPhone Air (phase19)', keep=1)
        self.assertEqual(status, 1)
        self.assertIn('1 outcome lines for 2 pairs', err)


if __name__ == '__main__':
    unittest.main()
