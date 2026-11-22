"""The heights tool: proposal from measuring runs, the canonical write into the view files, the read-back checks and
the export (19-20). The runs, inventory and provider files are synthetic and live in temporary directories; the pins
are the repository's own."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

import snapshot_heights
import snapshot_matrix

DEVICE = {('iphone', 'portrait'): 912, ('iphone', 'landscape'): 420, ('ipad', 'portrait'): 1210,
          ('ipad', 'landscape'): 834}


def scenario(identifier, rules=()):
    return {'id': identifier, 'group': 'home', 'plan': '19-05', 'state': 'A state', 'signedIn': True,
            'notApplicable': list(rules)}


def state(identifier, heights='heights: .screen,', imports=()):
    return f'''            SnapshotState(
                id: "{identifier}",
                {heights}
                factory: .init(make: {{ Page() }})
            )'''


def provider(*states, imports=('import AppModels',)):
    header = '\n'.join(imports) + '\n\n' if imports else ''
    return header + '''/// The snapshot states of a view.
enum PageViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
''' + ',\n'.join(states) + '''
        ]
    }
}
'''


def committed(per_device):
    """The canonical `heights:` argument for `{(family, orientation): (xSmall, large, accessibility5)}`."""
    rows = {key: ', '.join(f'{size}: {value}' for size, value in zip(snapshot_heights.SIZES, values))
            for key, values in per_device.items()}
    return f'''heights: .committed(
                    iphone: .init(
                        portrait: .init({rows[('iphone', 'portrait')]}),
                        landscape: .init({rows[('iphone', 'landscape')]})
                    ),
                    ipad: .init(
                        portrait: .init({rows[('ipad', 'portrait')]}),
                        landscape: .init({rows[('ipad', 'landscape')]})
                    )
                ),'''


class HeightsTestCase(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.sources = self.root / 'Snapshots'
        self.sources.mkdir()
        _, self.env = snapshot_matrix.load()
        # `de` is never captured on the iPad, so the iPad groups of `alpha` expect five languages.
        self.inventory = self.root / 'scenarios.json'
        self.document = {'schema': 2, 'scenarios': [
            scenario('alpha', [{'when': {'family': 'ipad', 'locale': 'de'}, 'reason': 'no German on the iPad'}]),
            scenario('beta')]}
        self.inventory.write_text(json.dumps(self.document))

    def lines(self, need, skip=(), status=None, scenarios=('alpha', 'beta')):
        """The `heights.jsonl` lines of a complete run: `need(coordinate)` for each expected coordinate."""
        found = {}
        for coordinate, reason in snapshot_matrix.coordinates(self.document, self.env):
            if coordinate.scenario not in scenarios or coordinate.key in skip:
                continue
            if reason:
                line = {'key': coordinate.key, 'status': 'notApplicable', 'neededPoints': None, 'reason': reason}
            else:
                line = {'key': coordinate.key, 'status': (status or {}).get(coordinate.key, 'measured'),
                        'neededPoints': need(coordinate), 'screenPoints': DEVICE[(coordinate.family,
                                                                                  coordinate.orientation)],
                        'steps': 1, 'reason': None}
            found[coordinate.key] = line
        return found

    def write(self, name, text):
        (self.sources / name).write_text(text)

    def read(self, name):
        return (self.sources / name).read_text()


class ProposeTests(HeightsTestCase):
    def test_the_tallest_need_over_languages_and_themes_is_rounded_up_and_never_under_the_device_height(self):
        def need(coordinate):
            if (coordinate.scenario, coordinate.family, coordinate.orientation, coordinate.size) \
                    == ('alpha', 'iphone', 'landscape', 'large'):
                return 633.4 if coordinate.locale == 'ja' and coordinate.theme == 'dark' else 500
            return 100  # under every device height
        heights, findings, missing = snapshot_heights.propose(self.lines(need), self.document, self.env)
        self.assertEqual((findings, missing), ([], []))
        self.assertEqual(heights['alpha']['iphone']['landscape'], {'xSmall': 420, 'large': 634, 'accessibility5': 420})
        self.assertEqual(heights['alpha']['iphone']['portrait'], dict.fromkeys(snapshot_heights.SIZES, 912))
        self.assertEqual(heights['beta']['ipad']['landscape'], dict.fromkeys(snapshot_heights.SIZES, 834))

    def test_a_group_with_an_expected_coordinate_missing_is_refused_by_name(self):
        gone = 'alpha__ko__large__portrait__iphone__dark'
        heights, _, missing = snapshot_heights.propose(self.lines(lambda _: 1000, skip=(gone,)), self.document,
                                                       self.env)
        self.assertEqual(missing, [gone])
        self.assertNotIn('large', heights['alpha']['iphone']['portrait'])
        out = self.root / 'proposal.json'
        run = self.root / 'run'
        run.mkdir()
        (run / 'heights.jsonl').write_text(''.join(json.dumps(line) + '\n' for line in
                                                   self.lines(lambda _: 1000, skip=(gone,)).values()))
        arguments = ['--inventory', str(self.inventory), 'propose', '--runs', str(run), '--out', str(out)]
        with contextlib.redirect_stderr(io.StringIO()) as stderr:
            self.assertEqual(snapshot_heights.main(arguments), 1)
        self.assertIn(gone, stderr.getvalue())
        self.assertFalse(out.exists())

    def test_a_coordinate_the_inventory_does_not_capture_is_not_missing(self):
        # `alpha` has no German iPad coordinate, so a run without one is complete.
        lines = self.lines(lambda _: 1000)
        self.assertNotIn('alpha__de__large__portrait__ipad__light', [key for key, line in lines.items()
                                                                      if line['status'] == 'measured'])
        _, _, missing = snapshot_heights.propose(lines, self.document, self.env)
        self.assertEqual(missing, [])

    def test_findings_are_listed_and_their_groups_get_no_value(self):
        stuck = 'beta__en__accessibility5__landscape__ipad__light'
        lines = self.lines(lambda _: 2000, status={stuck: 'cannot-cover'})
        lines[stuck]['reason'] = 'cannot-cover:UIScrollView'
        heights, findings, missing = snapshot_heights.propose(lines, self.document, self.env)
        self.assertEqual(missing, [])
        self.assertEqual(findings, [{'key': stuck, 'status': 'cannot-cover', 'reason': 'cannot-cover:UIScrollView'}])
        self.assertNotIn('accessibility5', heights['beta']['ipad']['landscape'])
        self.assertEqual(heights['beta']['ipad']['landscape']['large'], 2000)

    def test_a_later_line_replaces_an_earlier_one(self):
        first, second = self.root / 'first', self.root / 'second'
        first.mkdir()
        second.mkdir()
        key = 'beta__en__large__portrait__iphone__light'
        (first / 'heights.jsonl').write_text(json.dumps({'key': key, 'status': 'error'}) + '\n')
        (second / 'heights.jsonl').write_text(json.dumps({'key': key, 'status': 'measured', 'neededPoints': 1}) + '\n')
        self.assertEqual(snapshot_heights.read_runs([first, second])[key]['status'], 'measured')


class ApplyTests(HeightsTestCase):
    def proposal(self, alpha=1500, beta=None):
        def values(top):
            return {family: {orientation: dict.fromkeys(snapshot_heights.SIZES, top or DEVICE[(family, orientation)])
                             for orientation in snapshot_heights.ORIENTATIONS}
                    for family in snapshot_heights.FAMILIES}
        return {'heights': {'alpha': values(alpha), 'beta': values(beta)}, 'findings': []}

    def test_only_the_heights_argument_of_the_named_ids_is_rewritten_in_the_canonical_layout(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha'), state('beta')))
        before = self.read('AlphaViewSnapshot.swift')
        changed = snapshot_heights.apply(self.proposal(), ['alpha'], self.sources, self.document, self.env)
        self.assertEqual(changed, ['AlphaViewSnapshot.swift'])
        expected = provider(state('alpha', committed({key: (1500,) * 3 for key in DEVICE})), state('beta'),
                            imports=('import AppModels', 'import CoreGraphics'))
        self.assertEqual(self.read('AlphaViewSnapshot.swift'), expected)
        self.assertEqual(self.read('AlphaViewSnapshot.swift').replace('import CoreGraphics\n', '')
                         .count('factory: .init(make: { Page() })'), before.count('factory: .init(make: { Page() })'))

    def test_applying_twice_changes_nothing_more(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha'), state('beta')))
        snapshot_heights.apply(self.proposal(), [], self.sources, self.document, self.env)
        once = self.read('AlphaViewSnapshot.swift')
        self.assertEqual(snapshot_heights.apply(self.proposal(), [], self.sources, self.document, self.env), [])
        self.assertEqual(self.read('AlphaViewSnapshot.swift'), once)

    def test_a_scenario_whose_twelve_values_are_the_device_height_is_written_as_screen(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha', committed({key: (1500,) * 3 for key in DEVICE})),
                                                       state('beta'), imports=('import CoreGraphics',)))
        snapshot_heights.apply(self.proposal(alpha=None), [], self.sources, self.document, self.env)
        text = self.read('AlphaViewSnapshot.swift')
        self.assertEqual(text.count('heights: .screen,'), 2)
        self.assertNotIn('.committed', text)

    def test_core_graphics_is_added_in_module_order_among_the_imports(self):
        self.write('AlphaViewSnapshot.swift',
                   provider(state('alpha'), imports=('import AppModels', 'import Foundation')))
        snapshot_heights.apply(self.proposal(), ['alpha'], self.sources, self.document, self.env)
        self.assertTrue(self.read('AlphaViewSnapshot.swift').startswith(
            'import AppModels\nimport CoreGraphics\nimport Foundation\n\n'))
        self.write('BetaViewSnapshot.swift', provider(state('beta'), imports=()))
        proposal = self.proposal(beta=1500)
        snapshot_heights.apply(proposal, ['beta'], self.sources, self.document, self.env)
        self.assertTrue(self.read('BetaViewSnapshot.swift').startswith('import CoreGraphics\n\n/// The snapshot'))

    def test_a_scenario_without_a_value_in_its_group_is_refused_and_nothing_is_written(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha'), state('beta')))
        before = self.read('AlphaViewSnapshot.swift')
        partial = self.proposal()
        del partial['heights']['alpha']['ipad']['landscape']['accessibility5']
        with self.assertRaises(ValueError) as refused:
            snapshot_heights.apply(partial, [], self.sources, self.document, self.env)
        self.assertIn('alpha: no value for ipad landscape accessibility5', str(refused.exception))
        self.assertEqual(self.read('AlphaViewSnapshot.swift'), before)

    def test_a_value_under_the_device_height_or_not_whole_is_refused(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha'), state('beta')))
        under = self.proposal()
        under['heights']['alpha']['iphone']['portrait']['large'] = 900
        with self.assertRaises(ValueError):
            snapshot_heights.apply(under, ['alpha'], self.sources, self.document, self.env)
        fractional = self.proposal()
        fractional['heights']['alpha']['iphone']['portrait']['large'] = 1000.5
        with self.assertRaises(ValueError):
            snapshot_heights.apply(fractional, ['alpha'], self.sources, self.document, self.env)

    def test_an_id_in_no_provider_file_is_refused(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha')))
        with self.assertRaises(ValueError):
            snapshot_heights.apply(self.proposal(), ['beta'], self.sources, self.document, self.env)


class CheckSourcesTests(HeightsTestCase):
    def problems(self):
        return snapshot_heights.check_sources(self.sources, self.document, self.env)[1]

    def test_canonical_sources_with_the_inventorys_ids_pass(self):
        full = committed({('iphone', 'portrait'): (912, 912, 1000), ('iphone', 'landscape'): (420, 633, 850),
                          ('ipad', 'portrait'): (1210,) * 3, ('ipad', 'landscape'): (834, 834, 865)})
        self.write('AlphaViewSnapshot.swift', provider(state('alpha', full), state('beta'),
                                                       imports=('import CoreGraphics',)))
        self.assertEqual(self.problems(), [])

    def test_a_value_under_the_device_height_fails(self):
        low = committed({('iphone', 'portrait'): (912, 900, 912), ('iphone', 'landscape'): (420,) * 3,
                         ('ipad', 'portrait'): (1210,) * 3, ('ipad', 'landscape'): (834, 834, 800)})
        self.write('AlphaViewSnapshot.swift', provider(state('alpha', low), state('beta')))
        problems = self.problems()
        self.assertTrue(any('iphone portrait large is 900, under the device height 912' in item for item in problems))
        self.assertTrue(any('ipad landscape accessibility5 is 800' in item for item in problems))

    def test_a_non_integer_fails(self):
        fractional = committed({key: (DEVICE[key],) * 3 for key in DEVICE}).replace('1210', '1210.5', 1)
        self.write('AlphaViewSnapshot.swift', provider(state('alpha', fractional), state('beta')))
        self.assertTrue(any('1210.5 is not a whole number' in item for item in self.problems()))

    def test_a_literal_that_is_not_the_canonical_layout_fails(self):
        every = committed({key: (1500,) * 3 for key in DEVICE})
        for name, text in (('a CGFloat conversion', every.replace('xSmall: 1500', 'xSmall: CGFloat(1500)', 1)),
                           ('a different spacing', every.replace('large: 1500', 'large:  1500', 1)),
                           ('a committed literal of device heights',
                            committed({key: (DEVICE[key],) * 3 for key in DEVICE}))):
            with self.subTest(name):
                self.write('AlphaViewSnapshot.swift', provider(state('alpha', text), state('beta')))
                self.assertTrue(any('alpha: the heights literal is not the canonical layout' in item
                                    for item in self.problems()), self.problems())

    def test_a_duplicate_id_fails(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha'), state('beta')))
        self.write('BetaViewSnapshot.swift', provider(state('beta')))
        self.assertTrue(any(item.startswith('beta: declared twice') for item in self.problems()))

    def test_an_id_set_unlike_the_inventorys_fails(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha'), state('gamma')))
        problems = self.problems()
        self.assertIn('beta: in scenarios.json but in no provider file', problems)
        self.assertIn('gamma: in a provider file but not in scenarios.json', problems)

    def test_the_committed_tree_passes(self):
        document, env = snapshot_matrix.load()
        _, problems = snapshot_heights.check_sources(snapshot_heights.SNAPSHOTS, document, env)
        self.assertEqual(problems, [])


class ExportTests(HeightsTestCase):
    def test_screen_resolves_to_the_device_heights_and_committed_values_are_kept(self):
        full = committed({('iphone', 'portrait'): (912, 912, 1000), ('iphone', 'landscape'): (420, 633, 850),
                          ('ipad', 'portrait'): (1210,) * 3, ('ipad', 'landscape'): (834, 834, 865)})
        self.write('AlphaViewSnapshot.swift', provider(state('alpha', full), state('beta'),
                                                       imports=('import CoreGraphics',)))
        exported = snapshot_heights.export(self.sources, self.document, self.env)
        self.assertEqual(sorted(exported), ['alpha', 'beta'])
        self.assertEqual(exported['alpha']['iphone']['portrait'], {'xSmall': 912, 'large': 912, 'accessibility5': 1000})
        self.assertEqual(exported['alpha']['iphone']['landscape'], {'xSmall': 420, 'large': 633, 'accessibility5': 850})
        self.assertEqual(exported['beta']['ipad']['landscape'], dict.fromkeys(snapshot_heights.SIZES, 834))

    def test_sources_that_fail_the_checks_are_not_exported(self):
        self.write('AlphaViewSnapshot.swift', provider(state('alpha')))
        with self.assertRaises(ValueError):
            snapshot_heights.export(self.sources, self.document, self.env)


class CommittedTreeTests(unittest.TestCase):
    def test_check_sources_exits_zero_and_the_export_covers_every_scenario(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(snapshot_heights.main(['check-sources']), 0)
        document, env = snapshot_matrix.load()
        exported = snapshot_heights.export(snapshot_heights.SNAPSHOTS, document, env)
        self.assertEqual(len(exported), len(document['scenarios']))
        self.assertEqual(set(exported['settings-root']), {'iphone', 'ipad'})


if __name__ == '__main__':
    unittest.main()
