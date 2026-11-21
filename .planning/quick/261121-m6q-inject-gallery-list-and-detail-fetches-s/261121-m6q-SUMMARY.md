---
phase: 261121-m6q-inject-gallery-list-and-detail-fetches-s
plan: 01
subsystem: networking
tags: [tca, dependencies, testing, analytics, gallery-client]
status: complete
requires: []
provides:
  - "GalleryClient: one injectable TCA dependency for the 14 gallery list and detail requests reducers start"
  - "TestingSupport errorSignals / nonErrorSignals: the shared partition of a recorded signal list"
affects:
  - HomeFeature
  - FavoritesFeature
  - SearchFeature
  - DetailFeature
  - TestingSupport
tech-stack:
  added: []
  patterns:
    - "Every reducer-started gallery list or detail fetch goes through @Dependency(\\.galleryClient); the test value is unimplemented per closure"
    - "Tests whose signals come from concurrently running effects assert the shared errorSignals / nonErrorSignals partition exactly"
key-files:
  created:
    - AppPackage/Sources/GalleryClient/GalleryClient.swift
    - AppPackage/Sources/GalleryClient/.swiftlint.yml
    - AppPackage/Sources/TestingSupport/AnalyticsSignal+Partition.swift
    - AppPackage/Tests/HomeFeatureTests/GalleryClientTestSupport.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
    - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer+Reading.swift
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
    - AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift
    - AppPackage/Tests/HomeFeatureTests/HomeDuoPresentationTests.swift
    - AppPackage/Tests/HomeFeatureTests/HomePresentationLifecycleTests.swift
    - AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/AnalyticsEmissionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/AppDownloadDetailRoutingTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DetailReducerObserveTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift
    - AppPackage/Tests/AppFeatureTests/PresentationLifecycleTests.swift
    - AppPackage/Tests/ReadingFeatureTests/AnalyticsEmissionTests.swift
decisions:
  - "One GalleryClient in its own module over NetworkingFeature, closures mirroring the 14 requests one to one; HomeClient and DownloadClient stay as they are"
  - "The noop/failing factories return @concurrent closures: Swift 6.4.2 crashes in SILGen on a parameter-pack closure inferred nonisolated(nonsending) (orchestrator decision)"
  - "A finish()-then-state assertion first processes the buffered received actions with skipReceivedActions(strict: false), because TestStore.state only advances on receive (orchestrator decision)"
  - "The errorSignals/nonErrorSignals partition lives once, publicly, in TestingSupport; no test file defines its own"
metrics:
  duration: "about 2 h 40 min wall clock, much of it waiting for other sessions' xcodebuild runs"
  completed: 2026-11-21
actuals:
  tokens: 19319
  tasks: 3
  commits: 3
plan_head_before: 7dabc282bbe4861dbd520913971f84c95b5c1833
plan_head_after: 06b4747a3fa63ab9447e58544759c1468d371e77
---

# Phase 261121-m6q Plan 01: Inject gallery list and detail fetches Summary

Every gallery list and gallery detail fetch that a reducer starts now goes through one injectable TCA dependency,
`GalleryClient`: 14 closures, 22 call sites in 11 files. Its test value reports any fetch a test did not stub. The
three `.errorSurfaced` stopgap filters from 261121-ifi are gone, and those tests stub the fetch, wait with `finish()`
and assert every recorded signal exactly. The app's requests are argument-for-argument identical to HEAD.

## Commits

| Task | Commit | Message | `%G?` | Author / committer date |
|------|--------|---------|-------|-------------------------|
| 1 | `adfb1812f` | Inject Home list fetches through GalleryClient | G | 2026-11-21T16:47:30+08:00 / same |
| 2 | `60149ac1f` | Inject Favorites and Search list fetches | G | 2026-11-21T16:51:05+08:00 / same |
| 3 | `06b4747a3` | Inject gallery detail fetches | G | 2026-11-21T18:18:34+08:00 / same |

`git rev-list --count 7dabc282b..HEAD` measures 7. Four of them (`2a8acb6ae`, `29229280d`, `bd8c5d059`, `02373e7db`)
belong to the concurrent session, which committed to `develop` during Task 3 and touched none of this plan's files.
This plan's commits are the three above.

## Correction of 261121-ifi

261121-ifi explained the stopgap filters wrongly. Its deviations 1 and 2 said a pushed screen's fetch "reaches the real
network under the test host, because its list request takes no injectable session", and its first follow-up asked for
injectable sessions so tests never reach the network. Neither holds:

- **Tests were already offline.** `AppPackage/Sources/TestNetworkGuard/TestNetworkGuard.m` is linked into every package
  test target by `Package.swift`'s `testTarget(module:)` (only `LiveCheckTests` is exempt). Its `+load` registers an
  `NSURLProtocol` that fails every non-loopback http(s) request with `NSURLErrorNotConnectedToInternet`, which
  `Request.fetch` retries and `mapAppError` turns into `AppError.networkingFailed`.
- **The defect was request construction inside reducer effects.** A test had no way to choose the outcome. The guard's
  `.networkingFailed` arrived at a moment set by effect scheduling, and since 261121-ifi it raised `errorSurfaced`.
- **`skipInFlightEffects(strict: false)` neither cancels nor awaits.** TCA 1.26.2's `_skipInFlightEffects` reports its
  message and clears `reducer.inFlightEffects`. The pushed screen's fetch kept running, so the test raced it.

## Census

- **HEAD (`7dabc282b`):** 26 in-scope constructions in 13 files outside NetworkingFeature
  (`.build/261121-m6q/parity-before.txt`). 22 of them are reducer-started, in 11 files. The other 4 are HomeClient.swift
  (3, its live value) and DownloadClient+ExecutionFetch.swift (1, its own session and cellular policy).
- **After:** 18 constructions in 3 files: GalleryClient.swift 14, HomeClient.swift 3, DownloadClient+ExecutionFetch.swift
  1. There are 22 `galleryClient.fetch` calls in 11 files, through 14 closures.
- The orchestrator's list had 19 reducer sites. The re-census at planning added the 3 `GalleriesMetadataRequest` sites:
  History's list fetch (2) and the Search root's recently seen galleries (1).

## Client and placement

- **Module.** `AppPackage/Sources/GalleryClient`, depending on AppModels, NetworkingFeature and ComposableArchitecture,
  with its own `.swiftlint.yml` (`parent_config: ../../../.swiftlint.yml`).
  - Home, Favorites, Search and Detail all start these fetches, and Favorites, Search and Home depend on Detail. A
    client inside one feature would force the others to depend on that feature or to duplicate it.
  - NetworkingFeature stays the request layer, with no `DependencyKey`. DFClient and DownloadClient set the precedent of
    a `…Client` module over it.
- **One client.** Favorites and Detail start both kinds of fetch, and the test value is unimplemented per closure, so a
  second key would add nothing.
- **Shape.**
  - The closures mirror the requests one to one, keeping each initializer's parameter order and `response()` type.
  - `live` binds 14 `private static func` bodies by reference, so `throws(AppError)` survives and the long parameter
    lists stay within 120 columns. No live function passes a session or cellular argument.
  - `liveValue` is `.live`, `previewValue` is `.noop` and `testValue` is `.unimplemented`. Each unimplemented closure
    names itself (`Unimplemented: GalleryClient.<closure>`).
  - `failing(_:)` fails every closure and reports nothing.
  - `noop` and `failing` are built by two file-private parameter-pack factories, `returning(_:)` and `throwing(_:)`.
- **Kept outside on purpose.** HomeClient stays as it is: it is the capture scenes' seam, and its popular fetch arranges
  the carousel. DownloadClient's own detail request also stays: it carries its session and cellular policy.

## Parity

`.build/261121-m6q/parity.py` checks the plan's two tables against the tree.

- **Self-check.** At the untouched tree it exits 1 with `PARITY 88`: 56 GalleryClient.swift MISSING, 21 call-site
  MISSING and 11 TOTAL.
- **Final.** Exit 0, `PARITY 0` (`parity-task3.txt`). GalleryClient.swift contains no `urlSession` and no
  `allowsCellular`.
- **Evidence.** The HEAD listing is `.build/261121-m6q/parity-before.txt`.

## Shared partition (orchestrator amendment)

- **Moved once.** The partition is now in `AppPackage/Sources/TestingSupport/AnalyticsSignal+Partition.swift`, as a
  public `extension [AnalyticsSignal]` with `errorSignals` and `nonErrorSignals`. Search's private copy
  (`SearchFeatureTests/AnalyticsEmissionTests.swift`, the former lines 312-331) is deleted.
- **Imports.** The Search, Home and Downloads emission suites import `TestingSupport`. Under the second orchestrator
  amendment, so does `ReadingFeatureTests/AnalyticsEmissionTests.swift`.
- **Package.swift edges.**
  - `TestingSupport` now depends on `AnalyticsClient`.
  - `HomeFeatureTests` and `SearchFeatureTests` now depend on `TestingSupport`.
  - DownloadsFeatureTests and ReadingFeatureTests already did.
- **Graph evidence (from planning).**
  - TestingSupport is test-only: the `products:` filter excludes it, and only test targets depend on it.
  - No source target depends on TestingSupport, and AnalyticsClient's closure (AppModels, AppTools, Resources, OSLogExt,
    CookieClient, DeviceClient and external packages) cannot reach back, so there is no cycle.
  - ImageClientTests now links AnalyticsClient, CookieClient, DeviceClient and TelemetryDeck transitively. FeatureTests
    builds them anyway.
- **No test file defines a partition.** `git grep -e 'var errorSignals' -e 'var nonErrorSignals' -- AppPackage/Tests`
  finds nothing. Neither `.filter({ signal in` nor `recorded.value.filter` appears in any test file.

## Tests changed

| File | Test | Stub | Outcome asserted | Listed by |
|------|------|------|------------------|-----------|
| HomeFeatureTests/AnalyticsEmissionTests.swift | `tappingASectionDestinationRecordsOneHomeSectionSignal` (frontPage, toplists) | `homeDestinationFetchesFailing` | `finish()`; `nonErrorSignals == [.homeSectionViewed(section)]`, `errorSignals == [.errorSurfaced(.networkingFailed, screen: section)]` | explicit |
| HomeFeatureTests/AnalyticsEmissionTests.swift | `tappingAMiscDestinationRecordsOneHomeSectionSignal` (popular, watched, history) | `homeDestinationFetchesFailing` | `finish()`; non-error as above; errors: Popular `.networkingFailed`, Watched `[]` (logged out, no fetch), History `.notFound` (empty local history) | explicit |
| HomeFeatureTests/HomeDuoPresentationTests.swift | `singlePaneSectionsKeepStackRouting`, `singlePaneOtherListsKeepStackRouting` | `homeDestinationFetchesFailing` | `finish()`, `skipReceivedActions(strict: false)`, then the pushed list's `loadingState`: Front Page, Toplists and Popular `.failed(.networkingFailed)`, Watched `.idle`, History `.failed(.notFound)` | explicit (deviation 2) |
| HomeFeatureTests/HomeDuoPresentationTests.swift | `sectionListsPresentOnTheOppositeSide`, `otherListsPresentOnTheRight` | `homeDestinationFetchesFailing` | the same, on the sheet root | explicit (deviation 2) |
| HomeFeatureTests/HomePresentationLifecycleTests.swift | header only (C3) | none | none | explicit |
| SearchFeatureTests/AnalyticsEmissionTests.swift | private partition deleted, `import TestingSupport` | none | uses the shared members unchanged | explicit |
| DownloadsFeatureTests/AnalyticsEmissionTests.swift | `pushingAGalleryDetailRecordsOneSignalMatchingTheFixture` | `fetchGalleryDetail = failing(.networkingFailed)` | `finish()`; `nonErrorSignals == [.galleryDetailOpened(…)]`, `errorSignals == [.errorSurfaced(.networkingFailed, screen: .detail)]` | explicit |
| DownloadsFeatureTests/AnalyticsEmissionTests.swift | `pushedGalleryDetailSignalCarriesNoFixtureContent` | `fetchGalleryDetail = failing(.networkingFailed)` | `finish()`; the reflection now also covers the `errorSurfaced` signal | explicit |
| AppFeatureTests/PresentationLifecycleTests.swift | header only (C4) | none | none | explicit |
| ReadingFeatureTests/AnalyticsEmissionTests.swift | `pageErrorsAreRecordedOncePerKindPerPresentation` | none | `errorSignals` exact (3 signals, unchanged); `nonErrorSignals.count == 1` | orchestrator amendment |
| DownloadsFeatureTests/AppDownloadDetailRoutingTests.swift | `aRegularWindowPresentsTheDownloadModally` | R1 after the shared maker | R2 `receive(\.presentation.gallery.detail.fetchGalleryDetailDone)`; R3 `loadingState == .failed(.networkingFailed)` | census 3 |
| DownloadsFeatureTests/AppDownloadDetailRoutingTests.swift | `aWindowCompactInEitherDimensionPushesTheDownload` (both arguments) | R1 after the shared maker | `path.count == 1`, id read from state, R2 `receive(\.downloads.path[id: id].detail.fetchGalleryDetailDone)`; R3 as above; test now `throws` | census 3 (deviation 3) |
| DownloadsFeatureTests/DownloadsReducerActionTests.swift | `testDownloadsReducerSeedsOnlineDetailStateFromDownload` | R1 in `withDependencies:` | the seeded-state expectations first, then R2 `receive(\.path[id: 0].detail.fetchGalleryDetailDone)` and R3 | census 3 (deviation 4) |
| DownloadsFeatureTests/DownloadsReducerActionTests.swift | `testDownloadsReducerRepeatedPushAddsDetailOnce` | R1 in `withDependencies:` | R2 right after the first push; R3 at the end | census 3 |
| DownloadsFeatureTests/DetailReducerObserveTests.swift | `testDetailReducerObservesDownloadBadgeTransitions` | R1 after the store maker | R2 `receive(\.fetchGalleryDetailDone)` after `.onPresented`; R3 at the end | census 3 |

Every census entry failed with `Unimplemented: GalleryClient.fetchGalleryDetail`. The stub is always
`GalleryClient.failing(.networkingFailed).<closure>`, the outcome the test network guard produced before, so each test
keeps its meaning. None of these tests records analytics, so R3 adds one state `#expect` each. R4 was never needed.
R5 added `import GalleryClient` to each file. The DownloadsFeatureTests → GalleryClient edge was added by Task 3's
explicit change. `CaptureRouteTests` was predicted but did not fail. Census 1 listed only the plan's explicit Duo tests,
and census 2 listed nothing.

## Gate results

| Run | BUILD | LINT | TEST |
|-----|-------|------|------|
| baseline | TEST BUILD SUCCEEDED, 0 warnings | exit 0, empty | TEST_GATE 0, FAILED 0 |
| 1 | failed: compiler crash (deviation 1) | exit 0, empty | not run |
| 1b | pass, no new warnings | exit 0, empty | census 1: FAILED 4 (the Duo tests, deviation 2) |
| 1c | pass | exit 0, empty | TEST_GATE 0, FAILED 0, all bundles equal to baseline |
| 2 | pass | exit 0, empty | census 2: TEST_GATE 0, FAILED 0, empty census |
| 3 | pass | exit 0, empty | census 3: FAILED 7 (5 `Unimplemented: GalleryClient.fetchGalleryDetail`, 2 ReduceMotion transient) |
| 3b | pass | exit 0, empty | FAILED 2 (deviations 3 and 4) |
| 3c | pass | exit 0, empty | TEST_GATE 0, FAILED 0, TEST EXECUTE SUCCEEDED (final whole-plan run) |

Two notes on the runs:
- Run 1c was executed twice: once by a queued waiter of mine, and once directly. The two runs did not overlap, and both
  were green.
- Final per-bundle counts (run 3c, passed / expected failures): AnalyticsClient 116/2, AppFeature 212, AppModels 130,
  AppTools 15, CookieClient 20, DetailFeature 197, DownloadsFeature 526/6, FavoritesFeature 19, FileClient 8,
  GalleryListComponents 13, HomeFeature 81, HostedView 14, ImageClient 9, ImageColors 4, LiveCheck 11,
  LiveTextTranslation 77, MarkdownExt 11, NetworkingFeature 117, ParserFeature 92, ReadingFeature 122, SearchFeature 18,
  SettingFeature 85/1, SystemNotification 4, TagTranslationFeature 12.
  - Every count equals the baseline except HostedView, which went from 11 to 14. The concurrent session's commit
    `29229280d` added `HeaderSectionDownloadLabelTests`.
  - Every test ran in parallel. Nothing gained `.serialized`, a lint suppression or `withKnownIssue`.

Static gates (final):
- `inline` prints 3 lines summing to 18, one per kept file.
- `calls` prints 0 mismatches, and parity prints `PARITY 0`.
- `galleryClient` appears in Package.swift edges 6 times; `testingSupport` 7 times.
- The stopgap comment, the filter, the "injectable session" headers and any live value in tests are all absent.
- `import TestingSupport` is in all three emission suites.
- The visual scan has 3 lines, all of them Settings account sends, so no visual scenario starts a gallery fetch.
- Every touched Swift file is within 1000 lines. Package.swift keeps its pre-existing, reasoned `file_length` exemption.

## Deviations from Plan

### Orchestrator-approved

**1. `@concurrent` on the two closure factories** (Task 1)
- **Found during:** BUILD 1.
- **Issue:** `swift-frontend` (Swift 6.4.2, Xcode 27.2) crashed in SILGen while compiling `GalleryClient.swift`. The
  stack ran through `While silgen closureexpr … returning(_:)` → `FunctionInputGenerator::projectPackComponent` →
  `ArgumentInitHelper::makeArgument`, on the closure `{ (_: repeat each Argument) async throws(AppError) -> Output in
  value }`.
- **Standalone repro (scratch file, outside the repo):**
  - With `-enable-upcoming-feature NonisolatedNonsendingByDefault`, `swiftc -emit-sil` exits 139, the same crash.
  - Without the feature it exits 0.
  - Naming the parameter, dropping `-> Output` and using `return` all still crash.
  - Adding `@concurrent` to the factories' return type exits 0 with the feature.
- **Fix:** both factories return `@concurrent @Sendable (repeat each Argument) async throws(AppError) -> Output`. Bodies,
  generics and call sites are unchanged. Each factory's doc comment states why: the closures only return a constant or
  throw, so running off the caller's actor changes nothing, and IssueReporting's unimplemented closures use the same
  `@concurrent` shape.
- **Commit:** `adfb1812f`.

**2. `skipReceivedActions(strict: false)` before the Duo routing tests' state assertion** (Task 1)
- **Found during:** census 1.
- **Issue:** after `finish()`, the four Duo tests saw the pre-fetch state: `.idle` for Front Page, Popular and History,
  and `nil` for Toplists.
  - In TCA 1.26.2's `TestStore.swift`, `state` is `reducer.state` (line 486).
  - An action an effect sends is reduced into a local copy and only appended to `receivedActions` (lines 2385-2387).
  - `reducer.state` advances only when `receive` (line 1781) or `skipReceivedActions` (line 2097) processes it.
- **Fix:** each of the four tests inserts `await store.skipReceivedActions(strict: false)` between `finish()` and the
  loading-state `#expect`, with a comment saying why. The comment is wrapped onto two lines to fit 120 columns. These
  stores are already non-exhaustive, and the assertion stays exact. The plan's other `finish()`-then-state assertions
  in Tasks 2 and 3 do not have this shape: their census fixes receive the done action, so none needed the line.
- **Commit:** `adfb1812f`.

**3. Stack id read from state in `aWindowCompactInEitherDimensionPushesTheDownload`** (Task 3)
- **Found during:** test 3b.
- **Issue:** for the horizontal-compact, vertical-regular argument only, `receive(\.downloads.path[id: 0]…)` timed out.
  TCA reported "received none after 1.0 seconds; there are no in-flight effects". The compact-horizontal route allocates
  a stack id before the push, so the pushed detail is not id 0. The cause was not investigated, by direction.
- **Fix:** both arguments now `#expect(store.state.downloadsState.path.count == 1)`, read
  `let id = try #require(store.state.downloadsState.path.ids.first)`, and receive via `path[id: id]`. The test is now
  `throws`.
- **Commit:** `06b4747a3`.

**4. R2 receive placed after the seeded-state expectations** (Task 3)
- **Found during:** test 3b.
- **Issue:** in `testDownloadsReducerSeedsOnlineDetailStateFromDownload`, receiving the done action right after the push
  also processed the effect actions buffered before it. The expectations about the seeded state then read
  `downloadBadge` nil and `shouldCheckForRemoteUpdates` false.
- **Fix:** the receive and the R3 `#expect(store.state.path.first?.detail?.loadingState == .failed(.networkingFailed))`
  now follow those expectations. `testDownloadsReducerRepeatedPushAddsDetailOnce` keeps the plan's placement.
- **Commit:** `06b4747a3`.

**5. Reading amendment shape** (Task 3)
- `pageErrorsAreRecordedOncePerKindPerPresentation` asserts the exact `recorded.value.errorSignals` list, unchanged.
- Its other half is now `#expect(recorded.value.nonErrorSignals.count == 1)`, replacing the local `readingSessionEnded`
  filter's count. It passed in runs 3, 3b and 3c.
- **Commit:** `06b4747a3`.

### Census-rule applications and mechanics

- **R1 for a single-caller maker.** `makeObserveTestStore` has one caller, so it was treated as a maker: the override
  goes on the line after the store is made, and the maker is unchanged.
- **Wrapped lines.** The Downloads stub lines
  `store.dependencies.galleryClient.fetchGalleryDetail = GalleryClient.failing(.networkingFailed).fetchGalleryDetail`
  (5 sites) are 121 columns at their indentation. They are wrapped after `=`, and only the layout differs. The C5 and C8
  comments are rewrapped within 120 columns with their wording unchanged.
- **Transient census-3 failures.** Two failures in `AppToolsTests/ReduceMotionGatingSourceTests` (inventory 37 vs 36 and
  81 vs 80) came from the concurrent session's commits. `29229280d` changed `DetailView+HeaderSection.swift` and that
  test while BUILD 3 was compiling. Both were gone after the rebuild in 3b.
- **gate.sh log name.** The first baseline log was written as `build-taskbaseline.log`. It was renamed to the plan's
  `build-baseline.log`, `warnings-baseline.txt` was regenerated from it (0 warnings), and the script was fixed.

### Pre-authorized fallbacks

None used. Removing `import NetworkingFeature` from PopularReducer, ToplistsReducer, HistoryReducer and
SearchRootReducer built cleanly, and no test file needed NetworkingFeature.

## Follow-ups

- **Reducer-started requests still outside a dependency**, grouped by file (from `git grep -n -E
  '[A-Z][A-Za-z]+Request\(' -- AppPackage/Sources ':!AppPackage/Sources/NetworkingFeature'
  ':!AppPackage/Sources/GalleryClient'`, leaving out Foundation, BackgroundTasks, Vision and Core Foundation request
  types, the two kept files and the already injected LoginClient and ReportFormClient):
  - `AppFeature/DataFlow/PresentationFeature.swift`: `GalleryReverseRequest` (deep-link gallery lookup).
  - `DetailFeature/Comments/CommentsReducer.swift`: `GalleryReverseRequest`, `EditGalleryCommentRequest`,
    `CommentGalleryRequest`, `VoteGalleryCommentRequest`.
  - `DetailFeature/DetailReducer+Fetch.swift`: `RateGalleryRequest`, `FavorGalleryRequest`, `UnfavorGalleryRequest`,
    `CommentGalleryRequest`, `VoteGalleryTagRequest`, `VoteGalleryCommentRequest`.
  - `DetailFeature/Archives/ArchivesReducer.swift`: `GalleryArchiveRequest`, `GalleryArchiveFundsRequest`,
    `SendDownloadCommandRequest`.
  - `DetailFeature/Torrents/TorrentsReducer.swift`: `DataRequest`, `GalleryTorrentsRequest`.
  - `DetailFeature/Previews/PreviewsReducer.swift`: `GalleryPreviewURLsRequest`.
  - `ReadingFeature/ReadingReducer+ImageFetch.swift`: `GalleryPreviewURLsRequest`, `ThumbnailURLsRequest`,
    `GalleryNormalImageURLsRequest`, `GalleryNormalImageURLRefetchRequest`, `MPVKeysRequest`.
  - `SettingFeature/EhSetting/EhSettingReducer.swift`: `EhSettingRequest`, `SubmitEhSettingChangesRequest`,
    `EhProfileRequest`.
  - `SettingFeature/SettingReducer+Body.swift`: `EhProfileRequest`, `IgneousRequest`, `UserInfoRequest`,
    `VerifyEhProfileRequest`, `FavoriteCategoriesRequest`.
  - `SettingFeature/SettingReducer+Helpers.swift`: `GreetingRequest`, `TagTranslatorRequest`.
  - (`DownloadClient/DownloadClient+ExecutionSupport.swift` builds its page requests inside the already injected
    download client.)
- **SwiftUI previews** now get the noop client (empty lists, a not-found detail) instead of the live requests.
- **261121-ifi's first follow-up** (injectable sessions for these requests) is superseded by this task.

## Known Stubs

None. `GalleryClient.noop` is the deliberate preview value, documented on the type.

## Threat Flags

None. The threat register's mitigations are in place:
- T-01: parity, with no session or cellular argument.
- T-02: an unimplemented test value, the guard still linked, and no live value in any test.
- T-03: the filters are gone and both partitions are asserted exactly.
- T-04: only the request expression changed at each site.

## Self-Check: PASSED

- The created files exist: GalleryClient.swift, GalleryClient/.swiftlint.yml, AnalyticsSignal+Partition.swift and
  GalleryClientTestSupport.swift.
- Commits `adfb1812f`, `60149ac1f` and `06b4747a3` are ancestors of HEAD, signed (G), with +08:00 author and committer
  dates.
