#!/usr/bin/env python3
"""Writes the body of the dependency update's pull request: what changed between two `Package.resolved` files.

Usage:
  dependency_changes.py <before> <after> [--xcode <text>]

<before> is the base branch's `Package.resolved` and <after> the one just resolved (dependencies.yml). <text> is
what `xcodebuild -version` printed in the job that resolved it.

The body, each part only when it has something to say:

    Resolved with Xcode 27.1 (17B55).

    2 dependencies have changed:
    ~ kingfisher 8.13.0 -> kingfisher 8.16.0
    ~ swift-collections 1.7.3 -> swift-collections 1.7.6

    1 dependency was added:
    + swift-atomics 1.3.0

    1 dependency was removed:
    - swift-numerics 1.1.1

    Release notes URLs (updating from):
    https://github.com/onevcat/Kingfisher/releases (8.13.0)
    https://github.com/apple/swift-collections/releases (1.7.3)

The Xcode is named because a package may ship a manifest per Swift version, so two toolchains can resolve the same
requirements to different pins: whoever builds the branch needs the one that resolved it.

A pin is named by its version, or by its branch where it follows one. Where that name is the same before and
after (a branch that moved on, a tag that was moved), the short revisions are added, since the pin changed all
the same. A releases page is listed for a package hosted on GitHub, with the version to read on from; other hosts
have no such page at a known address and are left out of that list.

The body goes to stdout. A file that is not a `Package.resolved` this reads, or an Xcode text it cannot read,
fails with a message on stderr.
"""

import argparse
import json
import pathlib
import re
import sys

# The two formats whose pins are `{identity, location, state}`. Version 1 named them differently and no supported
# toolchain writes it.
FORMATS = (2, 3)
GITHUB = "https://github.com/"
SHORT_REVISION = 7


class ChangesError(ValueError):
    """A lockfile or an Xcode text this cannot read."""


def pins(text, where):
    """`{identity: pin}` for a `Package.resolved` file's text."""
    try:
        document = json.loads(text)
    except json.JSONDecodeError as error:
        raise ChangesError(f"{where} is not JSON: {error}") from error
    if (not isinstance(document, dict) or document.get("version") not in FORMATS
            or not isinstance(document.get("pins"), list)):
        raise ChangesError(f"{where} is not a Package.resolved of format {' or '.join(map(str, FORMATS))}.")
    found = {}
    for pin in document["pins"]:
        try:
            state = pin["state"]
            found[pin["identity"]] = {"location": pin["location"], "revision": state.get("revision") or "",
                                      "name": state.get("version") or state.get("branch") or ""}
        except (KeyError, TypeError, AttributeError) as error:
            raise ChangesError(f"{where} has a pin without an identity, a location or a state.") from error
    return found


def named(pin, with_revision=False):
    """A pin's version or branch; its short revision as well when asked, and alone when it has neither."""
    revision = pin["revision"][:SHORT_REVISION]
    if not pin["name"]:
        return revision
    return f"{pin['name']} ({revision})" if with_revision and revision else pin["name"]


def count(number, one, many):
    return f"{number} {one if number == 1 else many}"


def xcode_line(text):
    """`Resolved with Xcode 27.1 (17B55).` from what `xcodebuild -version` prints."""
    found = re.fullmatch(r"\s*(Xcode \S+)\s+Build version (\S+)\s*", text)
    if not found:
        raise ChangesError(f"This is not what `xcodebuild -version` prints: {text!r}")
    return f"Resolved with {found.group(1)} ({found.group(2)})."


def releases(location):
    """A GitHub repository's releases page, or None for a package hosted elsewhere."""
    if not location.startswith(GITHUB):
        return None
    return re.sub(r"(\.git)?/*$", "", location) + "/releases"


def body(before, after, xcode=None):
    """The pull request body for the change from the `before` pins to the `after` pins."""
    changed, links = [], []
    for identity in sorted(before.keys() & after.keys()):
        old, new = before[identity], after[identity]
        if (old["name"], old["revision"]) == (new["name"], new["revision"]):
            continue
        same_name = old["name"] == new["name"]
        changed.append(f"~ {identity} {named(old, same_name)} -> {identity} {named(new, same_name)}")
        page = releases(new["location"])
        if page:
            links.append(f"{page} ({named(old, same_name)})")
    added = [f"+ {identity} {named(after[identity])}" for identity in sorted(after.keys() - before.keys())]
    removed = [f"- {identity} {named(before[identity])}" for identity in sorted(before.keys() - after.keys())]

    parts = [xcode_line(xcode)] if xcode is not None else []
    if changed:
        parts.append("\n".join([count(len(changed), "dependency has", "dependencies have") + " changed:"] + changed))
    if added:
        parts.append("\n".join([count(len(added), "dependency was", "dependencies were") + " added:"] + added))
    if removed:
        parts.append("\n".join([count(len(removed), "dependency was", "dependencies were") + " removed:"] + removed))
    if not (changed or added or removed):
        parts.append("No dependency's pin has changed.")
    if links:
        parts.append("\n".join(["Release notes URLs (updating from):"] + links))
    return "\n\n".join(parts) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("before", type=pathlib.Path)
    parser.add_argument("after", type=pathlib.Path)
    parser.add_argument("--xcode")
    args = parser.parse_args(argv)
    try:
        before, after = (pins(path.read_text(encoding="utf-8"), path) for path in (args.before, args.after))
        sys.stdout.write(body(before, after, args.xcode))
    except (ChangesError, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
