"""`require-passing-tests.sh`: a release does not run the tests again, it requires that the Test workflow passed on
exactly its commit, and waits for a run that is still going. `gh` is a stand-in that answers from files and never
reaches the network."""

import json
import os
import pathlib
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "require-passing-tests.sh"
SHA = "0123456789abcdef0123456789abcdef01234567"
OTHER_SHA = "fedcba9876543210fedcba9876543210fedcba98"
REPO = "example-org/example-repo"

# Answers every `gh api` call with the next numbered file of $FAKE_GH_DIR (response-1.json, response-2.json, ...; the
# last one repeats), or fails with HTTP 500 when the file is named fail-N. Every call's arguments go to $FAKE_GH_LOG.
FAKE_GH = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$FAKE_GH_LOG"
count=$(( $(cat "$FAKE_GH_DIR/count" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$FAKE_GH_DIR/count"
last=$(ls "$FAKE_GH_DIR" | grep -c '^\\(response\\|fail\\)-')
(( count > last )) && count=$last
if [[ -f "$FAKE_GH_DIR/fail-$count" ]]; then
  echo "gh: HTTP 500" >&2
  exit 1
fi
cat "$FAKE_GH_DIR/response-$count.json"
"""


def run_of(run_id=77, sha=SHA, event="push", status="completed", conclusion="success", started="2026-11-12T04:42:58Z",
           attempt=1):
    return {"id": run_id, "head_sha": sha, "event": event, "status": status, "conclusion": conclusion,
            "run_started_at": started, "created_at": started, "run_attempt": attempt,
            "html_url": f"https://github.com/{REPO}/actions/runs/{run_id}"}


class RequirePassingTestsTests(unittest.TestCase):
    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.dir)], check=True))
        gh = self.dir / "gh"
        gh.write_text(FAKE_GH)
        gh.chmod(gh.stat().st_mode | stat.S_IXUSR)
        self.answers = self.dir / "answers"
        self.answers.mkdir()
        self.log = self.dir / "gh.log"

    def run_script(self, *answers, arguments=(SHA,), poll="0", timeout="60", repo=REPO):
        """`answers`: one entry per call, each a list of runs for one page, a list of such pages, or "fail"."""
        for number, answer in enumerate(answers, start=1):
            if answer == "fail":
                (self.answers / f"fail-{number}").write_text("")
                continue
            pages = answer if answer and isinstance(answer[0], list) else [answer]
            (self.answers / f"response-{number}.json").write_text(
                "\n".join(json.dumps({"total_count": len(page), "workflow_runs": page}) for page in pages))
        env = {**os.environ, "PATH": f"{self.dir}{os.pathsep}{os.environ['PATH']}", "FAKE_GH_LOG": str(self.log),
               "FAKE_GH_DIR": str(self.answers), "GH_TOKEN": "unused", "REQUIRE_TESTS_POLL_SECONDS": poll,
               "REQUIRE_TESTS_TIMEOUT_SECONDS": timeout}
        env.pop("GITHUB_REPOSITORY", None)
        if repo:
            env["GITHUB_REPOSITORY"] = repo
        return subprocess.run(["bash", str(SCRIPT), *arguments], capture_output=True, text=True, env=env)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def assertFails(self, result, *needles):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        message = result.stdout + result.stderr
        self.assertIn("::error::", message)
        for needle in needles:
            self.assertIn(needle, message)

    def test_a_successful_push_run_passes_and_is_read_for_the_exact_commit(self):
        result = self.run_script([run_of()])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("passed", result.stdout)
        calls = self.calls()
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0].startswith("api "), calls[0])
        self.assertIn(f"repos/{REPO}/actions/workflows/test.yml/runs", calls[0])
        self.assertIn(f"head_sha={SHA}", calls[0])

    def test_a_manual_run_of_the_commit_passes_too(self):
        result = self.run_script([run_of(event="workflow_dispatch")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_a_success_on_a_later_page_passes(self):
        result = self.run_script([[run_of(run_id=1, sha=OTHER_SHA)], [run_of(run_id=2)]])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_every_conclusion_but_success_fails_with_the_link_to_the_run(self):
        for conclusion in ("failure", "cancelled", "skipped", "timed_out", "neutral", "action_required", "stale", None):
            with self.subTest(conclusion=conclusion):
                result = self.run_script([run_of(conclusion=conclusion)])
                self.assertFails(result, f"https://github.com/{REPO}/actions/runs/77", SHA)
                if conclusion:
                    self.assertIn(f"'{conclusion}'", result.stdout)
                self.setUp()

    def test_no_run_fails_and_says_why(self):
        result = self.run_script([])
        self.assertFails(result, SHA, "[skip test]", f"https://github.com/{REPO}/actions/workflows/test.yml")
        self.assertEqual(len(self.calls()), 1)

    def test_a_run_of_another_commit_is_not_this_commits(self):
        # Whatever the query returned, the run's own head_sha must be the commit.
        self.assertFails(self.run_script([run_of(sha=OTHER_SHA)]), SHA)

    def test_a_pull_request_run_is_not_a_push_run(self):
        for event in ("pull_request", "pull_request_target", "schedule", "merge_group"):
            with self.subTest(event=event):
                self.assertFails(self.run_script([run_of(event=event)]), SHA)
                self.setUp()

    def test_a_skipped_run_is_not_a_pass_even_with_an_older_success(self):
        result = self.run_script([run_of(run_id=1, started="2026-11-12T04:00:00Z"),
                                  run_of(run_id=2, conclusion="skipped", started="2026-11-12T05:00:00Z")])
        self.assertFails(result, "actions/runs/2", "'skipped'")

    def test_the_newest_run_decides(self):
        failed_then_fixed = [run_of(run_id=1, conclusion="failure", started="2026-11-12T04:00:00Z"),
                             run_of(run_id=2, started="2026-11-12T05:00:00Z")]
        self.assertEqual(self.run_script(failed_then_fixed).returncode, 0)
        self.setUp()
        passed_then_failed = [run_of(run_id=1, started="2026-11-12T04:00:00Z"),
                              run_of(run_id=2, conclusion="failure", started="2026-11-12T05:00:00Z")]
        self.assertFails(self.run_script(passed_then_failed), "actions/runs/2")

    def test_a_run_in_progress_is_waited_for_until_it_passes(self):
        result = self.run_script([run_of(status="queued", conclusion=None)],
                                 [run_of(status="in_progress", conclusion=None)], [run_of()])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.calls()), 3)
        self.assertIn("waiting", result.stdout)
        self.assertIn("passed", result.stdout)

    def test_a_run_in_progress_that_then_fails_fails(self):
        result = self.run_script([run_of(status="in_progress", conclusion=None)], [run_of(conclusion="failure")])
        self.assertFails(result, "actions/runs/77", "'failure'")
        self.assertEqual(len(self.calls()), 2)

    def test_a_run_that_never_finishes_is_given_up_on(self):
        result = self.run_script([run_of(status="in_progress", conclusion=None)], timeout="1")
        self.assertFails(result, "actions/runs/77", "gave up")

    def test_the_poll_interval_and_timeout_default_to_30_seconds_and_90_minutes(self):
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('poll="${REQUIRE_TESTS_POLL_SECONDS:-30}"', text)
        self.assertIn('timeout="${REQUIRE_TESTS_TIMEOUT_SECONDS:-5400}"', text)

    def test_a_push_that_has_only_just_happened_gets_a_grace_period_to_start_its_run(self):
        result = self.run_script([], [], [run_of(status="queued", conclusion=None)], [run_of()],
                                 arguments=(SHA, "--start-grace", "60"))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.calls()), 4)

    def test_without_a_grace_period_a_missing_run_fails_at_once(self):
        result = self.run_script([], [run_of()])
        self.assertFails(result)
        self.assertEqual(len(self.calls()), 1)

    def test_a_missing_run_still_fails_when_the_grace_period_is_over(self):
        # A zero-second grace is the same as none; a long one is spent polling (bounded here by the answers).
        self.assertFails(self.run_script([], arguments=(SHA, "--start-grace", "0")))

    def test_a_failed_api_call_is_retried_a_few_times_and_then_stops_the_release(self):
        result = self.run_script("fail", [run_of()])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.setUp()
        self.assertFails(self.run_script("fail"), "cannot be confirmed")
        self.assertEqual(len(self.calls()), 5)

    def test_a_bad_commit_sha_fails_before_any_call(self):
        for bad in ("", "main", "0123456", SHA.upper(), SHA + "0"):
            with self.subTest(sha=bad):
                self.assertFails(self.run_script([run_of()], arguments=(bad,) if bad else ()), "not a full commit SHA")
                self.assertEqual(self.calls(), [])
                self.setUp()

    def test_a_missing_repository_fails_before_any_call(self):
        self.assertFails(self.run_script([run_of()], repo=""), "GITHUB_REPOSITORY")
        self.assertEqual(self.calls(), [])

    def test_an_unknown_option_fails(self):
        self.assertFails(self.run_script([run_of()], arguments=(SHA, "--frobnicate")), "--frobnicate")
        self.assertFails(self.run_script([run_of()], arguments=(SHA, "--start-grace", "soon")), "number")


if __name__ == "__main__":
    unittest.main()
