"""Tests for the app's privacy manifest, `App/PrivacyInfo.xcprivacy` (Phase 20 D-18).

App Store Connect refuses a build that uses a required-reason API without declaring it, and the
AltStore PAL build is notarized through App Store Connect, so the manifest ships in every build. The
manifest itself carries no comments; the reasons for each entry are recorded here.

Required-reason APIs the app's own code uses (the dependencies ship their own manifests):

* `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (data only the app itself reads):
  `UserDefaults.standard` in `AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift`
  (lines 13 and 16), and the Sharing `appStorage` keys in
  `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` (line 55 onwards). No app group
  suite is used.
* `NSPrivacyAccessedAPICategoryFileTimestamp`, reason `C617.1` (files inside the app container):
  `contentModificationDateKey` in `AppPackage/Sources/AppComponents/PreviewImageView.swift`
  (line 66) and `AppPackage/Sources/DownloadClient/DownloadStore.swift` (lines 660 and 688), and
  the creation and modification dates in `AppPackage/Sources/AppTools/DataCache.swift` (lines 306
  and 330 to 331). Every one of them reads the app's own cache or download folders.

Not used, so not declared: disk space, system boot time and active keyboards. The test below greps
for them and fails once one appears. The share extension uses no required-reason API, so it has
no manifest.

Data collected, through TelemetryDeck, as the README's "Analytics" section describes it. None of
it is linked to the user, none is used for tracking (`NSPrivacyTracking` is false), and the only
purpose is analytics:

* `NSPrivacyCollectedDataTypeProductInteraction`: the screens and features used (Basic and Full).
* `NSPrivacyCollectedDataTypeDeviceID`: the random per-install identifier of the install signal
  and TelemetryDeck's hashed per-install identifier.
* `NSPrivacyCollectedDataTypeOtherDiagnosticData`: the kinds of errors that occur (Basic and Full).
"""

import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "App" / "PrivacyInfo.xcprivacy"
SOURCE_ROOTS = [ROOT / "AppPackage" / "Sources", ROOT / "App", ROOT / "ShareExtension"]

EXPECTED_REASONS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
    "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
}
EXPECTED_DATA_TYPES = [
    "NSPrivacyCollectedDataTypeProductInteraction",
    "NSPrivacyCollectedDataTypeDeviceID",
    "NSPrivacyCollectedDataTypeOtherDiagnosticData",
]

# The symbols Apple lists for each required-reason category ("Describing use of required reason
# API"), plus the Swift spellings that reach them (`appStorage`, `attributesOfItem`,
# `attributesOfFileSystem`).
API_PATTERNS = {
    "NSPrivacyAccessedAPICategoryUserDefaults": [
        r"\bUserDefaults\b", r"\bNSUserDefaults\b", r"@AppStorage\b", r"\.appStorage\(",
    ],
    "NSPrivacyAccessedAPICategoryFileTimestamp": [
        r"\bcreationDate(Key)?\b", r"\bcontentModificationDate(Key)?\b", r"\bfileModificationDate\b",
        r"\.modificationDate\b", r"\battributesOfItem\b", r"\b(f|l)?stat(at)?\(",
        r"\b(f)?getattrlist(at|bulk)?\(",
    ],
    "NSPrivacyAccessedAPICategorySystemBootTime": [
        r"\bsystemUptime\b", r"\bmach_absolute_time\b",
    ],
    "NSPrivacyAccessedAPICategoryDiskSpace": [
        r"\bvolumeAvailableCapacity\w*Key\b", r"\bvolumeTotalCapacityKey\b", r"\bsystemFreeSize\b",
        r"\bsystemSize\b", r"\battributesOfFileSystem\b", r"\b(f)?statv?fs\(",
    ],
    "NSPrivacyAccessedAPICategoryActiveKeyboards": [
        r"\bactiveInputModes\b",
    ],
}
SOURCE_SUFFIXES = {".swift", ".m", ".mm", ".h", ".c"}


def load_manifest():
    with MANIFEST.open("rb") as file:
        return plistlib.load(file)


def shipped_sources():
    """The app's, the extension's and the package's sources, without UI-test support or tests."""
    for root in SOURCE_ROOTS:
        for path in sorted(root.rglob("*")):
            if path.suffix not in SOURCE_SUFFIXES or not path.is_file():
                continue
            parts = path.relative_to(ROOT).parts
            if "UITestSupport" in parts or any(part.endswith("Tests") for part in parts):
                continue
            yield path


def code_lines(path):
    """The lines of `path` that are not comments, so a doc comment naming an API is not a use."""
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith(("//", "*", "/*")):
            continue
        yield number, line


def categories_used():
    """Each required-reason category the shipped code uses, with the places it is used."""
    found = {}
    for path in shipped_sources():
        for number, line in code_lines(path):
            for category, patterns in API_PATTERNS.items():
                if any(re.search(pattern, line) for pattern in patterns):
                    found.setdefault(category, []).append(f"{path.relative_to(ROOT)}:{number}")
    return found


class PrivacyManifestShapeTests(unittest.TestCase):
    def test_nothing_is_tracked(self):
        manifest = load_manifest()
        self.assertIs(manifest["NSPrivacyTracking"], False)
        self.assertEqual(manifest["NSPrivacyTrackingDomains"], [])

    def test_declares_exactly_the_two_api_categories_with_their_reasons(self):
        entries = load_manifest()["NSPrivacyAccessedAPITypes"]
        declared = {entry["NSPrivacyAccessedAPIType"]: entry["NSPrivacyAccessedAPITypeReasons"]
                    for entry in entries}
        self.assertEqual(len(entries), len(declared), "a category is declared twice")
        self.assertEqual(declared, EXPECTED_REASONS)
        for entry in entries:
            self.assertEqual(sorted(entry), ["NSPrivacyAccessedAPIType", "NSPrivacyAccessedAPITypeReasons"])

    def test_declares_the_three_collected_types_unlinked_untracked_for_analytics(self):
        entries = load_manifest()["NSPrivacyCollectedDataTypes"]
        self.assertEqual([entry["NSPrivacyCollectedDataType"] for entry in entries], EXPECTED_DATA_TYPES)
        for entry in entries:
            with self.subTest(entry["NSPrivacyCollectedDataType"]):
                self.assertIs(entry["NSPrivacyCollectedDataTypeLinked"], False)
                self.assertIs(entry["NSPrivacyCollectedDataTypeTracking"], False)
                self.assertEqual(entry["NSPrivacyCollectedDataTypePurposes"],
                                 ["NSPrivacyCollectedDataTypePurposeAnalytics"])
                self.assertEqual(len(entry), 4)

    def test_has_no_other_top_level_keys(self):
        self.assertEqual(sorted(load_manifest()), [
            "NSPrivacyAccessedAPITypes", "NSPrivacyCollectedDataTypes",
            "NSPrivacyTracking", "NSPrivacyTrackingDomains",
        ])

    def test_is_xml_with_tabs_and_sorted_keys_as_xcode_writes_it(self):
        text = MANIFEST.read_bytes()
        self.assertEqual(text, plistlib.dumps(load_manifest(), fmt=plistlib.FMT_XML, sort_keys=True))


class RequiredReasonUsageTests(unittest.TestCase):
    def test_every_category_the_code_uses_is_declared(self):
        declared = {entry["NSPrivacyAccessedAPIType"]
                    for entry in load_manifest()["NSPrivacyAccessedAPITypes"]}
        undeclared = {category: places for category, places in categories_used().items()
                      if category not in declared}
        self.assertEqual(undeclared, {}, "required-reason API used but not declared")

    def test_every_declared_category_is_used(self):
        used = categories_used()
        for category in EXPECTED_REASONS:
            with self.subTest(category):
                self.assertIn(category, used, "declared but no use found; the grep or the manifest is stale")

    def test_the_scan_covers_the_known_uses(self):
        used = categories_used()
        self.assertTrue(any("UserDefaultsClient.swift" in place
                            for place in used["NSPrivacyAccessedAPICategoryUserDefaults"]))
        timestamps = used["NSPrivacyAccessedAPICategoryFileTimestamp"]
        for name in ("PreviewImageView.swift", "DataCache.swift", "DownloadStore.swift"):
            with self.subTest(name):
                self.assertTrue(any(name in place for place in timestamps))

    def test_only_the_app_has_a_manifest(self):
        manifests = sorted(str(path.relative_to(ROOT)) for root in SOURCE_ROOTS[1:]
                           for path in root.rglob("PrivacyInfo.xcprivacy"))
        self.assertEqual(manifests, ["App/PrivacyInfo.xcprivacy"])


if __name__ == "__main__":
    unittest.main()
