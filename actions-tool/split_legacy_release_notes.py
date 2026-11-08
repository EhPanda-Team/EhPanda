#!/usr/bin/env python3
"""Splits the mixed-language release notes of old AltStore.json versions into one text per language.

Usage: split_legacy_release_notes.py <AltStore.json>   (rewrites the file in place)
       split_legacy_release_notes.py --check <AltStore.json>   (only reports; exits 1 if any version
                                                                 cannot be split cleanly)

Before 3.0 the release notes were one text per version: each numbered item in English, followed by
its translations, one line per language (日本語, then 繁體中文), with a blank line
between items (owner msg 2561). AltStore 2.2+ picks a version's notes from `localizedDescriptions`
by language code and falls back to the plain `localizedDescription`; SideStore reads only the plain
field. So a version whose notes mix languages gets:

- `localizedDescription`: the English items only, one per line;
- `localizedDescriptions`: one text per language actually present, English included, so a device
  that prefers English over a language listed further down its preferences still gets English.

Every item is one line without its number (owner msg 2591): the numbers only ever counted from 1,
and the notes show without them. A translated line takes its item's credit (`(credit @user)` and the
like) when the line has none. An item with no line in some language keeps its English line in that
language's text, so every language lists every item. Nothing is translated: a language that a
version never had is left out and falls back to English.

A version whose notes are English only keeps them, without the numbers. A version already split by
an earlier run only loses its numbers. A version that does not follow the layout (a translation
before any item, two lines of one language for one item, an item line that is not English, an
unnumbered English line, numbers that do not count from 1) is reported and left unchanged, to be
fixed by hand.
"""

import json
import re
import sys

from altstore_languages import CODES

ITEM = re.compile(r"^(\d+)\.\s+(.*)$")
KANA = re.compile(r"[\u3040-\u30ff\u31f0-\u31ff\uff66-\uff9f]")
HANGUL = re.compile(r"[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]")
HAN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
# A credit at the end of an English item line: "(credit @user)", "credit @user", "@user" or "@user #123".
CREDIT = re.compile(r"\s*((?:\(credit @[^)]+\))|(?:credit @\S+)|(?:@[\w-]+(?:\s+#\d+)?))\s*$")

# Characters that exist only in simplified script, and their traditional counterparts. A Han line
# with more of the first kind than the second is simplified Chinese; every other Han line without
# kana is traditional Chinese.
SIMPLIFIED_ONLY = set("们这个发说时会为来对实现过关么问题设复页图应显载种开动后览档单击简记录无从带让试译钮选择观点设备签视频网络")
TRADITIONAL_ONLY = set("們這個發說時會為來對實現過關麼問題設復頁圖應顯載種開動後覽檔單擊簡記錄無從帶讓試譯鈕選擇觀點設備簽視頻網絡")

# Every language code EhPanda's notes can carry, in the order the texts are written.
LANGUAGES = CODES


def language_of(line):
    """The language code of one line of notes."""
    if KANA.search(line):
        return "ja"
    if HANGUL.search(line):
        return "ko"
    if HAN.search(line):
        simplified = sum(char in SIMPLIFIED_ONLY for char in line)
        traditional = sum(char in TRADITIONAL_ONLY for char in line)
        return "zh-Hans" if simplified > traditional else "zh-Hant"
    return "en"


class SplitError(ValueError):
    pass


def parse(text):
    """The items of one version's notes: a list of (number, english, {language: line}) tuples."""
    items = []
    for raw in text.split("\n"):
        line = raw.strip()
        if not line:
            continue
        match = ITEM.match(line)
        if match:
            if language_of(match.group(2)) != "en":
                raise SplitError(f"the item line {line!r} is not English")
            items.append((match.group(1), match.group(2), {}))
            continue
        language = language_of(line)
        if not items:
            raise SplitError(f"the line {line!r} comes before any numbered item")
        if language == "en":
            raise SplitError(f"the English line {line!r} has no number")
        translations = items[-1][2]
        if language in translations:
            raise SplitError(f"item {items[-1][0]} has two {language} lines")
        translations[language] = line
    numbers = [number for number, _, _ in items]
    if numbers != [str(index) for index in range(1, len(items) + 1)]:
        raise SplitError(f"the items are numbered {numbers}, not counting from 1")
    return items


def strip_numbers(text):
    """`text` with the leading item number ("1. ", "10. ") removed from every line."""
    return "\n".join(ITEM.sub(r"\2", line) for line in text.split("\n"))


def credit_of(english):
    match = CREDIT.search(english)
    return match.group(1) if match else None


def split(text):
    """{language: notes} for one version's notes, or None when they are English only."""
    items = parse(text)
    present = {language for _, _, translations in items for language in translations}
    if not present:
        return None
    texts = {}
    for language in [code for code in LANGUAGES if code == "en" or code in present]:
        lines = []
        for _, english, translations in items:
            line = translations.get(language)
            if line is None:
                line = english
            else:
                credit = credit_of(english)
                if credit and "@" not in line:
                    line = f"{line} {credit}"
            lines.append(line)
        texts[language] = "\n".join(lines)
    return texts


def source_lines(text):
    """The non-blank lines of one version's original notes, stripped, without the item numbers."""
    return [strip_numbers(line.strip()) for line in text.split("\n") if line.strip()]


def unsplit(texts):
    """The non-blank lines of the notes that `split` turned into `texts`, in their original order.

    Each item's English line, then each of its translations: a language's line where it differs from
    the English one, without a credit that `split` added. Comparing this with `source_lines` of the
    original shows that no line was lost, changed or duplicated."""
    english_lines = texts["en"].split("\n")
    lines = []
    for index, english in enumerate(english_lines):
        lines.append(english)
        credit = credit_of(english)
        for language in [code for code in LANGUAGES if code != "en" and code in texts]:
            line = texts[language].split("\n")[index]
            if line == english:
                continue
            if credit and line.endswith(f" {credit}") and "@" not in line[: -len(credit) - 1]:
                line = line[: -len(credit) - 1]
            lines.append(line)
    return lines


def main(argv):
    check_only = "--check" in argv
    paths = [arg for arg in argv[1:] if arg != "--check"]
    if len(paths) != 1:
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 2
    path = paths[0]
    with open(path, encoding="utf-8") as file:
        source = json.load(file)

    failures = []
    split_count = 0
    for app in source.get("apps", []):
        for version in app.get("versions", []):
            label = f"{version.get('version')} ({version.get('buildVersion')})"
            if "localizedDescriptions" in version:
                # Split by an earlier run: only the numbers go.
                version["localizedDescription"] = strip_numbers(version["localizedDescription"])
                version["localizedDescriptions"] = {
                    code: strip_numbers(text) for code, text in version["localizedDescriptions"].items()
                }
                continue
            try:
                texts = split(version.get("localizedDescription", ""))
            except SplitError as error:
                failures.append(f"{label}: {error}")
                continue
            if texts is None:
                version["localizedDescription"] = strip_numbers(version.get("localizedDescription", ""))
                continue
            if any(len(lines.split("\n")) != len(texts["en"].split("\n")) for lines in texts.values()) or (
                unsplit(texts) != source_lines(version["localizedDescription"])
            ):
                failures.append(f"{label}: the split texts do not give back the original lines")
                continue
            # Rebuilt so that `localizedDescriptions` follows `localizedDescription`.
            rebuilt = {}
            for key, value in version.items():
                rebuilt[key] = texts["en"] if key == "localizedDescription" else value
                if key == "localizedDescription":
                    rebuilt["localizedDescriptions"] = texts
            version.clear()
            version.update(rebuilt)
            split_count += 1

    for failure in failures:
        print(f"Could not split {failure}", file=sys.stderr)
    print(f"Split {split_count} versions; {len(failures)} could not be split.", file=sys.stderr)
    if failures:
        return 1
    if not check_only:
        with open(path, "w", encoding="utf-8") as file:
            json.dump(source, file, ensure_ascii=False, indent=2)
            file.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
