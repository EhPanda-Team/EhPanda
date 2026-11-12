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
        self.assertEqual(notes["en"], "Fixed reading page gestures not responding when scale is greater than 1.\n"
                                      "Improved the search page. (credit @someone)")
        self.assertTrue(notes["zh-Hant"].startswith("修正了閱讀頁面"))
        self.assertTrue(notes["zh-Hans"].startswith("修复了阅读页面"))

    def test_the_headings_are_the_six_language_names(self):
        self.assertEqual(list(release_notes.HEADINGS), HEADINGS)

    def test_a_missing_section_fails(self):
        for heading in HEADINGS:
            with self.subTest(heading=heading):
                with self.assertRaisesRegex(release_notes.NotesError, f"the {heading} section is missing"):
                    release_notes.parse(without_section(TEXT, heading))

    def test_an_empty_section_fails(self):
        text = TEXT.replace("## 한국어\n\n배율이 1보다 클 때 읽기 화면의 제스처가 반응하지 않는 문제를 수정했습니다.\n"
                            "검색 화면을 개선했습니다. (credit @someone)\n", "## 한국어\n   \n")
        with self.assertRaisesRegex(release_notes.NotesError, "the 한국어 section is empty"):
            release_notes.parse(text)

    def test_format_errors_fail(self):
        cases = {
            TEXT.replace("## English", "Notes for 9.9.9\n\n## English"): "text before the first heading",
            "Notes for 9.9.9\n\n" + TEXT: "must start with `# <release title>`",
            TEXT.replace("## 繁體中文", "## 台灣華語"): "is not a language heading",
            TEXT.replace("## 繁體中文", "## Traditional Chinese"): "is not a language heading",
            TEXT.replace("## 简体中文", "## 中文"): "is not a language heading",
            TEXT.replace("## English", "# English"): "only `## <language>` headings",
            TEXT.replace("## Deutsch\n", "## Deutsch\n### Fixes\n"): "only `## <language>` headings",
            TEXT + "\n## English\n\nAgain.\n": "the English section appears twice",
            TEXT.replace("\n", "\r\n"): "Windows line endings",
        }
        for text, message in cases.items():
            with self.subTest(message=message):
                with self.assertRaisesRegex(release_notes.NotesError, message):
                    release_notes.parse(text)

    def test_sections_out_of_order_fail(self):
        title, body = TEXT.split("## English", 1)
        english, rest = body.split("## Deutsch", 1)
        with self.assertRaisesRegex(release_notes.NotesError, "not in order"):
            release_notes.parse(title + "## Deutsch" + rest + "\n## English" + english)

    def test_the_title_is_the_first_line(self):
        # Owner msg 4620: the GitHub release takes everything from the notes file, its title too.
        self.assertEqual(release_notes.title(TEXT), "Bugfixes & search improvements")

    def test_the_title_is_not_part_of_any_language(self):
        for code, notes in release_notes.parse(TEXT).items():
            with self.subTest(code=code):
                self.assertNotIn("Bugfixes & search", notes)

    def test_a_missing_or_empty_title_fails(self):
        body = TEXT.split("\n", 2)[2]
        self.assertTrue(body.startswith("## English"))
        cases = {
            body: "must start with `# <release title>`",
            "\n" + TEXT: "must start with `# <release title>`",
            "#\n\n" + body: "the title is empty",
            "#   \n\n" + body: "the title is empty",
            "# Two\n# Titles\n\n" + body: "only `## <language>` headings",
            TEXT.replace("## Deutsch\n", "# Deutsch\n"): "only `## <language>` headings",
        }
        for text, message in cases.items():
            with self.subTest(message=message):
                with self.assertRaisesRegex(release_notes.NotesError, message):
                    release_notes.parse(text)
                with self.assertRaisesRegex(release_notes.NotesError, message):
                    release_notes.title(text)

    def test_a_title_too_long_for_one_line_fails(self):
        body = TEXT.split("\n", 2)[2]
        with self.assertRaisesRegex(release_notes.NotesError, "the title is longer than 100 characters"):
            release_notes.parse("# " + "x" * 101 + "\n\n" + body)
        release_notes.parse("# " + "x" * 100 + "\n\n" + body)

    def test_a_numbered_or_bulleted_item_fails(self):
        # AltStore shows the lines as they are, so items carry no number or bullet (owner msg 2591).
        for line in ["1. Fixed it.", "10. Fixed it.", "1) Fixed it.", "- Fixed it.", "* Fixed it.", "• Fixed it."]:
            with self.subTest(line=line):
                with self.assertRaisesRegex(release_notes.NotesError, "without a number or bullet"):
                    release_notes.parse(TEXT.replace("Improved the search page. (credit @someone)", line))

    def test_an_issue_number_at_the_start_of_a_line_is_text(self):
        text = TEXT.replace("Improved the search page. (credit @someone)", "Improved the search page.\n#241")
        self.assertTrue(release_notes.parse(text)["en"].endswith("\n#241"))

    def test_notes_too_long_for_telegram_or_discord_fail(self):
        long_line = "x" * 1900
        with self.assertRaisesRegex(release_notes.NotesError, "too long for Discord"):
            release_notes.parse(TEXT.replace("Fixed reading page gestures not responding when scale is greater than 1.",
                                             long_line))
        long_line = "修" * 3900
        with self.assertRaisesRegex(release_notes.NotesError, "too long for Telegram"):
            release_notes.parse(TEXT.replace("修正了閱讀頁面中縮放比例大於 1 時出現的手勢失效問題。", long_line))


def listed(notes, code, marker):
    """The lead sentence, then every other line as an item, as a section is rendered."""
    lead, *items = notes[code].split("\n")
    return lead + "".join(f"\n\n{marker} {items[0]}" if i == 0 else f"\n{marker} {item}" for i, item in enumerate(items))


class DestinationTests(unittest.TestCase):
    notes = release_notes.parse(TEXT)
    SITE = "https://ehpanda.app"

    def test_the_fixture_section_is_a_lead_and_one_item(self):
        # The expected layout in the tests below, written out once by hand.
        self.assertEqual(listed(self.notes, "en", "-"),
                         "Fixed reading page gestures not responding when scale is greater than 1.\n\n"
                         "- Improved the search page. (credit @someone)")

    def test_github_has_english_open_then_each_language_collapsed(self):
        body = release_notes.github(self.notes)
        self.assertTrue(body.startswith(listed(self.notes, "en", "-") + "\n\n<details>\n<summary>Deutsch</summary>\n\n"))
        summaries = [line for line in body.split("\n") if line.startswith("<summary>")]
        self.assertEqual(summaries, [f"<summary>{name}</summary>" for name in HEADINGS[1:]])
        self.assertEqual(body.count("<details>"), 5)
        self.assertEqual(body.count("</details>"), 5)
        for code in ["de", "ja", "ko", "zh-Hans", "zh-Hant"]:
            self.assertIn(f"\n\n{listed(self.notes, code, '-')}\n\n</details>", body)

    def test_github_body_in_full(self):
        expected = [listed(self.notes, "en", "-")]
        for code, name in [("de", "Deutsch"), ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文")]:
            expected.append(f"<details>\n<summary>{name}</summary>\n\n{listed(self.notes, code, '-')}\n\n</details>")
        self.assertEqual(release_notes.github(self.notes), "\n\n".join(expected) + "\n")

    def test_telegram_is_english_then_traditional_chinese_then_the_link_with_no_language_named(self):
        message = release_notes.telegram(self.notes, URL)
        self.assertEqual(message, f"{listed(self.notes, 'en', '•')}\n\n{listed(self.notes, 'zh-Hant', '•')}\n\n{URL}\n")
        for heading in HEADINGS:
            self.assertNotIn(heading, message)

    def test_the_destinations_bullet_the_items_and_the_raw_notes_stay_plain(self):
        # Owner msg 2591: AltStore and SideStore show the lines as written, so the parsed notes carry no
        # number or bullet; GitHub, Telegram and Discord bullet every line after the lead.
        for text in self.notes.values():
            for line in text.split("\n"):
                self.assertIsNone(release_notes.LIST_MARKER.match(line), line)
        for marker, output in [("-", release_notes.github(self.notes)), ("•", release_notes.telegram(self.notes, URL)),
                               ("-", release_notes.discord(self.notes, URL))]:
            with self.subTest(marker=marker):
                bulleted = [line for line in output.split("\n") if release_notes.LIST_MARKER.match(line)]
                self.assertTrue(bulleted)
                self.assertTrue(all(line.startswith(f"{marker} ") for line in bulleted), bulleted)
        self.assertNotIn("•", release_notes.github(self.notes))
        self.assertNotIn("•", release_notes.discord(self.notes, URL))
        self.assertNotIn("\n- ", release_notes.telegram(self.notes, URL))

    def test_discord_is_english_then_the_link(self):
        self.assertEqual(release_notes.discord(self.notes, URL), f"{listed(self.notes, 'en', '-')}\n\n{URL}\n")

    def test_every_line_after_the_first_is_an_item_in_order_with_no_blank_lines_between(self):
        notes = {code: "Lead.\nOne.\nTwo.\nThree." for code in self.notes}
        expected = "Lead.\n\n{m} One.\n{m} Two.\n{m} Three."
        self.assertEqual(release_notes.discord(notes, URL), expected.format(m="-") + f"\n\n{URL}\n")
        self.assertEqual(release_notes.telegram(notes, URL),
                         expected.format(m="•") + "\n\n" + expected.format(m="•") + f"\n\n{URL}\n")
        self.assertTrue(release_notes.github(notes).startswith(expected.format(m="-") + "\n\n<details>"))

    def test_items_separated_by_blank_lines_are_the_same_list(self):
        # The 3.0.0.md style: one item per paragraph.
        spaced = {code: "Lead.\n\nOne.\n\nTwo.\n\nThree." for code in self.notes}
        packed = {code: "Lead.\nOne.\nTwo.\nThree." for code in self.notes}
        self.assertEqual(release_notes.github(spaced), release_notes.github(packed))
        self.assertEqual(release_notes.telegram(spaced, URL), release_notes.telegram(packed, URL))
        self.assertEqual(release_notes.discord(spaced, URL), release_notes.discord(packed, URL))
        self.assertEqual(release_notes.discord(spaced, URL), f"Lead.\n\n- One.\n- Two.\n- Three.\n\n{URL}\n")

    def test_a_section_with_only_a_lead_is_just_the_lead(self):
        notes = {code: "Only the lead." for code in self.notes}
        self.assertEqual(release_notes.discord(notes, URL), f"Only the lead.\n\n{URL}\n")
        self.assertEqual(release_notes.telegram(notes, URL), f"Only the lead.\n\nOnly the lead.\n\n{URL}\n")
        self.assertIn("<summary>Deutsch</summary>\n\nOnly the lead.\n\n</details>", release_notes.github(notes))
        self.assertTrue(release_notes.github(notes).startswith("Only the lead.\n\n<details>"))

    def test_a_trailing_link_stays_its_own_paragraph_after_the_list(self):
        notes = {code: f"Lead.\n\nOne.\n\nTwo.\n\n{self.SITE}" for code in self.notes}
        self.assertEqual(release_notes.discord(notes, URL), f"Lead.\n\n- One.\n- Two.\n\n{self.SITE}\n\n{URL}\n")
        # Only the English section ends with the link on GitHub; the collapsed sections end with their last bullet.
        self.assertIn("<summary>日本語</summary>\n\nLead.\n\n- One.\n- Two.\n\n</details>", release_notes.github(notes))
        self.assertEqual(release_notes.github(notes).count(self.SITE), 1)
        self.assertTrue(release_notes.github(notes).startswith(f"Lead.\n\n- One.\n- Two.\n\n{self.SITE}\n\n<details>"))
        self.assertNotIn(f"- {self.SITE}", release_notes.github(notes))

    def test_the_collapsed_sections_never_show_the_link(self):
        notes = {code: f"{text}\n\n{self.SITE}" for code, text in self.notes.items()}
        body = release_notes.github(notes)
        for code, name in [("de", "Deutsch"), ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文")]:
            self.assertIn(f"<summary>{name}</summary>\n\n{listed(self.notes, code, '-')}\n\n</details>", body)
        self.assertEqual(body.count(self.SITE), 1)
        self.assertTrue(body.startswith(f"{listed(self.notes, 'en', '-')}\n\n{self.SITE}\n\n<details>"))

    def test_a_link_only_in_english_is_posted_once_at_the_end_of_the_english_block(self):
        # 3.0.0.md as it will be: https://ehpanda.app ends the English section only.
        notes = dict(self.notes, en=f"{self.notes['en']}\n\n{self.SITE}")
        self.assertEqual(release_notes.telegram(notes, URL),
                         f"{listed(self.notes, 'en', '•')}\n\n{self.SITE}\n\n{listed(self.notes, 'zh-Hant', '•')}\n\n{URL}\n")
        self.assertEqual(release_notes.telegram(notes, URL).count(self.SITE), 1)
        self.assertEqual(release_notes.discord(notes, URL), f"{listed(self.notes, 'en', '-')}\n\n{self.SITE}\n\n{URL}\n")

    def test_the_committed_3_0_0_notes_end_only_english_with_the_link(self):
        path = TOOLS.parent / "ReleaseNotes" / "3.0.0.md"
        notes = release_notes.read(path)
        self.assertTrue(notes["en"].endswith(f"\n\n{self.SITE}"))
        for code in ["de", "ja", "ko", "zh-Hans", "zh-Hant"]:
            self.assertNotIn(self.SITE, notes[code])
        self.assertEqual(release_notes.read(path, lambda text: release_notes.telegram(release_notes.parse(text), URL)).count(self.SITE), 1)

    def test_a_lead_with_only_a_link_after_it_has_no_list(self):
        notes = {code: f"Lead.\n\n{self.SITE}" for code in self.notes}
        self.assertEqual(release_notes.discord(notes, URL), f"Lead.\n\n{self.SITE}\n\n{URL}\n")

    def test_a_link_the_notes_already_end_with_is_posted_once(self):
        # Owner msg 4453: the 3.0.0 notes themselves end with the website link, which the posts also end with.
        notes = {code: f"{text}\n\n{self.SITE}" for code, text in self.notes.items()}
        self.assertEqual(release_notes.telegram(notes, self.SITE),
                         f"{listed(self.notes, 'en', '•')}\n\n{listed(self.notes, 'zh-Hant', '•')}\n\n{self.SITE}\n")
        self.assertEqual(release_notes.discord(notes, self.SITE), f"{listed(self.notes, 'en', '-')}\n\n{self.SITE}\n")

    def test_a_link_both_telegram_languages_end_with_is_posted_once_before_the_release_url(self):
        # Owner msg 4453 and 4459: the 3.0.0 notes end with https://ehpanda.app; the post ends with the release URL.
        notes = {code: f"{text}\n\n{self.SITE}" for code, text in self.notes.items()}
        self.assertEqual(release_notes.telegram(notes, URL),
                         f"{listed(self.notes, 'en', '•')}\n\n{listed(self.notes, 'zh-Hant', '•')}\n\n{self.SITE}\n\n{URL}\n")
        self.assertEqual(release_notes.discord(notes, URL),
                         f"{listed(self.notes, 'en', '-')}\n\n{self.SITE}\n\n{URL}\n")

    def test_length_checks_measure_the_rendered_text(self):
        # Every item gains "- " (Discord) or "• " (Telegram) and the lead a blank line after it, so notes
        # that fit as plain lines can be too long once rendered. Each case fits as written and not rendered.
        english_old = ("Fixed reading page gestures not responding when scale is greater than 1.\n"
                       "Improved the search page. (credit @someone)")
        chinese_old = "修正了閱讀頁面中縮放比例大於 1 時出現的手勢失效問題。\n改善了搜尋頁面。 (credit @someone)"

        english = "\n".join(["z" * 17] * 100)  # 1,799 characters as written, 1,998 rendered
        self.assertLessEqual(len(english) + release_notes.LINK_ALLOWANCE, release_notes.DISCORD_LIMIT)
        with self.assertRaisesRegex(release_notes.NotesError, "too long for Discord"):
            release_notes.parse(TEXT.replace(english_old, english))

        english = "\n".join(["y" * 18] * 100)  # 1,899 as written
        chinese = "\n".join(["修" * 18] * 100)
        self.assertLessEqual(len(english) + len(chinese) + 2 + release_notes.LINK_ALLOWANCE, release_notes.TELEGRAM_LIMIT)
        with self.assertRaisesRegex(release_notes.NotesError, "too long for Telegram"):
            release_notes.parse(TEXT.replace(english_old, english).replace(chinese_old, chinese))


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

    def test_title_prints_the_title(self):
        result = self.run_tool("title", str(FIXTURE))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "Bugfixes & search improvements\n")

    def test_a_wrong_command_fails(self):
        self.assertEqual(self.run_tool("telegram", str(FIXTURE)).returncode, 2)


if __name__ == "__main__":
    unittest.main()
