---
phase: "17"
slug: "localized-screenshot-capture-harness"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
open_total: 0
below_threshold_open: 0
accepted: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: "2026-11-05"
audited: "2026-11-05"
audited_source: 504fa50ac
---

# Phase 17 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Reduced scope (owner msg 1305, 2026-11-03). The register is the `<threat_model>` of the plans this phase
still owns: 17-01 to 17-06, 17-24, 17-14 (T2), 17-16 to 17-19 and 17-23. Plans 17-07 to 17-13, 17-15
and 17-20 to 17-22 moved to Phase 18 and are not audited here. No kept SUMMARY has a `## Threat Flags`
section.

The audit was static. It read the code at `504fa50ac` and ran no build, test plan or simulator. The only
command run against the source was `Scripts/check-cookie-logging.sh`, a text scan (exit 0, "Cookie
logging audit passed."). The built source the phase closes on is `891103afa`; `git diff 891103afa
504fa50ac` touches only `.planning/`, so the Release evidence recorded at `891103afa` covers this HEAD.
Every mitigation below was checked in the code or the tracked artifact itself, not only in the
phase records.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Capture configuration and fixtures to a capture launch | DEBUG-only launch keys and a fixture version directory decide what a capture shows | Launch environment, fixture manifests, saved responses and images (public gallery content) |
| Gallery site to the local fixture | Anonymous acquisition writes a versioned, checksummed, scrubbed fixture | Saved HTML and image bytes; access values on the pages |
| Debug capture code to the Release build | Release must contain no capture or test code and ignore capture keys | Compiled code, payload files, linked libraries |
| Simulator observations to tracked metadata | The rendering pin is tracked; device IDs and local paths stay in run-only output | Rendering characteristics, simulator UDIDs |
| Generated results and landed source to the verification record | Records describe HEAD as read and tested, never intent | Commit IDs, result counts, owner decisions |
| Verification evidence to owner decisions | Evidence never implies owner acceptance | Owner message IDs and dates |

---

## Threat Register

| Plan | Threat ID | Category | Component | Severity | Disposition | Mitigation (evidence in code or tracked artifact) | Status |
|---|---|---|---|---|---|---|---|
| 17-01 | T-17-01-T | Tampering | Input/result artifacts | high | mitigate | Public fixture export records size and SHA-256 per file (`VisualSnapshotSupport/PublicVisualFixtures.swift:184`, `:254`); the full-content gate hashes every source, including untracked files, so source drift is detected (`Scripts/verify-full-content-capture.py:40-41`). | closed |
| 17-01 | T-17-01-I | Information disclosure | Logs/images/payload | high | mitigate | Public test data is synthetic; real marketing data is only under the git-ignored `/.capture/` (`.gitignore`). `VisualSnapshotSupport` links only into the `VisualSnapshotTests` target (`project.pbxproj`), not the app. No screenshot or real gallery image is tracked (images added since phase 16: two app-icon JPGs and one UI-test fixture). | closed |
| 17-01 | T-17-01-R | Repudiation | Review evidence | medium | mitigate | Gate records keep run, environment and coordinate identity (17-01-*-GATE.md, `*-RED.json`). All 20 commits cited in 17-01-SUMMARY are ancestors of HEAD. | closed |
| 17-02 | T-17-02-T | Tampering | Input/result artifacts | high | mitigate | Two-pass same-rect read comparison and the rendering pin that includes Reduce Motion (`Scripts/visual/regression-environment.json`); `environment.py` rejects any field, length or value that differs from the pin (`EnvironmentMismatch`, `:25-145`). | closed |
| 17-02 | T-17-02-I | Information disclosure | Logs/images/payload | high | mitigate | Same isolation as T-17-01-I; tracer evidence stays in local result bundles. No credential, LAN address or local user path in tracked Phase 17 code or fixtures (repository scan at HEAD). | closed |
| 17-02 | T-17-02-R | Repudiation | Review evidence | medium | mitigate | Owner decisions in 17-02-SUMMARY carry dates; all 8 cited commits are ancestors of HEAD. | closed |
| 17-03 | T-17-03-T | Tampering | Input/result artifacts | high | mitigate | `fixtures.py` validation repeats the acquisition derivation; it rejects checksum or length mismatch, unlisted or missing files, unscrubbed stored pages and an aggregate digest or version mismatch (`fixtures.py:640-705`). Publication uses one writer and an atomic rename. | closed |
| 17-03 | T-17-03-I | Information disclosure | Logs/images/payload | high | mitigate | Acquisition is anonymous. It sends only `nw=1` to the gallery host (`acquire-fixtures.py:31-36`), refuses redirects (`:24-28`), and allows https only, no URL credentials, and only the gallery, image and H@H hosts (`fixtures.py:215-228`). Pages that show an account session fail (`SESSION`, `fixtures.py:69`, `:509-510`), and access values are zeroed (`SECRETS`, `:59-67`). Error text is scrubbed (`acquire-fixtures.py:74`). | closed |
| 17-03 | T-17-03-R | Repudiation | Review evidence | medium | mitigate | Versions are content-addressed over the selection and asset entries; the manifest keeps `retrievedAt`, generator sources and selection authority (`MANIFEST_KEYS`, `ENTRY_KEYS`). | closed |
| 17-04 | T-17-04-T | Tampering | Input/result artifacts | high | mitigate | `CaptureFixtureManifest.verifiedFiles` rejects unsafe or duplicate paths, unexpected or missing files, size and SHA-256 mismatch (`:325-355`). It checks the aggregate digest and version identity (`:205-229`) and refuses a symlinked directory (`requireRealDirectory`). A capture launch with any extra `EHPANDA_` key fails (`CaptureScenePreparation.swift:111-123`), and any failed check ends the launch (`UITestAutomation.swift`, `fatalError` before app state). | closed |
| 17-04 | T-17-04-I | Information disclosure | Logs/images/payload | high | mitigate | Every capture source file is wholly `#if DEBUG` (`AppFeature/UITestSupport/Capture*.swift`, `UITestStubURLProtocol.swift`, `AppshotCapture.swift`); `CaptureDiagnostics.swift` has only two imports outside its DEBUG block. `AppLaunchAutomation.current` and `resolve` return `nil` outside DEBUG (`AppLaunchAutomation.swift:62-68`, `:123-127`). | closed |
| 17-04 | T-17-04-R | Repudiation | Review evidence | medium | mitigate | Diagnostics carry screen, selection, fixture version, galleries and readiness (`CaptureDiagnostics.swift:53-106`); the 9 cited commits are ancestors of HEAD. | closed |
| 17-05 | T-17-05-T | Tampering | Input/result artifacts | high | mitigate | `capture-native.py` validates the pin, hashes producers, and accepts a frame only when every cold launch records the same bytes (`:23`, `:39`, `:72`). | closed |
| 17-05 | T-17-05-I | Information disclosure | Logs/images/payload | high | mitigate | Run reports with simulator UDIDs are written only to the local output (`capture-native.py:334-339`), under the git-ignored `/.capture/`. Routes run only from a DEBUG capture scene. The only producer of `captureRoute` is `CaptureScenePreparation.swift:255`, and the live client returns `nil` in Release. | closed |
| 17-05 | T-17-05-R | Repudiation | Review evidence | medium | mitigate | Per-coordinate run reports keep device, model and runtime build; the 18 cited commits are ancestors of HEAD. | closed |
| 17-06 | T-17-06-T | Tampering | Input/result artifacts | high | mitigate | Live Text records are validated against the page SHA-256, gallery, page and languages (`fixtures.py:561`, `:701`; `CaptureScenePreparation.swift:428-449`). Download seeding checks status order and page counts (`:474-527`). | closed |
| 17-06 | T-17-06-I | Information disclosure | Logs/images/payload | high | mitigate | The Live Text seam is DEBUG-only (`LiveTextCapture.swift`, `LiveTextCaptureTranslation.swift` wholly `#if DEBUG`; `LiveTextHandler.swift:41-45` gated). Records leave through diagnostics, not logs. `check-cookie-logging.sh` passes. | closed |
| 17-06 | T-17-06-R | Repudiation | Review evidence | medium | mitigate | Records keep `recordedOn` (model and runtime build only, no device ID) and the page digest; the 6 cited commits are ancestors of HEAD. | closed |
| 17-24 | T-17-24-T | Tampering | environment.py/pin | high | mitigate | Every pinned characteristic is compared, and any mismatch raises `EnvironmentMismatch`. The pin bytes are read, hashed and checked unchanged after validation (`environment.py:308-328`); `test_environment.py:219-269` (`ImmutableValidationTests`) pins this. | closed |
| 17-24 | T-17-24-I | Information disclosure | tracked rendering metadata | medium | mitigate | `regression-environment.json` holds rendering fields only. A scan for UDID-shaped values, `udid` keys and user paths found none. UDIDs stay in run-only `destinations` (`environment.py:260`). | closed |
| 17-24 | T-17-24-R | Repudiation | measurement evidence | medium | mitigate | Reports keep per-destination measurements and the pin SHA-256 (`environment.py:328`); the 5 cited commits are ancestors of HEAD. | closed |
| 17-14 | T-17-14-T | Tampering | Input/result artifacts | high | mitigate | `verify-release.py` fails on a build log that is not exclusively a Release simulator build, an empty link map, an instrumented or DEBUG-defining compile, and a Debug control that survives the probe (`:153-177`, `:245-255`). `test_release.py` has a seeded bad payload. The scanner is unchanged since `7af68d0e6`. | closed |
| 17-14 | T-17-14-I | Information disclosure | Logs/images/payload (Release isolation) | high | mitigate | In code: Release reads no capture key. `AppDelegate.init` calls `UITestAutomation.prepare` only under `#if DEBUG` (`AppDelegateReducer.swift:56-64`); `prepareIfNeeded` is empty and `shouldDetectClipboardURL` is `false` outside DEBUG (`UITestAutomation.swift:22-34`); `AppInfo.isTesting` is `false` in Release; RootView's capture branch is `#if DEBUG` (`RootView.swift:27-50`). No `EHPANDA_` or `APPSHOT_` key is read outside DEBUG files. Recorded run: the Release scan at `891103afa` passed with 0 findings, and the launch probe kept Release running with every capture key set while the Debug control ended (17-FINAL-VALIDATION §9 row 6). IN-02 (scanner token gap) is below. | closed |
| 17-14 | T-17-14-R | Repudiation | Review evidence | medium | mitigate | 17-RELEASE-ISOLATION.md keeps both runs, including the failed first run; all 24 commits cited in 17-14-SUMMARY are ancestors of HEAD. | closed |
| 17-16 | T-17-16-T | Tampering | Verification record | high | mitigate | Layout audit rows cite file:line and commits; all 3 cited in the SUMMARY and all 11 in 17-LAYOUT-AUDIT.md are ancestors of HEAD (`git merge-base --is-ancestor`, rechecked). | closed |
| 17-16 | T-17-16-I | Information disclosure | Logs/screenshots | medium | mitigate | No screenshot is tracked; result bundles stay local. No credential or LAN address in tracked files. | closed |
| 17-16 | T-17-16-R | Repudiation | Owner decisions | medium | mitigate | Owner requests are recorded with dates (17-16-SUMMARY, 2026-11-03). | closed |
| 17-17 | T-17-17-T | Tampering | Verification record | high | mitigate | The cited commit is an ancestor of HEAD. | closed |
| 17-17 | T-17-17-I | Information disclosure | Logs/screenshots | medium | mitigate | As T-17-16-I. | closed |
| 17-17 | T-17-17-R | Repudiation | Owner decisions | medium | mitigate | Observations are recorded as observations, with no inferred approval. | closed |
| 17-18 | T-17-18-T | Tampering | Verification record | high | mitigate | The cited commit is an ancestor of HEAD. | closed |
| 17-18 | T-17-18-I | Information disclosure | Logs/screenshots | medium | mitigate | As T-17-16-I. | closed |
| 17-18 | T-17-18-R | Repudiation | Owner decisions | medium | mitigate | No owner decision is inferred; the checks are by diff and test. | closed |
| 17-19 | T-17-19-T | Tampering | Verification record | high | mitigate | The cited commit is an ancestor of HEAD. | closed |
| 17-19 | T-17-19-I | Information disclosure | Logs/screenshots | medium | mitigate | As T-17-16-I; the simulator pass keeps screenshots local. | closed |
| 17-19 | T-17-19-R | Repudiation | Owner decisions | medium | mitigate | The keep decision is recorded verbatim with its date and message (owner msg 1409, 2026-11-03). | closed |
| 17-23 | T-17-23-T | Tampering | Verification record | high | mitigate | All 14 commits cited in 17-23-SUMMARY and 20 in 17-FINAL-VALIDATION.md are ancestors of HEAD. §9 states that no Debug negative control ran at `891103afa`. The reader fixes `97b31b063..891103afa` touch no DEBUG, capture or environment code (diff checked), and the scanner did not change. | closed |
| 17-23 | T-17-23-I | Information disclosure | Logs/screenshots | medium | mitigate | Result bundles (`f23c-*`, `f23d-*`, `stress9-*`) stay local; simulator UDIDs are recorded as not recorded. | closed |
| 17-23 | T-17-23-R | Repudiation | Owner decisions | medium | mitigate | Owner decisions carry message IDs and dates (msgs 1305, 1581, 1627, 1640). Known limits (×5 page-sync stress) are recorded as owner-accepted, not as passes. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (high) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

All 39 plan threats are retained, three per kept plan (13 × T/I/R). Every disposition is `mitigate`.

---

## Review Items With Security Weight

**IN-02: `verify-release.py` has no `captureSystemOverlay` token (deferred to Phase 18, owner msg 1627).**
Not an open threat for Release. It is a gap in what the scanner can detect, not a leak.

- `CaptureSystemOverlays.swift` is wholly `#if DEBUG`, so `captureSystemOverlayVisibility` does not exist
  in Release.
- Its three consumers are DEBUG-gated: `ReadingView.swift:24-26` and `:69-73`, `FiltersView.swift:9-11`
  and `:54-56`, and `RootView.swift:33`, which is inside `#if DEBUG`.
- Any ungated consumer would fail to compile in Release. A leak needs someone to remove the gate on the
  definition as well.
- Even then, the value is `nil` unless a DEBUG capture launch sets it, so the screens keep their own
  policy.
- Severity: low. The fix (add the token to `FORBIDDEN_CONTENT` plus a `test_release.py` case) stays in
  Phase 18.

**IN-03: `RootView` imports `AppComponents` outside `#if DEBUG` (deferred to Phase 18, owner msg 1627).**
No security weight.

- AppFeature already depends on AppComponents (`Package.swift`, `.module(.appComponents)`), and four
  other AppFeature files import it in Release.
- In Release, the module holds no capture symbol for the import to bring in.
- This is code hygiene only.

**WR-02 (skipped, owner msg 1627).** This affects DEBUG capture chrome only. Release is unaffected.

---

## Unregistered Findings

| ID | Severity | Where | Finding | Status |
|---|---|---|---|---|
| F-17-FX-01 | low | Private fixture repository `ehpanda-fixture`, `data/objects/` (original acquisition archive) | 160 saved image-page responses keep their static-link (`/r/`) and `/fullimg/` path access tokens unzeroed. These tokens are in neither `fixtures/versions/` (0 nonzero of 680) nor `overrides/`. In the same archive, `apikey`, `showkey` and `keystamp` are all zeroed, and every page has `apiuid = -1`. So the tokens were issued to an anonymous visitor and are not account credentials. This contradicts the fixture repo's own `AGENTS.md` ("transient access values scrubbed") and the 17-03 `SECRETS` list. The tokens have been in `6d5c308` since 2026-11-01, and that commit is already on the private remote. | open — non-blocking (unregistered, below threshold); owner decision requested |
| F-17-DOC-01 | informational | `17-REVIEW-FIX.md:108` | A tracked phase record contains the absolute local checkout path, including the macOS user name. It is not a credential, LAN address or simulator ID. | noted |

---

## Fixture Repository Spot-Check (`ehpanda-fixture`, HEAD `8ee4fc2`, 1 commit ahead of origin)

The scan covered `8ee4fc2`, every commit in `git rev-list --all` (5 commits), and the commit messages.

| Check | Result |
|---|---|
| Account cookies (`ipb_member_id`, `ipb_pass_hash`, `igneous`), `Set-Cookie`, `Authorization`/`Bearer`, token shapes (GitHub, AWS, OpenAI), passwords | 0 in every commit |
| Signed-in API user | 458 of 458 `apiuid` values are `-1` (anonymous) |
| `apikey` / `showkey` / `keystamp` / H@H `/cm/` | all zeroed (458 / 840 / 1729 / none present) |
| `/r/` and `/fullimg/` path tokens | zeroed in `fixtures/versions/`; 160 unzeroed in `data/objects/` (F-17-FX-01) |
| RFC 1918 addresses, `localhost`, `127.0.0.1` | 0 in every commit and in commit messages |
| Local user paths (`/Users/…`, `Library/…`) | 0 |
| UUID-shaped values | Live Text group and translation IDs only; `recordedOn` holds model and runtime build, no device ID |
| E-mail addresses | Ad-network script and one public commenter name in saved public pages; no owner address |
| Image metadata | 1302 WebP: no EXIF/XMP chunk; 2 PNG: no text or EXIF chunk |
| Personal library state | None. The `data/api/lists/owner-*` requests are `gdata` metadata lookups of public galleries, not favorites or account lists |

---

## Accepted Risks Log

No accepted risks. No threat in this register needed acceptance. F-17-FX-01 awaits the owner's
decision and is not accepted here.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-05 | 39 | 39 | 0 | gsd-security-auditor (inline in /gsd-secure-phase 17, no subagents; ASVS L1, block_on high, effort xhigh) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (none)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-11-05 (threat register). The F-17-FX-01 disposition is the owner's.
