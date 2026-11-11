"""`require-snapshot-gate.sh`: the release relies on Phase 19's screenshot check (Phase 20 plan 20-11; D-14 part 2,
T-20-29, T-20-30). `gh` is a stand-in that answers from a file and never reaches the network."""

import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "require-snapshot-gate.sh"
SHA = "0123456789abcdef0123456789abcdef01234567"
CHECK = "aggregate"
REPO = "example-org/example-repo"

# Answers `gh api` with the contents of $FAKE_GH_RESPONSE (one or more JSON documents, as --paginate prints them),
# or fails when $FAKE_GH_FAIL is set. Every call's arguments are appended to $FAKE_GH_LOG.
FAKE_GH = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$FAKE_GH_LOG"
if [[ -n "${FAKE_GH_FAIL:-}" ]]; then
  echo "gh: HTTP 500" >&2
  exit 1
fi
cat "$FAKE_GH_RESPONSE"
"""


def run_of(name=CHECK, status="completed", conclusion="success", app="github-actions"):
    return {"name": name, "status": status, "conclusion": conclusion, "app": {"slug": app} if app else None}


class RequireSnapshotGateTests(unittest.TestCase):
    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.dir)], check=True))
        gh = self.dir / "gh"
        gh.write_text(FAKE_GH)
        gh.chmod(gh.stat().st_mode | stat.S_IXUSR)
        self.log = self.dir / "gh.log"
        self.response = self.dir / "response.json"

    def run_script(self, pages, *arguments, fail=False, repo=REPO):
        self.response.write_text("\n".join(json.dumps({"check_runs": runs}) for runs in pages))
        env = {**os.environ, "PATH": f"{self.dir}{os.pathsep}{os.environ['PATH']}", "FAKE_GH_LOG": str(self.log),
               "FAKE_GH_RESPONSE": str(self.response), "GH_TOKEN": "unused"}
        env.pop("FAKE_GH_FAIL", None)
        env.pop("GITHUB_REPOSITORY", None)
        if fail:
            env["FAKE_GH_FAIL"] = "1"
        if repo:
            env["GITHUB_REPOSITORY"] = repo
        arguments = arguments or (SHA, CHECK)
        return subprocess.run(["bash", str(SCRIPT), *arguments], capture_output=True, text=True, env=env)

    def test_a_successful_check_passes_and_is_read_from_the_commits_check_runs(self):
        result = self.run_script([[run_of()]])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.log.read_text().splitlines()
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0].startswith("api "), calls[0])
        self.assertIn(f"repos/{REPO}/commits/{SHA}/check-runs", calls[0])

    def test_a_success_on_a_later_page_passes(self):
        result = self.run_script([[run_of(name="other")], [run_of()]])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_every_conclusion_but_success_fails_and_is_named(self):
        for conclusion in ("neutral", "skipped", "cancelled", "timed_out", "failure", "action_required", "stale",
                           None):
            with self.subTest(conclusion=conclusion):
                result = self.run_script([[run_of(conclusion=conclusion)]])
                self.assertEqual(result.returncode, 1)
                message = result.stdout + result.stderr
                self.assertIn(SHA, message)
                self.assertIn(CHECK, message)
                self.assertIn(str(conclusion) if conclusion else "completed", message)

    def test_a_check_still_running_fails_and_names_its_state(self):
        for status in ("in_progress", "queued", "pending"):
            with self.subTest(status=status):
                result = self.run_script([[run_of(status=status, conclusion=None)]])
                self.assertEqual(result.returncode, 1)
                self.assertIn(status, result.stdout + result.stderr)

    def test_no_run_of_that_name_fails(self):
        for runs in ([], [run_of(name="checks"), run_of(name="shard 1 (iphone)")]):
            with self.subTest(runs=len(runs)):
                result = self.run_script([runs])
                self.assertEqual(result.returncode, 1)
                message = result.stdout + result.stderr
                self.assertIn(SHA, message)
                self.assertIn(CHECK, message)

    def test_a_same_named_check_from_another_app_does_not_count(self):
        for app in ("some-other-app", None):
            with self.subTest(app=app):
                result = self.run_script([[run_of(app=app)]])
                self.assertEqual(result.returncode, 1)

    def test_every_matching_run_must_be_green(self):
        result = self.run_script([[run_of(), run_of(conclusion="failure")]])
        self.assertEqual(result.returncode, 1)

    def test_an_error_from_gh_fails(self):
        result = self.run_script([[run_of()]], fail=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn(SHA, result.stdout + result.stderr)

    def test_a_bad_call_fails_before_reading_anything(self):
        for arguments, repo in (((), REPO), (("not-a-sha", CHECK), REPO), ((SHA,), REPO), ((SHA, ""), REPO),
                                ((SHA, CHECK), None)):
            with self.subTest(arguments=arguments, repo=repo):
                result = self.run_script([[run_of()]], *arguments, repo=repo) if arguments else \
                    self.run_script([[run_of()]], "", repo=repo)
                self.assertEqual(result.returncode, 1)
                self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
