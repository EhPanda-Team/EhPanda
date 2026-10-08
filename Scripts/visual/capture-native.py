#!/usr/bin/env python3
"""Capture one marketing coordinate on the actual app, with native chrome, over independent cold launches."""
import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import time
import zlib

import contracts
import environment
import fixtures

ROOT = environment.ROOT
TEST = 'EhPandaUITests/MarketingCaptureUITests/testCaptureCoordinate'
COORDINATE_KEYS = ('screen', 'set', 'locale', 'theme', 'family')
# Every coordinate launches cold this many times, and every launch must record the same bytes.
COLD_LAUNCHES = 2
# The text size every marketing capture verifies (D-16 has no Dynamic Type axis).
TEXT_SIZE = 'large'
# The status bar every marketing frame shows (D-10). simctl freezes the date only for a full ISO time,
# which it reads in the host's time zone like the status bar itself, so the bar reads 9:41 everywhere.
# simctl derives the weekday as if the year were 2000, so iPad's date reads "Sat Jan 1" (owner decision).
STATUS_BAR_TIME = datetime(2026, 1, 1, 9, 41)
STATUS_BAR = ('--wifiMode', 'active', '--wifiBars', '3', '--cellularMode', 'active', '--cellularBars', '4',
              '--batteryState', 'charged', '--batteryLevel', '100')
STATUS_BAR_HEADER = ['Current Status Bar Overrides:', '=============================']
SETTLE_SCREENSHOT = ('--type=png', '--mask=ignored')
# The first app the system shows after a boot lays out iPad's status bar Wi-Fi glyph half a point left of where every
# later app does, so this app is shown and quit once before any capture launch (owner decision, 2026-10-08).
SETTLE_APP = 'com.apple.Preferences'
# Settings counts as shown once two screenshots this far apart are byte-identical.
SETTLE_INTERVAL = 1.0
SETTLE_ATTEMPTS = 10
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
# simctl records the settle launch's screenshots as 8-bit RGBA without interlacing.
SETTLE_PNG = {'bitDepth': 8, 'colorType': 6, 'compression': 0, 'filter': 0, 'interlace': 0}
# A marketing frame is the system screenshot the test attaches, 8-bit RGB. The system renders a screenshot whole, while
# the display framebuffer simctl reads keeps Liquid Glass as it last composed it, which differed between cold launches
# of one screen (owner decision, 2026-10-09).
FRAME_PNG = {**SETTLE_PNG, 'colorType': 2}
# Bytes per pixel of each color type a frame may have.
CHANNELS = {2: 3, 6: 4}
PRODUCERS = [Path(__file__), Path(environment.__file__), Path(fixtures.__file__), Path(contracts.__file__)]


class CaptureFailure(RuntimeError):
    """A launch did not produce a verified, complete frame of its coordinate."""


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    for name in ['coordinate', 'fixtures', 'environment', 'output']:
        result.add_argument('--' + name, type=Path, required=True)
    return result


def save(path, value):
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
    os.replace(temporary, path)


def producer_hashes():
    return {str(path.resolve().relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in PRODUCERS}


def read_coordinate(path):
    """One coordinate with exactly its five keys, each naming a known axis value."""
    coordinate = json.loads(Path(path).read_text())
    if not isinstance(coordinate, dict) or set(coordinate) != set(COORDINATE_KEYS):
        raise ValueError(f'A coordinate has exactly the keys {list(COORDINATE_KEYS)}')
    for key, allowed in [('screen', fixtures.SCREENS), ('set', fixtures.SETS), ('locale', contracts.AXES['locale']),
                         ('theme', contracts.AXES['theme']), ('family', contracts.AXES['family'])]:
        if coordinate[key] not in allowed:
            raise ValueError(f'Coordinate {key} {coordinate[key]!r} is not one of {list(allowed)}')
    return {key: coordinate[key] for key in COORDINATE_KEYS}


def coordinate_key(coordinate):
    return '__'.join(coordinate[key] for key in ('set', 'screen', 'family', 'locale', 'theme'))


def png_size(data, header):
    """The dimensions of a complete PNG with this header: every chunk intact and every scanline present."""
    if data[:8] != PNG_SIGNATURE:
        raise CaptureFailure('The frame is not a PNG')
    offset, chunks, compressed = 8, [], bytearray()
    while offset < len(data):
        if offset + 12 > len(data):
            raise CaptureFailure('The frame ends inside a chunk header')
        length, kind = struct.unpack('>I4s', data[offset:offset + 8])
        body = data[offset + 8:offset + 8 + length]
        if len(body) != length or offset + 12 + length > len(data):
            raise CaptureFailure(f'The frame ends inside its {kind!r} chunk')
        crc, = struct.unpack('>I', data[offset + 8 + length:offset + 12 + length])
        if zlib.crc32(kind + body) != crc:
            raise CaptureFailure(f'The frame\'s {kind!r} chunk is corrupt')
        chunks.append((kind, body))
        if kind == b'IDAT':
            compressed += body
        offset += 12 + length
    kinds = [kind for kind, _ in chunks]
    if not kinds or kinds[0] != b'IHDR' or kinds[-1] != b'IEND' or kinds.count(b'IEND') != 1 or chunks[-1][1]:
        raise CaptureFailure('The frame lacks its header or end chunk')
    data_chunks = [index for index, kind in enumerate(kinds) if kind == b'IDAT']
    if not data_chunks or data_chunks != list(range(data_chunks[0], data_chunks[-1] + 1)):
        raise CaptureFailure('The frame\'s image data is missing or split')
    ihdr = chunks[0][1]
    if len(ihdr) != 13:
        raise CaptureFailure('The frame header is malformed')
    width, height, *fields = struct.unpack('>IIBBBBB', ihdr)
    observed = dict(zip(header, fields))
    if observed != header or not width or not height:
        raise CaptureFailure(f'The frame is {width}x{height} with {observed}; expected {header}')
    decompressor = zlib.decompressobj()
    try:
        pixels = decompressor.decompress(bytes(compressed)) + decompressor.flush()
    except zlib.error as error:
        raise CaptureFailure(f'The frame\'s image data is corrupt: {error}') from error
    stride = 1 + width * CHANNELS[header['colorType']]
    if not decompressor.eof or decompressor.unused_data or len(pixels) != height * stride:
        raise CaptureFailure('The frame\'s image data is incomplete')
    if any(filter_type > 4 for filter_type in pixels[::stride]):
        raise CaptureFailure('The frame has an unknown scanline filter')
    return width, height


def verify_frame(data, header, pixels):
    """Fails unless the frame is a complete PNG with this header at the pin's portrait pixels."""
    size = png_size(data, header)
    if list(size) != pixels:
        raise CaptureFailure(f'The frame is {size[0]}x{size[1]} pixels; the pin expects {pixels[0]}x{pixels[1]}')


def status_bar_time():
    return STATUS_BAR_TIME.astimezone().isoformat(timespec='milliseconds')


def status_bar_overrides(device):
    lines = subprocess.check_output(['xcrun', 'simctl', 'status_bar', device, 'list'], text=True).splitlines()
    if lines[:2] != STATUS_BAR_HEADER:
        raise CaptureFailure(f'Unreadable status bar overrides: {lines!r}')
    return [line for line in lines[2:] if line.strip()]


def configure_run(path, coordinate, source):
    """Names the coordinate and fixture version in the UI test runner's environment."""
    native = environment.load_native_gate()
    data = plistlib.loads(path.read_bytes())
    targets = [item for item in native.nodes(data) if item.get('BlueprintName') == 'EhPandaUITests']
    if len(targets) != 1 or not targets[0].get('IsUITestBundle'):
        raise CaptureFailure('Expected exactly one EhPandaUITests UI test target')
    targets[0].setdefault('EnvironmentVariables', {}).update(
        EHPANDA_CAPTURE_COORDINATE=json.dumps(coordinate, separators=(',', ':')),
        EHPANDA_CAPTURE_SOURCE=str(source))
    path.write_bytes(plistlib.dumps(data))


def verify_diagnostics(path, coordinate, manifest):
    """The diagnostics the test attached, which must name this coordinate's screen, content and rendering."""
    diagnostics = json.loads(path.read_text())
    expected = {'screenID': coordinate['screen'], 'setID': coordinate['set'],
                'selectionID': manifest['selectionID'], 'fixtureVersion': manifest['fixtureVersion'],
                'readiness': 'ready', 'pendingImages': 0, 'unknownRequests': [], 'blockers': []}
    rendering = {'language': coordinate['locale'], 'appearance': coordinate['theme'], 'textSize': TEXT_SIZE,
                 'family': coordinate['family']}
    observed = {key: diagnostics.get(key) for key in expected}
    observed_rendering = {key: (diagnostics.get('rendering') or {}).get(key) for key in rendering}
    if observed != expected or observed_rendering != rendering:
        raise CaptureFailure(f'The test reported another screen: {diagnostics!r}')
    return diagnostics


def settle_frame(device, directory, pixels, output):
    """Screenshots until two consecutive frames are byte-identical, each a complete frame at native size."""
    frames, previous = [], None
    for attempt in range(1, SETTLE_ATTEMPTS + 1):
        path = directory / f'frame-{attempt}.png'
        command = ['xcrun', 'simctl', 'io', device, 'screenshot', *SETTLE_SCREENSHOT, str(path)]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode:
            raise CaptureFailure(f'simctl screenshot exited {result.returncode}: {result.stderr.strip()}')
        data = path.read_bytes()
        verify_frame(data, SETTLE_PNG, pixels)
        digest = hashlib.sha256(data).hexdigest()
        frames.append({'path': str(path.relative_to(output)), 'sha256': digest})
        if digest == previous:
            return {'frames': frames, 'capture': {'path': str(path.relative_to(output)), 'sha256': digest,
                                                  'pixels': pixels, 'bytes': len(data)}}
        previous = digest
        time.sleep(SETTLE_INTERVAL)
    raise CaptureFailure(f'The screen never held still across two screenshots in {SETTLE_ATTEMPTS} attempts')


def launch_attachment(directory, name):
    """The one file the test attached as `name`, which xcresulttool exports as `<name>_<index>_<UUID>.<extension>`."""
    manifest = json.loads((directory / 'manifest.json').read_text())
    matches = [item for test in manifest for item in test['attachments']
               if item['suggestedHumanReadableName'].startswith(name + '_')]
    if len(matches) != 1:
        raise CaptureFailure(f'Expected one {name} attachment, found {len(matches)}')
    return directory / matches[0]['exportedFileName']


def capture_launch(gate, number, context, record):
    """One cold launch: the test verifies the screen and attaches the system's settled screenshot."""
    output = context['output']
    configure_run(gate.test_runs['UITests'], context['coordinate'], context['source'])
    name = f'launch-{number}'
    record['xcresult'] = str((gate.output / f'{name}.xcresult').relative_to(output))
    attachments = gate.output / f'{name}-attachments'
    record['attachments'] = str(attachments.relative_to(output))
    gate.run(name, ['test-without-building'], 'UITests', context['device'], [TEST], 1)
    summary = json.loads((gate.output / f'{name}.summary.json').read_text())
    contracts.validate_test_result(summary, json.loads((gate.output / f'{name}.tests.json').read_text()))
    rendered = summary['devicesAndConfigurations'][0]['device']
    if (rendered['modelName'], rendered['osBuildNumber']) != (context['model'], context['runtimeBuild']):
        raise CaptureFailure(f'{name} ran on {rendered["modelName"]} {rendered["osBuildNumber"]}')
    key = coordinate_key(context['coordinate'])
    record['diagnostics'] = verify_diagnostics(launch_attachment(attachments, f'capture-{key}-state'),
                                               context['coordinate'], context['manifest'])
    data = launch_attachment(attachments, f'capture-{key}-screen').read_bytes()
    verify_frame(data, FRAME_PNG, context['pixels'])
    frame = output / 'launches' / str(number) / 'frame.png'
    frame.parent.mkdir(parents=True)
    frame.write_bytes(data)
    record['capture'] = {'path': str(frame.relative_to(output)), 'sha256': hashlib.sha256(data).hexdigest(),
                         'pixels': context['pixels'], 'bytes': len(data)}
    record['status'] = 'captured'


def clear_status_bar(device, report):
    subprocess.run(['xcrun', 'simctl', 'status_bar', device, 'clear'], check=True)
    if status_bar_overrides(device):
        raise CaptureFailure('The status bar overrides survived clearing')
    report['chrome']['statusBarRestored'] = True


def restore_appearance(device, appearance, report):
    subprocess.run(['xcrun', 'simctl', 'ui', device, 'appearance', appearance], check=True)
    report['chrome']['appearanceRestored'] = appearance


def restore_portrait(gate, family, device, rotation):
    # The launches named their capture in the UI test run; the orientation test gets a plain one again.
    gate.single_pass_run('UITests')
    gate.run(f'{family}-restore-portrait', ['test-without-building'], 'UITests', device,
             [rotation + 'testRotateToPortrait'], 1, cleanup=True)


def dispatch(args, coordinate, observed, source, manifest, report, publish):
    native = environment.load_native_gate()
    family = coordinate['family']
    pin = observed['rendering']
    context = {
        'output': args.output, 'coordinate': coordinate, 'source': source, 'manifest': manifest,
        'device': observed['destinations'][family]['udid'], 'model': pin['devices'][family]['model'],
        'runtimeBuild': pin['runtime']['buildVersion'],
        'pixels': pin['devices'][family]['orientations']['portrait']['pixels'],
    }
    device = context['device']
    report['device'] = {'udid': device, 'model': context['model'], 'runtimeBuild': context['runtimeBuild'],
                        'pixels': context['pixels']}
    gate = native.Gate(argparse.Namespace(output=args.output / 'native',
                                          derived_data=environment.default_derived_data()))
    # Environment validation built the final tree; reuse its products with explicit per-launch parameters.
    gate.single_pass_run('UITests')
    with gate.simulator_session(family, device), ExitStack() as restore:
        appearance = subprocess.check_output(['xcrun', 'simctl', 'ui', device, 'appearance'], text=True).strip()
        if appearance not in contracts.AXES['theme']:
            raise CaptureFailure(f'Cannot preserve appearance: {appearance}')
        # An override the runner did not set could not be put back after clearing its own.
        existing = status_bar_overrides(device)
        if existing:
            raise CaptureFailure(f'The status bar already carries overrides: {existing}')
        # The stack runs these last to first, each even when one before it fails: the status bar, the
        # appearance, the outcomes, then portrait.
        restore.callback(restore_portrait, gate, family, device, native.ROTATION)
        restore.callback(publish)
        restore.callback(restore_appearance, device, appearance, report)
        restore.callback(clear_status_bar, device, report)
        time_value = status_bar_time()
        subprocess.run(['xcrun', 'simctl', 'status_bar', device, 'override', '--time', time_value, *STATUS_BAR],
                       check=True)
        report['chrome']['statusBar'] = {'time': time_value, 'arguments': list(STATUS_BAR),
                                         'applied': status_bar_overrides(device)}
        settle = args.output / 'settle'
        settle.mkdir()
        subprocess.run(['xcrun', 'simctl', 'launch', device, SETTLE_APP], check=True, capture_output=True)
        try:
            report['chrome']['settleLaunch'] = {'app': SETTLE_APP,
                                                **settle_frame(device, settle, context['pixels'], args.output)}
        finally:
            subprocess.run(['xcrun', 'simctl', 'terminate', device, SETTLE_APP], check=True)
        publish()
        for number in range(1, COLD_LAUNCHES + 1):
            record = {'launch': number, 'status': 'failed'}
            report['launches'].append(record)
            try:
                capture_launch(gate, number, context, record)
            finally:
                publish()


def execute(args):
    args.output = args.output.resolve()
    coordinate = read_coordinate(args.coordinate)
    source = fixtures.resolve_fixtures(args.fixtures)
    # Reject overlapping output before writing anything, including provenance or failure reports.
    for path in [args.coordinate.resolve(), args.environment.resolve(), source]:
        if path.is_relative_to(args.output) or args.output.is_relative_to(path):
            raise ValueError('Output must be separate from the coordinate, pin and fixture version')
    args.output.mkdir(parents=True, exist_ok=False)
    native = environment.load_native_gate()
    sources, native_sources = producer_hashes(), native.source_hashes()
    report = {'schemaVersion': 1, 'kind': 'marketing-native-capture', 'status': 'running',
              'started': datetime.now(timezone.utc).isoformat(), 'coordinate': coordinate,
              'key': coordinate_key(coordinate), 'coldLaunches': COLD_LAUNCHES, 'launches': [],
              'chrome': {'orientation': 'portrait', 'textSize': TEXT_SIZE, 'frame': 'XCUIScreen.main.screenshot',
                         'settleScreenshot': list(SETTLE_SCREENSHOT)},
              'sources': sources, 'nativeSources': native_sources}
    def publish():
        save(args.output / 'outcomes.json', report)
    publish()
    try:
        manifest = fixtures.validate_fixtures(source)
        selection = json.loads((source / 'selection.json').read_text())
        if coordinate['set'] not in selection['scenes']:
            raise ValueError(f'The selection has no {coordinate["set"]} scene')
        report.update(fixtureVersion=manifest['fixtureVersion'], fixtureDigest=manifest['aggregateDigest'],
                      selectionID=manifest['selectionID'])
        observed = environment.validate_environment(args.environment, args.output / 'environment-check')
        report['pinSHA256'] = observed['pinSHA256']
        if native.source_hashes() != native_sources or producer_hashes() != sources:
            raise ValueError('Capture sources changed during preflight')
        dispatch(args, coordinate, observed, source, manifest, report, publish)
        digests = {launch['capture']['sha256'] for launch in report['launches']}
        report['identical'] = len(digests) == 1
        if len(report['launches']) != COLD_LAUNCHES or not report['identical']:
            raise CaptureFailure(f'{COLD_LAUNCHES} cold launches recorded {len(digests)} different frames')
        if native.source_hashes() != native_sources or producer_hashes() != sources:
            raise ValueError('Capture sources changed during capture')
        if hashlib.sha256(args.environment.read_bytes()).hexdigest() != report['pinSHA256']:
            raise ValueError('Rendering pin changed during capture')
        if fixtures.validate_fixtures(source) != manifest:
            raise ValueError('Fixture version changed during capture')
        report['capture'] = report['launches'][0]['capture']
        report['status'] = 'captured'
    except BaseException as error:
        report['status'] = 'failed'
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        report['completed'] = datetime.now(timezone.utc).isoformat()
        publish()
    return report


if __name__ == '__main__':
    try:
        execute(parser().parse_args())
    except (Exception, KeyboardInterrupt) as error:
        raise SystemExit(f'Native capture failed: {type(error).__name__}: {error}') from error
