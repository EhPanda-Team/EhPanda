"""The SideStore, beta and AltStore PAL source templates, as AltStore and SideStore read the sources
they seed (owner msg 2561; copy from Camo msg 2563; the PAL template from 20-03, Research §4)."""

import copy
import json
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import altstore_languages as languages  # noqa: E402

SIDESTORE = json.loads((TOOLS / "sidestore.template.json").read_text(encoding="utf-8"))
BETA = json.loads((TOOLS / "altstore-beta.template.json").read_text(encoding="utf-8"))
PAL = json.loads((TOOLS / "altstore-pal.template.json").read_text(encoding="utf-8"))
ALTSTORE = json.loads((TOOLS.parent / "AltStore.json").read_text(encoding="utf-8"))
ICON_URL = f"{languages.ASSETS_URL}app-marketplace/icon.png"
HEADER_URL = f"{languages.ASSETS_URL}app-marketplace/header.png"
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


# What a source does not say (owner msg 3827): "Apple ID" in any spelling, a count of apps (3 apps, 3 Apps, 3 つ,
# 3개, 3 个, 3 個) or AltStore's own name. It looks at the source's and its app's texts, not the release notes.
NOT_FOR_A_SOURCE = {
    "an Apple ID": re.compile(r"Apple[ -]?ID", re.IGNORECASE),
    "a number of apps": re.compile(r"(?<![\d.])\d+\s*(?:apps?|つ|개|个|個)", re.IGNORECASE),
    "AltStore": re.compile(r"AltStore", re.IGNORECASE),
}
SOURCE_TEXT_KEYS = {"name", "subtitle", "description", "localizedSubtitles", "localizedDescriptions",
                    "localizedDescription", "tintColor", "website"}


def source_texts(source):
    """(where, text) for every text of `source` and of its apps that people read, versions left out."""
    def walk(where, value):
        if isinstance(value, str):
            yield where, value
        elif isinstance(value, dict):
            for key, item in value.items():
                yield from walk(f"{where}.{key}", item)

    for key in SOURCE_TEXT_KEYS & set(source):
        yield from walk(key, source[key])
    for app in source["apps"]:
        for key in SOURCE_TEXT_KEYS & set(app):
            yield from walk(f"{app['bundleIdentifier']}.{key}", app[key])


class SourceTemplateTests(unittest.TestCase):
    def test_both_templates_are_readable_sources_without_versions(self):
        # The first release adds the first version; neither source is ever written without one.
        for template in [SIDESTORE, BETA]:
            with self.subTest(source=template["identifier"]):
                self.assertEqual(languages.check_source(template, versions_required=False), [])
                self.assertEqual(template["apps"][0].get("versions", []), [])

    def test_each_device_gets_its_language(self):
        for template in [SIDESTORE, BETA, PAL]:
            for entry in [template, template["apps"][0]]:
                for key in ["localizedSubtitles", "localizedDescriptions"]:
                    for preferred, code in DEVICES.items():
                        with self.subTest(source=template["identifier"], key=key, preferred=preferred):
                            self.assertEqual(languages.localized_value(entry[key], preferred), entry[key][code])

    def test_the_sidestore_source_and_app_share_the_regular_copy(self):
        app = SIDESTORE["apps"][0]
        self.assertEqual(SIDESTORE["localizedSubtitles"], app["localizedSubtitles"])
        self.assertEqual(SIDESTORE["localizedDescriptions"], app["localizedDescriptions"])

    def test_the_beta_template_is_altstore_json_with_only_its_own_identity(self):
        # Owner msgs 3824 and 3827: the beta source mirrors the regular one, every source and app key and value,
        # except what makes it a different app to AltStore. `versions` is left out: the template has none, and the
        # beta workflow adds the builds.
        expected = copy.deepcopy(ALTSTORE)
        expected["apps"][0].pop("versions")
        expected.update(name="EhPanda Beta", identifier="app.ehpanda.altstore.beta", featuredApps=["app.ehpanda.beta"])
        expected["apps"][0].update(name="EhPanda Beta", bundleIdentifier="app.ehpanda.beta")
        # `beta: true` is AltStore's isBeta, which shows its beta badge.
        app = {}
        for key, value in expected["apps"][0].items():
            if key == "appPermissions":
                app["beta"] = True
            app[key] = value
        expected["apps"][0] = app
        self.assertEqual(BETA, expected)
        # The same keys in the same order, so a diff of the two files shows only those values.
        self.assertEqual(list(BETA), list(ALTSTORE))
        self.assertEqual(list(BETA["apps"][0]), list(expected["apps"][0]))
        # Nothing but these values differs, whatever the template and AltStore.json hold.
        self.assertEqual(
            {key for key in ALTSTORE if key != "apps" and ALTSTORE[key] != BETA[key]},
            {"name", "identifier", "featuredApps"})
        self.assertEqual(
            {key for key in BETA["apps"][0] if ALTSTORE["apps"][0].get(key) != BETA["apps"][0][key]},
            {"name", "bundleIdentifier", "beta"})

    def test_only_the_beta_app_is_flagged_beta(self):
        # AltStore reads `beta` as isBeta and shows its beta badge; the regular apps are not betas.
        self.assertIs(BETA["apps"][0]["beta"], True)
        for source in [ALTSTORE, SIDESTORE, PAL]:
            with self.subTest(source=source["identifier"]):
                self.assertNotIn("beta", source["apps"][0])

    def test_the_permissions_are_the_ones_of_the_ipa_the_source_installs(self):
        # AltStore refuses an install whose permissions do not match the source's. The Classic, SideStore and beta
        # IPAs are built from this checkout, unsigned and with an empty CODE_SIGN_ENTITLEMENTS (deploy.yml and
        # deploy-beta.yml), so they carry this checkout's usage descriptions (App's and the extension's Info.plist)
        # and the keys of its entitlements file, which is none. Verified on an unsigned archive made with the
        # workflow's flags (codesign: "not signed at all"). The PAL build is signed and its release fills its list.
        privacy = {}
        for name in ["App/Info.plist", "ShareExtension/Info.plist"]:
            with (TOOLS.parent / name).open("rb") as handle:
                privacy.update({key: value for key, value in plistlib.load(handle).items()
                                if key.endswith("UsageDescription")})
        with (TOOLS.parent / "App" / "EhPanda.entitlements").open("rb") as handle:
            entitlements = sorted(plistlib.load(handle))
        self.assertEqual(entitlements, [])
        for source in [ALTSTORE, SIDESTORE, BETA]:
            with self.subTest(source=source["identifier"]):
                self.assertEqual(source["apps"][0]["appPermissions"], {"entitlements": entitlements, "privacy": privacy})

    def test_no_source_talks_about_apple_ids_or_how_many_apps_altstore_keeps(self):
        # Owner msg 3827: how many apps a free Apple ID can install is AltStore's business, not the source's.
        for source in [ALTSTORE, SIDESTORE, BETA, PAL]:
            for where, text in source_texts(source):
                with self.subTest(source=source["identifier"], where=where):
                    for name, needle in NOT_FOR_A_SOURCE.items():
                        self.assertEqual(needle.findall(text), [], f"{name}: {text}")

    def test_the_needles_find_the_sentences_the_beta_source_used_to_have(self):
        # The old beta copy, in each language: the check above must not pass only because it looks for the wrong thing.
        old = {
            "en": "With a free Apple ID, AltStore can keep only 3 apps at once, including AltStore itself.",
            "de": "Mit einer kostenlosen Apple-ID kann AltStore nur 3 Apps gleichzeitig behalten, AltStore selbst mitgezählt.",
            "ja": "無料の Apple ID では、AltStore でインストールしておけるアプリは AltStore 自体を含めて同時に 3 つまでです。",
            "ko": "무료 Apple ID로는 AltStore가 AltStore 자체를 포함해 앱을 동시에 3개까지만 유지할 수 있습니다.",
            "zh-Hans": "使用免费 Apple ID 时，AltStore 最多只能同时保留 3 个应用，包括 AltStore 本身。",
            "zh-Hant": "使用免費 Apple ID 時，AltStore 最多只能同時保留 3 個 App，包括 AltStore 本身。",
        }
        for code, text in old.items():
            with self.subTest(code=code):
                for name, needle in NOT_FOR_A_SOURCE.items():
                    self.assertTrue(needle.search(text), f"{name} is not found in {text}")
        clean = "EhPanda 3.0 is rebuilt for iOS 26 with 2 new modes. Toplists · Favorites · Hath Archives"
        for name, needle in NOT_FOR_A_SOURCE.items():
            self.assertIsNone(needle.search(clean), name)

    def test_every_app_shows_the_seven_iphone_screenshots(self):
        # Owner msg 2628: the same screenshots, in this order, for the regular, the beta and the PAL app
        # (20-10, closed with this set). The set is iPhone only; there is no iPad set.
        expected = [{"imageURL": f"{languages.ASSETS_URL}app-marketplace/iphone/{name}.png", "width": 1260, "height": 2736}
                    for name in SCREENSHOT_NAMES]
        for source in [ALTSTORE, SIDESTORE, BETA, PAL]:
            with self.subTest(source=source["identifier"]):
                self.assertEqual(source["apps"][0]["screenshots"], {"iphone": expected})

    def test_every_source_and_app_uses_the_icon_in_the_assets_repository(self):
        # The icon is served from the assets repository (owner msg 3824): the app repository's main branch has no icon
        # file to link to. Source and app have the same one.
        for source in [ALTSTORE, SIDESTORE, BETA, PAL]:
            for entry in [source, source["apps"][0]]:
                with self.subTest(source=source["identifier"]):
                    self.assertEqual(entry["iconURL"], ICON_URL)

    def test_every_source_shows_the_same_banner_from_the_assets_repository(self):
        # Owner msgs 3835 and 3848: one banner, AltStore's 3:2 source header, shared by every source.
        for source in [ALTSTORE, SIDESTORE, BETA, PAL]:
            with self.subTest(source=source["identifier"]):
                self.assertEqual(source["headerURL"], HEADER_URL)
                self.assertNotIn("headerURL", source["apps"][0])

    def test_the_banner_is_3_by_2(self):
        assets = assets_checkout()
        if assets is None:
            self.skipTest("no checkout of the assets repository")
        header = (assets / "app-marketplace" / "header.png").read_bytes()
        self.assertEqual(header[:8], b"\x89PNG\r\n\x1a\n")
        width, height = int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")
        self.assertEqual(width * 2, height * 3)

    def test_the_icon_and_the_screenshots_are_in_the_assets_repository(self):
        assets = assets_checkout()
        if assets is None:
            self.skipTest("no checkout of the assets repository")
        self.assertTrue((assets / "app-marketplace" / "icon.png").is_file())
        self.assertTrue((assets / "app-marketplace" / "header.png").is_file())
        for source in [ALTSTORE, SIDESTORE, BETA, PAL]:
            with self.subTest(source=source["identifier"]):
                problems = languages.check_source(source, versions_required=False, assets_dir=assets)
                self.assertEqual([problem for problem in problems
                                  if "screenshots" in problem or "iconURL" in problem or "headerURL" in problem], [])

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
        missing = [problem for problem in problems if "is not in the assets repository" in problem]
        self.assertEqual(len([problem for problem in missing if "screenshots" in problem]), 7)
        # The source's icon and the app's.
        self.assertEqual(len([problem for problem in missing if "iconURL app-marketplace/icon.png" in problem]), 2)
        # The source's banner.
        self.assertEqual(len([problem for problem in missing if "headerURL app-marketplace/header.png" in problem]), 1)
        self.assertEqual(len(missing), 10)

    def test_the_beta_names_are_not_translated(self):
        self.assertEqual(BETA["name"], "EhPanda Beta")
        self.assertEqual(BETA["apps"][0]["name"], "EhPanda Beta")



# The fields the PAL template may not share with AltStore.json (CONTEXT developer defaults): its own
# identity and featured app, the marketplace bundle ID and marketplaceID, and permissions read from the
# signed build. The screenshots are shared: 20-10 closed with the owner's seven (msg 2628).
PAL_SOURCE_OWN = {"identifier", "featuredApps"}
PAL_APP_OWN = {"bundleIdentifier", "marketplaceID", "appPermissions", "versions"}
FILTER = TOOLS / "altstore-add-version.jq"
PAL_ASSETS = json.loads((TOOLS / "tests" / "fixtures" / "pal-release-assets.json").read_text(encoding="utf-8"))


def pal_release(source, marketplace_id="6740000001", version="3.0.0", build="159"):
    """`source` with a release of the fixture ADP added by the filter, as 20-05's publish job will."""
    prefix = "EhPanda-AltStorePAL-"
    urls = {}
    for asset in PAL_ASSETS:
        if asset["name"].startswith(prefix):
            name = asset["name"][len(prefix):]
            # Each release has its own tag in the asset URLs.
            urls[name.rsplit(".", 1)[0] if "." in name else name] = \
                asset["browser_download_url"].replace("/3.0.0/", f"/{version}/")
    variant = next(a for a in PAL_ASSETS if a["name"].startswith(prefix) and a["name"].endswith(".ipa"))
    result = subprocess.run(
        ["jq", "--arg", "bundleIdentifier", "app.ehpanda.marketplace", "--arg", "version", version,
         "--arg", "buildVersion", build, "--arg", "marketingVersion", version, "--arg", "date",
         "2026-11-09T00:00:00Z", "--arg", "localizedDescription", "Notes.",
         "--argjson", "localizedDescriptions", json.dumps({"en": "Notes.", "de": "Notizen."}),
         "--arg", "downloadURL", urls["manifest"], "--arg", "minOSVersion", "27.0",
         "--argjson", "size", str(variant["size"]), "--argjson", "privacy", "{}",
         "--argjson", "releaseVersions", "null", "--argjson", "assetURLs", json.dumps(urls),
         "--argjson", "entitlements", json.dumps(["application-identifier", "keychain-access-groups"]),
         "--arg", "marketplaceID", marketplace_id, "-f", str(FILTER)],
        input=json.dumps(source), capture_output=True, text=True, encoding="utf-8", check=True)
    return json.loads(result.stdout)


class PALTemplateTests(unittest.TestCase):
    def test_the_pal_template_is_the_marketplace_app_with_no_versions(self):
        app = PAL["apps"][0]
        self.assertEqual(PAL["identifier"], "app.ehpanda.altstorepal")
        self.assertIs(PAL["nsfw"], True)
        self.assertEqual(PAL["featuredApps"], ["app.ehpanda.marketplace"])
        self.assertEqual(app["bundleIdentifier"], "app.ehpanda.marketplace")
        self.assertEqual(app["marketplaceID"], "")
        self.assertEqual(app["developerName"], "EhPanda Team")  # D-24
        self.assertEqual(app["appPermissions"], {"entitlements": [], "privacy": {}})
        self.assertEqual(app.get("versions", []), [])
        self.assertFalse((TOOLS.parent / "AltStorePAL.json").exists(), "only the first PAL publish creates it")

    def test_the_pal_template_has_the_classic_metadata(self):
        # D-16: the website's copy, https://ehpanda.app and #557F72, as AltStore.json has them.
        self.assertEqual({k: v for k, v in PAL.items() if k not in PAL_SOURCE_OWN | {"apps"}},
                         {k: v for k, v in ALTSTORE.items() if k not in PAL_SOURCE_OWN | {"apps"}})
        self.assertEqual({k: v for k, v in PAL["apps"][0].items() if k not in PAL_APP_OWN},
                         {k: v for k, v in ALTSTORE["apps"][0].items() if k not in PAL_APP_OWN})

    def test_the_pal_template_keeps_the_sidestore_field_order(self):
        self.assertEqual([k for k in PAL if k != "apps"], [k for k in SIDESTORE if k != "apps"])
        self.assertEqual([k for k in PAL["apps"][0] if k != "marketplaceID"],
                         list(SIDESTORE["apps"][0]))

    def test_the_template_alone_is_not_a_publishable_pal_source(self):
        problems = languages.check_source(PAL, pal=True)
        self.assertTrue(any("no versions" in problem for problem in problems), problems)
        self.assertTrue(any("marketplaceID" in problem for problem in problems), problems)

    @unittest.skipUnless(shutil.which("jq"), "jq is not installed")
    def test_the_template_with_a_release_is_a_pal_source(self):
        source = pal_release(PAL)
        self.assertEqual(languages.check_source(source, pal=True), [])
        self.assertEqual(source["apps"][0]["appPermissions"]["entitlements"], ["keychain-access-groups"])
        # A second release keeps the first (history).
        later = pal_release(source, version="3.0.1", build="160")
        self.assertEqual(languages.check_source(later, pal=True), [])
        self.assertEqual(len(later["apps"][0]["versions"]), 2)

    @unittest.skipUnless(shutil.which("jq"), "jq is not installed")
    def test_a_pal_source_that_altstore_pal_would_refuse_is_reported(self):
        good = pal_release(PAL)

        def mutated(change):
            source = copy.deepcopy(good)
            change(source, source["apps"][0], source["apps"][0]["versions"][0])
            return languages.check_source(source, pal=True)

        cases = {
            "has a sha256": lambda s, a, v: v.update(sha256="ff"),
            "no marketplaceID": lambda s, a, v: a.pop("marketplaceID"),
            "marketplaceID '' is not": lambda s, a, v: a.update(marketplaceID=""),
            "marketplaceID 'abc' is not": lambda s, a, v: a.update(marketplaceID="abc"),
            "nsfw is not true": lambda s, a, v: s.update(nsfw=False),
            "no assetURLs": lambda s, a, v: v.pop("assetURLs"),
            "downloadURL is not assetURLs.manifest": lambda s, a, v: v.update(downloadURL=v["assetURLs"]["signature"]),
            "assetURLs has no manifest": lambda s, a, v: v["assetURLs"].pop("manifest"),
            "assetURLs.signature is not an https URL": lambda s, a, v: v["assetURLs"].update(signature="http://x/s"),
            "size 0 is not": lambda s, a, v: v.update(size=0),
            "size True is not": lambda s, a, v: v.update(size=True),
            "no downloadURL": lambda s, a, v: v.pop("downloadURL"),
        }
        for message, change in cases.items():
            with self.subTest(message=message):
                problems = mutated(change)
                self.assertTrue(any(message in problem for problem in problems), problems)

    @unittest.skipUnless(shutil.which("jq"), "jq is not installed")
    def test_without_pal_the_checks_are_unchanged(self):
        # SideStore refuses a marketplaceID, and a Classic entry needs its sha256.
        problems = languages.check_source(pal_release(PAL))
        self.assertTrue(any("has a marketplaceID, which SideStore refuses" in problem for problem in problems))
        self.assertTrue(any("no sha256" in problem for problem in problems), problems)
        for template in [SIDESTORE, BETA]:
            with self.subTest(source=template["identifier"]):
                self.assertTrue(any("marketplaceID" in problem
                                    for problem in languages.check_source(template, versions_required=False, pal=True)))


if __name__ == "__main__":
    unittest.main()
