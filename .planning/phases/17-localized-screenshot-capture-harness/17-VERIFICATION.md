---
phase: 17-localized-screenshot-capture-harness
verified: 2026-11-04T16:10:00Z
status: human_needed
score: 5/8 must-haves verified
verification_scope: "Reduced scope (owner decision 2026-11-03, msg 1305). Executed plans 17-01 to 17-06, 17-24, 17-14 (T2), 17-16 to 17-19, 17-23. Plans 17-07 to 17-13, 17-15, 17-20 to 17-22 and 17-14 T1/T3 are moved to Phase 18 and are not verified here."
verified_head: 6674665c1
tested_source: 891103afa
effort: "high (resolved from .planning/config.json)"
covered_files: [".gitignore", ".planning/REQUIREMENTS.md", ".planning/ROADMAP.md", ".planning/phases/17-localized-screenshot-capture-harness/17-01-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-01-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-02-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-02-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-03-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-03-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-04-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-04-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-05-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-05-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-06-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-06-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-07-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-08-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-09-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-10-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-11-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-12-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-13-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-14-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-14-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-15-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-16-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-16-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-17-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-17-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-18-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-18-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-19-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-19-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-20-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-21-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-22-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-23-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-23-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-24-PLAN.md", ".planning/phases/17-localized-screenshot-capture-harness/17-24-SUMMARY.md", ".planning/phases/17-localized-screenshot-capture-harness/17-CONTEXT.md", ".planning/phases/17-localized-screenshot-capture-harness/17-FINAL-VALIDATION.md", ".planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md", ".planning/phases/17-localized-screenshot-capture-harness/17-RELEASE-ISOLATION.md", ".planning/phases/17-localized-screenshot-capture-harness/17-RESEARCH.md", ".planning/phases/17-localized-screenshot-capture-harness/17-REVIEW-DISPOSITION.md", ".planning/phases/17-localized-screenshot-capture-harness/17-REVIEW-FIX.md", ".planning/phases/17-localized-screenshot-capture-harness/17-REVIEW.md", ".planning/phases/17-localized-screenshot-capture-harness/17-SOURCE-AUDIT.md", ".planning/phases/17-localized-screenshot-capture-harness/17-VALIDATION.md", ".planning/quick/261101-website-review/APPROVAL-20261102.md", ".planning/quick/261101-website-review/PLAN.md", ".swiftlint.yml", "AppPackage/Package.swift", "AppPackage/Sources/AppComponents/CaptureSystemOverlays.swift", "AppPackage/Sources/AppComponents/ErrorInfoView.swift", "AppPackage/Sources/AppComponents/GalleryCover.swift", "AppPackage/Sources/AppComponents/GalleryCoverMetrics.swift", "AppPackage/Sources/AppComponents/GalleryCoverStyle.swift", "AppPackage/Sources/AppComponents/GalleryViewport.swift", "AppPackage/Sources/AppComponents/WindowDevice.swift", "AppPackage/Sources/AppComponents/WindowDeviceObservation.swift", "AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift", "AppPackage/Sources/AppFeature/DataFlow/WindowSizeClasses.swift", "AppPackage/Sources/AppFeature/RootView.swift", "AppPackage/Sources/AppFeature/UITestSupport/AppshotCapture.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureLiveText.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureTagTranslation.swift", "AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift", "AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift", "AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift", "AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift", "AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift", "AppPackage/Sources/AppTools/DataCache.swift", "AppPackage/Sources/DetailFeature/DetailReducer+Download.swift", "AppPackage/Sources/DetailFeature/GalleryNavigation.swift", "AppPackage/Sources/FiltersFeature/FiltersView.swift", "AppPackage/Sources/GalleryListComponents/GalleryList.swift", "AppPackage/Sources/HomeFeature/GalleryCardCell.swift", "AppPackage/Sources/HomeFeature/HomeClient.swift", "AppPackage/Sources/HomeFeature/HomeNavigationView.swift", "AppPackage/Sources/HomeFeature/HomeReducer+Body.swift", "AppPackage/Sources/HomeFeature/HomeReducer.swift", "AppPackage/Sources/HomeFeature/HomeView+Sections.swift", "AppPackage/Sources/HomeFeature/HomeView.swift", "AppPackage/Sources/ImageColors/ImageColors.swift", "AppPackage/Sources/LibraryClient/LibraryClient.swift", "AppPackage/Sources/ReadingFeature/ReadingView.swift", "AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift", "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift", "AppPackage/Sources/ReadingFeature/Support/LiveTextCapture.swift", "AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift", "AppPackage/Sources/ReadingFeature/Support/PageModel.swift", "AppPackage/Sources/VisualSnapshotSupport/FullContentHost.swift", "AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift", "AppPackage/Sources/VisualSnapshotSupport/RenderServerCapture.swift", "AppPackage/Sources/VisualSnapshotSupport/RenderSettlement.swift", "AppPackage/Sources/VisualSnapshotSupport/RenderedContentInspection.swift", "AppPackage/Tests/AppFeatureTests/CaptureDownloadTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureFixtureTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureLiveTextRecordTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureRouteTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift", "AppPackage/Tests/AppFeatureTests/GalleryDetailRoutingTests.swift", "AppPackage/Tests/AppFeatureTests/LibraryClientReaderCacheTests.swift", "AppPackage/Tests/AppFeatureTests/TabBarSettingPresentationTests.swift", "AppPackage/Tests/AppFeatureTests/UITestStubTests.swift", "AppPackage/Tests/DetailFeatureTests/DetailCaptureRouteTests.swift", "AppPackage/Tests/DetailFeatureTests/GalleryNavigationTests.swift", "AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift", "AppPackage/Tests/FeatureTests.xctestplan", "AppPackage/Tests/HomeFeatureTests/HomeClientTests.swift", "AppPackage/Tests/ReadingFeatureTests/CaptureLiveTextTests.swift", "AppPackage/Tests/ReadingFeatureTests/PagerSeedTests.swift", "AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift", "AppPackage/Tests/VisualSnapshotTests/FixtureArtwork.swift", "AppPackage/Tests/VisualSnapshotTests/FixtureArtworkTests.swift", "AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift", "AppPackage/Tests/VisualSnapshotTests/GeometryTests.swift", "AppPackage/Tests/VisualSnapshotTests/HostedHierarchyTests.swift", "AppPackage/Tests/VisualSnapshotTests/RenderServerCaptureTests.swift", "AppPackage/Tests/VisualSnapshotTests/RenderSettlementTests.swift", "AppPackage/Tests/VisualSnapshotTests/RenderedContentInspectionTests.swift", "AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json", "AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift", "EhPanda.xcodeproj/project.pbxproj", "EhPandaUITests/CaptureIsolationUITests.swift", "EhPandaUITests/MarketingCaptureUITests.swift", "EhPandaUITests/ReaderPageSyncUITests.swift", "EhPandaUITests/Support/CaptureLauncher.swift", "Scripts/check-cookie-logging.sh", "Scripts/verify-full-content-capture.py", "Scripts/visual/README.md", "Scripts/visual/acquire-fixtures.py", "Scripts/visual/capture-native.py", "Scripts/visual/contracts.py", "Scripts/visual/environment.py", "Scripts/visual/fixtures.py", "Scripts/visual/record-live-text.py", "Scripts/visual/regression-environment.json", "Scripts/visual/run-regression.py", "Scripts/visual/selection-review.py", "Scripts/visual/test_capture_native.py", "Scripts/visual/test_contracts.py", "Scripts/visual/test_environment.py", "Scripts/visual/test_fixtures.py", "Scripts/visual/test_record_live_text.py", "Scripts/visual/test_release.py", "Scripts/visual/test_selection_review.py", "Scripts/visual/verify-release.py", "UITests.xctestplan"]
covered_digest: "v4:sha256:633a41d1968454066bf00aaedff3a34875a77eadee0cf7057294971d8764c9ef"
behavior_unverified: 1
overrides_applied: 0
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
behavior_unverified_items:
  - truth: "WR-01: the reader's page-turn gate starts over whenever the pager is rebuilt (Reload all images, local-to-remote fallback, vertical-to-horizontal direction change)"
    test: "In the reader on phone and iPad: start a programmatic page turn (tap zone or slider) and immediately trigger Reload all images; then turn pages by tap, slider and Auto-Play. Repeat after switching the reading direction vertical to horizontal mid-scroll, and after switching left-to-right to right-to-left."
    expected: "After each rebuild, turns move the pager and the page indicator always names the page shown; a left-to-right/right-to-left switch keeps working turns."
    why_human: "PagerTurnGate.pagerRebuilt() is unit-tested (4 PagerTurnGateTests pass at 891103afa), but the SwiftUI wiring (.onChange(of: store.forceRefreshID) outside the .id identity, and the readingDirection observer) is not exercised by any UI test; ReaderPageSyncUITests covers neither forced refresh nor RTL."
human_verification:
  - test: "Run UAT through /gsd-verify-work 17 with the owner."
    expected: "The owner accepts the reduced-scope delivery: the 192-image website set, the landed size-class layout and the owner's five keep decisions, the Release isolation result, and the moved list."
    why_human: "Roadmap success criterion 7 requires verify-work (UAT), then /gsd-secure-phase 17 (security enforcement is on; no 17-SECURITY.md exists) and /gsd-validate-phase 17 (17-VALIDATION.md nyquist_compliant is false). None can be closed by static verification."
  - test: "Confirm the CAP-17-07 'unclassified' spec-less edge classification (17-FINAL-VALIDATION.md section 8; 17-SOURCE-AUDIT.md spec-less edge table)."
    expected: "The edge is accepted as covered by (a) the Release launch probe, repeated at 891103afa (release-isolation.json: Release app alive with EHPANDA_CAPTURE_CONFIGURATION, EHPANDA_CAPTURE_FIXTURES, APPSHOT_SCENE, EHPANDA_UITEST_STUB_NETWORK, EHPANDA_VISUAL_TEST_HOST and EHPANDA_AUTOMATION_TAB set; the Debug control ended) and (b) the idiom census with owner keep decisions (msg 1409). The verifier concurs: a re-run of the census grep at 891103afa finds the same files, and the ReadingView hits dropped from 8 to 6 with no new idiom decision."
    why_human: "The audit says 'manually classify the probe before closure' without naming the probe; no acceptance predicate exists, so the classification is a judgment the owner must accept."
  - test: "Resolve the judgment-tier prohibition 'Marketing MUST NOT invent gallery content' (17-03-PLAN.md must_haves.prohibitions, status unresolved)."
    expected: "The owner confirms the one recorded exception as approved: in the Comments scene of gallery 2758456, comment 9000000001 (author CedarComet91) is manually inserted and its image B (from gallery 4236534/comment 8715661) was edited to remove a Chinese subtitle (APPROVAL-20261102.md). Non-authoritative verifier judgment: the prohibition is violated by exactly this one owner-approved instance; no other invented content was found in the records."
    why_human: "Judgment-tier prohibition; it needs explicit human resolution, never a silent pass."
  - test: "Accept the reader page-sync stress coverage at the closing source as a known limit."
    expected: "Owner accepts that at 891103afa ReaderPageSyncUITests ran x5 on BOTH devices (phone 40/40, iPad 40/40, 0 retries). The x20 phone run (160/160) is at e745f38f6, before the WR-01/IN-01 reader changes. The owner chose x5 for the iPad on 2026-11-04; the records do not state an owner choice for the phone's final-source x5."
    why_human: "Earlier iPad desyncs occurred at about 1 in 20 and 1 in 160; 5 iterations cannot exclude those rates. Accepting reduced evidence is an owner decision."
  - test: "Exercise the WR-01 rebuild paths in the reader (see behavior_unverified_items)."
    expected: "The indicator stays on the page shown after a forced refresh and after a reading-direction change; an LTR/RTL switch keeps the pager working."
    why_human: "Present and unit-tested, but no UI test exercises the SwiftUI rebuild wiring."
  - test: "Decide on the stale requirements-completed frontmatter in 17-01-SUMMARY.md, 17-02-SUMMARY.md and 17-24-SUMMARY.md."
    expected: "Either correct those fields (docs-only) so they no longer list CAP-17-02/CAP-17-03 as completed, or record that they are pre-reduction history. Until then, roadmap success criterion 6 is not fully verified."
    why_human: "The verifier is not permitted to edit the summaries; /gsd-audit-milestone reads requirements-completed from SUMMARY frontmatter."
  - test: "Confirm that amended CAP-17-04 still refers to the 2026-11-02 approved set, given the owner-requested website replacements of 2026-11-04 (quick task 261104-website-recapture)."
    expected: "Owner confirms the requirement stands on the 2026-11-02 approval. The 17 recaptured images (reader, Live Text, Filters, adult-mode Detail) and the 101 status-bar signal-glyph edits are website delivery changes outside the requirement, or they are recorded against website-capture-20261102.json, whose 192 hashes no longer describe the delivered images for those coordinates."
    why_human: "17-FINAL-VALIDATION.md section 3 does not mention the 2026-11-04 replacements; only the owner can say which set the requirement cites."
---

# Phase 17: Screenshot Automation, Visual Regression & OS 27 Modernization: verification report

**Phase goal (ROADMAP):** Close the screenshot and OS 27 layout work that 3.0 needs, at reduced scope (owner
decision 2026-11-03, msg 1305). Keep the delivered capture foundation (17-01 to 17-06, 17-24) and the
owner-approved 192-image website screenshot set as the screenshot-export result. Confirm the size-class layout
migration that already landed through quick task `261015-duo-session-record`. Close the remaining device-idiom
census with the owner. Prove once that Release ships no capture or test code. Verify the phase honestly. The
visual-regression matrix, baselines, CI snapshot gate, preview tooling, 384-image marketing export, final
gallery selection and AltStore promotional images move to Phase 18; they are moved, not satisfied.

**Verified:** 2026-11-04T16:10:00Z (2026-11-05 00:10 +08:00)
**Status:** human_needed
**Re-verification:** No. This is the initial verification; no earlier 17-VERIFICATION.md was committed.
**Effort:** high (resolved from .planning/config.json)
**Source:** HEAD `6674665c1`. The tested source is `891103afa`. `git diff 891103afa 6674665c1` touches only
`.planning/` (ROADMAP, STATE, 17-23-SUMMARY, 17-FINAL-VALIDATION, 17-VALIDATION), and
`AppPackage`, `App`, `ShareExtension` and `Scripts` are identical.

**Method.** Static verification only. No build, test or simulator run. Evidence is the codebase at HEAD, the
committed phase records, and the uncommitted raw results in `/tmp/ehp-17gate/` (final runs `f23d-*` and
`stress9-*` at `891103afa`). The executor's draft (`/tmp/ehp-17gate/drafts/17-VERIFICATION.md`) was treated
as input only. It has unfilled placeholders, predates FV section 9, mentions only the iPad stress reduction,
and its criterion-4 row cites a Debug negative control (991 findings) that section 9 does not record at
`891103afa`.

## Goal Achievement

### Observable truths

The contract is the ROADMAP's seven success criteria, plus one truth from the code-review fix (WR-01). The
per-plan must-have truths roll up into these and are listed after the table.

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | The reduced plan set (17-01 to 17-06, 17-24, 17-14 T2, 17-16 to 17-19, 17-23) has summaries with evidence; the moved plans carry `status: superseded` and a pointer to Phase 18 | ✓ VERIFIED | All 13 summaries exist (`init.execute-phase`: 13 plans, 13 summaries, 0 incomplete). 17-07 to 17-13, 17-15 and 17-20 to 17-22 each have `status: superseded` and `superseded_by: "Phase 18 (moved 2026-11-03, owner msg 1305)"`. 17-14-PLAN.md has a T2-only banner, and T1/T3 sit outside `<tasks>` as `<moved-task>`. Every kept plan's `verify.artifacts` passes (01 to 06 and 24: 4/4; 14 and 23: 3/3; 16 to 19: 1/1). |
| 2 | The 192 approved website images and their fixtures are recorded as meeting the amended CAP-17-04, citing the 2026-11-02 approval | ✓ VERIFIED | REQUIREMENTS.md CAP-17-04 amendment; FV sections 2 and 3; `quick/261101-website-review/APPROVAL-20261102.md` (192 iPhone Air portrait images at 1260 × 2736, 2 groups × 6 locales × 2 themes × 8 screens, 16 immutable fixture versions, index `website-capture-20261102.json`); website contract without the iPad axis in `quick/261101-website-review/PLAN.md:4-5`. The images and fixtures are in the private fixture repository, so this verifies the record, not the bytes. See human item 7 on the 2026-11-04 replacements. |
| 3 | The landed size-class routing and layout pass the existing reducer tests and one simulator check on iPad full width, a narrow iPad window and iPhone landscape; every remaining idiom read has an owner keep/change disposition | ✓ VERIFIED | Code: `WindowSizeClasses.presentsModally` = regular ∧ regular (`WindowSizeClasses.swift:17-19`), applied once in `AppReducer.swift:515,527`. `routeGalleryDetail` has no match in source. Tests at `891103afa`, both devices: GalleryDetailRoutingTests 4, TabBarSettingPresentationTests 8, AppDownloadDetailRoutingTests 2, CaptureRouteTests 11, GalleryNavigationTests 1, all passed (`f23d-feature-*-tests.json`). Simulator pass in 17-LAYOUT-AUDIT.md: tablet bundle exit 0 (2/2). The phone bundle is exit 65 in the driver's own reader step, after the Detail and Settings rows were recorded, and the audit discloses this. Routing source is unchanged from the pass commit `24edc450d` to `891103afa`; only `DownloadsView.swift` (row restore), RootView and the DEBUG overlay changed. Census: owner kept all five (msg 1409). A re-run of the census grep at `891103afa` finds the same 9 files, with ReadingView hits down from 8 to 6 (`deviceState` at :44/:98/:252/:260/:277/:279), so no new idiom read appeared. |
| 4 | The 3.0-candidate Release build contains no capture code, fixtures, test assets or SnapshotTesting linkage, and no environment flag activates capture | ✓ VERIFIED | `/tmp/ehp-17gate/f23d-scan/release-isolation.json` at worktree HEAD `891103afa` (dirty=0): `passed: true`, `findings: []`, 377 payload files, link maps arm64 187 objects / 291 141 symbols and x86_64 187 / 279 629, `UITestAutomation` inert shell (11 symbols) accepted. Activation: Release `alive: true` with all six capture/automation keys set; Debug control `alive: false`. Scanner tests: `Ran 19 tests … OK` (`f23d-scanner.log`). Code: every `UITestSupport/*.swift` and `CaptureSystemOverlays.swift` opens with `#if DEBUG`; `AppLaunchAutomation.resolve` is `#if DEBUG`; `VisualSnapshotSupport` (the only `SnapshotTesting` consumer, `Package.swift:1104-1108`) is linked only into the `VisualSnapshotTests` target (`project.pbxproj:10,152`). The overlay key is an `@Entry` that exists only in DEBUG, so a Release reference would not compile (this mitigates IN-02's scanner blind spot). |
| 5 | FeatureTests and UITests pass on phone then tablet, one invocation at a time, with strict no-cache lint | ✓ VERIFIED | Raw results match FV section 9 exactly. Each `.head` shows `891103afa dirty=0`, and the runs are sequential (13:57 to 14:32 UTC). FeatureTests phone: 1541 cases, 1531 passed, 0 failed, 10 expected failures. UITests phone: 88 cases, 68 passed, 20 skipped. FeatureTests tablet: 1541, 1531, 0, 10. UITests tablet: 88, 71, 17 skipped. A node walk finds 0 Repetition nodes in all four. The 10 expected failures are the known issue-reporting set: Download series, ownership and unimplemented-client guards, Analytics unimplemented client ×2, `SettingPresentationTests.pushingAccountLoadsCookies`, and `SettingReducerTests.defaultProfileCreation…`. Lint: `Found 0 violations, 0 serious in 759 files.` (`f23d-lint.log`). The `--strict --no-cache` flags come from the recorded command, because the log does not echo flags. |
| 6 | CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/06 are listed as moved to Phase 18, never as satisfied | ? UNCERTAIN (WARNING) | Canonical records are correct: REQUIREMENTS.md (all CAP-17 unchecked; traceability "Phase 18 (moved 2026-11-03)"), the ROADMAP Phase 17 and 18 sections, FV section 6 "Moved to Phase 18", and the 17-SOURCE-AUDIT.md close status. **But** the pre-reduction summaries still claim them as completed: `17-01-SUMMARY.md:50 requirements-completed: [CAP-17-02, CAP-17-03, CAP-17-06]`, `17-02-SUMMARY.md:66 [CAP-17-02, CAP-17-03]`, `17-24-SUMMARY.md:36 [CAP-17-02, CAP-17-03]`. /gsd-audit-milestone reads that field. The fix is docs-only, so this goes to a human decision (item 6) rather than a blocker. |
| 7 | Phase 17 closes only through the GSD close steps: execute-phase gates (code review, regression gate, gsd-verifier writing 17-VERIFICATION.md), then verify-work (UAT), secure-phase and validate-phase | ? UNCERTAIN (in progress) | Code review: 17-REVIEW.md has 0 critical, 2 warnings and 3 info; 17-REVIEW-DISPOSITION.md has `open: 0` (WR-01 and IN-01 fixed in `92181ccd2`/`18ec91b86`, WR-02 skipped by owner msg 1627, IN-02/IN-03 deferred). Regression gate: covered (below). Verifier: this report. UAT, `/gsd-secure-phase 17` (no 17-SECURITY.md; security enforcement is on) and `/gsd-validate-phase 17` are still ahead. The phase is not marked complete: ROADMAP `- [ ] **Phase 17`, STATE `status: executing`. |
| 8 | WR-01: the reader's page-turn gate starts over whenever the pager is rebuilt | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present and wired: `PagerTurnGate.pagerRebuilt()` resets all state (`PageModel.swift`, `self = Self()`); `ReadingView.pagerRebuilt()` (:526-530) resets the gate, clears `shownPagerPosition` and places `scrollPositionID = pageModel.index`; it is called from `.onChange(of: store.forceRefreshID)` placed after `.id(store.forceRefreshID)` (:219-223) and from the `readingDirection` observer (:418-420). The four `aPagerBuiltAnew…` tests and the IN-01 tests pass on both devices at `891103afa` (PagerTurnGateTests 16/16, PagerSeedTests 3/3). No UI test exercises the SwiftUI rebuild path (FV section 9 "Not verified at runtime"). |

**Score:** 5/8 truths verified (1 present but behavior-unverified; 2 uncertain, pending human decision or close steps).

### Plan must-have truths (supporting, roll up into the criteria above)

| Plan | Must-have truths (summary) | Verdict | Evidence |
|---|---|---|---|
| 17-01 | Public fixture export; full-content capture without layout change; SnapshotTesting test-only; unproven capture stops execution | Executed (foundation for moved CAP-17-02/03) | 17-01-SUMMARY.md; VisualSnapshotTests (VisualTracerTests 3, HostedHierarchyTests 3, RenderServerCaptureTests 17, RenderSettlementTests 6, RenderedContentInspectionTests 18 …) pass at `891103afa`; SnapshotTesting test-only (truth 4) |
| 17-24 | Measured geometry before pin; immutable pin rejects drift; validation never rewrites pin | Executed (foundation) | 17-24-SUMMARY.md; `Scripts/visual/environment.py`, `regression-environment.json` present; GeometryTests are opt-in, not in FeatureTests (not re-run at `891103afa`) |
| 17-02 | 576 coordinates per scenario; drift and missing results fail; filters never claim completeness; edge predicates | Executed (foundation for moved CAP-17-02) | 17-02-SUMMARY.md; `run-regression.py` imports `environment` (key link wired); Python tests not re-run at `891103afa`, but `Scripts/visual/*.py` is unchanged since 17-14 (only README.md changed) |
| 17-03 | Offline real assets without an account; provisional declared; no repeated gallery in a screen; empty, ordering and concurrency edges | ✓ (prohibition flagged) | 17-03-SUMMARY.md; `selection-review.py` and `acquire-fixtures.py` share `fixtures.py` (wired). Prohibition: human item 3 |
| 17-04 | Capture launch consumes only the selected offline fixture; no contamination; unknown routes fail | ✓ | CaptureSceneTests 20, CaptureFixtureTests 10, UITestStubTests, CaptureScreenDiagnosticsTests 13 pass at `891103afa`; DEBUG-gated |
| 17-05 | Actual app views at device dimensions; readiness; 9:41, no capsule, byte-identical cold reruns | ✓ (at its own gate) | 17-05-SUMMARY.md: native-09/-10 byte-identical on both devices; the 17-04 dark-card color gate is resolved there (ImageColors ordering) |
| 17-06 | Live Text on the real page; Downloads completeness from manifests; eight states in real UI | ✓ | CaptureLiveTextRecordTests 9, CaptureLiveTextTests 5, CaptureDownloadTests 7, DownloadCoordinatorCaptureTests 2 pass; open items settled by the 2026-11-02 approval (FV section 5) |
| 17-16 to 17-19 | Landed size-class layouts and routing; routeGalleryDetail removed; manifest SSOT unchanged; Settings rule; simulator pass; census with owner decisions | ✓ | Truth 3; 17-LAYOUT-AUDIT.md |
| 17-14 | Release has no capture activation, fixtures, test assets or SnapshotTesting; no flag activates; tests and lint pass; failures observable | ✓ | Truths 4 and 5 |
| 17-23 | Kept requirements evidenced at final source; moved listed as moved; no silent completion | ✓ / see truth 6 | FV sections 1 to 9; 17-23 kept its own rule (it did not commit 17-VERIFICATION.md) |

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

**Carried to Phase 18 but not yet in the Phase 18 ROADMAP section** (recorded only in STATE.md, so the Step 9b
deferral rule cannot match them; they are not Phase 17 success criteria):

- Reader page tracking rework to one source of truth (owner msg 1630, product lead msg 1631; FV section 9;
  `/tmp/ehp-17gate/reader-root-cause.md`: five writable copies of "the page" reconciled by timing-dependent
  rules).
- IN-02: `verify-release.py` has no `captureSystemOverlay` token. IN-03: RootView's unconditional
  `import AppComponents`. Both are deferred by the owner (msg 1627).

  Recommendation: add these to the Phase 18 roadmap or requirements so they are not lost.

### Required artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/AppFeature/DataFlow/WindowSizeClasses.swift` | App-root sheet/push rule | ✓ VERIFIED | `presentsModally` used in `AppReducer.swift:515,527` |
| `AppPackage/Sources/AppFeature/UITestSupport/*` (9 files) | DEBUG-only capture | ✓ VERIFIED | Each guarded by `#if DEBUG` (two by `#if DEBUG && canImport(Appshot)…`) |
| `AppPackage/Sources/AppComponents/CaptureSystemOverlays.swift` | DEBUG-only overlay key | ✓ VERIFIED | Whole file `#if DEBUG`; consumers in RootView, FiltersView and ReadingView are DEBUG-gated |
| `Scripts/visual/verify-release.py`, `test_release.py` | Release scanner and seeded bad payload | ✓ VERIFIED | `test_seeded_bad_payload_fails_on_every_leak` loads `verify-release.py`; 19 OK at `891103afa` |
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
`Scripts/visual`. This resolves only on a case-insensitive file system.

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
| No new idiom read since the census | `git grep -nE "userInterfaceIdiom\|deviceState\|deviceType\|== \.pad\|case \.pad"` at `24edc450d` vs `891103afa` | Same 9 files; ReadingView 8 → 6 hits, all rows 1 and 5 | ✓ PASS |
| Soft top-edge count (D-26 claim) | `git grep -c "scrollEdgeEffectStyle(.soft"` | 55 top or top+bottom in 37 files (plus 1 bottom-only in ArchivesView) | ✓ PASS |
| Prior-phase cookie-logging gate (Phase 8/12) | `sh Scripts/check-cookie-logging.sh` (static, read-only) | `Cookie logging audit passed.` exit 0 | ✓ PASS |

### Probe execution

Step 7c: no `scripts/*/tests/probe-*.sh` exists and no plan declares a probe. The Release "launch probe" is
part of `verify-release.py`, whose result is cited in truth 4; it needs a simulator, so it was not re-run.

### Regression gate (execute-phase, prior phases)

Covered, and recorded here. The full FeatureTests plan (23 unit-test bundles, 1541 cases, every module's
suite, including all prior-phase tests) and the full UITests plan (88 cases) ran at `891103afa` on the
iPhone Air and then the iPad Pro 11-inch (M5), one invocation at a time. Both pass with 0 failures and 0
Repetition. The one prior-phase gate outside those plans, `Scripts/check-cookie-logging.sh` (cited by 08- and
12-VERIFICATION), is a static audit: it was run here and passes. Phase 17's own Python tests other than
`test_release.py` were not re-run at `891103afa`, but `Scripts/visual/*.py` is unchanged since 17-14.
**✓ Regression gate: no regressions detected.**

### Requirements coverage

Every ID in the PLAN frontmatter of the 24 plans is accounted for (CAP-17-01 to CAP-17-07). No orphaned IDs:
REQUIREMENTS.md maps no other ID to Phase 17.

| Requirement | Source plans | Description (Phase 17 part) | Status | Evidence |
|---|---|---|---|---|
| CAP-17-01 (fixture part) | 17-03, 17-04, 17-06, 17-23 | Explicit acquisition and refresh, provenance, checksums, offline replay without account or credentials | ✓ SATISFIED (Phase 17 part) | Capture fixture and scene suites pass at `891103afa`; 16 approved fixture versions. The download suites pass; the same-run deletion invariant is not separately re-proved (FV section 6 says so) |
| CAP-17-04 (amended 2026-11-03) | 17-03 to 17-06, 17-23 | Met by the 192 owner-approved website images of 2026-11-02 | ✓ SATISFIED as recorded | Truth 2; human item 7 |
| CAP-17-06 (bounded part) | 17-01, 17-05, 17-16 to 17-19, 17-23 | Preserve iOS/iPadOS 27, Swift 6.4, native navigation/search/toolbar/top-edge behavior | ✓ SATISFIED within bounds | Deployment target 27.0 in all 10 pbxproj configurations; `swift-tools-version: 6.4`, `platforms: [.iOS(.v27)]`; AccessibilityAuditUITests, DetailNavigationTitleUITests and LibraryPresentationUITests pass on both devices; AX checks recorded in 260921-f5u (not re-run). Note: app targets use `SWIFT_VERSION = 6.0` (language mode), unchanged by this phase |
| CAP-17-07 (amended 2026-11-03) | 17-04, 17-06, 17-14, 17-16 to 17-19, 17-23 | Release isolation; landed size-class migration verified; census with owner decisions; no lint/warning suppression | ✓ SATISFIED (pending the human confirmation of the unclassified edge, item 2) | Truths 3 and 4; no new `swiftlint:disable` in phase files (the three present predate the phase: `a4273c7ba`, `bdf477561`, `25c313400`) |
| CAP-17-02 | 17-01, 17-02, 17-05, 17-08 to 17-13, 17-24 | SnapshotTesting coverage | MOVED to Phase 18 (VIS-18-01), not satisfied | Truth 6 warning: 17-01/02/24 summaries still list it as completed |
| CAP-17-03 | 17-01, 17-02, 17-12, 17-13, 17-20, 17-24 | Baselines and CI matrix | MOVED to Phase 18 (VIS-18-01), not satisfied | Same warning |
| CAP-17-05 | 17-22 | AltStore promotional handoff | MOVED to Phase 18 (MKT-18-01, DIST-18-02), not satisfied | |

### Anti-patterns found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| none of the 91 phase files (17-REVIEW.md list plus ReadingView, WindowSizeClasses, TabBarView) | | `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER` | none | No debt markers |
| `17-01-SUMMARY.md:50`, `17-02-SUMMARY.md:66`, `17-24-SUMMARY.md:36` | frontmatter | `requirements-completed` lists moved CAP-17-02/03 | ⚠️ Warning | Truth 6; misleads milestone audit |
| `AppPackage/Sources/ReadingFeature/ReadingView.swift` | 219-223, 418-420 | rebuild wiring without runtime test | ℹ️ Info | Truth 8 |

### Human verification required

#### 1. UAT and the remaining close steps
**Test:** `/gsd-verify-work 17` with the owner, then `/gsd-secure-phase 17` and `/gsd-validate-phase 17`.
**Expected:** Owner acceptance of the reduced delivery; 17-SECURITY.md with no open threats; Nyquist validation.
**Why human:** Roadmap success criterion 7. Security enforcement is on and no 17-SECURITY.md exists.

#### 2. CAP-17-07 "unclassified" edge
**Test:** Accept or reject FV section 8's classification against the Release launch probe and the idiom census.
**Expected:** Accepted. The verifier concurs: the probe at `891103afa` keeps Release running with all six keys
set while the Debug control ends, and the census is unchanged at `891103afa`.
**Why human:** No acceptance predicate exists.

#### 3. Prohibition "Marketing MUST NOT invent gallery content" (judgment tier)
**Test:** Confirm the synthetic comment 9000000001 (CedarComet91) in gallery 2758456 and the edited image B
as the owner-approved exception.
**Expected:** Confirmed as the only exception.
**Why human:** The verifier's verdict is non-authoritative; it is flagged, not passed.

#### 4. Page-sync stress coverage at the closing source
**Test:** Accept ×5 on both devices at `891103afa` (40/40 each). The ×20 phone run is at `e745f38f6`, before
WR-01/IN-01.
**Expected:** Accepted as a known limit, or more iterations requested.
**Why human:** 5 iterations cannot exclude the 1-in-20 and 1-in-160 rates seen earlier, and the phone's
final-source reduction is not recorded as an owner choice.

#### 5. WR-01 rebuild wiring
**Test:** In the reader, trigger Reload all images, a vertical-to-horizontal switch and an LTR/RTL switch
(also during a turn), then turn pages by tap, slider and Auto-Play.
**Expected:** The indicator always names the page shown; turns keep working after every rebuild.
**Why human:** Unit tests pin the gate; no UI test drives the SwiftUI rebuild observers.

#### 6. Stale `requirements-completed` in 17-01, 17-02 and 17-24 summaries
**Test:** Decide whether to correct those fields (docs-only).
**Expected:** They no longer claim CAP-17-02/03, or they are explicitly marked as pre-reduction history.
**Why human:** The verifier may not edit summaries. Truth 6 stays uncertain until then.

#### 7. CAP-17-04 referent after the 2026-11-04 website replacements
**Test:** Confirm that the requirement cites the 2026-11-02 set, and decide whether the 2026-11-04 replacements
(17 recaptures and 101 status-bar glyph edits, quick task `261104-website-recapture`) need recording against
the website capture index.
**Expected:** An owner statement, recorded where the owner chooses.
**Why human:** FV section 3 is silent on the replacements. The quick-task summary says the 101 glyph edits
exclude the 17 recaptures, so up to 118 delivered images no longer match their 2026-11-02 indexed hashes.

### Record observations (reported, not edited)

1. **17-01/17-02/17-24 SUMMARY `requirements-completed`** still list the moved CAP-17-02/CAP-17-03 (truth 6).
2. **17-23-SUMMARY.md "Deviations"** says 17-VERIFICATION.md "was written at the orchestrator's direction …
   as a separate commit after this plan's records". No such file or commit existed before this report; the
   executor's draft stayed in `/tmp/ehp-17gate/drafts/`. This report is the gsd-verifier's, as 17-23-PLAN.md
   intended.
3. **17-VALIDATION.md**: the banner says "signed off by 17-23 on 2026-11-04 at `97b31b063`", while the
   frontmatter `signed_off_source` is `891103afa`. The body's "Repeated after the code review" paragraph
   reconciles this, but the banner is stale.
4. **Stress wording**: FV section 8, 17-VALIDATION.md, STATE.md and ROADMAP call only the iPad stress
   reduced. At the closing source `891103afa`, the phone also ran ×5; the FV section 9 table shows this, but
   no known-limit text says so.
5. **FV section 9 row 6** reports the Release scan at `891103afa` but records no Debug negative control run
   (991 findings) at that commit. The draft's criterion-4 row would have over-claimed one. The JSON's launch
   probe does include the Debug control (`alive: false`).
6. **17-LAYOUT-AUDIT.md** ReadingView line numbers (204, 212, 229, 232; 38, 75, 76, 163) are those of
   `24edc450d`. At `891103afa` they are 252/260 and 277/279, and 44/98. The census still holds.
7. **FV section 3** does not mention the 2026-11-04 website replacements (human item 7).
8. **Phase 18 ROADMAP** does not yet carry the reader single-source-of-truth rework, IN-02 or IN-03; only
   STATE.md does.

### Gaps summary

No blocking gap. Every truth that grep and the recorded runs can decide is verified at `891103afa`: the
reduced plan set and the moved markings, the website-set record, the landed size-class routing with the
owner's census, Release isolation, and the sequential phone-then-tablet FeatureTests and UITests with strict
lint. The regression gate is covered by those full runs, plus the static cookie-logging audit run here.

What keeps the phase short of `passed`:

- **Truth 6 (warning).** Three pre-reduction summaries still list CAP-17-02/03 as completed. This is a
  docs-only fix for the owner to decide.
- **Truth 7.** The remaining close steps (UAT, secure-phase, validate-phase) have not run.
- **Truth 8.** The WR-01 rebuild wiring is present and unit-tested but has no runtime test.
- **Owner decisions.** The CAP-17-07 unclassified edge, the synthetic-comment prohibition exception, the
  ×5 stress at the closing source on both devices, and which image set amended CAP-17-04 cites.

The moved work (CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/04/06) is listed as
moved to Phase 18 and is not verified here. Separately, the reader's page tracking has a known root cause:
five copies of "the current page", reconciled by timing-dependent rules. It is carried to Phase 18 by the
owner but is not yet in the Phase 18 roadmap.

---

_Verified: 2026-11-04T16:10:00Z_
_Verifier: Claude (gsd-verifier, inline; effort: high, resolved from .planning/config.json)_
