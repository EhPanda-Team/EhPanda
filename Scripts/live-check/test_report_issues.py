"""The live check's issue reporter against a recording `gh` (19-15; 19-CONTEXT D-22, D-23; T-19-32, T-19-33).

Every test runs `report_issues.py` as the scripts do, with `--gh` pointing at `fake-gh/gh`, which appends each
argument list it receives to `$FAKE_GH_LOG` and keeps the open issues in `$FAKE_GH_STATE`. No test reaches GitHub.
Each test has its own temporary directory, so the tests share nothing.
"""
from pathlib import Path
import ast
import importlib.util
import json
import os
import re
import shutil
import string
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REPORTER = HERE / 'report_issues.py'
FAKE_GH = HERE / 'fake-gh/gh'
LIVE_CHECK = ROOT / 'AppPackage/Tests/LiveCheckTests'
REPO = 'example-owner/example-repo'

GUEST_PAGES = ('frontPage', 'search', 'popular', 'toplists', 'gallery', 'reader', 'readerImage', 'tagSuggestions',
               'reportForm')
SIGNED_IN_PAGES = ('watched', 'favorites', 'exhentai')

# Text that looks like page content. None of it may reach `gh` or the reporter's output.
CONTENT_MARKERS = ('Sample Gallery Title', 'example.org', '987654', 'abcdef0123', 'session-cookie-value',
                   'reader@example.com')


def load_reporter():
    spec = importlib.util.spec_from_file_location('report_issues', REPORTER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def results(day, mode='local', **overrides):
    """A schema 1 results document for 2026-11-<day>: every guest page `ok` (200) and every signed-in page
    `skipped`, except the pages named in `overrides` as `(classification, expectation, status)`."""
    pages = []
    for page in GUEST_PAGES + SIGNED_IN_PAGES:
        if page in overrides:
            classification, expectation, status = overrides[page]
        elif page in SIGNED_IN_PAGES:
            classification, expectation, status = 'skipped', None, None
        else:
            classification, expectation, status = 'ok', None, 200
        pages.append({'page': page, 'status': status, 'classification': classification,
                      'expectation': expectation})
    return {'schema': 1, 'date': f'2026-11-{day:02d}T04:17:00Z', 'mode': mode, 'pages': pages}


TOPLISTS_BROKEN = ('parser', 'toplists.rows', 200)
BLOCKED = ('unreachable', None, 403)


def swift_cases(source, enum_name):
    """`[(case name, raw value)]` for a Swift `enum <enum_name>`'s cases, in order."""
    body = re.search(rf'enum {enum_name}\b[^{{]*{{(.*?)\n}}', source, re.S).group(1)
    cases = []
    for line in re.findall(r'^\s*case ([^\n]+)$', body, re.M):
        if line.lstrip().startswith('.'):
            continue
        for item in line.split(','):
            match = re.fullmatch(r'\s*(\w+)(?:\s*=\s*"([^"]*)")?\s*', item)
            if match:
                cases.append((match.group(1), match.group(2) or match.group(1)))
    return cases


class ReporterHarness(unittest.TestCase):
    def setUp(self):
        self.directory = Path(tempfile.mkdtemp(prefix='live-check-report-'))
        self.addCleanup(shutil.rmtree, self.directory, ignore_errors=True)
        self.history = self.directory / 'history'
        self.history.mkdir()
        self.log = self.directory / 'gh-log.jsonl'
        self.state = self.directory / 'gh-state.json'
        self.runs = 0
        self.outputs = []

    def run_reporter(self, document, dry_run=False, keep=True, raw=None):
        """Runs the reporter on `document` with the stored history, then stores it like local mode does."""
        self.runs += 1
        current = self.directory / f'run-{self.runs}'
        current.mkdir()
        path = current / 'results.json'
        path.write_text(raw if raw is not None else json.dumps(document, indent=2))
        env = dict(os.environ, FAKE_GH_LOG=str(self.log), FAKE_GH_STATE=str(self.state))
        command = [sys.executable, str(REPORTER), '--results', str(path), '--previous', str(self.history),
                   '--repo', REPO, '--gh', str(FAKE_GH)]
        if dry_run:
            command.append('--dry-run')
        completed = subprocess.run(command, env=env, capture_output=True, text=True, timeout=60)
        self.outputs.append(completed.stdout + completed.stderr)
        if keep and completed.returncode == 0:
            shutil.copy(path, self.history / f'results-{self.runs:03d}.json')
        return completed

    def calls(self):
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines() if line.strip()]

    def writes(self, verb=None):
        """The issue commands that change GitHub (create, comment, close), optionally of one verb."""
        found = [call for call in self.calls() if call[:1] == ['issue'] and call[1:2] != ['list']]
        return [call for call in found if verb is None or call[1] == verb]

    def open_issues(self):
        if not self.state.exists():
            return []
        return [issue for issue in json.loads(self.state.read_text())['issues'] if issue['state'] == 'open']

    @staticmethod
    def option(call, name):
        return call[call.index(name) + 1]

    def assert_ok(self, completed):
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)


class ParserIssueTests(ReporterHarness):
    def test_first_parser_result_opens_one_issue_and_second_comments(self):
        self.assert_ok(self.run_reporter(results(1, toplists=TOPLISTS_BROKEN)))
        created = self.writes('create')
        self.assertEqual(len(created), 1, self.calls())
        self.assertEqual(self.option(created[0], '--title'), 'Live check: Toplists parser')
        self.assertIn('expected a gallery table with at least one row, found none', self.option(created[0], '--body'))
        self.assertEqual(self.option(created[0], '--label'), 'live-check')

        self.assert_ok(self.run_reporter(results(2, toplists=TOPLISTS_BROKEN)))
        self.assertEqual(len(self.writes('create')), 1, 'a second run opened a second issue')
        comments = self.writes('comment')
        self.assertEqual(len(comments), 1, self.calls())
        self.assertEqual(comments[0][2], str(self.open_issues()[0]['number']))
        self.assertIn('expected a gallery table with at least one row, found none', self.option(comments[0], '--body'))
        self.assertEqual([issue['title'] for issue in self.open_issues()], ['Live check: Toplists parser'])

    def test_next_ok_for_the_page_closes_its_issue(self):
        self.assert_ok(self.run_reporter(results(1, toplists=TOPLISTS_BROKEN)))
        number = self.open_issues()[0]['number']
        self.assert_ok(self.run_reporter(results(2)))
        closed = self.writes('close')
        self.assertEqual(len(closed), 1, self.calls())
        self.assertEqual(closed[0][2], str(number))
        self.assertEqual(self.open_issues(), [])
        self.assertEqual(len(self.writes('create')), 1)

    def test_unreachable_never_opens_a_parser_issue(self):
        blocked = {page: BLOCKED for page in GUEST_PAGES}
        for day in (1, 2):
            self.assert_ok(self.run_reporter(results(day, **blocked)))
        self.assert_ok(self.run_reporter(results(3, toplists=BLOCKED, gallery=('unreachable', None, None))))
        titles = [self.option(call, '--title') for call in self.writes('create')]
        self.assertFalse([title for title in titles if title.endswith(' parser')], titles)

    def test_unreachable_page_leaves_its_open_parser_issue_open(self):
        self.assert_ok(self.run_reporter(results(1, toplists=TOPLISTS_BROKEN)))
        self.assert_ok(self.run_reporter(results(2, toplists=BLOCKED)))
        self.assertEqual(self.writes('close'), [])
        self.assertEqual(len(self.open_issues()), 1)


class CannotReachIssueTests(ReporterHarness):
    def test_three_unreachable_runs_open_one_cannot_reach_issue_and_a_reached_run_closes_it(self):
        self.assert_ok(self.run_reporter(results(1, popular=BLOCKED)))
        self.assert_ok(self.run_reporter(results(2, search=BLOCKED, popular=BLOCKED)))
        self.assertEqual(self.writes(), [], 'two unreachable runs already opened an issue')

        self.assert_ok(self.run_reporter(results(3, gallery=BLOCKED)))
        created = self.writes('create')
        self.assertEqual([self.option(call, '--title') for call in created], ['Live check: cannot reach the site'])
        body = self.option(created[0], '--body')
        self.assertIn('3 runs in a row', body)
        self.assertIn('Gallery', body)

        self.assert_ok(self.run_reporter(results(4)))
        closed = self.writes('close')
        self.assertEqual(len(closed), 1, self.calls())
        self.assertEqual(self.open_issues(), [])
        self.assertEqual(len(self.writes('create')), 1)

    def test_open_cannot_reach_issue_gets_a_comment_not_a_second_issue(self):
        for day in range(1, 6):
            self.assert_ok(self.run_reporter(results(day, frontPage=BLOCKED)))
        self.assertEqual(len(self.writes('create')), 1, self.calls())
        self.assertEqual(len(self.writes('comment')), 2, self.calls())
        self.assertEqual(self.writes('close'), [])

    def test_the_current_run_found_among_previous_results_counts_once(self):
        self.assert_ok(self.run_reporter(results(1, popular=BLOCKED)))
        (self.history / 'results-copy.json').write_text(json.dumps(results(2, popular=BLOCKED)))
        self.assert_ok(self.run_reporter(results(2, popular=BLOCKED)))
        self.assertEqual(self.writes(), [], 'the current run was counted twice')

    def test_skipped_signed_in_pages_do_not_count_as_unreachable(self):
        for day in range(1, 5):
            self.assert_ok(self.run_reporter(results(day)))
        self.assertEqual(self.writes(), [])


class InputRejectionTests(ReporterHarness):
    def assert_rejected_before_gh(self, completed):
        self.assertEqual(completed.returncode, 2, completed.stdout + completed.stderr)
        self.assertEqual(self.calls(), [], 'gh was called for a rejected results file')
        output = completed.stdout + completed.stderr
        for marker in CONTENT_MARKERS:
            self.assertNotIn(marker, output)

    def test_content_like_strings_in_unexpected_fields_are_rejected_before_any_gh_call(self):
        cases = {}
        document = results(1)
        document['title'] = 'Sample Gallery Title'
        cases['extra top-level field'] = document
        document = results(1)
        document['pages'][3]['title'] = 'Sample Gallery Title'
        cases['extra page field'] = document
        document = results(1, toplists=('parser', 'toplists.rows', 200))
        document['pages'][3]['expectation'] = 'https://example.org/g/987654/abcdef0123/'
        cases['expectation holds a URL'] = document
        document = results(1)
        document['pages'][4]['page'] = 'Sample Gallery Title'
        cases['page holds a title'] = document
        document = results(1)
        document['pages'][0]['status'] = 'session-cookie-value'
        cases['status holds text'] = document
        document = results(1)
        document['date'] = 'reader@example.com'
        cases['date holds text'] = document
        document = results(1)
        document['mode'] = 'Sample Gallery Title'
        cases['mode holds text'] = document
        document = results(1)
        document['pages'][2]['classification'] = 'parser: Sample Gallery Title'
        cases['classification holds text'] = document
        for name, document in cases.items():
            with self.subTest(name):
                self.assert_rejected_before_gh(self.run_reporter(document, keep=False))

    def test_valid_shape_with_an_unknown_enum_value_is_rejected_before_any_gh_call(self):
        cases = {}
        for field, value in (('classification', 'flaky'), ('page', 'homePage'), ('expectation', 'toplists.cells')):
            document = results(1, toplists=TOPLISTS_BROKEN)
            document['pages'][3][field] = value
            cases[field] = document
        document = results(1)
        document['mode'] = 'cloud'
        cases['mode'] = document
        document = results(1)
        document['schema'] = 2
        cases['schema'] = document
        for name, document in cases.items():
            with self.subTest(name):
                self.assert_rejected_before_gh(self.run_reporter(document, keep=False))

    def test_inconsistent_or_malformed_results_are_rejected_before_any_gh_call(self):
        cases = {}
        document = results(1)
        document['pages'][3]['classification'] = 'parser'
        cases['parser without expectation'] = document
        document = results(1, toplists=('unreachable', 'toplists.rows', 403))
        cases['unreachable with expectation'] = document
        document = results(1)
        document['pages'].append(dict(document['pages'][0]))
        cases['duplicate page'] = document
        document = results(1)
        document['pages'][0]['status'] = True
        cases['status is a boolean'] = document
        for name, document in cases.items():
            with self.subTest(name):
                self.assert_rejected_before_gh(self.run_reporter(document, keep=False))
        with self.subTest('not JSON'):
            self.assert_rejected_before_gh(self.run_reporter(None, keep=False, raw='Sample Gallery Title'))
        with self.subTest('duplicate key'):
            raw = json.dumps(results(1))[:-1] + ', "mode": "local"}'
            self.assert_rejected_before_gh(self.run_reporter(None, keep=False, raw=raw))

    def test_an_invalid_previous_file_is_ignored_and_never_reaches_gh(self):
        bad = results(1, popular=BLOCKED)
        bad['pages'][2]['title'] = 'Sample Gallery Title'
        (self.history / 'results-bad.json').write_text(json.dumps(bad))
        self.assert_ok(self.run_reporter(results(2, popular=BLOCKED)))
        self.assert_ok(self.run_reporter(results(3, popular=BLOCKED)))
        self.assertEqual(self.writes(), [], 'the invalid previous file counted as a run')
        log = self.log.read_text() if self.log.exists() else ''
        for marker in CONTENT_MARKERS:
            self.assertNotIn(marker, log + ''.join(self.outputs))


class VocabularyTests(ReporterHarness):
    def test_fake_gh_log_holds_only_the_fixed_vocabulary(self):
        reporter = load_reporter()
        sequence = [
            results(1, toplists=TOPLISTS_BROKEN, gallery=('parser', 'gallery.comments', 200),
                    reader=('parser', 'dependency.earlierPage', None)),
            results(2, mode='hosted', toplists=TOPLISTS_BROKEN, popular=BLOCKED),
            results(3, popular=BLOCKED),
            results(4, popular=BLOCKED, search=('unreachable', None, 503)),
            results(5, popular=BLOCKED, search=('unreachable', None, None)),
            results(6),
        ]
        for document in sequence:
            self.assert_ok(self.run_reporter(document))
        verbs = {call[1] for call in self.writes()}
        self.assertEqual(verbs, {'create', 'comment', 'close'}, self.calls())

        names = '|'.join(re.escape(name) for name in reporter.PAGE_NAMES.values())
        sentences = '|'.join(re.escape(sentence) for sentence in reporter.EXPECTATION_SENTENCES.values())
        fields = {'page': f'(?:{names})', 'pages': f'(?:{names})(?:, (?:{names}))*', 'sentence': f'(?:{sentences})',
                  'date': r'\d{4}-\d{2}-\d{2}', 'mode': '(?:hosted|local)', 'count': r'\d+',
                  'status': r'(?:HTTP \d{3}|no HTTP status)'}

        def pattern(template):
            parts = []
            for literal, field, _, _ in string.Formatter().parse(template):
                parts.append(re.escape(literal))
                if field is not None:
                    parts.append(fields[field])
            return re.compile(''.join(parts))

        texts = [pattern(value) for name, value in vars(reporter).items()
                 if name.startswith(('TITLE_', 'BODY_', 'LABEL_')) and isinstance(value, str)]
        words = {'issue', 'list', 'create', 'comment', 'close', 'label', '--repo', REPO, '--label', 'live-check',
                 '--state', 'open', '--json', 'number,title', '--limit', '100', '--title', '--body', '--comment',
                 '--description', '--color', reporter.LABEL_COLOR, '--force'}
        for call in self.calls():
            for argument in call:
                if argument in words or argument.isdigit():
                    continue
                self.assertTrue(any(text.fullmatch(argument) for text in texts), argument)

        inputs = set()

        def collect(value):
            if isinstance(value, dict):
                for key, item in value.items():
                    inputs.add(key)
                    collect(item)
            elif isinstance(value, list):
                for item in value:
                    collect(item)
            elif value is not None:
                inputs.add(str(value))
        for document in sequence:
            collect(document)
        vocabulary = (set(reporter.PAGES) | set(reporter.EXPECTATION_SENTENCES) | set(reporter.CLASSIFICATIONS)
                      | set(reporter.MODES) | {'schema', 'date', 'mode', 'pages', 'page', 'status', 'classification',
                                               'expectation'})
        log = self.log.read_text()
        for value in sorted(inputs - vocabulary):
            if value.isdigit():
                continue
            self.assertNotIn(value, log, 'an input string outside the fixed vocabulary reached gh')

    def test_titles_and_bodies_come_only_from_module_level_constant_templates(self):
        reporter = load_reporter()
        tree = ast.parse(REPORTER.read_text())
        templates = {}
        for node in tree.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                name = node.targets[0].id
                if name.startswith(('TITLE_', 'BODY_', 'LABEL_', 'LOG_')):
                    self.assertIsInstance(node.value, ast.Constant, name)
                    self.assertIsInstance(node.value.value, str, name)
                    templates[name] = node.value.value
        self.assertTrue({'TITLE_PARSER', 'TITLE_CANNOT_REACH', 'BODY_PARSER_OPEN', 'BODY_PARSER_COMMENT',
                         'BODY_PARSER_CLOSE', 'BODY_REACH_OPEN', 'BODY_REACH_COMMENT', 'BODY_REACH_CLOSE'}
                        <= set(templates), sorted(templates))
        self.assertEqual(reporter.TITLE_PARSER, 'Live check: {page} parser')
        self.assertEqual(reporter.TITLE_CANNOT_REACH, 'Live check: cannot reach the site')
        allowed = {'page', 'pages', 'sentence', 'date', 'mode', 'count', 'status', 'number', 'title', 'classification',
                   'expectation', 'action'}
        for name, template in templates.items():
            for _, field, spec, conversion in string.Formatter().parse(template):
                if field is not None:
                    self.assertIn(field, allowed, name)
                    self.assertFalse(spec or conversion, name)

        for node in ast.walk(tree):
            self.assertNotIsInstance(node, ast.JoinedStr, f'f-string on line {getattr(node, "lineno", "?")}')
            if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Mod, ast.Add)):
                for side in (node.left, node.right):
                    self.assertFalse(isinstance(side, ast.Constant) and isinstance(side.value, str),
                                     f'string built with an operator on line {node.lineno}')
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'format':
                self.assertIsInstance(node.func.value, ast.Name, f'format on line {node.lineno}')
                self.assertIn(node.func.value.id, templates, f'format on line {node.lineno}')

    def test_vocabulary_matches_the_swift_results_schema(self):
        reporter = load_reporter()
        page_source = (LIVE_CHECK / 'LiveCheckPage.swift').read_text()
        results_source = (LIVE_CHECK / 'LiveCheckResults.swift').read_text()
        expectation_source = (LIVE_CHECK / 'LiveCheckExpectation.swift').read_text()
        self.assertEqual(tuple(raw for _, raw in swift_cases(page_source, 'LiveCheckPage')), reporter.PAGES)
        self.assertEqual(set(reporter.PAGE_NAMES), set(reporter.PAGES))
        self.assertEqual({raw for _, raw in swift_cases(results_source, 'LiveCheckClassification')},
                         set(reporter.CLASSIFICATIONS))
        self.assertEqual({raw for _, raw in swift_cases(results_source, 'LiveCheckMode')}, set(reporter.MODES))
        cases = swift_cases(expectation_source, 'LiveCheckExpectation')
        sentences = dict(re.findall(r'case \.(\w+):\s*return "([^"]+)"', expectation_source))
        self.assertEqual({raw: sentences[name] for name, raw in cases}, reporter.EXPECTATION_SENTENCES)


class DryRunTests(ReporterHarness):
    def test_dry_run_only_lists_issues_and_prints_what_it_would_do(self):
        self.assert_ok(self.run_reporter(results(1, toplists=TOPLISTS_BROKEN)))
        number = self.open_issues()[0]['number']
        before = len(self.calls())
        completed = self.run_reporter(results(2, gallery=('parser', 'gallery.detail', 200)), dry_run=True,
                                      keep=False)
        self.assert_ok(completed)
        self.assertEqual([call[:2] for call in self.calls()[before:]], [['issue', 'list']])
        self.assertIn(f'would close #{number}: Live check: Toplists parser', completed.stdout)
        self.assertIn('would open: Live check: Gallery parser', completed.stdout)
        self.assertIn('no action: frontPage', completed.stdout)


if __name__ == '__main__':
    unittest.main()
