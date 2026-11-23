"""The lint gate's reading of build and SwiftLint output, and what it covers."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import app_storage_isolation
import lint_check
from lint_check import Finding

ROOT = lint_check.ROOT


class FindingsTests(unittest.TestCase):
    def found(self, text):
        return lint_check.ordered(lint_check.findings(text, ROOT))

    def test_a_compiler_warning_is_found_once_though_the_compiler_repeats_it_under_the_source_line(self):
        text = '\n'.join([
            f"{ROOT}/AppPackage/Tests/SomeTests/Some.swift:44:22: warning: 'init(frame:)' was deprecated in iOS 26.0",
            ' 42 |         let controller = UIHostingController(rootView: list)',
            ' 44 |         let window = UIWindow(frame: frame)',
            "    |                      `- warning: 'init(frame:)' was deprecated in iOS 26.0",
            ' 45 |         window.rootViewController = controller'
        ])
        self.assertEqual(self.found(text), [Finding(
            'AppPackage/Tests/SomeTests/Some.swift', 44, 22, 'warning', "'init(frame:)' was deprecated in iOS 26.0"
        )])

    def test_the_same_diagnostic_from_two_builds_is_one_finding(self):
        line = f'{ROOT}/App/EhPandaApp.swift:3:1: warning: unused'
        self.assertEqual(len(self.found(f'{line}\n{line}\n')), 1)

    def test_an_error_and_a_swiftlint_violation_are_found_with_their_severity(self):
        text = '\n'.join([
            f'{ROOT}/App/EhPandaApp.swift:9:5: error: cannot find \'x\' in scope',
            f'{ROOT}/EhPandaUITests/Some.swift:61:9: warning: Control Statement Violation: no parentheses '
            '(control_statement)'
        ])
        self.assertEqual([(item.path, item.severity) for item in self.found(text)], [
            ('App/EhPandaApp.swift', 'error'), ('EhPandaUITests/Some.swift', 'warning')
        ])

    def test_a_diagnostic_without_a_place_is_found_too(self):
        found = self.found('\n'.join([
            'ld: warning: object file was built for newer iOS-simulator version than being linked',
            'error: Build input file cannot be found: /tmp/missing.swift',
            'xcodebuild: error: Scheme EhPanda is not currently configured for the test action.'
        ]))
        self.assertEqual([item.severity for item in found], ['error', 'warning', 'error'])
        self.assertTrue(all(not item.path for item in found))

    def test_a_file_outside_the_repository_keeps_its_whole_path(self):
        found = self.found('/tmp/elsewhere/File.swift:1:1: warning: something')
        self.assertEqual(found[0].path, '/tmp/elsewhere/File.swift')

    def test_what_is_not_a_diagnostic_is_not_found(self):
        text = '\n'.join([
            '** TEST BUILD SUCCEEDED ** [75.043 sec]',
            f'{ROOT}/App/EhPandaApp.swift:3:1: note: add a conformance',
            '2026-11-15 18:29:14.667 xcodebuild[85776:47975195]  DVTAssertions: Warning in Recorder.m:747',
            '--- xcodebuild: WARNING: Using the first of multiple matching destinations:',
            "SwiftCompile normal arm64 Compiling\\ Warnings.swift /path/Warnings.swift (in target 'X')",
            'Error handling is described in ErrorView.swift'
        ])
        self.assertEqual(self.found(text), [])

    def test_located_findings_come_first_in_file_and_line_order(self):
        found = self.found('\n'.join([
            'error: no place',
            f'{ROOT}/B.swift:2:1: warning: second file',
            f'{ROOT}/A.swift:10:1: warning: later line',
            f'{ROOT}/A.swift:2:1: warning: earlier line'
        ]))
        self.assertEqual([str(item) for item in found], [
            'A.swift:2:1: warning: earlier line', 'A.swift:10:1: warning: later line',
            'B.swift:2:1: warning: second file', 'error: no place'
        ])


class ThirdPartyTests(unittest.TestCase):
    PACKAGES = Path('/build/SourcePackages')

    def judged(self, *lines, packages=PACKAGES):
        failing, allowed = lint_check.judged(lint_check.findings('\n'.join(lines), ROOT), packages, ROOT)
        return [str(item) for item in failing], [str(item) for item in allowed]

    def test_a_warning_inside_a_fetched_package_is_allowed(self):
        line = f'{self.PACKAGES}/checkouts/Kanna/Sources/Kanna/Kanna.swift:12:9: warning: never mutated'
        self.assertEqual(self.judged(line), ([], [line]))

    def test_a_warning_a_library_defines_fails_where_this_repository_triggers_it(self):
        # A deprecation a library declares and a diagnostic a library's macro emits point at the file that uses them.
        place = 'AppPackage/Sources/AppFeature/AppFeature.swift'
        deprecation = f"{place}:40:17: warning: 'send(_:animation:)' is deprecated: use 'send(_:)'"
        macro = f"{place}:12:1: warning: '@Reducer' has no effect on this declaration"
        self.assertEqual(self.judged(f'{ROOT}/{deprecation}', f'{ROOT}/{macro}'), ([macro, deprecation], []))

    def test_an_error_inside_a_fetched_package_fails(self):
        line = f'{self.PACKAGES}/checkouts/Kanna/Sources/Kanna/Kanna.swift:12:9: error: cannot find type'
        self.assertEqual(self.judged(line), ([line], []))

    def test_a_warning_without_a_place_is_allowed_only_where_its_line_names_a_fetched_file(self):
        named = f'ld: warning: object file ({self.PACKAGES}/artifacts/lib/libwebp.a) was built for a newer version'
        unnamed = "ld: warning: ignoring duplicate libraries: '-lc++'"
        self.assertEqual(self.judged(named, unnamed), ([unnamed], [named]))

    def test_a_file_beside_the_packages_is_not_third_party(self):
        line = '/build/SourcePackagesOfOurs/Thing.swift:1:1: warning: never mutated'
        self.assertEqual(self.judged(line), ([line], []))

    def test_packages_kept_inside_the_repository_are_third_party_too(self):
        packages = ROOT / '.build' / 'lint' / 'SourcePackages'
        line = f'{packages}/checkouts/Kanna/Sources/Kanna/Kanna.swift:12:9: warning: never mutated'
        failing, allowed = self.judged(line, packages=packages)
        self.assertEqual((failing, len(allowed)), ([], 1))


class ReportTests(unittest.TestCase):
    FINDINGS = [
        Finding('App/A.swift', 3, 7, 'warning', 'a 100% | odd message'),
        Finding('', 0, 0, 'error', 'error: no place')
    ]

    def test_only_a_finding_with_a_place_is_annotated_and_its_text_is_escaped(self):
        self.assertEqual(lint_check.annotate(self.FINDINGS), [
            '::warning file=App/A.swift,line=3,col=7::a 100%25 | odd message'
        ])

    def test_the_summary_counts_the_findings_and_keeps_a_table_cell_whole(self):
        summary = lint_check.summary(self.FINDINGS)
        self.assertTrue(summary.startswith('2 finding(s)'))
        self.assertIn('| `App/A.swift:3` | warning | a 100% &#124; odd message |', summary)

    def test_no_finding_says_so(self):
        self.assertIn('No compiler warning or error', lint_check.summary([]))

    def test_the_summary_lists_the_allowed_warnings_apart_from_the_failing_ones(self):
        ours = Finding('App/EhPandaApp.swift', 3, 1, 'warning', 'never mutated')
        theirs = Finding('/build/SourcePackages/checkouts/Kanna/Kanna.swift', 12, 9, 'warning', 'never used')
        text = lint_check.summary([ours], [theirs])
        self.assertIn('1 finding(s): each one fails the gate.', text)
        self.assertIn('1 warning(s) inside third-party packages, allowed.', text)
        self.assertLess(text.index('App/EhPandaApp.swift'), text.index('checkouts/Kanna'))
        self.assertIn('1 warning(s) inside third-party packages, allowed.', lint_check.summary([], [theirs]))


class BuildTests(unittest.TestCase):
    def test_the_build_runs_without_what_xcrun_adds_to_the_environment(self):
        # Started by the system's python3, the build of 2026-11-15 linked every test product of the package with
        # "using sysroot for 'macOS 27.2' but targeting 'arm64-apple-ios27.0.0-simulator'": 23 warnings of the
        # gate's own making.
        sdk = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
        developer = '/Applications/Xcode.app/Contents/Developer'
        environment = {
            'PATH': '/usr/bin', 'DEVELOPER_DIR': developer,
            'SDKROOT': sdk, 'CPATH': '/usr/local/include', 'LIBRARY_PATH': '/usr/local/lib'
        }
        self.assertEqual(
            lint_check.build_environment(environment), {'PATH': '/usr/bin', 'DEVELOPER_DIR': developer}
        )


class CoverageTests(unittest.TestCase):
    def test_the_plans_are_read_from_the_scheme_in_its_order(self):
        with tempfile.TemporaryDirectory() as directory:
            scheme = Path(directory) / 'Some.xcscheme'
            scheme.write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme><TestAction><TestPlans>
<TestPlanReference reference = "container:AppPackage/Tests/FeatureTests.xctestplan" default = "YES"/>
<TestPlanReference reference = "container:UITests.xctestplan"/>
<TestPlanReference reference = "container:AppPackage/Tests/FeatureTests.xctestplan"/>
</TestPlans></TestAction></Scheme>''')
            self.assertEqual(lint_check.scheme_test_plans(scheme), ['FeatureTests', 'UITests'])

    def test_the_app_scheme_lists_the_plans_that_build_every_test_target(self):
        scheme = ROOT / lint_check.PROJECT / 'xcshareddata' / 'xcschemes' / f'{lint_check.SCHEME}.xcscheme'
        plans = lint_check.scheme_test_plans(scheme)
        # The package's test targets and the app-hosted tests, the live check's target, and the UI tests.
        for plan in ('FeatureTests', 'LiveCheck', 'UITests'):
            self.assertIn(plan, plans)

    def test_a_module_with_swift_files_and_no_configuration_is_reported_and_one_without_swift_files_is_not(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for module, files in {
                'AppPackage/Sources/Configured': ['.swiftlint.yml', 'A.swift'],
                'AppPackage/Sources/Bare': ['Nested/B.swift'],
                'AppPackage/Sources/ObjectiveC': ['C.m'],
                'AppPackage/Tests/ConfiguredTests': ['.swiftlint.yml', 'D.swift'],
                'EhPandaUITests': ['.swiftlint.yml', 'E.swift']
            }.items():
                for name in files:
                    path = root / module / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('')
            configured, missing = lint_check.swift_modules(root)
            self.assertEqual([str(path.relative_to(root)) for path in configured], [
                'EhPandaUITests', 'AppPackage/Sources/Configured', 'AppPackage/Tests/ConfiguredTests'
            ])
            self.assertEqual([str(path.relative_to(root)) for path in missing], ['AppPackage/Sources/Bare'])

    def test_every_module_of_this_repository_has_its_configuration(self):
        self.assertEqual(lint_check.swift_modules(ROOT)[1], [])

    def test_every_swift_file_of_this_repository_is_in_a_place_the_gate_lints(self):
        # A new top-level folder of Swift sources has to be added to the gate, or its files are never linted.
        tracked = subprocess.run(
            ['git', 'ls-files', '*.swift'], cwd=ROOT, capture_output=True, text=True, check=True
        ).stdout.splitlines()
        self.assertGreater(len(tracked), 800)
        self.assertEqual([path for path in tracked if not lint_check.is_linted(path)], [])

    def test_a_file_beside_the_modules_or_in_an_unknown_folder_is_not_linted(self):
        self.assertTrue(lint_check.is_linted('AppPackage/Sources/AppModels/Gallery.swift'))
        self.assertTrue(lint_check.is_linted('AppPackage/Package.swift'))
        self.assertTrue(lint_check.is_linted('App/EhPandaApp.swift'))
        self.assertFalse(lint_check.is_linted('AppPackage/Sources/Stray.swift'))
        self.assertFalse(lint_check.is_linted('NewExtension/Entry.swift'))
        self.assertFalse(lint_check.is_linted('AppFoo/Entry.swift'))


class AppStorageIsolationTests(unittest.TestCase):
    def test_each_break_of_the_rule_is_an_error_finding_at_its_place(self):
        breaks = [
            app_storage_isolation.Violation(
                'AppPackage/Tests/SomeTests/Some.swift', 4,
                'The suite Some can reach app storage and has no .isolatedAppStorage trait.'
            ),
            app_storage_isolation.Violation(
                'AppPackage/Package.swift', 0,
                'The test target SomeTests holds suites that need .isolatedAppStorage and does not link TestingSupport.'
            )
        ]
        with mock.patch.object(app_storage_isolation, 'violations', return_value=breaks):
            self.assertEqual(lint_check.app_storage_findings(ROOT), {
                Finding(
                    'AppPackage/Tests/SomeTests/Some.swift', 4, 1, 'error',
                    'The suite Some can reach app storage and has no .isolatedAppStorage trait.'
                ),
                Finding(
                    'AppPackage/Package.swift', 0, 0, 'error',
                    'The test target SomeTests holds suites that need .isolatedAppStorage and does not link '
                    'TestingSupport.'
                )
            })

    def test_a_tree_the_check_cannot_read_is_a_finding(self):
        error = app_storage_isolation.ScopeError('no app-storage keys')
        with mock.patch.object(app_storage_isolation, 'violations', side_effect=error):
            self.assertEqual(lint_check.app_storage_findings(ROOT), {
                Finding(
                    '', 0, 0, 'error', 'The app-storage isolation check could not read the tree: no app-storage keys'
                )
            })

    def test_every_suite_of_this_repository_keeps_the_app_storage_isolation_rule(self):
        self.assertEqual(lint_check.app_storage_findings(ROOT), set())


if __name__ == '__main__':
    unittest.main()
