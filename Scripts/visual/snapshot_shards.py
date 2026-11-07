#!/usr/bin/env python3
"""The deterministic 20-shard plan the CI gate reads (19-CONTEXT D-15, owner msg 2263; 19-RESEARCH §5, §9).

A unit is one test process: an iPhone `<locale>-<size>` configuration with both orientations, or an iPad
configuration in one orientation, since an iPad process captures only the orientation the device was turned to
before launch (19-01-MEASURE.md). That gives 18 iPhone and 36 iPad units, 54 in all. A unit's cost is the sum, over
the pictures it captures, of the per-picture seconds in `snapshot-cost.json`. Each device gets a share of the shards in
proportion to its total cost; within a device, units go longest first to the least loaded shard, ties by unit key
and then by shard order, so the same inventory and cost table always give the same file.
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
SHARD_COUNT = 20
TIMEOUT_CAP_MINUTES = 120


def unit_key(unit):
    return f'{unit[0]}/{unit[1]}/{"+".join(unit[2])}'


def process_orientations(family):
    """The orientation groups one process of the family captures: both on iPhone, one at a time on iPad."""
    if family == 'ipad':
        return [(orientation,) for orientation in snapshot_matrix.ORIENTATIONS]
    return [snapshot_matrix.ORIENTATIONS]


def unit_pictures(document, env):
    """`{(family, configuration, orientations): pictures}` for the 54 units, from the expected captures."""
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


def split(costs_by_unit, shards=SHARD_COUNT):
    """Shards per device, in proportion to each device's total cost, at least one each."""
    totals = {family: sum(cost for unit, cost in costs_by_unit.items() if unit[0] == family)
              for family in snapshot_matrix.FAMILIES}
    units = {family: sum(unit[0] == family for unit in costs_by_unit) for family in snapshot_matrix.FAMILIES}
    ipad = round(shards * totals['ipad'] / sum(totals.values()))
    ipad = max(1, min(units['ipad'], shards - 1, ipad))
    return {'iphone': shards - ipad, 'ipad': ipad}


def assign(costs_by_unit, shards=SHARD_COUNT):
    """`[(family, [units], cost)]` in shard order: iPhone shards first, then iPad, each by longest-first."""
    result = []
    for family, count in split(costs_by_unit, shards).items():
        loads = [[0.0, []] for _ in range(count)]
        family_units = sorted((unit for unit in costs_by_unit if unit[0] == family),
                              key=lambda unit: (-costs_by_unit[unit], unit_key(unit)))
        for unit in family_units:
            target = min(range(count), key=lambda index: (loads[index][0], index))
            loads[target][0] += costs_by_unit[unit]
            loads[target][1].append(unit)
        result += [(family, units, cost) for cost, units in loads]
    return result


def run_order(unit):
    """Runs go by configuration order, then portrait before landscape, so an iPad shard turns as little as it can."""
    return snapshot_matrix.configurations().index(unit[1]), snapshot_matrix.ORIENTATIONS.index(unit[2][0])


def plan(document, env, costs, cost_digest):
    pictures = unit_pictures(document, env)
    costs_by_unit = unit_costs(pictures, costs)
    order = snapshot_matrix.configurations()
    shards = []
    for index, (family, units, cost) in enumerate(assign(costs_by_unit), start=1):
        estimated = round(costs['bootFetchMinutes'] + cost / (costs['cloneSpeedup'] * 60), 1)
        shards.append({
            'id': f's{index:02d}', 'family': family,
            'configurations': sorted({unit[1] for unit in units}, key=order.index),
            'runs': [{'configuration': unit[1], 'orientations': list(unit[2])}
                     for unit in sorted(units, key=run_order)],
            'pictures': sum(pictures[unit] for unit in units),
            'costSeconds': round(cost, 1),
            'estimatedMinutes': estimated,
            'timeoutMinutes': min(TIMEOUT_CAP_MINUTES, math.ceil(2 * estimated)),
        })
    return {'schema': 1, 'costTable': cost_digest, 'costSource': costs['source'], 'workers': costs['workers'],
            'shards': shards}


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
