"""The snapshot gate's static offline report and the owner's short packet (19-09)."""
import contextlib
from html.parser import HTMLParser
import io
import json
from pathlib import Path
import re
import tempfile
import unittest

import snapshot_report

SCENARIOS = {
    'home-populated': {'group': 'home', 'state': 'Populated', 'notApplicable': []},
    'library-sidebar': {'group': 'library', 'state': 'Sidebar',
                        'notApplicable': [{'when': {'widthClass': 'compact'}, 'reason': 'Needs a regular width.'}]},
}


class Tags(HTMLParser):
    """Every start tag with its attributes."""

    def __init__(self):
        super().__init__()
        self.tags = []

    def handle_starttag(self, tag, attrs):
        self.tags.append((tag, dict(attrs)))


def key(scenario, locale='en', size='large', orientation='portrait', family='iphone', theme='light'):
    return '__'.join((scenario, locale, size, orientation, family, theme))


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.shard = self.root / 'results/s01'
        self.baseline = self.root / 'baseline'
        self.out = self.root / 'report'

    def tearDown(self):
        self.directory.cleanup()

    def picture(self, base, key_value):
        path = base / snapshot_report.relative_path(key_value)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'png')

    def document(self, results, flaky=(), items=None):
        rows = [{'key': key_value, 'status': status, 'shard': 's01', 'attempts': 1, 'flaky': False,
                 'seconds': 1.0} for key_value, status in results]
        classes = {'pictureChanges': [], 'infrastructureErrors': [], 'drift': [], 'baselineMismatches': []}
        classes.update(items or {})
        return {'schema': 1, 'counts': {name: len(entries) for name, entries in classes.items()}, 'items': classes,
                'flaky': list(flaky), 'shards': {'s01': {'attempt': 1, 'infra': None, 'directory': str(self.shard)}},
                'statusCounts': {}, 'results': rows, 'scenarios': SCENARIOS,
                'environment': {'xcode': 'Build version 27A266a', 'runtime': '27.0', 'runtimeBuild': '24A434',
                                'devices': {'iphone': 'iPhone Air', 'ipad': 'iPad Pro 11-inch (M5)'}}}

    def page(self):
        return (self.out / 'index.html').read_text()

    def tags(self):
        parser = Tags()
        parser.feed(self.page())
        return parser.tags

    def test_page_loads_nothing_from_the_network(self):
        changed = key('home-populated')
        for base in (self.baseline, self.shard / 'actual', self.shard / 'difference'):
            self.picture(base, changed)
        snapshot_report.render(self.document([(changed, 'changed')]), self.baseline, self.out)
        page = self.page()
        self.assertNotIn('<link', page)
        self.assertIsNone(re.search(r'<script[^>]*\bsrc=', page))
        for tag, attributes in self.tags():
            for name in ('src', 'href'):
                value = attributes.get(name) or ''
                self.assertNotRegex(value, r'^(https?:)?//', f'{tag} {name}={value}')
        self.assertNotRegex(page, r'https?://')

    def test_filters_cover_the_five_axes_with_an_inline_script(self):
        rows = [(key('home-populated', locale=locale, theme=theme), 'recorded')
                for locale in ('en', 'ja') for theme in ('light', 'dark')]
        snapshot_report.render(self.document(rows), None, self.out)
        tags = self.tags()
        axes = [attributes['data-axis'] for tag, attributes in tags if tag == 'select']
        self.assertEqual(axes, ['locale', 'size', 'device', 'orientation', 'appearance'])
        row = next(attributes for tag, attributes in tags
                   if attributes.get('data-key') == key('home-populated', locale='ja', theme='dark'))
        self.assertEqual((row['data-locale'], row['data-size'], row['data-device'], row['data-orientation'],
                          row['data-appearance']), ('ja', 'large', 'iphone', 'portrait', 'dark'))
        self.assertIn('row.hidden', self.page())
        self.assertEqual([attributes for tag, attributes in tags if tag == 'script'], [{}])

    def test_failing_coordinate_shows_baseline_actual_and_difference_inside_the_report(self):
        changed, passed = key('home-populated', theme='dark'), key('home-populated')
        for base in (self.baseline, self.shard / 'actual', self.shard / 'difference'):
            self.picture(base, changed)
        shown = snapshot_report.render(self.document([(changed, 'changed'), (passed, 'passed')]),
                                       self.baseline, self.out)
        self.assertEqual(shown, [changed])
        sources = [attributes['src'] for tag, attributes in self.tags() if tag == 'img']
        path = snapshot_report.relative_path(changed)
        self.assertEqual(sources, [f'img/baseline/{path}', f'img/actual/{path}', f'img/difference/{path}'])
        for source in sources:
            self.assertTrue((self.out / source).is_file())
        self.assertEqual(sorted(str(p.relative_to(self.out)) for p in self.out.rglob('*.png')), sorted(sources))

    def test_packet_takes_one_picture_per_scenario_plus_flags_and_lists_rules(self):
        home = [key('home-populated', locale=locale, size=size, orientation=orientation, family=family, theme=theme)
                for locale in ('en', 'de') for size in ('xSmall', 'large') for orientation in ('portrait', 'landscape')
                for family in ('iphone', 'ipad') for theme in ('light', 'dark')]
        # The sidebar is not applicable on an upright iPhone, so its first captured coordinate in axis order
        # (locale, size, orientation, device, appearance) is en-xSmall portrait iPad light.
        sidebar = [row for row in (value.replace('home-populated', 'library-sidebar') for value in home)
                   if '__portrait__iphone__' not in row]
        for value in home + sidebar:
            self.picture(self.shard, value)
        flagged = key('home-populated', locale='de', theme='dark')
        shown = snapshot_report.render(self.document([(value, 'recorded') for value in home + sidebar]), None,
                                       self.out, packet=True, flags={flagged: 'Text clipped.'})
        self.assertEqual(shown, [key('home-populated'), flagged,
                                 key('library-sidebar', size='xSmall', family='ipad')])
        page = self.page()
        self.assertIn('Flagged: Text clipped.', page)
        self.assertIn('Needs a regular width.', page)
        self.assertIn('widthClass=compact', page)
        self.assertEqual(len(list(self.out.rglob('*.png'))), 3)

    def test_flake_log_and_infrastructure_items_are_listed(self):
        flaky = {'key': key('home-populated'), 'shard': 's01', 'seconds': 2.5, 'attempts': 2}
        lost = {'shard': 's02', 'kind': 'runner-lost', 'detail': 'no artifact'}
        snapshot_report.render(self.document([(key('home-populated'), 'passed')], flaky=[flaky],
                                             items={'infrastructureErrors': [lost]}), None, self.out)
        page = self.page()
        self.assertIn(f'<code>{key("home-populated")}</code></td><td>2.50</td><td>2</td>', page)
        self.assertIn('runner-lost', page)
        self.assertIn('1 infrastructure errors', page)


    def test_command_line_writes_the_report_from_an_aggregate_file(self):
        (self.root / 'aggregate.json').write_text(json.dumps(self.document([])))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = snapshot_report.main(['--aggregate', str(self.root / 'aggregate.json'), '--out', str(self.out)])
        self.assertEqual(code, 0)
        self.assertIn('0 coordinates', output.getvalue())
        self.assertIn('No picture to review.', self.page())


if __name__ == '__main__':
    unittest.main()
