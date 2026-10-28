"""Single-pass evidence must cover exactly the selected compiled UI tests."""

import copy
import fcntl
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

import environment


def load_runner():
    spec = importlib.util.spec_from_file_location('single_pass', Path(__file__).with_name('run-single-pass.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.runner = load_runner()
        self.native = environment.load_native_gate()
        self.identifiers = ['EhPandaUITests/ExampleTests/testFirst', 'EhPandaUITests/ExampleTests/testSecond']
        self.report = {'errors': [], 'values': [{
            'disabledTests': [], 'testPlan': 'UITests',
            'enabledTests': [{'identifier': value + '()'} for value in self.identifiers],
        }]}

    def test_suite_enumeration_provides_the_actual_expected_count(self):
        self.assertEqual(self.runner.enumerated_tests(self.report, ['EhPandaUITests/ExampleTests']), self.identifiers)

    def test_one_missing_selector_cannot_hide_behind_another_valid_selector(self):
        with self.assertRaisesRegex(RuntimeError, 'selector matched zero'):
            self.runner.enumerated_tests(self.report, ['EhPandaUITests/ExampleTests', 'EhPandaUITests/Missing'])

    def test_filtered_out_methods_are_allowed_but_disabled_requested_methods_fail(self):
        self.report['values'][0]['disabledTests'] = [{'identifier': 'EhPandaUITests/OtherTests/testExcluded()'}]
        self.assertEqual(self.runner.enumerated_tests(self.report, ['EhPandaUITests/ExampleTests']), self.identifiers)
        for selectors in [[], ['EhPandaUITests/ExampleTests', 'EhPandaUITests/OtherTests']]:
            with self.subTest(selectors=selectors), self.assertRaisesRegex(RuntimeError, 'requested test is disabled'):
                self.runner.enumerated_tests(self.report, selectors)
        self.report['values'][0]['disabledTests'] = [{'identifier': self.identifiers[0] + '()'}]
        with self.assertRaisesRegex(RuntimeError, 'both enabled and disabled'):
            self.runner.enumerated_tests(self.report, ['EhPandaUITests/ExampleTests'])

    def test_enumeration_refuses_empty_disabled_duplicate_wrong_plan_and_errors(self):
        variants = []
        for key, value in [('enabledTests', []), ('disabledTests', ['disabled']), ('testPlan', 'AnotherPlan'),
                           ('enabledTests', [{'identifier': self.identifiers[0]}] * 2)]:
            report = copy.deepcopy(self.report)
            report['values'][0][key] = value
            variants.append(report)
        variants += [{'errors': ['discovery failed'], 'values': self.report['values']},
                     {'errors': [], 'values': []}, {'errors': [], 'values': self.report['values'] * 2}]
        for report in variants:
            with self.subTest(report=report), self.assertRaises(RuntimeError):
                self.runner.enumerated_tests(report, [])

    def test_unrequested_methods_and_other_targets_are_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'unrequested'):
            self.runner.enumerated_tests(self.report, [self.identifiers[0]])
        self.report['values'][0]['enabledTests'][0]['identifier'] = 'OtherTarget/ExampleTests/testFirst()'
        with self.assertRaisesRegex(RuntimeError, 'unexpected test target'):
            self.runner.enumerated_tests(self.report, [])

    def test_result_identity_must_match_even_when_the_total_is_correct(self):
        cases = [{'nodeType': 'Test Case', 'nodeIdentifier': value.split('/', 1)[1] + '()', 'result': 'Passed'}
                 for value in self.identifiers]
        self.runner.verify_test_identity(self.native, {'testNodes': cases}, self.identifiers)
        for replacement in [cases[0], {**cases[1], 'nodeIdentifier': 'OtherTests/testOther()'},
                            {**cases[1], 'result': 'Skipped'}]:
            with self.subTest(replacement=replacement), self.assertRaises(RuntimeError):
                self.runner.verify_test_identity(self.native, {'testNodes': [cases[0], replacement]}, self.identifiers)


class NativeGateTests(unittest.TestCase):
    def setUp(self):
        self.native = environment.load_native_gate()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.products = self.directory / 'DerivedData/Build/Products'
        self.products.mkdir(parents=True)
        self.gate = self.native.Gate.__new__(self.native.Gate)
        self.gate.args = SimpleNamespace(derived_data=self.directory / 'DerivedData')
        self.gate.output = self.directory
        self.gate.sources = {}
        self.gate.lifecycle = {'device': 'device'}
        self.gate.test_runs = {}

    def test_preparation_removes_nested_policies_without_changing_the_original(self):
        original = self.products / 'generated.xctestrun'
        data = {'TestPlan': {'Name': 'UITests'}, 'TestConfigurations': [{
            'TestRepetitionPolicy': {'MaximumTestRepetitions': 3},
            'TestTargets': [{'TestRepetitionPolicy': {'TestRepetitionMode': 'retryOnFailure'},
                             'EnvironmentVariables': {'KEEP': 'value'}}],
        }]}
        original.write_bytes(plistlib.dumps(data))
        before = original.read_bytes()
        self.gate.single_pass_run('UITests')
        self.gate.single_pass_run('UITests')  # A prior generated copy is not a second source candidate.
        self.assertEqual(original.read_bytes(), before)
        copy_data = plistlib.loads(self.gate.test_runs['UITests'].read_bytes())
        self.assertFalse(any('TestRepetitionPolicy' in node for node in self.native.nodes(copy_data)))
        self.assertEqual(copy_data['TestConfigurations'][0]['TestTargets'][0]['EnvironmentVariables'], {'KEEP': 'value'})
        evidence = json.loads((self.directory / 'UITests-single-pass.json').read_text())
        self.assertEqual(len(evidence['removed']), 2)

    def test_ambiguous_and_missing_build_products_fail(self):
        with self.assertRaisesRegex(RuntimeError, 'found 0'):
            self.gate.single_pass_run('UITests')
        for name in ['first', 'second']:
            (self.products / f'{name}.xctestrun').write_bytes(plistlib.dumps({'TestPlan': {'Name': 'UITests'}}))
        with self.assertRaisesRegex(RuntimeError, 'found 2'):
            self.gate.single_pass_run('UITests')

    def invoke(self, summary, tree):
        self.gate.test_runs['UITests'] = self.products / 'phase17-UITests.xctestrun'
        (self.directory / 'selected.xcresult').mkdir(exist_ok=True)
        with patch.object(self.native, 'source_hashes', return_value={}), \
                patch.object(self.gate, 'record_simulator_state', return_value='Booted'), \
                patch.object(self.gate, 'export_attachments'), \
                patch.object(self.native, 'result_json', side_effect=[summary, tree]), \
                patch.object(self.native.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            self.gate.run('selected', ['test-without-building'], 'UITests', 'device',
                          ['EhPandaUITests/ExampleTests/testFirst'], 1)
        return run.call_args.args[0]

    def test_native_gate_rejects_zero_wrong_count_skip_failure_and_repetition(self):
        summary = {'totalTestCount': 1, 'passedTests': 1, 'failedTests': 0, 'skippedTests': 0,
                   'expectedFailures': 0, 'devicesAndConfigurations': [{'device': {'deviceId': 'device'}}]}
        command = self.invoke(summary, {'testNodes': []})
        self.assertIn('-xctestrun', command)
        self.assertIn('-derivedDataPath', command)
        self.assertNotIn('-testPlan', command)
        self.assertNotIn('-retry-tests-on-failure', command)
        for key, value in [('totalTestCount', 0), ('totalTestCount', 2), ('passedTests', 0),
                           ('failedTests', 1), ('skippedTests', 1), ('expectedFailures', 1)]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                self.invoke({**summary, key: value}, {})
        with self.assertRaisesRegex(RuntimeError, 'without skips/repetitions'):
            self.invoke(summary, {'children': [{'nodeType': 'Test Repetition'}]})
        with self.assertRaisesRegex(RuntimeError, 'unexpected devices'):
            self.invoke({**summary, 'devicesAndConfigurations': [{'device': {'deviceId': 'other'}}]}, {})


class SimulatorWindowTests(unittest.TestCase):
    def test_preparation_does_not_acquire_a_simulator(self):
        runner = load_runner()
        with tempfile.TemporaryDirectory() as directory:
            gate = SimpleNamespace(output=Path(directory))
            for action in ['build-for-testing', 'test-without-building']:
                with self.subTest(action=action), \
                        patch.object(runner, 'simulator_test_window') as window, \
                        patch.object(runner.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)):
                    runner.run_preparation(gate, action, ['xcodebuild', action])
                    window.assert_not_called()

    def test_same_device_is_exclusive_but_other_devices_are_independent(self):
        runner = load_runner()
        device, other_device = str(uuid.uuid4()), str(uuid.uuid4())
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(runner.tempfile, 'gettempdir', return_value=directory):
            with runner.simulator_test_window(device):
                lock_path = Path(directory) / f'ehpanda-tests-{device}.lock'
                with lock_path.open('a') as competing_lock:
                    with self.assertRaises(BlockingIOError):
                        fcntl.flock(competing_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with runner.simulator_test_window(other_device):
                    self.assertTrue((Path(directory) / f'ehpanda-tests-{other_device}.lock').is_file())

    def test_failure_releases_device_ownership(self):
        runner = load_runner()
        device = str(uuid.uuid4())
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(runner.tempfile, 'gettempdir', return_value=directory):
            with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                with runner.simulator_test_window(device):
                    raise RuntimeError('capture failed')
            with (Path(directory) / f'ehpanda-tests-{device}.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                fcntl.flock(lock, fcntl.LOCK_UN)


if __name__ == '__main__':
    unittest.main()
