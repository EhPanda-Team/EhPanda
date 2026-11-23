"""The app-storage isolation rule: which suites need `.isolatedAppStorage`, what breaks it, and what `apply` adds."""
from pathlib import Path
import tempfile
import textwrap
import unittest

import app_storage_isolation

PACKAGE = '''\
enum Module: String {
    case appModels = "AppModels"
    case dependent = "Dependent"
    case plain = "Plain"
    case reader = "Reader"
    case testingSupport = "TestingSupport"
    case appModelsTests = "AppModelsTests"
    case dependentTests = "DependentTests"
    case plainTests = "PlainTests"
    case readerTests = "ReaderTests"
    case hostedViewTests = "HostedViewTests"
    case visualSnapshotTests = "VisualSnapshotTests"
}
let targets: [Target] = [
    .target(
        module: .appModels,
        dependencies: []
    ),
    .target(
        module: .dependent,
        dependencies: [
            .module(.reader)
        ]
    ),
    .target(
        module: .plain,
        dependencies: [
            .module(.appModels)
        ]
    ),
    .target(
        module: .reader,
        dependencies: [
            .module(.appModels)
        ]
    ),
    .testTarget(
        module: .appModelsTests,
        dependencies: [
            .module(.appModels)
        ]
    ),
    .testTarget(
        module: .dependentTests,
        dependencies: [
            .module(.dependent),
            .module(.testingSupport)
        ]
    ),
    .testTarget(
        module: .plainTests,
        dependencies: [
            .module(.plain)
        ]
    ),
    .testTarget(
        module: .readerTests,
        dependencies: [
            .module(.reader),
            .module(.testingSupport)
        ]
    )
]
'''

KEYS = '''\
extension SharedKey where Self == AppStorageKey<Setting>.Default {
    public static var setting: Self {
        Self[.appStorage("setting"), default: Setting()]
    }
}
'''


def suite(name, imports=('Testing',), attributes=(), body='@Test func works() {}'):
    lines = [f'import {module}' for module in imports] + [''] + list(attributes) + [f'struct {name} {{']
    lines += ['    ' + line for line in body.split('\n')] + ['}', '']
    return '\n'.join(lines)


class RuleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.write('AppPackage/Package.swift', PACKAGE)
        self.write('AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift', KEYS)
        self.write('AppPackage/Sources/Reader/Reader.swift', 'struct Reader {\n    @Shared(.setting) var setting\n}\n')
        self.write('AppPackage/Sources/Dependent/Dependent.swift', 'import Reader\nstruct Dependent {}\n')
        self.write('AppPackage/Sources/Plain/Plain.swift', '// @Shared(.setting) in a comment\nstruct Plain {}\n')

    def tearDown(self):
        self.directory.cleanup()

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def read(self, path):
        return (self.root / path).read_text()

    def violations(self):
        return [str(item) for item in app_storage_isolation.violations(self.root)]

    def needed(self):
        return [name for _, name in app_storage_isolation.scope(self.root).needed]

    def test_a_reader_module_is_found_through_a_dependency_and_key_declarations_alone_do_not_make_one(self):
        self.assertEqual(app_storage_isolation.scope(self.root).readers, ['Dependent', 'Reader'])

    def test_a_suite_whose_file_imports_a_reader_module_and_lacks_the_trait_breaks_the_rule(self):
        self.write(
            'AppPackage/Tests/DependentTests/DependentSuite.swift', suite('DependentSuite', ('Dependent', 'Testing'))
        )
        self.assertEqual(self.violations(), [
            'AppPackage/Tests/DependentTests/DependentSuite.swift:4: '
            'The suite DependentSuite can reach app storage and has no .isolatedAppStorage trait.'
        ])

    def test_a_file_that_names_app_storage_needs_the_trait_without_importing_a_reader_module(self):
        for name, body in {
            'Assigns': '@Test func works() {\n    _ = defaultAppStorage\n}',
            'Types': '@Test func works() {\n    let value: UserDefaults? = nil\n}',
            'Keys': '@Test func works() {\n    @Shared(.setting) var setting\n}'
        }.items():
            self.write(f'AppPackage/Tests/PlainTests/{name}.swift', suite(name, body=body))
        self.assertEqual(sorted(self.needed()), ['Assigns', 'Keys', 'Types'])

    def test_words_in_comments_and_strings_do_not_select_a_suite(self):
        body = '\n'.join([
            '// UserDefaults and defaultAppStorage',
            '@Test func works() {',
            '    _ = "@Shared(.setting) UserDefaults"',
            '}'
        ])
        self.write('AppPackage/Tests/PlainTests/Quiet.swift', suite('Quiet', body=body))
        self.assertEqual(self.needed(), [])
        self.assertEqual(self.violations(), [])

    def test_the_trait_on_a_suite_that_cannot_reach_app_storage_breaks_the_rule(self):
        self.write('AppPackage/Tests/PlainTests/Quiet.swift', suite(
            'Quiet', ('Testing', 'TestingSupport'), ['@Suite(.isolatedAppStorage)']
        ))
        self.assertEqual(self.violations(), [
            'AppPackage/Tests/PlainTests/Quiet.swift:4: '
            '.isolatedAppStorage belongs only on the top-level suite of a file that can reach app storage.'
        ])

    def test_an_extension_file_that_reaches_selects_the_suite_declared_elsewhere_in_its_target_only(self):
        self.write('AppPackage/Tests/PlainTests/Shared.swift', suite('Shared'))
        self.write('AppPackage/Tests/ReaderTests/Shared.swift', suite('Shared'))
        self.write(
            'AppPackage/Tests/PlainTests/Shared+Storage.swift',
            'import Testing\n\nextension Shared {\n    @Test func stores() {\n        _ = defaultAppStorage\n    }\n}\n'
        )
        self.assertEqual(app_storage_isolation.scope(self.root).needed, [('PlainTests', 'Shared')])

    def test_a_carrier_without_the_import_and_a_target_without_the_link_break_the_rule(self):
        self.write('AppPackage/Tests/AppModelsTests/Keys.swift', suite(
            'Keys', attributes=['@Suite(.isolatedAppStorage)'],
            body='@Test func works() {\n    _ = defaultAppStorage\n}'
        ))
        self.assertEqual(self.violations(), [
            'AppPackage/Package.swift: The test target AppModelsTests holds suites that need .isolatedAppStorage and '
            'does not link TestingSupport.',
            'AppPackage/Tests/AppModelsTests/Keys.swift: This file carries .isolatedAppStorage and does not import '
            'TestingSupport.'
        ])

    def test_hosted_view_and_visual_snapshot_tests_are_out_of_scope(self):
        for target in app_storage_isolation.OUT_OF_SCOPE:
            self.write(f'AppPackage/Tests/{target}/Hosted.swift', suite('Hosted', ('Reader', 'Testing')))
        self.assertEqual(self.needed(), [])
        self.assertEqual(self.violations(), [])
        self.assertIn('HostedViewTests', app_storage_isolation.OUT_OF_SCOPE)
        self.assertIn('VisualSnapshotTests', app_storage_isolation.OUT_OF_SCOPE)

    def test_a_value_use_of_the_trait_is_not_an_application_of_it(self):
        body = '@Test func scope() {\n    let trait: IsolatedAppStorageTrait = .isolatedAppStorage\n}'
        self.write('AppPackage/Tests/ReaderTests/TraitTests.swift', suite(
            'TraitTests', ('Reader', 'Testing', 'TestingSupport'), ['@Suite(.isolatedAppStorage)'], body
        ))
        self.assertEqual(self.violations(), [])

    def test_apply_adds_the_trait_and_the_import_once_and_then_the_rule_holds(self):
        self.write('AppPackage/Tests/ReaderTests/Bare.swift', suite('Bare', ('Reader', 'Testing'), ['@Suite']))
        self.write('AppPackage/Tests/ReaderTests/Named.swift', suite(
            'Named', ('Reader', 'Testing'), ['@MainActor', '@Suite(.timeLimit(.minutes(1)))']
        ))
        self.write('AppPackage/Tests/ReaderTests/Implicit.swift', suite(
            'Implicit', ('Reader', 'Testing', 'UIKit'), ['/// A suite.', '@MainActor']
        ))
        self.assertEqual(app_storage_isolation.apply(self.root), [
            'AppPackage/Tests/ReaderTests/Bare.swift', 'AppPackage/Tests/ReaderTests/Implicit.swift',
            'AppPackage/Tests/ReaderTests/Named.swift'
        ])
        self.assertEqual(self.read('AppPackage/Tests/ReaderTests/Bare.swift'), textwrap.dedent('''\
            import Reader
            import Testing
            import TestingSupport

            @Suite(.isolatedAppStorage)
            struct Bare {
                @Test func works() {}
            }
            '''))
        self.assertIn('@MainActor\n@Suite(.timeLimit(.minutes(1)), .isolatedAppStorage)\nstruct Named',
                      self.read('AppPackage/Tests/ReaderTests/Named.swift'))
        self.assertIn(
            'import TestingSupport\nimport UIKit\n\n/// A suite.\n@Suite(.isolatedAppStorage)\n@MainActor\n',
            self.read('AppPackage/Tests/ReaderTests/Implicit.swift')
        )
        self.assertEqual(self.violations(), [])
        self.assertEqual(app_storage_isolation.apply(self.root), [])

    def test_apply_limited_to_files_edits_only_those_and_refuses_a_file_out_of_scope(self):
        self.write('AppPackage/Tests/ReaderTests/One.swift', suite('One', ('Reader', 'Testing')))
        self.write('AppPackage/Tests/ReaderTests/Two.swift', suite('Two', ('Reader', 'Testing')))
        self.assertEqual(app_storage_isolation.apply(self.root, ['AppPackage/Tests/ReaderTests/One.swift']), [
            'AppPackage/Tests/ReaderTests/One.swift'
        ])
        self.assertEqual(len(self.violations()), 1)
        with self.assertRaises(app_storage_isolation.ScopeError):
            app_storage_isolation.apply(self.root, ['AppPackage/Tests/ReaderTests/Missing.swift'])

    def test_a_tree_without_app_storage_keys_cannot_be_checked(self):
        self.write('AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift', 'struct Nothing {}\n')
        with self.assertRaises(app_storage_isolation.ScopeError):
            app_storage_isolation.violations(self.root)


if __name__ == '__main__':
    unittest.main()
