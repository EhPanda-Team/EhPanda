"""Tests for dependency_changes.py, which writes the dependency update's pull request body from the two
`Package.resolved` files (dependencies.yml)."""

import contextlib
import io
import json
import pathlib
import sys
import tempfile
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))

import dependency_changes  # noqa: E402

XCODE = "Xcode 27.1\nBuild version 17B55\n"
LOCKFILES = [ROOT / "AppPackage" / "Package.resolved",
             ROOT / "EhPanda.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"]


def pin(identity, version=None, revision="0123456789abcdef", branch=None, location=None):
    state = {"revision": revision}
    if version:
        state["version"] = version
    if branch:
        state["branch"] = branch
    return {"identity": identity, "kind": "remoteSourceControl",
            "location": location or f"https://github.com/example/{identity}", "state": state}


def lockfile(*entries, version=3):
    return json.dumps({"originHash": "0" * 64, "pins": list(entries), "version": version})


def pins(*entries):
    return dependency_changes.pins(lockfile(*entries), "Package.resolved")


class PinsTests(unittest.TestCase):
    def test_a_pin_is_read_by_its_identity(self):
        found = pins(pin("kingfisher", "8.13.0", "8648fe6", location="https://github.com/onevcat/Kingfisher"))
        self.assertEqual(found, {"kingfisher": {"location": "https://github.com/onevcat/Kingfisher",
                                                "revision": "8648fe6", "name": "8.13.0"}})

    def test_both_current_formats_are_read(self):
        for version in (2, 3):
            text = lockfile(pin("kingfisher", "8.13.0"), version=version)
            self.assertEqual(list(dependency_changes.pins(text, "Package.resolved")), ["kingfisher"])

    def test_the_repositorys_own_lockfiles_are_read(self):
        # The weekly job reads these: a format it cannot read is learnt here, on a push, and not on a Monday.
        for path in LOCKFILES:
            with self.subTest(lockfile=path.name):
                self.assertGreater(len(dependency_changes.pins(path.read_text(encoding="utf-8"), path)), 10)

    def test_what_is_no_lockfile_of_a_format_it_reads_is_refused(self):
        for text in ("not JSON", "[]", lockfile(version=1), lockfile(version=4), json.dumps({"version": 3}),
                     json.dumps({"version": 3, "pins": {}})):
            with self.subTest(text=text[:30]), self.assertRaises(dependency_changes.ChangesError):
                dependency_changes.pins(text, "Package.resolved")

    def test_a_pin_without_its_parts_is_refused(self):
        whole = pin("kingfisher", "8.13.0")
        for missing in ("identity", "location", "state"):
            broken = {key: value for key, value in whole.items() if key != missing}
            with self.subTest(missing=missing), self.assertRaises(dependency_changes.ChangesError):
                pins(broken)
        with self.assertRaises(dependency_changes.ChangesError):
            pins("kingfisher")


class BodyTests(unittest.TestCase):
    def test_changed_added_and_removed_are_listed_in_that_order_by_identity(self):
        before = pins(pin("swift-collections", "1.7.3", location="https://github.com/apple/swift-collections"),
                      pin("kingfisher", "8.13.0", location="https://github.com/onevcat/Kingfisher"),
                      pin("swift-numerics", "1.1.1"), pin("kanna", "6.1.0"))
        after = pins(pin("swift-collections", "1.7.6", "88754449",
                         location="https://github.com/apple/swift-collections"),
                     pin("kingfisher", "8.16.0", "21caad71", location="https://github.com/onevcat/Kingfisher"),
                     pin("swift-atomics", "1.3.0"), pin("kanna", "6.1.0"))
        self.assertEqual(dependency_changes.body(before, after, XCODE), "\n".join([
            "Resolved with Xcode 27.1 (17B55).",
            "",
            "2 dependencies have changed:",
            "~ kingfisher 8.13.0 -> kingfisher 8.16.0",
            "~ swift-collections 1.7.3 -> swift-collections 1.7.6",
            "",
            "1 dependency was added:",
            "+ swift-atomics 1.3.0",
            "",
            "1 dependency was removed:",
            "- swift-numerics 1.1.1",
            "",
            "Release notes URLs (updating from):",
            "https://github.com/onevcat/Kingfisher/releases (8.13.0)",
            "https://github.com/apple/swift-collections/releases (1.7.3)",
            "",
        ]))

    def test_one_and_several_are_counted_in_words_that_fit(self):
        one = dependency_changes.body(pins(pin("a", "1.0.0")), pins(pin("a", "1.0.1", "f" * 16)))
        self.assertIn("1 dependency has changed:", one)
        several = dependency_changes.body(pins(pin("a", "1.0.0"), pin("b", "1.0.0")), pins())
        self.assertIn("2 dependencies were removed:", several)
        several = dependency_changes.body(pins(), pins(pin("a", "1.0.0"), pin("b", "1.0.0")))
        self.assertIn("2 dependencies were added:", several)

    def test_a_part_with_nothing_to_say_is_left_out(self):
        text = dependency_changes.body(pins(pin("a", "1.0.0")), pins(pin("a", "1.0.0"), pin("b", "2.0.0")))
        self.assertEqual(text, "1 dependency was added:\n+ b 2.0.0\n")

    def test_lockfiles_with_the_same_pins_say_so(self):
        same = pins(pin("a", "1.0.0"))
        self.assertEqual(dependency_changes.body(same, same, XCODE),
                         "Resolved with Xcode 27.1 (17B55).\n\nNo dependency's pin has changed.\n")

    def test_a_pin_whose_name_stayed_shows_its_revisions(self):
        # A branch that moved on, and a tag that was moved: the pin changed although its name did not.
        before = pins(pin("a", branch="main", revision="1111111aaaa"), pin("b", "1.0.0", "3333333cccc"))
        after = pins(pin("a", branch="main", revision="2222222bbbb"), pin("b", "1.0.0", "4444444dddd"))
        text = dependency_changes.body(before, after)
        self.assertIn("~ a main (1111111) -> a main (2222222)", text)
        self.assertIn("~ b 1.0.0 (3333333) -> b 1.0.0 (4444444)", text)
        self.assertIn("https://github.com/example/a/releases (main (1111111))", text)

    def test_a_pin_without_a_version_or_a_branch_is_named_by_its_revision(self):
        text = dependency_changes.body(pins(pin("a", revision="1111111aaaa")), pins(pin("a", "1.0.0", "2222222bbbb")))
        self.assertIn("~ a 1111111 -> a 1.0.0", text)

    def test_a_releases_page_is_listed_for_github_alone(self):
        locations = {"plain": "https://github.com/example/plain",
                     "suffixed": "https://github.com/example/suffixed.git",
                     "slashed": "https://github.com/example/slashed/",
                     "elsewhere": "https://gitlab.com/example/elsewhere.git",
                     "ssh": "git@github.com:example/ssh.git"}
        before = pins(*[pin(identity, "1.0.0", location=location) for identity, location in locations.items()])
        after = pins(*[pin(identity, "1.1.0", "f" * 16, location=location)
                       for identity, location in locations.items()])
        text = dependency_changes.body(before, after)
        self.assertEqual(text.split("Release notes URLs (updating from):\n")[1].splitlines(), [
            "https://github.com/example/plain/releases (1.0.0)",
            "https://github.com/example/slashed/releases (1.0.0)",
            "https://github.com/example/suffixed/releases (1.0.0)",
        ])
        self.assertIn("5 dependencies have changed:", text)

    def test_an_xcode_text_it_cannot_read_is_refused(self):
        for text in ("", "Xcode 27.1", "xcode-select: error: tool 'xcodebuild' requires Xcode"):
            with self.subTest(text=text), self.assertRaises(dependency_changes.ChangesError):
                dependency_changes.body({}, {}, text)


class CommandTests(unittest.TestCase):
    def run_command(self, *texts, arguments=()):
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for index, text in enumerate(texts):
                paths.append(pathlib.Path(directory) / f"{index}.resolved")
                paths[-1].write_text(text, encoding="utf-8")
            output, errors = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                status = dependency_changes.main([*arguments, *map(str, paths)])
        return status, output.getvalue(), errors.getvalue()

    def test_the_body_goes_to_stdout(self):
        status, output, errors = self.run_command(lockfile(pin("a", "1.0.0")), lockfile(pin("a", "1.0.1", "f" * 16)),
                                                  arguments=["--xcode", XCODE])
        self.assertEqual((status, errors), (0, ""))
        self.assertEqual(output, "Resolved with Xcode 27.1 (17B55).\n\n1 dependency has changed:\n"
                                 "~ a 1.0.0 -> a 1.0.1\n\nRelease notes URLs (updating from):\n"
                                 "https://github.com/example/a/releases (1.0.0)\n")

    def test_a_file_it_cannot_read_fails_without_a_body(self):
        status, output, errors = self.run_command(lockfile(pin("a", "1.0.0")), "not JSON")
        self.assertEqual((status, output), (1, ""))
        self.assertIn("::error::", errors)
        self.assertIn("1.resolved is not JSON", errors)

    def test_a_missing_file_fails_without_a_body(self):
        with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()) as errors:
            status = dependency_changes.main(["/nonexistent/before", "/nonexistent/after"])
        self.assertEqual((status, output.getvalue()), (1, ""))
        self.assertIn("::error::", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
