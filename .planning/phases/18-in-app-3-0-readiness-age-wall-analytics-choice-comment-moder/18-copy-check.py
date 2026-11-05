#!/usr/bin/env python3
"""Phase 18 copy check: the string catalogs against the owner-approved copy files, byte for byte.

Usage:
    18-copy-check.py               check the repository's catalogs (exit 0 clean, 1 with findings)
    18-copy-check.py --self-test   run the built-in cases on temporary catalogs
    18-copy-check.py --root DIR    check the catalogs of another checkout (DIR holds AppPackage/)

Sources (CONTEXT D-06a to D-06f, D-09, D-22; Research section 8):
- 18-COPY-FIRST-LAUNCH.md (owner msg 1767): age wall and analytics choice.
- 18-COPY-MINIMAL.md: its first table (msg 1805), Revision 2 (msg 1818), Revision 3 (msg 1839, read only as retired
  text), Revision 5 (msg 1864) and both tables of Revision 6 (msgs 1880, 1882). Revision 4 was not approved and has
  no table.
- 18-COPY-COMMENTS.md (owner msg 1780): comment report, posting warning, blocking, Blocked Users.

Precedence: Minimal file Revision 6 (`consent.level.basic.description`, `consent.level.full.description`,
`consent.level.recommended`), Revision 5 (`consent.body`) and Revision 2 (`consent.level.minimal.description`) >
its first table > the first-launch file. Every row a later source replaces is retired text, as are the
`consent.level.none*` rows and Revision 3's Basic description. Glossary tables ("One term per concept") are skipped.

Only placeholders are transformed: `{site}` -> `%1$@` and the author `%@` -> `%2$@` in
`comment.report.confirm_body`; `{site}` -> `%@` in `comment.report`. Nothing else is rewritten.

Standard library only.
"""

from __future__ import annotations

import copy
import json
import re
import sys
import tempfile
from pathlib import Path

PHASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PHASE_DIR.parents[2]

FIRST_LAUNCH = "18-COPY-FIRST-LAUNCH.md"
MINIMAL = "18-COPY-MINIMAL.md"
COMMENTS = "18-COPY-COMMENTS.md"

LOCALES = ("en", "de", "ko", "ja", "zh-Hans", "zh-Hant")

RESOURCES_CATALOG = "AppPackage/Sources/Resources/Resources/Localizable.xcstrings"
RESOURCES_CONSTANT = "AppPackage/Sources/Resources/Resources/Constant.xcstrings"
DETAIL_CATALOG = "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
CATALOG_GLOB = "AppPackage/Sources/**/*.xcstrings"

# Research A-6: the privacy page URL, untranslated (`shouldTranslate: false`), the same in every locale.
PRIVACY_KEY = "contact.privacy_policy"
PRIVACY_URL = "https://ehpanda.app/privacy"

# Retired keys: never present in any catalog (D-06a).
RETIRED_KEYS = ("consent.level.none", "consent.level.none.description")

# Section headings of the Minimal file whose tables are read, by role.
MINIMAL_FIRST_TABLE = "New strings"
MINIMAL_ACTIVE_REVISIONS = ("Revision 2", "Revision 5", "Revision 6")
MINIMAL_RETIRED_REVISIONS = ("Revision 3",)

LINE_BREAKS = ("\n", "\r", "\u2028", "\u2029")


# --------------------------------------------------------------------------------------------------------------------
# Copy file parsing


def parse_tables(path: Path) -> list[tuple[str, str, dict[str, str]]]:
    """Every `| key | en | de | ko | ja | zh-Hans | zh-Hant |` row as (section heading, key, {locale: value}).

    A key cell's parenthesised suffix (`(APPROVED)`, `(swipe action)`, ...) is stripped. Tables whose first header
    cell is not a key column (the glossaries) are skipped.
    """
    rows: list[tuple[str, str, dict[str, str]]] = []
    section = ""
    columns: list[str] | None = None
    is_key_table = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            columns = None
            continue
        if not line.startswith("|"):
            columns = None
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if columns is None:
            columns = cells
            is_key_table = cells[0].lower().startswith("key")
            if is_key_table and tuple(cells[1:]) != LOCALES:
                raise SystemExit(f"{path.name}: unexpected table header {cells}")
            continue
        if all(set(cell) <= set("-: ") for cell in cells):
            continue
        if not is_key_table:
            continue
        key = re.sub(r"\s*\(.*\)\s*$", "", cells[0]).strip()
        rows.append((section, key, dict(zip(LOCALES, cells[1:]))))
    return rows


def transform(key: str, value: str) -> str:
    """The only rewrite: the placeholders of the two report keys."""
    if key == "comment.report.confirm_body":
        return value.replace("{site}", "%1$@").replace("%@", "%2$@")
    if key == "comment.report":
        return value.replace("{site}", "%@")
    return value


def catalog_for(key: str) -> str:
    if key == PRIVACY_KEY:
        return RESOURCES_CONSTANT
    if key.startswith(("age_wall.", "consent.", "blocked_users")):
        return RESOURCES_CATALOG
    if key.startswith("comment."):
        return DETAIL_CATALOG
    raise SystemExit(f"no catalog is mapped for key {key!r}")


def build_expectations(phase_dir: Path = PHASE_DIR):
    """(expected {key: (catalog, {locale: value})}, retired [(label, locale, text)])."""
    expected: dict[str, dict[str, str]] = {}
    origin: dict[str, str] = {}
    superseded: list[tuple[str, str, dict[str, str]]] = []

    def apply(source: str, key: str, values: dict[str, str]) -> None:
        if key in expected:
            superseded.append((origin[key], key, expected[key]))
        expected[key] = values
        origin[key] = source

    # 1. The first-launch file (lowest precedence).
    for _, key, values in parse_tables(phase_dir / FIRST_LAUNCH):
        apply(f"{FIRST_LAUNCH}", key, values)

    # 2. The Minimal file: first table, then Revisions 2, 5 and 6; Revision 3 is retired text only.
    minimal_rows = parse_tables(phase_dir / MINIMAL)
    sections = {section for section, _, _ in minimal_rows}
    if MINIMAL_FIRST_TABLE not in sections:
        raise SystemExit(f"{MINIMAL}: no first table under '## {MINIMAL_FIRST_TABLE}'")
    for revision in (*MINIMAL_ACTIVE_REVISIONS, *MINIMAL_RETIRED_REVISIONS):
        if not any(section.startswith(revision) for section in sections):
            raise SystemExit(f"{MINIMAL}: no table under '{revision}'")
    for section, key, values in minimal_rows:
        if section == MINIMAL_FIRST_TABLE:
            apply(f"{MINIMAL} first table", key, values)
    for revision in MINIMAL_ACTIVE_REVISIONS:
        for section, key, values in minimal_rows:
            if section.startswith(revision):
                apply(f"{MINIMAL} {revision}", key, values)
    for section, key, values in minimal_rows:
        if section.startswith(MINIMAL_RETIRED_REVISIONS):
            superseded.append((f"{MINIMAL} {section.split(' (')[0]}", key, values))

    # 3. The comments file.
    for _, key, values in parse_tables(phase_dir / COMMENTS):
        apply(COMMENTS, key, values)

    # Retired keys leave the expected map; their rows become retired text.
    for key in RETIRED_KEYS:
        if key in expected:
            superseded.append((origin.pop(key), key, expected.pop(key)))

    result = {
        key: (catalog_for(key), {locale: transform(key, value) for locale, value in values.items()})
        for key, values in expected.items()
    }
    result[PRIVACY_KEY] = (RESOURCES_CONSTANT, {locale: PRIVACY_URL for locale in LOCALES})

    retired: list[tuple[str, str, str, bool]] = []
    active_values = {value for _, values in result.values() for value in values.values()}
    for source, key, values in superseded:
        for locale, text in values.items():
            if text in active_values:
                continue
            # A retired level *name* ("None", "Keine", ...) is a short word other keys legitimately use, so it is
            # matched as a whole value of a `consent.*` key; every retired sentence is matched anywhere.
            label_only = key == "consent.level.none"
            retired.append((f"{key} ({source})", locale, text, label_only))
    return result, retired


# --------------------------------------------------------------------------------------------------------------------
# Catalog checks


def load_catalog(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def placeholders(text: str) -> list[str]:
    return sorted(re.findall(r"%(?:\d+\$)?[@dDuUxXoOfeEgGcCsSaAp]|%(?:\d+\$)?ll[dDuU]|%#@\w+@", text))


def check(root: Path = REPO_ROOT, phase_dir: Path = PHASE_DIR) -> list[str]:
    expected, retired = build_expectations(phase_dir)
    findings: list[str] = []
    catalogs: dict[str, dict] = {}

    for key, (catalog, values) in sorted(expected.items()):
        path = root / catalog
        if catalog not in catalogs:
            if not path.exists():
                findings.append(f"missing catalog: {catalog}")
                catalogs[catalog] = {"strings": {}}
            else:
                catalogs[catalog] = load_catalog(path)
        entry = catalogs[catalog]["strings"].get(key)
        if entry is None:
            findings.append(f"missing key: {key} in {catalog}")
            continue
        if entry.get("extractionState") != "manual":
            findings.append(f"not manual: {key} in {catalog} (extractionState {entry.get('extractionState')!r})")
        if key == PRIVACY_KEY and entry.get("shouldTranslate") is not False:
            findings.append(f"translatable: {key} in {catalog} must carry shouldTranslate: false")
        localizations = entry.get("localizations", {})
        en_placeholders = placeholders(values["en"])
        for locale in LOCALES:
            unit = localizations.get(locale, {}).get("stringUnit")
            if unit is None:
                findings.append(f"missing locale: {key} [{locale}] in {catalog}")
                continue
            if unit.get("state") != "translated":
                findings.append(f"not translated: {key} [{locale}] state {unit.get('state')!r}")
            actual = unit.get("value", "")
            want = values[locale]
            if actual != want:
                findings.append(f"differs: {key} [{locale}]: catalog {actual!r} != approved {want!r}")
            if any(mark in actual for mark in LINE_BREAKS):
                findings.append(f"line break: {key} [{locale}] contains a line break")
            if placeholders(actual) != en_placeholders:
                findings.append(f"placeholders: {key} [{locale}] {placeholders(actual)} != en {en_placeholders}")

    for path in sorted(root.glob(CATALOG_GLOB)):
        relative = path.relative_to(root).as_posix()
        strings = load_catalog(path).get("strings", {})
        for key in RETIRED_KEYS:
            if key in strings:
                findings.append(f"retired key: {key} in {relative}")
        for key, entry in strings.items():
            for locale, localization in entry.get("localizations", {}).items():
                value = localization.get("stringUnit", {}).get("value", "")
                for label, retired_locale, text, label_only in retired:
                    if label_only:
                        hit = key.startswith("consent.") and value == text
                    else:
                        hit = text in value
                    if hit:
                        findings.append(
                            f"retired text: {relative} {key} [{locale}] holds {label} [{retired_locale}]: {text!r}"
                        )
    return findings


# --------------------------------------------------------------------------------------------------------------------
# Self-test


def write_catalog(path: Path, strings: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"sourceLanguage": "en", "strings": strings, "version": "1.0"}, ensure_ascii=False))


def correct_catalogs(expected) -> dict[str, dict]:
    catalogs: dict[str, dict] = {RESOURCES_CATALOG: {}, RESOURCES_CONSTANT: {}, DETAIL_CATALOG: {}}
    for key, (catalog, values) in expected.items():
        entry = {
            "extractionState": "manual",
            "localizations": {
                locale: {"stringUnit": {"state": "translated", "value": values[locale]}} for locale in LOCALES
            },
        }
        if key == PRIVACY_KEY:
            entry["shouldTranslate"] = False
        catalogs[catalog][key] = entry
    # An unrelated key that says "None" must not trip the retired level-name check.
    catalogs[DETAIL_CATALOG]["metadata.none"] = {
        "extractionState": "manual",
        "localizations": {locale: {"stringUnit": {"state": "translated", "value": "None"}} for locale in LOCALES},
    }
    return catalogs


def self_test() -> int:
    expected, retired = build_expectations()

    def set_value(catalogs, key, locale, value):
        catalogs[expected[key][0]][key]["localizations"][locale]["stringUnit"]["value"] = value

    def first_launch_retired(key):
        return next(
            text
            for label, locale, text, _ in retired
            if label.startswith(f"{key} ({FIRST_LAUNCH}") and locale == "en"
        )

    def minimal_retired(key, section):
        return next(
            text
            for label, locale, text, _ in retired
            if label == f"{key} ({MINIMAL} {section})" and locale == "en"
        )

    def apostrophe(catalogs):
        old = expected["age_wall.footnote"][1]["en"]
        assert "'" in old, "the footnote no longer has a straight apostrophe to change"
        set_value(catalogs, "age_wall.footnote", "en", old.replace("'", "\u2019"))

    def missing_zh_hant(catalogs):
        del catalogs[RESOURCES_CATALOG]["age_wall.declaration"]["localizations"]["zh-Hant"]

    def old_minimal(catalogs):
        set_value(catalogs, "consent.level.minimal.description", "en",
                  minimal_retired("consent.level.minimal.description", "first table"))

    def first_launch_basic(catalogs):
        set_value(catalogs, "consent.level.basic.description", "en",
                  first_launch_retired("consent.level.basic.description"))

    def body_1805(catalogs):
        set_value(catalogs, "consent.body", "en", minimal_retired("consent.body", "first table"))

    def revision3_basic(catalogs):
        set_value(catalogs, "consent.level.basic.description", "en",
                  minimal_retired("consent.level.basic.description", "Revision 3"))

    def first_launch_full(catalogs):
        set_value(catalogs, "consent.level.full.description", "en",
                  first_launch_retired("consent.level.full.description"))

    def missing_recommended(catalogs):
        del catalogs[RESOURCES_CATALOG]["consent.level.recommended"]

    def title_line_break(catalogs):
        title = expected["consent.title"][1]["en"]
        words = title.split(" ")
        set_value(catalogs, "consent.title", "en", " ".join(words[:-1]) + "\n" + words[-1])

    def none_key(catalogs):
        catalogs[RESOURCES_CATALOG]["consent.level.none"] = {
            "extractionState": "manual",
            "localizations": {
                locale: {"stringUnit": {"state": "translated", "value": "None"}} for locale in LOCALES
            },
        }

    cases = [
        ("correct catalogs pass", None, None),
        ("a curly apostrophe in age_wall.footnote fails", apostrophe, "differs: age_wall.footnote [en]"),
        ("a missing zh-Hant locale fails", missing_zh_hant, "missing locale: age_wall.declaration [zh-Hant]"),
        ("the msg-1805 Minimal description fails", old_minimal, "retired text:"),
        ("the first-launch Basic description fails", first_launch_basic, "retired text:"),
        ("the msg-1805 consent.body fails", body_1805, "retired text:"),
        ("the Revision 3 Basic description fails", revision3_basic, "retired text:"),
        ("the first-launch Full description fails", first_launch_full, "retired text:"),
        ("a missing consent.level.recommended fails", missing_recommended, "missing key: consent.level.recommended"),
        ("a consent.title with a line break fails", title_line_break, "line break: consent.title [en]"),
        ("a consent.level.none key fails", none_key, "retired key: consent.level.none"),
    ]

    # The retired list must hold every superseded row in all six languages.
    for key, section in (
        ("consent.level.none", FIRST_LAUNCH),
        ("consent.level.none.description", FIRST_LAUNCH),
        ("consent.body", FIRST_LAUNCH),
        ("consent.level.basic.description", FIRST_LAUNCH),
        ("consent.level.full.description", FIRST_LAUNCH),
        ("consent.body", f"{MINIMAL} first table"),
        ("consent.level.minimal.description", f"{MINIMAL} first table"),
        ("consent.level.basic.description", f"{MINIMAL} Revision 3"),
    ):
        for locale in LOCALES:
            if not any(label == f"{key} ({section})" and loc == locale for label, loc, _, _ in retired):
                print(f"FAIL  retired list lacks {key} ({section}) [{locale}]")
                return 1

    failures = 0
    for number, (name, mutate, needle) in enumerate(cases, start=1):
        catalogs = correct_catalogs(expected)
        if mutate is not None:
            catalogs = copy.deepcopy(catalogs)
            mutate(catalogs)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for catalog, strings in catalogs.items():
                write_catalog(root / catalog, strings)
            findings = check(root)
        if needle is None:
            ok = not findings
        else:
            ok = any(finding.startswith(needle) for finding in findings)
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {number:2d}. {name}")
        if not ok:
            for finding in findings or ["(no findings)"]:
                print(f"        {finding}")
    print(f"self-test: {len(cases) - failures}/{len(cases)} cases passed")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    root = REPO_ROOT
    if "--root" in argv:
        root = Path(argv[argv.index("--root") + 1]).resolve()
    findings = check(root)
    for finding in findings:
        print(finding)
    if findings:
        print(f"copy check: {len(findings)} finding(s)")
        return 1
    expected, retired = build_expectations()
    print(f"copy check: {len(expected)} keys x {len(LOCALES)} locales verbatim; {len(retired)} retired texts absent")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
