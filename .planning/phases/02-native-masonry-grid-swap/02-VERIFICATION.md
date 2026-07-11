---
phase: 02-native-masonry-grid-swap
verified: 2026-07-11T13:46:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
requirement: DEP-04
notes: "Criteria 1 (feasibility spike) and 3 (scrolling not regressed) are inherently human-judgment; the owner performed the live SR-1 sign-off on iPhone Air + iPad Pro 11\" (portrait & landscape) during Plan 02 and recorded GO. Recorded here as owner-verified, not re-openable machine checks."
---

# Phase 2: Native Masonry Grid Swap — Verification Report

**Phase Goal:** Replace the third-party WaterfallGrid with a custom app-owned SwiftUI `Layout` — validated by a feasibility spike first — with column-balancing and scrolling parity. (Requirement DEP-04)
**Verified:** 2026-07-11T13:46:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | A feasibility spike confirms a custom `Layout` can reproduce masonry column balancing before implementation is committed, or surfaces the blocker | ✓ VERIFIED (owner) | Plan 02 wired the candidate into the live `.thumbnail` call site (commit `64870474`) and measured real `proposal.width`; owner observed masonry balancing, reflow-on-load, animation suppression, and smooth scrolling on iPhone Air + iPad Pro 11″ (portrait & landscape) and recorded **GO**, no blocker. Spike gate ran before the production swap (Plan 03, commits `bcb61ea2`/`e682d53a`). Human-judgment item, owner-verified live. |
| 2 | All cells share one identical flexible width tiling any container width with fixed 15pt spacing; column count is a pure function of container width (adaptive rule, min cell width 185pt, min 2 columns) — stable against cell content, image loading, and type size | ✓ VERIFIED | `MasonryLayout.columnCount(for:)` = `max(2, Int((w+15)/(185+15)))`, `cellWidth` = `(w − 15·(N−1))/N` exact division; constants `spacing=15`, `minCellWidth=185`, `minColumns=2` (MasonryLayout.swift:26-31, 90-98). Column count derived **solely** from `proposal.width` — no screen/device/size-class/idiom read anywhere (grep for `UIScreen`/`DeviceUtil` = 0). Wired live: `MasonryLayout { ForEach(galleries) … }` in the `.thumbnail` branch (GenericList.swift:204). Suite green (below). |
| 3 | Scrolling performance is not regressed | ✓ VERIFIED (owner) | Owner confirmed clean scrolling with no hitching on iPhone Air during the SR-1 spike (Plan 02 GO). The synchronous `Layout` sheds WaterfallGrid's first-layout opacity flash / async placement hop (D-33) — a strictly-beneficial change. Human-judgment runtime item, owner-verified live. |
| 4 | WaterfallGrid is removed from the dependency set | ✓ VERIFIED | `grep -c WaterfallGrid AppPackage/Package.swift` = **0**; `grep -ci waterfallgrid AppPackage/Package.resolved` = **0**; `grep -rc 'import WaterfallGrid' AppPackage/Sources/` = **0** (only descriptive doc comments in MasonryLayout.swift naming what it replaced remain — not dependency references). Package.resolved pin dropped, other pins (colorfulx, kingfisher) intact. AboutView acknowledgement row removed (owner decision). |

**Score:** 4/4 truths verified (2 machine-verified, 2 owner-verified live). 0 behavior-unverified.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `AppPackage/Sources/GalleryListComponents/MasonryLayout.swift` | `MasonryLayout: Layout` + `MasonryPlan` + pure `columnCount`/`cellWidth`/`masonryPlan` + `Cache` | ✓ VERIFIED | 123 lines; thin `sizeThatFits`/`placeSubviews` delegate to `Self.columnCount`/`Self.cellWidth`/`Self.masonryPlan`; module-internal (never public, D-35); no spike instrumentation, no `Logger` |
| `AppPackage/Sources/GalleryListComponents/GenericList.swift` | Production `.thumbnail` swap; WaterfallGrid + legacy column reads removed | ✓ VERIFIED | `MasonryLayout` renders the live grid; `columnsInPortrait`/`columnsInLandscape` deleted; no `WaterfallGrid`/`OSLogExt` reference; D-36 auto-load preserved |
| `AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift` | Swift Testing parity suite | ✓ VERIFIED | 4 `@Test`s (13 parametrized cases): column-count table, degenerate clamp, exact cellWidth, leftmost-shortest placement; `@testable import` reaches the internal pure functions |
| `AppPackage/Package.swift` | Test target registered; WaterfallGrid removed | ✓ VERIFIED | `galleryListComponentsTests` case + `.testTarget` (lines 123, 983); zero WaterfallGrid lines |
| `AppPackage/Package.resolved` | Pin set regenerated, waterfallgrid dropped | ✓ VERIFIED | 0 waterfallgrid references; no version drift on other pins |
| `AppPackage/Sources/SettingFeature/Components/AboutView.swift` | Acknowledgement refresh (owner decision) | ✓ VERIFIED | WaterfallGrid row removed; `acknowledgementColorfulX` + `acknowledgementSwiftMarkdown` symbols present and resolve; 11 rows |

### Key Link Verification

| From | To | Via | Status |
| ---- | --- | --- | ------ |
| `MasonryLayout.sizeThatFits`/`placeSubviews` | `columnCount`/`cellWidth`/`masonryPlan` | thin Layout conformance delegates all arithmetic to internal pure functions | ✓ WIRED (`Self.columnCount`, `Self.cellWidth`, `Self.masonryPlan` at lines 50-54, 62-68) |
| `GenericList .thumbnail` branch | `MasonryLayout { ForEach(galleries) … }` | production call-site swap, no WaterfallGrid reference | ✓ WIRED (GenericList.swift:204-218) |
| `GalleryListComponentsTests` target | `GalleryListComponents` module | `.testTarget` dependency + `@testable import` | ✓ WIRED |
| `AppPackage/Package.swift` | `AppPackage/Package.resolved` | `swift package resolve` regenerates the pin set after removal | ✓ WIRED (pin dropped) |

### Data-Flow Trace (Level 4)

The `.thumbnail` grid renders `ForEach(galleries)` — `galleries` is the live model data threaded into `GenericList` (not a hardcoded/empty stub); `GalleryThumbnailCell` receives real `gallery` + `downloadBadge` per item. Data flows through the wired MasonryLayout. Status: ✓ FLOWING.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Column rule + placement arithmetic correct | `xcodebuild test -only-testing:GalleryListComponentsTests` (iPhone Air) | `** TEST SUCCEEDED **`, 4 tests / 1 suite, all 13 cases pass (incl. SR-1 measured bands 335→2, 790→4, 1140→5, 1336→6) | ✓ PASS |

Criteria 1 and 3 (masonry balancing, reflow-on-load, animation suppression, smooth scrolling) are live-runtime behaviors that cannot be synthesized in a unit test; they were owner-verified on the simulators during the SR-1 spike (GO). Not re-checkable here without a device session — resolved during the phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| DEP-04 | 02-01..02-04 | Replace WaterfallGrid with a custom app-owned SwiftUI Layout, spike-gated, column-balancing + scrolling parity | ✓ SATISFIED | All 4 success criteria met (2 machine, 2 owner-verified) |

### Anti-Patterns Found

None. Modified files (MasonryLayout.swift, GenericList.swift, AboutView.swift) carry no debt markers (TODO/FIXME/XXX/HACK), no stubs, no leftover spike instrumentation (`Logger`/`os.Logger`/`logger.debug` all removed). The `proposal.width` occurrences in MasonryLayout.swift are legitimate `Layout`-protocol API reads, not the removed spike logging.

### Human Verification Required

None outstanding. Criteria 1 and 3 are human-judgment items that were performed and signed off by the owner during the Plan 02 SR-1 spike (GO on iPhone Air + iPad Pro 11″). No re-verification action is pending.

### Gaps Summary

No gaps. The phase goal is achieved in the codebase: an app-owned `MasonryLayout` (pure width-driven column rule, m=185/min-2/spacing-15) renders the live `.thumbnail` grid, the parity arithmetic is locked by a green Swift Testing suite, WaterfallGrid is fully removed from `Package.swift`/`Package.resolved`/source, and the spike gate + scrolling parity were owner-verified live. All 8 task commits (`174fcb93` → `850b3b57`) are present.

---

_Verified: 2026-07-11T13:46:00Z_
_Verifier: Claude (gsd-verifier)_
