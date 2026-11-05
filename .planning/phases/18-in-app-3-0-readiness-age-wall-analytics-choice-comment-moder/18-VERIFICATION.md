---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
verified: 2026-11-05T18:22:41Z
refreshed: 2026-11-05T18:58:44Z
status: passed
score: 10/10 must-haves verified
verification_scope: "Phase 18 as amended: None → Minimal (owner msgs 1805, 1818), member-ID blocking (owner msg 1918). DIST-18-01 is verified for `MKSellsDigitalGoods` only; its marketplace flavor is Phase 20."
verified_head: b961ea4d8
tested_source: c3ef39ac9
roles: "code-reviewer, code-fixer and verifier run in one agent, in sequence, following the gsd-* agent definitions"
covered_files: [".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-01-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-01-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-02-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-02-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-03-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-03-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-04-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-04-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-05-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-05-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-06-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-06-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-07-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-07-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-08-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-08-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-09-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-09-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-10-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-10-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-11-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-11-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-12-PLAN.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-12-SUMMARY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-CONTEXT.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-COMMENTS.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-FIRST-LAUNCH.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-COPY-MINIMAL.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-REGRESSION-GATE.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-REVIEW-DISPOSITION.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-REVIEW.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-SECURITY.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-UI-SPEC.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-VALIDATION.md", ".planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py", "App/Info.plist", "AppPackage/Package.swift", "AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift", "AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift", "AppPackage/Sources/AnalyticsClient/AnalyticsOrientation.swift", "AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Level.swift", "AppPackage/Sources/AnalyticsClient/InstallSignalSender.swift", "AppPackage/Sources/AnalyticsClient/TelemetrySDK.swift", "AppPackage/Sources/AppComponents/CheckboxToggleStyle.swift", "AppPackage/Sources/AppComponents/ChoiceCard.swift", "AppPackage/Sources/AppComponents/FirstLaunchContinueButton.swift", "AppPackage/Sources/AppComponents/SessionWebView.swift", "AppPackage/Sources/AppComponents/TitleWidowGuard.swift", "AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift", "AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift", "AppPackage/Sources/AppFeature/FirstLaunch/AgeWallView.swift", "AppPackage/Sources/AppFeature/FirstLaunch/AnalyticsChoiceView.swift", "AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchGateView.swift", "AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchReducer.swift", "AppPackage/Sources/AppFeature/RootView.swift", "AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift", "AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift", "AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift", "AppPackage/Sources/AppModels/Gallery/GalleryComment.swift", "AppPackage/Sources/AppModels/Moderation/BlockedCommentUser.swift", "AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift", "AppPackage/Sources/AppModels/Persistent/AgeDeclaration.swift", "AppPackage/Sources/AppModels/Persistent/AnalyticsLevel.swift", "AppPackage/Sources/AppModels/Persistent/InstallSignalState.swift", "AppPackage/Sources/AppModels/Persistent/Setting.swift", "AppPackage/Sources/CookieClient/CookieClient.swift", "AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift", "AppPackage/Sources/DetailFeature/Comments/CommentsView.swift", "AppPackage/Sources/DetailFeature/Components/PostCommentView.swift", "AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift", "AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift", "AppPackage/Sources/DetailFeature/DetailReducer.swift", "AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift", "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift", "AppPackage/Sources/DetailFeature/DetailView.swift", "AppPackage/Sources/DetailFeature/Moderation/BlockedCommentCard.swift", "AppPackage/Sources/DetailFeature/Moderation/BlockedCommentRow.swift", "AppPackage/Sources/DetailFeature/Moderation/CommentFilter.swift", "AppPackage/Sources/DetailFeature/Moderation/CommentFilterTerms.swift", "AppPackage/Sources/DetailFeature/Moderation/CommentModeration.swift", "AppPackage/Sources/DetailFeature/Moderation/CommentModerationMenu.swift", "AppPackage/Sources/DetailFeature/Moderation/CommentOwnership.swift", "AppPackage/Sources/DetailFeature/Moderation/CommentReportTarget.swift", "AppPackage/Sources/DetailFeature/Moderation/ReportPageSheet.swift", "AppPackage/Sources/DetailFeature/Resources/CommentFilterTerms.json", "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings", "AppPackage/Sources/InstallSourceClient/.swiftlint.yml", "AppPackage/Sources/InstallSourceClient/InstallSourceClient.swift", "AppPackage/Sources/ParserFeature/Parser+Comment.swift", "AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift", "AppPackage/Sources/ReadingFeature/ReadingReducer+Session.swift", "AppPackage/Sources/ReadingFeature/ReadingReducer.swift", "AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift", "AppPackage/Sources/ReadingFeature/ReadingView.swift", "AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift", "AppPackage/Sources/ReadingFeature/Support/AutoPlayHandler.swift", "AppPackage/Sources/ReadingFeature/Support/PageHandler.swift", "AppPackage/Sources/ReadingFeature/Support/ReaderPagesAccessibility.swift", "AppPackage/Sources/ReadingFeature/Support/ReaderPosition.swift", "AppPackage/Sources/Resources/ResourceStringSymbols.swift", "AppPackage/Sources/Resources/Resources/Constant.xcstrings", "AppPackage/Sources/Resources/Resources/Localizable.xcstrings", "AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift", "AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift", "AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersReducer.swift", "AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersView.swift", "AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift", "AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift", "AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings", "AppPackage/Sources/SettingFeature/SettingPath.swift", "AppPackage/Sources/SettingFeature/SettingReducer+Body.swift", "AppPackage/Sources/SettingFeature/SettingView.swift", "AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift", "AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift", "AppPackage/Tests/AnalyticsClientTests/AnalyticsLevelGateTests.swift", "AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift", "AppPackage/Tests/AnalyticsClientTests/InstallSourceTests.swift", "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift", "AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift", "AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift", "AppPackage/Tests/AppFeatureTests/UITestStubTests.swift", "AppPackage/Tests/AppModelsTests/BlockedCommentUserTests.swift", "AppPackage/Tests/AppModelsTests/SettingFirstLaunchFieldsTests.swift", "AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift", "AppPackage/Tests/CookieClientTests/CookieClientTests.swift", "AppPackage/Tests/DetailFeatureTests/BlockedCommentPresentationTests.swift", "AppPackage/Tests/DetailFeatureTests/CommentCardLayoutTests.swift", "AppPackage/Tests/DetailFeatureTests/CommentFilterTests.swift", "AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift", "AppPackage/Tests/DetailFeatureTests/CommentOwnershipTests.swift", "AppPackage/Tests/DetailFeatureTests/CommentReportTargetTests.swift", "AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift", "AppPackage/Tests/DownloadsFeatureTests/AppReadingFlushTests.swift", "AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift", "AppPackage/Tests/DownloadsFeatureTests/DownloadObserverReadingTests.swift", "AppPackage/Tests/ParserFeatureTests/Gallery/GalleryCommentParserTests.swift", "AppPackage/Tests/ReadingFeatureTests/AnalyticsEmissionTests.swift", "AppPackage/Tests/ReadingFeatureTests/AutoPlayHandlerTests.swift", "AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift", "AppPackage/Tests/ReadingFeatureTests/PagerSeedTests.swift", "AppPackage/Tests/ReadingFeatureTests/ReaderPagesAccessibilityTests.swift", "AppPackage/Tests/ReadingFeatureTests/ReaderPositionTests.swift", "AppPackage/Tests/ReadingFeatureTests/ReadingOrientationTests.swift", "AppPackage/Tests/SettingFeatureTests/BlockedUsersReducerTests.swift", "AppPackage/Tests/SettingFeatureTests/GeneralSettingReducerTests.swift", "AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift", "AppPackage/Tests/VisualSnapshotTests/ReaderListPositionTests.swift", "EhPandaUITests/BlockedUsersTitleLayoutUITests.swift", "EhPandaUITests/CommentModerationUITests.swift", "EhPandaUITests/FirstLaunchTitleLayoutUITests.swift", "EhPandaUITests/FirstLaunchUITests.swift", "EhPandaUITests/ReaderRebuildUITests.swift", "EhPandaUITests/SettingsModerationUITests.swift", "EhPandaUITests/Support/LocalizedLaunch.swift", "EhPandaUITests/Support/ReaderPageProbe.swift", "EhPandaUITests/Support/UITestConstants.swift", "README.md", "READMEs/README.chs.md", "READMEs/README.cht.md", "READMEs/README.de.md", "READMEs/README.jpn.md", "READMEs/README.ko.md", "Scripts/visual/test_release.py", "Scripts/visual/verify-release.py"]
covered_digest: "v4:sha256:8996378ebabb522ed3ff4f8f174315b38be690c33af9d16765ac95e94cca39d5"
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "DIST-18-01 marketplace build flavor"
    addressed_in: "Phase 20"
    evidence: "ROADMAP Phase 18 split map: DIST-18-01 → 18 (`MKSellsDigitalGoods`) and 20 (marketplace build flavor); REQUIREMENTS.md traceability row DIST-18-01"
  - truth: "UGC-18-01 published contact link"
    addressed_in: "Phase 20"
    evidence: "ROADMAP Phase 18 scope item 4 (Ampo msg 1774) and split map; REQUIREMENTS.md traceability row UGC-18-01"
  - truth: "Visual snapshots of the Phase 18 screens (UI-SPEC 'visual' backstop row)"
    addressed_in: "Phase 19"
    evidence: "18-UI-SPEC.md UI Considerations: 'Phase 19 snapshots must include frames 01–22's states'; ROADMAP Phase 19 covers the Phase 18 screens"
---

# Phase 18: In-App 3.0 Readiness: verification report

**Phase goal (ROADMAP):** Finish every in-app change 3.0 needs, in every build, before the visual baseline and
distribution work start. Every user, upgraders included, sees two first-launch screens once: an age wall, then an
analytics choice with nothing pre-selected. No content, network request or analytics SDK start happens before them.
Comments gain an E-Hentai report action, a posting warning, and local blocking with a Blocked Users list in Settings
(App Review Guideline 1.2). The reader gets one source of truth for its current page, with committed UI tests for
Phase 17's gaps G1/G2. IN-02, IN-03 and `MKSellsDigitalGoods` are closed.

**Verified:** 2026-11-05 (UTC), at `a1f96cb88`. The code under test is `e3c95a3bf`; every later commit changes
planning documents only (`git diff --stat e3c95a3bf..HEAD -- . ':!.planning'` is empty).
**Status:** passed
**Re-verification:** Refreshed 2026-11-05 (UTC) at `b961ea4d8`, after the review fix `c3ef39ac9` (IN-01). That commit
changes only `ParserFeature/Parser+Comment.swift` and `GalleryCommentParserTests.swift`
(`git diff --stat e3c95a3bf c3ef39ac9 -- . ':!.planning'`); every later commit changes planning documents only.
The verifier re-read the changed files against truths 6 and 10, and every truth still holds. The full FeatureTests
were rerun at `c3ef39ac9` on both devices (truth 10). The UITests were not rerun in full; the one UI class the
change can reach, `CommentModerationUITests`, was rerun on both devices.
**Who ran it:** the code-reviewer, code-fixer and verifier roles ran in one agent, in sequence, each following its
`gsd-*` agent definition (code-reviewer, then code-fixer, then verifier). They were not separate subagents.

**Amendments in force:** the analytics level "None" became **Minimal** (owner msgs 1805, 1818; CONTEXT D-06a to
D-06c). Minimal sends only one install signal with its install source, and the SDK never starts under Minimal, so no
level sends nothing. The Basic and Full descriptions and the intro line changed later (D-06d to D-06f). Blocking
matches the poster's E-Hentai member ID, not the display name (owner msg 1918, SC6 amendment). This report verifies
the criteria as amended.

## Goal Achievement

### Observable truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The age wall comes first on every 3.0 launch, fresh install or upgrade, before any content or network request. Continue stays dimmed until the declaration is ticked, there is no skip, and the answer is stored on the device | ✓ VERIFIED | `RootView.content` renders `FirstLaunchGateView` instead of `TabBarView` until `firstLaunch.step == .complete`, so nothing of the app is built behind the wall. `AppReducer` runs the deferred launch only after `.ageConfirmed` (lines 446-450). `FirstLaunchGateTests` has 31 cases (gate, storage, upgrader paths, link queueing). `FirstLaunchUITests.testAFreshLaunchShowsOnlyTheAgeWallAndMakesNoRequest` asserts no app content and no stubbed request, and `testTickingTheStatementGatesContinue` checks the dimmed Continue. On a fresh Release install 18-12 found no socket and no URL task for 30 s at the wall (`lsof` and `log stream`) |
| 2 | The analytics choice follows: Minimal, Basic and Full, equally prominent and none pre-selected. Tests prove no SDK call before the choice and none under Minimal, and each level sends only what its description says | ✓ VERIFIED | `FirstLaunchUITests.testTheAnalyticsChoiceStartsEmptyAndRecommendsBasicOnly`. `AnalyticsLevelGateTests` (13, including `nil` = before the choice), `AnalyticsClientGateTests` (5), `InstallSignalSenderTests` (13), `AnalyticsSignalRenderingTests`, and the per-feature `AnalyticsEmissionTests` (one per feature module). `AnalyticsClient` stops the SDK and never starts it under `.minimal` (line 35 doc, line 89 switch) |
| 3 | Settings has a three-level analytics picker in place of the toggle, a footer with the selected level's description, and a Privacy Policy row. The "installation is still counted" footer is gone | ✓ VERIFIED | `GeneralSettingView.swift:205` `Picker(.shareAnalyticsData, …)`. No string "installation is still counted" anywhere in `AppPackage/Sources` or `App` (grep; the only hit is a code comment describing the retired Phase 14 premise). `SettingsModerationUITests.testTheAnalyticsPickerChangesTheLevelAndItsDescription` passes on both devices and in dark on the phone (below) |
| 4 | Every comment has "Report on {site}", which confirms, then opens the gallery's report page on E-Hentai or ExHentai. There is no email or other contact path | ✓ VERIFIED | `CommentReportTarget.reportURL(for:)` builds only `https` `/g/<gid>/<token>/?report=select`. No `mailto` in the moderation code. `CommentModerationUITests.testTheMenuOffersReportThenBlockAndReportOpensTheSignedInSheet`. Live check with a real account, signed in and signed out (18-12 Task 3, agent-run per owner rule msg 1652; the signed-out guest page is accepted deviation 9) |
| 5 | Posting or editing a comment that matches the filter shows the posting warning (Edit by default, Post Anyway). It never names the matched word and keeps the typed text | ✓ VERIFIED | `CommentFilterTests` (18), `CommentModerationReducerTests` (25, including edit-path and text-kept cases), `CommentModerationUITests.testAMatchingCommentWaitsForTheSecondTap` |
| 6 | Blocking collapses the poster's comments, in the list and the Detail preview, into "Comment from a user you've blocked" with Show and Unblock and without the name. The block is stored on this device only, and Settings lists blocked users with an empty state and swipe to unblock. Blocks match the member ID (msg 1918) | ✓ VERIFIED | `BlockedCommentUserTests` (9), `BlockedCommentPresentationTests` (16), `BlockedUsersReducerTests` (6), `GalleryCommentParserTests` member-ID cases, including the look-alike-host cases added with the IN-01 fix (`c3ef39ac9`: only the exact contact link `https://forums.e-hentai.org/index.php` with a digits-only `showuser` gives an ID). `CommentModerationUITests` block, strip and collapsed-card cases, and `SettingsModerationUITests` swipe, context-menu and empty-state cases, on both devices. Storage is `@Shared(.blockedCommentUsers)` (local app storage, no sync) |
| 7 | All new strings come verbatim from the two approved copy files, every `.xcstrings` key is filled for six locales, and the six READMEs' Analytics sections describe the three levels | ✓ VERIFIED | Rerun at verification: `18-copy-check.py` reports "38 keys x 6 locales verbatim; 48 retired texts absent"; `--self-test` 21/21; `--readmes` "6 Analytics sections hold the three levels verbatim; no retired text" |
| 8 | The reader keeps one source of truth for the page shown and the number displayed. Committed UI tests cover Reload All Images then a turn, a direction change during Auto-Play, and an LTR/RTL switch (G1/G2), and pass | ✓ VERIFIED | 18-07: `ReaderPosition` (`ReaderPositionTests`, 27 cases). `PageModel.swift` and `PagerTurnGateTests.swift` were deleted, the old separate copies. `ReaderRebuildUITests`: `testReloadAllImagesThenATurn…`, its drop-idle variant, `testChangingDirectionDuringAutoPlay…` and `testSwitchingLeftToRightAndRightToLeft…`. All pass in the full UITests runs on both devices (18-12 gate). The iPad two-page spread stays a known limit (DD-03) |
| 9 | IN-02 and IN-03 are closed, and `MKSellsDigitalGoods` is `NO` | ✓ VERIFIED | `verify-release.py:31` `b'captureSystemOverlay'` (from `d006f6531`, an ancestor of HEAD) plus the `test_release.py:129-139` case. `test_release.py` was rerun: 20 tests OK. `RootView.swift:3-5` imports `AppComponents` inside `#if DEBUG`. `App/Info.plist:132-133` `MKSellsDigitalGoods` `<false/>`. On the Release app, `plutil` reads `false` (18-12) |
| 10 | The UI matches the UI-SPEC, and FeatureTests and UITests pass on the phone, then the tablet, with 0 failures, 0 Repetition and strict no-cache lint | ✓ VERIFIED | Refresh at `c3ef39ac9`: FeatureTests phone 1755 total, 1745 passed, 0 failed, 10 expected failures; pad 1755 total, 1746 passed, 0 failed, 9 expected failures; 0 Repetition nodes on each (the two new cases are the IN-01 tests). `CommentModerationUITests` 7/7 on each device. SwiftLint `--strict --no-cache` over the gate paths: 0 violations. Earlier gate at `e3c95a3bf` (18-12, reused by 18-REGRESSION-GATE.md). FeatureTests: phone 1743 passed and 0 failed; pad 1744 passed and 0 failed (run 2). UITests: phone 100 passed and 0 failed; pad 103 passed and 0 failed. 0 Repetition nodes. SwiftLint `--strict --no-cache` 0 violations in 805 files. UI-SPEC match: see "UI-SPEC comparison" below |

**Score:** 10/10 truths verified.

### Plan must-haves (supporting)

All 12 plans have a SUMMARY with `status: complete`. Their must-haves roll up into the truths above:

- 18-01 → truth 9.
- 18-02, 18-03, 18-09 → truths 1 and 2.
- 18-04, 18-05, 18-11 → truths 4 to 6.
- 18-06 → truth 7.
- 18-07, 18-08 → truth 8.
- 18-10 → truths 3 and 6.
- 18-12 → truths 6, 7 and 10.

18-VALIDATION.md is `status: validated` with 34 rows green (row 18-12-04, member-ID blocking, added by the validation audit) and `nyquist_compliant: true`.

### Deferred items (later phases, not satisfied here)

- The DIST-18-01 marketplace build flavor (Phase 20).
- The UGC-18-01 published contact link (Phase 20).
- The snapshot backstop for the Phase 18 screens (Phase 19).

All three are by the owner's split (msg 1753) and are in the frontmatter.

### Required artifacts and key links (spot-checked)

| Link | Status |
|------|--------|
| `RootView` → `FirstLaunchGateView` until `step == .complete`, then `TabBarView` | WIRED |
| `AppReducer` `.firstLaunch(.delegate(.ageConfirmed))` → `deferredLaunchEffect` (the launch network work) | WIRED |
| `AppReducer` `.levelChosen` → `analyticsLevelEffect` → `AnalyticsClient` level switch | WIRED |
| `CommentModerationMenu` → `CommentReportTarget.reportURL` → report sheet (`SessionWebView`) | WIRED |
| Block → `@Shared(.blockedCommentUsers)` → comments list, Detail strip and `BlockedUsersView` | WIRED |
| `AccountSettingView` Blocked Users row → `SettingPath` push → `BlockedUsersReducer` | WIRED |

### Behavioral spot-checks run at verification

| Check | Result |
|-------|--------|
| `18-copy-check.py`, `--self-test`, `--readmes` | PASS (above) |
| `python3 -m unittest test_release` | 20 tests OK |
| All commits since `5eec7ab3a` signed | 80 of 80 `G` |
| Dark-appearance UI pass, phone (`FFE7E686`): `SettingsModerationUITests`, `FirstLaunchUITests`, `CommentModerationUITests` | 16 tests, 0 failures (`** TEST SUCCEEDED **`, 338 s). Appearance set to dark for the run and restored to light afterwards |
| Dark-appearance UI pass, pad (`B470DB46`) | `FirstLaunchTitleLayoutUITests.testEnglishTitles`, `SettingsModerationUITests`, and the comment menu and block cases: 6 tests, 0 failures (`** TEST SUCCEEDED **`, 178 s). Matches frames 20 and 21. The first attempt did not start: the runner failed to launch on the just-booted simulator ("Host is down") before any test ran. A clean reboot and rerun passed. Appearance restored to light; both simulators shut down afterwards |

### UI-SPEC comparison (truth 10)

The 18-12 runs at `e3c95a3bf` (light) and the dark runs above kept their screenshots as test attachments. They were
exported to a temporary folder outside the repo, compared with `mockups/`, and are not committed.

| Mockup frame | Built screen (attachment) | Result |
|--------------|---------------------------|--------|
| 01 age wall light, unticked | `age-wall-en-default`, phone and pad | Matches: title, body, checkbox card unticked, dimmed Continue, footnote under Continue |
| 03 analytics light, empty | `analytics-choice-en-default` | Matches: three equal cards, no selection, "Recommended" on Basic only, Continue disabled |
| 17 / 18 AX5 | `age-wall-en-AX5-bottom`, `analytics-choice-en-AX5-basic` (light and dark) | Matches: content scrolls under the pinned Continue bar |
| 05 comment menu | `comments-menu-open` (phone, pad) | Matches: Report on {site}, then Block |
| 07 block confirm, dark | `comments-block-alert` (dark, phone) | Matches: "Block {name}?", the approved body, Cancel and a destructive Block |
| 08 / 09 collapsed and revealed rows | `comments-blocked-row`, `comments-revealed-row` (dark) | Matches: `eye.slash`, "Comment from a user you've blocked", no name in the collapsed row; Hide on the revealed row |
| 10 posting warning | `comments-posting-warning` | Matches |
| 11 Detail preview | `strip-collapsed-card`, `strip-card-menu` | Matches: collapsed card at equal size |
| 12 / 13 Settings analytics | `settings-analytics-minimal`, `-full` (light; dark Minimal) | Matches: Picker in the menu style, Privacy Policy row with `arrow.up.right`, footer with the level description |
| 14 Blocked Users | `blocked-users-list` | Matches: inset grouped names and the footer |
| 15 empty, dark | `blocked-users-empty` (dark, phone) | Matches: `hand.raised` and "You haven't blocked anyone.", no footer |
| 23 / 24 Account row | `account-blocked-users-row` | Matches: the row with a secondary count and chevron |

The 18-11 finding (the `…` glyph drawn in the accent tint) was fixed in `1f653a282`. In the light and dark
comment screenshots the `…` is the muted gray `.secondary`, as the UI-SPEC says.

### Regression gate

18-REGRESSION-GATE.md (`a1f96cb88`) reused the 18-12 runs at `e3c95a3bf` because no code changed after it. Earlier
phases' FeatureTests and UITests are green on both devices, so no regression was found.

### Requirements coverage

| Requirement | Phase 18 part | Status |
|-------------|---------------|--------|
| AGE-18-01 | All | ✓ Complete (truth 1) |
| CONSENT-18-01 | All | ✓ Complete (truths 2 and 3) |
| UGC-18-01 | Report, posting warning, blocking | ✓ Complete (truths 4 to 6); the contact link is Phase 20 |
| DIST-18-01 | `MKSellsDigitalGoods` only | ✓ Phase 18 part done (truth 9); stays Pending overall for the Phase 20 marketplace flavor |
| (no ID) Reader rework with the G1/G2 UI tests | All | ✓ (truth 8) |
| (no ID) Phase 17 IN-02 and IN-03 | All | ✓ (truth 9) |

### Anti-patterns found

None blocking. The phase code review (18-REVIEW.md, 26fec4b67) found 0 Critical, 0 Warning and 3 Info items, now
settled in 18-REVIEW-DISPOSITION.md:

- IN-01: the member-ID host check accepted any host ending in `e-hentai.org`. Fixed in `c3ef39ac9`, with tests.
- IN-02: two reducers use the `Reducer` suffix instead of AGENTS.md's `Feature` suffix. Accepted exception (the
  lead's decision): screens inside an existing `*Reducer` tree keep the suffix.
- IN-03: a link opened during the analytics choice routes at once. Accepted by the lead: nothing is shown and no
  analytics is sent before the choice, and D-04 and DD-07 allow the content fetch after the age confirmation.

### Human verification required

None. Every check an agent can run was run: the no-network observation, the live report page, the dark pass and the
UI-SPEC comparison. The manual-only rows of 18-VALIDATION.md are covered as follows:

- The report page and no-network-before-age-wall rows are agent-verified (18-12).
- The iPad two-page spread is a known limit (DD-03).
- The title C-3 tables are in 18-09 and 18-10.

Accepted items, not failures:

- The phone AX5 title cases (owner msg 1903). The phone AX5 en/de `blocked_users.empty` cases were accepted by the
  lead.
- The signed-out report page shows the site's guest page (18-12 deviation 9).

### Open process items (for the owner, not gaps)

- `verify:post` hooks:
  - nyquist `validate-phase`: run. 18-VALIDATION.md is `status: validated` (1 gap found and resolved, 0 escalated).
  - security `secure-phase`: run. 18-SECURITY.md is `status: verified`, `threats_open: 0`: 23 of 24 threat IDs are
    closed. T-18-SC (package installs, low, planned as `accept`) stays open below the threshold until the owner
    accepts it.
  - ui `ui-review`: not run.
- The credentialed check that `App.installed` reaches TelemetryDeck at Minimal was not run, to avoid sending a real
  install signal to the owner's analytics. The `InstallSignalSender` unit tests cover it.

### Gaps summary

No gaps. Phase 18 achieves its goal at the amended criteria.
