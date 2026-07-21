---
status: testing
phase: 11-infra-refactor-lint-capstone
source: [11-VERIFICATION.md]
started: 2026-07-21T00:00:00Z
updated: 2026-07-21T00:00:00Z
---

## Current Test

number: 1
name: Owner batch review of the 8 lint exceptions
expected: |
  Every phase-created `// swiftlint:disable` is intentional and correctly scoped.
awaiting: user response

## Tests

### 1. Owner batch review of the 8 lint exceptions (D-01/D-02)
expected: |
  Read `11-EXCEPTIONS.md`. Confirm all 8 phase-created disables are warranted:
  6 `lifecycle_modifiers` (per-page fetch/prefetch, image `.task(id:)` cancellation,
  reader teardown, toast timer, alert focus hop, thumbnail decode) and 2
  `unchecked_subscript_index_access` (PreviewSupport subscript, GalleryHistory op).
  Decide the surfaced option: narrow `lifecycle_modifiers` to exempt `.task(id:)`
  (would remove 3 of the 6). This is a config decision left explicitly to you.
result: [pending]

### 2. Animated image (GIF / WebP) still renders as animated
expected: |
  11-17 rewrote 14 unchecked byte reads in `AnimatedImageFeature/AnimatedImage+.swift`,
  which has NO test target — correctness rests on argument, not automated coverage.
  Open a gallery whose pages are animated GIFs (or an animated WebP), enter the reader,
  and confirm frames still animate and the first frame is not mis-detected as static.
result: [pending]

### 3. Detail page for a gallery with zero favourites parses
expected: |
  `parseInfoPanel`'s all-eight-fields-non-empty contract rejects the whole detail
  parse rather than degrading one field. Open the detail page of a gallery with
  zero favourites and confirm it loads (title, tags, rating, favourite count = 0)
  rather than failing to parse.
result: [pending]

### 4. Reader opens on the saved page in LTR and RTL, slider works
expected: |
  11-09 migrated reader scroll seeding into an `.onChange(initial: true)`. Open a
  part-read gallery in a left-to-right reading direction, confirm it opens on the
  saved page; repeat in right-to-left; then drag the page slider and confirm the
  preview tray thumbnails populate on first reveal and keep filling as you drag.
result: [pending]

### 5. GalleryCardCell colour bloom on the Home carousel
expected: |
  11-07 folded the card's colour bloom into `.onChange(of: colors, initial: true)`.
  Scroll the Home carousel and confirm each card's gradient blooms in rather than
  popping abruptly on first appearance.
result: [pending]

### 6. Tab-reselect and pop-back loads behave
expected: |
  Lifecycle migration changed several loads from view-appearance to presentation.
  Confirm: Favorites/Search re-run their guarded load on tab re-selection without a
  visible double-load; popping back from a Detail push into Downloads still shows the
  right folder contents; returning from the login flow refreshes the account screen's
  login state.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
