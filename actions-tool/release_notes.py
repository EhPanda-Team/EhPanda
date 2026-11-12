#!/usr/bin/env python3
"""Reads a release's notes file and writes the notes for each place a release is announced.

Each release has one committed file, `ReleaseNotes/<version>.md`, where <version> is the version
the release is tagged with (owner msgs 2564, 2567, 2569). The format is described in
`ReleaseNotes/README.md`: one `## ` section per language, all six, in this order and with exactly
these headings:

    ## English
    ## Deutsch
    ## 日本語
    ## 한국어
    ## 简体中文
    ## 繁體中文

Usage:
  release_notes.py version                       the version the next release is tagged with
  release_notes.py check [<file>]                fails unless the file (default: the next
                                                 release's) has every section, non-empty
  release_notes.py english <file>                the English notes (SideStore, plain AltStore field)
  release_notes.py altstore <file>               {"en": ..., "de": ..., ...} for AltStore's
                                                 localizedDescriptions
  release_notes.py github <file>                 the GitHub release body: English, then each other
                                                 language in a collapsed section
  release_notes.py telegram <file> <url>         English, a blank line, 繁體中文, then the link
  release_notes.py discord <file> <url>          English, then the link

The PR description is not read. Every command prints to stdout and fails with a message on stderr.
"""

import json
import os
import pathlib
import re
import sys

from altstore_languages import LANGUAGES

ROOT = pathlib.Path(__file__).resolve().parents[1]
NOTES_DIR = ROOT / "ReleaseNotes"
WORKFLOW = ROOT / ".github" / "workflows" / "deploy.yml"
PROJECT = ROOT / "EhPanda.xcodeproj" / "project.pbxproj"

HEADINGS = {name: code for code, name in LANGUAGES}
# Telegram refuses a message over 4,096 characters and Discord one over 2,000.
TELEGRAM_LIMIT = 4096
DISCORD_LIMIT = 2000
# Room kept for the release link, which is only known once the release exists.
LINK_ALLOWANCE = 200
VERSION = re.compile(r"^\d+\.\d+\.\d+$")
# AltStore and SideStore show the notes as they are, so items are plain lines (owner msg 2591).
LIST_MARKER = re.compile(r"^\s*(\d+[.)]|[-*+•])\s")


class NotesError(ValueError):
    pass


def parse(text):
    """{code: notes} for the text of a notes file, in the file's order."""
    if "\r" in text:
        raise NotesError("the file has Windows line endings; save it with \\n line endings")
    sections = {}
    current = None
    for number, line in enumerate(text.split("\n"), start=1):
        if re.match(r"^#{1,6}(\s|$)", line):
            match = re.match(r"^## (\S.*?)\s*$", line)
            if not match:
                raise NotesError(f"line {number}: only `## <language>` headings are allowed: {line!r}")
            name = match.group(1)
            if name not in HEADINGS:
                expected = ", ".join(HEADINGS)
                raise NotesError(f"line {number}: {name!r} is not a language heading (use: {expected})")
            code = HEADINGS[name]
            if code in sections:
                raise NotesError(f"line {number}: the {name} section appears twice")
            sections[code] = []
            current = code
        elif current is None:
            if line.strip():
                raise NotesError(f"line {number}: text before the first heading (## English)")
        else:
            if LIST_MARKER.match(line):
                raise NotesError(f"line {number}: write each item as a plain line, without a number or bullet: {line!r}")
            sections[current].append(line)

    notes = {}
    for code, name in LANGUAGES:
        if code not in sections:
            raise NotesError(f"the {name} section is missing")
        body = "\n".join(sections[code]).strip("\n")
        if not body.strip():
            raise NotesError(f"the {name} section is empty")
        notes[code] = "\n".join(line.rstrip() for line in body.split("\n"))
    order = [code for code in sections]
    if order != [code for code, _ in LANGUAGES]:
        names = dict(LANGUAGES)
        raise NotesError("the sections are not in order; use: " + ", ".join(names[code] for code, _ in LANGUAGES))
    if length(telegram(notes, "")) + LINK_ALLOWANCE > TELEGRAM_LIMIT:
        raise NotesError(f"English and 繁體中文 together are too long for Telegram ({TELEGRAM_LIMIT} characters)")
    if length(discord(notes, "")) + LINK_ALLOWANCE > DISCORD_LIMIT:
        raise NotesError(f"English is too long for Discord ({DISCORD_LIMIT} characters)")
    return notes


def length(text):
    """The length as Telegram counts it, in UTF-16 code units; never less than Discord's count."""
    return len(text.encode("utf-16-le")) // 2


def read(path):
    path = pathlib.Path(path)
    if not path.is_file():
        raise NotesError(f"{path} does not exist; every release needs its notes file (see ReleaseNotes/README.md)")
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        raise NotesError(f"{path} is not UTF-8: {error}") from error
    try:
        return parse(text)
    except NotesError as error:
        raise NotesError(f"{path}: {error}") from error


def github(notes):
    parts = [notes["en"]]
    for code, name in LANGUAGES:
        if code != "en":
            parts.append(f"<details>\n<summary>{name}</summary>\n\n{notes[code]}\n\n</details>")
    return "\n\n".join(parts) + "\n"


def without_link(text, url):
    """The notes without a last line that is the link itself, so a post that ends with it shows it once."""
    if url and text.endswith(f"\n\n{url}"):
        return text[: -len(url)].rstrip("\n")
    return text


def last_link(text):
    """The notes' last paragraph when it is a bare link, else None."""
    last = text.rsplit("\n\n", 1)[-1]
    return last if "\n\n" in text and re.fullmatch(r"https?://\S+", last) else None


def telegram(notes, url):
    # No language is named (owner msg 2582). A link both languages end with is shown once, after 繁體中文.
    english, chinese = without_link(notes["en"], url), without_link(notes["zh-Hant"], url)
    shared = last_link(english)
    if shared and shared == last_link(chinese):
        english = without_link(english, shared)
    return f"{english}\n\n{chinese}\n\n{url}".rstrip("\n") + "\n"


def discord(notes, url):
    return f"{without_link(notes['en'], url)}\n\n{url}".rstrip("\n") + "\n"


def release_version(workflow=WORKFLOW, project=PROJECT):
    """The version the next release is tagged with.

    Where deploy.yml sets `APP_VERSION`, the workflow bumps the app to it before building. Otherwise
    the app's version is MARKETING_VERSION of the build configurations that use App/Info.plist."""
    workflow = pathlib.Path(workflow)
    if workflow.is_file():
        match = re.search(r"^\s+APP_VERSION:\s*['\"]?([^'\"\s]+)['\"]?\s*$", workflow.read_text(encoding="utf-8"), re.M)
        if match:
            return checked_version(match.group(1), f"APP_VERSION in {workflow.name}")
    project = pathlib.Path(project)
    if not project.is_file():
        raise NotesError("cannot tell the release version: no APP_VERSION in deploy.yml and no project")
    versions = set()
    for block in re.findall(r"isa = XCBuildConfiguration;(.*?)\n\t\t};", project.read_text(encoding="utf-8"), re.S):
        if re.search(r"INFOPLIST_FILE = \"?([\w/]*/)?App/Info\.plist\"?;", block):
            match = re.search(r"MARKETING_VERSION = \"?([^\";]+)\"?;", block)
            if match:
                versions.add(match.group(1))
    if len(versions) != 1:
        raise NotesError(f"cannot tell the release version: the app's MARKETING_VERSION values are {sorted(versions)}")
    return checked_version(versions.pop(), "the app's MARKETING_VERSION")


def checked_version(version, where):
    if not VERSION.match(version):
        raise NotesError(f"{where} is {version!r}, not <major>.<minor>.<patch>")
    return version


def notes_path(version):
    return NOTES_DIR / f"{version}.md"


def main(argv):
    command, args = (argv[1], argv[2:]) if len(argv) > 1 else ("", [])
    try:
        if command == "version" and not args:
            print(release_version())
        elif command == "check" and len(args) <= 1:
            path = args[0] if args else os.path.relpath(notes_path(release_version()))
            read(path)
            print(f"{path}: every section is there.", file=sys.stderr)
        elif command == "english" and len(args) == 1:
            print(read(args[0])["en"])
        elif command == "altstore" and len(args) == 1:
            print(json.dumps(read(args[0]), ensure_ascii=False))
        elif command == "github" and len(args) == 1:
            sys.stdout.write(github(read(args[0])))
        elif command == "telegram" and len(args) == 2:
            sys.stdout.write(telegram(read(args[0]), args[1]))
        elif command == "discord" and len(args) == 2:
            sys.stdout.write(discord(read(args[0]), args[1]))
        else:
            print(__doc__.split("Usage:\n", 1)[1].split("\n\n", 1)[0], file=sys.stderr)
            return 2
    except NotesError as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
