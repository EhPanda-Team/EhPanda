"""The Live Text recorder saves only the reader's own recognition of the flow page, recorded on the pinned iPhone."""
from contextlib import contextmanager
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import environment
import fixtures
from test_fixtures import FixtureTestCase, live_text_record

ROOT = environment.ROOT
PIN = ROOT / 'Scripts/visual/regression-environment.json'
KEY = 'nonexplicit__reading-live-text__iphone__en__light'
XCTESTRUN = {'TestConfigurations': [{'TestTargets': [
    {'BlueprintName': 'EhPandaUITests', 'IsUITestBundle': True, 'EnvironmentVariables': {'TERM': 'dumb'}}]}]}


def load_recorder():
    spec = importlib.util.spec_from_file_location('record_live_text', ROOT / 'Scripts/visual/record-live-text.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def recognition(record):
    """The diagnostics' Live Text for what `record` holds, as a recording launch reports it."""
    return {'gid': record['gid'], 'page': record['page'], 'source': 'recognition',
            'recognitionLanguages': record['recognitionLanguages'], 'groups': record['groups']}


def diagnostics(manifest, live_text, **changes):
    value = {'screenID': 'reading-live-text', 'selectionID': manifest['selectionID'], 'setID': 'nonexplicit',
             'fixtureVersion': manifest['fixtureVersion'], 'galleryIDs': ['101'], 'page': 4, 'readiness': 'ready',
             'pendingImages': 0, 'unknownRequests': [], 'blockers': [],
             'rendering': {'language': 'en', 'locale': 'en_US', 'appearance': 'light', 'textSize': 'large',
                           'family': 'iphone'},
             'liveText': live_text}
    value.update(changes)
    return value


class RecordingTestCase(FixtureTestCase):
    """An acquired fixture output and a valid record of its flow's Live Text page."""

    def setUp(self):
        super().setUp()
        self.recorder = load_recorder()
        self.target, _ = self.acquire()
        self.manifest = fixtures.validate_fixtures(self.target)
        self.record = live_text_record(self.manifest, recordedOn={'model': 'iPhone Air', 'runtimeBuild': '24A434'})
        self.flow = self.selection['scenes']['nonexplicit']['flow']


class RecordTests(RecordingTestCase):
    def test_the_reader_recognition_becomes_a_record_of_its_page_image(self):
        record = self.recorder.live_text_record(diagnostics(self.manifest, recognition(self.record)), self.flow,
                                                self.manifest, self.record['recordedOn'])
        self.assertEqual(record, self.record)

    def test_anything_but_the_reader_recognition_of_the_flow_page_is_refused(self):
        live_text = recognition(self.record)
        for name, value in [('none', None), ('replayed', {**live_text, 'source': 'fixture'}),
                            ('other page', {**live_text, 'page': 5}), ('other gallery', {**live_text, 'gid': '102'}),
                            ('no groups', {**live_text, 'groups': []}),
                            ('empty line', {**live_text, 'groups': [{**live_text['groups'][0], 'blocks': [
                                {**live_text['groups'][0]['blocks'][0], 'text': ''}]}]})]:
            with self.subTest(live_text=name):
                with self.assertRaises(ValueError):
                    self.recorder.live_text_record(diagnostics(self.manifest, value), self.flow, self.manifest,
                                                   self.record['recordedOn'])

    def test_a_page_without_its_image_cannot_be_recorded(self):
        flow = {**self.flow, 'liveTextPage': 40, 'gallery': '101'}
        live_text = {**recognition(self.record), 'page': 40}
        with self.assertRaisesRegex(ValueError, 'no image of page 40'):
            self.recorder.live_text_record(diagnostics(self.manifest, live_text), flow, self.manifest,
                                           self.record['recordedOn'])


class FakeGate:
    """Runs the recording as the gate does: exports the test's attachments, then fails if the test failed."""

    def __init__(self, arguments, state, passed, summary):
        self.output = arguments.output
        self.output.mkdir(parents=True)
        self.state, self.passed, self.summary = state, passed, summary
        self.test_runs, self.runs, self.sessions = {}, [], []

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
        if name != 'record':
            self.restore_variables = variables
            return
        self.coordinate = json.loads(variables['EHPANDA_CAPTURE_COORDINATE'])
        self.source = variables['EHPANDA_CAPTURE_SOURCE']
        directory = self.output / 'record-attachments'
        directory.mkdir()
        (directory / '0.txt').write_text(json.dumps(self.state))
        (directory / 'manifest.json').write_text(json.dumps([{'attachments': [
            {'exportedFileName': '0.txt', 'suggestedHumanReadableName': f'live-text-recording-{KEY}-state_0_0.txt'}]}]))
        if not self.passed:
            raise RuntimeError('record exited 65')
        (self.output / 'record.summary.json').write_text(json.dumps(self.summary))
        (self.output / 'record.tests.json').write_text('{"testNodes": []}')


class FakeSimulator:
    def __init__(self, appearance='dark'):
        self.appearance = appearance

    def check_output(self, command, text=True):
        if command[2:] != ['ui', 'fresh-phone', 'appearance']:
            raise AssertionError(f'Unexpected command {command}')
        return self.appearance + '\n'

    def run(self, command, check=False, capture_output=False, text=False):
        if command[2:5] != ['ui', 'fresh-phone', 'appearance']:
            raise AssertionError(f'Unexpected command {command}')
        self.appearance = command[5]


class ExecuteTests(RecordingTestCase):
    def setUp(self):
        super().setUp()
        self.pin = self.directory / 'pin.json'
        self.pin.write_bytes(PIN.read_bytes())
        self.rendering = json.loads(self.pin.read_text())
        self.summary = {'totalTestCount': 1, 'passedTests': 1, 'failedTests': 0, 'skippedTests': 0,
                        'expectedFailures': 0, 'runtimeWarnings': [], 'devicesAndConfigurations': [{'device': {
                            'deviceId': 'fresh-phone', 'modelName': self.rendering['devices']['iphone']['model'],
                            'osBuildNumber': self.rendering['runtime']['buildVersion']}}]}
        self.evidence = self.directory / 'evidence'

    def execute(self, state, passed=True, simulator=None):
        simulator = simulator or FakeSimulator()
        gates = []
        def gate(arguments):
            gates.append(FakeGate(arguments, state, passed, self.summary))
            return gates[-1]
        real = environment.load_native_gate()
        native = SimpleNamespace(Gate=gate, nodes=real.nodes, ROTATION='Rotation/', source_hashes=dict)
        observed = {'pinSHA256': hashlib.sha256(self.pin.read_bytes()).hexdigest(), 'rendering': self.rendering,
                    'destinations': {'iphone': {'udid': 'fresh-phone'}, 'ipad': {'udid': 'fresh-tablet'}}}
        args = self.recorder.parser().parse_args(['--fixtures', str(self.output), '--set', 'nonexplicit',
                                                  '--environment', str(self.pin), '--output', str(self.evidence)])
        clock = iter(['2026-10-09T01:00:00+00:00', '2026-10-09T01:05:00+00:00', '2026-10-09T01:06:00+00:00'])
        capture = self.recorder.load_capture()
        with patch.object(environment, 'load_native_gate', return_value=native), \
                patch.object(environment, 'validate_environment', return_value=observed), \
                patch.object(environment, 'default_derived_data', return_value=self.directory), \
                patch.object(self.recorder, 'load_capture', return_value=capture), \
                patch.object(self.recorder.subprocess, 'check_output', side_effect=simulator.check_output), \
                patch.object(capture.subprocess, 'run', side_effect=simulator.run):
            try:
                return self.recorder.execute(args, clock=lambda: next(clock))
            finally:
                self.gate = gates[0] if gates else None
                self.simulator = simulator

    def outcomes(self):
        return json.loads((self.evidence / 'outcomes.json').read_text())

    def test_a_recording_publishes_a_version_holding_the_reader_recognition(self):
        report = self.execute(diagnostics(self.manifest, recognition(self.record)))
        self.assertEqual(report['status'], 'recorded')
        self.assertEqual(self.outcomes()['status'], 'recorded')
        current = fixtures.resolve_fixtures(self.output / 'current')
        self.assertEqual(current.name, report['publishedVersion'])
        manifest = fixtures.validate_fixtures(current)
        entry, = [entry for entry in manifest['assets'] if entry['kind'] == 'liveText']
        self.assertEqual(entry['retrievedAt'], '2026-10-09T01:05:00+00:00')
        self.assertEqual(json.loads((current / entry['path']).read_text()), self.record)
        self.assertEqual((report['groups'], report['lines']), (2, 3))
        # The recording ran once on the pinned iPhone in English and light appearance, then put the simulator back.
        self.assertEqual(self.gate.sessions, [('iphone', 'fresh-phone')])
        self.assertEqual(self.gate.coordinate, {'screen': 'reading-live-text', 'set': 'nonexplicit', 'locale': 'en',
                                                'theme': 'light', 'family': 'iphone'})
        self.assertEqual(self.gate.source, str(self.target.resolve()))
        self.assertEqual([run[0] for run in self.gate.runs], ['record', 'iphone-restore-portrait'])
        self.assertEqual(self.simulator.appearance, 'dark')
        self.assertEqual(report['chrome'], {'appearanceRestored': 'dark'})

    def test_a_failed_or_unverified_recording_publishes_nothing_and_restores(self):
        for name, state, passed, message in [
                ('failed test', diagnostics(self.manifest, recognition(self.record)), False, 'exited 65'),
                ('another screen', diagnostics(self.manifest, recognition(self.record), screenID='reading'), True,
                 'another screen'),
                ('replayed', diagnostics(self.manifest, {**recognition(self.record), 'source': 'fixture'}), True,
                 'no recognition')]:
            with self.subTest(recording=name):
                self.evidence = self.directory / f'evidence-{name}'
                with self.assertRaisesRegex(Exception, message):
                    self.execute(copy.deepcopy(state), passed)
                self.assertEqual(fixtures.resolve_fixtures(self.output / 'current'), self.target.resolve())
                self.assertEqual(self.outcomes()['status'], 'failed')
                self.assertEqual(self.gate.runs[-1][0], 'iphone-restore-portrait')
                self.assertEqual(self.simulator.appearance, 'dark')

    def test_a_recording_on_another_runtime_publishes_nothing(self):
        self.summary['devicesAndConfigurations'][0]['device']['osBuildNumber'] = '24A999'
        with self.assertRaisesRegex(Exception, 'ran on'):
            self.execute(diagnostics(self.manifest, recognition(self.record)))
        self.assertEqual(fixtures.resolve_fixtures(self.output / 'current'), self.target.resolve())

    def test_overlapping_output_is_rejected_before_writing(self):
        self.evidence = self.output / 'evidence'
        with self.assertRaisesRegex(ValueError, 'separate'):
            self.execute(diagnostics(self.manifest, recognition(self.record)))
        self.assertFalse(self.evidence.exists())
        self.assertEqual(sorted(os.listdir(self.output)), sorted(['.lock', 'current', 'versions']))


if __name__ == '__main__':
    unittest.main()
