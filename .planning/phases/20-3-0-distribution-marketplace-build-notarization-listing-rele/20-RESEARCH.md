# Phase 20: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks - Research

**Researched:** 2026-11-09 (on `feature/gsd-phase-20` at `4efc14ce1`; external pages fetched the same day)
**Domain:** Xcode build flavors, privacy manifests, GitHub Actions release workflows, App Store Connect notarization,
AltStore PAL sources and ADPs, TelemetryDeck signal vocabulary
**Confidence:** HIGH for the repository facts and AltStore's documented source format; MEDIUM for the App Store
Connect API call sequence (documented, never run against this account); LOW for the ADP archive's exact on-disk
layout and for whether an accepted notarization version can take a new build (both confirmed at the first live
submission, 20-08).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- D-01 to D-22 in `20-CONTEXT.md`. The ones that shape the plans:
  - D-02: the marketplace build has the GitHub IPA's features and is listed on AltStore PAL only.
  - D-03 / D-19: no tag creation, removal, renaming or release order; the PAL job uploads the ADP's files to the
    GitHub release `deploy.yml` already made for the version, and fails when there is none.
  - D-07: every Apple-account action is the collaborator's, or the owner's explicit OK at that time.
  - D-12 amended: the PAL build is signed, so `package-channel.sh` cannot stamp it; the flavor sets the stamp at
    build time through a build setting.
  - D-14: plan order (a) to (h); only (f)'s two parts wait for Phase 19.
  - D-18: `PrivacyInfo.xcprivacy` in every build.
  - D-20: pipeline first; the final PAL submission contains (g) and passes (h).
  - D-21: the App Manager key test is recorded at the first submission.
  - D-22 (product lead msg 2775): the current icon stays everywhere; if the review rejects it under 2.3.8, step (c)
    pauses for a design request to Colo. **No icon task.**

### Claude's Discretion

- Required-reason codes and collected-data entries; the scheme, setting and workflow names; the PAL asset prefix.

### Deferred Ideas (OUT OF SCOPE)

- Hiding features in the marketplace build; a second marketplace; explore.alt.store discoverability.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIST-18-01 (flavor part) | Marketplace flavor with its own bundle IDs, unsigned IPA and local signing unchanged | §1, §2 |
| REL-18-01 | Build number above 158; history and download URL hold | §3 |
| DIST-18-02 | PAL source: `marketplaceID`, `nsfw: true`, ADP URLs, history | §4 |
| DIST-18-03 | Notarization CI, App Manager key test | §5, §6 |
| UGC-18-01 (contact part) | Published contact link before the build goes to Apple | §7 |
| DEV-18-01 | iPad Gallery Detail stall on Release; iPhone continued background downloads | §8 |
| MKT-18-01, CAP-17-05 | PAL store screenshots and listing assets from Phase 19's approved set | §9 |
| ANALYTICS-02 | Signals for the 3.0 flows within ANALYTICS-01's rules | §10 |
| (D-09) | Closing Release isolation scan | §11 |
</phase_requirements>

<research_summary>
## Summary

Most of the phase is plumbing around facts already in the repository: one unsigned build stamped per channel
(`package-channel.sh`), sources created from templates by their first run, a jq filter that keeps history, and a
build-number check that only the beta workflow runs. Five findings change the plan shape:

1. **The flavor needs one code change besides the xcconfig.** `GalleryURLParser.normalizedURL` accepts only the
   `ehpanda` and `ehpanda-beta` schemes (`AppTools/GalleryURLParser.swift:99`). A marketplace scheme must be added
   there with a test, or the marketplace share extension's hand-off is dropped. Nothing public links with
   `ehpanda://` (repository grep: tests only), so the flavor registers only its own scheme.
2. **The privacy manifest needs no project edit.** `App/` is a file-system synchronized group of the `EhPanda`
   target, so `App/PrivacyInfo.xcprivacy` becomes a resource of the app by being there. The app's own required-reason
   uses are `UserDefaults` (CA92.1) and file timestamps (C617.1: `contentModificationDateKey` in
   `PreviewImageView.swift` and `DownloadStore.swift`, `attributesOfItem(...)[.modificationDate]` in `DataCache.swift`
   and `DownloadStore.swift`).
3. **Notarization requires screenshots, a description, a support URL, a privacy policy URL and an age rating**
   (App Store Connect Help, "Required, localizable, and editable properties for Notarization": each is marked
   *Required*). Screenshots are not marked *Editable*, so they change only with a new submission. EhPanda is universal,
   so an iPad 13-inch set is needed too, and none exists. **The first submission therefore cannot happen before some
   all-ages iPhone and iPad screenshots exist.** Phase 19's approved set is (f)'s, so 20-08 opens with a decision:
   wait for (f), or submit first with an interim, undecorated all-ages set from the public synthetic fixtures (OQ-A).
4. **D-05 orders (d) before the first submission.** The contact link must be live "before the AltStore build goes to
   Apple", and the support URL is a required property. So (c) is split into the pipeline (20-04 submit, 20-05
   publish), account setup (20-06) and the first live submission (20-08), which also depends on the website check
   (20-07). The product lead's order is otherwise unchanged.
5. **An early submission may consume a version.** App Store Connect builds must have a new build number per upload,
   and an accepted version cannot normally take another build. D-20's early verdict is still possible if the version's
   release is set to manual and the version is developer-rejected before the final build, which is confirmed at the
   first submission; otherwise the final PAL build needs a new version number (OQ-B, owner decision at 20-08).

**Primary recommendation:** 14 plans in the fixed order, with (c) split into the submit pipeline, the publish
pipeline, account setup and the first submission, and (g) split into vocabulary sign-off and implementation.
The waves follow the fixed order (D-14), so the phase runs as 11 waves. 20-07 (website check), 20-09 (device checks)
and 20-12 (vocabulary sign-off) need no code from earlier steps and could run in wave 1 if the product lead allows
(OQ-G); the plans do not assume it.
</research_summary>

<architectural_responsibility_map>
## Architectural Responsibility Map

| Concern | Owner | Notes |
|---------|-------|-------|
| Flavor values (bundle suffix, name, scheme, stamp) | `Config/*.xcconfig` | `-xcconfig` applies to every target and package, below command-line settings |
| Channel stamp in Info.plist | `App/Info.plist` reading `$(EHPANDA_DISTRIBUTION_CHANNEL)` | `package-channel.sh` still overwrites it for unsigned copies |
| Hand-off scheme acceptance | `AppTools/GalleryURLParser.swift` | closed list of schemes |
| Required-reason declarations | `App/PrivacyInfo.xcprivacy` | dependencies ship their own |
| Release, beta, PAL publishing | `.github/workflows/*.yml` + `actions-tool/` | sources on `main`, never written with zero versions |
| Apple records, keys, agreements | collaborator's App Store Connect account | D-07; agents never create them |
| PAL processing and ADP download | AltStore REST API (`api.altstore.io`) | no account needed for `GET/POST /adps` |
| Website pages and redirects | Leto | D-05, D-10 |
| Signal vocabulary | `AnalyticsClient` (`AnalyticsSignal`, `+Level`, `+Rendering`, `AnalyticsVocabulary`) | exhaustive switches; levels are a copy contract |
</architectural_responsibility_map>

<standard_stack>
## Standard Stack

### Core

| Tool | Use | Why |
|------|-----|-----|
| `xcodebuild archive -xcconfig` | flavor builds | the beta's proven pattern (`deploy-beta.yml`) |
| `xcodebuild -exportArchive` with `ExportOptions.plist` (`method` `app-store-connect`, `destination` `upload`, `signingStyle` `manual`) and `-authenticationKeyPath/-ID/-IssuerID` | signed export and upload | Apple's supported upload path; no altool |
| App Store Connect API v1 (JWT ES256, 20-minute tokens) | builds, versions (`reviewType: NOTARIZATION`), review submissions, ADP ID | D-21; OpenAPI 4.6 |
| `openssl dgst -sha256 -sign` (runner's LibreSSL/OpenSSL) + Python stdlib | JWT signing without third-party Python packages | DER-to-raw `r‖s` conversion is 20 lines; tested offline with a generated P-256 key |
| AltStore REST API | `POST /adps {adpID}`, `GET /adps/<id>` → `downloadURL` | AltStore, "REST API" |
| `gh release upload` / `gh api` | ADP files as release assets; release lookup by tag | D-19; never creates a release |
| `jq` + `actions-tool/altstore-add-version.jq` | PAL version entries | extend, do not fork (CONTEXT defaults) |
| Python `unittest` in `actions-tool/tests/` | all tool tests, fakes for both APIs | existing suite: 45 tests, 0.18 s |
| `Scripts/visual/verify-release.py` | closing scan | D-09 |

### Alternatives Considered

| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| openssl-signed JWT | `pip install pyjwt[crypto]` | a network dependency in a release job with signing secrets; rejected |
| `-exportArchive` upload | `xcrun altool --upload-app` | still works for iOS but is Apple's legacy path; rejected |
| Automatic signing with `-allowProvisioningUpdates` | — | can create certificates and profiles in the collaborator's account on its own: violates D-07; rejected |
| Running Phase 19's gate inside `deploy.yml` | require the gate's `aggregate` check to have passed on the PR head | the gate takes 2 to 3 hours; reading its verdict is the reliance (20-11) |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### §1 Marketplace flavor

```
Config/Flavor.xcconfig        EHPANDA_DISTRIBUTION_CHANNEL = source   (new default)
Config/Marketplace.xcconfig   BUNDLE_ID_SUFFIX = .marketplace
                              EHPANDA_DISPLAY_NAME = EhPanda
                              EHPANDA_URL_SCHEME = ehpanda-marketplace
                              EHPANDA_DISTRIBUTION_CHANNEL = altstorePAL
App/Info.plist                <key>EhPandaDistributionChannel</key><string>$(EHPANDA_DISTRIBUTION_CHANNEL)</string>
```

- `Signing.xcconfig` includes `Flavor.xcconfig`, so every build, test and package target sees the default.
- `Beta.xcconfig` needs no stamp line: `deploy-beta.yml` stamps `beta` with `package-channel.sh`, and the default
  `source` is what that script overwrites. Adding `EHPANDA_DISTRIBUTION_CHANNEL = beta` there would also be correct;
  leave it out so the beta's path is untouched.
- `package-channel.sh` refuses signed apps and checks the key exists; the resolved `source` keeps it working.
- `verify-release.py` forbids the bytes `EHPANDA_` in the shipped bundle. Build settings are resolved at build time,
  as `EHPANDA_URL_SCHEME` already is, so the literal never ships; 20-01's check asserts it on the built plist.
- No compilation condition, no icon setting (D-02, D-22).

### §2 Privacy manifest (D-18)

```xml
NSPrivacyTracking false; NSPrivacyTrackingDomains []
NSPrivacyAccessedAPITypes:
  NSPrivacyAccessedAPICategoryUserDefaults   [CA92.1]
  NSPrivacyAccessedAPICategoryFileTimestamp  [C617.1]
NSPrivacyCollectedDataTypes (Linked false, Tracking false, Purposes [Analytics]):
  NSPrivacyCollectedDataTypeProductInteraction   (screens and features; Basic and Full)
  NSPrivacyCollectedDataTypeDeviceID             (install identifier; TelemetryDeck's hashed ID)
  NSPrivacyCollectedDataTypeOtherDiagnosticData  (kinds of errors; Basic and Full)
```

- TelemetryDeck's own manifest (SwiftSDK checkout) declares `ProductInteraction` and `DeviceID`, Analytics, not
  linked, no tracking, and `UserDefaults` CA92.1. The app adds `OtherDiagnosticData` because it sends error kinds.
- Not declared: disk space, boot time, active keyboards (no use found by grep of `AppPackage/Sources`, `App`,
  `ShareExtension`). The share extension uses no required-reason API, so it gets no manifest.
- Verification: Xcode's privacy report needs an archive (Organizer → Generate Privacy Report). Without a signed
  archive, 20-01 checks the file is in the built `.app`, lints it with `plutil -lint`, and a unit test parses it
  and compares its categories against the grep result. The App Store Connect upload (20-08) is the real check.

### §3 Release mechanics (REL-18-01)

- `deploy.yml` (PR merge to `main`) has no build-number check. Add one before the tests, against `AltStore.json`,
  `SideStore.json` and `altstore-beta.json` from `origin/main`, with the same script; not against `AltStorePAL.json`,
  because a PAL build legitimately shares its version and build with the Classic release of the same commit.
- `CURRENT_PROJECT_VERSION = 158` in four targets; 2.8.1 and the published 3.0.0 beta used 158. Bump with
  `Scripts/bump-version.sh -v 3.0.0 -b <n>` where `n` is one above the highest build on `origin/main`'s sources at
  execution time (at least 159). Local `origin/main` is stale (July 2026): fetch first.
- History: `altstore-add-version.jq` keeps it (`be6614cc6`); `test_altstore_add_version.py` covers it. Download
  URLs: taken from `steps.release.outputs.assets` and checked with `curl -sSfIL` (`b10372a3b`). 20-02 adds
  workflow-shape tests that fail if either step is removed.
- `ReleaseNotes/3.0.0.md` does not exist; the 3.0.0 release PR fails its notes check until it does. Writing the
  notes is not a Phase 20 task (owner content); 20-02 records the dependency.
- The seven screenshot URLs point at `EhPanda-Team/ehpanda-assets`, a local-only repository (`d69b30a`); the
  owner's OK creates and pushes it (D-17, checkpoint in 20-02).

### §4 PAL source (DIST-18-02)

AltStore, "Make a Source" (read 2026-11-09):

- `marketplaceID` (string): the app's Apple ID from App Store Connect; required for PAL.
- Version `downloadURL`: "the URL of the `manifest.json` in your uploaded ADP"; `size`: "any of the variants";
  `assetURLs`: keys are ADP file names without extensions, values their URLs — "This allows you to host ADPs using
  GitHub Releases!" Example keys: `manifest`, `signature`, `<variant-uuid>`.
- `appPermissions.entitlements` must list every entitlement except `application-identifier` and
  `com.apple.developer.team-identifier`; `privacy` every `UsageDescription` key. AltStore refuses mismatches. The
  signed PAL build's entitlements differ from `AltStore.json`'s (`beta-reports-active`, `get-task-allow`,
  `keychain-access-groups`, from old ad-hoc builds), so they are read with `codesign -d --entitlements :-` from the
  signed app and **replace** the template's, rather than being merged as the filter does today.
- Screenshots: a plain URL list is iPhone 9:19.5; iPad entries need explicit `width`/`height` (step (f)).
- Updating (AltStore, "Updating Apps"): AltStore offers the first compatible entry of `versions`; each entry needs a
  distinct `version` or `buildVersion`; dates are not used.

Filter extension (backward compatible; every existing call passes neither new argument):

```jq
($ARGS.named.assetURLs // null) as $assetURLs     # object of non-empty https strings, must contain "manifest"
($ARGS.named.entitlements // null) as $entitlements
# PAL entry: downloadURL == $assetURLs.manifest, no sha256, + assetURLs
# entitlements given → replace; otherwise keep (unchanged behaviour)
# marketplaceID given → set when empty, error when different
```

`check_source` grows a `pal=True` mode: `marketplaceID` non-empty digits, `nsfw` true, every version has
`assetURLs.manifest == downloadURL`, no `sha256`, and no Classic-only field.

### §5 Notarization pipeline (DIST-18-03)

```
workflow_dispatch(version) ── environment: pal-notarization (required reviewer) ──┐
 submit job                                                                          │
   check build number vs AltStorePAL.json on main + ASC builds of this version        │
   archive -xcconfig $RUNNER_TEMP/marketplace-signing.xcconfig (includes Marketplace)  │
   verify flavor (bundle IDs, name, scheme, stamp altstorePAL, PrivacyInfo present)   │
   export + upload (ExportOptions: app-store-connect, upload, manual, profiles map)   │
   asc.py wait-build → ensure-version(reviewType NOTARIZATION) → attach build        │
         → review submission + item → submit; record key test (D-21)                 │
 publish job (re-dispatchable with publish-only)                                      │
   asc.py adp-id → pal_publish.py process (POST /adps) → wait downloadURL              │
   download ADP unchanged → verify manifest bytes and file hashes                     │
   gh release view <version> (fail if absent) → upload EhPanda-AltStorePAL-* assets   │
   assetURLs from the upload result → filter → AltStorePAL.json on main (retry loop)  ┘
```

- **Signing without per-target command-line settings.** `-xcconfig` is one file and applies to every target, so the
  job writes a temporary xcconfig: `#include "<repo>/Config/Marketplace.xcconfig"`, `DEVELOPMENT_TEAM`,
  `CODE_SIGN_STYLE = Manual`, `CODE_SIGN_IDENTITY = Apple Distribution`, and
  `PROVISIONING_PROFILE_SPECIFIER = $(EHPANDA_PROFILE_$(TARGET_NAME))` with `EHPANDA_PROFILE_EhPanda` and
  `EHPANDA_PROFILE_ShareExtension` set from secrets. Nested expansion selects a profile per target; package targets
  expand to empty. Checked offline with `xcodebuild -showBuildSettings` for both targets (20-04). The keychain is a
  temporary one, deleted in an `always()` step.
- **API sequence** (OpenAPI 4.6; CONTEXT D-21): `GET /v1/builds?filter[app]&filter[version]&filter[preReleaseVersion.version]`
  until `processingState == VALID`; `GET/POST /v1/appStoreVersions` (`platform IOS`, `versionString`,
  `reviewType NOTARIZATION`, release type `MANUAL` — see OQ-B); `PATCH .../relationships/build`;
  `POST /v1/reviewSubmissions` + `POST /v1/reviewSubmissionItems`; `PATCH /v1/reviewSubmissions/{id}`
  `submitted: true`; later `GET /v1/appStoreVersions/{id}/alternativeDistributionPackage`. Every call is logged with
  method, path and status only (never the token), so the D-21 record falls out of the log.
- **Export compliance.** `ITSAppUsesNonExemptEncryption` is already in `App/Info.plist`; no prompt.
- **AltStore processing.** If marketplace notifications are on, AltStore processes the ADP itself; `POST /adps` is
  harmless when it already has. Poll `GET /adps/<id>` with a bounded wait and a clear timeout message.
- **ADP layout is unverified.** Apple's ADP is a package with `manifest.json`, `signature` and per-variant IPAs.
  Whether AltStore's `downloadURL` serves a zip or a folder listing is first seen at 20-08. `pal_publish.py` accepts
  a zip or a directory, maps files by name without extension, and refuses anything else; 20-08 records the real
  layout and adjusts the fixture if it differs.
- **Never reformat `manifest.json`**: hashes of the downloaded and uploaded bytes are compared, and the uploaded
  asset is re-downloaded and compared once more.

### §6 Account setup facts (D-07, D-21)

- Roles: submit for notarization — Account Holder, Admin or App Manager; read the ADP ID — Account Holder, Admin,
  App Manager or Marketing; add a marketplace — Account Holder or Admin, web UI only; DPLA — Account Holder.
- AltStore registration: `POST https://api.altstore.io/register {developerID, email}` returns a token for Users and
  Access → Integrations → Marketplace. This uses the collaborator's Developer ID and email, so it is the
  collaborator's action (or the owner's OK) like any other account step.
- Countries: AltStore PAL serves the EU, Japan and Brazil.
- Secrets live only in a protected environment with a required reviewer: `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_KEY_P8`, `DIST_CERT_P12`, `DIST_CERT_PASSWORD`, `PROFILE_APP`, `PROFILE_SHARE_EXTENSION`, `TEAM_ID`, and the
  variable `PAL_MARKETPLACE_ID` (names are 20-04's to fix).

### Anti-Patterns to Avoid

- Stamping the signed PAL app with `package-channel.sh` (breaks the signature; the script refuses anyway).
- Writing `AltStorePAL.json` with zero versions, or before the ADP's assets resolve.
- Merging stale Classic entitlements into the PAL source.
- Any step that creates a tag, release, App ID, certificate, profile or key.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't build | Use instead |
|---------|-------------|-------------|
| Version history and replacement rules | a PAL-only filter | `altstore-add-version.jq` with two optional arguments |
| Build-number comparison | a second checker | `check-build-number.sh` |
| Release notes per language | new text | `release_notes.py english/altstore` |
| Upload to App Store Connect | REST upload of the IPA | `xcodebuild -exportArchive` with `destination upload` |
| Release scan | a new scanner | `Scripts/visual/verify-release.py` |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

1. **Required notarization metadata** (§ summary 3): no screenshots or support URL, no submission. 20-08 starts by
   confirming every required property is filled.
2. **Build numbers are single-use in App Store Connect.** The early upload consumes one; the final upload needs a
   higher one, and the Classic release of the same commit carries it too. The submit job checks App Store Connect's
   existing builds for the version before archiving.
3. **An accepted version may not take a new build** (OQ-B). Set the version's release to manual before submitting
   and confirm at the first acceptance whether "Developer Reject" is offered for a notarized version.
4. **`AltStorePAL.json` and the Classic check.** Do not add the PAL source to `deploy.yml`'s check (§3).
5. **Snapshot gate not on this branch.** `snapshot-gate.yml` is Phase 19's (19-10), on `feature/gsd-phase-19`.
   20-11 needs Phase 19 merged into this branch or into `main` first; this branch never touches the Phase 19 branch.
6. **The beta's scheme list.** Adding the marketplace scheme to `GalleryURLParser` without a test lets a later edit
   drop it silently.
7. **Interim screenshot wording.** The current decorated set's first picture says "Over a million adult comics and
   doujinshi" (D-04 amended); it is not a safe interim set for Apple's 4+ rule on screenshots.
8. **ROADMAP SC8 is outdated.** "Nothing is sent under None": there is no None level since Phase 18; nothing is sent
   before a level is chosen. Flagged for the product lead at 20-12; the plans test the current rule.
9. **Phase 19's approved references are 1x** (Phase 19 D-10), far below App Store Connect's sizes. Store pictures
   are rendered from the same approved scenarios at native scale, and the same run's 1x render must equal the
   approved reference, which ties each store picture to the approved state (20-10).
</common_pitfalls>

<code_examples>
## Code Examples

JWT for App Store Connect without third-party packages (verified pattern; test with a generated key):

```python
header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
claims = {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
signing_input = b64url(json(header)) + "." + b64url(json(claims))
der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input, capture_output=True).stdout
r, s = parse_der_ecdsa(der)                 # SEQUENCE { INTEGER r, INTEGER s }
token = signing_input + "." + b64url(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
```

PAL version entry the filter writes:

```json
{"version": "3.0.0", "buildVersion": "160", "marketingVersion": "3.0.0", "date": "…",
 "localizedDescription": "…", "localizedDescriptions": {"en": "…"},
 "downloadURL": "https://github.com/EhPanda-Team/EhPanda/releases/download/3.0.0/EhPanda-AltStorePAL-manifest.json",
 "assetURLs": {"manifest": "…manifest.json", "signature": "…signature", "<uuid>": "…<uuid>.ipa"},
 "size": 12345678, "minOSVersion": "27.0"}
```
</code_examples>

<sota_updates>
## State of the Art (2026)

- Apple's EU terms changed on 1 Oct 2026 (DPLA Attachment 14; 5% CTC on digital-goods sales). EhPanda sells nothing.
- AltStore PAL serves the EU, Japan and Brazil; AltStore charges developers 0%.
- AltStore's docs now state `assetURLs` for GitHub-release hosting, so no separate web host is needed.
</sota_updates>

### §7 Website dependencies (UGC-18-01 contact part)

- In-app privacy link: `contact.privacy_policy` = `https://ehpanda.app/privacy` (`Constant.xcstrings`), shown in the
  analytics choice and Settings → General. It must resolve before the submission.
- Needed from Leto: the privacy policy URL (same), a support URL, the published contact link (GitHub Issues), and a
  public URL for `AltStorePAL.json` (an `ehpanda.app` redirect to `raw.githubusercontent.com/.../main/AltStorePAL.json`,
  like `AltStore.json`'s).
- `ehpanda.app` did not resolve from this machine during research (curl exit 6); 20-07 checks from the executing
  machine and, if DNS fails there too, from a GitHub-hosted run or the owner's browser.
- "Apple-approved" wording: 20-07 greps the repository and the website pages it fetches.

### §8 Real-device checks (DEV-18-01)

- iPad: Phase 16's cold Gallery Detail stall was seen on iPadOS 27 beta simulators (~100% CPU in SwiftUI layout;
  `quick/260921-f5u…/260921-f5u-VERIFICATION.md`). The check is a Release build on the owner's iPad: ten cold
  launches, each opening a gallery's detail from Home, with a 30-second ceiling; a sample on any stall.
- iPhone: Phase 15 SC2's procedure (`15-VERIFICATION.md` human test): queue at least two galleries including a
  repair, start in the foreground, background the app, watch the system card, cancel from the card, foreground and
  compare. Phase 15 passed on device on 2026-08-19; this re-checks on the 3.0 build.
- Both need the owner's hardware and his signing (`Config/LocalSigning.xcconfig`), so the plan is a checkpoint.
  Anything that reproduces becomes a gap-closure plan, not a fix inside 20-09.

### §9 PAL listing (MKT-18-01, CAP-17-05)

- App Store Connect classes: iPhone 6.9" (1320 x 2868 or 1290 x 2796 or 1260 x 2736) and iPad 13" (2064 x 2752 or
  2048 x 2732) cover every smaller class by scaling. The existing 1260 x 2736 set is in the 6.9" class (D-04).
- Source screenshots for PAL: `{"iphone": [...], "ipad": [{imageURL, width, height}]}` from
  `EhPanda-Team/ehpanda-assets`; `check_screenshots` already supports both devices.
- Content: Phase 19's approved reference set is synthetic (`PublicVisualFixtures`, `FixtureArtwork`), so it is
  all-ages by construction; who decorates and which screens are the owner's (step (f) checkpoint).
- The PAL `subtitle` and ASC description wording ("adult comics") are a product-lead question at the same checkpoint
  (2.3.8 covers icons, screenshots and previews; AltStore guideline 2 requires accuracy).

### §10 Analytics revision (ANALYTICS-02)

Current vocabulary (`AnalyticsSignal`): navigation, search, reading, downloads, errors; level map in
`AnalyticsSignal+Level.swift` with an exhaustive switch; one name-minting file (`+Rendering`); the install signal
already carries `App.distributionChannel` at every level (D-06 amended).

Candidate additions, for sign-off (20-12), all Basic ("which screens and features you use"), with closed-enum values
only:

| Flow | Candidate signal | Parameters |
|------|------------------|------------|
| First launch | `firstLaunchCompleted` | `FirstLaunch.kind`: `newInstall` / `upgrade` (sent after the choice, only at Basic or Full) |
| Analytics choice | `analyticsLevelChanged` | `Analytics.from`, `Analytics.to` (sent at the new level, only if Basic or Full) |
| Report form | `commentReportSent` | `Report.reason`: `child` / `other`; `Report.outcome`: `sent` / `unavailable` / `reportPageOpened` |
| Blocking | `commentPosterBlocked`, `commentPosterUnblocked`, `blockedCommentShown` | none |
| Posting filter | `commentPostingWarningShown` | `Comment.choice`: `edit` / `postAnyway` |
| Marketplace build | none new | the channel is already in the install signal; optional default parameter `App.distributionChannel` on Basic and Full events (decision) |

All fit the approved Basic description; none needs the copy to change. README's Basic list names examples, so the
new flows are added there and in the five `READMEs/` translations (`18-copy-check.py --readmes` checks them).

**Carried from Phase 18 (18-03-SUMMARY, 18-RESEARCH OI-4):** at Basic and Full, one install arrives twice: the SDK's
own `TelemetryDeck.Acquisition.newInstallDetected` (SwiftSDK `SessionManager.startNewSession`, on the first session)
and EhPanda's `App.installed`. 18-RESEARCH recommends counting `App.installed` on the dashboard. Options for the
sign-off: A (recommended) keep both and document in COVERAGE.md and the README that `App.installed` is the install
count, because it is the only one sent at every level; B suppress the SDK's signal, which the SDK offers no
configuration for, so it would need filtering in `TelemetrySDK.swift` and a test. The other carried item, "verify the
install source on the marketplace build", now means the channel stamp: 20-01 checks it in the built plist, and the
installed PAL build's dashboard value can only be seen after a live PAL install, which is release order (20-14
lists it).

### §11 Closing scan (D-09)

`Scripts/visual/README.md` "Release isolation": Release simulator build with `CODE_SIGN_IDENTITY=-
CLANG_COVERAGE_MAPPING=NO LD_GENERATE_MAP_FILE=YES`, then `verify-release.py --app --build-log --link-map ...
--output [--device --debug-control]`. Run it twice: default flavor and `-xcconfig Config/Marketplace.xcconfig`,
since the PAL build is a distinct build.

<open_questions>
## Open Questions

- **OQ-A (product lead/owner, at 20-08):** Screenshots for the first notarization submission. A: wait for step (f)'s
  set (the first verdict comes after Phase 19). B (recommended): an interim, undecorated, all-ages set captured from
  the public synthetic fixtures on an iPhone 6.9" and an iPad 13" simulator, replaced by (f)'s set in the final
  submission.
- **OQ-B (owner, at 20-08):** If a notarized version cannot be developer-rejected after acceptance, does the early
  submission use 3.0.0 (and the final PAL build a later version), or does the first submission wait for the final
  build? Recommended: set manual release, and ask only if App Store Connect does not offer Developer Reject.
- **OQ-C (product lead, at 20-03 or 20-06):** The PAL source's `developerName`. "EhPanda Team" today; the install
  sheet shows the collaborator's account name. AltStore guideline 2 and Apple 5.6.2 require accuracy. Recommended:
  ask the collaborator how the account's developer name reads and use it, or "EhPanda Team" if the account's name
  is EhPanda's.
- **OQ-D (product lead, at 20-10):** PAL subtitle and ASC description wording for an all-ages listing.
- **OQ-E (product lead/owner, at 20-12):** the signal vocabulary in §10, and whether the channel becomes a default
  parameter on Basic and Full events; and the ROADMAP SC8 wording.
- **OQ-F (owner, at 20-11):** how Phase 19's `snapshot-gate.yml` reaches this branch (merge Phase 19 into `main`
  first, or merge `feature/gsd-phase-19` into this branch with his OK).
- **OQ-G (product lead, before execution):** may 20-07, 20-09 and 20-12 start in wave 1, ahead of the fixed order?
  Recommended: yes, since none needs code from an earlier step; the plans keep the fixed order until told.
</open_questions>

## Validation Architecture

| Property | Value |
|----------|-------|
| Frameworks | Python `unittest` (`actions-tool/tests`), Swift Testing (FeatureTests), `plutil -lint`, `actionlint` if installed (else a YAML parse test) |
| Quick run | `cd actions-tool && python3 -m unittest discover -s tests -q` (< 5 s) |
| Swift run | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE" -only-testing:<Target>` |
| Lint | `swiftlint lint --strict --no-cache --config .swiftlint.yml <paths>` → 0 violations |
| Build checks | `xcodebuild archive ... CODE_SIGNING_ALLOWED=NO` with and without `-xcconfig Config/Marketplace.xcconfig`, then `plutil -extract` of bundle ID, scheme, stamp, and the manifest's presence |
| Live checks | only at checkpoints: App Store Connect, AltStore API, GitHub release uploads, website URLs |
| Devices | `EhPanda iPhone Air` (`$PHONE`), `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), resolved by name; one `xcodebuild` at a time |

Every automated requirement maps to a test that fails before the change: scheme acceptance
(`GalleryURLParserTests`), manifest categories (`test_privacy_manifest.py`), workflow shape
(`test_workflows.py`), filter PAL mode (`test_altstore_add_version.py`), PAL template and checks
(`test_source_templates.py`), JWT and API sequence against fakes (`test_asc.py`), ADP publish against a fake
release (`test_pal_publish.py`), signal levels and rendering (`AnalyticsClientTests`).

## Sources

- Repository: files named above, at `4efc14ce1`.
- AltStore: Make a Source; Distribute with AltStore PAL; REST API; Updating Apps; App Guidelines (faq.altstore.io,
  fetched 2026-11-09).
- Apple: Submit for Notarization (required-properties table: Screenshots, Description, Support URL, Privacy Policy
  URL and Rating marked Required; Screenshots not Editable), fetched 2026-11-09; the other Apple pages in CONTEXT's
  canonical references.
- TelemetryDeck SwiftSDK `Sources/TelemetryDeck/PrivacyInfo.xcprivacy` (local package checkout).
</content>
