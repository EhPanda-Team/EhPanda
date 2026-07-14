---
status: testing
phase: 08-architecture-hygiene-client-seams
source: [08-VERIFICATION.md]
started: 2026-07-14T13:08:05Z
updated: 2026-07-14T13:08:05Z
---

# Phase 8: Architecture Hygiene & Client Seams — Human Verification

All automated checks pass (14/16 truths verified; all four verification gaps closed with no regressions). The remaining 2 items exercise **rendered control state** and **physical haptic output**, which source inspection and the client-test suite cannot observe — they require a physical device.

## Current Test

number: 1
name: Login-gated control visibility/enabled parity (12 migrated controls)
expected: |
  In both logged-in and logged-out states, the download, archive, comment,
  rating/tag-vote, favorite, watched, and account controls keep the same
  visibility and enabled/disabled state they had before CookieUtil was removed.
awaiting: user response

## Tests

### 1. Login-gated control visibility/enabled parity (12 migrated controls)
expected: Exercise logged-in and logged-out states across the download, archive, comment, rating/tag-vote, favorite, watched, and account controls. Each control has the same visibility and enabled/disabled state as before CookieUtil was removed (the `didLogin` predicate is now read through the injected CookieClient).
result: [pending]

### 2. Migrated haptic feedback parity (4 interactions)
expected: On physical hardware, trigger the excluded-language, category-filter, reload, and archive-selection interactions. Each fires the same haptic feedback type at the same time as the former HapticsUtil path (haptics now route through the injected HapticsClient).
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
