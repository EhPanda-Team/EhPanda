"""The local snapshot runner's argument checks (19-02, 19-10), its simulator lookup (19-18) and its measuring mode
(19-20)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent / 'run-snapshot-local.sh'


class RunSnapshotLocalTests(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run(['bash', str(SCRIPT), *args], capture_output=True, text=True, timeout=30)

    def test_ipad_landscape_refuses_clones(self):
        # 19-10: parallel-testing clones boot in portrait whatever the turned iPad shows, so every landscape picture
        # would fail geometry; the run is refused before anything starts.
        result = self.run_script('--device', 'pad', '--orientation', 'landscape', '--workers', '2', '--config',
                                 'en-large', '--classes', 'AppWideSnapshotTests', '--mode', 'candidate', '--out',
                                 '/nonexistent/out')
        self.assertEqual(result.returncode, 2)
        self.assertIn('clones boot in portrait', result.stderr)

    def test_parallel_testing_is_disabled_without_workers(self):
        # SnapshotMatrix.xctestplan marks VisualSnapshotTests parallelizable; without --workers the local script must
        # pass `-parallel-testing-enabled NO` so xcodebuild does not spawn unconfigured clones on its own.
        text = SCRIPT.read_text()
        self.assertIn('PARALLEL=(-parallel-testing-enabled NO)', text)

    def test_the_measuring_mode_replaces_the_mode(self):
        # 19-20: `--measure-heights` is a mode of its own, so naming a mode as well is refused before anything starts.
        result = self.run_script('--device', 'phone', '--config', 'en-large', '--classes', 'SettingsSnapshotTests',
                                 '--mode', 'candidate', '--measure-heights', '--out', '/nonexistent/out')
        self.assertEqual(result.returncode, 2)
        self.assertIn('--measure-heights replaces --mode', result.stderr)

    def test_the_measuring_mode_cannot_be_named_as_a_mode(self):
        result = self.run_script('--device', 'phone', '--config', 'en-large', '--classes', 'SettingsSnapshotTests',
                                 '--mode', 'measure', '--out', '/nonexistent/out')
        self.assertEqual(result.returncode, 2)


OTHER = '11111111-1111-1111-1111-111111111111'
DUPLICATE = '22222222-2222-2222-2222-222222222222'
EXACT = '33333333-3333-3333-3333-333333333333'


def device(name, udid):
    return {'name': name, 'udid': udid, 'isAvailable': True}


class StubbedRunnerCase(unittest.TestCase):
    """The runner runs with stub `xcrun`, `xcodebuild` and `pgrep` first on `PATH`: nothing touches a simulator."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.arguments = self.root / 'xcodebuild-arguments'
        self.devices = self.root / 'devices.json'
        self.stub('xcrun', f'if [ "$2" = list ]; then cat "{self.devices}"; fi')
        self.stub('pgrep', 'exit 1')
        self.stub('xcodebuild', f'echo "$@" >>"{self.arguments}"\necho "Executed 0 tests"')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)


class SimulatorLookupTests(StubbedRunnerCase):
    def run_script(self, devices, *extra):
        self.devices.write_text(json.dumps({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0': devices}}))
        environment = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}')
        return subprocess.run(
            ['bash', str(SCRIPT), '--device', 'phone', '--config', 'en-large', '--classes', 'AppWideSnapshotTests',
             '--mode', 'candidate', '--out', str(self.root / 'out'), *extra],
            capture_output=True, text=True, timeout=60, env=environment)

    def test_a_prefix_match_is_not_a_match(self):
        result = self.run_script([device('EhPanda iPhone Air (other)', OTHER)])
        self.assertEqual(result.returncode, 2)
        self.assertIn('No simulator named EhPanda iPhone Air.', result.stderr)
        self.assertFalse(self.arguments.exists())

    def test_a_named_simulator_is_the_destination_and_diagnostics_are_off(self):
        result = self.run_script(
            [device('EhPanda iPhone Air', EXACT), device('EhPanda iPhone Air (other)', OTHER)],
            '--simulator', 'EhPanda iPhone Air (other)')
        self.assertNotEqual(result.returncode, 2, result.stderr)
        arguments = self.arguments.read_text()
        self.assertIn(f'-destination platform=iOS Simulator,id={OTHER}', arguments)
        self.assertIn('-collect-test-diagnostics never', arguments)

    def test_two_simulators_with_one_name_are_refused(self):
        result = self.run_script([device('EhPanda iPhone Air', EXACT), device('EhPanda iPhone Air', DUPLICATE)])
        self.assertEqual(result.returncode, 2)
        self.assertIn('Several simulators named EhPanda iPhone Air.', result.stderr)
        self.assertFalse(self.arguments.exists())


class MeasuringModeTests(StubbedRunnerCase):
    """The measuring run's summary reads `heights.jsonl`; the stub `xcodebuild` writes it where the test host would."""

    def run_measuring(self, heights):
        body = (f'echo "$@" >>"{self.arguments}"\n'
                f'echo "$TEST_RUNNER_EHPANDA_SNAPSHOT_MODE" >"{self.root / "mode"}"\n'
                'echo "Executed 5 tests"\necho "** TEST SUCCEEDED **"\n')
        if heights is not None:
            written = self.root / 'heights.jsonl'
            written.write_text(''.join(json.dumps(line) + '\n' for line in heights))
            body += f'cp "{written}" "$TEST_RUNNER_EHPANDA_SNAPSHOT_OUTPUT/heights.jsonl"\n'
        self.stub('xcodebuild', body)
        self.devices.write_text(json.dumps({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [
            device('EhPanda iPhone Air', EXACT)]}}))
        environment = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}')
        return subprocess.run(
            ['bash', str(SCRIPT), '--device', 'phone', '--config', 'en-large', '--classes', 'SettingsSnapshotTests',
             '--measure-heights', '--out', str(self.root / 'out')],
            capture_output=True, text=True, timeout=60, env=environment)

    def line(self, key, status, **fields):
        return {'key': key, 'status': status, 'neededPoints': None, 'screenPoints': None, 'steps': 0, 'reason': None,
                **fields}

    def test_the_run_selects_the_measuring_mode_and_counts_each_status(self):
        result = self.run_measuring([self.line('a', 'measured', neededPoints=912, screenPoints=912),
                                     self.line('b', 'measured', neededPoints=1200, screenPoints=912, steps=1),
                                     self.line('c', 'notApplicable')])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'mode').read_text().strip(), 'measure')
        self.assertIn('measured=2', result.stdout)
        self.assertIn('notApplicable=1', result.stdout)
        self.assertIn('cannot-cover=0', result.stdout)

    def test_a_scroll_view_that_does_not_grow_is_a_finding_not_a_failure(self):
        result = self.run_measuring([self.line('a', 'measured', neededPoints=912, screenPoints=912),
                                     self.line('b', 'cannot-cover', reason='cannot-cover:UIScrollView')])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('cannot-cover=1', result.stdout)

    def test_an_error_or_a_page_that_never_converged_fails_the_run(self):
        for status in ('error', 'did-not-converge'):
            with self.subTest(status=status):
                result = self.run_measuring([self.line('a', 'measured', neededPoints=912, screenPoints=912),
                                             self.line('b', status)])
                self.assertEqual(result.returncode, 1)
                self.assertIn(f'{status}=1', result.stdout)

    def test_a_run_without_heights_fails(self):
        result = self.run_measuring(None)
        self.assertEqual(result.returncode, 1)

    def test_an_empty_heights_file_fails(self):
        result = self.run_measuring([])
        self.assertEqual(result.returncode, 1)

    def test_an_earlier_runs_heights_are_not_read_as_this_ones(self):
        out = self.root / 'out'
        out.mkdir()
        (out / 'heights.jsonl').write_text(json.dumps(self.line('stale', 'measured', neededPoints=1)) + '\n')
        result = self.run_measuring(None)
        self.assertEqual(result.returncode, 1)
        self.assertFalse((out / 'heights.jsonl').exists())


if __name__ == '__main__':
    unittest.main()
