"""actions-tool/ipa-entitlements.sh: the entitlement keys an app carries, for the sources' appPermissions."""

import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "ipa-entitlements.sh"


def make_bundle(path, executable="main"):
    path.mkdir(parents=True)
    (path / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": f"test.{path.stem}",
                                                      "CFBundleExecutable": executable}))
    shutil.copy("/bin/echo", path / executable)
    subprocess.run(["codesign", "--remove-signature", str(path / executable)], capture_output=True)


def sign(path, entitlements):
    file = path.parent / f"{path.stem}.entitlements"
    file.write_bytes(plistlib.dumps(entitlements))
    subprocess.run(["codesign", "-f", "-s", "-", "--entitlements", str(file), str(path)], check=True,
                   capture_output=True)


def read(app):
    return subprocess.run(["bash", str(SCRIPT), str(app)], capture_output=True, text=True)


@unittest.skipUnless(shutil.which("codesign") and shutil.which("jq") and shutil.which("plutil"), "needs macOS tools and jq")
class IpaEntitlementsTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.app = pathlib.Path(self.folder.name) / "Payload" / "EhPanda.app"
        make_bundle(self.app)
        make_bundle(self.app / "PlugIns" / "ShareExtension.appex")

    def test_an_unsigned_app_carries_none(self):
        result = read(self.app)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [])

    def test_the_keys_of_the_app_and_its_extensions_are_listed_without_the_identity_keys(self):
        sign(self.app / "PlugIns" / "ShareExtension.appex", {"com.apple.security.application-groups": ["g"]})
        sign(self.app, {"get-task-allow": True, "keychain-access-groups": ["x"], "application-identifier": "T.a",
                        "com.apple.developer.team-identifier": "T"})
        result = read(self.app)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout),
                         ["com.apple.security.application-groups", "get-task-allow", "keychain-access-groups"])

    def test_a_folder_that_is_not_an_app_fails(self):
        result = read(pathlib.Path(self.folder.name))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is not an app bundle", result.stderr)


if __name__ == "__main__":
    unittest.main()
