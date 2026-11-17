#!/usr/bin/env python3
"""Reads one hosted UI test run for its job summary, and refuses a test that stopped running without notice.

usage: report.py --title <title> [--elsewhere <plan>]... [--local-only <json>] [--expect <plan>] <tests.json>

`tests.json` is `xcrun xcresulttool get test-results tests --path <result bundle>` (ui-tests.yml).

Three things xcodebuild's own result does not say:

- A test that failed in one of several runs. The UI test plans run every test once, and no test may pass by a
  retry. Where a run repeats its tests all the same (xcodebuild's `-test-iterations`, to hunt a flaky test, or a
  retry somebody passed on the command line), xcodebuild counts a test that failed and later passed as passed.
  Here it is failed, and listed as passing only on a repeat.
- A skipped test. A test skips where it does not apply (an iPad's case on the iPhone), and a skip that nobody
  expects is a test that no longer runs. Each skip must be accounted for by name: selected by another plan
  (`--elsewhere`, the iPad plan on the iPhone's run) or named with its reason in `--local-only` (the Duo's cases,
  which no hosted run makes). Any other skip fails the report.
- A name that matches nothing. A plan that selects a test since renamed runs nothing for it and says nothing, and
  a list entry for a test that is gone accounts for nothing. Every name of `--elsewhere` and `--local-only` must be
  a test of this run, and every test `--expect` selects (the run's own plan) must have run here.

A name is `Class/test()` for one test or `Class` for all of a class's tests, as in a plan's `selectedTests`.

Exit status: 1 when a test failed in any of its runs, a skip is not accounted for or a name matches nothing; 0
otherwise.
"""

import argparse
import dataclasses
import json
from pathlib import Path
import sys


@dataclasses.dataclass
class Summary:
    passed: list = dataclasses.field(default_factory=list)
    failed: list = dataclasses.field(default_factory=list)
    # The failed tests whose last run passed: xcodebuild counts them as passed.
    repeated: list = dataclasses.field(default_factory=list)
    expected_failures: list = dataclasses.field(default_factory=list)
    # {source: [identifier]} for the skips a plan or the local-only list accounts for.
    accounted: dict = dataclasses.field(default_factory=dict)
    unaccounted: list = dataclasses.field(default_factory=list)
    # (source, name) for a name that is no test of this run, or that the run's own plan selects and did not run.
    unmatched: list = dataclasses.field(default_factory=list)

    @property
    def ok(self):
        return not (self.failed or self.unaccounted or self.unmatched)


def cases(document):
    """`(identifier, result, [repetition results])` for every test case of a `test-results tests` document."""
    found = []

    def walk(node):
        if node.get('nodeType') == 'Test Case':
            repetitions = [child.get('result') for child in node.get('children', [])
                           if child.get('nodeType') == 'Repetition']
            found.append((node['nodeIdentifier'], node.get('result'), repetitions))
            return
        for child in node.get('children', []):
            walk(child)

    for node in document.get('testNodes', []):
        walk(node)
    return found


def selected(plan):
    """The names a test plan selects. A plan that selects nothing by name runs its whole target and names none."""
    names = [name for target in plan.get('testTargets', []) for name in target.get('selectedTests', [])]
    if not names:
        raise ValueError('the plan selects no test by name')
    return names


def covers(name, identifier):
    return name == identifier or name == identifier.split('/')[0]


def summarize(document, elsewhere=(), local_only=None, expect=None):
    """Sorts the run's tests. `elsewhere` is `[(label, names)]`, `local_only` and `expect` are lists of names."""
    summary = Summary()
    sources = list(elsewhere) + ([('local only', local_only)] if local_only is not None else [])
    run = cases(document)
    for identifier, result, repetitions in run:
        if result == 'Skipped':
            source = next((label for label, names in sources if any(covers(name, identifier) for name in names)),
                          None)
            if source is None:
                summary.unaccounted.append(identifier)
            else:
                summary.accounted.setdefault(source, []).append(identifier)
        elif result == 'Expected Failure':
            summary.expected_failures.append(identifier)
        elif result != 'Passed':
            # A failure, and any result the tool has another word for: what is not a pass is not counted as one.
            summary.failed.append(identifier)
        elif any(each != 'Passed' for each in repetitions):
            # A pass that took more than one run is no pass: no test may rely on a retry.
            summary.failed.append(identifier)
            summary.repeated.append(identifier)
        else:
            summary.passed.append(identifier)
    for label, names in sources:
        for name in names:
            if not any(covers(name, identifier) for identifier, _, _ in run):
                summary.unmatched.append((label, name))
    for name in expect or []:
        if not any(covers(name, identifier) and result != 'Skipped' for identifier, result, _ in run):
            summary.unmatched.append(('this run', name))
    return summary


def render(summary, title):
    """The job summary, as Markdown."""
    skipped = sum(len(tests) for tests in summary.accounted.values()) + len(summary.unaccounted)
    lines = [f'### {title}: {len(summary.passed)} passed, {len(summary.failed)} failed, {skipped} skipped', '']

    def section(heading, names):
        if names:
            lines.extend([f'**{heading}**', ''] + [f'- `{name}`' for name in sorted(names)] + [''])

    section('Failed', [name + (' (passed only on a repeat)' if name in summary.repeated else '')
                       for name in summary.failed])
    section('Skipped and not accounted for', summary.unaccounted)
    section('Named and not found', [f'{name} ({label})' for label, name in summary.unmatched])
    if summary.expected_failures:
        lines.extend([f'{len(summary.expected_failures)} expected failures.', ''])
    for label, tests in sorted(summary.accounted.items()):
        lines.extend([f'{len(tests)} skipped here, accounted for by {label}.', ''])
    return '\n'.join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--title', required=True)
    parser.add_argument('--elsewhere', type=Path, action='append', default=[])
    parser.add_argument('--local-only', type=Path)
    parser.add_argument('--expect', type=Path)
    parser.add_argument('tests', type=Path)
    args = parser.parse_args(argv)

    def read(path):
        return json.loads(path.read_text(encoding='utf-8'))

    summary = summarize(
        read(args.tests),
        elsewhere=[(f'the {plan.stem} plan', selected(read(plan))) for plan in args.elsewhere],
        local_only=list(read(args.local_only)['tests']) if args.local_only else None,
        expect=selected(read(args.expect)) if args.expect else None,
    )
    print(render(summary, args.title))
    return 0 if summary.ok else 1


if __name__ == '__main__':
    sys.exit(main())
