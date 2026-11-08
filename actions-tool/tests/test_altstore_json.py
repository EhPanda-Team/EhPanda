"""AltStore.json as AltStore and SideStore read it (owner msg 2561; copy from Camo msg 2563)."""

import json
import pathlib
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import altstore_languages as languages  # noqa: E402

ALTSTORE = json.loads((TOOLS.parent / "AltStore.json").read_text(encoding="utf-8"))
APP = ALTSTORE["apps"][0]

# A device's preferred languages as iOS reports them, and the text each should get.
DEVICES = {
    ("en-US",): "en",
    ("de-DE",): "de",
    ("de-AT", "en-US"): "de",
    ("ja-JP",): "ja",
    ("ko-KR",): "ko",
    ("zh-Hans-CN",): "zh-Hans",
    ("zh-Hant-TW",): "zh-Hant",
    ("zh-Hant-HK",): "zh-Hant",
    ("en-GB", "ja-JP"): "en",
}


class AltStoreJsonTests(unittest.TestCase):
    def test_altstore_and_sidestore_can_read_it(self):
        self.assertEqual(languages.check_source(ALTSTORE), [])

    def test_each_device_gets_its_language(self):
        for entry, key in [(ALTSTORE, "localizedSubtitles"), (ALTSTORE, "localizedDescriptions"),
                           (APP, "localizedSubtitles"), (APP, "localizedDescriptions")]:
            for preferred, code in DEVICES.items():
                with self.subTest(key=key, preferred=preferred):
                    self.assertEqual(languages.localized_value(entry[key], preferred), entry[key][code])

    def test_a_language_ehpanda_does_not_have_falls_back_to_english(self):
        # AltStore finds no key, so it reads the plain field, which is English.
        self.assertIsNone(languages.localized_value(APP["localizedDescriptions"], ["fr-FR"]))
        # Checked against the English entry, not a fixed text, so the copy can change (msg 2606).
        self.assertEqual(APP["localizedDescription"], APP["localizedDescriptions"]["en"])

    def test_the_source_and_the_app_share_their_copy(self):
        self.assertEqual(ALTSTORE["localizedSubtitles"], APP["localizedSubtitles"])
        self.assertEqual(ALTSTORE["localizedDescriptions"], APP["localizedDescriptions"])

    def test_old_split_versions_fall_back_to_english_for_missing_languages(self):
        version = next(item for item in APP["versions"] if item["version"] == "2.7.9")
        self.assertIsNone(languages.localized_value(version["localizedDescriptions"], ["ko-KR"]))
        self.assertEqual(languages.localized_value(version["localizedDescriptions"], ["zh-Hant-TW"]),
                         version["localizedDescriptions"]["zh-Hant"])


if __name__ == "__main__":
    unittest.main()
