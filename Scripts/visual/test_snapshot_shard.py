"""The shard runner's helpers (19-10): the shard's plan, its classes, which classes still lack results, the pins and
the proof's fault switch (19-CONTEXT D-15; 19-RESEARCH §4, §5)."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

import snapshot_matrix
import snapshot_shard

INVENTORY = {'schema': 2, 'scenarios': [
    {'id': 'home-populated', 'group': 'home', 'plan': '19-05', 'state': 'Populated', 'signedIn': True,
     'notApplicable': []},
    {'id': 'home-loading', 'group': 'home', 'plan': '19-05', 'state': 'Loading', 'signedIn': True,
     'notApplicable': []},
    {'id': 'library-sidebar', 'group': 'library', 'plan': '19-06', 'state': 'Sidebar', 'signedIn': True,
     'notApplicable': [{'when': {'widthClass': 'compact'}, 'reason': 'Needs a regular width.'}]},
]}
SOURCE = '''import XCTest

final class HomeSnapshotTests: SnapshotMatrixCase {
    @MainActor func testPopulated() async throws { try await capture(scenario: "home-populated") }
    @MainActor func testLoading() async throws {
        try await capture(scenario: "home-loading")
    }
}

final class ShellSnapshotTests: SnapshotMatrixCase {
    @MainActor func testSidebar() async throws { try await capture(scenario: "library-sidebar") }
}

final class TracerSnapshotTests: SnapshotMatrixCase {
    @MainActor func testTracer() async throws { try await capture(scenario: "home-populated") }
}

final class HostedWindowCaptureTests: XCTestCase {
    func testWindow() {}
}
'''
PLAN = {'schema': 1, 'workers': 2, 'shards': [
    {'id': 's01', 'family': 'iphone', 'configurations': ['de-accessibility5', 'zh-Hans-large'],
     'runs': [{'configuration': 'de-accessibility5', 'orientations': ['portrait', 'landscape']},
              {'configuration': 'zh-Hans-large', 'orientations': ['portrait', 'landscape']}],
     'invocations': [{'configurations': ['de-accessibility5', 'zh-Hans-large'],
                      'orientations': ['portrait', 'landscape']}],
     'estimatedMinutes': 47.6, 'timeoutMinutes': 96},
    {'id': 's09', 'family': 'ipad', 'configurations': ['ko-large', 'de-accessibility5'],
     'runs': [{'configuration': 'ko-large', 'orientations': ['portrait', 'landscape']},
              {'configuration': 'de-accessibility5', 'orientations': ['landscape']}],
     'invocations': [{'configurations': ['ko-large'], 'orientations': ['portrait']},
                     {'configurations': ['de-accessibility5', 'ko-large'], 'orientations': ['landscape']}],
     'estimatedMinutes': 60.5, 'timeoutMinutes': 120},
]}


class ShardTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / 'Matrix').mkdir()
        (self.root / 'Matrix/HomeSnapshotTests.swift').write_text(SOURCE)
        _, self.env = snapshot_matrix.load()
        self.document = INVENTORY
        (self.root / 'scenarios.json').write_text(json.dumps(INVENTORY))
        (self.root / 'shards.json').write_text(json.dumps(PLAN))
        self.results = self.root / 'results.jsonl'

    def tearDown(self):
        self.directory.cleanup()

    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            status = snapshot_shard.main([*args, '--shards', str(self.root / 'shards.json'),
                                          '--inventory', str(self.root / 'scenarios.json')])
        return status, out.getvalue()

    def keys(self, family, configurations, orientations, scenarios):
        return [row.key for row, _ in snapshot_matrix.coordinates(self.document, self.env)
                if row.family == family and row.configuration in configurations
                and row.orientation in orientations and row.scenario in scenarios]

    def write(self, keys):
        with self.results.open('a') as lines:
            for key in keys:
                lines.write(json.dumps({'key': key, 'status': 'recorded'}) + '\n')

    def test_classes_are_the_matrix_cases_without_the_tracers(self):
        classes = snapshot_shard.classes(self.root)
        self.assertEqual(list(classes), ['HomeSnapshotTests', 'ShellSnapshotTests'])
        self.assertEqual(classes['HomeSnapshotTests'], ['home-populated', 'home-loading'])

    def test_the_real_matrix_classes_cover_the_whole_inventory(self):
        classes = snapshot_shard.classes()
        document, _ = snapshot_matrix.load()
        covered = [scenario for scenarios in classes.values() for scenario in scenarios]
        inventory = {scenario['id'] for scenario in document['scenarios']}
        # Every scenario once, the three Login ones included since their backdrop stands still under Reduce Motion
        # (19-10): a scenario without a method would leave its coordinates without results and fail its shard.
        self.assertEqual(sorted(covered), sorted(inventory))
        self.assertFalse([name for name in classes if name.startswith('Tracer')])

    def test_slices_name_each_configuration_of_the_shard_once(self):
        self.assertEqual(snapshot_shard.slices(PLAN['shards'][0]), ['iphone/de/accessibility5', 'iphone/zh-Hans/large'])
        self.assertEqual(snapshot_shard.slices(PLAN['shards'][1]), ['ipad/ko/large', 'ipad/de/accessibility5'])

    def test_invocations_print_configurations_and_orientations(self):
        status, output = self.run_main('invocations', '--shard', 's09')
        self.assertEqual(status, 0)
        self.assertEqual(output.splitlines(), ['ko-large portrait', 'de-accessibility5,ko-large landscape'])

    def test_every_class_is_pending_before_any_result(self):
        pending = snapshot_shard.pending(PLAN['shards'][0], 0, self.results, snapshot_shard.classes(self.root),
                                         self.document, self.env)
        self.assertEqual(pending, ['HomeSnapshotTests', 'ShellSnapshotTests'])

    def test_a_class_with_every_result_of_the_invocation_is_done(self):
        shard = PLAN['shards'][1]
        self.write(self.keys('ipad', ['ko-large'], ['portrait'], ['home-populated', 'home-loading']))
        # A partly finished class stays pending.
        self.write(self.keys('ipad', ['ko-large'], ['portrait'], ['library-sidebar'])[:1])
        classes = snapshot_shard.classes(self.root)
        self.assertEqual(snapshot_shard.pending(shard, 0, self.results, classes, self.document, self.env),
                         ['ShellSnapshotTests'])
        # The landscape invocation has none of its results yet.
        self.assertEqual(snapshot_shard.pending(shard, 1, self.results, classes, self.document, self.env),
                         ['HomeSnapshotTests', 'ShellSnapshotTests'])

    def test_not_applicable_coordinates_need_no_line(self):
        shard = PLAN['shards'][0]
        keys = [row.key for row, reason in snapshot_matrix.coordinates(self.document, self.env)
                if reason is None and row.family == 'iphone'
                and row.configuration in ('de-accessibility5', 'zh-Hans-large')]
        self.write(keys)
        self.assertEqual(snapshot_shard.pending(shard, 0, self.results, snapshot_shard.classes(self.root),
                                                self.document, self.env), [])

    def test_prune_drops_the_pending_classes_lines_of_that_invocation_only(self):
        shard = PLAN['shards'][1]
        done = self.keys('ipad', ['ko-large'], ['portrait'], ['home-populated', 'home-loading'])
        partial = self.keys('ipad', ['ko-large'], ['portrait'], ['library-sidebar'])[:1]
        other = self.keys('ipad', ['ko-large'], ['landscape'], ['library-sidebar'])
        self.write(done + partial + other)
        status, output = self.run_main('pending', '--shard', 's09', '--invocation', '0', '--results',
                                       str(self.results), '--sources', str(self.root), '--prune')
        self.assertEqual(status, 0)
        self.assertEqual(output.split(), ['ShellSnapshotTests'])
        kept = [json.loads(line)['key'] for line in self.results.read_text().splitlines()]
        self.assertEqual(kept, done + other)

    def test_prune_keeps_the_configurations_a_pending_class_finished(self):
        # Run 42577585956: a class re-run after a crash lost its lines in every configuration of the invocation; the
        # re-run skips a scenario already captured in a configuration (EHPANDA_SNAPSHOT_KEEP_CAPTURED), so they stay.
        finished = self.keys('iphone', ['de-accessibility5'], ['portrait', 'landscape'],
                             ['home-populated', 'home-loading'])
        partial = self.keys('iphone', ['zh-Hans-large'], ['portrait', 'landscape'], ['home-populated'])
        loading = self.keys('iphone', ['zh-Hans-large'], ['portrait', 'landscape'], ['home-loading'])[:2]
        self.write(finished + partial + loading)
        status, output = self.run_main('pending', '--shard', 's01', '--invocation', '0', '--results',
                                       str(self.results), '--sources', str(self.root), '--prune')
        self.assertEqual(status, 0)
        self.assertEqual(output.split(), ['HomeSnapshotTests', 'ShellSnapshotTests'])
        kept = [json.loads(line)['key'] for line in self.results.read_text().splitlines()]
        self.assertEqual(kept, finished + partial)

    def test_pins_match_or_name_each_drift(self):
        xcode = self.env['toolchain']['xcode']
        runtime = self.env['runtime']
        runtimes = {'runtimes': [{'identifier': runtime['identifier'], 'buildversion': runtime['buildVersion'],
                                  'version': runtime['version'], 'isAvailable': True}]}
        devicetypes = {'devicetypes': [{'identifier': self.env['devices']['ipad']['deviceTypeIdentifier']}]}
        self.assertEqual(snapshot_shard.drift(self.env, 'ipad', xcode + '\n', runtimes, devicetypes), [])
        problems = snapshot_shard.drift(self.env, 'ipad', 'Xcode 27.2\nBuild version 27B52',
                                        {'runtimes': [{**runtimes['runtimes'][0], 'buildversion': '24B8117'}]},
                                        {'devicetypes': []})
        self.assertEqual(len(problems), 3)
        self.assertIn('27B52', problems[0])
        self.assertIn('24B8117', problems[1])
        self.assertIn(self.env['devices']['ipad']['deviceTypeIdentifier'], problems[2])

    def test_the_fault_switch_names_one_shard_and_the_first_attempt_unless_it_persists(self):
        value = 's03=crash,s11=no-artifact'
        self.assertEqual(snapshot_shard.fault(value, 's03', 1), 'crash')
        self.assertEqual(snapshot_shard.fault(value, 's11', 1), 'no-artifact')
        self.assertIsNone(snapshot_shard.fault(value, 's03', 2))
        self.assertIsNone(snapshot_shard.fault(value, 's04', 1))
        self.assertIsNone(snapshot_shard.fault('', 's03', 1))
        self.assertEqual(snapshot_shard.fault('s03=crash@every-attempt', 's03', 2), 'crash')
        with self.assertRaises(ValueError):
            snapshot_shard.fault('s03=explode', 's03', 1)

    def test_record_writes_the_shard_class_the_aggregate_reads(self):
        path = self.root / 'out/shard.json'
        status, _ = self.run_main('record', '--shard', 's01', '--out', str(path), '--mode', 'compare',
                                  '--attempt', '2', '--infra', 'crash', '--detail', 'unfinished: HomeSnapshotTests',
                                  '--started', '2026-11-09T00:00:00Z', '--xcode', 'Xcode 27.0, Build version 27A266a',
                                  '--rerun', 'HomeSnapshotTests ShellSnapshotTests')
        self.assertEqual(status, 0)
        record = json.loads(path.read_text())
        self.assertEqual(record['shard'], 's01')
        self.assertEqual(record['infra'], 'crash')
        self.assertEqual(record['attempt'], 2)
        self.assertEqual(record['workers'], 2)
        self.assertEqual(record['units'], ['de-accessibility5', 'zh-Hans-large'])
        self.assertEqual(record['rerunClasses'], ['HomeSnapshotTests', 'ShellSnapshotTests'])
        status, _ = self.run_main('record', '--shard', 's01', '--out', str(path), '--mode', 'candidate',
                                  '--attempt', '1', '--infra', '')
        self.assertIsNone(json.loads(path.read_text())['infra'])
        with self.assertRaises(SystemExit):
            self.run_main('record', '--shard', 's01', '--out', str(path), '--mode', 'compare', '--attempt', '1',
                          '--infra', 'exploded')


if __name__ == '__main__':
    unittest.main()
