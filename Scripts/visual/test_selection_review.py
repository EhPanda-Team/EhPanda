"""Offline review of a real marketing fixture: traceability, composition and provisional-content contracts."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import fixtures
import test_fixtures as synthetic

ROOT = Path(__file__).resolve().parents[2]


def load_reviewer():
    spec = importlib.util.spec_from_file_location('selection_review', ROOT / 'Scripts/visual/selection-review.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def selection(prefix='1', scene_set='nonexplicit'):
    """The synthetic selection in a composition the review accepts: Live Text on the second hero gallery."""
    value = synthetic.selection(prefix, scene_set)
    value['scenes'][scene_set]['liveText']['gallery'] = f'{prefix}02'
    return value


def without(value, *gids):
    """A selection whose scenes no longer place `gids`, with those galleries undeclared."""
    value['galleries'] = [gallery for gallery in value['galleries']
                          if fixtures.GALLERY_URL.fullmatch(gallery['url'])[1] not in gids]
    return value


def reseal(current, edit):
    """Edit a published version's selection and recompute every digest, so only review semantics can object."""
    version = current.resolve()
    selection = json.loads((version / 'selection.json').read_text())
    edit(selection)
    data = json.dumps(selection, indent=2, sort_keys=True, ensure_ascii=False).encode() + b'\n'
    (version / 'selection.json').write_bytes(data)
    manifest = json.loads((version / 'manifest.json').read_text())
    manifest['selectionSHA256'] = hashlib.sha256(data).hexdigest()
    manifest['aggregateDigest'] = fixtures.version_identity(manifest['selectionSHA256'], manifest['assets'])
    manifest['fixtureVersion'] = f'marketing-{manifest["aggregateDigest"][:16]}'
    (version / 'manifest.json').write_text(json.dumps(manifest))
    version.rename(version.with_name(manifest['fixtureVersion']))
    current.unlink()
    os.symlink(f'versions/{manifest["fixtureVersion"]}', current)
    return current


class ReviewTestCase(unittest.TestCase):
    def setUp(self):
        self.acquirer = synthetic.load_acquirer()
        self.reviewer = load_reviewer()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.count = 0

    def publish(self, value=None, site=None):
        """Acquire `value` into a fresh output and return its `current` link."""
        value = selection() if value is None else value
        self.count += 1
        output = self.directory / f'marketing-{self.count}'
        path = self.directory / f'selection-{self.count}.json'
        path.write_text(json.dumps(value))
        self.acquirer.acquire(path, output, fetch=site or synthetic.Site(value), clock=synthetic.Clock())
        return output / 'current'

    def run_cli(self, current, name='review'):
        output = self.directory / name
        result = subprocess.run([sys.executable, '-B', str(ROOT / 'Scripts/visual/selection-review.py'),
                                 '--fixtures', str(current), '--output', str(output)],
                                capture_output=True, text=True, timeout=60)
        return result, output


class TraceabilityTests(ReviewTestCase):
    def test_every_visible_gallery_page_and_comment_traces_to_the_selection(self):
        value = selection()
        current = self.publish(value)
        result, output = self.run_cli(current)
        self.assertEqual(result.returncode, 0, result.stderr)
        ledger = json.loads((output / 'review.json').read_text())
        manifest = fixtures.validate_fixtures(current)
        self.assertTrue(ledger['valid'])
        self.assertEqual(ledger['fixture']['fixtureVersion'], manifest['fixtureVersion'])
        self.assertEqual(ledger['selection'], {'selectionID': 'marketing-test', 'selectionStatus': 'provisional',
                                               'selectionAuthority': 'owner'})
        scene = ledger['sets']['nonexplicit']
        expected = fixtures.screen_occurrences(value['scenes']['nonexplicit'])
        self.assertEqual(sorted(scene['screens']), sorted(fixtures.SCREENS))
        version = current.resolve()
        declared = {gallery['url'] for gallery in value['galleries']}
        for screen, rows in expected.items():
            self.assertEqual([(row['section'], row['slot'], row['gid']) for row in scene['screens'][screen]], rows)
            for row in scene['screens'][screen]:
                self.assertIn(row['url'], declared)
                self.assertTrue((version / row['cover']).is_file())
                self.assertEqual(row['title'], f'Gallery {row["gid"]}')
        self.assertEqual(scene['screens']['filters'], [])
        self.assertEqual(scene['screens']['laboratory'], [])
        self.assertEqual([page['page'] for page in scene['flow']['pages']], [3, 4, 5])
        for page in scene['flow']['pages']:
            self.assertTrue((version / page['image']).is_file())
        self.assertEqual(scene['flow']['readerPage'], 4)
        self.assertEqual((scene['liveText']['gallery'], scene['liveText']['page']), ('102', 4))
        self.assertEqual(scene['liveText']['language'], {'name': 'English', 'translated': False})
        self.assertEqual([page['page'] for page in scene['liveText']['pages']], [3, 4, 5])
        for page in scene['liveText']['pages']:
            self.assertTrue((version / page['image']).is_file())
        self.assertEqual(scene['comments'], [{'commentID': '1', 'author': 'Reader', 'posted': '01 January 2024, 00:00',
                                              'text': 'A readable comment.'}])
        self.assertEqual(scene['home']['frontpagePairs'], [['104', '105']])
        self.assertEqual(ledger['unresolvedInputs'], [
            'explicit: no scene declared (galleries, Home slots, flow and Live Text galleries and pages, downloads)',
            'final selection: the active selection is provisional with owner authority; '
            'closure needs a final owner selection'])
        self.assertIn('17-21', ledger['closureCheckpoint'])
        self.assertTrue(ledger['approval'].startswith('none'))

    def test_review_output_ignores_itself_and_references_images_in_place(self):
        current = self.publish()
        result, output = self.run_cli(current)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sorted(path.name for path in output.iterdir()), ['.gitignore', 'review.html', 'review.json'])
        self.assertEqual((output / '.gitignore').read_text(), '*\n')
        page = (output / 'review.html').read_text()
        relative = os.path.relpath(current.resolve(), output)
        self.assertIn(f'src="{relative}/assets/101/cover.jpg"', page)
        self.assertIn(f'src="{relative}/assets/101/pages/4.jpg"', page)
        self.assertIn(f'src="{relative}/assets/102/pages/4.jpg"', page)
        for label in ['hero[1] 102 Gallery 102', 'page 3</figcaption>', 'page 4 (reader)', '102 Gallery 102 (English)',
                      'page 4 (Live Text)',
                      'downloads[0] 104 active 12/60 Gallery 104', 'downloads[1] 105 completed 60/60 Gallery 105',
                      'A readable comment.', 'Unresolved final inputs', '17-21']:
            self.assertIn(label, page)

    def test_existing_output_is_never_overwritten(self):
        current = self.publish()
        output = self.directory / 'review'
        output.mkdir()
        (output / 'keep.txt').write_text('kept')
        result, _ = self.run_cli(current)
        self.assertEqual(result.returncode, 1)
        self.assertIn('already exists', result.stderr)
        self.assertEqual([path.name for path in output.iterdir()], ['keep.txt'])

    def test_both_sets_are_reviewed_and_only_finality_remains_unresolved(self):
        value = selection()
        other = selection('2', 'explicit')
        value['galleries'] += other['galleries']
        value['scenes'].update(other['scenes'])
        value.update(selectionStatus='final')
        ledger = self.reviewer.review(self.publish(value))
        self.assertEqual(sorted(ledger['sets']), ['explicit', 'nonexplicit'])
        self.assertTrue(ledger['valid'])
        self.assertEqual(ledger['unresolvedInputs'], [])


class SavedResponseTests(unittest.TestCase):
    def test_saved_comments_match_the_app_parser(self):
        # GalleryDetailParserTests expects 10 comments on this saved page, the uploader's comment 0 first.
        page = (ROOT / 'AppPackage/Sources/TestingSupport/Resources/Parser/Gallery/GalleryDetail.html').read_text()
        rows = load_reviewer().comments(fixtures.parse_html(page))
        self.assertEqual(len(rows), 10)
        self.assertEqual(rows[0]['commentID'], '0')
        self.assertTrue(all(row['author'] and row['posted'] and row['text'] for row in rows))


class AdjacencyTests(ReviewTestCase):
    def test_reuse_across_screens_is_valid(self):
        scene = self.reviewer.review(self.publish())['sets']['nonexplicit']['screens']
        self.assertIn('101', [row['gid'] for row in scene['home']])
        for screen in ('detail', 'comments', 'reading'):
            self.assertEqual([row['gid'] for row in scene[screen]], ['101'])
        self.assertEqual([row['gid'] for row in scene['reading-live-text']], ['102'])
        self.assertEqual([row['gid'] for row in scene['downloads']], ['104', '105'])

    def test_repeated_gallery_within_one_screen_is_rejected(self):
        for name, edit in [('home sections', lambda scene: scene['home']['toplists']['yesterday'].append('101')),
                           ('downloads', lambda scene: scene['downloads'].append(
                               {'gallery': '104', 'status': 'completed'}))]:
            with self.subTest(name):
                current = reseal(self.publish(), lambda value: edit(value['scenes']['nonexplicit']))
                with self.assertRaisesRegex(ValueError, 'repeats gallery'):
                    self.reviewer.review(current)


class EmptyTests(ReviewTestCase):
    def test_empty_selection_and_missing_assets_fail_explicitly(self):
        current = reseal(self.publish(), lambda value: value.update(galleries=[]))
        with self.assertRaisesRegex(ValueError, 'Empty selection'):
            self.reviewer.review(current)
        current = self.publish()
        (current.resolve() / 'assets/101/pages/4.jpg').unlink()
        with self.assertRaisesRegex(ValueError, 'missing'):
            self.reviewer.review(current)
        result, output = self.run_cli(self.directory / 'unpublished' / 'current')
        self.assertEqual(result.returncode, 1)
        self.assertFalse(output.exists())

    def test_one_item_and_odd_scenes_cannot_populate_the_composition(self):
        def scene(value):
            return value['scenes']['nonexplicit']

        def hero(value):
            scene(value)['home']['hero'] = {'galleries': ['101'], 'selectedIndex': 0}
            # 102 stays declared: it is still the Live Text gallery.
            return without(value, '103')

        def edge_hero(value):
            scene(value)['home']['hero']['selectedIndex'] = 0
            return value

        def one_frontpage(value):
            # 105 stays declared: it is still a download.
            scene(value)['home']['frontpage'] = ['104']
            return value

        def odd_frontpage(value):
            scene(value)['home']['frontpage'].append('118')
            value['galleries'].append({'url': synthetic.gallery_url('118'), 'set': 'nonexplicit'})
            return value

        def toplists(value):
            for gids in scene(value)['home']['toplists'].values():
                del gids[1:]
            return without(value, '107', '108', '110', '111', '113', '114', '116', '117')

        def downloads(value):
            del scene(value)['downloads'][1:]
            return value

        def flow_live_text(value):
            scene(value)['liveText']['gallery'] = '101'
            return value

        hero_problem = 'home hero needs at least three galleries with a neighbor on each side of selectedIndex'
        cases = [
            ('one hero gallery', hero, [hero_problem]),
            ('hero edge selection', edge_hero, [hero_problem]),
            ('one frontpage gallery', one_frontpage, ['home frontpage needs an even count of at least two; it has 1']),
            ('odd frontpage', odd_frontpage, ['home frontpage needs an even count of at least two; it has 3']),
            ('one toplists gallery', toplists, [f'home toplists {period} needs at least three galleries; it has 1'
                                                for period in fixtures.TOPLISTS]),
            ('one download', downloads, ['downloads needs at least two items; it has 1']),
            ('Live Text on the flow gallery', flow_live_text,
             ['Live Text gallery 101 must be another gallery than the flow gallery']),
        ]
        for name, edit, expected in cases:
            with self.subTest(name):
                current = self.publish(edit(selection()))
                result, output = self.run_cli(current, name.replace(' ', '-'))
                self.assertEqual(result.returncode, 1)
                ledger = json.loads((output / 'review.json').read_text())
                self.assertFalse(ledger['valid'])
                self.assertEqual(ledger['sets']['nonexplicit']['problems'], expected)
                self.assertEqual(result.stderr.splitlines(), [f'nonexplicit: {problem}' for problem in expected])

    def test_the_live_text_gallery_must_be_an_english_original(self):
        translated = ('English &nbsp;<span class="halp" title="This gallery has been translated from the original '
                      'language text.">TR</span>')
        for language, described in [(translated, 'a translation into English'), ('Japanese &nbsp;', 'Japanese')]:
            with self.subTest(described):
                value = selection()
                site = synthetic.Site(value)
                site.html(synthetic.gallery_url('102') + '?hc=1', synthetic.detail_html('102', language=language))
                problems = self.reviewer.review(self.publish(value, site))['sets']['nonexplicit']['problems']
                self.assertEqual(problems, [f'Live Text gallery 102 must be an English original, not {described}'])

    def test_unreadable_comments_are_reported(self):
        value = selection()
        site = synthetic.Site(value)
        url = synthetic.gallery_url('101') + '?hc=1'
        site.html(url, synthetic.detail_html('101').replace('A readable comment.', ''))
        problems = self.reviewer.review(self.publish(value, site))['sets']['nonexplicit']['problems']
        self.assertEqual(problems, ['comments gallery 101 has no readable saved comment'])


class OrderingTests(ReviewTestCase):
    def test_equal_ranking_values_keep_the_configured_order(self):
        value = selection()
        scene = value['scenes']['nonexplicit']
        scene['downloads'] = [{'gallery': '104', 'status': 'completed'}, {'gallery': '101', 'status': 'completed'}]
        scene['home']['toplists']['allTime'] = ['117', '115', '116']
        site = synthetic.Site(value)
        for gid in ('115', '116', '117'):
            site.html(synthetic.gallery_url(gid) + '?hc=1', synthetic.detail_html(gid, title='Equal ranking'))
        ledger = self.reviewer.review(self.publish(value, site))
        reviewed = ledger['sets']['nonexplicit']
        self.assertTrue(ledger['valid'])
        self.assertEqual([entry['gallery'] for entry in reviewed['downloads']], ['104', '101'])
        self.assertEqual([entry['displayPriority'] for entry in reviewed['downloads']], [5, 5])
        self.assertEqual(reviewed['home']['toplists']['allTime'],
                         [{'ranking': 1, 'gid': '117'}, {'ranking': 2, 'gid': '115'}, {'ranking': 3, 'gid': '116'}])

    def test_order_the_app_would_change_is_invalid(self):
        value = selection()
        value['scenes']['nonexplicit']['downloads'].reverse()
        problems = self.reviewer.review(self.publish(value))['sets']['nonexplicit']['problems']
        self.assertEqual(problems, ['downloads order is not a display order: the app lists statuses by priority, '
                                    'so it would reorder completed, active'])

    def test_review_is_deterministic_and_tracks_the_fixture_version(self):
        current = self.publish()
        first, first_output = self.run_cli(current, 'first')
        second, second_output = self.run_cli(current, 'second')
        self.assertEqual((first.returncode, second.returncode), (0, 0))
        for name in ('review.json', 'review.html'):
            self.assertEqual((first_output / name).read_bytes(), (second_output / name).read_bytes())
        swapped = selection()
        swapped['scenes']['nonexplicit']['home']['frontpage'].reverse()
        other = self.reviewer.review(self.publish(swapped))
        original = json.loads((first_output / 'review.json').read_text())
        self.assertNotEqual(other['fixture']['fixtureVersion'], original['fixture']['fixtureVersion'])
        self.assertEqual(other['sets']['nonexplicit']['home']['frontpagePairs'], [['105', '104']])


class ConcurrencyTests(ReviewTestCase):
    def test_review_reads_the_published_version_while_a_writer_holds_the_output(self):
        current = self.publish()
        published = fixtures.validate_fixtures(current)['fixtureVersion']
        with fixtures.Writer(current.parent) as writer:
            (writer.staging / 'manifest.json').write_text('{}')
            self.assertEqual(self.reviewer.review(current)['fixture']['fixtureVersion'], published)
            with self.assertRaises(ValueError):
                self.reviewer.review(writer.staging)

    def moving_current(self, current):
        """Validation whose first run is followed at once by a publication that repoints `current`."""
        swapped = selection()
        swapped['scenes']['nonexplicit']['home']['frontpage'].reverse()
        path = self.directory / f'swapped-{current.parent.name}.json'
        path.write_text(json.dumps(swapped))
        verify, moved = fixtures.verify_contents, []

        def verify_then_publish(directory):
            manifest = verify(directory)
            if not moved:
                moved.append(directory)
                self.acquirer.acquire(path, current.parent, refresh=True, fetch=synthetic.Site(swapped),
                                      clock=synthetic.Clock())
            return manifest
        return patch.object(fixtures, 'verify_contents', verify_then_publish)

    def test_review_reads_one_version_while_a_publication_moves_current(self):
        current = self.publish()
        first = current.resolve()
        with self.moving_current(current):
            ledger = self.reviewer.review(current)
        self.assertNotEqual(current.resolve(), first)
        self.assertEqual(ledger['fixture']['fixtureVersion'], first.name)
        self.assertEqual(ledger['sets']['nonexplicit']['home']['frontpagePairs'], [['104', '105']])
        # The command line review also keeps the contact sheet on the version its ledger describes.
        current = self.publish()
        first = current.resolve()
        output = self.directory / 'review'
        arguments = ['selection-review.py', '--fixtures', str(current), '--output', str(output)]
        with self.moving_current(current), patch.object(sys, 'argv', arguments), \
                contextlib.redirect_stdout(io.StringIO()):
            self.reviewer.main()
        self.assertNotEqual(current.resolve(), first)
        self.assertEqual(json.loads((output / 'review.json').read_text())['fixture']['fixtureVersion'], first.name)
        page = (output / 'review.html').read_text()
        self.assertIn(f'src="{os.path.relpath(first, output)}/assets/101/cover.jpg"', page)

    def test_interrupted_acquisition_leaves_nothing_to_review(self):
        value = selection()
        site = synthetic.Site(value)

        def interrupted(url):
            if len(site.calls) == 10:
                raise KeyboardInterrupt
            return site(url)
        path = self.directory / 'selection.json'
        path.write_text(json.dumps(value))
        output = self.directory / 'interrupted'
        with self.assertRaises(KeyboardInterrupt):
            self.acquirer.acquire(path, output, fetch=interrupted, clock=synthetic.Clock())
        result, review = self.run_cli(output / 'current')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Selection review failed', result.stderr)
        self.assertFalse(review.exists())
        self.assertEqual(list(output.glob('.staging-*')), [])


if __name__ == '__main__':
    unittest.main()
