# Phase 03 D-11 Go/No-Go Checklist

This checklist is the D-02 all-or-nothing gate for removing SwiftUIPager. Walk every row on a physical device and
on iOS 26 simulators in portrait and landscape where applicable. In the **Pass / Gap (owner)** column, enter exactly
`Pass` or `Gap` and record observed evidence or failure details. A `Gap` in any row makes the decision `NO-GO`.

The implementation under review is the committed native reader and carousel spike from Plans 03-02 through
03-04. SwiftUIPager remains declared until this checklist is complete and the owner records `GO`.

## Reader

| D-10 parity item | Pass / Gap (owner) | How to verify | Evidence to check or record |
|---|---|---|---|
| Horizontal paging | Pass | Use `.leftToRight` in portrait. Swipe several pages in both directions and stop after partial drags. Confirm every release snaps to exactly one full-width page and the displayed progress/index follows the visible page. | Record device/simulator and page numbers tested. The native paging structure is documented in `03-03-SUMMARY.md`. — R1 in `03-UAT.md`: full swipes settled 1→2→3→4→3→2; partial drag snapped back; progress + slider synchronized. |
| RTL direction and logical index | Pass | Switch to `.rightToLeft`. Swipe in both directions and use a seek action. Confirm the paging axis reverses, the requested logical page still lands correctly, and progress/index matches the visible page. | Record requested and visible page numbers. `PageHandlerTests` verifies that mapping stays direction-agnostic; `03-03-SUMMARY.md` records the axis-only `layoutDirection` flip. — R2 in `03-UAT.md`: RTL axis reversal and logical indexing passed. |
| Dual-page landscape paging and snap | Pass | Enable dual-page mode, rotate to landscape, and swipe across multiple stacks. Confirm every gesture settles on one complete spread with no half-way offset, skipped stack, or drift. Repeat near the first and last stacks. | Record device/simulator, orientation, and stacks tested. Explicitly note whether the `.paging` landscape FB16486510 misalignment appeared. — R3 in `03-UAT.md`: owner device pass (2026-07-12), dual-page landscape snapping cleanly; FB16486510 not observed. |
| RTL × dual-page landscape spread order | Pass | With dual-page mode on, landscape orientation, and `.rightToLeft`, swipe across several spreads. Confirm the paging axis runs right-to-left **and the earlier page appears on the RIGHT** in every spread. | Record at least two visible page pairs and their left/right order. An earlier page on the left is a genuine gap: the `layoutDirection` flip double-reversed the `imageContainerConfigs` swap (03-REVIEWS HIGH). — R4 in `03-UAT.md`: owner device pass (2026-07-12); no double-flip. |
| PageHandler index mapping, including dual-page cover math | Pass | Compare visible pages with slider/progress in single-page, ordinary dual-page, and dual-page-with-cover modes. Check the first spread, a middle spread, and the final boundary; seeking a reading page must show the expected stack and returning from that stack must report the expected reading page. | Record the checked page/stack pairs. Automated guard: `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` (8 tests / 58 cases) and `ContainerDataSourceTests.swift` (4 tests / 13 cases), summarized in `03-01-SUMMARY.md`. — R5 in `03-UAT.md`: owner device pass (2026-07-12) incl. dual-page; math auto-covered by green tests. |
| Slider seek | Pass | Drag the slider to the first, middle, penultimate, and final valid positions in single- and dual-page modes. Confirm each animated jump is smooth, lands exactly once, and has no flash, glitch, or off-by-one result. | For every sample, record slider target, visible page/stack, and the `jump requested:` / `landed:` values. Requested and landed ids must match. — R6 in `03-UAT.md`: middle 111/255, final 255/255; owner device pass (2026-07-12) incl. penultimate + dual-page. |
| Autoplay `.next` | Pass | Start autoplay in single- and dual-page modes and observe several advances, including the final valid stack. Confirm each advance is smooth, moves exactly once, and clamps at the end without an off-by-one or feedback jump. | Record visible transitions and matching `jump requested:` / `landed:` log pairs from the settle-time instrumentation described in `03-04-SUMMARY.md`. — R7 in `03-UAT.md`: advances once per interval and clamps; owner device pass (2026-07-12) incl. dual-page. Owner-requested change (`b6730a48`): autoplay auto-resets to `.off` at the last stack. |
| Tap-to-turn | Pass | At scale 1, tap both page-turn edge regions in LTR and RTL. Confirm each tap moves exactly one logical page/stack in the direction indicated by the reading mode, with no duplicate or reversed turn. | Record direction, tapped edge, starting page, resulting page, and matching requested/landed log ids. — R8 in `03-UAT.md`: RTL left/right edge tap directions passed; owner device pass (2026-07-12) incl. LTR + dual-page. |
| Resume-page seed | Pass | Leave the reader on a non-initial page, close it, and reopen the same gallery in single- and dual-page modes. Confirm the correct saved page/stack is visible immediately, without first showing another page or performing a corrective jump. | Record saved reading page, expected pager index, and first visible page/stack. `03-03-SUMMARY.md` records construction-time seeding of both `PageModel` and `scrollPositionID`. — R9 in `03-UAT.md`: reopens directly on the saved page; owner device pass (2026-07-12) incl. dual-page. |
| Zoom, pan, and tap coexistence | Pass | Zoom above scale 1, then swipe horizontally: paging must stay frozen. Pan the zoomed image: the image must move normally. Return to scale 1 and, in RTL, tap each edge: the correct page-turn direction must be preserved. Tap the center and confirm the reader panel toggles. | Record all four observations: paging frozen while zoomed, pan works, RTL edge taps turn correctly, and center tap toggles the panel. Wiring evidence is summarized in `03-04-SUMMARY.md`; touch behavior requires this manual check. — R10 in `03-UAT.md`: all four observations covered (frozen-while-zoomed, pan, RTL edge taps, center toggle). |
| Vertical `AdvancedList` shared-index seam | Pass | Select a vertical reading direction, scroll through several pages, use the slider, allow autoplay to advance, and reopen on a saved page. Confirm the visible page, progress, seek target, autoplay result, and resume page all share the same logical index with no ±1 regression. | Record the pages exercised and any requested/visible mismatch. `03-03-SUMMARY.md` records the byte-for-byte `AdvancedList` re-seam from `Page` to `PageModel`. — R11 in `03-UAT.md`: vertical scroll, progress, slider, autoplay, and resume all share one index. |

## Carousel

| D-10 parity item | Pass / Gap (owner) | How to verify | Evidence to check or record |
|---|---|---|---|
| Centered snap and symmetric peek | Pass | Open Home with at least three cards. Swipe one card at a time and stop after partial drags. Confirm the settled card is centered and equal portions of the neighboring cards peek on both sides. | Record device/simulator and whether left/right peek widths appear symmetric. `03-02-SUMMARY.md` records `contentMargins` centering with native `.viewAligned` paging. — C1 in `03-UAT.md`: centered snap + symmetric ~22pt peek confirmed from accessibility frames. |
| 0.2 opacity fade | Pass | While dragging between cards and after settling, compare the focused card with off-center cards. Confirm the focused card is fully opaque and off-center cards consistently fade to about 0.2 without flicker. | Record the cards/positions checked and any opacity or transition discontinuity. `03-02-SUMMARY.md` records the `.scrollTransition` mapping. — C2 in `03-UAT.md`: owner device pass (2026-07-12); binary-step fade accepted as-is (G-03-C2 closed, exact-interpolation parity deliberately dropped). |
| 20pt spacing | Pass | Inspect multiple adjacent cards while stationary and during a drag. Confirm spacing is visually uniform and remains 20pt through ordinary paging and a loop re-center. | Record the device/simulator and any spacing discontinuity. `03-02-SUMMARY.md` records `LazyHStack(spacing: 20)`. — C3 in `03-UAT.md`: adjacent-card gaps measured exactly 20pt both sides from accessibility frames. |
| `pageIndex` synchronization | Pass | Open with card 2 selected (logical index 1), then swipe forward and backward across ordinary positions and both loop boundaries. Confirm the outward `pageIndex` always matches the centered logical card. | Record centered card and outward index before and after each boundary. `03-02-SUMMARY.md` records middle-block seeding plus buffer-id-to-logical-index synchronization. — C4 in `03-UAT.md`: settled buffer%count matched every crossing incl. the 5→0 wrap; owner device pass (2026-07-12). |
| Infinite-loop invisibility | Pass | Repeatedly scroll forward and backward through both wrap boundaries. Watch closely during the tripled-buffer re-center. Confirm continuous ordering with no flash, stutter, jump, duplicate-looking pause, or index discontinuity. | Record at least three wraps in each direction and the device/simulator. This is the highest-risk carousel item; the transaction-suppressed idle re-center is documented in `03-02-SUMMARY.md`. — C5 in `03-UAT.md`: G-03-C5 defect fixed (sliding-window rebase, `scrollPositionID` never written, `.viewAligned(limitBehavior: .always)`); owner re-verified all three symptoms clean on device (2026-07-12). |

## Owner Sign-Off

All rows must be marked before signing.

**Decision: GO / NO-GO:** **GO**

**Owner:** Chihchy (on-device sign-off, iPhone Air / iOS 26.5)

**Date:** 2026-07-12

**D-02 outcome:**

- On `GO`: every row passed; Task 3 may remove SwiftUIPager and its acknowledgements.
- On `NO-GO`: identify every failed row and the device/orientation below. SwiftUIPager is kept, DEP-05 is
  deferred/not viable, and Task 3 is skipped so no half-migration is committed.

**Failed item(s), device/orientation, and observed gap (required for NO-GO):** None — all 16 parity rows passed.

The GO decision was reached over 4 device rounds (2026-07-12); the per-row marks above are transcribed from the
detailed evidence in `03-UAT.md` (`status: passed`, 16/16). Two in-scope findings surfaced during the walk and were
resolved before sign-off: **G-03-C5** (loop re-center visible defect) was fixed via the sliding-window rebase +
`.viewAligned(limitBehavior: .always)` and owner-re-verified clean; **G-03-C2** (binary-step off-center fade) was
closed as accepted behavior with exact-interpolation parity deliberately dropped. On GO, Task 3 removed SwiftUIPager
from `AppPackage/Package.swift`, both `Package.resolved` files, the `AboutView` acknowledgement row, and the
`acknowledgement.swiftUIPager` / `acknowledgement.swiftUIPager_link` xcstrings keys, and pruned the throwaway spike
logging (`ed4621fa`, `a4caa1ef`). DEP-05 is satisfied; the spike is KEEP.
