#!/usr/bin/env python3
"""Review a published real marketing fixture: every visible gallery, page and comment, and its scene composition.

The ledger traces each planned gallery occurrence, by content set and screen, to the active selection and its
saved source. Composition checks apply to the proposed populated marketing scenes, not to the app in general.
The review approves nothing: final owner selections remain a named Phase 17 closure checkpoint.
"""
import argparse
import html
import json
import os
from pathlib import Path
import re
import sys

import fixtures

# Owner decision, 2026-10-13: Home's Frontpage shows five pairs.
FRONTPAGE_COUNT = 10
CLOSURE = ('Phase 17 closure (17-21): the owner confirms final gallery identifiers, set assignments, Home slots, '
           'flow pages and downloads for both sets (selectionStatus final, selectionAuthority owner); affected '
           'captures are then regenerated and revalidated.')


def comments(document):
    """Saved comments as Parser.parseComments reads them: id, author, posted time and text."""
    container = document.first('div', id='cdiv')
    if container is None:
        return []
    rows = []
    for block in [node for node in container.walk() if node.attributes.get('class') == 'c1']:
        header = ' '.join(fixtures.text_of(block.first('div', **{'class': 'c3'})).split())
        body = next((node for node in block.walk() if node.tag == 'div' and node.attributes.get('class') == 'c6'
                     and node.attributes.get('id', '').startswith('comment_')), None)
        posted = re.fullmatch(r'Posted on (.+?) by: ?(.*)', header)
        if body is None or posted is None:
            continue
        rows.append({'commentID': body.attributes['id'].removeprefix('comment_'), 'author': posted[2],
                     'posted': posted[1], 'text': body.text().strip()})
    return rows


def language(document):
    """The language the detail page's Language row names, and whether the row marks the gallery as a translation."""
    gdd = document.first('div', id='gdd') or fixtures.Node('div', {})
    row = next((row for row in gdd.walk() if row.tag == 'tr'
                and fixtures.text_of(row.first('td', **{'class': 'gdt1'})).strip() == 'Language:'), None)
    cell = row.first('td', **{'class': 'gdt2'}) if row else None
    if cell is None:
        return {'name': None, 'translated': False}
    marker = cell.first('span', **{'class': 'halp'})
    return {'name': next(iter(fixtures.text_of(cell).split()), None),
            'translated': fixtures.text_of(marker).strip() == 'TR'}


def gallery_records(directory, manifest, selection):
    """Title, language, page count, cover and comments of every declared gallery, read from its saved detail page."""
    entries = {(entry['kind'], entry['gid'], entry['index']): entry for entry in manifest['assets']}
    records = {}
    for gallery in selection['galleries']:
        gid = fixtures.GALLERY_URL.fullmatch(gallery['url'])[1]
        text = (directory / entries['detail', gid, None]['path']).read_text()
        document = fixtures.parse_html(text)
        records[gid] = {'gid': gid, 'url': gallery['url'], 'set': gallery['set'],
                        'title': fixtures.text_of(document.first('h1', id='gn')).strip(),
                        'language': language(document),
                        'pageCount': fixtures.parse_detail(text)['pageCount'],
                        'cover': entries['cover', gid, None]['path'], 'comments': comments(document)}
    return records, entries


def composition_problems(scene, records):
    """Faults that keep a scene from populating the proposed marketing composition, in a fixed order."""
    problems = []
    hero = scene['home']['hero']
    if len(hero['galleries']) < 3 or not 0 < hero['selectedIndex'] < len(hero['galleries']) - 1:
        problems.append('home hero needs at least three galleries with a neighbor on each side of selectedIndex')
    frontpage = scene['home']['frontpage']
    if len(frontpage) != FRONTPAGE_COUNT:
        problems.append(f'home frontpage needs exactly {FRONTPAGE_COUNT} galleries; it has {len(frontpage)}')
    for period in fixtures.TOPLISTS:
        if len(scene['home']['toplists'][period]) < 3:
            problems.append(f'home toplists {period} needs at least three galleries; it has '
                            f'{len(scene["home"]["toplists"][period])}')
    flow = scene['flow']
    if not any(comment['text'] for comment in records[flow['gallery']]['comments']):
        problems.append(f'comments gallery {flow["gallery"]} has no readable saved comment')
    live_text = scene['liveText']['gallery']
    if live_text == flow['gallery']:
        problems.append(f'Live Text gallery {live_text} must be another gallery than the flow gallery')
    if records[live_text]['language'] != {'name': 'English', 'translated': False}:
        problems.append(f'Live Text gallery {live_text} must be an English original, not '
                        + describe_language(records[live_text]['language']))
    downloads = scene['downloads']
    if len(downloads) < 2:
        problems.append(f'downloads needs at least two items; it has {len(downloads)}')
    priorities = [fixtures.DOWNLOAD_STATUSES[entry['status']] for entry in downloads]
    if priorities != sorted(priorities):
        problems.append('downloads order is not a display order: the app lists statuses by priority, so it would '
                        'reorder ' + ', '.join(entry['status'] for entry in downloads))
    return problems


def describe_language(value):
    name = value['name'] or 'an unnamed language'
    return f'a translation into {name}' if value['translated'] else name


def reader_pages(reader, entries):
    return [{'page': page, 'image': entries['page', reader['gallery'], page]['path'],
             'url': entries['page', reader['gallery'], page]['url']} for page in reader['pages']]


def scene_ledger(name, scene, records, entries):
    flow, live_text = scene['flow'], scene['liveText']
    occurrences = {screen: [{'section': section, 'slot': slot, 'gid': gid, 'title': records[gid]['title'],
                             'url': records[gid]['url'], 'cover': records[gid]['cover']}
                            for section, slot, gid in rows]
                   for screen, rows in fixtures.screen_occurrences(scene, name).items()}
    home = scene['home']
    return {
        'screens': occurrences,
        'home': {'hero': {'galleries': home['hero']['galleries'], 'selectedIndex': home['hero']['selectedIndex']},
                 'frontpagePairs': [home['frontpage'][start:start + 2]
                                    for start in range(0, len(home['frontpage']), 2)],
                 'toplists': {period: [{'ranking': ranking, 'gid': gid}
                                       for ranking, gid in enumerate(home['toplists'][period], 1)]
                              for period in fixtures.TOPLISTS}},
        'flow': {'gallery': flow['gallery'], 'readerPage': flow['readerPage'], 'pages': reader_pages(flow, entries)},
        'liveText': {'gallery': live_text['gallery'], 'page': live_text['page'],
                     'language': records[live_text['gallery']]['language'],
                     'pages': reader_pages(live_text, entries)},
        'comments': records[flow['gallery']]['comments'],
        'downloads': [dict(entry, slot=slot, pageCount=records[entry['gallery']]['pageCount'],
                           displayPriority=fixtures.DOWNLOAD_STATUSES[entry['status']])
                      for slot, entry in enumerate(scene['downloads'])],
        'problems': composition_problems(scene, records),
    }


def unresolved(selection):
    inputs = [f'{name}: no scene declared (galleries, Home slots, flow and Live Text galleries and pages, downloads)'
              for name in fixtures.SETS if name not in selection['scenes']]
    if (selection['selectionStatus'], selection['selectionAuthority']) != ('final', 'owner'):
        inputs.append(f'final selection: the active selection is {selection["selectionStatus"]} with '
                      f'{selection["selectionAuthority"]} authority; closure needs a final owner selection')
    return inputs


def review(path):
    """The deterministic review ledger of the one fixture version `path` resolves to; integrity failures raise first."""
    directory = fixtures.resolve_fixtures(path)
    manifest = fixtures.validate_fixtures(directory)
    selection = json.loads((directory / 'selection.json').read_text())
    records, entries = gallery_records(directory, manifest, selection)
    scenes = {name: scene_ledger(name, selection['scenes'][name], records, entries)
              for name in fixtures.SETS if name in selection['scenes']}
    return {
        'schemaVersion': 1,
        'fixture': {key: manifest[key] for key in ('fixtureVersion', 'aggregateDigest', 'acquiredAt')},
        'selection': {key: selection[key] for key in ('selectionID', 'selectionStatus', 'selectionAuthority')},
        'galleries': [{key: records[gid][key] for key in ('gid', 'url', 'set', 'title', 'language', 'pageCount',
                                                          'cover')}
                      for gid in records],
        'sets': scenes,
        'valid': not any(scene['problems'] for scene in scenes.values()),
        'unresolvedInputs': unresolved(selection),
        'closureCheckpoint': CLOSURE,
        'approval': 'none: this review records provisional content and approves no marketing asset',
    }


FLOW_SCREENS = ('detail', 'comments', 'reading')


def contact_sheet(ledger, fixture_root):
    """An offline page for visual review; images are referenced in place, never copied out of the fixture."""
    escape = html.escape

    def image(path, label):
        return (f'<figure><img src="{escape(f"{fixture_root}/{path}")}" alt="{escape(label)}" loading="lazy">'
                f'<figcaption>{escape(label)}</figcaption></figure>')

    def page_label(page, shown, role):
        return f'page {page["page"]}' + (f' ({role})' if page['page'] == shown else '')
    selection = ledger['selection']
    parts = ['<!doctype html><meta charset="utf-8"><title>Marketing selection review</title>',
             '<style>:root{color-scheme:light dark}body{font:14px system-ui;margin:16px}'
             'figure{display:inline-block;width:160px;margin:4px;vertical-align:top}img{width:160px}'
             'figcaption{font-size:12px}.problem{color:#d33}</style>',
             f'<h1>{escape(selection["selectionID"])} ({escape(ledger["fixture"]["fixtureVersion"])})</h1>',
             f'<p>Status {escape(selection["selectionStatus"])}, authority {escape(selection["selectionAuthority"])}. '
             f'Approval {escape(ledger["approval"])}.</p>']
    for name, scene in ledger['sets'].items():
        parts.append(f'<h2>{escape(name)}</h2>')
        parts += [f'<p class="problem">{escape(problem)}</p>' for problem in scene['problems']]
        parts.append('<h3>home</h3>')
        parts += [image(row['cover'], f'{row["section"]}[{row["slot"]}] {row["gid"]} {row["title"]}')
                  for row in scene['screens']['home']]
        flow = scene['screens']['detail'][0]
        parts.append(f'<h3>{escape(", ".join(FLOW_SCREENS))}</h3>')
        parts.append(image(flow['cover'], f'{flow["gid"]} {flow["title"]}'))
        parts += [image(page['image'], page_label(page, scene['flow']['readerPage'], 'reader'))
                  for page in scene['flow']['pages']]
        parts += [f'<p><b>{escape(comment["author"])}</b> {escape(comment["posted"])}<br>{escape(comment["text"])}</p>'
                  for comment in scene['comments']]
        live_text = scene['screens']['reading-live-text'][0]
        parts.append('<h3>reading-live-text</h3>')
        parts.append(image(live_text['cover'], f'{live_text["gid"]} {live_text["title"]} '
                                               f'({describe_language(scene["liveText"]["language"])})'))
        parts += [image(page['image'], page_label(page, scene['liveText']['page'], 'Live Text'))
                  for page in scene['liveText']['pages']]
        parts.append('<h3>downloads</h3>')
        for row, entry in zip(scene['screens']['downloads'], scene['downloads']):
            progress = entry.get('completedPages', entry['pageCount'])
            parts.append(image(row['cover'], f'downloads[{row["slot"]}] {row["gid"]} {entry["status"]} '
                                             f'{progress}/{entry["pageCount"]} {row["title"]}'))
    parts.append('<h2>Unresolved final inputs</h2>')
    parts += [f'<p>{escape(item)}</p>' for item in ledger['unresolvedInputs']] + [f'<p>{escape(CLOSURE)}</p>']
    return '\n'.join(parts) + '\n'


def write(output, ledger, fixture_directory):
    output.mkdir(parents=True)
    # The ledger quotes real titles and comments, so its directory ignores itself like the fixtures it describes.
    (output / '.gitignore').write_text('*\n')
    (output / 'review.json').write_text(json.dumps(ledger, indent=2, sort_keys=True, ensure_ascii=False) + '\n')
    root = Path(os.path.relpath(fixture_directory, output)).as_posix()
    (output / 'review.html').write_text(contact_sheet(ledger, root))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', type=Path, required=True,
                        help='A fixture version directory or .capture/marketing/current')
    parser.add_argument('--output', type=Path, required=True, help='A new directory for review.json and review.html')
    arguments = parser.parse_args()
    try:
        if arguments.output.exists():
            raise ValueError(f'Output {arguments.output} already exists; use a new directory for each review')
        # The ledger and the contact sheet read the same version even if a publication moves `current` meanwhile.
        directory = fixtures.resolve_fixtures(arguments.fixtures)
        ledger = review(directory)
        write(arguments.output, ledger, directory)
    except (OSError, ValueError) as error:
        parser.exit(1, f'Selection review failed: {type(error).__name__}: {error}\n')
    for name, scene in ledger['sets'].items():
        for problem in scene['problems']:
            print(f'{name}: {problem}', file=sys.stderr)
    print(f'{"Valid" if ledger["valid"] else "Invalid"} composition: {arguments.output / "review.json"}')
    if not ledger['valid']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
