---
phase: 11-infra-refactor-lint-capstone
plan: 9
subsystem: ui-lifecycle
tags: [tca, swiftui, lifecycle, lint, reader]
requires:
  - "Modal `@Presents` lifecycle shape from 11-08 (each construction site carries its own send)"
provides:
  - "`ReadingReducer.onPresented` — the reader's load, sent by all four presenting reducers"
  - "Two reason-annotated D-02 exception candidates for owner review at 11-29"
  - "Finding: `swiftlint:disable:next` directives cannot land before the rule is uncommented"
affects:
  - "DetailFeature (two reader construction sites, DetailView)"
  - "DownloadsFeature (reader construction site, DownloadsView, three test doubles)"
tech-stack:
  added: []
  patterns:
    - "`.onChange(of:initial:)` collapsing an `.onAppear` into an adjacent change handler that already exists"
    - "Windowed prefetch keyed off the index window as a value, rather than per-slot appearance"
key-files:
  created:
    - AppPackage/Tests/DetailFeatureTests/DetailReadingLifecycleTests.swift
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
    - AppPackage/Tests/DetailFeatureTests/DetailReadingSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DetailReducerObserveTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/PreviewsReducerDownloadTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift
decisions:
  - "Three of six sites migrated, three kept as reason-annotated D-02 exception candidates. The reader's per-page loaders are driven by lazy-container materialization and by `.task(id:)`'s cancellation — both are the intended behaviour, not incidental lifecycle use."
  - "`ReadingView` lost its `gid` parameter entirely: it existed only to feed `.onAppear(gid)`, and every call site passed the gallery id the reducer already holds."
  - "`swiftlint:disable:next lifecycle_modifiers` cannot be written before 11-11 uncomments the rule — it trips `superfluous_disable_command`. Exceptions carry prose reasons now; the directives must land in 11-11's flip commit."
metrics:
  duration: ~40 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 09: Lifecycle Migration — ReadingFeature Summary

The reader's load is now sent by whoever presents it, and no TCA action named `onAppear` survives in ReadingFeature. Three of the module's six lifecycle-modifier sites migrated; the remaining three are reason-annotated D-02 exception candidates, per the escape hatch this plan explicitly sanctioned.

## Site count

Plan said 8. Re-enumerated at HEAD: **6** actual modifier sites (the grep also matches two prose comments, which the draft rule excludes via `excluded_match_kinds: [comment]`), plus the one `onAppear`-named action.

| # | Site | Verdict | Where it went |
|---|---|---|---|
| 1 | `ReadingView:126` reader load | migrate | `ReadingReducer.onPresented`, sent by all 4 construction sites |
| 2 | `ReadingView:234` scroll seeding | migrate | collapsed into the adjacent `.onChange(of: pageModel.index, initial: true)` |
| 3 | `ControlPanel:384` slider-preview fetch | migrate | `.onChange(of: previewsIndices, initial: true)` |
| 4 | `ReadingView:119` handler teardown | **exception** | view-owned `@State` handlers holding live work |
| 5 | `ReadingViewComponents:132` per-page fetch/prefetch | **exception** | lazy-container materialization is the intended trigger |
| 6 | `ReadingViewComponents:322` image `.task(id:)` | **exception** | load-bearing structured cancellation |

## Construction-site / load pairing (T-11-12)

The reader is a `@Presents` destination everywhere, so it takes 11-08's modal shape: no append to hook, each site carries its own send. All four:

| # | Construction site | Load send |
|---|---|---|
| 1 | `DetailReducer+Actions.presentReading` | `.destination(.presented(.reading(.onPresented)))` |
| 2 | `DetailReducer+Download.openReadingDone` | same |
| 3 | `PreviewsReducer.openReadingDone` | same |
| 4 | `DownloadsReducer.openReadingDone` | same |

`onPresented` reads the gid off `state.gallery.id` rather than taking it as a parameter — every construction site seeds `gallery`, and all three `ReadingView` call sites passed exactly that value. The view's `gid` parameter is gone.

## Migrate-vs-exception rationale

**2 — scroll seeding (migrated, but deliberately the safest possible version).** The adjacent `.onChange(of: pageModel.index)` already called the identical `tryScrollTo(id:)`; adding `initial: true` collapsed two modifiers into one. This is a genuine collapse rather than an `onAppear` renamed through `onChange`, because the handler has real non-initial work. It is also belt-and-braces: `scrollPositionID` is already seeded in `init`, so the resume page survives even if the initial fire lands late. The Phase 5 machinery — `onGeometryChange` as the single size source, position-based `scrollPosition` ids, the sliding-window rebase, `.scrollTargetBehavior(.paging)` — is untouched.

**3 — slider previews (migrated).** The window of preview slots is a pure function of `sliderValue` (plus size class and container size), so "which indices need a URL" is a value, not an appearance event. `.onChange(of: previewsIndices, initial: true)` covers the same set the per-slot `.onAppear` did, minus the dependency on when SwiftUI builds a slot. The comment warning that gating `previewsIndices` on a non-empty `previewURLs` deadlocks the tray was updated — the deadlock is still real, but it is no longer phrased in terms of `onAppear`.

**4 — reader teardown (exception).** `liveTextHandler.cancelRequests()` and `setAutoPlayPolocy(.off)` tear down two view-owned `@State` handlers: in-flight Vision requests and a repeating autoplay timer. Neither is reducer state, so no action can stand in, and no value change marks the view's removal. Dropping it leaks an autoplay timer that keeps turning pages of a reader nobody is looking at. Note the reducer already handles the *persistence* half on `.onPerformDismiss` — this hook is deliberately non-persistence only.

**5 — per-page fetch/prefetch (exception).** The trigger is materialization by the lazy container, and that is the behaviour wanted: both readers (`LazyHStack` when paging, `AdvancedList` when vertical) build a page's container shortly before it is needed. No reducer signal reproduces it — `pageModel.index` moves only on *settled* page changes, dual-page mode maps one position to two indices, and the vertical list renders many containers at once. `onScrollTargetVisibilityChange` (11-08's Previews answer) does not fit either: it covers only the horizontal path, and it fires at visibility, whereas prefetch exists precisely to run *ahead* of visibility. Rebuilding the laziness in the reducer would risk load-order and cancellation drift on the app's hottest request path for no behavioural gain.

**6 — image `.task(id:)` (exception).** Used for its cancellation, not merely to start work: it ties the download to both the view's lifetime and the URL's identity, and `load()` reads that signal via `Task.isCancelled` to tell a cancellation apart from a real failure (pre-existing, documented in the code). The only non-banned alternative — `.onChange(of: url, initial: true)` firing an unstructured `Task` — drops the cancellation and leaks concurrent image downloads.

## Verification

- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings (run after each task).
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures (66s).
- SwiftLint over `AppPackage/Sources AppPackage/Tests App ShareExtension` — **0 violations in 448 files**.
- Lifecycle-token grep across `AppPackage/Sources/ReadingFeature` — **3 matches, all reason-annotated exceptions**; remaining grep hits are prose comments the rule excludes.
- `onAppear`-named actions in ReadingFeature — **0**.
- `.swiftlint.yml` untouched (the `lifecycle_modifiers` flip belongs to 11-11).
- `LINT-01` left open — it flips at 11-29.

New test: `DetailReadingLifecycleTests` asserts both of Detail's presentation paths send `.onPresented` and that it fans out to `observeDownloads` + `loadLocalPageURLs`.

## Deviations from Plan

### Auto-fixed / expanded scope

**1. [Rule 3 - Blocking] Four presenting reducers and three views modified, though `files_modified` listed only ReadingFeature**

- **Found during:** Task 1
- **Issue:** The reader has no presenting reducer inside its own module. All four construction sites live in DetailFeature and DownloadsFeature; leaving any one unpaired ships a reader that never resolves its local pages and never observes its download.
- **Fix:** Added the `.onPresented` send at all four sites; dropped the now-dead `gid` argument at the three `ReadingView` call sites.
- **Commit:** `ccd7421b`

**2. [Rule 1 - Bug] Four existing tests asserted a contentSource that production immediately overwrote**

- **Found during:** Task 1
- **Issue:** `DetailReducerObserveTests` (×2), `PreviewsReducerDownloadTests` and `DownloadsReducerActionTests` assert `contentSource == .local` after opening the reader. Their `DownloadClient` doubles never stubbed `loadLocalPageURLs`, so it returned nil → `[:]` → `loadLocalPageURLsDone` correctly downgraded `.local` to `.remote`. The tests only passed because the load never ran inside the test store; **in production this downgrade already happened**, one beat later, via the view's `onAppear`. Moving the send into the transition surfaced the gap rather than creating it.
- **Fix:** Stubbed `loadLocalPageURLs` in the three doubles to return page URLs derived from the manifest — what a completed download actually has on disk. Added a `skipReceivedActions` to the Downloads test so the fanned-out actions settle before the assertion.
- **Commits:** `ccd7421b`
- **Note:** the assertions are unchanged and still meaningful; only the doubles became complete. No production behaviour was altered to make a test pass.

**3. [Rule 3 - Blocking] `DetailReadingSeedTests` needed a `downloadClient` stub**

- **Found during:** Task 1
- **Issue:** Same cause as 11-08's deviation 3 — presenting now runs the child's effects inside the presenter's store, hitting an unimplemented `downloadClient`.
- **Fix:** `$0.downloadClient = .noop` at both stores.
- **Commit:** `ccd7421b`

## D-02 exception candidates for owner review (11-29)

Three sites, all argued above. Summarised for the batch review:

| Site | Token | One-line reason |
|---|---|---|
| `ReadingView.swift` reader teardown | `.onDisappear` | Cancels view-owned Vision requests and an autoplay timer; no reducer state, no value change marks removal |
| `ReadingViewComponents.swift` page container | `.onAppear` | Lazy-container materialization IS the intended fetch/prefetch trigger; prefetch must run ahead of visibility |
| `ReadingViewComponents.swift` image loader | `.task(id:)` | Structured cancellation is load-bearing; `load()` branches on `Task.isCancelled` to avoid reporting false failures |

## Flagged for owner review

**1. Blocking finding for plan 11-11: exception directives cannot precede the rule flip.** Writing `// swiftlint:disable:next lifecycle_modifiers` while the rule is still commented out trips `superfluous_disable_command` (verified empirically against the project config: `'lifecycle_modifiers' is not a valid SwiftLint rule; remove it from the disable command`). Since lint is error-level here, that would break the gate. Consequence: **11-11's flip commit must atomically uncomment the rule AND add every `disable:next` directive across all modules** — it cannot be a one-line config change. This plan's three exceptions carry prose reasons only; 11-11 must add their directives. The same will hold for any exception 11-10 records.

**2. Device UAT: reader seeding.** Site 2 changed `.onAppear { tryScrollTo(...) }` into `.onChange(of: pageModel.index, initial: true)` on the horizontal paging ScrollView. This is inside the Phase 5 baseline-locked seeding pair, so it wants one device pass even though the risk is low (the `init` seed of `scrollPositionID` is unchanged and independently carries the resume page). UAT: open a gallery previously read to page N, in both LTR and RTL, and confirm it opens on page N rather than page 1; then drag the slider and confirm the pager lands where the slider says.

**3. Device UAT: slider preview tray.** Site 3 replaced the per-slot `.onAppear` fetch with a window-valued `.onChange`. UAT: open the reader on a non-downloaded gallery, reveal the control panel, and confirm the preview thumbnails above the slider populate on first reveal and keep populating as the slider is dragged across the gallery.

**4. Zoom/pan/tap parity untouched.** No gesture code was modified — `SpatialTapGesture`/`MagnifyGesture`, the `highPriorityGesture` drag, `gestureHandler.scale`/`offset` and the `scrollDisabled(scale != 1)` gating are byte-identical. The paging construct, `windowBase`/`scrollPositionID` write discipline, and `onGeometryChange` source-of-truth are likewise untouched. Flagging only that nothing here should need gesture re-verification.

**5. Test coverage remains asymmetric — still no network seam.** Covered here: both Detail presentation paths, end-to-end through the reader's local-page load (which settles offline). Not covered: the Previews and Downloads presentation sends, for the reason 11-07/11-08 recorded — `NetworkingFeature` request types take `urlSession: URLSession = .shared` as an init default, so a `TestStore` cannot stub a fetch. Both are one-line reducer changes, and the four repaired download tests now exercise those paths structurally. Unchanged and still worth a root fix outside this phase.

## Self-Check: PASSED

- `AppPackage/Tests/DetailFeatureTests/DetailReadingLifecycleTests.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-09-SUMMARY.md` — FOUND
- Commit `ccd7421b` — FOUND
- Commit `e167038d` — FOUND
