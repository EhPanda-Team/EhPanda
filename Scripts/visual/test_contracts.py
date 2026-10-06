"""Matrix identity, coverage and immutable preflight contracts."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
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

    def test_named_empty_state_enumerates_coordinates_instead_of_zero_tests(self):
        # Registration of an empty UI state is distinct from an absent scenario catalog.
        # The actual tracer catalog remains home-populated; screen expansion is a later plan.
        catalog = [{'id': 'home-empty', 'fixtureID': 'home-finite', 'state': 'empty'}]
        rows = self.contracts.enumerate_coordinates(catalog)
        self.assertEqual(len(rows), 576)
        self.assertEqual({row.scenario for row in rows}, {'home-empty'})
        with self.assertRaises(ValueError):
            self.contracts.enumerate_coordinates([dict(catalog[0], state='')])

    def test_adjacent_equal_fixture_payloads_do_not_collapse_distinct_scenarios(self):
        payload = {'fixtureID': 'home-finite', 'state': 'populated'}
        catalog = [dict(payload, id='home-first'), dict(payload, id='home-second')]
        rows = self.contracts.enumerate_coordinates(catalog)
        self.assertEqual(len(rows), 1152)
        self.assertEqual(len({row.key for row in rows}), 1152)
        self.assertEqual(rows[0].key.removeprefix('home-first'), rows[576].key.removeprefix('home-second'))
        # Repeating an identity is an error, even when adjacent data is equal; it is never silently deduplicated.
        with self.assertRaises(ValueError):
            self.contracts.enumerate_coordinates([catalog[0], catalog[0]])

    def test_enumeration_has_canonical_axis_and_scenario_order(self):
        catalog = [dict(self.scenarios[0], id='home-second'), dict(self.scenarios[0], id='home-first')]
        expected = self.contracts.enumerate_coordinates(catalog)
        for _ in range(3):
            self.assertEqual(self.contracts.enumerate_coordinates(list(reversed(catalog))), expected)
        self.assertEqual([row.key for row in expected[:8]], [
            'home-first__en__xSmall__portrait__iphone__light',
            'home-first__en__xSmall__portrait__iphone__dark',
            'home-first__en__xSmall__portrait__ipad__light',
            'home-first__en__xSmall__portrait__ipad__dark',
            'home-first__en__xSmall__landscape__iphone__light',
            'home-first__en__xSmall__landscape__iphone__dark',
            'home-first__en__xSmall__landscape__ipad__light',
            'home-first__en__xSmall__landscape__ipad__dark',
        ])
        self.assertEqual(expected[8].key, 'home-first__en__small__portrait__iphone__light')
        self.assertEqual(expected[96].key, 'home-first__de__xSmall__portrait__iphone__light')
        self.assertEqual(expected[575].key, 'home-first__zh-Hant__accessibility5__landscape__ipad__dark')
        self.assertEqual(expected[576].key, 'home-second__en__xSmall__portrait__iphone__light')

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
        metadata = self.contracts.validate_fixtures(ROOT / '.capture/regression-v3', self.scenarios)
        self.assertEqual(metadata['fixtureVersion'], 'phase17-finite-v3')
        self.assertEqual(len(metadata['assets']), 47)

    def test_modified_fixture_rejected(self):
        import shutil
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'fixtures'
            shutil.copytree(ROOT / '.capture/regression-v3', path)
            (path / 'assets/home/0.png').write_bytes(b'changed')
            with self.assertRaises(ValueError):
                self.contracts.validate_fixtures(path, self.scenarios)

    def test_fixture_path_escape_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            source = json.loads((ROOT / '.capture/regression-v3/manifest.json').read_text())
            source['assets'][0]['path'] = '../secret'
            (path / 'manifest.json').write_text(json.dumps(source))
            with self.assertRaises(ValueError):
                self.contracts.validate_fixtures(path, self.scenarios)


def read_record(index, frame, read_frame, owned_rows, digest='a', whole=None):
    whole = whole or digest
    return {'sliceIndex': index, 'frame': frame, 'readFrame': read_frame, 'pixels': [1260, 2736],
            'ownedRows': owned_rows,
            'firstPassOwnedSHA256': digest * 64, 'secondPassOwnedSHA256': digest * 64, 'matched': True,
            'firstPassReadSHA256': whole * 64, 'secondPassReadSHA256': whole * 64, 'readMatched': True}


def read_verification_fixture(reads=1):
    """Read 0 is the native rect; read 1 owns 300 pt below it and keeps 192 pt of upper context at 3x."""
    records = [read_record(0, '{{0, 0}, {420, 912}}', '{{0, 0}, {420, 912}}', [0, 2736])]
    if reads == 2:
        records.append(read_record(1, '{{0, 912}, {420, 300}}', '{{0, 720}, {420, 912}}', [576, 1476], 'b', 'c'))
    geometry = {'displayScale': 3, 'renderReadVerificationPasses': 2, 'outputSize': [420, 912 + 300 * (reads - 1)],
                'renderSlices': [{'frame': read['frame'], 'readFrame': read['readFrame'], 'contextFrame': None}
                                 for read in records],
                'renderReadVerifications': copy.deepcopy(records)}
    ledger = {'status': 'passed', 'requestedPasses': 2, 'displayScale': 3,
              'failedSliceIndex': None, 'reads': copy.deepcopy(records)}
    return geometry, ledger


def settle_fixture(slices=1):
    passes = [{'pass': index, 'elapsedMilliseconds': 120 * index, 'ownedSHA256': ['a' * 64] * slices,
               'changedSliceIndices': None if index == 1 else []} for index in range(1, 7)]
    passes[0]['ownedSHA256'] = ['f' * 64] * slices
    passes[1]['changedSliceIndices'] = list(range(slices))
    return {'status': 'settled', 'stableSpanMilliseconds': 500, 'maximumPasses': 40, 'passes': passes,
            'acceptedPass': 6, 'settledMilliseconds': 512}


class NativeReadVerificationTests(unittest.TestCase):
    def setUp(self):
        self.native = environment.load_native_gate()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.geometry, self.ledger = read_verification_fixture()

    def verify(self):
        (self.directory / 'render-read-verification.json').write_text(json.dumps(self.ledger))
        self.native.Gate.verify_read_verification(self.geometry, self.directory, 'coordinate')

    def mutate_read(self, index, key, value):
        """Changes one field of a two-read fixture in both the ledger and geometry's copy of it."""
        self.geometry, self.ledger = read_verification_fixture(2)
        self.ledger['reads'][index][key] = value
        self.geometry['renderReadVerifications'] = copy.deepcopy(self.ledger['reads'])

    def test_complete_matching_reads_are_accepted(self):
        self.verify()
        self.geometry, self.ledger = read_verification_fixture(2)
        self.verify()

    def test_changed_context_rows_are_evidence_not_failure(self):
        self.mutate_read(1, 'secondPassReadSHA256', 'd' * 64)
        self.ledger['reads'][1]['readMatched'] = False
        self.geometry['renderReadVerifications'] = copy.deepcopy(self.ledger['reads'])
        self.verify()

    def test_missing_or_incomplete_ledger_is_rejected(self):
        with self.assertRaises((FileNotFoundError, RuntimeError)):
            self.native.Gate.verify_read_verification(self.geometry, self.directory, 'coordinate')
        for key, value in [('status', 'verifying'), ('requestedPasses', 1), ('failedSliceIndex', 0),
                           ('reads', []), ('displayScale', 2)]:
            with self.subTest(key=key):
                self.geometry, self.ledger = read_verification_fixture()
                self.ledger[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()

    def test_false_or_malformed_matching_claim_is_rejected(self):
        cases = [(0, 'secondPassOwnedSHA256', 'b' * 64), (1, 'secondPassOwnedSHA256', 'd' * 64),
                 (1, 'secondPassOwnedSHA256', None), (1, 'matched', False), (1, 'firstPassOwnedSHA256', 'invalid'),
                 (1, 'secondPassReadSHA256', None), (1, 'readMatched', None), (1, 'readMatched', False),
                 (0, 'pixels', [0, 2736]), (0, 'pixels', [1260, 2735]), (1, 'sliceIndex', 0)]
        for index, key, value in cases:
            with self.subTest(index=index, key=key, value=value):
                self.mutate_read(index, key, value)
                with self.assertRaises(RuntimeError):
                    self.verify()

    def test_whole_read_match_flag_must_agree_with_its_digests(self):
        self.mutate_read(1, 'secondPassReadSHA256', 'd' * 64)
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_owned_rows_must_match_read_geometry(self):
        for index, rows in [(1, [576, 1475]), (1, [575, 1475]), (1, [0, 2736]), (1, None), (0, [0, 2735]),
                            (0, [1, 2736])]:
            with self.subTest(index=index, rows=rows):
                self.mutate_read(index, 'ownedRows', rows)
                with self.assertRaises(RuntimeError):
                    self.verify()
        for key in ['ownedRows', 'firstPassReadSHA256', 'readMatched']:
            with self.subTest(missing=key):
                self.geometry, self.ledger = read_verification_fixture(2)
                del self.ledger['reads'][1][key]
                self.geometry['renderReadVerifications'] = copy.deepcopy(self.ledger['reads'])
                with self.assertRaises(RuntimeError):
                    self.verify()

    def test_native_read_gates_its_whole_read(self):
        self.mutate_read(0, 'firstPassReadSHA256', 'e' * 64)
        self.ledger['reads'][0]['secondPassReadSHA256'] = 'e' * 64
        self.geometry['renderReadVerifications'] = copy.deepcopy(self.ledger['reads'])
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_owned_rows_must_partition_the_output(self):
        self.geometry, self.ledger = read_verification_fixture(2)
        self.geometry['outputSize'] = [420, 1213]
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_geometry_and_read_evidence_must_agree(self):
        for key, value in [('renderReadVerificationPasses', 1), ('renderSlices', []),
                           ('renderReadVerifications', [])]:
            with self.subTest(key=key):
                self.geometry, self.ledger = read_verification_fixture()
                self.geometry[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
        self.geometry, self.ledger = read_verification_fixture()
        self.geometry['renderSlices'][0]['readFrame'] = '{{0, 8}, {420, 912}}'
        with self.assertRaises(RuntimeError):
            self.verify()


class NativeFullContentSettleTests(unittest.TestCase):
    def setUp(self):
        self.native = environment.load_native_gate()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.geometry = read_verification_fixture(2)[0]
        self.ledger = settle_fixture(2)

    def verify(self):
        (self.directory / 'full-content-settle.json').write_text(json.dumps(self.ledger))
        self.native.Gate.verify_full_content_settle(self.geometry, self.directory, 'coordinate')

    def test_accepted_run_is_valid(self):
        self.verify()

    def test_missing_ledger_is_rejected(self):
        with self.assertRaises((FileNotFoundError, RuntimeError)):
            self.native.Gate.verify_full_content_settle(self.geometry, self.directory, 'coordinate')

    def test_unsettled_or_inconsistent_ledger_is_rejected(self):
        cases = [('status', 'settling'), ('acceptedPass', 5), ('acceptedPass', None), ('settledMilliseconds', 499),
                 ('settledMilliseconds', None), ('stableSpanMilliseconds', 400), ('maximumPasses', 41),
                 ('passes', [])]
        for key, value in cases:
            with self.subTest(key=key, value=value):
                self.ledger = settle_fixture(2)
                self.ledger[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()

    def test_pass_records_must_be_complete_and_consistent(self):
        def last_pass_changed(passes):
            passes[-1]['ownedSHA256'] = ['b' * 64, 'a' * 64]
            passes[-1]['changedSliceIndices'] = [0]
        def wrong_changes(passes):
            passes[2]['changedSliceIndices'] = [1]
        def misnumbered(passes):
            passes[3]['pass'] = 7
        def earlier_time(passes):
            passes[4]['elapsedMilliseconds'] = 0
        def missing_digest(passes):
            passes[5]['ownedSHA256'] = ['a' * 64]
        def malformed_digest(passes):
            passes[5]['ownedSHA256'] = ['A' * 64, 'a' * 64]
        def first_has_changes(passes):
            passes[0]['changedSliceIndices'] = []
        for mutation in [last_pass_changed, wrong_changes, misnumbered, earlier_time, missing_digest,
                         malformed_digest, first_has_changes]:
            with self.subTest(mutation=mutation.__name__):
                self.ledger = settle_fixture(2)
                mutation(self.ledger['passes'])
                with self.assertRaises(RuntimeError):
                    self.verify()


class NativeSourceHashTests(unittest.TestCase):
    def test_uncommitted_build_inputs_are_hashed_and_ignored_files_are_not(self):
        native = environment.load_native_gate()
        files = {
            'AppPackage/Sources/Tracked.swift': b'tracked',
            'AppPackage/Sources/Untracked.swift': b'untracked',
            'AppPackage/.build/Ignored.swift': b'ignored',
            'App/Untracked.swift': b'app',
            'EhPandaUITests/Untracked.swift': b'ui',
            'Scripts/verify-full-content-capture.py': b'gate',
            'Scripts/Unrelated.py': b'unrelated',
            '.swiftlint.yml': b'rules',
            '.gitignore': b'.build\n',
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path, data in files.items():
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_bytes(data)
            subprocess.run(['git', 'init', '-q'], cwd=root, check=True)
            subprocess.run(['git', 'add', '.gitignore', 'AppPackage/Sources/Tracked.swift'], cwd=root, check=True)
            with patch.object(native, 'ROOT', root):
                hashes = native.source_hashes()
        expected = ['.swiftlint.yml', 'App/Untracked.swift', 'AppPackage/Sources/Tracked.swift',
                    'AppPackage/Sources/Untracked.swift', 'EhPandaUITests/Untracked.swift',
                    'Scripts/verify-full-content-capture.py']
        self.assertEqual(sorted(hashes), expected)
        for path in expected:
            self.assertEqual(hashes[path], hashlib.sha256(files[path]).hexdigest())


class NativeContentSizeTests(unittest.TestCase):
    def setUp(self):
        self.native = environment.load_native_gate()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.gate = self.native.Gate.__new__(self.native.Gate)
        self.gate.output = Path(self.temporary.name)

    def test_documented_names_accept_native_readback_spelling(self):
        pairs = [('extra-small', 'extra-Small'), ('small', 'Small'), ('medium', 'medium'), ('large', 'large'),
                 ('extra-large', 'extra-large'), ('extra-extra-large', 'extra-extra-large'),
                 ('extra-extra-extra-large', 'extra-extra-extra-large'),
                 ('accessibility-medium', 'accessibility-medium'), ('accessibility-large', 'accessibility-large'),
                 ('accessibility-extra-large', 'accessibility-extra-large'),
                 ('accessibility-extra-extra-large', 'accessibility-extra-extra-large'),
                 ('accessibility-extra-extra-extra-large', 'accessibility-extra-extra-extra-large')]
        # Restore accepts the original spelling read from the device, too.
        for requested, observed in pairs + [('Small', 'Small'), ('extra-Small', 'extra-Small')]:
            with self.subTest(requested=requested), patch.object(self.native.subprocess, 'run', side_effect=[
                    subprocess.CompletedProcess([], 0, '', ''),
                    subprocess.CompletedProcess([], 0, observed + '\n', '')]):
                self.gate.set_content_size('coordinate', 'resolved-device', requested)
                report = json.loads((self.gate.output / 'coordinate.content-size.json').read_text())
                self.assertTrue(report['matched'])
                self.assertEqual(report['requested'], requested)
                self.assertEqual(report['observed'], observed)

    def test_wrong_or_unavailable_category_is_rejected(self):
        for observed in ['Small', 'large', 'accessibility-medium', '', 'unknown', 'unsupported', 'extra_small']:
            with self.subTest(observed=observed), patch.object(self.native.subprocess, 'run', side_effect=[
                    subprocess.CompletedProcess([], 0, '', ''),
                    subprocess.CompletedProcess([], 0, observed, '')]):
                with self.assertRaisesRegex(RuntimeError, 'does not match'):
                    self.gate.set_content_size('coordinate', 'resolved-device', 'extra-small')
                report = json.loads((self.gate.output / 'coordinate.content-size.json').read_text())
                self.assertFalse(report['matched'])

    def test_set_or_readback_failure_is_rejected_even_when_spelling_matches(self):
        for set_code, read_code in [(1, 0), (0, 1)]:
            with self.subTest(set_code=set_code, read_code=read_code), \
                    patch.object(self.native.subprocess, 'run', side_effect=[
                        subprocess.CompletedProcess([], set_code, '', 'set diagnostic'),
                        subprocess.CompletedProcess([], read_code, 'extra-Small', 'read diagnostic')]):
                with self.assertRaises(subprocess.CalledProcessError):
                    self.gate.set_content_size('coordinate', 'resolved-device', 'extra-small')
                report = json.loads((self.gate.output / 'coordinate.content-size.json').read_text())
                self.assertFalse(report['matched'])
                self.assertEqual(report['exitCode'], set_code)
                self.assertEqual(report['readbackExitCode'], read_code)


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
            '--mode', 'candidate', '--fixtures', str(ROOT / '.capture/regression-v3'),
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

    def test_empty_filter_fails_before_native_preflight(self):
        self.args.filter = ''
        with patch.object(environment, 'validate_environment',
                          side_effect=AssertionError('Empty filter reached native preflight')) as preflight:
            with self.assertRaisesRegex(ValueError, 'filter'):
                self.runner.execute(self.args)
            preflight.assert_not_called()
        self.assertFalse(self.args.output.exists())

    def test_empty_catalog_fails_before_native_preflight(self):
        catalog = self.directory / 'empty-catalog.json'
        catalog.write_text('[]')
        with patch.object(self.runner, 'SCENARIOS', catalog), \
                patch.object(environment, 'validate_environment') as preflight:
            with self.assertRaisesRegex(ValueError, 'named executable scenario'):
                self.runner.execute(self.args)
            preflight.assert_not_called()
        self.assertFalse(self.args.output.exists())

    def test_identical_pixels_keep_separate_requested_outcomes(self):
        self.args.filter = 'family=iphone,locale=en,size=large,orientation=portrait'
        artifact = {'sha256': 'identical-pixel-digest', 'pixels': [1260, 2736]}
        def dispatch(args, requested, report, publish):
            for row in requested:
                publish({'coordinate': row.key, 'status': 'captured', 'reason': 'controlled equal pixels',
                         'artifacts': [artifact]})
        with patch.object(environment, 'measure_environment',
                          return_value={'rendering': json.loads(self.original)}), \
                patch.object(self.runner, 'dispatch', side_effect=dispatch):
            report = self.runner.execute(self.args)
        self.assertEqual(report['status'], 'passed')
        self.assertEqual(report['counts']['captured'], 2)
        self.assertEqual([row['coordinate'] for row in report['outcomes']], [
            'home-populated__en__large__portrait__iphone__light',
            'home-populated__en__large__portrait__iphone__dark',
        ])
        self.assertEqual([row['artifacts'] for row in report['outcomes']], [[artifact], [artifact]])

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

    def test_named_archive_preserves_its_top_directory(self):
        import struct
        coordinate = self.runner.contracts.enumerate_coordinates(
            [{'id': 'home-populated', 'fixtureID': 'home-finite', 'state': 'populated'}])[0]
        directory = self.directory / 'attachments'
        root = directory / 'archive' / 'phase17-matrix-random'
        root.mkdir(parents=True)
        configuration = {'geometry': {'pixels': [1260, 2736]}}
        acceptance = {'configuration': configuration, 'status': 'captured', 'deviceID': 'current-device',
                      'itemCensus': {f'Visual Home Gallery {i}': 1 for i in range(1, 7)}}
        (directory / 'manifest.json').write_text(json.dumps([{
            'testIdentifier': 'VisualMatrixTests/testSelectedCoordinate()', 'attachments': [{
                'suggestedHumanReadableName': 'phase17-matrix_0.zip', 'deviceId': 'current-device',
                'exportedFileName': 'archive.zip'}]}]))
        (root / 'acceptance.json').write_text(json.dumps(acceptance))
        for name in ['native-viewport-parity.json', 'visible-viewport-freeze-parity.json']:
            (root / name).write_text('{"matched": true}')
        traits = {'horizontal': 1, 'vertical': 2}
        geometry, ledger = read_verification_fixture()
        geometry['sizeClasses'] = {
            key: traits for key in ['sceneAtViewport', 'windowAtViewport', 'sceneCurrent', 'windowCurrent']}
        (root / 'geometry.json').write_text(json.dumps(geometry))
        ledger_path = root / 'render-read-verification.json'
        ledger_path.write_text(json.dumps(ledger))
        settle_path = root / 'full-content-settle.json'
        settle_path.write_text(json.dumps(settle_fixture()))
        for name in ['viewport', 'frozen-viewport', 'full-content']:
            header = bytes.fromhex('89504e470d0a1a0a0000000d49484452') + struct.pack('>II', 1260, 2736)
            (root / f'capture.{name}.png').write_bytes(header)
        result = self.runner.read_capture(directory, coordinate, configuration, 'current-device')
        self.assertEqual(result['coordinate'], coordinate.key)
        self.assertEqual(len(result['artifacts']), 3)
        ledger_path.unlink()
        with self.assertRaises((FileNotFoundError, RuntimeError)):
            self.runner.read_capture(directory, coordinate, configuration, 'current-device')
        ledger['reads'][0]['secondPassOwnedSHA256'] = 'b' * 64
        ledger_path.write_text(json.dumps(ledger))
        with self.assertRaises(RuntimeError):
            self.runner.read_capture(directory, coordinate, configuration, 'current-device')
        ledger_path.write_text(json.dumps(read_verification_fixture()[1]))
        settle_path.write_text(json.dumps(dict(settle_fixture(), status='settling')))
        with self.assertRaises(RuntimeError):
            self.runner.read_capture(directory, coordinate, configuration, 'current-device')
        settle_path.write_text(json.dumps(settle_fixture()))
        (root.parent / 'acceptance.json').write_text(json.dumps(acceptance))
        with self.assertRaises(ValueError):
            self.runner.read_capture(directory, coordinate, configuration, 'current-device')

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

    def test_pin_change_during_capture_fails_the_run(self):
        def dispatch(args, requested, report, publish):
            self.pin.write_bytes(self.original + b'\n')
            for row in requested:
                publish({'coordinate': row.key, 'status': 'captured', 'reason': 'controlled capture'})
        with patch.object(environment, 'measure_environment',
                          return_value={'rendering': json.loads(self.original)}), \
                patch.object(self.runner, 'dispatch', side_effect=dispatch):
            with self.assertRaisesRegex(ValueError, 'pin changed'):
                self.runner.execute(self.args)
        report = json.loads((self.args.output / 'outcomes.json').read_text())
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['counts']['captured'], 1)

    def test_valid_replacement_fixture_during_capture_fails_the_run(self):
        manifest = self.runner.contracts.validate_fixtures(self.args.fixtures, json.loads(
            self.runner.SCENARIOS.read_text()))
        replacement = dict(manifest, aggregateDigest='replacement-valid-fixture-digest')
        def dispatch(args, requested, report, publish):
            for row in requested:
                publish({'coordinate': row.key, 'status': 'captured', 'reason': 'controlled capture'})
        with patch.object(environment, 'measure_environment',
                          return_value={'rendering': json.loads(self.original)}), \
                patch.object(self.runner.contracts, 'validate_fixtures', side_effect=[manifest, replacement]), \
                patch.object(self.runner, 'dispatch', side_effect=dispatch):
            with self.assertRaisesRegex(ValueError, 'fixture.*changed'):
                self.runner.execute(self.args)

    def test_native_source_changes_during_preflight_or_capture_fail(self):
        native = environment.load_native_gate()
        for stage in ['preflight', 'capture']:
            with self.subTest(stage=stage):
                self.args.output = self.directory / stage
                hashes = [{'source.swift': 'original'}]
                if stage == 'capture':
                    hashes.append(hashes[0])
                hashes.append({'source.swift': 'changed'})
                def dispatch(args, requested, report, publish):
                    for row in requested:
                        publish({'coordinate': row.key, 'status': 'captured', 'reason': 'controlled capture'})
                with patch.object(environment, 'measure_environment',
                                  return_value={'rendering': json.loads(self.original)}), \
                        patch.object(environment, 'load_native_gate', return_value=native), \
                        patch.object(native, 'source_hashes', side_effect=hashes), \
                        patch.object(self.runner, 'dispatch', side_effect=dispatch) as dispatch_mock:
                    with self.assertRaisesRegex(ValueError, 'Native capture sources changed'):
                        self.runner.execute(self.args)
                    if stage == 'preflight':
                        dispatch_mock.assert_not_called()


if __name__ == '__main__':
    unittest.main()
