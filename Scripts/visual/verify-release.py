#!/usr/bin/env python3
"""Prove a Release build ships, links and activates no capture or test facility."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import time

# Text that only capture, UI-test or snapshot code puts in a binary or resource. The DEBUG-only
# sources define every one of them, so a Release file holding any is shipping that code. `XCTest`
# is not text evidence: swift-issue-reporting and swift-case-paths ship strings such as
# `XCTestConfigurationFilePath` in Release to detect a test host at run time. Linking XCTest is
# what would ship it, and FORBIDDEN_LINKAGE checks that against every linked object and library.
FORBIDDEN_CONTENT = (
    b'EHPANDA_',
    b'APPSHOT_',
    b'Appshot',
    b'capture_diagnostics',
    b'EhPandaCapture',
    b'CaptureScene',
    b'CaptureFixture',
    b'CaptureDiagnostics',
    b'CaptureRendering',
    b'CaptureLiveText',
    b'CaptureTagTranslation',
    b'captureSystemOverlay',
    b'UITestAutomation',
    b'UITestStub',
    b'SnapshotTesting',
    b'XCUI',
)

# `UITestAutomation` stays in Release as an inert shell: `shouldDetectClipboardURL` compiles to
# `false` and `prepareIfNeeded` to nothing outside DEBUG, because Release call sites read them.
# Its name is accepted only while every live symbol that carries it is the shell's own type
# metadata or those two members; any other member, such as `prepare(environment:)`, is a leak.
INERT_SHELL_TOKEN = 'UITestAutomation'
INERT_SHELL_SYMBOL = re.compile(
    r'^(_?\$s10AppFeature16UITestAutomationO(|MF|Ma|Mf|Mn|N|15prepareIfNeededyyFZ'
    r'|24shouldDetectClipboardURLSbvgZ|24shouldDetectClipboardURLSbvpZMV)'
    r'|l_\$s10AppFeature16UITestAutomationOHn|_symbolic _+ 10AppFeature16UITestAutomationO'
    r'|l_\.str\.16\.UITestAutomation)$'
)

# Path parts of test bundles, test fixtures, snapshot references and the DEBUG-only debug dylib.
FORBIDDEN_PAYLOAD = re.compile(
    r'(\.xctest|\.xctestrun|\.xcresult|\.debug\.dylib|__preview\.dylib|__Snapshots__|Fixtures?'
    r'|SnapshotTesting|VisualSnapshotTests|Appshot|XCTest|XCUIAutomation|Testing\.framework'
    r'|scenarios\.json|manifest\.json)$|\.html$',
    re.IGNORECASE,
)

# Targets, packages and object files a Release graph or link must not contain.
FORBIDDEN_LINKAGE = re.compile(
    r'SnapshotTesting|snapshot-testing|VisualSnapshotTests|Appshot|XCTest|XCUIAutomation|(^|[/(])Testing\.framework'
    r'|lib_TestingInterop|EhPandaUITests|FeatureTests',
    re.IGNORECASE,
)

DEBUG_DEFINE = re.compile(r'(^|\s)(-D\s?DEBUG|-DDEBUG=1)(\s|$)')
COVERAGE_FLAG = re.compile(r'(^|\s)(-profile-generate|-profile-coverage-mapping|-fprofile-instr-generate)(\s|$)')
COMPILE_LINE = re.compile(r'(^|/)(swift-frontend|swiftc|clang)\s')

# One probe launch environment. In a DEBUG build `UITestAutomation.prepare` refuses this exact
# set with `fatalError`, so the control process ends; a Release build must ignore all of it.
PROBE_ENVIRONMENT = {
    'EHPANDA_CAPTURE_CONFIGURATION': '{"purpose":"release-probe"}',
    'EHPANDA_CAPTURE_FIXTURES': 'release-probe',
    'APPSHOT_SCENE': 'release-probe',
    'EHPANDA_UITEST_STUB_NETWORK': '1',
    'EHPANDA_VISUAL_TEST_HOST': '1',
    'EHPANDA_AUTOMATION_TAB': 'setting',
}


def scan_payload(app):
    """Every forbidden file and every forbidden text occurrence in the bundle, with its path."""
    findings = []
    files = 0
    for path in sorted(app.rglob('*')):
        relative = path.relative_to(app).as_posix()
        if FORBIDDEN_PAYLOAD.search(path.name):
            findings.append({'kind': 'payload', 'path': relative})
        if path.is_symlink() or not path.is_file():
            continue
        files += 1
        data = path.read_bytes()
        for token in FORBIDDEN_CONTENT:
            if token in data:
                findings.append({'kind': 'content', 'path': relative, 'token': token.decode()})
    if files == 0:
        findings.append({'kind': 'payload', 'path': '.', 'token': 'empty bundle'})
    return files, findings


def link_map_sections(text):
    """The object files and live symbols of one ld link map; dead-stripped symbols are excluded."""
    objects, symbols = [], []
    section = None
    for line in text.splitlines():
        if line.startswith('# '):
            header = line[2:].strip().rstrip(':')
            section = header if header in {'Object files', 'Symbols', 'Dead Stripped Symbols'} else (
                section if header.startswith('Address') else None)
            continue
        if section == 'Object files':
            match = re.match(r'\[\s*\d+\]\s+(.*)$', line)
            if match:
                objects.append(match.group(1))
        elif section == 'Symbols':
            match = re.match(r'0x[0-9A-Fa-f]+\s+0x[0-9A-Fa-f]+\s+\[\s*\d+\]\s+(.*)$', line)
            if match:
                symbols.append(match.group(1))
    return objects, symbols


def scan_link_map(path):
    text = Path(path).read_text(errors='replace')
    objects, symbols = link_map_sections(text)
    findings = []
    if not objects or not symbols:
        findings.append({'kind': 'link-map', 'path': str(path), 'token': 'no object files or symbols'})
    for item in objects:
        if FORBIDDEN_LINKAGE.search(item):
            findings.append({'kind': 'link-object', 'path': str(path), 'object': item})
    shell = 0
    for symbol in symbols:
        if INERT_SHELL_SYMBOL.match(symbol):
            shell += 1
            continue
        for token in FORBIDDEN_CONTENT:
            if token.decode() in symbol:
                findings.append({'kind': 'link-symbol', 'path': str(path), 'symbol': symbol,
                                 'token': token.decode()})
                break
    return {'objects': len(objects), 'symbols': len(symbols), 'inertShellSymbols': shell}, findings


def build_graph(text):
    """Targets of the build's dependency graph and the packages resolution listed."""
    targets = sorted(set(re.findall(r"^[ \t]*Target '([^']+)' in project '[^']+'", text, re.MULTILINE)))
    packages = []
    resolved = re.search(r'^Resolved source packages:\n((?:[ \t]+.+\n?)+)', text, re.MULTILINE)
    if resolved:
        packages = [line.strip().split(':', 1)[0] for line in resolved.group(1).splitlines() if line.strip()]
    return targets, packages


def scan_build_log(path):
    text = Path(path).read_text(errors='replace')
    targets, packages = build_graph(text)
    findings = []
    if '** BUILD SUCCEEDED **' not in text:
        findings.append({'kind': 'build-log', 'token': 'no BUILD SUCCEEDED'})
    if not targets:
        findings.append({'kind': 'build-log', 'token': 'no target dependency graph'})
    if 'Release-iphonesimulator' not in text or 'Debug-iphonesimulator' in text:
        findings.append({'kind': 'build-log', 'token': 'not exclusively a Release simulator build'})
    for target in targets:
        if FORBIDDEN_LINKAGE.search(target):
            findings.append({'kind': 'graph-target', 'target': target})
    compiles = 0
    for line in text.splitlines():
        if COMPILE_LINE.search(line.lstrip()):
            compiles += 1
            if DEBUG_DEFINE.search(line):
                findings.append({'kind': 'debug-define', 'line': line.strip()[:300]})
            if COVERAGE_FLAG.search(line):
                # A coverage-instrumented build is not the shipped one: archive builds carry no
                # profile counters, and the counters name every instrumented function.
                findings.append({'kind': 'instrumented', 'line': line.strip()[:300]})
    if compiles == 0:
        findings.append({'kind': 'build-log', 'token': 'no compiler invocation'})
    # A package resolution lists for the whole project is not linkage; only graph and link
    # evidence decides, so a resolved test-only package is recorded, never a finding by itself.
    resolution_only = [name for name in packages if FORBIDDEN_LINKAGE.search(name)]
    return {'targets': targets, 'compileInvocations': compiles, 'resolvedPackages': packages,
            'resolutionOnly': resolution_only}, findings


def accept_inert_shell(report):
    """Move the shell's name out of the findings when the link maps show only the inert shell."""
    report['accepted'] = []
    shell_linked = any(item['inertShellSymbols'] for item in report['linkMaps'])
    other_member = any(item['kind'] == 'link-symbol' and item['token'] == INERT_SHELL_TOKEN
                       for item in report['findings'])
    if not shell_linked or other_member:
        return
    for finding in list(report['findings']):
        if finding['kind'] == 'content' and finding['token'] == INERT_SHELL_TOKEN:
            report['findings'].remove(finding)
            report['accepted'].append({**finding, 'kind': 'inert-shell'})


def run(command, extra_environment=None):
    environment = {**os.environ, **(extra_environment or {})}
    return subprocess.run(command, capture_output=True, text=True, env=environment)


def bundle_identifier(app):
    with (Path(app) / 'Info.plist').open('rb') as handle:
        return plistlib.load(handle)['CFBundleIdentifier']


def launch_survives(app, device, wait, runner=run, sleep=time.sleep):
    """Install `app`, launch it with the probe environment and report whether it still runs."""
    identifier = bundle_identifier(app)
    install = runner(['xcrun', 'simctl', 'install', device, str(app)])
    if install.returncode:
        raise RuntimeError(f'simctl install exited {install.returncode}: {install.stderr.strip()}')
    launch = runner(
        ['xcrun', 'simctl', 'launch', '--terminate-running-process', device, identifier],
        {f'SIMCTL_CHILD_{key}': value for key, value in PROBE_ENVIRONMENT.items()},
    )
    match = re.search(r':\s*(\d+)\s*$', launch.stdout.strip())
    if launch.returncode or not match:
        return {'bundle': identifier, 'launchExit': launch.returncode, 'pid': None, 'alive': False}
    pid = match.group(1)
    sleep(wait)
    listing = runner(['xcrun', 'simctl', 'spawn', device, 'launchctl', 'list'])
    if listing.returncode:
        raise RuntimeError(f'launchctl list exited {listing.returncode}: {listing.stderr.strip()}')
    alive = any(line.split('\t')[0] == pid and identifier in line for line in listing.stdout.splitlines())
    runner(['xcrun', 'simctl', 'terminate', device, identifier])
    return {'bundle': identifier, 'launchExit': launch.returncode, 'pid': int(pid), 'alive': alive}


def verify(args, launcher=launch_survives):
    report = {'app': str(args.app), 'buildLog': str(args.build_log), 'linkMaps': [], 'findings': []}
    if not args.app.is_dir():
        raise SystemExit(f'{args.app} is not an app bundle')
    files, findings = scan_payload(args.app)
    report['payloadFiles'] = files
    report['findings'] += findings
    report['graph'], findings = scan_build_log(args.build_log)
    report['findings'] += findings
    for path in args.link_map:
        counts, findings = scan_link_map(path)
        report['linkMaps'].append({'path': str(path), **counts})
        report['findings'] += findings
    accept_inert_shell(report)
    if args.device:
        activation = {'environment': PROBE_ENVIRONMENT, 'release': launcher(args.app, args.device, args.wait)}
        if not activation['release']['alive']:
            report['findings'].append({'kind': 'activation', 'token': 'Release did not survive the probe launch'})
        if args.debug_control:
            activation['debugControl'] = launcher(args.debug_control, args.device, args.wait)
            if activation['debugControl']['alive']:
                report['findings'].append({'kind': 'activation',
                                           'token': 'Debug control survived, so the probe proves nothing'})
        report['activation'] = activation
    report['passed'] = not report['findings']
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'release-isolation.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def parse(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True, help='Release .app bundle')
    parser.add_argument('--build-log', type=Path, required=True, help='Full xcodebuild log of that build')
    parser.add_argument('--link-map', type=Path, action='append', required=True,
                        help='ld link map of a Release binary; repeat for every binary and architecture')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--device', help='Simulator UDID for the launched-activation probe')
    parser.add_argument('--debug-control', type=Path, help='Debug .app that must end under the probe')
    parser.add_argument('--wait', type=float, default=8.0, help='Seconds a launch must survive')
    return parser.parse_args(argv)


def main(argv=None):
    args = parse(argv)
    report = verify(args)
    for finding in report['findings']:
        print(json.dumps(finding), file=sys.stderr)
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {len(report['findings'])} finding(s); "
          f"{args.output / 'release-isolation.json'}")
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
