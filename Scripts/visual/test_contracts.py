"""Matrix identity, coverage and immutable preflight contracts."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import environment

ROOT = Path(__file__).resolve().parents[2]


class ContractsTests(unittest.TestCase):
    def setUp(self):
        self.contracts = importlib.import_module('contracts')
        self.scenarios = [{'id': 'home-populated', 'fixtureID': 'home-finite', 'state': 'populated'}]

    def test_complete_axes_are_unique(self):
        rows = self.contracts.enumerate_coordinates(self.scenarios)
        self.assertEqual(len(rows), 576)
        self.assertEqual(len({row.key for row in rows}), 576)
        for axis, count in [('locale', 6), ('size', 12), ('orientation', 2), ('family', 2), ('theme', 2)]:
            self.assertEqual(len({getattr(row, axis) for row in rows}), count)

    def test_empty_scenarios_rejected(self):
        with self.assertRaises(ValueError):
            self.contracts.enumerate_coordinates([])

    def test_duplicate_scenarios_rejected(self):
        with self.assertRaises(ValueError):
            self.contracts.enumerate_coordinates(self.scenarios * 2)

    def test_unsafe_scenario_identity_rejected(self):
        for value in ['../home', '', 'home/populated']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.contracts.enumerate_coordinates([dict(self.scenarios[0], id=value)])

    def test_unknown_or_noop_filter_rejected(self):
        rows = self.contracts.enumerate_coordinates(self.scenarios)
        for value in ['size=missing', 'unknown=en', '', 'locale=en,locale=de']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.contracts.select_coordinates(rows, value)

    def test_filter_reports_reduced_coverage(self):
        rows = self.contracts.enumerate_coordinates(self.scenarios)
        selected = self.contracts.select_coordinates(rows, 'family=iphone,locale=en,size=large')
        self.assertEqual(len(selected), 4)
        report = self.contracts.coverage(rows, selected)
        self.assertFalse(report['complete'])
        self.assertEqual(report['requested'], 4)
        self.assertEqual(report['possible'], 576)

    def test_outcome_missing_duplicate_and_unrequested_fail(self):
        rows = self.contracts.enumerate_coordinates(self.scenarios)[:2]
        good = [{'coordinate': row.key, 'status': 'captured', 'reason': 'verified'} for row in rows]
        self.contracts.validate_outcomes(rows, good)
        for bad in [good[:1], good * 2, good + [dict(good[0], coordinate='unknown')]]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.contracts.validate_outcomes(rows, bad)

    def test_capture_failure_cannot_be_inapplicable(self):
        rows = self.contracts.enumerate_coordinates(self.scenarios)[:1]
        for status, reason in [('not-applicable', 'capture failed'), ('failed', ''), ('pending', 'waiting')]:
            with self.subTest(status=status), self.assertRaises(ValueError):
                self.contracts.validate_outcomes(rows, [{'coordinate': rows[0].key,
                                                        'status': status, 'reason': reason}])

    def test_explicit_semantic_inapplicability_is_valid(self):
        rows = self.contracts.enumerate_coordinates(self.scenarios)[:1]
        reason = 'Popover state requires a regular horizontal size class'
        outcomes = [{'coordinate': rows[0].key, 'status': 'not-applicable', 'reason': reason}]
        self.contracts.validate_outcomes(rows, outcomes, {rows[0].key: reason})

    def test_zero_native_tests_and_repetition_rejected(self):
        good = {'totalTestCount': 1, 'passedTests': 1, 'failedTests': 0,
                'skippedTests': 0, 'expectedFailures': 0, 'runtimeWarnings': []}
        self.contracts.validate_test_result(good, {'children': []})
        for bad in [dict(good, totalTestCount=0, passedTests=0), dict(good, skippedTests=1),
                    dict(good, runtimeWarnings=['warning'])]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.contracts.validate_test_result(bad, {})
        with self.assertRaises(ValueError):
            self.contracts.validate_test_result(good, {'children': [{'nodeType': 'Repetition'}]})

    def test_fixture_integrity_and_provenance(self):
        metadata = self.contracts.validate_fixtures(ROOT / '.capture/regression', self.scenarios)
        self.assertEqual(metadata['fixtureVersion'], 'phase17-finite-v2')
        self.assertEqual(len(metadata['assets']), 47)

    def test_modified_fixture_rejected(self):
        import shutil
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixtures'
            shutil.copytree(ROOT / '.capture/regression', path)
            (path / 'assets/home/0.png').write_bytes(b'changed')
            with self.assertRaises(ValueError):
                self.contracts.validate_fixtures(path, self.scenarios)

    def test_fixture_path_escape_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            source = json.loads((ROOT / '.capture/regression/manifest.json').read_text())
            source['assets'][0]['path'] = '../secret'
            (path / 'manifest.json').write_text(json.dumps(source))
            with self.assertRaises(ValueError):
                self.contracts.validate_fixtures(path, self.scenarios)


class RunnerPreflightTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('regression_runner', ROOT / 'Scripts/visual/run-regression.py')
        self.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.runner)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.pin = self.directory / 'pin.json'
        self.pin.write_bytes((ROOT / 'Scripts/visual/regression-environment.json').read_bytes())
        self.original = self.pin.read_bytes()
        self.args = self.runner.parser().parse_args([
            '--filter', 'family=iphone,locale=en,size=large,orientation=portrait,theme=light',
            '--mode', 'candidate', '--fixtures', str(ROOT / '.capture/regression'),
            '--environment', str(self.pin), '--output', str(self.directory / 'result')])

    def test_real_validator_drift_stops_fixture_loading_and_dispatch(self):
        rendering = json.loads(self.original)
        rendering['runtime']['buildVersion'] = 'changed'
        with patch.object(environment, 'measure_environment', return_value={'rendering': rendering}), \
                patch.object(self.runner.contracts, 'validate_fixtures') as fixtures, \
                patch.object(self.runner, 'dispatch') as dispatch:
            with self.assertRaises(environment.EnvironmentMismatch):
                self.runner.execute(self.args)
            fixtures.assert_not_called()
            dispatch.assert_not_called()
        self.assertEqual(self.pin.read_bytes(), self.original)
        report = json.loads((self.args.output / 'outcomes.json').read_text())
        self.assertEqual(len(report['outcomes']), 1)
        self.assertEqual(report['outcomes'][0]['status'], 'failed')
        self.assertIn('buildVersion', report['outcomes'][0]['reason'])

    def test_valid_pin_precedes_fixture_loading_and_dispatch(self):
        calls = []
        def measure(*args, **kwargs):
            calls.append('measure')
            return {'rendering': json.loads(self.original)}
        original = self.runner.contracts.validate_fixtures
        def fixtures(*args):
            calls.append('fixtures')
            return original(*args)
        def dispatch(*args):
            calls.append('dispatch')
        with patch.object(environment, 'measure_environment', side_effect=measure), \
                patch.object(self.runner.contracts, 'validate_fixtures', side_effect=fixtures), \
                patch.object(self.runner, 'dispatch', side_effect=dispatch):
            # A dispatcher returning no results must fail even after successful preflight.
            with self.assertRaises(ValueError):
                self.runner.execute(self.args)
        self.assertEqual(calls, ['measure', 'fixtures', 'dispatch'])
        self.assertEqual(self.pin.read_bytes(), self.original)

    def test_missing_pin_stops_before_capture(self):
        self.pin.unlink()
        with patch.object(self.runner, 'dispatch') as dispatch:
            with self.assertRaises(environment.EnvironmentMismatch):
                self.runner.execute(self.args)
            dispatch.assert_not_called()

    def test_interruption_accounts_for_every_requested_coordinate(self):
        self.args.filter = 'family=iphone,locale=en,size=large'
        with patch.object(environment, 'measure_environment',
                          return_value={'rendering': json.loads(self.original)}), \
                patch.object(self.runner, 'dispatch', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                self.runner.execute(self.args)
        report = json.loads((self.args.output / 'outcomes.json').read_text())
        self.assertEqual(len(report['outcomes']), 4)
        self.assertTrue(all(row['status'] == 'failed' and row['reason'] for row in report['outcomes']))


if __name__ == '__main__':
    unittest.main()
