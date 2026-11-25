---
phase: 19-visual-regression-marketing-export
plan: "25"
subsystem: ui
tags: [archives, hath, gallery-points, credits, owner-decision, c15]

requires:
  - phase: 19-31
    provides: "the wave order; 19-25 runs after the Front Page page count fix"
provides:
  - "C15 decided: accepted by the owner on 2026-11-25. No card is disabled and no copy is added; the site decides whether an archive can be paid and the app shows its response, as before"
  - "Site evidence for archive prices: the H@H price is written \"1343 GP\" (digits, \" GP\", no grouping), and a GP shortfall is paid from Credits at the GP Exchange's 24-hour \"High\" rate"
affects: [19-13, 19-26]

actuals:
  tokens: 0
  tasks: 2
  commits: 4

plan_head_before: ea76a082874003afbe8bdbd95d1bca51c13788ba
plan_head_after: ed91524bb12e2a532ffeb1cd8be1aa71e78b6be2

key-files:
  created:
    - .planning/phases/19-visual-regression-marketing-export/19-25-C15-PROPOSAL.md
  modified:
    - .planning/phases/19-visual-regression-marketing-export/19-13-PRECHECK.md

key-decisions:
  - "C15 accepted (owner, verbatim 「不停用，C15 改為接受」): the app cannot know whether an archive is affordable, because the site covers a GP shortfall from Credits at a rate the app does not have"
  - "Task 3 not run: with C15 accepted there is no approved design or copy to implement"

requirements-completed: [VIS-18-01]

duration: 1 session
completed: 2026-11-25
---

# Phase 19 Plan 25: C15, insufficient funds on Archives Summary

C15 is accepted, so nothing changes in the app. A GP-only gate would block downloads the site completes by paying the
shortfall from Credits.

## Accomplishments

- Task 1: `19-25-C15-PROPOSAL.md` with the evidence, the rule, options `U1` and `U2` and their six-locale copy
  (`d44cdec70`). The orchestrator then had each locale read by its own reviewer who saw only that locale, and folded in
  what they found (`32f821b0c`).
- Task 2, first round: the owner chose disabled cards with no added line, asked whether the copy followed the global
  localization rule, asked the orchestrator to read the site for the price format, and was unsure of the currency. The
  answers are quoted in the proposal. On the copy, the answer was that the rule had not been fully followed: one writer
  drafted all six locales, the reviewers corrected drafts instead of writing from the facts, and one zh-Hant change was
  carried into zh-Hans.
- Site evidence, read only on e-hentai.org with the owner's signed-in account (`611ef1fc8`):
  - the H@H table writes "1343 GP" per size;
  - the page does not mark sizes the GP cannot pay;
  - the wiki's "Gallery Points" page says Credits are used in place of GP when GP falls short, auto-converted at the
    GP Exchange's 24-hour "High" rate.
- Task 2, second round: with that evidence the owner chose 「不停用，C15 改為接受」 (`ed91524bb`). The C15 row in
  `19-13-PRECHECK.md` now reads accepted, with the reason.

## Deviations from Plan

- **Task 3 not executed (owner decision).** The plan's truths (an unaffordable archive shown as such, its download
  disabled, new copy in six locales) are superseded by the owner's acceptance of C15. `HathArchive.gpCost`, the
  reducer gate, the copy and the three planned test files were not written, and no source file changed.
- **Threat ID collision fixed before the run.** 19-31 had reused T-19-53, this plan's ID. 19-31's threat is now
  T-19-67 (`ea76a0828`).
- **Orchestrator steps outside the plan's text.** These were the blind locale review and the site visit, which the
  owner asked for.

## Known limitations recorded

- The fixtures write archive prices as bare digits ("180"), while the site writes "180 GP". The card shows the stored
  text, so the `detail-pages-archives*` pictures show prices without the unit the real app shows. This is not changed
  here.

## Threat Flags

None. T-19-53 (copy or design landing without the owner's approval) is mitigated: nothing landed, and the owner's
choice came after the site evidence. T-19-54 (a misread price or balance blocking an affordable download) is avoided:
there is no gate, which is exactly the owner's reason.

## Self-Check: PASSED

- `19-25-C15-PROPOSAL.md` has exactly one "## Owner decision" (Task 2 verify).
- No file under `AppPackage/` changed between `ea76a0828` and `ed91524bb`.
- All commits are signed, with +08:00 dates.
