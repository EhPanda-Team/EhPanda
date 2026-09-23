---
phase: 16-dynamic-type-accessibility
reviewed: 2026-09-23T04:10:00Z
timezone: Asia/Tokyo
depth: standard
review_type: incremental
reviewed_head: 7675a7ac77301de9464a8e924c9fc8c70f691849
diff_base: a4e960a1238dfcce10edc8558bb80685daad0292
files_reviewed: 98
files_reviewed_list:
  - .github/workflows/deploy-pre-release.yml
  - .github/workflows/deploy.yml
  - .github/workflows/test.yml
  - AGENTS.md
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/AdaptiveStack.swift
  - AppPackage/Sources/AppComponents/AppToggle.swift
  - AppPackage/Sources/AppComponents/ErrorInfoView.swift
  - AppPackage/Sources/AppComponents/NewDawnView.swift
  - AppPackage/Sources/AppComponents/PreviewImageView.swift
  - AppPackage/Sources/AppComponents/SubSection.swift
  - AppPackage/Sources/AppComponents/TagCloudView.swift
  - AppPackage/Sources/AppComponents/ToolbarItems.swift
  - AppPackage/Sources/AppComponents/ViewModifiers.swift
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
  - AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/Components/PostCommentView.swift
  - AppPackage/Sources/DetailFeature/Components/TagDetailView.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift
  - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
  - AppPackage/Sources/DetailFeature/DetailView+Navigation.swift
  - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift
  - AppPackage/Sources/DetailFeature/GalleryComment+Accessibility.swift
  - AppPackage/Sources/DetailFeature/GalleryDestination.swift
  - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
  - AppPackage/Sources/DetailFeature/HeaderActionsLayout.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/FiltersFeature/FiltersView.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
  - AppPackage/Sources/GalleryListComponents/GalleryList.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
  - AppPackage/Sources/HomeFeature/GalleryRankingCell.swift
  - AppPackage/Sources/HomeFeature/History/HistoryView.swift
  - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
  - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
  - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
  - AppPackage/Sources/ReadingFeature/Support/AutoPlayHandler.swift
  - AppPackage/Sources/ReadingFeature/Support/ReadingToolbar.swift
  - AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift
  - AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift
  - AppPackage/Sources/SearchFeature/SearchRootView.swift
  - AppPackage/Sources/SearchFeature/SearchView.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
  - AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift
  - AppPackage/Sources/SettingFeature/Components/AboutView.swift
  - AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift
  - AppPackage/Sources/SettingFeature/Components/DownloadSettingView.swift
  - AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift
  - AppPackage/Sources/SettingFeature/Components/WebView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
  - AppPackage/Sources/SettingFeature/Login/LoginView.swift
  - AppPackage/Sources/SettingFeature/SettingView.swift
  - AppPackage/Sources/SystemNotification/ToastMessageView.swift
  - AppPackage/Tests/DetailFeatureTests/HeaderActionsLayoutTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionSubmissionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedSubmissionCoordinatorTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/FavoritesFeatureTests/LoginReturnObservationTests.swift
  - AppPackage/Tests/HomeFeatureTests/LoginReturnObservationTests.swift
  - AppPackage/Tests/ReadingFeatureTests/AutoPlayHandlerTests.swift
  - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
  - EhPanda.xcodeproj/project.pbxproj
  - EhPandaUITests/AccessibilityAuditUITests.swift
  - EhPandaUITests/DeepLinkSchemeUITests.swift
  - EhPandaUITests/DetailNavigationTitleUITests.swift
  - EhPandaUITests/IOS27MigrationUITests.swift
  - EhPandaUITests/ReaderPageSyncUITests.swift
  - EhPandaUITests/Support/AccessibilityAuditReport.swift
  - EhPandaUITests/Support/DeepLinkLauncher.swift
  - EhPandaUITests/Support/ReaderPageProbe.swift
  - README.md
  - READMEs/README.chs.md
  - READMEs/README.cht.md
  - READMEs/README.de.md
  - READMEs/README.jpn.md
  - READMEs/README.ko.md
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 16: Code Review Report

**Reviewed:** 2026-09-23 (Asia/Tokyo)
**Depth:** standard
**Files Reviewed:** 98
**Status:** clean — no new actionable defects established in this incremental scope.

## Narrative Findings (AI reviewer)

No new BLOCKER or WARNING finding was established by the source review. This disposition is limited to the explicit incremental scope and the owner decisions below. It does not certify runtime accessibility behavior, turn failed runs into passes, approve a Nutrition Label claim, or complete Phase 16/A11Y-02.

### Scope and method

The authoritative 98-path list in `/tmp/ehpanda-phase16-close-20260923/code-review-files.txt` agrees with `code-review-scope.json`. The comparison is `a4e960a1238dfcce10edc8558bb80685daad0292..7675a7ac77301de9464a8e924c9fc8c70f691849`, not a guessed recent-commit range. All listed current files were read in context with relevant diffs; none are ignored. The retired accessibility title/search helpers were also checked through their deletion diffs. The frontmatter lists the exact submitted current-file scope, excluding those deleted paths and supporting context reads.

The review applied `AGENTS.md`, the root SwiftLint rules, the code-review workflow, accessibility review guidance and Swift concurrency review guidance. Fallow was disabled; no structural pre-pass was provided. Source analysis covered input and collection boundaries, asynchronous cancellation and ownership, toolbar/sheet routing, stable dialog anchors, accessibility actions, presentation-root scroll-edge placement, and test assertion reliability. Relevant helper implementations and callers were cross-referenced where necessary.

The project file contains a pre-existing uncommitted Xcode serialization change. Its current contents and committed deployment-target diff were inspected separately; that dirty change was preserved. No source, test or configuration file was edited. No build, test, lint run, simulator interaction, process change or git-index mutation was performed by this reviewer.

### Higher-risk paths examined

- `ContinuedProcessingSession` publishes the pending identity before asynchronous submission, keeps a submission record after session termination until settlement, and blocks successor starts during that interval. Late settlement cancels the old request without owning a new session. The scheduler seam and held-submission/coordinator tests were inspected for delivery before settlement, termination, rejection and stale completion.
- `AutoPlayHandler` cancels the previous clock task on policy changes and checks cancellation before invoking a due tick. Reader dismissal, presentation and slider interaction continue to stop autoplay; the clock tests preserve cadence and cancellation assertions.
- `HeaderActionsLayout` retains one set of action views while changing placement. Its measurements, narrow-width cases and placement tests were checked against the header's action bindings and presentation anchors.
- `ReaderPageProbe` derives the displayed fixture page from numeric/Reload geometry in one snapshot, independently of the toolbar indicator. The centered union corrects the documented offset of the number within the placeholder. The stronger vertical gesture still requires forward movement; the autoplay helper adds a bounded disappearance assertion after the existing single tap. Neither repair changes production page-index logic, introduces tap retries, removes failure attachments, or substitutes the indicator for the independent measurement.
- Native iOS 27 `.inlineLarge`, searchable, toolbar and soft top-edge changes were reviewed as the approved platform policy. Deleted accessibility title/search fallback branches are intentional. The Quick Search audit now follows the actual direct Search-root toolbar control and retains its sheet, audit and dismissal checks.

### Runtime evidence and limits

The existing `16-SWEEP.md` closing-gate record and `16-26-PLAN.md` amendments remain the authority for runtime evidence. At review handoff, full iPhone and iPad UI gates on the final helper were pending. This report does not infer their outcome.

The recorded FeatureTests result is 1,055 passed with 11 expected failures and zero Repetition nodes; the recorded strict SwiftLint result is zero violations across 586 files. Those are existing orchestrator evidence, not runs performed or independently re-executed by this review.

The initial full iPhone run remains failed (one final failure and three Repetition nodes); the corrected-route full iPhone run records 54 passes, two expected iPad-only skips and zero Repetition nodes. The original full iPad gate remains failed: 55 eventual passes, one final failure and five Repetition nodes. The geometry diagnostic's third-attempt success is not a closing pass. The focused geometric-pairing and autoplay-postcondition iPad runs each passed first try with zero Repetition nodes, but cannot replace the pending full gates. Original bundles, screenshots and frame evidence remain preserved.

### Owner decisions and remaining scope

- W-8 and W-35 retain the owner's accepted focus behavior. VO-3/W-13 Comments retain the recorded Apple-bug disposition and no local workaround.
- W-38 retains the 2026-09-23 owner acceptance after native VoiceOver page 1 → 41 recording without index-logic changes. The prior request for a bounded VoiceOver path was superseded by that acceptance. No new concrete reproduction was established here; this review does not reopen the withdrawn index rewrite or classify ordinary-touch helper failures as a new VoiceOver defect.
- W-33/W-34 phonetic changes remain approved. Other recorded accepted/deferred limits, including D25/W21/W24/W31, Favorites echo behavior, W22 color decisions and the historical iPad beta stall evidence, remain explicit in the sweep. Historical observations retain their original uncertainty and outcome.
- The 2026-09-15 best-effort accessibility scope remains in force. App Store/Nutrition Label guarantees, owner closing approval, verification and phase completion are not supplied by a clean code-review result.

## Historical Review — 2026-09-17

The previous review's clean disposition is preserved, with its original scope and evidence limits. It covered 125 eligible paths from 25 summaries plus a diff cross-check (124 diff-eligible paths and the summary-only `Placeholder.swift`, `baselineRelevant=false`), at source `b01add4c11b1f9c355ac8f2e055ed8b24fe8146c`, repository HEAD `8a199c2f` and diff base `c65be7b8^`. Its counts were Critical 0, Warning 0 and Info 0. The full historical file list remains in this report's Git history; the current frontmatter intentionally records only this review's 98-path scope.

Its conclusion was that no defect directly supported by the reviewed code and outside the documented owner decisions/known limits was found. Owner 16-26 Task 3, verifier and completion were still pending. No source or test was added by that review.

The historical runtime references were `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-featuretests-iphone.{log,xcresult,summary.json,tests.json}`, `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-uitests-iphone.{log,xcresult,summary.json,tests.json}` and `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-uitests-ipad.{log,xcresult,summary.json,tests.json}`. That review referenced their recorded zero-Repetition results without rerunning tests. They remain historical evidence for their own source/runtime baseline, not evidence for the subsequent iOS 27 migration or the final helper.

The earlier D25/W8/W13/W21/W24/W31/W33/W34/W35/W38, Favorites echo guard, unexplained iPadOS 27 beta Gallery Detail stall and W22 accepted color shifts were retained as known limits/decisions, not new findings. Later dated owner dispositions above update only those decisions they explicitly supersede.

---

_Reviewer: gsd-code-reviewer_
_Depth: standard; incremental source review only_
