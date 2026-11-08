#!/usr/bin/env python3
"""Turns the daily live check's `results.json` into GitHub issues (19-15; 19-CONTEXT D-22, D-23).

    report_issues.py --results results.json --previous DIR --repo OWNER/NAME [--gh PATH] [--dry-run]

- One issue per page whose parser broke, titled `Live check: <Page> parser`, labelled `live-check`: opened on the
  first `parser` result, commented on while the page stays broken, closed on the page's next `ok`.
- `unreachable` (a block) never opens a parser issue. After three runs in a row on which any page was unreachable, one
  `Live check: cannot reach the site` issue opens; the next run that reaches every page closes it.
- The previous runs are the result files under `--previous` (searched recursively), judged by their dates.

The repository is public, so nothing read from the results reaches GitHub or the log except values of the fixed
vocabulary below: the results file is validated strictly before any `gh` call, and every title, body and log line is
one of the module-level templates, filled only with page names, expectation sentences, dates, modes, HTTP statuses
and counts. `--dry-run` lists the open issues and prints what it would do, and changes nothing.

Exit status: 0 done, 1 `gh` failed, 2 the results file was rejected.
"""
import argparse
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

# The fixed vocabulary, mirrored from AppPackage/Tests/LiveCheckTests (test_report_issues.py keeps them in step).
PAGES = ('frontPage', 'search', 'popular', 'toplists', 'gallery', 'reader', 'readerImage', 'tagSuggestions',
         'reportForm', 'watched', 'favorites', 'exhentai')
PAGE_NAMES = {
    'frontPage': 'Front page',
    'search': 'Search',
    'popular': 'Popular',
    'toplists': 'Toplists',
    'gallery': 'Gallery',
    'reader': 'Reader',
    'readerImage': 'Reader image',
    'tagSuggestions': 'Tag suggestions',
    'reportForm': 'Report form',
    'watched': 'Watched',
    'favorites': 'Favorites',
    'exhentai': 'ExHentai',
}
CLASSIFICATIONS = ('ok', 'unreachable', 'parser', 'skipped')
MODES = ('hosted', 'local')
EXPECTATION_SENTENCES = {
    'frontPage.rows': 'expected a gallery list with at least one row, found none',
    'search.rows': 'expected search results with at least one row, found none',
    'popular.rows': 'expected the Popular list with at least one row, found none',
    'toplists.rows': 'expected a gallery table with at least one row, found none',
    'gallery.detail': 'expected a gallery page with its title, category and page count, found a page the parser '
                      'rejects',
    'gallery.comments': "expected the gallery page's comments with at least one comment, found none",
    'reader.thumbnails': "expected links to the gallery's pages on its first preview page, found none",
    'reader.imageURL': "expected the first page's image address on its reader page, found none",
    'readerImage.decode': "expected the first page's image to decode, found data that does not",
    'tagSuggestions.asset': 'expected a tag database release with an English asset, found none',
    'reportForm.fields': 'expected the report form with its type picker and fields, found none',
    'dependency.earlierPage': 'expected the value an earlier page provides, found none because that page failed',
}
DOCUMENT_KEYS = frozenset({'schema', 'date', 'mode', 'pages'})
PAGE_KEYS = frozenset({'page', 'status', 'classification', 'expectation'})
DATE_PATTERN = re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z')
REPO_PATTERN = re.compile(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]{1,100}')
MAX_RESULTS_BYTES = 65536
# The consecutive runs with an unreachable page that open the cannot-reach issue (D-23).
CANNOT_REACH_RUNS = 3

LABEL = 'live-check'
LABEL_COLOR = 'c5def5'
LABEL_DESCRIPTION = 'Opened and closed by the daily live-parsing check'

TITLE_PARSER = 'Live check: {page} parser'
TITLE_CANNOT_REACH = 'Live check: cannot reach the site'

BODY_PARSER_OPEN = (
    'The daily live check read the {page} page as a guest on {date} ({mode} run, {status}), and the app\'s parser '
    'check failed:\n\n'
    '> {sentence}\n\n'
    'The check records only the page name, the HTTP status and this fixed expectation, never anything read from the '
    'page. This issue closes itself on the next run that reads the page as expected.'
)
BODY_PARSER_COMMENT = 'Still failing on {date} ({mode} run, {status}): {sentence}.'
BODY_PARSER_CLOSE = 'The {page} page met its expectations on {date} ({mode} run). Closing.'
BODY_REACH_OPEN = (
    'On {count} runs in a row the daily live check could not reach every page, most recently on {date} ({mode} run). '
    'Not reached on that run: {pages}.\n\n'
    'A Cloudflare challenge, an IP ban page, a timeout or a server error counts as not reached, never as a parser '
    'failure, so no parser issue is opened for these pages. This issue closes itself on the next run that reaches '
    'every page.'
)
BODY_REACH_COMMENT = 'Still not reached on {date} ({mode} run): {pages}.'
BODY_REACH_CLOSE = 'Every page was reached on {date} ({mode} run). Closing.'

LOG_PAGE = '{page}: {status}, {classification}'
LOG_PAGE_EXPECTATION = '{page}: {status}, {classification}, {expectation}'
LOG_REJECTED = 'results rejected: {action}; no issue was touched'
LOG_PREVIOUS_IGNORED = 'ignored {count} previous results file(s) that did not validate'
LOG_PREVIOUS = '{count} previous run(s) found; unreachable runs in a row: {number}'
LOG_WOULD_OPEN = 'would open: {title}'
LOG_WOULD_COMMENT = 'would comment on #{number}: {title}'
LOG_WOULD_CLOSE = 'would close #{number}: {title}'
LOG_OPENED = 'opened: {title}'
LOG_COMMENTED = 'commented on #{number}: {title}'
LOG_CLOSED = 'closed #{number}: {title}'
LOG_NO_ACTION_PAGE = 'no action: {page} ({classification})'
LOG_NO_ACTION_REACH = 'no action: cannot reach the site ({count} unreachable run(s) in a row)'
LOG_GH_FAILED = 'gh {action} failed with exit status {number}'
LOG_GH_ANSWER = 'gh {action} returned an answer that is not an issue list'

BODY_STATUS_HTTP = 'HTTP {status}'
BODY_STATUS_NONE = 'no HTTP status'
BODY_PAGES_SEPARATOR = ', '


class Rejected(Exception):
    """A results file outside the schema. Its message is a fixed phrase, never the offending value."""


class GhFailed(Exception):
    pass


def _reject_constant(_):
    raise Rejected('a number is not finite')


def _unique_keys(pairs):
    keys = [key for key, _ in pairs]
    if len(keys) != len(set(keys)):
        raise Rejected('a key appears twice')
    return dict(pairs)


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def validate(text):
    """The results document in `text`, checked against schema 1 with its fixed enums, or `Rejected`."""
    try:
        document = json.loads(text, object_pairs_hook=_unique_keys, parse_constant=_reject_constant)
    except ValueError:
        raise Rejected('the file is not JSON') from None
    if not isinstance(document, dict) or set(document) != DOCUMENT_KEYS:
        raise Rejected('the document does not have exactly the schema 1 fields')
    if not _is_int(document['schema']) or document['schema'] != 1:
        raise Rejected('the schema is not 1')
    if not isinstance(document['date'], str) or not DATE_PATTERN.fullmatch(document['date']):
        raise Rejected('the date is not an ISO 8601 UTC time')
    try:
        date = datetime.datetime.strptime(document['date'], '%Y-%m-%dT%H:%M:%SZ')
    except ValueError:
        raise Rejected('the date is not a real time') from None
    if document['mode'] not in MODES:
        raise Rejected('the mode is not hosted or local')
    pages = document['pages']
    if not isinstance(pages, list) or not pages or len(pages) > len(PAGES):
        raise Rejected('the pages are not a list of page results')
    seen = set()
    checked = []
    for entry in pages:
        if not isinstance(entry, dict) or set(entry) != PAGE_KEYS:
            raise Rejected('a page result does not have exactly its four fields')
        page, status = entry['page'], entry['status']
        classification, expectation = entry['classification'], entry['expectation']
        if not isinstance(page, str) or page not in PAGES or page in seen:
            raise Rejected('a page is unknown or appears twice')
        seen.add(page)
        if status is not None and not (_is_int(status) and 100 <= status <= 599):
            raise Rejected('a status is not an HTTP status or null')
        if not isinstance(classification, str) or classification not in CLASSIFICATIONS:
            raise Rejected('a classification is not in the fixed vocabulary')
        if expectation is not None and (not isinstance(expectation, str) or expectation not in EXPECTATION_SENTENCES):
            raise Rejected('an expectation is not in the fixed vocabulary')
        if (classification == 'parser') != (expectation is not None):
            raise Rejected('a parser result has no expectation, or another result has one')
        if classification == 'skipped' and status is not None:
            raise Rejected('a skipped page has a status')
        # Rebuilt from the vocabulary itself, so nothing later holds a string taken from the file.
        checked.append({
            'page': PAGES[PAGES.index(page)],
            'status': None if status is None else int(status),
            'classification': CLASSIFICATIONS[CLASSIFICATIONS.index(classification)],
            'expectation': None if expectation is None else _vocabulary_key(expectation),
        })
    return {'date': date, 'mode': MODES[MODES.index(document['mode'])], 'pages': checked}


def _vocabulary_key(expectation):
    return next(key for key in EXPECTATION_SENTENCES if key == expectation)


def load(path):
    try:
        with open(path, 'rb') as handle:
            data = handle.read(MAX_RESULTS_BYTES + 1)
    except OSError:
        raise Rejected('the file cannot be read') from None
    if len(data) > MAX_RESULTS_BYTES:
        raise Rejected('the file is larger than a results file can be')
    try:
        return validate(data.decode('utf-8'))
    except UnicodeDecodeError:
        raise Rejected('the file is not UTF-8') from None


def previous_runs(directory, current):
    """Valid earlier runs under `directory`, newest first, one per date, all before the current run."""
    if directory is None or not Path(directory).is_dir():
        return [], 0
    runs, ignored = {}, 0
    for path in sorted(Path(directory).rglob('*.json')):
        try:
            run = load(path)
        except Rejected:
            ignored += 1
            continue
        if run['date'] < current['date']:
            runs[run['date']] = run
    return [runs[date] for date in sorted(runs, reverse=True)], ignored


def unreachable_pages(run):
    return [entry['page'] for entry in run['pages'] if entry['classification'] == 'unreachable']


def unreachable_streak(current, previous):
    """How many runs in a row, ending with the current one, had an unreachable page."""
    streak = 0
    for run in [current] + previous:
        if not unreachable_pages(run):
            break
        streak += 1
    return streak


def status_text(status):
    return BODY_STATUS_NONE if status is None else BODY_STATUS_HTTP.format(status=status)


def day(run):
    return run['date'].strftime('%Y-%m-%d')


def plan(current, previous, open_issues):
    """`[(verb, number, title, body)]` for this run; `verb` is `create`, `comment` or `close`, or `none` with a log
    line in place of a body."""
    by_title = {}
    for number, title in sorted(open_issues):
        by_title.setdefault(title, number)
    actions = []
    date, mode = day(current), current['mode']
    for entry in current['pages']:
        name = PAGE_NAMES[entry['page']]
        title = TITLE_PARSER.format(page=name)
        number = by_title.get(title)
        if entry['classification'] == 'parser':
            sentence = EXPECTATION_SENTENCES[entry['expectation']]
            status = status_text(entry['status'])
            if number is None:
                body = BODY_PARSER_OPEN.format(page=name, date=date, mode=mode, status=status, sentence=sentence)
                actions.append(('create', None, title, body))
            else:
                body = BODY_PARSER_COMMENT.format(date=date, mode=mode, status=status, sentence=sentence)
                actions.append(('comment', number, title, body))
        elif entry['classification'] == 'ok' and number is not None:
            actions.append(('close', number, title, BODY_PARSER_CLOSE.format(page=name, date=date, mode=mode)))
        else:
            actions.append(('none', None, title,
                            LOG_NO_ACTION_PAGE.format(page=entry['page'], classification=entry['classification'])))

    streak = unreachable_streak(current, previous)
    number = by_title.get(TITLE_CANNOT_REACH)
    pages = BODY_PAGES_SEPARATOR.join(PAGE_NAMES[page] for page in unreachable_pages(current))
    if streak == 0 and number is not None:
        actions.append(('close', number, TITLE_CANNOT_REACH, BODY_REACH_CLOSE.format(date=date, mode=mode)))
    elif streak > 0 and number is not None:
        actions.append(('comment', number, TITLE_CANNOT_REACH,
                        BODY_REACH_COMMENT.format(date=date, mode=mode, pages=pages)))
    elif streak >= CANNOT_REACH_RUNS:
        actions.append(('create', None, TITLE_CANNOT_REACH,
                        BODY_REACH_OPEN.format(count=streak, date=date, mode=mode, pages=pages)))
    else:
        actions.append(('none', None, TITLE_CANNOT_REACH, LOG_NO_ACTION_REACH.format(count=streak)))
    return actions, streak


class GitHub:
    def __init__(self, gh, repo):
        self.gh = gh
        self.repo = repo
        self.labelled = False

    def call(self, action, arguments, capture=False):
        try:
            completed = subprocess.run([self.gh] + arguments, stdout=subprocess.PIPE if capture else None,
                                       text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            raise GhFailed(LOG_GH_FAILED.format(action=action, number=-1)) from None
        if completed.returncode != 0:
            raise GhFailed(LOG_GH_FAILED.format(action=action, number=completed.returncode))
        return completed.stdout

    def open_issues(self):
        answer = self.call('issue list', ['issue', 'list', '--repo', self.repo, '--label', LABEL, '--state', 'open',
                                          '--json', 'number,title', '--limit', '100'], capture=True)
        try:
            issues = json.loads(answer)
        except ValueError:
            raise GhFailed(LOG_GH_ANSWER.format(action='issue list')) from None
        if not isinstance(issues, list):
            raise GhFailed(LOG_GH_ANSWER.format(action='issue list'))
        found = []
        for issue in issues:
            if not (isinstance(issue, dict) and _is_int(issue.get('number')) and issue['number'] > 0
                    and isinstance(issue.get('title'), str)):
                raise GhFailed(LOG_GH_ANSWER.format(action='issue list'))
            found.append((issue['number'], issue['title']))
        return found

    def ensure_label(self):
        if not self.labelled:
            self.call('label create', ['label', 'create', LABEL, '--repo', self.repo, '--description',
                                       LABEL_DESCRIPTION, '--color', LABEL_COLOR, '--force'])
            self.labelled = True

    def create(self, title, body):
        self.ensure_label()
        self.call('issue create', ['issue', 'create', '--repo', self.repo, '--title', title, '--body', body,
                                   '--label', LABEL])

    def comment(self, number, body):
        self.call('issue comment', ['issue', 'comment', str(number), '--repo', self.repo, '--body', body])

    def close(self, number, body):
        self.call('issue close', ['issue', 'close', str(number), '--repo', self.repo, '--comment', body])


def parse_arguments(argv):
    parser = argparse.ArgumentParser(description='Report the daily live check through GitHub issues.')
    parser.add_argument('--results', required=True, help="this run's results.json")
    parser.add_argument('--previous', help="a directory holding earlier runs' result files")
    parser.add_argument('--repo', required=True, help='OWNER/NAME')
    parser.add_argument('--gh', default='gh', help='the gh executable (tests pass fake-gh/gh)')
    parser.add_argument('--dry-run', action='store_true', help='list issues and print the actions; change nothing')
    return parser.parse_args(argv)


def main(argv=None):
    arguments = parse_arguments(argv)
    try:
        current = load(arguments.results)
    except Rejected as rejection:
        print(LOG_REJECTED.format(action=rejection.args[0]), file=sys.stderr)
        return 2
    if not REPO_PATTERN.fullmatch(arguments.repo):
        print(LOG_REJECTED.format(action='the repository is not OWNER/NAME'), file=sys.stderr)
        return 2
    previous, ignored = previous_runs(arguments.previous, current)
    for entry in current['pages']:
        status = status_text(entry['status'])
        if entry['expectation'] is None:
            print(LOG_PAGE.format(page=entry['page'], status=status, classification=entry['classification']))
        else:
            print(LOG_PAGE_EXPECTATION.format(page=entry['page'], status=status,
                                              classification=entry['classification'],
                                              expectation=entry['expectation']))
    if ignored:
        print(LOG_PREVIOUS_IGNORED.format(count=ignored))

    github = GitHub(arguments.gh, arguments.repo)
    try:
        actions, streak = plan(current, previous, github.open_issues())
        print(LOG_PREVIOUS.format(count=len(previous), number=streak))
        for verb, number, title, body in actions:
            if verb == 'none':
                print(body)
            elif arguments.dry_run and verb == 'create':
                print(LOG_WOULD_OPEN.format(title=title))
            elif arguments.dry_run and verb == 'comment':
                print(LOG_WOULD_COMMENT.format(number=number, title=title))
            elif arguments.dry_run:
                print(LOG_WOULD_CLOSE.format(number=number, title=title))
            elif verb == 'create':
                github.create(title, body)
                print(LOG_OPENED.format(title=title))
            elif verb == 'comment':
                github.comment(number, body)
                print(LOG_COMMENTED.format(number=number, title=title))
            else:
                github.close(number, body)
                print(LOG_CLOSED.format(number=number, title=title))
    except GhFailed as failure:
        print(failure.args[0], file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
