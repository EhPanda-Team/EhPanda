"""The infra classifier of the hosted screenshot runs (19-04, run 42475531683)."""
import contextlib
import io
from pathlib import Path
import tempfile
import unittest

import snapshot_infra

# Lines as `xcodebuild` wrote them in run 42475531683's kept logs.
SHUTTING_DOWN = '''Testing failed:
\tUnable to lookup in current state: Shutting Down
\tEhPanda encountered an error (Failed to install or launch the test runner. (Underlying Error: Unable to lookup \
in current state: Shutting Down))
'''
BOOT = '''Testing failed:
\tEhPanda encountered an error (Failed to prepare device 'Clone 3 of EhPanda measure' for impending launch. \
(Underlying Error: Timed out trying to boot simulator after waiting 60.00s.))
'''
CONNECTION = '''Testing failed:
\tEhPanda encountered an error (Early unexpected exit, operation never finished bootstrapping - no restart will be \
attempted. (Underlying Error: Lost pending connection to the test runner before launch.))
'''
SERVER = ('IDELaunchReport: Launching VisualSnapshotTests Finished with error: The operation couldn\u2019t be '
          'completed. (Mach error -308 - (ipc/mig) server died)\n')
# Run 42533872440's compare at 3: every test reported (exit 65 for two changed pictures), then the recovered service.
RECOVERED_SERVER = """Test case 'FirstLaunchSnapshotTests.testAgewallUnticked()' failed on 'Clone 1' (20.1 seconds)

Test session results, code coverage, and logs:
\t/Users/runner/Library/Developer/Xcode/DerivedData/EhPanda/Logs/Test/Test-EhPanda.xcresult

Failing tests:
\tFirstLaunchSnapshotTests.testAgewallUnticked()

** TEST EXECUTE FAILED **

} (error = Error Domain=NSMachErrorDomain Code=-308 "(ipc/mig) server died")
"""
# The same service failure in a run the watchdog stopped: xcodebuild never reached its summary.
INTERRUPTED_SERVER = """} (error = Error Domain=NSMachErrorDomain Code=-308 "(ipc/mig) server died")
** BUILD INTERRUPTED **
"""
TEST_FAILURE = '''Test case 'ToplistsSnapshotTests.testGrid()' failed on 'Clone 1 of EhPanda measure' (0.000 seconds)
Failing tests:
\tToplistsSnapshotTests.testGrid()
** TEST EXECUTE FAILED **
'''


class SnapshotInfraTests(unittest.TestCase):
    def test_each_simulator_failure_of_the_run_is_infra(self):
        self.assertEqual(snapshot_infra.classify(SHUTTING_DOWN, 65), 'clone-shutting-down')
        self.assertEqual(snapshot_infra.classify(BOOT, 65), 'boot-timeout')
        self.assertEqual(snapshot_infra.classify(CONNECTION, 65), 'runner-connection')
        self.assertEqual(snapshot_infra.classify(SERVER, 143), 'simulator-service')

    def test_the_startup_watchdog_is_infra(self):
        log = 'Testing started\nwatchdog: no test started after 20 minutes\n'
        self.assertEqual(snapshot_infra.classify(log, 143), 'no-test-started')

    def test_a_failed_or_hung_test_is_not_infra(self):
        self.assertIsNone(snapshot_infra.classify(TEST_FAILURE, 65))
        self.assertIsNone(snapshot_infra.classify("Test case 'A.b()' passed\nwatchdog: stopped x after 45 minutes\n",
                                                  143))

    def test_a_recovered_service_is_not_infra_when_every_test_reported(self):
        self.assertIsNone(snapshot_infra.classify(RECOVERED_SERVER, 65))
        self.assertEqual(snapshot_infra.classify(INTERRUPTED_SERVER, 143), 'simulator-service')
        # A summary that names a failure that cost tests is still infra.
        lost = 'Testing failed:\n\tEhPanda encountered an error\n' + RECOVERED_SERVER
        self.assertEqual(snapshot_infra.classify(lost, 65), 'simulator-service')

    def test_other_failures_stay_infra_after_a_summary(self):
        self.assertEqual(snapshot_infra.classify(SHUTTING_DOWN + '** TEST EXECUTE FAILED **\n', 65),
                         'clone-shutting-down')

    def test_a_test_has_begun_when_the_log_or_the_results_say_so(self):
        self.assertTrue(snapshot_infra.started("Test case 'A.b()' passed\n", ''))
        # Run 42533872440: pictures written, no `Test case` line in the log.
        self.assertTrue(snapshot_infra.started('Testing started\n', '{"key": "a"}\n{"key": "b"}\n'))
        self.assertFalse(snapshot_infra.started('Testing started\n', ''))
        self.assertFalse(snapshot_infra.started('Testing started\n', '{"key": "a"}\n\n', baseline=1))
        self.assertTrue(snapshot_infra.started('Testing started\n', '{"key": "a"}\n{"key": "b"}\n', baseline=1))

    def test_command_line_started(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'xcodebuild.log'
            results = Path(directory) / 'results.jsonl'
            log.write_text('Testing started\n')
            self.assertEqual(snapshot_infra.main(['--started', str(log), str(results)]), 1)
            results.write_text('{"key": "a"}\n')
            self.assertEqual(snapshot_infra.main(['--started', str(log), str(results)]), 0)
            self.assertEqual(snapshot_infra.main(['--started', str(log), str(results), '--baseline', '1']), 1)

    def test_a_successful_invocation_is_never_infra(self):
        self.assertIsNone(snapshot_infra.classify(BOOT, 0))

    def test_command_line_prints_the_reason(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'xcodebuild.log'
            log.write_text(SHUTTING_DOWN)
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(snapshot_infra.main(['--status', '65', str(log)]), 0)
            self.assertEqual(output.getvalue(), 'clone-shutting-down\n')
            self.assertEqual(snapshot_infra.main(['--status', '0', str(log)]), 1)
            self.assertEqual(snapshot_infra.main(['--status', '65', str(Path(directory) / 'missing.log')]), 1)


if __name__ == '__main__':
    unittest.main()
