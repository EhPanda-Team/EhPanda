"""The Release isolation scanner must pass a clean build and reject every seeded capture leak."""

import importlib.util
import io
import json
from pathlib import Path
import plistlib
import tempfile
from types import SimpleNamespace
import unittest
from contextlib import redirect_stderr, redirect_stdout


def load_scanner():
    spec = importlib.util.spec_from_file_location('verify_release', Path(__file__).with_name('verify-release.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CLEAN_LOG = """Resolved source packages:
  swift-composable-architecture: https://github.com/pointfreeco/swift-composable-architecture @ 1.23.0
  swift-snapshot-testing: https://github.com/pointfreeco/swift-snapshot-testing @ 1.18.0

ComputeTargetDependencyGraph
note: Building targets in dependency order
note: Target dependency graph (3 targets)
    Target 'EhPanda' in project 'EhPanda'
        \u279c Explicit dependency on target 'AppFeature' in project 'AppPackage'
    Target 'AppFeature' in project 'AppPackage'
    Target 'ShareExtension' in project 'EhPanda'

SwiftCompile normal arm64 /src/App.swift (in target 'AppFeature' from project 'AppPackage')
    /Xcode/usr/bin/swift-frontend -c /src/App.swift -O -D RELEASE_BUILD -o /DD/Build/Intermediates.noindex/Release-iphonesimulator/App.o

** BUILD SUCCEEDED **
"""

CLEAN_LINK_MAP = """# Path: /DD/Build/Products/Release-iphonesimulator/EhPanda.app/EhPanda
# Arch: arm64
# Object files:
[  0] linker synthesized
[  1] /DD/Build/Intermediates.noindex/AppFeature.build/Release-iphonesimulator/AppFeature.build/Objects-normal/arm64/AppReducer.o
[  2] /DD/Build/Intermediates.noindex/AppFeature.build/Release-iphonesimulator/AppFeature.build/Objects-normal/arm64/CaptureScenePreparation.o
# Sections:
# Address\tSize    \tSegment\tSection
0x100000000\t0x00001000\t__TEXT\t__text
# Symbols:
# Address\tSize    \tFile  Name
0x100000000\t0x00000010\t[  1] _$s10AppFeature10AppReducerV4bodyQrvg
# Dead Stripped Symbols:
#        \tSize    \tFile  Name
<<dead>> \t0x00000010\t[  2] _$s10AppFeature23CaptureScenePreparationO7installyyKFZ
"""


class Fixture:
    """A clean Release-shaped bundle, build log and link map that each test then seeds."""

    def __init__(self, root):
        self.root = Path(root)
        self.app = self.root / 'EhPanda.app'
        (self.app / 'PlugIns' / 'ShareExtension.appex').mkdir(parents=True)
        with (self.app / 'Info.plist').open('wb') as handle:
            plistlib.dump({'CFBundleIdentifier': 'app.ehpanda'}, handle)
        (self.app / 'EhPanda').write_bytes(b'\xcf\xfa\xed\xfe AppReducer Home Settings \x00')
        (self.app / 'PlugIns' / 'ShareExtension.appex' / 'ShareExtension').write_bytes(b'\xcf\xfa\xed\xfe share')
        self.log = self.root / 'build.log'
        self.log.write_text(CLEAN_LOG)
        self.link_map = self.root / 'EhPanda-LinkMap-normal-arm64.txt'
        self.link_map.write_text(CLEAN_LINK_MAP)
        self.output = self.root / 'out'

    def args(self, **changes):
        values = {'app': self.app, 'build_log': self.log, 'link_map': [self.link_map], 'output': self.output,
                  'device': None, 'debug_control': None, 'wait': 0}
        values.update(changes)
        return SimpleNamespace(**values)


class ScannerTests(unittest.TestCase):
    def setUp(self):
        self.scanner = load_scanner()
        self.directory = tempfile.TemporaryDirectory()
        self.fixture = Fixture(self.directory.name)

    def tearDown(self):
        self.directory.cleanup()

    def kinds(self, report):
        return [finding['kind'] for finding in report['findings']]

    def test_clean_release_passes_and_records_its_evidence(self):
        report = self.scanner.verify(self.fixture.args())
        self.assertTrue(report['passed'], report['findings'])
        self.assertEqual(report['payloadFiles'], 3)
        self.assertEqual(report['graph']['targets'], ['AppFeature', 'EhPanda', 'ShareExtension'])
        self.assertEqual(report['graph']['resolutionOnly'], ['swift-snapshot-testing'])
        self.assertEqual(report['linkMaps'][0]['objects'], 3)
        self.assertEqual(report['linkMaps'][0]['symbols'], 1)
        written = json.loads((self.fixture.output / 'release-isolation.json').read_text())
        self.assertTrue(written['passed'])

    def test_seeded_bad_payload_fails_on_every_leak(self):
        (self.fixture.app / 'EhPanda').write_bytes(
            b'\xcf\xfa\xed\xfe EHPANDA_CAPTURE_CONFIGURATION capture_diagnostics '
            b'_$s10AppFeature23CaptureScenePreparationO')
        (self.fixture.app / 'EhPanda.debug.dylib').write_bytes(b'debug')
        fixtures = self.fixture.app / 'Fixtures'
        fixtures.mkdir()
        (fixtures / 'GalleryDetail.html').write_text('<html></html>')
        (self.fixture.app / 'AppPackage_VisualSnapshotTests.bundle' / '__Snapshots__').mkdir(parents=True)
        (self.fixture.app / 'PlugIns' / 'ShareExtension.appex' / 'ShareExtension').write_bytes(b'SnapshotTesting')
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            exit_code = self.scanner.main([
                '--app', str(self.fixture.app), '--build-log', str(self.fixture.log),
                '--link-map', str(self.fixture.link_map), '--output', str(self.fixture.output),
            ])
        self.assertEqual(exit_code, 1)
        report = json.loads((self.fixture.output / 'release-isolation.json').read_text())
        self.assertFalse(report['passed'])
        tokens = {finding.get('token') for finding in report['findings'] if finding['kind'] == 'content'}
        self.assertTrue({'EHPANDA_', 'capture_diagnostics', 'CaptureScene', 'SnapshotTesting'} <= tokens, tokens)
        paths = {finding['path'] for finding in report['findings'] if finding['kind'] == 'payload'}
        self.assertTrue({'EhPanda.debug.dylib', 'Fixtures', 'Fixtures/GalleryDetail.html',
                         'AppPackage_VisualSnapshotTests.bundle/__Snapshots__'} <= paths, paths)

    def test_clean_bundle_exits_zero(self):
        with redirect_stdout(io.StringIO()):
            exit_code = self.scanner.main([
                '--app', str(self.fixture.app), '--build-log', str(self.fixture.log),
                '--link-map', str(self.fixture.link_map), '--output', str(self.fixture.output),
            ])
        self.assertEqual(exit_code, 0)

    def test_linked_snapshot_library_and_live_capture_symbol_fail(self):
        self.fixture.link_map.write_text(CLEAN_LINK_MAP.replace(
            '# Sections:',
            '[  3] /DD/Build/Products/Release-iphonesimulator/SnapshotTesting.o\n# Sections:',
        ).replace(
            '# Dead Stripped Symbols:',
            '0x100000010\t0x00000010\t[  2] _$s10AppFeature23CaptureScenePreparationO7installyyKFZ\n'
            '# Dead Stripped Symbols:',
        ))
        report = self.scanner.verify(self.fixture.args())
        self.assertIn('link-object', self.kinds(report))
        self.assertIn('link-symbol', self.kinds(report))

    def test_dead_stripped_capture_symbol_and_empty_capture_object_are_not_linkage(self):
        objects, symbols = self.scanner.link_map_sections(CLEAN_LINK_MAP)
        self.assertEqual(len(objects), 3)
        self.assertEqual(symbols, ['_$s10AppFeature10AppReducerV4bodyQrvg'])

    def test_empty_link_map_fails(self):
        self.fixture.link_map.write_text('# Path: x\n')
        self.assertIn('link-map', self.kinds(self.scanner.verify(self.fixture.args())))

    def test_debug_define_in_a_compile_fails(self):
        self.fixture.log.write_text(CLEAN_LOG.replace('-D RELEASE_BUILD', '-D DEBUG'))
        self.assertIn('debug-define', self.kinds(self.scanner.verify(self.fixture.args())))

    def test_snapshot_target_in_the_graph_fails_even_though_resolution_alone_does_not(self):
        self.fixture.log.write_text(CLEAN_LOG.replace(
            "    Target 'ShareExtension' in project 'EhPanda'",
            "    Target 'ShareExtension' in project 'EhPanda'\n"
            "    Target 'SnapshotTesting' in project 'swift-snapshot-testing'",
        ))
        report = self.scanner.verify(self.fixture.args())
        self.assertIn({'kind': 'graph-target', 'target': 'SnapshotTesting'}, report['findings'])

    def test_failed_debug_or_graphless_build_log_fails(self):
        for text in (
            CLEAN_LOG.replace('** BUILD SUCCEEDED **', '** BUILD FAILED **'),
            CLEAN_LOG.replace('Release-iphonesimulator', 'Debug-iphonesimulator'),
            CLEAN_LOG.replace("Target '", "Built '"),
            CLEAN_LOG.replace('/Xcode/usr/bin/swift-frontend -c', 'echo'),
        ):
            with self.subTest(text=text[-80:]):
                self.fixture.log.write_text(text)
                self.assertIn('build-log', self.kinds(self.scanner.verify(self.fixture.args())))

    def test_coverage_instrumented_compile_fails(self):
        for flag in ('-profile-coverage-mapping -profile-generate', '-fprofile-instr-generate -fcoverage-mapping'):
            with self.subTest(flag=flag):
                self.fixture.log.write_text(CLEAN_LOG.replace('-D RELEASE_BUILD', f'-D RELEASE_BUILD {flag}'))
                self.assertIn('instrumented', self.kinds(self.scanner.verify(self.fixture.args())))

    def test_third_party_xctest_detection_strings_are_not_linkage(self):
        (self.fixture.app / 'EhPanda').write_bytes(
            b'\xcf\xfa\xed\xfe XCTestConfigurationFilePath XCTestObservationCenter '
            b'A failure was recorded without linking the XCTest framework')
        self.fixture.link_map.write_text(CLEAN_LINK_MAP.replace(
            '# Dead Stripped Symbols:',
            '0x100000010\t0x00000010\t[  1] literal string: XCTestConfigurationFilePath\n'
            '0x100000020\t0x00000010\t[  1] literal string: IssueReporting/XCTest.swift\n'
            '# Dead Stripped Symbols:',
        ))
        report = self.scanner.verify(self.fixture.args())
        self.assertTrue(report['passed'], report['findings'])

    def test_linked_xctest_or_testing_library_fails(self):
        for library in ('/SDK/Developer/Library/Frameworks/XCTest.framework/XCTest.tbd',
                        '/SDK/Developer/Library/Frameworks/Testing.framework/Testing.tbd'):
            with self.subTest(library=library):
                self.fixture.link_map.write_text(CLEAN_LINK_MAP.replace(
                    '# Sections:', f'[  3] {library}\n# Sections:'))
                report = self.scanner.verify(self.fixture.args())
                self.assertIn({'kind': 'link-object', 'path': str(self.fixture.link_map), 'object': library},
                              report['findings'])

    def test_inert_ui_test_shell_is_recorded_but_any_other_member_fails(self):
        shell = ''.join(
            f'0x1000001{index:02x}\t0x00000010\t[  1] {symbol}\n' for index, symbol in enumerate((
                '_$s10AppFeature16UITestAutomationO15prepareIfNeededyyFZ',
                '_$s10AppFeature16UITestAutomationO24shouldDetectClipboardURLSbvgZ',
                '_$s10AppFeature16UITestAutomationO24shouldDetectClipboardURLSbvpZMV',
                '_$s10AppFeature16UITestAutomationOMn',
                '_$s10AppFeature16UITestAutomationON',
                '_symbolic _____ 10AppFeature16UITestAutomationO',
                'l_$s10AppFeature16UITestAutomationOHn',
                'l_.str.16.UITestAutomation',
            )))
        (self.fixture.app / 'EhPanda').write_bytes(b'\xcf\xfa\xed\xfe UITestAutomation AppFeature')
        self.fixture.link_map.write_text(CLEAN_LINK_MAP.replace('# Dead Stripped Symbols:',
                                                                shell + '# Dead Stripped Symbols:'))
        report = self.scanner.verify(self.fixture.args())
        self.assertTrue(report['passed'], report['findings'])
        self.assertEqual({item['kind'] for item in report['accepted']}, {'inert-shell'})
        self.assertIn({'kind': 'inert-shell', 'path': 'EhPanda', 'token': 'UITestAutomation'}, report['accepted'])

        member = '_$s10AppFeature16UITestAutomationO7prepare11environmentAA0C13ConfigurationVSgSDyS2SG_tFZ'
        self.fixture.link_map.write_text(CLEAN_LINK_MAP.replace(
            '# Dead Stripped Symbols:', shell + f'0x100000200\t0x00000010\t[  1] {member}\n# Dead Stripped Symbols:'))
        report = self.scanner.verify(self.fixture.args())
        self.assertFalse(report['passed'])
        self.assertIn(member, [finding.get('symbol') for finding in report['findings']])
        self.assertIn({'kind': 'content', 'path': 'EhPanda', 'token': 'UITestAutomation'}, report['findings'])

    def test_ui_test_name_without_link_evidence_of_the_shell_fails(self):
        (self.fixture.app / 'EhPanda').write_bytes(b'\xcf\xfa\xed\xfe UITestAutomation')
        report = self.scanner.verify(self.fixture.args())
        self.assertIn({'kind': 'content', 'path': 'EhPanda', 'token': 'UITestAutomation'}, report['findings'])

    def test_release_that_ends_under_the_probe_fails(self):
        def launcher(app, device, wait):
            return {'alive': False}
        report = self.scanner.verify(self.fixture.args(device='UDID'), launcher=launcher)
        self.assertIn('activation', self.kinds(report))

    def test_debug_control_must_end_or_the_probe_proves_nothing(self):
        def launcher(app, device, wait):
            return {'alive': True}
        report = self.scanner.verify(self.fixture.args(device='UDID', debug_control=self.fixture.app),
                                     launcher=launcher)
        self.assertEqual(self.kinds(report), ['activation'])
        self.assertIn('Debug control survived', report['findings'][0]['token'])

    def test_release_surviving_and_debug_ending_passes(self):
        def launcher(app, device, wait):
            return {'alive': app == self.fixture.app}
        report = self.scanner.verify(
            self.fixture.args(device='UDID', debug_control=self.fixture.root / 'Debug.app'), launcher=launcher)
        self.assertTrue(report['passed'], report['findings'])


class LaunchTests(unittest.TestCase):
    def setUp(self):
        self.scanner = load_scanner()
        self.directory = tempfile.TemporaryDirectory()
        self.fixture = Fixture(self.directory.name)
        self.calls = []

    def tearDown(self):
        self.directory.cleanup()

    def runner(self, listing):
        def run(command, extra_environment=None):
            self.calls.append((command, extra_environment))
            stdout = {'launch': 'app.ehpanda: 4242\n', 'spawn': listing}.get(command[2], '')
            return SimpleNamespace(returncode=0, stdout=stdout, stderr='')
        return run

    def test_probe_launch_passes_every_key_to_the_app_and_reads_its_process(self):
        result = self.scanner.launch_survives(
            self.fixture.app, 'UDID', 0,
            runner=self.runner('PID\tStatus\tLabel\n4242\t0\tUIKitApplication:app.ehpanda[1a2b][rb-legacy]\n'),
            sleep=lambda _: None)
        self.assertEqual(result, {'bundle': 'app.ehpanda', 'launchExit': 0, 'pid': 4242, 'alive': True})
        launch = next(call for call in self.calls if call[0][2] == 'launch')
        self.assertEqual(launch[1], {f'SIMCTL_CHILD_{key}': value
                                     for key, value in self.scanner.PROBE_ENVIRONMENT.items()})

    def test_ended_process_reads_as_not_alive(self):
        result = self.scanner.launch_survives(
            self.fixture.app, 'UDID', 0, runner=self.runner('PID\tStatus\tLabel\n-\t134\tUIKitApplication:app.ehpanda\n'),
            sleep=lambda _: None)
        self.assertFalse(result['alive'])


if __name__ == '__main__':
    unittest.main()
