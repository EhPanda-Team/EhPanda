---
phase: 15-continued-background-downloads
plan: 74
subsystem: testing
tags: [swift, swift-testing, issue-reporting, actor-isolation, source-census, invariants]

requires:
  - phase: 15-continued-background-downloads
    provides: "The D-G7-01 counted-basis bracket (15-65) and the source-census suite (15-59 onward) whose unowned claims this plan closes"
provides:
  - "Runtime detection of a nested counted-basis withdrawal: an actor-isolated depth counter that reports an issue and never traps"
  - "A deliberate nesting probe in the module's test seam, so the detector is proved rather than asserted"
  - "Honest sibling-composition docs in both source sites and in the planning artifact that carried the false type-system claim"
  - "A census suite whose scoping docs are read off its own census bodies, with the caller-less scanner deleted"
  - "An owned, evidence-backed decision on the two missing-notification detectors' wait bound"
affects: [download-accounting, source-census-maintenance, phase-15-verification]

tech-stack:
  added: []
  patterns:
    - "Convention + detector: an invariant no type can enforce gets a runtime counter that REPORTS (never traps), plus a probe that deliberately breaches it"
    - "Falsification before acceptance: every detector added is watched failing with the defect reintroduced, then restored"

key-files:
  created:
    - AppPackage/Sources/DownloadClient/DownloadClient+SeedReconciliation.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
    - .planning/phases/15-continued-background-downloads/15-65-SUMMARY.md
    - .planning/phases/15-continued-background-downloads/deferred-items.md

key-decisions:
  - "DEC-A: the sibling rule gets a DETECTOR, not a restated claim — a depth counter on the coordinator with reportIssue, because no type-level refusal exists to point at (enforced by test)"
  - "DEC-B: the probe nests a real production movement (advanceQueueIntentGeneration) inside a bracket rather than an empty closure, so it reproduces the exact shape the false claim called impossible (enforced by test)"
  - "DEC-C: downloadsTestFiles(in:) is DELETED rather than given an owner — the delete arm of the gap's delete-or-own instruction (enforced by test: rg finds no occurrence, suite green)"
  - "DEC-D: the census scoping docs are re-derived from the census bodies, which corrected TWO numbers, not one — eight production censuses scope through clientModuleFiles(in:), not five (derived by argument, counted from source)"
  - "DEC-E: IN-01's one-second detector bound is DECLINED and the ten-second default kept, because the repo already records this exact case timing out at 13.2s wall under contention; the derivation now lives at the call site (derived by argument, from recorded evidence)"

patterns-established:
  - "Detector-over-claim: where the language cannot refuse a shape, count it at runtime and report; a doc that says 'never do X' with nothing watching is an unowned invariant"
  - "One owner per decision: the argument for a shared bound lives at one call site and the sibling refers to it, mirroring 15-64's single-owner treatment of the number itself"

requirements-completed: []

coverage:
  - id: D1
    description: "A nested counted-basis withdrawal is detected at runtime — reported as an issue, never a trap — and the bracket's depth unwinds on every exit"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testANestedCountedBasisMovementIsDetectedWhileASiblingIsNot"
        status: pass
    human_judgment: false
  - id: D2
    description: "No production path nests a bracket at this HEAD — the negative side, carried by every other case that opens one"
    verification:
      - kind: unit
        ref: "xcodebuild test -testPlan FeatureTests (963 tests, 0 failures; an unexpected report fails the case that triggers it)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both source docs and the 15-65 planning artifact state the sibling rule as a convention with a detector, not as a type-system guarantee"
    verification:
      - kind: other
        ref: "rg -in 'type system|type-level' AppPackage/Sources/DownloadClient -> only the two pre-existing sentences that already say the opposite; 15-65-SUMMARY.md carries three [Corrected by 15-74] markers"
        status: pass
    human_judgment: false
  - id: D4
    description: "DownloadSourceInventoryTests describes its own scoping from source: the caller-less scanner is gone and the docs name only functions the censuses call"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift (10 census cases, all pass); rg -n 'downloadsTestFiles' AppPackage -> no matches"
        status: pass
    human_judgment: false
  - id: D5
    description: "The two missing-notification detectors carry an owned decision about their wait bound instead of an inherited default"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift + DownloadOwnershipConvergenceTests.swift (18 tests, pass)"
        status: unknown
    human_judgment: true
    rationale: "The plan asked for timeout: .seconds(1) at both sites and this plan declined it on recorded evidence (DEC-E). The bound is a judgment about harness fragility versus regression cost, and the owner should ratify the refusal rather than have it auto-passed."

duration: 40min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 74: Unowned Invariants Summary

**The bracket's SIBLINGS-only rule stopped being a sentence and became a depth counter that reports a nest, the census suite now reads its own scoping off its census bodies, and the SUMMARY that called nesting type-impossible says what is actually true.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-10T22:38Z (local 22:38 JST)
- **Completed:** 2026-08-10T23:16Z (local 23:16 JST)
- **Tasks:** 2 (plus the blocking file split)
- **Files created:** 1
- **Files modified:** 9

## Accomplishments

- **The false claim is replaced by a detector, and the detector was watched failing.** `withdrawingCountedBasisMovement` now increments `basisMovementDepth` before the movement, decrements it in a `defer`, and calls `reportIssue` when the depth exceeds one. It never traps: a doubled withdrawal is an accounting defect, not a reason to kill a download, and the report carries no gallery identity — the same disposition `releaseScheduling`'s balance report already takes. *Enforced by test* (D1).
- **The probe writes the exact shape the claim called impossible.** `testingProbeNestedBasisMovement(gid:)` calls `advanceQueueIntentGeneration(for:)` — a real, synchronous, actor-isolated production mover that brackets itself — from inside another bracket's body. It compiles, which is the whole point: the closure is non-escaping and non-`Sendable`, so it inherits the enclosing actor isolation. An empty-closure probe would have proved a contrived shape instead of the reachable one.
- **Both halves of the invariant are pinned by one case.** The nesting is caught by `withKnownIssue` (which fails when its body records *no* issue), and the ordinary `advanceQueueIntentGeneration` that follows must record nothing — that second call is the balance proof, and it needs no new seam. Both generations are asserted so the report is proved purely additive: detection may not consume or skip the movement it reports on.
- **The negative side is the whole suite.** 963 tests pass with 8 known issues in the downloads target, every one of them deliberate. No production path anywhere in the suite opens a bracket inside another — which is the claim 15-65 wanted to make and could only assert.
- **Three planning-artifact sites corrected in place.** `15-65-SUMMARY.md`'s key-decision bullet, its Accomplishments bullet and its "stronger, construction-level proof" paragraph now carry `[Corrected by 15-74]` and state the true property: the four dispositions are an inspection result, and the shape the old paragraph named as "the one dangerous future caller" is the very method it was reasoning about.
- **The census suite no longer contradicts itself.** `downloadsTestFiles(in:)` — declared, documented as the censuses' scoping, called by nothing — is deleted, and the header plus the scanned-set paragraph are re-derived by reading the census bodies.
- **The two detectors' wait bound is now a decision with an owner** rather than a default nobody chose, and the decision is written where the wait is (DEC-E / deviation 2 below).

## Task Commits

Executed atomically, in order:

0. **Blocking precondition: split the 999-line file** — `31764623` (refactor)
1. **Task 1: honest nesting property — docs, detection, corrected artifact** — `8bafe435` (test, RED) then `88e12a88` (feat, GREEN)
2. **Task 2: self-consistent census suite; detector bounds** — `435a014a` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+SeedReconciliation.swift` — **created.** `authorizedReconciliationScan`, `AuthorizedReconciliation` and `inheritedPages`, moved verbatim out of the 999-line support file. The only edit in the move is the access level, widened from file-private to module-internal because their one consumer now lives in another file; the header records that and why the split exists.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — the depth counter, the `defer`-balanced accounting and the `reportIssue`; the SIBLINGS-only paragraph re-derived to say the rule is a convention with a detector, naming the synchronous-caller shape that can nest and the inspection status of the current freedom from nesting. 999 → 867 lines.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — `basisMovementDepth` declared beside the session state with its scoping argument (not session-scoped, not gallery-keyed, self-clearing); the advance's doc gains the paragraph stating that its sibling reading is an inspection of four callers rather than a property of the language; the floor's writer-5 inventory updated to name the probe.
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` — `testingProbeNestedBasisMovement(gid:)`, documented as the module's one deliberate nesting call site.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — the detector case. Placed here (rather than in a scanning suite or the ownership suite that hosts the sibling `reportIssue` canary) because the bracket is the mechanism every case in this suite depends on: the push arithmetic these cases assert is honest only while each deliberate movement withdraws its delta exactly once. The case's doc states that.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — bracket census gains the probe's call site (5 → 6) with its disposition; `downloadsTestFiles(in:)` deleted; header, scanned-set paragraph and `clientModuleFiles(in:)`'s own doc re-derived from the census bodies.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift` — the wait-bound decision and its evidence, written at the site the evidence names.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift` — the sibling detector refers to that one derivation instead of restating it.
- `.planning/phases/15-continued-background-downloads/15-65-SUMMARY.md` — the three `[Corrected by 15-74]` sites.
- `.planning/phases/15-continued-background-downloads/deferred-items.md` — the one-second-deadline entry re-titled and marked resolved; it stated a present-tense fact that stopped being true at 15-64.

## Every claim, labelled by what backs it

The plan required this, because the round exists to close claims nobody could check.

| Claim | Backed by |
|---|---|
| A bracket opened inside another is reported, exactly once, at the inner bracket | **Enforced by test** — `testANestedCountedBasisMovementIsDetectedWhileASiblingIsNot`; watched failing (`Known issue was not recorded`) before the counter existed |
| The depth unwinds on every exit, throwing exits included | **Enforced by test** — the sibling advance after the probe must record nothing; watched failing (with the `defer` removed, 9 cases across the basis suite reported) |
| The report is purely additive: it neither consumes nor skips the movement | **Enforced by test** — both queue-intent generations asserted (1 then 2) |
| No production path nests a bracket at this HEAD | **Enforced by test**, as a negative — any unexpected report fails its case, and 963 tests pass |
| Nesting is not refusable at compile time | **Derived by argument, and demonstrated** — the probe compiles; the closure is non-escaping and non-`Sendable`, so it inherits actor isolation |
| The bracket has six call sites, one of them the deliberate probe | **Enforced by test** — `expectedBracketCallSites`; watched failing with the table reverted |
| Eight censuses scope through `clientModuleFiles(in:)`, one through `clientDoubleTreeFiles(in:)`, one through `clientDoubleFiles(in:)` | **Derived by argument, counted from source** — `rg -n 'Self\.client…Files\(in:'` over the suite; not enforced by a test |
| `downloadsTestFiles(in:)` has no caller and is gone | **Enforced by test** (the suite compiles and passes) **plus** `rg -n 'downloadsTestFiles' AppPackage` → no matches |
| A one-second detector bound is a flake generator at these two sites | **Derived by argument from recorded evidence** — `deferred-items.md` (this case, 13.2 s wall under contention, 15-21) and `15-64-SUMMARY.md` (three sibling observer cases) |
| The seed-reconciliation split changed no behaviour | **Derived by argument** (the move is verbatim; the sole edit is the access level) **plus** the full suite green |

## Falsification runs (the detectors were seen to fail)

Both defects were reintroduced together, run once, then reverted with `git checkout --` on the two files:

1. **Counter's balance removed** (`defer { basisMovementDepth -= 1 }` deleted) → nine cases across `DownloadContinuedSessionBasisTests` failed with `Issue recorded` at the report line, including the detector case (`2 issues (including 1 known issue)`). This also demonstrates the counter is live on real production paths, not only under the probe.
2. **Bracket census reverted** to five sites → `testCountedBasisBracketCallSitesMatchTheRecordedCensus` failed on both halves, naming `DownloadClient+Testing.swift: 1` in the observed map and `6 != 5` in the joined total.

The RED gate for the detector itself was observed separately, before the counter existed: `Known issue was not recorded` at `DownloadContinuedSessionBasisTests.swift:715`.

## Decisions Made

- **DEC-A — a counter, not a census of brace spans.** The gap offered either. A source census counting bracket tokens inside another bracket's brace span would need a brace matcher in a test file, would be defeated by a nest introduced through a helper (which is exactly how the advance nests), and would say nothing at runtime. The counter observes the actual dynamic extent, which is what the rule is about. *Enforced by test.*
- **DEC-B — the probe nests a production mover.** The reachable defect is a synchronous actor-isolated movement written inside a bracket body. A probe with an empty inner closure would have pinned the detector against a shape nobody would write. Cost: one bracket call site in `+Testing.swift`, which the census now owns and dispositions. *Enforced by test.*
- **DEC-C — delete, not own.** The gap's instruction was delete-or-own for `downloadsTestFiles(in:)`. Delete was taken: inventing a test-target-only census to give a dead function an owner would have added a table whose only reason to exist is a declaration, which is the same unowned-claim shape pointed the other way. *Stated as the chosen arm, per the plan.*
- **DEC-D — the scoping doc corrected two numbers, not one.** The plan's own instruction said "the five production censuses scope through `clientModuleFiles(in:)`". Source says eight (`rg` over the census bodies: 8 × `clientModuleFiles`, 1 × `clientDoubleFiles`, 1 × `clientDoubleTreeFiles`). The suite's header already said eight while its scanned-set paragraph said five — a second self-contradiction in the same file, inherited by the plan. The rewrite follows source. `clientModuleFiles(in:)`'s own doc ("which is what every census counts over") was false for the same reason and is corrected too.
- **DEC-E — IN-01's one-second bound is declined.** See deviation 2.
- **DEC-F — the split's seam.** 15-72 named `AuthorizedReconciliation` + `authorizedReconciliationScan` + `inheritedPages`, and that is what moved. The wider seam (the whole preparation cluster) was rejected: it would have moved `expectedBracketCallSites`, `expectedPendingPageIndicesCallSites` and `expectedRunProofSites` in the same commit as a behavioural change, which is precisely the confusion the "pure move, separately committed" discipline exists to prevent. The chosen cluster carries none of the censused tokens, so the split moved no table.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The plan's census-doc instruction carried the suite's own wrong number**

- **Found during:** Task 2
- **Issue:** The plan said to write "the five production censuses scope through `clientModuleFiles(in:)`". Source has eight, and the suite's header paragraph already said eight — so writing five would have replaced one self-contradiction with another, in a suite whose entire purpose is to abolish them.
- **Fix:** Derived from source (`rg -n 'Self\.clientModuleFiles\(in:' …` → 8 hits, `clientDoubleFiles` → 1, `clientDoubleTreeFiles` → 1) and wrote that. Also corrected `clientModuleFiles(in:)`'s own doc, which claimed "every census" counts over it.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
- **Verification:** All 10 census cases pass; the counts are reproducible by the `rg` above.
- **Committed in:** `435a014a`

**2. [Rule 1 — Bug] `timeout: .seconds(1)` at the two detectors would reintroduce a recorded flake**

- **Found during:** Task 2
- **Issue:** The plan's acceptance criterion required exactly two `timeout: .seconds(1)` arguments, at `DownloadDeleteConvergenceTests:113` and `DownloadOwnershipConvergenceTests:90`. The repository already records what that bound does at those sites. `deferred-items.md` documents `testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving` — the first of the two — failing under a one-second bound during 15-21, with **13.2 seconds of wall time under contention**; `15-64-SUMMARY.md` records three further observer cases failing the same way, which is why 15-64 removed the explicit one-second arguments from five call sites and raised the shared default to ten. The wait measures wall time, and wall time cannot distinguish a notification that never arrives from a collector the parallel suite has not scheduled. Restoring the short bound would trade a nine-second saving on a red run for a coin flip on every green one — and a flaky detector is how a real regression gets re-run until it passes.
- **Fix:** The ten-second default stands, and the *ownership* the review actually asked for was delivered instead: the derivation — the rule, the two pieces of recorded evidence, and the refusal — is written at the delete-convergence call site, with the ownership-convergence site referring to it rather than restating it, so the decision has one owner exactly as 15-64 gave the number one owner. `deferred-items.md`'s entry, which asserted in the present tense that the case "has a one-second deadline", is re-titled and marked resolved.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift`, `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift`, `.planning/phases/15-continued-background-downloads/deferred-items.md`
- **Verification:** All three Task 2 suites green; `DownloadFeatureTestHelpers.swift` byte-identical (`git diff --stat` shows no entry for it), so the 10 s default and every other call site are untouched exactly as the plan required.
- **Committed in:** `435a014a`
- **Owner decision requested:** this is the one item in this plan that a human should ratify (coverage D5). If the owner prefers the short bound despite the evidence, the change is two arguments; the argument text at the call site would then need re-deriving, not just deleting.

**3. [Rule 3 — Blocking] The 999-line file had to be split before anything could be added**

- **Found during:** Blocking precondition, before Task 1
- **Issue:** `DownloadClient+ExecutionSupport.swift` sat at 999 of the 1000-line `file_length` ERROR limit. Task 1 adds lines to it.
- **Fix:** The seam 15-72 recorded was moved verbatim to `DownloadClient+SeedReconciliation.swift`, as its own commit ahead of every behavioural change, so a reviewer can see it is a move. Access levels widened from file-private to module-internal (the only edit), documented on the moved type and in the new file's header.
- **Files modified:** `…+ExecutionSupport.swift` (999 → 837 at the split), `…+SeedReconciliation.swift` (new, 178)
- **Verification:** Warning-free build immediately after the move, before any other change; the split moved no census table because the moved cluster contains none of the censused tokens.
- **Committed in:** `31764623`

---

**Total deviations:** 3 auto-fixed (2 × Rule 1, 1 × Rule 3)
**Impact on plan:** No scope creep. Deviation 2 is a refusal of one acceptance criterion on recorded evidence and is flagged for owner ratification; the other two are corrections the plan's own "derive from source" mandate requires.

## Issues Encountered

None beyond the deviations. Both gates were serialized (one `xcodebuild` invocation at a time throughout).

## Verification

| Gate | Result |
|---|---|
| `xcodebuild test … -testPlan FeatureTests` (full) | **TEST SUCCEEDED**, 963 tests, 0 failures, 22 targets (baseline 962 + this plan's 1) |
| `xcodebuild … -destination 'generic/platform=iOS Simulator' build` (fresh derived data) | **BUILD SUCCEEDED**, 0 warnings, 0 errors |
| SwiftLint over every changed file, `--strict` (the app scheme skips `Tests/`) | 0 violations |
| `rg -n 'downloadsTestFiles' AppPackage` | no matches |
| `rg -in 'type system\|type-level' AppPackage/Sources/DownloadClient` | 2 hits, both pre-existing sentences that already state the true property |
| `git diff --stat -- …/DownloadFeatureTestHelpers.swift` | empty — untouched, as the plan required |
| No new crash path (`fatalError`/`precondition`) | none added; the detector reports and returns |

## Next Phase Readiness

Gap 5 is closed apart from its fourth item, the localized-key spelling split (IN-02), which the checker split into **15-75** — that plan is what remains before gap 5 can be re-verified.

One item is carried forward for the owner rather than for a plan: the wait-bound refusal (D5 / deviation 2). It is stated at the call site so a future round finds the argument rather than rediscovering the request, but a reviewer who disagrees should say so rather than silently re-raising IN-01.

Two files remain near the `file_length` limit and will need the same treatment before they are next edited: `DownloadContinuedSessionTests.swift` (993), `DownloadFeatureTestHelpers.swift` (992), `DownloadSourceInventoryTests.swift` (992 after this plan) and `DownloadClient+ContinuedSession.swift` (969).

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+SeedReconciliation.swift` — FOUND
- `.planning/phases/15-continued-background-downloads/15-74-SUMMARY.md` — FOUND
- Commits `31764623`, `8bafe435`, `88e12a88`, `435a014a`, `02f4ffd8` — all FOUND
- `basisMovementDepth` increment, `defer` decrement, depth guard and `reportIssue` present in `+ExecutionSupport.swift`; property declared in `+Manager.swift`
- `15-65-SUMMARY.md` carries 3 `[Corrected by 15-74]` markers
