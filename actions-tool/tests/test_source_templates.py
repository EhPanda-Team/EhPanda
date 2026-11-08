"""The SideStore and beta source templates, as AltStore and SideStore read the sources they seed
(owner msg 2561; copy from Camo msg 2563)."""

import json
import pathlib
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import altstore_languages as languages  # noqa: E402

SIDESTORE = json.loads((TOOLS / "sidestore.template.json").read_text(encoding="utf-8"))
BETA = json.loads((TOOLS / "altstore-beta.template.json").read_text(encoding="utf-8"))
DEVICES = {("en-US",): "en", ("de-DE",): "de", ("ja-JP",): "ja", ("ko-KR",): "ko",
           ("zh-Hans-CN",): "zh-Hans", ("zh-Hant-TW",): "zh-Hant", ("zh-Hant-HK",): "zh-Hant"}


class SourceTemplateTests(unittest.TestCase):
    def test_both_templates_are_readable_sources_without_versions(self):
        # The first release adds the first version; neither source is ever written without one.
        for template in [SIDESTORE, BETA]:
            with self.subTest(source=template["identifier"]):
                self.assertEqual(languages.check_source(template, versions_required=False), [])
                self.assertEqual(template["apps"][0].get("versions", []), [])

    def test_each_device_gets_its_language(self):
        for template in [SIDESTORE, BETA]:
            for entry in [template, template["apps"][0]]:
                for key in ["localizedSubtitles", "localizedDescriptions"]:
                    for preferred, code in DEVICES.items():
                        with self.subTest(source=template["identifier"], key=key, preferred=preferred):
                            self.assertEqual(languages.localized_value(entry[key], preferred), entry[key][code])

    def test_the_sidestore_source_and_app_share_the_regular_copy(self):
        app = SIDESTORE["apps"][0]
        self.assertEqual(SIDESTORE["localizedSubtitles"], app["localizedSubtitles"])
        self.assertEqual(SIDESTORE["localizedDescriptions"], app["localizedDescriptions"])

    def test_the_beta_app_description_ends_with_the_regular_description(self):
        regular = SIDESTORE["apps"][0]["localizedDescriptions"]
        beta = BETA["apps"][0]["localizedDescriptions"]
        for code in languages.CODES:
            with self.subTest(code=code):
                self.assertTrue(beta[code].endswith("\n" + regular[code]))
                # The two beta lines, then the regular description.
                self.assertEqual(beta[code].count("\n"), 2 + regular[code].count("\n"))

    def test_the_beta_names_are_not_translated(self):
        self.assertEqual(BETA["name"], "EhPanda Beta")
        self.assertEqual(BETA["apps"][0]["name"], "EhPanda Beta")


if __name__ == "__main__":
    unittest.main()
