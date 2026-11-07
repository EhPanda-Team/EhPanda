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

    def test_there_are_36_units(self):
        self.assertEqual(len(self.costs_by_unit), 36)
        self.assertEqual({unit[0] for unit in self.costs_by_unit}, {'iphone', 'ipad'})

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
