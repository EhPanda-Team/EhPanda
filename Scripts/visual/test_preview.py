"""The preview validator must accept a matching response and reject every response that is not evidence."""

from contextlib import redirect_stderr, redirect_stdout
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

PNG = b'\x89PNG\r\n\x1a\n' + b'\x00' * 24


def load_validator():
    spec = importlib.util.spec_from_file_location('validate_preview', Path(__file__).with_name('validate-preview.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expected_environment():
    return {
        'schemaVersion': 1,
        'kind': 'preview-expectation',
        'destination': 'iPhone Air',
        'locale': 'ja',
        'variant': 'dark',
        'supportedLocales': ['en', 'de', 'ja', 'ko', 'zh-Hans', 'zh-Hant'],
        'supportedVariants': ['light', 'dark'],
        'source': {'file': 'AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift', 'previewIndex': 0},
    }


def response():
    return {
        'previewSnapshotPath': 'preview.png',
        'renderedDestination': 'iPhone Air',
        'displayName': 'Downloads row',
        'sourceLineNumber': 42,
        'errors': [],
        'locale': 'ja',
        'variant': 'dark',
        'review': {'liveContent': False, 'note': 'No date, spinner or progress ring is drawn.'},
    }


class PreviewValidatorTests(unittest.TestCase):
    def setUp(self):
        self.validator = load_validator()
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'preview.png').write_bytes(PNG)

    def run_validator(self, response_value=None, expected_value=None):
        response_value = response() if response_value is None else response_value
        expected_value = expected_environment() if expected_value is None else expected_value
        response_path = self.root / 'response.json'
        expected_path = self.root / 'expected.json'
        response_path.write_text(json.dumps(response_value))
        expected_path.write_text(json.dumps(expected_value))
        output = self.root / 'out'
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            status = self.validator.main(
                ['--response', str(response_path), '--expected-environment', str(expected_path),
                 '--output', str(output)])
        return status, err.getvalue(), output

    def assert_rejected(self, response_value=None, expected_value=None, mention=''):
        status, error, output = self.run_validator(response_value, expected_value)
        self.assertEqual(status, 1, error)
        self.assertIn(mention, error)
        self.assertFalse(output.exists(), 'a rejected response must write nothing')

    def test_accepts_a_matching_response_and_keeps_its_metadata(self):
        status, error, output = self.run_validator()
        self.assertEqual(status, 0, error)
        record = json.loads((output / 'preview-metadata.json').read_text())
        self.assertEqual(record['status'], 'accepted')
        self.assertFalse(record['countsAsSnapshotAcceptance'])
        self.assertEqual(record['requested'], {'destination': 'iPhone Air', 'locale': 'ja', 'variant': 'dark'})
        self.assertEqual(record['returned']['renderedDestination'], 'iPhone Air')
        self.assertEqual(record['returned']['displayName'], 'Downloads row')
        self.assertEqual(record['returned']['sourceLineNumber'], 42)
        self.assertEqual(record['returned']['errors'], [])
        self.assertEqual(record['snapshot']['sha256'], hashlib.sha256(PNG).hexdigest())
        self.assertEqual(record['snapshot']['bytes'], len(PNG))
        self.assertEqual(record['snapshot']['format'], 'png')
        self.assertEqual((output / record['snapshot']['file']).read_bytes(), PNG)
        self.assertNotIn(str(self.root), json.dumps(record), 'the record carries no absolute path')

    def test_rejects_a_destination_mismatch(self):
        mismatched = response()
        mismatched['renderedDestination'] = 'iPhone 18 Pro'
        self.assert_rejected(mismatched, mention='destination')

    def test_rejects_non_empty_errors(self):
        failed = response()
        failed['errors'] = ['Preview crashed']
        self.assert_rejected(failed, mention='errors')

    def test_rejects_a_missing_snapshot(self):
        absent = response()
        absent['previewSnapshotPath'] = 'missing.png'
        self.assert_rejected(absent, mention='snapshot')
        unnamed = response()
        del unnamed['previewSnapshotPath']
        self.assert_rejected(unnamed, mention='snapshot')
        (self.root / 'empty.png').write_bytes(b'')
        empty = response()
        empty['previewSnapshotPath'] = 'empty.png'
        self.assert_rejected(empty, mention='snapshot')

    def test_rejects_an_unsupported_locale(self):
        requested = expected_environment()
        requested['locale'] = 'fr'
        self.assert_rejected(expected_value=requested, mention='locale')

    def test_rejects_an_unsupported_variant(self):
        requested = expected_environment()
        requested['variant'] = 'sepia'
        self.assert_rejected(expected_value=requested, mention='variant')

    def test_rejects_a_render_in_another_locale_than_requested(self):
        other = response()
        other['locale'] = 'en'
        self.assert_rejected(other, mention='locale')

    def test_rejects_a_live_date_or_spinner(self):
        live = response()
        live['review'] = {'liveContent': True, 'note': 'A spinner is drawn.'}
        self.assert_rejected(live, mention='live')


if __name__ == '__main__':
    unittest.main()
