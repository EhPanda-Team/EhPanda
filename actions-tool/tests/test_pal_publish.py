"""The AltStore PAL publish tool (`pal_publish.py`) against fakes (Phase 20 plan 20-05, amended
2026-11-21; D-19, D-26; Research §4, §5).

Nothing here reaches AltStore, App Store Connect or GitHub:
- AltStore is a local `http.server` that answers `GET /adps/<id>` and serves the ADP zip;
- `gh` is `fixtures/fake-gh/gh`, which keeps releases and their assets in a temporary directory and logs each call;
- `main` lives in a local bare repository, and the tool works in a clone of it;
- `main` carries an `AltStore.json` that lists the fixture's 3.0.0 (159), as the Classic release would (D-26).

The ADP is synthetic (`fixtures/adp/`) and has the layout of the real 3.0.0 ADP (20-08): `manifest.json`, with
Apple's field names and fixed bytes, `signature`, and `variant/<publicId>.ipa`, whose bytes are opaque because Apple
encrypts the variants. The entitlements and privacy keys come from the project's files, so the publish tests write
a small project of their own.
"""

import hashlib
import http.server
import json
import os
import pathlib
import plistlib
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import zipfile

TOOLS = pathlib.Path(__file__).resolve().parents[1]
ROOT = TOOLS.parent
TOOL = TOOLS / "pal_publish.py"
FIXTURES = pathlib.Path(__file__).resolve().parent / "fixtures"
ADP_FIXTURE = FIXTURES / "adp"
FAKE_GH = FIXTURES / "fake-gh" / "gh"
NOTES = FIXTURES / "release-notes" / "9.9.9.md"
sys.path.insert(0, str(TOOLS))

import altstore_languages as languages  # noqa: E402

REPO = "example-owner/example-repo"
VERSION = "3.0.0"
ADP_ID = "1a2b3c4d-0000-4000-8000-00000000adp1"
VARIANT = "fb855afc-8ce8-39b7-877e-63444105c95c"
MARKETPLACE_ID = "6448401697"
PREFIX = "EhPanda-AltStorePAL-"
VARIANT_PATH = f"variant/{VARIANT}.ipa"
# Like Apple's encrypted variants, these bytes are no zip and nothing can be read from them.
OPAQUE_VARIANT = b"".join(hashlib.sha256(bytes([index])).digest() for index in range(128))
JQ = shutil.which("jq")
GIT = shutil.which("git")


def sha256(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def build_adp(directory):
    """The synthetic ADP as a directory: manifest.json, signature and variant/<publicId>.ipa."""
    adp = pathlib.Path(directory)
    (adp / "variant").mkdir(parents=True)
    shutil.copyfile(ADP_FIXTURE / "manifest.json", adp / "manifest.json")
    shutil.copyfile(ADP_FIXTURE / "signature", adp / "signature")
    (adp / VARIANT_PATH).write_bytes(OPAQUE_VARIANT)
    return adp


def write_plist(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(value))
    return path


def zip_adp(adp, path):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(pathlib.Path(adp).rglob("*")):
            if file.is_file():
                archive.write(file, file.relative_to(adp).as_posix())
    return path


def classic_source(versions):
    return json.dumps({"apps": [{"bundleIdentifier": "app.ehpanda", "versions": versions}]}, indent=2) + "\n"


class FakeAltStore:
    """`GET /adps/<id>` answers the replies in `statuses` in turn (the last one repeats); a reply's
    `downloadURL` of "ZIP" becomes this server's URL for `zip_path`."""

    def __init__(self):
        self.statuses = []
        self.requests = []
        self.zip_path = None
        fake = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body, content_type="application/json"):
                self.send_response(status)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self):
                fake.requests.append(("GET", self.path, None))
                if self.path == "/download/adp.zip" and fake.zip_path:
                    return self.reply(200, pathlib.Path(fake.zip_path).read_bytes(), "application/zip")
                if self.path == f"/adps/{ADP_ID}" and fake.statuses:
                    status = dict(fake.statuses[0] if len(fake.statuses) == 1 else fake.statuses.pop(0))
                    if status.get("downloadURL") == "ZIP":
                        status["downloadURL"] = fake.base_url + "/download/adp.zip"
                    return self.reply(200, json.dumps(status).encode())
                self.reply(404, b'{"error":"not found"}')

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base_url = f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class ToolTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("FAKE_GH_", "PAL_", "ALTSTORE_", "GIT_"))}
        self.env.update({"PAL_GH": str(FAKE_GH)})

    def run_tool(self, *args, cwd=None):
        result = subprocess.run([sys.executable, str(TOOL), *args], capture_output=True, text=True, env=self.env,
                                cwd=cwd, timeout=120)
        self.output = result.stdout + result.stderr
        return result


class FetchTests(ToolTestCase):
    def setUp(self):
        super().setUp()
        self.altstore = FakeAltStore()
        self.addCleanup(self.altstore.close)
        self.env["ALTSTORE_API_URL"] = self.altstore.base_url
        self.adp = build_adp(self.tmp / "adp-source")
        self.altstore.zip_path = zip_adp(self.adp, self.tmp / "adp.zip")

    def test_fetch_waits_for_the_download_url_then_downloads_the_adp_unchanged(self):
        self.altstore.statuses = [{"status": "processing"}, {"status": "processing"},
                                  {"status": "completed", "downloadURL": "ZIP"}]
        out = self.tmp / "fetched"
        result = self.run_tool("fetch", "--adp-id", ADP_ID, "--out", str(out), "--interval", "0", "--timeout", "30")
        self.assertEqual(result.returncode, 0, self.output)
        polls = [request for request in self.altstore.requests if request[1] == f"/adps/{ADP_ID}"]
        self.assertEqual(len(polls), 3)
        self.assertEqual(sha256(out / "adp.zip"), sha256(self.altstore.zip_path))
        for name in ("manifest.json", "signature", VARIANT_PATH):
            with self.subTest(name=name):
                self.assertEqual(sha256(out / "adp" / name), sha256(self.adp / name))
        hashes = json.loads((out / "adp-files.json").read_text())
        self.assertEqual(hashes, {name: sha256(self.adp / name)
                                  for name in ("manifest.json", "signature", VARIANT_PATH)})

    def test_fetch_times_out_with_the_adp_id_and_altstores_status(self):
        self.altstore.statuses = [{"status": "processing"}]
        result = self.run_tool("fetch", "--adp-id", ADP_ID, "--out", str(self.tmp / "fetched"),
                               "--interval", "0.05", "--timeout", "0.3")
        self.assertEqual(result.returncode, 1)
        self.assertIn(ADP_ID, self.output)
        self.assertIn("processing", self.output)
        self.assertIn("timed out", self.output)

    def test_a_zip_and_a_directory_give_the_same_files(self):
        from_zip = self.tmp / "from-zip"
        from_dir = self.tmp / "from-dir"
        self.assertEqual(self.run_tool("fetch", "--from", str(self.altstore.zip_path), "--out", str(from_zip))
                         .returncode, 0, self.output)
        self.assertEqual(self.run_tool("fetch", "--from", str(self.adp), "--out", str(from_dir)).returncode, 0,
                         self.output)
        self.assertEqual(json.loads((from_zip / "adp-files.json").read_text()),
                         json.loads((from_dir / "adp-files.json").read_text()))

    def test_an_adp_without_a_signature_or_a_variant_is_refused(self):
        for missing in ("signature", VARIANT_PATH, "manifest.json"):
            with self.subTest(missing=missing):
                adp = build_adp(self.tmp / f"broken-{missing.replace('/', '-')}")
                (adp / missing).unlink()
                result = self.run_tool("fetch", "--from", str(adp), "--out", str(self.tmp / f"out-{missing[:4]}"))
                self.assertEqual(result.returncode, 1)
                self.assertIn(pathlib.Path(missing).suffix or pathlib.Path(missing).name, self.output)

    def test_a_zip_reaching_outside_its_folder_is_refused(self):
        path = self.tmp / "evil.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("manifest.json", "{}")
            archive.writestr("signature", "x")
            archive.writestr("../outside.ipa", "x")
        result = self.run_tool("fetch", "--from", str(path), "--out", str(self.tmp / "evil"))
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.tmp / "outside.ipa").exists())

    def test_two_files_with_the_same_name_are_refused(self):
        adp = build_adp(self.tmp / "twice")
        (adp / "other").mkdir()
        shutil.copyfile(adp / "signature", adp / "other" / "signature")
        result = self.run_tool("fetch", "--from", str(adp), "--out", str(self.tmp / "twice-out"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("signature", self.output)

    def test_a_download_url_that_is_not_https_is_refused(self):
        self.altstore.statuses = [{"status": "completed", "downloadURL": "http://example.com/adp.zip"}]
        result = self.run_tool("fetch", "--adp-id", ADP_ID, "--out", str(self.tmp / "fetched"), "--interval", "0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("https", self.output)


@unittest.skipUnless(JQ and GIT, "jq and git are needed")
class PublishTests(ToolTestCase):
    def setUp(self):
        super().setUp()
        # Git without the machine's configuration (signing, hooks), and with a fixed identity.
        (self.tmp / "gitconfig").write_text("")
        self.env.update({"GIT_CONFIG_GLOBAL": str(self.tmp / "gitconfig"), "GIT_CONFIG_NOSYSTEM": "1",
                         "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.invalid",
                         "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.invalid"})
        self.gh_state = self.tmp / "gh-state"
        self.gh_state.mkdir()
        self.gh_log = self.tmp / "gh.log"
        self.env.update({"FAKE_GH_STATE": str(self.gh_state), "FAKE_GH_LOG": str(self.gh_log)})
        self.make_release()
        self.bare = self.tmp / "origin.git"
        self.git("init", "-q", "--bare", "-b", "main", str(self.bare))
        seed = self.tmp / "seed"
        self.git("clone", "-q", self.bare.as_uri(), str(seed))
        (seed / "README.md").write_text("seed\n")
        (seed / "AltStore.json").write_text(classic_source([{"version": VERSION, "buildVersion": "159"}]))
        self.git("-C", str(seed), "add", "README.md", "AltStore.json")
        self.git("-C", str(seed), "commit", "-q", "-m", "seed")
        self.git("-C", str(seed), "push", "-q", "origin", "HEAD:refs/heads/main")
        self.checkout = self.tmp / "checkout"
        self.git("clone", "-q", self.bare.as_uri(), str(self.checkout))
        fetched = self.tmp / "fetched"
        result = self.run_tool("fetch", "--from", str(build_adp(self.tmp / "adp-source")), "--out", str(fetched))
        self.assertEqual(result.returncode, 0, self.output)
        self.fetched = fetched
        # The project's files, as the workflow passes them: an entitlements file per bundle that has one, and each
        # bundle's Info.plist. The identity keys are left out of the source, and a build setting is fine outside
        # the usage descriptions.
        project = self.tmp / "project"
        self.app_entitlements = write_plist(project / "App" / "EhPanda.entitlements", {
            "application-identifier": "TEAM.app.ehpanda.store", "com.apple.developer.team-identifier": "TEAM",
            "com.apple.security.application-groups": ["group.app.ehpanda.store"]})
        self.extension_entitlements = write_plist(project / "ShareExtension" / "ShareExtension.entitlements", {
            "com.apple.security.application-groups": ["group.app.ehpanda.store"],
            "keychain-access-groups": ["TEAM.app.ehpanda.store"]})
        self.app_info = write_plist(project / "App" / "Info.plist", {
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "NSPhotoLibraryAddUsageDescription": "Save images.", "NSCameraUsageDescription": "Scan codes."})
        self.extension_info = write_plist(project / "ShareExtension" / "Info.plist", {
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER).ShareExtension",
            "NSCameraUsageDescription": "Scan codes."})
        self.project_args = ["--entitlements", str(self.app_entitlements),
                             "--entitlements", str(self.extension_entitlements),
                             "--info-plist", str(self.app_info), "--info-plist", str(self.extension_info)]
        self.notes_dir = self.tmp / "notes"
        self.notes_dir.mkdir()
        shutil.copyfile(NOTES, self.notes_dir / f"{VERSION}.md")

    def git(self, *args, cwd=None):
        return subprocess.run([GIT, *args], capture_output=True, text=True, env=self.env, cwd=cwd,
                              check=True).stdout

    def replace_on_main(self, name, text):
        """Changes one file on main: writes `text` to it, or removes it when `text` is None."""
        checkout = str(self.checkout)
        self.git("-C", checkout, "pull", "-q", "--ff-only", "origin", "main")
        if text is None:
            self.git("-C", checkout, "rm", "-q", name)
        else:
            (self.checkout / name).write_text(text)
            self.git("-C", checkout, "add", name)
        self.git("-C", checkout, "commit", "-q", "-m", f"change {name}")
        self.git("-C", checkout, "push", "-q", "origin", "HEAD:refs/heads/main")

    def adp_with_manifest(self, name, **changes):
        """The fetched fixture ADP with some manifest fields changed."""
        adp = build_adp(self.tmp / name)
        manifest = json.loads((ADP_FIXTURE / "manifest.json").read_text())
        manifest.update(changes)
        (adp / "manifest.json").write_text(json.dumps(manifest))
        fetched = self.tmp / f"{name}-fetched"
        result = self.run_tool("fetch", "--from", str(adp), "--out", str(fetched))
        self.assertEqual(result.returncode, 0, self.output)
        return fetched

    def make_release(self, tag=VERSION):
        releases_path = self.gh_state / "releases.json"
        releases = json.loads(releases_path.read_text()) if releases_path.exists() else {}
        releases[tag] = {"tag_name": tag, "draft": False, "published_at": "2026-11-20T08:00:00Z", "assets": [
            {"name": "EhPanda-GitHub.ipa", "size": 100,
             "browser_download_url": f"https://github.com/{REPO}/releases/download/{tag}/EhPanda-GitHub.ipa"}]}
        releases_path.write_text(json.dumps(releases))

    def publish(self, *extra, project=None, marketplace_id=MARKETPLACE_ID, adp=None):
        return self.run_tool("publish", "--adp", str(adp or self.fetched), "--repo", REPO,
                             "--notes-dir", str(self.notes_dir), "--marketplace-id", marketplace_id, "--work",
                             str(self.tmp / "work"), "--retry-delay", "0",
                             *(self.project_args if project is None else project), *extra, cwd=self.checkout)

    def assert_refused_before_upload(self, result, *needles):
        self.assertEqual(result.returncode, 1, self.output)
        for needle in needles:
            self.assertIn(needle, self.output)
        self.assertEqual([call for call in self.gh_calls() if call[:2] == ["release", "upload"]], [])
        self.assertNotIn("AltStorePAL.json", self.main_files())

    def gh_calls(self):
        if not self.gh_log.exists():
            return []
        return [json.loads(line) for line in self.gh_log.read_text().splitlines()]

    def main_source(self):
        self.git("-C", str(self.checkout), "fetch", "-q", "origin", "main")
        return json.loads(self.git("-C", str(self.checkout), "show", "FETCH_HEAD:AltStorePAL.json"))

    def main_files(self):
        self.git("-C", str(self.checkout), "fetch", "-q", "origin", "main")
        return self.git("-C", str(self.checkout), "ls-tree", "--name-only", "FETCH_HEAD").split()

    def test_publish_uploads_the_adp_and_writes_the_pal_source_on_main(self):
        result = self.publish()
        self.assertEqual(result.returncode, 0, self.output)
        uploads = [call for call in self.gh_calls() if call[:2] == ["release", "upload"]]
        self.assertEqual(len(uploads), 1)
        self.assertEqual(sorted(pathlib.Path(arg).name for arg in uploads[0][3:] if arg.startswith("/")),
                         sorted([f"{PREFIX}manifest.json", f"{PREFIX}signature", f"{PREFIX}{VARIANT}.ipa"]))

        source = self.main_source()
        self.assertEqual(languages.check_source(source, pal=True), [])
        app = source["apps"][0]
        self.assertEqual(app["marketplaceID"], MARKETPLACE_ID)
        entry = app["versions"][0]
        base = f"https://github.com/{REPO}/releases/download/{VERSION}/"
        self.assertEqual(entry["assetURLs"], {"manifest": base + f"{PREFIX}manifest.json",
                                              "signature": base + f"{PREFIX}signature",
                                              VARIANT: base + f"{PREFIX}{VARIANT}.ipa"})
        self.assertEqual(entry["downloadURL"], entry["assetURLs"]["manifest"])
        self.assertEqual(entry["size"], (self.fetched / "adp" / VARIANT_PATH).stat().st_size)
        self.assertNotIn("sha256", entry)
        self.assertEqual((entry["version"], entry["buildVersion"], entry["minOSVersion"]), (VERSION, "159", "27.0"))
        self.assertEqual(entry["date"], "2026-11-20T08:00:00Z")
        self.assertEqual(set(entry["localizedDescriptions"]), set(languages.CODES))

    def test_the_entitlements_and_privacy_come_from_the_project_files(self):
        # Owner decision (20-08): the project's entitlements files, not what Apple's signing adds; the variants are
        # encrypted and are never read.
        self.assertEqual(self.publish().returncode, 0, self.output)
        permissions = self.main_source()["apps"][0]["appPermissions"]
        self.assertEqual(permissions["entitlements"],
                         ["com.apple.security.application-groups", "keychain-access-groups"])
        self.assertEqual(permissions["privacy"], {"NSCameraUsageDescription": "Scan codes.",
                                                  "NSPhotoLibraryAddUsageDescription": "Save images."})

    def test_a_project_without_an_entitlements_file_lists_none(self):
        result = self.publish(project=["--info-plist", str(self.app_info), "--info-plist", str(self.extension_info)])
        self.assertEqual(result.returncode, 0, self.output)
        self.assertEqual(self.main_source()["apps"][0]["appPermissions"]["entitlements"], [])

    def test_a_usage_description_that_differs_between_bundles_is_refused(self):
        write_plist(self.extension_info, {"NSCameraUsageDescription": "Scan other codes."})
        self.assert_refused_before_upload(self.publish(), "NSCameraUsageDescription", str(self.extension_info))

    def test_a_usage_description_from_a_build_setting_is_refused(self):
        write_plist(self.app_info, {"NSPhotoLibraryAddUsageDescription": "$(APP_NAME) saves images."})
        self.assert_refused_before_upload(self.publish(), "NSPhotoLibraryAddUsageDescription", "$(")

    def test_a_missing_project_file_is_refused(self):
        self.app_entitlements.unlink()
        self.assert_refused_before_upload(self.publish(), str(self.app_entitlements))

    def test_a_marketplace_id_other_than_the_manifests_is_refused(self):
        self.assert_refused_before_upload(self.publish(marketplace_id="1234567890"), "1234567890", MARKETPLACE_ID)

    def test_a_variant_the_manifest_does_not_list_is_refused(self):
        adp = build_adp(self.tmp / "extra-variant")
        (adp / "variant" / "0b1c2d3e-0000-4000-8000-000000000000.ipa").write_bytes(OPAQUE_VARIANT[::-1])
        fetched = self.tmp / "extra-fetched"
        self.assertEqual(self.run_tool("fetch", "--from", str(adp), "--out", str(fetched)).returncode, 0, self.output)
        self.assert_refused_before_upload(self.publish(adp=fetched), "0b1c2d3e-0000-4000-8000-000000000000")

    def test_the_repositorys_files_give_the_published_permissions(self):
        # The files publish-pal.yml passes (test_workflows holds them to the project) give AltStorePAL.json's list.
        import pal_publish
        entitlements, privacy = pal_publish.project_permissions(
            [ROOT / "App" / "EhPanda.entitlements"],
            [ROOT / "App" / "Info.plist", ROOT / "ShareExtension" / "Info.plist"])
        published = json.loads((ROOT / "AltStorePAL.json").read_text(encoding="utf-8"))["apps"][0]["appPermissions"]
        self.assertEqual({"entitlements": entitlements, "privacy": privacy}, published)

    def test_the_manifest_bytes_never_change(self):
        original = sha256(ADP_FIXTURE / "manifest.json")
        self.assertEqual(sha256(self.fetched / "adp" / "manifest.json"), original)
        self.assertEqual(self.publish().returncode, 0, self.output)
        self.assertEqual(sha256(self.tmp / "work" / "assets" / f"{PREFIX}manifest.json"), original)
        self.assertEqual(sha256(self.gh_state / "assets" / VERSION / f"{PREFIX}manifest.json"), original)
        self.assertEqual(sha256(self.tmp / "work" / "verify" / f"{PREFIX}manifest.json"), original)

    def test_older_versions_are_kept(self):
        self.assertEqual(self.publish().returncode, 0, self.output)
        older = self.main_source()
        older["apps"][0]["versions"][0].update({"version": "2.9.0", "buildVersion": "150", "marketingVersion": "2.9.0"})
        urls = older["apps"][0]["versions"][0]["assetURLs"]
        older["apps"][0]["versions"][0]["assetURLs"] = {key: url.replace(f"/{VERSION}/", "/2.9.0/")
                                                        for key, url in urls.items()}
        older["apps"][0]["versions"][0]["downloadURL"] = older["apps"][0]["versions"][0]["assetURLs"]["manifest"]
        self.git("-C", str(self.checkout), "pull", "-q", "--ff-only", "origin", "main")
        (self.checkout / "AltStorePAL.json").write_text(json.dumps(older, indent=2, ensure_ascii=False) + "\n")
        self.git("-C", str(self.checkout), "commit", "-q", "-am", "an older PAL release")
        self.git("-C", str(self.checkout), "push", "-q", "origin", "HEAD:refs/heads/main")

        self.assertEqual(self.publish().returncode, 0, self.output)
        versions = [(v["version"], v["buildVersion"]) for v in self.main_source()["apps"][0]["versions"]]
        self.assertEqual(versions, [(VERSION, "159"), ("2.9.0", "150")])

    def test_an_older_build_is_not_put_above_a_newer_one(self):
        # AltStore offers the first entry, so a stale ADP published late would read as a downgrade.
        newer = json.loads((TOOLS / "altstore-pal.template.json").read_text(encoding="utf-8"))
        base = f"https://github.com/{REPO}/releases/download/3.1.0/{PREFIX}"
        newer["apps"][0]["marketplaceID"] = MARKETPLACE_ID
        newer["apps"][0]["versions"] = [{
            "version": "3.1.0", "buildVersion": "170", "marketingVersion": "3.1.0", "date": "2026-12-01T08:00:00Z",
            "localizedDescription": "Newer.", "downloadURL": base + "manifest.json", "size": 1, "minOSVersion": "27.0",
            "assetURLs": {"manifest": base + "manifest.json", "signature": base + "signature"}}]
        self.git("-C", str(self.checkout), "pull", "-q", "--ff-only", "origin", "main")
        (self.checkout / "AltStorePAL.json").write_text(json.dumps(newer, indent=2, ensure_ascii=False) + "\n")
        self.git("-C", str(self.checkout), "add", "AltStorePAL.json")
        self.git("-C", str(self.checkout), "commit", "-q", "-m", "a newer PAL release")
        self.git("-C", str(self.checkout), "push", "-q", "origin", "HEAD:refs/heads/main")
        result = self.publish()
        self.assertEqual(result.returncode, 1)
        self.assertIn("3.1.0 (170)", self.output)
        self.assertFalse([call for call in self.gh_calls() if call[:2] == ["release", "upload"]])

    def test_a_missing_release_fails_without_uploading_or_creating_anything(self):
        (self.gh_state / "releases.json").write_text("{}")
        result = self.publish()
        self.assertEqual(result.returncode, 1)
        self.assertIn(f"no GitHub release for {VERSION}", self.output)
        calls = self.gh_calls()
        self.assertTrue(calls)
        for call in calls:
            with self.subTest(call=call):
                self.assertNotIn("upload", call)
                self.assertNotIn("create", call)
        self.assertNotIn("AltStorePAL.json", self.main_files())

    def test_a_changed_byte_after_upload_fails_the_run(self):
        self.env["FAKE_GH_CORRUPT"] = f"{PREFIX}manifest.json"
        result = self.publish()
        self.assertEqual(result.returncode, 1)
        self.assertIn(f"{PREFIX}manifest.json", self.output)
        self.assertIn("changed", self.output)
        self.assertNotIn("AltStorePAL.json", self.main_files())

    def test_a_changed_adp_file_before_upload_fails_the_run(self):
        with open(self.fetched / "adp" / "manifest.json", "ab") as handle:
            handle.write(b" ")
        result = self.publish()
        self.assertEqual(result.returncode, 1)
        self.assertIn("manifest.json", self.output)
        self.assertFalse([call for call in self.gh_calls() if call[:2] == ["release", "upload"]])

    def test_dry_run_uploads_and_commits_nothing(self):
        result = self.publish("--dry-run")
        self.assertEqual(result.returncode, 0, self.output)
        self.assertFalse([call for call in self.gh_calls() if call[:2] == ["release", "upload"]])
        self.assertNotIn("AltStorePAL.json", self.main_files())
        for name in (f"{PREFIX}manifest.json", f"{PREFIX}signature", f"{PREFIX}{VARIANT}.ipa"):
            self.assertIn(name, self.output)
        preview = json.loads((self.tmp / "work" / "AltStorePAL.json").read_text())
        self.assertEqual(languages.check_source(preview, pal=True), [])
        self.assertIn("dry run", self.output)

    def test_a_rerun_reuses_identical_assets(self):
        self.assertEqual(self.publish().returncode, 0, self.output)
        self.assertEqual(self.publish().returncode, 0, self.output)
        uploads = [call for call in self.gh_calls() if call[:2] == ["release", "upload"]]
        self.assertEqual(len(uploads), 1)
        self.assertIn("already up to date", self.output)

    def test_an_existing_asset_with_other_bytes_is_refused(self):
        self.assertEqual(self.publish().returncode, 0, self.output)
        stored = self.gh_state / "assets" / VERSION / f"{PREFIX}signature"
        stored.write_bytes(stored.read_bytes() + b"!")
        result = self.publish()
        self.assertEqual(result.returncode, 1)
        self.assertIn(f"{PREFIX}signature", self.output)

    def test_a_manifest_version_that_is_not_a_release_version_is_refused(self):
        adp = self.adp_with_manifest("bad-version", shortVersionString="3.0")
        self.assert_refused_before_upload(self.publish(adp=adp), "'3.0'", "not one like 3.0.0")

    def test_a_manifest_of_another_bundle_is_refused(self):
        adp = self.adp_with_manifest("other-bundle", bundleId="app.ehpanda")
        self.assert_refused_before_upload(self.publish(adp=adp), "bundle identifier mismatch", "app.ehpanda.store")

    def test_the_notes_are_the_manifest_versions_file(self):
        with self.subTest("missing"):
            shutil.copyfile(NOTES, self.notes_dir / "9.9.9.md")
            (self.notes_dir / f"{VERSION}.md").unlink()
            self.assert_refused_before_upload(self.publish(), str(self.notes_dir / f"{VERSION}.md"))
        with self.subTest("incomplete"):
            (self.notes_dir / f"{VERSION}.md").write_text("# 3.0.0\n\n## English\n\nNew.\n")
            self.assert_refused_before_upload(self.publish(), f"{VERSION}.md")

    def test_a_version_the_classic_source_does_not_list_is_refused(self):
        self.replace_on_main("AltStore.json", classic_source([{"version": "2.8.1", "buildVersion": "158"}]))
        self.assert_refused_before_upload(self.publish(), "AltStore.json", "does not list 3.0.0", "D-26")

    def test_a_build_other_than_the_classic_releases_is_refused(self):
        self.replace_on_main("AltStore.json", classic_source([{"version": VERSION, "buildVersion": "163"}]))
        for label, extra in (("live", []), ("dry run", ["--dry-run"])):
            with self.subTest(label):
                self.assert_refused_before_upload(self.publish(*extra), "3.0.0 (159)", "3.0.0 (163)", "D-26")

    def test_main_without_the_classic_source_is_refused(self):
        self.replace_on_main("AltStore.json", None)
        self.assert_refused_before_upload(self.publish(), "main has no AltStore.json", "D-26")

    def install_reject_hook(self, rejections):
        """A pre-receive hook that, for the first `rejections` pushes, lands another commit on main (as a
        concurrent run would) and refuses the push."""
        hook = self.bare / "hooks" / "pre-receive"
        counter = self.tmp / "pushes"
        hook.write_text(f"""#!/bin/sh
count=$(cat "{counter}" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "{counter}"
if [ "$count" -le {rejections} ]; then
  unset GIT_QUARANTINE_PATH GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
  blob=$(printf 'concurrent %s\\n' "$count" | git hash-object -w --stdin)
  base=$(git rev-parse refs/heads/main)
  tree=$( (git ls-tree "$base" | grep -v '\tCONCURRENT.txt$'; printf '100644 blob %s\\tCONCURRENT.txt\\n' "$blob") | git mktree)
  commit=$(echo "concurrent $count" | git commit-tree "$tree" -p "$base")
  git update-ref refs/heads/main "$commit" "$base"
  echo "rejected for the test" >&2
  exit 1
fi
exit 0
""")
        hook.chmod(0o755)
        return counter

    def test_a_rejected_push_is_retried_with_a_fresh_main(self):
        counter = self.install_reject_hook(2)
        result = self.publish()
        self.assertEqual(result.returncode, 0, self.output)
        self.assertEqual(counter.read_text().strip(), "3")
        files = self.main_files()
        self.assertIn("AltStorePAL.json", files)
        self.assertIn("CONCURRENT.txt", files)
        self.assertEqual(self.git("-C", str(self.checkout), "show", "FETCH_HEAD:CONCURRENT.txt"), "concurrent 2\n")

    def test_five_rejected_pushes_fail_the_run(self):
        counter = self.install_reject_hook(99)
        result = self.publish()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(counter.read_text().strip(), "5")
        self.assertNotIn("AltStorePAL.json", self.main_files())


class SourceTextTests(unittest.TestCase):
    def test_the_manifest_is_never_serialized(self):
        text = TOOL.read_text(encoding="utf-8")
        self.assertNotRegex(text, r"json\.dumps?\(.*manifest")
        self.assertNotIn("release create", text)
        self.assertNotIn("--clobber", text)

    def test_the_tool_only_reads_from_altstore(self):
        text = TOOL.read_text(encoding="utf-8")
        self.assertNotIn("POST", text)
        self.assertNotIn('add_parser("process")', text)


if __name__ == "__main__":
    unittest.main()
