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
# or fails when $FAKE_GH_FAIL is set. Every call's arguments are appended to $FAKE_GH_LOG. A call for a commit's pull
# requests (`.../commits/<sha>/pulls`) is answered from $FAKE_GH_PULLS, and one for a workflow run
# (`.../actions/runs/<id>`) from $FAKE_GH_RUNS/<id>.json; a missing file is an HTTP 404.
FAKE_GH = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$FAKE_GH_LOG"
if [[ -n "${FAKE_GH_FAIL:-}" ]]; then
  echo "gh: HTTP 500" >&2
  exit 1
fi
case "$*" in
  */pulls*) file="${FAKE_GH_PULLS:-/nonexistent}" ;;
  */actions/runs/*) file="$FAKE_GH_RUNS/$(sed -E 's|.*/actions/runs/([0-9]+).*|\\1|' <<< "$*").json" ;;
  *) file="$FAKE_GH_RESPONSE" ;;
esac
if [[ ! -f "$file" ]]; then
  echo "gh: HTTP 404" >&2
  exit 1
fi
cat "$file"
"""


def run_of(name=CHECK, status="completed", conclusion="success", app="github-actions", run_id=None):
    run = {"name": name, "status": status, "conclusion": conclusion, "app": {"slug": app} if app else None}
    if run_id is not None:
        run["details_url"] = f"https://github.com/{REPO}/actions/runs/{run_id}/job/9{run_id}"
    return run


HEAD = "fedcba9876543210fedcba9876543210fedcba98"


def pull_of(merge_commit=SHA, head=HEAD, merged_at="2026-07-20T11:58:18Z", number=460):
    return {"number": number, "merged_at": merged_at, "merge_commit_sha": merge_commit, "head": {"sha": head}}


class GateHarness(unittest.TestCase):
    """The fake `gh` and the way the script is run; no tests of its own."""

    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.dir)], check=True))
        gh = self.dir / "gh"
        gh.write_text(FAKE_GH)
        gh.chmod(gh.stat().st_mode | stat.S_IXUSR)
        self.log = self.dir / "gh.log"
        self.response = self.dir / "response.json"

    def run_script(self, pages, *arguments, fail=False, repo=REPO, pulls=None, workflow_runs=None):
        self.response.write_text("\n".join(json.dumps({"check_runs": runs}) for runs in pages))
        runs_dir = self.dir / "runs"
        runs_dir.mkdir(exist_ok=True)
        for run_id, event in (workflow_runs or {}).items():
            (runs_dir / f"{run_id}.json").write_text(json.dumps({"id": run_id, "event": event}))
        env = {**os.environ, "PATH": f"{self.dir}{os.pathsep}{os.environ['PATH']}", "FAKE_GH_LOG": str(self.log),
               "FAKE_GH_RESPONSE": str(self.response), "FAKE_GH_RUNS": str(runs_dir), "GH_TOKEN": "unused"}
        if pulls is not None:
            pulls_file = self.dir / "pulls.json"
            pulls_file.write_text("\n".join(json.dumps(page) for page in pulls))
            env["FAKE_GH_PULLS"] = str(pulls_file)
        env.pop("FAKE_GH_FAIL", None)
        env.pop("GITHUB_REPOSITORY", None)
        if fail:
            env["FAKE_GH_FAIL"] = "1"
        if repo:
            env["GITHUB_REPOSITORY"] = repo
        arguments = arguments or (SHA, CHECK)
        return subprocess.run(["bash", str(SCRIPT), *arguments], capture_output=True, text=True, env=env)


class RequireSnapshotGateTests(GateHarness):

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


class RequireEventTests(GateHarness):
    """`--compare-only` (20-11, point 2): a candidate-mode run (a push to `ci/snapshot-gate`, or a dispatch) is also
    an `aggregate` check run, and it passes without comparing anything. Only a run of a workflow started by a pull
    request is a compare run (`snapshot-gate.yml` has no other way to mean compare for that event)."""

    def run_event(self, runs, workflow_runs):
        return self.run_script([runs], SHA, CHECK, "--compare-only", workflow_runs=workflow_runs)

    def test_a_pull_request_run_passes_and_its_workflow_run_is_read(self):
        result = self.run_event([run_of(run_id=111)], {111: "pull_request"})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"repos/{REPO}/actions/runs/111", self.log.read_text())

    def test_a_run_of_any_other_event_fails_and_names_the_event_and_the_run(self):
        for event in ("push", "workflow_dispatch", "schedule", "workflow_call"):
            with self.subTest(event=event):
                result = self.run_event([run_of(run_id=222)], {222: event})
                self.assertEqual(result.returncode, 1)
                message = result.stdout + result.stderr
                self.assertIn(event, message)
                self.assertIn("222", message)
                self.assertIn(SHA, message)

    def test_every_matching_run_must_come_from_a_pull_request(self):
        result = self.run_event([run_of(run_id=111), run_of(run_id=222)], {111: "pull_request", 222: "push"})
        self.assertEqual(result.returncode, 1)

    def test_a_run_that_is_not_green_still_fails(self):
        result = self.run_event([run_of(conclusion="failure", run_id=111)], {111: "pull_request"})
        self.assertEqual(result.returncode, 1)
        self.assertIn("failure", result.stdout + result.stderr)

    def test_a_check_run_without_a_workflow_run_url_fails(self):
        result = self.run_event([run_of()], {})
        self.assertEqual(result.returncode, 1)
        self.assertIn(SHA, result.stdout + result.stderr)

    def test_an_unreadable_workflow_run_fails(self):
        result = self.run_event([run_of(run_id=333)], {})
        self.assertEqual(result.returncode, 1)
        self.assertIn("333", result.stdout + result.stderr)

    def test_no_run_at_all_still_fails(self):
        result = self.run_event([], {})
        self.assertEqual(result.returncode, 1)

    def test_without_the_option_the_event_is_not_read(self):
        result = self.run_script([[run_of(run_id=222)]], workflow_runs={222: "push"})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("actions/runs", self.log.read_text())


class RequireMergedPullRequestTests(GateHarness):
    """`--merged-pr` (20-11, point 1): the commit is the squash or rebase commit a merged pull request left on the
    default branch, which has no check run of its own (the gate does not run on a push to main). The verdict is
    read on that pull request's head commit."""

    def run_merged(self, pulls, runs, *extra, **keywords):
        return self.run_script([runs], SHA, CHECK, "--merged-pr", *extra, pulls=pulls, **keywords)

    def test_the_verdict_is_read_on_the_merged_pull_requests_head(self):
        result = self.run_merged([[pull_of()]], [run_of()])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.log.read_text().splitlines()
        self.assertIn(f"repos/{REPO}/commits/{SHA}/pulls", calls[0])
        self.assertIn(f"repos/{REPO}/commits/{HEAD}/check-runs", calls[1])
        self.assertFalse(any(f"commits/{SHA}/check-runs" in call for call in calls))
        message = result.stdout + result.stderr
        self.assertIn(HEAD, message)
        self.assertIn(SHA, message)

    def test_a_verdict_on_the_merge_commit_alone_does_not_count(self):
        # The fake answers every check-runs call alike, so the head must be what was asked for.
        result = self.run_merged([[pull_of()]], [run_of(conclusion="failure")])
        self.assertEqual(result.returncode, 1)
        self.assertIn(HEAD, result.stdout + result.stderr)

    def test_a_commit_without_a_merged_pull_request_fails(self):
        for label, pulls in (("none", [[]]),
                             ("open", [[pull_of(merged_at=None)]]),
                             ("another merge commit", [[pull_of(merge_commit="1" * 40)]]),
                             ("two", [[pull_of(), pull_of(number=461, head="2" * 40)]])):
            with self.subTest(label):
                self.log.unlink(missing_ok=True)
                result = self.run_merged(pulls, [run_of()])
                self.assertEqual(result.returncode, 1)
                message = result.stdout + result.stderr
                self.assertIn(SHA, message)
                self.assertNotIn("check-runs", self.log.read_text())

    def test_pull_requests_on_a_later_page_are_read(self):
        result = self.run_merged([[pull_of(merge_commit="1" * 40)], [pull_of()]], [run_of()])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_an_error_reading_the_pull_requests_fails(self):
        result = self.run_script([[run_of()]], SHA, CHECK, "--merged-pr", pulls=None)
        self.assertEqual(result.returncode, 1)
        self.assertIn(SHA, result.stdout + result.stderr)
        self.assertNotIn("check-runs", self.log.read_text())

    def test_the_compare_only_option_applies_to_the_pull_requests_head(self):
        result = self.run_merged([[pull_of()]], [run_of(run_id=111)], "--compare-only",
                                 workflow_runs={111: "push"})
        self.assertEqual(result.returncode, 1)
        result = self.run_merged([[pull_of()]], [run_of(run_id=111)], "--compare-only",
                                 workflow_runs={111: "pull_request"})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_an_unknown_option_fails_before_reading_anything(self):
        result = self.run_script([[run_of()]], SHA, CHECK, "--merge-pr")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.log.exists())
        result = self.run_script([[run_of()]], SHA, CHECK, "--event", "pull_request")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
