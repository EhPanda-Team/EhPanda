"""The local snapshot runner's argument checks (19-02, 19-10), which come before any simulator or xcodebuild call."""
from pathlib import Path
import subprocess
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


if __name__ == '__main__':
    unittest.main()
