---
phase: 11-infra-refactor-lint-capstone
plan: 8
subsystem: ui-lifecycle
tags: [tca, swiftui, lifecycle, lint, navigation]
requires:
  - "GalleryPath stack routing shared by five hosts"
  - "appendGuardingDuplicate returning the new StackElementID (11-07)"
provides:
  - "GalleryPath.State.onPresentedAction — the per-screen load action every host sends on presentation"
  - "GalleryNavigation.presentationEffect — one pairing helper for all six append sites"
  - "Presentation-driven lifecycle for the whole DetailFeature module"
affects:
  - "AppFeature (PresentationFeature modal + deep-link routes)"
  - "HomeFeature / SearchFeature / FavoritesFeature / DownloadsFeature (push seams)"
  - "DownloadsFeature (shared FolderManager sheet)"
tech-stack:
  added: []
  patterns:
    - "`GalleryNavigation.presentationEffect(id:screen:embed:)` — append-and-start in one expression"
    - "Sheet destinations start their fetch from the reducer case that sets the destination"
    - "`onScrollTargetVisibilityChange` replacing per-cell `onAppear` pagination"
key-files:
  created:
    - AppPackage/Tests/AppFeatureTests/PresentationLifecycleTests.swift
  modified:
    - AppPackage/Sources/DetailFeature/GalleryNavigation.swift
    - AppPackage/Sources/DetailFeature/GalleryDestination.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
    - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DetailFeature/Components/PostCommentView.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsReducer.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
    - AppPackage/Tests/HomeFeatureTests/HomePresentationLifecycleTests.swift
    - AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DetailReducerObserveTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift
decisions:
  - "The pairing lives on the route, not in each host: `GalleryPath.State.onPresentedAction` maps a screen to its load action and `GalleryNavigation.presentationEffect` sends it, so adding a gallery screen cannot silently skip a host."
  - "Sheet destinations (Archives/Torrents/FolderManager/PostComment) start from the reducer case that sets the destination, not from a shared helper — each has exactly one construction site."
  - "PostCommentView lost its `onAppearAction` parameter entirely: focus is now raised by the presenting reducer, so the component has no lifecycle hook to thread."
  - "Previews pagination moved to `onScrollTargetVisibilityChange`; the always-needed first page moved into `onPresented` so nothing depends on that callback's initial-fire timing."
metrics:
  duration: ~95 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 08: Lifecycle Migration — DetailFeature Summary

All DetailFeature lifecycle sites migrated to presentation-driven lifecycle. The module is lifecycle-modifier-free with **zero** `swiftlint:disable` exceptions, and no TCA action named `onAppear` survives anywhere in it.

## Site count

Plan said 14. Re-enumerated at HEAD before starting: **10** view lifecycle modifiers across 8 files (the plan appears to have counted the three `onAppear`-named *actions* alongside the modifiers). All 10 removed, all 3 actions renamed.

| Site | Where it went |
|---|---|
| `DetailView` gid load | `DetailReducer.onPresented`, sent by all 7 construction paths |
| `ArchivesView` fetchArchive | `DetailReducer.archivesButtonTapped` |
| `TorrentsView` fetchGalleryTorrents | `DetailReducer.torrentsButtonTapped` |
| `FolderManagerView` fetchFolders | `DetailReducer.folderManagerButtonTapped` **and** `DownloadsReducer.folderManagerButtonTapped` |
| `PostCommentView` focus hook | `DetailReducer.postCommentButtonTapped` / `CommentsReducer.presentPostComment`; the view's `onAppearAction` parameter deleted |
| `CommentsView` load | `CommentsReducer.onPresented`, sent on push |
| `CommentsView` deep-link scroll | `.onChange(of: scrollCommentID, initial: true)` — needs the `ScrollViewReader` proxy, so it stays in the view |
| `DetailSearchView` load | new `DetailSearchReducer.onPresented`, sent on push |
| `PreviewsView` load | `PreviewsReducer.onPresented`, sent on push |
| `PreviewsView` per-cell pagination | `.onScrollTargetVisibilityChange(idType:)` on the grid |

## Construction-site / load pairing (T-11-10)

Every `DetailReducer.State` construction site in the repo, and what starts it:

| # | Construction site | Load send |
|---|---|---|
| 1 | `HomeReducer+Body.swift` `.pushGalleryDetail` | `presentationEffect` → `.path[id].gallery.detail.onPresented` |
| 2 | `SearchRootReducer.swift` `.pushGalleryDetail` | same |
| 3 | `FavoritesReducer.swift` `.pushGalleryDetail` | `presentationEffect` → `.path[id].detail.onPresented` |
| 4 | `DownloadsReducer.swift` `.pushGalleryDetail` (`seededFrom:`) | same |
| 5 | `GalleryNavigation.nextScreen` → `.detail` (Comments → Detail, DetailSearch → Detail) | `presentationEffect` at all 6 `nextScreen` call sites |
| 6 | `PresentationFeature.presentGalleryDetail` (iPad modal) | `.send(.detail(.presented(.onPresented)))` |
| 7 | `PresentationFeature.handleGalleryLink` (deep link / clipboard / URL) | `.send(.detail(.presented(.onPresented)))` |

Sites 1–5 all funnel through `GalleryNavigation.presentationEffect(id:screen:embed:)`, which reads the load action off `GalleryPath.State.onPresentedAction`. That is the structural guard: a new gallery screen declares its load action once on the route enum and every host picks it up, rather than each host remembering to pair the send with the append. Sites 6–7 are the modal shape and carry their own send, since `@Presents` has no append to hook.

Verification greps: `DetailReducer.State` / `.detail(.init` construction sites — 7, all listed above; lifecycle tokens under `AppPackage/Sources/DetailFeature` — **0**; `onAppear`-named actions in DetailFeature — **0**.

## Parity notes

**Re-fire on pop-back.** The old `DetailView.onAppear` fired again when the user popped back from Comments/Previews. `onPresented` fires once. That is parity-equivalent because every effect it merges is guarded or idempotent (`fetchGalleryDetail` bails while `.loading`, `observeDownload` is `cancelInFlight: true`, the local-preview load is request-ID-guarded), and the one flow that genuinely needs a refresh from deeper in the stack — posting/voting a comment — already had an explicit path: `comments(.delegate(.performedCommentAction(gid)))` sends `.detail(.fetchGalleryDetail)` at the right element. That existed before this plan and is untouched.

**`onPresented` no longer takes a gid.** It used to receive the view's `gid` and assign `state.gid`. `State.init` already derives `gid` from the seeded gallery (both initializers do), so the parameter was writing the value it already held.

**`PreviewsView` and `DetailSearchView` lost their `gid` / `keyword` init parameters** — they existed only to feed the removed lifecycle callbacks. `galleryDestination` updated.

**`DownloadsFeature` touched beyond DetailFeature.** `FolderManagerView` is shared: Downloads presents the same sheet. Removing the view's `onAppear` without pairing Downloads' `folderManagerButtonTapped` would have shipped an empty folder list there, so that seam was migrated too (Rule 3).

## Verification

- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings (run after each task).
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures (66s).
- SwiftLint over `AppPackage/Sources AppPackage/Tests App ShareExtension` — **clean, 0 output**.
- `.swiftlint.yml` untouched (the `lifecycle_modifiers` flip belongs to 11-11).
- `LINT-01` left open — it flips at 11-29.

New tests: `PresentationLifecycleTests` (both modal routes) and `HomePresentationLifecycleTests.pushingGalleryDetailStartsItsLoad` (the push shape, on the host whose path nests the gallery stack under a `.gallery` case — the awkward embed of the five). `CommentsReducerTests` now asserts that presenting the post-comment sheet raises focus itself, replacing the assertion that used to hand-mimic the editor's `onAppear`.

## Deviations from Plan

### Auto-fixed / expanded scope

**1. [Rule 3 - Blocking] Five host modules modified, though the plan listed only DetailFeature files**

- **Found during:** Task 1
- **Issue:** Detail has no presenting reducer inside its own module. `files_modified` listed only DetailFeature, but the presentation seams live in HomeFeature, SearchFeature, FavoritesFeature, DownloadsFeature and AppFeature. Leaving any one unpaired is a permanently blank detail screen.
- **Fix:** Added `GalleryPath.State.onPresentedAction` + `GalleryNavigation.presentationEffect`, and wired all 7 construction sites.
- **Commit:** `0f52555c`

**2. [Rule 1 - Bug] `DownloadsFeature`'s FolderManager sheet would have stopped loading**

- **Found during:** Task 2
- **Issue:** `FolderManagerView` is presented by both DetailReducer and DownloadsReducer; only the former is in scope for this plan.
- **Fix:** `DownloadsReducer.folderManagerButtonTapped` now sends `.fetchFolders` too.
- **Commit:** `9bc0fa86`

**3. [Rule 3 - Blocking] Four existing tests needed dependency stubs**

- **Found during:** Task 1
- **Issue:** Pushing a detail now runs the detail's presentation effects inside the host's test store, so `DownloadsReducerActionTests`' two push tests hit unimplemented `date`/`downloadClient`, and `PresentationLifecycleTests`' deep-link case hit unimplemented `urlClient`.
- **Fix:** Stubbed those dependencies at the affected stores (`.noop` / constant date).
- **Commits:** `0f52555c`

## Flagged for owner review

**1. `onScrollTargetVisibilityChange` on the Previews grid wants device UAT.** The per-cell `onAppear` that requested the next batch of ten preview URLs is now a scroll-visibility callback on the `ScrollView` with `.scrollTargetLayout()` on the `LazyVGrid`. To make the screen independent of that callback's initial-fire timing, the always-needed first page moved into `PreviewsReducer.onPresented` (guarded on `previewURLs.isEmpty`) — so a worst case where the callback never fires initially still renders page one rather than a blank grid. What UAT should confirm is the *continued* paging: scroll a long non-downloaded gallery's previews past index 10, 20, 30 and check thumbnails keep filling in. `.scrollTargetLayout()` was added purely for id resolution and no `scrollTargetBehavior` was set, so scrolling should not feel paged; confirm that too.

**2. `CommentsView`'s deep-link scroll is now `.onChange(initial: true)`.** Same category as 11-07's `GalleryCardCell` note: documented to fire at appearance time, but not observable in tests. UAT: open a `#c`-anchored comment deep link and confirm the list still scrolls to and highlights that comment after ~0.75s.

**3. The three sheet seams have no test, for the same reason as 11-07's flag — there is no network seam.** `ArchivesReducer.fetchArchive` and `TorrentsReducer.fetchGalleryTorrents` construct request types whose `urlSession` is an `init` default, so a `TestStore` cannot stub them; asserting the presentation pairing would run a real request. They are three-line reducer changes with no branching (Archives keeps the `galleryURL`/`archiveURL` guard the sheet's `if let` already applied, so a tap without them presents the same empty sheet as before), and the whole-app build covers them structurally. Root-fixing means threading an injectable session through every request type — real work, well outside this plan.

**4. The post-comment focus delay is still a raw `Task.sleep(for: .milliseconds(750))`,** carried over verbatim from the deleted `onPostCommentAppear`. It now costs the Comments test ~1.5s of real time. Switching it to `@Dependency(\.continuousClock)` would make that instant and is a small, self-contained improvement — deliberately not done here to keep this plan's diff to the lifecycle move.

## Self-Check: PASSED

- `AppPackage/Tests/AppFeatureTests/PresentationLifecycleTests.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-08-SUMMARY.md` — FOUND
- Commit `0f52555c` — FOUND
- Commit `9bc0fa86` — FOUND
