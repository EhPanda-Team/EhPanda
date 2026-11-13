#!/usr/bin/env python3
"""The deterministic shard plan the CI gate reads (19-CONTEXT D-15, owner msg 2263; 19-RESEARCH §5, §9).

A unit is one test process: a `<locale>-<size>` configuration in one orientation. An iPad process captures only the
orientation the device was turned to before launch (19-01-MEASURE.md); an iPhone process turns itself, and
`EHPANDA_SNAPSHOT_ORIENTATIONS` names the one orientation it captures (run-shard.sh), which run 43298876957 made
necessary: its iPhone shards of both orientations were estimated at 73 minutes and the runner cut about half of the
jobs that long (13 of 27, at random times, 18 to 93 minutes in). That gives 36 iPhone and 36 iPad units, 72 in all.
A unit's cost is the sum, over the pictures it captures, of the per-picture seconds in `snapshot-cost.json`. Each
device gets the fewest shards whose estimates all stay within its target in `TARGET_MINUTES` (at most one shard per
unit); within a device, units go longest first to the least loaded shard, ties by unit key and then by shard order,
so the same inventory and cost table always give the same file. Run 42577585956 planned 20 shards on a modelled
table: its iPhone shards were estimated at 60 minutes and needed 113 to 115 or more, so five of six ran out of time.

The targets are the shortest a shard can be. Each shard pays the table's `bootFetchMinutes` and `invocationMinutes`
(11.3 minutes), so a shard is one process for an iPad (about 26 to 29 estimated minutes, target 35: two would be 40
to 45) and one process for an iPhone (about 42, since its process is the longest unit; the target 45 only has to
admit it). More, shorter shards cost more shard-minutes in total, since each repeats that fixed cost.

A shard runs its units as few `xcodebuild` invocations as it can: one per orientation group, each with every
configuration of that group (`-only-test-configuration` once per configuration). The simulator clones are created
once per invocation and kept across its configurations, and each invocation has a fixed cost (clone creation,
installing, launching) that the hosted measurement put at 7 to 10 minutes (19-04-MEASURE.md, run 42455556948);
locally a second configuration in the same invocation added 76 s to the first's 208 s. The estimate counts the cost
table's `invocationMinutes` once per invocation.

A unit's wall time is its cost divided by the cost table's `cloneSpeedup`, except an iPad landscape unit: clones boot
in portrait whatever the turned device shows, so that process runs on the turned device alone, without clones
(19-10-PROOF.md). Shards are balanced and estimated on wall time.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import snapshot_matrix

ROOT = Path(__file__).resolve().parents[2]
COSTS = ROOT / 'Scripts/visual/snapshot-cost.json'
SHARDS = ROOT / 'Scripts/visual/snapshot-shards.json'
TIMEOUT_CAP_MINUTES = 120
# The estimate a shard of each device may take. A shard the runner cuts is run again from its start, so the target is
# the shortest the cost table lets a shard be (see the module docstring), not a share of the limit.
TARGET_MINUTES = {'iphone': 45.0, 'ipad': 35.0}


def unit_key(unit):
    return f'{unit[0]}/{unit[1]}/{"+".join(unit[2])}'


def process_orientations(family):
    """The orientation groups one process of the family captures: one at a time, on either device."""
    return [(orientation,) for orientation in snapshot_matrix.ORIENTATIONS]


def unit_pictures(document, env):
    """`{(family, configuration, orientations): pictures}` for the 72 units, from the expected captures."""
    counts = {(family, configuration, orientations): 0
              for family in snapshot_matrix.FAMILIES for configuration in snapshot_matrix.configurations()
              for orientations in process_orientations(family)}
    for row, reason in snapshot_matrix.coordinates(document, env):
        if reason is None:
            orientations = next(group for group in process_orientations(row.family) if row.orientation in group)
            counts[(row.family, row.configuration, orientations)] += 1
    return counts


def unit_costs(pictures, costs):
    """Seconds per unit: its pictures times the per-picture seconds of its device and text size."""
    seconds = costs['secondsPerPicture']
    return {unit: count * seconds[unit[0]][unit[1].rsplit('-', 1)[1]] for unit, count in pictures.items()}


def clone_speedup(unit, costs):
    """The unit's speedup from simulator clones: none for an iPad landscape process, which runs unparallelled."""
    return 1 if unit[0] == 'ipad' and unit[2] == ('landscape',) else costs['cloneSpeedup']


def unit_seconds(costs_by_unit, costs):
    """Wall seconds per unit: its cost over the speedup its process gets from clones."""
    return {unit: cost / clone_speedup(unit, costs) for unit, cost in costs_by_unit.items()}


def balance(costs_by_unit, family, count):
    """`[(units, cost)]`: the family's units over `count` shards, longest first to the least loaded."""
    loads = [[0.0, []] for _ in range(count)]
    family_units = sorted((unit for unit in costs_by_unit if unit[0] == family),
                          key=lambda unit: (-costs_by_unit[unit], unit_key(unit)))
    for unit in family_units:
        target = min(range(count), key=lambda index: (loads[index][0], index))
        loads[target][0] += costs_by_unit[unit]
        loads[target][1].append(unit)
    return [(units, cost) for cost, units in loads]


def estimate(units, wall, costs):
    """Minutes: boot and fetch once, the fixed cost once per invocation, then the wall seconds."""
    return costs['bootFetchMinutes'] + len(invocations(units)) * costs.get('invocationMinutes', 0) + wall / 60


def split(costs_by_unit, costs=None):
    """Shards per device: the fewest whose estimates all fit the device's `TARGET_MINUTES`, at most one per unit.

    `costs_by_unit` is in wall seconds. Without a cost table only the wall seconds count (no fixed minutes)."""
    costs = costs or {'bootFetchMinutes': 0, 'invocationMinutes': 0}
    result = {}
    for family in snapshot_matrix.FAMILIES:
        target = TARGET_MINUTES[family]
        units = sum(unit[0] == family for unit in costs_by_unit)
        count = 1
        while count < units and any(estimate(group, wall, costs) > target
                                    for group, wall in balance(costs_by_unit, family, count)):
            count += 1
        result[family] = count
    return result


def assign(costs_by_unit, costs=None):
    """`[(family, [units], cost)]` in shard order: iPhone shards first, then iPad, each by longest-first."""
    result = []
    for family, count in split(costs_by_unit, costs).items():
        result += [(family, units, cost) for units, cost in balance(costs_by_unit, family, count)]
    return result


def run_order(unit):
    """Runs go by configuration order, then portrait before landscape, so an iPad shard turns as little as it can."""
    return snapshot_matrix.configurations().index(unit[1]), snapshot_matrix.ORIENTATIONS.index(unit[2][0])


def invocations(units):
    """`[{'configurations', 'orientations'}]`: one invocation per orientation group of the shard's units."""
    order = snapshot_matrix.configurations()
    groups = {}
    for unit in sorted(units, key=run_order):
        groups.setdefault(unit[2], []).append(unit[1])
    return [{'configurations': sorted(configurations, key=order.index), 'orientations': list(orientations)}
            for orientations, configurations in sorted(groups.items(),
                                                       key=lambda item: snapshot_matrix.ORIENTATIONS.index(item[0][0]))]


def plan(document, env, costs, cost_digest):
    pictures = unit_pictures(document, env)
    costs_by_unit = unit_costs(pictures, costs)
    order = snapshot_matrix.configurations()
    shards = []
    for index, (family, units, wall) in enumerate(assign(unit_seconds(costs_by_unit, costs), costs), start=1):
        calls = invocations(units)
        cost = sum(costs_by_unit[unit] for unit in units)
        estimated = round(estimate(units, wall, costs), 1)
        shards.append({
            'id': f's{index:02d}', 'family': family,
            'configurations': sorted({unit[1] for unit in units}, key=order.index),
            'runs': [{'configuration': unit[1], 'orientations': list(unit[2])}
                     for unit in sorted(units, key=run_order)],
            'invocations': calls,
            'pictures': sum(pictures[unit] for unit in units),
            'costSeconds': round(cost, 1),
            'estimatedMinutes': estimated,
            'timeoutMinutes': min(TIMEOUT_CAP_MINUTES, math.ceil(2 * estimated)),
        })
    return {'schema': 1, 'costTable': cost_digest, 'costSource': costs['source'], 'workers': costs['workers'],
            'targetMinutes': dict(TARGET_MINUTES), 'shards': shards}


def render(shard_plan):
    return json.dumps(shard_plan, indent=2, ensure_ascii=False) + '\n'


def compute(inventory=snapshot_matrix.INVENTORY, environment=snapshot_matrix.ENVIRONMENT, cost_path=COSTS):
    document, env = snapshot_matrix.load(inventory, environment)
    cost_bytes = Path(cost_path).read_bytes()
    costs = json.loads(cost_bytes)
    if costs.get('schema') != 1 or costs.get('source') not in ('model', 'measured'):
        raise ValueError('Expected a schema-1 cost table whose source is model or measured')
    return render(plan(document, env, costs, hashlib.sha256(cost_bytes).hexdigest()))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='exit 1 when the committed plan is stale')
    parser.add_argument('--output', type=Path, default=SHARDS)
    args = parser.parse_args(argv)
    fresh = compute()
    if args.check:
        if not args.output.exists() or args.output.read_text() != fresh:
            print(f'{args.output} is stale; run Scripts/visual/snapshot_shards.py', file=sys.stderr)
            return 1
        print('snapshot-shards.json is current')
        return 0
    args.output.write_text(fresh)
    return 0


if __name__ == '__main__':
    sys.exit(main())
