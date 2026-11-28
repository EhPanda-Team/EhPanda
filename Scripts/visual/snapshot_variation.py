#!/usr/bin/env python3
"""Compares two snapshot runs of one commit key by key, for the run-to-run variation (19-27; design §5 step 3).

Two runs of the same commit should take the same pictures. Where they do not, the difference is a defect, fixed at
its cause and never absorbed: the comparison is the matrix's own (`HostedWindowCapture.compare`, precision 0.9999 and
perceptual precision 1, D-10), run in the app-hosted test `VariationComparisonTests`, and this tool adds no tolerance,
retry or skipped scenario of its own.

A side (`--a`, `--b`) is either an assembled set (`fingerprints.json` and `pictures/`, `snapshot_publish.py
assemble`) or a local run's output directory (its `results.jsonl` `recorded` lines, pictures at their baseline
paths, `run-snapshot-local.sh`). `--scenarios` limits either command to those scenario IDs.

- `pairs --a SET --b SET [--scenarios IDS] --out FILE` writes, as JSON Lines, the keys whose digests differ, each with
  both pictures' absolute paths (`key`, `a`, `b`). Keys on one side only are written to `missing.json` beside `FILE`
  (`{"a": [...], "b": [...]}`: the keys only that side holds) and make the command exit 1, naming them.
- `compare --pairs FILE --out DIR --simulator NAME` runs `VariationComparisonTests` on the simulator of exactly that
  name (FeatureTests, after any running `xcodebuild`), which writes `DIR/outcomes.jsonl` (one line per pair, in order:
  `key`, `outcome`, `region`, `largestStep`, `differingBytes`) and `DIR/difference/<key>.png` per `beyond-tolerance`
  key. It exits 1 when the test fails or an outcome is missing.
- `report --a SET --b SET --pairs FILE --outcomes FILE [--artifacts-a DIR --artifacts-b DIR] [--scenarios IDS] --out
  FILE` writes JSON: `counts` (`identical-digest`, the four outcome classes and `unreadable`), `beyond` as
  `{scenario: {"count", "keys", "families", "orientations", "themes", "locales", "sizes"}}` (the last five as value
  counts) and `flaky` as `{"a": [keys], "b": [keys]}`: the keys whose line in that run's artifacts (the attempt
  `snapshot_publish.choose` picked) carries `flaky: true` or more than one attempt. It exits 1 when a pair has no
  outcome line.

Outcome classes: `identical-pixels` (different files, the same pixels), `within-tolerance` (the comparison passes),
`beyond-tolerance` (it fails), `size-differs`, and `unreadable` (a file that is not a picture). A picture file that
cannot be read at all fails the comparison instead of being classed.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import snapshot_fetch
import snapshot_publish

ROOT = Path(__file__).resolve().parents[2]
CLASSES = ('identical-pixels', 'within-tolerance', 'beyond-tolerance', 'size-differs', 'unreadable')
FIELDS = ('families', 'orientations', 'themes', 'locales', 'sizes')
TEST = 'VisualSnapshotTests/VariationComparisonTests'
SHOWN = 20


class VariationError(Exception):
    """The runs cannot be compared as asked; each argument is one problem line."""


def scenario_filter(scenarios):
    """The set of scenario IDs a comma-separated list names, or `None` for every scenario."""
    names = {name for name in (scenarios or '').split(',') if name}
    return names or None


def read_side(directory, scenarios=None):
    """`{key: (digest, picture path)}` of an assembled set or a local run's output directory."""
    fingerprints = directory / 'fingerprints.json'
    if fingerprints.is_file():
        digests = json.loads(fingerprints.read_text())['pictures']
        pictures = directory / 'pictures'
    elif (directory / 'results.jsonl').is_file():
        digests = {}
        for key, found in snapshot_publish.recorded_lines(directory).items():
            if len(found) != 1 or '' in found:
                raise VariationError(f'{key}: {directory} recorded it with {len(found)} different digests')
            digests[key] = next(iter(found))
        pictures = directory
    else:
        raise VariationError(f'{directory}: neither an assembled set (fingerprints.json) nor a run (results.jsonl)')
    return {key: (digest, pictures / snapshot_fetch.key_path(key)) for key, digest in digests.items()
            if scenarios is None or key.split('__')[0] in scenarios}


def pairs(side_a, side_b):
    """`(pairs, missing)`: the pairs whose digests differ, by key, and the keys each side alone holds.

    The paths are absolute: the comparison runs in the test process, whose working directory is not this one.
    """
    found = [{'key': key, 'a': str(side_a[key][1].resolve()), 'b': str(side_b[key][1].resolve())}
             for key in sorted(side_a.keys() & side_b.keys()) if side_a[key][0] != side_b[key][0]]
    missing = {'a': sorted(side_a.keys() - side_b.keys()), 'b': sorted(side_b.keys() - side_a.keys())}
    return found, missing


def read_lines(path):
    return [json.loads(text) for text in path.read_text().splitlines() if text.strip()]


def flaky_keys(artifacts, keys):
    """The keys whose chosen attempt's line is flaky or took more than one attempt."""
    found = []
    for key, (directory, _) in snapshot_publish.choose(artifacts).items():
        if key not in keys:
            continue
        for line in read_lines(directory / 'results.jsonl'):
            if line['key'] == key and line.get('status') == 'recorded' and (
                    line.get('flaky') or (line.get('attempts') or 1) > 1):
                found.append(key)
                break
    return sorted(found)


def report(side_a, side_b, pair_lines, outcome_lines, artifacts_a=None, artifacts_b=None):
    """The report document; raises `VariationError` when a pair has no outcome line."""
    outcomes = {line['key']: line for line in outcome_lines}
    absent = [pair['key'] for pair in pair_lines if pair['key'] not in outcomes]
    if absent:
        raise VariationError(*(f'{key}: no outcome line' for key in absent))
    common = side_a.keys() & side_b.keys()
    counts = {'identical-digest': sum(1 for key in common if side_a[key][0] == side_b[key][0])}
    counts.update({name: 0 for name in CLASSES})
    beyond = {}
    for pair in pair_lines:
        outcome = outcomes[pair['key']]['outcome']
        counts[outcome] += 1
        if outcome != 'beyond-tolerance':
            continue
        scenario, locale, size, orientation, family, theme = pair['key'].split('__')
        entry = beyond.setdefault(scenario, {'count': 0, 'keys': [], **{field: {} for field in FIELDS}})
        entry['count'] += 1
        entry['keys'].append(pair['key'])
        for field, value in zip(FIELDS, (family, orientation, theme, locale, size)):
            entry[field][value] = entry[field].get(value, 0) + 1
    flaky = {'a': flaky_keys(artifacts_a, common) if artifacts_a else [],
             'b': flaky_keys(artifacts_b, common) if artifacts_b else []}
    return {'counts': counts, 'beyond': dict(sorted(beyond.items())), 'flaky': flaky}


def simulator(name):
    """The UDID of the one available simulator named exactly `name`, as `run-snapshot-local.sh` resolves it."""
    listing = subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], check=True,
                             capture_output=True, text=True).stdout
    matches = [device['udid'] for devices in json.loads(listing)['devices'].values() for device in devices
               if device['name'] == name and device.get('isAvailable', True)]
    if len(matches) != 1:
        raise VariationError(f'{"No" if not matches else "Several"} simulators named {name}.')
    return matches[0]


def wait_for_host():
    """Waits while another `xcodebuild` runs: one at a time on this host."""
    while subprocess.run(['pgrep', '-x', 'xcodebuild'], capture_output=True).returncode == 0:
        time.sleep(15)


def compare(pairs_path, out, name):
    """Runs the comparison; returns the outcome lines, one per pair."""
    udid = simulator(name)
    out.mkdir(parents=True, exist_ok=True)
    bundle = out / 'compare.xcresult'
    outcomes = out / 'outcomes.jsonl'
    for stale in (bundle, outcomes):
        if stale.is_dir():
            shutil.rmtree(stale)
        elif stale.exists():
            stale.unlink()
    wait_for_host()
    environment = dict(os.environ, TEST_RUNNER_EHPANDA_VARIATION_PAIRS=str(pairs_path.resolve()),
                       TEST_RUNNER_EHPANDA_VARIATION_OUTPUT=str(out.resolve()))
    with (out / 'xcodebuild.log').open('w') as log:
        status = subprocess.run(
            ['xcodebuild', 'test', '-project', 'EhPanda.xcodeproj', '-scheme', 'EhPanda', '-testPlan', 'FeatureTests',
             '-destination', f'platform=iOS Simulator,id={udid}', f'-only-testing:{TEST}',
             '-collect-test-diagnostics', 'never', '-resultBundlePath', str(bundle)],
            cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT).returncode
    if status != 0:
        raise VariationError(f'xcodebuild exited {status} ({out / "xcodebuild.log"})')
    expected = [pair['key'] for pair in read_lines(pairs_path)]
    written = [line['key'] for line in read_lines(outcomes)] if outcomes.is_file() else []
    if written != expected:
        raise VariationError(f'{outcomes}: {len(written)} outcome lines for {len(expected)} pairs')
    return written


def problem_lines(error):
    lines = list(error.args)
    shown = lines[:SHOWN]
    if len(lines) > SHOWN:
        shown.append(f'... and {len(lines) - SHOWN} more')
    return shown


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    pairing = commands.add_parser('pairs')
    pairing.add_argument('--a', type=Path, required=True)
    pairing.add_argument('--b', type=Path, required=True)
    pairing.add_argument('--scenarios')
    pairing.add_argument('--out', type=Path, required=True)
    comparing = commands.add_parser('compare')
    comparing.add_argument('--pairs', type=Path, required=True)
    comparing.add_argument('--out', type=Path, required=True)
    comparing.add_argument('--simulator', required=True)
    reporting = commands.add_parser('report')
    reporting.add_argument('--a', type=Path, required=True)
    reporting.add_argument('--b', type=Path, required=True)
    reporting.add_argument('--pairs', type=Path, required=True)
    reporting.add_argument('--outcomes', type=Path, required=True)
    reporting.add_argument('--artifacts-a', type=Path)
    reporting.add_argument('--artifacts-b', type=Path)
    reporting.add_argument('--scenarios')
    reporting.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'pairs':
            scenarios = scenario_filter(args.scenarios)
            found, missing = pairs(read_side(args.a, scenarios), read_side(args.b, scenarios))
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(''.join(json.dumps(pair, sort_keys=True) + '\n' for pair in found))
            (args.out.parent / 'missing.json').write_text(json.dumps(missing, indent=2) + '\n')
            print(f'{len(found)} pairs differ')
            if missing['a'] or missing['b']:
                raise VariationError(*(f'{key}: only in {side}' for side in ('a', 'b') for key in missing[side]))
        elif args.command == 'compare':
            print(f'{len(compare(args.pairs, args.out, args.simulator))} pairs compared')
        else:
            scenarios = scenario_filter(args.scenarios)
            document = report(read_side(args.a, scenarios), read_side(args.b, scenarios), read_lines(args.pairs),
                              read_lines(args.outcomes), args.artifacts_a, args.artifacts_b)
            args.out.write_text(json.dumps(document, indent=2, sort_keys=True) + '\n')
            print(json.dumps(document['counts'], sort_keys=True))
    except (VariationError, snapshot_publish.PublishError) as error:
        print('\n'.join(problem_lines(error)), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
