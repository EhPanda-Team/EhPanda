"""The pin is explicit input; observations and fresh simulator IDs are outputs."""

from contextlib import contextmanager
import copy
import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import environment


def rendering_pin():
    devices = {}
    for family, model, identifier, hardware, size, scale in (
        ('iphone', 'iPhone Air', 'iPhone-Air', 'iPhone18,4', [420, 912], 3),
        ('ipad', 'iPad Pro 11-inch (M5)', 'iPad-Pro-11-inch-M5-12GB', 'iPad17,2', [834, 1210], 2),
    ):
        orientations = {}
        for orientation, points in (('portrait', size), ('landscape', list(reversed(size)))):
            orientations[orientation] = {
                'points': points, 'pixels': [value * scale for value in points],
                'safeAreaInsets': [24, 0, 20, 0], 'scale': scale,
                'horizontalSizeClass': 2, 'verticalSizeClass': 2,
                'contentSizeCategory': 'UICTContentSizeCategoryL', 'appearance': 1,
                'boldTextEnabled': False, 'legibilityWeight': 0,
                'displayGamut': 1, 'nativeScale': scale,
                'fonts': {'body': {'name': '.SFUI-Regular', 'pointSize': 17, 'lineHeight': 20.3}},
            }
        devices[family] = {
            'model': model, 'deviceTypeIdentifier': 'com.apple.CoreSimulator.SimDeviceType.' + identifier,
            'modelIdentifier': hardware, 'orientations': orientations,
        }
    return {
        'schemaVersion': 1, 'kind': 'rendering-pin',
        'toolchain': {'xcode': 'Xcode 27.0\nBuild version 18A123', 'swift': 'Swift version 6.4 test',
                      'sdkVersion': '27.0'},
        'runtime': {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0',
                    'version': '27.0', 'buildVersion': '24A434'},
        'settings': {'locale': 'en_US', 'timeZone': 'GMT', 'fixedDateUnix': 1735689600,
                     'textSize': 'large', 'fontDesign': 'system', 'animationsEnabled': False},
        'devices': devices,
    }


def inventory(pin):
    runtime = {**pin['runtime'], 'isAvailable': True}
    runtime['buildversion'] = runtime.pop('buildVersion')
    models = [{'name': value['model'], 'identifier': value['deviceTypeIdentifier'],
               'modelIdentifier': value['modelIdentifier']} for value in pin['devices'].values()]
    devices = [{
        'udid': f'fresh-{family}', 'name': value['model'], 'isAvailable': True,
        'deviceTypeIdentifier': value['deviceTypeIdentifier'], 'state': 'Shutdown',
    } for family, value in pin['devices'].items()]
    return {'runtimes': [runtime], 'devicetypes': models, 'devices': {runtime['identifier']: devices}}


class PinContractTests(unittest.TestCase):
    def test_complete_explicit_pin_is_accepted(self):
        pin = rendering_pin()
        before = copy.deepcopy(pin)
        environment.validate_pin(pin)
        self.assertEqual(pin, before)

    def test_matching_rendering_is_accepted(self):
        environment.compare_rendering(rendering_pin(), rendering_pin())

    def test_every_pinned_leaf_is_compared(self):
        # A newly added rendering characteristic cannot silently escape comparison.
        pin = rendering_pin()
        def leaves(value, path=()):
            if isinstance(value, dict):
                for key, child in value.items():
                    yield from leaves(child, (*path, key))
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    yield from leaves(child, (*path, index))
            else:
                yield path, value
        for path, value in leaves(pin):
            with self.subTest(path=path):
                changed = copy.deepcopy(pin)
                parent = changed
                for key in path[:-1]:
                    parent = parent[key]
                parent[path[-1]] = not value if isinstance(value, bool) else (
                    value + 1 if isinstance(value, (int, float)) else value + '-changed')
                with self.assertRaises(environment.EnvironmentMismatch):
                    environment.compare_rendering(pin, changed)

    def test_missing_fields_are_rejected(self):
        for field in rendering_pin():
            with self.subTest(field=field):
                pin = rendering_pin()
                del pin[field]
                with self.assertRaises(environment.EnvironmentMismatch):
                    environment.validate_pin(pin)

    def test_observations_cannot_substitute_for_pin(self):
        with self.assertRaises(environment.EnvironmentMismatch):
            environment.validate_pin({'kind': 'rendering-observations', 'rendering': rendering_pin()})

    def test_unknown_fields_cannot_hide_host_specific_inputs(self):
        for key, value in [('udid', 'old-device'), ('path', '/private/old-run')]:
            with self.subTest(key=key):
                pin = rendering_pin()
                pin['devices']['iphone'][key] = value
                with self.assertRaises(environment.EnvironmentMismatch):
                    environment.validate_pin(pin)

    def test_malformed_geometry_is_rejected(self):
        for key, value in [('scale', 0), ('scale', True), ('pixels', [1260]),
                           ('points', [-420, 912]), ('safeAreaInsets', [0, 0, 0]),
                           ('horizontalSizeClass', 0), ('fonts', {})]:
            with self.subTest(key=key, value=value):
                pin = rendering_pin()
                pin['devices']['iphone']['orientations']['portrait'][key] = value
                with self.assertRaises(environment.EnvironmentMismatch):
                    environment.validate_pin(pin)

    def test_missing_orientation_is_rejected(self):
        pin = rendering_pin()
        del pin['devices']['ipad']['orientations']['landscape']
        with self.assertRaises(environment.EnvironmentMismatch):
            environment.validate_pin(pin)

    def test_mismatched_pixel_rectangle_is_rejected(self):
        pin = rendering_pin()
        pin['devices']['iphone']['orientations']['portrait']['pixels'] = [1260, 2700]
        with self.assertRaises(environment.EnvironmentMismatch):
            environment.validate_pin(pin)

    def test_non_finite_geometry_is_rejected(self):
        for value in [float('nan'), float('inf')]:
            pin = rendering_pin()
            pin['devices']['ipad']['orientations']['landscape']['safeAreaInsets'][0] = value
            with self.assertRaises(environment.EnvironmentMismatch):
                environment.validate_pin(pin)


class DestinationTests(unittest.TestCase):
    def setUp(self):
        self.pin = rendering_pin()
        self.inventory = inventory(self.pin)

    def resolve(self):
        return environment.resolve_destinations(self.inventory, self.pin['runtime'], self.pin['devices'])

    def test_current_ids_are_resolved_from_model_and_runtime(self):
        first = self.resolve()
        self.assertEqual({item['udid'] for item in first.values()}, {'fresh-iphone', 'fresh-ipad'})
        for device in self.inventory['devices'][self.pin['runtime']['identifier']]:
            device['udid'] = 'replacement-' + device['udid']
        self.assertEqual({item['udid'] for item in self.resolve().values()},
                         {'replacement-fresh-iphone', 'replacement-fresh-ipad'})

    def test_same_name_on_wrong_runtime_is_not_used(self):
        self.inventory['devices']['older-runtime'] = self.inventory['devices'].pop(self.pin['runtime']['identifier'])
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()

    def test_missing_runtime_is_rejected(self):
        self.inventory['runtimes'] = []
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()

    def test_changed_runtime_build_is_rejected(self):
        self.inventory['runtimes'][0]['buildversion'] = 'different-build'
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()

    def test_missing_model_is_rejected(self):
        self.inventory['devices'][self.pin['runtime']['identifier']].pop()
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()

    def test_wrong_hardware_identifier_is_rejected(self):
        self.inventory['devicetypes'][0]['modelIdentifier'] = 'other-hardware'
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()

    def test_unavailable_device_is_rejected(self):
        self.inventory['devices'][self.pin['runtime']['identifier']][0]['isAvailable'] = False
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()

    def test_duplicate_matching_devices_are_ambiguous(self):
        devices = self.inventory['devices'][self.pin['runtime']['identifier']]
        devices.append({**devices[0], 'udid': 'duplicate'})
        with self.assertRaises(environment.EnvironmentMismatch):
            self.resolve()


class ImmutableValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.path = self.root / 'explicit-pin.json'
        self.before = json.dumps(rendering_pin(), indent=3).encode() + b'\n'
        self.path.write_bytes(self.before)
        self.observation = {'schemaVersion': 1, 'kind': 'rendering-observations', 'status': 'passed',
                            'rendering': rendering_pin(), 'destinations': {'iphone': {'udid': 'new-phone'}}}

    def test_validation_links_observation_without_rewriting_input(self):
        with patch.object(environment, 'measure_environment', return_value=self.observation) as measure:
            output = self.root / 'validation'
            environment.validate_environment(self.path, output)
        self.assertEqual(self.path.read_bytes(), self.before)
        self.assertEqual(measure.call_args.args[0], output.resolve())
        result = json.loads((output / 'environment.json').read_text())
        self.assertEqual(result['pinSHA256'], hashlib.sha256(self.before).hexdigest())
        self.assertEqual(result['destinations']['iphone']['udid'], 'new-phone')
        self.assertEqual(result['status'], 'passed')

    def test_changed_build_fails_and_retains_separate_observation(self):
        self.observation['rendering']['toolchain']['xcode'] += '-drift'
        with patch.object(environment, 'measure_environment', return_value=self.observation):
            output = self.root / 'failed'
            with self.assertRaises(environment.EnvironmentMismatch):
                environment.validate_environment(self.path, output)
        self.assertEqual(self.path.read_bytes(), self.before)
        result = json.loads((output / 'environment.json').read_text())
        self.assertEqual(result['status'], 'failed')
        self.assertIn('xcode', result['error'])
        self.assertEqual(result['pinSHA256'], hashlib.sha256(self.before).hexdigest())

    def test_missing_or_malformed_pin_fails_before_measurement(self):
        for content in [None, b'{bad json', b'{}']:
            with self.subTest(content=content):
                if self.path.exists():
                    self.path.unlink()
                if content is not None:
                    self.path.write_bytes(content)
                with patch.object(environment, 'measure_environment') as measure:
                    with self.assertRaises(environment.EnvironmentMismatch):
                        environment.validate_environment(self.path, self.root / 'unused')
                measure.assert_not_called()

    def test_output_cannot_contain_or_replace_input(self):
        with patch.object(environment, 'measure_environment') as measure:
            with self.assertRaises(environment.EnvironmentMismatch):
                environment.validate_environment(self.path, self.root)
        self.assertEqual(self.path.read_bytes(), self.before)
        measure.assert_not_called()


class GeometryAttachmentTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.runtime = rendering_pin()['runtime']
        self.device = {'udid': 'fresh-iphone'}
        self.manifest = [{'testIdentifier': 'GeometryTests/testPortraitGeometry()', 'attachments': [{
            'suggestedHumanReadableName': 'phase17-geometry_0.json', 'exportedFileName': 'geometry.json',
            'deviceId': 'fresh-iphone',
        }]}]
        self.data = {'family': 'iphone', 'orientation': 'portrait', 'deviceID': 'fresh-iphone',
                     'stableSamples': 2, 'windowIsAttached': True, 'operatingSystem': 'iOS 27.0 (24A434)'}

    def read(self):
        (self.directory / 'manifest.json').write_text(json.dumps(self.manifest))
        (self.directory / 'geometry.json').write_text(json.dumps(self.data))
        return environment.read_geometry(self.directory, 'iphone', 'portrait', self.device, self.runtime)

    def test_named_actual_measurement_is_attributed_to_requested_device(self):
        data, path = self.read()
        self.assertEqual(data, self.data)
        self.assertEqual(path, self.directory / 'geometry.json')

    def test_missing_named_test_or_attachment_is_rejected(self):
        for manifest in [[], [{'testIdentifier': 'GeometryTests/testPortraitGeometry()', 'attachments': []}]]:
            self.manifest = manifest
            with self.assertRaises(environment.EnvironmentMismatch):
                self.read()

    def test_duplicate_measurement_attachment_is_rejected(self):
        self.manifest[0]['attachments'] *= 2
        with self.assertRaises(environment.EnvironmentMismatch):
            self.read()

    def test_wrong_device_orientation_runtime_or_unsettled_window_is_rejected(self):
        original = self.data.copy()
        for key, value in [('family', 'ipad'), ('orientation', 'landscape'), ('deviceID', 'old-id'),
                           ('stableSamples', 1), ('windowIsAttached', False), ('operatingSystem', 'iOS 26')]:
            with self.subTest(key=key):
                self.data = {**original, key: value}
                with self.assertRaises(environment.EnvironmentMismatch):
                    self.read()

    def test_attachment_cannot_escape_export_directory(self):
        self.manifest[0]['attachments'][0]['exportedFileName'] = '../outside.json'
        with self.assertRaises(environment.EnvironmentMismatch):
            self.read()


class MeasurementOrderTests(unittest.TestCase):
    def test_sorted_pin_still_builds_and_measures_phone_before_tablet(self):
        # A canonical JSON pin sorts "ipad" before "iphone". Input serialization order
        # must never determine execution order or skip the one-time build setup.
        pin = json.loads(json.dumps(rendering_pin(), sort_keys=True))
        sessions = []
        invocations = []
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'measure'
            class Gate:
                def __init__(self, arguments):
                    self.sources = {}
                    self.test_runs = {}
                    arguments.output.mkdir(parents=True)

                @contextmanager
                def simulator_session(self, family, device):
                    sessions.append(family)
                    yield

                def run(self, name, actions, plan, device, *args, **kwargs):
                    if 'test-without-building' in actions and plan not in self.test_runs:
                        raise RuntimeError('Attempted a test before build setup: ' + plan)
                    invocations.append(name)
                    if name.endswith('-geometry'):
                        (output / (name + '.summary.json')).write_text('{"runtimeWarnings": []}')

                def single_pass_run(self, plan):
                    self.test_runs[plan] = output / (plan + '.xctestrun')

            def save_json(path, value):
                path.write_text(json.dumps(value))

            def geometry(directory, family, orientation, device, runtime):
                return ({'modelIdentifier': pin['devices'][family]['modelIdentifier'],
                         'geometry': pin['devices'][family]['orientations'][orientation],
                         'settings': pin['settings'], 'stableSamples': 2, 'windowIsAttached': True},
                        directory / 'geometry.json')

            native = SimpleNamespace(Gate=Gate, save_json=save_json, source_hashes=lambda: {}, ROTATION='Rotation/')
            with patch.object(environment, 'toolchain_identity', return_value=pin['toolchain']), \
                    patch.object(environment.subprocess, 'check_output', return_value=json.dumps(inventory(pin))), \
                    patch.object(environment, 'load_native_gate', return_value=native), \
                    patch.object(environment, 'configure_geometry_run'), \
                    patch.object(environment, 'read_geometry', side_effect=geometry):
                report = environment.measure_environment(output, pin=pin, derived_data=Path(temporary))
            self.assertEqual(sessions, ['iphone', 'ipad'])
            self.assertEqual(invocations[:2], ['geometry-build', 'orientation-build'])
            self.assertEqual(sum(name.endswith('-geometry') for name in invocations), 4)
            self.assertEqual(report['status'], 'passed')


if __name__ == '__main__':
    unittest.main()
