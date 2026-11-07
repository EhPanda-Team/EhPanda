"""The test network guard in both directions (19-03; 19-RESEARCH §8, Pitfall 1).

`LiveCheckTests` reads the live site, so it must not link `TestNetworkGuard`, or every page looks unreachable. Every
other package test target must link it, or a test that forgets a stub reaches the live site again (18-UAT, gap of
test 10). The checks read `AppPackage/Package.swift`: test targets are declared only through `testTarget(module:)`,
which adds the guard, or `liveCheckTestTarget(dependencies:)`, which does not, and only for `LiveCheckTests`.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / 'AppPackage/Package.swift'
GUARD = '.module(.testNetworkGuard)'


def helper_body(source, name):
    """The body of the `static func <name>(` helper, up to the closing brace at its own indent."""
    match = re.search(rf'^(\s*)static func {name}\(.*?^\1}}$', source, re.S | re.M)
    if match is None:
        raise AssertionError(f'Package.swift has no {name} helper')
    return match.group(0)


def target_list(source):
    """The `let targets` array, where every target is declared."""
    start = source.index('let targets: [PackageDescription.Target] = [')
    end = source.index('\n]\n', start)
    return source[start:end]


def declarations(targets):
    """`[(helper, first argument)]` for each test target declaration in the target list."""
    return re.findall(r'^\s{4}\.(testTarget|liveCheckTestTarget)\(\s*(\w+:\s*[^,\n]*)?', targets, re.M)


class NetworkGuardTests(unittest.TestCase):
    def setUp(self):
        self.source = PACKAGE.read_text()
        self.targets = target_list(self.source)
        self.declared = declarations(self.targets)

    def test_the_shared_helper_links_the_guard(self):
        body = helper_body(self.source, 'testTarget')
        self.assertIn(f'(dependencies + [{GUARD}])', body)

    def test_the_live_check_helper_does_not_link_the_guard(self):
        body = helper_body(self.source, 'liveCheckTestTarget')
        self.assertNotIn('testNetworkGuard', body)
        self.assertIn('Module.liveCheckTests.rawValue', body)

    def test_every_other_test_target_goes_through_the_shared_helper(self):
        shared = [argument for helper, argument in self.declared if helper == 'testTarget']
        self.assertGreater(len(shared), 20)
        for argument in shared:
            self.assertRegex(argument, r'^module:\s*\.\w+$', 'A test target bypasses testTarget(module:)')
            self.assertNotIn('liveCheckTests', argument)

    def test_live_check_tests_is_declared_once_without_the_guard(self):
        self.assertEqual([helper for helper, _ in self.declared].count('liveCheckTestTarget'), 1)
        start = self.targets.index('.liveCheckTestTarget(')
        end = self.targets.index('\n    ),', start)
        self.assertNotIn('testNetworkGuard', self.targets[start:end])

    def test_no_test_target_is_declared_any_other_way(self):
        self.assertEqual(len(re.findall(r'\.testTarget\(', self.targets)), len(
            [helper for helper, _ in self.declared if helper == 'testTarget']))
        self.assertNotIn('testTarget(name:', self.targets)

    def test_the_parsers_see_a_guard_removal(self):
        broken = self.source.replace(f'(dependencies + [{GUARD}])', 'dependencies')
        self.assertNotIn(f'(dependencies + [{GUARD}])', helper_body(broken, 'testTarget'))
        leaked = self.source.replace('.liveCheckTestTarget(\n        dependencies: [\n',
                                     f'.liveCheckTestTarget(\n        dependencies: [\n            {GUARD},\n')
        start = target_list(leaked).index('.liveCheckTestTarget(')
        end = target_list(leaked).index('\n    ),', start)
        self.assertIn('testNetworkGuard', target_list(leaked)[start:end])


if __name__ == '__main__':
    unittest.main()
