"""The deterministic, cost-balanced 20-shard plan (19-02; 19-RESEARCH §5)."""
import json
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest

import snapshot_matrix
import snapshot_shards


class SnapshotShardsTests(unittest.TestCase):
    def setUp(self):
        self.document, self.env = snapshot_matrix.load()
        self.costs = json.loads(snapshot_shards.COSTS.read_text())
        self.pictures = snapshot_shards.unit_pictures(self.document, self.env)
        self.costs_by_unit = snapshot_shards.unit_costs(self.pictures, self.costs)

    def test_there_are_54_units_one_per_process(self):
        self.assertEqual(len(self.costs_by_unit), 54)
        iphone = [unit for unit in self.costs_by_unit if unit[0] == 'iphone']
        ipad = [unit for unit in self.costs_by_unit if unit[0] == 'ipad']
        self.assertEqual(len(iphone), 18)
        self.assertEqual({unit[2] for unit in iphone}, {('portrait', 'landscape')})
        self.assertEqual(len(ipad), 36)
        self.assertEqual({unit[2] for unit in ipad}, {('portrait',), ('landscape',)})

    def test_units_hold_every_expected_picture(self):
        totals = snapshot_matrix.totals(self.document, self.env)
        self.assertEqual(sum(self.pictures.values()), totals['expected'])

    def test_runs_name_each_process_once_in_configuration_order(self):
        plan = json.loads(snapshot_shards.compute())
        order = snapshot_matrix.configurations()
        seen = []
        for shard in plan['shards']:
            runs = [(run['configuration'], tuple(run['orientations'])) for run in shard['runs']]
            self.assertEqual(runs, sorted(runs, key=lambda run: (order.index(run[0]),
                                                                 snapshot_matrix.ORIENTATIONS.index(run[1][0]))))
            self.assertEqual(shard['configurations'], sorted({run[0] for run in runs}, key=order.index))
            if shard['family'] == 'ipad':
                self.assertTrue(all(len(run[1]) == 1 for run in runs))
            seen += [(shard['family'],) + run for run in runs]
        self.assertEqual(sorted(seen), sorted(self.costs_by_unit))

    def test_a_shard_runs_one_invocation_per_orientation_group(self):
        plan = json.loads(snapshot_shards.compute())
        for shard in plan['shards']:
            groups = {}
            for run in shard['runs']:
                groups.setdefault(tuple(run['orientations']), []).append(run['configuration'])
            self.assertEqual([(tuple(call['orientations']), call['configurations']) for call in shard['invocations']],
                             sorted(groups.items(), key=lambda item: snapshot_matrix.ORIENTATIONS.index(item[0][0])))

    def test_the_estimate_counts_the_fixed_cost_once_per_invocation(self):
        plan = json.loads(snapshot_shards.compute())
        without = dict(self.costs, invocationMinutes=0)
        with tempfile.NamedTemporaryFile('w', suffix='.json') as handle:
            json.dump(without, handle)
            handle.flush()
            bare = json.loads(snapshot_shards.compute(cost_path=Path(handle.name)))
        for shard, other in zip(plan['shards'], bare['shards']):
            self.assertAlmostEqual(shard['estimatedMinutes'] - other['estimatedMinutes'],
                                   len(shard['invocations']) * self.costs['invocationMinutes'], delta=0.11)

    def test_an_ipad_landscape_process_gets_no_clone_speedup(self):
        # 19-10: clones boot in portrait, so an iPad landscape process runs on the turned device alone.
        seconds = snapshot_shards.unit_seconds(self.costs_by_unit, self.costs)
        for unit, cost in self.costs_by_unit.items():
            speedup = 1 if unit[0] == 'ipad' and unit[2] == ('landscape',) else self.costs['cloneSpeedup']
            self.assertAlmostEqual(seconds[unit], cost / speedup)

    def test_shards_are_balanced_and_estimated_on_wall_seconds(self):
        plan = json.loads(snapshot_shards.compute())
        seconds = snapshot_shards.unit_seconds(self.costs_by_unit, self.costs)
        assigned = snapshot_shards.assign(seconds)
        for shard, (family, units, wall) in zip(plan['shards'], assigned):
            self.assertEqual(shard['family'], family)
            self.assertEqual(sorted((run['configuration'], tuple(run['orientations'])) for run in shard['runs']),
                             sorted(unit[1:] for unit in units))
            self.assertAlmostEqual(shard['costSeconds'], sum(self.costs_by_unit[unit] for unit in units), delta=0.11)
            self.assertAlmostEqual(shard['estimatedMinutes'],
                                   self.costs['bootFetchMinutes']
                                   + len(shard['invocations']) * self.costs['invocationMinutes'] + wall / 60,
                                   delta=0.06)

    def test_every_unit_is_in_exactly_one_shard_of_its_own_device(self):
        shards = snapshot_shards.assign(self.costs_by_unit)
        self.assertEqual(len(shards), 20)
        placed = [unit for _, units, _ in shards for unit in units]
        self.assertEqual(sorted(placed), sorted(self.costs_by_unit))
        for family, units, _ in shards:
            self.assertTrue(units)
            self.assertEqual({unit[0] for unit in units}, {family})

    def test_the_ipad_gets_more_shards(self):
        split = snapshot_shards.split(self.costs_by_unit)
        self.assertEqual(sum(split.values()), 20)
        self.assertGreater(split['ipad'], split['iphone'])

    def test_assignment_ignores_input_order(self):
        expected = snapshot_shards.assign(self.costs_by_unit)
        items = list(self.costs_by_unit.items())
        for seed in range(5):
            random.Random(seed).shuffle(items)
            self.assertEqual(snapshot_shards.assign(dict(items)), expected)

    def test_largest_shard_is_within_a_quarter_of_the_mean(self):
        costs = [cost for _, _, cost in snapshot_shards.assign(self.costs_by_unit)]
        self.assertLessEqual(max(costs), 1.25 * sum(costs) / len(costs))

    def test_timeouts_are_twice_the_estimate_and_capped(self):
        plan = json.loads(snapshot_shards.compute())
        for shard in plan['shards']:
            self.assertEqual(shard['timeoutMinutes'], min(120, math.ceil(2 * shard['estimatedMinutes'])))
            self.assertLessEqual(shard['timeoutMinutes'], 120)

    def test_plan_names_s01_to_s20_and_the_cost_table(self):
        plan = json.loads(snapshot_shards.compute())
        self.assertEqual([shard['id'] for shard in plan['shards']], [f's{index:02d}' for index in range(1, 21)])
        self.assertEqual(plan['costSource'], self.costs['source'])
        self.assertEqual(len(plan['costTable']), 64)
        self.assertEqual(plan['workers'], self.costs['workers'])

    def test_two_runs_are_byte_identical(self):
        self.assertEqual(snapshot_shards.compute(), snapshot_shards.compute())

    def test_committed_plan_is_current(self):
        script = Path(snapshot_shards.__file__)
        result = subprocess.run([sys.executable, str(script), '--check'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_check_fails_on_a_stale_plan(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / 'snapshot-shards.json'
        path.write_text('{}\n')
        self.assertEqual(snapshot_shards.main(['--check', '--output', str(path)]), 1)


if __name__ == '__main__':
    unittest.main()
