---
phase: 15-continued-background-downloads
plan: 54
subsystem: downloads
tags: [continued-session, numerator-redesign, run-progress-basis, evidence-hierarchy, gap-closure, loop-root-cause]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Round 18's five open gaps (G-15-34 blocker through G-15-38) and the verifier's basis/predicate diagnosis they culminate in"
  - phase: 15-continued-background-downloads
    provides: "The rounds 8-17 correction tower this plan retires: the trust set's proof-seeding, provenPageWorkRunPageDebts, the complete-reading guard"
  - phase: 15-continued-background-downloads
    provides: "The parts proven right and kept: retirement ledger (D-G2-01), run-exit freeze, monotonic floor, announce gate (G-15-27), queued-window zero (D-G4-01)"
provides:
  - "RunProgressBasis: a run-owned measured numerator (inherited ∪ performed), monotone and record-independent by construction while a run is live"
  - "The evidence-hierarchy inherited rule sharing the blanking loop's positive-signal principle, carried on WorkingSeed (unprobedPages, scanSucceeded)"
  - "observedIncompleteSessionGIDs purified to a true observation set: seeded empty, written only by snapshot merges, never granted, never withdrawn"
  - "withdrawingCountedBasisMovement measuring sessionCreditedPages around the movement, with the announce as its own sibling bracket"
  - "flushManifestPageProgress as the structurally single landing point (performCacheCapture rerouted; orphan store overload deleted)"
  - "BackgroundProcessingClient.noop suspending at all three endpoints, censused by the double-fidelity tables"
  - "testAnIncompleteRefusalRepairsPushesClimbFromTheEvidence — the incomplete-half SERIES observation round 18 demanded"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Measure the quantity a number reports instead of inferring it from a reading of a different quantity and correcting the inference"
    - "Hold monotonicity and continuity structurally (a union of a fixed set with a growing set, no record read) rather than arguing them branch by branch"
    - "Value inherited work by the same positive-signal evidence rule the destructive path uses, from the same probe, so the two can never disagree"
    - "A withdrawal bracket measures the governed function itself, so movers nobody enumerated are covered by construction"
    - "Sibling brackets, never nested: a nested bracket withdraws the inner delta twice"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift (new series case; file pre-existing)
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreHashTests.swift
    - .planning/phases/15-continued-background-downloads/15-SECURITY.md

# Decisions
decisions:
  - "The numerator is measured, not inferred: while a run is live its gallery's credit is RunProgressBasis.creditedPageCount and never reads the index record. This retires the correction tower (proof-seeded trust, page debts, the completeness guard) as a family rather than patching its newest member."
  - "inheritedPages follows the blanking loop's evidence rule: successful scan → existing ∪ (claimed ∩ unprobed); failed scan → existing ∪ claimed; a COMPLETE-reading record additionally forfeits the pages the run was asked to fetch. Positive absence alone zeroes a claim."
  - "The evidence travels on WorkingSeed from the one scan preparation already took, so credit and blanking answer from the same probe by construction."
  - "observedIncompleteSessionGIDs is observation-only. Debt-key seeding at session start and removal at run exit are both deleted; within one session incomplete→complete happens only through landed pages, so the complete-after-observation branch has no route to an unearned number."
  - "The D-G7-01 bracket measures sessionCreditedPages(gid:) before/after the movement instead of a record delta gated on trust. The basis announcement is bracketed as its own SIBLING movement; run-exit basis retirement is deliberately NOT bracketed (the freeze plus floor keep landed pages; a numerator that does not rise is accepted over one that falls)."
  - "performCacheCapture lands its restored page through flushManifestPageProgress, making the single-landing-point premise structural; the zero-caller single-page store overload is deleted rather than kept as an unused seam."
  - "BackgroundProcessingClient.noop suspends (await Task.yield()) at all three endpoints because it is the default client of DownloadCoordinator.init and makeBlockingCoordinator; the census tables now walk its module so the rule is owned by a failing test, not a classification."
  - "The page-count-mismatch fixture's dip to 0/8 was the OLD design's record-inference, not a truth to preserve: the probed survivors are inherited work. The fixture now pins 4/8 with a rewritten doc."
---

# Phase 15 Plan 54: Round 18 — the measured numerator (loop root-cause closure)

All five round-18 gaps are closed by one redesign plus three satellite fixes, landed as four commits.
The design and the root-cause analysis live in 15-54-PLAN.md; this summary records what shipped and
the evidence.

## Gap-by-gap closure

| Gap | Closure | Commit |
|-----|---------|--------|
| G-15-34 (BLOCKER, non-monotonic credit) | `RunProgressBasis` measured numerator; `sessionCreditedPages` reduced to three continuous regimes; the guarded subtraction and the debt map are gone | `a6105b0b` |
| G-15-35 (cache capture bypasses the flush) | `performCacheCapture` routes through `flushManifestPageProgress`; orphan `refreshManifestPageFileHash` single-page overload deleted | `d155236a` |
| G-15-36 (atomic `noop` outside the census) | `noop` suspends at all three endpoints; `BackgroundProcessingClient`'s module joins the double-fidelity census walk | `5df56a8e` |
| G-15-37 (stale T-15-09) | 15-SECURITY.md T-15-09 / T-15-03 / trust-boundary row rewritten to the 15-51 per-process `registeredIdentifier` design with fresh line citations | `d4d568c6` |
| G-15-38 (duplicated helper) | `landPageFiles` delegates to the shared `pageResults` | `a6105b0b` |

## What the redesign replaced, concretely

- `provenPageWorkRunPageDebts` (session-scoped debt map) → `runProgressBases` (run-scoped, retired at
  `processDownload`'s defer). The source-inventory census re-derived: seven roles across five files
  (ContinuedSession 3, Execution 1, ExecutionSupport 1, Manager 1, Persistence 1).
- `retireProvenPageWork` → `retireRunProgressBasis`: supersession guard, freeze, basis removal. The
  observed-set removal it used to perform is deleted, not moved.
- `ensureContinuedSession` no longer seeds `observedIncompleteSessionGIDs` from debt keys; the set
  starts empty and fills only from snapshot merges reading `isIncomplete`.
- `withdrawingCountedBasisMovement` lost its trust predicate and its record read; it now measures the
  credit function it governs. `hasSessionCreditReading(gid:)` guards the after-read so a movement that
  deletes the last reading withdraws nothing (the floor covers that exit).
- `WorkingSeed` gained `unprobedPages` and `scanSucceeded`, both defaulted, both filled by
  `prepareWorkingSeed` from the reconciliation scan it already ran.

## Behavioural deltas, each pinned by a test

- Incomplete-reading refusal repair (Files-app deletion of a partial gallery) now pushes a climbing
  series: `testAnIncompleteRefusalRepairsPushesClimbFromTheEvidence` (gid 210409, 6 pages, record
  claims 4, no files on disk) observes the announce at 0/6, at least three distinct numerators, no
  rewind, terminal 6/6. This is the exact route G-15-34 named (crossover absorbed by the floor) —
  now impossible because nothing crosses.
- Page-count-mismatch repair keeps probed survivors:
  `testAPageCountMismatchFreshManifestKeepsProbedPagesCredited` pins 4/8 where the old design pinned
  a dip to 0/8.
- Complete-reading repair/retry drains from the evidence exactly as round 17 left it — the ledger
  and run-proof suites pass unmodified in behaviour, with docs rewritten from the trust story to the
  measurement story.

## Verification

- Full package suite green on the final tree: **374 tests in the downloads target** (23 suites'
  worth of continued-session, ledger, run-proof, census and store cases, including the new series
  case), **888 total across all targets, 0 failures**. Two consecutive green full runs; one
  intermediate run showed a known pre-existing overlapping-push presentation-order flake (tracked
  separately, see below) and three simulator-contention timeouts, none reproducible.
- SwiftLint build-plugin clean; `awk 'length($0)>120'` over every changed file returns nothing.
- Censuses re-derived, not adjusted: run-proof 7, double suspensions 9 (BackgroundProcessingClient 3,
  ExpirationTests 3, TestSupportTypes 3), double construction 5 (BackgroundProcessingClient 3,
  ExpirationTests 1, TestSupportTypes 1). `knownMembers` extended with
  `BackgroundProcessingClient.swift`; all census cases green.
- One `xcodebuild` invocation at a time throughout.

## Commits

- `5df56a8e` — `fix(15-56): make the noop client suspend where the seam does`
- `a6105b0b` — `fix(15-54): measure the numerator instead of correcting the record` (9 files,
  +742/−612)
- `d155236a` — `fix(15-55): land cache captures through the shared flush`
- `d4d568c6` — `docs(15-57): record the per-process identifier in the threat model`

## What this plan did NOT close

- **15-UAT.md test 2**: the physical-device iOS 26 re-run (`.redownload` route, `.repair` in a
  multi-gallery queue) is still owed, and this plan changes what that run should observe — the
  incomplete-repair series now climbs instead of freezing.
- **15-48's overlapping-run gating** is still owned by no test; unchanged by this plan.
- **The reused-identifier second submission** (15-51) still has no device observation.
- **G-15-33's historical gap record** in 15-VERIFICATION.md still carries the round-16 false-premise
  quotation; it is a historical record and was left as such.
- **A pre-existing presentation-order race**: two overlapping continued-session pushes can be
  recorded out of order at the client seam (the drain doc's accepted "one stale-shaped push"). The
  never-rewinds series assertions are stricter than that accepted transient, so under extreme
  scheduling perturbation a series test can flake without a production defect. Observed once during
  this plan's iteration; tracked as a follow-up task outside the phase.

## Self-Check: PASSED

Commits verified in `git log`: `5df56a8e`, `a6105b0b`, `d155236a`, `d4d568c6` — all FOUND.
Files asserted modified all exist on disk and appear in the commits above.
