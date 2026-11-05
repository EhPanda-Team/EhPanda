---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
reviewed: 2026-11-05
depth: standard
effort: high
source_head: f08a6a781
review_head: c0b10ac03
review_range: 92e9ea71f..c0b10ac03
files_reviewed: 129
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift
  - AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift
  - AppPackage/Sources/AnalyticsClient/AnalyticsOrientation.swift
  - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Level.swift
  - AppPackage/Sources/AnalyticsClient/InstallSignalSender.swift
  - AppPackage/Sources/AnalyticsClient/TelemetrySDK.swift
  - AppPackage/Sources/AppComponents/CheckboxToggleStyle.swift
  - AppPackage/Sources/AppComponents/ChoiceCard.swift
  - AppPackage/Sources/AppComponents/FirstLaunchContinueButton.swift
  - AppPackage/Sources/AppComponents/SessionWebView.swift
  - AppPackage/Sources/AppComponents/TitleWidowGuard.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/FirstLaunch/AgeWallView.swift
  - AppPackage/Sources/AppFeature/FirstLaunch/AnalyticsChoiceView.swift
  - AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchGateView.swift
  - AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchReducer.swift
  - AppPackage/Sources/AppFeature/RootView.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
  - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
  - AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift
  - AppPackage/Sources/AppModels/Gallery/GalleryComment.swift
  - AppPackage/Sources/AppModels/Moderation/BlockedCommentUser.swift
  - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
  - AppPackage/Sources/AppModels/Persistent/AgeDeclaration.swift
  - AppPackage/Sources/AppModels/Persistent/AnalyticsLevel.swift
  - AppPackage/Sources/AppModels/Persistent/InstallSignalState.swift
  - AppPackage/Sources/AppModels/Persistent/Setting.swift
  - AppPackage/Sources/CookieClient/CookieClient.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/Components/PostCommentView.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
  - AppPackage/Sources/DetailFeature/DetailReducer.swift
  - AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift
  - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/Moderation/BlockedCommentCard.swift
  - AppPackage/Sources/DetailFeature/Moderation/BlockedCommentRow.swift
  - AppPackage/Sources/DetailFeature/Moderation/CommentFilter.swift
  - AppPackage/Sources/DetailFeature/Moderation/CommentFilterTerms.swift
  - AppPackage/Sources/DetailFeature/Moderation/CommentModeration.swift
  - AppPackage/Sources/DetailFeature/Moderation/CommentModerationMenu.swift
  - AppPackage/Sources/DetailFeature/Moderation/CommentOwnership.swift
  - AppPackage/Sources/DetailFeature/Moderation/CommentReportTarget.swift
  - AppPackage/Sources/DetailFeature/Moderation/ReportPageSheet.swift
  - AppPackage/Sources/DetailFeature/Resources/CommentFilterTerms.json
  - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/InstallSourceClient/.swiftlint.yml
  - AppPackage/Sources/InstallSourceClient/InstallSourceClient.swift
  - AppPackage/Sources/ParserFeature/Parser+Comment.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+Session.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
  - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
  - AppPackage/Sources/ReadingFeature/Support/AutoPlayHandler.swift
  - AppPackage/Sources/ReadingFeature/Support/PageHandler.swift
  - AppPackage/Sources/ReadingFeature/Support/ReaderPagesAccessibility.swift
  - AppPackage/Sources/ReadingFeature/Support/ReaderPosition.swift
  - AppPackage/Sources/Resources/ResourceStringSymbols.swift
  - AppPackage/Sources/Resources/Resources/Constant.xcstrings
  - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersReducer.swift
  - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersView.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/SettingFeature/SettingPath.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
  - AppPackage/Sources/SettingFeature/SettingView.swift
  - AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift
  - AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift
  - AppPackage/Tests/AnalyticsClientTests/AnalyticsLevelGateTests.swift
  - AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift
  - AppPackage/Tests/AnalyticsClientTests/InstallSourceTests.swift
  - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift
  - AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift
  - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
  - AppPackage/Tests/AppModelsTests/BlockedCommentUserTests.swift
  - AppPackage/Tests/AppModelsTests/SettingFirstLaunchFieldsTests.swift
  - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
  - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
  - AppPackage/Tests/DetailFeatureTests/BlockedCommentPresentationTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentCardLayoutTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentFilterTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentOwnershipTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentReportTargetTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/AppReadingFlushTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadObserverReadingTests.swift
  - AppPackage/Tests/ParserFeatureTests/Gallery/GalleryCommentParserTests.swift
  - AppPackage/Tests/ReadingFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/ReadingFeatureTests/AutoPlayHandlerTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PagerSeedTests.swift
  - AppPackage/Tests/ReadingFeatureTests/ReaderPagesAccessibilityTests.swift
  - AppPackage/Tests/ReadingFeatureTests/ReaderPositionTests.swift
  - AppPackage/Tests/ReadingFeatureTests/ReadingOrientationTests.swift
  - AppPackage/Tests/SettingFeatureTests/BlockedUsersReducerTests.swift
  - AppPackage/Tests/SettingFeatureTests/GeneralSettingReducerTests.swift
  - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
  - AppPackage/Tests/VisualSnapshotTests/ReaderListPositionTests.swift
  - EhPandaUITests/BlockedUsersTitleLayoutUITests.swift
  - EhPandaUITests/CommentModerationUITests.swift
  - EhPandaUITests/FirstLaunchTitleLayoutUITests.swift
  - EhPandaUITests/FirstLaunchUITests.swift
  - EhPandaUITests/ReaderRebuildUITests.swift
  - EhPandaUITests/SettingsModerationUITests.swift
  - EhPandaUITests/Support/LocalizedLaunch.swift
  - EhPandaUITests/Support/ReaderPageProbe.swift
  - EhPandaUITests/Support/UITestConstants.swift
  - README.md
  - READMEs/README.chs.md
  - READMEs/README.cht.md
  - READMEs/README.de.md
  - READMEs/README.jpn.md
  - READMEs/README.ko.md
  - Scripts/visual/test_release.py
  - Scripts/visual/verify-release.py
files_deleted:
  - AppPackage/Sources/ReadingFeature/Support/PageModel.swift
  - AppPackage/Tests/AppModelsTests/SettingAnalyticsOptOutTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: issues_found
resolution:
  IN-01: "fixed in 8b30b8c55 (2026-11-05 UTC)"
  IN-02: "accepted exception (lead's decision): screens inside an existing *Reducer tree keep the Reducer suffix"
  IN-03: "accepted by the lead: nothing is shown and no analytics is sent before the choice; D-04 and DD-07 allow the content fetch after the age confirmation"
open: 0
scope: phase-18-all-plans-18-01..18-12
execution: inline-reviewer (code-reviewer, code-fixer and verifier roles ran in one agent, in sequence)
---

# Phase 18 code review

Scope: every file the phase changed outside `.planning/`, `git diff 92e9ea71f..c0b10ac03` (92e9ea71f is the parent of
the first Phase 18 commit, e2174dfd2). That is 129 added or changed files and 3 deleted ones; 76 are app, package
and extension sources. The code is unchanged since the gated commit `f08a6a781`; the 4 later commits change
planning docs only.

The code-reviewer, code-fixer and verifier roles ran in one agent, in sequence, following
`agents/gsd-code-reviewer.md`, `gsd-code-fixer.md` and `gsd-verifier.md`. The reviewer read the code. It did not
build or run anything for the review itself; the regression evidence is the 18-12 gate (18-REGRESSION-GATE.md).

## Areas read, and what was checked

- **Launch gate (18-02, 18-09):** `AppReducer`, `AppDelegateReducer`, `FirstLaunchReducer`, `RootView`,
  `AgeWallView`, `AnalyticsChoiceView`, `ChoiceCard`. `onLaunchFinish` keeps only local work. The settings load,
  liveness, greeting, tab fetches and the SDK start wait for the age confirmation. A deep link is queued until then
  and routed once. `RootView` renders the gate instead of `TabBarView` until the step is `complete`, so no content is
  built behind it. No level is pre-selected, and Continue on the choice screen is disabled until a level is picked.
- **Analytics levels (18-03):** `AnalyticsClient`, the TelemetryDeck wrapper and default parameters (the `App.*`
  parameters at Full only), `InstallSignalSender` / `InstallSignalState`, `InstallSourceClient`. The SDK never
  starts at Minimal. Lowering the level terminates the SDK at once. `send` reads the stored level for every
  signal. TelemetryDeck 2.14.2's `terminate()` nils its manager, so starting again after a raise is safe. The install
  signal is sent once, with retry and a stored disposition.
- **Settings (18-10):** `GeneralSettingReducer` / `GeneralSettingView` (the picker binds a read-only level, a pick
  stores and then applies it, `nil` is ignored), the Privacy Policy row, `BlockedUsersReducer` / `BlockedUsersView`
  (reads the shared list, unblocks by member ID, sorts only for display).
- **Moderation (18-04, 18-05, 18-11, 18-12):** `CommentFilter` / `CommentFilterTerms`, `CommentReportTarget` (the
  URL is rebuilt from the parsed gallery URL, the host must be exactly a `GalleryHost`, the path must be
  `/g/<digits>/<alnum>/`, and the query is fixed), `CommentOwnership`, `CommentModeration`,
  `CommentModerationMenu`, `BlockedCommentUser` (strict decode, so the app never stores a list it cannot read
  back), `Parser.parseMemberID`, the `CommentsReducer` / `DetailReducer` changes, `CommentsView`, the Detail
  strip cards and rows.
- **Report sheet (18-11):** `SessionWebView` and `ReportPageSheet`. The store is `WKWebsiteDataStore.nonPersistent()`.
  The cookies come from `CookieClient.sessionCookies(for:)`, which returns only the report host's unexpired cookies
  and only reads. Each cookie is set and awaited before the load. A cancelled seed loads nothing. Nothing is
  written back to the app's store. The page never loads in a stubbed UI-test launch.
- **Reader (18-07, 18-08):** `ReaderPosition` (one committed page, one pending turn, a generation per pager, a
  retry limit for missed turns, held turns while the pager animates), `PagerSeed`, `ReadingReducer` (+Body,
  +Session: progress is the committed page, saved debounced and on dismissal), `ReadingView`, `AdvancedList`,
  `PageHandler`, `AutoPlayHandler`, `ReaderPagesAccessibility`. `PageModel` is removed, along with its copies of
  the page.
- **Test support and release isolation:** `UITestAutomation` (presets read only inside `#if DEBUG`, applied only to
  automated launches), `UITestStubURLProtocol` (whole file `#if DEBUG`), `ReaderUITestOptions` (`#if DEBUG`),
  `CaptureDiagnostics`, `verify-release.py` / `test_release.py` (IN-02), and `RootView`'s DEBUG-only
  `import AppComponents` (IN-03). Release isolation was also confirmed at runtime by the 18-12 scan.
- **Release fix:** `App/Info.plist` `MKSellsDigitalGoods` = `false`.

No Critical or Warning finding. Nothing was fixed, so there is no 18-REVIEW-FIX.md.

## Info

### IN-01: The member-ID parser accepts any host that ends in `e-hentai.org`

**File:** `AppPackage/Sources/ParserFeature/Parser+Comment.swift:92`

**Issue:** `parseMemberID` checks `components.host?.hasSuffix("e-hentai.org")`. That also matches a host such as
`note-hentai.org` or `fake-e-hentai.org`. The link it reads is the site-printed contact link on the author line
(the `c3` node), not comment text, so a commenter cannot inject it. The only effect would be on a malformed page.

**Fix:** Match the host exactly (`== "forums.e-hentai.org"`), or as a domain (`host == "e-hentai.org" ||
host.hasSuffix(".e-hentai.org")`), and add a parser case with a look-alike host.

**Status: fixed in `8b30b8c55`** (the lead's call). `parseMemberID` now accepts only the exact contact link
`Defaults.URL.forum`: scheme `https`, host `forums.e-hentai.org` (both compared without case), path `/index.php`,
no user, password or port, and a `showuser` of ASCII digits only. Every fixture under `EhPandaUITests/Fixtures` and
the TestingSupport parser resources uses that one host over `https`, so no other host or scheme is allowed.
`GalleryCommentParserTests.aLookAlikeContactLinkHasNoMemberID` covers `fake-e-hentai.org`, `note-hentai.org`,
`forums.e-hentai.org.evil.com`, `e-hentai.org`, a subdomain, user parts, a port, `http`, another path and a
relative link (all `nil`); `theContactLinkHostMatchesWhateverItsCase` keeps the capitalised link. Runs at
`8b30b8c55`: ParserFeatureTests + DetailFeatureTests 199/199 on the phone and 199/199 on the pad;
`CommentModerationUITests` 7/7 on each; 0 Repetition nodes; strict lint 0 violations on the two files.

### IN-02: Two new reducers use the `Reducer` suffix, not AGENTS.md's `Feature` suffix

**File:** `AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchReducer.swift:13`,
`AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersReducer.swift:14`

**Issue:** AGENTS.md line 15 asks for reducer names with a `Feature` suffix. `FirstLaunchReducer` and
`BlockedUsersReducer` follow the names their plans gave them (18-02, 18-10) and the neighbouring
`GeneralSettingReducer` / `AppDelegateReducer`, while `CommentModerationFeature` follows AGENTS.md. Naming only;
no behavior impact.

**Fix:** Rename both to `FirstLaunchFeature` and `BlockedUsersFeature` in a later cleanup, together with their
tests and `SettingPath` case, or record the exception for screens inside an existing `*Reducer` tree.

**Status: accepted exception** (the lead's decision, 2026-11-05). A screen inside an existing `*Reducer` tree
keeps the `Reducer` suffix of its neighbours (`AppReducer`/`AppDelegateReducer` for `FirstLaunchReducer`,
`SettingReducer`/`GeneralSettingReducer` for `BlockedUsersReducer`). Not renamed.

### IN-03: A link opened during the analytics choice routes at once, under the gate

**File:** `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift:249-257`, `AppPackage/Sources/AppFeature/RootView.swift:40-46`

**Issue:** `openURL` queues a link only while the age wall is unconfirmed (`isUnlocked`). Once the age is confirmed
and the analytics choice is showing, a link goes straight to `.presentation(.handleDeepLink)`. Its detail state
(and any fetch it starts) is prepared under the gate and shows when the choice completes. This matches DD-07 (queue
until the age confirmation) and D-04, and the deferred launch's network work also starts at that point. No content
is shown before the choice. Recorded so the behavior is known, not as a defect.

**Fix:** None needed under the current decisions. If the product wants links held until both screens are answered,
gate `openURL` on `firstLaunch.step == .complete` instead of `isUnlocked`.

**Status: accepted by the lead** (2026-11-05). There is no user-visible difference: nothing is shown and no
analytics is sent before the analytics choice, and the content fetch after the age confirmation is allowed by D-04
and DD-07. No change.

---

_Reviewed: 2026-11-05_
_Reviewer: gsd-code-reviewer role, run inline (one agent for reviewer, fixer and verifier)_
_Depth: standard_
