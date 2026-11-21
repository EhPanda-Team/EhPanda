---
phase: 261121-jps-split-pal-ci-into-deploy-upload-and-adp-
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/deploy.yml
  - .github/workflows/publish-pal.yml
  - .github/workflows/deploy-pal.yml
  - actions-tool/pal_publish.py
  - actions-tool/tests/test_pal_publish.py
  - actions-tool/tests/test_workflows.py
  - Scripts/visual/test_snapshot_gate.py
  - actions-tool/asc.py
  - actions-tool/tests/test_asc.py
  - Config/Marketplace.xcconfig
  - actions-tool/ExportOptions-marketplace.plist
  - actions-tool/marketplace-signing.sh
  - Scripts/visual/README.md
  - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md
  - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-08-SUBMISSION.md
  - .planning/REQUIREMENTS.md
autonomous: true
requirements: [DIST-18-03]

estimate:
  tokens: 160000
  raw_tokens: 160000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Deploy (dispatched by hand on main) runs its existing Deploy job unchanged, then a second job, AltStorePAL (needs: Deploy, environment pal-notarization, D-07), that archives the marketplace flavor on its own from the same commit, verifies it, uploads it to App Store Connect and stops, with a job summary telling the owner the collaborator now creates the version and submits it (owner items 1)."
    - "The AltStorePAL job calls App Store Connect only through asc.py check-build before archiving; it creates no version, attaches no build and submits nothing, and it still checks the build number against AltStorePAL.json on main, verifies the marketplace build, uploads the call record (D-21) and always tears down the signing material (owner item 1)."
    - "Publish AltStore PAL (.github/workflows/publish-pal.yml) is workflow_dispatch only, runs on main only, takes exactly the inputs adp_id and dry_run (default true), refuses any adp_id that is not a bare UUID before any request, has no environment, reads no App Store Connect secret, and checks out with the DEPLOY_KEY so the push of AltStorePAL.json to main passes main's ruleset (owner items 1, 2)."
    - "pal_publish.py publish takes the version, build, bundle ID and Apple ID from the ADP's manifest.json (no --version), checks <notes-dir>/<version>.md exactly as release_notes.py check does, refuses unless AltStore.json on main lists that version with the manifest's build (D-26), attaches the ADP unchanged to the existing release (D-19) and keeps the marketplace-ID, bundle and project-permission rules; the process command is gone (owner item 3)."
    - "asc.py offers only check-build and its allow-list permits only GET /v1/builds, with the call record unchanged (owner item 4)."
    - "deploy-pal.yml no longer exists and nothing outside .planning names it; every script test directory passes (lint.yml's loop) and actionlint is clean on deploy.yml, deploy-beta.yml and publish-pal.yml (owner items 5, 6)."
    - "20-CONTEXT.md, 20-08-SUBMISSION.md and REQUIREMENTS.md carry dated 2026-11-21 owner-decision amendments for the split and for the D-21 / DIST-18-03 consequence, and DIST-18-03 stays Pending (owner item 7)."
  artifacts:
    - path: ".github/workflows/publish-pal.yml"
      provides: "The dispatch-only ADP publish workflow"
      contains: "name: Publish AltStore PAL"
    - path: ".github/workflows/deploy.yml"
      provides: "The Deploy workflow with the AltStorePAL upload job after the release"
      contains: "needs: Deploy"
    - path: "actions-tool/pal_publish.py"
      provides: "publish driven by the ADP manifest, with the D-26 Classic-release guard"
      contains: "def check_classic_release"
    - path: "actions-tool/asc.py"
      provides: "The App Store Connect client reduced to the build check"
      contains: "COMMANDS = {\"check-build\": check_build}"
    - path: "actions-tool/tests/test_workflows.py"
      provides: "Shape tests for the AltStorePAL job and publish-pal.yml"
      contains: "class PublishWorkflowTests"
  key_links:
    - from: ".github/workflows/deploy.yml"
      to: ".github/workflows/deploy.yml"
      via: "the AltStorePAL job's needs: Deploy, so the PAL upload only follows a successful release"
      pattern: "needs: Deploy"
    - from: ".github/workflows/deploy.yml"
      to: "actions-tool/asc.py"
      via: "the AltStorePAL job's Check build number step runs asc.py check-build before the archive"
      pattern: "check-build"
    - from: ".github/workflows/publish-pal.yml"
      to: "actions-tool/pal_publish.py"
      via: "Fetch the ADP (fetch --adp-id) and Publish to AltStore PAL (publish --notes-dir, no --version)"
      pattern: "--notes-dir"
    - from: ".github/workflows/publish-pal.yml"
      to: "actions-tool/pal_publish.py"
      via: "the checkout's ssh-key: secrets.DEPLOY_KEY carries pal_publish.py's push to HEAD:refs/heads/main"
      pattern: "secrets.DEPLOY_KEY"
    - from: "actions-tool/pal_publish.py"
      to: "actions-tool/pal_publish.py"
      via: "publish calls check_classic_release on main's AltStore.json before any release lookup or upload"
      pattern: "check_classic_release"
---

<objective>
Split the AltStore PAL CI exactly as the owner decided on 2026-11-21 (the task definition's items 1 to 7,
cited below as "owner item N"; locked, do not revisit).

- Upload: `deploy.yml` (Deploy) keeps its `Deploy` job and gains a second job, `AltStorePAL`, that runs after
  the release (`needs: Deploy`) in the GitHub environment `pal-notarization` (D-07: its required reviewer is the
  per-run OK). It builds its own marketplace archive (never the Classic one), verifies it, uploads it to App Store
  Connect and stops. The collaborator creates the version, attaches the build and submits it by hand.
- Publish: a new dispatch-only workflow, `.github/workflows/publish-pal.yml` (name "Publish AltStore PAL"), takes
  only the ADP ID (a bare UUID) and `dry_run`, uses no App Store Connect key and no environment, fetches the ADP
  from AltStore, takes the version and build from its manifest, attaches it unchanged to that version's existing
  GitHub release (D-19) and adds it to `AltStorePAL.json` on `main`, pushing with the repository's deploy key (the
  default token's push is refused by main's ruleset: owner item 2).
- `deploy-pal.yml` is deleted; `pal_publish.py` loses `process` and `--version`, gains `--notes-dir` and the D-26
  guard; `asc.py` keeps only `check-build`; every reference outside `.planning/` is updated; the Phase 20 records
  get dated amendments.

Purpose: the owner releases once (Deploy), the PAL build follows to App Store Connect with one approval, and the
accepted package is published from the one ID the collaborator shares.

Output: three tasks, three signed commits:
1. `ci: upload PAL in Deploy, publish by ADP ID` (Task 1, the tracer: the new shape of both workflows and the
   publish tool, end to end).
2. `pal: trim asc.py and drop deploy-pal mentions` (Task 2).
3. `docs(quick-261121-jps): record the PAL CI split` (Task 3).

Why Task 1 spans seven files: the publish tool's command line and every workflow that calls it change together.
Changing the tool first would leave a commit whose workflow calls flags the tool no longer accepts; moving the
workflows first would do the reverse. So the two workflows, the deletion of `deploy-pal.yml`, the tool and their
tests land in one coherent commit. Task 2 then removes what nothing calls any more and the stale comments.

Out of scope, untouched: everything under `AppPackage/` and `.planning/quick/261121-ifi-make-error-signals-reach-telemetrydeck/`
(another session's work in the main checkout), `.planning/STATE.md` and `.planning/ROADMAP.md` (the quick workflow
updates STATE.md itself), the Deploy job's steps, and the pre-existing actionlint findings in `snapshot-gate.yml`
and `snapshot-measure.yml`.

Execution rule: follow this plan exactly. If any step cannot be done as written (ambiguity, a contradiction with
the source, a test outcome the plan does not foresee, a needed deviation), stop and ask the orchestrator. Do not
choose a workaround. Do not dispatch any workflow, do not push, and do not call App Store Connect, AltStore or the
GitHub API (the tests use local fakes only).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@AGENTS.md
@.github/workflows/deploy.yml
@.github/workflows/deploy-pal.yml
@.github/workflows/lint.yml
@actions-tool/pal_publish.py
@actions-tool/asc.py

- Locked phase decisions cited here (`.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md`):
  D-07 (Apple-account actions only with the owner's OK at the time; the `pal-notarization` reviewer gives it per
  run), D-19 (the ADP goes unchanged onto the version's existing release; no release or tag is ever created),
  D-21 (the call record: which key and role made each App Store Connect call), D-26 (the PAL build carries the
  Classic release's version and build number and ships after it).
- Facts checked while planning (2026-11-21, HEAD `e82010b40`):
  - All script tests pass at HEAD: `actions-tool/tests` 301, `Scripts/visual` 468. `test_workflows.py` 85,
    `test_asc.py` 32, `test_pal_publish.py` 30, `Scripts/visual/test_snapshot_gate.py` 48.
  - `actionlint` is on PATH (Homebrew, 1.7.12); there is no `~/.local/bin/actionlint`. `actionlint` on all of
    `.github/workflows/*.yml` exits 1 at HEAD only because of shellcheck info findings in `snapshot-gate.yml` and
    `snapshot-measure.yml`, which are out of scope; lint exactly the files named in each verify.
  - `ruby`, `jq`, `git` and `openssl` are installed (the workflow tests read YAML through Ruby; the publish tests
    need `jq` and `git`; the asc tests need `openssl`).
  - `git grep -n 'deploy-pal' -- ':!.planning' | wc -l` is 18 at HEAD: `.github/workflows/deploy-pal.yml` 1,
    `Config/Marketplace.xcconfig` 1, `Scripts/visual/README.md` 1, `Scripts/visual/test_snapshot_gate.py` 1,
    `actions-tool/ExportOptions-marketplace.plist` 1, `actions-tool/asc.py` 1, `actions-tool/marketplace-signing.sh` 2,
    `actions-tool/pal_publish.py` 1, `actions-tool/tests/test_pal_publish.py` 1, `actions-tool/tests/test_workflows.py` 8.
  - Every `step_named(self.deploy, ...)` and `step_index(self.deploy, ...)` call in `test_workflows.py` (15, lines
    90 to 249) is inside `DeployWorkflowTests`.
  - The bundle rule ("the bundle must be app.ehpanda.store") is enforced today by `altstore-add-version.jq`
    (`bundle identifier mismatch`) against the PAL template's `app.ehpanda.store`; it is kept as is.
- Writing rules: comments and docstrings in plain, short sentences like the surrounding ones. Reader-facing
  Markdown (`Scripts/visual/README.md`) uses no em dashes. Never write an absolute home path into any file. Never
  write the string `deploy-pal` into any file outside `.planning/` (the old file is only read, then deleted).
- Commits (one per task, from the orchestrator's conventions): the configured git identity and its signing key
  (never bypass signing or hooks), subject of 50 characters or fewer, no attribution or Co-Authored-By lines,
  author and committer dates in +0800. Verify each with `git log -1 --format='%G? %aI %cI'`: `G`, and both dates
  end in `+08:00`. Stage files by explicit path only, and `git rm` for the deleted workflow.
- The executor runs in an isolated worktree. Uncommitted `AppPackage/` changes and
  `.planning/quick/261121-ifi-make-error-signals-reach-telemetrydeck/` in the main checkout belong to another
  session: never touch, stage or commit them.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Upload the PAL build in Deploy and publish it by ADP ID (owner items 1, 2, 3, 6; D-07, D-19, D-21, D-26)</name>
  <files>.github/workflows/deploy.yml, .github/workflows/publish-pal.yml, .github/workflows/deploy-pal.yml, actions-tool/pal_publish.py, actions-tool/tests/test_pal_publish.py, actions-tool/tests/test_workflows.py, Scripts/visual/test_snapshot_gate.py</files>
  <read_first>
    - .github/workflows/deploy-pal.yml (whole: its `submit` job's steps are moved into deploy.yml nearly verbatim, and its header's secret and variable list moves into deploy.yml's header; read it before deleting it)
    - .github/workflows/deploy.yml (whole; the `Deploy` job stays as it is)
    - actions-tool/pal_publish.py (whole), actions-tool/release_notes.py lines 140-160 and 236-277 (`read` is exactly what `release_notes.py check <file>` runs)
    - actions-tool/tests/test_pal_publish.py (whole), actions-tool/tests/fixtures/adp/manifest.json, actions-tool/tests/fixtures/release-notes/9.9.9.md
    - actions-tool/tests/test_workflows.py (whole)
    - Scripts/visual/test_snapshot_gate.py lines 706-731 (`WiringTests`)
    - AltStore.json on HEAD (the shape `apps[0].versions[]` with `version` and `buildVersion`)
  </read_first>
  <behavior>
    - publish with no `--version` uploads the fixture ADP and writes AltStorePAL.json listing 3.0.0 (159), the manifest's version and build.
    - publish refuses before any upload, also with `--dry-run`, when main's AltStore.json lacks 3.0.0, lists 3.0.0 with another build (163), or is missing (D-26).
    - publish refuses before any upload when `<notes-dir>/3.0.0.md` is missing or lacks a language section, naming that file.
    - publish refuses a manifest whose shortVersionString is not x.y.z, and a manifest of another bundle (the filter's bundle identifier mismatch).
    - The publish workflow's "Check the ADP ID" script exits 0 for the example UUID (lower or upper case) and 1, with `::error::`, for an empty value, a URL, padded or truncated IDs and other strings.
    - deploy.yml's jobs are exactly `Deploy` then `AltStorePAL`; the AltStorePAL job calls asc.py only as `check-build`.
  </behavior>
  <action>
Work in this order: (a) the tool and its tests, (b) the publish workflow, (c) deploy.yml, (d) delete the old
workflow, (e) the workflow tests, (f) the screenshot-gate wiring test. Then run the verify and commit.

(a) actions-tool/pal_publish.py (owner item 3)
1. Module docstring. Replace the first paragraph with: "Publishes a notarized AltStore PAL build: the ADP,
   unchanged, as assets of the version's GitHub release, and the version in `AltStorePAL.json` on `main` (Phase 20
   plan 20-05; DIST-18-02, DIST-18-03; D-19, D-26; Research §4, §5). `.github/workflows/publish-pal.yml` runs it
   with the ADP ID the collaborator shares once Apple has accepted the version (owner decision, 2026-11-21)."
   In Usage, delete the `pal_publish.py process --adp-id <id>` entry and its two description lines. Keep both
   `fetch` entries and their description unchanged. Replace the `publish` entry with the usage line
   `pal_publish.py publish --adp <dir> --repo <owner/name> --notes-dir <dir> --marketplace-id <id>`, the
   continuation lines `[--entitlements <file>]... --info-plist <file>...` and
   `[--work <dir>] [--retry-delay <s>] [--dry-run]` (aligned under `publish` as now), and this description:
   "run in a checkout whose `origin` is the repository: checks the fetched ADP against its hashes and its
   manifest and takes the version from the manifest; checks `<notes-dir>/<version>.md` as `release_notes.py check`
   does; refuses unless `AltStore.json` on `main` lists that version with the manifest's build (D-26: the PAL
   build carries the Classic release's build number); finds the release tagged <version> (it never creates one),"
   followed by the existing text from "uploads each ADP file as" to the end of that description, unchanged.
   In the paragraph that starts "Apple encrypts the variants", after the sentence ending "come from
   `manifest.json`." insert: "The Apple ID must be `--marketplace-id`, and the bundle ID must be the PAL source's
   (`altstore-add-version.jq` refuses another)." Leave the rest of the docstring unchanged.
2. Delete the `process` function.
3. `request_json`: its only remaining caller reads, so give it the signature `request_json(url)`. It always sends
   GET, never a body (drop the `data` and Content-Type handling), keeps the Accept and User-Agent headers, and keeps
   its three error messages word for word with `{method}` replaced by the literal `GET`. Update the call in
   `wait_for_download_url` to `request_json(f"{api_url()}/adps/{urllib.parse.quote(adp_id, safe='')}")`.
4. Add the constant `CLASSIC_SOURCE_NAME = "AltStore.json"` on the line after `SOURCE_NAME`.
5. Add `check_classic_release(main_path, facts)` in the "The source" section, directly after `version_key`, with
   the docstring "D-26: the PAL build carries the Classic release's version and build number, so `AltStore.json` on
   `main` must already list the manifest's version with the manifest's build." It reads
   `main_path / CLASSIC_SOURCE_NAME`, with `version = facts["shortVersionString"]` and
   `build = facts["bundleVersion"]`, and raises PublishError with exactly these messages:
   - file missing: f"main has no {CLASSIC_SOURCE_NAME}; release {version} on GitHub and AltStore Classic before AltStore PAL (D-26)."
   - a JSON error, or a top level that is not an object: f"{CLASSIC_SOURCE_NAME} on main could not be read: {error}" (for a non-object, `error` is the text "it is not an object").
   - It takes the versions as `(source.get("apps") or [{}])[0].get("versions") or []` (the same shape `build_source`
     reads) and the FIRST entry whose `version` equals `version` (AltStore lists the newest first). None found:
     f"{CLASSIC_SOURCE_NAME} on main does not list {version}; release it on GitHub and AltStore Classic before AltStore PAL (D-26)."
   - that entry's `buildVersion` differs from `build`: f"The ADP is {version} ({build}), but {CLASSIC_SOURCE_NAME} on main lists {version} ({classic_build}); the PAL build carries the Classic release's build number (D-26)."
   On success it calls `say(f"{CLASSIC_SOURCE_NAME} on main lists {version} ({build}), the ADP's build.")`.
6. `publish(args)`, in this order:
   - keep the marketplace-ID digits check first, then the `adp_dir` / `work` setup and the three work folders;
   - delete the old `args.version` format check and the "The ADP is version ..., not ..." comparison;
   - after `facts = manifest_facts(...)`, set `version = facts["shortVersionString"]` and refuse a version that
     `VERSION` does not match with PublishError(f"The ADP's manifest.json gives the version {version!r}, not one like 3.0.0.")
     (the version becomes a tag and a file name);
   - keep `entitlements, privacy = project_permissions(...)`;
   - read the notes with `release_notes.read(pathlib.Path(args.notes_dir) / f"{version}.md")`, keeping the existing
     NotesError-to-PublishError wrapping (this is exactly the check `release_notes.py check <file>` runs);
   - then `main_path = (work / "main").resolve()`, `fresh = fresh_main(main_path)` and
     `check_classic_release(main_path, facts)`, BEFORE `find_release`;
   - delete the later `fresh = fresh_main((work / "main").resolve())` line (the preview `build_source` call keeps
     using `fresh`);
   - replace every remaining `args.version` in `publish` (the release lookup, both `gh release download` calls,
     the upload, `asset_url`, `entry_for`'s "version", the messages) with `version`.
7. `parse`: delete the `process` subparser. In the `publish` subparser delete `--version`, replace `--notes` with
   `command.add_argument("--notes-dir", required=True)`, and change the comment above `--entitlements` to
   "# Each bundle's CODE_SIGN_ENTITLEMENTS (a bundle may have none) and INFOPLIST_FILE, as publish-pal.yml passes them."
8. `main`: the dispatch dict becomes `{"fetch": fetch, "publish": publish}`. Keep the ADP ID character check.

(a') actions-tool/tests/test_pal_publish.py
1. Module docstring: "(Phase 20 plan 20-05; D-19; Research §4, §5)" becomes "(Phase 20 plan 20-05, amended
   2026-11-21; D-19, D-26; Research §4, §5)"; the AltStore line becomes "AltStore is a local `http.server` that
   answers `GET /adps/<id>` and serves the ADP zip;"; add the bullet "- `main` carries an `AltStore.json` that lists
   the fixture's 3.0.0 (159), as the Classic release would (D-26);" after the `main` bullet.
2. Add the module-level helper `classic_source(versions)` after `zip_adp`: it returns
   `json.dumps({"apps": [{"bundleIdentifier": "app.ehpanda", "versions": versions}]}, indent=2) + "\n"`.
3. `FakeAltStore`: delete `do_POST`, and make its docstring start "`GET /adps/<id>` answers ..." unchanged otherwise.
4. `FetchTests`: delete `test_process_asks_altstore_to_process_the_adp`.
5. `PublishTests.setUp`: before the seed commit, write `seed / "AltStore.json"` with
   `classic_source([{"version": VERSION, "buildVersion": "159"}])` and add it with README.md in the same
   `git add`. After the existing setup, create `self.notes_dir = self.tmp / "notes"`, `mkdir` it, and copy NOTES to
   `self.notes_dir / f"{VERSION}.md"`.
6. Add `replace_on_main(self, name, text)`: pull the checkout `--ff-only` from `origin main`; when `text` is None,
   `git rm -q name`, else write `text` to the file and `git add` it; commit `-q -m f"change {name}"`; push
   `HEAD:refs/heads/main` (all through `self.git("-C", str(self.checkout), ...)`).
7. Add `adp_with_manifest(self, name, **changes)`: `build_adp(self.tmp / name)`, load
   `ADP_FIXTURE / "manifest.json"` as JSON, `update(changes)`, write it back over the built ADP's manifest.json
   with `json.dumps`, run `fetch --from <that ADP> --out self.tmp / f"{name}-fetched"`, assert return code 0 with
   `self.output`, and return the fetched path.
8. `publish(...)` helper: drop `"--version", VERSION`, and replace `"--notes", str(NOTES)` with
   `"--notes-dir", str(self.notes_dir)`.
9. Delete `test_an_adp_of_another_version_is_refused`. In `test_the_repositorys_files_give_the_published_permissions`
   change the comment's workflow name to `publish-pal.yml`.
10. Add these tests to `PublishTests`, each through `assert_refused_before_upload(result, *needles)`:
    - `test_a_manifest_version_that_is_not_a_release_version_is_refused`: `adp_with_manifest("bad-version", shortVersionString="3.0")`; needles `"'3.0'"`, `"not one like 3.0.0"`.
    - `test_a_manifest_of_another_bundle_is_refused`: `adp_with_manifest("other-bundle", bundleId="app.ehpanda")`; needles `"bundle identifier mismatch"`, `"app.ehpanda.store"`.
    - `test_the_notes_are_the_manifest_versions_file`: subTest "missing": unlink `self.notes_dir / "3.0.0.md"` after copying NOTES to `self.notes_dir / "9.9.9.md"`, needle `str(self.notes_dir / "3.0.0.md")`; subTest "incomplete": write `"# 3.0.0\n\n## English\n\nNew.\n"` to `self.notes_dir / "3.0.0.md"`, needle `"3.0.0.md"`.
    - `test_a_version_the_classic_source_does_not_list_is_refused`: `replace_on_main("AltStore.json", classic_source([{"version": "2.8.1", "buildVersion": "158"}]))`; needles `"AltStore.json"`, `"does not list 3.0.0"`, `"D-26"`.
    - `test_a_build_other_than_the_classic_releases_is_refused`: `replace_on_main("AltStore.json", classic_source([{"version": VERSION, "buildVersion": "163"}]))`; for each of `self.publish()` and `self.publish("--dry-run")` (subTests "live" and "dry run"): needles `"3.0.0 (159)"`, `"3.0.0 (163)"`, `"D-26"`.
    - `test_main_without_the_classic_source_is_refused`: `replace_on_main("AltStore.json", None)`; needles `"main has no AltStore.json"`, `"D-26"`.
11. `SourceTextTests`: add `test_the_tool_only_reads_from_altstore`, asserting `"POST"` and `'add_parser("process")'` are not in the tool's text.

(b) .github/workflows/publish-pal.yml (new; owner items 1, 2)
Write it in this order:
1. A header comment, before `name:`, of these lines (each starting `# `, wrapped at 120 columns like the other
   workflows):
   "Publish AltStore PAL: puts an accepted AltStore PAL build on the PAL source (Phase 20, DIST-18-02, DIST-18-03;
   owner decision, 2026-11-21)." / blank `#` line / "Started by hand on main only, after Apple has accepted the
   version the collaborator submitted. Its one input is the ADP ID the collaborator shares, a bare UUID; by then
   AltStore has processed the package. actions-tool/pal_publish.py fetches the ADP from AltStore, takes the
   version, build, bundle ID and Apple ID from its manifest.json, refuses unless AltStore.json on main lists that
   version with the same build (D-26), attaches the ADP unchanged to that version's existing GitHub release (D-19;
   it never creates one) and adds the version to AltStorePAL.json on main. It can be dispatched again; `dry_run`
   (default true) stops it before any upload or commit." / blank `#` line / "It holds no App Store Connect key and
   runs in no GitHub environment. It reads:" / then two aligned entries:
   `DEPLOY_KEY` "secret: the repository's deploy key. Main's ruleset lets only deploy keys push, so pal_publish.py
   pushes AltStorePAL.json through it, as deploy.yml's Deploy job pushes its sources" and
   `ALTSTORE_PAL_MARKETPLACE_ID` "variable: the app's Apple ID in App Store Connect, the PAL source's marketplaceID".
2. `name: Publish AltStore PAL`.
3. `on: workflow_dispatch:` with `inputs:` `adp_id` (description `'The ADP ID the collaborator shares, a bare UUID such as 453ead28-2d2b-49d1-a398-5a06ca29186b'`, `required: true`, `type: string`) and `dry_run` (description `'Check everything and print the plan, but upload and commit nothing'`, `required: false`, `type: boolean`, `default: true`). No other trigger, no other input.
4. `concurrency:` `group: publish-pal`, `cancel-in-progress: false`.
5. `env:` `PAL_PUBLISH_TOOL_PATH: './actions-tool/pal_publish.py'` and `RELEASE_NOTES_DIR: './ReleaseNotes'`.
6. `jobs:` one job `Publish:` with `runs-on: xcode-27`, `timeout-minutes: 60`, the comment "# contents: the
   release's assets. The push to main goes through the deploy key." above `permissions:` `contents: write`, no
   `environment`, no `if`, no `needs`, and `env:` `ADP_ID: ${{ inputs.adp_id }}` and
   `MARKETPLACE_ID: ${{ vars.ALTSTORE_PAL_MARKETPLACE_ID }}`. Steps, in order:
   1. "Refuse to run off main": the same `env` (REF_TYPE, REF_NAME) and the same two checks as Deploy's step of
      that name, with the messages `::error::Publish AltStore PAL runs on the main branch only, not on a tag.` and
      `::error::Publish AltStore PAL runs on main only. Start it on main.`
   2. "Check the ADP ID": no `env`; its `run` is the comment line "# A bare UUID, as AltStore shows it, checked
      before any request (owner decision, 2026-11-21)." then
      `if [[ ! "$ADP_ID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then`,
      `echo "::error::The ADP ID must be a bare UUID such as 453ead28-2d2b-49d1-a398-5a06ca29186b, as AltStore shows it, not a URL."`,
      `exit 1`, `fi`. It never echoes the input.
   3. "Checkout": `uses: actions/checkout@v7` with exactly `with: ssh-key: ${{ secrets.DEPLOY_KEY }}`, under the
      comment "# Main's ruleset lets only deploy keys past and refuses the job's token, so the checkout carries the
      repository's deploy key, as deploy.yml's Deploy job does: pal_publish.py pushes AltStorePAL.json to main
      through it." (owner item 2).
   4. "Modify git config": identical to Deploy's step of that name.
   5. "Fetch the ADP": comment "# AltStore has processed the ADP by the time its ID is shared; the short wait only
      covers a slow answer." then
      `python3 "$PAL_PUBLISH_TOOL_PATH" fetch --adp-id "$ADP_ID" --out "$RUNNER_TEMP/adp" --interval 30 --timeout 600`.
   6. "Publish to AltStore PAL": `env:` `GH_TOKEN: ${{ github.token }}` and `DRY_RUN: ${{ inputs.dry_run }}`.
      Its `run`: `set -euo pipefail`; the same `dry_run=()` array logic as the old publish step; the comment lines
      "# The version and build come from the ADP's manifest.json. The tool checks ReleaseNotes/<version>.md and
      that AltStore.json on main lists the same build (D-26). The release must exist already: the tool finds it by
      the version's tag and never creates one (D-19). The permissions come from the project, never from the
      encrypted variants (owner decision, 20-08): each bundle's CODE_SIGN_ENTITLEMENTS and INFOPLIST_FILE, held to
      project.pbxproj by test_workflows.py."; then `python3 "$PAL_PUBLISH_TOOL_PATH" publish` with one flag per
      continuation line in this order: `--adp "$RUNNER_TEMP/adp"`, `--repo "$GITHUB_REPOSITORY"`,
      `--notes-dir "$RELEASE_NOTES_DIR"`, `--marketplace-id "$MARKETPLACE_ID"`, `--entitlements App/EhPanda.entitlements`,
      `--info-plist App/Info.plist`, `--info-plist ShareExtension/Info.plist`, `--work "$RUNNER_TEMP/pal-publish"`,
      `"${dry_run[@]}"`; then the old step's `{ if ...; else ...; fi } >> "$GITHUB_STEP_SUMMARY"` block with these
      lines: dry run: `### AltStore PAL: dry run`, an empty line, and "ADP \`$ADP_ID\`: nothing was uploaded or
      committed. Run Publish AltStore PAL again with dry_run off to publish."; live: `### AltStore PAL published`,
      an empty line, and "ADP \`$ADP_ID\` is on its version's GitHub release, and AltStorePAL.json on main lists it."
   No step calls `pal_publish.py process`, asc.py, xcodebuild or marketplace-signing.sh.

(c) .github/workflows/deploy.yml (owner items 1, 5)
1. Header: after the existing comment line 4 ("decision), so nothing is typed in or read from a pull request.")
   and before `on:`, add a blank `#` line and these comment lines (wrapped at 120 columns):
   "Two jobs. `Deploy` makes the release: the archive, the GitHub release, AltStore.json and SideStore.json on main,
   and the Telegram and Discord posts. `AltStorePAL` then builds the AltStore PAL flavor (DIST-18-03) from the same
   commit: its own archive with Config/Marketplace.xcconfig, signed by Xcode through the generated signing
   xcconfig, with the release's version and build number (D-26). It uploads that build to App Store Connect and
   stops (owner decision, 2026-11-21): the collaborator creates the version with review type Notarization, adds
   the build and submits it in App Store Connect. Once Apple accepts it, publish-pal.yml publishes the package."
   / blank `#` line / "`AltStorePAL` runs in the GitHub environment `pal-notarization`, whose required reviewer gives
   the owner's OK for each run (D-07). Its secrets are the only place the signing material and the API key exist:"
   / the eight secret lines of the old workflow's header (`APP_STORE_CONNECT_KEY_ID` to `APPLE_TEAM_ID`), copied
   verbatim / "Its variables:" / the two variable lines (`ALTSTORE_PAL_MARKETPLACE_ID`, `APP_STORE_CONNECT_KEY_ROLE`),
   verbatim / "The PAL archive also reads the repository secrets TELEMETRYDECK_APP_ID and TELEMETRYDECK_SALT, as
   Deploy's archive does." / blank `#` line / "Nothing here creates an App ID, certificate, profile or key: signing
   is manual with the profiles above, and actions-tool/asc.py refuses every endpoint outside its allow-list (D-07).
   Its calls are recorded with the key's ID and role and uploaded as an artifact (D-21); the upload uses the same
   key."
2. The only edit inside the `Deploy` job, a comment: in "Check build number", the comment's last words "the PAL
   build has its own check in its own workflow." become "the PAL build has its own check in the AltStorePAL job
   below." No step, key or command of the `Deploy` job changes.
3. After the `Deploy` job, add a blank line, the comment lines "  # The AltStore PAL build (DIST-18-03), after the
   release and from the same commit. Upload only (owner decision, 2026-11-21); the header lists its environment
   and secrets." and the job `AltStorePAL:` with these keys in this order: `needs: Deploy`, `runs-on: xcode-27`,
   `environment: pal-notarization`, `timeout-minutes: 120`, the comment "# One upload at a time: queue, never
   cancel." above `concurrency:` (`group: pal-upload`, `cancel-in-progress: false`), `permissions:`
   (`contents: read`), `env:` (`ASC_APP_ID: ${{ vars.ALTSTORE_PAL_MARKETPLACE_ID }}`,
   `APP_STORE_CONNECT_KEY_ROLE: ${{ vars.APP_STORE_CONNECT_KEY_ROLE }}`, `ALTSTORE_PAL_JSON_PATH: './AltStorePAL.json'`,
   `ASC_TOOL_PATH: './actions-tool/asc.py'`, `SIGNING_SCRIPT_PATH: './actions-tool/marketplace-signing.sh'`,
   the comment "# The marketplace flavor (Config/Marketplace.xcconfig, included by the generated signing xcconfig)."
   then `MARKETPLACE_BUNDLE_ID: 'app.ehpanda.store'`, `MARKETPLACE_URL_SCHEME: 'ehpanda-marketplace'`, the comment
   "# Its own archive: the Classic archive is never reused or re-signed (owner decision)." then
   `PAL_ARCHIVE_PATH: '/tmp/action-builds/EhPanda-AltStorePAL.xcarchive'` and
   `PAL_EXPORT_PATH: '/tmp/action-builds/EhPanda-AltStorePAL-export'`), no `if`, and `steps:` in this order (the
   job uses the workflow-level SCHEME_NAME and CHECK_BUILD_NUMBER_SCRIPT_PATH):
   1. "Checkout": `actions/checkout@v7` with `persist-credentials: false`, followed by the old submit job's two
      "Snapshot gate off for 3.0 (owner decision); ..." comment lines, verbatim.
   2. "Read the version", `id: version`, `run`: `set -euo pipefail`; the old "Check version" step's
      `ASC_APP_ID` check line verbatim; the comment "# The release's version, read from the project as Deploy's
      build gets it: every app and extension target carries the same MARKETING_VERSION; test targets carry 1.0.";
      the old `versions="$(grep -Eo 'MARKETING_VERSION ...' ... | sort -u)"` line verbatim;
      `[[ "$versions" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "::error::The project's targets do not share one MARKETING_VERSION: '$(tr '\n' ' ' <<< "$versions")'."; exit 1; }`;
      `echo "version=$versions" >> "$GITHUB_OUTPUT"`; `echo "The project is version $versions."`
   3. "Write App Store Connect key": verbatim from the old submit job.
   4. "Check build number": `id: build-number`; `env` = the old step's two secrets plus
      `VERSION: ${{ steps.version.outputs.version }}`; `run` verbatim, except the first comment line ends
      "# The PAL source as published on main." (drop ", whichever ref this run was dispatched on").
   5. "Install iOS 27 Platform", 6. "Show Xcode version", 7. "Set up signing": verbatim.
   8. "Xcode archive": verbatim, except `-archivePath "$PAL_ARCHIVE_PATH"`.
   9. "Verify analytics credentials": verbatim, except `app_info_plist="$PAL_ARCHIVE_PATH/Products/Applications/$SCHEME_NAME.app/Info.plist"`.
   10. "Verify marketplace build": `env` = the old step's APPLE_TEAM_ID and BUILD_NUMBER plus
       `VERSION: ${{ steps.version.outputs.version }}`; `run` verbatim, except `app_path="$PAL_ARCHIVE_PATH/Products/Applications/$SCHEME_NAME.app"`.
   11. "Export and upload": `env` = the old step's two secrets plus `VERSION: ${{ steps.version.outputs.version }}`
       and `BUILD_NUMBER: ${{ steps.build-number.outputs.build }}`; `run` verbatim, except
       `-archivePath "$PAL_ARCHIVE_PATH"` and `-exportPath "$PAL_EXPORT_PATH"`, then, after the xcodebuild command,
       the comment "# Upload only (owner decision, 2026-11-21): the version, the build's attachment and the
       submission are the collaborator's steps in App Store Connect." and a `{ ... } >> "$GITHUB_STEP_SUMMARY"`
       block that echoes `### AltStore PAL $VERSION ($BUILD_NUMBER) uploaded`, an empty line, and "The collaborator
       now creates version $VERSION in App Store Connect with review type Notarization, adds this build and
       submits it. Once Apple accepts it, run Publish AltStore PAL with the ADP ID."
   12. "Upload the call record": `if: always()`, `uses: actions/upload-artifact@v7`, `with:`
       `name: asc-call-record-${{ steps.version.outputs.version }}-upload`, `path: ${{ runner.temp }}/asc-calls.jsonl`,
       `if-no-files-found: ignore`.
   13. "Tear down signing": verbatim (`if: always()`).
   The old "Check version", "Wait for the build", "Ensure the notarization version", "Attach the build" and
   "Submit for notarization" steps do not exist here. Nothing in this job uses `inputs.` or `github.event.`.

(d) `git rm .github/workflows/deploy-pal.yml` (owner item 1).

(e) actions-tool/tests/test_workflows.py (owner item 6)
1. Module docstring first sentence: "The release workflows' shape: the steps a release relies on stay in place
   (Phase 20 D-03, D-19; REL-18-01), deploy.yml's AltStore PAL upload job (20-04, amended 2026-11-21; D-07, D-21,
   D-26) and publish-pal.yml (20-05, amended 2026-11-21; D-19, D-26)." The Ruby paragraph stays.
2. `import os` (sorted with the other imports).
3. The comment above GATE_CHECK becomes: "# Phase 19's screenshot check is OFF in the release workflows for 3.0
   (owner decision): neither deploy.yml (its release job and its AltStore PAL job) nor deploy-beta.yml calls
   snapshot-gate.yml or reads the `aggregate` check. The workflow and actions-tool/require-snapshot-gate.sh stay
   in the repository (pull requests and manual dispatch still use them)." Set
   `RELEASE_WORKFLOWS = ("deploy.yml", "deploy-beta.yml")`, and after GATE_MENTIONS add the comment "# The one
   job a release job waits for: deploy.yml's AltStore PAL job runs after the release (owner decision,
   2026-11-21)." and `RELEASE_NEEDS = {("deploy.yml", "AltStorePAL"): "Deploy"}`.
4. `DeployWorkflowTests`: in `setUpClass` add `cls.release = cls.deploy["jobs"]["Deploy"]`; replace every
   `step_named(self.deploy, ` with `step_named(self.release, ` and every `step_index(self.deploy, ` with
   `step_index(self.release, ` (all 15 are in this class). In `test_the_screenshot_gate_is_off_for_3_0` the jobs
   assertion becomes `["Deploy", "AltStorePAL"]` and `job = self.release`.
5. `ReleasesDoNotTestTests`: replace RELEASES and PERMISSIONS with one map, commented "# (workflow file, release
   job) -> that job's permissions",
   `RELEASES = {("deploy.yml", "Deploy"): {"contents": "write"}, ("deploy.yml", "AltStorePAL"): {"contents": "read"}, ("deploy-beta.yml", "Deploy"): {"contents": "write"}, ("publish-pal.yml", "Publish"): {"contents": "write"}}`.
   `test_no_release_runs_tests_or_waits_on_them` loops over `sorted({name for name, _ in self.RELEASES})`;
   `test_no_release_job_may_read_workflow_runs` loops over `self.RELEASES.items()` with subTest(workflow, job) and
   asserts the job's permissions equal the mapped value.
6. Delete PAL_STEPS, PalWorkflowTests, PAL_PUBLISH_STEPS and PalPublishWorkflowTests. Keep PAL_SECRETS and
   PAL_VARIABLES. Add `PAL_UPLOAD_STEPS` = the 13 step names of (c)3 in order, and `class PalUploadJobTests`
   (skipUnless RUBY; docstring "deploy.yml's `AltStorePAL` job (20-04, amended 2026-11-21; D-07, D-21, D-26):
   after the release it archives the marketplace build on its own, verifies and uploads it, and stops there (owner
   decision)."). `setUpClass` loads deploy.yml into `cls.path`, `cls.text`, `cls.deploy`, `cls.env` (workflow env)
   and `cls.job = cls.deploy["jobs"]["AltStorePAL"]`; `run_text(name)` expands `code(step_named(self.job, name)...)`
   with `{**self.env, **self.job.get("env", {})}`. Tests:
   - `test_it_runs_after_a_successful_release_in_the_protected_environment`: `needs` == "Deploy"; no `if` key; environment name (str or dict) == "pal-notarization"; permissions == {"contents": "read"}; "timeout-minutes" present; concurrency == {"group": "pal-upload", "cancel-in-progress": False}.
   - `test_the_steps_run_in_order`: names == PAL_UPLOAD_STEPS.
   - `test_the_checkout_cannot_push`: as the old submit-job test.
   - `test_the_version_is_the_projects`: step "Read the version" has `id` "version"; its run text contains "MARKETING_VERSION", "EhPanda.xcodeproj/project.pbxproj", "ALTSTORE_PAL_MARKETPLACE_ID", 'echo "version=' and "GITHUB_OUTPUT"; steps "Check build number", "Verify marketplace build" and "Export and upload" each have env VERSION == "${{ steps.version.outputs.version }}"; "inputs." is not in `json.dumps(self.job)`.
   - `test_the_build_number_is_checked_against_the_pal_source_and_app_store_connect` and `test_the_build_number_is_checked_before_the_build`: as the old submit-job tests, on this job.
   - `test_it_archives_the_marketplace_build_on_its_own`: the "Xcode archive" run text contains "xcodebuild archive", '-xcconfig "$MARKETPLACE_XCCONFIG"' and '-archivePath "/tmp/action-builds/EhPanda-AltStorePAL.xcarchive"', and not "CODE_SIGNING_ALLOWED=NO" or "Config/Marketplace.xcconfig"; "Set up signing" runs `marketplace-signing.sh" setup`; the job env PAL_ARCHIVE_PATH differs from the workflow env ARCHIVE_PATH; no step's expanded run text contains the workflow's ARCHIVE_PATH or PAYLOAD_PATH value; no step uses an `actions/download-artifact@` action.
   - `test_nothing_asks_xcode_to_make_signing_records`, `test_the_marketplace_build_is_verified_before_upload`, `test_the_upload_uses_the_export_options_and_the_api_key`: as the old submit-job tests, on this job.
   - `test_it_uploads_and_stops`: over the joined expanded run text of every step, `re.findall(r'actions-tool/asc\.py" ([\w-]+)', text)` == ["check-build"], and none of "wait-build", "ensure-version", "attach-build", "adp-id", "reviewSubmission", "appStoreVersions", "NOTARIZATION", "pal_publish.py" occurs; none of "Wait for the build", "Ensure the notarization version", "Attach the build", "Submit for notarization" is a step name.
   - `test_the_summary_hands_over_to_the_collaborator`: the "Export and upload" run text contains "GITHUB_STEP_SUMMARY", "collaborator" and "Publish AltStore PAL", with "xcodebuild -exportArchive" before "GITHUB_STEP_SUMMARY"; its env BUILD_NUMBER == "${{ steps.build-number.outputs.build }}".
   - `test_the_call_record_is_kept_even_when_a_step_fails`: as the old one, plus `with.name` == "asc-call-record-${{ steps.version.outputs.version }}-upload".
   - `test_the_signing_material_is_always_removed`, `test_no_step_stamps_tags_or_releases`, `test_secrets_reach_steps_only_through_env_and_are_never_echoed`: as the old submit-job tests, on this job.
   - `test_the_checks_see_no_signing_secret`: as the old one, over "Read the version", "Install iOS 27 Platform" and "Verify analytics credentials".
   - `test_the_header_lists_every_secret_and_variable`: header = deploy.yml's lines starting with "#"; used = the `secrets.`/`vars.` names found in `json.dumps(self.job)` minus GITHUB_TOKEN; every name in PAL_SECRETS, PAL_VARIABLES and used is in the header; PAL_SECRETS and PAL_VARIABLES are subsets of used; "pal-notarization", "D-07", "D-21", "D-26" and "publish-pal.yml" are in the header.
7. Add `PUBLISH_STEPS = ["Refuse to run off main", "Check the ADP ID", "Checkout", "Modify git config", "Fetch the ADP", "Publish to AltStore PAL"]`
   and `class PublishWorkflowTests` (skipUnless RUBY; docstring "publish-pal.yml (20-05, amended 2026-11-21; D-19,
   D-26): the ADP ID alone, the unchanged ADP as release assets and the PAL source on `main`, pushed with the
   deploy key, with the permissions from the project's files (owner decision, 20-08)."). `setUpClass` loads
   `cls.path`, `cls.text`, `cls.document`, `cls.env` (workflow env) and `cls.job = cls.document["jobs"]["Publish"]`;
   `run_text(name)` expands with `self.env` only (the job's $ADP_ID and $MARKETPLACE_ID stay as the shell sees
   them). Tests:
   - `test_it_is_dispatched_by_hand_with_the_adp_id_and_dry_run_only`: name == "Publish AltStore PAL"; triggers == ["workflow_dispatch"]; set(inputs) == {"adp_id", "dry_run"}; adp_id required True and type "string"; dry_run type "boolean" and default True; list(jobs) == ["Publish"]; none of "push:", "pull_request", "schedule:", "release:", "workflow_run", "tags:" in `code(self.text)`.
   - `test_it_runs_on_main_only`: mirrors Deploy's guard test on this job's "Refuse to run off main" (index 0, env, both comparisons, two `::error::`, two `exit 1`).
   - `test_the_adp_id_must_be_a_uuid_before_any_request`: "Check the ADP ID" is step 1, before "Checkout" and "Fetch the ADP"; job env ADP_ID == "${{ inputs.adp_id }}"; its run has no "${{"; running `["bash", "-c", run]` with env {"PATH": os.environ.get("PATH", ""), "ADP_ID": value} (capture_output, text, timeout 30) returns 0 for "453ead28-2d2b-49d1-a398-5a06ca29186b" and "453EAD28-2D2B-49D1-A398-5A06CA29186B", and returns 1 with "::error::" in stdout for "", "https://api.altstore.io/adps/453ead28-2d2b-49d1-a398-5a06ca29186b", "453ead28-2d2b-49d1-a398-5a06ca29186b\n", " 453ead28-2d2b-49d1-a398-5a06ca29186b", "453ead28-2d2b-49d1-a398", "453ead28-2d2b-49d1-a398-5a06ca29186b-", "453ead28_2d2b_49d1_a398_5a06ca29186b" and "../etc/passwd" (one subTest each).
   - `test_the_push_to_main_uses_the_deploy_key`: comment "Main's ruleset (pull requests and signed commits, with only the deploy key on its bypass list; checked 2026-11-21) refuses a push with the job's token." Checkout's `with` == {"ssh-key": "${{ secrets.DEPLOY_KEY }}"}; `'"push", "origin", "HEAD:refs/heads/main"'` is in actions-tool/pal_publish.py's text; "Modify git config" comes before "Publish to AltStore PAL".
   - `test_it_holds_no_app_store_connect_key_and_no_environment`: "environment" is a key of neither the job nor the document; none of "APP_STORE_CONNECT", "asc.py", "pal-notarization", "marketplace-signing", "xcodebuild", "ASC_" is in `json.dumps(self.document)`; the `secrets.`/`vars.` names in `code(self.text)` are exactly {"DEPLOY_KEY", "ALTSTORE_PAL_MARKETPLACE_ID"}.
   - `test_the_header_lists_its_secret_and_variable`: the file's "#" lines contain "DEPLOY_KEY", "ALTSTORE_PAL_MARKETPLACE_ID", "D-19" and "D-26".
   - `test_the_adp_is_fetched_then_published_from_its_own_manifest`: "Fetch the ADP" run text contains 'actions-tool/pal_publish.py" fetch --adp-id "$ADP_ID"' and "--timeout"; "Publish to AltStore PAL" run text contains 'actions-tool/pal_publish.py" publish', '--repo "$GITHUB_REPOSITORY"', '--marketplace-id "$MARKETPLACE_ID"', '--notes-dir "./ReleaseNotes"' and "--dry-run", and neither "--version" nor "--notes "; `code(self.text)` does not match `pal_publish\.py"?\s+process`; job env MARKETPLACE_ID == "${{ vars.ALTSTORE_PAL_MARKETPLACE_ID }}".
   - `test_the_permissions_come_from_the_projects_files`: the old publish-job test, verbatim, reading this job's "Publish to AltStore PAL".
   - `test_dry_run_is_passed_through` and `test_gh_gets_the_job_token_only`: the old publish-job tests on this job.
   - `test_the_job_never_builds_signs_or_submits`: for every step, the expanded run text contains none of "xcodebuild", "marketplace-signing.sh", "asc.py", "package-channel.sh", "check-build-number.sh", and no `git tag`/`git push`, no `gh release`, no `action-gh-release` use; job permissions == {"contents": "write"}; none of DISTRIBUTION_CERTIFICATE, DISTRIBUTION_CERTIFICATE_PASSWORD, PROVISIONING_PROFILE_APP, PROVISIONING_PROFILE_SHARE_EXTENSION, APPLE_TEAM_ID is in `json.dumps(self.job)`.
   - `test_secrets_reach_steps_only_through_env`: the old publish-job test on this job.
8. `GateOffTests.test_no_release_workflow_calls_or_reads_the_gate`: replace `self.assertNotIn("needs", job)` with
   `self.assertEqual(job.get("needs"), RELEASE_NEEDS.get((workflow, name)))`.
   Write no test, comment or docstring that names the deleted workflow file.

(f) Scripts/visual/test_snapshot_gate.py `WiringTests`
- `assert_gate_off(self, path, needs=None)`: inside the job loop, replace the `needs` assertion with
  `self.assertEqual(job.get('needs'), (needs or {}).get(name), f'{path.name}: {name}')`.
- `test_the_release_does_not_wait_for_the_gate`: add the comment "# deploy.yml's AltStore PAL job waits only for
  the release job (owner decision, 2026-11-21)."; call `self.assert_gate_off(WORKFLOWS / 'deploy.yml',
  needs={'AltStorePAL': 'Deploy'})`; the jobs assertion becomes `['Deploy', 'AltStorePAL']`.
- Delete `test_the_pal_submission_does_not_wait_for_the_gate` (that job now lives in deploy.yml, covered above).

Commit (signed, +0800, explicit paths plus the `git rm`): `ci: upload PAL in Deploy, publish by ADP ID`.
  </action>
  <!-- planner-discipline-allow: deploy-pal -->
  <verify>
    <automated>python3 -m unittest discover -s actions-tool/tests -p 'test_pal_publish.py' && python3 -m unittest discover -s actions-tool/tests -p 'test_workflows.py' && python3 -m unittest discover -s Scripts/visual -p 'test_snapshot_gate.py' && actionlint .github/workflows/deploy.yml .github/workflows/deploy-beta.yml .github/workflows/publish-pal.yml && test ! -e .github/workflows/deploy-pal.yml && files="$(git grep -l 'deploy-pal' -- ':!.planning')" && [ "$files" = "$(printf '%s\n' Config/Marketplace.xcconfig Scripts/visual/README.md actions-tool/ExportOptions-marketplace.plist actions-tool/asc.py actions-tool/marketplace-signing.sh)" ] && grep -q '^    needs: Deploy$' .github/workflows/deploy.yml</automated>
    Baselines: files naming the old workflow outside .planning [HEAD=10 EXPECT==5] (exactly Task 2's five: Config/Marketplace.xcconfig, Scripts/visual/README.md, actions-tool/ExportOptions-marketplace.plist, actions-tool/asc.py, actions-tool/marketplace-signing.sh); lines matching `^    needs: Deploy$` [HEAD=0 EXPECT>=1]; the old workflow file exists at HEAD and must not after. Run after the commit, so `git grep` sees the new file and not the removed one. Then `git log -1 --format='%G? %aI %cI'` shows `G` and two `+08:00` dates.
  </verify>
  <done>deploy.yml has the jobs Deploy (unchanged apart from one comment) and AltStorePAL (upload only); publish-pal.yml exists with the adp_id and dry_run inputs, the UUID check, the DEPLOY_KEY checkout and no App Store Connect secret or environment; pal_publish.py publish takes the version from the manifest, reads --notes-dir, refuses a mismatch with main's AltStore.json (D-26), and has no process command; deploy-pal.yml is deleted; the four named test files pass; actionlint is clean on the three workflows; one signed +0800 commit.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Reduce asc.py to the build check and drop the old workflow's mentions (owner items 4, 5; D-07, D-21)</name>
  <files>actions-tool/asc.py, actions-tool/tests/test_asc.py, Config/Marketplace.xcconfig, actions-tool/ExportOptions-marketplace.plist, actions-tool/marketplace-signing.sh, Scripts/visual/README.md</files>
  <read_first>
    - actions-tool/asc.py (whole) and actions-tool/tests/test_asc.py (whole)
    - .github/workflows/deploy.yml as committed by Task 1 (the AltStorePAL job: the only asc.py call is `check-build`)
    - Config/Marketplace.xcconfig lines 1-3, actions-tool/ExportOptions-marketplace.plist lines 1-9, actions-tool/marketplace-signing.sh lines 1-5 and 90-96, Scripts/visual/README.md line 134
  </read_first>
  <behavior>
    - `asc.ALLOWED` == [("GET", r"^/v1/builds$")]; every submission and ADP endpoint (POST/PATCH appStoreVersions, reviewSubmissions, reviewSubmissionItems, the ADP read, the app's versions list) is refused before any request.
    - `asc.py wait-build`, `ensure-version`, `attach-build`, `submit` and `adp-id` exit 2 (argparse) and make no request; `asc.COMMANDS` keys are exactly {"check-build"}.
    - check-build still fails on a used build number, passes a new one with the app and version filters, reports an API error with Apple's status and detail, and records one call-record line per call with key ID and role, never the key or a token.
  </behavior>
  <action>
1. actions-tool/asc.py (owner item 4; the allow-list stays the D-07 gate, the call record stays as is for D-21)
   - Docstring: first line "A small App Store Connect API client for the AltStore PAL upload (the `AltStorePAL`
     job of `deploy.yml`)." Next paragraph: "It makes the one call that job needs and nothing else (Phase 20 D-07,
     D-21; App Store Connect OpenAPI 4.6): before the archive, it checks that the build number is still unused.
     The job uploads the build with xcodebuild and stops; the collaborator creates the version, attaches the build
     and submits it in App Store Connect (owner decision, 2026-11-21). The standard library and `openssl` are all it
     uses, so a release job holding signing secrets installs nothing." Usage keeps only the `check-build` entry and
     its description line. The paragraph "The client refuses every endpoint outside `ALLOWED`." becomes "The client
     refuses every endpoint outside `ALLOWED`, which holds only that build read." followed by the existing "In
     particular it can never create ..." sentence. Everything else in the docstring stays.
   - `TOKEN_REFRESH`'s comment becomes "# A token is replaced well before it expires."
   - `ALLOWED`: its comment becomes "# The only endpoint this client may call, as (method, path pattern): the build
     list check-build reads." and the list holds only `("GET", r"^/v1/builds$")`.
   - Delete EDITABLE_VERSION_STATES, OPEN_SUBMISSION_STATE and BUSY_SUBMISSION_STATES with their comments.
   - `Client.request`: drop the `body` parameter, the `data` variable and the Content-Type header (no remaining
     command sends a body); build the request as `urllib.request.Request(url, method=method)`. Keep the `method`
     parameter, the allow-list check, the call record, the GET-only retry rule and its comment.
   - Delete `find_builds`, and inline its query into `check_build`: the query is
     `{"filter[app]": args.app, "filter[preReleaseVersion.version]": args.version, "limit": "200"}` and the builds
     are `(client.request("GET", "/v1/builds", query) or {}).get("data") or []`; the rest of `check_build` is
     unchanged.
   - Delete `wait_build`, `find_versions`, `ensure_version`, `attach_build`, `submit` and `adp_id`.
   - `parse`: the description becomes "App Store Connect's build check for the AltStore PAL upload."; keep the
     `number` and `version` validators; the only subparser is `check-build` with `--app` (number), `--version`
     (version) and `--build` (number), all required.
   - `COMMANDS = {"check-build": check_build}`. `main` is unchanged.
2. actions-tool/tests/test_asc.py
   - Docstring: "the request sequence and bodies (App Store Connect OpenAPI 4.6)" becomes "the build check's request
     (App Store Connect OpenAPI 4.6)"; add the sentence "Since 2026-11-21 (owner decision) the client makes only that
     check; the submission is the collaborator's, by hand."
   - Delete the module-level `version()` helper.
   - `AllowListTests`: replace `test_the_allow_list_names_only_the_submit_and_read_endpoints` with
     `test_the_allow_list_is_the_build_read_only` (`asc.ALLOWED == [("GET", r"^/v1/builds$")]`). Keep
     `test_the_allow_list_has_no_record_making_endpoint` as is. Add `test_the_submission_steps_are_refused`: each of
     ("POST", "/v1/appStoreVersions"), ("PATCH", "/v1/appStoreVersions/1/relationships/build"),
     ("GET", "/v1/apps/1/appStoreVersions"), ("GET", "/v1/appStoreVersions/1"), ("GET", "/v1/reviewSubmissions"),
     ("POST", "/v1/reviewSubmissions"), ("PATCH", "/v1/reviewSubmissions/1"), ("GET", "/v1/reviewSubmissions/1/items"),
     ("POST", "/v1/reviewSubmissionItems"), ("GET", "/v1/appStoreVersions/1/alternativeDistributionPackage"),
     ("GET", "/v1/builds/1"), ("GET", "/v1/preReleaseVersions") is not `asc.allowed`. `test_the_paths_the_client_uses_are_allowed`
     checks only ("GET", "/v1/builds"). Add `test_only_the_build_check_is_a_command`: `set(asc.COMMANDS) == {"check-build"}`,
     and for each of "wait-build", "ensure-version", "attach-build", "submit", "adp-id" (subTest), running
     `[sys.executable, str(ASC), name]` (capture_output, text, timeout 60) returns 2 with "invalid choice" in stderr.
     Keep the remaining AllowListTests.
   - `CommandTests`: delete every wait-build, ensure-version, attach-build, submit and adp-id test and the
     `submission` helper. Keep both check-build tests; in `test_check_build_passes_for_a_new_number` also assert the
     first call's query has `filter[app]` == [APP_ID] and `limit` == ["200"]. Replace
     `test_an_api_error_fails_with_apples_message` with a check-build version: route ("GET", "/v1/builds") to
     (403, {"errors": [{"status": "403", "code": "FORBIDDEN_ERROR", "title": "Forbidden", "detail": "The API key in use does not allow this request."}]});
     return code 1, "403" and the detail in stderr.
   - Replace `run_whole_sequence` with `run_build_checks`: route ("GET", "/v1/builds") to
     [(200, {"data": [build("b-1", "158", "VALID")]})], then run check-build for builds "159" and "160" (app APP_ID,
     version 3.0.0), each with return code 0. The three record and log tests call it; the record test expects the
     statuses [200, 200].
   - `test_missing_credentials_fail_before_any_request` runs `check-build --app APP_ID --version 3.0.0 --build 159`.
3. Reference comments (owner item 5; meaning unchanged, only the workflow named):
   - Config/Marketplace.xcconfig lines 1-2 become "// Marketplace flavor — COMMITTED, used only by the AltStore PAL
     upload job" and "// (`AltStorePAL` in `.github/workflows/deploy.yml`, Phase 20 plan 20-04):".
   - actions-tool/ExportOptions-marketplace.plist line 4 becomes "  Export options for the AltStore PAL upload (the
     AltStorePAL job of deploy.yml, Phase 20 plan 20-04)."
   - actions-tool/marketplace-signing.sh line 3 becomes "# Signing for the AltStore PAL build (the `AltStorePAL`
     job of `.github/workflows/deploy.yml`, Phase 20 plan 20-04)." and the generated xcconfig's first line (the
     `echo` in `write_xcconfig`) becomes "// Generated by actions-tool/marketplace-signing.sh for one run of
     deploy.yml's AltStorePAL job, and deleted after it."
   - Scripts/visual/README.md line 134: the parenthesis after "The release workflows" becomes
     "(`deploy.yml`, including its AltStore PAL job, and `deploy-beta.yml`)"; the rest of the line is unchanged.

Commit (signed, +0800, explicit paths): `pal: trim asc.py and drop deploy-pal mentions`.
  </action>
  <!-- planner-discipline-allow: deploy-pal -->
  <verify>
    <automated>python3 -m unittest discover -s actions-tool/tests -p 'test_asc.py' && python3 -m unittest discover -s actions-tool/tests -p 'test_workflows.py' && plutil -lint actions-tool/ExportOptions-marketplace.plist && bash -n actions-tool/marketplace-signing.sh && { git grep -n 'deploy-pal' -- ':!.planning'; [ $? -eq 1 ]; }</automated>
    Baseline: files naming the old workflow outside .planning [HEAD=10 EXPECT==0] (5 after Task 1); `git grep` exits 1 for no match, 0 for a match and 128 for an error, so only a clean "no match" passes. Then `git log -1 --format='%G? %aI %cI'` shows `G` and two `+08:00` dates.
  </verify>
  <done>asc.py has only check-build and an allow-list of GET /v1/builds, with no request body support or submission helpers left; test_asc.py covers the build check, the refusals and the call record; no file outside .planning names the deleted workflow; one signed +0800 commit.</done>
</task>

<task type="auto">
  <name>Task 3: Record the split and the D-21 / DIST-18-03 consequence (owner item 7; D-21)</name>
  <files>.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md, .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-08-SUBMISSION.md, .planning/REQUIREMENTS.md</files>
  <read_first>
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md lines 224-235 (D-21), 304-321 (plan order (c)), 377-389 (Developer defaults, Notarization CI)
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-08-SUBMISSION.md lines 109-123 ("Open")
    - .planning/REQUIREMENTS.md lines 165-168 (DIST-18-03) and 240-262 (traceability and footer)
  </read_first>
  <action>
Keep history: insert dated amendments; rewrite nothing that is already there except the REQUIREMENTS.md footer
line noted below. Do not mark DIST-18-03 complete anywhere. Do not touch STATE.md, ROADMAP.md or any other quick
task's folder. Wrap the 20-CONTEXT.md and 20-08-SUBMISSION.md insertions at about 118 columns with the same
indentation as their neighbours, keeping each amendment's opening words, up to the end of the first clause quoted
in the verify, on its first line (the verify greps those phrases). REQUIREMENTS.md lines are not wrapped.

1. 20-CONTEXT.md
   - Plan order: directly after the two lines of "- **(c) Notarization CI job** (DIST-18-03): ..." and before
     "  - **Checkpoints (collaborator and owner, D-07), each at its own time:**", insert the sub-bullet
     "  - *Amended 2026-11-21 (owner decision):* the CI uploads the signed build and stops. Creating the version with
     `reviewType: NOTARIZATION`, attaching the build and submitting are the collaborator's steps by hand in App Store
     Connect, and publishing takes only the ADP ID (Developer defaults, Notarization CI; D-21)."
   - Developer defaults, Notarization CI: after the bullet "  - **The key test.** The workflow records D-21's App
     Manager key test result.", insert the sub-bullet "  - *Amended 2026-11-21 (owner decision):* the split is now
     different. `deploy.yml` (Deploy) has a second job, `AltStorePAL`, that runs after the release (`needs:
     Deploy`) in the `pal-notarization` environment, whose required reviewer is the per-run OK (D-07). It builds its
     own archive with `Config/Marketplace.xcconfig` and the generated signing xcconfig, signed by Xcode (the Classic
     archive is not reused or re-signed), checks that App Store Connect has not seen the build number, verifies the
     build, uploads it and stops. The collaborator creates the version, attaches the build and submits it by hand.
     A separate dispatch-only workflow, `publish-pal.yml` (Publish AltStore PAL), takes only the ADP ID the
     collaborator shares (a bare UUID) and `dry_run`. It uses no App Store Connect key and no environment, fetches
     the ADP from AltStore, takes the version and build from its manifest, refuses unless `AltStore.json` on `main`
     lists the same build (D-26), attaches the ADP unchanged to that version's existing GitHub release (D-19) and
     adds it to `AltStorePAL.json` on `main`, pushing with the repository's deploy key. It no longer asks AltStore
     to process the ADP: AltStore has processed it by the time the ID is shared. `deploy-pal.yml` is deleted."
   - D-21: after the bullet "  - **Recorded at the test.** ..." (two lines), insert the sub-bullet
     "  - *Amended 2026-11-21 (owner decision):* the workflow now only uploads the build. Its call record carries the
     key's ID and role on the build-number check, and the upload uses the same key in the same job, so a run shows
     which key uploaded the build. Creating the version, attaching the build and submitting are the collaborator's
     steps by hand, so no run records whether an App Manager key alone can do them. DIST-18-03 stays Pending."
2. 20-08-SUBMISSION.md, section "Open"
   - Directly after the last line of the "**Closed (2026-11-21): `publish` follows the owner's rule.**" bullet
     (the line ending "byte for byte."), add the indented continuation "  *Amended 2026-11-21 (owner decision):*
     `publish-pal.yml` passes them now, and `publish` takes the version from the manifest instead of a `--version`
     input." with "`publish-pal.yml` passes them now" on its first line.
   - Directly after the bullet "- **DIST-18-03:** the D-21 answer needs a `deploy-pal.yml` `submit` run.", add the
     indented continuation "  *Amended 2026-11-21 (owner decision):* `deploy-pal.yml` is gone. Deploy's
     `AltStorePAL` job uploads the build only, and the collaborator creates the version, attaches the build and
     submits it by hand in App Store Connect. A run's call record can show which key uploaded the build; it cannot
     answer whether an App Manager key alone can create the version, attach the build and submit. DIST-18-03 stays
     Pending."
3. REQUIREMENTS.md
   - Under "- [ ] **DIST-18-03**: Automate notarization and publishing.", after its "  - *Phase 20 (split
     2026-11-05).*" line, add "  - *Amended 2026-11-21 (owner decision):* the CI uploads the build only (the
     `AltStorePAL` job of `deploy.yml`, after the GitHub release). The collaborator creates the version, attaches the
     build and submits it for notarization by hand in App Store Connect, and `publish-pal.yml` takes the ADP ID and
     publishes it to the PAL source. So a workflow run can show which key uploaded the build, but it no longer tests
     whether an App Manager key can create the version and submit. Still Pending."
   - Leave the checkbox unticked and the traceability row `| DIST-18-03 | Phase 20 | Pending |` as is.
   - Footer: in the current first footer line (the 20-08 entry), change only its leading "*Last updated:" to
     "*Previously updated:" (the rest of that line unchanged), and insert above it the new line
     "*Last updated: 2026-11-21 — quick 261121-jps: DIST-18-03 amended (owner decision): the CI uploads the PAL build
     only, the collaborator creates, attaches and submits by hand, and `publish-pal.yml` publishes by ADP ID; it
     stays Pending.*" (the footer's em dash matches the existing footer lines of this planning file).

Commit (signed, +0800, explicit paths): `docs(quick-261121-jps): record the PAL CI split`.
  </action>
  <verify>
    <automated>P=.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele; grep -q 'the CI uploads the signed build and stops' $P/20-CONTEXT.md && grep -q 'the split is now' $P/20-CONTEXT.md && grep -q 'the workflow now only uploads the build' $P/20-CONTEXT.md && grep -q '`publish-pal.yml` passes them now' $P/20-08-SUBMISSION.md && grep -q 'is gone. Deploy' $P/20-08-SUBMISSION.md && grep -q 'the CI uploads the build only (the' .planning/REQUIREMENTS.md && grep -q '^\*Last updated: 2026-11-21 — quick 261121-jps: DIST-18-03 amended' .planning/REQUIREMENTS.md && grep -q '^\*Previously updated: 2026-11-21 — 20-08: the first AltStore PAL source is live' .planning/REQUIREMENTS.md && grep -q '^- \[ \] \*\*DIST-18-03\*\*' .planning/REQUIREMENTS.md && grep -q '^| DIST-18-03 | Phase 20 | Pending |$' .planning/REQUIREMENTS.md</automated>
    Baselines: each of the first eight phrases [HEAD=absent EXPECT==present @e82010b40] (the three 20-CONTEXT.md amendments, the two 20-08-SUBMISSION.md amendments, the DIST-18-03 amendment, the new footer line and the 20-08 footer line turned "Previously updated"); the unticked DIST-18-03 line and its Pending row are guards [HEAD=present EXPECT==present @e82010b40 GUARD MUTATION: ticking DIST-18-03 or writing anything but Pending in its traceability row]. Then `git log -1 --format='%G? %aI %cI'` shows `G` and two `+08:00` dates.
  </verify>
  <done>The three records carry the dated owner-decision amendments for the split and for D-21 / DIST-18-03; DIST-18-03 is still unticked and Pending; one signed +0800 commit.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| workflow_dispatch input → shell and AltStore URL | The ADP ID is typed by a person with write access and reaches a shell and an HTTP path. |
| AltStore download → publish tool | manifest.json comes from AltStore's download; its version becomes a tag lookup and a notes file name. |
| publish workflow → main | A workflow without a required reviewer pushes to main with the deploy key, which is on main's bypass list. |
| pal-notarization environment → App Store Connect | The signing material and the API key exist only there and touch the collaborator's account (D-07). |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261121-jps-01 | Tampering | publish-pal.yml `adp_id` input | medium | mitigate | Reaches steps only through job env (never `${{ }}` inside `run`); "Check the ADP ID" refuses anything but a bare UUID before checkout or any request and never echoes it; pal_publish.py's own ID character check stays; test_workflows runs the step's script on good and bad IDs. |
| T-261121-jps-02 | Tampering | manifest.json version used as a tag and a file name | medium | mitigate | publish refuses a shortVersionString that is not x.y.z before any lookup (pal_publish VERSION pattern); test_a_manifest_version_that_is_not_a_release_version_is_refused. |
| T-261121-jps-03 | Elevation of privilege | DEPLOY_KEY in a workflow without a reviewer | medium | accept | Same exposure as Deploy: dispatch needs write access, main only, dry_run defaults to true, and the only push is pal_publish.py's commit of AltStorePAL.json alone (git add of that one file). |
| T-261121-jps-04 | Information disclosure | App Store Connect key and signing secrets | high | mitigate | Only deploy.yml's AltStorePAL job (environment pal-notarization, required reviewer, D-07) reads them, through step env; publish-pal.yml has no environment and reads no App Store Connect secret (PublishWorkflowTests). |
| T-261121-jps-05 | Elevation of privilege | asc.py allow-list | high | mitigate | ALLOWED holds only GET /v1/builds; no command can create, attach or submit (D-07); tests assert the submission endpoints are refused and the removed commands do not exist. |
| T-261121-jps-06 | Repudiation | which key made the App Store Connect calls (D-21) | low | mitigate | The call record is still written and uploaded with `if: always()`; the records state that version creation, attachment and submission are now manual and unrecorded by the workflow. |
| T-261121-jps-07 | Tampering | a PAL build that differs from the Classic release (D-26) | medium | mitigate | check_classic_release refuses unless AltStore.json on main lists the manifest's version with the same build, in live and dry runs; three tests. |
| T-261121-jps-SC | Tampering | dependency installs | low | accept | No package, pip or npm installs in this plan. |
</threat_model>

<verification>
After Task 3:
1. Every script test directory, exactly as lint.yml runs them:
   `bash -c 'failed=0; while IFS= read -r directory; do python3 -m unittest discover -s "$directory" -p "test_*.py" || failed=1; done < <(find Scripts actions-tool -name "test_*.py" -exec dirname {} \; | sort -u); exit "$failed"'`
   (all OK; at HEAD this is 301 tests in actions-tool/tests and 468 in Scripts/visual, plus Scripts/lint, Scripts/live-check and Scripts/ui-tests).
2. `actionlint .github/workflows/deploy.yml .github/workflows/deploy-beta.yml .github/workflows/publish-pal.yml` exits 0.
3. `git grep -n 'deploy-pal' -- ':!.planning'` exits 1 (no match).
4. `git log --format='%G? %aI %cI %s' -3` shows three `G` commits with `+08:00` dates and the three subjects above.
5. `git status --short` in the worktree is clean (no AppPackage/ or other quick-task path was touched).

## Multi-Source Coverage Audit

| Source | Item | Covered by |
|--------|------|------------|
| GOAL | Split PAL CI into a Deploy upload job and an ADP-ID publish workflow | Task 1 |
| Owner item 1 | Deploy job unchanged; AltStorePAL job `needs: Deploy`, environment pal-notarization, own Marketplace archive signed by Xcode (no Classic reuse) | Task 1 (c), tests in (e)6 |
| Owner item 1 | Upload only: no wait, ensure-version, attach or submit; keep check-build, the AltStorePAL.json build check, marketplace verification, call record, teardown; version from MARKETING_VERSION; summary line | Task 1 (c)3, (e)6 |
| Owner item 1 | New dispatch-only publish workflow: inputs ADP ID (bare UUID, validated before any request) and dry_run (default true); no ASC key, no environment; fetch by ADP ID; version/build/bundle/Apple ID from the manifest; existing release only (D-19); AltStorePAL.json on main; no process step; main only; named publish-pal.yml / "Publish AltStore PAL" | Task 1 (a), (b), (e)7 |
| Owner item 1 | Delete deploy-pal.yml | Task 1 (d) |
| Owner item 2 | Push to main with the DEPLOY_KEY checkout, with a test | Task 1 (b)6.3, (e)7 test_the_push_to_main_uses_the_deploy_key |
| Owner item 3 | publish without --version; --notes-dir with the release-notes check for that version's file | Task 1 (a)6, (a')10 |
| Owner item 3 | D-26 guard against AltStore.json on main | Task 1 (a)5-6, (a')10 |
| Owner item 3 | Keep marketplace-ID match, bundle app.ehpanda.store, project permissions with the pbxproj test | Task 1 (a) (unchanged code), (a')10, (e)7 test_the_permissions_come_from_the_projects_files |
| Owner item 3 | Remove process and its tests; update the docstring | Task 1 (a)1-2, 7-8, (a')3-4, 11 |
| Owner item 4 | asc.py keeps only what the AltStorePAL job calls; tests; call record unchanged | Task 2 step 1-2 |
| Owner item 5 | Every deploy-pal.yml reference outside .planning; deploy.yml header; secrets and variables moved to their new homes | Task 1 (a)7, (a')9, (c)1, (e), (f); Task 2 step 3 |
| Owner item 6 | test_workflows.py shape tests for both new homes; action pins (existing ActionPinTests, unchanged) | Task 1 (e) |
| Owner item 7 | 20-CONTEXT.md Notarization CI amendment; D-21 / DIST-18-03 consequence in 20-CONTEXT.md, 20-08-SUBMISSION.md and REQUIREMENTS.md; DIST-18-03 not completed; 261121-ifi folder untouched | Task 3 |
| CONTEXT D-07 | Apple-account actions only with the per-run OK (environment reviewer); nothing creates Apple records | Task 1 (c), Task 2 step 1 |
| CONTEXT D-19 | ADP unchanged onto the existing release; never create a release or tag | Task 1 (a) (unchanged find_release), (b) |
| CONTEXT D-21 | Call record kept; consequence recorded | Task 1 (c)3.12, Task 2, Task 3 |
| CONTEXT D-26 | PAL carries the Classic build number; guard | Task 1 (a)5 |
| Repo facts | No dispatch, push or live API call; other session's files untouched; commit conventions; Scripts/visual tests mirrored from lint.yml | Objective, context, verification |

Exclusions: none of the task definition's items is deferred.
</verification>

<success_criteria>
- A Deploy run releases exactly as before and then, after the pal-notarization approval, uploads the separately
  archived marketplace build and stops with the hand-over summary.
- Publish AltStore PAL publishes an accepted ADP from its ID alone, pushing AltStorePAL.json through the deploy key,
  and refuses a malformed ID, a missing release, a notes file gap or a build that differs from the Classic release.
- asc.py can only read builds; pal_publish.py has no process command; deploy-pal.yml is gone everywhere outside
  .planning.
- All script tests and the three workflows' actionlint pass; three signed +0800 commits.
- The Phase 20 records explain the split and its D-21 / DIST-18-03 consequence, with DIST-18-03 still Pending.
</success_criteria>

<output>
Create `.planning/quick/261121-jps-split-pal-ci-into-deploy-upload-and-adp-/261121-jps-SUMMARY.md` when done.
</output>
