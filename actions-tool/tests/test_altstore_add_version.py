"""Tests for altstore-add-version.jq: per-language notes (owner msg 2561), the golden outputs of the
Classic, SideStore and beta calls, and the AltStore PAL entry (20-03; Research §4)."""

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
FIXTURES = TOOLS / "tests" / "fixtures"
GOLDEN = FIXTURES / "add-version-golden"
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



def golden_cases():
    """The three call shapes the workflows make today, as (name, jq arguments). Each runs on the frozen
    `<name>.input.json` and must print `<name>.output.json` byte for byte: the PAL arguments leave
    every other source as it was. The outputs were captured from the filter before PAL mode existed."""
    release = ["--arg", "version", "9.9.9", "--arg", "buildVersion", "999", "--arg", "marketingVersion", "9.9.9",
               "--arg", "date", "2026-11-08T00:00:00Z", "--arg", "localizedDescription", NOTES["en"],
               "--arg", "sha256", "ff" * 32, "--arg", "minOSVersion", "27.0", "--argjson", "size", "7400000"]
    privacy = json.dumps({"NSFaceIDUsageDescription": "Face ID.", "NSCameraUsageDescription": "Camera."})
    download = "https://github.com/EhPanda-Team/EhPanda/releases/download/9.9.9/"
    return [
        ("classic", ["--arg", "bundleIdentifier", "app.ehpanda", *release,
                     "--argjson", "localizedDescriptions", json.dumps(NOTES, ensure_ascii=False),
                     "--arg", "downloadURL", download + "EhPanda-AltStore.ipa",
                     "--argjson", "privacy", privacy, "--argjson", "releaseVersions", "null"]),
        ("sidestore", ["--arg", "bundleIdentifier", "app.ehpanda", *release,
                       "--argjson", "localizedDescriptions", "null",
                       "--arg", "downloadURL", download + "EhPanda-SideStore.ipa",
                       "--argjson", "privacy", privacy, "--argjson", "releaseVersions", "null"]),
        # deploy-beta.yml passes no localizedDescriptions, and the regular releases as releaseVersions.
        ("beta", ["--arg", "bundleIdentifier", "app.ehpanda.beta", *release,
                  "--arg", "downloadURL", download + "EhPanda-Beta.ipa",
                  "--argjson", "privacy", privacy,
                  "--argjson", "releaseVersions", json.dumps([{"version": "2.8.1", "buildVersion": "158"}])]),
    ]


def run_filter(args, source_text):
    return subprocess.run(["jq", *args, "-f", str(FILTER)], input=source_text, capture_output=True, text=True,
                          encoding="utf-8")


@unittest.skipUnless(shutil.which("jq"), "jq is not installed")
class GoldenOutputTests(unittest.TestCase):
    def test_classic_sidestore_and_beta_output_is_unchanged(self):
        for name, args in golden_cases():
            with self.subTest(source=name):
                source_text = (GOLDEN / f"{name}.input.json").read_text(encoding="utf-8")
                result = run_filter(args, source_text)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, (GOLDEN / f"{name}.output.json").read_text(encoding="utf-8"))

    def test_the_beta_case_still_drops_betas_older_than_the_release(self):
        # Keeps the golden beta case meaningful: 3.0.0 (157) is newer than 2.8.1 and stays; 2.8.0 goes.
        versions = json.loads((GOLDEN / "beta.output.json").read_text(encoding="utf-8"))["apps"][0]["versions"]
        self.assertEqual([(v["version"], v["buildVersion"]) for v in versions], [("9.9.9", "999"), ("3.0.0", "157")])


PAL_ASSETS = json.loads((FIXTURES / "pal-release-assets.json").read_text(encoding="utf-8"))
PAL_PREFIX = "EhPanda-AltStorePAL-"
PAL_SOURCE = {
    "name": "EhPanda",
    "identifier": "app.ehpanda.altstorepal",
    "subtitle": "Subtitle.",
    "description": "Description.",
    "iconURL": "https://example.com/icon.png",
    "nsfw": True,
    "apps": [{
        "name": "EhPanda",
        "bundleIdentifier": "app.ehpanda.marketplace",
        "marketplaceID": "",
        "developerName": "EhPanda Team",
        "subtitle": "Subtitle.",
        "localizedDescription": "Description.",
        "iconURL": "https://example.com/icon.png",
        "appPermissions": {"entitlements": ["get-task-allow", "keychain-access-groups"], "privacy": {}},
    }],
}


def pal_asset_urls(assets=PAL_ASSETS):
    """`assetURLs` as 20-05 builds it: each ADP file's name without its extension, to its asset's URL."""
    urls = {}
    for asset in assets:
        if asset["name"].startswith(PAL_PREFIX):
            file_name = asset["name"][len(PAL_PREFIX):]
            urls[file_name.rsplit(".", 1)[0] if "." in file_name else file_name] = asset["browser_download_url"]
    return urls


@unittest.skipUnless(shutil.which("jq"), "jq is not installed")
class PALEntryTests(unittest.TestCase):
    ENTITLEMENTS = ["application-identifier", "com.apple.developer.team-identifier", "get-task-allow",
                    "keychain-access-groups"]

    def add(self, source=PAL_SOURCE, asset_urls=None, download_url=None, entitlements=ENTITLEMENTS,
            marketplace_id="6740000001", sha256=None, version="3.0.0", build="159", extra=()):
        asset_urls = pal_asset_urls() if asset_urls is None else asset_urls
        download_url = asset_urls.get("manifest") if download_url is None else download_url
        args = ["--arg", "bundleIdentifier", "app.ehpanda.marketplace", "--arg", "version", version,
                "--arg", "buildVersion", build, "--arg", "marketingVersion", version,
                "--arg", "date", "2026-11-09T00:00:00Z", "--arg", "localizedDescription", NOTES["en"],
                "--argjson", "localizedDescriptions", json.dumps(NOTES, ensure_ascii=False),
                "--arg", "downloadURL", download_url or "", "--arg", "minOSVersion", "27.0",
                "--argjson", "size", "7400000", "--argjson", "privacy", json.dumps({"NSFaceIDUsageDescription": "Face ID."}),
                "--argjson", "releaseVersions", "null", "--argjson", "assetURLs", json.dumps(asset_urls)]
        if sha256 is not None:
            args += ["--arg", "sha256", sha256]
        if entitlements is not None:
            args += ["--argjson", "entitlements", json.dumps(entitlements)]
        if marketplace_id is not None:
            args += ["--arg", "marketplaceID", marketplace_id]
        return run_filter([*args, *extra], json.dumps(source))

    def entry(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)["apps"][0]["versions"][0]

    def test_the_fixture_is_an_adp_on_a_release(self):
        urls = pal_asset_urls()
        self.assertEqual(sorted(urls), sorted(["manifest", "signature", "8F0C2C7E-4F5B-4C55-9C1B-3E2A6D1B9A70"]))
        for url in urls.values():
            self.assertTrue(url.startswith("https://github.com/EhPanda-Team/EhPanda/releases/download/3.0.0/"), url)

    def test_a_pal_entry_points_at_the_manifest_and_has_no_sha256(self):
        entry = self.entry(self.add())
        self.assertEqual(list(entry), ["version", "buildVersion", "marketingVersion", "date", "localizedDescription",
                                       "localizedDescriptions", "downloadURL", "assetURLs", "size", "minOSVersion"])
        self.assertEqual(entry["downloadURL"], entry["assetURLs"]["manifest"])
        self.assertEqual(entry["assetURLs"], pal_asset_urls())
        self.assertNotIn("sha256", entry)
        self.assertEqual(entry["size"], 7400000)

    def test_an_empty_sha256_is_accepted_and_left_out(self):
        self.assertNotIn("sha256", self.entry(self.add(sha256="")))

    def test_a_sha256_with_asset_urls_fails(self):
        self.assertIn("no sha256", self.add(sha256="ff").stderr)

    def test_bad_asset_urls_fail(self):
        urls = pal_asset_urls()
        manifest = urls["manifest"]
        no_manifest = {key: value for key, value in urls.items() if key != "manifest"}
        cases = {
            "must have a manifest": (no_manifest, manifest),
            "https URLs": ({**urls, "signature": "http://example.com/signature"}, manifest),
            "https URLs ": ({**urls, "signature": ""}, manifest),
            "an object": (["manifest"], manifest),
            "differs from downloadURL": (urls, manifest.replace("manifest", "other")),
        }
        for message, (asset_urls, download_url) in cases.items():
            with self.subTest(message=message):
                result = self.add(asset_urls=asset_urls, download_url=download_url)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message.strip(), result.stderr)

    def test_entitlements_replace_the_list_without_the_two_identity_keys(self):
        result = self.add()
        self.assertEqual(result.returncode, 0, result.stderr)
        permissions = json.loads(result.stdout)["apps"][0]["appPermissions"]
        self.assertEqual(permissions["entitlements"], ["get-task-allow", "keychain-access-groups"])
        self.assertEqual(permissions["privacy"], {"NSFaceIDUsageDescription": "Face ID."})
        source = json.loads(json.dumps(PAL_SOURCE))
        source["apps"][0]["appPermissions"]["entitlements"] = ["beta-reports-active"]
        result = self.add(source=source, entitlements=["keychain-access-groups"])
        self.assertEqual(json.loads(result.stdout)["apps"][0]["appPermissions"]["entitlements"],
                         ["keychain-access-groups"])

    def test_without_entitlements_the_list_is_kept(self):
        result = self.add(entitlements=None)
        self.assertEqual(json.loads(result.stdout)["apps"][0]["appPermissions"]["entitlements"],
                         PAL_SOURCE["apps"][0]["appPermissions"]["entitlements"])

    def test_entitlements_must_be_a_list_of_strings(self):
        for bad in [{"a": 1}, ["ok", 1], "keychain-access-groups"]:
            with self.subTest(entitlements=bad):
                self.assertIn("entitlements must be", self.add(entitlements=bad).stderr)

    def test_marketplace_id_is_set_once_and_then_must_match(self):
        result = self.add()
        self.assertEqual(result.returncode, 0, result.stderr)
        written = json.loads(result.stdout)
        self.assertEqual(written["apps"][0]["marketplaceID"], "6740000001")
        self.assertEqual(self.add(source=written, version="3.0.1", build="160").returncode, 0)
        self.assertIn("marketplaceID mismatch", self.add(source=written, marketplace_id="6740000002").stderr)
        for bad in ["", "67400x", "12 3"]:
            with self.subTest(marketplace_id=bad):
                self.assertIn("marketplaceID must be", self.add(marketplace_id=bad).stderr)

    def test_without_marketplace_id_the_source_keeps_its_own(self):
        result = self.add(marketplace_id=None)
        self.assertEqual(json.loads(result.stdout)["apps"][0]["marketplaceID"], "")

    def test_a_marketplace_id_is_not_added_to_a_source_without_one(self):
        source = json.loads(json.dumps(PAL_SOURCE))
        del source["apps"][0]["marketplaceID"]
        self.assertNotIn("marketplaceID", json.loads(self.add(source=source, marketplace_id=None).stdout)["apps"][0])

    def test_a_rerun_of_the_same_version_and_build_replaces_its_entry(self):
        first = json.loads(self.add().stdout)
        again = self.add(source=first)
        self.assertEqual(again.returncode, 0, again.stderr)
        versions = json.loads(again.stdout)["apps"][0]["versions"]
        self.assertEqual([(v["version"], v["buildVersion"]) for v in versions], [("3.0.0", "159")])
        newer = json.loads(self.add(source=first, version="3.0.1", build="160").stdout)["apps"][0]["versions"]
        self.assertEqual([(v["version"], v["buildVersion"]) for v in newer], [("3.0.1", "160"), ("3.0.0", "159")])

    def test_a_classic_call_still_needs_its_sha256(self):
        args = ["--arg", "bundleIdentifier", "app.ehpanda", "--arg", "version", "9.9.9", "--arg", "buildVersion",
                "999", "--arg", "marketingVersion", "9.9.9", "--arg", "date", "2026-11-08T00:00:00Z",
                "--arg", "localizedDescription", "Notes.", "--arg", "downloadURL", "https://example.com/a.ipa",
                "--arg", "minOSVersion", "17.0", "--argjson", "size", "2", "--argjson", "privacy", "{}",
                "--argjson", "releaseVersions", "null"]
        result = run_filter(args, json.dumps(SOURCE))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sha256", result.stderr)


if __name__ == "__main__":
    unittest.main()
