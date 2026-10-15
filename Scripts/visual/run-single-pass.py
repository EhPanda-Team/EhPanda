#!/usr/bin/env python3
"""Build, enumerate and run selected UITests once through the native gate."""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
from pathlib import Path
import subprocess
import tempfile
import uuid

import environment


@contextmanager
def simulator_test_window(device):
    """Serialize this helper per dedicated simulator, allowing independent devices to run."""
    identifier = uuid.UUID(device)
    lock_path = Path(tempfile.gettempdir()) / f'ehpanda-tests-{identifier}.lock'
    with lock_path.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(f'Waiting for the selected simulator {identifier}.', flush=True)
            fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def run_preparation(gate, name, command):
    (gate.output / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
    with (gate.output / f'{name}.log').open('w') as log:
        result = subprocess.run(command, cwd=environment.ROOT, stdout=log, stderr=subprocess.STDOUT)
    (gate.output / f'{name}.exit.json').write_text(json.dumps({'exitCode': result.returncode}) + '\n')
    if result.returncode:
        raise RuntimeError(f'{name} exited {result.returncode}; inspect {gate.output / (name + ".log")}')


def enumerated_tests(report, selectors):
    configurations = report.get('values')
    if report.get('errors') != [] or not isinstance(configurations, list) or len(configurations) != 1:
        raise RuntimeError('Expected one successful UITests enumeration configuration')
    configuration = configurations[0]
    if (not isinstance(configuration, dict) or configuration.get('testPlan') != 'UITests'
            or not isinstance(configuration.get('disabledTests'), list)):
        raise RuntimeError('Expected an explicit UITests enabled/disabled selection')
    tests = configuration.get('enabledTests')
    if not isinstance(tests, list) or not tests:
        raise RuntimeError('The selection matched zero tests')
    identifiers = []
    for test in tests:
        identifier = test.get('identifier') if isinstance(test, dict) else None
        if not isinstance(identifier, str) or not identifier.startswith('EhPandaUITests/'):
            raise RuntimeError('Enumeration contains an unexpected test target')
        identifier = identifier.removesuffix('()')
        if len(identifier.split('/')) != 3 or any(not part for part in identifier.split('/')):
            raise RuntimeError('Enumeration did not identify individual UI test methods')
        identifiers.append(identifier)
    if len(identifiers) != len(set(identifiers)):
        raise RuntimeError('Enumeration repeated a test')

    def matches(identifier, selector):
        selector = selector.removesuffix('()')
        return identifier == selector or identifier.startswith(selector + '/')

    for test in configuration['disabledTests']:
        identifier = test.get('identifier') if isinstance(test, dict) else None
        if not isinstance(identifier, str) or not identifier.startswith('EhPandaUITests/'):
            raise RuntimeError('Disabled-test enumeration contains an unexpected test identity')
        identifier = identifier.removesuffix('()')
        if identifier in identifiers:
            raise RuntimeError('A test is both enabled and disabled')
        if not selectors or any(matches(identifier, selector) for selector in selectors):
            raise RuntimeError('A requested test is disabled')
    if any(not any(matches(identifier, selector) for identifier in identifiers) for selector in selectors):
        raise RuntimeError('A requested selector matched zero tests')
    if selectors and any(not any(matches(identifier, selector) for selector in selectors) for identifier in identifiers):
        raise RuntimeError('Enumeration includes an unrequested test')
    return sorted(identifiers)


def verify_test_identity(native, tree, expected):
    cases = [node for node in native.nodes(tree) if node.get('nodeType') == 'Test Case']
    actual = []
    for case in cases:
        identifier = case.get('nodeIdentifier')
        if not isinstance(identifier, str) or case.get('result') != 'Passed':
            raise RuntimeError('Every enumerated test must have one passing result')
        actual.append('EhPandaUITests/' + identifier.removesuffix('()'))
    if sorted(actual) != expected:
        raise RuntimeError('Result tests differ from the enumerated selection, or a test ran more than once')


def execute(args):
    native = environment.load_native_gate()
    gate = native.Gate(args)
    build = ['xcodebuild', 'build-for-testing', *gate.common, '-testPlan', 'UITests',
             '-destination', 'generic/platform=iOS Simulator',
             '-resultBundlePath', str(gate.output / 'build.xcresult')]
    print(f'Single-pass evidence: {gate.output}', flush=True)
    run_preparation(gate, 'build', build)
    build_result = json.loads(subprocess.check_output([
        'xcrun', 'xcresulttool', 'get', 'build-results', '--path', str(gate.output / 'build.xcresult')], text=True))
    native.save_json(gate.output / 'build-results.json', build_result)
    if (build_result.get('status') != 'succeeded' or build_result.get('errorCount') != 0
            or build_result.get('warningCount') != 0):
        raise RuntimeError('The build must succeed without warnings or errors')
    if native.source_hashes() != gate.sources:
        raise RuntimeError('Sources changed during the build; start a fresh run')
    gate.single_pass_run('UITests')
    enumeration = ['xcodebuild', 'test-without-building', '-xctestrun', str(gate.test_runs['UITests']),
                   '-derivedDataPath', str(args.derived_data.resolve()), '-parallel-testing-enabled', 'NO',
                   '-collect-test-diagnostics', 'never',
                   '-destination', f'platform=iOS Simulator,id={args.device}',
                   *[f'-only-testing:{test}' for test in args.only_testing],
                   '-enumerate-tests', '-test-enumeration-style', 'flat', '-test-enumeration-format', 'json',
                   '-test-enumeration-output-path', str(gate.output / 'enumeration.json'),
                   '-resultBundlePath', str(gate.output / 'enumeration.xcresult')]
    with simulator_test_window(args.device), gate.simulator_session('selected', args.device):
        run_preparation(gate, 'enumerate', enumeration)
        expected = enumerated_tests(json.loads((gate.output / 'enumeration.json').read_text()), args.only_testing)
        native.save_json(gate.output / 'expected-tests.json', expected)
        gate.run('selected-tests', ['test-without-building'], 'UITests', args.device, expected, len(expected))
        verify_test_identity(native, json.loads((gate.output / 'selected-tests.tests.json').read_text()), expected)
    if native.source_hashes() != gate.sources:
        raise RuntimeError('Sources changed during the run; evidence is not valid for the final tree')
    native.save_json(gate.output / 'result.json', {'status': 'passed', 'testCount': len(expected)})


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('--device', required=True, help='Current simulator UDID; run phone and tablet serially')
    result.add_argument('--only-testing', action='append', default=[], help='Target, suite or method; repeat to combine')
    result.add_argument('--output', type=Path, help='New evidence directory; default .capture/single-pass/<timestamp>')
    result.add_argument('--derived-data', type=Path, help='Build directory; default <output>/DerivedData')
    return result


def main():
    args = parser().parse_args()
    if args.output is None:
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        args.output = environment.ROOT / '.capture/single-pass' / stamp
    if args.derived_data is None:
        args.derived_data = args.output / 'DerivedData'
    execute(args)


if __name__ == '__main__':
    main()
