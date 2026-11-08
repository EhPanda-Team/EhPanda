#!/usr/bin/env python3
"""A static offline report of a snapshot gate run, or the owner's short review packet (19-CONTEXT D-17, D-18).

The report reads `aggregate.json` from `snapshot_aggregate.py`. It shows every failing coordinate with its baseline,
actual and difference side by side, grouped by the inventory's group and then by scenario, with filters for language,
text size, device, orientation and appearance. A candidate run's report shows every recorded picture for the agents'
pre-check. `--packet` keeps one picture per scenario (the `en-large` iPhone portrait light coordinate, or the first
one captured in axis order) plus every flagged key. Both list the not-applicable rules with their reasons and the
flake log.

`--pictures` is the baseline slice the shards compared against (`<family>/<locale>/<size>/<scenario>/...`); actual,
difference and candidate pictures come from the shard directories that `aggregate.json` names. Only the pictures
shown are copied, into `<out>/img/`. The page loads nothing from the network: no stylesheet, script, font or image
leaves the report directory.
"""

import argparse
import html
import json
from pathlib import Path
import shutil
import sys

import snapshot_aggregate
import snapshot_matrix

AXES = (('locale', 'Language', snapshot_matrix.LOCALES), ('size', 'Text size', snapshot_matrix.SIZES),
        ('device', 'Device', snapshot_matrix.FAMILIES), ('orientation', 'Orientation', snapshot_matrix.ORIENTATIONS),
        ('appearance', 'Appearance', snapshot_matrix.THEMES))
FAILING = ('changed', 'missing-baseline', 'timeout', 'error')
PICTURED = ('recorded', 'changed', 'missing-baseline')
STYLE = '''
body { font: 14px -apple-system, system-ui, sans-serif; margin: 24px; color: #1d1d1f; background: #fff; }
h1 { font-size: 22px; } h2 { font-size: 18px; margin-top: 32px; } h3 { font-size: 15px; margin: 20px 0 6px; }
table { border-collapse: collapse; } td, th { border: 1px solid #d2d2d7; padding: 4px 8px; text-align: left; }
.filters { position: sticky; top: 0; background: #fff; padding: 8px 0; border-bottom: 1px solid #d2d2d7; }
.filters label { margin-right: 16px; }
.row { margin: 8px 0 16px; } .row code { font-size: 12px; }
.pictures { display: flex; gap: 12px; align-items: flex-start; flex-wrap: wrap; }
figure { margin: 0; } figcaption { font-size: 12px; color: #6e6e73; }
img { width: 240px; border: 1px solid #d2d2d7; } .absent { width: 240px; color: #6e6e73; font-style: italic; }
.note { color: #b3261e; } .status { font-weight: 600; }
'''
SCRIPT = '''
function applyFilters() {
  const chosen = {};
  document.querySelectorAll('select[data-axis]').forEach(select => { chosen[select.dataset.axis] = select.value; });
  document.querySelectorAll('.row[data-key]').forEach(row => {
    row.hidden = Object.entries(chosen).some(([axis, value]) => value !== '' && row.dataset[axis] !== value);
  });
}
document.querySelectorAll('select[data-axis]').forEach(select => select.addEventListener('change', applyFilters));
'''


def parse_key(key):
    """`{scenario, locale, size, orientation, device, appearance}` of a coordinate key."""
    scenario, locale, size, orientation, family, theme = key.split('__')
    return {'scenario': scenario, 'locale': locale, 'size': size, 'orientation': orientation, 'device': family,
            'appearance': theme}


def relative_path(key):
    return snapshot_matrix.Coordinate(*key.split('__')).baseline_path


def packet_keys(document, flags):
    """One key per scenario, the default coordinate first, then the flagged keys not chosen already."""
    pictured = {row['key'] for row in document['results'] if row['status'] in PICTURED}
    chosen = []
    for scenario in sorted(document['scenarios']):
        order = [row.key for row in snapshot_matrix.scenario_coordinates(scenario)]
        default = f'{scenario}__en__large__portrait__iphone__light'
        pick = default if default in pictured else next((key for key in order if key in pictured), None)
        if pick:
            chosen.append(pick)
    return chosen + sorted(key for key in flags if key not in chosen)


def report_keys(document, flags, packet):
    if packet:
        return packet_keys(document, flags)
    shown = {row['key'] for row in document['results'] if row['status'] in FAILING + ('recorded',)}
    shown |= {item['key'] for items in document['items'].values() for item in items if item.get('key')}
    return sorted(shown | set(flags))


class Pictures:
    """Copies a coordinate's pictures into `<out>/img/<kind>/` and returns their paths relative to the report."""

    def __init__(self, document, baseline, out):
        self.shards = {shard: Path(row['directory']) for shard, row in document['shards'].items()}
        self.baseline, self.out = baseline, out

    def copy(self, source, kind, path):
        if source is None or not source.is_file():
            return None
        target = self.out / 'img' / kind / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        return f'img/{kind}/{path}'

    def for_row(self, key, row):
        """`[(caption, relative path or None)]`: the candidate alone, or baseline, actual and difference."""
        path = relative_path(key)
        shard = self.shards.get(row['shard']) if row else None
        if row and row['status'] == 'recorded':
            return [('Candidate', self.copy(shard / path, 'candidate', path))]
        baseline = self.copy(self.baseline / path if self.baseline else None, 'baseline', path)
        actual = self.copy(shard / 'actual' / path if shard else None, 'actual', path)
        difference = self.copy(shard / 'difference' / path if shard else None, 'difference', path)
        return [('Baseline', baseline), ('Actual', actual), ('Difference', difference)]


def figure(caption, source):
    body = (f'<img src="{html.escape(source)}" alt="{html.escape(caption)}" loading="lazy">' if source
            else '<div class="absent">no picture</div>')
    return f'<figure>{body}<figcaption>{html.escape(caption)}</figcaption></figure>'


def row_html(key, row, note, pictures):
    axes = parse_key(key)
    data = ' '.join(f'data-{axis}="{html.escape(axes[axis])}"' for axis, _, _ in AXES)
    status = row['status'] if row else 'no result'
    parts = [f'<div class="row" data-key="{html.escape(key)}" {data}>',
             f'<div><code>{html.escape(key)}</code> <span class="status">{html.escape(status)}</span>']
    if row and row.get('reason'):
        parts.append(f' — {html.escape(row["reason"])}')
    if note:
        parts.append(f' <span class="note">Flagged: {html.escape(note)}</span>')
    parts.append('</div><div class="pictures">')
    parts += [figure(caption, source) for caption, source in pictures.for_row(key, row)]
    parts.append('</div></div>')
    return ''.join(parts)


def filters_html():
    parts = ['<div class="filters">']
    for axis, label, values in AXES:
        options = ''.join(f'<option value="{html.escape(value)}">{html.escape(value)}</option>' for value in values)
        parts.append(f'<label>{label} <select data-axis="{axis}"><option value="">All</option>{options}</select>'
                     '</label>')
    parts.append('</div>')
    return ''.join(parts)


def header_html(document, packet):
    environment = document['environment']
    devices = ', '.join(f'{family}: {model}' for family, model in environment['devices'].items())
    counts = ', '.join(f"{document['counts'][name]} {label}" for name, label in snapshot_aggregate.CLASSES)
    statuses = ', '.join(f'{status} {count}' for status, count in document['statusCounts'].items()) or 'none'
    title = 'Snapshot review packet' if packet else 'Snapshot report'
    return (f'<h1>{title}</h1><p>{html.escape(environment["xcode"])}; iOS {html.escape(environment["runtime"])} '
            f'({html.escape(environment["runtimeBuild"])}); {html.escape(devices)}.</p>'
            f'<p>{html.escape(counts)}. Results: {html.escape(statuses)}. Shards: {len(document["shards"])}.</p>')


def problems_html(document):
    entries = [(label, item) for name, label in snapshot_aggregate.CLASSES if name != 'pictureChanges'
               for item in document['items'][name]]
    if not entries:
        return ''
    rows = ''.join(f'<tr><td>{html.escape(label)}</td><td>{html.escape(item["shard"])}</td>'
                   f'<td>{html.escape(item["kind"])}</td><td><code>{html.escape(item.get("key", ""))}</code></td>'
                   f'<td>{html.escape(item.get("detail", ""))}</td></tr>' for label, item in entries)
    return ('<h2>Infrastructure, drift and baseline problems</h2><table><tr><th>Class</th><th>Shard</th>'
            f'<th>Kind</th><th>Coordinate</th><th>Detail</th></tr>{rows}</table>')


def not_applicable_html(document):
    rows = ''.join(
        f'<tr><td>{html.escape(scenario)}</td><td>'
        f'{html.escape(", ".join(f"{axis}={value}" for axis, value in rule["when"].items()))}</td>'
        f'<td>{html.escape(rule["reason"])}</td></tr>'
        for scenario, entry in sorted(document['scenarios'].items()) for rule in entry['notApplicable'])
    body = (f'<table><tr><th>Scenario</th><th>When</th><th>Reason</th></tr>{rows}</table>' if rows
            else '<p>None.</p>')
    return f'<h2>Not applicable</h2>{body}'


def flake_html(document):
    rows = ''.join(f'<tr><td><code>{html.escape(row["key"])}</code></td><td>{row["seconds"]:.2f}</td>'
                   f'<td>{row["attempts"]}</td><td>{html.escape(row["shard"])}</td></tr>'
                   for row in document['flaky'])
    body = (f'<table><tr><th>Coordinate</th><th>Seconds</th><th>Attempts</th><th>Shard</th></tr>{rows}</table>'
            if rows else '<p>None.</p>')
    return f'<h2>Flake log (passed only on a retry)</h2>{body}'


def render(document, baseline, out, packet=False, flags=None):
    """Writes `<out>/index.html` and the pictures it shows; returns the keys shown, in page order."""
    flags = flags or {}
    results = {row['key']: row for row in document['results']}
    pictures = Pictures(document, baseline, out)
    keys = report_keys(document, flags, packet)
    by_scenario = {}
    for key in keys:
        by_scenario.setdefault(parse_key(key)['scenario'], []).append(key)
    groups = {}
    for scenario in by_scenario:
        group = document['scenarios'].get(scenario, {}).get('group', 'unknown')
        groups.setdefault(group, []).append(scenario)
    sections, shown = [], []
    for group in sorted(groups):
        sections.append(f'<h2>{html.escape(group)}</h2>')
        for scenario in sorted(groups[group]):
            state = document['scenarios'].get(scenario, {}).get('state', '')
            sections.append(f'<h3>{html.escape(scenario)} <small>{html.escape(state)}</small></h3>')
            for key in by_scenario[scenario]:
                sections.append(row_html(key, results.get(key), flags.get(key), pictures))
                shown.append(key)
    if not keys:
        sections.append('<p>No picture to review.</p>')
    page = ('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            f'<title>{"Snapshot review packet" if packet else "Snapshot report"}</title>'
            f'<style>{STYLE}</style></head><body>{header_html(document, packet)}{filters_html()}'
            f'{"".join(sections)}{problems_html(document)}{not_applicable_html(document)}{flake_html(document)}'
            f'<script>{SCRIPT}</script></body></html>\n')
    out.mkdir(parents=True, exist_ok=True)
    (out / 'index.html').write_text(page)
    return shown


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--aggregate', type=Path, required=True, help="snapshot_aggregate.py's aggregate.json")
    parser.add_argument('--pictures', type=Path, help='the baseline slice root the shards compared against')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--packet', action='store_true', help="the owner's short packet: one picture per scenario")
    parser.add_argument('--flags', type=Path, help='the pre-check flags, {key: note}')
    args = parser.parse_args(argv)
    document = json.loads(args.aggregate.read_text())
    flags = json.loads(args.flags.read_text()) if args.flags else {}
    shown = render(document, args.pictures, args.out, args.packet, flags)
    print(f'{args.out / "index.html"}: {len(shown)} coordinates')
    return 0


if __name__ == '__main__':
    sys.exit(main())
