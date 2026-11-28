# Phase 19: Full-page capture and per-view snapshot files (design proposal)

**Status:** approved by the owner on 2026-11-22 and implemented by plans 19-18 to 19-20 (per-view providers, the tall
window and its check, the measuring mode and `snapshot_heights.py`) and 19-30 (the two step stages, 2026-11-23); the
committed heights are filled in by 19-26.

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
    let factory: ScenarioFactory // make / prepare / still / interact / sign-in
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
- **Exemptions from C4 (owner decisions in 19-26 Task 2, amended 2026-11-28):** a state the owner keeps at the screen
  height declares `heights: .viewport(reason: "<the owner's words, dated>")`: it is taken at the device height and
  the `page-height` check skips it, and `snapshot_heights.py` never overwrites it. 29 states, each group with the
  owner's words: the reader's eight (「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」); the seventeen
  alerts and confirmation dialogs (「alert 組件不需要測量，所以只確認到存在 alert 就足夠」; the popover ones also
  「第四類已經拍到 popover 存在，為什麼還要拉高？」; `app-wide-app-alert` 「當 alert，維持螢幕高（建議）」); the four menus
  (「選單可以按你推薦處理」, the screen height, the menu's presence being enough). The states are listed in
  19-CONTEXT D-08 and in 19-26-HEIGHTS.md "## Owner decisions". The four keyboard states leave the matrix
  (「第三類拍不到鍵盤的話可以不拍這個狀態」). Every other state keeps C4.
- A window taller than the screen has known side effects, all measured in Phase 17, with remedies already in
  `VisualSnapshotSupport` (`FullContentHost`, `RenderServerCapture`):
  - the status bar comes back (companion window that mirrors `isStatusBarHidden`);
  - phone landscape turns into a regular vertical size class, and `GalleryViewport.isLandscape` flips (pin the
    size classes to the viewport's);
  - views that size themselves from their own measured viewport reflow (the observation-scoped viewport freeze);
    the frozen read is verified against the native one by the settle's own still-window rule (`readsMatch`: no byte
    more than one step apart, and no more such bytes than half the comparison's budget), not byte for byte. The
    byte-identical check of 19-19 failed on rendering rounding alone (one step on a card's 1 pt border, mostly in dark,
    at coordinates that moved from run to run), while a reflow moves far more (owner decision 2026-11-27 in 19-26:
    「改用靜止判斷的規則」);
  - pictures above 8192 device pixels in one dimension need the sliced composite. The slices are always the native
    viewport size: cross-origin reads are not byte-identical at glass rims and SF Symbols;
  - a form sheet that floats in its container (the iPad's, 580 x 660 pt) keeps its own size whatever the window's
    height, so content taller than it was in no picture at any height. The harness fits every such sheet to its
    content, never under its own size, through its preferred height, which UIKit keeps within the window less its
    margins (32 pt above and below): before the operating step, after it, and after the settle, with a second settle
    when that changed anything. The window's height stays the committed one; content taller than the window allows
    still fails the check. A sheet that fills the window's height, as on the iPhone, grows with the window already and
    is left as it is. The preferred height is the content's height less the sheet's native offset (its first frame
    height less SwiftUI's preferred height, 660 and 640 pt), kept per hosting, never the last preferred height plus the
    overflow, which kept rising while the window held the frame. It is compared and set in whole device pixels, as
    UIKit lays the frame out: a preferred height under a pixel off can still land the frame a pixel short (the
    downloads inspector's 742.008 pt for 742.5 pt of content was `cannot-cover` at every height in the CJK locales).
    The page of a sheet state is the sheet, on both
    devices: the need, the check and the measuring mode read only the front-most sheet and what is presented over it,
    never the page behind it (a 9,257 pt reader behind the reader's settings sheet set the iPad's need at every text
    size) (owner decisions 2026-11-27 in 19-26: 「sheet 的狀況應當測量 sheet 內容」, then 「貼合內容」; the
    reader's settings sheet is captured whole like the other sheets: 「當 sheet，整個內容都拍」).
- **Two kinds of step (owner decision 2026-11-23: 「把步驟拆成兩種」, split the steps into two kinds):** a scenario's
  steps are marked by their argument label. A stillness step (`still:`) only lets what `make` built finish and hold it
  still (it stops a spinner or a caret's blink, or waits for a keyboard, an alert or a glass shadow the state itself
  brought up); it runs at screen size right after hosting, so the page can settle before the window grows. Every other
  step is an operating step (`interact:`: a tap, a held tap, opening a menu or a dialog, scrolling, typing, or a check
  or correction the page does not need in order to settle, with everything the same step does after its action); it
  runs after the window has grown, so a popover anchors on its control. Order: on the screen-sized path host, `still`,
  `interact`, settle, capture, check (the one step of before); on the tall path host, `still`, native settle, freeze and
  verify, grow, `interact`, settle, capture, check. The measuring mode takes each height in the same order: the window's
  own height in a screen-sized hosting, each taller height in a fresh tall hosting, through the same
  `prepareGrownWindow`. A page that needs more than its window while the scroll view that sets its need avoids a
  keyboard that is up (the keyboard's top lies a device pixel or more above the scroll view's bottom, and the scroll
  view's bottom inset covers the overlap) is `cannot-cover:keyboard`, in the measuring mode and in the check's reason:
  a classification, never an adjustment.
- **Dialogs are opened by steps (owner decisions 2026-11-23: 「改成拉高後由步驟點開」 and 「還是照做，規則一致」):** every
  dialog, confirmation, popover, menu or alert is opened by the state's operating step after the window grows, through
  the held tap (`RevealStep.tap`, performed by `RevealStep.reveal`) or the step itself; no state is built with one
  already open, also where the old placement happened to hold. The hold of what the opening brought up (the app alert's
  caret) runs in that step right after the tap. The posting warning follows the order a user acts in: its stillness step waits for
  the editor to be focused and the keyboard up and at rest and stops the caret (`GalleryScenarios.holdStillOverKeyboard`,
  before the window grows), then its operating step taps Post, then waits for the warning and holds it still; the warning takes the focus and the keyboard goes down, so the state is not
  a keyboard state (no `cannot-cover:keyboard`). A toast has no control and is
  still built by `make`. A centred alert card centres in the window it is presented in, so on a taller window it sits
  lower on the page (a finding for 19-26). Popover constraint: in a window taller than the screen the scene's bounds
  stay at the screen's size, and UIKit draws an arrowed popover only within them, so a popover whose control lies
  below the first screen is `cannot-cover:popover` in the check's reason and in the measuring mode: a classification,
  never an adjustment (the reason's suffixes in a fixed order, `, cannot-cover:keyboard` before
  `, cannot-cover:popover` when both hold); 19-26 decides those pages one by one (「標出來，19-26 逐頁決定」).
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
