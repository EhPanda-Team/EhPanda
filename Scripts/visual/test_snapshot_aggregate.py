"""The snapshot gate's merge, failure classes and retry triage (19-09)."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

import snapshot_aggregate
import snapshot_matrix

INVENTORY = {'schema': 2, 'scenarios': [
    {'id': 'home-populated', 'group': 'home', 'plan': '19-05', 'state': 'Populated', 'signedIn': True,
     'notApplicable': []},
    {'id': 'library-sidebar', 'group': 'library', 'plan': '19-06', 'state': 'Sidebar', 'signedIn': True,
     'notApplicable': [{'when': {'widthClass': 'compact'}, 'reason': 'Needs a regular width.'}]},
]}
SHARD_PLAN = {'schema': 1, 'shards': [
    {'id': 's03', 'family': 'iphone', 'configurations': ['en-large'],
     'runs': [{'configuration': 'en-large', 'orientations': ['portrait', 'landscape']}]},
    {'id': 's07', 'family': 'iphone', 'configurations': ['de-large'],
     'runs': [{'configuration': 'de-large', 'orientations': ['portrait', 'landscape']}]},
    {'id': 's11', 'family': 'ipad', 'configurations': ['en-large'],
     'runs': [{'configuration': 'en-large', 'orientations': ['portrait']}]},
]}


class AggregateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.results, self.retry = self.root / 'results', self.root / 'retry'
        _, self.env = snapshot_matrix.load()
        (self.root / 'scenarios.json').write_text(json.dumps(INVENTORY))
        (self.root / 'shards.json').write_text(json.dumps(SHARD_PLAN))
        self.rows = snapshot_matrix.coordinates(INVENTORY, self.env)

    def tearDown(self):
        self.directory.cleanup()

    def keys(self, shard_id, captured=True):
        shard = next(row for row in SHARD_PLAN['shards'] if row['id'] == shard_id)
        return sorted(key for key, reason in snapshot_aggregate.shard_coordinates(shard, self.rows).items()
                      if (reason is None) == captured)

    def write(self, root, shard_id, status='passed', infra=None, overrides=None, skip=(), extra=()):
        """A shard directory: one line per coordinate (not-applicable ones included), as the Swift writer does."""
        directory = root / shard_id
        directory.mkdir(parents=True)
        record = {'shard': shard_id, 'units': [], 'workers': 2, 'xcodeBuild': '27A266a', 'runtime': '24A434',
                  'model': 'iPhone18,4', 'runnerImage': None, 'started': '', 'finished': '', 'infra': infra}
        (directory / 'shard.json').write_text(json.dumps(record))
        lines = []
        if infra not in ('drift', 'baseline-mismatch'):
            for key in self.keys(shard_id) + self.keys(shard_id, captured=False):
                if key in skip:
                    continue
                state = 'notApplicable' if key in self.keys(shard_id, captured=False) else status
                line = {'key': key, 'status': state, 'attempts': 1, 'flaky': False, 'seconds': 1.5,
                        'settleSamples': 5, 'bytes': 10, 'sha256': None, 'reason': None}
                line.update((overrides or {}).get(key, {}))
                lines.append(line)
        lines += list(extra)
        (directory / 'results.jsonl').write_text(''.join(json.dumps(line) + '\n' for line in lines))

    def write_all(self, root=None, **changes):
        for shard_id in ('s03', 's07', 's11'):
            self.write(root or self.results, shard_id, **changes.get(shard_id, {}))

    def run_cli(self, *extra):
        out = io.StringIO()
        arguments = ['--results', str(self.results), '--inventory', str(self.root / 'scenarios.json'),
                     '--shards', str(self.root / 'shards.json'), *extra]
        if '--triage' not in extra:
            arguments += ['--out', str(self.root / 'out')]
        with contextlib.redirect_stdout(out):
            code = snapshot_aggregate.main(arguments)
        return code, out.getvalue()

    def aggregate(self):
        return json.loads((self.root / 'out/aggregate.json').read_text())

    def triage(self, *extra):
        code, out = self.run_cli('--triage', *extra)
        self.assertEqual(code, 0)
        return json.loads(out)

    def test_all_passed_with_flakes_exits_zero_and_lists_the_flake_log(self):
        flaky = self.keys('s03')[0]
        self.write_all(s03={'overrides': {flaky: {'flaky': True, 'attempts': 2, 'seconds': 3.25}}})
        summary_file = self.root / 'step-summary.md'
        code, out = self.run_cli('--summary', str(summary_file))
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines()[:4], ['- 0 picture changes', '- 0 infrastructure errors', '- 0 drift',
                                                '- 0 baseline mismatches'])
        self.assertIn(f'| `{flaky}` | 3.25 | 2 | s03 |', out)
        self.assertEqual(summary_file.read_text(), out)
        document = self.aggregate()
        self.assertEqual(document['flaky'], [{'key': flaky, 'shard': 's03', 'seconds': 3.25, 'attempts': 2}])
        self.assertEqual(document['statusCounts']['passed'], len(self.keys('s03') + self.keys('s07')
                                                                 + self.keys('s11')))
        self.assertEqual(self.triage(), [])

    def test_one_changed_picture_fails_without_a_retry(self):
        changed = self.keys('s07')[1]
        self.write_all(s07={'overrides': {changed: {'status': 'changed'}}})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(out.splitlines()[0], '- 1 picture changes')
        self.assertEqual(self.aggregate()['items']['pictureChanges'],
                         [{'shard': 's07', 'kind': 'changed', 'key': changed}])
        self.assertEqual(self.triage(), [])

    def test_crashed_shard_is_retried_and_a_passing_retry_is_merged(self):
        self.write_all(s07={'infra': 'crash', 'skip': self.keys('s07')[2:]})
        self.assertEqual(self.triage(), ['s07'])
        code, _ = self.run_cli()
        self.assertEqual(code, 1)
        self.write(self.retry, 's07')
        code, out = self.run_cli('--retry', str(self.retry))
        self.assertEqual(code, 0, out)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07']['attempt'], 2)
        self.assertIn('retried: s07', out)

    def test_shard_without_a_directory_is_runner_lost_and_retried(self):
        self.write(self.results, 's03')
        self.write(self.results, 's07')
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(self.aggregate()['shards']['s11']['infra'], 'runner-lost')
        self.assertIn('runner-lost', out)
        self.assertEqual(self.triage(), ['s11'])

    def test_drift_fails_and_is_never_retried(self):
        self.write_all(s03={'infra': 'drift'})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(out.splitlines()[:4], ['- 0 picture changes', '- 0 infrastructure errors', '- 1 drift',
                                                '- 0 baseline mismatches'])
        self.assertEqual(self.triage(), [])

    def test_baseline_mismatch_fails_and_is_never_retried(self):
        self.write_all(s11={'infra': 'baseline-mismatch'})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(out.splitlines()[3], '- 1 baseline mismatches')
        self.assertEqual(self.triage(), [])

    def test_failed_retry_is_never_listed_again(self):
        self.write_all(s07={'infra': 'timeout'})
        self.write(self.retry, 's07', infra='crash')
        code, _ = self.run_cli('--retry', str(self.retry))
        self.assertEqual(code, 1)
        self.assertEqual(self.triage('--retry', str(self.retry)), [])

    def test_expected_coordinate_without_a_line_is_missing_result(self):
        missing = self.keys('s11')[0]
        self.write_all(s11={'skip': [missing]})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(self.aggregate()['items']['infrastructureErrors'],
                         [{'shard': 's11', 'kind': 'missing-result', 'key': missing}])
        self.assertIn(f'`{missing}`: missing-result', out)
        self.assertEqual(self.triage(), ['s11'])

    def test_duplicate_line_is_an_error_naming_the_key(self):
        duplicate = self.keys('s03')[0]
        line = {'key': duplicate, 'status': 'passed', 'attempts': 1, 'flaky': False, 'seconds': 1.0}
        self.write_all(s03={'extra': [line]})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertIn(f'`{duplicate}`: duplicate-result (s03)', out)

    def test_coordinate_timeout_and_malformed_line_are_infrastructure_errors(self):
        timed_out = self.keys('s03')[0]
        self.write_all(s03={'overrides': {timed_out: {'status': 'timeout', 'reason': 'settle'}}})
        with (self.results / 's03/results.jsonl').open('a') as handle:
            handle.write('{not json\n')
        code, _ = self.run_cli()
        self.assertEqual(code, 1)
        kinds = [item['kind'] for item in self.aggregate()['items']['infrastructureErrors']]
        self.assertEqual(kinds, ['malformed-result', 'timeout'])
        self.assertEqual(self.triage(), ['s03'])

    def test_not_applicable_coordinates_need_no_line(self):
        absent = self.keys('s03', captured=False)
        self.assertTrue(absent)
        self.write_all(s03={'skip': absent})
        code, _ = self.run_cli()
        self.assertEqual(code, 0)


if __name__ == '__main__':
    unittest.main()
