"""The measurement reducer: hosted runs to the cost table and the worker count (19-04; 19-CONTEXT D-15)."""
import contextlib
from datetime import datetime, timedelta, timezone
import io
import json
from pathlib import Path
import tempfile
import unittest

import snapshot_measure
import snapshot_shards

START = datetime(2026, 11, 8, 4, 0, tzinfo=timezone.utc)
CONFIGURATIONS = ('en-xSmall', 'en-large', 'en-accessibility5')


def stamp(time):
    return time.strftime('%Y-%m-%dT%H:%M:%SZ')


class Runs:
    """A synthetic runs directory: every device and configuration at 2, 3 and 4 workers, 10 minutes apart."""

    def __init__(self, root):
        self.root = Path(root)
        self.windows = {}
        slot = 0
        for family in ('iphone', 'ipad'):
            (self.root / family).mkdir(parents=True)
            (self.root / family / 'timing.json').write_text(json.dumps({'bootFetchSeconds': 540 + len(family)}))
            (self.root / family / 'memory.log').write_text('')
            for configuration in CONFIGURATIONS:
                for workers in snapshot_measure.WORKER_COUNTS:
                    started = START + timedelta(minutes=10 * slot)
                    self.windows[(family, configuration, workers)] = started
                    slot += 1
                    self.run(family, configuration, workers, seconds=2.0)

    def run(self, family, configuration, workers, seconds, statuses=None, pictures=24, wall=None):
        directory = self.root / family / configuration / f'w{workers}'
        directory.mkdir(parents=True, exist_ok=True)
        statuses = statuses or ['passed'] * pictures
        lines = [{'key': f'scenario-{index}__en__large__portrait__{family}__light', 'status': status,
                  'attempts': 1, 'flaky': False, 'seconds': seconds, 'settleSamples': 3, 'bytes': 1,
                  'sha256': None} for index, status in enumerate(statuses)]
        lines.append({'key': 'na', 'status': 'notApplicable', 'attempts': 0, 'flaky': False, 'seconds': 0,
                      'settleSamples': 0, 'bytes': 0, 'sha256': None, 'reason': 'n/a'})
        (directory / 'results.jsonl').write_text(''.join(json.dumps(line) + '\n' for line in lines))
        started = self.windows[(family, configuration, workers)]
        wall = wall or len(statuses) * seconds / (workers * 0.8)
        (directory / 'shard.json').write_text(json.dumps({
            'shard': 'measure', 'units': [configuration], 'workers': workers, 'xcodeBuild': '27A1',
            'runtime': 'iOS 27.0', 'model': family, 'runnerImage': 'macos-26', 'started': stamp(started),
            'finished': stamp(started + timedelta(seconds=wall)), 'infra': None,
        }))

    def memory(self, *samples):
        for family, time, level in samples:
            with open(self.root / family / 'memory.log', 'a') as log:
                log.write(f'{stamp(time)} {level}\n')

    def facts(self):
        runs, memory, _ = snapshot_measure.load(self.root)
        return snapshot_measure.measure(runs, memory)


class SnapshotMeasureTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.runs = Runs(self.directory.name)

    def tearDown(self):
        self.directory.cleanup()

    def verdict(self):
        excluded = snapshot_measure.exclusions(self.runs.facts())
        return excluded, snapshot_measure.choose(excluded)

    def test_larger_count_wins_only_when_every_rule_passes(self):
        for configuration in CONFIGURATIONS:
            self.runs.run('iphone', configuration, 3, seconds=2.2)
            self.runs.run('iphone', configuration, 4, seconds=2.4)
        excluded, chosen = self.verdict()
        self.assertEqual(excluded, {2: [], 3: [], 4: []})
        self.assertEqual(chosen, 4)

    def test_exactly_one_and_a_quarter_times_still_passes(self):
        self.runs.run('ipad', 'en-large', 4, seconds=2.5)
        self.assertEqual(self.verdict(), ({2: [], 3: [], 4: []}, 4))

    def test_slowdown_excludes_a_count(self):
        self.runs.run('ipad', 'en-accessibility5', 4, seconds=2.6)
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[4], ['slowdown'])
        self.assertEqual(chosen, 3)

    def test_critical_memory_pressure_during_a_run_excludes_its_count(self):
        started = self.runs.windows[('iphone', 'en-large', 4)]
        self.runs.memory(('iphone', started + timedelta(seconds=5), 'critical'))
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[4], ['memory'])
        self.assertEqual(chosen, 3)

    def test_warn_memory_pressure_is_reported_but_excludes_nothing(self):
        started = self.runs.windows[('iphone', 'en-large', 4)]
        self.runs.memory(('iphone', started + timedelta(seconds=5), 'warn'))
        self.assertEqual(self.verdict(), ({2: [], 3: [], 4: []}, 4))
        _, memory, _ = snapshot_measure.load(self.runs.root)
        facts = snapshot_measure.measure(snapshot_measure.load(self.runs.root)[0], memory)
        self.assertEqual(facts[('iphone', 'en-large', 4)]['memory'], 'warn')

    def test_a_run_with_fewer_result_lines_is_incomplete(self):
        self.runs.run('iphone', 'en-xSmall', 3, seconds=2.0, statuses=['passed'] * 20)
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[3], ['incomplete'])
        self.assertEqual(chosen, 4)

    def test_memory_pressure_between_runs_excludes_nothing(self):
        started = self.runs.windows[('iphone', 'en-large', 4)]
        self.runs.memory(('iphone', started - timedelta(seconds=30), 'critical'),
                         ('iphone', started + timedelta(seconds=5), 'normal'))
        self.assertEqual(self.verdict(), ({2: [], 3: [], 4: []}, 4))

    def test_a_per_configuration_job_reads_only_its_own_host_samples(self):
        started = self.runs.windows[('iphone', 'en-large', 4)]
        other = self.runs.root / 'iphone' / 'en-xSmall'
        (other / 'memory.log').write_text(f'{stamp(started + timedelta(seconds=5))} critical\n')
        (other / 'timing.json').write_text(json.dumps({'bootFetchSeconds': 600}))
        self.assertEqual(self.verdict(), ({2: [], 3: [], 4: []}, 4))
        (self.runs.root / 'iphone' / 'en-large' / 'memory.log').write_text(
            f'{stamp(started + timedelta(seconds=5))} critical\n')
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[4], ['memory'])
        self.assertEqual(chosen, 3)
        _, _, boot = snapshot_measure.load(self.runs.root)
        self.assertEqual(snapshot_measure.boot_fetch_minutes(boot, None), 10.0)

    def test_a_changed_picture_excludes_its_count_and_is_reported(self):
        self.runs.run('iphone', 'en-xSmall', 3, seconds=2.0, statuses=['passed'] * 23 + ['changed'])
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[3], ['changed'])
        self.assertEqual(chosen, 4)
        facts = self.runs.facts()
        self.assertEqual(facts[('iphone', 'en-xSmall', 3)]['changed'], 1)
        self.assertIn('| iphone | en-xSmall | 3 | 24 | 2.00 | 1.00 |', snapshot_measure.table(facts))

    def test_a_missing_run_excludes_its_count(self):
        directory = self.runs.root / 'ipad' / 'en-xSmall' / 'w4'
        for path in directory.iterdir():
            path.unlink()
        directory.rmdir()
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[4], ['incomplete'])
        self.assertEqual(chosen, 3)

    def test_a_run_cut_off_before_its_record_counts_as_missing(self):
        (self.runs.root / 'iphone' / 'en-large' / 'w4' / 'shard.json').unlink()
        excluded, chosen = self.verdict()
        self.assertEqual(excluded[4], ['incomplete'])
        self.assertEqual(chosen, 3)

    def test_nothing_is_chosen_or_written_when_two_is_excluded(self):
        started = self.runs.windows[('ipad', 'en-large', 2)]
        self.runs.memory(('ipad', started + timedelta(seconds=1), 'critical'))
        target = self.runs.root / 'cost.json'
        with contextlib.redirect_stdout(io.StringIO()) as output:
            status = snapshot_measure.main(['--runs', str(self.runs.root), '--run-id', '7', '--write', str(target)])
        self.assertEqual(status, 1)
        self.assertFalse(target.exists())
        self.assertIn('- 2 workers: memory', output.getvalue())
        self.assertIn('- Chosen: none', output.getvalue())

    def test_written_table_is_measured_and_feeds_the_shard_plan(self):
        self.runs.run('ipad', 'en-accessibility5', 4, seconds=3.0)
        for configuration in CONFIGURATIONS:
            self.runs.run('iphone', configuration, 3, seconds=2.1)
        target = self.runs.root / 'cost.json'
        with contextlib.redirect_stdout(io.StringIO()) as output:
            status = snapshot_measure.main(['--runs', str(self.runs.root), '--run-id', '123', '--write', str(target)])
        self.assertEqual(status, 0)
        self.assertIn('- 4 workers: slowdown', output.getvalue())
        self.assertIn('- Chosen: 3 workers', output.getvalue())
        costs = json.loads(target.read_text())
        self.assertEqual((costs['schema'], costs['source'], costs['runId'], costs['workers']),
                         (1, 'measured', '123', 3))
        self.assertEqual(costs['secondsPerPicture'], {
            'iphone': {'xSmall': 2.1, 'large': 2.1, 'accessibility5': 2.1},
            'ipad': {'xSmall': 2.0, 'large': 2.0, 'accessibility5': 2.0},
        })
        self.assertEqual(costs['cloneSpeedup'], 2.4)
        self.assertEqual(costs['bootFetchMinutes'], 9.1)
        plan = json.loads(snapshot_shards.compute(cost_path=target))
        self.assertEqual((plan['costSource'], plan['workers'], len(plan['shards'])), ('measured', 3, 20))

    def candidate(self, family, configuration, minutes):
        directory = self.runs.root / family / configuration / 'candidate'
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'shard.json').write_text(json.dumps({
            'started': stamp(START), 'finished': stamp(START + timedelta(minutes=minutes))}))

    def test_fixed_cost_per_invocation_comes_from_the_all_candidate(self):
        # F + C_i per single size and F + sum(C_i) together: iPhone F = (12 + 14 + 16 - 26) / 2 = 8, iPad 9.
        for family, singles, together in (('iphone', (12, 14, 16), 26), ('ipad', (15, 17, 19), 33)):
            for configuration, minutes in zip(CONFIGURATIONS, singles):
                self.candidate(family, configuration, minutes)
            self.candidate(family, 'all', together)
        walls = snapshot_measure.candidate_walls(self.runs.root)
        self.assertEqual(snapshot_measure.invocation_minutes(walls, None), 9.0)
        self.assertEqual(snapshot_measure.invocation_minutes(walls, 5.5), 5.5)
        target = self.runs.root / 'cost.json'
        with contextlib.redirect_stdout(io.StringIO()) as output:
            snapshot_measure.main(['--runs', str(self.runs.root), '--run-id', '9', '--write', str(target)])
        self.assertIn('- Fixed cost per invocation: 9.0 min', output.getvalue())
        self.assertEqual(json.loads(target.read_text())['invocationMinutes'], 9.0)

    def test_fixed_cost_is_not_measured_without_an_all_candidate(self):
        self.candidate('iphone', 'en-large', 12)
        self.assertIsNone(snapshot_measure.invocation_minutes(snapshot_measure.candidate_walls(self.runs.root), None))

    def test_rendered_table_keeps_the_committed_layout(self):
        costs = json.loads(snapshot_shards.COSTS.read_text())
        costs.update(source='measured', runId='1')
        rendered = snapshot_measure.render(costs)
        self.assertEqual(json.loads(rendered), costs)
        self.assertIn('    "iphone": {"xSmall": ', rendered)


if __name__ == '__main__':
    unittest.main()
