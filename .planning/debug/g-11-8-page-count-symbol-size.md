---
status: diagnosed
trigger: "the symbol indicating page count looks larger before it became label — i meant the symbol in gallery cell"
created: 2026-07-21T00:00:00Z
updated: 2026-07-21T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — commit 6dd51b00 replaced `HStack(spacing: 2) { Image(systemSymbol:); Text(...) }`
  with `Label(...).labelIconToTitleSpacing(2)`. Font is unchanged (.footnote in both), so the icon's
  growth is attributable solely to Label's titleAndIcon style sizing the icon from label/title font
  metrics instead of rendering a bare Image at the ambient font's default (.medium) symbol scale.
test: git show 6dd51b00 on both cells — diff isolates the change (no font modifier moved or altered)
expecting: confirmed
next_action: diagnosis-only mode — report; do NOT apply changes

## Symptoms

expected: page-count SF Symbol in gallery cell renders at its prior (smaller) size
actual: symbol renders larger after Label conversion
errors: none (cosmetic/visual)
reproduction: view a gallery list cell showing page count (both list + masonry thumbnail modes)
started: commit 6dd51b00 "Overall UI adjustments" (Sat Jul 18 2026), part of the phase-11 sweep

## Eliminated

- hypothesis: The SFSafeSymbolsExt `Label(_:systemSymbol:)` shim applies its own sizing
  evidence: SFSafeSymbols+LocalizedStringResource.swift composes `Text` + `Image(systemSymbol:)`
    verbatim with no font/imageScale modifiers. Sizing cannot originate there.
  timestamp: 2026-07-21

- hypothesis: A `.font(...)` modifier was dropped or moved during the conversion
  evidence: git show 6dd51b00 — GalleryThumbnailCell keeps `.font(.footnote)` on the enclosing
    HStack (unchanged); GalleryDetailCell keeps `.font(.footnote)` directly on the view. Neither
    old nor new code ever set a font on the Image itself. Font is a constant across the change.
  timestamp: 2026-07-21

- hypothesis: A global `.labelStyle(...)` change altered icon rendering
  evidence: all 20 `labelStyle(` call sites are local `.iconOnly` on buttons/toolbars; no ambient
    labelStyle is injected above the gallery cells.
  timestamp: 2026-07-21

- hypothesis: DetailView+HeaderSection Label conversions are part of the same regression
  evidence: those sites carry `.labelStyle(.iconOnly)` + explicit `.font(actionIconFont)`, so the
    icon size is pinned by an explicit font — not inherited. Not affected.
  timestamp: 2026-07-21

## Evidence

- checked: grep for pageCount + SF Symbol across AppPackage/Sources
  found: two Label call sites — GalleryThumbnailCell.swift:82, GalleryDetailCell.swift:133,
    both `Label(gallery.pageCount.description, systemSymbol: .photoOnRectangleAngled)`
  implication: both gallery cell styles are affected, not just the one the user saw

- checked: git log -S "labelIconToTitleSpacing"
  found: single introducing commit 6dd51b00 "Overall UI adjustments"
  implication: one sweep introduced every Label conversion; blast radius is that commit

- checked: git show 6dd51b00 on both cells
  found: exact conversion `HStack(spacing: 2) { Image(systemSymbol:); Text(String(pageCount)) }`
    -> `Label(pageCount.description, systemSymbol:).labelIconToTitleSpacing(2)`
  implication: root cause confirmed; spacing was preserved (2), only glyph metric changed

- checked: awk scan of the full sweep diff for removed inline `HStack(spacing:)` icon+text groups
  found: 6 inline conversions total — GalleryThumbnailCell (1), GalleryDetailCell (1),
    TorrentsView (4: arrowUpCircle, arrowDownCircle, checkmarkCircle, documentCircle)
  implication: TorrentsView stat row is a sibling regression with identical mechanism

- checked: existing in-repo Label icon sizing precedent
  found: ListNoticeView.swift:22 scales the icon INSIDE the `icon:` closure
    (`Image(systemSymbol: .infoCircle).imageScale(.small)`); SearchRootView+Keywords.swift:124
    applies `.imageScale(.small)` on the Label itself
  implication: project already has an established, lint-legal compensation pattern to reuse

- checked: .swiftlint.yml custom rule `label_text_image_shorthand` (severity: error)
  found: regex requires `Image(systemSymbol: ...)` immediately followed by `}` to match; adding
    `.imageScale(...)` to the Image breaks the match
  implication: the fix must NOT revert to HStack (rule drove the sweep), and the icon-closure form
    with a modifier is lint-legal — ListNoticeView already proves this

- checked: AppPackage/Package.swift
  found: platforms: [.iOS(.v26)]
  implication: labelIconToTitleSpacing / labelReservedIconWidth are available; no back-compat gate

## Resolution

root_cause: Commit 6dd51b00 converted the page-count indicator from a hand-composed
  `HStack { Image(systemSymbol:); Text }` to a SwiftUI `Label`. The bare `Image` rendered at the
  ambient `.footnote` font's default symbol scale; the `Label`'s default titleAndIcon style sizes
  its icon from the label's own font/line metrics, producing a visibly larger glyph at the same
  font. No explicit `.imageScale`/`.font` was ever set on the icon, so nothing constrains it.
fix: (diagnosis only — not applied) reassert explicit relative icon scale on the affected Labels
verification: pending
files_changed: []
