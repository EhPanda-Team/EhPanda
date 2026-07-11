# Phase 03 D-11 Go/No-Go Checklist

This checklist is the D-02 all-or-nothing gate for removing SwiftUIPager. Walk every row on a physical device and
on iOS 26 simulators in portrait and landscape where applicable. In the **Pass / Gap (owner)** column, enter exactly
`Pass` or `Gap` and record observed evidence or failure details. A `Gap` in any row makes the decision `NO-GO`.

The implementation under review is the committed native reader and carousel spike from Plans 03-02 through
03-04. SwiftUIPager remains declared until this checklist is complete and the owner records `GO`.

## Reader

| D-10 parity item | Pass / Gap (owner) | How to verify | Evidence to check or record |
|---|---|---|---|
| Horizontal paging |  | Use `.leftToRight` in portrait. Swipe several pages in both directions and stop after partial drags. Confirm every release snaps to exactly one full-width page and the displayed progress/index follows the visible page. | Record device/simulator and page numbers tested. The native paging structure is documented in `03-03-SUMMARY.md`. |
| RTL direction and logical index |  | Switch to `.rightToLeft`. Swipe in both directions and use a seek action. Confirm the paging axis reverses, the requested logical page still lands correctly, and progress/index matches the visible page. | Record requested and visible page numbers. `PageHandlerTests` verifies that mapping stays direction-agnostic; `03-03-SUMMARY.md` records the axis-only `layoutDirection` flip. |
| Dual-page landscape paging and snap |  | Enable dual-page mode, rotate to landscape, and swipe across multiple stacks. Confirm every gesture settles on one complete spread with no half-way offset, skipped stack, or drift. Repeat near the first and last stacks. | Record device/simulator, orientation, and stacks tested. Explicitly note whether the `.paging` landscape FB16486510 misalignment appeared. |
| RTL × dual-page landscape spread order |  | With dual-page mode on, landscape orientation, and `.rightToLeft`, swipe across several spreads. Confirm the paging axis runs right-to-left **and the earlier page appears on the RIGHT** in every spread. | Record at least two visible page pairs and their left/right order. An earlier page on the left is a genuine gap: the `layoutDirection` flip double-reversed the `imageContainerConfigs` swap (03-REVIEWS HIGH). |
| PageHandler index mapping, including dual-page cover math |  | Compare visible pages with slider/progress in single-page, ordinary dual-page, and dual-page-with-cover modes. Check the first spread, a middle spread, and the final boundary; seeking a reading page must show the expected stack and returning from that stack must report the expected reading page. | Record the checked page/stack pairs. Automated guard: `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` (8 tests / 58 cases) and `ContainerDataSourceTests.swift` (4 tests / 13 cases), summarized in `03-01-SUMMARY.md`. |
| Slider seek |  | Drag the slider to the first, middle, penultimate, and final valid positions in single- and dual-page modes. Confirm each animated jump is smooth, lands exactly once, and has no flash, glitch, or off-by-one result. | For every sample, record slider target, visible page/stack, and the `jump requested:` / `landed:` values. Requested and landed ids must match. |
| Autoplay `.next` |  | Start autoplay in single- and dual-page modes and observe several advances, including the final valid stack. Confirm each advance is smooth, moves exactly once, and clamps at the end without an off-by-one or feedback jump. | Record visible transitions and matching `jump requested:` / `landed:` log pairs from the settle-time instrumentation described in `03-04-SUMMARY.md`. |
| Tap-to-turn |  | At scale 1, tap both page-turn edge regions in LTR and RTL. Confirm each tap moves exactly one logical page/stack in the direction indicated by the reading mode, with no duplicate or reversed turn. | Record direction, tapped edge, starting page, resulting page, and matching requested/landed log ids. |
| Resume-page seed |  | Leave the reader on a non-initial page, close it, and reopen the same gallery in single- and dual-page modes. Confirm the correct saved page/stack is visible immediately, without first showing another page or performing a corrective jump. | Record saved reading page, expected pager index, and first visible page/stack. `03-03-SUMMARY.md` records construction-time seeding of both `PageModel` and `scrollPositionID`. |
| Zoom, pan, and tap coexistence |  | Zoom above scale 1, then swipe horizontally: paging must stay frozen. Pan the zoomed image: the image must move normally. Return to scale 1 and, in RTL, tap each edge: the correct page-turn direction must be preserved. Tap the center and confirm the reader panel toggles. | Record all four observations: paging frozen while zoomed, pan works, RTL edge taps turn correctly, and center tap toggles the panel. Wiring evidence is summarized in `03-04-SUMMARY.md`; touch behavior requires this manual check. |
| Vertical `AdvancedList` shared-index seam |  | Select a vertical reading direction, scroll through several pages, use the slider, allow autoplay to advance, and reopen on a saved page. Confirm the visible page, progress, seek target, autoplay result, and resume page all share the same logical index with no ±1 regression. | Record the pages exercised and any requested/visible mismatch. `03-03-SUMMARY.md` records the byte-for-byte `AdvancedList` re-seam from `Page` to `PageModel`. |

## Carousel

| D-10 parity item | Pass / Gap (owner) | How to verify | Evidence to check or record |
|---|---|---|---|
| Centered snap and symmetric peek |  | Open Home with at least three cards. Swipe one card at a time and stop after partial drags. Confirm the settled card is centered and equal portions of the neighboring cards peek on both sides. | Record device/simulator and whether left/right peek widths appear symmetric. `03-02-SUMMARY.md` records `contentMargins` centering with native `.viewAligned` paging. |
| 0.2 opacity fade |  | While dragging between cards and after settling, compare the focused card with off-center cards. Confirm the focused card is fully opaque and off-center cards consistently fade to about 0.2 without flicker. | Record the cards/positions checked and any opacity or transition discontinuity. `03-02-SUMMARY.md` records the `.scrollTransition` mapping. |
| 20pt spacing |  | Inspect multiple adjacent cards while stationary and during a drag. Confirm spacing is visually uniform and remains 20pt through ordinary paging and a loop re-center. | Record the device/simulator and any spacing discontinuity. `03-02-SUMMARY.md` records `LazyHStack(spacing: 20)`. |
| `pageIndex` synchronization |  | Open with card 2 selected (logical index 1), then swipe forward and backward across ordinary positions and both loop boundaries. Confirm the outward `pageIndex` always matches the centered logical card. | Record centered card and outward index before and after each boundary. `03-02-SUMMARY.md` records middle-block seeding plus buffer-id-to-logical-index synchronization. |
| Infinite-loop invisibility |  | Repeatedly scroll forward and backward through both wrap boundaries. Watch closely during the tripled-buffer re-center. Confirm continuous ordering with no flash, stutter, jump, duplicate-looking pause, or index discontinuity. | Record at least three wraps in each direction and the device/simulator. This is the highest-risk carousel item; the transaction-suppressed idle re-center is documented in `03-02-SUMMARY.md`. |

## Owner Sign-Off

All rows must be marked before signing.

**Decision: GO / NO-GO:**

**Owner:**

**Date:**

**D-02 outcome:**

- On `GO`: every row passed; Task 3 may remove SwiftUIPager and its acknowledgements.
- On `NO-GO`: identify every failed row and the device/orientation below. SwiftUIPager is kept, DEP-05 is
  deferred/not viable, and Task 3 is skipped so no half-migration is committed.

**Failed item(s), device/orientation, and observed gap (required for NO-GO):**
