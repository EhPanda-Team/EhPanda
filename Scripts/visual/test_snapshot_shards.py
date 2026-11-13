"""The deterministic, cost-balanced shard plan (19-02; 19-RESEARCH §5; sized by the measured costs since 19-10)."""
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

    def test_there_are_72_units_one_per_process(self):
        # Run 43298876957: an iPhone shard of both orientations took 39 to 73 minutes and half of them were cut, so
        # an iPhone process captures one orientation too (EHPANDA_SNAPSHOT_ORIENTATIONS, which the iPhone honours).
        self.assertEqual(len(self.costs_by_unit), 72)
        iphone = [unit for unit in self.costs_by_unit if unit[0] == 'iphone']
        ipad = [unit for unit in self.costs_by_unit if unit[0] == 'ipad']
        self.assertEqual(len(iphone), 36)
        self.assertEqual({unit[2] for unit in iphone}, {('portrait',), ('landscape',)})
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
        assigned = snapshot_shards.assign(seconds, self.costs)
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
        self.assertEqual(len(shards), sum(snapshot_shards.split(self.costs_by_unit).values()))
        placed = [unit for _, units, _ in shards for unit in units]
        self.assertEqual(sorted(placed), sorted(self.costs_by_unit))
        for family, units, _ in shards:
            self.assertTrue(units)
            self.assertEqual({unit[0] for unit in units}, {family})

    def test_each_device_gets_the_fewest_shards_that_fit_its_target(self):
        # Run 42577585956: shards estimated at 60 minutes needed 113 or more. Run 43298876957: shards of 73 to 77
        # estimated minutes were cut by the runner at random times (13 of 27). A shard now stays within its device's
        # target, with as few shards (and simulator setups) as that allows.
        plan = json.loads(snapshot_shards.compute())
        self.assertEqual(plan['targetMinutes'], snapshot_shards.TARGET_MINUTES)
        seconds = snapshot_shards.unit_seconds(self.costs_by_unit, self.costs)
        split = snapshot_shards.split(seconds, self.costs)
        for family, count in split.items():
            shards = [shard for shard in plan['shards'] if shard['family'] == family]
            target = plan['targetMinutes'][family]
            self.assertEqual(len(shards), count)
            self.assertTrue(all(shard['estimatedMinutes'] <= target for shard in shards), family)
            if count > 1:
                fewer = snapshot_shards.balance(seconds, family, count - 1)
                self.assertTrue(any(snapshot_shards.estimate(units, wall, self.costs) > target
                                    for units, wall in fewer), family)

    def test_a_device_never_gets_more_shards_than_units(self):
        costs = dict(self.costs, bootFetchMinutes=500)
        seconds = snapshot_shards.unit_seconds(self.costs_by_unit, costs)
        self.assertEqual(snapshot_shards.split(seconds, costs), {'iphone': 36, 'ipad': 36})

    def test_a_shard_is_about_half_an_hour_to_three_quarters_and_the_run_has_72_of_them(self):
        # Owner msg 5033: shorter shards lose less to a cut. The fixed cost per shard (9 minutes to boot and fetch,
        # 2.3 per invocation) puts the floor of an iPhone shard, one orientation of one configuration, at about 42
        # estimated minutes; an iPad shard, one process, is about 26 to 29.
        plan = json.loads(snapshot_shards.compute())
        self.assertEqual(len(plan['shards']), 72)
        for shard in plan['shards']:
            self.assertEqual(len(shard['runs']), 1, shard['id'])
            self.assertEqual(len(shard['invocations']), 1, shard['id'])
            self.assertEqual(len(shard['runs'][0]['orientations']), 1, shard['id'])
            self.assertLessEqual(shard['estimatedMinutes'], 45, shard['id'])
        self.assertLessEqual(max(shard['estimatedMinutes'] for shard in plan['shards'] if shard['family'] == 'ipad'),
                             35)
        self.assertLessEqual(max(shard['timeoutMinutes'] for shard in plan['shards']), 90)

    def test_assignment_ignores_input_order(self):
        expected = snapshot_shards.assign(self.costs_by_unit)
        items = list(self.costs_by_unit.items())
        for seed in range(5):
            random.Random(seed).shuffle(items)
            self.assertEqual(snapshot_shards.assign(dict(items)), expected)

    def test_largest_shard_of_a_device_is_within_a_quarter_of_its_mean(self):
        shards = snapshot_shards.assign(self.costs_by_unit)
        for family in snapshot_matrix.FAMILIES:
            costs = [cost for name, _, cost in shards if name == family]
            self.assertLessEqual(max(costs), 1.25 * sum(costs) / len(costs), family)

    def test_timeouts_are_twice_the_estimate_and_capped(self):
        plan = json.loads(snapshot_shards.compute())
        for shard in plan['shards']:
            self.assertEqual(shard['timeoutMinutes'], min(120, math.ceil(2 * shard['estimatedMinutes'])))
            self.assertLessEqual(shard['timeoutMinutes'], 120)

    def test_plan_names_s01_to_s20_and_the_cost_table(self):
        plan = json.loads(snapshot_shards.compute())
        self.assertEqual([shard['id'] for shard in plan['shards']],
                         [f's{index:02d}' for index in range(1, len(plan['shards']) + 1)])
        self.assertEqual(plan['costSource'], self.costs['source'])
        self.assertEqual(len(plan['costTable']), 64)
        self.assertEqual(plan['workers'], self.costs['workers'])

    def test_the_cost_table_is_measured_on_the_gate(self):
        self.assertEqual(self.costs['source'], 'measured')
        self.assertEqual(self.costs['runId'], '42577585956')
        self.assertEqual(self.costs['workers'], 2)

    def test_a_selection_is_validated_against_the_plan_and_kept_in_plan_order(self):
        # A candidate run may be restricted to some shards (the dispatch input `shards`), by the plan's own ids.
        plan = json.loads(snapshot_shards.compute())
        self.assertEqual(snapshot_shards.select('', plan), [])
        self.assertEqual(snapshot_shards.select(' , ', plan), [])
        self.assertEqual(snapshot_shards.select('s40, s01,s40 ,s72', plan), ['s01', 's40', 's72'])
        for text in ('s73', 's00', 'S01', '1', 's1', 's01;s02', 's01 s02', 's01,sXX'):
            with self.assertRaises(ValueError, msg=text) as raised:
                snapshot_shards.select(text, plan)
            self.assertIn('shard', str(raised.exception))
        with self.assertRaises(ValueError) as raised:
            snapshot_shards.select('s01,s99,s98', plan)
        self.assertIn('s98', str(raised.exception))
        self.assertIn('s99', str(raised.exception))
        self.assertIn('s01 to s72', str(raised.exception))

    def test_the_select_command_prints_the_ids_or_fails_on_an_unknown_one(self):
        script = Path(snapshot_shards.__file__)
        ok = subprocess.run([sys.executable, str(script), '--select', 's19,s01'], capture_output=True, text=True)
        self.assertEqual((ok.returncode, ok.stdout.strip()), (0, 's01,s19'))
        empty = subprocess.run([sys.executable, str(script), '--select', ''], capture_output=True, text=True)
        self.assertEqual((empty.returncode, empty.stdout.strip()), (0, ''))
        bad = subprocess.run([sys.executable, str(script), '--select', 's01,s99'], capture_output=True, text=True)
        self.assertEqual(bad.returncode, 1)
        self.assertIn('s99', bad.stderr)

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
