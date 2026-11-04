---
phase: 17-localized-screenshot-capture-harness
verified: 2026-11-04T16:52:31Z
status: human_needed
score: 5/8 must-haves verified
verification_scope: "Reduced scope (owner decision 2026-11-03, msg 1305). Executed plans 17-01 to 17-06, 17-24, 17-14 (T2), 17-16 to 17-19, 17-23. Plans 17-07 to 17-13, 17-15, 17-20 to 17-22 and 17-14 T1/T3 are moved to Phase 18 and are not verified here."
verified_head: b2fbaaa37
tested_source: b5eca09d1
effort: "high (resolved from .planning/config.json)"
covered_files: [".gitignore", ".planning/REQUIREMENTS.md", ".planning/ROADMAP.md", ".planning/phases/17-localized-screenshot-capture-harness/17-01-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-01-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-02-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-02-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-03-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-03-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-04-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-04-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-05-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-05-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-06-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-06-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-07-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-08-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-09-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-10-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-11-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-12-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-13-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-14-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-14-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-15-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-16-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-16-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-17-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-17-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-18-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-18-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-19-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-19-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-20-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-21-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-22-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-23-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-23-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-24-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-24-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-CONTEXT.md", ".planning/phases/17-localized-screenshot-capture-harness/17-FINAL-VALIDATION.md", ".planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md", ".planning/phases/17-localized-screenshot-capture-harness/17-RELEASE-ISOLATION.md", ".planning/phases/17-localized-screenshot-capture-harness/17-RESEARCH.md", ".planning/phases/17-localized-screenshot-capture-harness/17-REVIEW-DISPOSITION.md", ".planning/phases/17-localized-screenshot-capture-harness/17-REVIEW-FIX.md", ".planning/phases/17-localized-screenshot-capture-harness/17-REVIEW.md", ".planning/phases/17-localized-screenshot-capture-harness/17-SOURCE-AUDIT.md", ".planning/phases/17-localized-screenshot-capture-harness/17-VALIDATION.md", ".planning/quick/261101-website-review/APPROVAL-20261102.md", ".planning/quick/261101-website-review/PLAN.md", ".swiftlint.yml", "AppPackage/Package.swift", "AppPackage/Sources/AppComponents/CaptureSystemOverlays.swift", "AppPackage/Sources/AppComponents/ErrorInfoView.swift", "AppPackage/Sources/AppComponents/GalleryCover.swift", "AppPackage/Sources/AppComponents/GalleryCoverMetrics.swift", "AppPackage/Sources/AppComponents/GalleryCoverStyle.swift", "AppPackage/Sources/AppComponents/GalleryViewport.swift", "AppPackage/Sources/AppComponents/WindowDevice.swift", "AppPackage/Sources/AppComponents/WindowDeviceObservation.swift", "AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift", "AppPackage/Sources/AppFeature/DataFlow/WindowSizeClasses.swift", "AppPackage/Sources/AppFeature/RootView.swift", "AppPackage/Sources/AppFeature/UITestSupport/AppshotCapture.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureLiveText.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureTagTranslation.swift", "AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift", "AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift", "AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift", "AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift", "AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift", "AppPackage/Sources/AppTools/DataCache.swift", "AppPackage/Sources/DetailFeature/DetailReducer+Download.swift", "AppPackage/Sources/DetailFeature/GalleryNavigation.swift", "AppPackage/Sources/FiltersFeature/FiltersView.swift", "AppPackage/Sources/GalleryListComponents/GalleryList.swift", "AppPackage/Sources/HomeFeature/GalleryCardCell.swift", "AppPackage/Sources/HomeFeature/HomeClient.swift", "AppPackage/Sources/HomeFeature/HomeNavigationView.swift", "AppPackage/Sources/HomeFeature/HomeReducer+Body.swift", "AppPackage/Sources/HomeFeature/HomeReducer.swift", "AppPackage/Sources/HomeFeature/HomeView+Sections.swift", "AppPackage/Sources/HomeFeature/HomeView.swift", "AppPackage/Sources/ImageColors/ImageColors.swift", "AppPackage/Sources/LibraryClient/LibraryClient.swift", "AppPackage/Sources/ReadingFeature/ReadingView.swift", "AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift", "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift", "AppPackage/Sources/ReadingFeature/Support/LiveTextCapture.swift", "AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift", "AppPackage/Sources/ReadingFeature/Support/PageModel.swift", "AppPackage/Sources/VisualSnapshotSupport/FullContentHost.swift", "AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift", "AppPackage/Sources/VisualSnapshotSupport/RenderServerCapture.swift", "AppPackage/Sources/VisualSnapshotSupport/RenderSettlement.swift", "AppPackage/Sources/VisualSnapshotSupport/RenderedContentInspection.swift", "AppPackage/Tests/AppFeatureTests/CaptureDownloadTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureFixtureTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureLiveTextRecordTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureRouteTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift", "AppPackage/Tests/AppFeatureTests/GalleryDetailRoutingTests.swift", "AppPackage/Tests/AppFeatureTests/LibraryClientReaderCacheTests.swift", "AppPackage/Tests/AppFeatureTests/TabBarSettingPresentationTests.swift", "AppPackage/Tests/AppFeatureTests/UITestStubTests.swift", "AppPackage/Tests/DetailFeatureTests/DetailCaptureRouteTests.swift", "AppPackage/Tests/DetailFeatureTests/GalleryNavigationTests.swift", "AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift", "AppPackage/Tests/FeatureTests.xctestplan", "AppPackage/Tests/HomeFeatureTests/HomeClientTests.swift", "AppPackage/Tests/ReadingFeatureTests/CaptureLiveTextTests.swift", "AppPackage/Tests/ReadingFeatureTests/PagerSeedTests.swift", "AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift", "AppPackage/Tests/VisualSnapshotTests/FixtureArtwork.swift", "AppPackage/Tests/VisualSnapshotTests/FixtureArtworkTests.swift", "AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift", "AppPackage/Tests/VisualSnapshotTests/GeometryTests.swift", "AppPackage/Tests/VisualSnapshotTests/HostedHierarchyTests.swift", "AppPackage/Tests/VisualSnapshotTests/RenderServerCaptureTests.swift", "AppPackage/Tests/VisualSnapshotTests/RenderSettlementTests.swift", "AppPackage/Tests/VisualSnapshotTests/RenderedContentInspectionTests.swift", "AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json", "AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift", "EhPanda.xcodeproj/project.pbxproj", "EhPandaUITests/CaptureIsolationUITests.swift", "EhPandaUITests/MarketingCaptureUITests.swift", "EhPandaUITests/ReaderPageSyncUITests.swift", "EhPandaUITests/Support/CaptureLauncher.swift", "Scripts/check-cookie-logging.sh", "Scripts/verify-full-content-capture.py", "Scripts/visual/README.md", "Scripts/visual/acquire-fixtures.py", "Scripts/visual/capture-native.py", "Scripts/visual/contracts.py", "Scripts/visual/environment.py", "Scripts/visual/fixtures.py", "Scripts/visual/record-live-text.py", "Scripts/visual/regression-environment.json", "Scripts/visual/run-regression.py", "Scripts/visual/selection-review.py", "Scripts/visual/test_capture_native.py", "Scripts/visual/test_contracts.py", "Scripts/visual/test_environment.py", "Scripts/visual/test_fixtures.py", "Scripts/visual/test_record_live_text.py", "Scripts/visual/test_release.py", "Scripts/visual/test_selection_review.py", "Scripts/visual/verify-release.py", "UITests.xctestplan"]
covered_digest: "v4:sha256:07500a222c51630280169b7d3a92b9fe5c98ebb615d6bd54b470bf6a12631a22"
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/8
  previous_report: 8c5dc3af2
  trigger: "Owner decisions msg 1640 (2026-11-04 16:43 UTC) on human items 2, 3, 4, 6 and 7; records corrected in b2fbaaa37 (.planning only, signed G)"
  gaps_closed:
    - "Truth 6: 17-01, 17-02 and 17-24 SUMMARY requirements-completed are now [] with dated correction notes; no Phase 17 summary claims CAP-17-02, CAP-17-03 or CAP-17-05"
    - "Human item 2 (CAP-17-07 unclassified-edge classification): accepted by the owner (msg 1640), recorded in FV section 8, 17-SOURCE-AUDIT.md and 17-VALIDATION.md"
    - "Human item 3 (synthetic-comment prohibition exception, gallery 2758456): accepted by the owner (msg 1640), recorded in FV section 3, 17-SOURCE-AUDIT.md and 17-VALIDATION.md"
    - "Human item 4 (page-sync stress x5 on both devices at b5eca09d1): accepted as a known limit (msg 1640), recorded in FV sections 8 and 9, 17-VALIDATION.md, 17-23-SUMMARY.md, ROADMAP and STATE.md"
    - "Human item 6 (stale requirements-completed): corrected (see truth 6)"
    - "Human item 7 (CAP-17-04 referent): the owner chose the current set, the 2026-11-04 recapture; verified against ehpanda-website d4393bd"
    - "Record errors (a) to (i) of the initial report: all fixed (see Re-verification section)"
  gaps_remaining: []
  regressions:
    - "Truth 2 moved from VERIFIED to UNCERTAIN. This is not a source regression: the owner's new CAP-17-04 referent (the 2026-11-04 set) makes 6 of its 118 files (24 of 192 coordinates, the Live Text screen) rest on six fixture versions that are not retained in the fixture repository and are not identified in the Phase 17 records."
behavior_unverified_items:
  - truth: "WR-01: the reader's page-turn gate starts over whenever the pager is rebuilt (Reload all images, local-to-remote fallback, vertical-to-horizontal direction change)"
    test: "During UAT, in the reader on phone and iPad: start a programmatic page turn (tap zone or slider) and immediately trigger Reload all images; then turn pages by tap, slider and Auto-Play. Repeat after switching the reading direction vertical to horizontal mid-scroll, and after switching left-to-right to right-to-left."
    expected: "After each rebuild, turns move the pager and the page indicator always names the page shown; a left-to-right/right-to-left switch keeps working turns."
    why_human: "PagerTurnGate.pagerRebuilt() is unit-tested (4 PagerTurnGateTests pass at b5eca09d1), but the SwiftUI wiring (.onChange(of: store.forceRefreshID) outside the .id identity, and the readingDirection observer) is not exercised by any UI test. Phase 18 Step 4b now plans those UI tests; until then this is a manual check."
human_verification:
  - test: "Run UAT through /gsd-verify-work 17 with the owner, including the WR-01 manual reader test in behavior_unverified_items."
    expected: "The owner accepts the reduced-scope delivery: the current 192-coordinate website set (2026-11-04), the landed size-class layout and the five keep decisions, the Release isolation result, the moved list and the known limits. The reader indicator follows the page shown after Reload all images, a vertical-to-horizontal change and an LTR/RTL switch."
    why_human: "Roadmap success criterion 7 requires verify-work (UAT). The WR-01 rebuild wiring has no runtime test."
  - test: "Then run /gsd-secure-phase 17 and /gsd-validate-phase 17."
    expected: "17-SECURITY.md exists with no open threats (security enforcement is on); 17-VALIDATION.md becomes nyquist_compliant, or its gaps are recorded."
    why_human: "Close steps owned by other workflows; static verification cannot run them."
  - test: "Decide on the six Live Text fixture versions that the current CAP-17-04 set relies on (new finding in this re-verification)."
    expected: "Either retain marketing-e21df44ae7f9a521 (en), -5ec8abb6b5b9ff4b (de), -79494cb0384c200f (ko), -4f2ac4b9bf0054c9 (ja), -c3d49c5a48153585 (zh-Hans) and -7d7cea6102958b16 (zh-Hant), together with the newly recorded de/ko/zh-Hans/zh-Hant Live Text translation records, in the private fixture repository and name them in 17-FINAL-VALIDATION.md section 3; or record that the website Live Text screen does not need replayable fixtures."
    why_human: "Success criterion 2 says the website images 'and their fixtures are recorded'. The versions exist only in EhPanda's git-ignored .capture/website-recapture-20261104/ (.gitignore:23); ehpanda-fixture/fixtures/versions holds only the 16 approved versions, and FV section 3 calls them 'new immutable local fixture versions' without identifiers. Retention is an owner/data decision."
deferred:
  - truth: "CAP-17-02: SnapshotTesting coverage at 576 coordinates per scenario"
    addressed_in: "Phase 18"
    evidence: "VIS-18-01 (REQUIREMENTS.md); Phase 18 ROADMAP Step 5 'Snapshot test scenarios, real-app public dispatch and strict compare/report ... (VIS-18-01; from 17-08 to 17-12)'"
  - truth: "CAP-17-03: reviewed public baselines and the complete matrix on every PR and release"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 6 (one baseline approval, from 17-13) and Step 7 (CI snapshot gate on every PR and release, from 17-14 T1/T3 and 17-15)"
  - truth: "CAP-17-05: AltStore promotional composition and designer handoff"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 9 (designer promotional images, DIST-18-02, MKT-18-01; from 17-22)"
  - truth: "CAP-17-01 moved part: public regression test-data dispatch (17-11) and final 384 reacquisition (17-21)"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 5 (public dispatch, VIS-18-01) and Step 8 (final gallery selection and 384 regeneration, MKT-18-01)"
  - truth: "CAP-17-04 moved part: 384 export tooling, handoff validator and regeneration (17-07, 17-21)"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 8 'Marketing export tooling, final gallery selection and 384 regeneration (MKT-18-01; from 17-07 and 17-21)'"
  - truth: "CAP-17-06 moved part: snapshot-measured native visual policy (17-09 T2) and preview review (17-15)"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 7 'preview review docs (VIS-18-01; from ... 17-15)'; VIS-18-01 'preview review is documented (from 17-15)'"
  - truth: "17-14 T1/T3: full-matrix PR/release snapshot gate and clean-checkout acceptance"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 7; the release gate repeats the Release isolation scan on the final 3.0 build (REL-18-01)"
  - truth: "Reader page tracking rework to one source of truth, plus UI tests for the WR-01 rebuild paths"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP context item 7 and Step 4b (owner msg 1630, product lead msg 1631), added in b2fbaaa37"
  - truth: "Code-review info items IN-02 (verify-release.py captureSystemOverlay token) and IN-03 (RootView import under #if DEBUG)"
    addressed_in: "Phase 18"
    evidence: "Phase 18 ROADMAP Step 7 'Before that scan, close the two Phase 17 review items the owner deferred (msg 1627)', added in b2fbaaa37"
---

# Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization: verification report

**Phase goal (ROADMAP):** Close the screenshot and OS 27 layout work that 3.0 needs, at reduced scope (owner
decision 2026-11-03, msg 1305). Keep the delivered capture foundation (17-01 to 17-06, 17-24) and the
owner-approved 192-image website screenshot set as the screenshot-export result. Confirm the size-class layout
migration that already landed through quick task `261015-duo-session-record`. Close the remaining device-idiom
census with the owner. Prove once that Release ships no capture or test code. Verify the phase honestly. The
visual-regression matrix, baselines, CI snapshot gate, preview tooling, 384-image marketing export, final
gallery selection and AltStore promotional images move to Phase 18; they are moved, not satisfied.

**Verified:** 2026-11-04T16:52:31Z (2026-11-05 00:52 +08:00)
**Status:** human_needed
**Re-verification:** Yes. This follows the owner's decisions in msg 1640 (2026-11-04 16:43 UTC) and the record
corrections in `b2fbaaa37`. The initial report is `8c5dc3af2` (human_needed, 5/8). See "Re-verification" below.
**Effort:** high (resolved from .planning/config.json)
**Source:** HEAD `b2fbaaa37` (signed, `G`). The tested source is still `b5eca09d1`. Between `b5eca09d1` and
`b2fbaaa37` only `.planning/` changed: `git diff --stat b5eca09d1 b2fbaaa37` over `AppPackage`, `App`,
`ShareExtension`, `Scripts`, `EhPanda.xcodeproj`, `EhPandaUITests` and the test plans is empty. The final run
results from the initial verification therefore still apply.

**Method.** Static verification only. No build, test or simulator run. Evidence is the codebase at HEAD, the
committed phase records, and the uncommitted raw results in `/tmp/ehp-17gate/` (final runs `f23d-*` and
`stress9-*` at `b5eca09d1`). The executor's draft (`/tmp/ehp-17gate/drafts/17-VERIFICATION.md`) was treated
as input only. It has unfilled placeholders, predates FV section 9, mentions only the iPad stress reduction,
and its criterion-4 row cites a Debug negative control (991 findings) that section 9 does not record at
`b5eca09d1`.

The re-verification read the full diff of `b2fbaaa37` (13 `.planning` files). It checked each initial record
error against that diff, and the CAP-17-04 claims against the `ehpanda-website` repository (`d4393bd`), the
fixture repository (`ehpanda-fixture`, which has not changed since `134cbf3` on 2026-11-02) and the local recapture evidence
(`.capture/website-recapture-20261104/`). It ran no build, test or simulator.

## Goal Achievement

### Observable truths

The contract is the ROADMAP's seven success criteria, plus one truth from the code-review fix (WR-01). The
per-plan must-have truths roll up into these and are listed after the table.

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | The reduced plan set (17-01 to 17-06, 17-24, 17-14 T2, 17-16 to 17-19, 17-23) has summaries with evidence; the moved plans carry `status: superseded` and a pointer to Phase 18 | ✓ VERIFIED | All 13 summaries exist (`init.execute-phase`: 13 plans, 13 summaries, 0 incomplete). 17-07 to 17-13, 17-15 and 17-20 to 17-22 each have `status: superseded` and `superseded_by: "Phase 18 (moved 2026-11-03, owner msg 1305)"`. 17-14-PLAN.md has a T2-only banner, and T1/T3 sit outside `<tasks>` as `<moved-task>`. Every kept plan's `verify.artifacts` passes (01 to 06 and 24: 4/4; 14 and 23: 3/3; 16 to 19: 1/1). |
| 2 | The 192 approved website images and their fixtures are recorded as meeting the amended CAP-17-04, citing the 2026-11-02 approval | ? UNCERTAIN (WARNING; was ✓) | **Images: verified.** Owner msg 1640 set the referent to the current set. That clarification is in REQUIREMENTS.md CAP-17-04, ROADMAP Phase 17 scope item 2, and FV sections 2, 3 and 6, and the 2026-11-02 approval is still cited for which coordinates exist. It was checked against the website repository: `ehpanda-website` commit `d4393bd` (signature `G`, on `develop` and `main`, "record the owner's approval of the 2026-11-04 screenshot set (msg1581)"). In that commit, `07-SCREENSHOT-PROVENANCE-20261104.json` has `status: approved`, `approvedOn: 2026-11-04` and the source msg1581. It has 118 served files covering 192 coordinates, each coordinate exactly once and 24 per screen. The 118 split as 101 `signal-glyph-edit`, 10 `recapture` and 7 `home-indicator-recapture`. All 101 edits name their 2026-11-02 original and its SHA-256, and the record supersedes every path of the 2026-11-02 record (0 paths left over). So the records' "118 files serving the same 192 coordinates" is exact. **Fixtures: not fully recorded.** 112 files rest on retained versions in `ehpanda-fixture/fixtures/versions` (16 entries). That includes the reader recaptures (`marketing-58abe2abbdeb7391`, `-15d9f3402020edef`) and the Filters/Detail recaptures (`-1e33788fc9228d9f`, `-1bbee205f2f1f108`). The 6 Live Text files (24 coordinates) were captured from six new versions: `marketing-e21df44ae7f9a521`, `-5ec8abb6b5b9ff4b`, `-79494cb0384c200f`, `-4f2ac4b9bf0054c9`, `-c3d49c5a48153585` and `-7d7cea6102958b16` (per `.capture/website-recapture-20261104/delivery-evidence.json`). They exist only under git-ignored `.capture/` (`.gitignore:23`). They are absent from the fixture repository, whose `active-fixtures.json` still indexes `website-capture-20261102.json`, and FV section 3 does not identify them. This is a new owner decision (human item 3), not a source defect. |
| 3 | The landed size-class routing and layout pass the existing reducer tests and one simulator check on iPad full width, a narrow iPad window and iPhone landscape; every remaining idiom read has an owner keep/change disposition | ✓ VERIFIED | Code: `WindowSizeClasses.presentsModally` = regular ∧ regular (`WindowSizeClasses.swift:17-19`), applied once in `AppReducer.swift:515,527`. `routeGalleryDetail` has no match in source. Tests at `b5eca09d1`, both devices: GalleryDetailRoutingTests 4, TabBarSettingPresentationTests 8, AppDownloadDetailRoutingTests 2, CaptureRouteTests 11, GalleryNavigationTests 1, all passed (`f23d-feature-*-tests.json`). Simulator pass in 17-LAYOUT-AUDIT.md: tablet bundle exit 0 (2/2). The phone bundle is exit 65 in the driver's own reader step, after the Detail and Settings rows were recorded, and the audit discloses this. Routing source is unchanged from the pass commit `5a7fe7f13` to `b5eca09d1`; only `DownloadsView.swift` (row restore), RootView and the DEBUG overlay changed. Census: owner kept all five (msg 1409). A re-run of the census grep at `b5eca09d1` finds the same 9 files, with ReadingView hits down from 8 to 6 (`deviceState` at :44/:98/:252/:260/:277/:279), so no new idiom read appeared. |
| 4 | The 3.0-candidate Release build contains no capture code, fixtures, test assets or SnapshotTesting linkage, and no environment flag activates capture | ✓ VERIFIED | `/tmp/ehp-17gate/f23d-scan/release-isolation.json` at worktree HEAD `b5eca09d1` (dirty=0): `passed: true`, `findings: []`, 377 payload files, link maps arm64 187 objects / 291 141 symbols and x86_64 187 / 279 629, `UITestAutomation` inert shell (11 symbols) accepted. Activation: Release `alive: true` with all six capture/automation keys set; Debug control `alive: false`. Scanner tests: `Ran 19 tests … OK` (`f23d-scanner.log`). Code: every `UITestSupport/*.swift` and `CaptureSystemOverlays.swift` opens with `#if DEBUG`; `AppLaunchAutomation.resolve` is `#if DEBUG`; `VisualSnapshotSupport` (the only `SnapshotTesting` consumer, `Package.swift:1104-1108`) is linked only into the `VisualSnapshotTests` target (`project.pbxproj:10,152`). The overlay key is an `@Entry` that exists only in DEBUG, so a Release reference would not compile (this mitigates IN-02's scanner blind spot). |
| 5 | FeatureTests and UITests pass on phone then tablet, one invocation at a time, with strict no-cache lint | ✓ VERIFIED | Raw results match FV section 9 exactly. Each `.head` shows `b5eca09d1 dirty=0`, and the runs are sequential (13:57 to 14:32 UTC). FeatureTests phone: 1541 cases, 1531 passed, 0 failed, 10 expected failures. UITests phone: 88 cases, 68 passed, 20 skipped. FeatureTests tablet: 1541, 1531, 0, 10. UITests tablet: 88, 71, 17 skipped. A node walk finds 0 Repetition nodes in all four. The 10 expected failures are the known issue-reporting set: Download series, ownership and unimplemented-client guards, Analytics unimplemented client ×2, `SettingPresentationTests.pushingAccountLoadsCookies`, and `SettingReducerTests.defaultProfileCreation…`. Lint: `Found 0 violations, 0 serious in 759 files.` (`f23d-lint.log`). The `--strict --no-cache` flags come from the recorded command, because the log does not echo flags. |
| 6 | CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/06 are listed as moved to Phase 18, never as satisfied | ✓ VERIFIED (gap closed) | Canonical records: REQUIREMENTS.md (all CAP-17 unchecked; traceability "Phase 18 (moved 2026-11-03)"), the ROADMAP Phase 17 and 18 sections, FV section 6 "Moved to Phase 18", and the 17-SOURCE-AUDIT.md close status. Summaries: `b2fbaaa37` set `requirements-completed: []` in `17-01-SUMMARY.md:50`, `17-02-SUMMARY.md:66` and `17-24-SUMMARY.md:36`, each with a dated "Record correction (2026-11-05)" note. Grepping all 13 summaries finds only CAP-17-01/04/06/07 claimed (17-03, 17-16 to 17-19, 17-23), and none claims CAP-17-02, -03 or -05. CAP-17-06 is now claimed only for its bounded part (17-16 to 17-19, 17-23). |
| 7 | Phase 17 closes only through the GSD close steps: execute-phase gates (code review, regression gate, gsd-verifier writing 17-VERIFICATION.md), then verify-work (UAT), secure-phase and validate-phase | ? UNCERTAIN (in progress) | Code review: 17-REVIEW.md has 0 critical, 2 warnings and 3 info; 17-REVIEW-DISPOSITION.md has `open: 0` (WR-01 and IN-01 fixed in `fb1ea4b18`/`443e74541`, WR-02 skipped by owner msg 1627, IN-02/IN-03 deferred). Regression gate: covered (below). Verifier: this report. UAT, `/gsd-secure-phase 17` (no 17-SECURITY.md; security enforcement is on) and `/gsd-validate-phase 17` are still ahead. The phase is not marked complete: ROADMAP `- [ ] **Phase 17`, STATE `status: executing`. |
| 8 | WR-01: the reader's page-turn gate starts over whenever the pager is rebuilt | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present and wired: `PagerTurnGate.pagerRebuilt()` resets all state (`PageModel.swift`, `self = Self()`); `ReadingView.pagerRebuilt()` (:526-530) resets the gate, clears `shownPagerPosition` and places `scrollPositionID = pageModel.index`; it is called from `.onChange(of: store.forceRefreshID)` placed after `.id(store.forceRefreshID)` (:219-223) and from the `readingDirection` observer (:418-420). The four `aPagerBuiltAnew…` tests and the IN-01 tests pass on both devices at `b5eca09d1` (PagerTurnGateTests 16/16, PagerSeedTests 3/3). No UI test exercises the SwiftUI rebuild path (FV section 9 "Not verified at runtime"). |

**Score:** 5/8 truths verified (1 present but behavior-unverified; 2 uncertain: truth 2 pending the owner's
fixture-retention decision, truth 7 pending the close steps). Previous: 5/8. Truth 6 closed. Truth 2 changed from ✓
to ? because the referent moved to the 2026-11-04 set, not because of a source change.

### Plan must-have truths (supporting, roll up into the criteria above)

| Plan | Must-have truths (summary) | Verdict | Evidence |
|---|---|---|---|
| 17-01 | Public fixture export; full-content capture without layout change; SnapshotTesting test-only; unproven capture stops execution | Executed (foundation for moved CAP-17-02/03) | 17-01-SUMMARY.md; VisualSnapshotTests (VisualTracerTests 3, HostedHierarchyTests 3, RenderServerCaptureTests 17, RenderSettlementTests 6, RenderedContentInspectionTests 18 …) pass at `b5eca09d1`; SnapshotTesting test-only (truth 4) |
| 17-24 | Measured geometry before pin; immutable pin rejects drift; validation never rewrites pin | Executed (foundation) | 17-24-SUMMARY.md; `Scripts/visual/environment.py`, `regression-environment.json` present; GeometryTests are opt-in, not in FeatureTests (not re-run at `b5eca09d1`) |
| 17-02 | 576 coordinates per scenario; drift and missing results fail; filters never claim completeness; edge predicates | Executed (foundation for moved CAP-17-02) | 17-02-SUMMARY.md; `run-regression.py` imports `environment` (key link wired); Python tests not re-run at `b5eca09d1`, but `Scripts/visual/*.py` is unchanged since 17-14 (only README.md changed) |
| 17-03 | Offline real assets without an account; provisional declared; no repeated gallery in a screen; empty, ordering and concurrency edges | ✓ (prohibition: owner-accepted exception) | 17-03-SUMMARY.md; `selection-review.py` and `acquire-fixtures.py` share `fixtures.py` (wired). Prohibition "Marketing MUST NOT invent gallery content": the one exception (comment 9000000001 by CedarComet91 on gallery 2758456, and the edited image B) was accepted by the owner in msg 1640. The current set's 12 Comments files are glyph edits of the 2026-11-02 captures, so no new invented content entered |
| 17-04 | Capture launch consumes only the selected offline fixture; no contamination; unknown routes fail | ✓ | CaptureSceneTests 20, CaptureFixtureTests 10, UITestStubTests, CaptureScreenDiagnosticsTests 13 pass at `b5eca09d1`; DEBUG-gated |
| 17-05 | Actual app views at device dimensions; readiness; 9:41, no capsule, byte-identical cold reruns | ✓ (at its own gate) | 17-05-SUMMARY.md: native-09/-10 byte-identical on both devices; the 17-04 dark-card color gate is resolved there (ImageColors ordering) |
| 17-06 | Live Text on the real page; Downloads completeness from manifests; eight states in real UI | ✓ | CaptureLiveTextRecordTests 9, CaptureLiveTextTests 5, CaptureDownloadTests 7, DownloadCoordinatorCaptureTests 2 pass; open items settled by the 2026-11-02 approval (FV section 5) |
| 17-16 to 17-19 | Landed size-class layouts and routing; routeGalleryDetail removed; manifest SSOT unchanged; Settings rule; simulator pass; census with owner decisions | ✓ | Truth 3; 17-LAYOUT-AUDIT.md |
| 17-14 | Release has no capture activation, fixtures, test assets or SnapshotTesting; no flag activates; tests and lint pass; failures observable | ✓ | Truths 4 and 5 |
| 17-23 | Kept requirements evidenced at final source; moved listed as moved; no silent completion | ✓ | FV sections 1 to 9; 17-23 kept its own rule (it did not commit 17-VERIFICATION.md; its Deviations bullet now says so, `b2fbaaa37`) |

### Deferred items (moved to Phase 18, not satisfied here)

| # | Item | Addressed in | Evidence |
|---|---|---|---|
| 1 | CAP-17-02 snapshot coverage (17-08 to 17-12) | Phase 18, VIS-18-01 | ROADMAP Phase 18 Step 5 |
| 2 | CAP-17-03 baselines and CI matrix (17-12, 17-13, 17-14 T1/T3; 17-20 folded) | Phase 18, VIS-18-01 | Steps 6 and 7 |
| 3 | CAP-17-05 AltStore promotional images (17-22) | Phase 18, MKT-18-01, DIST-18-02 | Step 9 |
| 4 | CAP-17-01 moved part: public dispatch (17-11), final 384 reacquisition (17-21) | Phase 18, VIS-18-01, MKT-18-01 | Steps 5 and 8 |
| 5 | CAP-17-04 moved part: 384 export tooling and regeneration (17-07, 17-21) | Phase 18, MKT-18-01 | Step 8 |
| 6 | CAP-17-06 moved part: 17-09 T2 snapshot-measured policy, 17-15 preview review | Phase 18, VIS-18-01 | Step 7; VIS-18-01 text |
| 7 | Toplists fixtures with at least six galleries per period | Phase 18 | Step 5 ("Fixtures carry at least six galleries per Toplists period") |

| 8 | Reader page tracking rework to one source of truth, with UI tests for the WR-01 rebuild paths | Phase 18 | Context item 7 and Step 4b (added in `b2fbaaa37`) |
| 9 | IN-02 (`captureSystemOverlay` token in `verify-release.py`'s `FORBIDDEN_CONTENT`) and IN-03 (RootView's `import AppComponents` under `#if DEBUG`) | Phase 18 | Context item 7 and Step 7, before the final Release scan (added in `b2fbaaa37`) |

Rows 8 and 9 were only in STATE.md at the initial verification. `b2fbaaa37` added them to the Phase 18 roadmap,
and both target names exist: `FORBIDDEN_CONTENT` is at `verify-release.py:19`, and RootView has an
unconditional `import AppComponents` at :1 beside its `#if DEBUG` import block at :4-6. Step 4b lists the
reader's page copies A to F from `/tmp/ehp-17gate/reader-root-cause.md`: five writable copies plus the read-only
shown position. That analysis file is under `/tmp` and is not committed (Step 4b says so), so the analysis
could be lost.

### Required artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/AppFeature/DataFlow/WindowSizeClasses.swift` | App-root sheet/push rule | ✓ VERIFIED | `presentsModally` used in `AppReducer.swift:515,527` |
| `AppPackage/Sources/AppFeature/UITestSupport/*` (9 files) | DEBUG-only capture | ✓ VERIFIED | Each guarded by `#if DEBUG` (two by `#if DEBUG && canImport(Appshot)…`) |
| `AppPackage/Sources/AppComponents/CaptureSystemOverlays.swift` | DEBUG-only overlay key | ✓ VERIFIED | Whole file `#if DEBUG`; consumers in RootView, FiltersView and ReadingView are DEBUG-gated |
| `Scripts/visual/verify-release.py`, `test_release.py` | Release scanner and seeded bad payload | ✓ VERIFIED | `test_seeded_bad_payload_fails_on_every_leak` loads `verify-release.py`; 19 OK at `b5eca09d1` |
| `AppPackage/Sources/ReadingFeature/Support/PageModel.swift` (`PagerTurnGate`, `PagerSeed`) | Reader page-sync fixes | ✓ present / ⚠️ wiring behavior-unverified | Truth 8 |
| `AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift`, `PagerSeedTests.swift` | Unit pins | ✓ VERIFIED | 16 + 3 cases pass on both devices |
| 17-FINAL-VALIDATION.md, 17-LAYOUT-AUDIT.md, 17-RELEASE-ISOLATION.md | Evidence records | ✓ VERIFIED | Numbers spot-checked against raw results (truths 4, 5) |
| All kept plans' `must_haves.artifacts` | | ✓ | `query verify.artifacts`: every kept plan all_passed |

### Key link verification

`query verify.key-links` returned `verified=false` ("Target not referenced in source") for every kept plan
except one link in 17-24. The tool only checks whether the target path appears literally in the source file.
These links run through shared modules or test relationships instead, so each was checked by hand:

| From | To | Via | Status |
|---|---|---|---|
| `AppPackage/Package.swift` | `VisualSnapshotSupport/FullContentHost.swift` | module `.visualSnapshotSupport` target (Package.swift:1104) | WIRED |
| `Scripts/visual/run-regression.py` | `environment.py` | `import environment` (:14) | WIRED |
| `acquire-fixtures.py` | `selection-review.py` | both `import fixtures`; review consumes the fixture manifest | WIRED |
| `CaptureFixtureManifest.swift` | `CaptureSceneTests.swift` | `@testable import AppFeature`; 20 tests pass | WIRED |
| `AppLaunchAutomation.swift` | `capture-native.py` | `EHPANDA_CAPTURE_*` / `EHPANDA_AUTOMATION_*` environment contract | WIRED |
| `LiveTextHandler.swift` | `CaptureScenePreparation.swift` | `LiveTextCapture` replay (`CaptureScenePreparation.swift:38,400-421`) | WIRED |
| `verify-release.py` | `test_release.py` | `spec_from_file_location('verify_release', …)` | WIRED |
| `AppReducer.swift` | `WindowSizeClasses.swift` | `state.windowSizeClasses?.presentsModally` | WIRED |
| `GalleryNavigation.swift` | `GalleryNavigationTests.swift` | `appendGuardingDuplicateSkipsOnlyAdjacentDuplicates` passes | WIRED |
| `environment.py` | `GeometryTests.swift` | named test id `GeometryTests/test…Geometry()` (:185-193) | WIRED (tool: verified) |
| `regression-environment.json` | `environment.py` | loaded as the tracked pin | WIRED |
| 17-LAYOUT-AUDIT.md | `quick/261015-duo-session-record/DISCUSSION-LOG.md` | D01/D02 citations (:20, :64) | WIRED |
| 17-FINAL-VALIDATION.md | APPROVAL-20261102.md; 17-LAYOUT-AUDIT.md | markdown links (:164, :188) | WIRED |

Info: 17-03, 17-05 and 17-24 plans spell `scripts/visual/…` in lowercase, while the directory is
`Scripts/visual`. This resolves only on a case-insensitive file system. Their summaries now carry an erratum
(`b2fbaaa37`); the executed plans are not rewritten.

### Data-flow trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|---|---|---|---|---|
| Gallery Detail presentation | `windowSizeClasses` | TabBarView reports `horizontalSizeClass`/`verticalSizeClass` with `.onChange(initial: true)` to `AppReducer.windowSizeClassesChanged` | yes | ✓ FLOWING |
| Reader indicator | `pageHandler.sliderValue` ← `pageModel.index` ← `shownPagerPosition` | `onScrollTargetVisibilityChange` and the gate (truth 8) | yes; rebuild path not runtime-exercised | ⚠️ see truth 8 |
| Capture fixtures | `CaptureScenePreparation.installed` | validated fixture manifest (DEBUG launch only) | yes (DEBUG) | ✓ FLOWING |

### Behavioral spot-checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Final-run numbers match the records | node walk of `f23d-*-tests.json`, `stress9-*-tests.json` | 1541/1531/0/10 ×2; 88/68/20 and 88/71/17; stress 8 tests × 5 Repetition = 40 passed per device; 0 Repetition in the four full runs | ✓ PASS |
| Release scan result | parse `f23d-scan/release-isolation.json` | `passed: true`, 0 findings, Release alive / Debug ended | ✓ PASS |
| No new idiom read since the census | `git grep -nE "userInterfaceIdiom\|deviceState\|deviceType\|== \.pad\|case \.pad"` at `5a7fe7f13` vs `b5eca09d1` | Same 9 files; ReadingView 8 → 6 hits, all rows 1 and 5 | ✓ PASS |
| Soft top-edge count (D-26 claim) | `git grep -c "scrollEdgeEffectStyle(.soft"` | 55 top or top+bottom in 37 files (plus 1 bottom-only in ArchivesView) | ✓ PASS |
| Prior-phase cookie-logging gate (Phase 8/12) | `sh Scripts/check-cookie-logging.sh` (static, read-only) | `Cookie logging audit passed.` exit 0 | ✓ PASS |
| Re-verification: source unchanged since the runs | `git diff --stat b5eca09d1 b2fbaaa37 -- AppPackage App ShareExtension Scripts EhPanda.xcodeproj EhPandaUITests '*.xctestplan'` | empty | ✓ PASS |
| Re-verification: CAP-17-04 referent | parse `ehpanda-website` `d4393bd:.planning/phases/07-full-image-matrix-import-review-promote/07-SCREENSHOT-PROVENANCE-20261104.json` | approved 2026-11-04 (msg1581); 118 files, 192 unique coordinates (24 per screen); 101/10/7 by kind; 101/101 edits name their original's SHA-256; 0 paths of the 2026-11-02 record left unsuperseded; the 12 Comments files are all glyph edits | ✓ PASS |
| Re-verification: fixtures behind the current set | `delivery-evidence.json` and the recapture diagnostics vs `ls ehpanda-fixture/fixtures/versions` | Reader and Filters/Detail versions retained; the 6 Live Text versions are absent (local `.capture/` only, git-ignored) | ⚠️ WARN (truth 2) |
| Re-verification: no summary claims moved IDs | `grep -n '^requirements-completed' 17-*-SUMMARY.md` | Only CAP-17-01/04/06/07 appear | ✓ PASS |

### Probe execution

Step 7c: no `scripts/*/tests/probe-*.sh` exists and no plan declares a probe. The Release "launch probe" is
part of `verify-release.py`, whose result is cited in truth 4; it needs a simulator, so it was not re-run.

### Regression gate (execute-phase, prior phases)

Covered, and recorded here (unchanged by this re-verification, because no built source changed). The full FeatureTests plan (23 unit-test bundles, 1541 cases, every module's
suite, including all prior-phase tests) and the full UITests plan (88 cases) ran at `b5eca09d1` on the
iPhone Air and then the iPad Pro 11-inch (M5), one invocation at a time. Both pass with 0 failures and 0
Repetition. The one prior-phase gate outside those plans, `Scripts/check-cookie-logging.sh` (cited by 08- and
12-VERIFICATION), is a static audit: it was run here and passes. Phase 17's own Python tests other than
`test_release.py` were not re-run at `b5eca09d1`, but `Scripts/visual/*.py` is unchanged since 17-14.
**✓ Regression gate: no regressions detected.**

### Requirements coverage

Every ID in the PLAN frontmatter of the 24 plans is accounted for (CAP-17-01 to CAP-17-07). No orphaned IDs:
REQUIREMENTS.md maps no other ID to Phase 17.

| Requirement | Source plans | Description (Phase 17 part) | Status | Evidence |
|---|---|---|---|---|
| CAP-17-01 (fixture part) | 17-03, 17-04, 17-06, 17-23 | Explicit acquisition and refresh, provenance, checksums, offline replay without account or credentials | ✓ SATISFIED (Phase 17 part), with the truth 2 warning | Capture fixture and scene suites pass at `b5eca09d1`; 16 approved fixture versions retained in the fixture repository. The download suites pass; the same-run deletion invariant is not separately re-proved (FV section 6 says so). The six Live Text versions behind the current website set are local only (human item 3) |
| CAP-17-04 (amended 2026-11-03, clarified 2026-11-05) | 17-03 to 17-06, 17-23 | Met by the current website set: the 2026-11-04 recapture, 118 files serving the 192 coordinates of the 2026-11-02 approval | ? SATISFIED for the images; fixture record incomplete | Truth 2; owner msg 1640; `ehpanda-website` `d4393bd` |
| CAP-17-06 (bounded part) | 17-01, 17-05, 17-16 to 17-19, 17-23 | Preserve iOS/iPadOS 27, Swift 6.4, native navigation/search/toolbar/top-edge behavior | ✓ SATISFIED within bounds | Deployment target 27.0 in all 10 pbxproj configurations; `swift-tools-version: 6.4`, `platforms: [.iOS(.v27)]`; AccessibilityAuditUITests, DetailNavigationTitleUITests and LibraryPresentationUITests pass on both devices; AX checks recorded in 260921-f5u (not re-run). Note: app targets use `SWIFT_VERSION = 6.0` (language mode), unchanged by this phase |
| CAP-17-07 (amended 2026-11-03) | 17-04, 17-06, 17-14, 17-16 to 17-19, 17-23 | Release isolation; landed size-class migration verified; census with owner decisions; no lint/warning suppression | ✓ SATISFIED (the unclassified edge was accepted by the owner, msg 1640) | Truths 3 and 4; no new `swiftlint:disable` in phase files (the three present predate the phase: `e7bf8a2cb`, `9c3698e0a`, `25c313400`) |
| CAP-17-02 | 17-01, 17-02, 17-05, 17-08 to 17-13, 17-24 | SnapshotTesting coverage | MOVED to Phase 18 (VIS-18-01), not satisfied | No summary claims it (truth 6) |
| CAP-17-03 | 17-01, 17-02, 17-12, 17-13, 17-20, 17-24 | Baselines and CI matrix | MOVED to Phase 18 (VIS-18-01), not satisfied | No summary claims it (truth 6) |
| CAP-17-05 | 17-22 | AltStore promotional handoff | MOVED to Phase 18 (MKT-18-01, DIST-18-02), not satisfied | |

### Anti-patterns found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| none of the 91 phase files (17-REVIEW.md list plus ReadingView, WindowSizeClasses, TabBarView) | | `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER` | none | No debt markers |
| `17-01-SUMMARY.md:50`, `17-02-SUMMARY.md:66`, `17-24-SUMMARY.md:36` | frontmatter | `requirements-completed` listed moved CAP-17-02/03 | resolved | Corrected to `[]` in `b2fbaaa37` (truth 6) |
| `AppPackage/Sources/ReadingFeature/ReadingView.swift` | 219-223, 418-420 | rebuild wiring without runtime test | ℹ️ Info | Truth 8 |

### Human verification required

#### 1. UAT, including the WR-01 manual reader test
**Test:** `/gsd-verify-work 17` with the owner. As part of it, in the reader on phone and iPad: trigger Reload
all images (also during a turn), a vertical-to-horizontal switch and an LTR/RTL switch, then turn pages by
tap, slider and Auto-Play.
**Expected:** The owner accepts the reduced delivery (the current website set, the landed layout with the
five keep decisions, the Release isolation result, the moved list and the known limits). The indicator always
names the page shown, and turns keep working after every rebuild.
**Why human:** Roadmap success criterion 7. The WR-01 gate is unit-tested, but no UI test drives the SwiftUI
rebuild observers (truth 8; Phase 18 Step 4b adds those tests).

#### 2. Secure-phase and validate-phase
**Test:** `/gsd-secure-phase 17`, then `/gsd-validate-phase 17`.
**Expected:** 17-SECURITY.md with no open threats; 17-VALIDATION.md `nyquist_compliant` resolved.
**Why human:** Close steps owned by other workflows. Security enforcement is on and no 17-SECURITY.md exists.

#### 3. Live Text fixture versions behind the current CAP-17-04 set (new in this re-verification)
**Test:** Decide whether to retain the six Live Text fixture versions (`marketing-e21df44ae7f9a521` en,
`-5ec8abb6b5b9ff4b` de, `-79494cb0384c200f` ko, `-4f2ac4b9bf0054c9` ja, `-c3d49c5a48153585` zh-Hans,
`-7d7cea6102958b16` zh-Hant), and the newly recorded de/ko/zh-Hans/zh-Hant translation records, in
`ehpanda-fixture`, and whether to name them in FV section 3.
**Expected:** Either they are retained and named, or the owner records that the Live Text screen of the
website set does not need replayable fixtures.
**Why human:** Criterion 2 asks that the images "and their fixtures are recorded". After msg 1640 the images
are the 2026-11-04 set. Its 6 Live Text files (24 coordinates) come from versions that exist only in
EhPanda's git-ignored `.capture/website-recapture-20261104/`. Everything else is in the fixture repository's
16 versions. Retention is a data decision, and one machine's ignored directory is the only copy.

### Resolved by owner msg 1640 (2026-11-05)

| Initial item | Decision | Where recorded (`b2fbaaa37`) | Verifier check |
|---|---|---|---|
| 2. CAP-17-07 unclassified edge | Classification accepted | FV section 8; 17-SOURCE-AUDIT.md table and close status; 17-VALIDATION.md; 17-23-SUMMARY.md | ✓ consistent in all four |
| 3. Synthetic-comment exception (judgment-tier prohibition) | Accepted as the approved exception | FV section 3; 17-SOURCE-AUDIT.md; 17-VALIDATION.md; STATE.md | ✓ The prohibition stays flagged-unverified with one owner-accepted exception. The current Comments files are glyph edits, verified in the website record |
| 4. ×5 page-sync stress on both devices at `b5eca09d1` | Accepted as a known limit | FV sections 8 and 9; 17-VALIDATION.md; 17-23-SUMMARY.md; ROADMAP Phase 17 Plans line; STATE.md | ✓ |
| 5. WR-01 manual test | Folded into UAT (item 1) | — | — |
| 6. Stale `requirements-completed` | Corrected to `[]` with notes | 17-01, 17-02, 17-24 summaries | ✓ truth 6 closed |
| 7. CAP-17-04 referent | The current set, the 2026-11-04 recapture (msg 1581) | REQUIREMENTS.md; ROADMAP scope item 2; FV sections 2, 3, 6; STATE.md | ✓ for the images, against `d4393bd`; fixture record: human item 3 |

### Re-verification of the initial record errors

| # | Initial record error | Verdict | Evidence in `b2fbaaa37` |
|---|---|---|---|
| (a) | 17-01/02/24 `requirements-completed` list moved IDs | **Fixed** | All three `[]`, with dated correction notes. 17-01's note also explains removing CAP-17-06: the bounded part rests on the behavior suites and AX checks |
| (b) | 17-23 Deviations claimed 17-VERIFICATION.md was already written | **Fixed** | Bullet rewritten. It names `8c5dc3af2` and records the correction. FV's preamble now says the same |
| (c) | 17-VALIDATION banner named `52df81fa3` | **Fixed** | Banner: "signed off on 2026-11-04 at `b5eca09d1`" (17-23's gate at `52df81fa3`, repeated); the sign-off intro is updated to match |
| (d) | Stress wording called only the iPad reduced | **Fixed** | FV sections 1, 8 and 9; 17-VALIDATION.md known limits and table row; 17-23 key decision and Deviations; ROADMAP Plans line; STATE.md. All now say both devices ran ×5 at `b5eca09d1` and that the ×20 phone run is at `33dbf648b` |
| (e) | FV section 9 did not say the Debug negative control was not repeated | **Fixed** | Section 9 intro "except the Debug negative-control scan"; new bullet (last control at `52df81fa3`, 991 findings; earlier at `50c794b53`, confirmed in 17-RELEASE-ISOLATION.md); row 6 describes the launch-probe Debug app separately; the same wording is in 17-23-SUMMARY.md, 17-VALIDATION.md and STATE.md |
| (f) | 17-LAYOUT-AUDIT ReadingView line numbers are from `5a7fe7f13` | **Fixed (annotated)** | A dated note says the numbers are from `5a7fe7f13` and were not re-derived, citing this report for the unchanged census. Acceptable: the census conclusion, not the line numbers, is the evidence |
| (g) | FV section 3 silent on the 2026-11-04 replacements | **Fixed, with one omission** | Section 3 rewritten: 17 recaptures plus 101 edits = 118 files serving the 192 coordinates; approval msg 1581; `d4393bd`; the provenance record and its supersession. Every claim matches the website record. Omission: the fixtures bullet says "new immutable local fixture versions" without naming them or noting that they are not retained (human item 3) |
| (h) | Phase 18 ROADMAP lacked the reader rework, IN-02 and IN-03 | **Fixed** | Context item 7; Step 4b (the reader rework plus UI tests for the WR-01 paths); Step 7 (IN-02 `FORBIDDEN_CONTENT` token with a `test_release.py` case; IN-03 import under `#if DEBUG`). Both targets exist as named |
| (i) | Plans spell `scripts/visual` (info) | **Fixed (errata)** | Errata in 17-03 and 17-24 summaries; 17-05's existing note marked confirmed. Plans not rewritten, which is correct for executed plans |

### Checks on the extra edits

- **REQUIREMENTS.md CAP-17-04 clarification.** Correct against `d4393bd`: 17 + 101 = 118 files, each coordinate
  served once, approval msg 1581, provenance on `develop`. The checkbox is still unchecked, which is right
  because Phase 17 is not closed. The footer adds a 2026-11-05 note but keeps "Last updated: 2026-11-03" as its
  lead date (cosmetic).
- **ROADMAP Phase 18 context item 7, Step 4b and Step 7.** Correct and traceable (owner msgs 1627, 1630,
  product lead msg 1631). Step 4b cites `/tmp/ehp-17gate/reader-root-cause.md`, which is local and not
  committed (Step 4b says so). The analysis could be lost when `/tmp` is cleared. Consider committing it to
  Phase 18's context when that phase is planned.
- **ROADMAP Phase 17 scope item 2.** It keeps the 2026-11-03 sentence and adds the 2026-11-05 clarification, so
  the amendment history is layered and readable.
- **STATE.md.** The new 2026-11-05 entry is accurate. `last_updated` 2026-11-04T16:48:39Z equals 00:48 +08:00 on
  2026-11-05, which is consistent with `last_activity: 2026-11-05`. `stopped_at` correctly names the next step.
  `state_head` still reads `33dbf648b…`. That is unchanged from before this commit (not newly wrong), but stale.

**ROADMAP Phase 17 success criterion 2** still reads "The 192 approved website images and their fixtures are
recorded as meeting the amended CAP-17-04, citing the 2026-11-02 approval." Verifier judgment: **no
contradiction, but under-specified.**

- The 2026-11-02 approval remains the authority for which coordinates exist and which file serves each one.
  The website record says so ("pairs keep the 2026-11-02 approval of which coordinates exist and which file
  each one uses"), and FV section 3 still cites it. The criterion's citation requirement is therefore still met.
- The coordinate count is still 192.
- The criterion no longer names the image set the requirement now means (the 2026-11-04 set, msg 1581). A
  reader of the criterion alone would take the 2026-11-02 captures as the deliverable.
- Recommendation (docs-only, not a gap): append "and, after owner msg 1640, the 2026-11-04 approval (msg 1581)
  of the current files".

The criterion's "and their fixtures" clause is what human item 3 addresses.

### New observations in this re-verification (reported, not edited)

1. **Live Text fixtures not retained** (truth 2; human item 3). This is the only new finding of substance.
2. **SC2 wording** does not name the 2026-11-04 set (above).
3. **`/tmp` dependency** of Phase 18 Step 4b's root-cause analysis (above).
4. **STATE.md `state_head`** is stale at `33dbf648b` (unchanged by `b2fbaaa37`).
5. **FV section 3** gives the provenance path `.planning/phases/07-full-image-matrix-import-review-promote/…`
   without saying it is in the website repository. It is (verified at `d4393bd`); there is no such directory
   in EhPanda.

No claim in `b2fbaaa37` was found to be newly wrong. Every factual statement checked against the website
record, the fixture repository and the raw results holds.

### Gaps summary

No blocking gap and no failed truth. The owner's msg 1640 decisions and `b2fbaaa37` closed truth 6 and five of
the seven initial human items. All nine initial record errors are fixed.

- **Unchanged and verified at `b5eca09d1`** (the built source is identical at `b2fbaaa37`): truths 1, 3, 4
  and 5, and the regression gate.
- **Truth 2 is uncertain on fixtures, not on images.** The current 2026-11-04 set is approved and fully
  provenanced in the website repository. However, 6 of its 118 files rest on six Live Text fixture versions that
  exist only in a git-ignored local directory (human item 3).
- **Truth 7.** UAT, secure-phase and validate-phase are still ahead.
- **Truth 8.** The WR-01 rebuild wiring has no runtime test and is checked manually during UAT.

Status: `human_needed`.

The moved work (CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/04/06) is listed as moved
to Phase 18 and is not verified here. The reader page-tracking rework and IN-02/IN-03 are now in the Phase 18
roadmap.

---

_Verified: 2026-11-04T16:52:31Z (re-verification; initial report `8c5dc3af2` at 2026-11-04T16:10:00Z)_
_Verifier: Claude (gsd-verifier, inline; effort: high, resolved from .planning/config.json)_
