#!/usr/bin/env python3
"""The shard runner's bookkeeping (19-10; 19-CONTEXT D-15, owner msg 2263; 19-RESEARCH §4, §5).

`Scripts/visual/run-shard.sh` runs one entry of `snapshot-shards.json` and asks this script for:

- `describe`: the shard's family, pinned device type and runtime, worker count, timeout and estimate (tab-separated).
- `invocations`: one line per `xcodebuild` invocation, `<configurations,> <orientations,>`.
- `slices`: the baseline slices (`<family>/<locale>/<size>`) the shard compares against, comma-separated.
- `classes`: the `SnapshotMatrixCase` subclasses, read from the test sources, without the `Tracer*` classes (19-01's
  tracer is not part of the matrix).
- `pending`: the classes of one invocation that still lack a result line for a coordinate they capture; `--prune`
  first drops their unfinished scenarios' lines of that invocation (per configuration), so their re-run, which skips
  every scenario already captured in a configuration, writes each coordinate once.
- `drift`: whether this runner's Xcode build, runtime and device type match the rendering pin; prints each mismatch.
- `fault`: the proof's injected fault for this shard and attempt, from `EHPANDA_SNAPSHOT_FAULT`
  (`<shard>=crash|no-artifact[@every-attempt],…`; by default the first attempt only).
- `record`: writes `shard.json`, whose `infra` is the shard's class for `snapshot_aggregate.py`.
"""

import argparse
from collections import Counter, OrderedDict
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys

import snapshot_aggregate
import snapshot_matrix

ROOT = Path(__file__).resolve().parents[2]
SHARDS = Path(__file__).resolve().parent / 'snapshot-shards.json'
SOURCES = ROOT / 'AppPackage/Tests/VisualSnapshotTests'
CLASS = re.compile(r'^\s*(?:final\s+)?class\s+(\w+)\s*:\s*SnapshotMatrixCase\b', re.MULTILINE)
CAPTURE = re.compile(r'capture\(scenario:\s*"([^"]+)"')
FAULTS = ('crash', 'no-artifact')
EVERY_ATTEMPT = '@every-attempt'
INFRA = (*snapshot_aggregate.SHARD_ERRORS, *snapshot_aggregate.SHARD_CLASSES)


def load_shard(plan, shard_id):
    for shard in plan['shards']:
        if shard['id'] == shard_id:
            return shard
    raise SystemExit(f'snapshot_shard: no shard {shard_id!r} in the shard plan')


def split_configuration(configuration):
    locale, size = configuration.rsplit('-', 1)
    return locale, size


def slices(shard):
    return [f"{shard['family']}/{'/'.join(split_configuration(configuration))}"
            for configuration in shard['configurations']]


def classes(sources=SOURCES):
    """`{class: [scenario, …]}` in source order, from every Swift file under `sources`, tracers left out."""
    found = OrderedDict()
    for path in sorted(Path(sources).rglob('*.swift')):
        text = path.read_text()
        starts = [(match.start(), match.group(1)) for match in CLASS.finditer(text)]
        others = [match.start() for match in re.finditer(r'^\s*(?:final\s+)?class\s+\w+', text, re.MULTILINE)]
        for start, name in starts:
            end = min([offset for offset in others if offset > start] or [len(text)])
            if not name.startswith('Tracer'):
                found[name] = CAPTURE.findall(text[start:end])
    return found


def invocation_rows(shard, index, document, env):
    """`[(coordinate, reason)]` the invocation captures: the shard's device, configurations and orientations."""
    invocation = shard['invocations'][index]
    return [(row, reason) for row, reason in snapshot_matrix.coordinates(document, env)
            if row.family == shard['family'] and row.configuration in invocation['configurations']
            and row.orientation in invocation['orientations']]


def read_keys(results):
    keys = set()
    if Path(results).is_file():
        for line in Path(results).read_text().splitlines():
            try:
                keys.add(json.loads(line)['key'])
            except (ValueError, KeyError, TypeError):
                continue
    return keys


def pending(shard, index, results, matrix_classes, document, env):
    """The classes with a captured coordinate of this invocation that has no result line yet."""
    rows = invocation_rows(shard, index, document, env)
    done = read_keys(results)
    missing = {row.scenario for row, reason in rows if reason is None and row.key not in done}
    return [name for name, scenarios in matrix_classes.items() if missing & set(scenarios)]


def prune(shard, index, results, names, matrix_classes, document, env):
    """Drops this invocation's lines of each scenario of `names` in each configuration where it lacks a captured
    line, so its re-run writes each coordinate once; every other line stays as it was.

    A scenario that has all its lines in a configuration keeps them: the re-run skips it there
    (`EHPANDA_SNAPSHOT_KEEP_CAPTURED`, SnapshotMatrixCase). Run 42577585956 dropped every configuration's lines of a
    re-run class and kept 186 to 378 of 1614 pictures in the shards a crash had hit.
    """
    scenarios = {scenario for name in names for scenario in matrix_classes[name]}
    rows = [(row, reason) for row, reason in invocation_rows(shard, index, document, env) if row.scenario in scenarios]
    done = read_keys(results)
    unfinished = {(row.scenario, row.configuration) for row, reason in rows if reason is None and row.key not in done}
    dropped = {row.key for row, _ in rows if (row.scenario, row.configuration) in unfinished}
    path = Path(results)
    if not path.is_file():
        return
    kept = []
    for line in path.read_text().splitlines():
        try:
            key = json.loads(line).get('key')
        except (ValueError, AttributeError):
            key = None
        if key not in dropped:
            kept.append(line)
    path.write_text(''.join(line + '\n' for line in kept))


def drift(env, family, xcode, runtimes, devicetypes):
    """Each way this runner differs from the rendering pin; an empty list when it matches."""
    problems = []
    pinned = env['toolchain']['xcode'].strip()
    if xcode.strip() != pinned:
        problems.append(f"Xcode is {' / '.join(xcode.strip().splitlines())}, "
                        f"pinned {' / '.join(pinned.splitlines())}")
    runtime = env['runtime']
    available = [row for row in runtimes.get('runtimes', [])
                 if row.get('identifier') == runtime['identifier'] and row.get('isAvailable', True)]
    if not any(row.get('buildversion') == runtime['buildVersion'] for row in available):
        builds = ', '.join(sorted({str(row.get('buildversion')) for row in available})) or 'none'
        problems.append(f"runtime {runtime['identifier']} build {builds}, pinned {runtime['buildVersion']}")
    device = env['devices'][family]['deviceTypeIdentifier']
    if not any(row.get('identifier') == device for row in devicetypes.get('devicetypes', [])):
        problems.append(f'device type {device} ({env["devices"][family]["model"]}) is not available')
    return problems


def fault(value, shard_id, attempt):
    """The injected fault for this shard and attempt, or `None`."""
    for entry in filter(None, (part.strip() for part in (value or '').split(','))):
        name, _, kind = entry.partition('=')
        every = kind.endswith(EVERY_ATTEMPT)
        kind = kind[:-len(EVERY_ATTEMPT)] if every else kind
        if kind not in FAULTS:
            raise ValueError(f'EHPANDA_SNAPSHOT_FAULT: unknown fault {entry!r}')
        if name == shard_id and (every or attempt == 1):
            return kind
    return None


def counts(results):
    statuses = Counter()
    if Path(results).is_file():
        for line in Path(results).read_text().splitlines():
            try:
                statuses[json.loads(line)['status']] += 1
            except (ValueError, KeyError, TypeError):
                statuses['malformed'] += 1
    return dict(sorted(statuses.items()))


def main(argv=None):
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--shards', type=Path, default=SHARDS)
    common.add_argument('--inventory', type=Path, default=snapshot_matrix.INVENTORY)
    common.add_argument('--environment', type=Path, default=snapshot_matrix.ENVIRONMENT)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ('describe', 'invocations', 'slices'):
        commands.add_parser(name, parents=[common]).add_argument('--shard', required=True)
    commands.add_parser('classes', parents=[common]).add_argument('--sources', type=Path, default=SOURCES)
    command = commands.add_parser('pending', parents=[common])
    command.add_argument('--shard', required=True)
    command.add_argument('--invocation', type=int, required=True)
    command.add_argument('--results', type=Path, required=True)
    command.add_argument('--sources', type=Path, default=SOURCES)
    command.add_argument('--prune', action='store_true')
    command = commands.add_parser('drift', parents=[common])
    command.add_argument('--shard', required=True)
    command.add_argument('--xcode', type=Path, required=True, help='the output of `xcodebuild -version`')
    command.add_argument('--runtimes', type=Path, required=True, help='`xcrun simctl list runtimes -j`')
    command.add_argument('--devicetypes', type=Path, required=True, help='`xcrun simctl list devicetypes -j`')
    command = commands.add_parser('fault', parents=[common])
    command.add_argument('--shard', required=True)
    command.add_argument('--attempt', type=int, required=True)
    command = commands.add_parser('record', parents=[common])
    command.add_argument('--shard', required=True)
    command.add_argument('--out', type=Path, required=True)
    command.add_argument('--mode', choices=('compare', 'candidate'), required=True)
    command.add_argument('--attempt', type=int, required=True)
    command.add_argument('--infra', default='', help=f"empty, or one of {', '.join(INFRA)}")
    command.add_argument('--detail', default='')
    command.add_argument('--started', default='')
    command.add_argument('--xcode', default='')
    command.add_argument('--runner', default='')
    command.add_argument('--rerun', default='', help='the classes re-run in the job, space-separated')
    args = parser.parse_args(argv)

    plan = json.loads(args.shards.read_text())
    if args.command == 'classes':
        print('\n'.join(classes(args.sources)))
        return 0
    shard = load_shard(plan, args.shard)
    if args.command == 'describe':
        _, env = snapshot_matrix.load(args.inventory, args.environment)
        device = env['devices'][shard['family']]['deviceTypeIdentifier']
        print('\t'.join(str(value) for value in (shard['family'], device, env['runtime']['identifier'],
                                                   plan['workers'], shard['timeoutMinutes'],
                                                   shard['estimatedMinutes'])))
    elif args.command == 'invocations':
        for invocation in shard['invocations']:
            print(','.join(invocation['configurations']), ','.join(invocation['orientations']))
    elif args.command == 'slices':
        print(','.join(slices(shard)))
    elif args.command == 'pending':
        document, env = snapshot_matrix.load(args.inventory, args.environment)
        matrix_classes = classes(args.sources)
        names = pending(shard, args.invocation, args.results, matrix_classes, document, env)
        if args.prune and names:
            prune(shard, args.invocation, args.results, names, matrix_classes, document, env)
        print(' '.join(names))
    elif args.command == 'drift':
        _, env = snapshot_matrix.load(args.inventory, args.environment)
        problems = drift(env, shard['family'], args.xcode.read_text(), json.loads(args.runtimes.read_text()),
                         json.loads(args.devicetypes.read_text()))
        print('; '.join(problems))
        return 1 if problems else 0
    elif args.command == 'fault':
        print(fault(os.environ.get('EHPANDA_SNAPSHOT_FAULT', ''), args.shard, args.attempt) or '')
    elif args.command == 'record':
        if args.infra and args.infra not in INFRA:
            parser.error(f'--infra {args.infra!r} is not one of {", ".join(INFRA)}')
        results = args.out.parent / 'results.jsonl'
        record = {'shard': shard['id'], 'family': shard['family'], 'units': shard['configurations'],
                  'workers': plan['workers'], 'mode': args.mode, 'attempt': args.attempt,
                  'xcodeBuild': args.xcode, 'runnerImage': args.runner, 'started': args.started,
                  'finished': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                  'infra': args.infra or None, 'detail': args.detail or None,
                  'rerunClasses': args.rerun.split(), 'statusCounts': counts(results)}
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(record, indent=2) + '\n')
        statuses = ' '.join(f'{name}={count}' for name, count in record['statusCounts'].items()) or 'no results'
        print(f"{shard['id']} attempt {args.attempt}: infra={args.infra or 'none'}; {statuses}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
