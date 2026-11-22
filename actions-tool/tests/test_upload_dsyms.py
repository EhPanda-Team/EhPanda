"""`upload-dsyms.sh`: the release workflows upload each archive's dSYMs to Sentry with a pinned sentry-cli
(quick task 261123-3wz). The tests run offline and on any host: `curl` and `uname` are stand-ins, so nothing
reaches the network and the host's operating system and architecture do not matter. The live check of the pinned
digests against the real asset is a manual step recorded with the task."""

import os
import pathlib
import re
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "upload-dsyms.sh"
TOKEN = "tok-3wz-0123456789abcdef-distinctive"

# Logs every call's arguments to $FAKE_CURL_LOG, fails like `curl --fail` on an HTTP error when $FAKE_CURL_FAIL is
# set, and otherwise writes the bytes of $FAKE_CURL_BODY to the path given after `--output`.
FAKE_CURL = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$FAKE_CURL_LOG"
if [[ -n "${FAKE_CURL_FAIL:-}" ]]; then
  echo "curl: (22) The requested URL returned error: 404" >&2
  exit 22
fi
while (( $# > 0 )); do
  if [[ "$1" == "--output" ]]; then
    cp "$FAKE_CURL_BODY" "$2"
  fi
  shift
done
"""

# Prints Darwin for `-s` and $FAKE_UNAME_M for `-m`.
FAKE_UNAME = """#!/usr/bin/env bash
case "$1" in
  -s) echo "${FAKE_UNAME_S:-Darwin}" ;;
  -m) echo "$FAKE_UNAME_M" ;;
esac
"""


def code(path):
    """The lines of `path` that are not comments, as in test_workflows.code."""
    return [line for line in path.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")]


def constant(name):
    match = re.search(rf'^{name}="([^"]*)"$', SCRIPT.read_text(encoding="utf-8"), re.MULTILINE)
    assert match, name
    return match.group(1)


class ScriptContractTests(unittest.TestCase):
    def test_the_pinned_version_and_digests_have_the_expected_shape(self):
        self.assertRegex(constant("SENTRY_CLI_VERSION"), r"^\d+\.\d+\.\d+$")
        for name in ("SENTRY_CLI_SHA256_ARM64", "SENTRY_CLI_SHA256_X86_64"):
            with self.subTest(name):
                self.assertRegex(constant(name), r"^[0-9a-f]{64}$")
        self.assertNotEqual(constant("SENTRY_CLI_SHA256_ARM64"), constant("SENTRY_CLI_SHA256_X86_64"))

    def test_nothing_downloaded_is_piped_into_a_shell_or_evaluated(self):
        for line in code(SCRIPT):
            with self.subTest(line):
                self.assertNotRegex(line, r"\|\s*(sudo\s+)?(sh|bash|zsh)\b")
                self.assertNotRegex(line, r"<\(.*\)\s*\|?\s*(sh|bash|zsh)\b|(sh|bash|zsh)\s+<\(")
                self.assertNotRegex(line, r"\beval\b")
                self.assertNotRegex(line, r"\bset\s+-\w*x|\bxtrace\b")
                self.assertNotRegex(line, r"include-sources|--with-sources|\bsources\b")

    def test_the_token_is_never_a_flag_and_only_ever_tested_or_hidden(self):
        for line in code(SCRIPT):
            if "SENTRY_AUTH_TOKEN" not in line:
                continue
            with self.subTest(line):
                self.assertNotIn("--auth-token", line)
                presence_test = re.match(r'\s*\[\[ -n "\$\{SENTRY_AUTH_TOKEN:-\}" \]\] \|\| ', line)
                hide_assignment = re.match(r'\s*local token="\$\{SENTRY_AUTH_TOKEN:-\}" ', line)
                self.assertTrue(presence_test or hide_assignment)
        self.assertNotIn("--auth-token", SCRIPT.read_text(encoding="utf-8"))

    def test_the_download_url_and_the_upload_command_have_the_expected_shape(self):
        lines = code(SCRIPT)
        self.assertTrue(any('https://github.com/getsentry/sentry-cli/releases/download/${SENTRY_CLI_VERSION}/${asset}'
                            in line for line in lines))
        upload = [line for line in lines if "debug-files" in line]
        self.assertEqual(len(upload), 1)
        self.assertLess(upload[0].index("--url"), upload[0].index("debug-files"))
        self.assertIn("--type dsym", " ".join(lines))

    def test_the_output_of_the_tool_passes_through_the_token_filter(self):
        upload = [line for line in code(SCRIPT) if "debug-files" in line]
        self.assertTrue(any("2>&1 | hide_token" in line for line in upload + code(SCRIPT)))

    def test_the_script_can_be_sourced_without_running(self):
        result = subprocess.run(["bash", "-c", f'source "{SCRIPT}"; type hide_token fail main'],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)


class ScriptRunTests(unittest.TestCase):
    """The script run end to end against stand-ins for `curl` and `uname`."""

    def setUp(self):
        self.dir = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(lambda: subprocess.run(["rm", "-rf", str(self.dir)], check=True))
        for name, body in (("curl", FAKE_CURL), ("uname", FAKE_UNAME)):
            path = self.dir / name
            path.write_text(body)
            path.chmod(path.stat().st_mode | stat.S_IXUSR)
        self.curl_log = self.dir / "curl.log"
        self.marker = self.dir / "marker"
        self.body = self.dir / "body"
        self.body.write_text(f"#!/bin/sh\ntouch '{self.marker}'\n")
        self.archive = self.dir / "archive"
        (self.archive / "dSYMs" / "Probe.dSYM").mkdir(parents=True)

    def run_script(self, *arguments, token=TOKEN, arch="arm64", curl_fails=False, drop=()):
        env = {**os.environ, "PATH": f"{self.dir}{os.pathsep}{os.environ['PATH']}",
               "FAKE_CURL_LOG": str(self.curl_log), "FAKE_CURL_BODY": str(self.body), "FAKE_UNAME_M": arch,
               "SENTRY_ORGANIZATION": "example-organization", "SENTRY_PROJECT": "example-project",
               "SENTRY_URL": "https://sentry.invalid"}
        if token is not None:
            env["SENTRY_AUTH_TOKEN"] = token
        else:
            env.pop("SENTRY_AUTH_TOKEN", None)
        if curl_fails:
            env["FAKE_CURL_FAIL"] = "1"
        for name in drop:
            env.pop(name, None)
        result = subprocess.run(["bash", str(SCRIPT), *arguments], capture_output=True, text=True, env=env,
                                check=False)
        # The token never appears in anything the script prints, whatever happened (T-3wz-03).
        self.assertNotIn(TOKEN, result.stdout + result.stderr)
        return result

    def warnings(self, result):
        return [line for line in result.stdout.splitlines() if line.startswith("::warning::")]

    def assert_ci_warns_once(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.warnings(result)), 1, result.stdout)
        self.assertEqual(len(result.stdout.strip().splitlines()), 1, result.stdout)
        self.assertIn("--reupload", self.warnings(result)[0])

    def assert_reupload_errors(self, result):
        self.assertNotEqual(result.returncode, 0)
        errors = [line for line in result.stderr.splitlines() if line.startswith("error:")]
        self.assertEqual(len(errors), 1, result.stderr)
        self.assertEqual(self.warnings(result), [])

    def test_a_checksum_mismatch_warns_once_and_runs_nothing_in_ci(self):
        result = self.run_script(str(self.archive))

        self.assert_ci_warns_once(result)
        self.assertIn("pinned SHA-256", result.stdout)
        self.assertFalse(self.marker.exists())

    def test_a_checksum_mismatch_errors_and_runs_nothing_when_reuploading(self):
        result = self.run_script("--reupload", str(self.archive / "dSYMs"))

        self.assert_reupload_errors(result)
        self.assertFalse(self.marker.exists())

    def test_the_download_is_asked_for_over_https_from_the_pinned_release(self):
        self.run_script(str(self.archive))

        calls = self.curl_log.read_text().splitlines()
        self.assertEqual(len(calls), 1)
        self.assertIn("--proto =https", calls[0])
        self.assertIn(f"https://github.com/getsentry/sentry-cli/releases/download/{constant('SENTRY_CLI_VERSION')}/"
                      "sentry-cli-Darwin-arm64", calls[0])

    def test_the_intel_asset_is_chosen_on_x86_64(self):
        self.run_script(str(self.archive), arch="x86_64")

        self.assertIn("sentry-cli-Darwin-x86_64", self.curl_log.read_text())

    def test_a_missing_token_warns_once_in_ci_and_never_downloads(self):
        result = self.run_script(str(self.archive), token=None)

        self.assert_ci_warns_once(result)
        self.assertFalse(self.curl_log.exists())

    def test_every_missing_variable_warns_once_in_ci_and_never_downloads(self):
        for name in ("SENTRY_ORGANIZATION", "SENTRY_PROJECT", "SENTRY_URL"):
            with self.subTest(name):
                result = self.run_script(str(self.archive), drop=(name,))
                self.assert_ci_warns_once(result)
                self.assertIn(name, result.stdout)
                self.assertFalse(self.curl_log.exists())

    def test_a_missing_token_errors_when_reuploading(self):
        result = self.run_script("--reupload", str(self.archive / "dSYMs"), token=None)

        self.assert_reupload_errors(result)

    def test_a_missing_empty_or_dsym_less_folder_warns_once_in_ci(self):
        empty = self.dir / "empty"
        (empty / "dSYMs").mkdir(parents=True)
        other = self.dir / "other"
        (other / "dSYMs" / "notes.txt").parent.mkdir(parents=True)
        (other / "dSYMs" / "notes.txt").write_text("not a dSYM")
        for archive in (self.dir / "missing", empty, other):
            with self.subTest(archive.name):
                result = self.run_script(str(archive))
                self.assert_ci_warns_once(result)
                self.assertFalse(self.curl_log.exists())

    def test_a_failing_download_warns_once_in_ci_and_errors_when_reuploading(self):
        self.assert_ci_warns_once(self.run_script(str(self.archive), curl_fails=True))
        self.assert_reupload_errors(self.run_script("--reupload", str(self.archive / "dSYMs"), curl_fails=True))

    def test_an_unsupported_architecture_warns_once_in_ci(self):
        result = self.run_script(str(self.archive), arch="riscv64")

        self.assert_ci_warns_once(result)
        self.assertFalse(self.curl_log.exists())

    def test_wrong_arguments_warn_once_in_ci(self):
        self.assert_ci_warns_once(self.run_script())
        self.assert_ci_warns_once(self.run_script(str(self.archive), "extra"))

    def test_the_token_never_appears_in_any_output(self):
        # run_script asserts it for every run; this one pins the cases that print the most.
        for arguments, options in (((str(self.archive),), {}),
                                   (("--reupload", str(self.archive / "dSYMs")), {}),
                                   ((str(self.archive),), {"curl_fails": True}),
                                   ((str(self.archive),), {"arch": "riscv64"})):
            with self.subTest(arguments=arguments, options=options):
                result = self.run_script(*arguments, **options)
                self.assertNotIn(TOKEN, result.stdout + result.stderr)


class HideTokenTests(unittest.TestCase):
    def hide(self, text, token):
        env = {**os.environ, "SENTRY_AUTH_TOKEN": token}
        result = subprocess.run(["bash", "-c", f'source "{SCRIPT}"; hide_token'], input=text, capture_output=True,
                                text=True, env=env, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_every_occurrence_of_the_token_is_hidden(self):
        output = self.hide(f"Authorization: Bearer {TOKEN} done\nagain {TOKEN}{TOKEN}\n", TOKEN)

        self.assertEqual(output, "Authorization: Bearer [hidden] done\nagain [hidden][hidden]\n")

    def test_a_last_line_without_a_newline_survives(self):
        self.assertEqual(self.hide(f"first\nlast {TOKEN}", TOKEN), "first\nlast [hidden]")

    def test_an_empty_token_passes_the_text_through_unchanged(self):
        text = "one\ntwo with * and [x] and $HOME\nthree"

        self.assertEqual(self.hide(text, ""), text)

    def test_characters_special_to_patterns_in_the_token_are_taken_literally(self):
        self.assertEqual(self.hide("a*b?c[d] and a*b?c[d]", "a*b?c[d]"), "[hidden] and [hidden]")


if __name__ == "__main__":
    unittest.main()
