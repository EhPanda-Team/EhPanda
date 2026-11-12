"""No tracked file outside `.planning/` claims the app has Apple's approval (Phase 20 D-04, prep L8).

An AltStore PAL build is notarized, not reviewed for approval, so EhPanda must never claim Apple's approval. The
phrases are spelled as regular expressions below, so this file does not match itself. `.planning/` is left out
because the plans quote the rule.
"""

import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PHRASE = re.compile(rb"apple[\s-]+approved|approved\s+by\s+apple", re.IGNORECASE)


def tracked_files():
    output = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True).stdout
    return [name for name in output.decode("utf-8").split("\0") if name and not name.startswith(".planning/")]


def offending(paths, root):
    """The paths, relative to `root`, of the text files among `paths` that contain the phrase."""
    found = []
    for name in paths:
        path = root / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"\0" in data:
            continue
        if PHRASE.search(data):
            found.append(name)
    return found


class NoAppleApprovedWordingTests(unittest.TestCase):
    def test_no_tracked_file_uses_the_wording(self):
        paths = tracked_files()
        self.assertGreater(len(paths), 100)
        self.assertEqual(offending(paths, ROOT), [])

    def test_the_check_finds_every_spelling(self):
        spellings = ["Apple" + "-approved", "apple " + "approved", "APPLE" + "  APPROVED", "approved " + "by Apple",
                     "Approved\n" + "by apple"]
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            for index, spelling in enumerate(spellings):
                (root / f"{index}.md").write_text(f"EhPanda is {spelling}.\n", encoding="utf-8")
            (root / "clean.md").write_text("Notarized by Apple for the AltStore PAL marketplace.\n", encoding="utf-8")
            (root / "binary.png").write_bytes(b"\x89PNG\0" + ("Apple" + " approved").encode())
            names = [f"{index}.md" for index in range(len(spellings))] + ["clean.md", "binary.png"]
            self.assertEqual(offending(names, root), [f"{index}.md" for index in range(len(spellings))])


if __name__ == "__main__":
    unittest.main()
