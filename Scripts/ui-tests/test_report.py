"""The UI test run's report (ui-tests.yml): what it lists, which skips it accepts and which names it refuses."""

import contextlib
import io
import json
from pathlib import Path
import re
import tempfile
import unittest

import report

ROOT = Path(__file__).resolve().parents[2]
PAD_PLAN = ROOT / 'UITests-iPad.xctestplan'
PHONE_PLAN = ROOT / 'UITests.xctestplan'
LOCAL_ONLY = ROOT / 'Scripts/ui-tests/local-only.json'
SOURCES = ROOT / 'EhPandaUITests'


def case(identifier, result='Passed', repetitions=()):
    children = [{'nodeType': 'Repetition', 'name': f'Repetition {index + 1}', 'result': each}
                for index, each in enumerate(repetitions)]
    return {'nodeType': 'Test Case', 'name': identifier.split('/')[1], 'nodeIdentifier': identifier,
            'result': result, 'children': children}


def document(*tests):
    """A `test-results tests` document: plan, bundle, one suite per class, the cases."""
    suites = {}
    for test in tests:
        suites.setdefault(test['nodeIdentifier'].split('/')[0], []).append(test)
    bundle = {'nodeType': 'UI test bundle', 'name': 'EhPandaUITests',
              'children': [{'nodeType': 'Test Suite', 'name': name, 'children': children}
                           for name, children in suites.items()]}
    return {'testNodes': [{'nodeType': 'Test Plan', 'name': 'UITests', 'children': [bundle]}]}


def plan(*names):
    return {'testTargets': [{'target': {'name': 'EhPandaUITests'}, 'selectedTests': list(names)}]}


def declared_tests():
    """`{class: {test}}` for every `XCTestCase` of the UI test sources."""
    declared = {}
    for path in sorted(SOURCES.glob('*.swift')):
        current = None
        for line in path.read_text(encoding='utf-8').splitlines():
            found = re.match(r'(?:final )?class (\w+): XCTestCase', line)
            if found:
                current = declared.setdefault(found.group(1), set())
            found = re.match(r'\s+func (test\w*)\(', line)
            if found and current is not None:
                current.add(f'{found.group(1)}()')
    return declared


class SortingTests(unittest.TestCase):
    def test_a_test_that_passed_at_once_is_passed(self):
        summary = report.summarize(document(case('A/testOne()'), case('A/testTwo()')))
        self.assertEqual(summary.passed, ['A/testOne()', 'A/testTwo()'])
        self.assertTrue(summary.ok)

    def test_a_test_that_failed_and_then_passed_is_retried_not_passed(self):
        summary = report.summarize(document(case('A/testOne()', repetitions=('Failed', 'Passed'))))
        self.assertEqual(summary.retried, ['A/testOne()'])
        self.assertEqual(summary.passed, [])
        # A retry reports; it does not fail the run that xcodebuild passed.
        self.assertTrue(summary.ok)

    def test_iterations_that_all_passed_are_not_a_retry(self):
        summary = report.summarize(document(case('A/testOne()', repetitions=('Passed', 'Passed'))))
        self.assertEqual(summary.passed, ['A/testOne()'])

    def test_a_failed_test_fails_the_report(self):
        summary = report.summarize(document(case('A/testOne()', 'Failed', ('Failed', 'Failed', 'Failed'))))
        self.assertEqual(summary.failed, ['A/testOne()'])
        self.assertFalse(summary.ok)

    def test_a_result_that_is_not_a_pass_is_not_counted_as_one(self):
        summary = report.summarize(document(case('A/testOne()', 'unknown'), case('A/testTwo()', None)))
        self.assertEqual(summary.failed, ['A/testOne()', 'A/testTwo()'])
        self.assertEqual(summary.passed, [])
        self.assertFalse(summary.ok)

    def test_an_expected_failure_is_counted_apart(self):
        summary = report.summarize(document(case('A/testOne()', 'Expected Failure')))
        self.assertEqual(summary.expected_failures, ['A/testOne()'])
        self.assertTrue(summary.ok)


class SkipTests(unittest.TestCase):
    def test_a_skip_nobody_named_fails_the_report(self):
        summary = report.summarize(document(case('A/testOne()', 'Skipped')), elsewhere=[], local_only=[])
        self.assertEqual(summary.unaccounted, ['A/testOne()'])
        self.assertFalse(summary.ok)

    def test_a_skip_another_plan_selects_is_accounted_for(self):
        tests = document(case('A/testOne()', 'Skipped'), case('A/testTwo()'))
        summary = report.summarize(tests, elsewhere=[('the iPad plan', ['A/testOne()'])])
        self.assertEqual(summary.accounted, {'the iPad plan': ['A/testOne()']})
        self.assertTrue(summary.ok)

    def test_a_class_name_accounts_for_all_of_its_tests_and_no_other_class(self):
        tests = document(case('Duo/testOne()', 'Skipped'), case('Duo/testTwo()', 'Skipped'),
                         case('DuoMore/testOne()', 'Skipped'))
        summary = report.summarize(tests, local_only=['Duo'])
        self.assertEqual(summary.accounted, {'local only': ['Duo/testOne()', 'Duo/testTwo()']})
        self.assertEqual(summary.unaccounted, ['DuoMore/testOne()'])

    def test_a_named_test_that_ran_is_not_a_fault(self):
        # The list says where a test may skip, not that it must.
        summary = report.summarize(document(case('A/testOne()')), local_only=['A/testOne()'])
        self.assertTrue(summary.ok)


class NameTests(unittest.TestCase):
    def test_a_name_that_is_no_test_of_the_run_fails_the_report(self):
        tests = document(case('A/testOne()'))
        summary = report.summarize(tests, elsewhere=[('the iPad plan', ['A/testRenamed()'])], local_only=['Gone'])
        self.assertEqual(summary.unmatched, [('the iPad plan', 'A/testRenamed()'), ('local only', 'Gone')])
        self.assertFalse(summary.ok)

    def test_the_runs_own_plan_must_have_run_every_test_it_selects(self):
        tests = document(case('A/testOne()'), case('A/testTwo()', 'Skipped'))
        summary = report.summarize(tests, elsewhere=[], local_only=[],
                                   expect=['A/testOne()', 'A/testTwo()', 'A/testRenamed()'])
        self.assertEqual(summary.unmatched, [('this run', 'A/testTwo()'), ('this run', 'A/testRenamed()')])
        self.assertEqual(summary.unaccounted, ['A/testTwo()'])
        self.assertFalse(summary.ok)

    def test_a_plan_that_selects_nothing_by_name_is_refused(self):
        with self.assertRaises(ValueError):
            report.selected({'testTargets': [{'target': {'name': 'EhPandaUITests'}, 'skippedTests': ['A']}]})


class RenderTests(unittest.TestCase):
    def test_the_summary_counts_and_lists_what_needs_reading(self):
        tests = document(case('A/testOne()'), case('A/testTwo()', repetitions=('Failed', 'Passed')),
                         case('A/testThree()', 'Failed'), case('B/testPad()', 'Skipped'),
                         case('C/testLost()', 'Skipped'))
        summary = report.summarize(tests, elsewhere=[('the iPad plan', ['B/testPad()'])], local_only=[])
        text = report.render(summary, 'UI tests (iphone)')
        self.assertIn('### UI tests (iphone): 2 passed, 1 failed, 2 skipped', text)
        self.assertIn('**Failed**\n\n- `A/testThree()`', text)
        self.assertIn('**Passed only on a retry**\n\n- `A/testTwo()`', text)
        self.assertIn('**Skipped and not accounted for**\n\n- `C/testLost()`', text)
        self.assertIn('1 skipped here, accounted for by the iPad plan.', text)
        self.assertNotIn('A/testOne()', text)


class CommandTests(unittest.TestCase):
    def run_report(self, tests, *arguments):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'tests.json'
            path.write_text(json.dumps(tests), encoding='utf-8')
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = report.main(['--title', 'UI tests', *arguments, str(path)])
        return status, output.getvalue()

    def test_the_iphones_run_accepts_the_skips_the_two_lists_name(self):
        pad = report.selected(json.loads(PAD_PLAN.read_text(encoding='utf-8')))
        local = list(json.loads(LOCAL_ONLY.read_text(encoding='utf-8'))['tests'])
        skipped = [case(name if '/' in name else f'{name}/testOne()', 'Skipped') for name in pad + local]
        status, text = self.run_report(document(case('A/testOne()'), *skipped),
                                       '--elsewhere', str(PAD_PLAN), '--local-only', str(LOCAL_ONLY))
        self.assertEqual(status, 0, text)
        self.assertIn(f'{len(pad)} skipped here, accounted for by the UITests-iPad plan.', text)
        self.assertIn(f'{len(local)} skipped here, accounted for by local only.', text)

    def test_the_ipads_run_fails_on_a_selected_test_that_did_not_run(self):
        pad = report.selected(json.loads(PAD_PLAN.read_text(encoding='utf-8')))
        status, text = self.run_report(document(*[case(name) for name in pad[1:]]), '--expect', str(PAD_PLAN))
        self.assertEqual(status, 1)
        self.assertIn(f'- `{pad[0]} (this run)`', text)
        status, _ = self.run_report(document(*[case(name) for name in pad]), '--expect', str(PAD_PLAN))
        self.assertEqual(status, 0)


class RepositoryTests(unittest.TestCase):
    """The two lists against the UI test sources, so a renamed or removed test is caught at the push, before a
    night's run names it."""

    def assert_declared(self, names, source):
        declared = declared_tests()
        self.assertGreater(len(declared), 20)
        for name in names:
            owner, _, test = name.partition('/')
            self.assertIn(owner, declared, f'{source} names a class that is not in EhPandaUITests: {name}')
            if test:
                self.assertIn(test, declared[owner], f'{source} names a test that is not in EhPandaUITests: {name}')

    def test_the_ipad_plan_selects_tests_that_exist(self):
        self.assert_declared(report.selected(json.loads(PAD_PLAN.read_text(encoding='utf-8'))), PAD_PLAN.name)

    def test_the_local_only_list_names_tests_that_exist_and_says_why(self):
        tests = json.loads(LOCAL_ONLY.read_text(encoding='utf-8'))['tests']
        self.assert_declared(tests, LOCAL_ONLY.name)
        for name, reason in tests.items():
            self.assertTrue(reason.strip(), f'{name} has no reason')

    def test_no_test_is_named_by_both_lists(self):
        pad = report.selected(json.loads(PAD_PLAN.read_text(encoding='utf-8')))
        local = json.loads(LOCAL_ONLY.read_text(encoding='utf-8'))['tests']
        for name in pad:
            self.assertFalse(any(report.covers(other, name) for other in local), name)

    def test_the_ipad_plan_sets_its_gate_and_keeps_the_iphone_plans_options(self):
        pad = json.loads(PAD_PLAN.read_text(encoding='utf-8'))
        phone = json.loads(PHONE_PLAN.read_text(encoding='utf-8'))
        options = dict(pad['defaultOptions'])
        self.assertEqual(options.pop('environmentVariableEntries'), [{'key': 'EHPANDA_IPAD_UI_TESTS', 'value': '1'}])
        self.assertEqual(options, phone['defaultOptions'])
        self.assertEqual([target['target'] for target in pad['testTargets']],
                         [target['target'] for target in phone['testTargets']])
        # Tests run in parallel unless the owner approved otherwise (AGENTS.md).
        self.assertTrue(all(target['parallelizable'] for target in pad['testTargets']))


if __name__ == '__main__':
    unittest.main()
