#!/usr/bin/env python3
"""Merge the snapshot shards' results, decide the gate run and list the shards to retry (19-CONTEXT D-15 amendment).

Each shard uploads `<results>/<shard-id>/` with `results.jsonl` and `shard.json` (19-RESEARCH §9). A retry of a shard
uploads the same layout under `<retry>/<shard-id>/`, a second retry under `<retry2>/<shard-id>/` and a third under
`<retry3>/<shard-id>/`, four attempts in all (run 43298876957: the runner cut 13 of 27 shard jobs and 3 of their 13
retries). The merge keeps each shard's latest attempt, except that
a retry without `shard.json` never replaces an earlier attempt that has one: the latest attempt that has one is merged
and the lost retry is reported as `retry-lost` (run 42577585956, s07). Every expected coordinate of the shard plan must have a line: a
coordinate without one is an infrastructure error, so a missing or malformed file never reads as a pass. A coordinate
written twice with the same status (XCTest runs a class again after its runner crashed) counts once; lines that
disagree are a `duplicate-result` error, and so are two `recorded` lines with different digests: the candidate keeps one
picture per coordinate, so one of the lines names a picture that is not there (run 43298876957, s15).

Failures fall into four classes, each named in the summary: picture changes, infrastructure errors, environment drift
and baseline mismatches. Any non-empty class fails the run. `--triage` prints the shards to retry: those with an
shard-level infrastructure error (crash, timeout, lost runner, missing or malformed results), never those with only
coordinate errors (one picture's `timeout` or `error` is reported, not retried: rerunning a whole shard for it costs an
hour and repeats the same picture), picture changes, drift or a baseline mismatch, and never a shard that already ran
its retries.

`--triage` lists the shards for round `--attempt` (2 by default, the first retry; 3 and 4 for the next): those with a
shard-level error whose latest artifact is from an earlier attempt, so a retry that was cut with no artifact, or with
no `shard.json`, is listed again by the next round and never by its own.

The summary names every shard on one line with its counts before the item lists, which are capped.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

import snapshot_matrix
import snapshot_shards

SHARDS = Path(__file__).resolve().parent / 'snapshot-shards.json'
CLASSES = (('pictureChanges', 'picture changes'), ('infrastructureErrors', 'infrastructure errors'),
           ('drift', 'drift'), ('baselineMismatches', 'baseline mismatches'))
STATUSES = ('passed', 'changed', 'missing-baseline', 'recorded', 'timeout', 'error', 'notApplicable')
PICTURE_CHANGES = ('changed', 'missing-baseline')
COORDINATE_ERRORS = ('timeout', 'error')
SHARD_ERRORS = ('crash', 'timeout', 'runner-lost')
SHARD_CLASSES = {'drift': 'drift', 'baseline-mismatch': 'baselineMismatches'}
SUMMARY_ITEMS = 200


def shard_coordinates(shard, rows):
    """`{key: reason or None}` for every coordinate the shard's runs cover: its device, configurations, orientations."""
    runs = {(run['configuration'], orientation) for run in shard['runs'] for orientation in run['orientations']}
    return {row.key: reason for row, reason in rows
            if row.family == shard['family'] and (row.configuration, row.orientation) in runs}


def read_attempt(directory):
    """`(record, lines, problems)` of one shard directory, or `None` when no artifact arrived (no `shard.json`)."""
    record_path = directory / 'shard.json'
    if not record_path.is_file():
        return None
    try:
        record = json.loads(record_path.read_text())
    except ValueError:
        return {'infra': None}, [], [{'kind': 'malformed-shard', 'detail': 'shard.json is not JSON'}]
    lines, problems = [], []
    results = directory / 'results.jsonl'
    text = results.read_text() if results.is_file() else ''
    for number, raw in enumerate(text.splitlines(), start=1):
        if not raw.strip():
            continue
        try:
            line = json.loads(raw)
        except ValueError:
            line = None
        if not isinstance(line, dict) or not isinstance(line.get('key'), str) or line.get('status') not in STATUSES:
            problems.append({'kind': 'malformed-result', 'detail': f'results.jsonl line {number}'})
            continue
        lines.append(line)
    return record, lines, problems


ORDINALS = {1: 'first', 2: 'second', 3: 'third', 4: 'fourth'}
RETRY_NAMES = {2: 'the retry', 3: 'the second retry', 4: 'the third retry'}
FIRST_ROUND = 2
LAST_ATTEMPT = 4


def arrived(shard_id, results, *retries):
    """`[(attempt, directory)]`, oldest first: the first attempt always, each retry whose directory arrived."""
    found = [(1, results / shard_id)]
    for attempt, base in enumerate(retries, start=FIRST_ROUND):
        if base is not None and (base / shard_id).is_dir():
            found.append((attempt, base / shard_id))
    return found


def lost_detail(directory, expected):
    """Why an attempt has no `shard.json`: no artifact at all, or an artifact from a runner that could not run it."""
    missing = sum(reason is None for reason in expected.values())
    if directory.is_dir():
        return f'no shard.json (runner unusable, see {directory.name}/logs); {missing} coordinates missing'
    return f'no artifact; {missing} coordinates missing'


def duplicate_disagreement(first, line):
    """Why a second line of a coordinate disagrees with its first, or `None` when it repeats it.

    A `passed` picture taken twice may differ within the comparison's tolerance, so only `recorded` lines, whose
    picture is the candidate itself, are held to the same digest.
    """
    if first['status'] != line['status']:
        return f"{first['status']}, then {line['status']}"
    if line['status'] == 'recorded' and first.get('sha256') != line.get('sha256'):
        return f"recorded twice with different pictures ({first.get('sha256')}, then {line.get('sha256')})"
    return None


def aggregate(results, retry, document, env, shard_plan, retry2=None, retry3=None, only=()):
    """The merged verdict as the `aggregate.json` document; `only` restricts it to those shards (a restricted run)."""
    total = len(shard_plan['shards'])
    if only:
        shard_plan = dict(shard_plan, shards=[shard for shard in shard_plan['shards'] if shard['id'] in only])
    rows = snapshot_matrix.coordinates(document, env)
    items = {name: [] for name, _ in CLASSES}
    flaky, merged, shards, ran = [], [], {}, {}
    for shard in shard_plan['shards']:
        shard_id = shard['id']
        tries = arrived(shard_id, results, retry, retry2, retry3)
        attempt, directory = tries[-1]
        ran[shard_id] = attempt
        expected = shard_coordinates(shard, rows)
        read = read_attempt(directory)
        retry_lost = False
        if read is None and attempt > 1:
            for earlier, folder in reversed(tries[:-1]):
                kept = read_attempt(folder)
                if kept is not None:
                    retry_lost = True
                    lost = RETRY_NAMES[attempt]
                    items['infrastructureErrors'].append({
                        'shard': shard_id, 'kind': 'retry-lost',
                        'detail': f'{lost} left no shard.json (see {directory}/logs); '
                                  f'the {ORDINALS[earlier]} attempt is merged'})
                    attempt, directory, read = earlier, folder, kept
                    break
        if read is None:
            shards[shard_id] = {'attempt': attempt, 'infra': 'runner-lost', 'directory': str(directory)}
            items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'runner-lost',
                                                  'detail': lost_detail(directory, expected)})
            continue
        record, lines, problems = read
        infra = record.get('infra')
        shards[shard_id] = {'attempt': attempt, 'infra': infra, 'directory': str(directory)}
        if retry_lost:
            shards[shard_id]['retryLost'] = True
        items['infrastructureErrors'] += [{'shard': shard_id, **problem} for problem in problems]
        if infra in SHARD_CLASSES:
            items[SHARD_CLASSES[infra]].append({'shard': shard_id, 'kind': infra,
                                                'detail': 'the shard captured nothing'})
        elif infra in SHARD_ERRORS:
            items['infrastructureErrors'].append({'shard': shard_id, 'kind': infra, 'detail': 'shard.json'})
        elif infra is not None:
            items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'malformed-shard',
                                                  'detail': f'unknown infra {infra!r}'})
        seen = {}
        for line in lines:
            key, status = line['key'], line['status']
            if key not in expected:
                items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'unexpected-result', 'key': key})
                continue
            if key in seen:
                if disagreement := duplicate_disagreement(seen[key], line):
                    items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'duplicate-result', 'key': key,
                                                          'detail': disagreement})
                continue
            seen[key] = line
            entry = {'key': key, 'status': status, 'shard': shard_id, 'attempts': line.get('attempts', 1),
                     'flaky': bool(line.get('flaky')), 'seconds': line.get('seconds', 0)}
            if line.get('reason'):
                entry['reason'] = line['reason']
            merged.append(entry)
            if status in PICTURE_CHANGES:
                items['pictureChanges'].append({'shard': shard_id, 'kind': status, 'key': key})
            elif status in COORDINATE_ERRORS:
                items['infrastructureErrors'].append({'shard': shard_id, 'kind': status, 'key': key,
                                                      'detail': line.get('reason') or ''})
            if entry['flaky'] and status not in COORDINATE_ERRORS:
                flaky.append({'key': key, 'shard': shard_id, 'seconds': entry['seconds'],
                              'attempts': entry['attempts']})
        if infra not in SHARD_CLASSES:
            items['infrastructureErrors'] += [{'shard': shard_id, 'kind': 'missing-result', 'key': key}
                                              for key, reason in sorted(expected.items())
                                              if reason is None and key not in seen]
    return {
        'schema': 1,
        'counts': {name: len(items[name]) for name, _ in CLASSES},
        'items': items,
        'flaky': sorted(flaky, key=lambda row: row['key']),
        'shards': shards,
        'ran': ran,
        **({'only': sorted(only), 'planned': total} if only else {}),
        'statusCounts': dict(sorted(Counter(row['status'] for row in merged).items())),
        'results': sorted(merged, key=lambda row: row['key']),
        'scenarios': {row['id']: {'group': row['group'], 'state': row['state'], 'notApplicable': row['notApplicable']}
                      for row in document['scenarios']},
        'environment': {'xcode': ', '.join(env['toolchain']['xcode'].splitlines()),
                        'runtime': env['runtime']['version'],
                        'runtimeBuild': env['runtime']['buildVersion'],
                        'devices': {family: env['devices'][family]['model'] for family in snapshot_matrix.FAMILIES}},
    }


def failed(document):
    return any(document['counts'].values())


def shard_level(item):
    """Whether an infrastructure error is the shard's (retry it) rather than one coordinate's (report it)."""
    return not (item['kind'] in COORDINATE_ERRORS and item.get('key'))


def triage(document, attempt=FIRST_ROUND):
    """Shard IDs to run as `attempt`: a shard-level infrastructure error on a shard whose latest artifact (one that
    arrived, with or without `shard.json`) is from an earlier attempt, so no round lists a shard its own retry ran."""
    erring = {item['shard'] for item in document['items']['infrastructureErrors'] if shard_level(item)}
    return sorted(shard for shard in erring if document['ran'][shard] < attempt)


def describe(item):
    subject = f"`{item['key']}`" if item.get('key') else item['shard']
    detail = f" — {item['detail']}" if item.get('detail') else ''
    return f"- {subject}: {item['kind']} ({item['shard']}){detail}"


def counted(counter, order=None):
    keys = sorted(counter, key=lambda key: (order.index(key) if order and key in order else len(order or ()), key))
    return ', '.join(f'{key} {counter[key]}' for key in keys) or 'none'


def shard_table(document):
    """One row per shard: its attempt, shard class, result counts and infrastructure error counts."""
    statuses = {shard: Counter() for shard in document['shards']}
    for row in document['results']:
        statuses[row['shard']][row['status']] += 1
    errors = {shard: Counter() for shard in document['shards']}
    for item in document['items']['infrastructureErrors']:
        errors[item['shard']][item['kind']] += 1
    lines = ['| Shard | Attempt | Shard class | Results | Infrastructure errors |', '|---|---|---|---|---|']
    for shard, row in sorted(document['shards'].items()):
        attempt = f"{row['attempt']} (retry lost)" if row.get('retryLost') else str(row['attempt'])
        lines.append(f"| {shard} | {attempt} | {row.get('infra') or 'none'} | {counted(statuses[shard], STATUSES)} "
                     f"| {counted(errors[shard])} |")
    return lines


def summary(document):
    """Markdown: the four class counts first, in a fixed order, then the verdict, one line per shard and the details."""
    lines = [f"- {document['counts'][name]} {label}" for name, label in CLASSES]
    retried = sorted(shard for shard, row in document['shards'].items() if row['attempt'] > 1)
    statuses = ', '.join(f'{status} {count}' for status, count in document['statusCounts'].items()) or 'none'
    lines += ['', f"## Snapshot gate: {'failed' if failed(document) else 'passed'}", '']
    if document.get('only'):
        lines += [f"Restricted to {len(document['only'])} of {document['planned']} shards: "
                  f"{', '.join(document['only'])}.", '']
    lines += [f"Shards: {len(document['shards'])}; retried: {', '.join(retried) or 'none'}. Results: {statuses}.",
              '']
    lines += shard_table(document)
    for name, label in CLASSES:
        entries = document['items'][name]
        if entries:
            lines += ['', f'### {label.capitalize()} ({len(entries)})', '']
            lines += [describe(item) for item in entries[:SUMMARY_ITEMS]]
            if len(entries) > SUMMARY_ITEMS:
                lines.append(f'- … and {len(entries) - SUMMARY_ITEMS} more in aggregate.json')
    lines += ['', f"### Flake log ({len(document['flaky'])} passed only on a retry)", '']
    if document['flaky']:
        lines += ['| Coordinate | Seconds | Attempts | Shard |', '|---|---|---|---|']
        lines += [f"| `{row['key']}` | {row['seconds']:.2f} | {row['attempts']} | {row['shard']} |"
                  for row in document['flaky']]
    else:
        lines.append('None.')
    return '\n'.join(lines) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--results', type=Path, required=True, help='the first attempts, one directory per shard')
    parser.add_argument('--retry', type=Path, help='the retried shards, one directory per shard')
    parser.add_argument('--retry2', type=Path, help='the shards retried a second time, one directory per shard')
    parser.add_argument('--retry3', type=Path, help='the shards retried a third time, one directory per shard')
    parser.add_argument('--inventory', type=Path, default=snapshot_matrix.INVENTORY)
    parser.add_argument('--env', type=Path, default=snapshot_matrix.ENVIRONMENT)
    parser.add_argument('--shards', type=Path, default=SHARDS)
    parser.add_argument('--out', type=Path, help='where aggregate.json and summary.md go')
    parser.add_argument('--triage', action='store_true', help='print the shard IDs to retry as JSON and exit 0')
    parser.add_argument('--only', default='', metavar='IDS',
                        help='restrict the run to these comma-separated shard IDs (a restricted candidate run)')
    parser.add_argument('--attempt', type=int, choices=range(FIRST_ROUND, LAST_ATTEMPT + 1), default=FIRST_ROUND,
                        help='the attempt the triage lists shards for: 2 (the retry), 3 or 4 (the second and third retry)')
    parser.add_argument('--summary', type=Path, help='a file the Markdown summary is appended to')
    args = parser.parse_args(argv)
    document, env = snapshot_matrix.load(args.inventory, args.env)
    plan = json.loads(args.shards.read_text())
    try:
        only = snapshot_shards.select(args.only, plan)
    except ValueError as error:
        parser.error(str(error))
    result = aggregate(args.results, args.retry, document, env, plan, args.retry2, args.retry3, only)
    if args.triage:
        print(json.dumps(triage(result, args.attempt)))
        return 0
    if args.out is None:
        parser.error('--out is required unless --triage is given')
    text = summary(result)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'aggregate.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    (args.out / 'summary.md').write_text(text)
    if args.summary:
        with args.summary.open('a') as handle:
            handle.write(text)
    print(text, end='')
    return 1 if failed(result) else 0


if __name__ == '__main__':
    sys.exit(main())
