#!/usr/bin/env python3
"""Turns measuring runs into the committed page heights, writes them into the view files and reads them back
(19-20; 19-FULL-PAGE-CAPTURE-DESIGN sections 3 and 4).

usage: snapshot_heights.py propose --runs DIR... --out FILE
       snapshot_heights.py apply --proposal FILE [--only ID,ID...]
       snapshot_heights.py check-sources
       snapshot_heights.py export --out FILE

Every picture is taken in a window of a height that covers its whole page, and that height is fixed in the source: the
`heights:` argument of the state in its `AppPackage/Tests/VisualSnapshotTests/Snapshots/*ViewSnapshot.swift` file,
never measured or changed during a run (owner decision, 2026-11-22). One value serves a device, an orientation and a
text size, the tallest of the six languages and both themes (owner decision). The measuring mode that finds the
need of each coordinate is local only (`run-snapshot-local.sh --measure-heights`: no picture, one line per
coordinate in `heights.jsonl`); this tool is the only thing that turns its lines into source, and only as an explicit
step whose diff is reviewed before it is committed.

- `propose`: reads the `heights.jsonl` of each run directory (a later line of a coordinate replaces an earlier one)
  and writes the proposal `{"heights": {scenario: {family: {orientation: {size: points}}}}, "findings": [...]}`: per
  scenario, family, orientation and text size the tallest need over the languages and themes the inventory captures,
  rounded up to whole points and never under the device height (the pinned screen height; a group the inventory does
  not capture at all gets the device height). It refuses, naming the coordinates and writing nothing, when a scenario
  that a run measured has an expected coordinate without a line: an incomplete run must not decide a height. A
  `cannot-cover`, `did-not-converge` or `error` line is a finding for the owner: it is listed, and its group gets no
  value.
- `apply`: writes the proposal into the view files in the canonical layout, only the `heights:` argument of each
  named state (`--only`, default every scenario of the proposal) and, where a file commits heights, `import
  CoreGraphics`. It refuses, writing nothing, a scenario whose twelve values are not all in the proposal, or a value
  that is not a whole number or is under the device height. A scenario whose twelve values are all the device height is
  written as `.screen`. Running it twice changes nothing more. It refuses a state declared `.viewport(reason:)`: the
  owner exempted it from the full-page rule, and only the owner's decision changes it.
- `check-sources`: fails on a value under the device height, a non-integer, a literal that is not the canonical layout
  (`.screen` where all twelve values are the device height), a `.viewport` state without its reason, a duplicate ID, or
  an ID set unlike `scenarios.json`.
- `export`: writes the committed heights as `{scenario: {family: {orientation: {size: points}}}}` with `.screen` and
  `.viewport` resolved to the device heights, the file `snapshot_precheck.py --heights` reads.

A `.viewport(reason:)` state is taken at the device height without the `page-height` check (19-26): the owner kept its
pictures at the screen height, and `reason` holds their decision, quoted and dated. Its canonical layout is
`heights: .viewport(`, then `reason: "<the decision>"` indented one level more, then `),`.
"""

import argparse
from collections import defaultdict
from dataclasses import dataclass
import json
import math
from pathlib import Path
import re
import sys

import snapshot_matrix

SNAPSHOTS = snapshot_matrix.ROOT / 'AppPackage/Tests/VisualSnapshotTests/Snapshots'
FAMILIES = snapshot_matrix.FAMILIES
ORIENTATIONS = snapshot_matrix.ORIENTATIONS
SIZES = snapshot_matrix.SIZES
UNFINISHED = ('cannot-cover', 'did-not-converge', 'error')
IMPORT = re.compile(r'^(?:public |internal |package |@testable )*import (\w+)\s*$')
STATE_ID = re.compile(r'^(\s*)id: "([^"]+)",$')
VALUE = re.compile(r'\b(xSmall|large|accessibility5): ([^,)\s]+)')
REASON = re.compile(r'^(\s*)reason: "((?:[^"\\]|\\.)*)"$')


@dataclass(frozen=True)
class Block:
    """One state's `heights:` argument in a provider file: the lines `[start, end)` and the state's indent."""
    identifier: str
    indent: str
    start: int
    end: int


def device_heights(env):
    """`{(family, orientation): points}`: the pinned screen height each picture is at least as tall as."""
    heights = {}
    for family in FAMILIES:
        for orientation in ORIENTATIONS:
            height = env['devices'][family]['orientations'][orientation]['points'][-1]
            if height != int(height):
                raise ValueError(f'{family} {orientation}: the pinned height {height} is not whole points')
            heights[(family, orientation)] = int(height)
    return heights


def device_values(env):
    """The twelve values of a scenario that stays at the device height."""
    pins = device_heights(env)
    return {family: {orientation: dict.fromkeys(SIZES, pins[(family, orientation)]) for orientation in ORIENTATIONS}
            for family in FAMILIES}


# MARK: propose

def read_runs(directories):
    """`{key: line}` of every `heights.jsonl` in order; a later line of a key replaces an earlier one."""
    lines = {}
    for directory in directories:
        path = Path(directory) / 'heights.jsonl'
        if not path.is_file():
            raise ValueError(f'{path}: no heights.jsonl')
        for text in path.read_text().splitlines():
            if text.strip():
                line = json.loads(text)
                lines[line['key']] = line
    return lines


def propose(lines, document, env):
    """`(heights, findings, missing)` from the runs' lines.

    `heights` holds a value for each group of a measured scenario that has one; `findings` lists the lines that
    gave no value; `missing` lists the expected coordinates of a measured scenario that no line covers.
    """
    pins = device_heights(env)
    inventory = {entry['id'] for entry in document['scenarios']}
    measured = {key.split('__')[0] for key in lines}
    unknown = sorted(measured - inventory)
    if unknown:
        raise ValueError(f'scenarios not in the inventory: {", ".join(unknown)}')
    groups = defaultdict(list)
    for coordinate, reason in snapshot_matrix.coordinates(document, env):
        if coordinate.scenario in measured:
            expected = [coordinate.key] if reason is None else []
            groups[(coordinate.scenario, coordinate.family, coordinate.orientation, coordinate.size)] += expected
    heights, findings, missing = {}, [], []
    for (scenario, family, orientation, size), keys in sorted(groups.items()):
        device = pins[(family, orientation)]
        absent = [key for key in keys if key not in lines or lines[key]['status'] == 'notApplicable']
        missing += absent
        if absent:
            continue
        unfinished = [lines[key] for key in keys if lines[key]['status'] in UNFINISHED]
        findings += [{'key': line['key'], 'status': line['status'], 'reason': line.get('reason')}
                     for line in unfinished]
        if unfinished:
            continue
        needs = []
        for key in keys:
            if lines[key]['status'] != 'measured' or lines[key].get('neededPoints') is None:
                raise ValueError(f'{key}: a measured line without a need')
            needs.append(lines[key]['neededPoints'])
        value = max([device, *(math.ceil(need) for need in needs)])
        heights.setdefault(scenario, {}).setdefault(family, {}).setdefault(orientation, {})[size] = value
    return heights, sorted(findings, key=lambda finding: finding['key']), sorted(missing)


# MARK: Provider files

def locate(lines):
    """The `heights:` argument of every state in a provider file, found by its `id: "<id>",` line."""
    blocks = []
    for index, text in enumerate(lines):
        match = STATE_ID.match(text)
        if not match or index == 0 or lines[index - 1].strip() != 'SnapshotState(':
            continue
        indent, identifier = match.groups()
        start = index + 1
        end = next((position for position in range(start, len(lines))
                    if lines[position].strip().startswith('factory:')), None)
        if end is None or start >= end or not lines[start].strip().startswith('heights:'):
            raise ValueError(f'{identifier}: no heights argument between its id and its factory')
        blocks.append(Block(identifier, indent, start, end))
    return blocks


def render(values, env, indent):
    """The canonical `heights:` argument: `.screen` when all twelve values are the device height."""
    if values == device_values(env):
        return [f'{indent}heights: .screen,']
    lines = [f'{indent}heights: .committed(']
    for family in FAMILIES:
        lines.append(f'{indent}    {family}: .init(')
        for orientation in ORIENTATIONS:
            row = ', '.join(f'{size}: {values[family][orientation][size]}' for size in SIZES)
            lines.append(f'{indent}        {orientation}: .init({row}){"," if orientation != ORIENTATIONS[-1] else ""}')
        lines.append(f'{indent}    ){"," if family != FAMILIES[-1] else ""}')
    lines.append(f'{indent}),')
    return lines


def viewport_reason(block, lines):
    """The reason of a state declared `.viewport(reason:)`, as written; `None` for any other declaration."""
    text = lines[block.start:block.end]
    if not text or not text[0].startswith(f'{block.indent}heights: .viewport('):
        return None
    reason = REASON.match(text[1]) if len(text) == 3 else None
    return reason.group(2) if reason else ''


def parse(block, lines, env):
    """`(values, problems)` of a state's `heights:` argument; `values` is `None` when it cannot be read."""
    text = lines[block.start:block.end]
    if text == [f'{block.indent}heights: .screen,']:
        return device_values(env), []
    if text and text[0].startswith(f'{block.indent}heights: .viewport('):
        reason = REASON.match(text[1]) if len(text) == 3 else None
        canonical = (text[0] == f'{block.indent}heights: .viewport(' and reason is not None
                     and reason.group(1) == f'{block.indent}    ' and text[2] == f'{block.indent}),')
        if not canonical:
            return None, [f'{block.identifier}: the heights literal is not the canonical layout']
        if not reason.group(2).strip():
            return device_values(env), [f'{block.identifier}: a viewport state needs its reason']
        return device_values(env), []
    entries = VALUE.findall('\n'.join(text))
    if len(entries) != len(FAMILIES) * len(ORIENTATIONS) * len(SIZES):
        return None, [f'{block.identifier}: the heights literal is not the canonical layout']
    problems, numbers = [], []
    for _, literal in entries:
        if re.fullmatch(r'\d+', literal):
            numbers.append(int(literal))
        elif re.fullmatch(r'\d+\.\d+', literal):
            problems.append(f'{block.identifier}: {literal} is not a whole number of points')
            numbers.append(None)
        else:
            return None, [f'{block.identifier}: the heights literal is not the canonical layout']
    if problems:
        return None, problems
    values, remaining = {}, iter(numbers)
    for family in FAMILIES:
        values[family] = {orientation: {size: next(remaining) for size in SIZES} for orientation in ORIENTATIONS}
    if render(values, env, block.indent) != text:
        return values, [f'{block.identifier}: the heights literal is not the canonical layout']
    return values, []


def provider_files(directory):
    return sorted(Path(directory).glob('*ViewSnapshot.swift'))


def read_sources(directory, env):
    """`({id: (path, values, viewport reason or None)}, problems)` of every state in the provider files."""
    pins = device_heights(env)
    states, problems = {}, []
    for path in provider_files(directory):
        lines = path.read_text().split('\n')
        for block in locate(lines):
            if block.identifier in states:
                problems.append(f'{block.identifier}: declared twice ({states[block.identifier][0].name}, {path.name})')
                continue
            values, found = parse(block, lines, env)
            problems += found
            for family in FAMILIES:
                for orientation in ORIENTATIONS:
                    for size, value in ((values or {}).get(family, {}).get(orientation, {})).items():
                        if value < pins[(family, orientation)]:
                            problems.append(f'{block.identifier}: {family} {orientation} {size} is {value}, under the '
                                            f'device height {pins[(family, orientation)]}')
            states[block.identifier] = (path, values, viewport_reason(block, lines))
    return states, problems


def check_sources(directory, document, env):
    """The problems of the committed heights: values, literals, duplicate IDs and the ID set."""
    states, problems = read_sources(directory, env)
    inventory = {entry['id'] for entry in document['scenarios']}
    for identifier in sorted(inventory - states.keys()):
        problems.append(f'{identifier}: in scenarios.json but in no provider file')
    for identifier in sorted(states.keys() - inventory):
        problems.append(f'{identifier}: in a provider file but not in scenarios.json')
    return states, problems


def export(directory, document, env):
    """`{scenario: {family: {orientation: {size: points}}}}`, refusing sources that fail the checks."""
    states, problems = check_sources(directory, document, env)
    if problems:
        raise ValueError('\n'.join(problems))
    return {identifier: states[identifier][1] for identifier in sorted(states)}


def with_core_graphics(lines):
    """`lines` with `import CoreGraphics` among the leading imports in module order, if it is not there."""
    imports = [(index, IMPORT.match(text).group(1)) for index, text in enumerate(lines) if IMPORT.match(text)]
    if any(name == 'CoreGraphics' for _, name in imports):
        return lines
    if not imports:
        return ['import CoreGraphics', '', *lines]
    after = [index for index, name in imports if name.lower() < 'coregraphics']
    at = after[-1] + 1 if after else imports[0][0]
    return [*lines[:at], 'import CoreGraphics', *lines[at:]]


def apply(proposal, only, directory, document, env):
    """Writes the proposal into the provider files; returns the files that changed. Nothing is written on a refusal."""
    pins = device_heights(env)
    heights = proposal['heights']
    names = sorted(only) if only else sorted(heights)
    states, problems = read_sources(directory, env)
    problems = [problem for problem in problems if problem.split(':')[0] in names]
    new_values = {}
    for name in names:
        if name not in states:
            problems.append(f'{name}: in no provider file')
            continue
        if states[name][2] is not None:
            problems.append(f'{name}: a viewport state keeps the screen height; only the owner changes it')
            continue
        values = heights.get(name)
        if values is None:
            problems.append(f'{name}: not in the proposal')
            continue
        for family in FAMILIES:
            for orientation in ORIENTATIONS:
                for size in SIZES:
                    value = values.get(family, {}).get(orientation, {}).get(size)
                    if value is None:
                        problems.append(f'{name}: no value for {family} {orientation} {size}')
                    elif not isinstance(value, int) or isinstance(value, bool):
                        problems.append(f'{name}: {family} {orientation} {size} is not a whole number of points')
                    elif value < pins[(family, orientation)]:
                        problems.append(f'{name}: {family} {orientation} {size} is {value}, under the device height')
        new_values[name] = values
    if problems:
        raise ValueError('\n'.join(problems))
    changed = []
    for path in provider_files(directory):
        original = path.read_text()
        lines = original.split('\n')
        # Bottom up, so that a rewritten block never moves the next one's line numbers.
        for block in reversed(locate(lines)):
            if block.identifier in new_values:
                lines[block.start:block.end] = render(new_values[block.identifier], env, block.indent)
        if any(line.strip().startswith('heights: .committed(') for line in lines):
            lines = with_core_graphics(lines)
        text = '\n'.join(lines)
        if text != original:
            path.write_text(text)
            changed.append(path.name)
    return changed


# MARK: Command line

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sources', type=Path, default=SNAPSHOTS, help=argparse.SUPPRESS)
    parser.add_argument('--inventory', type=Path, default=snapshot_matrix.INVENTORY, help=argparse.SUPPRESS)
    commands = parser.add_subparsers(dest='command', required=True)
    proposing = commands.add_parser('propose')
    proposing.add_argument('--runs', type=Path, nargs='+', required=True)
    proposing.add_argument('--out', type=Path, required=True)
    applying = commands.add_parser('apply')
    applying.add_argument('--proposal', type=Path, required=True)
    applying.add_argument('--only', help='comma-separated scenario IDs')
    commands.add_parser('check-sources')
    exporting = commands.add_parser('export')
    exporting.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(argv)
    document, env = snapshot_matrix.load(args.inventory)
    try:
        if args.command == 'propose':
            heights, findings, missing = propose(read_runs(args.runs), document, env)
            if missing:
                print(f'{len(missing)} expected coordinates have no measurement, so nothing is proposed:',
                      file=sys.stderr)
                print('\n'.join(f'  {key}' for key in missing), file=sys.stderr)
                return 1
            args.out.write_text(json.dumps({'heights': heights, 'findings': findings}, indent=2) + '\n')
            print(f'{len(heights)} scenarios proposed, {len(findings)} findings')
            for finding in findings:
                print(f'  finding: {finding["key"]}: {finding["status"]}'
                      + (f' ({finding["reason"]})' if finding['reason'] else ''))
        elif args.command == 'apply':
            only = [name for name in (args.only or '').split(',') if name]
            changed = apply(json.loads(args.proposal.read_text()), only, args.sources, document, env)
            print(f'{len(changed)} files changed' + (': ' + ', '.join(changed) if changed else ''))
        elif args.command == 'check-sources':
            states, problems = check_sources(args.sources, document, env)
            if problems:
                print('\n'.join(problems), file=sys.stderr)
                return 1
            print(f'{len(states)} states, heights read back')
        else:
            args.out.write_text(json.dumps(export(args.sources, document, env), indent=2) + '\n')
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
