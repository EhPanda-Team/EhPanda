"""The pre-check's machine checks and contact-sheet plan (19-13 Task 1; 19-CONTEXT D-17).

The probe's output is synthetic here, so the checks run without Vision or a Swift toolchain; the string catalogs
and parser pages are small stand-ins written per test.
"""
import json
import math
from pathlib import Path
import tempfile
import unittest

import snapshot_precheck


def key(scenario='home-populated', locale='en', size='large', orientation='portrait', family='iphone',
        theme='light'):
    return '__'.join((scenario, locale, size, orientation, family, theme))


def probe(lines=(), deviation=40.0, share=0.5, rectangles=(), width=420, height=912):
    return {'width': width, 'height': height, 'lumaDeviation': deviation, 'dominantShare': share,
            'grayRectangles': list(rectangles), 'lines': [{'text': text, 'confidence': 1, 'box': [0, 0, 1, 1]}
                                                          for text in lines]}


class CheckTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        catalog = {'sourceLanguage': 'en', 'strings': {
            'favorites': {'localizations': {'en': {'stringUnit': {'value': 'Favorites'}},
                                            'ja': {'stringUnit': {'value': 'お気に入り'}}}},
            'search': {'localizations': {'en': {'stringUnit': {'value': 'Search…'}},
                                         'ja': {'stringUnit': {'value': '検索…'}}}},
            'name': {'shouldTranslate': False, 'localizations': {'en': {'stringUnit': {'value': 'EhPanda'}},
                                                                 'ja': {'stringUnit': {'value': 'EhPanda'}}}},
            'count': {'localizations': {'en': {'stringUnit': {'value': '%lld pages'}},
                                        'ja': {'stringUnit': {'value': '%lldページ'}}}}}}
        (self.root / 'Sources/Module').mkdir(parents=True)
        (self.root / 'Sources/Module/Localizable.xcstrings').write_text(json.dumps(catalog))
        (self.root / 'Parser').mkdir()
        (self.root / 'Parser/List.html').write_text(
            '<div class="glink">[Real Circle] A Real Gallery Title &amp; More</div><div class="glink">Short</div>')
        self.strings = snapshot_precheck.catalog_strings(self.root / 'Sources')
        self.markers = snapshot_precheck.fixture_markers(self.root / 'Parser')

    def run_checks(self, probes, digests=None, sizes=None):
        digests = digests or {name: f'digest-{name}' for name in probes}
        sizes = sizes or {name: 1000 for name in probes}
        return snapshot_precheck.check({name: Path(name) for name in probes}, probes, digests, sizes, self.strings,
                                       self.markers)

    def names(self, flags, name):
        return [entry[0] for entry in flags.get(name, [])]

    def test_catalog_strings_collect_values_and_translated_english(self):
        values, translated = self.strings
        self.assertIn('お気に入り', values['ja'])
        self.assertIn('Favorites', translated['ja'])
        self.assertNotIn('EhPanda', translated['ja'])
        self.assertNotIn('%lld pages', translated['ja'])

    def test_fixture_markers_keep_long_real_titles(self):
        self.assertEqual(self.markers, {'[real circle] a real gallery title & more'})

    def test_a_uniform_picture_is_flagged(self):
        flat, mostly, normal = key(scenario='flat'), key(scenario='mostly'), key(scenario='normal')
        flags = self.run_checks({flat: probe(deviation=0.4), mostly: probe(share=0.999), normal: probe()})
        self.assertEqual(self.names(flags, flat), ['uniform'])
        self.assertEqual(self.names(flags, mostly), ['uniform'])
        self.assertNotIn(normal, flags)

    def test_a_placeholder_of_the_pictures_theme_is_flagged(self):
        light, dark, full = key(theme='light'), key(scenario='other', theme='dark'), key(scenario='full')
        placeholder = {'x': 10, 'y': 20, 'width': 80, 'height': 113, 'color': 'systemGray5-light'}
        flags = self.run_checks({
            light: probe(rectangles=[placeholder]),
            dark: probe(rectangles=[placeholder]),
            full: probe(rectangles=[{**placeholder, 'width': 420, 'height': 900}])})
        self.assertEqual(self.names(flags, light), ['placeholder'])
        self.assertNotIn(dark, flags)
        self.assertNotIn(full, flags)

    def test_a_size_outlier_is_flagged_against_the_same_screen_in_other_languages(self):
        names = [key(locale=locale) for locale in ('en', 'de', 'ja', 'ko', 'zh-Hans', 'zh-Hant')]
        sizes = dict.fromkeys(names, 100_000)
        sizes[names[2]] = 30_000
        flags = self.run_checks({name: probe() for name in names}, sizes=sizes)
        self.assertEqual([name for name in names if name in flags], [names[2]])
        self.assertEqual(self.names(flags, names[2]), ['size-outlier'])

    def test_two_states_with_the_same_picture_are_flagged(self):
        loading, populated, other = key(scenario='home-loading'), key(), key(scenario='settings')
        flags = self.run_checks({loading: probe(), populated: probe(), other: probe()},
                                digests={loading: 'same', populated: 'same', other: 'different'})
        self.assertEqual(flags[loading], [('same-as', 'home-populated')])
        self.assertEqual(flags[populated], [('same-as', 'home-loading')])
        self.assertNotIn(other, flags)

    def test_identical_light_and_dark_pictures_are_flagged(self):
        light, dark = key(theme='light'), key(theme='dark')
        flags = self.run_checks({light: probe(), dark: probe()}, digests={light: 'same', dark: 'same'})
        self.assertEqual(self.names(flags, light), ['same-in-both-themes'])
        self.assertEqual(self.names(flags, dark), ['same-in-both-themes'])

    def test_truncated_text_is_flagged_unless_it_is_a_catalog_string(self):
        name = key()
        flags = self.run_checks({name: probe(lines=['Visual Home Gallery with a long tit…', 'Search…'])})
        self.assertEqual(flags[name], [('truncated', 'Visual Home Gallery with a long tit…')])

    def test_english_text_in_a_japanese_picture_is_flagged_but_not_in_an_english_one(self):
        japanese, english = key(locale='ja'), key(locale='en')
        flags = self.run_checks({japanese: probe(lines=['Favorites', 'EhPanda']),
                                 english: probe(lines=['Favorites', 'EhPanda'])})
        self.assertEqual(flags[japanese], [('untranslated', 'Favorites')])
        self.assertNotIn(english, flags)

    def test_english_text_from_a_fixture_is_not_untranslated(self):
        source = self.root / 'Fixtures/GalleryFixtures.swift'
        source.parent.mkdir()
        source.write_text('let folder = "Visual Favorites \\(index) Folder"\nlet empty = ""\n')
        fixtures = snapshot_precheck.fixture_strings([source.parent])
        self.assertEqual(fixtures, {'visual favorites', 'folder'})
        name = key(locale='ja')
        flags = snapshot_precheck.check({name: Path(name)}, {name: probe(lines=['Favorites'])}, {name: 'd'},
                                        {name: 1}, self.strings, self.markers, fixtures)
        self.assertNotIn(name, flags)

    def test_real_content_is_flagged(self):
        name = key()
        flags = self.run_checks({name: probe(lines=['A Real Gallery Title & More', 'Visual Home Gallery 1'])})
        self.assertEqual(flags[name], [('real-content', 'A Real Gallery Title & More')])

    def test_an_unreadable_picture_is_flagged(self):
        name = key()
        flags = self.run_checks({name: {'error': 'unreadable'}})
        self.assertEqual(flags[name], [('unreadable', 'unreadable')])

    def test_the_sheet_plan_shows_every_picture_once_sixteen_a_sheet_in_slice_order(self):
        names = [key(scenario=f's{number:02d}', locale=locale) for number in range(20)
                 for locale in ('ja', 'en')]
        sheets = snapshot_precheck.sheet_plan(names)
        self.assertEqual(len(sheets), math.ceil(len(names) / 16))
        shown = [name for keys in sheets.values() for name in keys]
        self.assertEqual(sorted(shown), sorted(names))
        self.assertTrue(all(name.split('__')[1] == 'en' for name in shown[:20]))
        self.assertEqual(list(sheets)[0], 'sheet-0001.png')
        self.assertEqual(snapshot_precheck.tile_label(3, names[0]), '3 s00 portrait-light\niphone/ja/large')

    def test_a_file_outside_the_layout_is_refused(self):
        pictures = self.root / 'pictures'
        (pictures / 'iphone/en/large/home').mkdir(parents=True)
        (pictures / 'iphone/en/large/home/portrait-light.png').write_bytes(b'png')
        (pictures / 'stray.png').write_bytes(b'png')
        with self.assertRaises(ValueError):
            snapshot_precheck.pictures_of(pictures)


if __name__ == '__main__':
    unittest.main()
