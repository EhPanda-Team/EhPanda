"""The release workflows' shape: the steps a release relies on stay in place (Phase 20 D-03, D-19; REL-18-01),
the AltStore PAL upload and submission (20-04, amended 2026-11-21, 2026-11-25 and 2026-11-26: marketplace-upload.yml,
called by deploy.yml after each release with `submit` on, or started by hand; D-07, D-21, D-26) and publish-pal.yml
(20-05, amended 2026-11-21; D-19, D-26).

YAML is read through Ruby's standard library (`ruby -ryaml -rjson`), because PyYAML is not installed on the
machines that run these tests. YAML 1.1 reads the `on:` key as `true`; only the PAL tests read triggers.
"""

import ast
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"
RUBY = shutil.which("ruby")

# Tag and release operations no workflow may run (D-03): the only tag a release makes is the one
# `softprops/action-gh-release` creates from `tag_name`. The one exception (owner request): deploy.yml's commit
# step moves that tag onto the source update commit afterwards, with exactly this command.
TAG_MOVE = (("deploy.yml", "Commit update AltStore.json and SideStore.json"), 'git tag -f "$RELEASE_VERSION" HEAD')
FORBIDDEN = [
    r"\bgit\s+tag\b",
    r"\bgit\s+push\b[^\n]*--tags\b",
    r"\bgit\s+push\b[^\n]*\s:refs/tags",
    r"\bgit\s+push\b[^\n]*--delete\b",
    r"\bgh\s+release\s+(delete|create|edit)\b",
    r"\bgh\s+api\b[^\n]*git/refs/tags",
]


# Phase 19's screenshot check is OFF in the release workflows for 3.0 (owner decision): neither deploy.yml, nor
# marketplace-upload.yml (its AltStore PAL upload), nor deploy-beta.yml calls snapshot-gate.yml or reads the
# `aggregate` check.
# The workflow and actions-tool/require-snapshot-gate.sh stay in the repository (pull requests and manual dispatch
# still use them).
GATE_CHECK = "aggregate"
GATE_SCRIPT = "./actions-tool/require-snapshot-gate.sh"
RELEASE_WORKFLOWS = ("deploy.yml", "marketplace-upload.yml", "deploy-beta.yml")
GATE_MENTIONS = ("snapshot-gate.yml", "require-snapshot-gate", "REQUIRE_SNAPSHOT_GATE", "SNAPSHOT_GATE_CHECK",
                 "Require the screenshot check")
# The one job a release job waits for: deploy.yml's AltStore PAL job runs after the release (owner decision,
# 2026-11-21), and it is the one job that calls another workflow: the upload in marketplace-upload.yml (owner
# decision, 2026-11-25).
RELEASE_NEEDS = {("deploy.yml", "AltStorePAL"): "Deploy"}
RELEASE_USES = {("deploy.yml", "AltStorePAL"): "./.github/workflows/marketplace-upload.yml"}


def load(path):
    result = subprocess.run([RUBY, "-ryaml", "-rjson", "-e", "puts JSON.dump(YAML.load_file(ARGV[0]))", str(path)],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def steps(workflow):
    """The steps of every job of `workflow`, or of one job when given a job."""
    if "jobs" not in workflow:
        return workflow.get("steps", [])
    return [step for job in workflow["jobs"].values() for step in job.get("steps", [])]


def step_named(workflow, name):
    found = [step for step in steps(workflow) if step.get("name") == name]
    if len(found) != 1:
        raise AssertionError(f"expected one step named {name!r}, found {len(found)}")
    return found[0]


def step_index(workflow, name):
    names = [step.get("name") for step in steps(workflow)]
    return names.index(name)


def code(run):
    """The shell lines of a step's `run`, without comment lines, so a comment naming a file is not a use."""
    return "\n".join(line for line in run.splitlines() if not line.strip().startswith("#"))


def expand(text, env):
    """`text` with the workflow-level `env` values put in for `$NAME`, `${NAME}` and `${{ env.NAME }}`."""
    text = re.sub(r"\$\{\{\s*env\.(\w+)\s*\}\}", lambda m: env.get(m.group(1), m.group(0)), text)
    text = re.sub(r"\$\{(\w+)(?:[#%][^}]*)?\}", lambda m: env.get(m.group(1), m.group(0)), text)
    return re.sub(r"\$(\w+)", lambda m: env.get(m.group(1), m.group(0)), text)


@unittest.skipUnless(RUBY, "ruby is not installed")
class DeployWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.deploy = load(WORKFLOWS / "deploy.yml")
        cls.release = cls.deploy["jobs"]["Deploy"]
        cls.env = cls.deploy.get("env", {})

    def run_text(self, name):
        return expand(code(step_named(self.release, name).get("run", "")), self.env)

    def test_the_build_number_is_checked_before_the_build(self):
        self.assertLess(step_index(self.release, "Check build number"), step_index(self.release, "Xcode archive"))

    def test_it_is_only_ever_started_by_hand(self):
        # Owner decision: merging a pull request or pushing to main never releases; the release
        # is started by hand on main. Owner decision: nothing is typed in; everything comes from the notes file.
        triggers = self.deploy.get("on", self.deploy.get("true"))
        self.assertEqual(list(triggers), ["workflow_dispatch"])
        self.assertFalse(triggers["workflow_dispatch"])
        text = code((WORKFLOWS / "deploy.yml").read_text(encoding="utf-8"))
        for word in ("push", "pull_request", "schedule", "release", "workflow_run"):
            with self.subTest(trigger=word):
                self.assertNotRegex(text, rf"(?m)^\s*{word}:")
        for word in ("pull_request", "github.event.", "inputs."):
            with self.subTest(word=word):
                self.assertNotIn(word, text)
        self.assertEqual(self.deploy["jobs"]["Deploy"]["if"], "github.event_name == 'workflow_dispatch'")

    def test_a_release_dispatched_off_main_fails_before_it_builds_anything(self):
        guard = step_named(self.release, "Refuse to run off main")
        self.assertEqual(step_index(self.release, "Refuse to run off main"), 0)
        self.assertEqual(guard["env"], {"REF_TYPE": "${{ github.ref_type }}", "REF_NAME": "${{ github.ref_name }}"})
        run = guard["run"]
        self.assertIn('"$REF_TYPE" != "branch"', run)
        self.assertIn('"$REF_NAME" != "main"', run)
        self.assertEqual(run.count("::error::"), 2)
        self.assertEqual(run.count("exit 1"), 2)

    def test_the_release_is_named_by_the_notes_files_title(self):
        self.assertIn('title="$(python3 "./actions-tool/release_notes.py" title "$notes_path")"', self.run_text("Retrieve data"))
        self.assertIn('echo "title=$title"', self.run_text("Retrieve data"))
        release = step_named(self.release, "Release to GitHub")
        self.assertEqual(release["with"]["name"], "${{ steps.retrieve-data.outputs.title }}")
        validate = step_named(self.release, "Validate data")
        self.assertEqual(validate["env"]["RELEASE_TITLE"], "${{ steps.retrieve-data.outputs.title }}")
        self.assertIn('[[ ! -z "$RELEASE_TITLE" ]] || exit 1', validate["run"])

    def test_the_sources_are_pushed_to_main_with_the_deploy_key(self):
        # Main's rule lets only deploy keys past, and GitHub refuses GitHub Actions on that list, so the checkout
        # carries the repository's deploy key and the source commit is pushed with it.
        checkout = step_named(self.release, "Checkout")
        self.assertEqual(checkout["with"], {"ssh-key": "${{ secrets.DEPLOY_KEY }}"})
        self.assertIn("git push origin HEAD", [line.strip() for line in
                                               self.run_text("Commit update AltStore.json and SideStore.json").splitlines()])

    def test_the_release_tag_is_moved_onto_the_source_update_commit(self):
        # Owner request: the tag softprops/action-gh-release creates on main's HEAD ends up on the commit that
        # updates the store sources, which is the commit users' clones and the release page point at.
        step = step_named(self.release, "Commit update AltStore.json and SideStore.json")
        self.assertEqual(step["env"]["RELEASE_VERSION"], "${{ steps.retrieve-data.outputs.version }}")
        lines = [line.strip() for line in self.run_text("Commit update AltStore.json and SideStore.json").splitlines()]
        self.assertEqual(lines[0], "set -euo pipefail")
        push, tag, push_tag = (lines.index(line) for line in (
            "git push origin HEAD", 'git tag -f "$RELEASE_VERSION" HEAD',
            'git push -f origin "refs/tags/$RELEASE_VERSION"'))
        self.assertLess(lines.index('git commit -m "Update AltStore.json and SideStore.json"'), push)
        self.assertLess(push, tag)
        self.assertLess(tag, push_tag)
        run = "\n".join(lines)
        remote = run.index('git ls-remote origin "refs/tags/$RELEASE_VERSION"')
        self.assertGreater(remote, run.index('git push -f origin "refs/tags/$RELEASE_VERSION"'))
        self.assertIn('git rev-parse HEAD', run[remote:])
        verification = run[remote:]
        self.assertIn("::error::", verification)
        self.assertIn("exit 1", verification)

    def test_the_release_step_comment_says_the_tag_is_moved_afterwards(self):
        text = (WORKFLOWS / "deploy.yml").read_text(encoding="utf-8")
        self.assertNotIn("The tag is created on main's HEAD.", text)
        self.assertRegex(text, r"moved onto the source update commit")

    def test_discord_is_posted_with_wait_and_the_message_id_is_logged(self):
        # So a later post can edit the message. The URL gets `wait=true` whether or not the secret has a query.
        run = code(step_named(self.release, "Post release notes")["run"])
        self.assertIn("*\\?*", run)
        self.assertIn('&wait=true', run)
        self.assertIn('?wait=true', run)
        self.assertIn("jq -r .id", run)
        self.assertIn('echo "Discord message id: $', run)
        self.assertIn("--fail-with-body", run[run.index("discord_payload="):])
        curl = run[run.index("curl", run.index("discord_payload=")):]
        self.assertNotIn('"$DISCORD_WEBHOOK"', curl)
        self.assertEqual(curl.count("DISCORD_WEBHOOK"), 0)
        for line in run.splitlines():
            if "echo" in line:
                self.assertNotIn("WEBHOOK", line)
                self.assertNotIn("discord_url", line)

    def test_the_screenshot_gate_is_off_for_3_0(self):
        # Owner decision: the release no longer waits for, or reads, the screenshot check.
        self.assertEqual(list(self.deploy["jobs"]), ["Deploy", "AltStorePAL"])
        job = self.release
        self.assertNotIn("needs", job)
        self.assertNotIn("uses", job)
        self.assertEqual([step.get("name") for step in job["steps"]][:2], ["Refuse to run off main", "Checkout"])
        self.assertNotIn("Require the screenshot check", [step.get("name") for step in job["steps"]])
        for name in ("SNAPSHOT_GATE_CHECK", "REQUIRE_SNAPSHOT_GATE_SCRIPT_PATH"):
            self.assertNotIn(name, self.env)
        # Only what the release itself needs.
        self.assertEqual(job["permissions"], {"contents": "write"})
        self.assertLess(step_index(self.release, "Check build number"), step_index(self.release, "Check release notes"))

    def test_the_build_number_check_reads_mains_classic_side_sources(self):
        run = self.run_text("Check build number")
        self.assertIn("actions-tool/check-build-number.sh", run)
        self.assertRegex(run, r"git fetch --no-tags --depth 1 origin main")
        self.assertIn("FETCH_HEAD", run)
        for source in ("AltStore.json", "SideStore.json", "AltStoreBeta.json"):
            with self.subTest(source):
                self.assertIn(f"./{source}", run)
        self.assertIn("CURRENT_PROJECT_VERSION", run)

    def test_the_build_number_check_ignores_the_pal_source(self):
        # The PAL build is versioned by App Store Connect's own rules and checked in its own job.
        self.assertNotIn("AltStorePAL", self.run_text("Check build number"))

    def test_the_release_posts_end_with_the_release_url(self):
        # Owner decision: Telegram and Discord end with the GitHub release link. A release whose notes
        # carry another link (3.0.0 ends with https://ehpanda.app, owner decision) carries it in its notes file.
        self.assertNotIn("WEBSITE_URL", self.env)
        step = step_named(self.release, "Post release notes")
        self.assertEqual(step["env"]["RELEASE_URL"], "${{ steps.release.outputs.url }}")
        run = code(step["run"])
        self.assertIn('telegram "$RELEASE_NOTES_PATH" "$RELEASE_URL"', run)
        self.assertIn('discord "$RELEASE_NOTES_PATH" "$RELEASE_URL"', run)

    def test_the_release_notes_are_checked(self):
        self.assertIn("actions-tool/release_notes.py\" check", self.run_text("Check release notes"))
        self.assertIn("release_notes.py\" check", self.run_text("Retrieve data"))

    def test_the_sources_point_at_the_releases_own_assets(self):
        update = step_named(self.release, "Update AltStore.json and SideStore.json")
        self.assertEqual(update["env"]["RELEASE_ASSETS"], "${{ steps.release.outputs.assets }}")
        run = expand(update["run"], self.env)
        self.assertIn(".browser_download_url", run)
        self.assertIn('curl -sSfIL -o /dev/null "$download_url"', update["run"])

    def test_the_sources_list_the_permissions_of_the_ipa(self):
        # AltStore refuses an install whose IPA asks for permissions the source does not list: both lists come from
        # the build (usage descriptions replace the old ones in the filter; entitlements are read from the app).
        update = step_named(self.release, "Update AltStore.json and SideStore.json")
        run = expand(update["run"], self.env)
        self.assertIn('entitlements="$(bash "./actions-tool/ipa-entitlements.sh" "/tmp/action-builds/Payload/EhPanda.app")"', run)
        self.assertIn('--argjson entitlements "$entitlements"', run)
        self.assertIn('--argjson privacy "$RELEASE_PRIVACY"', run)
        # The one call serves both sources.
        self.assertEqual(run.count("--argjson entitlements"), 1)
        self.assertIn("add_version", run)

    def test_the_sources_keep_their_history(self):
        update = step_named(self.release, "Update AltStore.json and SideStore.json")
        run = expand(update["run"], self.env)
        self.assertIn("--argjson releaseVersions null", run)
        self.assertIn('-f "./actions-tool/altstore-add-version.jq"', run)
        self.assertIn("(.apps[0].versions | length) >= 1", run)

    def test_the_release_step_is_the_only_tag_maker(self):
        release = step_named(self.release, "Release to GitHub")
        self.assertTrue(release["uses"].startswith("softprops/action-gh-release@"))
        self.assertEqual(release["id"], "release")
        self.assertEqual(release["with"]["tag_name"], "${{ steps.retrieve-data.outputs.version }}")


@unittest.skipUnless(RUBY, "ruby is not installed")
class BetaWorkflowTests(unittest.TestCase):
    def test_the_beta_still_checks_its_build_number_before_the_build(self):
        beta = load(WORKFLOWS / "deploy-beta.yml")
        self.assertLess(step_index(beta, "Check build number"), step_index(beta, "Xcode archive"))
        self.assertEqual(beta["jobs"]["Deploy"]["permissions"], {"contents": "write"})
        run = expand(step_named(beta, "Check build number")["run"], beta.get("env", {}))
        self.assertIn("actions-tool/check-build-number.sh", run)
        # The beta's own source is the checkout's ./AltStoreBeta.json, next to main's AltStore.json.
        self.assertRegex(run, r"git fetch --no-tags --depth 1 origin main")
        self.assertIn("./AltStore.json", run)
        self.assertIn('cp "./AltStoreBeta.json"', run)
        self.assertNotIn("altstore-beta branch", run)
        self.assertNotIn("ls-remote", run)

    def test_the_beta_workflow_has_no_orphan_branch_left(self):
        text = (WORKFLOWS / "deploy-beta.yml").read_text(encoding="utf-8")
        for gone in ("BETA_SOURCE_BRANCH", "git worktree", "switch --orphan", "ls-remote", "altstore-beta/altstore-beta.json"):
            with self.subTest(gone):
                self.assertNotIn(gone, text)
        self.assertIn("EhPanda/main/AltStoreBeta.json", text)

    def test_a_beta_dispatched_on_main_fails_before_it_builds_anything(self):
        beta = load(WORKFLOWS / "deploy-beta.yml")
        guard = step_named(beta, "Refuse to run on main")
        self.assertEqual(step_index(beta, "Refuse to run on main"), 0)
        self.assertLess(step_index(beta, "Refuse to run on main"), step_index(beta, "Checkout"))
        self.assertEqual(guard["env"], {"REF_TYPE": "${{ github.ref_type }}", "REF_NAME": "${{ github.ref_name }}"})
        run = guard["run"]
        self.assertIn('"$REF_TYPE" != "branch"', run)
        self.assertIn('"$REF_NAME" == "main"', run)
        self.assertEqual(run.count("::error::"), 2)
        self.assertEqual(run.count("exit 1"), 2)

    def test_the_beta_source_goes_to_the_dispatched_branch_never_to_main(self):
        step, env = self.update_step()
        self.assertEqual(step["env"]["BETA_BRANCH"], "${{ github.ref_name }}")
        run = expand(step["run"], env)
        self.assertIn('git push origin "HEAD:refs/heads/$BETA_BRANCH"', run)
        self.assertIn('git commit -m "Update AltStoreBeta.json"', run)
        self.assertIn('git add -- "./AltStoreBeta.json"', run.replace("${ALTSTORE_BETA_JSON_PATH#./}", "./AltStoreBeta.json"))
        # The only push goes to the dispatched branch, never forced, and nothing pushes main.
        pushes = re.findall(r"git push[^\n]*", run)
        self.assertEqual(len(pushes), 1)
        self.assertNotIn("--force", run)
        self.assertNotIn("refs/heads/main", run)
        # The branch may have moved during the build: every attempt starts from its latest tip, re-derives the
        # source from the tip's file, and the build number is checked against main's AltStore.json and that file.
        self.assertIn("for attempt in", run)
        self.assertIn('git fetch --no-tags --depth 1 origin "refs/heads/$BETA_BRANCH"', run)
        self.assertIn("git reset --quiet --mixed FETCH_HEAD", run)
        self.assertIn('bash "$check_build_number_path" "$build_version" "$release_json" "$beta_json"', run)
        self.assertLess(run.index("git reset --quiet --mixed FETCH_HEAD"), run.index('-f "$filter_path" "$source_json"'))
        self.assertLess(run.index('-f "$filter_path" "$source_json"'), run.index("git push"))

    def test_the_branch_is_checked_out_as_a_branch_and_may_push(self):
        beta = load(WORKFLOWS / "deploy-beta.yml")
        checkout = step_named(beta, "Checkout")
        self.assertTrue(checkout["uses"].startswith("actions/checkout@"))
        # No `ref:` override: a branch ref is checked out as that branch at the commit the run was dispatched for.
        self.assertNotIn("ref", checkout.get("with", {}))
        self.assertEqual(beta["jobs"]["Deploy"]["permissions"], {"contents": "write"})

    @classmethod
    def update_step(cls):
        beta = load(WORKFLOWS / "deploy-beta.yml")
        return step_named(beta, "Update AltStoreBeta.json on the dispatched branch"), beta.get("env", {})

    def test_the_versions_get_every_language_of_the_notes_like_the_regular_release(self):
        # The regular release passes localizedDescriptions from release_notes.py (deploy.yml); a beta version
        # used to carry English only.
        step, env = self.update_step()
        run = expand(step["run"], env)
        self.assertEqual(env["RELEASE_NOTES_TOOL_PATH"], load(WORKFLOWS / "deploy.yml")["env"]["RELEASE_NOTES_TOOL_PATH"])
        self.assertEqual(env["RELEASE_NOTES_DIR"], load(WORKFLOWS / "deploy.yml")["env"]["RELEASE_NOTES_DIR"])
        self.assertIn('notes_path="./ReleaseNotes/$version.md"', run)
        self.assertIn('python3 "./actions-tool/release_notes.py" check "$notes_path"', run)
        self.assertIn('notes="$(python3 "./actions-tool/release_notes.py" english "$notes_path")"', run)
        self.assertIn('localized_notes="$(python3 "./actions-tool/release_notes.py" altstore "$notes_path")"', run)
        self.assertIn('--arg localizedDescription "$notes"', run)
        self.assertIn('--argjson localizedDescriptions "$localized_notes"', run)
        # Without a notes file the beta keeps the release description, in English only.
        self.assertIn("localized_notes=null", run)
        self.assertIn('"${RELEASE_DESCRIPTION:-$RELEASE_TITLE}"', run)

    def test_every_beta_takes_its_metadata_from_the_template_and_only_keeps_the_published_versions(self):
        step, env = self.update_step()
        run = expand(step["run"], env)
        self.assertIn('template_path="$PWD/./actions-tool/altstore-beta.template.json"', run)
        self.assertIn('beta_json="$PWD/./AltStoreBeta.json"', run)
        # The template is the base of every run; the first beta has no published file to take versions from.
        self.assertIn('source_json="$template_path"', run)
        self.assertNotIn('source_json="$beta_json"', run)
        self.assertEqual(len(re.findall(r'-f "\$filter_path" "\$source_json"', run)), 1)

    @unittest.skipUnless(shutil.which("jq"), "jq is not installed")
    def test_a_template_fix_reaches_the_live_source_and_the_published_versions_stay(self):
        step, env = self.update_step()
        run = expand(step["run"], env)
        match = re.search(r"jq --slurpfile published \"\$beta_json\" \\\n\s*'([^']+)' \"\$template_path\"", run)
        self.assertIsNotNone(match, "the step no longer carries the versions over with jq")
        program = match.group(1)
        template = json.loads((ROOT / "actions-tool" / "altstore-beta.template.json").read_text(encoding="utf-8"))
        old_version = {"version": "3.0.0", "buildVersion": "159", "marketingVersion": "3.0.0",
                       "date": "2026-11-11T14:08:57Z", "localizedDescription": "Old.", "downloadURL": "https://example.com/a.ipa",
                       "size": 1, "sha256": "ff", "minOSVersion": "27.0"}
        live = json.loads(json.dumps(template))
        live["subtitle"] = "Stale subtitle"
        live["iconURL"] = "https://example.com/old-icon.png"
        live["apps"][0].update(beta=True, subtitle="Stale", appPermissions={"entitlements": [], "privacy": {}},
                               versions=[old_version])
        with tempfile.TemporaryDirectory() as folder:
            live_path = pathlib.Path(folder) / "live.json"
            template_path = pathlib.Path(folder) / "template.json"
            live_path.write_text(json.dumps(live), encoding="utf-8")
            template_path.write_text(json.dumps(template), encoding="utf-8")
            base = json.loads(subprocess.run(["jq", "--slurpfile", "published", str(live_path), program, str(template_path)],
                                             capture_output=True, text=True, check=True).stdout)
        expected = json.loads(json.dumps(template))
        expected["apps"][0]["versions"] = [old_version]
        self.assertEqual(base, expected)

    def test_the_beta_source_lists_the_permissions_of_the_beta_ipa(self):
        step, env = self.update_step()
        run = expand(step["run"], env)
        self.assertIn('entitlements="$(bash "./actions-tool/ipa-entitlements.sh" "$app_path")"', run)
        self.assertIn('--argjson entitlements "$entitlements"', run)
        self.assertIn('--argjson privacy "$privacy"', run)
        self.assertIn("jq -e 'type == \"array\"'", run.replace("\\\"", "\""))


@unittest.skipUnless(RUBY, "ruby is not installed")
class ReleasesDoNotTestTests(unittest.TestCase):
    """Owner decision: a release neither runs the test suite nor waits for the Test workflow. Tests are test.yml's
    job, on every branch push; a release is built from a commit the owner has already seen pass."""

    # (workflow file, release job) -> that job's permissions
    RELEASES = {("deploy.yml", "Deploy"): {"contents": "write"},
                ("deploy.yml", "AltStorePAL"): {"contents": "read"},
                ("marketplace-upload.yml", "AltStorePAL"): {"contents": "read"},
                ("deploy-beta.yml", "Deploy"): {"contents": "write"},
                ("publish-pal.yml", "Publish"): {"contents": "write"}}

    def test_no_release_runs_tests_or_waits_on_them(self):
        for name in sorted({name for name, _ in self.RELEASES}):
            with self.subTest(workflow=name):
                text = (WORKFLOWS / name).read_text(encoding="utf-8")
                body = code(text)
                names = [step.get("name") for step in steps(load(WORKFLOWS / name))]
                for step in ("Run tests", "Require passing tests"):
                    self.assertNotIn(step, names)
                self.assertNotRegex(body, r"xcodebuild\s+(clean\s+)?(build-for-)?test\b")
                self.assertNotIn("-testPlan", body)
                self.assertNotIn("FeatureTests", body)
                for needle in ("require-passing-tests", "test.yml", "workflow_run", "actions/workflows", "TESTED_SHA"):
                    self.assertNotIn(needle, body)
        self.assertFalse((ROOT / "actions-tool" / "require-passing-tests.sh").exists())

    def test_no_release_job_may_read_workflow_runs(self):
        for (name, job_name), permissions in self.RELEASES.items():
            with self.subTest(workflow=name, job=job_name):
                self.assertEqual(load(WORKFLOWS / name)["jobs"][job_name]["permissions"], permissions)

    def test_the_test_workflow_runs_the_feature_tests_on_every_branch_push(self):
        # `xcodebuild clean test -testPlan FeatureTests` on iPhone Air, iOS 27.0, on every push to a branch.
        document = load(WORKFLOWS / "test.yml")
        run = " ".join(code(step_named(document, "Run tests")["run"]).split())
        self.assertIn("xcodebuild clean test", run)
        self.assertIn("-testPlan FeatureTests", run)
        self.assertIn("-destination 'platform=iOS Simulator,name=iPhone Air,OS=27.0'", run)
        # No paths filter. A tag push has no run: moving a release's tag is a push too, and must not start the suite.
        self.assertEqual(document.get("on", document.get("true")),
                         {"push": {"branches": ["**"]}, "workflow_dispatch": None})


PAL_SECRETS = ["APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_PRIVATE_KEY", "DISTRIBUTION_CERTIFICATE", "DISTRIBUTION_CERTIFICATE_PASSWORD", "PROVISIONING_PROFILE_APP",
               "PROVISIONING_PROFILE_SHARE_EXTENSION", "APPLE_TEAM_ID"]
PAL_VARIABLES = ["ALTSTORE_PAL_MARKETPLACE_ID"]
PAL_UPLOAD_STEPS = [
    "Checkout",
    "Read the version",
    "Check the release notes",
    "Write App Store Connect key",
    "Check build number",
    "Install iOS 27 Platform",
    "Show Xcode version",
    "Set up signing",
    "Xcode archive",
    "Verify analytics credentials",
    "Verify crash reporting DSN",
    "Verify marketplace build",
    "Upload dSYMs",
    "Keep the dSYMs",
    "Export and upload",
    "Tear down signing",
    "Wait for the build",
    "Ensure the notarization version",
    "Fill What's New",
    "Attach the build",
    "Submit for notarization",
    "Upload the call record",
    "Remove the API key",
]
# The steps after the signing teardown that run only with `submit` on (owner decisions, 2026-11-26).
PAL_SUBMIT_STEPS = ["Wait for the build", "Ensure the notarization version", "Fill What's New",
                    "Attach the build", "Submit for notarization"]
# The check before the build that runs only with `submit` on.
PAL_SUBMIT_CHECKS = ["Check the release notes"]
PAL_ALWAYS_STEPS = ["Tear down signing", "Upload the call record", "Remove the API key"]
# What no step after the signing teardown may name.
PAL_SIGNING_NAMES = ["DISTRIBUTION_CERTIFICATE", "DISTRIBUTION_CERTIFICATE_PASSWORD", "PROVISIONING_PROFILE_APP",
                     "PROVISIONING_PROFILE_SHARE_EXTENSION", "APPLE_TEAM_ID", "APP_STORE_CONNECT_PRIVATE_KEY",
                     "MARKETPLACE_KEYCHAIN", "MARKETPLACE_XCCONFIG", "MARKETPLACE_EXPORT_OPTIONS"]
PAL_SUBMIT_INPUT = {"description": "Submit the uploaded build for notarization", "required": False,
                    "type": "boolean", "default": False}


@unittest.skipUnless(RUBY, "ruby is not installed")
class PalUploadJobTests(unittest.TestCase):
    """marketplace-upload.yml's `AltStorePAL` job (20-04, amended 2026-11-21, 2026-11-25 and 2026-11-26; D-07, D-21,
    D-26): it archives the marketplace build on its own, verifies and uploads it, and with `submit` on submits it for
    notarization in the same job (owner decisions, 2026-11-26). deploy.yml calls it after each release with `submit`
    on; a hand dispatch submits only when asked."""

    @classmethod
    def setUpClass(cls):
        cls.path = WORKFLOWS / "marketplace-upload.yml"
        cls.text = cls.path.read_text(encoding="utf-8")
        cls.upload = load(cls.path)
        cls.env = cls.upload.get("env", {})
        cls.job = cls.upload["jobs"]["AltStorePAL"]
        cls.deploy = load(WORKFLOWS / "deploy.yml")
        cls.deploy_env = cls.deploy.get("env", {})

    def run_text(self, name):
        return expand(code(step_named(self.job, name).get("run", "")), {**self.env, **self.job.get("env", {})})

    def test_it_is_the_only_job_and_is_called_by_deploy_or_started_by_hand(self):
        self.assertEqual(list(self.upload["jobs"]), ["AltStorePAL"])
        triggers = self.upload.get("on", self.upload.get("true"))
        # The version and build number come from the checked-out project; the one input is `submit`, off unless set
        # (owner decisions, 2026-11-26). No push starts it.
        self.assertEqual(triggers, {"workflow_call": {"inputs": {"submit": PAL_SUBMIT_INPUT}},
                                    "workflow_dispatch": {"inputs": {"submit": PAL_SUBMIT_INPUT}}})
        text = code(self.text)
        for word in ("push", "pull_request", "schedule", "release", "workflow_run"):
            with self.subTest(trigger=word):
                self.assertNotRegex(text, rf"(?m)^\s*{word}:")

    def test_deploy_calls_it_after_a_successful_release_to_submit(self):
        self.assertEqual(self.deploy["jobs"]["AltStorePAL"], {
            "needs": "Deploy",
            "permissions": {"contents": "read"},
            "uses": "./.github/workflows/marketplace-upload.yml",
            "with": {"submit": True},
            "secrets": "inherit",
        })

    def test_it_runs_in_the_protected_environment(self):
        self.assertNotIn("needs", self.job)
        self.assertNotIn("if", self.job)
        environment = self.job["environment"]
        name = environment["name"] if isinstance(environment, dict) else environment
        self.assertEqual(name, "app-marketplace")
        self.assertEqual(self.job["permissions"], {"contents": "read"})
        self.assertEqual(self.job["timeout-minutes"], 240)
        self.assertEqual(self.job["concurrency"], {"group": "pal-upload", "cancel-in-progress": False})

    def test_the_steps_run_in_order(self):
        self.assertEqual([step.get("name") for step in self.job["steps"]], PAL_UPLOAD_STEPS)

    def test_the_checkout_cannot_push(self):
        checkout = step_named(self.job, "Checkout")
        self.assertTrue(checkout["uses"].startswith("actions/checkout@"))
        self.assertIs(checkout["with"]["persist-credentials"], False)

    def test_the_version_is_the_projects(self):
        version = step_named(self.job, "Read the version")
        self.assertEqual(version["id"], "version")
        run = self.run_text("Read the version")
        for needle in ("MARKETING_VERSION", "EhPanda.xcodeproj/project.pbxproj", "ALTSTORE_PAL_MARKETPLACE_ID",
                       'echo "version=', "GITHUB_OUTPUT"):
            with self.subTest(needle=needle):
                self.assertIn(needle, run)
        for name in ("Check build number", "Verify marketplace build", "Export and upload", "Wait for the build",
                     "Ensure the notarization version", "Submit for notarization", "Check the release notes",
                     "Fill What's New"):
            with self.subTest(step=name):
                self.assertEqual(step_named(self.job, name)["env"]["VERSION"], "${{ steps.version.outputs.version }}")
        self.assertEqual(set(re.findall(r"inputs\.(\w+)", json.dumps(self.job))), {"submit"})
        self.assertNotIn("github.event.", json.dumps(self.job))

    def test_the_build_number_is_checked_against_the_pal_source_and_app_store_connect(self):
        run = self.run_text("Check build number")
        self.assertRegex(run, r"git fetch --no-tags --depth 1 origin main")
        self.assertIn("FETCH_HEAD", run)
        self.assertIn("./AltStorePAL.json", run)
        self.assertIn("actions-tool/check-build-number.sh", run)
        self.assertIn("actions-tool/asc.py\" check-build", run)
        self.assertIn("CURRENT_PROJECT_VERSION", run)
        # D-26: the PAL build carries the Classic release's build number, so the Classic sources are not compared.
        for source in ("./AltStore.json", "./SideStore.json", "./AltStoreBeta.json"):
            with self.subTest(source=source):
                self.assertNotIn(source, run)

    def test_the_build_number_is_checked_before_the_build(self):
        self.assertLess(step_index(self.job, "Check build number"), step_index(self.job, "Xcode archive"))

    def test_it_archives_the_marketplace_build_on_its_own(self):
        run = self.run_text("Xcode archive")
        self.assertIn("xcodebuild archive", run)
        self.assertIn('-xcconfig "$MARKETPLACE_XCCONFIG"', run)
        self.assertIn('-archivePath "/tmp/action-builds/EhPanda-AltStorePAL.xcarchive"', run)
        self.assertNotIn("CODE_SIGNING_ALLOWED=NO", run)
        self.assertNotIn("Config/Marketplace.xcconfig", run)
        self.assertIn("marketplace-signing.sh\" setup", self.run_text("Set up signing"))
        # Never the Classic archive: not reused, not re-signed.
        self.assertNotEqual(self.job["env"]["PAL_ARCHIVE_PATH"], self.deploy_env["ARCHIVE_PATH"])
        for step in self.job["steps"]:
            with self.subTest(step=step.get("name")):
                run = expand(code(step.get("run", "")), {**self.env, **self.job.get("env", {})})
                self.assertNotIn(self.deploy_env["ARCHIVE_PATH"], run)
                self.assertNotIn(self.deploy_env["PAYLOAD_PATH"], run)
                self.assertFalse(step.get("uses", "").startswith("actions/download-artifact@"))

    def test_nothing_asks_xcode_to_make_signing_records(self):
        # D-07: no automatic signing, so Xcode never creates or downloads a profile, certificate or App ID.
        self.assertNotIn("allowProvisioningUpdates", self.text)
        self.assertNotIn("allowProvisioningUpdates", (ROOT / "actions-tool" / "marketplace-signing.sh").read_text())

    def test_the_marketplace_build_is_verified_before_upload(self):
        run = self.run_text("Verify marketplace build")
        for needle in ("app.ehpanda.store", ".ShareExtension", "CFBundleDisplayName", "EhPanda",
                       "ehpanda-marketplace", "EhPandaURLScheme", "EhPandaDistributionChannel", "altstorePAL",
                       "PrivacyInfo.xcprivacy", "codesign --verify --deep --strict", "Authority=Apple Distribution: ",
                       "CFBundleShortVersionString", "get-task-allow", "check-build-number.sh"):
            with self.subTest(needle=needle):
                self.assertIn(needle, run)
        self.assertLess(step_index(self.job, "Verify marketplace build"), step_index(self.job, "Export and upload"))

    def test_the_upload_uses_the_export_options_and_the_api_key(self):
        run = self.run_text("Export and upload")
        self.assertIn("xcodebuild -exportArchive", run)
        self.assertIn('-exportOptionsPlist "$MARKETPLACE_EXPORT_OPTIONS"', run)
        for flag in ("-authenticationKeyPath", "-authenticationKeyID", "-authenticationKeyIssuerID"):
            with self.subTest(flag=flag):
                self.assertIn(flag, run)

    def test_only_the_submission_steps_wait_for_submit(self):
        for step in self.job["steps"]:
            name = step.get("name")
            with self.subTest(step=name):
                if name in PAL_SUBMIT_CHECKS + PAL_SUBMIT_STEPS:
                    self.assertEqual(step.get("if"), "inputs.submit")
                elif name in PAL_ALWAYS_STEPS:
                    self.assertEqual(step.get("if"), "always()")
                else:
                    self.assertNotIn("if", step)

    def test_the_client_calls_are_the_build_check_then_the_submission(self):
        text = "\n".join(self.run_text(step["name"]) for step in self.job["steps"] if "run" in step)
        self.assertEqual(re.findall(r'actions-tool/asc\.py" ([\w-]+)', text),
                         ["check-build", "wait-build", "ensure-version", "whats-new", "attach-build", "submit"])
        for needle in ("adp-id", "pal_publish.py"):
            with self.subTest(needle=needle):
                self.assertNotIn(needle, text)

    def test_the_signing_material_is_gone_before_the_wait(self):
        teardown = step_index(self.job, "Tear down signing")
        self.assertEqual(teardown, step_index(self.job, "Export and upload") + 1)
        self.assertEqual(code(step_named(self.job, "Tear down signing")["run"]).strip(),
                         'bash "$SIGNING_SCRIPT_PATH" teardown-signing')
        for name in PAL_SUBMIT_STEPS:
            self.assertLess(teardown, step_index(self.job, name))
        for step in self.job["steps"][teardown + 1:]:
            with self.subTest(step=step.get("name")):
                for secret in PAL_SIGNING_NAMES:
                    self.assertNotIn(secret, json.dumps(step))
                self.assertNotIn("xcodebuild", expand(code(step.get("run", "")),
                                                      {**self.env, **self.job.get("env", {})}))

    def test_the_submission_waits_for_the_build_and_chains_its_ids(self):
        wait = step_named(self.job, "Wait for the build")
        self.assertEqual(wait["id"], "wait-build")
        self.assertEqual(wait["env"]["BUILD_NUMBER"], "${{ steps.build-number.outputs.build }}")
        run = code(wait["run"])
        self.assertIn('wait-build --app "$ASC_APP_ID" --version "$VERSION" --build "$BUILD_NUMBER" --timeout ', run)
        self.assertIn('echo "build_id=', run)
        # The wait leaves two hours for the build and upload.
        timeout = int(re.search(r"--timeout (\d+)", run).group(1))
        self.assertLessEqual(timeout, (self.job["timeout-minutes"] - 120) * 60)
        ensure = step_named(self.job, "Ensure the notarization version")
        self.assertEqual(ensure["id"], "ensure-version")
        self.assertIn('ensure-version --app "$ASC_APP_ID" --version "$VERSION"', code(ensure["run"]))
        self.assertIn('echo "version_id=', code(ensure["run"]))
        attach = step_named(self.job, "Attach the build")
        self.assertEqual(attach["env"]["VERSION_ID"], "${{ steps.ensure-version.outputs.version_id }}")
        self.assertEqual(attach["env"]["BUILD_ID"], "${{ steps.wait-build.outputs.build_id }}")
        self.assertIn('attach-build --version-id "$VERSION_ID" --build-id "$BUILD_ID"', code(attach["run"]))
        submit = step_named(self.job, "Submit for notarization")
        self.assertEqual(submit["env"]["VERSION_ID"], "${{ steps.ensure-version.outputs.version_id }}")
        for needle in ('submit --app "$ASC_APP_ID" --version-id "$VERSION_ID"', "GITHUB_STEP_SUMMARY",
                       "Publish AltStore PAL"):
            with self.subTest(needle=needle):
                self.assertIn(needle, code(submit["run"]))
        for name in PAL_SUBMIT_STEPS:
            with self.subTest(step=name):
                env = step_named(self.job, name)["env"]
                self.assertEqual(env["APP_STORE_CONNECT_KEY_ID"], "${{ secrets.APP_STORE_CONNECT_KEY_ID }}")
                self.assertEqual(env["APP_STORE_CONNECT_ISSUER_ID"], "${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}")

    def test_the_summary_says_whether_the_run_submits(self):
        export = step_named(self.job, "Export and upload")
        self.assertEqual(export["env"]["SUBMIT"], "${{ inputs.submit }}")
        self.assertEqual(export["env"]["BUILD_NUMBER"], "${{ steps.build-number.outputs.build }}")
        run = self.run_text("Export and upload")
        for needle in ("GITHUB_STEP_SUMMARY", '"$SUBMIT" == "true"', "collaborator", "Publish AltStore PAL"):
            with self.subTest(needle=needle):
                self.assertIn(needle, run)
        self.assertLess(run.index("xcodebuild -exportArchive"), run.index("GITHUB_STEP_SUMMARY"))

    def test_the_call_record_is_kept_even_when_a_step_fails(self):
        upload = step_named(self.job, "Upload the call record")
        self.assertTrue(upload["uses"].startswith("actions/upload-artifact@"))
        self.assertEqual(upload["if"], "always()")
        self.assertIn("asc-calls.jsonl", upload["with"]["path"])
        self.assertEqual(upload["with"]["name"], "asc-call-record-${{ steps.version.outputs.version }}-upload")
        self.assertIn("asc-calls.jsonl", self.run_text("Write App Store Connect key"))
        # It follows every call the client makes, and only the key's removal comes after it.
        self.assertEqual(step_index(self.job, "Upload the call record"), len(self.job["steps"]) - 2)
        for name in PAL_SUBMIT_STEPS:
            self.assertLess(step_index(self.job, name), step_index(self.job, "Upload the call record"))

    def test_whats_new_comes_from_the_release_notes(self):
        self.assertEqual(self.env["RELEASE_NOTES_DIR"], "./ReleaseNotes")
        self.assertEqual(self.env["RELEASE_NOTES_TOOL_PATH"], "./actions-tool/release_notes.py")
        self.assertLess(step_index(self.job, "Check the release notes"),
                        step_index(self.job, "Write App Store Connect key"))
        self.assertIn('./actions-tool/release_notes.py" check "./ReleaseNotes/$VERSION.md"',
                      self.run_text("Check the release notes"))
        fill = step_named(self.job, "Fill What's New")
        self.assertEqual(fill["env"]["VERSION_ID"], "${{ steps.ensure-version.outputs.version_id }}")
        self.assertIn('./actions-tool/asc.py" whats-new --version-id "$VERSION_ID" '
                      '--notes "./ReleaseNotes/$VERSION.md"', self.run_text("Fill What's New"))
        self.assertLess(step_index(self.job, "Ensure the notarization version"),
                        step_index(self.job, "Fill What's New"))
        self.assertLess(step_index(self.job, "Fill What's New"), step_index(self.job, "Attach the build"))

    def test_the_api_key_is_removed_last_whatever_happens(self):
        last = self.job["steps"][-1]
        self.assertEqual(last["name"], "Remove the API key")
        self.assertEqual(last["if"], "always()")
        self.assertEqual(code(last["run"]).strip(), 'bash "$SIGNING_SCRIPT_PATH" teardown')

    def test_no_step_stamps_tags_or_releases(self):
        for step in self.job["steps"]:
            run = code(step.get("run", ""))
            with self.subTest(step=step.get("name")):
                self.assertNotIn("package-channel.sh", expand(run, self.env))
                self.assertNotRegex(run, r"\bgit\s+(tag|push)\b")
                self.assertNotRegex(run, r"\bgh\s+release\b")
                self.assertNotIn("action-gh-release", step.get("uses", ""))

    def test_secrets_reach_steps_only_through_env_and_are_never_echoed(self):
        for step in self.job["steps"]:
            run = step.get("run", "")
            with self.subTest(step=step.get("name")):
                self.assertNotIn("secrets.", run)
                self.assertNotRegex(run, r"set -[a-z]*x")
                for name in PAL_SECRETS:
                    self.assertNotRegex(code(run), rf"(echo|printf)[^\n|]*\$\{{?{name}\b(?![^\n]*base64)")
        self.assertNotIn("secrets.", json.dumps(self.job.get("env", {})))

    def test_the_checks_see_no_signing_secret(self):
        for name in ("Read the version", "Check the release notes", "Install iOS 27 Platform",
                     "Verify analytics credentials", "Verify crash reporting DSN"):
            with self.subTest(step=name):
                self.assertNotIn("secrets.", json.dumps(step_named(self.job, name).get("env", {})))

    def test_the_header_lists_every_secret_and_variable(self):
        header = "\n".join(line for line in self.text.splitlines() if line.startswith("#"))
        used = set(re.findall(r"(?:secrets|vars)\.(\w+)", json.dumps(self.job))) - {"GITHUB_TOKEN"}
        for name in set(PAL_SECRETS) | set(PAL_VARIABLES) | used:
            with self.subTest(name=name):
                self.assertIn(name, header)
        self.assertTrue(set(PAL_SECRETS) <= used)
        self.assertTrue(set(PAL_VARIABLES) <= used)
        for needle in ("app-marketplace", "D-07", "D-21", "D-26", "publish-pal.yml", "submit"):
            with self.subTest(needle=needle):
                self.assertIn(needle, header)


class SigningTeardownTests(unittest.TestCase):
    """actions-tool/marketplace-signing.sh: the signing teardown after the upload keeps only the API key, and the last
    step's teardown removes it (owner decision, 2026-11-26). A stand-in `security` on PATH records the keychain calls,
    so the test never touches a real keychain."""

    def test_teardown_signing_keeps_only_the_api_key_and_teardown_removes_it(self):
        script = ROOT / "actions-tool" / "marketplace-signing.sh"
        with tempfile.TemporaryDirectory() as directory:
            tmp = pathlib.Path(directory)
            (tmp / "bin").mkdir()
            (tmp / "home").mkdir()
            runner = tmp / "runner"
            runner.mkdir()
            stand_in = tmp / "bin" / "security"
            stand_in.write_text('#!/bin/sh\necho "$*" >> "$SECURITY_LOG"\n', encoding="utf-8")
            stand_in.chmod(0o755)
            env = {"PATH": f"{tmp / 'bin'}{os.pathsep}{os.environ['PATH']}", "HOME": str(tmp / "home"),
                   "RUNNER_TEMP": str(runner), "SECURITY_LOG": str(tmp / "security.log"),
                   "GITHUB_ENV": str(tmp / "github_env")}
            self.assertEqual(shutil.which("security", path=env["PATH"]), str(stand_in))

            def run(command, **extra):
                return subprocess.run(["bash", str(script), command], capture_output=True, text=True, timeout=60,
                                      env={**env, **extra})

            made = run("api-key", APP_STORE_CONNECT_KEY_ID="FAKEKEY123",
                       APP_STORE_CONNECT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----")
            self.assertEqual(made.returncode, 0, made.stderr)
            work = runner / "marketplace-signing"
            key = work / "private_keys" / "AuthKey_FAKEKEY123.p8"
            self.assertTrue(key.is_file())
            self.assertIn(f"ASC_KEY_PATH={key}", (tmp / "github_env").read_text(encoding="utf-8").splitlines())

            # What setup leaves behind.
            keychain = runner / "marketplace-signing.keychain-db"
            keychain.write_text("keychain", encoding="utf-8")
            (work / "keychain").write_text(f"{keychain}\n", encoding="utf-8")
            (work / "keychains").write_text(f"{runner}/login.keychain-db\n{keychain}\n", encoding="utf-8")
            (tmp / "profiles").mkdir()
            profiles = [tmp / "profiles" / "one.mobileprovision", tmp / "profiles" / "two.mobileprovision"]
            for profile in profiles:
                profile.write_text("profile", encoding="utf-8")
            (work / "installed-profiles").write_text("".join(f"{profile}\n" for profile in profiles), encoding="utf-8")
            leftovers = [work / "PROVISIONING_PROFILE_APP.plist", runner / "marketplace-signing.xcconfig",
                         runner / "ExportOptions-marketplace.plist"]
            for leftover in leftovers:
                leftover.write_text("generated", encoding="utf-8")

            signing = run("teardown-signing")
            self.assertEqual(signing.returncode, 0, signing.stderr)
            self.assertEqual(sorted(os.listdir(work)), ["private_keys"])
            self.assertTrue(key.is_file())
            for gone in [keychain, *profiles, *leftovers]:
                with self.subTest(gone=gone.name):
                    self.assertFalse(gone.exists())
            self.assertEqual((tmp / "security.log").read_text(encoding="utf-8").splitlines(),
                             [f"list-keychains -d user -s {runner}/login.keychain-db",
                              f"delete-keychain {keychain}"])

            full = run("teardown")
            self.assertEqual(full.returncode, 0, full.stderr)
            self.assertFalse(work.exists())
            for command in ("teardown", "teardown-signing"):
                with self.subTest(again=command):
                    self.assertEqual(run(command).returncode, 0)


PUBLISH_STEPS = [
    "Refuse to run off main",
    "Check the ADP ID",
    "Checkout",
    "Modify git config",
    "Fetch the ADP",
    "Publish to AltStore PAL",
]
GOOD_ADP_IDS = ["453ead28-2d2b-49d1-a398-5a06ca29186b", "453EAD28-2D2B-49D1-A398-5A06CA29186B"]
BAD_ADP_IDS = ["", "https://api.altstore.io/adps/453ead28-2d2b-49d1-a398-5a06ca29186b",
               "453ead28-2d2b-49d1-a398-5a06ca29186b\n", " 453ead28-2d2b-49d1-a398-5a06ca29186b",
               "453ead28-2d2b-49d1-a398", "453ead28-2d2b-49d1-a398-5a06ca29186b-",
               "453ead28_2d2b_49d1_a398_5a06ca29186b", "../etc/passwd"]


@unittest.skipUnless(RUBY, "ruby is not installed")
class PublishWorkflowTests(unittest.TestCase):
    """publish-pal.yml (20-05, amended 2026-11-21; D-19, D-26): the ADP ID alone, the unchanged ADP as release assets
    and the PAL source on `main`, pushed with the deploy key, with the permissions from the project's files (owner
    decision, 20-08)."""

    @classmethod
    def setUpClass(cls):
        cls.path = WORKFLOWS / "publish-pal.yml"
        cls.text = cls.path.read_text(encoding="utf-8")
        cls.document = load(cls.path)
        cls.env = cls.document.get("env", {})
        cls.job = cls.document["jobs"]["Publish"]

    def run_text(self, name):
        # The workflow's paths are put in; the job's $ADP_ID and $MARKETPLACE_ID are kept, as the shell sees them.
        return expand(code(step_named(self.job, name).get("run", "")), self.env)

    def test_it_is_dispatched_by_hand_with_the_adp_id_and_dry_run_only(self):
        self.assertEqual(self.document["name"], "Publish AltStore PAL")
        # YAML 1.1 reads the `on` key as true.
        triggers = self.document.get("on", self.document.get("true"))
        self.assertEqual(list(triggers), ["workflow_dispatch"])
        inputs = triggers["workflow_dispatch"]["inputs"]
        self.assertEqual(set(inputs), {"adp_id", "dry_run"})
        self.assertIs(inputs["adp_id"]["required"], True)
        self.assertEqual(inputs["adp_id"]["type"], "string")
        self.assertEqual(inputs["dry_run"]["type"], "boolean")
        self.assertIs(inputs["dry_run"]["default"], True)
        self.assertEqual(list(self.document["jobs"]), ["Publish"])
        for word in ("push:", "pull_request", "schedule:", "release:", "workflow_run", "tags:"):
            with self.subTest(word=word):
                self.assertNotIn(word, code(self.text))

    def test_it_runs_on_main_only(self):
        guard = step_named(self.job, "Refuse to run off main")
        self.assertEqual(step_index(self.job, "Refuse to run off main"), 0)
        self.assertEqual(guard["env"], {"REF_TYPE": "${{ github.ref_type }}", "REF_NAME": "${{ github.ref_name }}"})
        run = guard["run"]
        self.assertIn('"$REF_TYPE" != "branch"', run)
        self.assertIn('"$REF_NAME" != "main"', run)
        self.assertEqual(run.count("::error::"), 2)
        self.assertEqual(run.count("exit 1"), 2)

    def test_the_steps_run_in_order(self):
        self.assertEqual([step.get("name") for step in self.job["steps"]], PUBLISH_STEPS)

    def test_the_adp_id_must_be_a_uuid_before_any_request(self):
        self.assertEqual(step_index(self.job, "Check the ADP ID"), 1)
        self.assertLess(step_index(self.job, "Check the ADP ID"), step_index(self.job, "Checkout"))
        self.assertLess(step_index(self.job, "Check the ADP ID"), step_index(self.job, "Fetch the ADP"))
        self.assertEqual(self.job["env"]["ADP_ID"], "${{ inputs.adp_id }}")
        run = step_named(self.job, "Check the ADP ID")["run"]
        self.assertNotIn("${{", run)
        for value in GOOD_ADP_IDS + BAD_ADP_IDS:
            with self.subTest(adp_id=value):
                result = subprocess.run(["bash", "-c", run], capture_output=True, text=True, timeout=30,
                                        env={"PATH": os.environ.get("PATH", ""), "ADP_ID": value})
                if value in GOOD_ADP_IDS:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                else:
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("::error::", result.stdout)

    def test_the_push_to_main_uses_the_deploy_key(self):
        # Main's ruleset (pull requests and signed commits, with only the deploy key on its bypass list; checked
        # 2026-11-21) refuses a push with the job's token.
        checkout = step_named(self.job, "Checkout")
        self.assertEqual(checkout["with"], {"ssh-key": "${{ secrets.DEPLOY_KEY }}"})
        tool = (ROOT / "actions-tool" / "pal_publish.py").read_text(encoding="utf-8")
        self.assertIn('"push", "origin", "HEAD:refs/heads/main"', tool)
        self.assertLess(step_index(self.job, "Modify git config"), step_index(self.job, "Publish to AltStore PAL"))

    def test_it_holds_no_app_store_connect_key_and_no_environment(self):
        self.assertNotIn("environment", self.job)
        self.assertNotIn("environment", self.document)
        document = json.dumps(self.document)
        for needle in ("APP_STORE_CONNECT", "asc.py", "app-marketplace", "marketplace-signing", "xcodebuild", "ASC_"):
            with self.subTest(needle=needle):
                self.assertNotIn(needle, document)
        self.assertEqual(set(re.findall(r"(?:secrets|vars)\.(\w+)", code(self.text))),
                         {"DEPLOY_KEY", "ALTSTORE_PAL_MARKETPLACE_ID"})

    def test_the_header_lists_its_secret_and_variable(self):
        header = "\n".join(line for line in self.text.splitlines() if line.startswith("#"))
        for needle in ("DEPLOY_KEY", "ALTSTORE_PAL_MARKETPLACE_ID", "D-19", "D-26"):
            with self.subTest(needle=needle):
                self.assertIn(needle, header)

    def test_the_adp_is_fetched_then_published_from_its_own_manifest(self):
        fetch = self.run_text("Fetch the ADP")
        self.assertIn('actions-tool/pal_publish.py" fetch --adp-id "$ADP_ID"', fetch)
        self.assertIn("--timeout", fetch)
        publish = self.run_text("Publish to AltStore PAL")
        for needle in ('actions-tool/pal_publish.py" publish', '--repo "$GITHUB_REPOSITORY"',
                       '--marketplace-id "$MARKETPLACE_ID"', '--notes-dir "./ReleaseNotes"', "--dry-run"):
            with self.subTest(needle=needle):
                self.assertIn(needle, publish)
        self.assertNotIn("--version", publish)
        self.assertNotIn("--notes ", publish)
        self.assertNotRegex(code(self.text), r'pal_publish\.py"?\s+process')
        self.assertEqual(self.job["env"]["MARKETPLACE_ID"], "${{ vars.ALTSTORE_PAL_MARKETPLACE_ID }}")

    def test_the_permissions_come_from_the_projects_files(self):
        # Owner decision (20-08): the PAL source lists the project's entitlements and usage descriptions, never
        # what signing adds. The files publish reads must be the ones the project builds with, and nothing may add
        # an entitlements file or a usage description outside them.
        publish = self.run_text("Publish to AltStore PAL")
        project = (ROOT / "EhPanda.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
        self.assertEqual(set(re.findall(r"--entitlements (\S+)", publish)),
                         set(re.findall(r"(?<![A-Z_])CODE_SIGN_ENTITLEMENTS = ([^;]+);", project)))
        self.assertEqual(set(re.findall(r"--info-plist (\S+)", publish)),
                         set(re.findall(r"(?<![A-Z_])INFOPLIST_FILE = ([^;]+);", project)))
        overriders = sorted((ROOT / "Config").glob("*.xcconfig"))
        overriders.append(ROOT / "actions-tool" / "marketplace-signing.sh")
        for path in [ROOT / "EhPanda.xcodeproj" / "project.pbxproj", *overriders]:
            with self.subTest(path=path.name):
                self.assertNotRegex(path.read_text(encoding="utf-8"), r"INFOPLIST_KEY_\w*UsageDescription")
        for path in overriders:
            with self.subTest(path=path.name):
                self.assertNotIn("CODE_SIGN_ENTITLEMENTS", path.read_text(encoding="utf-8"))

    def test_dry_run_is_passed_through(self):
        step = step_named(self.job, "Publish to AltStore PAL")
        self.assertEqual(step["env"]["DRY_RUN"], "${{ inputs.dry_run }}")
        self.assertRegex(self.run_text("Publish to AltStore PAL"), r'"\$DRY_RUN" (==|!=) "?(true|false)"?')

    def test_gh_gets_the_job_token_only(self):
        step = step_named(self.job, "Publish to AltStore PAL")
        self.assertEqual(step["env"]["GH_TOKEN"], "${{ github.token }}")
        for other in self.job["steps"]:
            if other is not step:
                with self.subTest(step=other.get("name")):
                    self.assertNotIn("GH_TOKEN", json.dumps(other.get("env", {})))

    def test_the_job_never_builds_signs_or_submits(self):
        for step in self.job["steps"]:
            run = code(step.get("run", ""))
            with self.subTest(step=step.get("name")):
                for needle in ("xcodebuild", "marketplace-signing.sh", "asc.py", "package-channel.sh",
                               "check-build-number.sh"):
                    self.assertNotIn(needle, expand(run, self.env))
                self.assertNotRegex(run, r"\bgit\s+(tag|push)\b")
                self.assertNotRegex(run, r"\bgh\s+release\b")
                self.assertNotIn("action-gh-release", step.get("uses", ""))
        self.assertEqual(self.job["permissions"], {"contents": "write"})
        for name in ("DISTRIBUTION_CERTIFICATE", "DISTRIBUTION_CERTIFICATE_PASSWORD", "PROVISIONING_PROFILE_APP",
                     "PROVISIONING_PROFILE_SHARE_EXTENSION", "APPLE_TEAM_ID"):
            with self.subTest(secret=name):
                self.assertNotIn(name, json.dumps(self.job))

    def test_secrets_reach_steps_only_through_env(self):
        for step in self.job["steps"]:
            with self.subTest(step=step.get("name")):
                self.assertNotIn("secrets.", step.get("run", ""))
                self.assertNotRegex(step.get("run", ""), r"set -[a-z]*x")
        self.assertNotIn("secrets.", json.dumps(self.job.get("env", {})))


@unittest.skipUnless(RUBY, "ruby is not installed")
class CrashReportingWorkflowTests(unittest.TestCase):
    """Quick task 261123-3wz: each release archive carries the crash reporting DSN, a release without one fails, and
    the archive's dSYMs go to Sentry (never failing the release) and stay as a run artifact for `--reupload`."""

    # (workflow file, job, its archive path variable, the step that moves the .app out of the archive or exports
    # it, the dSYMs artifact)
    RELEASES = (
        ("deploy.yml", "Deploy", "ARCHIVE_PATH", "Export .ipa files", "EhPanda-dSYMs"),
        ("marketplace-upload.yml", "AltStorePAL", "PAL_ARCHIVE_PATH", "Export and upload", "EhPanda-AltStorePAL-dSYMs"),
        ("deploy-beta.yml", "Deploy", "ARCHIVE_PATH", "Export .ipa file", "EhPanda-Beta-dSYMs"),
    )
    UPLOAD_ENV = {
        "SENTRY_AUTH_TOKEN": "${{ secrets.SENTRY_AUTH_TOKEN }}",
        "SENTRY_ORGANIZATION": "${{ vars.SENTRY_ORGANIZATION }}",
        "SENTRY_PROJECT": "${{ vars.SENTRY_PROJECT }}",
        "SENTRY_URL": "${{ vars.SENTRY_URL }}",
    }
    SENTRY_NAMES = {"SENTRY_DSN", "SENTRY_AUTH_TOKEN", "SENTRY_ORGANIZATION", "SENTRY_PROJECT", "SENTRY_URL"}

    def each_release(self):
        for name, job_name, archive, export_step, artifact in self.RELEASES:
            document = load(WORKFLOWS / name)
            with self.subTest(workflow=name, job=job_name):
                yield name, document, document["jobs"][job_name], archive, export_step, artifact

    def test_the_archive_gets_the_dsn_as_a_build_setting(self):
        for _, _, job, _, _, _ in self.each_release():
            archive = step_named(job, "Xcode archive")
            self.assertEqual(archive["env"]["SENTRY_DSN"], "${{ secrets.SENTRY_DSN }}")
            self.assertIn('SENTRY_DSN="$SENTRY_DSN"', archive["run"])
            self.assertNotIn("secrets.", archive["run"])

    def test_a_release_without_a_dsn_fails(self):
        for _, _, job, archive, _, _ in self.each_release():
            names = [step.get("name") for step in steps(job)]
            self.assertEqual(names.index("Verify crash reporting DSN"), names.index("Verify analytics credentials") + 1)
            step = step_named(job, "Verify crash reporting DSN")
            run = code(step["run"])
            self.assertIn(f"${archive}/Products/Applications/$SCHEME_NAME.app/Info.plist", run)
            self.assertIn("plutil -extract SentryDSN raw", run)
            self.assertIn("https://", run)
            self.assertIn("::error::", run)
            self.assertIn("SENTRY_DSN", run)
            self.assertIn("exit 1", run)
            # The value is never printed, and the step holds no secret (D-02).
            self.assertNotRegex(run, r"(echo|printf)[^\n]*\$\{?dsn\b")
            self.assertNotIn("env", step)
            self.assertNotIn("secrets.", step["run"])

    def test_the_dsyms_are_uploaded_after_every_verification_and_before_the_app_leaves_the_archive(self):
        for _, _, job, archive, export_step, _ in self.each_release():
            names = [step.get("name") for step in steps(job)]
            upload = names.index("Upload dSYMs")
            for verify in [step_name for step_name in names if step_name and step_name.startswith("Verify")]:
                self.assertLess(names.index(verify), upload, verify)
            self.assertLess(upload, names.index(export_step))
            step = step_named(job, "Upload dSYMs")
            self.assertEqual(step["env"], self.UPLOAD_ENV)
            self.assertEqual(code(step["run"]).strip(), f'bash "$UPLOAD_DSYMS_SCRIPT_PATH" "${archive}"')
            self.assertNotIn("secrets.", step["run"])
            # The script's exit-0 contract is what keeps the release going: nothing here suppresses an error.
            self.assertNotIn("continue-on-error", step)

    def test_the_dsyms_are_kept_as_an_artifact_for_a_later_reupload(self):
        for _, _, job, archive, _, artifact in self.each_release():
            names = [step.get("name") for step in steps(job)]
            self.assertEqual(names.index("Keep the dSYMs"), names.index("Upload dSYMs") + 1)
            step = step_named(job, "Keep the dSYMs")
            self.assertEqual(step["uses"], "actions/upload-artifact@v7")
            self.assertEqual(step["with"], {"name": artifact, "path": f"${{{{ env.{archive} }}}}/dSYMs"})

    def test_the_script_is_named_by_the_workflow_env_and_exists(self):
        for _, document, _, _, _, _ in self.each_release():
            self.assertEqual(document["env"]["UPLOAD_DSYMS_SCRIPT_PATH"], "./actions-tool/upload-dsyms.sh")
        self.assertTrue((ROOT / "actions-tool" / "upload-dsyms.sh").is_file())

    def test_only_the_five_documented_names_are_used(self):
        for name, _, _, _, _, _ in self.each_release():
            text = (WORKFLOWS / name).read_text(encoding="utf-8")
            self.assertEqual(set(re.findall(r"SENTRY_\w+", text)), self.SENTRY_NAMES)

    def test_the_dsn_reaches_only_the_archive_and_the_token_only_the_upload(self):
        for _, _, job, _, _, _ in self.each_release():
            for step in steps(job):
                step_name = step.get("name")
                text = json.dumps(step)
                if step_name == "Xcode archive":
                    self.assertIn("SENTRY_DSN", text)
                else:
                    self.assertNotIn("secrets.SENTRY_DSN", text, step_name)
                if step_name == "Upload dSYMs":
                    self.assertIn("secrets.SENTRY_AUTH_TOKEN", text)
                else:
                    self.assertNotIn("SENTRY_AUTH_TOKEN", text, step_name)
            self.assertNotIn("SENTRY_", json.dumps(job.get("env", {})))


@unittest.skipUnless(RUBY, "ruby is not installed")
class GateOffTests(unittest.TestCase):
    """Phase 19's screenshot check is off in every release workflow for 3.0 (owner decision), and stays available."""

    def test_no_release_workflow_calls_or_reads_the_gate(self):
        for workflow in RELEASE_WORKFLOWS:
            text = (WORKFLOWS / workflow).read_text(encoding="utf-8")
            body = "\n".join(line for line in text.splitlines() if not line.strip().startswith("#"))
            for needle in GATE_MENTIONS:
                with self.subTest(workflow=workflow, needle=needle):
                    self.assertNotIn(needle, body)
            document = load(WORKFLOWS / workflow)
            for name, job in document["jobs"].items():
                with self.subTest(workflow=workflow, job=name):
                    self.assertEqual(job.get("uses"), RELEASE_USES.get((workflow, name)))
                    self.assertEqual(job.get("needs"), RELEASE_NEEDS.get((workflow, name)))
                    for step in job.get("steps", []):
                        self.assertNotIn("require-snapshot-gate", step.get("run", ""))

    def test_each_removal_site_says_why(self):
        for workflow in RELEASE_WORKFLOWS:
            with self.subTest(workflow=workflow):
                self.assertIn("Snapshot gate off for 3.0 (owner decision)",
                              (WORKFLOWS / workflow).read_text(encoding="utf-8"))

    def test_the_gate_and_its_script_stay_for_pull_requests_and_manual_runs(self):
        self.assertTrue((ROOT / GATE_SCRIPT).is_file())
        gate = WORKFLOWS / "snapshot-gate.yml"
        if gate.exists():
            job = load(gate)["jobs"]["aggregate"]
            # A job's check run is named by its `name`, or its ID when it has none.
            self.assertEqual(job.get("name", "aggregate"), GATE_CHECK)


@unittest.skipUnless(RUBY, "ruby is not installed")
class TagOperationTests(unittest.TestCase):
    def test_no_workflow_runs_a_tag_or_release_command(self):
        paths = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
        self.assertTrue(paths)
        for path in paths:
            for index, step in enumerate(steps(load(path))):
                run = code(step.get("run", ""))
                if (path.name, step.get("name")) == TAG_MOVE[0]:
                    run = "\n".join(line for line in run.splitlines() if line.strip() != TAG_MOVE[1])
                for pattern in FORBIDDEN:
                    with self.subTest(workflow=path.name, step=step.get("name", index), pattern=pattern):
                        self.assertIsNone(re.search(pattern, run))

    def test_only_the_release_action_sets_a_tag_name(self):
        for path in sorted(WORKFLOWS.glob("*.y*ml")):
            for step in steps(load(path)):
                if "tag_name" in step.get("with", {}):
                    with self.subTest(workflow=path.name, step=step.get("name")):
                        self.assertTrue(step["uses"].startswith("softprops/action-gh-release@"))

    def test_the_patterns_catch_what_they_forbid(self):
        for command in ("git tag 3.0.0", "git push origin --tags", "git push origin :refs/tags/3.0.0",
                        "git push --delete origin 3.0.0", "gh release delete 3.0.0", "gh release create 3.0.0",
                        "gh api -X DELETE repos/o/r/git/refs/tags/3.0.0"):
            with self.subTest(command):
                self.assertTrue(any(re.search(pattern, command) for pattern in FORBIDDEN))
        self.assertFalse(any(re.search(pattern, "git push origin HEAD") for pattern in FORBIDDEN))


class ActionPinTests(unittest.TestCase):
    """Owner decision: every action is pinned to its major version tag (`@v8`), never a commit hash."""

    def test_every_action_is_pinned_to_a_major_version(self):
        for path in sorted(WORKFLOWS.glob("*.y*ml")):
            for ref in re.findall(r"(?m)^\s*-?\s*uses:\s*(\S+)", path.read_text(encoding="utf-8")):
                if ref.startswith("./"):
                    continue
                with self.subTest(workflow=path.name, uses=ref):
                    self.assertRegex(ref, r"^[\w.-]+/[\w./-]+@v\d+$")

    def test_the_snapshot_gate_allows_the_versions_the_workflows_use(self):
        """A version bump that misses the snapshot gate's own allow-list stops the gate before it records anything
        (run 43284991580: download-artifact went to v8 in the workflows while the list still named v7)."""
        gate_tests = ROOT / "Scripts/visual/test_snapshot_gate.py"
        allowed = next(
            ast.literal_eval(node.value)
            for node in ast.parse(gate_tests.read_text(encoding="utf-8")).body
            if isinstance(node, ast.Assign) and any(getattr(t, "id", None) == "ALLOWED_ACTIONS" for t in node.targets)
        )
        used = set()
        for path in sorted(WORKFLOWS.glob("*.y*ml")):
            used.update(
                ref for ref in re.findall(r"(?m)^\s*-?\s*uses:\s*(\S+)", path.read_text(encoding="utf-8"))
                if not ref.startswith("./")
            )
        used_majors = {}
        for ref in used:
            name, _, major = ref.partition("@")
            used_majors.setdefault(name, set()).add(major)
        for entry in allowed:
            name, _, major = entry.partition("@")
            with self.subTest(allowed=entry):
                self.assertIn(name, used_majors, "allowed but used by no workflow")
                self.assertEqual(used_majors[name], {major}, "the workflows use another version")


@unittest.skipUnless(RUBY, "ruby is not installed")
class ScriptTestsTests(unittest.TestCase):
    """lint.yml runs the tests of every script directory on every branch push, found and not listed: a pattern
    list once left 250 tests of Scripts/visual and the 27 of Scripts/live-check running in no workflow."""

    ROOTS = ("Scripts", "actions-tool")

    @classmethod
    def setUpClass(cls):
        cls.lint = load(WORKFLOWS / "lint.yml")

    def test_every_directory_with_tests_is_found_not_listed(self):
        run = code(step_named(self.lint, "Test the scripts")["run"])
        self.assertIn(f"find {' '.join(self.ROOTS)} -name 'test_*.py' -exec dirname {{}} \\; | sort -u", run)
        self.assertIn("python3 -m unittest discover -s \"$directory\" -p 'test_*.py' || failed=1", run)
        self.assertIn('exit "$failed"', run)

    def test_no_test_file_lies_outside_the_roots_the_step_searches(self):
        listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "test_*.py", "*/test_*.py"],
                                capture_output=True, text=True, check=True).stdout.split()
        self.assertGreater(len(listed), 30)
        for path in listed:
            self.assertIn(path.split("/")[0], self.ROOTS, f"{path} is run by no workflow")

    def test_the_cookie_logging_audit_runs_after_its_own_fixtures(self):
        run = code(step_named(self.lint, "Check that no cookie is logged in the clear")["run"]).split()
        self.assertEqual(run, ["Scripts/Tests/check-cookie-logging-tests.sh", "Scripts/check-cookie-logging.sh"])

    def test_it_runs_on_every_branch_push_like_the_tests(self):
        self.assertEqual(self.lint.get("on", self.lint.get(True, self.lint.get("true"))),
                         {"push": {"branches": ["**"]}, "workflow_dispatch": None})


@unittest.skipUnless(RUBY, "ruby is not installed")
class UITestsWorkflowTests(unittest.TestCase):
    """ui-tests.yml: the UI tests every night and by hand, on the iPhone and the iPad, reporting and blocking
    nothing."""

    @classmethod
    def setUpClass(cls):
        cls.path = WORKFLOWS / "ui-tests.yml"
        cls.document = load(cls.path)
        cls.text = code(cls.path.read_text(encoding="utf-8"))

    def test_it_starts_at_night_by_hand_and_on_its_trial_branch(self):
        triggers = self.document.get("on", self.document.get(True, self.document.get("true")))
        self.assertEqual(set(triggers), {"schedule", "workflow_dispatch", "push"})
        self.assertEqual(len(triggers["schedule"]), 1)
        self.assertRegex(triggers["schedule"][0]["cron"], r"^\d+ \d+ \* \* \*$")
        self.assertEqual(triggers["push"], {"branches": ["ci/ui-tests"]})

    def test_each_device_runs_its_own_plan_and_accounts_for_its_skips(self):
        self.assertEqual(self.document["jobs"]["run"]["strategy"]["matrix"]["include"], [
            {"family": "iphone", "plan": "UITests",
             "accounting": "--elsewhere UITests-iPad.xctestplan --local-only Scripts/ui-tests/local-only.json"},
            {"family": "ipad", "plan": "UITests-iPad", "accounting": "--expect UITests-iPad.xctestplan"},
        ])
        for word in self.document["jobs"]["run"]["strategy"]["matrix"]["include"][0]["accounting"].split():
            if not word.startswith("--"):
                self.assertTrue((ROOT / word).is_file(), word)

    def test_both_plans_are_built_once_and_run_without_building(self):
        build = code(step_named(self.document, "Build for testing")["run"])
        self.assertIn("for plan in UITests UITests-iPad; do", build)
        self.assertIn('-testPlan "$plan"', build)
        run = code(step_named(self.document, "Run the UI tests")["run"])
        self.assertIn("xcodebuild test-without-building", run)
        self.assertIn('-xctestrun "$XCTESTRUN"', run)
        create = code(step_named(self.document, "Create the simulator")["run"])
        self.assertIn('-name "${SCHEME_NAME}_${PLAN}_*.xctestrun"', create)
        # `find` succeeds when it finds nothing, so the step says that the plan's file is missing.
        self.assertIn('[ -n "$xctestrun" ] || {', create)

    def test_nothing_caps_parallel_testing(self):
        # Tests run in parallel unless the owner approved a serial run for the invocation concerned (AGENTS.md).
        for flag in ("-parallel-testing-enabled", "-parallel-testing-worker-count",
                     "-maximum-parallel-testing-workers", "-disable-concurrent-destination-testing"):
            self.assertNotIn(flag, self.text)

    def test_a_lost_run_is_made_once_more_and_a_failed_one_is_not(self):
        run = code(step_named(self.document, "Run the UI tests")["run"])
        self.assertEqual(run.count("attempt 1 || status=$?"), 1)
        self.assertEqual(run.count("attempt 2 || status=$?"), 1)
        self.assertIn('snapshot_infra.py --status "$status" "$RUNNER_TEMP/ui/xcodebuild-1.log"', run)
        self.assertLess(run.index("snapshot_infra.py --status"), run.index("attempt 2 || status=$?"))

    def test_the_report_is_made_after_a_failed_run_too_and_can_fail_the_job(self):
        report = step_named(self.document, "Report")
        self.assertIn("always()", report["if"])
        run = code(report["run"])
        self.assertIn("python3 Scripts/ui-tests/report.py", run)
        # The summary's copy ends the pipeline, and a pipeline's status is its last command's unless told otherwise.
        self.assertLess(run.index("set -euo pipefail"), run.index('| tee -a "$GITHUB_STEP_SUMMARY"'))
        self.assertNotIn("|| true", run)
        self.assertNotIn("continue-on-error", self.text)

    def test_it_reads_the_repository_and_nothing_else(self):
        self.assertEqual(self.document["permissions"], {})
        for name, job in self.document["jobs"].items():
            with self.subTest(job=name):
                self.assertEqual(job["permissions"], {"contents": "read"})
        self.assertNotIn("secrets.", self.text)

    def test_no_other_workflow_waits_for_it(self):
        for path in sorted(WORKFLOWS.glob("*.y*ml")):
            if path.name != "ui-tests.yml":
                with self.subTest(workflow=path.name):
                    self.assertNotIn("ui-tests.yml", code(path.read_text(encoding="utf-8")))


@unittest.skipUnless(RUBY, "ruby is not installed")
class DependencyChangesTests(unittest.TestCase):
    """dependencies.yml writes what changed between the lockfiles into its pull request's body
    (actions-tool/dependency_changes.py)."""

    @classmethod
    def setUpClass(cls):
        cls.document = load(WORKFLOWS / "dependencies.yml")
        cls.steps = steps(cls.document)
        cls.describe = step_named(cls.document, "Describe what changed")
        cls.run_lines = code(cls.describe["run"])

    def test_the_body_compares_the_base_lockfile_with_the_resolved_one(self):
        self.assertIn('git show HEAD:AppPackage/Package.resolved > "$RUNNER_TEMP/Package.resolved.before"',
                      self.run_lines)
        self.assertIn('python3 actions-tool/dependency_changes.py --xcode "$(xcodebuild -version)"', self.run_lines)
        self.assertIn('"$RUNNER_TEMP/Package.resolved.before" AppPackage/Package.resolved', self.run_lines)
        self.assertTrue((ROOT / "actions-tool" / "dependency_changes.py").is_file())

    def test_a_tool_that_fails_fails_the_step(self):
        # The body is piped into its file, and a pipeline's status is its last command's unless told otherwise.
        self.assertLess(self.run_lines.index("set -euo pipefail"), self.run_lines.index("| tee"))

    def test_the_body_is_written_outside_the_checkout(self):
        # create-pull-request commits every file it finds in the checkout.
        written = re.findall(r'(?:>|tee) "([^"]+)"', self.run_lines)
        self.assertEqual(len(written), 2)
        for path in written:
            self.assertTrue(path.startswith("$RUNNER_TEMP/"), path)

    def test_the_pull_request_takes_that_body(self):
        create = [step for step in self.steps if step.get("uses", "").startswith("peter-evans/create-pull-request@")]
        self.assertEqual(len(create), 1)
        self.assertEqual(create[0]["with"]["body-path"], "${{ runner.temp }}/dependency-changes.md")
        self.assertNotIn("body", create[0]["with"])
        self.assertIn('| tee "$RUNNER_TEMP/dependency-changes.md"', self.run_lines)
        # Written when, and only when, the pull request is made, and before it.
        self.assertEqual(self.describe["if"], create[0]["if"])
        self.assertLess(self.steps.index(self.describe), self.steps.index(create[0]))


class NoTestRetryTests(unittest.TestCase):
    """No workflow runs a test a second time. A test that passes on its retry is a flaky test, and the retry hides
    it: until 2026-11-16 the UI test plans ran a failing test up to three times and the screenshot check's policy
    job twice, and three of that job's four passing runs passed by it. The plans' side of this is
    Scripts/ui-tests/test_report.py."""

    FLAGS = ("-retry-tests-on-failure", "-test-iterations", "-run-tests-until-failure", "-test-repetition")

    def test_no_workflow_passes_a_repetition_flag(self):
        paths = sorted(WORKFLOWS.glob("*.y*ml"))
        self.assertGreater(len(paths), 5)
        for path in paths:
            text = code(path.read_text(encoding="utf-8"))
            for flag in self.FLAGS:
                with self.subTest(workflow=path.name, flag=flag):
                    self.assertNotIn(flag, text)

    def test_the_scripts_the_workflows_run_pass_none_either(self):
        scripts = [path for folder in ("Scripts", "actions-tool") for path in sorted((ROOT / folder).rglob("*.sh"))]
        self.assertGreater(len(scripts), 3)
        for path in scripts:
            text = code(path.read_text(encoding="utf-8"))
            for flag in self.FLAGS:
                with self.subTest(script=path.name, flag=flag):
                    self.assertNotIn(flag, text)


if __name__ == "__main__":
    unittest.main()
