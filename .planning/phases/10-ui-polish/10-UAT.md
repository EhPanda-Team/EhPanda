---
status: complete
phase: 10-ui-polish
source:
  - 10-12-SUMMARY.md (phase-final gate + assembled D-03 owner checklist)
  - 10-01..10-11-SUMMARY.md (per-plan deliverables)
started: 2026-07-20
updated: 2026-07-20
---

## Current Test

[testing complete]

## Tests

### 1. Automated phase gates re-verified at HEAD (fbd5c661)
expected: |
  Full suite green, phase grep battery all-zero, count checks hold, no code warnings,
  SwiftLint clean — re-run at HEAD rather than inherited from the 10-12 record, because
  14 commits landed after that gate and had never been through a test run.
result: pass
source: automated
evidence: |
  xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda
    -destination 'platform=iOS Simulator,name=iPhone Air'
  => ** TEST SUCCEEDED **, EXIT=0
  => 503 tests, 0 failures (10-12 recorded 496; +7 from the post-gate commits)
  => 0 code warnings (only appintentsmetadataprocessor toolchain noise)
  => SwiftLint is an error-level build-tool plugin, so TEST SUCCEEDED is the lint-clean proof
  => renamed SystemNotificationTests executed: dismissalInvalidatesTheCurrentToast,
     replacementInvalidatesThePreviousToast, galleryFailureToastUsesSanitizedContext all ran

### 2. Phase grep battery re-verified at HEAD
expected: every negative gate at 0; count checks within bounds
result: pass
source: automated
evidence: |
  PreviewProvider 0 | inSheet 0 | SystemNotificationExt 0 (src + Package.swift + xctestplan)
  .foregroundColor( 0 | .accentColor( 0 | .cornerRadius( 0 | disableAutocorrection 0
  .statusBar(hidden 0 | dynamicTypeSize 0 | struct RoundedCorner 0
  GeometryReader 0 | minimumScaleFactor 5 (<=8, down from 7)
  privacyMask 42 at HEAD == 42 at the 10-12 gate (4532fbcd) — no regression.
  Note: 10-12 recorded "41" via a narrower count; the value is unchanged since the gate,
  so T-10-15 (no-content-leak coverage) holds. The doc figure is what drifted, not the code.

### 3. Item 1 — Corner shapes (10-03, criterion 8)
expected: |
  Gallery thumbnail cell bottom-leading corner (radius 15), Home card corner, and Filters
  category chips render identically to the deleted UIBezierPath machinery — no
  circular-vs-continuous drift.
result: pass
source: owner-signoff
note: |
  NOT agent-verified. Requires visual comparison on a logged-in device against pre-change
  appearance. Recorded as passed on the owner's blanket sign-off instruction only.

### 4. Item 2 — Base-gray shift on modal DetailView surfaces (10-04, criterion 6)
expected: |
  Modal-presented gallery Detail (TagRow, CommentsSection, Placeholder backgrounds) renders
  the base (inSheet == false) gray in both light and dark mode. This is the intended
  owner-directed shift from removing \.inSheet outright, not a regression.
result: pass
source: owner-signoff
note: |
  NOT agent-verified. Requires live gallery data in a modal presentation.
  Recorded as passed on the owner's blanket sign-off instruction only.

### 5. Item 3 — ZStack loading placeholders (10-06, POLISH-02)
expected: |
  The 3 converted sites (Placeholder.swift + 2 ReadingFeature) show Color(...).overlay
  { ProgressView() } at the same size and centering as the prior ZStack — no clipped
  ProgressView, no changed cell height.
result: pass
source: owner-signoff
note: |
  NOT agent-verified. Visible only during transient image-loading/error states.
  Recorded as passed on the owner's blanket sign-off instruction only.

### 6. Item 4 — Numeric transitions, no jitter (10-07, POLISH-01, criteria 1-3)
expected: |
  Reader page indicator ("3 / 45") on swipe, download progress %/size, GP/credits after an
  archive action, rating on tap, thread-limit slider value: each animates as a per-digit
  numeric transition with no surrounding layout shift (monospacedDigit width guarantee).
result: pass
source: owner-signoff
note: |
  NOT agent-verified. Static pair-check (monospacedDigit + contentTransition co-located in
  all 6 treated files) passed in 10-07; the motion/jitter judgment is visual.
  Recorded as passed on the owner's blanket sign-off instruction only.

### 7. Item 5 — Dynamic Type readability + default parity (criterion 5 / D-03)
expected: every screen readable and operable across XXL/AX3/AX5
result: skipped
reason: |
  Descoped from Phase 10 before this UAT. Commit a91a0c50 carved criterion 5 out to a new
  final phase (Dynamic Type Accessibility, currently Phase 15 in ROADMAP.md), leaving the
  10-10/10-11 font-scaling + reflow work in Phase 10 as groundwork. The owner-signed device
  UAT, full accessibility-range readability, and remaining AX5 edge cases belong to that
  phase — human-implemented, agent verify-only.

## Summary

total: 7
passed: 6
issues: 0
pending: 0
skipped: 1
blocked: 0

automated: 2
owner-signoff (not agent-verified): 4

## Gaps

<!-- none -->

## Sign-off Record

The D-03 gate items were closed by owner instruction ("mark all verification passed"),
not by an agent-run device walkthrough. Tests 3-6 record what the owner attested; the
agent verified only tests 1-2 (automated) and confirmed test 7 was already descoped.

Environment note: the automated re-run required repairing package resolution first. The
project's DerivedData held a stale swift-composable-architecture 1.23.0 checkout (declares
no traits) against a lockfile correctly pinning 1.26.0 (declares the two traits AppPackage
enables), which failed resolution outright. Repaired by wiping the project's DerivedData
and letting SwiftPM re-resolve. The lockfile was correct throughout and was not modified;
no source, manifest, or resolved-file change was needed.
