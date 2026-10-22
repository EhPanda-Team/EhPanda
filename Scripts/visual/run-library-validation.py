#!/usr/bin/env python3
"""Run the Library feature or UI regression selection once, retaining native evidence."""

import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

import environment

FEATURE_TARGETS = [
    'AppModelsTests', 'AppFeatureTests', 'FavoritesFeatureTests', 'DownloadsFeatureTests',
    'HomeFeatureTests', 'SearchFeatureTests', 'DetailFeatureTests', 'SettingFeatureTests',
    'GalleryListComponentsTests', 'AnalyticsClientTests',
]
PHONE = '6CE1E40A-7090-484E-8C49-B7BCBDC5E684'
# Existing diagnostic-contract tests and TCA's explicit cancellation diagnostics.
# Unexpected failures, new expected-failure sites, skips and repetitions still fail.
DIAGNOSTIC_TESTS = {
    'DownloadsFeatureTests/DownloadContinuedSessionBasisTests/testANestedCountedBasisMovementIsDetectedWhileASiblingIsNot()',
    'DownloadsFeatureTests/DownloadContinuedSessionTests/testUnimplementedClientReportsAnIssueForEveryEndpoint()',
    'DownloadsFeatureTests/DownloadOwnershipConvergenceTests/testAnUnmatchedSchedulingReleaseReportsAnIssue()',
    'DownloadsFeatureTests/DownloadProgressSeriesGuardTests/testADipNoLaterPushRepaintsIsRefused()',
    'DownloadsFeatureTests/DownloadProgressSeriesGuardTests/testASecondDisplacedPushIsRefused()',
    'DownloadsFeatureTests/DownloadProgressSeriesGuardTests/testADipInTheFinalPositionIsRefused()',
    'SettingFeatureTests/SettingPresentationTests/pushingAccountLoadsCookies()',
    'SettingFeatureTests/SettingReducerTests/defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges()',
    'AnalyticsClientTests/AnalyticsClientGateTests/theUnimplementedClientReportsAnIssueWhenSendIsCalled()',
    'AnalyticsClientTests/AnalyticsClientGateTests/theUnimplementedClientReportsAnIssueWhenStartIsCalled()',
}


def validate_feature_results(native, output, expected, device):
    summary = json.loads((output / 'feature-tests.summary.json').read_text())
    tree = json.loads((output / 'feature-tests.tests.json').read_text())
    nodes = list(native.nodes(tree))
    cases = [node for node in nodes if node.get('nodeType') == 'Test Case']
    results = {}
    for case in cases:
        identifier = case['nodeIdentifierURL'].split('/AppPackage/', 1)[1]
        # XCTest result URLs omit empty argument lists; enumeration and Swift Testing retain them.
        # Compare the same method identity without relaxing the selected-test or duplicate checks.
        if not identifier.endswith(')'):
            identifier += '()'
        if identifier in results:
            raise RuntimeError(f'Duplicate test result: {identifier}')
        results[identifier] = case['result']
    if set(results) != set(expected):
        raise RuntimeError('Executed test identities differ from the enumerated selection')
    for identifier, result in results.items():
        if result == 'Passed':
            continue
        if result == 'Expected Failure' and identifier in DIAGNOSTIC_TESTS:
            continue
        raise RuntimeError(f'Unexpected test outcome: {identifier}: {result}')
    if (summary['totalTestCount'] != len(expected) or summary['failedTests'] or summary['skippedTests']
            or any('Repetition' in node.get('nodeType', '') for node in nodes)):
        raise RuntimeError('Feature results must include each selected test once without failures or skips')
    devices = {item['device']['deviceId'] for item in summary['devicesAndConfigurations']}
    if devices != {device}:
        raise RuntimeError(f'Unexpected devices: {devices}')
    return {
        'status': 'passed', 'testCount': len(expected), 'passedTests': summary['passedTests'],
        'expectedDiagnosticTests': sorted(key for key, value in results.items() if value == 'Expected Failure'),
        'skippedTests': 0, 'failedTests': 0,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', choices=['feature', 'ui'], required=True)
    parser.add_argument('--device')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.stage == 'ui' and not args.device:
        parser.error('--device is required for UI validation')
    args.device = args.device or PHONE
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    args.output = args.output or environment.ROOT / '.build/library' / f'{args.stage}-{stamp}'
    args.derived_data = environment.ROOT / '.build/library-dd'
    helper = Path(__file__).with_name('run-single-pass.py')
    if args.stage == 'ui':
        subprocess.run([
            sys.executable, str(helper), '--device', args.device, '--output', str(args.output),
            '--derived-data', str(args.derived_data),
            '--only-testing', 'EhPandaUITests/LibraryPresentationUITests',
            '--only-testing', 'EhPandaUITests/GalleryLayoutUITests',
        ], check=True)
        return
    spec = importlib.util.spec_from_file_location('single_pass', helper)
    if spec is None or spec.loader is None:
        raise RuntimeError('Could not load the native single-pass helper')
    single = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(single)
    native = environment.load_native_gate()
    gate = native.Gate(args)
    print(f'Library feature evidence: {gate.output}', flush=True)
    selectors = [f'-only-testing:{target}' for target in FEATURE_TARGETS]
    single.run_preparation(gate, 'build', [
        'xcodebuild', 'build-for-testing', *gate.common, '-testPlan', 'FeatureTests',
        # Xcode 27.1's Swift linker sends --sysroot; Darwin clang needs -isysroot
        # to read the simulator SDK's metadata. Pass the actual per-target SDK only
        # through the Swift linker, retaining the native host SDK for macro tools.
        'OTHER_LDFLAGS=$(inherited) $(LIBRARY_SYSROOT_$(LINKER_DRIVER))',
        'LIBRARY_SYSROOT_swiftc=-Xclang-linker -isysroot -Xclang-linker $(SDKROOT)',
        '-destination', f'platform=iOS Simulator,id={args.device}', *selectors,
        '-resultBundlePath', str(gate.output / 'build.xcresult'),
    ])
    build = json.loads(subprocess.check_output([
        'xcrun', 'xcresulttool', 'get', 'build-results', '--path', str(gate.output / 'build.xcresult')
    ], text=True))
    native.save_json(gate.output / 'build-results.json', build)
    if build.get('status') != 'succeeded' or build.get('errorCount') != 0 or build.get('warningCount') != 0:
        raise RuntimeError('Build must pass without errors or warnings')
    gate.single_pass_run('FeatureTests')
    with single.simulator_test_window(args.device), gate.simulator_session('feature', args.device):
        command = [
            'xcodebuild', 'test-without-building', '-xctestrun', str(gate.test_runs['FeatureTests']),
            '-derivedDataPath', str(args.derived_data), '-parallel-testing-enabled', 'NO',
            '-collect-test-diagnostics', 'never', '-destination', f'platform=iOS Simulator,id={args.device}',
            *selectors,
        ]
        single.run_preparation(gate, 'enumerate', [
            *command, '-enumerate-tests', '-test-enumeration-style', 'flat',
            '-test-enumeration-format', 'json', '-test-enumeration-output-path',
            str(gate.output / 'enumeration.json'),
        ])
        report = json.loads((gate.output / 'enumeration.json').read_text())
        values = report.get('values', [])
        if report.get('errors') != [] or len(values) != 1:
            raise RuntimeError('Expected one successful enumeration configuration')
        expected = [test['identifier'] for test in values[0]['enabledTests']]
        if not expected or len(expected) != len(set(expected)):
            raise RuntimeError('Expected nonempty, unique test enumeration')
        for target in FEATURE_TARGETS:
            if not any(test.startswith(target + '/') for test in expected):
                raise RuntimeError(f'No tests enumerated for {target}')
        native.save_json(gate.output / 'expected-tests.json', expected)
        gate.run('feature-tests', ['test-without-building'], 'FeatureTests', args.device, FEATURE_TARGETS,
                 len(expected), expected_diagnostic_tests=DIAGNOSTIC_TESTS)
        result = validate_feature_results(native, gate.output, expected, args.device)
    if native.source_hashes() != gate.sources:
        raise RuntimeError('Sources changed during validation')
    native.save_json(gate.output / 'result.json', result)


if __name__ == '__main__':
    main()
