#!/usr/bin/env python3
"""Turns the hosted measurement runs into the cost table and the worker count (19-04; 19-CONTEXT D-13, D-15).

The runs directory holds one directory per comparison run, `<family>/<configuration>/w<N>/`, with the run's
`results.jsonl` (19-01's writer) and `shard.json` (`workers`, `started`, `finished`), and per job a `memory.log`
(lines `<UTC ISO 8601 time> normal|warn|critical`) and a `timing.json` (`{"bootFetchSeconds": s}`). A job that
measures one configuration keeps them in `<family>/<configuration>/`, where they apply to that configuration's runs
only, since its samples come from its own host; a job that measures a whole device keeps them in `<family>/`. The
candidate run that records the references has no `w<N>` directory and is not read.

The worker count is the largest of 2, 3 and 4 that passes every rule:
- `incomplete`: every configuration measured at any count has a run at this count, with as many result lines as
  that configuration's fullest run;
- `changed`: no picture at this count is `changed` against the candidate;
- `memory`: no `critical` memory pressure was sampled while a run at this count ran. `warn` is recorded and reported
  but does not exclude: the hosted runner sat at `warn` under two clones already, in every run at every count (lead's
  technical call after run 42455556948, amending D-15's wording);
- `slowdown`: for every device and text size, the median seconds per picture is at most 1.25 x the median at 2.

`--write` stores the medians at the chosen count, its smallest clone speed-up (picture count x median / wall), the
boot-and-fetch minutes and the fixed minutes per invocation in the 19-02 cost table schema, with `source: measured`
and the run ID.

The fixed cost per invocation comes from the candidates, whose `shard.json` and `results.jsonl` each job keeps in
`<family>/<configuration>/candidate/`: an `all` job records every text size in one invocation, so with a fixed cost
F per invocation the single-size candidates take F + C_i each and the `all` candidate F + sum(C_i), and
F = (sum of the single walls - the `all` wall) / (sizes - 1). The larger of the two devices' F is used.
"""

import argparse
from datetime import datetime
import json
import math
from pathlib import Path
import re
import statistics
import sys

import snapshot_matrix

WORKER_COUNTS = (2, 3, 4)
BASE = 2
SLOWDOWN = 1.25
TIMED = ('passed', 'changed', 'recorded')
LEVELS = ('warn', 'critical')
PRESSURE = ('critical',)
SIZES = ('xSmall', 'large', 'accessibility5')


def parse_time(text):
    return datetime.fromisoformat(text.strip().replace('Z', '+00:00'))


def read_lines(path):
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def read_memory(path):
    """`[(time, level)]` from a `memory.log`; lines it cannot read are skipped."""
    samples = []
    if path.exists():
        for line in path.read_text().splitlines():
            parts = line.split()
            if len(parts) == 2:
                try:
                    samples.append((parse_time(parts[0]), parts[1]))
                except ValueError:
                    continue
    return samples


def read_job(directory, key, memory, boot):
    """Adds the `memory.log` and `timing.json` of the job that wrote `directory`, if it holds them, under `key`."""
    if (directory / 'memory.log').exists():
        memory[key] = read_memory(directory / 'memory.log')
    timing = directory / 'timing.json'
    if timing.exists():
        boot[key] = json.loads(timing.read_text())['bootFetchSeconds']


def load(root):
    """`(runs, memory, boot_seconds)`; `runs` maps `(family, configuration, workers)` to its lines and record.

    `memory` and `boot_seconds` are keyed by family for a per-device job and by `(family, configuration)` for a
    per-configuration job.
    """
    root = Path(root)
    runs, memory, boot = {}, {}, {}
    for family in snapshot_matrix.FAMILIES:
        family_dir = root / family
        if not family_dir.is_dir():
            continue
        read_job(family_dir, family, memory, boot)
        for config_dir in sorted(path for path in family_dir.iterdir() if path.is_dir()):
            read_job(config_dir, (family, config_dir.name), memory, boot)
            for run_dir in sorted(path for path in config_dir.iterdir() if path.is_dir()):
                match = re.fullmatch(r'w(\d+)', run_dir.name)
                # A run cut off by the step's time limit has no shard.json; it counts as missing.
                if not match or not (run_dir / 'shard.json').exists():
                    continue
                record = json.loads((run_dir / 'shard.json').read_text())
                runs[(family, config_dir.name, int(match.group(1)))] = {
                    'lines': read_lines(run_dir / 'results.jsonl'), 'record': record,
                }
    return runs, memory, boot


def size_of(configuration):
    return configuration.rsplit('-', 1)[1]


def run_facts(run, samples):
    """Pictures, median seconds, wall seconds, speed-up, changed count and worst memory level of one run."""
    timed = [line['seconds'] for line in run['lines'] if line['status'] in TIMED]
    started, finished = parse_time(run['record']['started']), parse_time(run['record']['finished'])
    wall = (finished - started).total_seconds()
    median = statistics.median(timed) if timed else None
    levels = {level for time, level in samples if started <= time <= finished}
    worst = next((level for level in reversed(LEVELS) if level in levels), 'normal')
    return {
        'pictures': len(timed), 'median': median, 'wall': wall,
        'speedup': len(timed) * median / wall if timed and wall > 0 else None,
        'changed': sum(line['status'] == 'changed' for line in run['lines']), 'memory': worst,
        'lines': len(run['lines']),
    }


def measure(runs, memory):
    """`{(family, configuration, workers): facts}` for every run, against the samples of the host that ran it."""
    return {key: run_facts(run, memory.get(key[:2], memory.get(key[0], []))) for key, run in runs.items()}


def medians(facts):
    """`{(family, size, workers): median}` over the timed pictures of each device, text size and count."""
    grouped = {}
    for (family, configuration, workers), fact in facts.items():
        if fact['median'] is not None:
            grouped.setdefault((family, size_of(configuration), workers), []).append(fact['median'])
    return {key: statistics.median(values) for key, values in grouped.items()}


def exclusions(facts):
    """`{workers: [rules that exclude it]}` for 2, 3 and 4: incomplete, changed, memory, slowdown, in that order."""
    configurations = {(family, configuration) for family, configuration, _ in facts}
    by_size = medians(facts)
    result = {}
    for workers in WORKER_COUNTS:
        rules = []
        at = {(family, configuration): fact for (family, configuration, count), fact in facts.items()
              if count == workers}
        fullest = {key: max(fact['lines'] for (family, configuration, _), fact in facts.items()
                            if (family, configuration) == key) for key in configurations}
        if set(at) != configurations or any(fact['median'] is None or fact['lines'] < fullest[key]
                                            for key, fact in at.items()):
            rules.append('incomplete')
        if any(fact['changed'] for fact in at.values()):
            rules.append('changed')
        if any(fact['memory'] in PRESSURE for fact in at.values()):
            rules.append('memory')
        if workers != BASE:
            for (family, size, count), median in by_size.items():
                base = by_size.get((family, size, BASE))
                if count == workers and base is not None and median > SLOWDOWN * base:
                    rules.append('slowdown')
                    break
        result[workers] = rules
    return result


def choose(excluded):
    """The largest count no rule excludes, or None when even 2 is excluded."""
    if excluded[BASE]:
        return None
    return max(workers for workers, rules in excluded.items() if not rules)


def table(facts):
    """The Markdown table `19-04-MEASURE.md` carries, one row per device, configuration and count."""
    by_size = medians(facts)
    head = ('Device', 'Configuration', 'Workers', 'Pictures', 'Median s', 'x at 2', 'Wall s', 'Speed-up', 'Memory',
            'Changed')
    rows = ['| ' + ' | '.join(head) + ' |', '|' + '---|' * len(head)]
    families, configurations = snapshot_matrix.FAMILIES, snapshot_matrix.configurations()

    def order(key):
        position = configurations.index(key[1]) if key[1] in configurations else len(configurations)
        return families.index(key[0]), position, key[1], key[2]

    for key in sorted(facts, key=order):
        family, configuration, workers = key
        fact = facts[key]
        base = by_size.get((family, size_of(configuration), BASE))
        ratio = f'{fact["median"] / base:.2f}' if fact['median'] is not None and base else '-'
        median = f'{fact["median"]:.2f}' if fact['median'] is not None else '-'
        speedup = f'{fact["speedup"]:.2f}' if fact['speedup'] is not None else '-'
        rows.append(f'| {family} | {configuration} | {workers} | {fact["pictures"]} | {median} | {ratio} | '
                    f'{fact["wall"]:.0f} | {speedup} | {fact["memory"]} | {fact["changed"]} |')
    return '\n'.join(rows)


def verdict(excluded, chosen):
    lines = [f'- {workers} workers: ' + (', '.join(rules) if rules else 'passes every rule')
             for workers, rules in excluded.items()]
    lines.append(f'- Chosen: {chosen} workers' if chosen else '- Chosen: none (2 workers is excluded)')
    return '\n'.join(lines)


def cost_table(facts, chosen, run_id, boot_minutes, fixed_minutes=None):
    by_size = medians(facts)
    seconds = {}
    for family in snapshot_matrix.FAMILIES:
        missing = [size for size in SIZES if (family, size, chosen) not in by_size]
        if missing:
            raise ValueError(f'No {family} measurement at {chosen} workers for {", ".join(missing)}')
        seconds[family] = {size: round(by_size[(family, size, chosen)], 3) for size in SIZES}
    speedups = [fact['speedup'] for (_, _, workers), fact in facts.items()
                if workers == chosen and fact['speedup'] is not None]
    return {
        'schema': 1, 'source': 'measured', 'runId': str(run_id),
        'note': (f'Measured on the hosted runner in run {run_id}: median seconds per picture per clone at {chosen} '
                 'workers over the 19-05 classes in en; the clone speed-up is the smallest of its runs.'),
        'secondsPerPicture': seconds, 'workers': chosen, 'cloneSpeedup': round(min(speedups), 2),
        'bootFetchMinutes': boot_minutes, 'invocationMinutes': fixed_minutes,
    }


def render(costs):
    """The cost table in the committed file's layout: one line per device."""
    head = {key: costs[key] for key in ('schema', 'source', 'runId', 'note')}
    lines = ['{'] + [f'  {json.dumps(key)}: {json.dumps(value, ensure_ascii=False)},' for key, value in head.items()]
    lines.append('  "secondsPerPicture": {')
    families = list(costs['secondsPerPicture'].items())
    for index, (family, sizes) in enumerate(families):
        inner = ', '.join(f'{json.dumps(size)}: {json.dumps(value)}' for size, value in sizes.items())
        lines.append(f'    {json.dumps(family)}: {{{inner}}}' + (',' if index < len(families) - 1 else ''))
    lines.append('  },')
    tail = [f'  {json.dumps(key)}: {json.dumps(costs[key])}'
            for key in ('workers', 'cloneSpeedup', 'bootFetchMinutes', 'invocationMinutes')
            if costs.get(key) is not None]
    lines += [line + ',' for line in tail[:-1]] + [tail[-1], '}']
    return '\n'.join(lines) + '\n'


def candidate_walls(root):
    """`{(family, configuration): wall seconds}` of every candidate that kept its `shard.json`."""
    walls = {}
    for record in sorted(Path(root).glob('*/*/candidate/shard.json')):
        data = json.loads(record.read_text())
        family, configuration = record.parts[-4], record.parts[-3]
        walls[(family, configuration)] = (parse_time(data['finished']) - parse_time(data['started'])).total_seconds()
    return walls


def invocation_minutes(walls, override):
    """The fixed minutes per invocation (see the module note), or `override`; `None` when nothing measures it."""
    if override is not None:
        return override
    fixed = []
    for family in snapshot_matrix.FAMILIES:
        singles = [walls.get((family, f'en-{size}')) for size in SIZES]
        together = walls.get((family, 'all'))
        if together is not None and None not in singles:
            fixed.append((sum(singles) - together) / (len(SIZES) - 1))
    return round(max(fixed) / 60, 1) if fixed else None


def boot_fetch_minutes(boot, override):
    if override is not None:
        return override
    if not boot:
        raise ValueError('No timing.json with bootFetchSeconds; pass --boot-fetch-minutes')
    return math.ceil(max(boot.values()) / 6) / 10


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--runs', type=Path, required=True)
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--write', type=Path, help='the cost table to write when a count is chosen')
    parser.add_argument('--boot-fetch-minutes', type=float)
    parser.add_argument('--invocation-minutes', type=float, help='the fixed minutes per invocation, if not measured')
    args = parser.parse_args(argv)
    runs, memory, boot = load(args.runs)
    if not runs:
        print(f'No w<N> runs under {args.runs}', file=sys.stderr)
        return 2
    facts = measure(runs, memory)
    excluded = exclusions(facts)
    chosen = choose(excluded)
    print(table(facts))
    print()
    print(verdict(excluded, chosen))
    fixed = invocation_minutes(candidate_walls(args.runs), None)
    print(f'- Fixed cost per invocation: {"not measured" if fixed is None else f"{fixed} min"}')
    if chosen is None:
        return 1
    if args.write:
        try:
            costs = cost_table(facts, chosen, args.run_id, boot_fetch_minutes(boot, args.boot_fetch_minutes),
                               invocation_minutes(candidate_walls(args.runs), args.invocation_minutes))
        except ValueError as error:
            print(error, file=sys.stderr)
            return 2
        args.write.write_text(render(costs))
    return 0


if __name__ == '__main__':
    sys.exit(main())
