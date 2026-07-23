---
status: complete
phase: 13-deep-link-hardening-code-review-the-current-deep-link-implem
source: [13-01-SUMMARY.md, 13-02-SUMMARY.md, 13-03-SUMMARY.md, 13-04-SUMMARY.md, 13-05-SUMMARY.md, 13-06-SUMMARY.md, 13-07-SUMMARY.md, 13-08-SUMMARY.md, 13-09-SUMMARY.md, 13-10-SUMMARY.md]
started: 2026-07-23T11:59:00Z
updated: 2026-07-23T12:12:45Z
---

## Current Test

[testing complete]

## Tests

### 1. GalleryURLParser normalizes and rejects
expected: GalleryURLParser safely normalizes and parses supported gallery links while rejecting spoofed or malformed input.
result: pass
source: automated
coverage_id: 13-01-D1

### 2. AppToolsTests in default plan
expected: The new AppToolsTests target executes in the default FeatureTests plan with exhaustive parser and MPV coverage.
result: pass
source: automated
coverage_id: 13-01-D2

### 3. Unsupported deep-link error vocabulary
expected: Unsupported deep links have distinct non-retryable localized error and recovery vocabulary.
result: pass
source: automated
coverage_id: 13-02-D1

### 4. Unsupported-link context sanitization
expected: Unsupported-link context identifies the route without retaining access-bearing URL components.
result: pass
source: automated
coverage_id: 13-02-D2

### 5. URLClient consumers routed through GalleryURLParser
expected: Every former URLClient consumer routes through GalleryURLParser while preserving existing destination, fallback, timing, and MPV behavior.
result: pass
source: automated
coverage_id: 13-03-D1

### 6. URLClient fully removed
expected: The URLClient source directory, target, package dependencies, imports, and test overrides are fully removed.
result: pass
source: automated
coverage_id: 13-03-D2

### 7. Explicit vs clipboard unsupported opens
expected: Explicit unsupported opens surface a sanitized persistent error while unsupported clipboard URLs remain silent and recognized clipboard URLs still route.
result: pass
source: automated
coverage_id: 13-04-D1

### 8. ShareExtension scheme-only rewrite
expected: ShareExtension changes only the URL scheme, preserving host, path, query, and fragment even when the query embeds another scheme string.
result: pass
source: automated
coverage_id: 13-04-D2

### 9. Modal replacement awaits dismissal
expected: Modal replacement waits for actual sheet dismissal completion while gallery fetching continues concurrently.
result: pass
source: automated
coverage_id: 13-05-D1

### 10. Deterministic modal coordination orderings
expected: Both completion orderings, ordinary user dismissal, direct presentation, and latest fetched replacement behavior are deterministic under TestStore.
result: pass
source: automated
coverage_id: 13-05-D2

### 11. Toast overlay animates identity changes
expected: The toast overlay animates every presented-toast identity change while retaining its id-keyed dismissal timer.
result: pass
source: automated
coverage_id: 13-06-D1

### 12. Loading toast replaced without sleeps
expected: PresentationFeature and CommentsReducer replace loading toasts with error toasts directly, with no 500ms routing-path sleeps or follow-up actions.
result: pass
source: automated
coverage_id: 13-06-D2

### 13. Hermetic fixture route coverage
expected: Fixture responses hermetically cover gallery, alternate gallery, single-page, front-page, and unmatched routes without network fallback.
result: pass
source: automated
coverage_id: 13-07-D1

### 14. Opt-in launch environment resolution
expected: Launch environment resolution is opt-in and supplies deterministic network and clipboard overrides while preserving live clipboard writes.
result: pass
source: automated
coverage_id: 13-07-D2

### 15. Deep-link accessibility identifiers on every destination
expected: Every deep-link destination exposes its planned locale-independent accessibility identifier without changing labels, values, or traits.
result: pass
note: "Verified from the 13-07 diff: +7 insertions, 0 deletions — no label, value, or trait changed. Identifier naming is tracked as a deferred follow-up."
coverage_id: 13-07-D3

### 16. UI-test target, retrying plan, fixtures
expected: EhPanda has a buildable UI-test target, a second non-default retrying test plan, lint coverage, and four runner-owned fixtures.
result: pass
source: automated
coverage_id: 13-08-D1

### 17. Cold gallery deep link reaches detail_view
expected: A cold ehpanda:// gallery open reaches detail_view and renders the bundled marker through the real app routing seam.
result: pass
source: automated
coverage_id: 13-08-D2

### 18. Default scheme stays unit-only
expected: The ordinary scheme invocation remains unit-only and green after adding the UI target.
result: pass
source: automated
coverage_id: 13-08-D3

### 19. Route matrix across cold and warm lifecycles
expected: Gallery, single-page, and comment ehpanda:// routes reach their locked destinations in both cold-launch and warm-foreground lifecycles.
result: pass
source: automated
coverage_id: 13-09-D1

### 20. Malformed routes show persistent toast
expected: Malformed ehpanda:// routes keep the app foregrounded, show the persistent unsupported-link toast, avoid detail presentation, and open ErrorInfoView when tapped in both lifecycles.
result: pass
source: automated
coverage_id: 13-09-D2

### 21. Scheme matrix preserves unit suite and lint
expected: The new scheme matrix preserves the default unit suite, strict lint, and simulator build.
result: pass
source: automated
coverage_id: 13-09-D3

### 22. Clipboard and comment-link entry paths
expected: The clipboard entry lands on detail from a cold launch without touching the real pasteboard, and a gallery link inside a comment pushes the linked gallery's detail.
result: pass
source: automated
coverage_id: 13-10-D1

### 23. Safari share-sheet hand-off
expected: Sharing a gallery link from Safari through the real share sheet and the real extension foregrounds the app on the linked gallery's detail.
result: pass
source: automated
coverage_id: 13-10-D2

### 24. iPad tab modal replaced by deep link
expected: Tapping a gallery from a tab on iPad presents the modal detail, and a deep link arriving over it replaces it with the linked gallery.
result: pass
source: automated
coverage_id: 13-10-D3

### 25. Green exit evidence across all plans
expected: The phase's automated exit evidence is green across the unit plan, the complete UI plan on iPhone, and the iPad class on iPad.
result: pass
source: automated
coverage_id: 13-10-D4

## Summary

total: 25
passed: 25
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]

## Deferred Follow-Ups

- test: 15
  idea: "all hard-coded strings? no, give them something like AccessibilityIdentifiers.readingView — the accessibility identifiers must be grouped into one shared constants file instead of being re-typed as literals on both sides (7 literals in AppPackage/Sources, 18 literal call sites across 5 EhPandaUITests files, no compile-time link between them)."
  deferred_at: 2026-07-23
