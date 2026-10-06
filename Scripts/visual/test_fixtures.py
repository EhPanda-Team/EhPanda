"""Real marketing fixture selection, acquisition, scrubbing and publication contracts."""
import copy
import fcntl
import hashlib
import http.client
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.request

import fixtures

ROOT = Path(__file__).resolve().parents[2]
SAVED = ROOT / 'AppPackage/Sources/TestingSupport/Resources/Parser'
JPEG = b'\xff\xd8\xff\xe0'
PNG = b'\x89PNG\r\n\x1a\n'
APIKEY = '5f3c1e2d4b6a7980ab'
SHOWKEY = '9a8b7c6d5e'
KEYSTAMP = '1759800000-0a1b2c3d4e'
ORIGINAL_KEY = 'k3y9z8w7v6'
BATCH = fixtures.batch_size('gt100', 40)


def load_acquirer():
    spec = importlib.util.spec_from_file_location('acquire_fixtures', ROOT / 'Scripts/visual/acquire-fixtures.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def token(value):
    return hashlib.sha256(value.encode()).hexdigest()[:10]


def gallery_url(gid):
    return f'https://e-hentai.org/g/{gid}/{token(gid)}/'


def reader_url(gid, page):
    return f'https://e-hentai.org/s/{token(gid + str(page))}/{gid}-{page}'


def image_url(gid, page):
    return (f'https://abcde.hath.network:1443/h/{token(gid + "h" + str(page))}-1000-1280-1820-jpg/'
            f'keystamp={KEYSTAMP};fileindex=12345;xres=1280/{page:03d}.jpg')


def sprite_url(gid, page):
    return f'https://ehgt.org/m/{gid}/{gid}-{(page - 1) // 20:02d}.jpg'


def thumbnails(gid, first, last):
    return ''.join(
        f'<a href="{reader_url(gid, page)}"><div title="Page {page}: {page:03d}.jpg" '
        f'style="width:100px;height:142px;background:transparent url({sprite_url(gid, page)}) '
        f'-{(page - 1) % 20 * 100}px 0 no-repeat"></div></a>' for page in range(first, last + 1))


def detail_html(gid, pages=60, shown=40, apiuid='-1', cover=None, title=None, body='', named=None):
    named = named or (gid, token(gid))
    cover = cover or f'https://ehgt.org/w/{gid}/cover.jpg'
    return '\n'.join([
        '<!DOCTYPE html><html><head><script type="text/javascript">',
        'var base_url = "https://e-hentai.org/";',
        f'var gid = {named[0]};', f'var token = "{named[1]}";', f'var apiuid = {apiuid};', f'var apikey = "{APIKEY}";',
        'var average_rating = 4.50;', '</script></head><body><div class="gm"><div id="gleft"><div id="gd1">',
        f'<div style="width:250px; height:354px; background:transparent url({cover}) 0 0 no-repeat"></div></div></div>',
        f'<div id="gd2"><h1 id="gn">{title or "Gallery " + gid}</h1><h1 id="gj"></h1></div>',
        '<div id="gmid"><div id="gdd"><table>',
        '<tr><td class="gdt1">Posted:</td><td class="gdt2">2024-01-01 00:00</td></tr>',
        f'<tr><td class="gdt1">Length:</td><td class="gdt2">{pages} pages</td></tr></table></div></div></div>',
        f'<div class="gtb"><p class="gpc">Showing 1 - {min(shown, pages)} of {pages} images</p></div>',
        f'<div id="gdt" class="gt100">{thumbnails(gid, 1, min(shown, pages))}</div>{body}',
        '<div id="cdiv" class="gm"><div class="c1"><div class="c2"><div class="c3">Posted on 01 January 2024, 00:00',
        ' by: &nbsp; <a href="https://e-hentai.org/uploader/Reader">Reader</a></div></div>',
        '<div class="c6" id="comment_1">A readable comment.</div></div></div>', '</body></html>'])


def thumbnails_html(gid, number, pages=60):
    first = number * BATCH + 1
    return f'<html><body><div id="gdt" class="gt100">{thumbnails(gid, first, min(first + BATCH - 1, pages))}</div>'


def image_page_html(gid, page, image=None):
    return '\n'.join([
        '<html><head><script type="text/javascript">',
        f'var gid={gid};var startpage={page};var showkey="{SHOWKEY}";</script></head><body>',
        f'<div id="i3"><a href="{reader_url(gid, page + 1)}">',
        f'<img id="img" src="{image or image_url(gid, page)}" /></a></div><div id="i7" class="if">',
        f'<a href="https://e-hentai.org/fullimg/{gid}/{page}/{ORIGINAL_KEY}/{page:03d}.jpg">Download original</a>',
        '</div></body></html>'])


def selection(prefix='1', scene_set='nonexplicit'):
    gids = [f'{prefix}{index:02d}' for index in range(1, 18)]
    return {
        'schemaVersion': 1, 'selectionID': 'marketing-test', 'selectionStatus': 'provisional',
        'selectionAuthority': 'owner',
        'galleries': [{'url': gallery_url(gid), 'set': scene_set} for gid in gids],
        'scenes': {scene_set: {
            'home': {'hero': {'galleries': gids[0:3], 'selectedIndex': 1}, 'frontpage': gids[3:5],
                     'toplists': {'yesterday': gids[5:8], 'pastMonth': gids[8:11], 'pastYear': gids[11:14],
                                  'allTime': gids[14:17]}},
            'flow': {'gallery': gids[0], 'readerPage': 4, 'liveTextPage': 4, 'pages': [3, 4, 5]},
            'downloads': [{'gallery': gids[0], 'status': 'completed'},
                          {'gallery': gids[3], 'status': 'active', 'completedPages': 12}],
        }},
    }


class Site:
    """Synthetic responses shaped like the app parser's inputs; records every requested URL."""

    def __init__(self, value, pages=60, shown=40):
        self.calls = []
        self.responses = {}
        flows = {scene['flow']['gallery']: scene['flow']['pages'] for scene in value['scenes'].values()}
        for gallery in value['galleries']:
            gid = gallery['url'].split('/')[4]
            self.html(gallery['url'] + '?hc=1', detail_html(gid, pages, shown))
            self.image(f'https://ehgt.org/w/{gid}/cover.jpg')
            if gid not in flows:
                continue
            for page in range(1, min(shown, pages) + 1, 20):
                self.image(sprite_url(gid, page), PNG)
            for number in {fixtures.page_number(page, BATCH) for page in flows[gid]}:
                self.html(f'{gallery["url"]}?p={number}', thumbnails_html(gid, number, pages))
            for page in flows[gid]:
                self.html(reader_url(gid, page), image_page_html(gid, page))
                self.image(image_url(gid, page))

    def html(self, url, text):
        self.responses[url] = (text.encode(), 'text/html')

    def image(self, url, magic=JPEG):
        # Image bytes are a digest of the URL, so they never repeat an access-bearing value from it.
        mime = 'image/png' if magic == PNG else 'image/jpeg'
        self.responses[url] = (magic + hashlib.sha256(url.encode()).digest(), mime)

    def __call__(self, url):
        self.calls.append(url)
        if url not in self.responses:
            raise OSError('HTTP Error 404: Not Found')
        return self.responses[url]


class Clock:
    def __init__(self, start=0):
        self.tick = start

    def __call__(self):
        self.tick += 1
        return f'2026-10-07T00:{self.tick // 60:02d}:{self.tick % 60:02d}+00:00'


class FixtureTestCase(unittest.TestCase):
    def setUp(self):
        self.acquirer = load_acquirer()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.output = self.directory / 'marketing'
        self.selection = selection()

    def write_selection(self, value=None):
        path = self.directory / 'selection.json'
        path.write_text(json.dumps(self.selection if value is None else value))
        return path

    def acquire(self, site=None, value=None, refresh=False, clock=None):
        value = self.selection if value is None else value
        return self.acquirer.acquire(self.write_selection(value), self.output, refresh=refresh,
                                     fetch=site or Site(value), clock=clock or Clock())

    def assert_unpublished(self):
        self.assertFalse((self.output / 'current').exists())
        self.assertEqual(list((self.output / 'versions').glob('*')), [])
        self.assertEqual(list(self.output.glob('.staging-*')), [])


class AcquisitionTests(FixtureTestCase):
    def test_publishes_versioned_selection_with_provenance(self):
        site = Site(self.selection)
        target, changed = self.acquire(site)
        self.assertTrue(changed)
        current = self.output / 'current'
        self.assertTrue(current.is_symlink())
        self.assertEqual(os.readlink(current), f'versions/{target.name}')
        manifest = fixtures.validate_fixtures(current)
        self.assertEqual(manifest['fixtureVersion'], target.name)
        self.assertRegex(target.name, r'^marketing-[0-9a-f]{16}$')
        self.assertEqual((manifest['purpose'], manifest['selectionID'], manifest['selectionStatus'],
                          manifest['selectionAuthority']), ('marketingReal', 'marketing-test', 'provisional', 'owner'))
        self.assertEqual(json.loads((target / 'selection.json').read_text()), self.selection)
        for entry in manifest['assets']:
            data = (target / entry['path']).read_bytes()
            self.assertEqual((entry['bytes'], entry['sha256']), (len(data), hashlib.sha256(data).hexdigest()))
            self.assertTrue(entry['url'].startswith('https://'))
            self.assertRegex(entry['retrievedAt'], r'^2026-10-07T')
            self.assertIn(entry['mime'], ('text/html', 'image/jpeg', 'image/png'))
        self.assertEqual(sorted(manifest['generatorSources']), sorted(fixtures.GENERATORS))
        kinds = [entry['kind'] for entry in manifest['assets']]
        self.assertEqual({kind: kinds.count(kind) for kind in set(kinds)},
                         {'detail': 17, 'cover': 17, 'preview': 2, 'thumbnails': 1, 'imagePage': 3, 'page': 3})
        # Fetches follow declaration order and request exactly the derived resources, each once.
        self.assertEqual(len(site.calls), 43)
        self.assertEqual(len(set(site.calls)), 43)
        details = [url for url in site.calls if url.endswith('?hc=1')]
        self.assertEqual(details, [gallery['url'] + '?hc=1' for gallery in self.selection['galleries']])
        self.assertIn(gallery_url('101') + '?p=0', site.calls)

    def test_reader_page_beyond_the_first_batch_uses_the_app_page_number(self):
        self.selection['scenes']['nonexplicit']['flow'].update(pages=[45], readerPage=45, liveTextPage=45)
        site = Site(self.selection)
        self.acquire(site)
        self.assertIn(gallery_url('101') + '?p=1', site.calls)
        self.assertNotIn(gallery_url('101') + '?p=0', site.calls)

    def test_batch_size_mirrors_the_app_preview_configuration(self):
        for mode, count, expected in [('gt100', 20, 40), ('gt100', 40, 40), ('gt100', 41, 80), ('gt100', 200, 200),
                                      ('gt100', 400, 400), ('gt100', 401, 40), ('gt200', 20, 20), ('gt200', 21, 40),
                                      ('gt200', 100, 100), ('gt200', 200, 200), ('gt200', 201, 20)]:
            with self.subTest(mode=mode, count=count):
                self.assertEqual(fixtures.batch_size(mode, count), expected)
        self.assertEqual([fixtures.page_number(page, 40) for page in (1, 40, 41, 80, 81)], [0, 0, 1, 1, 2])

    def test_reader_page_beyond_the_gallery_fails_before_publication(self):
        self.selection['scenes']['nonexplicit']['flow'].update(pages=[4, 61], readerPage=4, liveTextPage=4)
        with self.assertRaisesRegex(ValueError, 'page 61 exceeds the 60 pages'):
            self.acquire()
        self.assert_unpublished()

    def test_failed_remote_resource_fails_without_publication(self):
        cover = 'https://ehgt.org/w/105/cover.jpg'
        for name, failure in [('missing', None), ('truncated', http.client.IncompleteRead(b'\xff\xd8', 4096))]:
            with self.subTest(name):
                site = Site(self.selection)
                del site.responses[cover]

                def fetch(url):
                    if url == cover and failure is not None:
                        raise failure
                    return site(url)
                with self.assertRaisesRegex(ValueError, f'cover 105: {cover}: (OSError|IncompleteRead)'):
                    self.acquire(fetch)
                self.assert_unpublished()

    def test_not_a_detail_page_fails_explicitly(self):
        site = Site(self.selection)
        site.html(gallery_url('104') + '?hc=1', '<html><body><p>This gallery has been removed.</p></body></html>')
        with self.assertRaisesRegex(ValueError, '104: not a gallery detail page .*removed'):
            self.acquire(site)
        self.assert_unpublished()

    def test_response_for_another_gallery_is_rejected(self):
        for named, message in [(('105', token('105')), 'identifies gallery 105/'),
                               (('104', 'ffffffffff'), 'identifies gallery 104/ffffffffff, not the selected 104/')]:
            with self.subTest(message):
                site = Site(self.selection)
                site.html(gallery_url('104') + '?hc=1', detail_html('104', named=named))
                with self.assertRaisesRegex(ValueError, message):
                    self.acquire(site)
                self.assert_unpublished()

    def test_multi_page_viewer_links_are_rejected(self):
        site = Site(self.selection)
        viewer = f'https://e-hentai.org/mpv/101/{token("101")}/#page4'
        site.html(gallery_url('101') + '?p=0', thumbnails_html('101', 0).replace(reader_url('101', 4), viewer))
        with self.assertRaisesRegex(ValueError, 'multi-page viewer'):
            self.acquire(site)
        self.assert_unpublished()

    def test_bandwidth_limit_image_is_rejected(self):
        site = Site(self.selection)
        site.html(reader_url('101', 3), image_page_html('101', 3, 'https://ehgt.org/g/509.gif'))
        with self.assertRaisesRegex(ValueError, 'bandwidth'):
            self.acquire(site)
        self.assert_unpublished()

    def test_media_type_must_match_the_bytes(self):
        cases = {
            'image bytes do not match their type': ('https://ehgt.org/w/102/cover.jpg', (PNG + b'x', 'image/jpeg')),
            'unsupported image type': ('https://ehgt.org/w/102/cover.jpg', (b'BM' + b'x', 'image/bmp')),
            'expected text/html': (gallery_url('102') + '?hc=1', (detail_html('102').encode(), 'text/plain')),
        }
        for message, (url, response) in cases.items():
            with self.subTest(message):
                site = Site(self.selection)
                site.responses[url] = response
                with self.assertRaisesRegex(ValueError, message):
                    self.acquire(site)
                self.assert_unpublished()


class HostPolicyTests(FixtureTestCase):
    def test_disallowed_resource_hosts_are_never_fetched(self):
        for url in ['https://evil.example/cover.jpg', 'http://ehgt.org/w/102/cover.jpg',
                    'https://e-hentai.org.evil.example/c.jpg', 'https://user@ehgt.org/w/c.jpg',
                    'https://ehgt.org:8443/w/c.jpg', 'https://x.hath.network.evil.example/c.jpg']:
            with self.subTest(url):
                site = Site(self.selection)
                site.html(gallery_url('102') + '?hc=1', detail_html('102', cover=url))
                site.image(url)
                with self.assertRaisesRegex(ValueError, 'not an allowed|https|credentials'):
                    self.acquire(site)
                self.assertNotIn(url, site.calls)
                self.assert_unpublished()

    def test_page_hosts_and_image_hosts_are_not_interchangeable(self):
        with self.assertRaisesRegex(ValueError, 'not an allowed'):
            fixtures.check_url('https://ehgt.org/g/123/abcdef0123/?hc=1', 'detail')
        with self.assertRaisesRegex(ValueError, 'not an allowed'):
            fixtures.check_url('https://e-hentai.org/cover.jpg', 'cover')
        fixtures.check_url('https://abc.def.hath.network:1443/h/x/keystamp=0-0/1.jpg', 'page')
        fixtures.check_url('https://gt2.ehgt.org/m/1/1-00.jpg', 'preview')

    def test_requests_carry_no_credentials_even_when_the_environment_has_them(self):
        environment = {'EHPANDA_AUTOMATION_IPB_MEMBER_ID': '4242', 'EHPANDA_AUTOMATION_IPB_PASS_HASH': 'f' * 32,
                       'EHPANDA_AUTOMATION_IGNEOUS': 'secret'}
        with patch.dict(os.environ, environment):
            page = self.acquirer.request(gallery_url('101') + '?hc=1')
            image = self.acquirer.request('https://ehgt.org/w/101/cover.jpg')
        self.assertEqual(page.header_items(), [('User-agent', self.acquirer.USER_AGENT), ('Cookie', 'nw=1')])
        self.assertEqual(image.header_items(), [('User-agent', self.acquirer.USER_AGENT)])

    def test_redirects_are_refused(self):
        handler = self.acquirer.RefuseRedirects()
        request = urllib.request.Request(gallery_url('101'))
        self.assertIsNone(handler.redirect_request(request, None, 302, 'Found', {}, 'https://evil.example/'))


class ScrubbingTests(FixtureTestCase):
    def test_access_bearing_values_never_reach_the_fixture(self):
        target, _ = self.acquire()
        manifest = fixtures.validate_fixtures(target)
        stored = b''.join(path.read_bytes() for path in target.rglob('*') if path.is_file())
        for secret in [APIKEY, SHOWKEY, KEYSTAMP, ORIGINAL_KEY]:
            self.assertNotIn(secret.encode(), stored)
        detail = (target / 'responses/101/detail.html').read_text()
        self.assertIn('var apikey = "000000000000000000";', detail)
        reader = (target / 'responses/101/pages/4.html').read_text()
        self.assertIn('var showkey="0000000000";', reader)
        self.assertIn('keystamp=0000000000-0000000000;', reader)
        self.assertIn('/fullimg/101/4/0000000000/', reader)
        # The recorded replay URL is the URL the stored response names, so offline replay stays consistent.
        page = next(entry for entry in manifest['assets'] if entry['kind'] == 'page' and entry['index'] == 4)
        self.assertIn(f'src="{page["url"]}"', reader)

    def test_scrubbing_is_idempotent_and_preserves_shape(self):
        text = (f'var apikey = "{APIKEY}"; keystamp={KEYSTAMP}; https://a.hath.network/cm/ab12cd/1-0.jpg '
                f'https://e-hentai.org/fullimg.php?gid=1&amp;page=2&amp;key={ORIGINAL_KEY} '
                f'https://e-hentai.org/r/ea42b28b-311480-1280-1920-jpg/forumtoken/1-1/x.jpg')
        scrubbed = fixtures.scrub(text)
        self.assertEqual(len(scrubbed), len(text))
        self.assertEqual(fixtures.scrub(scrubbed), scrubbed)
        for secret in [APIKEY, KEYSTAMP, 'ab12cd', ORIGINAL_KEY, 'forumtoken']:
            self.assertNotIn(secret, scrubbed)

    def test_unscrubbable_access_value_fails_before_publication(self):
        # An entity-encoded stamp parses to a live URL that scrubbing cannot see in the stored text; the staged
        # copy then disagrees with the recorded replay URL, so verification refuses it before anything is published.
        site = Site(self.selection)
        encoded = image_url('101', 3).replace('keystamp=', 'keystamp&#61;')
        site.html(reader_url('101', 3), image_page_html('101', 3, encoded))
        with self.assertRaisesRegex(ValueError, 'replay URL differs'):
            self.acquire(site)
        self.assert_unpublished()

    def test_account_session_responses_are_rejected(self):
        cases = [('apiuid', detail_html('103', apiuid='4242')),
                 ('ipb_member_id', detail_html('103', body='<script>document.cookie="ipb_member_id=4242"</script>')),
                 ('ipb_pass_hash', detail_html('103', body='<p>ipb_pass_hash</p>')),
                 ('igneous', detail_html('103', body='<p>igneous</p>'))]
        for marker, html in cases:
            with self.subTest(marker):
                site = Site(self.selection)
                site.html(gallery_url('103') + '?hc=1', html)
                with self.assertRaisesRegex(ValueError, 'account session'):
                    self.acquire(site)
                self.assert_unpublished()


class SelectionTests(FixtureTestCase):
    def assert_rejected(self, value, message):
        site = Site(selection())
        with self.assertRaisesRegex(ValueError, message):
            self.acquire(site, value)
        self.assertEqual(site.calls, [])
        self.assertFalse(self.output.exists())

    def test_empty_selection_is_rejected_before_any_request(self):
        value = selection()
        value['galleries'] = []
        self.assert_rejected(value, 'Empty selection')
        value = selection()
        value['scenes'] = {}
        self.assert_rejected(value, 'Empty selection')

    def test_repeated_gallery_within_one_screen_is_rejected(self):
        queued = {'gallery': '101', 'status': 'queued', 'completedPages': 0}
        cases = [('hero and toplists', lambda scene: scene['home']['toplists']['allTime'].__setitem__(2, '101'), '117'),
                 ('frontpage pair', lambda scene: scene['home']['frontpage'].__setitem__(1, '104'), '105'),
                 ('downloads', lambda scene: scene['downloads'].append(queued), None)]
        for name, mutate, displaced in cases:
            with self.subTest(name):
                value = selection()
                mutate(value['scenes']['nonexplicit'])
                if displaced:
                    # Drop the displaced gallery so that the repetition is the only fault.
                    value['galleries'] = [item for item in value['galleries'] if item['url'] != gallery_url(displaced)]
                self.assert_rejected(value, 'repeats gallery')

    def test_reuse_across_screens_is_valid(self):
        # 101 is a hero card, the reading flow and a download; 104 is on the frontpage and in downloads.
        occurrences = fixtures.screen_occurrences(self.selection['scenes']['nonexplicit'])
        self.assertIn('101', [gid for _, _, gid in occurrences['home']])
        self.assertEqual([gid for _, _, gid in occurrences['reading']], ['101'])
        self.assertEqual([gid for _, _, gid in occurrences['downloads']], ['101', '104'])
        self.assertEqual(fixtures.validate_selection(self.selection), self.selection)

    def test_set_assignment_is_explicit_and_scoped(self):
        value = selection()
        value['galleries'][5]['set'] = 'explicit'
        self.assert_rejected(value, 'assigned to explicit, not nonexplicit')
        value = selection()
        value['galleries'][5]['set'] = 'sfw'
        self.assert_rejected(value, 'set must be one of')
        value = selection()
        value['galleries'][5].pop('set')
        self.assert_rejected(value, 'exactly the keys')

    def test_declared_galleries_must_be_placed_and_unique(self):
        value = selection()
        value['galleries'].append({'url': gallery_url('199'), 'set': 'nonexplicit'})
        self.assert_rejected(value, 'not placed in any scene: 199')
        value = selection()
        value['galleries'].append(copy.deepcopy(value['galleries'][0]))
        self.assert_rejected(value, 'declared twice')
        value = selection()
        value['scenes']['nonexplicit']['home']['frontpage'][0] = '198'
        self.assert_rejected(value, 'undeclared gallery 198')

    def test_selection_fields_are_strict(self):
        scene = ('scenes', 'nonexplicit')
        cases = [
            ((), dict(selectionStatus='final', selectionAuthority='agent-delegated'), 'owner authority'),
            ((), dict(selectionAuthority='anyone'), 'selectionAuthority'),
            ((), dict(schemaVersion=2), 'schemaVersion'),
            ((), dict(selectionID='Has Spaces'), 'selectionID'),
            (('galleries', 0), dict(url='https://exhentai.org/g/101/abcdef0123/'), 'Gallery URL'),
            (('galleries', 0), dict(url=gallery_url('101').rstrip('/')), 'Gallery URL'),
            (('scenes',), dict(other={}), 'content set'),
            ((*scene, 'home', 'hero'), dict(selectedIndex=3), 'selectedIndex'),
            ((*scene, 'home', 'hero'), dict(selectedIndex=True), 'selectedIndex'),
            ((*scene, 'flow'), dict(pages=[5, 3, 4]), 'ascending'),
            ((*scene, 'flow'), dict(pages=[0, 4]), 'ascending'),
            ((*scene, 'flow'), dict(liveTextPage=9), 'liveTextPage'),
            ((*scene, 'downloads', 0), dict(status='paused'), 'status'),
            ((*scene, 'downloads', 0), dict(completedPages=3), 'completedPages'),
            ((*scene, 'downloads', 1), dict(completedPages=-1), 'completedPages'),
            ((*scene, 'downloads', 1), dict(completedPages='12'), 'completedPages'),
        ]
        for path, change, message in cases:
            with self.subTest(message=message, change=change):
                value = selection()
                target = value
                for key in path:
                    target = target[key]
                target.update(change)
                self.assert_rejected(value, message)
        for path, key in [((*scene, 'downloads', 1), 'completedPages'), ((*scene, 'home', 'toplists'), 'allTime')]:
            with self.subTest(removed=key):
                value = selection()
                target = value
                for step in path:
                    target = target[step]
                del target[key]
                self.assert_rejected(value, 'exactly the keys')

    def test_both_sets_can_be_declared_in_one_selection(self):
        value = selection()
        other = selection('2', 'explicit')
        value['galleries'] += other['galleries']
        value['scenes'].update(other['scenes'])
        target, _ = self.acquire(value=value)
        manifest = fixtures.validate_fixtures(target)
        self.assertEqual(sum(entry['kind'] == 'detail' for entry in manifest['assets']), 34)


class OrderingTests(FixtureTestCase):
    def test_equal_ranking_values_keep_the_configured_order_and_a_stable_version(self):
        # Two frontpage galleries share title, rating and page count; nothing re-sorts them by those values.
        site = Site(self.selection)
        for gid in ('104', '105'):
            site.html(gallery_url(gid) + '?hc=1', detail_html(gid, title='Equal ranking'))
        first, _ = self.acquire(site, clock=Clock(0))
        stored = json.loads((first / 'selection.json').read_text())
        self.assertEqual(stored['scenes']['nonexplicit']['home']['frontpage'], ['104', '105'])
        self.assertEqual([url for url in site.calls if url.endswith('?hc=1')][3:5],
                         [gallery_url('104') + '?hc=1', gallery_url('105') + '?hc=1'])
        # The same inputs at a later time keep the version hash; timestamps are provenance, not identity.
        again, changed = self.acquire(site, refresh=True, clock=Clock(500))
        self.assertEqual((again, changed), (first, False))
        # Swapping the equal-ranking pair is a different configured order, so it is a different version.
        swapped = copy.deepcopy(self.selection)
        swapped['scenes']['nonexplicit']['home']['frontpage'] = ['105', '104']
        other, changed = self.acquire(site, value=swapped, refresh=True)
        self.assertTrue(changed)
        self.assertNotEqual(other, first)
        frontpage = json.loads((other / 'selection.json').read_text())['scenes']['nonexplicit']['home']['frontpage']
        self.assertEqual(frontpage, ['105', '104'])
        occurrences = fixtures.screen_occurrences(swapped['scenes']['nonexplicit'])['home']
        self.assertEqual([row for row in occurrences if row[0] == 'frontpage'], [('frontpage', 0, '105'),
                                                                                 ('frontpage', 1, '104')])
        self.assertTrue(first.is_dir())

    def test_changed_remote_content_publishes_a_new_version_and_keeps_the_old_one(self):
        first, _ = self.acquire()
        site = Site(self.selection)
        site.html(gallery_url('110') + '?hc=1', detail_html('110', title='Retitled'))
        second, changed = self.acquire(site, refresh=True)
        self.assertTrue(changed)
        self.assertNotEqual(first, second)
        self.assertEqual(os.readlink(self.output / 'current'), f'versions/{second.name}')
        fixtures.validate_fixtures(first)

    def test_published_output_requires_an_explicit_refresh(self):
        self.acquire()
        site = Site(self.selection)
        with self.assertRaisesRegex(ValueError, '--refresh'):
            self.acquire(site)
        self.assertEqual(site.calls, [])


class TamperingTests(FixtureTestCase):
    def setUp(self):
        super().setUp()
        self.target, _ = self.acquire()
        self.manifest = json.loads((self.target / 'manifest.json').read_text())
        self.page = next(entry['path'] for entry in self.manifest['assets'] if entry['kind'] == 'page')

    def tampered(self, name, mutate):
        root = self.directory / 'tampered' / name
        version = root / 'versions' / self.target.name
        shutil.copytree(self.target, version, symlinks=True)
        os.symlink(f'versions/{self.target.name}', root / 'current')
        mutate(version, root)
        return root / 'current'

    def edit_manifest(self, version, change):
        manifest = json.loads((version / 'manifest.json').read_text())
        change(manifest)
        (version / 'manifest.json').write_text(json.dumps(manifest))

    def relink(self, root, target):
        (root / 'current').unlink()
        os.symlink(target, root / 'current')

    def resealed(self, name, edit):
        """A tampered copy whose checksums, aggregate and version are recomputed, so only semantic checks remain."""
        def mutate(version, root):
            edit(version)
            manifest = json.loads((version / 'manifest.json').read_text())
            for entry in manifest['assets']:
                data = (version / entry['path']).read_bytes()
                entry.update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            manifest['aggregateDigest'] = fixtures.version_identity(manifest['selectionSHA256'], manifest['assets'])
            manifest['fixtureVersion'] = f'marketing-{manifest["aggregateDigest"][:16]}'
            (version / 'manifest.json').write_text(json.dumps(manifest))
            version.rename(version.with_name(manifest['fixtureVersion']))
            self.relink(root, f'versions/{manifest["fixtureVersion"]}')
        return self.tampered(name, mutate)

    def test_resealed_semantic_tampering_is_rejected(self):
        detail = 'responses/101/detail.html'

        def foreign_cover(version):
            path = version / detail
            path.write_text(path.read_text().replace('https://ehgt.org/w/101/cover.jpg', 'https://evil.example/c.jpg'))
            self.edit_manifest(version, lambda manifest: next(
                entry for entry in manifest['assets'] if entry['kind'] == 'cover' and entry['gid'] == '101')
                .update(url='https://evil.example/c.jpg'))

        def replace_text(old, new):
            def edit(version):
                path = version / detail
                path.write_text(path.read_text().replace(old, new))
            return edit

        def move_cover(version):
            (version / 'assets/101/cover.jpg').rename(version / 'assets/101/other.jpg')
            self.edit_manifest(version, lambda manifest: next(
                entry for entry in manifest['assets'] if entry['path'] == 'assets/101/cover.jpg')
                .update(path='assets/101/other.jpg'))
            manifest = json.loads((version / 'manifest.json').read_text())
            manifest['assets'].sort(key=lambda entry: entry['path'])
            (version / 'manifest.json').write_text(json.dumps(manifest))

        def link_identical_cover(version):
            # A link to another listed file with identical bytes stays inside the fixture and matches every checksum.
            cover = version / 'assets/102/cover.jpg'
            cover.unlink()
            os.symlink('../103/cover.jpg', cover)

        cases = {
            'symbolic link to identical bytes': (link_identical_cover, 'symbolic link'),
            'foreign host': (foreign_cover, 'not an allowed'),
            'unscrubbed secret': (replace_text('"000000000000000000"', f'"{APIKEY}"'), 'scrubbed form'),
            'account session': (replace_text('var apiuid = -1;', 'var apiuid = 4242;'), 'account session'),
            'unexpected location': (move_cover, 'unexpected location'),
        }
        for name, (edit, message) in cases.items():
            with self.subTest(name):
                with self.assertRaisesRegex(ValueError, message):
                    fixtures.validate_fixtures(self.resealed(name, edit))

    def test_untampered_fixture_validates(self):
        self.assertEqual(fixtures.validate_fixtures(self.tampered('none', lambda version, root: None)), self.manifest)

    def test_tampering_is_rejected(self):
        def flip(path):
            data = bytearray(path.read_bytes())
            data[-1] ^= 1
            path.write_bytes(bytes(data))

        def link_asset(version, root):
            outside = self.directory / 'elsewhere' / f'{root.name}.jpg'
            shutil.move(version / self.page, outside)
            os.symlink(outside, version / self.page)

        def move_version(version, root):
            # The moved directory keeps its version name and contents, so only the link check can reject it.
            outside = self.directory / 'elsewhere' / root.name / version.name
            outside.parent.mkdir()
            shutil.move(version, outside)
            os.symlink(outside, version)

        def rename_version(version, root):
            version.rename(version.with_name('marketing-0000000000000000'))
            self.relink(root, 'versions/marketing-0000000000000000')

        def first_page(manifest):
            return next(entry for entry in manifest['assets'] if entry['kind'] == 'page')

        def edit_selection(version, root):
            path = version / 'selection.json'
            path.write_text(path.read_text().replace('"owner"', '"agent-delegated"'))

        cases = {
            'checksum': lambda version, root: flip(version / self.page),
            'manifest hash': lambda version, root: self.edit_manifest(
                version, lambda manifest: manifest['assets'][0].update(sha256='0' * 64)),
            'unlisted file': lambda version, root: (version / 'assets/extra.jpg').write_bytes(JPEG),
            'symbolic link asset': link_asset,
            'selection': edit_selection,
            'missing asset': lambda version, root: (version / self.page).unlink(),
            'aggregate': lambda version, root: self.edit_manifest(
                version, lambda manifest: manifest.update(aggregateDigest='0' * 64)),
            'replay URL': lambda version, root: self.edit_manifest(
                version, lambda manifest: first_page(manifest).update(url='https://abcde.hath.network:1443/h/x/1.jpg')),
            'malformed entry': lambda version, root: self.edit_manifest(
                version, lambda manifest: first_page(manifest).update(index=[4])),
            'traversal': lambda version, root: self.edit_manifest(
                version, lambda manifest: manifest['assets'][0].update(path='../../outside.html')),
            'escaping current link': lambda version, root: self.relink(root, str(version)),
            'symbolic version directory': move_version,
            'renamed version': rename_version,
        }
        (self.directory / 'elsewhere').mkdir()
        for name, mutate in cases.items():
            with self.subTest(name):
                with self.assertRaises(ValueError):
                    fixtures.validate_fixtures(self.tampered(name, mutate))


class PublicationTests(FixtureTestCase):
    def test_second_writer_is_rejected_while_the_first_holds_the_output(self):
        site = Site(self.selection)
        with fixtures.Writer(self.output):
            with self.assertRaisesRegex(ValueError, 'Another fixture acquisition is writing'):
                self.acquire(site)
            self.assertEqual(site.calls, [])
        self.assert_unpublished()
        self.acquire(site)
        self.assertTrue((self.output / 'current').is_symlink())

    def test_second_writer_in_another_process_is_rejected(self):
        self.output.mkdir()
        lock = os.open(self.output / '.lock', os.O_RDWR | os.O_CREAT)
        self.addCleanup(os.close, lock)
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = subprocess.run(
            [sys.executable, '-B', str(ROOT / 'Scripts/visual/acquire-fixtures.py'),
             '--selection', str(self.write_selection()), '--output', str(self.output)],
            capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Another fixture acquisition is writing', result.stderr)
        self.assert_unpublished()

    def test_interruption_never_promotes_an_incomplete_directory(self):
        site = Site(self.selection)

        def interrupted(url):
            if len(site.calls) == 20:
                raise KeyboardInterrupt
            return site(url)
        with self.assertRaises(KeyboardInterrupt):
            self.acquirer.acquire(self.write_selection(), self.output, fetch=interrupted, clock=Clock())
        self.assertEqual(len(site.calls), 20)
        self.assert_unpublished()
        # A writer killed outright leaves its staging directory; the next writer removes it and never publishes it.
        stale = self.output / '.staging-killed'
        (stale / 'responses').mkdir(parents=True)
        (stale / 'responses/partial.html').write_text('<html>')
        target, _ = self.acquire()
        self.assertFalse(stale.exists())
        self.assertEqual(os.readlink(self.output / 'current'), f'versions/{target.name}')

    def test_output_inside_the_repository_must_be_ignored(self):
        unignored = ROOT / 'Scripts/visual/marketing-output-test'
        with self.assertRaisesRegex(ValueError, 'ignored'):
            self.acquirer.acquire(self.write_selection(), unignored, fetch=Site(self.selection), clock=Clock())
        self.assertFalse(unignored.exists())
        ignored = subprocess.run(['git', '-C', str(ROOT), 'check-ignore', '-q', '.capture/marketing/current'])
        self.assertEqual(ignored.returncode, 0)


class SavedResponseTests(unittest.TestCase):
    """The extraction mirrors the app parser on the repository's saved real responses."""

    def test_saved_detail_page(self):
        detail = fixtures.parse_detail((SAVED / 'Gallery/GalleryDetail.html').read_text())
        self.assertEqual(detail['cover'], 'https://ehgt.org/03/08/'
                         '0308268821e99628b05a19fa54e2fc0fa9ad8f4b-1705560-1012-1470-png_250.jpg')
        self.assertEqual((detail['pageCount'], detail['previewMode'], detail['previewCount']), (156, 'gt100', 40))
        self.assertEqual(sorted(detail['previews']), list(range(1, 41)))
        self.assertEqual(len(set(detail['previews'].values())), 2)
        self.assertEqual(detail['thumbnails'][1], 'https://e-hentai.org/mpv/3103480/0000000000/#page1')
        self.assertEqual(fixtures.batch_size(detail['previewMode'], detail['previewCount']), 40)
        with self.assertRaisesRegex(ValueError, 'multi-page viewer'):
            fixtures.reader_link(detail['thumbnails'], 1)

    def test_saved_reader_page(self):
        text = (SAVED / 'Gallery/GalleryNormalImageURL.html').read_text()
        image = fixtures.parse_image_page(text)
        self.assertTrue(image.startswith('https://akrtazd.spuqplybaxmf.hath.network:65000/h/'))
        self.assertIn('keystamp=1694132700-fd778f8260;', image)
        self.assertIn('keystamp=0000000000-0000000000;', fixtures.parse_image_page(fixtures.scrub(text)))
        self.assertEqual(fixtures.scrub(image), fixtures.parse_image_page(fixtures.scrub(text)))


if __name__ == '__main__':
    unittest.main()
