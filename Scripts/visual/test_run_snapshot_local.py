"""The local snapshot runner's argument checks (19-02, 19-10) and its simulator lookup (19-18)."""
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


OTHER = '11111111-1111-1111-1111-111111111111'
DUPLICATE = '22222222-2222-2222-2222-222222222222'
EXACT = '33333333-3333-3333-3333-333333333333'


def device(name, udid):
    return {'name': name, 'udid': udid, 'isAvailable': True}


class SimulatorLookupTests(unittest.TestCase):
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


if __name__ == '__main__':
    unittest.main()
