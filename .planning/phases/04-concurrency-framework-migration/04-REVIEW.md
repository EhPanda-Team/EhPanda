---
phase: 04-concurrency-framework-migration
reviewed: 2026-07-13T08:55:02+09:00
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
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-07-13
**Depth:** standard
**Files Reviewed:** 74
**Status:** issues_found

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

One behavioral deviation from the locked parity bar survived into the merged code (WR-01), plus
three informational quality/documentation items.

## Warnings

### WR-01: Missing-thumbnail-index in image refetch is now retried 4× (formerly a single attempt)

**File:** `AppPackage/Sources/NetworkingFeature/Request+Image.swift:186` (loop) and `:216` (guard)
**Issue:** In the legacy Combine chain, `storedThumbnailURL()` used
`.compactMap { thumbnailURLs[index] }`: when the freshly parsed detail page did not contain the
requested index, the publisher completed *empty* — `genericRetry()` only re-subscribes on
failure, so the chain made exactly **one** attempt and the async bridge surfaced
`AppError.unknown`. The rewrite converts that case into `throw AppError.unknown` inside
`refetchAttempt()`, which the surrounding `for _ in 1...4` loop catches as a retryable error. A
permanently missing index therefore now re-fetches and re-parses the whole chain three extra
times before surfacing the same `.unknown`. The final user-visible error is identical, but the
phase's contract (04-CONTEXT D-06 lists retry count as a parity dimension) makes this a genuine,
undocumented delta — the report's accepted-delta section covers only the cancellation change,
and no baseline test locks this corner (`ImageRequestBaselineTests` covers transport-failure
retries only).
**Fix:** Make the missing-index case non-retryable, restoring the single-attempt semantics:
```swift
private struct MissingThumbnailIndex: Error {}

// in refetchAttempt():
guard let thumbnail = thumbnails[index] else {
    throw MissingThumbnailIndex()
}

// in response()'s retry loop:
} catch {
    if error is MissingThumbnailIndex {
        throw .unknown
    }
    if (error as? URLError)?.code == .cancelled || Task.isCancelled {
        throw mapAppError(error: error)
    }
    lastError = error
}
```
Alternatively, if the extra retries are judged acceptable, document this as a second entry in
the Accepted Behavior Delta section and add a baseline test locking the new count.

## Info

### IN-01: Redundant `.noUpdates` switch in tag-translator catch block

**File:** `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift:116`
**Issue:** The `catch` block switches on the typed `AppError`:
`case .noUpdates:` sends `.fetchTagTranslatorDone(.failure(.noUpdates))` while `default:` sends
`.fetchTagTranslatorDone(.failure(error))`. When `error` is `.noUpdates` the default branch
would produce the identical action, so the switch is a no-op distinction — dead branching that
implies special handling where none exists.
**Fix:** Delete the switch and send `.fetchTagTranslatorDone(.failure(error))` unconditionally,
matching the pre-migration single-line failure path.

### IN-02: Byte-invalid tag-translator metadata JSON now maps to `.parseFailed` instead of `.unknown`

**File:** `AppPackage/Sources/NetworkingFeature/Request.swift:330`
**Issue:** The Combine chain used `try JSONSerialization.jsonObject(...)`; a thrown Cocoa JSON
error fell through `mapAppError`'s `default` case to `.unknown`. The rewrite uses
`try?` inside the guard, so byte-level invalid JSON now surfaces as `.parseFailed`. Valid JSON
with missing keys threw `.parseFailed` in both implementations, and the baseline
(`tagTranslatorMalformedMetadataMapsParseFailure`) feeds `{}` — valid JSON — so this corner is
not locked either way. `.parseFailed` is the more accurate classification and `.noUpdates`
handling is unaffected, but it is an unadvertised mapping change on a parity-bar phase.
**Fix:** Accept as an improvement and note it in the review's behavior-delta record (this
entry serves that purpose), or restore `try` + rethrough `mapAppError` for byte-exact parity.

### IN-03: Placeholder request instance constructed to reach protocol-extension helpers

**File:** `AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift:160`
**Issue:** `chunkResult` is `static` and builds `Self(gidList: [], urlSession: urlSession)`
solely to call the `gdataResponse` protocol-extension method. A dummy request whose `gidList`
is deliberately empty (while the real gid list travels in the `gidlist` argument) reads as a
bug on first encounter. `GalleriesMetadataRequest` is Sendable, so the task-group closure could
capture the real instance instead.
**Fix:** Drop the `static` and capture `self` in `group.addTask` (the struct is Sendable), or
hoist `gdataResponse` to a free function taking its dependencies explicitly.

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
implementations, so user-visible behavior is unchanged. WR-01 and IN-02 above are the two
additional deltas identified by this review; neither was previously documented.

---

_Reviewed: 2026-07-13T08:55:02+09:00_
_Reviewer: Claude (inline gsd-code-review, no subagents)_
_Depth: standard_
