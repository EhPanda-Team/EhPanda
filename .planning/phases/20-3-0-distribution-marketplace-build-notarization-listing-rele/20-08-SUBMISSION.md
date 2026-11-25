# 20-08 Record: notarization verdict, the ADP and the first PAL source

Recorded 2026-11-21 by the orchestrator, from the owner's report and from what the ADP, the signed archive and
GitHub showed. Times are UTC.

## Decisions

- OQ-A: A1 (D-26). The screenshots are 20-10's set.
- OQ-B: moot (D-26). The first submission is the final 3.0.0 build.
- **The submission went outside `deploy-pal.yml`** (owner decision). The owner gave the collaborator the signed
  marketplace archive, and the collaborator submitted it in App Store Connect. `deploy-pal.yml` has no run yet.
- **The first `AltStorePAL.json` was made by hand** (owner decision), because the App Store Connect API key is not
  available to the owner yet. This overrides the plan's "no live publish in this plan": the owner chose to publish
  3.0.0 on AltStore PAL now.
- **PAL copy: Classic copy kept** (owner decision, 2026-11-25). D-25 is dropped: the PAL listing keeps the Classic
  subtitle, description and screenshots. Nothing changes in the template or its tests.
- **DIST-18-03 closes on the first successful CI upload** (owner decision, 2026-11-25): the first Deploy run whose
  `AltStorePAL` job uploads a marketplace build with the `app-marketplace` secrets. Its run ID and build number go
  here. D-21 is no longer asked.

## Submission and verdict (Task 3)

| | |
|---|---|
| Build | `app.ehpanda.store` 3.0.0 (163), signed with an Apple Distribution certificate; archive created 2026-11-12T19:24Z |
| Review type | Notarization |
| Verdict: accepted | reported by the owner; the ADP existed by 2026-11-20T15:53Z (AltStore's `created`) |
| Workflow run | none (manual submission) |

Not recorded, because the submission was made outside this session and the workflow: the owner's approval of the
PAL copy with the first screenshot's caption (D-25, step 1), the collaborator's App Store Connect entries and
screenshot upload (step 2), and the D-21 table. Without a call record, which key and role created the version,
attached the build and submitted it is unknown: create version: unknown, attach build: unknown, submit: unknown.
DIST-18-03 stays Pending until a `deploy-pal.yml` run answers D-21.
*Closed 2026-11-25:* DIST-18-03 closed on the first CI upload instead (see First CI upload).

## The ADP (Task 4)

ADP `453ead28-2d2b-49d1-a398-5a06ca29186b`. AltStore's `GET /adps/<id>` gave `status: success`, created
2026-11-20T15:53:04Z and updated 15:55:50Z (about three minutes of processing), and a `downloadURL` that expires
2026-11-25T15:55:37Z. It was fetched with `pal_publish.py fetch --adp-id`, which needs no App Store Connect key.

**Layout:** one zip (30,424,707 bytes). Inside it, `manifest.json`, `signature` and a `variant/` folder with one
`<publicId>.ipa` per variant. This is what the 20-05 fixture assumed, so neither the fixture nor `fetch` changes.

| File | Bytes | SHA-256 |
|---|---|---|
| `manifest.json` | 4,871 | `3cdd44f9a76f135eee583e50ef979480064e340c7799a713e9022f2bb711cbb3` |
| `signature` | 2,756 | `7a05e7beb85c34af12d7f64632c7e88d7446f01f65b7a706fde0b8d903ef3add` |
| `variant/647d58c8-9641-3e96-9f9f-cce15e24ce2c.ipa` (iPad) | 15,385,978 | `332eb7672b1f0cb433633e2a80801c4c2e0d9bcd68760f748f8877d0909d1fe6` |
| `variant/e02d8e15-2647-3a6b-928d-038446b3e5e1.ipa` (iPhone) | 15,386,016 | `f6fda99037e01baa8dc186c2e9803f6bd258b7ca4a93cf35ed972c3778a24b36` |

**`assetURLs` keys:** `manifest`, `signature`, `647d58c8-9641-3e96-9f9f-cce15e24ce2c`,
`e02d8e15-2647-3a6b-928d-038446b3e5e1`.

**The manifest** carries what the source needs: `appleItemId` 6832942312 (the `marketplaceID`), `bundleId`
`app.ehpanda.store`, `shortVersionString` 3.0.0, `bundleVersion` 163, `minimumSystemVersions.ios` 27.0, and per
variant its `assetPath`, install targets (iPad or iPhone, iOS 27) and `compressedSize`, with encrypted and
unencrypted chunk digests.

**The variants are encrypted.** Their bytes are not a zip, so `pal_publish.py publish` stops in `bundle_facts` with
`BadZipFile` and cannot read entitlements or privacy keys from them. This differs from 20-05's assumption, and the
tool is not changed here: where `publish` takes the entitlements from is open for the owner (see Open).

## Entitlements

**Amended 2026-11-21 (owner decision):** the source lists only the entitlements in the project's entitlements
files, and leaves out the ones Apple's signing adds. For 3.0.0 that is `[]`: `App/EhPanda.entitlements` is empty
and the share extension has none. `AltStorePAL.json` was changed to `[]` on `develop` and `main`. No install has
been tried with `[]` yet; the install below listed the two signed keys. The table that follows is what the signed
build carries, kept as the evidence.

Read with `codesign -d --entitlements` from the signed 3.0.0 (163) archive, without the two keys AltStore excludes
(`application-identifier`, `com.apple.developer.team-identifier`):

| Bundle | Entitlements |
|---|---|
| `EhPanda.app` | `get-task-allow` = false |
| `ShareExtension.appex` | `beta-reports-active` = true, `get-task-allow` = false |

The source lists their union, `["beta-reports-active", "get-task-allow"]`. Privacy: `NSPhotoLibraryAddUsageDescription`,
as in `App/Info.plist`. A signed 3.0.0 (158) archive of the same flavor had the same entitlements. `AltStore.json`'s
`[]` is not a precedent: the Classic build is unsigned.

## The source

- Built with `pal_publish.py`'s own steps (`verified_adp`, `release_notes.read`, `find_release`, `build_source`,
  so the publish filter and `check_source(pal=True)`), with the entitlements above passed in.
- The source identifier is `app.ehpanda.altstore.pal` (owner decision), in the template and its tests.
- The test that held `AltStorePAL.json` absent now checks the published source: it passes the PAL checks and equals
  the template apart from `marketplaceID`, `appPermissions` and `versions`.
- `downloadURL` is the manifest's release asset, and `size` is the iPad variant's.

## Release assets

The four files went to the 3.0.0 release unchanged as `EhPanda-AltStorePAL-manifest.json`,
`EhPanda-AltStorePAL-signature`, `EhPanda-AltStorePAL-647d58c8-9641-3e96-9f9f-cce15e24ce2c.ipa` and
`EhPanda-AltStorePAL-e02d8e15-2647-3a6b-928d-038446b3e5e1.ipa`, uploaded with the owner's go-ahead. Each URL in the
source was downloaded again without signing in: four 200s, and every SHA-256 equals the table above.

## Install test

The owner added the source from `develop` on an iPhone in AltStore PAL and installed EhPanda 3.0.0 (163): it worked.
So AltStore accepted the listed entitlements.

## Publication

- `develop`: `66219f291` (identifier) and `7f29c6b17` (`AltStorePAL.json`).
- `main`: the same two commits as `c1f2e6087` and `d651d9b2c`, through
  [EhPanda-Team/EhPanda#476](https://github.com/EhPanda-Team/EhPanda/pull/476), merged locally as `ec39cc9a8` with an
  owner bypass of the code-owner review (owner decision). The wider develop-to-main pull request #475 was withdrawn
  (owner decision): only the PAL source went to `main`.
- `https://ehpanda.app/AltStorePAL.json` returns 200 with the same bytes as `main`.

## First CI upload (DIST-18-03)

The first CI upload of a marketplace build with the `app-marketplace` secrets succeeded, so DIST-18-03 closes as the
2026-11-25 owner decision set out.

| | |
|---|---|
| Run | [45583656180](https://github.com/EhPanda-Team/EhPanda/actions/runs/45583656180), AltStore PAL upload (`marketplace-upload.yml`) |
| Trigger | push to `develop` at `33efae302`; the `app-marketplace` deployment approved on the owner's word |
| Build | `app.ehpanda.store` 3.1.0 (164), a test upload: no GitHub release, announcement or source change |
| Job | started 2026-11-25T12:11:37Z, done 12:27:46Z, every step green |
| Upload | `xcodebuild -exportArchive` reported "Upload succeeded" at 12:27:36Z; the package was processing |
| Call record | `asc-call-record-3.1.0-upload`: one call, `GET /v1/builds` 200 (the build-number check), key `86972AQ69S` |

The decision named "the first Deploy run whose `AltStorePAL` job" uploads. Since `3b64b957d` that job is
`marketplace-upload.yml`, which Deploy calls after a release and which also runs on each push to `develop` (owner
decision, 2026-11-25), so this push-started run of the same job counts.

**Observed, not part of the closing:** the export warned "Upload Symbols Failed" for `Sentry.framework`
(UUID `6C5F22F7-8C8A-3804-A52A-FC2CD9676BF1`): the archive has no dSYM for the Sentry SDK, which came in on
2026-11-23 after the last Classic deploy, so Classic releases will show the same warning. The app's own dSYMs went to
Sentry in the Upload dSYMs step.

**Build number 164 is used.** The 3.1.0 release needs 165 or later.

## Open

- **Closed (2026-11-21): `publish` follows the owner's rule.** `pal_publish.py publish` takes the version,
  build, bundle ID, minimum iOS version and Apple ID from `manifest.json` (which must list exactly the ADP's
  variants and name the marketplace ID), and the permissions from `--entitlements` and `--info-plist`, which
  `deploy-pal.yml` passes and `test_workflows.py` holds to `project.pbxproj`'s CODE_SIGN_ENTITLEMENTS and
  INFOPLIST_FILE. A usage description that names a build setting, or that two bundles word differently, is
  refused. The variants are never read, `codesign` is no longer used, and the ADP fixture has the real layout
  (opaque `variant/<publicId>.ipa`). Run on this ADP with `--dry-run`, it rebuilds `main`'s `AltStorePAL.json`
  byte for byte.
  *Amended 2026-11-21 (owner decision):* `publish-pal.yml` passes them now, and `publish` takes the version from the
  manifest instead of a `--version` input.
- **Install with `[]` not yet tried.** If AltStore refuses it, the rule needs another look.
- **DIST-18-03:** the D-21 answer needs a `deploy-pal.yml` `submit` run.
  *Amended 2026-11-21 (owner decision):* `deploy-pal.yml` is gone. Deploy's `AltStorePAL` job uploads the build only,
  and the collaborator creates the version, attaches the build and submits it by hand in App Store Connect. A run's
  call record can show which key uploaded the build; it cannot answer whether an App Manager key alone can create the
  version, attach the build and submit. DIST-18-03 stays Pending.
  *Closed 2026-11-25 (owner decision):* run 45583656180 uploaded 3.1.0 (164) with the
  `app-marketplace` secrets (see First CI upload). DIST-18-03 is Complete.
- **Not recorded:** the owner's copy-and-caption approval and the collaborator's App Store Connect entries (Task 3,
  steps 1 and 2).
