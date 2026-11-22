# Phase 19: Full-page capture and per-view snapshot files (design proposal)

**Status:** proposal, 2026-11-22. Nothing is implemented. Needs the owner's go-ahead before any code changes.

## Owner decisions this answers (2026-11-22)

- **C4, for every page:** each picture is taken at a size whose height covers the whole page, so nothing is hidden
  under a floating bar or below the fold (owner decision; "applies to all pages").
- **The height is fixed in the source:** never measured or changed during a run; the value lives in each view's
  `*ViewSnapshot.swift` file (owner decision).
- **One value per device × orientation × text size**, the tallest of the six languages (owner decision).
- **Declaration type:** previews stay `#Preview`; the snapshot states are declared in per-view `*ViewSnapshot.swift`
  files through a test-only `SnapshotProvider` protocol (owner decision, after the proof in
  `.capture/agent-work/review/provider-proof`: swift-snapshot-testing 1.19.6 records and compares a custom protocol's
  states and fails on a changed state; it has no `PreviewProvider` API of its own).

## 1. Declaration

```swift
/// A view's snapshot states, shaped like `PreviewProvider`, read by the matrix tests.
protocol SnapshotProvider {
    @MainActor static var states: [SnapshotState] { get }
}

struct SnapshotState {
    let id: String               // the scenario ID, unchanged: `front-page-list`
    let factory: ScenarioFactory // today's make / prepare / interact / sign-in, unchanged
    let heights: PageHeights     // the committed full-page heights
}

/// Points, per family × orientation × text size (12 values). `.screen` keeps the device height.
struct PageHeights { ... }
```

- One file per view under `AppPackage/Tests/VisualSnapshotTests/Snapshots/`, for example `FrontPageViewSnapshot.swift`
  (`enum FrontPageViewSnapshot: SnapshotProvider`). The four `ScenarioCatalog+*.swift` files are split into these and
  removed; `ScenarioCatalog` keeps only an explicit list of providers (Swift has no type discovery), and
  `ScenarioInventoryTests` keeps checking that the list equals `scenarios.json`.
- Scenario IDs, picture keys and the repository layout do not change.
- Test target only: nothing reaches Release (`verify-release.py` stays as it is).

## 2. Capture

- After rotation, the hosted key window is resized to the scene's width and the committed height for that
  coordinate. A page shorter than the screen keeps the screen height (the minimum is the device height).
- Pages that never scroll (reader, alerts, full-screen states) declare `.screen`.
- A window taller than the screen has known side effects, all measured in Phase 17, with remedies already in
  `VisualSnapshotSupport` (`FullContentHost`, `RenderServerCapture`):
  - the status bar comes back (companion window that mirrors `isStatusBarHidden`);
  - phone landscape turns into a regular vertical size class, and `GalleryViewport.isLandscape` flips (pin the
    size classes to the viewport's);
  - views that size themselves from their own measured viewport reflow (the observation-scoped viewport freeze);
  - pictures above 8192 device pixels in one dimension need the sliced composite. The slices are always the native
    viewport size: cross-origin reads are not byte-identical at glass rims and SF Symbols.
- **Check, never adjust:** after the settle, if the page's scroll content (with its insets) is taller than the
  committed height, the coordinate fails with `page-height: needs <n> pt, committed <m> pt`. Nothing grows the window
  at run time.

## 3. Filling in the heights

- A measuring mode of the local runner (`run-snapshot-local.sh --measure-heights`) records each coordinate's needed
  height and writes a proposal: the tallest of the six languages per family × orientation × size, rounded up to whole
  points. An agent copies it into the `*ViewSnapshot.swift` files in a reviewed commit. The gate never runs this mode.
- When a view changes and outgrows its height, the gate fails with the needed value. Updating the height is a
  source change, and the next baseline approval covers it.

## 4. Effects to accept

- **Storage:** today's set is 4.94 GB, just under the 5 GB line of 19-12 (R-2). Taller pictures will very likely go
  over it, so 19-12 Task 3's storage choice (keep git anyway, compressed release assets with the same fingerprints,
  or lossless PNG optimisation) comes back to the owner with the measured size.
- **Time and shards:** `snapshot-cost.json` and `snapshot-shards.json` are re-measured; slices add capture time.
- **Records to amend:** 19-CONTEXT D-08 (the window is taller than the screen), the scenario inventory, `README.md`,
  and 19-13's pre-check (the size-outlier check compares against the committed height).
- Every picture changes, so the whole set is recorded again (19-12 Task 2) and pre-checked again (19-13 Task 1).

## 5. Order of work (proposed)

1. Harness: protocol and per-view files (a pure move, same pictures at `.screen` everywhere: proven by a local run
   that matches `baseline2` for the moved scenarios), then the tall window with its check, then the measuring mode.
2. The owner's app fixes, one commit each with its test: C1, C2, C3, C5, C6, C7, C9, C11, C15, C16.
3. The run-to-run variation, measured on two hosted runs of the same commit.
4. Push with the owner's go-ahead, one full candidate run, assemble, pre-check, owner review and approval (19-13).

Planned as new Phase 19 plans (GSD), so each step has its own plan, checks and summary.
