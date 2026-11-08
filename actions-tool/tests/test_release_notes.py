"""Tests for release_notes.py, which turns ReleaseNotes/<version>.md into each release destination's
notes (owner msgs 2564, 2567, 2569, 2579, 2582)."""

import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import release_notes  # noqa: E402

FIXTURE = TOOLS / "tests" / "fixtures" / "release-notes" / "9.9.9.md"
TEXT = FIXTURE.read_text(encoding="utf-8")
URL = "https://github.com/EhPanda-Team/EhPanda/releases/tag/9.9.9"
HEADINGS = ["English", "Deutsch", "日本語", "한국어", "简体中文", "繁體中文"]


def without_section(text, heading):
    parts = text.split("## ")
    return "## ".join(part for part in parts if not part.startswith(heading + "\n"))


class ParseTests(unittest.TestCase):
    def test_the_fixture_has_every_language(self):
        notes = release_notes.parse(TEXT)
        self.assertEqual(list(notes), ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"])
        self.assertEqual(notes["en"], "1. Fixed reading page gestures not responding when scale is greater than 1.\n"
                                      "2. Improved the search page. (credit @someone)")
        self.assertTrue(notes["zh-Hant"].startswith("1. 修正了閱讀頁面"))
        self.assertTrue(notes["zh-Hans"].startswith("1. 修复了阅读页面"))

    def test_the_headings_are_the_six_language_names(self):
        self.assertEqual(list(release_notes.HEADINGS), HEADINGS)

    def test_a_missing_section_fails(self):
        for heading in HEADINGS:
            with self.subTest(heading=heading):
                with self.assertRaisesRegex(release_notes.NotesError, f"the {heading} section is missing"):
                    release_notes.parse(without_section(TEXT, heading))

    def test_an_empty_section_fails(self):
        text = TEXT.replace("## 한국어\n\n1. 배율이 1보다 클 때 읽기 화면의 제스처가 반응하지 않는 문제를 수정했습니다.\n"
                            "2. 검색 화면을 개선했습니다. (credit @someone)\n", "## 한국어\n   \n")
        with self.assertRaisesRegex(release_notes.NotesError, "the 한국어 section is empty"):
            release_notes.parse(text)

    def test_format_errors_fail(self):
        cases = {
            "Notes for 9.9.9\n\n" + TEXT: "text before the first heading",
            TEXT.replace("## 繁體中文", "## 台灣華語"): "is not a language heading",
            TEXT.replace("## 繁體中文", "## Traditional Chinese"): "is not a language heading",
            TEXT.replace("## 简体中文", "## 中文"): "is not a language heading",
            TEXT.replace("## English", "# English"): "only `## <language>` headings",
            TEXT.replace("## Deutsch\n", "## Deutsch\n### Fixes\n"): "only `## <language>` headings",
            TEXT + "\n## English\n\n1. Again.\n": "the English section appears twice",
            TEXT.replace("\n", "\r\n"): "Windows line endings",
        }
        for text, message in cases.items():
            with self.subTest(message=message):
                with self.assertRaisesRegex(release_notes.NotesError, message):
                    release_notes.parse(text)

    def test_sections_out_of_order_fail(self):
        english, rest = TEXT.split("## Deutsch", 1)
        with self.assertRaisesRegex(release_notes.NotesError, "not in order"):
            release_notes.parse("## Deutsch" + rest + "\n" + english)

    def test_an_issue_number_at_the_start_of_a_line_is_text(self):
        text = TEXT.replace("2. Improved the search page. (credit @someone)", "2. Improved the search page.\n#241")
        self.assertTrue(release_notes.parse(text)["en"].endswith("\n#241"))

    def test_notes_too_long_for_telegram_or_discord_fail(self):
        long_line = "1. " + "x" * 1900
        with self.assertRaisesRegex(release_notes.NotesError, "too long for Discord"):
            release_notes.parse(TEXT.replace("1. Fixed reading page gestures not responding when scale is greater than 1.",
                                             long_line))
        long_line = "1. " + "修" * 3900
        with self.assertRaisesRegex(release_notes.NotesError, "too long for Telegram"):
            release_notes.parse(TEXT.replace("1. 修正了閱讀頁面中縮放比例大於 1 時出現的手勢失效問題。", long_line))


class DestinationTests(unittest.TestCase):
    notes = release_notes.parse(TEXT)

    def test_github_has_english_open_then_each_language_collapsed(self):
        body = release_notes.github(self.notes)
        self.assertTrue(body.startswith(self.notes["en"] + "\n\n<details>\n<summary>Deutsch</summary>\n\n"))
        summaries = [line for line in body.split("\n") if line.startswith("<summary>")]
        self.assertEqual(summaries, [f"<summary>{name}</summary>" for name in HEADINGS[1:]])
        self.assertEqual(body.count("<details>"), 5)
        self.assertEqual(body.count("</details>"), 5)
        for code in ["de", "ja", "ko", "zh-Hans", "zh-Hant"]:
            self.assertIn(f"\n\n{self.notes[code]}\n\n</details>", body)

    def test_telegram_is_english_then_traditional_chinese_then_the_link_with_no_language_named(self):
        message = release_notes.telegram(self.notes, URL)
        self.assertEqual(message, f"{self.notes['en']}\n\n{self.notes['zh-Hant']}\n\n{URL}\n")
        for heading in HEADINGS:
            self.assertNotIn(heading, message)

    def test_discord_is_english_then_the_link(self):
        self.assertEqual(release_notes.discord(self.notes, URL), f"{self.notes['en']}\n\n{URL}\n")


class VersionTests(unittest.TestCase):
    def write(self, directory, name, text):
        path = pathlib.Path(directory) / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_app_version_in_the_workflow_wins(self):
        with tempfile.TemporaryDirectory() as directory:
            workflow = self.write(directory, "deploy.yml", "env:\n  APP_VERSION: '2.8.2'\n  SCHEME_NAME: 'EhPanda'\n")
            self.assertEqual(release_notes.release_version(workflow, pathlib.Path(directory) / "none"), "2.8.2")

    def test_otherwise_the_apps_marketing_version(self):
        project = (
            "\t\tA /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n"
            "\t\t\t\tINFOPLIST_FILE = App/Info.plist;\n\t\t\t\tMARKETING_VERSION = 3.0.0;\n\t\t\t};\n\t\t};\n"
            "\t\tB /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n"
            "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n\t\t\t\tMARKETING_VERSION = 1.0;\n\t\t\t};\n\t\t};\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            workflow = self.write(directory, "deploy.yml", "env:\n  SCHEME_NAME: 'EhPanda'\n")
            pbxproj = self.write(directory, "project.pbxproj", project)
            self.assertEqual(release_notes.release_version(workflow, pbxproj), "3.0.0")
            pbxproj = self.write(directory, "project.pbxproj", project + project.replace("3.0.0", "3.0.1"))
            with self.assertRaisesRegex(release_notes.NotesError, "MARKETING_VERSION values"):
                release_notes.release_version(workflow, pbxproj)

    def test_this_checkouts_version_is_a_version(self):
        self.assertRegex(release_notes.release_version(), r"^\d+\.\d+\.\d+$")


class CommandLineTests(unittest.TestCase):
    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(TOOLS / "release_notes.py"), *args],
                              capture_output=True, text=True, encoding="utf-8")

    def test_check_passes_for_the_fixture_and_fails_for_a_missing_file(self):
        self.assertEqual(self.run_tool("check", str(FIXTURE)).returncode, 0)
        result = self.run_tool("check", str(FIXTURE.with_name("0.0.0.md")))
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stderr)
        self.assertIn("does not exist", result.stderr)

    def test_altstore_prints_every_language(self):
        result = self.run_tool("altstore", str(FIXTURE))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), release_notes.parse(TEXT))

    def test_english_prints_the_english_notes(self):
        result = self.run_tool("english", str(FIXTURE))
        self.assertEqual(result.stdout, release_notes.parse(TEXT)["en"] + "\n")

    def test_a_wrong_command_fails(self):
        self.assertEqual(self.run_tool("telegram", str(FIXTURE)).returncode, 2)


if __name__ == "__main__":
    unittest.main()
