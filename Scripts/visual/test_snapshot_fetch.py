"""The baseline slice fetch and its fingerprint check (19-10; 19-CONTEXT D-14, 19-RESEARCH §6).

A local snapshot repository stands in for EhPanda-Team/ehpanda-snapshot. It has two commits: the approved one the
fingerprints pin, and a later tip that changes a picture, so a fetch that took the tip instead of the pin fails.
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

import snapshot_fetch

KEYS = (
    'home-populated__en__large__portrait__iphone__light',
    'home-populated__en__large__portrait__iphone__dark',
    'home-populated__en__large__landscape__iphone__light',
    'home-loading__en__large__portrait__iphone__light',
    'home-populated__de__large__portrait__iphone__light',
    'home-populated__en__large__portrait__ipad__light',
    'home-populated__en__xSmall__portrait__iphone__light',
)
SLICES = ('iphone/en/large', 'iphone/en/xSmall')


def picture_path(key):
    scenario, locale, size, orientation, family, theme = key.split('__')
    return f'{family}/{locale}/{size}/{scenario}/{orientation}-{theme}.png'


def git(*args, cwd):
    return subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True, text=True,
                          env={**os.environ, 'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1',
                               'GIT_AUTHOR_NAME': 'Test', 'GIT_AUTHOR_EMAIL': 'test@example.invalid',
                               'GIT_COMMITTER_NAME': 'Test', 'GIT_COMMITTER_EMAIL': 'test@example.invalid'}
                          ).stdout.strip()


class FetchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.repository = self.root / 'ehpanda-snapshot'
        self.repository.mkdir()
        git('init', '-q', '-b', 'main', cwd=self.repository)
        # A file:// clone honours --filter and fetching a pinned commit only when the server allows both, as
        # GitHub does.
        git('config', 'uploadpack.allowFilter', 'true', cwd=self.repository)
        git('config', 'uploadpack.allowAnySHA1InWant', 'true', cwd=self.repository)
        git('config', 'commit.gpgsign', 'false', cwd=self.repository)
        (self.repository / 'README.md').write_text('The approved screenshot baseline.\n')
        self.pictures = {}
        for number, key in enumerate(KEYS):
            path = self.repository / picture_path(key)
            path.parent.mkdir(parents=True, exist_ok=True)
            data = f'png {number} {key}'.encode()
            path.write_bytes(data)
            self.pictures[key] = hashlib.sha256(data).hexdigest()
        git('add', '-A', cwd=self.repository)
        git('commit', '-q', '-m', 'Approved baseline', cwd=self.repository)
        self.commit = git('rev-parse', 'HEAD', cwd=self.repository)
        (self.repository / picture_path(KEYS[0])).write_bytes(b'a later, unapproved picture')
        git('commit', '-q', '-am', 'A later tip', cwd=self.repository)
        self.fingerprints = self.root / 'fingerprints.json'
        self.write_fingerprints(self.pictures)
        self.dest = self.root / 'baseline'

    def tearDown(self):
        self.directory.cleanup()

    def write_fingerprints(self, pictures, commit=None):
        self.fingerprints.write_text(json.dumps({
            'schema': 1, 'repository': self.repository.as_uri(), 'commit': commit or self.commit,
            'tag': 'baseline-1', 'count': len(pictures), 'pictures': pictures}))

    def fetch(self, slices=SLICES, fingerprints=None):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = snapshot_fetch.main(['--fingerprints', str(fingerprints or self.fingerprints),
                                          '--slices', ','.join(slices), '--dest', str(self.dest)])
        return status, out.getvalue() + err.getvalue()

    def files(self):
        return sorted(str(path.relative_to(self.dest)) for path in self.dest.rglob('*')
                      if path.is_file() and '.git' not in path.relative_to(self.dest).parts)

    def test_matching_fingerprints_leave_only_the_requested_slices_at_the_pinned_commit(self):
        status, output = self.fetch()
        self.assertEqual(status, 0, output)
        wanted = sorted(picture_path(key) for key in KEYS if '/'.join(picture_path(key).split('/')[:3]) in SLICES)
        self.assertEqual([path for path in self.files() if path != 'README.md'], wanted)
        self.assertFalse((self.dest / 'iphone/de').exists())
        self.assertFalse((self.dest / 'ipad').exists())
        # The approved picture, not the later tip's.
        first = self.dest / picture_path(KEYS[0])
        self.assertEqual(hashlib.sha256(first.read_bytes()).hexdigest(), self.pictures[KEYS[0]])
        self.assertIn('5 pictures', output)

    def test_one_altered_byte_fails_with_baseline_mismatch_and_the_key(self):
        pictures = dict(self.pictures)
        pictures[KEYS[1]] = hashlib.sha256(b'png 1 ' + KEYS[1].encode() + b'!').hexdigest()
        self.write_fingerprints(pictures)
        status, output = self.fetch()
        self.assertEqual(status, snapshot_fetch.MISMATCH, output)
        self.assertIn('baseline-mismatch', output)
        self.assertIn(KEYS[1], output)
        self.assertIn('differs', output)

    def test_a_missing_file_fails_with_baseline_mismatch_and_the_key(self):
        missing = 'home-error__en__large__portrait__iphone__light'
        self.write_fingerprints({**self.pictures, missing: '0' * 64})
        status, output = self.fetch()
        self.assertEqual(status, snapshot_fetch.MISMATCH, output)
        self.assertIn('baseline-mismatch', output)
        self.assertIn(missing, output)
        self.assertIn('missing', output)

    def test_an_extra_file_fails_with_baseline_mismatch_and_the_key(self):
        pictures = dict(self.pictures)
        del pictures[KEYS[3]]
        self.write_fingerprints(pictures)
        status, output = self.fetch()
        self.assertEqual(status, snapshot_fetch.MISMATCH, output)
        self.assertIn('baseline-mismatch', output)
        self.assertIn(KEYS[3], output)
        self.assertIn('extra', output)

    def test_a_requested_slice_without_fingerprints_fails_as_a_mismatch(self):
        status, output = self.fetch(slices=('iphone/en/large', 'iphone/ja/large'))
        self.assertEqual(status, snapshot_fetch.MISMATCH, output)
        self.assertIn('iphone/ja/large', output)

    def test_no_fingerprints_file_fails_with_no_approved_baseline_yet(self):
        status, output = self.fetch(fingerprints=self.root / 'absent' / 'fingerprints.json')
        self.assertEqual(status, snapshot_fetch.NO_BASELINE, output)
        self.assertIn('no approved baseline yet', output)
        self.assertFalse(self.dest.exists())

    def test_an_unreachable_repository_is_not_a_mismatch(self):
        self.fingerprints.write_text(json.dumps({
            'schema': 1, 'repository': (self.root / 'nowhere').as_uri(), 'commit': self.commit, 'tag': 'baseline-1',
            'count': len(self.pictures), 'pictures': self.pictures}))
        status, output = self.fetch()
        self.assertEqual(status, snapshot_fetch.FETCH_FAILED, output)
        self.assertNotIn('baseline-mismatch', output)

    def test_repository_names_resolve_to_github(self):
        self.assertEqual(snapshot_fetch.repository_url('EhPanda-Team/ehpanda-snapshot'),
                         'https://github.com/EhPanda-Team/ehpanda-snapshot.git')
        self.assertEqual(snapshot_fetch.repository_url('file:///tmp/x'), 'file:///tmp/x')


if __name__ == '__main__':
    unittest.main()
