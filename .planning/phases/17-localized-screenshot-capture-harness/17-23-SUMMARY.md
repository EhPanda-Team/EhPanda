---
phase: 17-localized-screenshot-capture-harness
plan: "23"
subsystem: verification
tags: [verification, reader, release-isolation, requirements]
requires:
  - phase: 17-14
    provides: Release isolation scanner and the T2 run at 1829841d8
  - phase: 17-19
    provides: Layout census with the owner's keep decisions
provides:
  - 17-FINAL-VALIDATION.md, the reduced-scope gate at 97b31b063 and the requirement trace
  - 17-VALIDATION.md reduced-scope sign-off
  - 17-SOURCE-AUDIT.md execution status at Phase 17 close
  - Reader pager fixes found by the gate, and the reader's soft bottom edge
affects: [18]
actuals:
  tasks: 2
  commits: 8
tech-stack:
  added: []
  patterns:
    - "The reader reads the page on screen from scroll-target visibility, not from the position binding, and corrects the pager at rest"
key-files:
  created:
    - .planning/phases/17-localized-screenshot-capture-harness/17-FINAL-VALIDATION.md
    - AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift
    - AppPackage/Tests/ReadingFeatureTests/PagerSeedTests.swift
  modified:
    - .planning/phases/17-localized-screenshot-capture-harness/17-VALIDATION.md
    - .planning/phases/17-localized-screenshot-capture-harness/17-SOURCE-AUDIT.md
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/Support/PageModel.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
key-decisions:
  - "A page turn that arrives while the pager animates moves only the index; the pager is sent there once it rests."
  - "At rest, the page on screen is checked against the index; after two failed sends the index follows the screen, so the indicator never names a page that is not shown."
  - "The pager is seeded at the first measurement with both a width and a height, and its pages are built only after that."
  - "The soft bottom edge's invisible bar appears only after the reader has a reading area, so it cannot be mistaken for one."
  - "The owner chose a 5-iteration iPad page-sync stress instead of 20 to close the phase on 2026-11-04; recorded as a known limit."
  - "At the closing source 891103afa both devices ran the page-sync stress ×5; the owner accepted that as a known limit on 2026-11-05 (owner msg 1640)."
requirements-completed: [CAP-17-01, CAP-17-04, CAP-17-06, CAP-17-07]
---

# 17-23 summary: reduced-scope Phase 17 gate

Phase 17's reduced gate passes at `97b31b063`. The record is
[17-FINAL-VALIDATION.md](17-FINAL-VALIDATION.md). The requirements listed as completed are the Phase 17
parts only (fixture part of CAP-17-01, amended CAP-17-04, bounded part of CAP-17-06, amended
CAP-17-07). CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts are moved to Phase 18.

## T1: final gate

| Check | Result at `97b31b063` |
|---|---|
| FeatureTests, iPhone Air | exit 0; 1535 cases: 1526 passed, 0 failed, 9 expected failures, 0 Repetition |
| UITests, iPhone Air | exit 0; 88 cases: 68 passed, 0 failed, 20 skipped, 0 Repetition |
| FeatureTests, iPad Pro 11-inch (M5) | exit 0; 1535 cases: 1525 passed, 0 failed, 10 expected failures, 0 Repetition |
| UITests, iPad Pro 11-inch (M5) | exit 0; 88 cases: 71 passed, 0 failed, 17 skipped, 0 Repetition |
| Strict lint | 0 violations in 759 files |
| Release scan | exit 0, 0 findings; the launched probe can't activate capture |
| Debug negative control | exit 1, 991 findings |
| Scanner tests | 19 OK |

ReaderPageSyncUITests stress:

| Device | Source | Iterations | Result |
|---|---|---|---|
| iPhone Air | `e745f38f6` | 20 | 160 of 160 passed, 0 retries |
| iPad Pro 11-inch (M5) | `97b31b063` | 5 | 40 of 40 passed, 0 retries |

## What the gate found and fixed

ReaderPageSyncUITests found reader desyncs during the gate, in T1 attempts and in stress runs. Each
cause was fixed in the app before the final runs; the pager fixes carry unit tests.

- `adbd63809`: a turn during a programmatic scroll could be dropped, so the indicator named one page
  and the screen showed another. Turns are now held until the pager rests.
- `8f0d09fff`: a turn could still go missing without starting a scroll (iPad, 1 in 20). The reader now
  checks the page on screen against the index at rest and sends the pager again.
- `2539331b2`: after two failed sends the index follows the screen instead of naming a missing page.
- `4372e4b8f`: a cold vertical reader could open on page 1 while the indicator named the resume page
  (1 in 160 iPad openings). The pager is now seeded at the first measurement that has both a width
  and a height.
- `90d6a6339`: the reader's bottom edge softens under the control panel, as the top does under the
  navigation bar.
- `346a3ea87`: that bar made the phone's vertical reader lose the resumed page on its first turn to
  landscape (19 of 20 failures). The bar now appears only after the reader has a reading area.
- `e745f38f6`: the reader hides the home indicator while its controls are hidden. No test can see the
  indicator; the website recapture confirmed it on screen.

The owner's website recapture added two DEBUG-only capture commits during the gate, `d474d7f68` and
`61d13639b`. Neither is reached outside a capture launch, and the final runs include them.

## T2: records

- 17-FINAL-VALIDATION.md: gate results, amended wording, website approval, layout census, 17-06
  leftovers, requirement trace, D-01 to D-27, remaining assumptions.
- 17-VALIDATION.md: reduced-scope sign-off.
- 17-SOURCE-AUDIT.md: execution status at close, with the moved plans marked. Uncommitted versions of
  these two edits were discarded on 2026-11-04 during another agent's cleanup of incomplete Phase 17
  drafts; they were rewritten for this commit.

## After the code review

The phase code review's WR-01 and IN-01 were fixed (`92181ccd2`, `18ec91b86`), and the gate ran
again at `891103afa`, except the Debug negative-control scan (last run at `97b31b063`). All four
runs exit 0 with 0 failures and 0 Repetition; lint and the Release scan are clean. ReaderPageSyncUITests
ran ×5 on the phone (40 of 40 passed, 0 retries) and on the iPad (40 of 40 passed, 0 retries). See
17-FINAL-VALIDATION.md section 9. The reader's page tracking moves to one source of truth in Phase 18.

## Deviations

- **Release scan repeated.** The plan cites 17-RELEASE-ISOLATION.md only if the source equals 17-14's
  commit. It doesn't, so the Release build and scan ran again at `97b31b063`.
- **Reduced stress.** At `97b31b063`, the iPad ran 5 iterations instead of 20, by the owner's choice
  (see key decisions). At the closing source `891103afa`, **both** devices ran ×5; the ×20 phone run
  is at `e745f38f6`, before WR-01/IN-01. The owner accepted ×5 on both devices as a known limit
  (owner msg 1640).
- **17-VERIFICATION.md.** This plan says not to write it, and its records do not include it. The
  gsd-verifier wrote it after this plan's records; it was committed as `7900db15e`. (Corrected
  2026-11-05: this bullet used to say the file had been written at the orchestrator's direction.
  No such file was committed before `7900db15e`, and the executor's draft was never committed.)

## Unresolved gates and known limits

- The CAP-17-07 unclassified-edge classification and the owner-approved synthetic comment in gallery
  2758456 (17-FINAL-VALIDATION.md sections 3 and 8): the verifier concurred, and the owner accepted
  both on 2026-11-05 (owner msg 1640).
- UAT and the remaining close steps.
- The slider's preview gesture ends before the finger lifts, so the rest of a drag seeks live. The
  fixes keep the indicator correct; the gesture itself is unchanged.
- ReaderPageSyncUITests doesn't cover right-to-left reading, and `ReaderPageProbe` can't read an iPad
  landscape spread.
- A rotation or a two-page spread could add one pager correction (at most two sends before the index
  follows the screen).
- The comment in `ReadingView.swift` says the full-width bar moved the opening page "on iOS 26"; it was
  probably iOS 27.x. Kept as written.
