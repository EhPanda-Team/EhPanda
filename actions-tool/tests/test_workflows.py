"""The release workflows' shape: the steps a release relies on stay in place (Phase 20 D-03, D-19; REL-18-01), and
the AltStore PAL submit job's (20-04; D-07, D-21, D-26).

YAML is read through Ruby's standard library (`ruby -ryaml -rjson`), because PyYAML is not installed on the
machines that run these tests. YAML 1.1 reads the `on:` key as `true`; only the PAL tests read triggers.
"""

import json
import pathlib
import re
import shutil
import subprocess
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


def load(path):
    result = subprocess.run([RUBY, "-ryaml", "-rjson", "-e", "puts JSON.dump(YAML.load_file(ARGV[0]))", str(path)],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def steps(workflow):
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

    def test_the_build_number_is_checked_before_the_tests(self):
        self.assertLess(step_index(self.deploy, "Check build number"), step_index(self.deploy, "Run tests"))

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

    def test_the_release_notes_are_checked(self):
        self.assertIn("actions-tool/release_notes.py\" check", self.run_text("Check release notes"))
        self.assertIn("release_notes.py\" check", self.run_text("Retrieve data"))

    def test_the_sources_point_at_the_releases_own_assets(self):
        update = step_named(self.deploy, "Update AltStore.json and SideStore.json")
        self.assertEqual(update["env"]["RELEASE_ASSETS"], "${{ steps.release.outputs.assets }}")
        run = expand(update["run"], self.env)
        self.assertIn(".browser_download_url", run)
        self.assertIn('curl -sSfIL -o /dev/null "$download_url"', update["run"])

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
    def test_the_beta_still_checks_its_build_number_before_the_tests(self):
        beta = load(WORKFLOWS / "deploy-beta.yml")
        self.assertLess(step_index(beta, "Check build number"), step_index(beta, "Run tests"))
        run = expand(step_named(beta, "Check build number")["run"], beta.get("env", {}))
        self.assertIn("actions-tool/check-build-number.sh", run)


PAL_STEPS = [
    "Checkout",
    "Check version",
    "Write App Store Connect key",
    "Check build number",
    "Install iOS 27 Platform",
    "Show Xcode version",
    "Run tests",
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
        return expand(code(step_named(self.pal, name).get("run", "")), {**self.env, **self.job.get("env", {})})

    def test_it_is_only_ever_dispatched_by_hand(self):
        # YAML 1.1 reads the `on` key as true.
        triggers = self.pal.get("on", self.pal.get("true"))
        self.assertEqual(list(triggers), ["workflow_dispatch"])
        inputs = triggers["workflow_dispatch"]["inputs"]
        self.assertEqual(set(inputs), {"version", "mode"})
        self.assertTrue(inputs["version"]["required"])
        self.assertEqual(inputs["mode"]["type"], "choice")
        self.assertEqual(inputs["mode"]["options"], ["submit", "publish"])
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

    def test_the_checkout_cannot_push(self):
        checkout = step_named(self.pal, "Checkout")
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

    def test_the_build_number_is_checked_before_the_tests(self):
        self.assertLess(step_index(self.pal, "Check build number"), step_index(self.pal, "Run tests"))

    def test_the_tests_are_the_feature_tests(self):
        run = self.run_text("Run tests")
        self.assertIn("-testPlan FeatureTests", run)

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
        for needle in ("app.ehpanda.marketplace", ".shareExtension", "CFBundleDisplayName", "EhPanda",
                       "ehpanda-marketplace", "EhPandaURLScheme", "EhPandaDistributionChannel", "altstorePAL",
                       "PrivacyInfo.xcprivacy", "codesign --verify --deep --strict", "Authority=Apple Distribution: ",
                       "CFBundleShortVersionString", "get-task-allow", "check-build-number.sh"):
            with self.subTest(needle=needle):
                self.assertIn(needle, run)
        self.assertLess(step_index(self.pal, "Verify marketplace build"), step_index(self.pal, "Export and upload"))

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
        upload = step_named(self.pal, "Upload the call record")
        self.assertTrue(upload["uses"].startswith("actions/upload-artifact@"))
        self.assertEqual(upload["if"], "always()")
        self.assertIn("asc-calls.jsonl", upload["with"]["path"])
        self.assertIn("asc-calls.jsonl", self.run_text("Write App Store Connect key"))

    def test_the_signing_material_is_always_removed(self):
        teardown = step_named(self.pal, "Tear down signing")
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
        for name in ("Check version", "Run tests", "Install iOS 27 Platform", "Verify analytics credentials"):
            with self.subTest(step=name):
                self.assertNotIn("secrets.", json.dumps(step_named(self.pal, name).get("env", {})))

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


if __name__ == "__main__":
    unittest.main()
