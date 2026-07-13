---
phase: 04-concurrency-framework-migration
reviewed: 2026-07-13T09:28:51+09:00
depth: standard
files_reviewed: 74
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppRouteReducer.swift
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/ApplicationClient/ApplicationClient.swift
  - AppPackage/Sources/AuthorizationClient/AuthorizationClient.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesReducer.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift
  - AppPackage/Sources/DetailFeature/GalleryDestination.swift
  - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsReducer.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/FiltersFeature/FiltersView.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
  - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
  - AppPackage/Sources/HomeFeature/History/HistoryView.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
  - AppPackage/Sources/ImageClient/ImageClient.swift
  - AppPackage/Sources/LibraryClient/LibraryClient.swift
  - AppPackage/Sources/NetworkingFeature/Request+Account.swift
  - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
  - AppPackage/Sources/NetworkingFeature/Request+GData.swift
  - AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift
  - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
  - AppPackage/Sources/NetworkingFeature/Request+Image.swift
  - AppPackage/Sources/NetworkingFeature/Request.swift
  - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/SearchFeature/SearchReducer.swift
  - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
  - AppPackage/Sources/SearchFeature/SearchRootView.swift
  - AppPackage/Sources/SearchFeature/SearchView.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
  - AppPackage/Sources/SettingFeature/Login/LoginReducer.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift
  - AppPackage/Sources/SettingFeature/SettingView.swift
  - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift
  - AppPackage/Tests/NetworkingFeatureTests/Support/HarnessSelfTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/Support/RequestHarness.swift
  - AppPackage/Tests/ParserFeatureTests/Other/DownloadPageErrorParserTests.swift
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 04: Code Review Report

**Reviewed:** 2026-07-13
**Depth:** standard
**Files Reviewed:** 74
**Status:** clean

## Summary

Reviewed the complete Phase 4 diff (74 files, `2511f0d6^..HEAD` excluding planning artifacts):
the `Request` protocol's typed-throws façade and all 44 conformers, the shared four-attempt
`fetch` retry helper, the structured-concurrency rewrites (sliding-window chunk fan-out,
throwing-task-group image fan-out, whole-chain refetch retry), all migrated reducer effects and
client call sites, the Combine teardown, the TCA 1.25.3 traits pin, the projected-scope
migration across every touched view, and the offline parity harness plus its six baseline
suites.

The migration is faithful at the transport level: retry counts (4 total attempts), retry scope
(network fetch only, parse outside), first-step-only retry on the two-step chains
(`GalleryReverse`, `GalleryArchiveFunds`, `TagTranslator`), whole-chain retry on the image
refetch, the max-2 in-flight gdata window, fail-fast group cancellation, and the
`mapAppError` funnel all match the legacy Combine semantics, and the baseline tests lock these
dimensions honestly. `grep -r "import Combine" AppPackage/Sources` returns zero matches; no
`@unchecked Sendable`, `@preconcurrency`, continuation bridge, or detached task was introduced.
TCA declares exactly the two traits enabled (no default trait set is dropped by the explicit
`traits:` list), and every view change is an in-place scope-syntax swap that preserves the
original presentation anchors.

The three queued changes have been applied and re-reviewed. No actionable findings remain.

## Resolved Findings

### WR-01 — Fixed: missing thumbnail indexes no longer retry

`GalleryNormalImageURLRefetchRequest` now uses a private sentinel for a missing freshly parsed
thumbnail index. The retry loop maps that sentinel directly to `AppError.unknown`, restoring
the legacy single-attempt behavior while leaving genuine parse and transport failures retryable.
`normalImageRefetchMissingIndexFailsWithoutRetry` locks the one-attempt contract.

### IN-01 — Fixed: redundant `.noUpdates` branch removed

The typed `AppError` catch now sends `.fetchTagTranslatorDone(.failure(error))` directly. The
downstream action handler remains responsible for any `.noUpdates` behavior.

### IN-03 — Fixed: placeholder metadata request removed

`GalleriesMetadataRequest` now explicitly conforms to `Sendable`. Its task-group children
capture the real request and call an instance `chunkResult`, eliminating the empty placeholder
request without changing the two-task sliding window, cancellation, or output ordering.

### IN-02 — Accepted: malformed metadata maps to `.parseFailed`

The more accurate `.parseFailed` classification remains an intentional behavior improvement.
It does not affect `.noUpdates` handling or the UI error surface.

## Review Evidence

- **Retry parity:** `fetch` performs 4 total attempts with cancellation short-circuit;
  `RoutineRequestBaselineTests` asserts 4 attempts on persistent transport failure and the
  frozen `mapAppError` table; two-step chains retry only their first fetch
  (`urlSession.data(for:)` used directly on second steps), matching the Combine
  `genericRetry()` placement in every conformer diffed.
- **Structured concurrency:** the gdata sliding window primes 2 tasks and refills on success,
  cancelling all on first failure (matches `flatMap(maxPublishers: .max(2))` + fail-fast);
  output order is reconstructed from the input gid order. The normal-image fan-out uses a
  throwing task group with a `Sendable` result record; first failure cancels siblings.
- **Consumers:** all migrated effects follow the D-03 `do throws(AppError)` convention inside
  `.run`, preserving existing Result-carrying actions, cancel IDs, and send ordering;
  `Void` requests reconstruct `.success(())`; `createDefaultEhProfile` preserves the original
  fire-and-forget discard (QUAL-04 error surfacing is Phase 9 scope).
- **Teardown:** zero `import Combine` / publisher / continuation-bridge / `legacyResponse`
  matches under `AppPackage/Sources`; the remaining `withCheckedContinuation` uses are
  preexisting third-party-callback bridges outside phase scope.
- **CONC-02:** `Package.swift` pins `from: "1.25.3"` with both deprecation traits; TCA declares
  exactly those two traits (no default set silently dropped); resolution is 1.26.0. All view
  diffs are in-place scope/presentation-syntax swaps (`\.$destination`, `$detail`, `$toast`,
  plain `path` for `StackState`) — confirmed by pattern-scanning every non-scope changed line.
- **Hygiene:** no debris (TODO/FIXME/print/fatalError/`try!`/`swiftlint:disable`) and no
  >120-column lines among all added lines; no banned APIs (`NSLock`, `@preconcurrency`,
  `@unchecked Sendable`).

## Accepted Behavior Delta (carried from execution)

Native URLSession cancellation now stops active transport work immediately; the removed
continuation bridge could leave it running. TCA discarded the cancelled effect's send in both
implementations, so user-visible behavior is unchanged. IN-02 above is also accepted as the
more accurate error classification. WR-01 was fixed and is no longer a behavior delta.

---

_Reviewed: 2026-07-13T09:28:51+09:00_
_Reviewer: Codex (inline re-review after fixes)_
_Depth: standard_
