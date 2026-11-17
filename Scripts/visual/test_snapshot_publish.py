"""Assembling, slicing, committing and pinning the approved baseline (19-12 Task 1; 19-CONTEXT D-14).

A one-scenario inventory with one not-applicable rule stands in for scenarios.json, synthetic picture artifacts for
a candidate run's downloads, and a local repository for EhPanda-Team/ehpanda-snapshot.
"""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import snapshot_fetch
import snapshot_matrix
import snapshot_publish

SCENARIO = 'home-populated'
RULE = {'when': {'family': 'ipad', 'orientation': 'landscape'}, 'reason': 'Synthetic rule for the test.'}
GIT_ENVIRONMENT = {'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1'}


def inventory_document():
    return {'schema': 2, 'scenarios': [{'id': SCENARIO, 'group': 'home', 'plan': '19-05', 'state': 'Populated',
                                        'signedIn': True, 'notApplicable': [RULE]}]}


def git(*args, cwd):
    return subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


class PublishTests(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.dict(os.environ, GIT_ENVIRONMENT)
        patcher.start()
        self.addCleanup(patcher.stop)
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.inventory = self.root / 'scenarios.json'
        self.inventory.write_text(json.dumps(inventory_document()))
        document, env = snapshot_matrix.load(self.inventory, snapshot_matrix.ENVIRONMENT)
        self.keys = [row.key for row, reason in snapshot_matrix.coordinates(document, env) if reason is None]
        self.artifacts = self.root / 'artifacts'
        self.set = self.root / 'set'

    def write_attempt(self, name, pictures, extra_lines=()):
        """An artifact directory with a recorded line and a picture per `{key: bytes}`."""
        directory = self.artifacts / name
        directory.mkdir(parents=True)
        lines = []
        for key, data in pictures.items():
            path = directory / snapshot_fetch.key_path(key)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            lines.append({'key': key, 'status': 'recorded', 'sha256': hashlib.sha256(data).hexdigest()})
        lines.extend(extra_lines)
        (directory / 'results.jsonl').write_text(''.join(json.dumps(line) + '\n' for line in lines))
        return directory

    def write_candidate(self):
        """A first attempt with every key but the last two, and a retry with those two and a re-recorded first key."""
        first = {key: f'png 1 {key}'.encode() for key in self.keys[:-2]}
        retry = {key: f'png 2 {key}'.encode() for key in [self.keys[0], *self.keys[-2:]]}
        self.write_attempt('pictures-shard-s01', first)
        self.write_attempt('pictures-retry-s01', retry)
        return {**first, **retry}

    def assemble(self):
        return snapshot_publish.assemble(self.artifacts, self.set, self.inventory, snapshot_matrix.ENVIRONMENT)

    def assert_fails(self, call, *fragments):
        with self.assertRaises(snapshot_publish.PublishError) as caught:
            call()
        text = '\n'.join(caught.exception.args)
        for fragment in fragments:
            self.assertIn(fragment, text)

    def test_assemble_lays_out_every_expected_coordinate_from_its_latest_attempt(self):
        pictures = self.write_candidate()
        fingerprints = self.assemble()
        self.assertEqual(len(self.keys), 108)
        self.assertEqual(fingerprints['count'], 108)
        self.assertEqual((fingerprints['commit'], fingerprints['tag']), ('', ''))
        self.assertEqual(fingerprints['repository'], 'EhPanda-Team/ehpanda-snapshot')
        for key in self.keys:
            path = self.set / 'pictures' / snapshot_fetch.key_path(key)
            self.assertEqual(path.read_bytes(), pictures[key])
            self.assertEqual(fingerprints['pictures'][key], hashlib.sha256(pictures[key]).hexdigest())
        self.assertEqual(json.loads((self.set / 'fingerprints.json').read_text()), fingerprints)
        slices = json.loads((self.set / 'slices.json').read_text())
        self.assertEqual(sum(entry['pictures'] for entry in slices.values()), 108)
        self.assertEqual(slices['ipad/de']['pictures'], 6)
        self.assertEqual(slices['iphone/de']['pictures'], 12)

    def test_a_key_outside_the_inventory_fails_with_the_key(self):
        self.write_candidate()
        unknown = 'removed-scenario__en__large__portrait__iphone__light'
        self.write_attempt('pictures-shard-s02', {unknown: b'png'})
        self.assert_fails(self.assemble, f'{unknown}: recorded but not in the inventory')

    def test_a_missing_expected_coordinate_fails_with_the_key(self):
        self.write_attempt('pictures-shard-s01', {key: b'png ' + key.encode() for key in self.keys[1:]})
        self.assert_fails(self.assemble, f'{self.keys[0]}: expected but not recorded')

    def test_a_picture_that_differs_from_its_line_fails(self):
        directory = self.write_attempt('pictures-shard-s01', {key: b'png ' + key.encode() for key in self.keys})
        (directory / snapshot_fetch.key_path(self.keys[3])).write_bytes(b'other bytes')
        self.assert_fails(self.assemble, f'{self.keys[3]}: the picture in pictures-shard-s01 differs')

    def test_two_digests_in_one_attempt_fail(self):
        pictures = {key: b'png ' + key.encode() for key in self.keys}
        second = {'key': self.keys[5], 'status': 'recorded', 'sha256': '0' * 64}
        self.write_attempt('pictures-shard-s01', pictures, extra_lines=[second])
        self.assert_fails(self.assemble, f'{self.keys[5]}: pictures-shard-s01 recorded it with 2 different digests')

    def test_an_unknown_artifact_fails(self):
        self.write_candidate()
        (self.artifacts / 'shard-s01').mkdir()
        self.assert_fails(self.assemble, 'shard-s01: not a picture artifact')

    def test_assemble_refuses_a_set_directory_that_holds_files(self):
        self.write_candidate()
        self.set.mkdir()
        (self.set / 'left-over').write_text('x')
        self.assert_fails(self.assemble, 'already holds files')

    def test_plan_orders_the_slices_and_fails_over_the_limit(self):
        self.write_candidate()
        self.assemble()
        names = [name for name, _, _ in snapshot_publish.plan(self.set, 1.8)]
        self.assertEqual(names, [f'{family}/{locale}' for family in snapshot_matrix.FAMILIES
                                 for locale in snapshot_matrix.LOCALES])
        self.assert_fails(lambda: snapshot_publish.plan(self.set, 1e-9), 'iphone/en: ', 'is over')

    def make_repository(self):
        repo = self.root / 'ehpanda-snapshot'
        repo.mkdir()
        git('init', '-q', '-b', 'main', cwd=repo)
        for key, value in (('user.name', 'Test'), ('user.email', 'test@example.invalid'),
                           ('commit.gpgsign', 'false'), ('uploadpack.allowFilter', 'true'),
                           ('uploadpack.allowAnySHA1InWant', 'true')):
            git('config', key, value, cwd=repo)
        (repo / 'README.md').write_text('The approved screenshot baseline.\n')
        git('add', '-A', cwd=repo)
        git('commit', '-q', '-m', 'README', cwd=repo)
        return repo

    def test_push_commits_each_slice_then_the_approval_and_never_pushes(self):
        self.write_candidate()
        self.assemble()
        repo = self.make_repository()
        approval = {'owner': 'test approval', 'candidateRun': 1}
        run = subprocess.run
        calls = []

        def recording(command, *args, **kwargs):
            calls.append(command)
            return run(command, *args, **kwargs)

        with mock.patch.object(snapshot_publish.subprocess, 'run', side_effect=recording):
            commands = snapshot_publish.push(self.set, repo, 'baseline-1', approval, 1.8, dry_run=False)
        self.assertFalse([command for command in calls if 'push' in command])
        self.assertEqual(len(commands), 14)
        self.assertTrue(all(command.startswith(f'git -C {repo} push origin ') for command in commands))
        self.assertTrue(commands[-1].endswith('refs/tags/baseline-1'))
        subjects = git('log', '--reverse', '--format=%s', cwd=repo).splitlines()
        self.assertEqual(subjects[1], 'baseline-1: iphone en pictures')
        self.assertEqual(subjects[-1], 'baseline-1: approval record')
        self.assertEqual(len(subjects), 1 + 12 + 1)
        for dates in git('log', '--format=%aI %cI', cwd=repo).splitlines()[:-1]:
            self.assertTrue(all(value.endswith('+08:00') for value in dates.split()), dates)
        record = json.loads((repo / 'baseline.json').read_text())
        self.assertEqual(record['approval'], approval)
        self.assertEqual(record['fingerprintsSha256'],
                         hashlib.sha256((self.set / 'fingerprints.json').read_bytes()).hexdigest())
        self.assertEqual(git('rev-parse', 'baseline-1^{commit}', cwd=repo), git('rev-parse', 'HEAD', cwd=repo))
        self.assertEqual(json.loads((self.set / 'push.json').read_text())['commits'][-1],
                         git('rev-parse', 'HEAD', cwd=repo))

    def test_a_dry_run_changes_nothing(self):
        self.write_candidate()
        self.assemble()
        repo = self.make_repository()
        head = git('rev-parse', 'HEAD', cwd=repo)
        lines = snapshot_publish.push(self.set, repo, 'baseline-1', {}, 1.8, dry_run=True)
        self.assertEqual(len(lines), 13)
        self.assertEqual(git('rev-parse', 'HEAD', cwd=repo), head)
        self.assertFalse(git('tag', '--list', cwd=repo))

    def test_push_refuses_a_bad_tag_or_a_dirty_clone(self):
        self.write_candidate()
        self.assemble()
        repo = self.make_repository()
        self.assert_fails(lambda: snapshot_publish.push(self.set, repo, 'v1', {}, 1.8, False), 'baseline-<n>')
        (repo / 'stray').write_text('x')
        self.assert_fails(lambda: snapshot_publish.push(self.set, repo, 'baseline-1', {}, 1.8, False),
                          'uncommitted changes')

    def test_pinned_fingerprints_pass_the_gate_fetch(self):
        self.write_candidate()
        self.assemble()
        repo = self.make_repository()
        snapshot_publish.push(self.set, repo, 'baseline-1', {}, 1.8, dry_run=False)
        pinned = self.root / 'fingerprints.json'
        commit = snapshot_publish.pin(self.set, repo, 'baseline-1', pinned)
        document = json.loads(pinned.read_text())
        self.assertEqual((document['commit'], document['tag'], document['count']), (commit, 'baseline-1', 108))
        # The fetch reads the local repository standing in for the public one.
        pinned.write_text(json.dumps({**document, 'repository': f'file://{repo}'}))
        slices = ['iphone/en/large', 'ipad/zh-Hant/accessibility5']
        with contextlib.redirect_stdout(io.StringIO()):
            status = snapshot_fetch.main(['--fingerprints', str(pinned), '--slices', ','.join(slices),
                                          '--dest', str(self.root / 'fetched')])
        self.assertEqual(status, 0)

    def test_the_manifest_records_tolerances_digests_rules_and_approval(self):
        self.write_candidate()
        self.assemble()
        repo = self.make_repository()
        snapshot_publish.push(self.set, repo, 'baseline-1', {}, 1.8, dry_run=False)
        pinned = self.root / 'fingerprints.json'
        snapshot_publish.pin(self.set, repo, 'baseline-1', pinned)
        approval = {'approved': 'owner, test', 'candidateRun': 1}
        document = snapshot_publish.manifest(pinned, approval, {'inventory': self.inventory})
        self.assertEqual((document['precision'], document['perceptualPrecision'], document['scale']), (0.9999, 1, 1))
        self.assertEqual(document['approval'], approval)
        self.assertEqual(document['baseline']['tag'], 'baseline-1')
        self.assertEqual(document['baseline']['fingerprintsSha256'], hashlib.sha256(pinned.read_bytes()).hexdigest())
        self.assertEqual(document['inventory'], hashlib.sha256(self.inventory.read_bytes()).hexdigest())
        plan = json.loads(snapshot_publish.SHARD_PLAN.read_text())
        self.assertEqual(document['costTable'], plan['costTable'])
        self.assertEqual(document['workers']['count'], plan['workers'])
        self.assertEqual(len(document['notApplicable']), 144 - 108)
        self.assertEqual({entry['reason'] for entry in document['notApplicable']}, {RULE['reason']})

    def test_the_manifest_refuses_unpinned_fingerprints(self):
        self.write_candidate()
        self.assemble()
        self.assert_fails(lambda: snapshot_publish.manifest(self.set / 'fingerprints.json', {}), 'run `pin` first')

    def test_pin_refuses_a_tag_that_does_not_hold_the_set(self):
        self.write_candidate()
        self.assemble()
        repo = self.make_repository()
        snapshot_publish.push(self.set, repo, 'baseline-1', {}, 1.8, dry_run=False)
        picture = repo / snapshot_fetch.key_path(self.keys[0])
        picture.write_bytes(b'edited after the approval')
        git('commit', '-q', '-am', 'edit', cwd=repo)
        git('tag', '-f', 'baseline-1', cwd=repo)
        self.assert_fails(lambda: snapshot_publish.pin(self.set, repo, 'baseline-1', self.root / 'out.json'),
                          f'{self.keys[0]}: differs at baseline-1')


if __name__ == '__main__':
    unittest.main()
