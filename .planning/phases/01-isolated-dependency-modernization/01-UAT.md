---
status: testing
phase: 01-isolated-dependency-modernization
source: [01-VERIFICATION.md]
started: 2026-07-10T13:30:00Z
updated: 2026-07-10T13:30:00Z
---

## Current Test

number: 1
name: Colorful animated gradient visual parity (D-19)
expected: |
  On Home, focus a gallery card in dark and light mode; the soft blurred multicolor
  animated ColorfulView gradient and the gray fallback render as before the phase
  (Colorful 1.1.1 vs the prior pin) — no visual regression from the update.
awaiting: user response

## Tests

### 1. Colorful animated gradient visual parity (D-19)
expected: On Home, focus a gallery card in dark and light mode; confirm the soft blurred multicolor animated `ColorfulView` gradient and the gray fallback render as before the phase (Colorful 1.1.1 vs the prior pin), per `01-COLORFUL-UAT.md`. Animated-gradient concept and fallback colors match the pre-phase behavior closely enough; no visual regression.
result: [pending]

### 2. Real-world domain-fronting / SNI behavior (D-15) — informational
expected: Informational only for this phase — the tree retains `DeprecatedAPI` via the approved `document-skip` decision, so domain-fronting behavior is unchanged and no new China/SNI verification is owed. This item becomes a required UAT only if a non-deprecated DF replacement is ever adopted (a future phase), at which point an in-region tester under China/SNI-filtering conditions must confirm gallery/image loading still works. Mark as skipped / N-A for Phase 1.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
