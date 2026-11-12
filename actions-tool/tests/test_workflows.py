"""The release workflows' shape: the steps a release relies on stay in place (Phase 20 D-03, D-19; REL-18-01), and
the AltStore PAL submit job's (20-04; D-07, D-21, D-26) and publish job's (20-05).

YAML is read through Ruby's standard library (`ruby -ryaml -rjson`), because PyYAML is not installed on the
machines that run these tests. YAML 1.1 reads the `on:` key as `true`; only the PAL tests read triggers.
"""

import json
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
# `softprops/action-gh-release` creates from `tag_name`.
FORBIDDEN = [
    r"\bgit\s+tag\b",
    r"\bgit\s+push\b[^\n]*--tags\b",
    r"\bgit\s+push\b[^\n]*\s:refs/tags",
    r"\bgit\s+push\b[^\n]*--delete\b",
    r"\bgh\s+release\s+(delete|create|edit)\b",
    r"\bgh\s+api\b[^\n]*git/refs/tags",
]


# Phase 19's screenshot check is OFF in the release workflows for 3.0 (owner msg 3757): none of deploy.yml,
# deploy-beta.yml and deploy-pal.yml calls snapshot-gate.yml or reads the `aggregate` check. The workflow and
# actions-tool/require-snapshot-gate.sh stay in the repository (pull requests and manual dispatch still use them).
GATE_CHECK = "aggregate"
GATE_SCRIPT = "./actions-tool/require-snapshot-gate.sh"
RELEASE_WORKFLOWS = ("deploy.yml", "deploy-beta.yml", "deploy-pal.yml")
GATE_MENTIONS = ("snapshot-gate.yml", "require-snapshot-gate", "REQUIRE_SNAPSHOT_GATE", "SNAPSHOT_GATE_CHECK",
                 "Require the screenshot check")


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
        cls.env = cls.deploy.get("env", {})

    def run_text(self, name):
        return expand(code(step_named(self.deploy, name).get("run", "")), self.env)

    def test_the_build_number_is_checked_before_the_build(self):
        self.assertLess(step_index(self.deploy, "Check build number"), step_index(self.deploy, "Xcode archive"))

    def test_it_is_only_ever_started_by_hand(self):
        # Owner msg 4611: merging a pull request or pushing to main never releases; the release
        # is started by hand on main. Owner msg 4620: nothing is typed in; everything comes from the notes file.
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
        guard = step_named(self.deploy, "Refuse to run off main")
        self.assertEqual(step_index(self.deploy, "Refuse to run off main"), 0)
        self.assertEqual(guard["env"], {"REF_TYPE": "${{ github.ref_type }}", "REF_NAME": "${{ github.ref_name }}"})
        run = guard["run"]
        self.assertIn('"$REF_TYPE" != "branch"', run)
        self.assertIn('"$REF_NAME" != "main"', run)
        self.assertEqual(run.count("::error::"), 2)
        self.assertEqual(run.count("exit 1"), 2)

    def test_the_release_is_named_by_the_notes_files_title(self):
        self.assertIn('title="$(python3 "./actions-tool/release_notes.py" title "$notes_path")"', self.run_text("Retrieve data"))
        self.assertIn('echo "title=$title"', self.run_text("Retrieve data"))
        release = step_named(self.deploy, "Release to GitHub")
        self.assertEqual(release["with"]["name"], "${{ steps.retrieve-data.outputs.title }}")
        validate = step_named(self.deploy, "Validate data")
        self.assertEqual(validate["env"]["RELEASE_TITLE"], "${{ steps.retrieve-data.outputs.title }}")
        self.assertIn('[[ ! -z "$RELEASE_TITLE" ]] || exit 1', validate["run"])

    def test_the_sources_are_pushed_to_main_with_the_deploy_key(self):
        # Main's rule lets only deploy keys past, and GitHub refuses GitHub Actions on that list, so the checkout
        # carries the repository's deploy key and the source commit is pushed with it.
        checkout = step_named(self.deploy, "Checkout")
        self.assertEqual(checkout["with"], {"ssh-key": "${{ secrets.DEPLOY_KEY }}"})
        self.assertEqual(self.run_text("Commit update AltStore.json and SideStore.json").splitlines()[-1].strip(),
                         "git push origin HEAD")

    def test_the_screenshot_gate_is_off_for_3_0(self):
        # Owner msg 3757: the release no longer waits for, or reads, the screenshot check.
        self.assertEqual(list(self.deploy["jobs"]), ["Deploy"])
        job = self.deploy["jobs"]["Deploy"]
        self.assertNotIn("needs", job)
        self.assertNotIn("uses", job)
        self.assertEqual([step.get("name") for step in job["steps"]][:2], ["Refuse to run off main", "Checkout"])
        self.assertNotIn("Require the screenshot check", [step.get("name") for step in job["steps"]])
        for name in ("SNAPSHOT_GATE_CHECK", "REQUIRE_SNAPSHOT_GATE_SCRIPT_PATH"):
            self.assertNotIn(name, self.env)
        # Only what the release itself needs.
        self.assertEqual(job["permissions"], {"contents": "write"})
        self.assertLess(step_index(self.deploy, "Check build number"), step_index(self.deploy, "Check release notes"))

    def test_the_build_number_check_reads_mains_classic_side_sources(self):
        run = self.run_text("Check build number")
        self.assertIn("actions-tool/check-build-number.sh", run)
        self.assertRegex(run, r"git fetch --no-tags --depth 1 origin main")
        self.assertIn("FETCH_HEAD", run)
        for source in ("AltStore.json", "SideStore.json", "altstore-beta.json"):
            with self.subTest(source):
                self.assertIn(f"./{source}", run)
        self.assertIn("CURRENT_PROJECT_VERSION", run)

    def test_the_build_number_check_ignores_the_pal_source(self):
        # The PAL build is versioned by App Store Connect's own rules and checked in its own job.
        self.assertNotIn("AltStorePAL", self.run_text("Check build number"))

    def test_the_release_posts_end_with_the_release_url(self):
        # Owner msg 4459: Telegram and Discord end with the GitHub release link. A release whose notes
        # carry another link (3.0.0 ends with https://ehpanda.app, owner msg 4453) carries it in its notes file.
        self.assertNotIn("WEBSITE_URL", self.env)
        step = step_named(self.deploy, "Post release notes")
        self.assertEqual(step["env"]["RELEASE_URL"], "${{ steps.release.outputs.url }}")
        run = code(step["run"])
        self.assertIn('telegram "$RELEASE_NOTES_PATH" "$RELEASE_URL"', run)
        self.assertIn('discord "$RELEASE_NOTES_PATH" "$RELEASE_URL"', run)

    def test_the_release_notes_are_checked(self):
        self.assertIn("actions-tool/release_notes.py\" check", self.run_text("Check release notes"))
        self.assertIn("release_notes.py\" check", self.run_text("Retrieve data"))

    def test_the_sources_point_at_the_releases_own_assets(self):
        update = step_named(self.deploy, "Update AltStore.json and SideStore.json")
        self.assertEqual(update["env"]["RELEASE_ASSETS"], "${{ steps.release.outputs.assets }}")
        run = expand(update["run"], self.env)
        self.assertIn(".browser_download_url", run)
        self.assertIn('curl -sSfIL -o /dev/null "$download_url"', update["run"])

    def test_the_sources_list_the_permissions_of_the_ipa(self):
        # AltStore refuses an install whose IPA asks for permissions the source does not list: both lists come from
        # the build (usage descriptions replace the old ones in the filter; entitlements are read from the app).
        update = step_named(self.deploy, "Update AltStore.json and SideStore.json")
        run = expand(update["run"], self.env)
        self.assertIn('entitlements="$(bash "./actions-tool/ipa-entitlements.sh" "/tmp/action-builds/Payload/EhPanda.app")"', run)
        self.assertIn('--argjson entitlements "$entitlements"', run)
        self.assertIn('--argjson privacy "$RELEASE_PRIVACY"', run)
        # The one call serves both sources.
        self.assertEqual(run.count("--argjson entitlements"), 1)
        self.assertIn("add_version", run)

    def test_the_sources_keep_their_history(self):
        update = step_named(self.deploy, "Update AltStore.json and SideStore.json")
        run = expand(update["run"], self.env)
        self.assertIn("--argjson releaseVersions null", run)
        self.assertIn('-f "./actions-tool/altstore-add-version.jq"', run)
        self.assertIn("(.apps[0].versions | length) >= 1", run)

    def test_the_release_step_is_the_only_tag_maker(self):
        release = step_named(self.deploy, "Release to GitHub")
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
        # The beta's own source is the checkout's ./altstore-beta.json, next to main's AltStore.json.
        self.assertRegex(run, r"git fetch --no-tags --depth 1 origin main")
        self.assertIn("./AltStore.json", run)
        self.assertIn('cp "./altstore-beta.json"', run)
        self.assertNotIn("altstore-beta branch", run)
        self.assertNotIn("ls-remote", run)

    def test_the_beta_workflow_has_no_orphan_branch_left(self):
        text = (WORKFLOWS / "deploy-beta.yml").read_text(encoding="utf-8")
        for gone in ("BETA_SOURCE_BRANCH", "git worktree", "switch --orphan", "ls-remote", "altstore-beta/altstore-beta.json"):
            with self.subTest(gone):
                self.assertNotIn(gone, text)
        self.assertIn("EhPanda/main/altstore-beta.json", text)

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
        self.assertIn('git commit -m "Update altstore-beta.json"', run)
        self.assertIn('git add -- "./altstore-beta.json"', run.replace("${ALTSTORE_BETA_JSON_PATH#./}", "./altstore-beta.json"))
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
        return step_named(beta, "Update altstore-beta.json on the dispatched branch"), beta.get("env", {})

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
        self.assertIn('beta_json="$PWD/./altstore-beta.json"', run)
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
    """Owner msg 4070: a release neither runs the test suite nor waits for the Test workflow. Tests are test.yml's
    job, on every branch push; a release is built from a commit the owner has already seen pass."""

    # workflow file -> its release job
    RELEASES = {"deploy.yml": "Deploy", "deploy-beta.yml": "Deploy", "deploy-pal.yml": "submit"}
    PERMISSIONS = {"deploy.yml": {"contents": "write"}, "deploy-beta.yml": {"contents": "write"},
                   "deploy-pal.yml": {"contents": "read"}}

    def test_no_release_runs_tests_or_waits_on_them(self):
        for name in self.RELEASES:
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
        for name, job_name in self.RELEASES.items():
            with self.subTest(workflow=name):
                self.assertEqual(load(WORKFLOWS / name)["jobs"][job_name]["permissions"], self.PERMISSIONS[name])

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


PAL_STEPS = [
    "Checkout",
    "Check version",
    "Write App Store Connect key",
    "Check build number",
    "Install iOS 27 Platform",
    "Show Xcode version",
    "Set up signing",
    "Xcode archive",
    "Verify analytics credentials",
    "Verify marketplace build",
    "Export and upload",
    "Wait for the build",
    "Ensure the notarization version",
    "Attach the build",
    "Submit for notarization",
    "Upload the call record",
    "Tear down signing",
]
PAL_SECRETS = ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8", "DIST_CERT_P12", "DIST_CERT_PASSWORD", "PROFILE_APP",
               "PROFILE_SHARE_EXTENSION", "TEAM_ID"]
PAL_VARIABLES = ["PAL_MARKETPLACE_ID", "ASC_KEY_ROLE"]


@unittest.skipUnless(RUBY, "ruby is not installed")
class PalWorkflowTests(unittest.TestCase):
    """`deploy-pal.yml`'s submit job (20-04; D-07, D-21, D-26). It is dispatched by hand only: the first live run is
    20-08, after the Classic release, with the owner's OK at the time."""

    @classmethod
    def setUpClass(cls):
        cls.path = WORKFLOWS / "deploy-pal.yml"
        cls.text = cls.path.read_text(encoding="utf-8")
        cls.pal = load(cls.path)
        cls.env = cls.pal.get("env", {})
        cls.job = cls.pal["jobs"]["submit"]

    def run_text(self, name):
        return expand(code(step_named(self.job, name).get("run", "")), {**self.env, **self.job.get("env", {})})

    def test_it_is_only_ever_dispatched_by_hand(self):
        # YAML 1.1 reads the `on` key as true.
        triggers = self.pal.get("on", self.pal.get("true"))
        self.assertEqual(list(triggers), ["workflow_dispatch"])
        inputs = triggers["workflow_dispatch"]["inputs"]
        self.assertEqual(set(inputs), {"version", "mode", "dry_run"})
        self.assertTrue(inputs["version"]["required"])
        self.assertEqual(inputs["mode"]["type"], "choice")
        self.assertEqual(inputs["mode"]["options"], ["submit", "publish"])
        # A live publish is always a deliberate choice.
        self.assertEqual(inputs["dry_run"]["type"], "boolean")
        self.assertIs(inputs["dry_run"]["default"], True)
        self.assertEqual(set(self.pal["jobs"]), {"submit", "publish"})
        for word in ("push:", "pull_request", "schedule:", "release:", "workflow_run", "tags:"):
            with self.subTest(word=word):
                self.assertNotIn(word, code(self.text))

    def test_the_submit_job_runs_in_the_protected_environment(self):
        environment = self.job["environment"]
        name = environment["name"] if isinstance(environment, dict) else environment
        self.assertEqual(name, "pal-notarization")
        self.assertEqual(self.job["if"].replace(" ", ""), "inputs.mode=='submit'")
        self.assertEqual(self.job["permissions"], {"contents": "read"})
        self.assertIn("timeout-minutes", self.job)

    def test_the_steps_run_in_order(self):
        names = [step.get("name") for step in self.job["steps"]]
        self.assertEqual(names, PAL_STEPS)

    def test_the_screenshot_gate_is_off_for_3_0(self):
        # Owner msg 3757: the submission no longer reads the screenshot check on the dispatched commit.
        names = [step.get("name") for step in self.job["steps"]]
        self.assertEqual(names[0], "Checkout")
        self.assertNotIn("Require the screenshot check", names)
        self.assertNotIn("needs", self.job)
        for name in ("SNAPSHOT_GATE_CHECK", "REQUIRE_SNAPSHOT_GATE_SCRIPT_PATH"):
            self.assertNotIn(name, self.env)

    def test_the_checkout_cannot_push(self):
        checkout = step_named(self.job, "Checkout")
        self.assertTrue(checkout["uses"].startswith("actions/checkout@"))
        self.assertIs(checkout["with"]["persist-credentials"], False)

    def test_the_version_must_be_the_projects(self):
        run = self.run_text("Check version")
        self.assertIn("MARKETING_VERSION", run)
        self.assertIn("EhPanda.xcodeproj/project.pbxproj", run)
        self.assertEqual(self.job["env"]["VERSION"], "${{ inputs.version }}")

    def test_the_build_number_is_checked_against_the_pal_source_and_app_store_connect(self):
        run = self.run_text("Check build number")
        self.assertRegex(run, r"git fetch --no-tags --depth 1 origin main")
        self.assertIn("FETCH_HEAD", run)
        self.assertIn("./AltStorePAL.json", run)
        self.assertIn("actions-tool/check-build-number.sh", run)
        self.assertIn("actions-tool/asc.py\" check-build", run)
        self.assertIn("CURRENT_PROJECT_VERSION", run)
        # D-26: the PAL build carries the Classic release's build number, so the Classic sources are not compared.
        for source in ("./AltStore.json", "./SideStore.json", "./altstore-beta.json"):
            with self.subTest(source=source):
                self.assertNotIn(source, run)

    def test_the_build_number_is_checked_before_the_build(self):
        self.assertLess(step_index(self.job, "Check build number"), step_index(self.job, "Xcode archive"))

    def test_the_archive_is_signed_with_the_generated_xcconfig(self):
        run = self.run_text("Xcode archive")
        self.assertIn("xcodebuild archive", run)
        self.assertIn('-xcconfig "$MARKETPLACE_XCCONFIG"', run)
        self.assertNotIn("CODE_SIGNING_ALLOWED=NO", run)
        self.assertNotIn("Config/Marketplace.xcconfig", run)
        self.assertIn("marketplace-signing.sh\" setup", self.run_text("Set up signing"))

    def test_nothing_asks_xcode_to_make_signing_records(self):
        # D-07: no automatic signing, so Xcode never creates or downloads a profile, certificate or App ID.
        self.assertNotIn("allowProvisioningUpdates", self.text)
        self.assertNotIn("allowProvisioningUpdates", (ROOT / "actions-tool" / "marketplace-signing.sh").read_text())

    def test_the_marketplace_build_is_verified_before_upload(self):
        run = self.run_text("Verify marketplace build")
        for needle in ("app.ehpanda.marketplace", ".ShareExtension", "CFBundleDisplayName", "EhPanda",
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

    def test_the_submission_goes_through_the_client(self):
        for name, command in (("Wait for the build", "wait-build"), ("Ensure the notarization version", "ensure-version"),
                              ("Attach the build", "attach-build"), ("Submit for notarization", "submit")):
            with self.subTest(step=name):
                self.assertIn(f"actions-tool/asc.py\" {command}", self.run_text(name))
        self.assertIn("NOTARIZATION", self.text)
        self.assertIn("reviewType", self.text)

    def test_the_call_record_is_kept_even_when_a_step_fails(self):
        upload = step_named(self.job, "Upload the call record")
        self.assertTrue(upload["uses"].startswith("actions/upload-artifact@"))
        self.assertEqual(upload["if"], "always()")
        self.assertIn("asc-calls.jsonl", upload["with"]["path"])
        self.assertIn("asc-calls.jsonl", self.run_text("Write App Store Connect key"))

    def test_the_signing_material_is_always_removed(self):
        teardown = step_named(self.job, "Tear down signing")
        self.assertEqual(teardown["if"], "always()")
        self.assertIn("marketplace-signing.sh\" teardown", self.run_text("Tear down signing"))
        self.assertEqual(self.job["steps"][-1]["name"], "Tear down signing")

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

    def test_the_tests_and_checks_see_no_signing_secret(self):
        for name in ("Check version", "Install iOS 27 Platform", "Verify analytics credentials"):
            with self.subTest(step=name):
                self.assertNotIn("secrets.", json.dumps(step_named(self.job, name).get("env", {})))

    def test_the_header_lists_every_secret_and_variable(self):
        header = "\n".join(line for line in self.text.splitlines() if line.startswith("#"))
        used = set(re.findall(r"\$\{\{\s*(?:secrets|vars)\.(\w+)", self.text)) - {"GITHUB_TOKEN"}
        for name in set(PAL_SECRETS) | set(PAL_VARIABLES) | used:
            with self.subTest(name=name):
                self.assertIn(name, header)
        self.assertTrue(set(PAL_SECRETS) <= used)
        self.assertIn("pal-notarization", header)
        self.assertIn("D-07", header)
        self.assertIn("D-26", header)


PAL_PUBLISH_STEPS = [
    "Checkout",
    "Modify git config",
    "Check version",
    "Write App Store Connect key",
    "Read the ADP ID",
    "Ask AltStore to process the ADP",
    "Fetch the ADP",
    "Publish to AltStore PAL",
    "Upload the call record",
    "Remove the API key",
]


@unittest.skipUnless(RUBY, "ruby is not installed")
class PalPublishWorkflowTests(unittest.TestCase):
    """`deploy-pal.yml`'s publish job (20-05; D-19, D-21): ADP ID, AltStore processing, the unchanged ADP as release
    assets and the PAL source on `main`. Its first live run is 20-08, as a dry run first."""

    @classmethod
    def setUpClass(cls):
        cls.path = WORKFLOWS / "deploy-pal.yml"
        cls.text = cls.path.read_text(encoding="utf-8")
        cls.pal = load(cls.path)
        cls.env = cls.pal.get("env", {})
        cls.job = cls.pal["jobs"]["publish"]

    def run_text(self, name):
        # The workflow's paths are put in; the job's $VERSION and $ASC_APP_ID are kept, as the shell sees them.
        return expand(code(step_named(self.job, name).get("run", "")), self.env)

    def test_the_publish_job_runs_in_the_protected_environment(self):
        environment = self.job["environment"]
        name = environment["name"] if isinstance(environment, dict) else environment
        self.assertEqual(name, "pal-notarization")
        self.assertEqual(self.job["if"].replace(" ", ""), "inputs.mode=='publish'")
        self.assertEqual(self.job["permissions"], {"contents": "write"})
        self.assertIn("timeout-minutes", self.job)
        self.assertNotIn("needs", self.job)

    def test_the_steps_run_in_order(self):
        self.assertEqual([step.get("name") for step in self.job["steps"]], PAL_PUBLISH_STEPS)

    def test_the_version_and_notes_are_checked_first(self):
        run = self.run_text("Check version")
        self.assertIn("[0-9]+", run)
        self.assertIn("PAL_MARKETPLACE_ID", run)
        self.assertIn("actions-tool/release_notes.py\" check", run)
        self.assertEqual(self.job["env"]["VERSION"], "${{ inputs.version }}")
        self.assertEqual(self.job["env"]["ASC_APP_ID"], "${{ vars.PAL_MARKETPLACE_ID }}")

    def test_the_adp_id_comes_from_app_store_connect(self):
        run = self.run_text("Read the ADP ID")
        self.assertIn('actions-tool/asc.py" adp-id --app "$ASC_APP_ID" --version "$VERSION"', run)
        self.assertIn("GITHUB_OUTPUT", run)
        self.assertIn("asc-calls.jsonl", self.run_text("Write App Store Connect key"))

    def test_altstore_processes_then_the_adp_is_fetched_and_published(self):
        self.assertIn('actions-tool/pal_publish.py" process --adp-id "$ADP_ID"',
                      self.run_text("Ask AltStore to process the ADP"))
        fetch = self.run_text("Fetch the ADP")
        self.assertIn('actions-tool/pal_publish.py" fetch --adp-id "$ADP_ID"', fetch)
        self.assertIn("--timeout", fetch)
        publish = self.run_text("Publish to AltStore PAL")
        self.assertIn('actions-tool/pal_publish.py" publish', publish)
        for needle in ('--version "$VERSION"', '--repo "$GITHUB_REPOSITORY"', '--marketplace-id "$ASC_APP_ID"',
                       "ReleaseNotes/", "--dry-run"):
            with self.subTest(needle=needle):
                self.assertIn(needle, publish)

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
                for needle in ("xcodebuild", "setup", "check-build", "wait-build", "ensure-version",
                               "attach-build", " submit", "package-channel.sh"):
                    self.assertNotIn(needle, expand(run, self.env))
                self.assertNotRegex(run, r"\bgit\s+(tag|push)\b")
                self.assertNotRegex(run, r"\bgh\s+release\b")
                self.assertNotIn("action-gh-release", step.get("uses", ""))
        for name in ("DIST_CERT_P12", "DIST_CERT_PASSWORD", "PROFILE_APP", "PROFILE_SHARE_EXTENSION", "TEAM_ID"):
            with self.subTest(secret=name):
                self.assertNotIn(name, json.dumps(self.job))

    def test_the_call_record_is_kept_and_the_key_removed(self):
        upload = step_named(self.job, "Upload the call record")
        self.assertEqual(upload["if"], "always()")
        self.assertIn("asc-calls.jsonl", upload["with"]["path"])
        self.assertIn("publish", upload["with"]["name"])
        teardown = step_named(self.job, "Remove the API key")
        self.assertEqual(teardown["if"], "always()")
        self.assertIn('marketplace-signing.sh" teardown', self.run_text("Remove the API key"))
        self.assertEqual(self.job["steps"][-1]["name"], "Remove the API key")

    def test_secrets_reach_steps_only_through_env(self):
        for step in self.job["steps"]:
            with self.subTest(step=step.get("name")):
                self.assertNotIn("secrets.", step.get("run", ""))
                self.assertNotRegex(step.get("run", ""), r"set -[a-z]*x")
        self.assertNotIn("secrets.", json.dumps(self.job.get("env", {})))


@unittest.skipUnless(RUBY, "ruby is not installed")
class GateOffTests(unittest.TestCase):
    """Phase 19's screenshot check is off in every release workflow for 3.0 (owner msg 3757), and stays available."""

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
                    self.assertNotIn("uses", job)
                    self.assertNotIn("needs", job)
                    for step in job.get("steps", []):
                        self.assertNotIn("require-snapshot-gate", step.get("run", ""))

    def test_each_removal_site_says_why(self):
        for workflow in RELEASE_WORKFLOWS:
            with self.subTest(workflow=workflow):
                self.assertIn("Snapshot gate off for 3.0 (owner msg 3757)",
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
    """Owner msg 4659: every action is pinned to its major version tag (`@v8`), never a commit hash."""

    def test_every_action_is_pinned_to_a_major_version(self):
        for path in sorted(WORKFLOWS.glob("*.y*ml")):
            for ref in re.findall(r"(?m)^\s*-?\s*uses:\s*(\S+)", path.read_text(encoding="utf-8")):
                if ref.startswith("./"):
                    continue
                with self.subTest(workflow=path.name, uses=ref):
                    self.assertRegex(ref, r"^[\w.-]+/[\w./-]+@v\d+$")


if __name__ == "__main__":
    unittest.main()
