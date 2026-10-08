"""The native marketing runner validates its pin before dispatch and accepts only identical, complete cold frames."""
from contextlib import contextmanager
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import plistlib
import struct
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zlib

import environment
import fixtures

ROOT = environment.ROOT
PIN = ROOT / 'Scripts/visual/regression-environment.json'
COORDINATE = {'screen': 'home', 'set': 'nonexplicit', 'locale': 'en', 'theme': 'dark', 'family': 'iphone'}
MANIFEST = {'fixtureVersion': 'marketing-0123456789abcdef', 'aggregateDigest': 'a' * 64, 'selectionID': 'selection-1'}


def load_runner():
    spec = importlib.util.spec_from_file_location('capture_native', ROOT / 'Scripts/visual/capture-native.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body))


def png(width, height, fill=0, color_type=6, rows=None, trailing=b''):
    channels = 4 if color_type == 6 else 3
    raw = rows if rows is not None else b''.join(
        b'\x00' + bytes([fill]) * (width * channels) for _ in range(height))
    header = struct.pack('>IIBBBBB', width, height, 8, color_type, 0, 0, 0)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(raw))
            + chunk(b'IEND', b'') + trailing)


def diagnostics(**changes):
    value = {'screenID': 'home', 'selectionID': MANIFEST['selectionID'], 'setID': 'nonexplicit',
             'fixtureVersion': MANIFEST['fixtureVersion'], 'galleryIDs': ['1'], 'readiness': 'ready',
             'pendingImages': 0, 'unknownRequests': [], 'blockers': [],
             'rendering': {'language': 'en', 'locale': 'en_US', 'appearance': 'dark', 'textSize': 'large',
                           'family': 'iphone'}}
    value.update(changes)
    return value


def observation(pin):
    return {'schemaVersion': 1, 'kind': 'rendering-observations', 'status': 'passed', 'rendering': pin,
            'destinations': {'iphone': {'udid': 'fresh-phone'}, 'ipad': {'udid': 'fresh-tablet'}}}


class Workspace:
    """A coordinate, a tracked-pin copy and a fixture version directory, all outside the output."""

    def __init__(self, root):
        self.root = root
        self.coordinate = root / 'coordinate.json'
        self.coordinate.write_text(json.dumps(COORDINATE))
        self.pin = root / 'pin.json'
        self.pin.write_bytes(PIN.read_bytes())
        self.original = self.pin.read_bytes()
        self.fixture = root / 'fixtures' / MANIFEST['fixtureVersion']
        self.fixture.mkdir(parents=True)
        (self.fixture / 'selection.json').write_text(json.dumps({'scenes': {'nonexplicit': {}}}))
        self.output = root / 'result'

    def args(self, runner):
        return runner.parser().parse_args([
            '--coordinate', str(self.coordinate), '--fixtures', str(self.fixture),
            '--environment', str(self.pin), '--output', str(self.output)])


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.runner = load_runner()
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.workspace = Workspace(Path(temporary.name))
        self.args = self.workspace.args(self.runner)
        validate = patch.object(fixtures, 'validate_fixtures', return_value=MANIFEST)
        self.validate_fixtures = validate.start()
        self.addCleanup(validate.stop)
        # The build inputs are not under test here; hashing the whole tree for every case would only be slow.
        native = patch.object(environment, 'load_native_gate', return_value=SimpleNamespace(source_hashes=dict))
        native.start()
        self.addCleanup(native.stop)

    def outcomes(self):
        return json.loads((self.workspace.output / 'outcomes.json').read_text())

    def identical_dispatch(self, digests=('f' * 64, 'f' * 64)):
        def dispatch(args, coordinate, observed, source, manifest, report, publish):
            for number, digest in enumerate(digests, 1):
                report['launches'].append({'launch': number, 'status': 'captured',
                                           'capture': {'path': f'launches/{number}/frame.png', 'sha256': digest}})
        return dispatch

    def test_tracked_pin_is_a_valid_pin(self):
        environment.validate_pin(json.loads(PIN.read_text()))

    def test_produced_pin_passes_before_dispatch_without_changing(self):
        calls = []
        def measure(output, pin=None, derived_data=None):
            calls.append('measure')
            return observation(pin)
        dispatch = self.identical_dispatch()
        def recorded(*args):
            calls.append('dispatch')
            dispatch(*args)
        with patch.object(environment, 'measure_environment', side_effect=measure), \
                patch.object(self.runner, 'dispatch', side_effect=recorded):
            report = self.runner.execute(self.args)
        self.assertEqual(calls, ['measure', 'dispatch'])
        self.assertEqual(report['status'], 'captured')
        self.assertTrue(report['identical'])
        self.assertEqual(report['capture']['sha256'], 'f' * 64)
        self.assertEqual(self.workspace.pin.read_bytes(), self.workspace.original)
        check = json.loads((self.workspace.output / 'environment-check/environment.json').read_text())
        self.assertEqual(check['pinSHA256'], hashlib.sha256(self.workspace.original).hexdigest())
        self.assertEqual(check['status'], 'passed')
        self.assertEqual(report['pinSHA256'], check['pinSHA256'])
        self.assertEqual(self.outcomes()['status'], 'captured')

    def test_drift_prevents_dispatch_and_keeps_the_pin(self):
        def runtime(pin):
            pin['runtime']['buildVersion'] = 'changed'
        def scale(pin):
            portrait = pin['devices']['iphone']['orientations']['portrait']
            portrait['scale'] = portrait['nativeScale'] = 2
            portrait['pixels'] = [value * 2 for value in portrait['points']]
        def toolchain(pin):
            pin['toolchain']['xcode'] += '-changed'
        def model(pin):
            pin['devices']['ipad']['modelIdentifier'] = 'iPad0,0'
        for name, drift in [('runtime', runtime), ('scale', scale), ('toolchain', toolchain), ('model', model)]:
            with self.subTest(drift=name):
                self.args.output = self.workspace.output = self.workspace.root / f'drift-{name}'
                measured = json.loads(self.workspace.original)
                drift(measured)
                with patch.object(environment, 'measure_environment', return_value=observation(measured)), \
                        patch.object(self.runner, 'dispatch') as dispatch:
                    with self.assertRaises(environment.EnvironmentMismatch):
                        self.runner.execute(self.args)
                    dispatch.assert_not_called()
                self.assertEqual(self.workspace.pin.read_bytes(), self.workspace.original)
                report = self.outcomes()
                self.assertEqual(report['status'], 'failed')
                self.assertIn('EnvironmentMismatch', report['error'])
                self.assertEqual(report['launches'], [])

    def test_observation_or_malformed_pin_prevents_measurement_and_dispatch(self):
        tracked = json.loads(self.workspace.original)
        for name, content in [('observation', json.dumps(observation(tracked)).encode()),
                              ('malformed', b'{bad json'), ('missing', None)]:
            with self.subTest(pin=name):
                self.args.output = self.workspace.output = self.workspace.root / f'pin-{name}'
                if content is None:
                    self.workspace.pin.unlink(missing_ok=True)
                else:
                    self.workspace.pin.write_bytes(content)
                with patch.object(environment, 'measure_environment') as measure, \
                        patch.object(self.runner, 'dispatch') as dispatch:
                    with self.assertRaises(environment.EnvironmentMismatch):
                        self.runner.execute(self.args)
                    measure.assert_not_called()
                    dispatch.assert_not_called()
                if content is not None:
                    self.assertEqual(self.workspace.pin.read_bytes(), content)

    def test_coordinate_is_exact_before_any_output(self):
        for coordinate in [{**COORDINATE, 'size': 'large'}, {key: COORDINATE[key] for key in list(COORDINATE)[1:]},
                           {**COORDINATE, 'screen': 'favorites'}, {**COORDINATE, 'locale': 'fr'},
                           {**COORDINATE, 'family': 'mac'}, {**COORDINATE, 'set': 'unlisted'}]:
            with self.subTest(coordinate=coordinate):
                self.workspace.coordinate.write_text(json.dumps(coordinate))
                with patch.object(environment, 'validate_environment') as preflight:
                    with self.assertRaises(ValueError):
                        self.runner.execute(self.args)
                    preflight.assert_not_called()
                self.assertFalse(self.workspace.output.exists())

    def test_overlapping_output_is_rejected_before_writing(self):
        for output in [self.workspace.root, self.workspace.fixture / 'result']:
            with self.subTest(output=output):
                self.args.output = output
                with patch.object(environment, 'validate_environment') as preflight:
                    with self.assertRaisesRegex(ValueError, 'separate'):
                        self.runner.execute(self.args)
                    preflight.assert_not_called()
        self.assertFalse((self.workspace.fixture / 'result').exists())

    def test_set_missing_from_the_selection_stops_before_the_environment(self):
        (self.workspace.fixture / 'selection.json').write_text(json.dumps({'scenes': {'explicit': {}}}))
        with patch.object(environment, 'validate_environment') as preflight:
            with self.assertRaisesRegex(ValueError, 'nonexplicit'):
                self.runner.execute(self.args)
            preflight.assert_not_called()
        self.assertEqual(self.outcomes()['status'], 'failed')

    def test_different_cold_frames_fail(self):
        with patch.object(environment, 'measure_environment',
                          side_effect=lambda output, pin, derived_data: observation(pin)), \
                patch.object(self.runner, 'dispatch', side_effect=self.identical_dispatch(('e' * 64, 'f' * 64))):
            with self.assertRaisesRegex(self.runner.CaptureFailure, '2 different frames'):
                self.runner.execute(self.args)
        report = self.outcomes()
        self.assertEqual(report['status'], 'failed')
        self.assertFalse(report['identical'])
        self.assertNotIn('capture', report)

    def test_pin_or_fixture_change_during_capture_fails(self):
        dispatch = self.identical_dispatch()
        def change_pin(*args):
            self.workspace.pin.write_bytes(self.workspace.original + b'\n')
            dispatch(*args)
        for name, side_effect, replacement, message in [
                ('pin', change_pin, MANIFEST, 'pin changed'),
                ('fixture', dispatch, dict(MANIFEST, aggregateDigest='b' * 64), 'Fixture version changed')]:
            with self.subTest(change=name):
                self.workspace.pin.write_bytes(self.workspace.original)
                self.args.output = self.workspace.output = self.workspace.root / f'change-{name}'
                self.validate_fixtures.side_effect = [MANIFEST, replacement]
                with patch.object(environment, 'measure_environment',
                                  side_effect=lambda output, pin, derived_data: observation(pin)), \
                        patch.object(self.runner, 'dispatch', side_effect=side_effect):
                    with self.assertRaisesRegex(ValueError, message):
                        self.runner.execute(self.args)
                self.assertEqual(self.outcomes()['status'], 'failed')


class FrameTests(unittest.TestCase):
    def setUp(self):
        self.runner = load_runner()

    def test_complete_frames_report_their_size(self):
        self.assertEqual(self.runner.png_size(png(4, 3), self.runner.SETTLE_PNG), (4, 3))
        self.assertEqual(self.runner.png_size(png(4, 3, color_type=2), self.runner.FRAME_PNG), (4, 3))

    def test_partial_or_altered_frames_are_rejected(self):
        frame = png(4, 3)
        iend = frame.rindex(b'IEND') - 4
        corrupt = bytearray(frame)
        corrupt[40] ^= 0xFF
        short = b''.join(b'\x00' + bytes(16) for _ in range(2))
        bad_filter = b''.join(b'\x05' + bytes(16) for _ in range(3))
        for name, data in [('truncated', frame[:-20]), ('no end', frame[:iend]), ('corrupt', bytes(corrupt)),
                           ('trailing', png(4, 3, trailing=b'garbage')), ('rgb', png(4, 3, color_type=2)),
                           ('missing rows', png(4, 3, rows=short)), ('filter', png(4, 3, rows=bad_filter)),
                           ('jpeg', b'\xff\xd8\xff' + frame[3:])]:
            with self.subTest(frame=name):
                with self.assertRaises(self.runner.CaptureFailure):
                    self.runner.png_size(data, self.runner.SETTLE_PNG)

    def test_a_marketing_frame_must_be_the_rgb_system_screenshot(self):
        short = b''.join(b'\x00' + bytes(12) for _ in range(2))
        for name, data in [('rgba', png(4, 3)), ('missing rows', png(4, 3, color_type=2, rows=short))]:
            with self.subTest(frame=name):
                with self.assertRaises(self.runner.CaptureFailure):
                    self.runner.png_size(data, self.runner.FRAME_PNG)

    def test_a_frame_of_another_size_is_rejected(self):
        self.runner.verify_frame(png(4, 3, color_type=2), self.runner.FRAME_PNG, [4, 3])
        with self.assertRaisesRegex(self.runner.CaptureFailure, 'pin expects 4x3'):
            self.runner.verify_frame(png(3, 4, color_type=2), self.runner.FRAME_PNG, [4, 3])


class SettleTests(unittest.TestCase):
    def setUp(self):
        self.runner = load_runner()
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.output = Path(temporary.name)
        self.directory = self.output / 'settle'
        self.directory.mkdir()
        interval = patch.object(self.runner, 'SETTLE_INTERVAL', 0)
        interval.start()
        self.addCleanup(interval.stop)

    def screenshots(self, frames):
        queue = list(frames)
        def run(command, **kwargs):
            self.assertEqual(command[:5], ['xcrun', 'simctl', 'io', 'fresh-phone', 'screenshot'])
            self.assertEqual(command[5:7], ['--type=png', '--mask=ignored'])
            Path(command[7]).write_bytes(queue.pop(0))
            return SimpleNamespace(returncode=0, stderr='')
        return patch.object(self.runner.subprocess, 'run', side_effect=run)

    def settle(self):
        return self.runner.settle_frame('fresh-phone', self.directory, [4, 3], self.output)

    def test_the_first_repeated_frame_is_recorded(self):
        with self.screenshots([png(4, 3, 1), png(4, 3, 2), png(4, 3, 2)]):
            result = self.settle()
        self.assertEqual(len(result['frames']), 3)
        self.assertEqual(result['capture']['path'], 'settle/frame-3.png')
        self.assertEqual(result['capture']['sha256'], hashlib.sha256(png(4, 3, 2)).hexdigest())
        self.assertEqual(result['capture']['pixels'], [4, 3])

    def test_wrong_native_size_is_rejected(self):
        with self.screenshots([png(3, 4)]):
            with self.assertRaisesRegex(self.runner.CaptureFailure, 'pin expects 4x3'):
                self.settle()

    def test_a_screen_that_never_holds_still_fails(self):
        frames = [png(4, 3, fill) for fill in range(self.runner.SETTLE_ATTEMPTS)]
        with self.screenshots(frames):
            with self.assertRaisesRegex(self.runner.CaptureFailure, 'never held still'):
                self.settle()

    def test_a_failed_screenshot_fails(self):
        with patch.object(self.runner.subprocess, 'run',
                          return_value=SimpleNamespace(returncode=1, stderr='No devices are booted.')):
            with self.assertRaisesRegex(self.runner.CaptureFailure, 'No devices are booted'):
                self.settle()


class DiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.runner = load_runner()
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / 'state.txt'

    def verify(self, value):
        self.path.write_text(json.dumps(value))
        return self.runner.verify_diagnostics(self.path, COORDINATE, MANIFEST)

    def test_the_coordinate_screen_is_accepted(self):
        self.assertEqual(self.verify(diagnostics()), diagnostics())

    def test_another_screen_content_or_rendering_is_rejected(self):
        rendering = diagnostics()['rendering']
        for change in [{'screenID': 'detail'}, {'setID': 'explicit'}, {'fixtureVersion': 'marketing-other'},
                       {'selectionID': 'other'}, {'readiness': 'loading'}, {'pendingImages': 1},
                       {'unknownRequests': ['GET https://e-hentai.org/']}, {'blockers': ['waiting']},
                       {'rendering': {**rendering, 'appearance': 'light'}},
                       {'rendering': {**rendering, 'family': 'ipad'}},
                       {'rendering': {**rendering, 'textSize': 'accessibilityExtraExtraExtraLarge'}},
                       {'rendering': {**rendering, 'language': 'de'}}]:
            with self.subTest(change=change):
                with self.assertRaises(self.runner.CaptureFailure):
                    self.verify(diagnostics(**change))


XCTESTRUN = {'TestConfigurations': [{'TestTargets': [
    {'BlueprintName': 'EhPandaUITests', 'IsUITestBundle': True, 'EnvironmentVariables': {'TERM': 'dumb'}}]}]}
SUMMARY = {'totalTestCount': 1, 'passedTests': 1, 'failedTests': 0, 'skippedTests': 0, 'expectedFailures': 0,
           'runtimeWarnings': [], 'devicesAndConfigurations': [
               {'device': {'deviceId': 'fresh-phone', 'modelName': 'iPhone Air', 'osBuildNumber': '24A434'}}]}
KEY = 'nonexplicit__home__iphone__en__dark'


class FakeSimulator:
    """The simctl state a run touches: appearance, status bar overrides and the displayed frame."""

    def __init__(self, frames, appearance='light', overrides=(), clear_fails=False):
        self.frames = list(frames)
        self.clear_fails = clear_fails
        self.appearance = appearance
        self.overrides = list(overrides)
        self.foreground = None
        self.commands = []

    def check_output(self, command, text=True):
        self.commands.append(command)
        if command[2:] == ['ui', 'fresh-phone', 'appearance']:
            return self.appearance + '\n'
        if command[2:] == ['status_bar', 'fresh-phone', 'list']:
            return '\n'.join(['Current Status Bar Overrides:', '=============================', *self.overrides]) + '\n'
        raise AssertionError(f'Unexpected command {command}')

    def run(self, command, check=False, capture_output=False, text=False):
        self.commands.append(command)
        if command[2:4] == ['io', 'fresh-phone']:
            Path(command[-1]).write_bytes(self.frames.pop(0) if len(self.frames) > 1 else self.frames[0])
        elif command[2:5] == ['status_bar', 'fresh-phone', 'override']:
            self.overrides = ['Time: ' + command[command.index('--time') + 1]]
        elif command[2:5] == ['status_bar', 'fresh-phone', 'clear']:
            if self.clear_fails:
                raise subprocess.CalledProcessError(1, command)
            self.overrides = []
        elif command[2:5] == ['ui', 'fresh-phone', 'appearance']:
            self.appearance = command[5]
        elif command[2:4] in (['launch', 'fresh-phone'], ['terminate', 'fresh-phone']):
            self.foreground = command[4] if command[2] == 'launch' else None
        else:
            raise AssertionError(f'Unexpected command {command}')
        return SimpleNamespace(returncode=0, stderr='')


class FakeGate:
    """Runs each launch as the gate does: exports the test's attachments, then fails if the test failed."""

    def __init__(self, arguments, test, simulator, summary=SUMMARY):
        self.simulator = simulator
        self.summary = summary
        self.output = arguments.output
        self.output.mkdir(parents=True)
        self.test_runs = {}
        self.runs = []
        self.sessions = []
        self.test = test

    def single_pass_run(self, plan):
        path = self.output / f'{plan}.xctestrun'
        path.write_bytes(plistlib.dumps(XCTESTRUN))
        self.test_runs[plan] = path

    @contextmanager
    def simulator_session(self, family, device):
        self.sessions.append((family, device))
        yield

    def run(self, name, actions, plan, device, tests=(), expected_count=None, cleanup=False, content_size=None):
        self.runs.append((name, tuple(tests), cleanup))
        variables = plistlib.loads(self.test_runs[plan].read_bytes())['TestConfigurations'][0]['TestTargets'][0][
            'EnvironmentVariables']
        if not name.startswith('launch-'):
            self.restore_variables = variables
            return
        if self.simulator.foreground is not None:
            raise RuntimeError(f'{name} started with {self.simulator.foreground} in front')
        attachments, passed = self.test(name, json.loads(variables['EHPANDA_CAPTURE_COORDINATE']))
        directory = self.output / f'{name}-attachments'
        directory.mkdir()
        exported = []
        for index, (attachment, data) in enumerate(attachments):
            extension = 'png' if attachment.endswith('-screen') else 'txt'
            (directory / f'{index}.{extension}').write_bytes(data)
            exported.append({'exportedFileName': f'{index}.{extension}',
                             'suggestedHumanReadableName': f'{attachment}_0_{index:08X}.{extension}'})
        (directory / 'manifest.json').write_text(json.dumps([{'attachments': exported}]))
        if not passed:
            raise RuntimeError(f'{name} exited 65')
        (self.output / f'{name}.summary.json').write_text(json.dumps(self.summary))
        (self.output / f'{name}.tests.json').write_text('{"testNodes": []}')


def capture_test(state=diagnostics(), frames=(png(4, 3, 7, color_type=2),), passed=True):
    """The marketing UI test: it attaches its diagnostics and settled screenshots and passes or fails."""
    def test(name, coordinate):
        if coordinate != COORDINATE:
            raise RuntimeError(f'{name} got {coordinate}')
        attachments = [(f'capture-{KEY}-state', json.dumps(state).encode())]
        attachments += [(f'capture-{KEY}-screen', frame) for frame in frames]
        return attachments, passed
    return test


class DispatchTests(unittest.TestCase):
    def setUp(self):
        self.runner = load_runner()
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.workspace = Workspace(Path(temporary.name))
        self.args = self.workspace.args(self.runner)
        self.args.output = self.workspace.output.resolve()
        self.args.output.mkdir()
        # Frames are tiny here; the pin's model and runtime are the tracked ones SUMMARY reports.
        self.pin = json.loads(self.workspace.original)
        self.pin['devices']['iphone']['orientations']['portrait']['pixels'] = [4, 3]
        self.report = {'launches': [], 'chrome': {}}
        interval = patch.object(self.runner, 'SETTLE_INTERVAL', 0)
        interval.start()
        self.addCleanup(interval.stop)

    def dispatch(self, simulator, test, summary=SUMMARY):
        gates = []
        def gate(arguments):
            gates.append(FakeGate(arguments, test, simulator, summary))
            return gates[-1]
        real = environment.load_native_gate()
        native = SimpleNamespace(Gate=gate, nodes=real.nodes, ROTATION='Rotation/')
        with patch.object(environment, 'load_native_gate', return_value=native), \
                patch.object(environment, 'default_derived_data', return_value=self.workspace.root), \
                patch.object(self.runner.subprocess, 'check_output', side_effect=simulator.check_output), \
                patch.object(self.runner.subprocess, 'run', side_effect=simulator.run):
            try:
                self.runner.dispatch(self.args, copy.deepcopy(COORDINATE), observation(self.pin),
                                     self.workspace.fixture, MANIFEST, self.report, lambda: None)
            finally:
                self.gate = gates[0] if gates else None

    def assert_restored(self, simulator, appearance='light', overrides=()):
        self.assertEqual(simulator.overrides, list(overrides))
        self.assertEqual(simulator.appearance, appearance)
        self.assertEqual(self.gate.runs[-1], ('iphone-restore-portrait', ('Rotation/testRotateToPortrait',), True))
        # The orientation restore runs without any launch's capture parameters.
        self.assertEqual(self.gate.restore_variables, XCTESTRUN['TestConfigurations'][0]['TestTargets'][0][
            'EnvironmentVariables'])

    def test_two_cold_launches_record_identical_frames_and_restore_the_simulator(self):
        simulator = FakeSimulator([png(4, 3, 1), png(4, 3, 2)])
        self.dispatch(simulator, capture_test())
        self.assertEqual(self.gate.sessions, [('iphone', 'fresh-phone')])
        self.assertEqual([run[0] for run in self.gate.runs], ['launch-1', 'launch-2', 'iphone-restore-portrait'])
        self.assertEqual([launch['status'] for launch in self.report['launches']], ['captured', 'captured'])
        frame = png(4, 3, 7, color_type=2)
        for number, launch in enumerate(self.report['launches'], 1):
            self.assertEqual(launch['diagnostics'], diagnostics())
            self.assertEqual(launch['attachments'], f'native/launch-{number}-attachments')
            self.assertEqual(launch['capture'], {'path': f'launches/{number}/frame.png', 'pixels': [4, 3],
                                                 'sha256': hashlib.sha256(frame).hexdigest(), 'bytes': len(frame)})
            self.assertEqual((self.workspace.output / launch['capture']['path']).read_bytes(), frame)
        self.assertRegex(self.report['chrome']['statusBar']['time'], r'^2026-01-01T09:41:00\.000[+-][0-9]{2}:[0-9]{2}$')
        self.assertEqual(self.report['chrome']['statusBar']['applied'],
                         ['Time: ' + self.report['chrome']['statusBar']['time']])
        self.assertTrue(self.report['chrome']['statusBarRestored'])
        override = next(command for command in simulator.commands if command[3:5] == ['fresh-phone', 'override'])
        self.assertEqual(override[7:], list(self.runner.STATUS_BAR))
        # Settings is the first app after the override and is quit before the first capture launch, and simctl
        # screenshots only Settings: every marketing frame is the system screenshot the test attached.
        actions = [command[2] for command in simulator.commands if command[2] in ('launch', 'terminate', 'io')]
        self.assertEqual(actions, ['launch', 'io', 'io', 'io', 'terminate'])
        self.assertEqual([command[4] for command in simulator.commands if command[2] in ('launch', 'terminate')],
                         [self.runner.SETTLE_APP] * 2)
        settle = self.report['chrome']['settleLaunch']
        self.assertEqual(settle['app'], self.runner.SETTLE_APP)
        self.assertEqual(settle['capture']['path'], 'settle/frame-3.png')
        self.assert_restored(simulator)

    def test_a_launch_showing_another_screen_fails_and_still_restores(self):
        simulator = FakeSimulator([png(4, 3)])
        with self.assertRaisesRegex(self.runner.CaptureFailure, 'another screen'):
            self.dispatch(simulator, capture_test(diagnostics(screenID='detail')))
        self.assertEqual(len(self.report['launches']), 1)
        self.assertEqual(self.report['launches'][0]['status'], 'failed')
        self.assertNotIn('capture', self.report['launches'][0])
        self.assert_restored(simulator)

    def test_a_failing_test_fails_its_launch_and_still_restores(self):
        simulator = FakeSimulator([png(4, 3)])
        with self.assertRaisesRegex(RuntimeError, 'launch-1 exited 65'):
            self.dispatch(simulator, capture_test(passed=False))
        self.assertEqual([launch['status'] for launch in self.report['launches']], ['failed'])
        self.assertFalse((self.workspace.output / 'launches/1/frame.png').exists())
        self.assert_restored(simulator)

    def test_a_launch_needs_exactly_one_screenshot(self):
        frame = png(4, 3, 7, color_type=2)
        for count, frames in [(0, ()), (2, (frame, frame))]:
            with self.subTest(screenshots=count):
                self.args.output = self.workspace.root / f'screenshots-{count}'
                self.args.output.mkdir()
                self.report = {'launches': [], 'chrome': {}}
                simulator = FakeSimulator([png(4, 3)])
                with self.assertRaisesRegex(self.runner.CaptureFailure,
                                            f'one capture-{KEY}-screen attachment, found {count}'):
                    self.dispatch(simulator, capture_test(frames=frames))
                self.assert_restored(simulator)

    def test_a_launch_whose_result_has_a_warning_fails(self):
        simulator = FakeSimulator([png(4, 3)])
        with self.assertRaisesRegex(ValueError, 'without warnings'):
            self.dispatch(simulator, capture_test(), {**SUMMARY, 'runtimeWarnings': ['A main-thread hang']})
        self.assertNotIn('capture', self.report['launches'][0])
        self.assert_restored(simulator)

    def test_a_framebuffer_or_wrong_size_screenshot_fails_the_launch(self):
        for name, frame, message in [('rgba', png(4, 3), r"'colorType': 6.*expected .*'colorType': 2"),
                                     ('size', png(3, 4, color_type=2), 'pin expects 4x3')]:
            with self.subTest(frame=name):
                self.args.output = self.workspace.root / f'frame-{name}'
                self.args.output.mkdir()
                self.report = {'launches': [], 'chrome': {}}
                simulator = FakeSimulator([png(4, 3)])
                with self.assertRaisesRegex(self.runner.CaptureFailure, message):
                    self.dispatch(simulator, capture_test(frames=(frame,)))
                self.assert_restored(simulator)

    def test_a_launch_on_another_runtime_fails(self):
        self.pin['runtime']['buildVersion'] = '24A999'
        simulator = FakeSimulator([png(4, 3)])
        with self.assertRaisesRegex(self.runner.CaptureFailure, 'ran on iPhone Air 24A434'):
            self.dispatch(simulator, capture_test())
        self.assert_restored(simulator)

    def test_a_settle_app_that_never_holds_still_fails_before_any_capture_and_restores(self):
        frames = [png(4, 3, fill) for fill in range(self.runner.SETTLE_ATTEMPTS + 1)]
        simulator = FakeSimulator(frames)
        with self.assertRaisesRegex(self.runner.CaptureFailure, 'never held still'):
            self.dispatch(simulator, capture_test())
        self.assertEqual(self.report['launches'], [])
        self.assertEqual([run[0] for run in self.gate.runs], ['iphone-restore-portrait'])
        self.assertIsNone(simulator.foreground)
        self.assert_restored(simulator)

    def test_a_failed_status_bar_clear_still_restores_the_appearance_and_portrait(self):
        simulator = FakeSimulator([png(4, 3)], appearance='dark', clear_fails=True)
        def test(name, coordinate):
            simulator.appearance = 'light'
            return capture_test()(name, coordinate)
        with self.assertRaises(subprocess.CalledProcessError):
            self.dispatch(simulator, test)
        self.assertNotIn('statusBarRestored', self.report['chrome'])
        self.assertEqual(self.report['chrome']['appearanceRestored'], 'dark')
        self.assert_restored(simulator, appearance='dark', overrides=simulator.overrides)
        self.assertTrue(simulator.overrides[0].startswith('Time: 2026-01-01T09:41'))

    def test_existing_overrides_are_never_replaced(self):
        simulator = FakeSimulator([png(4, 3)], overrides=['Battery State: 2, Battery Level: 100'])
        with self.assertRaisesRegex(self.runner.CaptureFailure, 'already carries overrides'):
            self.dispatch(simulator, capture_test())
        self.assertEqual(simulator.overrides, ['Battery State: 2, Battery Level: 100'])
        self.assertEqual(self.gate.runs, [])

    def test_a_dark_simulator_gets_its_appearance_back(self):
        simulator = FakeSimulator([png(4, 3)], appearance='dark')
        def test(name, coordinate):
            simulator.appearance = 'light'
            return capture_test()(name, coordinate)
        self.dispatch(simulator, test)
        self.assert_restored(simulator, appearance='dark')


class ConfigureRunTests(unittest.TestCase):
    def test_the_ui_test_runner_receives_the_coordinate_and_fixture(self):
        runner = load_runner()
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'UITests.xctestrun'
            path.write_bytes(plistlib.dumps(XCTESTRUN))
            runner.configure_run(path, COORDINATE, Path('/fixtures/version'))
            target = plistlib.loads(path.read_bytes())['TestConfigurations'][0]['TestTargets'][0]
            self.assertEqual(target['EnvironmentVariables'], {
                'TERM': 'dumb', 'EHPANDA_CAPTURE_SOURCE': '/fixtures/version',
                'EHPANDA_CAPTURE_COORDINATE': json.dumps(COORDINATE, separators=(',', ':'))})
            hosted = copy.deepcopy(XCTESTRUN)
            hosted['TestConfigurations'][0]['TestTargets'][0]['IsUITestBundle'] = False
            path.write_bytes(plistlib.dumps(hosted))
            with self.assertRaises(runner.CaptureFailure):
                runner.configure_run(path, COORDINATE, Path('/fixtures/version'))


if __name__ == '__main__':
    unittest.main()
