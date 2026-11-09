---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "05"
subsystem: infra
tags: [altstore-pal, notarization, adp, github-releases, github-actions]

requires: [20-03, 20-04]
provides:
  - "`actions-tool/pal_publish.py`: `process` (POST /adps), `fetch` (poll GET /adps/<id> until `downloadURL`, or `--from` a zip or folder; byte-for-byte unpack with a SHA-256 per file), `publish` (release by tag only, `EhPanda-AltStorePAL-*` assets, re-download and hash compare, `assetURLs`, entitlements and privacy from the signed variant, AltStorePAL.json on main with five push attempts; `--dry-run`)"
  - "`actions-tool/tests/fixtures/adp/`: a synthetic ADP (manifest.json, signature, one variant app with Info.plists and entitlements) and `fake-codesign`; `tests/fixtures/fake-gh/gh`: a recording gh that refuses any command it does not know"
  - "`.github/workflows/deploy-pal.yml`: `publish` job (`inputs.mode == 'publish'`, environment `pal-notarization`, `contents: write`) and the `dry_run` input (boolean, default true)"
  - "`.github/actionlint.yaml`: the self-hosted `xcode-27` runner label"
affects: [20-06, 20-08]

actuals:
  tokens: 80000
  tasks: 2
  commits: 5

tech-stack:
  added: []
  patterns:
    - "A recording fake `gh` on PATH with a state directory for releases and assets; unknown commands exit 2, so `release create`, `edit` or `delete` cannot pass silently"
    - "A local bare repository as `main`, with a pre-receive hook that lands a concurrent commit and rejects the push, to test the retry loop"
    - "Git in tests isolated with GIT_CONFIG_GLOBAL (empty file) and GIT_CONFIG_NOSYSTEM"

key-files:
  created:
    - actions-tool/pal_publish.py
    - actions-tool/tests/test_pal_publish.py
    - actions-tool/tests/fixtures/adp/
    - actions-tool/tests/fixtures/fake-gh/gh
    - .github/actionlint.yaml
  modified:
    - .github/workflows/deploy-pal.yml
    - actions-tool/tests/test_workflows.py

key-decisions:
  - "ADP files are mapped by file name: `manifest.json` → `manifest`, `signature` → `signature`, `<uuid>.ipa` → `<uuid>` (AltStore, Make a Source, `assetURLs`). Anything else in the package, two files with one name, a symlink, or a zip entry outside its folder is refused, so 20-08 sees the real layout as an error rather than as a silent drop."
  - "AltStore's `downloadURL` must be https; the only exception is the API's own origin, which is how the tests' local fake is reached (`ALTSTORE_API_URL`)."
  - "Assets are never replaced: an existing asset with the same bytes is reused (a re-dispatch is idempotent), one with other bytes fails the run. There is no `--clobber`."
  - "`size` is the first variant's size (sorted by name), `date` is the release's `published_at`, `minOSVersion` and `buildVersion` come from the variant's Info.plist, and the version must equal the variant's CFBundleShortVersionString."
  - "Entitlements are the union of `codesign -d --entitlements - --xml` over the app and each `PlugIns/*.appex` (and `Extensions/*.appex`), without the two identity keys; privacy is every `*UsageDescription` of the same bundles."
  - "A build older than the source's newest entry is refused: AltStore offers the first entry, so a stale ADP published late would read as a downgrade."
  - "In the workflow, `dry_run` is on unless it is exactly `false`; the job summary says which it was."

patterns-established:
  - "The publish job never builds, signs or submits: its steps are checkout, git identity, version and notes check, API key, `asc.py adp-id`, `pal_publish.py process`, `fetch`, `publish`, call record (always), key removal (always). gh gets `github.token` in the publish step only."

requirements-completed: []

coverage:
  - id: D1
    description: "Fetch waits, downloads unchanged, accepts a zip or a folder and refuses a broken package; publish uploads by the version's tag only, re-downloads and compares, writes a checked PAL source that keeps history, makes no upload or commit in a dry run, and retries a rejected push up to five times"
    requirement: DIST-18-03
    verification:
      - kind: unit
        ref: "test_pal_publish.py: Ran 23 tests, OK (FetchTests 8, PublishTests 14, SourceTextTests 1); RED before pal_publish.py: 22 tests, failures=23 (subtests), errors=1"
        status: pass
    human_judgment: false
  - id: D2
    description: "The manifest is only ever copied as bytes"
    requirement: DIST-18-03
    verification:
      - kind: unit
        ref: "test_the_manifest_bytes_never_change: the fixture, fetched, staged, stored-on-release and re-downloaded SHA-256 are equal; grep -cE 'json\\.dumps?\\(.*manifest' pal_publish.py → 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "The publish job is dispatch-only, protected, dry-run by default and never builds, signs or submits"
    requirement: DIST-18-03
    verification:
      - kind: unit
        ref: "test_workflows.py: Ran 40 tests, OK (PalPublishWorkflowTests 10); RED before the job: setUpClass KeyError 'publish' and the inputs test"
        status: pass
      - kind: lint
        ref: "actionlint 1.7.12 on every workflow: no finding (the xcode-27 label is now declared)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 05: the publish side (ADP fetch, AltStore processing, release assets, PAL source) Summary

**`deploy-pal.yml` has a dispatch-only `publish` job. It reads the ADP ID from App Store Connect, asks AltStore to
process the package, waits for its `downloadURL`, and downloads it. `pal_publish.py` attaches every file unchanged
to the version's existing GitHub release, downloads each asset again to compare hashes, and adds the version to
`AltStorePAL.json` on `main`. `dry_run` defaults to true. All of it is tested offline against a fake AltStore, a
fake `gh`, a fake `codesign` and a local bare repository. Nothing contacted AltStore, Apple or GitHub, and the
workflow was not dispatched.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-11-09T02:16:00Z
- **Completed:** 2026-11-09T02:41:00Z
- **Tasks:** 2 (plus the actionlint label commit the coordinator asked for)
- **Files modified:** 13 (11 created, 2 modified)

## Accomplishments

- **actionlint label.** `.github/actionlint.yaml` declares `xcode-27` under `self-hosted-runner.labels`, in its
  own commit. actionlint is now clean on every workflow without `-ignore`.
- **Tool (Task 1).** `pal_publish.py`, standard library plus `gh`, `codesign`, `jq` and `git`:
  - `process` sends `{"adpID": <id>}` to `POST /adps` (AltStore REST API, "Process ADP").
  - `fetch --adp-id` polls `GET /adps/<id>` until it has a `downloadURL`, with a bounded wait. A timeout names the
    ADP ID and AltStore's last `status`. `fetch --from` takes a zip or a folder. Both write `adp/` (byte copies),
    `adp-files.json` (SHA-256 per file) and, for a zip, `adp.zip`.
  - `publish` re-checks every fetched file against `adp-files.json`. It reads the variant's Info.plists and
    entitlements and the release notes in six languages (`release_notes.read`). It finds the release with
    `gh api repos/{repo}/releases/tags/<version>`, and fails with "no GitHub release for <version>" before any
    upload. Next it builds and checks a preview source, then uploads the missing `EhPanda-AltStorePAL-*` assets in
    one `gh release upload`. It downloads each asset again and compares hashes. Finally it runs
    `altstore-add-version.jq` with `assetURLs`, `entitlements` and `marketplaceID` on `main`'s `AltStorePAL.json`
    (or the template), checks the result with `check_source(pal=True)`, commits and pushes from a worktree, and
    retries on a fresh shallow `main` up to five times.
  - `--dry-run` stops after the checks and the preview. It prints each asset it would upload or keep, with its
    hash, and leaves the source it would write in `<work>/AltStorePAL.json`.
- **Publish job (Task 2).** The `publish` job runs on `xcode-27` (macOS, for `codesign`) with
  `if: inputs.mode == 'publish'`, the same environment, `contents: write` and a 120-minute timeout. Its steps are:
  Checkout, Modify git config, Check version (format, `PAL_MARKETPLACE_ID`, `release_notes.py check`), Write App
  Store Connect key, Read the ADP ID, Ask AltStore to process the ADP, Fetch the ADP (30 s interval, 1 h timeout),
  Publish to AltStore PAL (passing `dry_run` through), Upload the call record (`always()`), and Remove the API key
  (`always()`). It has no build, signing, submit, tag or release step.

## Task Commits

0. **actionlint label.** `0ba4c62a8` (ci)
1. **Task 1: `pal_publish.py`.** `041d11b26` (test, RED), `d6a906880` (feat, GREEN)
2. **Task 2: Publish job.** `adab36e21` (test, RED), `42124cf8f` (feat, GREEN)

## Verification evidence

| Check | Result |
|-------|--------|
| Task 1 RED (no `pal_publish.py`) | 22 tests, failures=23 (subtests), errors=1 |
| Task 1 verify | `test_pal_publish.py`: Ran 23 tests, OK |
| Task 1 acceptance | `grep -cE "json\.dumps?\(.*manifest" actions-tool/pal_publish.py` → 0; the manifest's SHA-256 is equal at fixture, fetch, staging, on the release and after re-download |
| Task 2 RED (no job) | `test_workflows`: setUpClass KeyError `publish`, plus the inputs test |
| Task 2 verify | full actions-tool suite: Ran 173 tests, OK; `/opt/homebrew/bin/actionlint` (every workflow): no finding; each `publish` `run` block passes `bash -n` and `/bin/bash -n` |
| Task 2 acceptance | `grep -A4 "dry_run:"` shows `type: boolean`, `default: true` |

## Files Created/Modified

- `actions-tool/pal_publish.py`: the publish tool
- `actions-tool/tests/test_pal_publish.py`: fetch, publish, dry-run, retry and source-text tests
- `actions-tool/tests/fixtures/adp/`: the synthetic ADP and `fake-codesign`
- `actions-tool/tests/fixtures/fake-gh/gh`: the recording fake `gh`
- `.github/workflows/deploy-pal.yml`: `dry_run` input, `PAL_PUBLISH_TOOL_PATH` and `RELEASE_NOTES_TOOL_PATH`, and
  the `publish` job
- `actions-tool/tests/test_workflows.py`: `PalPublishWorkflowTests` (10); the submit tests' step lookups are now
  scoped to their own job
- `.github/actionlint.yaml`: the runner label

## Research (coordinator points 2 and 3)

Read 2026-11-09 from Apple's and AltStore's public documentation. No account and no API was used.

### Does `releaseType MANUAL` keep AltStore from getting the package?

- **The ADP exists before release.** App Store Connect Help, "Get an alternative distribution package ID": a package
  "automatically generates for an app version if … the app version is accepted on or after February 8, 2024, or
  the app version is Ready for Distribution, or Processing for Distribution, or **Pending Developer Release**".
  <https://developer.apple.com/help/app-store-connect/managing-alternative-distribution/get-an-alternative-distribution-package-id/>
- The API article "Creating alternative distribution packages" lists the eligible states as "Pending Developer
  Release, Pending Apple Release, or Ready for Distribution".
  <https://developer.apple.com/documentation/appstoreconnectapi/creating-alternative-distribution-packages>
- **What "release" covers.** "Select an App Store version release option" describes "Release This Version" for a
  version in Pending Developer Release as releasing it "to the App Store". It also says "Send this request only
  when you're ready to publish your version. You can't cancel this request." The second sentence is from the API's
  `POST /v1/appStoreVersionReleaseRequests` page.
  <https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/>,
  <https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appstoreversionreleaserequests>
- "App and submission statuses" defines Pending Developer Release as "accepted, but you still need to release it
  for distribution on the App Store".
  <https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/>
- In "Submit for Notarization", "Version Release settings" is neither required nor editable. The same page ends
  "The app version is accepted, an alternative distribution package automatically generates."
  <https://developer.apple.com/help/app-store-connect/managing-alternative-distribution/submit-for-notarization/>
- **AltStore's side.** AltStore's pages only require "a notarized ADP ID" for `POST /adps` and `GET /adps/<id>`.
  They say nothing about the version's release state.
  <https://faq.altstore.io/developers/rest-api>, <https://faq.altstore.io/developers/distribute-with-altstore-pal>
- **Finding.** In Apple's documents, MANUAL does not block the package: it is generated in Pending Developer Release.
  No Apple or AltStore page says whether AltStore PAL serves or installs a version that is still Pending Developer
  Release. The release request is documented only in App Store terms, and it cannot be undone. **No release call
  was added to `asc.py`'s allow-list.** This is recorded as an open item for the owner at 20-08 (below).

### Does Apple create the ADP, or does it need a POST?

- **Automatic in our order.** "Submit for Notarization" opens with "After you've added your app as eligible for
  distribution on a marketplace in App Store Connect … follow these steps", and ends "The app version is accepted, an
  alternative distribution package automatically generates."
- The API article "Configuring alternative marketplaces and alternative marketplace apps" agrees. If the app is not
  yet in an approved state, "the alternative distribution package is automatically created after approval". If it
  was already approved when it was connected to the marketplace, "the app developer needs to generate an alternative
  distribution package by using the POST-v1-alternativeDistributionPackages endpoint".
  <https://developer.apple.com/documentation/appstoreconnectapi/configuring-alternative-marketplaces-and-alternative-marketplace-apps>
- "Creating alternative distribution packages" describes the POST path after approval and after the app is added to
  a marketplace integration. It also says "Only one alternative distribution package can exist for an
  `appStoreVersion`" and "A marketplace can't generate alternative distribution packages on behalf of the app
  developer".
- **Finding.** 20-06 adds AltStore PAL as a marketplace before 20-08 submits, so Apple creates the ADP when the
  notarized version is accepted. No POST is needed. A POST is needed only if the app is connected to the
  marketplace after the version was already accepted. **`POST /v1/alternativeDistributionPackages` stays refused
  (D-07).** If 20-08's `asc.py adp-id` reports "has no alternative distribution package yet", that is an owner
  decision at the time.
- Related: with "Yes, send notifications" on, AltStore processes the package itself (Distribute with AltStore
  PAL, step 4; Apple, "Manage distribution on an alternative app marketplace": the marketplace "needs to be approved
  for Notarization and needs to support receiving notifications"). The job's `process` call is then harmless.

## Deviations from Plan

1. **Extra guards.** These are beyond the behavior list, and each one is tested:
   - a zip entry outside its folder;
   - two package files with the same name;
   - an http `downloadURL`;
   - a variant whose version is not the requested one;
   - an existing asset with other bytes (an identical one is reused, so a re-dispatch is idempotent);
   - a fetched file changed before upload;
   - a build older than the source's newest entry.
2. **`fetch --from`.** It is an extra input for `fetch`, alongside `--adp-id`. 20-08 can feed it the real package
   when it records the layout, and the tests use it for the zip and folder cases.
3. **Entitlements are read with `codesign -d --entitlements - --xml`.** The plan says `--entitlements :-`. The XML
   form is the one 20-04's verify step already uses. The current `codesign` man page documents `-` with `--xml`
   or `--der`, and does not document the `:` prefix.
4. **The ADP layout rule is strict.** Any file that is not `manifest.json`, `signature` or an `.ipa` fails the run,
   with a pointer to 20-08. Research §5 says to "refuse anything else". If Apple's real package carries more, 20-08
   adjusts the rule and the fixture.
5. **Test fix in a GREEN commit.** `test_older_versions_are_kept` wrote `AltStorePAL.json` into the checkout
   before `git pull`, which then refused to overwrite the untracked file. The first write was removed in
   `d6a906880`, as its message says. The same commit adds `test_an_older_build_is_not_put_above_a_newer_one`.
6. **The publish job's Check version does not compare MARKETING_VERSION.** Publish may be re-dispatched from a
   later `main`. It checks the version's format, `PAL_MARKETPLACE_ID`, and the notes file of that version instead.
   The variant's own version is compared in `pal_publish.py`.
7. **Lines over 120 characters.** One test line is 128 characters: shell text inside the pre-receive hook's string.
   It was left as is, since no Python linter is configured.

## Open items

- **Owner, at 20-08: is a release needed for AltStore?** Apple generates the ADP in Pending Developer Release, but
  nothing documents whether AltStore PAL distributes a version still in that state. At the first acceptance, run
  publish with `dry_run` on and look at AltStore's `GET /adps/<id>` and a test install. If AltStore needs the
  version released, there are two ways, both the owner's call (D-07):
  - "Release This Version" in the App Store Connect web UI, by the collaborator; or
  - an allow-list entry for `POST /v1/appStoreVersionReleaseRequests`.
  Either cannot be undone. With review type Notarization the version is not on the App Store, so a release should
  only change where it is distributed.
- **The ADP's real layout and AltStore's download format** (zip or something else) are first seen at 20-08.
  `fetch` fails clearly on anything other than a zip or the three file kinds.
- **`ReleaseNotes/3.0.0.md`** (owner content) is still missing. The publish job's Check version fails without it,
  as the release does.
- **Carried over:**
  - the PAL template's Classic copy, which 20-10 replaces before 20-08 publishes (D-25);
  - 20-10's stale `pal/` screenshot paths;
  - upload without `-allowProvisioningUpdates`;
  - `setup`'s live path.

  DIST-18-02 and DIST-18-03 stay Pending until 20-08.

## User Setup Required

None now. 20-06 creates the `pal-notarization` environment, its secrets and variables, and adds AltStore PAL as a
marketplace for the app before anything is submitted. That order is what makes the ADP automatic.

## Next Phase Readiness

20-06 can set up the account with the names in the `deploy-pal.yml` header. At 20-08 the order is: dispatch
`submit`; after Apple accepts, dispatch `publish` with `dry_run` on; then dispatch `publish` with `dry_run` off,
with the owner's OK each time.
