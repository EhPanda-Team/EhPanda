---
phase: 11-infra-refactor-lint-capstone
plan: 31
subsystem: ui-appearance
gap_ids: [G-11-8]
gap_closure: true
status: complete
tags: [lint, swiftui, label, sf-symbols, appearance-parity, dynamic-type]
requires:
  - "6dd51b00 (the introducing commit, for the pre-sweep baseline)"
  - "label_text_image_shorthand rule at error (drove the conversion this corrects)"
provides:
  - "pre-sweep page-count symbol size in both gallery cell styles"
  - "pre-sweep stat symbol sizes in the torrent row, all four matching"
affects:
  - "Phase 15 (Dynamic Type) — the six icons stay relative-scaled, no frozen glyph handed forward"
tech-stack:
  added: []
  patterns:
    - "Explicit .imageScale inside a Label's icon closure to override a list row's ambient icon inflation"
key-files:
  created: []
  modified:
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
decisions:
  - "The shipped scale is .medium, not the plan's .small default — measured, not assumed"
  - "The regression is list-specific: a free-standing Label icon already matches a bare Image exactly"
  - "The parity snapshot harness was removed rather than shipped with a deprecation warning"
metrics:
  duration: ~50 min
  tasks: 2
  files: 3
  completed: 2026-07-22
---

# Phase 11 Plan 31: Page-Count Symbol Size (G-11-8) Summary

All six converted `Label` sites now carry `.imageScale(.medium)` inside their icon closure, which
cancels the list row's icon inflation and restores the exact pre-`6dd51b00` glyph — measured at
16.25 x 13.25 pt against the unfixed 21.0 x 17.25 pt.

## What shipped

| Site | Change |
|------|--------|
| `GalleryThumbnailCell` page count | shorthand -> icon-closure form + `.imageScale(.medium)` |
| `GalleryDetailCell` page count | shorthand -> icon-closure form + `.imageScale(.medium)` |
| `TorrentsView` seed / peer / download | `.imageScale(.medium)` added to the existing icon closures |
| `TorrentsView` file size | shorthand -> icon-closure form + `.imageScale(.medium)`, trailing frame preserved |

Spacing (2 and 3), line limits, fonts, foreground styles, minimum scale factors, the
trailing-aligned frame and both download-badge branches are byte-for-byte unchanged. Titles keep
their non-localizing string semantics (`Text(gallery.pageCount.description)`, `Text(torrent.fileSize)`).

## The A/B: what was actually observed

The plan called the `.small` vs `.medium` choice genuinely open and required a visual comparison
against `6dd51b00^`. Rather than eyeball it, the comparison was rendered and the glyph's inked
bounding box measured in points, with the baseline row repeated between candidates as a
self-check (all baseline measurements came back identical).

**Free-standing (no list), whole-element render:**

| Form | Size |
|------|------|
| baseline `HStack { Image; Text }` | 53.0 x 16.0 |
| `Label`, no explicit scale | 53.0 x 18.0 |
| bare `Image` glyph | 20.0 x 16.0 |
| `Label` icon glyph, no explicit scale | 20.0 x 16.0 |

**Inside a real `List` row, leading glyph only:**

| Form | Glyph | Verdict |
|------|-------|---------|
| baseline (pre-sweep bare `Image`) | 16.25 x 13.25 | the target |
| `Label`, no explicit scale | 21.0 x 17.25 | ~29% wider — the reported regression |
| `.imageScale(.small)` | 13.0 x 10.75 | undershoots by 3.25 pt (~20% too small) |
| **`.imageScale(.medium)`** | **16.25 x 13.5** | **matches, within antialiasing noise** |

**The winner is `.medium`, and it won by measurement.** The plan's written starting point —
`.small`, the repo precedent at `ListNoticeView` and `SearchRootView+Keywords` — was tried and
rejected: it makes the symbol visibly *smaller* than it ever was, trading one appearance
regression for another. A rendered A/B of `.small` against the baseline was also inspected
visually and confirms the numbers.

`.medium` is nominally the default image scale, so each call site carries a comment explaining that
it is deliberately not a no-op: it overrides the ambient inflation the list applies to a
`titleAndIcon` label's icon.

## Correction to the recorded diagnosis

`.planning/debug/g-11-8-page-count-symbol-size.md` attributes the growth to `Label`'s
`titleAndIcon` style sizing its icon from the label's own font and line metrics. **Measurement
does not support that.** Free-standing, a `Label`'s icon renders at 20.0 x 16.0 — pixel-identical
to the bare `Image` it replaced, at the same `.footnote` font. The only free-standing difference is
2 pt of extra row height, which is the label reserving vertical space, not a bigger glyph.

The inflation is **list-specific**: it appears only once the label is inside a `List` row. This
matters for two reasons:

1. It explains why `.medium` looked like a no-op in isolation and is in fact the exact fix in
   context. Anyone re-deriving this outside a list will reach the wrong conclusion.
2. It briefly looked like the thumbnail cell was unaffected (it renders in a masonry grid, not a
   list). That was checked, not assumed: `GalleryList.ThumbnailList` puts the whole `MasonryLayout`
   inside a single eager `List` row, so the thumbnail cell inflates too. The plan's premise that all
   six sites share one mechanism and one value holds — for a different reason than recorded.

The debug document's root-cause paragraph should be corrected if it is used again.

## Deviations from Plan

**1. [Rule 1 - Bug] The plan's default scale value was wrong and was not used**

- **Found during:** Task 1's A/B
- **Issue:** The plan instructed starting from `.small` and stepping up only if it undershot. It
  undershoots by 3.25 pt.
- **Fix:** Shipped `.medium` at all six sites. The Task 2 gate (exactly 6 applications, exactly 1
  distinct value) was left untouched and passes on `.medium`.
- **Commits:** `01b79ff7`, `66f08295`

**2. [Rule 3 - Blocking] A parity snapshot harness was built, then removed**

- **Found during:** Task 1 (both tasks carry `tdd="true"`)
- **Issue:** A test that renders the comparison and measures glyph ink bounds is the only way to
  assert this behavior. It requires hosting a `List` in a `UIWindow` — `ImageRenderer` cannot
  rasterize a `List` and draws an unsupported-content placeholder instead. Every `UIWindow`
  initializer that works without a window scene (`init()`, `init(frame:)`) is deprecated on
  iOS 26, and the test host exposes no connected `UIWindowScene`, so `init(windowScene:)` is
  unreachable. Polling ten seconds for a scene returned none.
- **Fix:** The harness did its job as an investigation instrument — every number above came from it,
  and it was RED/GREEN-verified (it fails on `.small` by 3.25 pt width / 2.75 pt height and passes
  on `.medium`). It was then removed rather than shipped, because the only way to keep it was to
  leave a deprecation warning in the build, which project policy forbids. The `SFSafeSymbols`
  dependency added to the test target for it was reverted with it.
- **Commit:** `5c58d3e2`
- **Consequence:** This plan ships no automated regression test. The protection that remains is the
  grep gate (six applications, one value) plus the owner's visual check.

**3. [Rule 2 - Missing] Each corrected site carries an explanatory comment**

`.imageScale(.medium)` reads as a no-op to anyone who does not know about the list inflation, and a
future cleanup pass would delete it. A short comment at each of the three files records the measured
~29% inflation and states the modifier is load-bearing.

## Lint bar

- `xcodebuild build -scheme EhPanda` succeeds with **zero errors and zero warnings**
- **Zero** `swiftlint:disable` introduced, in any form
- `.swiftlint.yml` **untouched** — no rule edit, no severity change
- No site reverted to a hand-composed icon-plus-text stack; `label_text_image_shorthand` stays
  satisfied structurally (the icon `Image` is followed by `.imageScale`, not by `}`), verified by
  building under the plugin at error rather than by reading the regex
- Zero absolute point sizes (`system(size:`) across all three files — the scale stays relative

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface; this is an icon-metric change only.
T-11-36's mitigation holds — every line limit and minimum-scale-factor modifier is unchanged, so a
hostile server-supplied count or file-size string still truncates or shrinks rather than breaking
the row.

## Requires the owner's device check

Three things could not be settled headlessly and are stated plainly rather than claimed:

1. **Dynamic Type across the accessibility range.** The structural guarantee holds — the scale is
   relative and there is no absolute point size anywhere in the three files (gate-verified), so the
   glyph tracks `.footnote`. The empirical check at an accessibility content size was attempted but
   the measurement fixture could not fit four rows at AX3 in the render frame, and the harness was
   removed before that was resolved. **Not empirically confirmed.**
2. **The Torrents sheet in the running app** — that the four stat symbols match each other and the
   pre-sweep baseline, at default and raised content sizes.
3. **The download-badge branch** of both cells, which is untouched by this change but shares the row.

The measurements above were taken on an iPhone Air simulator at `.footnote`. Re-deriving them
requires rendering inside a `List`; a free-standing preview will show no difference at all and is
not a valid check.

## Self-Check: PASSED

- `AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift` — FOUND, 1 `imageScale`
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift` — FOUND, 1 `imageScale`
- `AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift` — FOUND, 4 `imageScale`
- Across the three files: 6 applications, 1 distinct value (`imageScale(.medium)`) — gate PASS
- Commits `01b79ff7`, `66f08295`, `5c58d3e2` — all FOUND in `git log`
