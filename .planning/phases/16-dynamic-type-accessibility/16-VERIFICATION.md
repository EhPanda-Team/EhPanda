---
phase: 16-dynamic-type-accessibility
verified: 2026-09-23T06:58:01Z
status: passed
score: 26/26 must-haves verified
behavior_unverified: 0
overrides_applied: 8
verification_scope: approved best-effort contract; historical and unmeasured limits retained
verified_head: a46ef238
metadata_rechecked: 2026-09-23T07:10:03Z
metadata_rechecked_head: 01103bf1b72f7d94ea3e50e9213a70ca41ec034e
tested_source: 7675a7ac77301de9464a8e924c9fc8c70f691849
human_verification: []
decision_coverage:
  honored: 34
  total: 34
  not_honored: []
overrides:
  - must_have: "Every user-facing screen remains readable and operable throughout the complete Dynamic Type range, including accessibility sizes (AX1–AX5), without clipped essential text, overlapping content, or unreachable controls."
    reason: "The owner signed the sampled round-1 matrix with six accepted findings and bounded title budgets, then accepted D-25 finding #39 and the explicitly unreached scope. This verifies the approved sampled outcome, not universal absence of clipping. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "Layouts adapt via reflow (wrap / ViewThatFits / stacking), never by capping Dynamic Type (dynamicTypeSize cap) or clipping."
    reason: "Reflow is retained, with the owner-approved lower reader-control range large...xxLarge; the dedicated error-level rule confines this exception to ControlPanel.swift. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "Default-size (.large) appearance parity is preserved — no visible change at the default size."
    reason: "Owner-approved exceptions include the five-line thumbnail budget and comment score/date parity finding #35; the signed baseline and later native iOS 27 policy supersede literal universal pixel parity. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "Every interactive element is reachable and correctly announced under VoiceOver — icon-only controls carry labels, decorative images are hidden, state is expressed as traits rather than label text, and reading order and post-navigation focus are correct."
    reason: "Best-effort main-flow walkthrough and stable audits replace a universal claim. Fifteen unreached sites, accepted focus behavior, native double-tap limits, W-21/W-24, and other explicitly carried findings remain recorded. W-38 is bounded owner-approved evidence. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "Every interactive element is actuatable by Voice Control — it appears under Show numbers and Show names, and its input label matches its visible text."
    reason: "Owner-approved English native-label proxy verifies names and structure; spoken Voice Control commands remain unmeasured. No speech-activation guarantee is inferred. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "All text meets WCAG 4.5:1 and non-text elements 3:1, in light and dark and under Increase Contrast. Gallery category background colors stay byte-identical; badge text becomes adaptive black/white."
    reason: "Owner reversal cc05aca6 removed adaptive contrast code and color fixes. White text and retained Increase Contrast backgrounds are intentional. Tests pin 44 standard and 40 high-contrast variants; they do not prove text contrast. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "No information is conveyed by color alone — every color-coded state also carries a shape, glyph, or text."
    reason: "Owner reversal cc05aca6 withdrew the added Activity Logs/Laboratory glyphs. Retained names, native toggle/selection semantics and bounded grayscale observations satisfy the approved best-effort scope, not a universal visual DWC guarantee. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
  - must_have: "A Nutrition Label recommendation is produced, stating which categories are claimable and why."
    reason: "Owner decision 2026-09-15 replaced this deliverable with the main-flow walkthrough, D-25 re-sweep, closing gates and owner sign-off. No Nutrition Label recommendation or App Store guarantee is required or produced. Ratified by whole-phase approval recorded in a4cc3754; accepted_at records its observed UTC time, not a claimed message timestamp."
    accepted_by: owner
    accepted_at: 2026-09-23T06:35:48Z
covered_files:
  - ".github/workflows/deploy-pre-release.yml"
  - ".github/workflows/deploy.yml"
  - ".github/workflows/test.yml"
  - ".gitignore"
  - ".planning/PROJECT.md"
  - ".planning/REQUIREMENTS.md"
  - ".planning/ROADMAP.md"
  - ".planning/STATE.md"
  - ".planning/debug/phase16-search-menu.md"
  - ".planning/phases/15-continued-background-downloads/15-77-SUMMARY.md"
  - ".planning/phases/15-continued-background-downloads/15-UAT.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-01-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-01-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-02-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-02-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-03-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-03-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-04-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-04-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-05-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-05-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-06-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-06-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-07-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-07-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-08-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-08-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-09-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-09-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-10-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-10-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-11-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-11-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-12-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-12-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-13-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-13-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-14-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-14-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-15-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-15-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-16-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-16-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-17-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-17-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-18-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-18-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-19-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-19-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-20-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-20-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-21-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-21-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-22-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-22-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-23-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-23-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-24-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-24-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-25-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-25-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-26-PLAN.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-26-SUMMARY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-AGENT-WALKTHROUGH-RESEARCH.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-AX-POLICY-REVIEW.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-CLOSEOUT-NOTES.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-CONTEXT.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-DISCUSSION-LOG.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-FOCUS-INVESTIGATION.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-LOGIN-COVER-RECHECK.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-PATTERNS.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-RECONCILIATION.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-REFLOW-PATTERNS.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-RESEARCH.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-REVIEW.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-SECURITY.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-SETTING-TAB-ROOT-CAUSE.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-TARGETED-RECHECK.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-UI-REVIEW.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-VALIDATION.md"
  - ".planning/phases/16-dynamic-type-accessibility/16-W38-ROOT-CAUSE.md"
  - ".planning/phases/16-dynamic-type-accessibility/deferred-items.md"
  - ".planning/quick/20260908-slideshow-viewport-cap/PLAN.md"
  - ".planning/quick/20260908-slideshow-viewport-cap/REVISION.md"
  - ".planning/quick/20260908-slideshow-viewport-cap/SUMMARY.md"
  - ".planning/quick/260907-n39-unify-cover-sizing-with-bounded-dynamic-/260907-n39-PLAN.md"
  - ".planning/quick/260907-n39-unify-cover-sizing-with-bounded-dynamic-/260907-n39-SUMMARY.md"
  - ".planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/260921-f5u-PLAN.md"
  - ".planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/260921-f5u-SUMMARY.md"
  - ".planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/260921-f5u-VERIFICATION.md"
  - ".planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/COVERAGE.md"
  - ".planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md"
  - ".planning/state.json"
  - ".swiftlint.yml"
  - "AGENTS.md"
  - "App/Assets.xcassets/Category/Colors/E-Hentai/Asian Porn.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/E-Hentai/Cosplay.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/E-Hentai/Doujinshi.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/E-Hentai/Game CG.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/E-Hentai/Image Set.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/E-Hentai/Misc.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Asian Porn.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Cosplay.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Doujinshi.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Image Set.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Manga.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Misc.colorset/Contents.json"
  - "App/Assets.xcassets/Category/Colors/ExHentai/Non-H.colorset/Contents.json"
  - "AppPackage/Package.swift"
  - "AppPackage/Sources/AppComponents/AdaptiveStack.swift"
  - "AppPackage/Sources/AppComponents/AppToggle.swift"
  - "AppPackage/Sources/AppComponents/CategoryView.swift"
  - "AppPackage/Sources/AppComponents/ErrorInfoView.swift"
  - "AppPackage/Sources/AppComponents/FlowLayout.swift"
  - "AppPackage/Sources/AppComponents/GalleryCover.swift"
  - "AppPackage/Sources/AppComponents/GalleryCoverMetrics.swift"
  - "AppPackage/Sources/AppComponents/GalleryCoverStyle.swift"
  - "AppPackage/Sources/AppComponents/GalleryViewport.swift"
  - "AppPackage/Sources/AppComponents/NewDawnView.swift"
  - "AppPackage/Sources/AppComponents/PreviewImageView.swift"
  - "AppPackage/Sources/AppComponents/RatingView.swift"
  - "AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/AppComponents/StateViews.swift"
  - "AppPackage/Sources/AppComponents/SubSection.swift"
  - "AppPackage/Sources/AppComponents/TagCloudView.swift"
  - "AppPackage/Sources/AppComponents/TagSuggestionView.swift"
  - "AppPackage/Sources/AppComponents/ToolbarItems.swift"
  - "AppPackage/Sources/AppComponents/UnhighlightedButtonStyle.swift"
  - "AppPackage/Sources/AppComponents/ViewModifiers.swift"
  - "AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift"
  - "AppPackage/Sources/AppFeature/View/TabBar/TabBarReducer.swift"
  - "AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift"
  - "AppPackage/Sources/AppModels/Download/DownloadFolderFilter.swift"
  - "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
  - "AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift"
  - "AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift"
  - "AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift"
  - "AppPackage/Sources/DetailFeature/Comments/CommentsView.swift"
  - "AppPackage/Sources/DetailFeature/Components/LinkedText.swift"
  - "AppPackage/Sources/DetailFeature/Components/PostCommentView.swift"
  - "AppPackage/Sources/DetailFeature/Components/TagDetailView.swift"
  - "AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+Navigation.swift"
  - "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift"
  - "AppPackage/Sources/DetailFeature/DetailView.swift"
  - "AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift"
  - "AppPackage/Sources/DetailFeature/GalleryComment+Accessibility.swift"
  - "AppPackage/Sources/DetailFeature/GalleryDestination.swift"
  - "AppPackage/Sources/DetailFeature/GalleryDetail+Accessibility.swift"
  - "AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift"
  - "AppPackage/Sources/DetailFeature/HeaderActionsLayout.swift"
  - "AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift"
  - "AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift"
  - "AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift"
  - "AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift"
  - "AppPackage/Sources/DownloadsFeature/DownloadsView.swift"
  - "AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift"
  - "AppPackage/Sources/FavoritesFeature/FavoritesView.swift"
  - "AppPackage/Sources/FavoritesFeature/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/FiltersFeature/FiltersView.swift"
  - "AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift"
  - "AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift"
  - "AppPackage/Sources/GalleryListComponents/GalleryList.swift"
  - "AppPackage/Sources/GalleryListComponents/MasonryLayout.swift"
  - "AppPackage/Sources/GalleryListComponents/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift"
  - "AppPackage/Sources/HomeFeature/GalleryCardCell.swift"
  - "AppPackage/Sources/HomeFeature/GalleryCardHeightLayout.swift"
  - "AppPackage/Sources/HomeFeature/GalleryCardLayout.swift"
  - "AppPackage/Sources/HomeFeature/GalleryRankingCell.swift"
  - "AppPackage/Sources/HomeFeature/History/HistoryView.swift"
  - "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
  - "AppPackage/Sources/HomeFeature/HomeView.swift"
  - "AppPackage/Sources/HomeFeature/Popular/PopularView.swift"
  - "AppPackage/Sources/HomeFeature/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift"
  - "AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift"
  - "AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift"
  - "AppPackage/Sources/HomeFeature/Watched/WatchedView.swift"
  - "AppPackage/Sources/NetworkingFeature/Request+Account.swift"
  - "AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift"
  - "AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift"
  - "AppPackage/Sources/ReadingFeature/ReadingView.swift"
  - "AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift"
  - "AppPackage/Sources/ReadingFeature/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift"
  - "AppPackage/Sources/ReadingFeature/Support/AutoPlayHandler.swift"
  - "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift"
  - "AppPackage/Sources/ReadingFeature/Support/ReadingToolbar.swift"
  - "AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift"
  - "AppPackage/Sources/ReadingSettingFeature/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/SearchFeature/GalleryHistoryCell.swift"
  - "AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift"
  - "AppPackage/Sources/SearchFeature/SearchRootView.swift"
  - "AppPackage/Sources/SearchFeature/SearchView.swift"
  - "AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift"
  - "AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift"
  - "AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift"
  - "AppPackage/Sources/SettingFeature/Components/AboutView.swift"
  - "AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift"
  - "AppPackage/Sources/SettingFeature/Components/DownloadSettingView.swift"
  - "AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift"
  - "AppPackage/Sources/SettingFeature/Components/WebView.swift"
  - "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift"
  - "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift"
  - "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift"
  - "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift"
  - "AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift"
  - "AppPackage/Sources/SettingFeature/Login/LoginView.swift"
  - "AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings"
  - "AppPackage/Sources/SettingFeature/SettingView.swift"
  - "AppPackage/Sources/SystemNotification/ToastMessageView.swift"
  - "AppPackage/Sources/SystemNotification/View+Toast.swift"
  - "AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift"
  - "AppPackage/Tests/AppFeatureTests/TabBarSettingPresentationTests.swift"
  - "AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift"
  - "AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift"
  - "AppPackage/Tests/AppToolsTests/RepositoryWalk.swift"
  - "AppPackage/Tests/DetailFeatureTests/HeaderActionsLayoutTests.swift"
  - "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionSubmissionTests.swift"
  - "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift"
  - "AppPackage/Tests/DownloadsFeatureTests/ContinuedSubmissionCoordinatorTests.swift"
  - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionHeartbeatTests.swift"
  - "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift"
  - "AppPackage/Tests/FavoritesFeatureTests/LoginReturnObservationTests.swift"
  - "AppPackage/Tests/FavoritesFeatureTests/SortSelectionTests.swift"
  - "AppPackage/Tests/FeatureTests.xctestplan"
  - "AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift"
  - "AppPackage/Tests/HomeFeatureTests/GalleryCoverLayoutTests.swift"
  - "AppPackage/Tests/HomeFeatureTests/LoginReturnObservationTests.swift"
  - "AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift"
  - "AppPackage/Tests/NetworkingFeatureTests/LoginRejectionSurfacingTests.swift"
  - "AppPackage/Tests/ReadingFeatureTests/AutoPlayHandlerTests.swift"
  - "AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift"
  - "EhPanda.xcodeproj/project.pbxproj"
  - "EhPandaUITests/AccessibilityAuditUITests.swift"
  - "EhPandaUITests/DeepLinkSchemeUITests.swift"
  - "EhPandaUITests/DetailNavigationTitleUITests.swift"
  - "EhPandaUITests/IOS27MigrationUITests.swift"
  - "EhPandaUITests/ReaderPageSyncUITests.swift"
  - "EhPandaUITests/ShareSheetUITests.swift"
  - "EhPandaUITests/Support/AccessibilityAuditReport.swift"
  - "EhPandaUITests/Support/DeepLinkLauncher.swift"
  - "EhPandaUITests/Support/ReaderPageProbe.swift"
  - "README.md"
  - "READMEs/README.chs.md"
  - "READMEs/README.cht.md"
  - "READMEs/README.de.md"
  - "READMEs/README.jpn.md"
  - "READMEs/README.ko.md"
  - "UITests.xctestplan"
covered_digest: "v1:sha256:cbae9d6b5d155ba328a0822881b086c3486c4a4dc29f20f48f2665aecf80be81"
---
# Phase 16: Accessibility Verification Report

**Status: passed — within the explicitly approved best-effort contract.** Score: **26/26 consolidated truths**, including **8 owner overrides**. This is not a claim of universal accessibility or App Store eligibility.

**Phase goal:** Round 1 completes Dynamic Type readability and operability on Phase 10's foundation; round 2 adds systematic VoiceOver, Voice Control, Reduce Motion, contrast and Differentiate Without Color support. The roadmap's original Nutrition Label wording is historical: the owner replaced that bar on 2026-09-15, withdrew specified visible changes in `cc05aca6`, and approved the assembled closure in `a4cc3754`.

**Verification mode:** Initial canonical goal verification; no previous `16-VERIFICATION.md` existed. Current source, all 26 PLAN/SUMMARY records, the sweep and amendments, requirements, review/security/validation records, and existing runtime evidence were cross-referenced. SUMMARY assertions alone were not used as proof. This report changes no implementation or workflow status and makes no commit.

## Evidence basis and scope

- **Current source:** `7675a7ac77301de9464a8e924c9fc8c70f691849` remains the implementation at report HEAD `a46ef238`; later committed changes are documentation only. The pre-existing uncommitted project serialization edit was preserved.
- **Final fingerprint:** all **809** current source/config files independently match `source-after-reader-probe-fix.json`, including the dirty project file. This is the snapshot consumed by `run-final-ui.py` and `final-cleanup.py`. The earlier `source-after-full-gates.json` still has two pre-fix UI-test hashes; it is not the final source fingerprint.
- **Archived evidence:** `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260923/` (called **close/** below). The selected final summaries, test trees, logs and source snapshots match their `archive-sha256.json` entries. The manifest lists 8,552 files; this verifier checked the evidence it used, not every archived byte.
- **Existing runtime evidence, no reruns:** the dispatch explicitly prohibited builds, tests and simulator operations. This verifier inspected named results from the existing test trees and their test implementations, rather than claiming a new test execution. No server, package installation, network request or simulator action was performed.
- **Human decisions are complete:** round 1 was signed at `d5afe78f` on 2026-09-11. Round 2's exact reply `approved` was observed at 2026-09-23T06:35:48Z over `30f54fe93729ebd8885dbea488b5a1445eaa9453`. The timestamp is an observation time. It covers the explicit accepted, carried, deferred and unmeasured limits.
- **No scope expansion:** D-25 remains nine iPhone portrait cells; no additional iPad, landscape, Gallery Detail, Activity Logs or Laboratory re-sweep is invented. Native iOS 27 title/search behavior supersedes the removed workarounds.

## Goal achievement

The twelve roadmap criteria are retained below; broad historical wording is not silently treated as proven. Repeated PLAN details are consolidated into fourteen additional checks. The plan mapping accounts for all **211 raw PLAN truths**, with the scope changes applied before judging them.

| # | Observable truth / roadmap contract | Status | Evidence and precise disposition |
|---|---|---|---|
| 1 | Every user-facing screen remains readable and operable across the full Dynamic Type range without clipping, overlap or unreachable controls. | PASSED (override) | Signed 42-surface, 504-cell round-1 record; 32 re-verified and 6 explicitly accepted findings, five D-13 dispositions. Accepted title budgets, unexercised states and D-25 #39 prevent a universal claim. Current reflow exists in CategoryView, TagCloudView, gallery cells, Detail and settings. |
| 2 | Layouts reflow rather than cap Dynamic Type or clip. | PASSED (override) | Reflow uses scaled metrics, wrapping and measured/container layouts. The sole source `.dynamicTypeSize(...)` is `ReadingFeature/Support/ControlPanel.swift:53`, the owner-approved `.large ... .xxLarge` lower-control range. Two complementary error-level rules enforce its boundary. |
| 3 | Default `.large` appearance parity is preserved. | PASSED (override) | Owner signed D-15 comparisons and accepted #35; five-line thumbnail titles and bounded hero/Detail budgets are explicit owner design changes. Native iOS 27 presentation policy applies now. Original four `d15-baseline/large-*.png` files are absent today, so no fresh pixel comparison is claimed. |
| 4 | Five Phase 10 AX5 edge cases are fixed or explicitly accepted. | VERIFIED | SWEEP D-13: statistics, long tags, reader counter and Favorites paired page count are owner-approved fixed; hero-title ellipsis is accepted. Current source retains wrapping, native page indicator and bounded hero design. |
| 5 | Owner-signed UAT covers XXL / AX3 / AX5 including authenticated screens. | VERIFIED | SWEEP “Owner sign-off” records the exact 2026-09-11 approval, covered commit and closed Phase 10 device gate; later logged-in iPad checks supersede the original blocked entries. Round-2 sign-off ratifies D-25 closure and its limits. This verifies completion of the human checkpoint, not a fresh full matrix. |
| 6 | No minimumScaleFactor remains; four foundation rules enforce the bans. | VERIFIED | Current production scan finds zero shrink modifiers, GeometryReader or numeric-literal system-font calls. Root lint contains all four foundation rules at error, plus the localization guard and bounded reader-range rule. Strict archived lint: 0 violations / 586 files. |
| 7 | Every interactive element is reachable and correctly announced with correct state, order and focus under VoiceOver. | PASSED (override) | Current labels, traits, actions and hidden-state wiring are substantive; stable audits pass on both gate devices and actual VOT walkthrough evidence exists. The approved best-effort closure preserves fifteen unreached sites, accepted focus behavior and native activation limits; no universal flow guarantee. |
| 8 | Every interactive element is actuatable by Voice Control with matching visible/input names. | PASSED (override) | Native Label/Button/Toggle names and catalog-backed custom actions support the English label proxy. Spoken commands were not exercised. This is structural naming evidence, not measured speech activation. |
| 9 | Meaningful motion respects Reduce Motion; excluded subtle crossfades/numeric transitions remain. | VERIFIED | Environment reads and gates are wired to the animating views; `ReduceMotionGatingSourceTests` has five passing named results. Walkthrough F1/F8 records actual setting-off/on differences for gradient and rating motion. Unreached motion states remain within the approved walkthrough limit. |
| 10 | All text/non-text meets 4.5:1/3:1, category backgrounds are frozen and badge foreground adapts. | PASSED (override) | `cc05aca6` deliberately removed `Color+Contrast.swift`, `ColorContrastTests.swift` and adaptive foreground use. CategoryView draws white text. Current tests pin 44 standard and 40 HC variants only; HC re-authoring was authorized. No contrast guarantee is credited. |
| 11 | Every color-coded state also has a visual shape, glyph or text. | PASSED (override) | Owner withdrew the new Activity Logs/Laboratory glyphs. Current log-level label, toggle/selection semantics, category names and download status glyph/text remain. Bounded grayscale evidence is retained; universal visual DWC is not established. |
| 12 | Produce a Nutrition Label recommendation stating claimable categories. | PASSED (override) | Replaced by owner decision 2026-09-15 and fulfilled by walkthrough, D-25, final gates and explicit sign-off. No recommendation or App Store claim is required. |
| 13 | Lint allows Dynamic Type reads/scaled fonts while rejecting prohibited modifiers/literals. | VERIFIED | `.swiftlint.yml:182–253` distinguishes modifier `(` from reads, literal font sizes from metrics, and confines the reader exception; `Package.swift:62` attaches the build-tool plugin through module construction. Historical probe evidence and current strict lint agree. |
| 14 | Surface inventory, matrix, findings and D-13/D-04 dispositions remain traceable. | VERIFIED | SWEEP records routes/primary files for 42 surfaces, 504 stored cells, no pending/re-verify round-1 cells, 38 disposed findings and 5/5 D-13 outcomes. Historical finding cells retain provenance instead of being rewritten as fresh passes. |
| 15 | Account-gated verification and simulator lifecycle are recorded without replacing real flows with fabricated data. | VERIFIED | Separate logged-in and hermetic routes are explicit in SWEEP. Current tests use fixture launch only for automation; production reducers consume real gallery/settings/download state. Final cleanup records task devices Shutdown and VoiceOver false; absent preferences are not described as measured values. Historical operational judgments were owner-reviewed. |
| 16 | Accessibility copy uses localized resources, including numeric substitutions and all supported locales. | VERIFIED | Current scan finds 37 `accessibility.*` keys across AppComponents, DetailFeature, ReadingFeature and SettingFeature, all with en/de/ja/ko/zh-Hans/zh-Hant. Slider current/total and rating use named numeric substitutions; exclude-language strings remain positional. Hardcoded/empty/Text-argument lint guards are live. |
| 17 | Custom controls expose native semantics and bind to their real state. | VERIFIED | CategoryCell toggles its supplied filter binding and emits inverted `.isSelected`; ExcludeToggle and Laboratory expose Toggle representations bound to the same values; App Icon/setting rows are native controls. The audited surfaces and bounded setting toggle on/off transcripts substantiate observed semantics. |
| 18 | Reader named actions and assistive zoom reuse existing page/gesture paths. | VERIFIED | `ReadingView.swift:196–202` sends next/previous to `jump(toPagerIndex:)`; zoom reaches `GestureHandler.onDoubleTapGestureEnded` through direction guards. Slider and ordinary tap routes share the same clamped mapping. This verifies wiring, not unmeasured spoken zoom commands. |
| 19 | Announced ratings, comments, download actions and page values derive from live model values. | VERIFIED | RatingView's half-rounded value feeds both stars and accessibility value. Comments derive actions from parsed link runs and send the same handler as taps. DownloadRow shares actual action buttons between surfaces. Panel value uses slider/page count; reader progress updates reach its reducer. See data-flow table. |
| 20 | Hidden descendants stay hidden when their visible ancestor is rendered. | VERIFIED | `ViewModifiers.swift:71–73` applies `.accessibilityHidden(true, isEnabled: !isVisible)`, avoiding an ancestor false override. Reader panel/preview callers use it. Existing isolation/walkthrough evidence closes VO-2; `testReadingControlPanelAudit` passes on both final devices without E-1. Fifteen unreached sites are not individually promoted to pass. |
| 21 | Motion inventory and autoplay cleanup have regression evidence rather than presence-only assertions. | VERIFIED | Five motion source-census tests pass (structural guard only). Five AutoPlayHandlerTests pass, including off, policy reset, invalidation and stopping from a tick; each silence case first establishes an active tick. Final UI reader autoplay/page checks pass in both directions/devices. |
| 22 | Automated audits reject unapproved issues and preserve test assertions. | VERIFIED | Three stable audit types run separately; only `ContentUnavailableView.symbol` and `V-1.designed-hit-regions` may return true. Unknown/no-element issues fall through to false. Quick Search navigation repair retains title/audit/dismissal checks; reader helper measures independent page geometry and retains advancement/agreement assertions. |
| 23 | D-25 closes exactly the approved visible-change set and records every exception. | VERIFIED | Search/Favorites/Watched × XXL/AX3/AX5 = 9 iPhone portrait cells: 8 measured passes, #39 accepted, 0 blocked. Earlier Detail/Activity Logs/Laboratory candidates were withdrawn with the visible changes. September 17 captures are historical, not new iOS 27 screenshots. |
| 24 | Closing gates are first-try green on current inputs, with zero strict lint and added phase media. | VERIFIED | Final archived result trees: FeatureTests 1055 pass + 11 expected failures; phone UI 54 pass + 2 expected iPad skips; pad UI 56 pass. All have 0 failure and 0 Repetition nodes. Current fingerprint, lint log and independent git media scan support the result. |
| 25 | PLAN prohibitions are accounted for under current enforcement and explicit owner resolutions. | VERIFIED | All 81 entries (63 judgment, 18 test) are reconciled below. Active test-tier restrictions have lint, value-pin, source-census, audit rejection or phase-range enforcement evidence; withdrawn luminance/glyph mechanisms are identified as superseded. Judgment decisions are owner-ratified, not silently passed by an LLM. |
| 26 | Earlier-phase regression coverage and source provenance survive the close. | VERIFIED | 12 prior VERIFICATION records map 27 basenames to 33 current files (29 FeatureTests / 4 UI), within 22 FeatureTests targets and UITests. Two historical renames are resolved; no uncovered target/file remains. Current 809-file comparison has no mismatch against the final snapshot. |

**Score: 26/26**, comprising 18 VERIFIED consolidated checks and 8 PASSED (override) checks. **Present-but-behavior-unverified current obligations: 0.** Unmeasured activities explicitly removed from the completion obligation remain listed below; they are not counted as successful behaviors.

## All-plan mapping

Every PLAN requirement ID resolves to A11Y-01 or A11Y-02; no additional requirement mapped to Phase 16 is orphaned. Original procedural truths are judged against their dated executions and later owner amendments, rather than asserted as current filesystem/runtime facts.

| Plan | Requirement | Consolidated checks | Current disposition / implementation or primary evidence |
|---|---|---|---|
| 16-01 | both | 6, 13, 16, 25 | VERIFIED: error-level rules/plugin; environment reads and scaled metrics remain legal. Reader cap is the later authorized exception. |
| 16-02 | A11Y-01 | 14, 15, 25 | VERIFIED: actual 42-surface inventory, protocol, matrix, D-04 and D-13 sections. “No image” concerns new evidence, not pre-existing app assets. |
| 16-03 | A11Y-01 | 5, 15, 25 | VERIFIED: recorded hand-login/infrastructure/preflight; dated replacement-device records supersede retired UDIDs. |
| 16-04 | A11Y-01 | 1, 4, 14 | VERIFIED with accepted SC1 scope: iPhone group A rows, numbered findings, before evidence and later dispositions. |
| 16-05 | A11Y-01 | 1, 3, 4, 14 | VERIFIED with SC1/3 scope: iPhone group B; baseline captures are historical signed evidence. Four originally named baseline files are no longer present today. |
| 16-06 | A11Y-01 | 1, 14, 15 | VERIFIED with accepted scope: iPhone group C, explicit Login/active-transfer reachability boundaries, restore record. |
| 16-07 | A11Y-01 | 1, 4, 14 | VERIFIED with accepted scope: independent iPad group A; later login-gated rechecks, not inferred iPhone results. |
| 16-08 | A11Y-01 | 1, 4, 14 | VERIFIED with accepted scope: iPad group B and dated authenticated modal/control-panel observations. |
| 16-09 | A11Y-01 | 1, 14, 15 | VERIFIED with accepted scope: iPad group C; complete historical matrix and disposition vocabulary. |
| 16-10 | A11Y-01 | 3–5, 14 | VERIFIED under amended D-01: owner authorized agent fix batches; obsolete owner-only/no-proposal text is superseded, not an implementation failure. |
| 16-11 | A11Y-01 | 1–5, 14 | VERIFIED/owner parity override: batch/source mapping and five final dispositions; visual-backstop decision supplied by actual owner review. No new pixel-parity claim. |
| 16-12 | A11Y-01 | 5, 6, 13 | VERIFIED: zero shrink calls, live rule, explicit owner signature preceding round 2. |
| 16-13 | A11Y-02 | 10, 11, 25 | VERIFIED audit-first history; original STARS/D28/adaptive decisions are superseded by dated reversal, while HC=A survives. |
| 16-14 | A11Y-02 | 10, 25 | PASSED (override) for deleted luminance helper/tests; VERIFIED retained colorset inventory/encoding/value pins. Deleted artifacts are not credited as present. |
| 16-15 | A11Y-02 | 10, 17, 25 | PASSED (override) adaptive/composite foreground; VERIFIED CategoryCell native binding/trait and authorized HC pin. |
| 16-16 | A11Y-02 | 7, 16, 19 | VERIFIED retained Detail/comment semantics and real link actions; universal runtime scope follows SC7 override. |
| 16-17 | A11Y-02 | 7, 8, 16, 17 | VERIFIED native setting/selectable semantics and localized representations; speech actuation remains proxy-only. |
| 16-18 | A11Y-02 | 2, 7, 18–21 | VERIFIED current native ReadingToolbar, localized slider, shared actions and cleanup. Historical custom upper-panel/menu assumptions are replaced; no auto-hide timer needs an assistive-tech branch. |
| 16-19 | A11Y-02 | 7, 8, 16, 19 | VERIFIED RatingView/traits/actions. Download swipe actions are exposed natively; only context-menu-only Detail is mirrored. Wiring moved to DownloadsView, avoiding duplicate rotor entries. |
| 16-20 | A11Y-02 | 9, 18, 21 | VERIFIED actual Detail/reader motion gates; former second upper-panel offset no longer exists. Actual display observations are bounded. |
| 16-21 | A11Y-02 | 9, 21, 25 | VERIFIED current per-file equalities, environment reads and numericText exclusion. Unreached motion states are recorded, not inferred from the census. |
| 16-22 | A11Y-02 | 11, 25 | PASSED (override) visible DWC glyphs withdrawn; retained view semantics audited. No SFSafeSymbols dependency was introduced into AppModels for this mapping. |
| 16-23 | A11Y-02 | 10, 25 | PASSED (override) visible star/non-category color changes withdrawn. No missing RatingStar artifact is misclassified as an unfinished current task. |
| 16-24 | A11Y-02 | 7, 22, 24 | VERIFIED stable audit suite and active allowances; superseded audit types/E2–E9 are not pending exclusions. E-1 is retired. |
| 16-25 | A11Y-02 | 7–9, 17–22, 25 | VERIFIED bounded F1–F8 walkthrough, hide inventory, owner listening and approved fixes. W-38 native recording accepted; no index rewrite restored. Limits remain explicit. |
| 16-26 | both | 5, 12, 23–26 | VERIFIED exact D-25 set, amended test-only corrections, final gates, provenance and whole-phase sign-off. No new approval is pending. |

### Artifact and key-link verification

Both GSD artifact and key-link queries were run for all 26 plans. Literal query failures were manually resolved: section-qualified paths, globs and directories are not filenames; retired contrast/glyph artifacts are owner-withdrawn; Downloads actions live at their real consumer; and the ignored test command uses the new iOS 27 destination. No unresolved current artifact or broken link remains.

| Artifact / connection | Existence and substance | Wiring / current result |
|---|---|---|
| Root lint → package modules | Six phase rules plus empty/Text accessibility guards are substantive | Plugin attached through package module construction; strict lint evidence covers source, tests, app and extension. |
| CategoryView → supplied filter bindings / category assets | Scaled insets/columns, real Button and inverted selected trait | Filter state toggles the same binding; asset name is host + category. White text is intentional after reversal. |
| Detail Comments → reducer link handling | Extracts and deduplicates actual parsed links; named actions call supplied closure | Parent closure sends `.handleCommentLink(url)`; same closure serves visible taps. |
| RatingView → gallery rating | Five-star drawing and accessibility value share `rawRating.halfRounded` | Used by real gallery list/header/card consumers; no fixed rating output. |
| Setting representations → setting bindings | ExcludeToggle/Laboratory Toggle use actual `$isOn`; settings/App Icon native controls | Accessible state and the rendered state share storage. |
| ReadingView → GestureHandler / PageModel / reducer | Named next/previous/zoom, bounded page mapping, model observers | Ordinary gestures and assistive actions reuse handlers; index updates synchronize slider and reading progress. |
| DownloadRow → action buttons / row store | Shared inspect/move/update/pause/delete definitions; explicit Detail action only | Native swipe semantics and explicit action reach real store sends; stable row owns confirmation dialog. |
| `visible(_:)` → panel/preview/callers | Conditional accessibility hiding with no visible-ancestor unhide | Actual callers preserve descendant hides; E-1-free panel audit and native walkthrough substantiate bounded behavior. |
| Audit suite → UITests plan / hermetic launcher | 28 audit test methods; real navigation and three audit types | Both final device trees contain the tests. Only iPad-specific audit skips on phone; it passes on pad. |
| CategoryColorsetInvariantTests → live asset JSON | 22 colorsets / 84 variants, known-member guards, encoding fixtures, two SHA pins | Wired into AppToolsTests/FeatureTests; passing named pin results. No remaining contrast-helper link is expected. |
| Sweep → findings → owner decisions → closing packet | Dated matrix, numbered issues, evidence paths, current disposition table | Both signatures identify their scope; final source snapshot and test trees independently corroborate closing claims. |

### Data-flow trace

| Rendered or announced value | Production source | Trace result |
|---|---|---|
| Category name, color and selection | `Category.value`, `Category.color(host: setting.galleryHost)`, caller's filter binding | FLOWING: localized model value and shared state, not fixture literals. |
| Rating stars and spoken score | Gallery rating → `RatingView(rating:)` → `rawRating.halfRounded` | FLOWING: same derived number for visual and spoken output. |
| Comment body, vote value and link actions | `store.comments` → CommentCell → parsed `comment.contents` / vote flags | FLOWING: actual loaded comments; actions return to reducer. |
| Download label/status/actions | Coordinator-backed row state → `rowStore.download` → status gates / buttons | FLOWING: real row state; named/native actions use the real sends. |
| Reader slider/page indicator/progress | Gallery page count, PageModel index, PageHandler mapping, reducer progress | FLOWING: two-way mapping and production image/local-file paths; UI-test placeholders are hermetic inputs only. |
| Setting toggle/value | Shared settings or reducer bindings → native control/representation | FLOWING: representations do not introduce a second state store. |

No current goal artifact ends in an unpopulated static array, empty handler or mock-only production return. Test fixtures intentionally provide deterministic gallery content and failed-image placeholders.

## Behavioral evidence and test quality

These are **inspected existing executions**, not commands rerun by this verifier. Commands/provenance are preserved in close/ logs and `run-final-ui.py`.

| Check / named behavior | Existing result | What it proves |
|---|---|---|
| FeatureTests, final production/FeatureTests inputs | 1066 reported = 1055 passed + 11 expected failures; 0 failed/skipped; Repetition 0 | Package regression gate. Expected issue-reporting cases are not unexpected failures. |
| UITests iPhone, final helper | 56 = 54 passed + 2 expected iPad-only skips; Repetition 0 | First-try phone gate after the documented route/helper repairs. |
| UITests iPad, final helper | 56 passed, 0 skipped; Repetition 0 | Full first-try pad gate; focused diagnostics alone were not substituted. |
| `AccessibilityAuditUITests/testReadingControlPanelAudit()` | Passed on both final devices | Actual rendered panel passes retained audit types without E-1; not a proof of every VoiceOver interaction. |
| `ReaderPageSyncUITests/testScrollingKeepsTheIndicatorOnThePageShown()` and slider/resume/autoplay tests | Passed on both final devices | State transitions agree with independent numbered-placeholder geometry. Loaded images and assistive scrolling are outside these fixtures. |
| `AutoPlayHandlerTests/turningAutoPlayOffStopsTheTicks()`, `invalidatingStopsTheTicks()`, policy restart and callback-stop tests | All five passed | Cancellation/timing behavior exercised using TestClock after establishing an active tick. |
| Five `ReduceMotionGatingSourceTests` | Passed | Exact source inventory/ungated numeric transitions; not perceptual motion proof. F1/F8 actual setting observations supply bounded runtime evidence. |
| Five `CategoryColorsetInvariantTests` methods, including parameterized encoding fixtures | Passed | Inventory, normalization and standard/HC color pins; no contrast assertion. |
| Detail title tests at standard/AX1/AX3/AX5; iOS27 migration tests | Passed on both devices | Current tested native title/search/toolbar and orientation flows; not a new full 504-cell visual sweep. |
| W-38 native VoiceOver recording | Owner accepted; video SHA independently matches `d79113d227fcd76604438ecb77619d06001ee82ac5d378cead07ca995ca3acd7` | Native Quick Nav Scroll Down 40 times, page 1 → 41, then native VoiceOver double-tap reveals placeholder 41 / panel 41 of 156. No model injection or source patch. |

**Assertion audit:** reader checks compare two independent observations and demand advancement; the repaired probe pairs numeric label and nearest Reload geometry in one snapshot. Autoplay selection remains one tap followed by a bounded disappearance assertion. Tests do not derive expected visual page from the toolbar they validate. Color pins deliberately freeze approved asset values; motion counts deliberately freeze an inventory, and neither is used as a substitute for behavioral/visual proof.

**Disabled tests:** the two phone skips are `testPadSettingAndDetailModalsAudit` and `testPadTabModalReplacedByDeepLink`, both passing on pad. No accessibility requirement relies solely on a disabled test. TCA `skipReceivedActions`/`skipInFlightEffects` calls in unrelated/scoped reducer tests are not disabled test cases.

**Historical failures:** original route/helper failures and Repetition-bearing diagnostic runs remain failed evidence. The final full gates are distinct executions after explicit repairs. Internal Xcode QoS warnings remain; zero lint is not zero platform warnings.

**Probe execution:** no conventional `scripts/*/tests/probe-*.sh` path is declared by these plans. Historical SwiftLint positive/negative snippets are recorded in 16-01/16-12; no new lint probe or runtime command was executed under the read-only dispatch.

### Prohibitions, security and decision coverage

All 81 authored prohibitions were considered, including repeated entries:

- **18 test-tier entries:** current modifier/string bans are enforced by live lint rules; frozen category channels by passing pin tests; numeric transition policy by the passing source inventory; unapproved audit exclusions by the failing-default handler; new media/transcript/log prohibitions by the phase-range added-file check. The old luminance-channel constraint has no current consumer because the owner removed that mechanism; the DWC module/dependency constraint is scoped to its historical plan, whose visible mapping was withdrawn. Neither is silently treated as a currently tested color algorithm.
- **63 judgment-tier entries:** simulator/account discipline, no unapproved visible changes/suppressions, scope boundaries and owner checkpoints are covered by the signed procedural record and the 113-row threat register. D-01's original agent-no-reflow prohibition was expressly amended; the no-label-document scope, visible reversals and accepted limits were owner decisions. This is human-ratified procedural evidence, not an authoritative LLM inference about every historical operation.
- **Security/validation reconciliation:** current SECURITY closes all 113 authored rows after sign-off. The immutable pre-sign-off recheck still lists the last sign-off row open; that historical state is resolved by `a4cc3754`, not rewritten. Validation maps all 68 tasks (59 automated / 9 checkpoint), with 23 behavior rows and no unmapped automated task. No deferred `<human-check>` blocks were found in PLAN files.

### Decision Coverage

All trackable CONTEXT.md decisions are honored by shipped artifacts.

The read-only GSD query reports **34/34**, `not_honored: []`. This is advisory string-trace coverage; the dated owner reversals were separately reconciled against actual source.

## Requirements coverage

| Requirement | Source plans | Result | Evidence |
|---|---|---|---|
| A11Y-01 — full-range Dynamic Type readability/operability | 16-01–16-12, 16-26 | SATISFIED under signed exceptions | Current reflow/lint, five D-13 dispositions, signed round-1 UAT, bounded D-25 closure and current native-policy tests. |
| A11Y-02 — assistive technology / motion / display accessibility | 16-01, 16-13–16-26 | SATISFIED under the explicit best-effort supersession | Current semantics/action/data wiring, motion gates, stable audits, bounded walkthrough/listening, category pins and completed owner closure. No universal contrast/Voice Control/Nutrition Label guarantee. |

The still-pending A11Y-02 checkbox/Phase 16 completion fields are workflow bookkeeping reserved to the orchestrator after this report, not evidence of a missing implementation. No requirement outside these two maps to Phase 16.

## Anti-patterns and disconfirmation

No unreferenced TBD/FIXME/XXX marker was found in the **129 current Swift files changed across the phase range**. No phase-added image/video/log file was found. No current must-have artifact is an implementation stub or orphan.

Three plausible false-pass paths were checked explicitly:

1. **Partial requirement:** universal contrast, Voice Control speech and all-flow reachability are not delivered. They remain visible as owner overrides/evidence limits, not broad passes.
2. **Misleading test:** colorset pins and motion source counts can pass without proving text contrast or perceptual behavior. The report confines them to those structural properties and uses existing runtime/human evidence for the bounded behaviors.
3. **Uncovered path:** loaded-image/other native VoiceOver activation and the fifteen unreached sites have no complete runtime proof. W-38 proves its exact recorded mock-reader scroll/reveal only; it does not generalize to all reader/assistive configurations.

**Evidence-retention note:** the four original D-15 baseline images are absent at their named paths today. The signed visual/backstop outcome and later targeted records remain; original-pixel parity cannot be independently replayed from those paths. This limitation is not concealed by the score or claimed as a new pass.

## Human verification and approved limits

**No outstanding human decision is required for the current approved phase.** The existing signatures resolve the end-of-phase checkpoints; they do not turn unmeasured behavior into test evidence.

Retain these limits when describing or extending accessibility:

- Fifteen hide-inventory sites remain unreached; Voice Control spoken commands remain unmeasured. Native VoiceOver double-tap outside the bounded W-38 reveal remains unmeasured.
- #39 is an accepted historical Favorites AX5 native blank-search capsule, not a ninth passing D-25 cell or newly reproduced iOS 27 defect.
- W-8/W-35 retain accepted focus behavior; VO-3/W-13 Comments retain the Apple-bug/no-workaround disposition. Withdrawn focus/index workarounds are not required deliverables.
- W-33 ordinary P M and W-34 MiB pronunciation have bounded owner verification. W-31 accepts only the observed empty uploader capsule under Button Shapes.
- W-21 raw ContentUnavailableView symbol speech and W-24 Delete glyph contrast remain owner-deferred. The rating adjustable-action and other carried walkthrough limitations remain part of the signed record.
- W-38 closes on native VoiceOver Scroll Down commands and panel reveal at page 41; no claim is made that an OS upgrade caused the non-reproduction or that 40 Next Item actions were performed.
- UI review remains **21/24** with accepted/deferred quality limitations. It is not converted to 24/24 by the owner's approval.

Later Phase 17's separately planned platform/UI work was inspected for deferral context. No current failed truth was transferred to it to obtain a pass; existing accepted/deferred items above keep their original owner disposition.

## Conclusion

The current code and existing current-input gate results achieve the **owner-approved Phase 16 goal**. No unresolved BLOCKER, missing current artifact, broken current link or new approval need was established. Proceed with canonical completion using this bounded result; keep the superseded original guarantees and retained evidence limits explicit.

_Verified: 2026-09-23T06:58:01Z_  
_Verifier: gsd-verifier; source inspection and existing evidence, no new execution_


## Post-completion metadata verification

The orchestrator reviewed the canonical completion and transition changes through `01103bf1b72f7d94ea3e50e9213a70ca41ec034e`. Changes since the verifier's `a46ef238` input are limited to PROJECT, REQUIREMENTS, ROADMAP, STATE, the generated state-contract snapshot, this report and the closeout notes. They record the already-approved completion, preserve historical reference warnings and advance only planning position to Phase 17. The state-contract snapshot also reports Phase 16 complete.

The source/config diff from tested commit `7675a7ac` still contains only the pre-existing Xcode project edit, whose patch is byte-identical to the archived patch. No source, test, decision or gate outcome changed. The earlier passage describing A11Y-02 tracking as pending is historical; canonical completion now marks it complete. No runtime checks were rerun for these documentation-only changes.

After this bounded metadata review, the orchestrator refreshed `covered_files` and `covered_digest` with the canonical `verification.fingerprint` command, retaining every original covered input and adding the transition documents. This resolves the stale tracking-document digest without dropping coverage or changing the verifier's verdict or evidence limits.
