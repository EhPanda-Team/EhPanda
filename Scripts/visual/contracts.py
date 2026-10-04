"""Explicit coordinate identity and fail-closed regression artifact contracts."""
from dataclasses import dataclass
import hashlib
import itertools
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
AXES = {
    'locale': ('en', 'de', 'ja', 'ko', 'zh-Hans', 'zh-Hant'),
    'size': ('xSmall', 'small', 'medium', 'large', 'xLarge', 'xxLarge', 'xxxLarge',
             'accessibility1', 'accessibility2', 'accessibility3', 'accessibility4', 'accessibility5'),
    'orientation': ('portrait', 'landscape'), 'family': ('iphone', 'ipad'), 'theme': ('light', 'dark'),
}


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
        return '__'.join(vars(self).values())


def enumerate_coordinates(scenarios):
    if not isinstance(scenarios, list) or not scenarios:
        raise ValueError('At least one named executable scenario is required')
    seen = set()
    for scenario in scenarios:
        if (not isinstance(scenario, dict) or set(scenario) != {'id', 'fixtureID', 'state'}
                or not all(isinstance(value, str) and value for value in scenario.values())
                or not re.fullmatch(r'[a-z][a-z0-9-]*', scenario['id']) or scenario['id'] in seen):
            raise ValueError(f'Invalid or duplicate scenario: {scenario!r}')
        seen.add(scenario['id'])
    return [Coordinate(scenario, *values) for scenario in sorted(seen)
            for values in itertools.product(*AXES.values())]


def select_coordinates(rows, expression):
    if not expression:
        raise ValueError('A filter must select at least one explicit axis value')
    criteria = {}
    for term in expression.split(','):
        parts = term.split('=')
        if len(parts) != 2 or parts[0] not in ('scenario', *AXES) or parts[0] in criteria or not parts[1]:
            raise ValueError(f'Invalid coordinate filter: {term!r}')
        criteria[parts[0]] = parts[1]
    selected = [row for row in rows if all(getattr(row, axis) == value for axis, value in criteria.items())]
    if not selected:
        raise ValueError(f'Filter matches zero coordinates: {expression}')
    return selected


def coverage(all_rows, requested):
    return {'possible': len(all_rows), 'requested': len(requested),
            'complete': {row.key for row in all_rows} == {row.key for row in requested}}


def validate_outcomes(requested, outcomes, inapplicable=None):
    inapplicable = inapplicable or {}
    if (not requested or len(outcomes) != len(requested)
            or {row['coordinate'] for row in outcomes} != {row.key for row in requested}):
        raise ValueError('Missing, duplicate or unrequested coordinate outcomes')
    for row in outcomes:
        if row['status'] not in ('captured', 'failed', 'not-applicable') or not row.get('reason', '').strip():
            raise ValueError(f'Outcome requires a terminal status and reason: {row}')
        if row['status'] == 'not-applicable' and inapplicable.get(row['coordinate']) != row['reason']:
            raise ValueError('Only an explicit semantic exception can be not-applicable')


def validate_test_result(summary, tree):
    if (summary.get('totalTestCount') != 1 or summary.get('passedTests') != 1
            or any(summary.get(key) for key in ('failedTests', 'skippedTests', 'expectedFailures', 'runtimeWarnings'))):
        raise ValueError('Expected exactly one passing native test without warnings/skips/failures')
    def visit(value):
        if isinstance(value, dict):
            if 'Repetition' in value.get('nodeType', ''):
                raise ValueError('Test repetition is prohibited')
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    visit(tree)


def contained(root, relative):
    path = Path(relative)
    if path.is_absolute() or '..' in path.parts or not path.parts:
        raise ValueError(f'Invalid relative artifact path: {relative}')
    result = (root / path).resolve()
    if not result.is_relative_to(root.resolve()):
        raise ValueError(f'Artifact escapes its root: {relative}')
    return result


def validate_fixtures(directory, scenarios):
    directory = Path(directory).resolve()
    manifest = json.loads((directory / 'manifest.json').read_text())
    if manifest.get('schemaVersion') != 1 or manifest.get('fixtureVersion') != 'phase17-finite-v2':
        raise ValueError('Expected the verified phase17-finite-v2 public fixture export')
    assets = manifest['assets']
    if not assets or len({entry['path'] for entry in assets}) != len(assets):
        raise ValueError('Fixture assets must be nonempty and uniquely named')
    for entry in assets:
        data = contained(directory, entry['path']).read_bytes()
        if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise ValueError(f'Fixture checksum/length mismatch: {entry["path"]}')
    serialized = json.dumps(assets, indent=2, sort_keys=True, ensure_ascii=False, separators=(',', ' : ')).encode()
    if hashlib.sha256(serialized).hexdigest() != manifest['aggregateDigest']:
        raise ValueError('Fixture aggregate digest mismatch')
    sources = manifest['generatorSources']
    if set(sources) != {'AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift'}:
        raise ValueError('Unrecognized public fixture generator')
    for source, digest in sources.items():
        if hashlib.sha256(contained(ROOT, source).read_bytes()).hexdigest() != digest:
            raise ValueError(f'Fixture generator changed: {source}')
    catalog = json.loads((directory / 'scenarios.json').read_text())
    fixture_ids = {row['fixtureID'] for row in catalog}
    for scenario in scenarios:
        if scenario['fixtureID'] not in fixture_ids or scenario['fixtureID'] not in manifest['fixtureIDs']:
            raise ValueError(f'Missing upstream fixture: {scenario["fixtureID"]}')
    return manifest
