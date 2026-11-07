#!/usr/bin/env python3
"""The Phase 19 coordinate space: every scenario on the D-04 axes, its not-applicable rules and the totals.

The key and the baseline path are a contract shared with Swift `SnapshotCoordinate` (19-RESEARCH §9); both sides
test the same sample strings.
"""

import argparse
from collections import Counter
from dataclasses import dataclass
import itertools
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / 'AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json'
ENVIRONMENT = ROOT / 'Scripts/visual/regression-environment.json'
LOCALES = ('en', 'de', 'ja', 'ko', 'zh-Hans', 'zh-Hant')
SIZES = ('xSmall', 'large', 'accessibility5')
ORIENTATIONS = ('portrait', 'landscape')
FAMILIES = ('iphone', 'ipad')
THEMES = ('light', 'dark')
PLANS = ('19-05', '19-06', '19-07', '19-08')
WIDTH_CLASSES = {1: 'compact', 2: 'regular'}
RULE_AXES = {'family': FAMILIES, 'orientation': ORIENTATIONS, 'locale': LOCALES, 'size': SIZES, 'theme': THEMES,
             'widthClass': tuple(WIDTH_CLASSES.values())}


@dataclass(frozen=True)
class Coordinate:
    scenario: str
    locale: str
    size: str
    orientation: str
    family: str
    theme: str

    @property
    def key(self):
        """`scenario__locale__size__orientation__family__theme`."""
        return '__'.join((self.scenario, self.locale, self.size, self.orientation, self.family, self.theme))

    @property
    def baseline_path(self):
        """`<family>/<locale>/<size>/<scenario>/<orientation>-<theme>.png`, relative to a baseline slice root."""
        return f'{self.family}/{self.locale}/{self.size}/{self.scenario}/{self.orientation}-{self.theme}.png'

    @property
    def configuration(self):
        """The test-plan configuration that carries the coordinate's language and text size."""
        return f'{self.locale}-{self.size}'


def configurations():
    """The 18 `<locale>-<size>` configurations of `SnapshotMatrix.xctestplan`."""
    return [f'{locale}-{size}' for locale, size in itertools.product(LOCALES, SIZES)]


def width_classes(env):
    """`{(family, orientation): 'compact' | 'regular'}` from the pinned horizontal size classes."""
    return {(family, orientation): WIDTH_CLASSES[env['devices'][family]['orientations'][orientation]
                                                 ['horizontalSizeClass']]
            for family in FAMILIES for orientation in ORIENTATIONS}


def axes(coordinate, widths):
    return {'family': coordinate.family, 'orientation': coordinate.orientation, 'locale': coordinate.locale,
            'size': coordinate.size, 'theme': coordinate.theme,
            'widthClass': widths[(coordinate.family, coordinate.orientation)]}


def not_applicable_reason(scenario, coordinate, widths):
    """The reason of the first rule that matches, or `None` when the coordinate is captured (as Swift does)."""
    values = axes(coordinate, widths)
    for rule in scenario['notApplicable']:
        if all(values[axis] == value for axis, value in rule['when'].items()):
            return rule['reason']
    return None


def scenario_coordinates(identifier):
    return [Coordinate(identifier, *values)
            for values in itertools.product(LOCALES, SIZES, ORIENTATIONS, FAMILIES, THEMES)]


def validate(document, env):
    """Rejects an inventory that is not schema 2, repeats an ID, lacks a plan, or has a rule without a reason, on
    an unknown axis or value, or that removes every coordinate of its scenario."""
    if not isinstance(document, dict) or document.get('schema') != 2 or not document.get('scenarios'):
        raise ValueError('Expected a schema-2 inventory with scenarios')
    widths = width_classes(env)
    seen = set()
    for scenario in document['scenarios']:
        identifier = scenario.get('id', '')
        if not re.fullmatch(r'[a-z][a-z0-9-]*', identifier) or identifier in seen:
            raise ValueError(f'Invalid or duplicate scenario ID: {identifier!r}')
        seen.add(identifier)
        if scenario.get('plan') not in PLANS or not scenario.get('group') or not scenario.get('state'):
            raise ValueError(f'{identifier}: a scenario needs a group, a state and one of {PLANS}')
        if not isinstance(scenario.get('signedIn'), bool) or not isinstance(scenario.get('notApplicable'), list):
            raise ValueError(f'{identifier}: signedIn must be a boolean and notApplicable a list')
        for rule in scenario['notApplicable']:
            when = rule.get('when')
            if not str(rule.get('reason', '')).strip() or not isinstance(when, dict) or not when:
                raise ValueError(f'{identifier}: a not-applicable rule needs a condition and a reason')
            for axis, value in when.items():
                if value not in RULE_AXES.get(axis, ()):
                    raise ValueError(f'{identifier}: unknown rule axis or value {axis}={value!r}')
        if all(not_applicable_reason(scenario, row, widths) for row in scenario_coordinates(identifier)):
            raise ValueError(f'{identifier}: its rules remove every coordinate')
    return document


def coordinates(document, env):
    """Every coordinate of every scenario, sorted by scenario, with its not-applicable reason or `None`."""
    validate(document, env)
    widths = width_classes(env)
    return [(row, not_applicable_reason(scenario, row, widths))
            for scenario in sorted(document['scenarios'], key=lambda entry: entry['id'])
            for row in scenario_coordinates(scenario['id'])]


def totals(document, env):
    rows = coordinates(document, env)
    reasons = Counter(reason for _, reason in rows if reason)
    return {'scenarios': len(document['scenarios']), 'coordinates': len(rows),
            'expected': sum(reason is None for _, reason in rows), 'notApplicable': sum(reasons.values()),
            'notApplicableReasons': dict(sorted(reasons.items())),
            'notCaptured': document.get('notCaptured', [])}


def expected_keys(document, env, family, configuration):
    """The keys a (device, configuration) unit captures."""
    return [row.key for row, reason in coordinates(document, env)
            if reason is None and row.family == family and row.configuration == configuration]


def load(path=INVENTORY, env_path=ENVIRONMENT):
    return json.loads(Path(path).read_text()), json.loads(Path(env_path).read_text())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--totals', action='store_true', help='print the totals as JSON')
    mode.add_argument('--list', action='store_true', help='print the keys one unit captures')
    parser.add_argument('--family', choices=FAMILIES)
    parser.add_argument('--configuration', choices=configurations())
    parser.add_argument('--inventory', type=Path, default=INVENTORY)
    parser.add_argument('--environment', type=Path, default=ENVIRONMENT)
    args = parser.parse_args(argv)
    document, env = load(args.inventory, args.environment)
    if args.totals:
        print(json.dumps(totals(document, env), indent=2, ensure_ascii=False))
    else:
        if not args.family or not args.configuration:
            parser.error('--list needs --family and --configuration')
        print('\n'.join(expected_keys(document, env, args.family, args.configuration)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
