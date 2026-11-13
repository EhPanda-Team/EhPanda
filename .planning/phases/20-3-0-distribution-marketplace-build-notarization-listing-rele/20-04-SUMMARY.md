---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "04"
subsystem: infra
tags: [altstore-pal, notarization, app-store-connect, signing, github-actions]

requires: [20-01, 20-02, 20-03]
provides:
  - "`actions-tool/asc.py`: App Store Connect client (stdlib + openssl ES256): `check-build`, `wait-build`, `ensure-version`, `attach-build`, `submit`, `adp-id`; method-scoped endpoint allow-list; per-call log and JSON-lines call record with key ID and role only"
  - "`actions-tool/marketplace-signing.sh`: `api-key`, `setup`, `teardown`, `xcconfig-only`, `export-options-only`"
  - "`actions-tool/ExportOptions-marketplace.plist`: template (app-store-connect, upload, manual, Apple Distribution, no build-number management), filled per run"
  - "`.github/workflows/deploy-pal.yml`: workflow_dispatch only (`version`, `mode: submit|publish`); `submit` job in environment `pal-notarization`"
affects: [20-05, 20-06, 20-08]

actuals:
  tokens: 60000
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - "JWT ES256 without packages: `openssl dgst -sha256 -sign` plus a DER-to-raw `r || s` conversion"
    - "One `-xcconfig` for every target, a profile per target through `PROVISIONING_PROFILE_SPECIFIER = $(EHPANDA_PROFILE_$(TARGET_NAME))`"
    - "A local `http.server` fake for API sequence tests; the client's base URL must be https unless it is loopback"

key-files:
  created:
    - actions-tool/asc.py
    - actions-tool/marketplace-signing.sh
    - actions-tool/ExportOptions-marketplace.plist
    - actions-tool/tests/test_asc.py
    - .github/workflows/deploy-pal.yml
  modified:
    - actions-tool/tests/test_workflows.py

key-decisions:
  - "Secret names (environment `pal-notarization`): ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, DIST_CERT_P12, DIST_CERT_PASSWORD, PROFILE_APP, PROFILE_SHARE_EXTENSION, TEAM_ID. Variables: PAL_MARKETPLACE_ID (the app's Apple ID, also the App Store Connect app ID for `--app`), ASC_KEY_ROLE (D-21, informational). The archive also reads the repository's TELEMETRYDECK_APP_ID and TELEMETRYDECK_SALT, as deploy.yml does. All are listed in the workflow header for 20-06."
  - "The allow-list is per method. Writes are only POST appStoreVersions, PATCH .../relationships/build, POST reviewSubmissions, PATCH reviewSubmissions/{id}, POST reviewSubmissionItems. Every other entry is a GET. The only `apps` path is GET /v1/apps/{id}/appStoreVersions, because OpenAPI 4.6 has no top-level list of versions. POST /v1/alternativeDistributionPackages is refused (D-07)."
  - "`ensure-version` reuses a version with the same string only if it is editable (PREPARE_FOR_SUBMISSION, DEVELOPER_REJECTED, REJECTED, METADATA_REJECTED, INVALID_BINARY) and already has review type NOTARIZATION; otherwise it fails and changes nothing. A new version gets reviewType NOTARIZATION and releaseType MANUAL, as the plan says."
  - "`submit` reuses the app's open (READY_FOR_REVIEW) submission and adds the version only if it is not already an item. It refuses while a submission is WAITING_FOR_REVIEW, IN_REVIEW, UNRESOLVED_ISSUES, CANCELING or COMPLETING."
  - "Only GETs are retried (429, 5xx, connection errors; 3 attempts). A create is never sent twice."
  - "The call record's fields are exactly method, path (no query), status, keyID and keyRole. The log line is `ASC <method> <path> <status> key=<id> role=<role>`. No token, key, query or body is logged."
  - "The export options leave the build number alone (`manageAppVersionAndBuildNumber` false): the PAL upload carries the Classic release's version and build (D-26)."
  - "The build-number check compares only AltStorePAL.json on main and App Store Connect's builds of the version, never the Classic sources (D-26)."

patterns-established:
  - "Each App Store Connect step passes ASC_KEY_ID and ASC_ISSUER_ID in its own `env`; the key file path, call-record path and signing paths go through GITHUB_ENV; no `secrets.` appears in any `run`."

requirements-completed: []

coverage:
  - id: D1
    description: "Token verifies with openssl; the submit sequence, bodies, failure modes, allow-list and call record work against a fake"
    requirement: DIST-18-03
    verification:
      - kind: unit
        ref: "test_asc.py: Ran 32 tests, OK (TokenTests 4, AllowListTests 5, CommandTests 23); RED before asc.py: import error"
        status: pass
    human_judgment: false
  - id: D2
    description: "The generated xcconfig gives each target its own profile and the marketplace bundle ID"
    requirement: DIST-18-03
    verification:
      - kind: integration
        ref: "xcodebuild -showBuildSettings -target EhPanda / -target ShareExtension -xcconfig <generated>: App Profile + app.ehpanda.marketplace; Share Profile + app.ehpanda.marketplace.shareExtension; Manual, Apple Distribution, TEAMID0000"
        status: pass
    human_judgment: false
  - id: D3
    description: "The submit job is dispatch-only, protected, ordered, and leaks no secret"
    requirement: DIST-18-03
    verification:
      - kind: unit
        ref: "test_workflows.py: Ran 30 tests, OK (PalWorkflowTests 19); RED before the workflow: setUpClass error"
        status: pass
      - kind: lint
        ref: "actionlint 1.7.12: only the shared `xcode-27` runner-label finding; clean with -ignore 'label \"xcode-27\" is unknown'"
        status: pass
    human_judgment: false

duration: 14min
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 04: the notarization submit side (App Store Connect client, signing helper, submit job) Summary

**`deploy-pal.yml` has a dispatch-only `submit` job in the `pal-notarization` environment. It checks the version
and build number, runs the tests, signs the marketplace build, verifies and uploads it, then creates the
Notarization version and submits it through `asc.py`. The call record is always uploaded and the signing material
always removed. All of it is tested offline. Nothing contacted Apple, and the workflow was not dispatched.**

> **Renamed later (owner msg 4895, full names only):** the secret and variable names below are the old ones. The current ones are in the `deploy-pal.yml` header: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, `DISTRIBUTION_CERTIFICATE`, `DISTRIBUTION_CERTIFICATE_PASSWORD`, `PROVISIONING_PROFILE_APP`, `PROVISIONING_PROFILE_SHARE_EXTENSION`, `APPLE_TEAM_ID`; variables `ALTSTORE_PAL_MARKETPLACE_ID`, `APP_STORE_CONNECT_KEY_ROLE`.

## Performance

- **Duration:** 14 min
- **Started:** 2026-11-09T02:00:00Z
- **Completed:** 2026-11-09T02:14:00Z
- **Tasks:** 3
- **Files modified:** 6 (5 created, 1 modified)

## Accomplishments

- **Client (Task 1).** `asc.py` signs ES256 tokens with `openssl`, renews them after 15 minutes during long waits,
  and implements the calls the plan lists, plus `check-build` for the lookup before the archive (Research pitfall
  2). Request bodies follow OpenAPI 4.6 (`AppStoreVersionCreateRequest`, `ReviewSubmissionCreateRequest`,
  `ReviewSubmissionItemCreateRequest`, `ReviewSubmissionUpdateRequest`, `AppStoreVersionBuildLinkageRequest`),
  taken from the spec downloaded to `/tmp`. Paths off the allow-list are refused before any request is made.
  Missing credentials fail before any request. The tests grep stdout, stderr and the record for every token
  segment and every key line, and find none (T-20-10). They also check that the list has no app, bundle ID,
  certificate, profile, user, key or ADP-creating path (T-20-11).
- **Signing (Task 2).** `setup` decodes the `.p12` into a temporary keychain under `$RUNNER_TEMP`, with a random
  password, `set-key-partition-list`, and the original search list saved. It checks that the identity is Apple
  Distribution. It checks that each profile's team and `application-identifier` match `TEAM_ID` and the
  marketplace bundle ID, then installs it by UUID. Finally it writes the xcconfig and the filled export options.
  Profile names that xcconfig would misread (`//`, `$(`, newline) are refused. `teardown` restores the search
  list and deletes the keychain, the installed profiles, the key and the generated files. It always exits 0
  (T-20-12).
- **Submit job (Task 3).** The steps in order: Checkout (`persist-credentials: false`), Check version, Write App
  Store Connect key, Check build number, Install platform, Show Xcode version, Run tests (FeatureTests), Set up
  signing, Xcode archive, Verify analytics credentials, Verify marketplace build, Export and upload, Wait for the
  build, Ensure the notarization version, Attach the build, Submit for notarization, Upload the call record
  (`always()`), Tear down signing (`always()`).
  - The job has `permissions: contents: read`, `concurrency: deploy-pal` and `timeout-minutes: 300`.
  - The flavor check reuses the beta's plist checks for the marketplace values (bundle IDs, name, URL scheme, the
    extension's hand-off scheme), plus the `altstorePAL` stamp, version, build, `PrivacyInfo.xcprivacy`,
    `codesign --verify --deep --strict`, `Authority=Apple Distribution: `, `TeamIdentifier`, an embedded profile,
    and no `get-task-allow`, for the app and the extension.

## Task Commits

1. **Task 1: App Store Connect client.** `4c61f5b80` (test, RED), `dd15e0df9` (feat, GREEN)
2. **Task 2: Signing helper and export options.** `ca17b8502` (feat)
3. **Task 3: Submit job.** `86bf6e313` (test, RED), `1a2829de6` (feat, GREEN)

## Verification evidence

| Check | Result |
|-------|--------|
| Task 1 RED (no `asc.py`) | import error |
| Task 1 verify | `test_asc.py`: Ran 32 tests, OK; `grep -c "import requests\|import jwt" asc.py` → 0 |
| Task 2 verify | `bash -n` OK (also `/bin/bash` 3.2); `plutil -lint` OK; `xcconfig-only` and `export-options-only` written; `api-key` and `teardown` run with a fake `RUNNER_TEMP` (teardown also with none: exit 0); `setup` without secrets fails on the first missing one |
| Task 2 build settings | `-target EhPanda`: `App Profile`, `app.ehpanda.marketplace`. `-target ShareExtension`: `Share Profile`, `app.ehpanda.marketplace.shareExtension`. Both Manual / Apple Distribution / TEAMID0000 |
| Task 3 RED (no workflow) | `test_workflows`: 11 tests, errors=1 |
| Task 3 verify | full actions-tool suite: Ran 140 tests, OK; actionlint: only the `xcode-27` label finding (also present in all 8 existing workflows); every `run` block passes `bash -n`; "Check version" run locally: 3.0.0 passes, 3.0.1 / 3.0 / an empty app ID fail |
| Acceptance | `grep -c allowProvisioningUpdates` → 0 in both files; `grep -c "environment: pal-notarization"` → 1 |

## Files Created/Modified

- `actions-tool/asc.py`: the App Store Connect client
- `actions-tool/tests/test_asc.py`: token, allow-list, command sequence and call-record tests against a local fake
- `actions-tool/marketplace-signing.sh`: keychain, profiles, key file, xcconfig, export options, teardown
- `actions-tool/ExportOptions-marketplace.plist`: export options template
- `.github/workflows/deploy-pal.yml`: the dispatch-only notarization workflow (submit job)
- `actions-tool/tests/test_workflows.py`: `PalWorkflowTests` (19 tests)

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **An `apps` read path in the allow-list.** The plan's list names builds, preReleaseVersions, appStoreVersions,
   reviewSubmissions, reviewSubmissionItems and the ADP paths. Finding a version by its string needs
   `GET /v1/apps/{id}/appStoreVersions`, because OpenAPI 4.6 has no `GET /v1/appStoreVersions`. It is the only
   `apps` entry, and it is GET only. The test asserts that no non-GET entry touches `apps`.
2. **Extra subcommands.**
   - `asc.py check-build` is the lookup before the archive that the plan's truth asks for; the behavior list has
     no name for it.
   - `adp-id` also accepts `--app --version`, so 20-05's publish job can resolve the version ID itself.
   - `marketplace-signing.sh api-key` exists because the build-number check (before the tests, as the plan
     orders) already needs the key. That is why the job has a "Write App Store Connect key" step.
   - `export-options-only` checks the export options offline, the same way `xcconfig-only` checks the xcconfig.
3. **The build-settings check uses `-target`.** With `-scheme EhPanda`, `-showBuildSettings` lists only the app,
   because the extension is an embedded dependency. Running it once per target with `-target` shows both. The
   plan's literal command also passes and shows the app.
4. **Profile directories.** Profiles are installed in both `~/Library/Developer/Xcode/UserData/Provisioning
   Profiles` (Xcode 16 and later) and `~/Library/MobileDevice/Provisioning Profiles` (the plan's), and
   `teardown` removes both.
5. **actionlint location.** `~/.local/bin/actionlint` does not exist, so I used `/opt/homebrew/bin/actionlint`
   1.7.12. Its one finding, the custom runner label `xcode-27`, appears in every workflow and still needs a
   decision: an `actionlint.yaml` listing the label, or keep ignoring it.
6. **Test-data fix in a GREEN commit.** `test_der_signatures_become_raw_r_and_s` had a wrong DER sequence length
   (0x41 instead of 0x43). It is fixed in `dd15e0df9`, as that commit's message says.

## Open items

- **PAL template copy (D-25), carried over from 20-03.** `actions-tool/altstore-pal.template.json` still has the
  Classic subtitle and description, including the source subtitle "Over a million adult comics and doujinshi".
  20-10 replaces both with the copywriter's PAL copy (copywriter msg 2785, pending the owner's approval at 20-10). It
  also updates `test_the_pal_template_has_the_classic_metadata` in `test_source_templates.py` to match. This must
  happen before 20-08 publishes.
- **Upload without `-allowProvisioningUpdates` is unproven.** `xcodebuild -help` documents the
  `-authenticationKey*` flags on their own ("xcodebuild will authenticate with the Apple Developer website using
  this credential"). Whether `-exportArchive` with `destination upload` and manual signing accepts the key
  without that flag is first seen at 20-08. If it refuses, the fallback is `destination export` plus a separate
  upload with the same key, which needs a plan change. `-allowProvisioningUpdates` must stay out (D-07).
- **`releaseType MANUAL`.** The plan asks for it, but D-26 makes OQ-B moot. A notarized version with manual release
  may need "Release this version" in App Store Connect before AltStore can fetch the package. 20-05 and 20-08
  should check this when the version is accepted. If it does, either 20-05 releases the version through the API
  (a PATCH or `appStoreVersionReleaseRequests`, which needs an allow-list change and the owner's OK), or 20-08 does
  it by hand.
- **The ADP may not exist yet when it is read.** `adp-id` only reads it. If Apple does not create it for a
  marketplace-distributed version, `POST /v1/alternativeDistributionPackages` would be needed. That is refused
  today, and enabling it is a D-07 decision at 20-05 or 20-08.
- **`setup`'s live path is unexercised.** Keychain import, the profile checks and installation need the
  collaborator's real certificate and profiles. They run first at 20-08, or in a dry run with the owner's OK once
  20-06 has created the secrets. The script edits the runner user's keychain search list and restores it at
  teardown. If the runner is killed so that `always()` steps never run, the installed profiles stay in
  `~/Library`; the runner empties `RUNNER_TEMP`, which holds the key and keychain.
- **What the logs show.** GitHub masks the `ASC_KEY_ID` secret in logs, but the uploaded call record contains the
  key ID in clear, which D-21 asks for. The record holds no token or key.
- **Carried over:** 20-10's `pal/iphone/` and `pal/ipad/` screenshot paths are stale (`app-marketplace/`). REL-18-01
  and DIST-18-02 stay Pending. DIST-18-03 stays Pending until the publish half (20-05) and the live run (20-08).

## User Setup Required

None now. 20-06 creates the environment, its required reviewer, and the secrets and variables named above.

## Next Phase Readiness

20-05 (wave 4) can add the `publish` job to `deploy-pal.yml` (`if: inputs.mode == 'publish'`, same environment,
`contents: write` for the PAL source commit). It reads the package ID with
`asc.py adp-id --app "$ASC_APP_ID" --version "$VERSION"` and appends to the same call-record format.
