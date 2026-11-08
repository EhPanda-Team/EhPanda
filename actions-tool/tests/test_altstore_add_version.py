"""Tests for altstore-add-version.jq with per-language notes (owner msg 2561)."""

import json
import pathlib
import shutil
import subprocess
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import altstore_languages as languages  # noqa: E402
import release_notes  # noqa: E402

FILTER = TOOLS / "altstore-add-version.jq"
NOTES = release_notes.read(TOOLS / "tests" / "fixtures" / "release-notes" / "9.9.9.md")
SOURCE = {
    "name": "EhPanda",
    "identifier": "app.ehpanda.test",
    "subtitle": "Subtitle.",
    "description": "Description.",
    "iconURL": "https://example.com/icon.png",
    "apps": [{
        "name": "EhPanda",
        "bundleIdentifier": "app.ehpanda",
        "developerName": "EhPanda Team",
        "subtitle": "Subtitle.",
        "localizedDescription": "Description.",
        "iconURL": "https://example.com/icon.png",
        "versions": [{
            "version": "9.9.8", "buildVersion": "998", "date": "2026-01-01T00:00:00Z",
            "localizedDescription": "Older.", "downloadURL": "https://example.com/old.ipa",
            "size": 1, "sha256": "00", "minOSVersion": "17.0",
        }],
    }],
}


@unittest.skipUnless(shutil.which("jq"), "jq is not installed")
class AddVersionTests(unittest.TestCase):
    def add(self, localized=None, english=NOTES["en"], omit=False):
        args = ["jq",
                "--arg", "bundleIdentifier", "app.ehpanda", "--arg", "version", "9.9.9",
                "--arg", "buildVersion", "999", "--arg", "marketingVersion", "9.9.9",
                "--arg", "date", "2026-11-08T00:00:00Z", "--arg", "localizedDescription", english,
                "--arg", "downloadURL", "https://example.com/EhPanda-AltStore.ipa", "--arg", "sha256", "ff",
                "--arg", "minOSVersion", "17.0", "--argjson", "size", "2", "--argjson", "privacy", "{}",
                "--argjson", "releaseVersions", "null"]
        if not omit:
            args += ["--argjson", "localizedDescriptions", json.dumps(localized, ensure_ascii=False)]
        args += ["-f", str(FILTER)]
        return subprocess.run(args, input=json.dumps(SOURCE), capture_output=True, text=True, encoding="utf-8")

    def test_altstore_gets_every_language_with_english_as_the_default(self):
        result = self.add(NOTES)
        self.assertEqual(result.returncode, 0, result.stderr)
        source = json.loads(result.stdout)
        version = source["apps"][0]["versions"][0]
        self.assertEqual(list(version)[:6], ["version", "buildVersion", "marketingVersion", "date",
                                             "localizedDescription", "localizedDescriptions"])
        self.assertEqual(version["localizedDescription"], NOTES["en"])
        self.assertEqual(version["localizedDescriptions"], NOTES)
        self.assertEqual(languages.localized_value(version["localizedDescriptions"], ["zh-Hant-TW"]), NOTES["zh-Hant"])
        self.assertEqual(languages.check_source(source, every_language=False), [])
        self.assertEqual(len(source["apps"][0]["versions"]), 2)

    def test_sidestore_gets_english_only(self):
        for result in [self.add(None), self.add(omit=True)]:
            self.assertEqual(result.returncode, 0, result.stderr)
            version = json.loads(result.stdout)["apps"][0]["versions"][0]
            self.assertEqual(version["localizedDescription"], NOTES["en"])
            self.assertNotIn("localizedDescriptions", version)

    def test_mismatched_or_empty_notes_fail(self):
        self.assertIn("differs from localizedDescription", self.add(NOTES, english="Other.").stderr)
        self.assertIn("non-empty strings", self.add({**NOTES, "de": ""}).stderr)
        self.assertIn("non-empty strings", self.add(["en"]).stderr)


if __name__ == "__main__":
    unittest.main()
