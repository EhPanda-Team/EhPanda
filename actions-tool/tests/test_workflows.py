"""The release workflows' shape: the steps a release relies on stay in place (Phase 20 D-03, D-19; REL-18-01).

YAML is read through Ruby's standard library (`ruby -ryaml -rjson`), because PyYAML is not installed on the
machines that run these tests. YAML 1.1 reads the `on:` key as `true`; nothing here reads triggers.
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
        return expand(step_named(self.deploy, name).get("run", ""), self.env)

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


@unittest.skipUnless(RUBY, "ruby is not installed")
class TagOperationTests(unittest.TestCase):
    def test_no_workflow_runs_a_tag_or_release_command(self):
        paths = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
        self.assertTrue(paths)
        for path in paths:
            for index, step in enumerate(steps(load(path))):
                run = step.get("run", "")
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
