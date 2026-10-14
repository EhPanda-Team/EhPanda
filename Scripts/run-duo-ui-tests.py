#!/usr/bin/env python3
"""Run built Duo UI tests with a host driver for real simulator hinge and orientation changes.

Prepare the hinge pose with foldctl first, then run:
  python3 Scripts/run-duo-ui-tests.py --device UDID --xctestrun PATH -- \
    -only-testing:EhPandaUITests/DuoHomeUITests

For ReadingOrientationUITests on the closed display, add --cover-display before --.

DuoPose sends requests through a temporary directory. Each request is acknowledged only
once foldctl succeeds. The source test manifest is preserved. Requires foldctl on PATH
(or --foldctl PATH), Xcode and an already booted Duo simulator.
"""

import argparse
import plistlib
import signal
import subprocess
import tempfile
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--xctestrun', required=True, type=Path)
    parser.add_argument('--foldctl', default='foldctl')
    parser.add_argument('--cover-display', action='store_true', help='Test the closed Duo cover display')
    parser.add_argument('test_arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    source = args.xctestrun.resolve()
    config = plistlib.loads(source.read_bytes())
    extra = args.test_arguments
    if extra[:1] == ['--']:
        extra = extra[1:]

    with tempfile.TemporaryDirectory(prefix='ehpanda-duo-pose-') as temporary:
        directory = Path(temporary)
        for run in config['TestConfigurations']:
            for target in run['TestTargets']:
                environment = target.setdefault('EnvironmentVariables', {})
                environment['EHPANDA_DUO_UI_TESTS'] = '1'
                environment['EHPANDA_DUO_COVER_DISPLAY'] = '1' if args.cover_display else '0'
                environment['EHPANDA_DUO_POSE_DIRECTORY'] = str(directory)
        # __TESTROOT__ paths remain relative to Products, including the application under test.
        with tempfile.NamedTemporaryFile(dir=source.parent, suffix='.xctestrun') as manifest:
            manifest.write(plistlib.dumps(config))
            manifest.flush()
            process = subprocess.Popen([
                'xcodebuild', 'test-without-building', '-xctestrun', manifest.name,
                '-destination', f'platform=iOS Simulator,id={args.device}',
                '-parallel-testing-enabled', 'NO', *extra
            ])
            last_request = None
            try:
                while process.poll() is None:
                    request_file = directory / 'request'
                    if request_file.exists():
                        request = request_file.read_text().splitlines()
                        if len(request) != 2 or request[1] not in {
                            'portrait', 'landscape-left', 'closed', 'half', 'open'
                        }:
                            raise ValueError(f'Invalid Duo pose request: {request!r}')
                        identifier, pose = request
                        if identifier != last_request:
                            option = '--orientation' if pose in {'portrait', 'landscape-left'} else '--hinge'
                            subprocess.run([args.foldctl, args.device, option, pose], check=True)
                            (directory / 'acknowledgement').write_text(identifier)
                            last_request = identifier
                    time.sleep(0.1)
                return process.returncode
            finally:
                if process.poll() is None:
                    process.send_signal(signal.SIGINT)
                    process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
