#!/usr/bin/env python3
"""Record what the app's own Live Text finds on a selection's Live Text page into the marketing fixture (17-06).

The app opens the fixture's saved page in the reader on the pinned iPhone and runs Live Text through its own
recognizer, request settings and grouping. The UI test attaches the capture diagnostics, which carry every group and
line the reader found, and this saves them as the page's Live Text record in a new fixture version. Every capture of
the reading-live-text screen then replays that record and never runs Vision itself.
"""
import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

import contracts
import environment
import fixtures

ROOT = environment.ROOT
TEST = 'EhPandaUITests/MarketingCaptureUITests/testRecordLiveText'
# The page is recognized once, on the pinned iPhone; the reader's recognition depends on the page and the gallery's
# language, not on the coordinate's locale or appearance, so one English light launch records it for every capture.
FAMILY = 'iphone'
LOCALE = 'en'
THEME = 'light'
PRODUCERS = [Path(__file__), ROOT / 'Scripts/visual/capture-native.py', Path(environment.__file__),
             Path(fixtures.__file__), Path(contracts.__file__)]


def load_capture():
    """The native capture runner, whose simulator, chrome-restoring and attachment steps a recording shares."""
    spec = importlib.util.spec_from_file_location('capture_native', ROOT / 'Scripts/visual/capture-native.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('--fixtures', type=Path, required=True,
                        help='The fixture output whose current version is recorded, such as .capture/marketing')
    result.add_argument('--set', required=True, choices=fixtures.SETS)
    for name in ['environment', 'output']:
        result.add_argument('--' + name, type=Path, required=True)
    return result


def producer_hashes():
    return {str(path.resolve().relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in PRODUCERS}


def recording_coordinate(set_id):
    return {'screen': 'reading-live-text', 'set': set_id, 'locale': LOCALE, 'theme': THEME, 'family': FAMILY}


def live_text_record(diagnostics, scene, manifest, device):
    """The record of the reader's recognition of the scene's Live Text page, as the recording launch reported it."""
    live_text = diagnostics.get('liveText')
    if not isinstance(live_text, dict) or live_text.get('source') != 'recognition':
        raise ValueError("The recording reported no recognition by the reader's own Live Text")
    gid, page = scene['gallery'], scene['page']
    if (live_text.get('gid'), live_text.get('page')) != (gid, page):
        raise ValueError(f'The recording read page {live_text.get("page")!r} of gallery {live_text.get("gid")!r}, '
                         f'not page {page} of gallery {gid}')
    images = [entry for entry in manifest['assets']
              if (entry['kind'], entry['gid'], entry['index']) == ('page', gid, page)]
    if len(images) != 1:
        raise ValueError(f'The fixture holds no image of page {page} of gallery {gid}')
    record = {'schemaVersion': fixtures.SCHEMA_VERSION, 'gid': gid, 'page': page, 'pageSHA256': images[0]['sha256'],
              'recognitionLanguages': live_text.get('recognitionLanguages'), 'recordedOn': device,
              'groups': live_text.get('groups')}
    fixtures.validate_live_text(record, gid, page, images[0]['sha256'])
    return record


def dispatch(args, capture, coordinate, observed, source, manifest, report):
    """Runs the recording test once on the pinned iPhone and returns its verified diagnostics and device."""
    native = environment.load_native_gate()
    pin = observed['rendering']
    device = observed['destinations'][FAMILY]['udid']
    model, runtime = pin['devices'][FAMILY]['model'], pin['runtime']['buildVersion']
    report['device'] = {'udid': device, 'model': model, 'runtimeBuild': runtime}
    gate = native.Gate(argparse.Namespace(output=args.output / 'native',
                                          derived_data=environment.default_derived_data()))
    # Environment validation built the final tree; reuse its products with the recording's parameters.
    gate.single_pass_run('UITests')
    with gate.simulator_session(FAMILY, device), ExitStack() as restore:
        appearance = subprocess.check_output(['xcrun', 'simctl', 'ui', device, 'appearance'], text=True).strip()
        if appearance not in contracts.AXES['theme']:
            raise capture.CaptureFailure(f'Cannot preserve appearance: {appearance}')
        # The stack runs these last to first, each even when one before it fails: the appearance, then portrait.
        restore.callback(capture.restore_portrait, gate, FAMILY, device, native.ROTATION)
        restore.callback(capture.restore_appearance, device, appearance, report)
        capture.configure_run(gate.test_runs['UITests'], coordinate, source)
        gate.run('record', ['test-without-building'], 'UITests', device, [TEST], 1)
        summary = json.loads((gate.output / 'record.summary.json').read_text())
        contracts.validate_test_result(summary, json.loads((gate.output / 'record.tests.json').read_text()))
        rendered = summary['devicesAndConfigurations'][0]['device']
        if (rendered['modelName'], rendered['osBuildNumber']) != (model, runtime):
            raise capture.CaptureFailure(f'The recording ran on {rendered["modelName"]} {rendered["osBuildNumber"]}')
        name = f'live-text-recording-{capture.coordinate_key(coordinate)}-state'
        state = capture.launch_attachment(gate.output / 'record-attachments', name)
        report['attachment'] = str(state.relative_to(args.output))
        diagnostics = capture.verify_diagnostics(state, coordinate, manifest)
    return diagnostics, {'model': model, 'runtimeBuild': runtime}


def now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def execute(args, clock=now):
    args.output = args.output.resolve()
    output = args.fixtures.resolve()
    fixtures.check_output(output)
    source = fixtures.resolve_fixtures(output / 'current')
    # Reject overlapping output before writing anything, including provenance or failure reports.
    for path in [args.environment.resolve(), output]:
        if path.is_relative_to(args.output) or args.output.is_relative_to(path):
            raise ValueError('Output must be separate from the pin and the fixture output')
    args.output.mkdir(parents=True, exist_ok=False)
    capture = load_capture()
    coordinate = recording_coordinate(args.set)
    native = environment.load_native_gate()
    sources, native_sources = producer_hashes(), native.source_hashes()
    report = {'schemaVersion': 1, 'kind': 'live-text-recording', 'status': 'running', 'started': clock(),
              'coordinate': coordinate, 'chrome': {}, 'sources': sources, 'nativeSources': native_sources}
    def publish():
        capture.save(args.output / 'outcomes.json', report)
    publish()
    try:
        manifest = fixtures.validate_fixtures(source)
        selection = json.loads((source / 'selection.json').read_text())
        if args.set not in selection['scenes']:
            raise ValueError(f'The selection has no {args.set} scene')
        scene = selection['scenes'][args.set]['liveText']
        report.update(fixtureVersion=manifest['fixtureVersion'], selectionID=manifest['selectionID'],
                      page={'gid': scene['gallery'], 'page': scene['page']})
        observed = environment.validate_environment(args.environment, args.output / 'environment-check')
        report['pinSHA256'] = observed['pinSHA256']
        if native.source_hashes() != native_sources or producer_hashes() != sources:
            raise ValueError('Recording sources changed during preflight')
        diagnostics, device = dispatch(args, capture, coordinate, observed, source, manifest, report)
        record = live_text_record(diagnostics, scene, manifest, device)
        if native.source_hashes() != native_sources or producer_hashes() != sources:
            raise ValueError('Recording sources changed during the recording')
        if hashlib.sha256(args.environment.read_bytes()).hexdigest() != report['pinSHA256']:
            raise ValueError('Rendering pin changed during the recording')
        if fixtures.validate_fixtures(output / 'current') != manifest:
            raise ValueError('The current fixture version changed during the recording')
        recorded_at = clock()
        published, changed = fixtures.publish_records(output, [record], recorded_at)
        report.update(recordedAt=recorded_at, groups=len(record['groups']),
                      lines=sum(len(group['blocks']) for group in record['groups']),
                      publishedVersion=published.name, currentChanged=changed, status='recorded')
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        report['completed'] = clock()
        publish()
    return report


if __name__ == '__main__':
    try:
        execute(parser().parse_args())
    except (Exception, KeyboardInterrupt) as error:
        raise SystemExit(f'Live Text recording failed: {type(error).__name__}: {error}') from error
