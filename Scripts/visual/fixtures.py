"""Real marketing fixture selection, scrubbing, derivation and atomic publication contracts.

A selection declares real galleries, their explicit content set and every scene slot. Acquisition
derives the required responses and images from the galleries' own pages, mirroring the app's request
builders and parsers, and validation repeats that derivation over the stored files. A later recording
adds what the app's own Live Text found on each flow's Live Text page.
"""
import fcntl
import hashlib
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import urlsplit

from contracts import ROOT, contained

SCHEMA_VERSION = 1
SETS = ('nonexplicit', 'explicit')
STATUSES = ('provisional', 'final')
AUTHORITIES = ('agent-delegated', 'owner')
TOPLISTS = ('yesterday', 'pastMonth', 'pastYear', 'allTime')
# DownloadDisplayStatus cases with their sortPriority. The two complete statuses carry no page progress.
DOWNLOAD_STATUSES = {'active': 0, 'queued': 1, 'updateAvailable': 2, 'error': 3, 'inactive': 4, 'completed': 5}
COMPLETE_DOWNLOADS = ('updateAvailable', 'completed')
# Setting.prefetchLimit's default: how many pages around a built page the reader resolves ahead of time.
PREFETCH_LIMIT = 10
SCREENS = ('home', 'detail', 'comments', 'filters', 'reading', 'reading-live-text', 'downloads', 'laboratory')
GALLERY_HOST = 'e-hentai.org'
IMAGE_HOSTS = frozenset({'ehgt.org', 'gt0.ehgt.org', 'gt1.ehgt.org', 'gt2.ehgt.org', 'gt3.ehgt.org', 'ul.ehgt.org'})
HATH_HOST = re.compile(r'(?:[a-z0-9]+\.)+hath\.network')
GALLERY_URL = re.compile(r'https://e-hentai\.org/g/([1-9][0-9]*)/([0-9a-f]{10})/')
PAGE_KINDS = ('detail', 'thumbnails', 'imagePage')
IMAGE_KINDS = ('cover', 'preview', 'page')
# Records are made rather than fetched, so they answer no replay URL: a Live Text record is what the app's own
# recognizer found on a flow's Live Text page, saved by record-live-text.py after acquisition.
RECORD_KINDS = ('liveText',)
RECORD_MEDIA = 'application/json'
MEDIA = {'image/jpeg': 'jpg', 'image/png': 'png', 'image/gif': 'gif', 'image/webp': 'webp'}
SIGNATURES = ((b'\xff\xd8\xff', 'image/jpeg'), (b'\x89PNG\r\n\x1a\n', 'image/png'), (b'GIF87a', 'image/gif'),
              (b'GIF89a', 'image/gif'))
GENERATORS = ('Scripts/visual/acquire-fixtures.py', 'Scripts/visual/fixtures.py', 'Scripts/visual/contracts.py',
              'Scripts/visual/record-live-text.py')
MANIFEST_KEYS = ('schemaVersion', 'purpose', 'fixtureVersion', 'aggregateDigest', 'selectionID', 'selectionStatus',
                 'selectionAuthority', 'selectionSHA256', 'generatorSources', 'acquiredAt', 'assets')
ENTRY_KEYS = ('kind', 'gid', 'index', 'url', 'path', 'mime', 'bytes', 'sha256', 'retrievedAt')
LIVE_TEXT_KEYS = ('schemaVersion', 'gid', 'page', 'pageSHA256', 'recognitionLanguages', 'recordedOn', 'groups')
CORNERS = ('topLeft', 'topRight', 'bottomLeft', 'bottomRight')
# Foundation's UUID encoding: uppercase hexadecimal in 8-4-4-4-12 groups.
UUID = re.compile(r'[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
# Values that grant access rather than identify content: the anonymous API key, the reader's show key, the
# signed image-server stamp and preview path key, the original-image key and the static-link token. Each is
# zeroed in place, keeping the response's shape, so a parsed URL and its stored response still agree.
SECRETS = (
    re.compile(r'(var\s+apikey\s*=\s*")([^"]*)(?=")'),
    re.compile(r'(var\s+showkey\s*=\s*")([^"]*)(?=")'),
    re.compile(r'(keystamp=)([0-9]+-[0-9a-f]+)'),
    re.compile(r'(\.hath\.network(?::[0-9]+)?/cm/)([0-9a-z]+)(?=/)'),
    re.compile(r'(fullimg\.php\?[^"\'\s<>]*?\bkey=)([0-9a-z]+)'),
    re.compile(r'(/fullimg/[0-9]+/[0-9]+/)([0-9a-z]+)(?=/)'),
    re.compile(r'(e-hentai\.org/r/[0-9a-z-]+/)([0-9a-z]+)(?=/)'),
)
# Account cookies or a signed-in API user; the lookahead's \s forces the whole gap to be consumed before -1 is tested.
SESSION = re.compile(r'ipb_member_id|ipb_pass_hash|igneous|var\s+apiuid\s*=\s*(?!\s|-1\s*;)')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def keys(value, expected, context):
    if not isinstance(value, dict) or set(value) != set(expected):
        raise ValueError(f'{context} must have exactly the keys {", ".join(sorted(expected))}')


def gallery_ids(value, context):
    if not isinstance(value, list) or not all(isinstance(gid, str) and gid for gid in value):
        raise ValueError(f'{context} must be a list of gallery IDs')
    return value


def counting(value):
    return type(value) is int and value >= 0


def current_schema(value):
    # JSON true equals 1 in Python, so the type is checked as well as the value.
    return type(value) is int and value == SCHEMA_VERSION


def screen_occurrences(scene, context='Scene'):
    """Every gallery occurrence of one content set's scene, by screen, as (section, slot, gid) in configured order."""
    keys(scene, ('home', 'flow', 'downloads'), context)
    home, flow, downloads = scene['home'], scene['flow'], scene['downloads']
    keys(home, ('hero', 'frontpage', 'toplists'), f'{context} home')
    keys(home['hero'], ('galleries', 'selectedIndex'), f'{context} home hero')
    keys(home['toplists'], TOPLISTS, f'{context} home toplists')
    hero = gallery_ids(home['hero']['galleries'], f'{context} home hero')
    if not counting(home['hero']['selectedIndex']) or home['hero']['selectedIndex'] >= len(hero):
        raise ValueError(f'{context} home hero selectedIndex must address one of its galleries')
    keys(flow, ('gallery', 'readerPage', 'liveTextPage', 'pages'), f'{context} flow')
    gallery_ids([flow['gallery']], f'{context} flow gallery')
    pages = flow['pages']
    if (not isinstance(pages, list) or not pages or not all(counting(page) and page > 0 for page in pages)
            or pages != sorted(set(pages))):
        raise ValueError(f'{context} flow pages must be ascending, unique page numbers from 1')
    for key in ('readerPage', 'liveTextPage'):
        if not counting(flow[key]) or flow[key] not in pages:
            raise ValueError(f'{context} flow {key} must be one of its pages')
    if not isinstance(downloads, list):
        raise ValueError(f'{context} downloads must be a list')
    for slot, entry in enumerate(downloads):
        where = f'{context} downloads[{slot}]'
        if (not isinstance(entry, dict) or not isinstance(entry.get('status'), str)
                or entry['status'] not in DOWNLOAD_STATUSES):
            raise ValueError(f'{where} status must be one of {", ".join(DOWNLOAD_STATUSES)}')
        complete = entry['status'] in COMPLETE_DOWNLOADS
        if complete and 'completedPages' in entry:
            raise ValueError(f'{where} is {entry["status"]}, which carries no completedPages')
        keys(entry, ('gallery', 'status') if complete else ('gallery', 'status', 'completedPages'), where)
        gallery_ids([entry['gallery']], f'{where} gallery')
        if not complete and not counting(entry['completedPages']):
            raise ValueError(f'{where} completedPages must be a page count')
    rows = {screen: [] for screen in SCREENS}
    rows['home'] = ([('hero', slot, gid) for slot, gid in enumerate(hero)]
                    + [('frontpage', slot, gid)
                       for slot, gid in enumerate(gallery_ids(home['frontpage'], f'{context} home frontpage'))]
                    + [(f'toplists.{period}', slot, gid) for period in TOPLISTS
                       for slot, gid in enumerate(gallery_ids(home['toplists'][period], f'{context} toplists'))])
    for screen in ('detail', 'comments', 'reading', 'reading-live-text'):
        rows[screen] = [('flow', 0, flow['gallery'])]
    rows['downloads'] = [('downloads', slot, entry['gallery']) for slot, entry in enumerate(downloads)]
    return rows


def validate_selection(selection):
    keys(selection, ('schemaVersion', 'selectionID', 'selectionStatus', 'selectionAuthority', 'galleries', 'scenes'),
         'Selection')
    if not current_schema(selection['schemaVersion']):
        raise ValueError(f'Selection schemaVersion must be {SCHEMA_VERSION}')
    if not isinstance(selection['selectionID'], str) or not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}',
                                                                         selection['selectionID']):
        raise ValueError('selectionID must be lowercase letters, digits and hyphens')
    if selection['selectionStatus'] not in STATUSES:
        raise ValueError(f'selectionStatus must be one of {", ".join(STATUSES)}')
    if selection['selectionAuthority'] not in AUTHORITIES:
        raise ValueError(f'selectionAuthority must be one of {", ".join(AUTHORITIES)}')
    if selection['selectionStatus'] == 'final' and selection['selectionAuthority'] != 'owner':
        raise ValueError('A final selection requires owner authority')
    galleries, scenes = selection['galleries'], selection['scenes']
    if not isinstance(galleries, list) or not galleries:
        raise ValueError('Empty selection: declare at least one gallery')
    if not isinstance(scenes, dict) or not scenes:
        raise ValueError('Empty selection: declare at least one content set scene')
    assigned = {}
    for gallery in galleries:
        keys(gallery, ('url', 'set'), 'Gallery')
        match = GALLERY_URL.fullmatch(gallery['url']) if isinstance(gallery['url'], str) else None
        if match is None:
            raise ValueError(f'Gallery URL must be https://e-hentai.org/g/<gid>/<token>/: {gallery["url"]!r}')
        if gallery['set'] not in SETS:
            raise ValueError(f'Gallery {match[1]} set must be one of {", ".join(SETS)}')
        if match[1] in assigned:
            raise ValueError(f'Gallery {match[1]} is declared twice')
        assigned[match[1]] = gallery['set']
    placed = set()
    for name, scene in scenes.items():
        if name not in SETS:
            raise ValueError(f'Scene {name!r} is not a content set: {", ".join(SETS)}')
        for screen, rows in screen_occurrences(scene, name).items():
            seen = {}
            for section, slot, gid in rows:
                where = f'{name} {screen} {section}[{slot}]'
                if gid not in assigned:
                    raise ValueError(f'{where} references undeclared gallery {gid}')
                if assigned[gid] != name:
                    raise ValueError(f'{where}: gallery {gid} is assigned to {assigned[gid]}, not {name}')
                if gid in seen:
                    raise ValueError(f'{name} {screen} repeats gallery {gid} at {seen[gid]} and {section}[{slot}]')
                seen[gid] = f'{section}[{slot}]'
                placed.add(gid)
    unplaced = [gid for gid in assigned if gid not in placed]
    if unplaced:
        raise ValueError(f'Declared galleries are not placed in any scene: {", ".join(unplaced)}')
    return selection


def check_url(url, kind):
    parts = urlsplit(url)
    if parts.scheme != 'https':
        raise ValueError(f'{kind} URL must use https: {scrub(url)}')
    if parts.username is not None or parts.password is not None:
        raise ValueError(f'{kind} URL must not carry credentials')
    host = parts.hostname or ''
    if kind in PAGE_KINDS:
        allowed = host == GALLERY_HOST and parts.port is None
    else:
        allowed = (host in IMAGE_HOSTS and parts.port is None) or HATH_HOST.fullmatch(host) is not None
    if not allowed:
        port = f' with port {parts.port}' if parts.port is not None else ''
        raise ValueError(f'{kind} host {host}{port} is not an allowed gallery or image host')


def scrub(text):
    for pattern in SECRETS:
        text = pattern.sub(lambda match: match[1] + re.sub(r'[0-9A-Za-z]', '0', match[2]), text)
    return text


class Node:
    __slots__ = ('tag', 'attributes', 'children')

    def __init__(self, tag, attributes):
        self.tag = tag
        self.attributes = dict(attributes)
        self.children = []

    def walk(self):
        yield self
        for child in self.children:
            if isinstance(child, Node):
                yield from child.walk()

    def first(self, tag=None, **attributes):
        return next((node for node in self.walk() if (tag is None or node.tag == tag)
                     and all(node.attributes.get(name) == value for name, value in attributes.items())), None)

    def text(self):
        return ''.join(child if isinstance(child, str) else '\n' if child.tag == 'br' else child.text()
                       for child in self.children)


class TreeBuilder(HTMLParser):
    VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node('document', {})
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs)
        self.stack[-1].children.append(node)
        if tag not in self.VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(tag, attrs))

    def handle_endtag(self, tag):
        for depth in range(len(self.stack) - 1, 0, -1):
            if self.stack[depth].tag == tag:
                del self.stack[depth:]
                break

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def parse_html(text):
    builder = TreeBuilder()
    builder.feed(text)
    builder.close()
    return builder.root


def style_url(style):
    start = style.find('url(')
    end = style.find(')', start)
    return style[start + 4:end].replace("'", '') if start >= 0 and end > start else None


def page_divs(gdt, direct):
    """The (link, page) pairs of a preview grid, read like Parser.parseThumbnailURLs and parsePreviewURLs."""
    if direct:
        links = [child for child in gdt.children if isinstance(child, Node) and child.tag == 'a']
    else:
        links = [node for node in gdt.walk() if node.tag == 'a']
    for link in links:
        div = next((node for node in link.walk() if node.tag == 'div' and 'title' in node.attributes
                    and 'style' in node.attributes), None)
        page = div and re.fullmatch(r'\s*([0-9]+)\s*', div.attributes['title'].split(':')[0].replace('Page ', ''))
        if page:
            yield link, div, int(page[1])


def summary(document):
    return ' '.join(document.text().split())[:160]


def text_of(node):
    return node.text() if node is not None else ''


def parse_detail(text):
    """Cover, page count, preview layout, preview images and reader links of a gallery detail page."""
    document = parse_html(text)
    gd1, gdd, gdt = (document.first('div', id=name) for name in ('gd1', 'gdd', 'gdt'))
    cover = next((style_url(node.attributes['style']) for node in gd1.walk()
                  if 'url(' in node.attributes.get('style', '')), None) if gd1 else None
    mode = next((name for name in ('gt100', 'gt200') if document.first('div', **{'class': name})), None)
    shown = re.search(r'Showing 1 - ([0-9]+) of ', text_of(document.first('p', **{'class': 'gpc'})))
    rows = [row for row in gdd.walk() if row.tag == 'tr'] if gdd else []
    length = next((re.fullmatch(r'\s*([0-9]+) pages?\s*', text_of(row.first('td', **{'class': 'gdt2'})))
                   for row in rows if 'Length' in text_of(row.first('td', **{'class': 'gdt1'}))), None)
    if not (cover and mode and shown and length and gdt):
        raise ValueError(f'not a gallery detail page ({summary(document)})')
    return {
        'cover': cover, 'pageCount': int(length[1]), 'previewMode': mode, 'previewCount': int(shown[1]),
        'previews': {page: url for _, div, page in page_divs(gdt, direct=False)
                     if (url := style_url(div.attributes['style']))},
        'thumbnails': {page: link.attributes['href'] for link, _, page in page_divs(gdt, direct=True)
                       if link.attributes.get('href')},
    }


def parse_thumbnails(text):
    gdt = parse_html(text).first('div', id='gdt')
    if gdt is None:
        raise ValueError('not a gallery preview page')
    return {page: link.attributes['href'] for link, _, page in page_divs(gdt, direct=True)
            if link.attributes.get('href')}


def parse_image_page(text):
    document = parse_html(text)
    image = (document.first('div', id='i3') or Node('div', {})).first('img')
    if image is None or not image.attributes.get('src'):
        raise ValueError(f'not a gallery image page ({summary(document)})')
    return image.attributes['src']


def batch_size(mode, count):
    """PreviewConfig.batchSize for the layout Parser.parsePreviewConfig derives from the first preview page."""
    factor = 1 if mode == 'gt200' else 2
    rows = next((rows for limit, rows in ((20, 4), (40, 8), (100, 20), (200, 40)) if count <= limit * factor), 4)
    return (5 if mode == 'gt200' else 10) * rows


def page_number(page, batch):
    return max(page - 1, 0) // batch


def prefetch_window(page, page_count):
    """The pages ReadingReducer.prefetchImages resolves and loads around a page the reader builds.

    The window skips the page's direct neighbours, which the reader builds itself, and uses the default
    Setting.prefetchLimit, which a capture launch keeps.
    """
    previous_upper = max(page - 2, 1)
    previous_lower = max(previous_upper - PREFETCH_LIMIT // 2, 1)
    next_lower = min(page + 2, page_count)
    next_upper = min(next_lower + PREFETCH_LIMIT // 2, page_count)
    window = set()
    if previous_upper - previous_lower > 0:
        window.update(range(previous_lower, previous_upper + 1))
    if next_upper - next_lower > 0:
        window.update(range(next_lower, next_upper + 1))
    return window


def reader_images(pages, page_count):
    """Every page whose image the reader loads: each declared page it builds, and that page's prefetch window."""
    return sorted(set(pages).union(*(prefetch_window(page, page_count) for page in pages)))


def reader_link(thumbnails, page):
    link = thumbnails.get(page)
    if link is None:
        raise ValueError(f'reader page {page} has no link on its preview page')
    if urlsplit(link).path.startswith('/mpv/'):
        raise ValueError(f'reader page {page} opens the multi-page viewer, which needs an account')
    return link


def identity(text, gid, token):
    named = (re.search(r'var\s+gid\s*=\s*([0-9]+)\s*;', text), re.search(r'var\s+token\s*=\s*"([0-9a-f]+)"', text))
    found = '/'.join(match[1] if match else '?' for match in named)
    if found != f'{gid}/{token}':
        raise ValueError(f'detail page identifies gallery {found}, not the selected {gid}/{token}')


def download_pages(entry, page_count):
    """The pages a download entry's folder holds: every page of a complete one, the first completedPages of another."""
    if entry['status'] in COMPLETE_DOWNLOADS:
        return set(range(1, page_count + 1))
    if entry['completedPages'] >= page_count:
        raise ValueError(f'the {entry["status"]} download holds {entry["completedPages"]} of {page_count} pages; '
                         'an incomplete download holds fewer')
    return set(range(1, entry['completedPages'] + 1))


def collect(selection, retrieve):
    """Derive every required resource in declaration order; retrieve(kind, gid, index, url) returns its bytes.

    A flow gallery's reader resources follow the app's reader: the preview page of every batch holding a loaded
    page, every reader page those preview pages list, and the image of each declared page and its prefetch window.
    A download entry's gallery needs the image of every page its folder holds, resolved as a download resolves it:
    the preview page of each batch holding one of those pages, and each of those pages' reader page.
    """
    flows = {scene['flow']['gallery']: scene['flow']['pages'] for scene in selection['scenes'].values()}
    downloads = {entry['gallery']: entry for scene in selection['scenes'].values() for entry in scene['downloads']}
    for gallery in selection['galleries']:
        gid, token = GALLERY_URL.fullmatch(gallery['url']).groups()
        text = retrieve('detail', gid, None, gallery['url'] + '?hc=1').decode()
        try:
            detail = parse_detail(text)
        except ValueError as error:
            raise ValueError(f'{gid}: {error}') from None
        identity(text, gid, token)
        retrieve('cover', gid, None, detail['cover'])
        loaded = set()
        if gid in flows:
            previews = dict.fromkeys(detail['previews'][page] for page in sorted(detail['previews']))
            for index, url in enumerate(previews):
                retrieve('preview', gid, index, url)
            pages = flows[gid]
            if pages[-1] > detail['pageCount']:
                raise ValueError(f'{gid}: reader page {pages[-1]} exceeds the {detail["pageCount"]} pages')
            loaded = set(reader_images(pages, detail['pageCount']))
        held = set()
        if gid in downloads:
            try:
                held = download_pages(downloads[gid], detail['pageCount'])
            except ValueError as error:
                raise ValueError(f'{gid}: {error}') from None
        if not loaded | held:
            continue
        batch = batch_size(detail['previewMode'], detail['previewCount'])
        listings = {}
        for number in sorted({page_number(page, batch) for page in loaded | held}):
            url = f'{gallery["url"]}?p={number}'
            listings[number] = parse_thumbnails(retrieve('thumbnails', gid, number, url).decode())
        links = {page: link for listing in listings.values() for page, link in listing.items()}
        # The reader resolves a batch's image URLs together, from every reader page its preview page lists, and
        # fails them all when one fails: each listed page is required, though only the loaded ones need an image.
        # A download resolves only the pages it saves.
        listed = {page for number in {page_number(page, batch) for page in loaded} for page in listings[number]}
        images = {}
        for page in sorted(listed | loaded | held):
            images[page] = parse_image_page(retrieve('imagePage', gid, page, reader_link(links, page)).decode())
            if urlsplit(images[page]).path.endswith('/509.gif'):
                raise ValueError(f'{gid}: reader page {page} returned the bandwidth-limit image')
        for page in sorted(loaded | held):
            retrieve('page', gid, page, images[page])


def media_type(kind, data, declared):
    if kind in PAGE_KINDS:
        if declared != 'text/html':
            raise ValueError(f'{kind} response is {declared}; expected text/html')
        return declared
    sniffed = 'image/webp' if data[:4] == b'RIFF' and data[8:12] == b'WEBP' else \
        next((mime for signature, mime in SIGNATURES if data.startswith(signature)), None)
    if sniffed is None:
        raise ValueError(f'{kind} has an unsupported image type ({declared})')
    if sniffed != declared:
        raise ValueError(f'{kind} image bytes do not match their type: {sniffed}, declared {declared}')
    return sniffed


def sanitize(kind, data, declared):
    """The stored form of a response and its media type; pages are scrubbed and must carry no account session."""
    mime = media_type(kind, data, declared)
    if kind not in PAGE_KINDS:
        return data, mime
    text = data.decode()
    if SESSION.search(text):
        raise ValueError(f'{kind} response carries an account session; acquisition must stay anonymous')
    return scrub(text).encode(), mime


def asset_path(kind, gid, index, mime):
    if kind in PAGE_KINDS:
        return f'responses/{gid}/' + {'detail': 'detail', 'thumbnails': f'thumbnails-{index}',
                                      'imagePage': f'pages/{index}'}[kind] + '.html'
    if kind in RECORD_KINDS:
        return f'records/{gid}/{kind}/{index}.json'
    return f'assets/{gid}/' + {'cover': 'cover', 'preview': f'previews/{index}', 'page': f'pages/{index}'}[kind] \
        + f'.{MEDIA[mime]}'


def version_identity(selection_sha, assets):
    entries = [{key: value for key, value in entry.items() if key != 'retrievedAt'} for entry in assets]
    return sha256(canonical({'selectionSHA256': selection_sha, 'assets': entries}))


def write_manifest(directory, selection, assets, acquired_at):
    """Write selection.json and manifest.json; the version is content-addressed, so equal inputs share it."""
    selection_bytes = json.dumps(selection, indent=2, sort_keys=True, ensure_ascii=False).encode() + b'\n'
    (directory / 'selection.json').write_bytes(selection_bytes)
    assets = sorted(assets, key=lambda entry: entry['path'])
    aggregate = version_identity(sha256(selection_bytes), assets)
    manifest = {
        'schemaVersion': SCHEMA_VERSION, 'purpose': 'marketingReal', 'fixtureVersion': f'marketing-{aggregate[:16]}',
        'aggregateDigest': aggregate, 'selectionID': selection['selectionID'],
        'selectionStatus': selection['selectionStatus'], 'selectionAuthority': selection['selectionAuthority'],
        'selectionSHA256': sha256(selection_bytes), 'acquiredAt': acquired_at, 'assets': assets,
        'generatorSources': {path: sha256((ROOT / path).read_bytes()) for path in GENERATORS},
    }
    (directory / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    return manifest


def media_types(kind):
    if kind in PAGE_KINDS:
        return ('text/html',)
    return (RECORD_MEDIA,) if kind in RECORD_KINDS else tuple(MEDIA)


def live_text_point(value, context):
    keys(value, ('x', 'y'), context)
    # JSON true is an int in Python, so the type is checked exactly.
    if not all(type(value[axis]) in (int, float) and math.isfinite(value[axis]) for axis in ('x', 'y')):
        raise ValueError(f'{context} must have finite x and y')
    return value['x'], value['y']


def validate_live_text(record, gid, page, page_sha):
    """A Live Text record of page `page` of gallery `gid`, recognized on the page image with digest `page_sha`.

    Every group and line must have an ID, every line text and a quadrilateral that has an extent and overlaps its
    page. Vision may place a corner slightly outside the image, so corners are not clamped to the page.
    """
    keys(record, LIVE_TEXT_KEYS, 'Live Text record')
    if not current_schema(record['schemaVersion']):
        raise ValueError(f'Live Text record schemaVersion must be {SCHEMA_VERSION}')
    if (record['gid'], record['page']) != (gid, page):
        raise ValueError(f'Live Text record names page {record["page"]!r} of gallery {record["gid"]!r}, '
                         f'not page {page} of gallery {gid}')
    if record['pageSHA256'] != page_sha:
        raise ValueError(f'Live Text record of page {page} of gallery {gid} was recognized on other bytes')
    languages = record['recognitionLanguages']
    if languages is not None and (not isinstance(languages, list) or not languages
                                  or not all(isinstance(language, str) and language for language in languages)):
        raise ValueError('Live Text recognitionLanguages must be null or a list of language identifiers')
    keys(record['recordedOn'], ('model', 'runtimeBuild'), 'Live Text recordedOn')
    if not all(isinstance(value, str) and value for value in record['recordedOn'].values()):
        raise ValueError('Live Text recordedOn must name the model and runtime build')
    groups, ids = record['groups'], set()
    if not isinstance(groups, list) or not groups:
        raise ValueError('Live Text record holds no groups')
    for number, group in enumerate(groups):
        keys(group, ('id', 'blocks'), f'Live Text group {number}')
        if not isinstance(group['blocks'], list) or not group['blocks']:
            raise ValueError(f'Live Text group {number} holds no lines')
        for line, block in enumerate(group['blocks']):
            where = f'Live Text group {number} line {line}'
            keys(block, ('id', 'text', *CORNERS), where)
            if not isinstance(block['text'], str) or not block['text']:
                raise ValueError(f'{where} has no text')
            xs, ys = zip(*(live_text_point(block[corner], f'{where} {corner}') for corner in CORNERS))
            if max(xs) <= min(xs) or max(ys) <= min(ys):
                raise ValueError(f'{where} has no extent')
            if max(xs) <= 0 or min(xs) >= 1 or max(ys) <= 0 or min(ys) >= 1:
                raise ValueError(f'{where} lies outside its page')
        for identifier in [group['id'], *(block['id'] for block in group['blocks'])]:
            if not isinstance(identifier, str) or not UUID.fullmatch(identifier) or identifier in ids:
                raise ValueError(f'Live Text group {number} has a missing, malformed or repeated ID')
            ids.add(identifier)


def verify_contents(directory):
    """Validate a fixture directory's files against its manifest by repeating the resource derivation."""
    directory = Path(directory)
    for parent, folders, files in os.walk(directory):
        for name in folders + files:
            if (Path(parent) / name).is_symlink():
                raise ValueError(f'Fixture contains a symbolic link: {(Path(parent) / name).relative_to(directory)}')
    manifest = json.loads((directory / 'manifest.json').read_text())
    keys(manifest, MANIFEST_KEYS, 'Manifest')
    if not current_schema(manifest['schemaVersion']) or manifest['purpose'] != 'marketingReal':
        raise ValueError('Expected a schema 1 marketingReal fixture manifest')
    selection_bytes = (directory / 'selection.json').read_bytes()
    if sha256(selection_bytes) != manifest['selectionSHA256']:
        raise ValueError('selection.json does not match its manifest digest')
    selection = validate_selection(json.loads(selection_bytes))
    if any(manifest[key] != selection[key] for key in ('selectionID', 'selectionStatus', 'selectionAuthority')):
        raise ValueError('Manifest selection identity differs from selection.json')
    keys(manifest['generatorSources'], GENERATORS, 'generatorSources')
    assets = manifest['assets']
    if not isinstance(assets, list) or not assets:
        raise ValueError('Fixture manifest lists no assets')
    by_resource, urls = {}, set()
    for entry in assets:
        keys(entry, ENTRY_KEYS, 'Asset entry')
        kind = entry['kind']
        if (kind not in PAGE_KINDS + IMAGE_KINDS + RECORD_KINDS or not isinstance(entry['gid'], str)
                or not (entry['index'] is None or counting(entry['index'])) or not counting(entry['bytes'])
                or not all(isinstance(entry[key], str) for key in ('path', 'mime', 'sha256', 'retrievedAt'))
                or not (entry['url'] is None if kind in RECORD_KINDS else isinstance(entry['url'], str))
                or entry['mime'] not in media_types(kind)):
            raise ValueError(f'Malformed asset entry: {entry["path"]!r}')
        resource = (kind, entry['gid'], entry['index'])
        if resource in by_resource or entry['url'] in urls:
            raise ValueError(f'Duplicate fixture resource or replay URL: {entry["path"]}')
        by_resource[resource] = entry
        if entry['url'] is not None:
            urls.add(entry['url'])
    if [entry['path'] for entry in assets] != sorted(entry['path'] for entry in assets):
        raise ValueError('Fixture assets must be listed in path order')
    visited = []

    def stored(entry):
        if entry['path'] != asset_path(entry['kind'], entry['gid'], entry['index'], entry['mime']):
            raise ValueError(f'{entry["path"]}: unexpected location for {entry["kind"]} {entry["gid"]}')
        path = contained(directory, entry['path'])
        if not path.is_file():
            raise ValueError(f'Fixture is missing the file {entry["path"]}')
        data = path.read_bytes()
        if len(data) != entry['bytes'] or sha256(data) != entry['sha256']:
            raise ValueError(f'Fixture checksum/length mismatch: {entry["path"]}')
        return data

    def retrieve(kind, gid, index, url):
        entry = by_resource.get((kind, gid, index))
        if entry is None:
            raise ValueError(f'Fixture is missing the required {kind} for gallery {gid}')
        if entry['url'] != url or scrub(url) != url:
            raise ValueError(f'{entry["path"]}: replay URL differs from the URL its gallery names')
        check_url(url, kind)
        data = stored(entry)
        if sanitize(kind, data, entry['mime']) != (data, entry['mime']):
            raise ValueError(f'{entry["path"]}: stored response is not in its scrubbed form')
        visited.append(entry)
        return data

    collect(selection, retrieve)
    records = [entry for entry in assets if entry['kind'] in RECORD_KINDS]
    if len(visited) + len(records) != len(assets):
        raise ValueError('Fixture manifest lists resources the selection does not require')
    # Recording adds a Live Text record after acquisition, so a fixture holds each flow's record or none of them,
    # and only for the page a flow shows Live Text on.
    recordable = {(scene['flow']['gallery'], scene['flow']['liveTextPage']) for scene in selection['scenes'].values()}
    for entry in records:
        gid, page = entry['gid'], entry['index']
        if (gid, page) not in recordable:
            raise ValueError(f'{entry["path"]}: no flow shows Live Text on page {page} of gallery {gid}')
        validate_live_text(json.loads(stored(entry)), gid, page, by_resource['page', gid, page]['sha256'])
    listed = {entry['path'] for entry in assets} | {'manifest.json', 'selection.json'}
    present = {str(path.relative_to(directory)) for path in directory.rglob('*') if path.is_file()}
    if present != listed:
        raise ValueError(f'Fixture files differ from the manifest: {", ".join(sorted(present ^ listed))}')
    aggregate = version_identity(manifest['selectionSHA256'], assets)
    if manifest['aggregateDigest'] != aggregate or manifest['fixtureVersion'] != f'marketing-{aggregate[:16]}':
        raise ValueError('Fixture aggregate digest or version mismatch')
    return manifest


def resolve_fixtures(path):
    """The version directory a path names, directly or through the output's `current` link, resolved once.

    Readers keep reading the returned directory: a later publication can repoint `current` at any moment,
    while a published version directory never changes.
    """
    path = Path(path)
    if path.is_symlink():
        target = Path(os.readlink(path))
        version = path.parent / target
        if (target.is_absolute() or len(target.parts) != 2 or target.parts[0] != 'versions'
                or version.parent.is_symlink() or version.is_symlink()):
            raise ValueError(f'{path} must link to a versions/<fixtureVersion> directory beside it')
        path = version
    return path.resolve(strict=True)


def validate_fixtures(path):
    """Validate a published version directory, directly or through the output's `current` link."""
    directory = resolve_fixtures(path)
    manifest = verify_contents(directory)
    if directory.name != manifest['fixtureVersion']:
        raise ValueError(f'Fixture directory {directory.name} is not named for version {manifest["fixtureVersion"]}')
    return manifest


def check_output(output):
    """Real marketing assets stay out of version control: an output inside the repository must be ignored."""
    if output.resolve().is_relative_to(ROOT):
        relative = output.resolve().relative_to(ROOT)
        result = subprocess.run(['git', '-C', str(ROOT), 'check-ignore', '-q', str(relative / 'current')])
        if result.returncode != 0:
            raise ValueError(f'Output {relative} must be git-ignored; use .capture/marketing')


class Writer:
    """The output's single writer: holds its lock and one staging directory, and publishes only verified contents.

    Every acquisition writes into a fresh staging directory and nothing else. Publication renames a verified
    staging directory into versions/<fixtureVersion> and then atomically repoints `current`; an interrupted or
    failed acquisition never reaches either step, and a writer killed outright leaves only staging behind,
    which the next writer removes under the same lock.
    """

    def __init__(self, output):
        self.output = Path(output)

    def __enter__(self):
        if self.output.is_symlink():
            raise ValueError('Fixture output must not be a symbolic link')
        self.output.mkdir(parents=True, exist_ok=True)
        self.lock = os.open(self.output / '.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o644)
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            for stale in self.output.glob('.staging-*'):
                shutil.rmtree(stale)
            for stale in self.output.glob('.current-*'):
                stale.unlink()
            self.staging = Path(tempfile.mkdtemp(prefix='.staging-', dir=self.output))
        except BaseException as error:
            os.close(self.lock)
            if isinstance(error, BlockingIOError):
                raise ValueError(f'Another fixture acquisition is writing {self.output}') from None
            raise
        return self

    def published(self):
        link = self.output / 'current'
        return link.is_symlink() or link.exists()

    def publish(self, manifest):
        if verify_contents(self.staging) != manifest:
            raise ValueError('Staged fixture differs from the manifest written for it')
        target = self.output / 'versions' / manifest['fixtureVersion']
        if target.parent.is_symlink():
            raise ValueError('Fixture versions directory must not be a symbolic link')
        target.parent.mkdir(exist_ok=True)
        changed = not target.exists()
        if changed:
            self.staging.rename(target)
        validate_fixtures(target)
        link, relative = self.output / 'current', f'versions/{target.name}'
        if not link.is_symlink() or os.readlink(link) != relative:
            temporary = self.output / f'.current-{os.getpid()}'
            os.symlink(relative, temporary)
            os.replace(temporary, link)
            changed = True
        return target, changed

    def __exit__(self, *_):
        try:
            if self.staging.exists():
                shutil.rmtree(self.staging)
        finally:
            os.close(self.lock)


def publish_records(output, records, recorded_at):
    """Publish the current version again with these Live Text records, each replacing any earlier record of its page.

    The new version keeps every other file and the acquisition time; a record's retrieval time is when it was
    recorded. Returns the published directory and whether `current` changed.
    """
    output = Path(output)
    with Writer(output) as writer:
        if not writer.published():
            raise ValueError(f'{output / "current"} is not published; acquire the fixture before recording')
        source = resolve_fixtures(output / 'current')
        manifest = validate_fixtures(source)
        selection = validate_selection(json.loads((source / 'selection.json').read_text()))
        # Publication validates each record completely; its keys are needed first to place it.
        for record in records:
            keys(record, LIVE_TEXT_KEYS, 'Live Text record')
        replaced = {(record['gid'], record['page']) for record in records}
        assets = [entry for entry in manifest['assets']
                  if entry['kind'] not in RECORD_KINDS or (entry['gid'], entry['index']) not in replaced]
        for entry in assets:
            (writer.staging / entry['path']).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / entry['path'], writer.staging / entry['path'])
        for record in records:
            data = json.dumps(record, indent=2, sort_keys=True, ensure_ascii=False).encode() + b'\n'
            relative = asset_path('liveText', record['gid'], record['page'], RECORD_MEDIA)
            (writer.staging / relative).parent.mkdir(parents=True, exist_ok=True)
            (writer.staging / relative).write_bytes(data)
            assets.append({'kind': 'liveText', 'gid': record['gid'], 'index': record['page'], 'url': None,
                           'path': relative, 'mime': RECORD_MEDIA, 'bytes': len(data), 'sha256': sha256(data),
                           'retrievedAt': recorded_at})
        return writer.publish(write_manifest(writer.staging, selection, assets, manifest['acquiredAt']))
