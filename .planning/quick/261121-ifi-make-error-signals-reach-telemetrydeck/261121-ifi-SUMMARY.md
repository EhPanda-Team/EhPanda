---
phase: 261121-ifi-make-error-signals-reach-telemetrydeck
plan: 01
subsystem: analytics
tags: [analytics, telemetrydeck, tca, error-signals]
status: complete
requires: []
provides:
  - "Reducer.signalsErrors: state-observing error signal operator (single value, dictionary, once-per-kind)"
  - "ErrorScreen closed vocabulary (17 cases) and the Error.screen parameter"
affects:
  - AnalyticsClient
  - AppFeature
  - HomeFeature
  - FavoritesFeature
  - SearchFeature
  - DetailFeature
  - DownloadsFeature
  - SettingFeature
  - ReadingFeature
tech-stack:
  added: []
  patterns:
    - "Signals follow state, not actions: TCA onChange(of:_:) wrapped as Reducer.signalsErrors"
key-files:
  created:
    - AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift
    - AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift
  modified:
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
    - AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
    - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesReducer.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift
    - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
decisions:
  - "errorSurfaced is emitted by observing state (Reducer.signalsErrors), not from an action; the dead setToast action is deleted"
  - "errorSurfaced carries a closed ErrorScreen under Error.screen; 17 cases, each used by exactly the call sites in the census"
  - "Reader counts each error kind at most once per presentation via surfacedErrorKinds, emptied in .onPresented"
  - "detailBody is wrapped in CombineReducers so the observer sees writes from every Detail sub-reducer (orchestrator decision)"
  - "Tests whose pushed screen's own fetch reaches the real network filter .errorSurfaced before asserting (orchestrator decision)"
metrics:
  duration: "about 2 h (wall clock, dominated by waits for another session's xcodebuild)"
  completed: 2026-11-21
actuals:
  tokens: 12740
  tasks: 3
  commits: 8
plan_head_before: 1d9a353b51fe1c5f779b8006b758ff98a877717f
plan_head_after: 5308210f4db94a08ff84ddca5d1b7af70b1bf998
---

# Phase 261121-ifi Plan 01: Make error signals reach TelemetryDeck Summary

`errorSurfaced` is now sent whenever an error toast or a rendered inline `LoadingState.failed` appears. The trigger is
a state-observing `Reducer.signalsErrors` operator built on TCA's `onChange(of:_:)`, so a direct state assignment can
no longer bypass the signal. Each signal carries a closed `ErrorScreen` spelling under `Error.screen`. There are 24 call
sites on 17 reducers, and the reader is de-duplicated once per kind per presentation.

## Commits

| Task | Commit | Message |
|---|---|---|
| 1 | `2d5b8efa1` | Send error signals from state changes |
| 2 | `070180421` | Signal inline errors on list screens |
| 3 | `5308210f4` | Signal detail, settings and reader errors |

All three are signed (`G`) with author and committer offsets `+08:00`. Nothing was pushed.

`commits: 8` is the measured `git rev-list --count` from the ledger base. Another session was committing to
`develop` at the same time, so the count includes five of its commits (`26aebba8d`, `c2a7809ca`, `7020d896b`,
`a4105944f`, `d0b6a0ee6`). They touch only PAL/CI files, `.gitignore` and their own planning folder. This plan made
three commits. The ledger base `1d9a353b5` is itself that session's commit, written after HEAD `e82010b40` at dispatch.
None of its files overlap this plan's.

## What was built

- **Operator** (`AnalyticsClient/Reducer+ErrorSignals.swift`), three public forms:
  1. `signalsErrors(of:on:)`: one signal when the projected `AppError?` changes to a non-nil value.
  2. `signalsErrors(of:on:)` over `[Key: LoadingState]`: one signal per key whose new value is `.failed` and differs
     from its old value. A key that had no value before counts as changed. Signals are sent ordered by kind.
  3. `signalsErrors(of:on:oncePerKindIn:)`: the dictionary form, but a kind already in the set is skipped, and each kind
     sent is added to the set in the same reduce.

  Each form resolves the client through a local `@Dependency(\.analyticsClient)` and returns one `.run` effect.
- **Vocabulary.**
  - `ErrorScreen` has 17 cases with implicit spellings, in the plan's order.
  - The signal is now `case errorSurfaced(AppErrorKind, screen: ErrorScreen)`.
  - It renders as `.error(id:category:parameters: ["Error.screen": screen])`, and the `"Error.screen"` literal is
    created only in the rendering file.
  - `AnalyticsSignal+Level.swift` and `TelemetrySDK.swift` are unchanged, and `errorSurfaced` stays at Basic.
- **PresentationFeature.** `setToast` and its reducer arm are deleted, and the `presentErrorInfo` comment is reworded.
  The observer is `.signalsErrors(of: \.toast?.errorInfo?.error, on: .deepLink)`.
- **Reader.** `surfacedErrorKinds: Set<AppErrorKind>` is emptied in `.onPresented`, and `imageURLLoadingStates` is
  observed with `oncePerKindIn: \.surfacedErrorKinds`.

## Gate results

**Baseline at the untouched HEAD:**
- `TEST BUILD SUCCEEDED`. `warnings-baseline.txt` is empty: 0 warnings.
- Lint (`App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension`) exited 0 with empty output.

| Task | BUILD | LINT | TEST |
|---|---|---|---|
| 1 | passed, no new warnings | exit 0, empty | first run 3011 passed / 1 failed (Home sweep, see deviations); after the fix 3012 passed / 0 failed / 9 expected failures |
| 2 | passed, no new warnings | exit 0, empty | first run 3019 passed / 5 failed (sweep rule); after the fix 3024 passed / 0 failed / 9 expected failures |
| 3 (final whole-plan run) | passed, no new warnings | exit 0, empty | first run 3033 passed / 3 failed; after the fixes **3036 runs passed, 0 failed, 9 expected failures, 0 skipped** (1910 test cases + 9 expected, 1919 total) |

**Final run, per-target test cases (from the xcresult `tests` tree; VisualSnapshotTests skipped as planned and compiled by BUILD):**

| Target | Passed | Expected failures |
|---|---|---|
| AnalyticsClientTests | 116 | 2 |
| AppFeatureTests | 212 | 0 |
| AppModelsTests | 130 | 0 |
| AppToolsTests | 15 | 0 |
| CookieClientTests | 20 | 0 |
| DetailFeatureTests | 197 | 0 |
| DownloadsFeatureTests | 526 | 6 |
| FavoritesFeatureTests | 19 | 0 |
| FileClientTests | 8 | 0 |
| GalleryListComponentsTests | 13 | 0 |
| HomeFeatureTests | 81 | 0 |
| HostedViewTests | 11 | 0 |
| ImageClientTests | 9 | 0 |
| ImageColorsTests | 4 | 0 |
| LiveCheckTests | 11 | 0 |
| LiveTextTranslationTests | 77 | 0 |
| MarkdownExtTests | 11 | 0 |
| NetworkingFeatureTests | 117 | 0 |
| ParserFeatureTests | 92 | 0 |
| ReadingFeatureTests | 122 | 0 |
| SearchFeatureTests | 18 | 0 |
| SettingFeatureTests | 85 | 1 |
| SystemNotificationTests | 4 | 0 |
| TagTranslationFeatureTests | 12 | 0 |

**Static gates (final):**
- Census: no MISMATCH lines. There are 24 `.signalsErrors(of:` calls, and 0 in PreviewsReducer, LoginReducer and
  SettingReducer+Body.
- Per-case: no UNUSED lines; all 17 `ErrorScreen` cases are used.
- Code-level `= .failed(` assignments: still 69.
- `surfacedErrorKinds` appears 2 times in `ReadingReducer+Body.swift`.
- `setToast` grep exit code is 1 (no match). `"Error.screen"` appears once in the rendering file. `public enum ErrorScreen` appears once.
- Every touched file is at most 1000 lines; the largest is 492.

## Exclusions (failure states no view renders, so none of them is observed)

| State | Evidence | Pinned by |
|---|---|---|
| Home `frontPageLoadingState`, `toplistsLoadingState` | `HomeSectionsView` reads only the loading half | `HomeFeatureTests.onlyTheHomePopularBlockFailureRecordsAnErrorSignal` |
| EhSetting `submittingState` | `EhSettingView` reads only `== .loading` | `SettingFeatureTests.onlyAFailedSettingsFetchRecordsAnErrorSignal` |
| Previews `loadingState` | `PreviewsView` never reads `loadingState` | `DetailFeatureTests.aFailedPreviewsFetchRecordsNothing` |
| Reader `previewLoadingStates` | no view reads it | `ReadingFeatureTests.pageErrorsAreRecordedOncePerKindPerPresentation` |
| Setting `tagTranslatorLoadingState` | `GeneralSettingView` reads only the loading half | census 0 in `SettingReducer+Body.swift` |
| Login `loginState` and its toast | login sends only `loginFailed` (out of scope) | the existing SettingFeatureTests login pins, unchanged and passing |

## Deviations from Plan

### Orchestrator-decided (owner delegated test-shape and attach-point calls to the orchestrator, 2026-11-21)

**1. Home destination sweeps filter `.errorSurfaced`** (Task 1)
- **Found during:** Task 1 TEST.
- **Issue:** `tappingASectionDestinationRecordsOneHomeSectionSignal(.frontPage)` recorded an extra
  `.errorSurfaced(.networkingFailed, screen: .frontPage)`. The pushed FrontPage's own fetch reaches the real network
  under the test host, because its list request takes no injectable session.
- **Fix:**
  - Both `tappingASectionDestinationRecordsOneHomeSectionSignal` and `tappingAMiscDestinationRecordsOneHomeSectionSignal`
    now assert the home-section signal as the exact subsequence of signals that are not `.errorSurfaced`, each with a
    one-line comment.
  - The suite header now says that `skipInFlightEffects` does NOT stop the pushed sub-screen's fetch.
- **File:** `AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift`. **Commit:** `2d5b8efa1`.

**2. Downloads gallery-detail push test filters `.errorSurfaced`** (Task 3, same cause)
- **Issue:** `DownloadsFeatureTests/AnalyticsEmissionTests/pushingAGalleryDetailRecordsOneSignalMatchingTheFixture`
  recorded `.errorSurfaced(.networkingFailed, screen: .detail)`. The download fixture carries host, gid and token, so
  the pushed Detail has a `galleryURL`, and `GalleryDetailRequest` reaches the real network under the test host.
- **Fix:** the same treatment as deviation 1: assert the non-`.errorSurfaced` subsequence, with a one-line comment.
- **Commit:** `5308210f4`.

**3. `detailBody` wrapped in `CombineReducers`** (Task 3; the plan text said to append to `detailBody`)
- **Issue:** `detailBody` is a builder of separate sub-reducers. The existing modifier chain hangs off
  `galleryOpsReducer` only, so an observer appended there would never see `fetchReducer`'s `loadingState` write.
- **Fix:**
  - The builder contents are unchanged in order, and the two `.ifLet`s stay on `galleryOpsReducer`.
  - They are now wrapped in `CombineReducers { … }`, with `.signalsErrors(of: \.loadingState.failed, on: .detail)`
    appended and a one-line comment explaining why.
  - The census stays at 1 in `DetailReducer.swift`.
- **Commit:** `5308210f4`.

### Sweep-rule applications (within the plan's test sweep rule)

- **Task 2, first run:** five failures from unimplemented `AnalyticsClient.send` in tests that are not about analytics.
  Each store got `$0.analyticsClient = .noop`, plus `import AnalyticsClient` where the file lacked it:
  - `FavoritesFeatureTests/EmptyStateTests`: `emptyKeywordSearchStaysNotFound`, `emptyDateSeekStaysNotFound`,
    `failedReloadOfAnEmptyCategoryShowsTheErrorInstead`
  - `FavoritesFeatureTests/GridPaginationTests/failedNextPageKeepsExistingResultsAndMarksRetryState`
  - `FavoritesFeatureTests/SortSelectionTests/selectingWhileLoadingAndFailedResponsePreserveConfirmedOrder`
- **Task 2, Search:** two existing analytics tests now also receive `.errorSurfaced(.notFound, screen: .search)`:
  `aFailedSearchRecordsOnePerformedSignalWithAZeroBucket` and `theRecordedPerformedSignalReflectsTheKeywordShape`.
  Each now asserts the `errorSurfaced` subsequence exactly and `searchPerformed` separately, through a private
  `[AnalyticsSignal]` partition extension in that file. They never assert cross-signal order.
- **Task 3, reader:**
  - `ReadingReducerImageFetchTests/refetchResponseWritesSkipServerToOriginatingHost`: the exhaustive assertion adds
    `$0.surfacedErrorKinds = [.notFound]`.
  - `ReadingReducerPageSizeTests/anMPVListForAnotherPageCountRecordsNoSize`: the store gets `.noop` analytics (with
    `import AnalyticsClient`), and the exhaustive assertion adds `$0.surfacedErrorKinds = [.notFound]`.

### Necessary mechanics, not shape changes

- `ReadingReducer.swift` now has `public import AnalyticsClient` instead of `import AnalyticsClient`. The new
  `public var surfacedErrorKinds: Set<AppErrorKind>` is public, at the same level as its neighbours, and the package
  enables `InternalImportsByDefault`.
- `Reducer+ErrorSignals.swift` imports `public import AppModels` and `public import ComposableArchitecture`, because
  its public signatures use `AppError`, `LoadingState` and `Reducer`.
- `import AnalyticsClient` was added (sorted) to the Toplists, History, Archives, Torrents, FolderManager and EhSetting
  reducers. `import DetailFeature` was added to the DownloadsFeatureTests emission file for `FolderManagerReducer`.
- The operator uses TCA's current `onChange(of:_:)` overload: old value plus `inout State`, returning an effect. It
  does not use the soft-deprecated builder overload.
- The fixture reducer in `ErrorSignalReducerTests` is a plain `Reduce` with `.signalsErrors` applied. It is not a
  `@Reducer` type, so the `Feature`-suffix naming rule does not apply.

## Follow-ups

- **Injectable sessions for list and detail requests.** `FrontPageGalleriesRequest` and its sibling list requests,
  plus `GalleryDetailRequest`, need an injectable session or client so tests never reach the network. Until then, the
  Home destination sweeps and the Downloads gallery-detail push test filter out `.errorSurfaced`.
- **Insights collector.** Its signal catalogue, kept outside this repository, must be re-derived, because
  `AnalyticsClient` changed: `errorSurfaced` now carries `Error.screen`.
- **Owner check after the next build that carries a TelemetryDeck app ID reaches users.** TelemetryDeck should list
  `TelemetryDeck.Error.*` events whose parameters include `Error.screen` with one of the 17 spellings. This cannot be
  checked locally.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or file access is introduced. The only new payload value is the closed
`ErrorScreen` spelling, as the threat model plans (T-261121-ifi-01).

## Self-Check: PASSED

- Created files exist: `AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift` and
  `AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift`.
- Commits `2d5b8efa1`, `070180421` and `5308210f4` are ancestors of HEAD.

## Correction (2026-11-21, quick task 261121-m6q)

The claim above that a pushed screen's fetch "reaches the real network" under the test host is wrong. The test network guard (`AppPackage/Sources/TestNetworkGuard`) fails every unstubbed request offline at once. The defect was that reducers built their requests inline, so a test could not choose the outcome, and the guard's failure raised `errorSurfaced` at a moment that raced `skipInFlightEffects`. Quick task 261121-m6q routed those fetches through `GalleryClient` and removed the three `.errorSurfaced` filters.
