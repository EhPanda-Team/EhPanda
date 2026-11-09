---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "12"
subsystem: analytics
tags: [analytics, telemetrydeck, vocabulary, consent, sign-off]

requires: []
provides:
  - "`20-12-VOCABULARY.md`, signed off (OQ-E): the 3.0 signals 20-13 implements, the channel as a Basic and Full default parameter, the OI-4 answer and the SC8 wording"
affects: [20-13]

actuals:
  tokens: 35000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-12-VOCABULARY.md
  modified:
    - .planning/ROADMAP.md

key-decisions:
  - "Signals (product lead msg 2829): `FirstLaunch.completed` (`Analytics.level`), `Analytics.levelChanged` (`Analytics.from`, `Analytics.to`), `Moderation.reportOutcome` (`Moderation.reportOutcome` only), `Moderation.posterBlocked`, `Moderation.posterUnblocked` (`Moderation.unblockSurface`), `Moderation.blockedCommentShown`, `Moderation.postingWarningAnswered` (`Moderation.postingChoice`). All need Basic. Nothing new for the marketplace build."
  - "Report reason (owner msg 2837, \"No, only how it ended\"): option (3-i). `Moderation.reportReason` is dropped and the README line loses \"with its reason\", so no level description changes."
  - "Channel (owner msg 2842, \"Yes, on every signal\"): §3 option 1. `App.distributionChannel` becomes a default parameter at Basic and Full. The README Basic section gains \"every event also carries where you got the app from\"."
  - "OI-4: answer A, a technical call by the developer. Both install signals are kept; `App.installed` is the install count."
  - "SC8: the proposed wording, a technical call by the developer, applied to ROADMAP Phase 20 SC8."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "A rule-checked proposal for every 3.0 flow and OI-4"
    requirement: ANALYTICS-02
    verification:
      - kind: manual
        ref: "grep -ci counts in 20-12-VOCABULARY.md: First launch 2, Analytics choice 2, Report 13, Block 8, Posting 3, Marketplace 1, OI-4 4; git diff --stat -- AppPackage: empty"
        status: pass
    human_judgment: false
  - id: D2
    description: "Sign-off recorded with message numbers before any implementation"
    requirement: ANALYTICS-02
    verification:
      - kind: manual
        ref: "Sign-off table: product lead msg 2829, owner msgs 2837 and 2842; OI-4 and SC8 marked as developer calls; no AppPackage change on the branch for this plan"
        status: pass
    human_judgment: true

duration: n/a (proposal and sign-off in separate sittings)
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 12: the analytics vocabulary for the 3.0 flows Summary

**The 3.0 analytics vocabulary is signed off (OQ-E). There are seven Basic signals, the report signal carries only
how the report ended, and `App.distributionChannel` goes on every signal at Basic and Full. OI-4 keeps both install
signals and counts `App.installed`. ROADMAP SC8 now reads "nothing is sent before a level is chosen". No code
changed; 20-13 implements the record.**

## Performance

- **Duration:** not tracked. The proposal was committed at 2026-11-09T01:34:54Z and the sign-off recorded around
  02:40Z, after the approvers answered.
- **Completed:** 2026-11-09
- **Tasks:** 2
- **Files modified:** 2 (`20-12-VOCABULARY.md`, `ROADMAP.md`), plus STATE

## Accomplishments

- **Proposal (Task 1).** `20-12-VOCABULARY.md` sets out the following, refined against the code:
  - each signal's case, name, closed-enum parameters with every value, level, covering sentence, and send site
    (file and action);
  - the README line in English;
  - the rules check per signal;
  - the channel option with pros and cons;
  - OI-4's options A and B;
  - the SC8 wording.

  Research's `FirstLaunch.kind` was dropped (note c): 3.0 has no stored fact that tells an upgrade from a new
  install.
- **Sign-off (Task 2).** The record now carries the following, with a table that names who decided each item:
  - the approvals: product lead msg 2829, owner msgs 2837 and 2842;
  - the two developer calls: OI-4 answer A and the SC8 wording.

  Where a decision changed the proposal, the record marks the change in place:
  - signal 3 loses `Moderation.reportReason`, and `ReportReason` leaves 20-13's enum list;
  - the README line ends at "(sent, failed, unavailable or opened on the site)";
  - §3 gains the Basic README line;
  - §7 gains the Basic `snapshot` case.

## Task Commits

1. **Task 1: Vocabulary proposal.** `02b242cfc` (docs)
2. **Task 2: Sign-off.** The docs commit that adds this summary, the sign-off and the ROADMAP SC8 wording

## Decisions Made

See `key-decisions`. No level description changes, because (3-i) was chosen and §3 option 1 is covered by Basic's
"Everything in Minimal". So no copy approval is needed under the `AnalyticsSignal+Level.swift` header rule.

## Deviations from Plan

1. **OI-4 and SC8 were decided by the developer, not by the product lead and the owner.** The plan's truth asks
   for the approvers to sign off OI-4 and SC8. The coordinator's instruction for Task 2 assigned both to the
   developer as technical calls. The sign-off table records them that way, with no approver message number.
2. **The product lead's column for §3 is empty.** The owner decided the channel (msg 2842). Product lead msg 2829
   approved the §2 list only.

## Open items

- 20-13 adds the README lines in English and the five translations (`READMEs/`, `18-copy-check.py --readmes`):
  the moderation clause without "with its reason", and the Basic channel line. Those translations are the copy
  20-13 needs; the level descriptions themselves stay as approved.
- 20-13 rewrites the two "no analytics" headers (`CommentModeration.swift`, `ReportFormFeature.swift`) and
  records the OI-4 answer in `COVERAGE.md`.

## User Setup Required

None.

## Next Phase Readiness

20-13 can implement the record when its turn in the fixed order comes (after 20-11). 20-06 and 20-13 were not
started.
