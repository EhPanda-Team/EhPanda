"""The SideStore and beta source templates, as AltStore and SideStore read the sources they seed
(owner msg 2561; copy from Camo msg 2563)."""

import json
import os
import pathlib
import subprocess
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import altstore_languages as languages  # noqa: E402

SIDESTORE = json.loads((TOOLS / "sidestore.template.json").read_text(encoding="utf-8"))
BETA = json.loads((TOOLS / "altstore-beta.template.json").read_text(encoding="utf-8"))
ALTSTORE = json.loads((TOOLS.parent / "AltStore.json").read_text(encoding="utf-8"))
SCREENSHOT_NAMES = ["01-home", "02-detail", "03-reading", "04-comments", "05-downloads", "06-filters", "07-more"]


def assets_checkout():
    """A checkout of the assets repository: $EHPANDA_ASSETS, or `ehpanda-assets` next to the app's
    checkout (the main one when this runs in a worktree). None where there is none, as on CI."""
    if os.environ.get("EHPANDA_ASSETS"):
        return pathlib.Path(os.environ["EHPANDA_ASSETS"])
    try:
        common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=TOOLS,
                                capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    candidate = pathlib.Path(common).parent.parent / "ehpanda-assets"
    return candidate if (candidate / "app-marketplace").is_dir() else None
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

    def test_every_app_shows_the_seven_iphone_screenshots(self):
        # Owner msg 2628: the same screenshots, in this order, for the regular and the beta app.
        expected = [{"imageURL": f"{languages.ASSETS_URL}app-marketplace/iphone/{name}.png", "width": 1260, "height": 2736}
                    for name in SCREENSHOT_NAMES]
        for source in [ALTSTORE, SIDESTORE, BETA]:
            with self.subTest(source=source["identifier"]):
                self.assertEqual(source["apps"][0]["screenshots"], {"iphone": expected})

    def test_the_screenshots_are_in_the_assets_repository(self):
        assets = assets_checkout()
        if assets is None:
            self.skipTest("no checkout of the assets repository")
        for source in [ALTSTORE, SIDESTORE, BETA]:
            with self.subTest(source=source["identifier"]):
                problems = languages.check_source(source, versions_required=False, assets_dir=assets)
                self.assertEqual([problem for problem in problems if "screenshots" in problem], [])

    def test_screenshots_altstore_cannot_read_are_reported(self):
        good = {"imageURL": f"{languages.ASSETS_URL}app-marketplace/iphone/01-home.png", "width": 1260, "height": 2736}
        cases = {
            "not an object": [good],
            "unknown devices": {"iphone": [good], "watch": [good]},
            "not a non-empty list": {"iphone": []},
            "exactly imageURL, width and height": {"iphone": [good["imageURL"]]},
            "is not an https URL": {"iphone": [dict(good, imageURL="http://example.com/a.png")]},
            "width 1260.0 is not a whole number": {"iphone": [dict(good, width=1260.0)]},
            "height 40000 is not a whole number": {"iphone": [dict(good, height=40000)]},
            "width True is not a whole number": {"iphone": [dict(good, width=True)]},
            "lists an image twice": {"iphone": [good, good]},
        }
        for message, screenshots in cases.items():
            with self.subTest(message=message):
                app = dict(SIDESTORE["apps"][0], screenshots=screenshots)
                problems = languages.check_source(dict(SIDESTORE, apps=[app]), versions_required=False)
                self.assertTrue(any(message in problem for problem in problems), problems)

    def test_a_screenshot_missing_from_the_assets_repository_is_reported(self):
        assets = pathlib.Path(self.id())  # a folder that does not exist
        problems = languages.check_source(SIDESTORE, versions_required=False, assets_dir=assets)
        self.assertEqual(len([problem for problem in problems if "is not in the assets repository" in problem]), 7)

    def test_the_beta_names_are_not_translated(self):
        self.assertEqual(BETA["name"], "EhPanda Beta")
        self.assertEqual(BETA["apps"][0]["name"], "EhPanda Beta")


if __name__ == "__main__":
    unittest.main()
