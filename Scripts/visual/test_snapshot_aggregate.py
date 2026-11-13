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
        self.retry2, self.retry3 = self.root / 'retry2', self.root / 'retry3'
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

    def test_a_shard_still_lost_after_its_retry_is_listed_for_the_second_retry(self):
        # Run 43298876957: 3 of 13 retries were cut by the runner as well. The shards the first retry did not bring
        # back go once more (`--triage --attempt 3`); the first round's list is unchanged.
        self.write_all(s07={'infra': 'crash', 'skip': self.keys('s07')[2:]}, s03={'infra': 'timeout'})
        self.assertEqual(self.triage(), ['s03', 's07'])
        self.assertEqual(self.triage('--attempt', '3'), ['s03', 's07'])
        self.write(self.retry, 's03')
        self.write(self.retry, 's07', infra='crash')
        self.assertEqual(self.triage('--retry', str(self.retry)), [])
        self.assertEqual(self.triage('--retry', str(self.retry), '--attempt', '3'), ['s07'])

    def test_a_retry_that_left_no_artifact_or_no_shard_json_is_listed_for_the_second_retry(self):
        self.write_all(s03={'infra': 'crash'}, s07={'infra': 'crash'}, s11={'infra': 'timeout'})
        (self.retry / 's07' / 'logs').mkdir(parents=True)
        self.write(self.retry, 's11')
        # s03's retry job was cut with nothing uploaded, s07's left only logs, s11's came back.
        self.assertEqual(self.triage('--retry', str(self.retry)), ['s03'])
        self.assertEqual(self.triage('--retry', str(self.retry), '--attempt', '3'), ['s03', 's07'])

    def test_a_shard_whose_second_retry_ran_is_never_listed_again(self):
        self.write_all(s07={'infra': 'timeout'})
        self.write(self.retry, 's07', infra='crash')
        self.write(self.retry2, 's07', infra='crash')
        arguments = ('--retry', str(self.retry), '--retry2', str(self.retry2))
        self.assertEqual(self.triage(*arguments, '--attempt', '3'), [])
        (self.retry2 / 's07' / 'shard.json').unlink()
        self.assertEqual(self.triage(*arguments, '--attempt', '3'), [])

    def test_a_coordinate_error_is_not_retried_in_the_second_round_either(self):
        erring = self.keys('s07')[0]
        self.write_all(s07={'overrides': {erring: {'status': 'error', 'reason': 'interaction'}}})
        self.write(self.retry, 's03')
        self.assertEqual(self.triage('--attempt', '3'), [])

    def test_the_second_retry_is_the_latest_attempt_and_is_merged(self):
        self.write_all(s07={'infra': 'crash', 'skip': self.keys('s07')[2:]})
        self.write(self.retry, 's07', infra='timeout', skip=self.keys('s07')[1:])
        self.write(self.retry2, 's07')
        code, out = self.run_cli('--retry', str(self.retry), '--retry2', str(self.retry2))
        self.assertEqual(code, 0, out)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07']['attempt'], 3)
        self.assertEqual(document['shards']['s07']['directory'], str(self.retry2 / 's07'))
        self.assertIn('retried: s07', out)
        self.assertIn('| s07 | 3 | none |', out)

    def test_a_second_retry_without_shard_json_keeps_the_latest_attempt_that_has_one(self):
        self.write_all(s07={'infra': 'crash', 'skip': [self.keys('s07')[0]]})
        self.write(self.retry, 's07', infra='crash', skip=[self.keys('s07')[1]])
        (self.retry2 / 's07' / 'logs').mkdir(parents=True)
        code, out = self.run_cli('--retry', str(self.retry), '--retry2', str(self.retry2))
        self.assertEqual(code, 1)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07']['attempt'], 2)
        self.assertTrue(document['shards']['s07']['retryLost'])
        self.assertEqual(document['shards']['s07']['directory'], str(self.retry / 's07'))
        self.assertIn('- s07: retry-lost (s07) — the second retry left no shard.json', out)
        self.assertIn('| s07 | 2 (retry lost) | crash |', out)
        missing = [item['key'] for item in document['items']['infrastructureErrors'] if item['kind'] == 'missing-result']
        self.assertEqual(missing, [self.keys('s07')[1]])

    def test_a_second_retry_after_two_lost_attempts_is_runner_lost_at_attempt_3(self):
        self.write(self.results, 's03')
        self.write(self.results, 's11')
        (self.retry2 / 's07' / 'logs').mkdir(parents=True)
        code, out = self.run_cli('--retry2', str(self.retry2))
        self.assertEqual(code, 1)
        self.assertEqual(self.aggregate()['shards']['s07'], {'attempt': 3, 'infra': 'runner-lost',
                                                             'directory': str(self.retry2 / 's07')})

    def test_a_retry2_directory_alone_is_enough_without_a_retry_one(self):
        # The first retry's job may have left no artifact at all; the second retry still replaces the first attempt.
        self.write_all(s07={'infra': 'crash', 'skip': self.keys('s07')[2:]})
        self.write(self.retry2, 's07')
        code, out = self.run_cli('--retry2', str(self.retry2))
        self.assertEqual(code, 0, out)
        self.assertEqual(self.aggregate()['shards']['s07']['attempt'], 3)

    def test_a_shard_still_lost_after_its_second_retry_is_listed_for_the_third(self):
        # Four attempts in all (owner msg 5033 follow-up): the third retry round lists what the second did not bring
        # back, by the same rule, and a shard whose own third retry ran is never listed again.
        self.write_all(s03={'infra': 'crash'}, s07={'infra': 'crash'}, s11={'infra': 'timeout'})
        self.write(self.retry, 's03', infra='crash')
        self.write(self.retry, 's07', infra='crash')
        self.write(self.retry, 's11')
        self.write(self.retry2, 's03', infra='timeout')
        (self.retry2 / 's07' / 'logs').mkdir(parents=True)
        arguments = ('--retry', str(self.retry), '--retry2', str(self.retry2))
        self.assertEqual(self.triage(*arguments, '--attempt', '3'), [])
        self.assertEqual(self.triage(*arguments, '--attempt', '4'), ['s03', 's07'])
        self.write(self.retry3, 's03', infra='crash')
        arguments += ('--retry3', str(self.retry3))
        self.assertEqual(self.triage(*arguments, '--attempt', '4'), ['s07'])
        (self.retry3 / 's07' / 'logs').mkdir(parents=True)
        self.assertEqual(self.triage(*arguments, '--attempt', '4'), [])

    def test_a_retry_cut_with_no_artifact_in_every_round_is_listed_again_until_the_last(self):
        self.write_all(s07={'infra': 'crash'})
        for attempt in ('2', '3', '4'):
            self.assertEqual(self.triage('--attempt', attempt), ['s07'])

    def test_the_third_retry_is_the_latest_attempt_and_is_merged(self):
        self.write_all(s07={'infra': 'crash', 'skip': self.keys('s07')[2:]})
        self.write(self.retry, 's07', infra='timeout', skip=self.keys('s07')[1:])
        self.write(self.retry2, 's07', infra='crash', skip=self.keys('s07')[1:])
        self.write(self.retry3, 's07')
        code, out = self.run_cli('--retry', str(self.retry), '--retry2', str(self.retry2),
                                 '--retry3', str(self.retry3))
        self.assertEqual(code, 0, out)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07']['attempt'], 4)
        self.assertEqual(document['shards']['s07']['directory'], str(self.retry3 / 's07'))
        self.assertEqual(document['ran']['s07'], 4)
        self.assertIn('retried: s07', out)
        self.assertIn('| s07 | 4 | none |', out)

    def test_a_third_retry_without_shard_json_keeps_the_latest_attempt_that_has_one(self):
        self.write_all(s07={'infra': 'crash', 'skip': [self.keys('s07')[0]]})
        self.write(self.retry, 's07', infra='crash', skip=[self.keys('s07')[1]])
        (self.retry2 / 's07' / 'logs').mkdir(parents=True)
        (self.retry3 / 's07' / 'logs').mkdir(parents=True)
        code, out = self.run_cli('--retry', str(self.retry), '--retry2', str(self.retry2),
                                 '--retry3', str(self.retry3))
        self.assertEqual(code, 1)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07']['attempt'], 2)
        self.assertTrue(document['shards']['s07']['retryLost'])
        self.assertIn('- s07: retry-lost (s07) — the third retry left no shard.json', out)
        self.assertIn('the second attempt is merged', out)

    def test_the_triage_takes_only_the_rounds_there_are(self):
        with self.assertRaises(SystemExit):
            self.run_cli('--triage', '--attempt', '5')
        with self.assertRaises(SystemExit):
            self.run_cli('--triage', '--attempt', '1')

    def test_a_restricted_run_merges_and_triages_only_the_selected_shards(self):
        # The dispatch input `shards` restricts a candidate run: the others are not lost, they were never asked for.
        self.write(self.results, 's07')
        code, out = self.run_cli('--only', 's07')
        self.assertEqual(code, 0, out)
        document = self.aggregate()
        self.assertEqual(sorted(document['shards']), ['s07'])
        self.assertEqual(document['only'], ['s07'])
        self.assertTrue({row['shard'] for row in document['results']} <= {'s07'})
        self.assertIn('Restricted to 1 of 3 shards: s07', out)
        self.assertEqual(self.triage('--only', 's07'), [])
        self.assertEqual(self.triage('--only', 's07,s11'), ['s11'])
        self.assertEqual(self.triage(), ['s03', 's11'])
        code, out = self.run_cli('--only', 's03,s07')
        self.assertEqual(code, 1)
        self.assertIn('s03: runner-lost', out)
        self.assertNotIn('s11', out.split('## Snapshot gate', 1)[1])

    def test_an_unrestricted_run_says_nothing_about_a_restriction(self):
        self.write_all()
        code, out = self.run_cli()
        self.assertEqual(code, 0)
        self.assertNotIn('Restricted', out)
        self.assertNotIn('only', self.aggregate())

    def test_an_unknown_shard_in_only_is_refused(self):
        with self.assertRaises(SystemExit):
            self.run_cli('--only', 's07,s99')

    def test_expected_coordinate_without_a_line_is_missing_result(self):
        missing = self.keys('s11')[0]
        self.write_all(s11={'skip': [missing]})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(self.aggregate()['items']['infrastructureErrors'],
                         [{'shard': 's11', 'kind': 'missing-result', 'key': missing}])
        self.assertIn(f'`{missing}`: missing-result', out)
        self.assertEqual(self.triage(), ['s11'])

    def test_duplicate_lines_that_disagree_are_an_error_naming_the_key(self):
        duplicate = self.keys('s03')[0]
        line = {'key': duplicate, 'status': 'changed', 'attempts': 1, 'flaky': False, 'seconds': 1.0}
        self.write_all(s03={'extra': [line]})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertIn(f'`{duplicate}`: duplicate-result (s03)', out)

    def test_duplicate_lines_that_agree_are_merged_once(self):
        # Run 42577585956 (s06, s17, s18): XCTest runs a class again after its test runner crashed, so a picture
        # taken twice with the same result is written twice. That is one result, not an infrastructure error.
        duplicate = self.keys('s03')[0]
        line = {'key': duplicate, 'status': 'passed', 'attempts': 1, 'flaky': False, 'seconds': 4.0}
        self.write_all(s03={'extra': [line]})
        code, out = self.run_cli()
        self.assertEqual(code, 0, out)
        rows = [row for row in self.aggregate()['results'] if row['key'] == duplicate]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['seconds'], 1.5)

    def test_recorded_twice_with_different_pictures_is_an_error_naming_both_digests(self):
        # Run 43298876957 (s15): runners XCTest had given up woke and recorded the coordinates their replacements
        # recorded, and the merge kept the first line while the disk kept the second picture.
        duplicate = self.keys('s03')[0]
        first = {'sha256': 'aa', 'status': 'recorded'}
        line = {'key': duplicate, 'status': 'recorded', 'attempts': 1, 'flaky': False, 'seconds': 4.0, 'sha256': 'bb'}
        self.write_all(s03={'status': 'recorded', 'overrides': {duplicate: first}, 'extra': [line]})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(self.aggregate()['items']['infrastructureErrors'], [{
            'shard': 's03', 'kind': 'duplicate-result', 'key': duplicate,
            'detail': 'recorded twice with different pictures (aa, then bb)'}])
        self.assertIn(f'`{duplicate}`: duplicate-result (s03)', out)

    def test_recorded_twice_with_the_same_picture_is_merged_once(self):
        duplicate = self.keys('s03')[0]
        line = {'key': duplicate, 'status': 'recorded', 'attempts': 1, 'flaky': False, 'seconds': 4.0, 'sha256': 'aa'}
        self.write_all(s03={'status': 'recorded', 'overrides': {duplicate: {'sha256': 'aa'}}, 'extra': [line]})
        code, out = self.run_cli()
        self.assertEqual(code, 0, out)
        self.assertEqual(len([row for row in self.aggregate()['results'] if row['key'] == duplicate]), 1)

    def test_retry_without_shard_json_keeps_the_first_attempt_and_is_reported(self):
        # Run 42577585956: s07's retry could not make its simulator and left only its logs, and the merge took that
        # empty retry over a first attempt with 547 pictures. The first attempt stays; the lost retry is named.
        erring = self.keys('s07')[0]
        self.write_all(s07={'infra': 'crash', 'skip': [erring]})
        (self.retry / 's07' / 'logs').mkdir(parents=True)
        code, out = self.run_cli('--retry', str(self.retry))
        self.assertEqual(code, 1)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07']['attempt'], 1)
        self.assertTrue(document['shards']['s07']['retryLost'])
        kinds = sorted(item['kind'] for item in document['items']['infrastructureErrors'])
        self.assertEqual(kinds, ['crash', 'missing-result', 'retry-lost'])
        self.assertIn('- s07: retry-lost (s07) — the retry left no shard.json', out)
        self.assertIn('| s07 | 1 (retry lost) | crash |', out)
        self.assertNotIn('runner-lost', out)
        self.assertEqual(self.triage('--retry', str(self.retry)), [])

    def test_retry_without_shard_json_after_a_lost_first_attempt_is_runner_lost(self):
        self.write(self.results, 's03')
        self.write(self.results, 's11')
        (self.retry / 's07' / 'logs').mkdir(parents=True)
        code, out = self.run_cli('--retry', str(self.retry))
        self.assertEqual(code, 1)
        document = self.aggregate()
        self.assertEqual(document['shards']['s07'], {'attempt': 2, 'infra': 'runner-lost',
                                                     'directory': str(self.retry / 's07')})
        self.assertIn('s07: runner-lost (s07) — no shard.json (runner unusable, see s07/logs)', out)

    def test_shard_directory_without_shard_json_is_named_unusable_not_missing(self):
        self.write(self.results, 's03')
        self.write(self.results, 's07')
        (self.results / 's11' / 'logs').mkdir(parents=True)
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertIn('s11: runner-lost (s11) — no shard.json (runner unusable, see s11/logs)', out)
        self.assertNotIn('no artifact', out)
        self.assertEqual(self.triage(), ['s11'])

    def test_a_coordinate_error_is_reported_but_never_retries_the_shard(self):
        # Run 42577585956: one picture's `interaction` error sent s07's 547 good pictures to a whole-shard retry.
        # Only a shard-level error (crash, timeout, lost runner, missing or malformed results) retries a shard.
        erring, slow = self.keys('s07')[:2]
        self.write_all(s07={'overrides': {erring: {'status': 'error', 'reason': 'interaction'},
                                          slow: {'status': 'timeout', 'reason': 'settle-timeout'}}})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        self.assertEqual(self.aggregate()['counts']['infrastructureErrors'], 2)
        self.assertIn(f'`{erring}`: error (s07) — interaction', out)
        self.assertEqual(self.triage(), [])

    def test_the_summary_has_one_line_per_shard_before_the_items(self):
        # Run 42577585956's summary spent its 200 items on one shard's missing results and never named the others.
        self.write_all(s03={'infra': 'timeout', 'skip': self.keys('s03')[1:]},
                       s07={'overrides': {self.keys('s07')[0]: {'status': 'error', 'reason': 'interaction'}}})
        code, out = self.run_cli()
        self.assertEqual(code, 1)
        lines = out.splitlines()
        table = lines.index('| Shard | Attempt | Shard class | Results | Infrastructure errors |')
        self.assertLess(table, lines.index(next(line for line in lines if line.startswith('### Infrastructure'))))
        missing = len(self.keys('s03')) - 1
        self.assertIn(f'| s03 | 1 | timeout | passed 1, notApplicable {len(self.keys("s03", captured=False))} '
                      f'| missing-result {missing}, timeout 1 |', lines)
        self.assertIn('| s11 | 1 | none | passed 4 | none |', lines)
        self.assertTrue(any(line.startswith('| s07 | 1 | none |') and line.endswith('| error 1 |')
                            for line in lines), out)

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
