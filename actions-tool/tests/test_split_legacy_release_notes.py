"""Tests for split_legacy_release_notes.py against every version AltStore.json listed before the split.

`fixtures/legacy-release-notes.json` holds each version's notes as they were (owner msg 2561)."""

import json
import pathlib
import sys
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

import split_legacy_release_notes as split_notes  # noqa: E402

LEGACY = json.loads((TOOLS / "tests" / "fixtures" / "legacy-release-notes.json").read_text(encoding="utf-8"))
ALTSTORE_JSON = TOOLS.parent / "AltStore.json"


def label(version):
    return f"{version['version']} ({version['buildVersion']})"


class LanguageOfTests(unittest.TestCase):
    def test_lines(self):
        cases = {
            "Fixed a parsing issue.": "en",
            "ex ギャラリーホストでのサムネイルが表示されない不具合を修正。": "ja",
            "一つの解析問題を修正。": "ja",
            "修正了畫廊頁面的 header 佈局錯誤。": "zh-Hant",
            "修復了App啓動後HUD太快出現時發生的transition動畫異常問題。": "zh-Hant",
            "修复了一个画廊解析问题。": "zh-Hans",
            "画廊页面显示问题": "zh-Hans",
            "갤러리 파싱 문제를 수정했습니다.": "ko",
        }
        for line, language in cases.items():
            with self.subTest(line=line):
                self.assertEqual(split_notes.language_of(line), language)


class LegacyNotesTests(unittest.TestCase):
    def test_every_version_splits_cleanly_and_round_trips(self):
        mixed = 0
        for version in LEGACY:
            with self.subTest(version=label(version)):
                notes = version["localizedDescription"]
                texts = split_notes.split(notes)
                if texts is None:
                    # English only: every line is a numbered English item.
                    self.assertTrue(all(split_notes.language_of(line) == "en" for line in split_notes.source_lines(notes)))
                    continue
                mixed += 1
                self.assertEqual(texts["en"].split("\n")[0][:3], "1. ")
                # Every text lists every item, in order, under its own number.
                count = len(split_notes.parse(notes))
                for language, text in texts.items():
                    numbers = [line.split(". ", 1)[0] for line in text.split("\n")]
                    self.assertEqual(numbers, [str(index) for index in range(1, count + 1)], language)
                # No line lost, changed or duplicated.
                self.assertEqual(split_notes.unsplit(texts), split_notes.source_lines(notes))
                # Each translated line is in its own language's text, and only there.
                for _, _, translations in split_notes.parse(notes):
                    for language, line in translations.items():
                        holders = [code for code, text in texts.items() if line in text]
                        self.assertEqual(holders, [language], line)
        self.assertEqual(mixed, 40)

    def test_only_languages_actually_present_are_listed(self):
        for version in LEGACY:
            texts = split_notes.split(version["localizedDescription"])
            if texts is not None:
                self.assertEqual(list(texts), ["en", "ja", "zh-Hant"], label(version))

    def test_a_credit_follows_its_item_into_each_language(self):
        version = next(item for item in LEGACY if item["version"] == "2.7.9")
        texts = split_notes.split(version["localizedDescription"])
        self.assertEqual(texts["ja"].split("\n")[1], "2. 台湾華語と中国語繁体字（香港）の翻訳を改善しました。 (credit @NeKoOuO)")
        self.assertEqual(texts["zh-Hant"].split("\n")[1], "2. 改善了台灣華語和繁體中文（香港）翻譯。 (credit @NeKoOuO)")

    def test_an_untranslated_item_keeps_its_english_line(self):
        version = next(item for item in LEGACY if item["version"] == "2.7.0")
        texts = split_notes.split(version["localizedDescription"])
        self.assertEqual(texts["ja"].split("\n")[3:], ["4. refactor: TCA reducers.", "5. refactor: CI"])

    def test_notes_off_the_layout_are_refused(self):
        for notes in [
            "閲覧ページの不具合を修正。\n1. Fixed the reading page.",
            "1. Fixed the reading page.\n閲覧ページの不具合を修正。\n閲覧ページを修正。",
            "1. 閲覧ページの不具合を修正。",
            "1. Fixed the reading page.\nAnd something else.",
        ]:
            with self.subTest(notes=notes):
                with self.assertRaises(split_notes.SplitError):
                    split_notes.split(notes)


@unittest.skipUnless(ALTSTORE_JSON.exists(), "no AltStore.json")
class AltStoreJsonTests(unittest.TestCase):
    def test_altstore_json_holds_the_split_notes(self):
        versions = json.loads(ALTSTORE_JSON.read_text(encoding="utf-8"))["apps"][0]["versions"]
        listed = {label(version): version for version in versions}
        for legacy in LEGACY:
            with self.subTest(version=label(legacy)):
                version = listed[label(legacy)]
                texts = split_notes.split(legacy["localizedDescription"])
                if texts is None:
                    self.assertEqual(version["localizedDescription"], legacy["localizedDescription"])
                    self.assertNotIn("localizedDescriptions", version)
                else:
                    self.assertEqual(version["localizedDescription"], texts["en"])
                    self.assertEqual(version["localizedDescriptions"], texts)


if __name__ == "__main__":
    unittest.main()
