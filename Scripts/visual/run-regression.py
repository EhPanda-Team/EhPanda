#!/usr/bin/env python3
"""Run every requested hosted regression coordinate with an immutable native rendering pin."""
import argparse
from dataclasses import asdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import subprocess

import contracts
import environment

ROOT = environment.ROOT
SCENARIOS = ROOT / 'AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json'
REFERENCES = ROOT / 'AppPackage/Tests/VisualSnapshotTests/__Snapshots__/VisualMatrixTests'
TEST = 'VisualSnapshotTests/VisualMatrixTests/testSelectedCoordinate'
CONTENT_SIZES = dict(zip(contracts.AXES['size'], (
    'extra-small', 'small', 'medium', 'large', 'extra-large', 'extra-extra-large', 'extra-extra-extra-large',
    'accessibility-medium', 'accessibility-large', 'accessibility-extra-large',
    'accessibility-extra-extra-large', 'accessibility-extra-extra-extra-large')))
LOCALES = {'en': 'en_US', 'de': 'de_DE', 'ja': 'ja_JP', 'ko': 'ko_KR', 'zh-Hans': 'zh_CN', 'zh-Hant': 'zh_TW'}
PRODUCERS = [Path(__file__), Path(contracts.__file__), Path(environment.__file__), SCENARIOS,
             ROOT / 'AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift']


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    selection = result.add_mutually_exclusive_group(required=True)
    selection.add_argument('--all', action='store_true')
    selection.add_argument('--filter', help='Comma-separated axis=value terms; always declares reduced coverage')
    result.add_argument('--mode', choices=['candidate', 'compare'], required=True)
    for name in ['output', 'environment', 'fixtures']:
        result.add_argument('--' + name, type=Path, required=True)
    return result


def save(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    temporary.replace(path)


def fingerprint(root):
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(root.rglob('*')) if path.is_file()} if root.exists() else {}


def configure_run(path, coordinate, args, report):
    native = environment.load_native_gate()
    data = plistlib.loads(path.read_bytes())
    targets = [item for item in native.nodes(data) if item.get('BlueprintName') == 'VisualSnapshotTests']
    if len(targets) != 1 or not targets[0].get('IsAppHostedTestBundle'):
        raise ValueError('Expected exactly one genuine app-hosted visual target')
    configuration = {
        'coordinate': asdict(coordinate), 'key': coordinate.key, 'mode': args.mode,
        'fixtures': str(args.fixtures.resolve()), 'references': str(REFERENCES / coordinate.key),
        'pinSHA256': report['pinSHA256'], 'fixtureDigest': report['fixtureDigest'],
        'localeIdentifier': LOCALES[coordinate.locale],
        'geometry': report['rendering']['devices'][coordinate.family]['orientations'][coordinate.orientation],
    }
    targets[0].setdefault('EnvironmentVariables', {}).update(
        TZ='UTC', EHPANDA_VISUAL_COORDINATE=json.dumps(configuration, separators=(',', ':')))
    targets[0]['CommandLineArguments'] = ['-AppleLanguages', f'({coordinate.locale})',
                                        '-AppleLocale', LOCALES[coordinate.locale]]
    path.write_bytes(plistlib.dumps(data))
    return configuration


def read_capture(directory, coordinate, configuration, device):
    manifest = json.loads((directory / 'manifest.json').read_text())
    tests = [row for row in manifest if row['testIdentifier'] == 'VisualMatrixTests/testSelectedCoordinate()']
    attachments = [item for row in tests for item in row['attachments']
                   if item['suggestedHumanReadableName'].startswith('phase17-matrix_')]
    if len(tests) != 1 or len(attachments) != 1 or attachments[0]['deviceId'] != device:
        raise ValueError(f'{coordinate.key}: missing or misattributed capture attachment')
    archive = contracts.contained(directory, attachments[0]['exportedFileName'])
    extracted = archive.with_suffix('')
    acceptances = list(extracted.rglob('acceptance.json'))
    if len(acceptances) != 1:
        raise ValueError(f'{coordinate.key}: expected exactly one acceptance in the named archive')
    root = acceptances[0].parent
    acceptance = json.loads(acceptances[0].read_text())
    if (acceptance['configuration'] != configuration or acceptance['status'] != 'captured'
            or acceptance['deviceID'] != device or acceptance['itemCensus'] != {f'Visual Home Gallery {i}': 1 for i in range(1, 7)}):
        raise ValueError(f'{coordinate.key}: identity, configuration or exact-once census failed')
    for name in ['native-viewport-parity.json', 'visible-viewport-freeze-parity.json']:
        if json.loads((root / name).read_text())['matched'] is not True:
            raise ValueError(f'{coordinate.key}: {name} failed')
    geometry = json.loads((root / 'geometry.json').read_text())
    environment.load_native_gate().Gate.verify_size_classes(geometry, coordinate.key)
    artifacts = []
    for name in ['capture.viewport.png', 'capture.frozen-viewport.png', 'capture.full-content.png']:
        path = root / name
        data = path.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise ValueError(f'{coordinate.key}: invalid PNG {name}')
        width, height = struct.unpack('>II', data[16:24])
        expected = configuration['geometry']['pixels']
        if width != expected[0] or height < expected[1] or (name != 'capture.full-content.png' and height != expected[1]):
            raise ValueError(f'{coordinate.key}: wrong native PNG dimensions {name}: {width}x{height}')
        artifacts.append({'path': str(path), 'pixels': [width, height], 'bytes': len(data),
                          'sha256': hashlib.sha256(data).hexdigest()})
    return {'coordinate': coordinate.key, 'status': 'captured', 'reason': 'Native geometry, parity and census verified',
            'artifacts': artifacts, 'acceptance': str(root / 'acceptance.json')}


def dispatch(args, requested, report, publish):
    native = environment.load_native_gate()
    pin = report['rendering']
    inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json'], text=True))
    devices = environment.resolve_destinations(inventory, pin['runtime'], pin['devices'])
    gate = native.Gate(argparse.Namespace(output=args.output / 'native', derived_data=environment.default_derived_data()))
    # Preflight already built the final tree. Reuse its products, but write explicit per-invocation parameters.
    gate.single_pass_run('FeatureTests')
    gate.single_pass_run('UITests')
    for family in environment.MODELS:
        family_rows = [row for row in requested if row.family == family]
        if not family_rows:
            continue
        device = devices[family]['udid']
        report['destinations'][family] = device
        with gate.simulator_session(family, device):
            original_appearance = subprocess.check_output(['xcrun', 'simctl', 'ui', device, 'appearance'], text=True).strip()
            if original_appearance not in ('light', 'dark'):
                raise ValueError(f'Cannot preserve appearance: {original_appearance}')
            try:
                for orientation in contracts.AXES['orientation']:
                    rows = [row for row in family_rows if row.orientation == orientation]
                    if not rows:
                        continue
                    gate.run(f'{family}-rotate-{orientation}', ['test-without-building'], 'UITests', device,
                             [native.ROTATION + f'testRotateTo{orientation.title()}'], 1)
                    for coordinate in rows:
                        subprocess.run(['xcrun', 'simctl', 'ui', device, 'appearance', coordinate.theme], check=True)
                        configuration = configure_run(gate.test_runs['FeatureTests'], coordinate, args, report)
                        save(args.output / 'native' / f'{coordinate.key}.configuration.json', configuration)
                        gate.run(coordinate.key, ['test-without-building'], 'FeatureTests', device, [TEST], 1,
                                 content_size=CONTENT_SIZES[coordinate.size])
                        summary = json.loads((gate.output / f'{coordinate.key}.summary.json').read_text())
                        tree = json.loads((gate.output / f'{coordinate.key}.tests.json').read_text())
                        contracts.validate_test_result(summary, tree)
                        outcome = read_capture(gate.output / f'{coordinate.key}-attachments', coordinate, configuration, device)
                        for artifact in outcome['artifacts']:
                            artifact['path'] = str(Path(artifact['path']).relative_to(args.output))
                        outcome['acceptance'] = str(Path(outcome['acceptance']).relative_to(args.output))
                        outcome['xcresult'] = str((gate.output / f'{coordinate.key}.xcresult').relative_to(args.output))
                        publish(outcome)
            finally:
                subprocess.run(['xcrun', 'simctl', 'ui', device, 'appearance', original_appearance], check=True)
                gate.run(f'{family}-restore-portrait', ['test-without-building'], 'UITests', device,
                         [native.ROTATION + 'testRotateToPortrait'], 1, cleanup=True)


def execute(args):
    args.output = args.output.resolve()
    # Reject overlapping output before writing anything, including provenance or failure reports.
    for source in [REFERENCES, args.fixtures.resolve(), args.environment.resolve(), SCENARIOS]:
        if source.is_relative_to(args.output) or args.output.is_relative_to(source):
            raise ValueError('Output must be separate from fixtures, source catalog, pin and references')
    scenarios = json.loads(SCENARIOS.read_text())
    all_rows = contracts.enumerate_coordinates(scenarios)
    requested = contracts.select_coordinates(all_rows, args.filter) if args.filter is not None else all_rows
    args.output.mkdir(parents=True, exist_ok=False)
    references_before = fingerprint(REFERENCES)
    sources = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in PRODUCERS}
    native = environment.load_native_gate()
    native_sources = native.source_hashes()
    def validate_sources():
        if native.source_hashes() != native_sources:
            raise ValueError('Native capture sources changed during preflight or capture')
        if sources != {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in PRODUCERS}:
            raise ValueError('Matrix producer sources changed during preflight or capture')
    report = {'schemaVersion': 1, 'status': 'running', 'mode': args.mode,
              'started': datetime.now(timezone.utc).isoformat(), 'coverage': contracts.coverage(all_rows, requested),
              'filter': args.filter, 'destinations': {}, 'sources': sources, 'nativeSources': native_sources,
              'outcomes': [{'coordinate': row.key, 'status': 'failed', 'reason': 'Not executed'} for row in requested]}
    if args.filter is not None:
        report['coverage']['complete'] = False
    save(args.output / 'requested.json', [dict(asdict(row), key=row.key) for row in requested])
    save(args.output / 'outcomes.json', report)
    completed = set()
    def publish(outcome):
        if outcome['coordinate'] in completed or outcome['coordinate'] not in {row.key for row in requested}:
            raise ValueError('Duplicate or unrequested result from native dispatcher')
        completed.add(outcome['coordinate'])
        report['outcomes'] = [outcome if row['coordinate'] == outcome['coordinate'] else row for row in report['outcomes']]
        save(args.output / 'outcomes.json', report)
        print(f'Captured {len(completed)}/{len(requested)}: {outcome["coordinate"]}', flush=True)
    try:
        observed = environment.validate_environment(args.environment, args.output / 'environment')
        report['pinSHA256'] = observed['pinSHA256']
        report['rendering'] = observed['rendering']
        validate_sources()
        manifest = contracts.validate_fixtures(args.fixtures, scenarios)
        report['fixtureVersion'] = manifest['fixtureVersion']
        report['fixtureDigest'] = manifest['aggregateDigest']
        dispatch(args, requested, report, publish)
        contracts.validate_outcomes(requested, report['outcomes'])
        if completed != {row.key for row in requested} or any(row['status'] != 'captured' for row in report['outcomes']):
            raise ValueError('Native dispatch did not capture every requested coordinate')
        validate_sources()
        if hashlib.sha256(args.environment.read_bytes()).hexdigest() != report['pinSHA256']:
            raise ValueError('Rendering pin changed during capture')
        if contracts.validate_fixtures(args.fixtures, scenarios) != manifest:
            raise ValueError('Public fixture input changed during capture')
        report['status'] = 'passed'
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = f'{type(error).__name__}: {error}'
        for row in report['outcomes']:
            if row['coordinate'] not in completed:
                row['reason'] = report['error']
        raise
    finally:
        report['completed'] = datetime.now(timezone.utc).isoformat()
        report['referencesUnchanged'] = fingerprint(REFERENCES) == references_before
        report['counts'] = {status: sum(row['status'] == status for row in report['outcomes'])
                            for status in ('captured', 'failed', 'not-applicable')}
        if not report['referencesUnchanged']:
            report['status'] = 'failed'
            report['error'] = 'Approved references changed during capture'
        save(args.output / 'outcomes.json', report)
        if not report['referencesUnchanged']:
            raise ValueError(report['error'])
    return report


if __name__ == '__main__':
    try:
        execute(parser().parse_args())
    except (Exception, KeyboardInterrupt) as error:
        raise SystemExit(f'Regression failed: {type(error).__name__}: {error}') from error
