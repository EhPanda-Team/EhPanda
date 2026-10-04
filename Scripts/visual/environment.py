#!/usr/bin/env python3
"""Measure native rendering characteristics and validate an explicit immutable pin."""

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MODELS = {'iphone': 'iPhone Air', 'ipad': 'iPad Pro 11-inch (M5)'}
PORTRAIT_PIXELS = {'iphone': [1260, 2736], 'ipad': [1668, 2420]}
PRODUCERS = [Path(__file__).relative_to(ROOT).as_posix(),
             'AppPackage/Tests/VisualSnapshotTests/GeometryTests.swift',
             'Scripts/verify-full-content-capture.py']


class EnvironmentMismatch(RuntimeError):
    """The requested rendering environment is incomplete or differs from observations."""


def keys(value, expected, context):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise EnvironmentMismatch(f'{context}: expected exactly {sorted(expected)}')


def number(value, context, minimum=0, positive=False):
    if (type(value) not in (int, float) or not math.isfinite(value)
            or value < minimum or (positive and value == 0)):
        raise EnvironmentMismatch(f'{context}: invalid number {value!r}')


def strings(value, expected, context):
    keys(value, expected, context)
    if any(not isinstance(item, str) or not item.strip() for item in value.values()):
        raise EnvironmentMismatch(f'{context}: nonempty strings required')


def validate_pin(pin):
    keys(pin, ['schemaVersion', 'kind', 'toolchain', 'runtime', 'settings', 'devices'], 'pin')
    if type(pin['schemaVersion']) is not int or pin['schemaVersion'] != 1 or pin['kind'] != 'rendering-pin':
        raise EnvironmentMismatch('Expected schemaVersion 1 rendering-pin; observations are not pin inputs')
    strings(pin['toolchain'], ['xcode', 'swift', 'sdkVersion'], 'toolchain')
    strings(pin['runtime'], ['identifier', 'version', 'buildVersion'], 'runtime')
    settings = pin['settings']
    keys(settings, ['locale', 'timeZone', 'fixedDateUnix', 'textSize', 'fontDesign', 'animationsEnabled'], 'settings')
    for key in ['locale', 'timeZone', 'textSize', 'fontDesign']:
        if not isinstance(settings[key], str) or not settings[key]:
            raise EnvironmentMismatch(f'settings.{key}: nonempty string required')
    number(settings['fixedDateUnix'], 'settings.fixedDateUnix')
    if type(settings['animationsEnabled']) is not bool:
        raise EnvironmentMismatch('settings.animationsEnabled must be Boolean')
    keys(pin['devices'], MODELS, 'devices')
    for family, device in pin['devices'].items():
        keys(device, ['model', 'deviceTypeIdentifier', 'modelIdentifier', 'orientations'], family)
        if device['model'] != MODELS[family]:
            raise EnvironmentMismatch(f'{family}: expected model {MODELS[family]}')
        for key in ['deviceTypeIdentifier', 'modelIdentifier']:
            if not isinstance(device[key], str) or not device[key]:
                raise EnvironmentMismatch(f'{family}.{key}: nonempty string required')
        keys(device['orientations'], ['portrait', 'landscape'], family + '.orientations')
        for orientation, geometry in device['orientations'].items():
            context = family + '.' + orientation
            keys(geometry, ['points', 'pixels', 'safeAreaInsets', 'scale', 'horizontalSizeClass',
                            'verticalSizeClass', 'contentSizeCategory', 'appearance', 'boldTextEnabled',
                            'legibilityWeight', 'displayGamut', 'nativeScale', 'fonts'], context)
            for key, length in [('points', 2), ('pixels', 2), ('safeAreaInsets', 4)]:
                values = geometry[key]
                if not isinstance(values, list) or len(values) != length:
                    raise EnvironmentMismatch(f'{context}.{key}: expected {length} values')
                for value in values:
                    number(value, context + '.' + key, positive=key != 'safeAreaInsets')
            for key in ['scale', 'nativeScale']:
                number(geometry[key], context + '.' + key, positive=True)
            for key in ['horizontalSizeClass', 'verticalSizeClass', 'appearance']:
                if type(geometry[key]) is not int or geometry[key] not in (1, 2):
                    raise EnvironmentMismatch(f'{context}.{key}: unresolved trait')
            for key in ['legibilityWeight', 'displayGamut']:
                if type(geometry[key]) is not int:
                    raise EnvironmentMismatch(f'{context}.{key}: integer trait required')
            if type(geometry['boldTextEnabled']) is not bool or not isinstance(geometry['contentSizeCategory'], str):
                raise EnvironmentMismatch(f'{context}: malformed font settings')
            expected = PORTRAIT_PIXELS[family]
            if orientation == 'landscape':
                expected = list(reversed(expected))
            if geometry['pixels'] != expected or geometry['pixels'] != [
                    value * geometry['scale'] for value in geometry['points']]:
                raise EnvironmentMismatch(f'{context}: actual points/scale/pixels disagree with native rectangle')
            fonts = geometry['fonts']
            if not isinstance(fonts, dict) or not fonts:
                raise EnvironmentMismatch(f'{context}.fonts: font observations required')
            for style, font in fonts.items():
                keys(font, ['name', 'pointSize', 'lineHeight'], context + '.fonts.' + style)
                if not isinstance(font['name'], str) or not font['name']:
                    raise EnvironmentMismatch(f'{context}.fonts.{style}: missing font name')
                number(font['pointSize'], context + '.fonts.' + style, positive=True)
                number(font['lineHeight'], context + '.fonts.' + style, positive=True)


def compare_rendering(expected, actual, path='rendering'):
    """Compare every field, including future fields, with a useful first differing path."""
    if isinstance(expected, dict) and isinstance(actual, dict):
        if expected.keys() != actual.keys():
            raise EnvironmentMismatch(f'{path}: field set differs')
        for key in expected:
            compare_rendering(expected[key], actual[key], path + '.' + key)
    elif isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            raise EnvironmentMismatch(f'{path}: array length differs')
        for index, (left, right) in enumerate(zip(expected, actual)):
            compare_rendering(left, right, f'{path}[{index}]')
    elif expected != actual or (isinstance(expected, bool) != isinstance(actual, bool)):
        raise EnvironmentMismatch(f'{path}: pinned {expected!r}, observed {actual!r}')


def resolve_destinations(inventory, runtime, models):
    matches = [item for item in inventory['runtimes']
               if item['identifier'] == runtime['identifier'] and item.get('isAvailable')]
    if len(matches) != 1 or any(matches[0].get('buildversion' if key == 'buildVersion' else key) != value
                                for key, value in runtime.items()):
        raise EnvironmentMismatch('Requested runtime identifier/version/build is unavailable or changed')
    resolved = {}
    for family, model in models.items():
        types = [item for item in inventory['devicetypes']
                 if item['identifier'] == model['deviceTypeIdentifier']]
        if (len(types) != 1 or types[0]['modelIdentifier'] != model['modelIdentifier']
                or types[0]['name'] != model['model']):
            raise EnvironmentMismatch(f'{family}: device model metadata differs from pin')
        devices = [item for item in inventory['devices'].get(runtime['identifier'], [])
                   if item.get('isAvailable') and item['deviceTypeIdentifier'] == model['deviceTypeIdentifier']]
        if len(devices) != 1:
            raise EnvironmentMismatch(f'{family}: expected one available simulator, found {len(devices)}')
        resolved[family] = devices[0]
    return resolved


def load_native_gate():
    # Reuse the verified single-pass invocation, attachment and simulator-lifecycle implementation.
    spec = importlib.util.spec_from_file_location('native_capture_gate', ROOT / 'Scripts/verify-full-content-capture.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def toolchain_identity():
    return {key: subprocess.check_output(command, text=True).strip() for key, command in {
        'xcode': ['xcodebuild', '-version'], 'swift': ['xcrun', 'swift', '--version'],
        'sdkVersion': ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'],
    }.items()}


def default_derived_data():
    settings = json.loads(subprocess.check_output([
        'xcodebuild', '-showBuildSettings', '-json', '-project', 'EhPanda.xcodeproj', '-scheme', 'EhPanda',
        '-destination', 'generic/platform=iOS Simulator',
    ], cwd=ROOT, text=True))
    matches = [item['buildSettings']['BUILD_DIR'] for item in settings if item['target'] == 'EhPanda']
    if len(matches) != 1:
        raise EnvironmentMismatch('Cannot resolve the project DerivedData directory')
    return Path(matches[0]).parents[1]


def configure_geometry_run(path):
    data = plistlib.loads(path.read_bytes())
    native = load_native_gate()
    matches = [node for node in native.nodes(data) if node.get('BlueprintName') == 'VisualSnapshotTests']
    if len(matches) != 1:
        raise EnvironmentMismatch('Expected one app-hosted VisualSnapshotTests configuration')
    target = matches[0]
    if not target.get('IsAppHostedTestBundle'):
        raise EnvironmentMismatch('GeometryTests must run in the real app host')
    target.setdefault('EnvironmentVariables', {})['TZ'] = 'UTC'
    target['CommandLineArguments'] = ['-AppleLanguages', '(en)', '-AppleLocale', 'en_US']
    path.write_bytes(plistlib.dumps(data))


def read_geometry(directory, family, orientation, device, runtime):
    manifest = json.loads((directory / 'manifest.json').read_text())
    test_id = f'GeometryTests/test{orientation.title()}Geometry()'
    tests = [test for test in manifest if test['testIdentifier'] == test_id]
    attachments = [item for test in tests for item in test['attachments']
                   if item['suggestedHumanReadableName'].startswith('phase17-geometry_')]
    if len(tests) != 1 or len(attachments) != 1 or attachments[0]['deviceId'] != device['udid']:
        raise EnvironmentMismatch(f'{family}/{orientation}: missing or misattributed geometry attachment')
    path = directory / attachments[0]['exportedFileName']
    if not path.resolve().is_relative_to(directory.resolve()):
        raise EnvironmentMismatch('Geometry attachment escapes its result directory')
    data = json.loads(path.read_text())
    if (data['family'] != family or data['orientation'] != orientation
            or data['deviceID'] != device['udid'] or data['stableSamples'] < 2
            or data['windowIsAttached'] is not True or runtime['buildVersion'] not in data['operatingSystem']):
        raise EnvironmentMismatch(f'{family}/{orientation}: geometry identity/readiness/runtime mismatch')
    return data, path


def measure_environment(output, pin=None, derived_data=None):
    output = Path(output).resolve()
    if pin is not None:
        validate_pin(pin)
    toolchain = toolchain_identity()
    if pin is not None:
        compare_rendering(pin['toolchain'], toolchain, 'toolchain')
    inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json'], text=True))
    if pin is None:
        runtimes = [item for item in inventory['runtimes'] if item.get('isAvailable')
                    and item.get('platform') == 'iOS' and item['version'] == toolchain['sdkVersion']]
        if len(runtimes) != 1:
            raise EnvironmentMismatch('Expected one available iOS runtime matching the selected simulator SDK')
        runtime = {key: runtimes[0][key] for key in ['identifier', 'version']}
        runtime['buildVersion'] = runtimes[0]['buildversion']
        models = {}
        for family, name in MODELS.items():
            types = [item for item in inventory['devicetypes'] if item['name'] == name]
            if len(types) != 1:
                raise EnvironmentMismatch(f'{family}: model name does not resolve uniquely')
            model = types[0]
            models[family] = {'model': name, 'deviceTypeIdentifier': model['identifier'],
                              'modelIdentifier': model['modelIdentifier']}
    else:
        runtime, models = pin['runtime'], pin['devices']
    destinations = resolve_destinations(inventory, runtime, models)
    native = load_native_gate()
    gate = native.Gate(argparse.Namespace(output=output, derived_data=derived_data or default_derived_data()))
    producer_hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in PRODUCERS}
    native.save_json(output / 'simulators.json', inventory)
    report = {'schemaVersion': 1, 'kind': 'rendering-observations', 'status': 'running',
              'started': datetime.now(timezone.utc).isoformat(), 'destinations': {},
              'producerSources': producer_hashes,
              'rendering': {'schemaVersion': 1, 'kind': 'rendering-pin', 'toolchain': toolchain,
                            'runtime': runtime, 'settings': None, 'devices': {}}}
    try:
        for family, device in destinations.items():
            with gate.simulator_session(family, device['udid']):
                if family == 'iphone':
                    gate.run('geometry-build', ['build-for-testing'], 'FeatureTests', device['udid'], content_size='large')
                    gate.run('orientation-build', ['build-for-testing'], 'UITests', device['udid'])
                    gate.single_pass_run('FeatureTests')
                    gate.single_pass_run('UITests')
                    configure_geometry_run(gate.test_runs['FeatureTests'])
                measured = {key: models[family][key] for key in ['model', 'deviceTypeIdentifier', 'modelIdentifier']}
                measured['orientations'] = {}
                report['rendering']['devices'][family] = measured
                report['destinations'][family] = {'udid': device['udid'], 'measurements': {}}
                try:
                    for orientation in ['portrait', 'landscape']:
                        gate.run(f'{family}-rotate-{orientation}', ['test-without-building'], 'UITests', device['udid'],
                                 [native.ROTATION + f'testRotateTo{orientation.title()}'], 1)
                        name = f'{family}-{orientation}-geometry'
                        gate.run(name, ['test-without-building'], 'FeatureTests', device['udid'],
                                 [f'VisualSnapshotTests/GeometryTests/test{orientation.title()}Geometry'], 1,
                                 content_size='large')
                        summary = json.loads((output / f'{name}.summary.json').read_text())
                        if summary.get('runtimeWarnings'):
                            raise EnvironmentMismatch(f'{name}: test runtime warnings')
                        data, path = read_geometry(output / f'{name}-attachments', family, orientation, device, runtime)
                        if data['modelIdentifier'] != measured['modelIdentifier']:
                            raise EnvironmentMismatch(f'{name}: actual hardware identifier mismatch')
                        if report['rendering']['settings'] is None:
                            report['rendering']['settings'] = data['settings']
                        else:
                            compare_rendering(report['rendering']['settings'], data['settings'], name + '.settings')
                        measured['orientations'][orientation] = data['geometry']
                        report['destinations'][family]['measurements'][orientation] = {
                            'attachment': str(path.relative_to(output)), 'xcresult': name + '.xcresult',
                            'stableSamples': data['stableSamples'], 'windowIsAttached': data['windowIsAttached'],
                        }
                        native.save_json(output / 'environment.json', report)
                finally:
                    gate.run(f'{family}-restore-portrait', ['test-without-building'], 'UITests', device['udid'],
                             [native.ROTATION + 'testRotateToPortrait'], 1, cleanup=True)
        validate_pin(report['rendering'])
        if native.source_hashes() != gate.sources or producer_hashes != {
                path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in PRODUCERS}:
            raise EnvironmentMismatch('Sources changed during geometry measurement')
        report['status'] = 'passed'
        report['completed'] = datetime.now(timezone.utc).isoformat()
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = str(error)
        raise
    finally:
        native.save_json(output / 'environment.json', report)
    return report


def validate_environment(pin_path, output, derived_data=None):
    pin_path, output = Path(pin_path).resolve(), Path(output).resolve()
    if pin_path.is_relative_to(output) or output.exists():
        raise EnvironmentMismatch('Validation needs a fresh output directory separate from its input pin')
    try:
        original = pin_path.read_bytes()
        pin = json.loads(original)
    except (OSError, ValueError) as error:
        raise EnvironmentMismatch(f'Cannot read explicit rendering pin: {error}') from error
    validate_pin(pin)
    digest = hashlib.sha256(original).hexdigest()
    report = {'schemaVersion': 1, 'kind': 'rendering-observations', 'status': 'failed'}
    try:
        report = measure_environment(output, pin=pin, derived_data=derived_data)
        compare_rendering(pin, report['rendering'])
        if pin_path.read_bytes() != original:
            raise EnvironmentMismatch('Input rendering pin changed during validation')
        report['status'] = 'passed'
    except Exception as error:
        if (output / 'environment.json').is_file():
            report = json.loads((output / 'environment.json').read_text())
        report['status'] = 'failed'
        report['error'] = str(error)
        raise
    finally:
        report['pinSHA256'] = digest
        output.mkdir(parents=True, exist_ok=True)
        (output / 'environment.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ['measure', 'validate']:
        command = commands.add_parser(name)
        command.add_argument('--output', required=True, type=Path)
        command.add_argument('--derived-data', type=Path)
        if name == 'validate':
            command.add_argument('--environment', required=True, type=Path)
    arguments = parser.parse_args()
    try:
        if arguments.command == 'measure':
            measure_environment(arguments.output, derived_data=arguments.derived_data)
        else:
            validate_environment(arguments.environment, arguments.output, arguments.derived_data)
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Environment verification failed: {error}\n')
    print(f'Passed: {arguments.output / "environment.json"}')


if __name__ == '__main__':
    main()
