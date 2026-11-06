#!/usr/bin/env python3
"""Phase 18.1 copy check: the report form strings against the owner-approved copy, byte for byte.

Usage:
    18.1-copy-check.py               check the repository's catalogs (exit 0 clean, 1 with findings)
    18.1-copy-check.py --self-test   run the built-in cases on temporary catalogs
    18.1-copy-check.py --root DIR    check the catalogs of another checkout

Source (CONTEXT D-06, D-09): 18.1-COPY-REPORT-FORM.md, Camo's final file (msg 1977), headed "APPROVED msg 1975".
This script only reads it; the file is never edited.

- Every `report.*` row of its key tables is a shipping key, unless its key cell is struck out (`~~key~~ DROPPED`):
  those six gallery-only rows are dropped keys (owner msg 1975). A parenthesised note after a key name is not part
  of the key.
- `report.reason.choose` is approved but dropped by the lead (msgs 1980, 1983): the final C-13 reason list is a
  plain checkmark list with no picker, so the string is never shown. It joins the dropped keys.
- The 22 remaining keys must be in the DetailFeature catalog, filled for all six locales, `translated`, and equal to
  the approved text. The only rewrite is the placeholder: `{site}` -> `%@`.
- No dropped key may be in any catalog, and no other `report.*` key may exist in one.

The comment prefill block (D-07) is English in every language and lives in code, so it is not a catalog key.

Standard library only.
"""

from __future__ import annotations

import contextlib
import copy
import io
import json
import re
import sys
import tempfile
from pathlib import Path

PHASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PHASE_DIR.parents[2]

COPY_FILE = "18.1-COPY-REPORT-FORM.md"
APPROVAL_MARK = "APPROVED msg 1975"

LOCALES = ("en", "de", "ko", "ja", "zh-Hans", "zh-Hant")

DETAIL_CATALOG = "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
CATALOG_GLOB = "AppPackage/Sources/**/*.xcstrings"
KEY_PREFIX = "report."

# The approved file's counts: 23 shipping rows and 6 struck-out rows (owner msg 1975).
APPROVED_SHIPPING_COUNT = 23
APPROVED_DROPPED_COUNT = 6

# Approved, but dropped by the lead (msgs 1980, 1983): C-13 has no picker, so "Choose a Reason" is never shown.
LEAD_DROPPED = ("report.reason.choose",)

LINE_BREAKS = ("\n", "\r", "\u2028", "\u2029")


# --------------------------------------------------------------------------------------------------------------------
# Copy file parsing


def parse_copy(phase_dir: Path = PHASE_DIR) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    """({shipping key: {locale: value}}, {dropped key: {locale: value}}) from the approved file's key tables."""
    path = phase_dir / COPY_FILE
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or APPROVAL_MARK not in lines[0]:
        raise SystemExit(f"{COPY_FILE}: the header does not say {APPROVAL_MARK!r}")

    shipping: dict[str, dict[str, str]] = {}
    dropped: dict[str, dict[str, str]] = {}
    columns: list[str] | None = None
    is_key_table = False
    for line in lines:
        if not line.startswith("|"):
            columns = None
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if columns is None:
            columns = cells
            is_key_table = cells[0].lower().startswith("key")
            if is_key_table and tuple(cells[1:]) != LOCALES:
                raise SystemExit(f"{COPY_FILE}: unexpected table header {cells}")
            continue
        if all(set(cell) <= set("-: ") for cell in cells):
            continue
        if not is_key_table:
            continue
        if len(cells) != 1 + len(LOCALES):
            raise SystemExit(f"{COPY_FILE}: a row has {len(cells)} cells: {cells[0]!r}")
        cell = cells[0]
        struck = re.match(r"~~(.+?)~~", cell)
        key = struck.group(1).strip() if struck else re.sub(r"\s*\(.*\)\s*$", "", cell).strip()
        if not key.startswith(KEY_PREFIX):
            raise SystemExit(f"{COPY_FILE}: unexpected key cell {cell!r}")
        target = dropped if struck else shipping
        if key in shipping or key in dropped:
            raise SystemExit(f"{COPY_FILE}: key {key!r} appears twice")
        target[key] = dict(zip(LOCALES, cells[1:]))

    if len(shipping) != APPROVED_SHIPPING_COUNT:
        raise SystemExit(f"{COPY_FILE}: {len(shipping)} shipping keys, expected {APPROVED_SHIPPING_COUNT}")
    if len(dropped) != APPROVED_DROPPED_COUNT:
        raise SystemExit(f"{COPY_FILE}: {len(dropped)} dropped keys, expected {APPROVED_DROPPED_COUNT}")
    return shipping, dropped


def transform(value: str) -> str:
    """The only rewrite: the site placeholder."""
    return value.replace("{site}", "%@")


def build_expectations(phase_dir: Path = PHASE_DIR) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    """({key that ships: {locale: catalog value}}, {key that must be absent: {locale: approved text}})."""
    shipping, dropped = parse_copy(phase_dir)
    absent = dict(dropped)
    for key in LEAD_DROPPED:
        if key not in shipping:
            raise SystemExit(f"{COPY_FILE}: lead-dropped key {key!r} is not an approved shipping row")
        absent[key] = shipping.pop(key)
    expected = {key: {locale: transform(value) for locale, value in values.items()} for key, values in shipping.items()}
    return expected, absent


# --------------------------------------------------------------------------------------------------------------------
# Catalog checks


def placeholders(text: str) -> list[str]:
    return sorted(re.findall(r"%(?:\d+\$)?[@dDuUxXoOfeEgGcCsSaAp]|%(?:\d+\$)?ll[dDuU]|%#@\w+@", text))


def check(root: Path = REPO_ROOT, phase_dir: Path = PHASE_DIR) -> list[str]:
    expected, absent = build_expectations(phase_dir)
    findings: list[str] = []

    detail_path = root / DETAIL_CATALOG
    if not detail_path.exists():
        return [f"missing catalog: {DETAIL_CATALOG}"]
    strings = json.loads(detail_path.read_text(encoding="utf-8")).get("strings", {})

    for key, values in sorted(expected.items()):
        entry = strings.get(key)
        if entry is None:
            findings.append(f"missing key: {key} in {DETAIL_CATALOG}")
            continue
        if entry.get("extractionState") != "manual":
            findings.append(f"not manual: {key} (extractionState {entry.get('extractionState')!r})")
        localizations = entry.get("localizations", {})
        en_placeholders = placeholders(values["en"])
        for locale in LOCALES:
            unit = localizations.get(locale, {}).get("stringUnit")
            if unit is None:
                findings.append(f"missing locale: {key} [{locale}]")
                continue
            if unit.get("state") != "translated":
                findings.append(f"not translated: {key} [{locale}] state {unit.get('state')!r}")
            actual = unit.get("value", "")
            want = values[locale]
            if not actual:
                findings.append(f"empty: {key} [{locale}]")
            elif actual != want:
                findings.append(f"differs: {key} [{locale}]: catalog {actual!r} != approved {want!r}")
            if any(mark in actual for mark in LINE_BREAKS):
                findings.append(f"line break: {key} [{locale}] contains a line break")
            if placeholders(actual) != en_placeholders:
                findings.append(f"placeholders: {key} [{locale}] {placeholders(actual)} != en {en_placeholders}")

    for path in sorted(root.glob(CATALOG_GLOB)):
        relative = path.relative_to(root).as_posix()
        for key in json.loads(path.read_text(encoding="utf-8")).get("strings", {}):
            if key in absent:
                findings.append(f"dropped key: {key} in {relative}")
            elif key.startswith(KEY_PREFIX) and (key not in expected or relative != DETAIL_CATALOG):
                findings.append(f"unexpected key: {key} in {relative}")
    return findings


# --------------------------------------------------------------------------------------------------------------------
# Self-test


def correct_catalog(expected: dict[str, dict[str, str]]) -> dict:
    strings = {
        # An unrelated key, as in the real catalog.
        "comment.report": {
            "extractionState": "manual",
            "localizations": {
                locale: {"stringUnit": {"state": "translated", "value": "Report on %@"}} for locale in LOCALES
            },
        }
    }
    for key, values in expected.items():
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                locale: {"stringUnit": {"state": "translated", "value": values[locale]}} for locale in LOCALES
            },
        }
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def run_on(catalog: dict) -> tuple[int, str]:
    """main() on a temporary checkout holding only this DetailFeature catalog: (exit code, output)."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        path = root / DETAIL_CATALOG
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(catalog, ensure_ascii=False), encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = main(["--root", str(root)])
    return code, output.getvalue()


def self_test() -> int:
    expected, absent = build_expectations()

    def set_value(catalog, key, locale, value):
        catalog["strings"][key]["localizations"][locale]["stringUnit"]["value"] = value

    def add_key(catalog, key):
        catalog["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                locale: {"stringUnit": {"state": "translated", "value": transform(text)}}
                for locale, text in absent[key].items()
            },
        }

    def missing(catalog):
        del catalog["strings"]["report.help.illegal_warning"]

    def reworded_zh_hant(catalog):
        old = expected["report.failed.body"]["zh-Hant"]
        set_value(catalog, "report.failed.body", "zh-Hant", old.replace("請重試", "請再試一次"))

    def empty_ko(catalog):
        set_value(catalog, "report.send", "ko", "")

    def dropped_copyright(catalog):
        add_key(catalog, "report.help.copyright")

    def lead_dropped_choose(catalog):
        add_key(catalog, "report.reason.choose")

    def unexpected(catalog):
        catalog["strings"]["report.reason.spam"] = copy.deepcopy(catalog["strings"]["report.reason.child"])

    cases = [
        ("an exactly right catalog passes", None, 0, None),
        ("a missing shipping key fails, naming it", missing, 1, "missing key: report.help.illegal_warning"),
        ("a reworded zh-Hant value fails", reworded_zh_hant, 1, "differs: report.failed.body [zh-Hant]"),
        ("an empty ko value fails", empty_ko, 1, "empty: report.send [ko]"),
        ("report.help.copyright present fails as dropped", dropped_copyright, 1, "dropped key: report.help.copyright"),
        ("report.reason.choose present fails as dropped (lead, msgs 1980/1983)", lead_dropped_choose, 1,
         "dropped key: report.reason.choose"),
        ("an unapproved report.* key fails", unexpected, 1, "unexpected key: report.reason.spam"),
    ]

    parse_failures = 0
    if len(expected) != APPROVED_SHIPPING_COUNT - len(LEAD_DROPPED):
        print(f"FAIL  parse: {len(expected)} shipping keys")
        parse_failures += 1
    if len(absent) != APPROVED_DROPPED_COUNT + len(LEAD_DROPPED):
        print(f"FAIL  parse: {len(absent)} keys that must be absent")
        parse_failures += 1
    failures = 0
    for number, (name, mutate, want_code, needle) in enumerate(cases, start=1):
        catalog = correct_catalog(expected)
        if mutate is not None:
            mutate(catalog)
        code, output = run_on(catalog)
        ok = code == want_code and (needle is None or any(line.startswith(needle) for line in output.splitlines()))
        failures += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {number}. {name} (exit {code})")
        if not ok:
            for line in output.splitlines() or ["(no output)"]:
                print(f"        {line}")
    print(f"self-test: {len(cases) - failures}/{len(cases)} cases passed")
    return 1 if failures or parse_failures else 0


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
    expected, absent = build_expectations()
    print(f"copy check: {len(expected)} keys × {len(LOCALES)} locales, 0 dropped keys present ({len(absent)} checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
