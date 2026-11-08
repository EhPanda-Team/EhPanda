#!/usr/bin/env python3
"""Merge the snapshot shards' results, decide the gate run and list the shards to retry (19-CONTEXT D-15 amendment).

Each shard uploads `<results>/<shard-id>/` with `results.jsonl` and `shard.json` (19-RESEARCH §9). A retry of a shard
uploads the same layout under `<retry>/<shard-id>/`, and the merge keeps each shard's latest attempt. Every expected
coordinate of the shard plan must have exactly one line: a coordinate without one is an infrastructure error, so a
missing or malformed file never reads as a pass.

Failures fall into four classes, each named in the summary: picture changes, infrastructure errors, environment drift
and baseline mismatches. Any non-empty class fails the run. `--triage` prints the shards to retry: those with an
infrastructure error or no artifact, never those with only picture changes, drift or a baseline mismatch, and never a
shard whose latest attempt already was its retry.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

import snapshot_matrix

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


def latest(shard_id, results, retry):
    """`(attempt, directory)`: the retry when its directory arrived, else the first attempt."""
    if retry is not None and (retry / shard_id).is_dir():
        return 2, retry / shard_id
    return 1, results / shard_id


def aggregate(results, retry, document, env, shard_plan):
    """The merged verdict as the `aggregate.json` document."""
    rows = snapshot_matrix.coordinates(document, env)
    items = {name: [] for name, _ in CLASSES}
    flaky, merged, shards = [], [], {}
    for shard in shard_plan['shards']:
        shard_id = shard['id']
        attempt, directory = latest(shard_id, results, retry)
        expected = shard_coordinates(shard, rows)
        read = read_attempt(directory)
        if read is None:
            shards[shard_id] = {'attempt': attempt, 'infra': 'runner-lost', 'directory': str(directory)}
            items['infrastructureErrors'].append({
                'shard': shard_id, 'kind': 'runner-lost',
                'detail': f'no artifact; {sum(reason is None for reason in expected.values())} coordinates missing'})
            continue
        record, lines, problems = read
        infra = record.get('infra')
        shards[shard_id] = {'attempt': attempt, 'infra': infra, 'directory': str(directory)}
        items['infrastructureErrors'] += [{'shard': shard_id, **problem} for problem in problems]
        if infra in SHARD_CLASSES:
            items[SHARD_CLASSES[infra]].append({'shard': shard_id, 'kind': infra,
                                                'detail': 'the shard captured nothing'})
        elif infra in SHARD_ERRORS:
            items['infrastructureErrors'].append({'shard': shard_id, 'kind': infra, 'detail': 'shard.json'})
        elif infra is not None:
            items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'malformed-shard',
                                                  'detail': f'unknown infra {infra!r}'})
        seen = set()
        for line in lines:
            key, status = line['key'], line['status']
            if key not in expected:
                items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'unexpected-result', 'key': key})
                continue
            if key in seen:
                items['infrastructureErrors'].append({'shard': shard_id, 'kind': 'duplicate-result', 'key': key})
                continue
            seen.add(key)
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


def triage(document):
    """Shard IDs to run once more: an infrastructure error on a first attempt."""
    erring = {item['shard'] for item in document['items']['infrastructureErrors']}
    return sorted(shard for shard in erring if document['shards'][shard]['attempt'] == 1)


def describe(item):
    subject = f"`{item['key']}`" if item.get('key') else item['shard']
    detail = f" — {item['detail']}" if item.get('detail') else ''
    return f"- {subject}: {item['kind']} ({item['shard']}){detail}"


def summary(document):
    """Markdown: the four class counts first, in a fixed order, then the verdict and the details."""
    lines = [f"- {document['counts'][name]} {label}" for name, label in CLASSES]
    retried = sorted(shard for shard, row in document['shards'].items() if row['attempt'] == 2)
    statuses = ', '.join(f'{status} {count}' for status, count in document['statusCounts'].items()) or 'none'
    lines += ['', f"## Snapshot gate: {'failed' if failed(document) else 'passed'}", '',
              f"Shards: {len(document['shards'])}; retried: {', '.join(retried) or 'none'}. Results: {statuses}."]
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
    parser.add_argument('--inventory', type=Path, default=snapshot_matrix.INVENTORY)
    parser.add_argument('--env', type=Path, default=snapshot_matrix.ENVIRONMENT)
    parser.add_argument('--shards', type=Path, default=SHARDS)
    parser.add_argument('--out', type=Path, help='where aggregate.json and summary.md go')
    parser.add_argument('--triage', action='store_true', help='print the shard IDs to retry as JSON and exit 0')
    parser.add_argument('--summary', type=Path, help='a file the Markdown summary is appended to')
    args = parser.parse_args(argv)
    document, env = snapshot_matrix.load(args.inventory, args.env)
    result = aggregate(args.results, args.retry, document, env, json.loads(args.shards.read_text()))
    if args.triage:
        print(json.dumps(triage(result)))
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
