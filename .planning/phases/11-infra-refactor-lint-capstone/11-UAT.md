---
status: partial
phase: 11-infra-refactor-lint-capstone
source: [11-VERIFICATION.md]
started: 2026-07-21T00:00:00Z
updated: "2026-07-21T13:10:48Z"
---

<!--
verify:pre gate override (2026-07-21): the `api-coverage.verify-pre` gate blocked with
`detected: true, signals: [{verb: "(surface)", noun: "api"}]`. Traced to a single
branch-(b) regex hit on the phrase "the existing Colorful API" in 11-07-PLAN.md:78 —
an internal SwiftUI library's API surface, not an external-API integration. Phase 11
integrates no external API. Confirmed a detector false positive by independent review;
gate treated as overridden so UAT could proceed. Reported upstream against
`gsd-core/bin/lib/api-coverage.cjs` (`SERVICE_SURFACE_API_RE`, no verb required).
-->

## Current Test

[testing paused — 1 item outstanding]

Test 3 (zero-favourites detail parse) remains pending — deferred until a suitable
gallery is found. Suggested route: sort the front page by newest and open a
just-posted gallery, which has zero favourites by construction.

## Tests

### 1. Owner batch review of the 8 lint exceptions (D-01/D-02)

expected: |
  Read `11-EXCEPTIONS.md`. Confirm all 8 phase-created disables are warranted:
  6 `lifecycle_modifiers` (per-page fetch/prefetch, image `.task(id:)` cancellation,
  reader teardown, toast timer, alert focus hop, thumbnail decode) and 2
  `unchecked_subscript_index_access` (PreviewSupport subscript, GalleryHistory op).
  Decide the surfaced option: narrow `lifecycle_modifiers` to exempt `.task(id:)`
  (would remove 3 of the 6). This is a config decision left explicitly to you.
result: pass
decision: "All 8 exceptions accepted as warranted. Surfaced config option declined —
  `lifecycle_modifiers` stays as-is; `.task(id:)` is NOT exempted, so all 6 lifecycle
  disables remain."

### 2. Animated image (GIF / WebP) still renders as animated

expected: |
  11-17 rewrote 14 unchecked byte reads in `AnimatedImageFeature/AnimatedImage+.swift`,
  which has NO test target — correctness rests on argument, not automated coverage.
  Open a gallery whose pages are animated GIFs (or an animated WebP), enter the reader,
  and confirm frames still animate and the first frame is not mis-detected as static.
result: pass

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
result: pass

### 5. GalleryCardCell colour bloom on the Home carousel

expected: |
  11-07 folded the card's colour bloom into `.onChange(of: colors, initial: true)`.
  Scroll the Home carousel and confirm each card's gradient blooms in rather than
  popping abruptly on first appearance.
result: pass

### 6. Tab-reselect and pop-back loads behave

expected: |
  Lifecycle migration changed several loads from view-appearance to presentation.
  Confirm: Favorites/Search re-run their guarded load on tab re-selection without a
  visible double-load; popping back from a Detail push into Downloads still shows the
  right folder contents; returning from the login flow refreshes the account screen's
  login state.
result: pass

### 7. List pagination — fetch-more on scroll to end

expected: |
  Scrolling a gallery list (front page, and presumably every list) to the bottom
  fetches the next page and appends more galleries.
result: issue
reported: "frontpage list (probably all lists) fetch more feature is broken, it just reach the end and won't fetch more"
severity: blocker
found_during: out-of-band observation while testing (not a scripted checkpoint)

### 8. Gallery cell page-count symbol sizing

expected: |
  The page-count indicator symbol in the gallery cell renders at its prior size.
result: issue
reported: "the symbol indicating page count looks larger before it became label — i meant the symbol in gallery cell"
severity: cosmetic
found_during: out-of-band observation while testing (not a scripted checkpoint)

## Summary

total: 8
passed: 5
issues: 2
pending: 1
skipped: 0
blocked: 0

## Gaps

- gap_id: G-11-7
  truth: "Scrolling a gallery list to the end fetches and appends the next page"
  status: failed
  reason: "User reported: frontpage list (probably all lists) fetch more feature is broken, it just reach the end and won't fetch more"
  severity: blocker
  test: 7
  hypothesis: "Phase 11 migrated list lifecycle modifiers off view-appearance (11-07 and
    the lifecycle_modifiers sweep). Infinite scroll is classically driven by an
    .onAppear on the trailing cell; if that trigger was migrated to a presentation-time
    reducer action, the paginate-on-reach-end edge would fire once (or never) instead of
    per-scroll. Prime suspect, to be confirmed by diagnosis."
  artifacts: []
  missing: []

- gap_id: G-11-8
  truth: "The page-count symbol in the gallery cell renders at its prior size"
  status: failed
  reason: "User reported: the symbol indicating page count looks larger before it became label (symbol in gallery cell)"
  severity: cosmetic
  test: 8
  hypothesis: "A page-count view was converted to a Label; the symbol now inherits the
    Label's icon sizing/font metrics rather than its former explicit size. To be
    confirmed by diagnosis."
  artifacts: []
  missing: []
