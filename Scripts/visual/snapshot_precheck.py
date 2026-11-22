#!/usr/bin/env python3
"""Machine checks on every candidate picture before the owner sees any, and the agent's contact sheets (19-13; D-17).

usage: snapshot_precheck.py --set SET [--out FLAGS] [--sheets DIR] [--workers N] [--heights FILE]

`SET` is an assembled candidate set (`snapshot_publish.py assemble`): its pictures under `SET/pictures/` in the
baseline layout. Every picture is read once by `picture-probe.swift` (Vision text and pixel statistics; the results
are kept in `SET/probe.jsonl` by SHA-256, so a re-run reads only new pictures), then checked:

- `uniform`: blank or near-uniform (luminance deviation under 2, or one colour over 99.5 % of the pixels).
- `placeholder`: a solid rectangle of the colour of the app's image placeholder, at least 40 pixels a side and
  shaped like an image, so an image may not have loaded. In dark sheets the raised background is the same colour.
- `size-outlier`: a file under half or over twice the median size of the same screen in the other languages.
- `committed-height` (with `--heights FILE`, the file `snapshot_heights.py export` writes): a picture whose pixel size
  is not the pinned width of its device and orientation by the committed height of its coordinate (19-20, design
  section 4: every picture is taken in a window of exactly that height, at scale 1). A scenario the file does not
  list is flagged too.
- `same-as`: the same bytes as another scenario at the same coordinate, where the states should differ.
- `same-in-both-themes`: the light and dark pictures are identical.
- `truncated`: text ending in or containing `…` that is not itself a catalog string.
- `untranslated`: an English catalog string, as a whole line, in a non-English picture whose language translates it,
  unless the line is part of a synthetic fixture's own text (a title wrapping, a profile name).
- `real-content`: text from the real site pages kept as parser fixtures, which no synthetic fixture uses.
- `unreadable`: the probe could not read the picture.

Writes `FLAGS` (`{key: "check: detail; …"}`, the shape `snapshot_report.py --flags` reads; default
`SET/flags.json`), `SET/checks.json` (each check's flagged keys) and, with `--sheets`, one contact sheet of 16
pictures per PNG with `sheets.json` naming each sheet's keys in order. The agent views every sheet and each flagged
picture at full size and records a verdict per flag.
"""

import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import html
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import tempfile

import snapshot_fetch
import snapshot_matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCES = ROOT / 'AppPackage/Sources'
PARSER_FIXTURES = SOURCES / 'TestingSupport/Resources/Parser'
VISUAL_FIXTURES = (SOURCES / 'VisualSnapshotSupport', ROOT / 'AppPackage/Tests/VisualSnapshotTests')
LANGUAGES = {'en': ['en-US'], 'de': ['de-DE', 'en-US'], 'ja': ['ja-JP', 'en-US'], 'ko': ['ko-KR', 'en-US'],
             'zh-Hans': ['zh-Hans', 'en-US'], 'zh-Hant': ['zh-Hant', 'en-US']}
CHECKS = ('unreadable', 'uniform', 'placeholder', 'size-outlier', 'committed-height', 'same-as',
          'same-in-both-themes', 'truncated', 'untranslated', 'real-content')
SHEET_SIZE = 16
UNIFORM_DEVIATION = 2.0
UNIFORM_SHARE = 0.995
OUTLIER_LOW, OUTLIER_HIGH = 0.5, 2.0
PLACEHOLDER_SHARE = 0.6
PLACEHOLDER_SIDE = 40
PLACEHOLDER_ASPECT = (0.4, 2.5)
MARKER_LENGTH = 12
SWIFT_STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
FIXTURE_TITLE = re.compile(r'<(?:div class="glink"|h1 id="g[nj]")>(.*?)</(?:div|h1)>', re.S)


def build(source, directory):
    """Compiles a Swift tool of this directory into `directory`; returns the binary."""
    binary = directory / source.stem
    if not binary.exists() or binary.stat().st_mtime < source.stat().st_mtime:
        subprocess.run(['swiftc', '-O', '-o', str(binary), str(source)], check=True)
    return binary


def pictures_of(root):
    """`{key: path}` of every picture in the layout; a file outside it is an error."""
    found = {}
    for path in sorted(root.rglob('*.png')):
        relative = path.relative_to(root).as_posix()
        key = snapshot_fetch.path_key(relative)
        if key == relative:
            raise ValueError(f'{relative}: not a baseline path')
        found[key] = path
    return found


def axes(key):
    scenario, locale, size, orientation, family, theme = key.split('__')
    return {'scenario': scenario, 'locale': locale, 'size': size, 'orientation': orientation, 'family': family,
            'theme': theme}


def probe(pictures, digests, cache_path, binary, workers):
    """`{key: probe}`, reading only pictures whose digest the cache does not hold."""
    cache = {}
    if cache_path.is_file():
        for text in cache_path.read_text().splitlines():
            entry = json.loads(text)
            cache[entry['sha256']] = entry
    missing = [key for key in pictures if digests[key] not in cache]
    chunks = [missing[index::workers] for index in range(workers)]

    def run(chunk):
        if not chunk:
            return []
        requests = ''.join(json.dumps({'path': str(pictures[key]), 'languages': LANGUAGES[axes(key)['locale']]})
                           + '\n' for key in chunk)
        output = subprocess.run([str(binary)], input=requests, capture_output=True, text=True, check=True).stdout
        results = [json.loads(line) for line in output.splitlines() if line.strip()]
        if len(results) != len(chunk):
            raise RuntimeError(f'the probe answered {len(results)} of {len(chunk)} pictures')
        return [{**result, 'sha256': digests[key]} for key, result in zip(chunk, results)]

    with ThreadPoolExecutor(max_workers=workers) as pool:
        for results in pool.map(run, chunks):
            for result in results:
                cache[result['sha256']] = result
    with cache_path.open('w') as handle:
        for entry in cache.values():
            handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + '\n')
    return {key: cache[digests[key]] for key in pictures}


def catalog_strings(sources=SOURCES):
    """`{locale: {value}}` of every plain catalog string, and the English values each locale translates."""
    values, translated = defaultdict(set), defaultdict(set)
    for catalog in sorted(sources.rglob('*.xcstrings')):
        document = json.loads(catalog.read_text())
        for entry in document.get('strings', {}).values():
            units = {locale: localization.get('stringUnit', {}).get('value')
                     for locale, localization in entry.get('localizations', {}).items()}
            for locale, value in units.items():
                if value:
                    values[locale].add(normalize(value))
            english = units.get('en')
            if not english or '%' in english:
                continue
            for locale, value in units.items():
                if locale != 'en' and value and normalize(value) != normalize(english):
                    translated[locale].add(normalize(english))
    return values, translated


def fixture_markers(directory=PARSER_FIXTURES):
    """Gallery titles of the real site pages kept as parser fixtures, case-folded."""
    markers = set()
    for page in sorted(directory.rglob('*.html')):
        for match in FIXTURE_TITLE.finditer(page.read_text(errors='replace')):
            title = normalize(html.unescape(re.sub(r'<[^>]+>', '', match.group(1))))
            if len(title) >= MARKER_LENGTH:
                markers.add(title.casefold())
    return markers


def fixture_strings(directories=VISUAL_FIXTURES):
    """The synthetic fixtures' string literals, case-folded, each interpolation splitting a literal in parts."""
    parts = set()
    for directory in directories:
        for source in sorted(directory.rglob('*.swift')):
            for literal in SWIFT_STRING.findall(source.read_text()):
                parts.update(normalize(part).casefold() for part in re.split(r'\\\(.*?\)', literal) if part.strip())
    return parts


def normalize(text):
    return ' '.join(text.split())


def expected_pixels(heights, env):
    """`{(scenario, family, orientation, size): (width, height)}` in pixels: the pinned width and the committed height
    of each coordinate, from the exported heights (`snapshot_heights.py export`) and the rendering pins."""
    width = {(family, orientation): int(env['devices'][family]['orientations'][orientation]['points'][0])
             for family in env['devices'] for orientation in env['devices'][family]['orientations']}
    return {(scenario, family, orientation, size): (width[(family, orientation)], value)
            for scenario, families in heights.items()
            for family, orientations in families.items()
            for orientation, sizes in orientations.items()
            for size, value in sizes.items()}


def check(pictures, probes, digests, sizes, strings, markers, fixtures=frozenset(), expected=None):
    """`{key: [(check, detail)]}` for every flagged picture; `expected` (``expected_pixels``) turns on
    `committed-height`."""
    values, translated = strings
    flags = defaultdict(list)
    for key, result in probes.items():
        if 'error' in result:
            flags[key].append(('unreadable', result['error']))
            continue
        coordinate = axes(key)
        if expected is not None:
            want = expected.get(tuple(coordinate[axis] for axis in ('scenario', 'family', 'orientation', 'size')))
            got = (result['width'], result['height'])
            if want is None:
                flags[key].append(('committed-height', 'no committed height for this scenario'))
            elif got != want:
                flags[key].append(('committed-height', f'{got[0]}x{got[1]} px, expected {want[0]}x{want[1]}'))
        if result['lumaDeviation'] < UNIFORM_DEVIATION or result['dominantShare'] > UNIFORM_SHARE:
            flags[key].append(('uniform', f"deviation {result['lumaDeviation']:.2f}, "
                                          f"one colour {result['dominantShare']:.1%}"))
        gray = [rect for rect in result['grayRectangles'] if rect['color'].endswith(coordinate['theme'])
                and min(rect['width'], rect['height']) >= PLACEHOLDER_SIDE
                and PLACEHOLDER_ASPECT[0] <= rect['width'] / rect['height'] <= PLACEHOLDER_ASPECT[1]
                and rect['width'] <= PLACEHOLDER_SHARE * result['width']
                and rect['height'] <= PLACEHOLDER_SHARE * result['height']]
        if gray:
            boxes = ', '.join(f"{rect['width']}x{rect['height']} at {rect['x']},{rect['y']}" for rect in gray[:3])
            flags[key].append(('placeholder', boxes))
        own = values[coordinate['locale']] | values['en']
        for line in result['lines']:
            text = normalize(line['text'])
            if '…' in text and text not in own:
                flags[key].append(('truncated', text))
            if coordinate['locale'] != 'en' and text in translated[coordinate['locale']] \
                    and text not in values[coordinate['locale']] \
                    and not any(text.casefold() in literal for literal in fixtures):
                flags[key].append(('untranslated', text))
            folded = text.casefold()
            if len(folded) >= MARKER_LENGTH and any(folded in marker or marker in folded for marker in markers):
                flags[key].append(('real-content', text))
    groups = defaultdict(list)
    for key in pictures:
        coordinate = axes(key)
        groups[tuple(coordinate[axis] for axis in ('scenario', 'family', 'orientation', 'size', 'theme'))].append(key)
    for members in groups.values():
        if len(members) < 4:
            continue
        median = statistics.median(sizes[key] for key in members)
        for key in members:
            if not OUTLIER_LOW * median <= sizes[key] <= OUTLIER_HIGH * median:
                flags[key].append(('size-outlier', f'{sizes[key]} bytes, median {median:.0f} of {len(members)}'))
    by_coordinate = defaultdict(lambda: defaultdict(list))
    by_theme = defaultdict(dict)
    for key in pictures:
        coordinate = axes(key)
        rest = tuple(coordinate[axis] for axis in ('locale', 'size', 'orientation', 'family', 'theme'))
        by_coordinate[rest][digests[key]].append(coordinate['scenario'])
        others = tuple(coordinate[axis] for axis in ('scenario', 'locale', 'size', 'orientation', 'family'))
        by_theme[others][coordinate['theme']] = key
    for rest, digest_groups in by_coordinate.items():
        for scenarios in digest_groups.values():
            for scenario in scenarios if len(scenarios) > 1 else ():
                key = '__'.join((scenario, rest[0], rest[1], rest[2], rest[3], rest[4]))
                flags[key].append(('same-as', ', '.join(sorted(set(scenarios) - {scenario}))))
    for themes in by_theme.values():
        if len(themes) == 2 and digests[themes['light']] == digests[themes['dark']]:
            for key in themes.values():
                flags[key].append(('same-in-both-themes', 'light and dark pictures are identical'))
    return {key: sorted(set(entries)) for key, entries in flags.items()}


def sheet_order(key):
    coordinate = axes(key)
    return (coordinate['family'], coordinate['locale'], coordinate['size'], coordinate['scenario'],
            coordinate['orientation'], coordinate['theme'])


def sheet_plan(keys):
    """`{sheet name: [keys]}`: 16 pictures a sheet, in slice and scenario order."""
    ordered = sorted(keys, key=sheet_order)
    return {f'sheet-{number:04d}.png': ordered[start:start + SHEET_SIZE]
            for number, start in enumerate(range(0, len(ordered), SHEET_SIZE), start=1)}


def tile_label(index, key):
    """The tile's number and screen on the first line, its slice on the second."""
    coordinate = axes(key)
    return (f"{index} {coordinate['scenario']} {coordinate['orientation']}-{coordinate['theme']}\n"
            f"{coordinate['family']}/{coordinate['locale']}/{coordinate['size']}")


def write_sheets(pictures, directory, binary):
    """Draws every sheet of `sheet_plan`; returns the plan, also written as `sheets.json`."""
    directory.mkdir(parents=True, exist_ok=True)
    sheets = sheet_plan(pictures)
    requests = [{'out': str(directory / name), 'columns': 4, 'tile': 400,
                 'tiles': [{'path': str(pictures[key]), 'label': tile_label(index, key)}
                           for index, key in enumerate(keys, start=1)]}
                for name, keys in sheets.items()]
    workers = max(1, (os.cpu_count() or 2) // 2)
    chunks = [requests[index::workers] for index in range(workers)]

    def run(chunk):
        if not chunk:
            return []
        lines = ''.join(json.dumps(request) + '\n' for request in chunk)
        return subprocess.run([str(binary)], input=lines, capture_output=True, text=True, check=True).stdout.split('\n')

    with ThreadPoolExecutor(max_workers=workers) as pool:
        errors = [line for output in pool.map(run, chunks) for line in output if line.startswith('error')]
    if errors:
        raise RuntimeError('\n'.join(errors[:20]))
    (directory / 'sheets.json').write_text(json.dumps(sheets, indent=2) + '\n')
    return sheets


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--set', type=Path, required=True)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--sheets', type=Path)
    parser.add_argument('--workers', type=int, default=max(1, (os.cpu_count() or 2) // 2))
    parser.add_argument('--heights', type=Path, help='the committed heights (snapshot_heights.py export): '
                        'check each picture against its coordinate\'s pinned width and committed height')
    parser.add_argument('--build', type=Path, help='where to compile the Swift tools (default: a temporary directory)')
    args = parser.parse_args(argv)
    root = args.set / 'pictures'
    pictures = pictures_of(root)
    if not pictures:
        parser.error(f'{root}: no pictures')
    digests, sizes = {}, {}
    for key, path in pictures.items():
        data = path.read_bytes()
        digests[key], sizes[key] = hashlib.sha256(data).hexdigest(), len(data)
    with tempfile.TemporaryDirectory() as scratch:
        build_directory = args.build or Path(scratch)
        build_directory.mkdir(parents=True, exist_ok=True)
        probes = probe(pictures, digests, args.set / 'probe.jsonl', build(HERE / 'picture-probe.swift',
                                                                            build_directory), args.workers)
        expected = None
        if args.heights:
            _, env = snapshot_matrix.load()
            expected = expected_pixels(json.loads(args.heights.read_text()), env)
        flags = check(pictures, probes, digests, sizes, catalog_strings(), fixture_markers(), fixture_strings(),
                      expected)
        if args.sheets:
            sheets = write_sheets(pictures, args.sheets, build(HERE / 'contact-sheet.swift', build_directory))
            print(f'{len(sheets)} contact sheets in {args.sheets}')
    by_check = {name: sorted(key for key, entries in flags.items() if any(entry[0] == name for entry in entries))
                for name in CHECKS}
    out = args.out or args.set / 'flags.json'
    out.write_text(json.dumps({key: '; '.join(f'{name}: {detail}' for name, detail in entries)
                               for key, entries in sorted(flags.items())}, indent=2, ensure_ascii=False) + '\n')
    (args.set / 'checks.json').write_text(json.dumps(by_check, indent=2) + '\n')
    print(f'{len(pictures)} pictures, {len(flags)} flagged')
    for name in CHECKS:
        print(f'  {name}: {len(by_check[name])}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
