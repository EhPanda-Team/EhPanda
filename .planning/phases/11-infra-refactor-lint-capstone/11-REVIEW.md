---
phase: 11-infra-refactor-lint-capstone
reviewed: 2026-07-21T00:51:34Z
depth: standard
files_reviewed: 172
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/AnimatedImageFeature/AnimatedImage+.swift
  - AppPackage/Sources/AppComponents/AppAlertState.swift
  - AppPackage/Sources/AppComponents/PreviewImageView.swift
  - AppPackage/Sources/AppComponents/TagCloudView.swift
  - AppPackage/Sources/AppComponents/TagSuggestionView.swift
  - AppPackage/Sources/AppComponents/ViewModifiers.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
  - AppPackage/Sources/AppModels/Gallery/GalleryComment.swift
  - AppPackage/Sources/AppModels/Persistence/JSONValue.swift
  - AppPackage/Sources/AppModels/Persistent/GalleryHistory+Operations.swift
  - AppPackage/Sources/AppModels/Support/AppError+Context.swift
  - AppPackage/Sources/AppModels/Support/EhSetting.swift
  - AppPackage/Sources/AppModels/Support/RunLogFile.swift
  - AppPackage/Sources/AppModels/Tags/TagTranslation.swift
  - AppPackage/Sources/AppTools/DataCache.swift
  - AppPackage/Sources/AppTools/Defaults.swift
  - AppPackage/Sources/AppTools/Extensions.swift
  - AppPackage/Sources/AppTools/Extensions/String+Helpers.swift
  - AppPackage/Sources/CookieClient/CookieClient.swift
  - AppPackage/Sources/CookieClient/DidLoginKey.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/Components/LinkedText.swift
  - AppPackage/Sources/DetailFeature/Components/PostCommentView.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift
  - AppPackage/Sources/DetailFeature/DetailReducer.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift
  - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift
  - AppPackage/Sources/DetailFeature/GalleryDestination.swift
  - AppPackage/Sources/DetailFeature/GalleryNavigation.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsReducer.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/FileClient/FileClient.swift
  - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
  - AppPackage/Sources/FiltersFeature/FiltersView.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
  - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
  - AppPackage/Sources/GalleryListComponents/GalleryList.swift
  - AppPackage/Sources/GalleryListComponents/MasonryLayout.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
  - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
  - AppPackage/Sources/HomeFeature/GalleryRankingCell.swift
  - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
  - AppPackage/Sources/HomeFeature/History/HistoryView.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/HomeFeature/HomeReducer.swift
  - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
  - AppPackage/Sources/ImageClient/ImageClient.swift
  - AppPackage/Sources/ImageColors/ImageColors.swift
  - AppPackage/Sources/LibraryClient/LibraryClient.swift
  - AppPackage/Sources/LogsClient/LogsClient.swift
  - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
  - AppPackage/Sources/NetworkingFeature/Request+Account.swift
  - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
  - AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift
  - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
  - AppPackage/Sources/NetworkingFeature/Request+Image.swift
  - AppPackage/Sources/NetworkingFeature/Request.swift
  - AppPackage/Sources/OSLogExt/Logger+.swift
  - AppPackage/Sources/ParserFeature/Parser+Detail.swift
  - AppPackage/Sources/ParserFeature/Parser+Greeting.swift
  - AppPackage/Sources/ParserFeature/Parser+Image.swift
  - AppPackage/Sources/ParserFeature/Parser+List.swift
  - AppPackage/Sources/ParserFeature/Parser+Preview.swift
  - AppPackage/Sources/ParserFeature/Parser+Profile.swift
  - AppPackage/Sources/ParserFeature/Parser+Shared.swift
  - AppPackage/Sources/ParserFeature/Parser+Torrent.swift
  - AppPackage/Sources/ParserFeature/Parser+Types.swift
  - AppPackage/Sources/ParserFeature/Parser+User.swift
  - AppPackage/Sources/PreviewSupport/.swiftlint.yml
  - AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
  - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
  - AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift
  - AppPackage/Sources/SearchFeature/GalleryHistoryCell.swift
  - AppPackage/Sources/SearchFeature/SearchReducer.swift
  - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
  - AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift
  - AppPackage/Sources/SearchFeature/SearchRootView.swift
  - AppPackage/Sources/SearchFeature/SearchView.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsPumpReducer.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsReducer.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
  - AppPackage/Sources/SettingFeature/SettingPath.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
  - AppPackage/Sources/SystemNotification/View+Toast.swift
  - AppPackage/Sources/TagTranslationFeature/TagTranslator+Lookup.swift
  - AppPackage/Sources/URLClient/URLClient.swift
  - AppPackage/Tests/AppFeatureTests/PresentationLifecycleTests.swift
  - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
  - AppPackage/Tests/CookieClientTests/DidLoginKeyTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift
  - AppPackage/Tests/DetailFeatureTests/DetailReadingLifecycleTests.swift
  - AppPackage/Tests/DetailFeatureTests/DetailReadingSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DetailReducerObserveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestFactories.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingCacheTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadsPresentationLifecycleTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerRefreshTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/PreviewsReducerDownloadTests.swift
  - AppPackage/Tests/FeatureTests.xctestplan
  - AppPackage/Tests/FileClientTests/FileClientTests.swift
  - AppPackage/Tests/HomeFeatureTests/.swiftlint.yml
  - AppPackage/Tests/HomeFeatureTests/FiltersPresentationLifecycleTests.swift
  - AppPackage/Tests/HomeFeatureTests/HomePresentationLifecycleTests.swift
  - AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift
  - AppPackage/Tests/ImageClientTests/ImageClientTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift
  - AppPackage/Tests/ParserFeatureTests/List/ListParserTests.swift
  - AppPackage/Tests/SettingFeatureTests/AccountSettingReducerTests.swift
  - AppPackage/Tests/SettingFeatureTests/SettingPresentationTests.swift
  - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
  - AppPackage/Tests/SystemNotificationTests/ToastInteractionTests.swift
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: resolved
---
# Phase 11: Code Review Report

**Reviewed:** 2026-07-21T00:51:34Z
**Depth:** standard
**Files Reviewed:** 172
**Status:** issues_found (1 Info; no Critical, no Warning)

## Summary

Phase 11 enabled eight SwiftLint rules at error and refactored the codebase to satisfy
them across 88 commits. I reviewed the semantic-risk surface rather than lint conformance
(which the phase's own battery already proves: 0 violations / 452 files, both builds clean,
565 tests green). I independently traced the six areas the prompt flagged as highest-risk —
the lifecycle migration, the parser restructures, the byte-parser rewrite, the tuple
labeling, the ~240 index-access rewrites, and the injected seams.

**Finding, stated plainly: this is clean work.** Every high-risk rewrite I traced is
behaviour-preserving, and I could not prove a single correctness, security, or data-loss
defect introduced by the phase. What follows is one forward-looking hardening observation
(Info), plus a confirmation section verifying that the residuals recorded in `11-EXCEPTIONS.md`
are accurately stated and none is worse than recorded.

I am not padding this report. A refactor of this size tempts filler; the honest result is
that the adversarial pass came up empty at Blocker/Warning severity, and saying so is more
useful than inventing severity.

### What I verified behaviour-preserving (traced, not assumed)

- **`AnimatedImage+.swift` byte parser** (`isAnimatedGIFFormat`, `isAnimatedWebPFormat`,
  `isAPNGFormat`). The `bytes[i]` → `Self.byte(bytes, at:)` conversion is equivalent for the
  non-negative offsets these walks use (`indices.contains(offset)` ≡ `offset < count`). The
  hand-rolled little/big-endian shifts became `UInt32(littleEndian:/bigEndian: loadUnaligned)`,
  which is correct on the little-endian iOS target. The added `offset >= 0` terms in the
  chunk-size guards are a strict improvement (a negative offset previously passed
  `offset + 4 <= count`). No off-by-one. (No test target — already recorded, §6.3.)
- **`ImageColors.colors`** column-major nested loop → flat 4-byte `makeIterator()` walk. The
  buffer is tightly packed (`bytesPerRow = width * 4`, size `width*height*4`), so the walk
  covers exactly the same pixel set; B/G/R/A consumption order and the packing math match the
  originals; the `[Double]` → `ProposedColors` struct is a field-for-field rename with the same
  `-1` sentinel. `edgeColor`'s `1..<count` → `dropFirst()` is equivalent on the empty case.
- **Tuple labeling** at `Request+Image.swift` (`imageURLs`/`originalImageURLs`),
  `parseMPVKeys` (`key`/`imageKeys`), and `parseCurrentFunds`/`GalleryArchiveFundsRequest`
  (`galleryPoints`/`credits`). I checked each construction site and each destructuring consumer
  (`fanOutResponse`, `ArchivesReducer.fetchArchiveFundsDone`); labels match semantics, nothing
  swapped.
- **`parseInfoPanel`** positional `[String]` → named `InfoPanel` struct: every slot maps to
  the same field (slot 4 = `fileSize`, slot 7 = `favoritedCount`, etc.), and the all-fields-
  non-empty guard is logically identical (`filter{!isEmpty}.count == 8` ≡ `!contains(isEmpty)`).
- **`parseGalleryTitle` / `URL.galleryIdentifiers`**: `pathComponents[2]`/`[3]` →
  `dropFirst(2).first`/`.dropFirst().first` yields the same gid/token and the same `count >= 4`
  guard, now routed to the parse-error path instead of a trap.
- **DownloadClient index-access rewrites**: the ~240 sites I sampled are Dictionary-key renames
  (`index` → `page`) — key lookups where off-by-one is structurally impossible — not Array
  restructures. `refetchAttempt(page: index)` passes the same value it read before.
- **Lifecycle migration**: `onAppear`/`onDisappear`/`.task` loads now fire from the presenting
  reducer. I traced the load-bearing seams (`GalleryNavigation.presentationEffect`,
  `GalleryPath.State.onPresentedAction`, `AppReducer.tabPresentationEffect`, `SettingPath.present`)
  and the four re-entry paths that could double-fire or miss:
  - **Cold launch**: `tabPresentationEffect(for: currentTab)` fires once from
    `loadUserSettingsDone` (after settings load); the tab shown at launch never gets a
    "became active" transition, so this is its only trigger. No pairing with a view `onAppear`.
  - **Tab switch**: the `type == current ? {re-tap logic} : tabPresentationEffect` branch is
    mutually exclusive, and the comparison reads the pre-Scope (old) tab value, correctly
    detecting re-tap.
  - **Idempotency**: each tab root's `.onPresented` self-guards (`popularGalleries.isEmpty`,
    `hasLoadedInitialDownloads`, `galleries?.isEmpty != false && didLogin`, gid-diff), so
    re-activation and repeated `loadUserSettingsDone` (login/logout) refetch nothing.
  - **Effect teardown**: presentation-started streams (`observeDownloads`) are
    `.cancellable(id:, cancelInFlight: true)`; the reader's `.onDisappear` handler-teardown and
    Setting's `.path(.popFrom)` profile-persist are the two justified exceptions, correctly
    placed in the parent reducer where the pop does not cancel them.
- **Injected seams**: `FileClient.live(applicationSupportURL:cachesURL:)` and
  `DownloadCoordinator.init(now:)` both default to the production locations
  (`.applicationSupportDirectory`, `.cachesDirectory`, `{ Date() }`); `liveValue = .live()` and
  every non-test call site passes no argument. Production behaviour is genuinely unchanged.

## Info

### IN-01: `Parser.degrading` logs the caught error at `privacy: .public` while only its `description` argument is privacy-guarded

**Status:** RESOLVED — commit `1dd35b2e` changed the error interpolation to `privacy: .private`; `description` stays `.public`. Build clean, ParserFeatureTests 33/33, cookie-logging scan exit 0.

**File:** `AppPackage/Sources/ParserFeature/Parser+Shared.swift:24-31`
**Issue:** The new degradation helper is:

```swift
static func degrading<Value>(_ description: String, _ parse: () throws -> Value) -> Value? {
    do {
        return try parse()
    } catch {
        logger.error("\(description, privacy: .public) failed to parse: \(error, privacy: .public)")
        return nil
    }
}
```

The doc comment carefully warns that `description` "must stay a fixed literal: never interpolate
document content, URLs, or cookie-bearing values into it" — but the *caught error itself* is
also interpolated at `privacy: .public`, with no such guard. The asymmetry is the concern: the
helper hardens the argument it controls and leaves open the argument an attacker's markup
influences.

**Not currently exploitable** — I verified every parse closure wrapped by `degrading` throws a
payload-free `AppError.parseFailed` (or another no-associated-value `AppError` case), so
`\(error)` today prints only a case name (`"parseFailed"`), carries no scraped content, and the
`Scripts/check-cookie-logging.sh` scan passes. This is a forward-looking robustness note, not a
present leak.

**Why it still matters here:** the project's cookie/PII-logging discipline is explicitly
absolute, and this is a brand-new, widely-called helper (every Group A/B parser degradation
routes through it). The moment a future parse closure throws an `AppError.fileOperationFailed(path)`,
`.expunged(reason)`, or a non-`AppError` (e.g. a Kanna error whose description echoes markup),
that value lands in a `.public` log line. The safe default for an error of uncertain provenance
is `.private`.

**Fix:**
```swift
logger.error("\(description, privacy: .public) failed to parse: \(error, privacy: .private)")
```
The fixed `description` already gives an operator the site; the error detail does not need to be
public. If a specific error's public visibility is wanted, narrow it to that case explicitly
rather than blanket-`.public` on an arbitrary `Error`.

## Confirmation of recorded residuals (not new findings — accuracy check only)

Per the review brief, I spot-checked the `11-EXCEPTIONS.md` residuals against the tree at HEAD.
Each is present as described and **none is worse than recorded**:

- **CookieClient race (§6.2)** — confirmed at `CookieClient.swift:36-48`: the
  `NotificationCenter.notifications(...)` observer is created inside the inner `Task {}` within
  the `AsyncStream` initializer, so a jar mutation in the window before the task starts can be
  missed. The `DidLoginKey` sibling was fixed; this narrower production window matches the
  writeup exactly.
- **AnimatedImageFeature has no test target (§6.3)** — confirmed; correctness rests on argument
  plus a green suite, as stated.
- **`parseInfoPanel` rejects the whole detail parse when any field is empty (§6.7)** — confirmed
  at `Parser+Detail.swift:275-276`; behaviour matches the pre-phase `count == 8` guard.
- **`ImageColors` nondeterministic tie-break (§6.6)**, **EhSetting arrays lack a count invariant
  (§6.5)**, **`saveTorrent` fixed Caches path (§6.8)**, **four gallery-URL grammars / duplicated
  `parseTags` (§6.4)**, **D-09 half-done — `AppModels` fixtures still mint `UUID()` (§7.3)**,
  **11-02 empty-vs-malformed conversion is inert (§7.1)**, **no network seam (§7.4)** — all
  confirmed present and accurately characterised; each is an acknowledged owner decision, not a
  Phase 11 regression.
- **`swiftlint_disable_requires_reason` `match_kinds: [comment]` gap (§3.1)** — confirmed; the
  reason requirement only binds where a comment already precedes the directive.

---

_Reviewed: 2026-07-21T00:51:34Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
