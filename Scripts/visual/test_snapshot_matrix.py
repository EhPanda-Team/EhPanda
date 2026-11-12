"""The Phase 19 coordinate space, its not-applicable rules and its totals (19-02)."""
import unittest

import snapshot_matrix

# The same samples as HostedWindowCaptureTests.testCoordinateKeyAndBaselinePathMatchTheContract (Swift).
SWIFT_SAMPLES = [
    (('home-populated', 'en', 'large', 'portrait', 'iphone', 'light'),
     'home-populated__en__large__portrait__iphone__light', 'iphone/en/large/home-populated/portrait-light.png'),
    (('report-form-sending', 'zh-Hant', 'accessibility5', 'landscape', 'ipad', 'dark'),
     'report-form-sending__zh-Hant__accessibility5__landscape__ipad__dark',
     'ipad/zh-Hant/accessibility5/report-form-sending/landscape-dark.png'),
    (('agewall-unticked', 'de', 'xSmall', 'portrait', 'ipad', 'light'),
     'agewall-unticked__de__xSmall__portrait__ipad__light', 'ipad/de/xSmall/agewall-unticked/portrait-light.png'),
]


def scenario(identifier, rules=()):
    return {'id': identifier, 'group': 'home', 'plan': '19-05', 'state': 'A state', 'signedIn': True,
            'notApplicable': list(rules)}


class SnapshotMatrixTests(unittest.TestCase):
    def setUp(self):
        self.document, self.env = snapshot_matrix.load()

    def test_key_and_path_match_the_swift_samples(self):
        for values, key, path in SWIFT_SAMPLES:
            coordinate = snapshot_matrix.Coordinate(*values)
            self.assertEqual(coordinate.key, key)
            self.assertEqual(coordinate.baseline_path, path)

    def test_each_scenario_has_144_unique_coordinates(self):
        rows = snapshot_matrix.coordinates(self.document, self.env)
        self.assertEqual(len(rows), 144 * len(self.document['scenarios']))
        self.assertEqual(len({row.key for row, _ in rows}), len(rows))
        self.assertEqual(len(snapshot_matrix.configurations()), 18)

    def test_compact_width_rule_drops_the_upright_iphone_only(self):
        rule = {'when': {'widthClass': 'compact'}, 'reason': 'Needs a regular width.'}
        document = {'schema': 2, 'scenarios': [scenario('library-sidebar', [rule])]}
        rows = snapshot_matrix.coordinates(document, self.env)
        dropped = {(row.family, row.orientation) for row, reason in rows if reason}
        self.assertEqual(dropped, {('iphone', 'portrait')})
        self.assertTrue(all(reason is None for row, reason in rows if row.family == 'ipad'))

    def test_family_rule_keeps_the_other_device(self):
        rule = {'when': {'family': 'iphone'}, 'reason': 'iPad only.'}
        document = {'schema': 2, 'scenarios': [scenario('gallery-detail-sheet', [rule])]}
        rows = snapshot_matrix.coordinates(document, self.env)
        self.assertEqual({row.family for row, reason in rows if reason is None}, {'ipad'})

    def test_totals_count_rules_by_reason(self):
        totals = snapshot_matrix.totals(self.document, self.env)
        self.assertEqual(totals['coordinates'], 144 * totals['scenarios'])
        self.assertEqual(totals['expected'] + totals['notApplicable'], totals['coordinates'])
        self.assertEqual(sum(totals['notApplicableReasons'].values()), totals['notApplicable'])
        rules = {rule['reason'] for row in self.document['scenarios'] for rule in row['notApplicable']}
        self.assertEqual(set(totals['notApplicableReasons']), rules)
        self.assertEqual({row['surface'] for row in totals['notCaptured']},
                         {'keyboard', 'web-content', 'share-sheet', 'file-importer'})

    def test_inventory_is_valid_and_keeps_the_tracer(self):
        ids = {row['id'] for row in self.document['scenarios']}
        self.assertTrue(130 <= len(ids) <= 150)
        self.assertTrue({'home-populated', 'agewall-unticked', 'comments-block-confirmation'} <= ids)
        home = next(row for row in self.document['scenarios'] if row['id'] == 'home-populated')
        self.assertEqual(home['fixtureID'], 'home-finite')

    def test_invalid_inventories_are_rejected(self):
        cases = {
            'rule without reason': [scenario('a', [{'when': {'family': 'ipad'}, 'reason': ' '}])],
            'unknown axis': [scenario('a', [{'when': {'device': 'ipad'}, 'reason': 'x'}])],
            'unknown value': [scenario('a', [{'when': {'size': 'medium'}, 'reason': 'x'}])],
            'whole scenario removed': [scenario('a', [{'when': {'family': 'ipad'}, 'reason': 'x'},
                                                      {'when': {'family': 'iphone'}, 'reason': 'y'}])],
            'duplicate ID': [scenario('a'), scenario('a')],
            'no plan': [dict(scenario('a'), plan='19-09')],
        }
        for name, rows in cases.items():
            with self.subTest(name), self.assertRaises(ValueError):
                snapshot_matrix.coordinates({'schema': 2, 'scenarios': rows}, self.env)
        with self.assertRaises(ValueError):
            snapshot_matrix.coordinates({'schema': 1, 'scenarios': [scenario('a')]}, self.env)

    def test_list_prints_one_units_expected_keys(self):
        keys = snapshot_matrix.expected_keys(self.document, self.env, 'iphone', 'en-large')
        self.assertTrue(all('__en__large__' in key and '__iphone__' in key for key in keys))
        self.assertNotIn('gallery-detail-sheet__en__large__portrait__iphone__light', keys)
        self.assertIn('home-populated__en__large__portrait__iphone__light', keys)

    def test_rules_apply_in_order(self):
        rules = [{'when': {'family': 'iphone'}, 'reason': 'first'}, {'when': {'theme': 'dark'}, 'reason': 'second'}]
        document = {'schema': 2, 'scenarios': [scenario('a', rules)]}
        reasons = {reason for row, reason in snapshot_matrix.coordinates(document, self.env)
                   if row.family == 'iphone' and row.theme == 'dark'}
        self.assertEqual(reasons, {'first'})


if __name__ == '__main__':
    unittest.main()
