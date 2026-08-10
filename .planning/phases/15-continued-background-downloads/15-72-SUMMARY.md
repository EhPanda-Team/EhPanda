---
phase: 15-continued-background-downloads
plan: 72
subsystem: downloads
tags: [download-client, manifest-ssot, compensation, run-progress-basis, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-67's classify-guard-remove-rescan-blank ordering on the repair-seed route, and the validate route's CR-02 recover-once-and-log compensation it copied the ordering from"
provides:
  - "One module-internal recover-once-and-log implementation reached from both destructive routes, opening no bracket of its own"
  - "authorizedReconciliationScan answering with the pages it destroyed, not only the scan it took"
  - "A three-exit disposition enumeration on prepareWorkingSeed, with each exit's mechanism, disposition and pinning test named"
  - "WorkingSeed.removedPages, subtracted in both inheritedPages branches so the announced basis cannot over-report"
affects: [repair seed preparation, validate-time reconciliation, run progress announcement, continued-session card]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A shared compensation helper opens no bracket: the caller supplies it, so one implementation can serve a caller that already has a bracket open and a caller that needs its own sibling"
    - "Return a Result out of a bracket rather than throwing through it when the failing path may itself have moved the bracketed quantity"
    - "Knowledge an operation produced by ACTING (which files it deleted) outranks any later probe and must be carried, not re-derived"
    - "A recovery is only observable through a TRANSIENT failure; a permanent one leaves both regimes in the same end state and discriminates nothing"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift

key-decisions:
  - "DEC-A: the shared core is `recoveredBlanking` itself, made module-internal and bracket-free; `blankingPass` lost its bracket and the validate route now supplies ONE span around both of its attempts, which is exactly what the seed route's enclosing bracket already is"
  - "DEC-B: `recoveredBlanking` answers with the recovered MANIFEST (nil on a second failure) rather than a Bool, because the seed route must carry the corrected record into the working seed while the validate route only needs the success half"
  - "DEC-C: exit 3 returns `.failure` out of the bracket instead of throwing through it — its compensation can lower the record, and a throw would skip the bracket's second reading and withdraw nothing (G-15-7's masking shape reintroduced through the recovery)"
  - "DEC-D: `scanSucceeded` STAYS sourced from the post-removal rescan (15-67's DEC-F is not reverted); the removed-pages subtraction is what makes a false value unable to over-report, so the seed keeps one probe for the credit rule and the blanking rule"
  - "DEC-E: exits 1 and 2 are decided by ONE predicate (`claimsAnyPage` over the loop's answer) rather than by their distinct mechanisms, because what the record shows is the answer and not the reason"
  - "DEC-F (deviation): Case A stages a TRANSIENT unwritable manifest rather than the plan's permanent one; a permanent failure leaves record and disk diverged in both regimes and its 'next converging pass' heals both identically, so it discriminates nothing"

patterns-established:
  - "Bracket ownership is a documented contract of the helper, not an accident of where it happens to be called"
  - "Count the injected failure AND name what the count is not pinning: a tally that continues past the observation window is asserted as a floor, with the exact pin placed on the release"

requirements-completed: []

coverage:
  - id: D1
    description: "A manifest write that throws after an authorized removal on the seed route recovers once, so the run fails without settling a record that claims a page whose file the pass deleted"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift#testAThrownSeedManifestWriteRecoversTheRecordBeforeFailing"
        status: pass
    human_judgment: false
  - id: D2
    description: "A post-removal rescan that cannot enumerate cannot raise the announced basis above the honest one (claimed pages minus this pass's removals)"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift#testASeedRescanFailureCannotAnnounceMoreThanTheHonestBasis"
        status: pass
    human_judgment: false
  - id: D3
    description: "The healthy-rescan regime announces the same honest basis and its record is corrected on disk — the other side of the discontinuity, unchanged by the fix"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift#testAHealthySeedRescanAnnouncesTheSameHonestBasis"
        status: pass
    human_judgment: false
  - id: D4
    description: "One recovery implementation serves both routes and no withdrawal bracket nests"
    verification:
      - kind: other
        ref: "rg -n 'Validation removed refuted page files the record still claims' AppPackage/Sources/DownloadClient -> 1 call site; rg -n 'withdrawingCountedBasisMovement' on PersistenceNormalize.swift -> 1 call site (3 doc mentions)"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift + DownloadValidationRejectionArmTests.swift (whole suites green with zero expectation edits)"
        status: pass
    human_judgment: false
  - id: D5
    description: "UAT test 2 on device (system card fraction + cancel parity) after the announced-basis change"
    verification: []
    human_judgment: true
    rationale: "15-VERIFICATION.md asks for a physical-device iOS 26 re-run of UAT test 2 once gap 3 closes; the continued-processing card cannot be observed from the simulator"

# Metrics
duration: 76 min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 72: Shared Post-Removal Recovery on the Repair-Seed Route Summary

**`recoveredBlanking` is now one bracket-free implementation reached from both destructive routes, `prepareWorkingSeed` compensates all three of its post-removal exits with written dispositions, and `WorkingSeed.removedPages` is subtracted in both `inheritedPages` branches so a rescan failing after a removal can never presume a deleted page done.**

## Performance

- **Duration:** 76 min
- **Started:** 2026-08-10T12:00:00Z (approx.)
- **Completed:** 2026-08-10T13:15:45Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- **The compensation is shared, not copied.** 15-67 copied the validate route's classify → guard → remove → rescan → blank ORDERING into `authorizedReconciliationScan` and dropped the recovery that ordering obliges. `recoveredBlanking` is now module-internal and opens NO bracket; the validate route supplies one span around both of its attempts and the seed route runs it inside `prepareWorkingSeed`'s already-open bracket. A second copy of the ordering is what dropped the compensation; a second copy of the recovery would have dropped it again.
- **All three exits swept, each with a written disposition and a named mechanism.** Exits 1 (rescan could not enumerate) and 2 (the post-removal loop's own refusal lines) recover once and proceed — self-healing on the run route, because the removed pages are absent from `existingPages` and therefore pending. Exit 3 (a thrown manifest write) recovers once and PROPAGATES: the run must fail, but it may not fail over a lying record.
- **The announcement is structurally unable to over-report.** `authorizedReconciliationScan` answers with the pages it destroyed, `WorkingSeed` carries them, and `inheritedPages` subtracts them in BOTH branches. `scanSucceeded` deliberately stays sourced from the post-removal rescan (15-67's DEC-F stands): what changed is that a false value can no longer promote a deleted page to presumed-done.
- **The validate route's observable behavior is unchanged**, and its own suites are the proof: `DownloadValidationReconciliationTests` and `DownloadValidationRejectionArmTests` are green with ZERO expectation edits. The plan named that as the falsification condition for a wrong factoring.

## Task Commits

1. **Task 1: RED — pin the un-compensated write and the over-reporting announcement** — `1c15cc6f` (test)
2. **Task 2: GREEN — shared compensation, swept exits, never-over-reporting announcement** — `8e263e8d` (fix)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift` (new, 536 lines) — the three cases and both count-gated `FileManager` doubles, owned by the suite rather than added to `DownloadFeatureTestHelpers.swift` (992/1000).
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — `AuthorizedReconciliation` result struct; `authorizedReconciliationScan` deriving and returning `removedPages`; `prepareWorkingSeed` restructured around the three exits; `inheritedPages` subtraction and its re-derived authority order.
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` — `blankingPass` de-bracketed; the validate route's single spanning bracket; `recoveredBlanking` made module-internal, manifest-returning and bracket-free; `claimsAnyPage` made module-internal.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — `WorkingSeed.removedPages`.

## Decisions Made

**DEC-A — the factoring shape chosen.** The shared core IS `recoveredBlanking`, made module-internal, with the bracket lifted OFF it and off `blankingPass` beneath it. The validate route then needed a bracket somewhere, and it takes ONE span around both of its attempts rather than one each. *Derived by argument, and the argument is arithmetic:* the two deltas are computed against `sessionCreditedPages` readings with nothing between them that moves the credited count, and both movements are downward (blanking only lowers), so `max(d1,0) + max(d2,0) == max(d1+d2,0)` — one span withdraws exactly what two siblings would. The bracket opens BELOW the removal, preserving D-G7-01's own exclusion that a deletion must never happen inside one. What the single span buys is the property the plan pinned: `PersistenceNormalize.swift` supplies exactly one bracket wrapper, and its shape now MIRRORS the seed route's instead of differing from it.

**DEC-B — the recovery answers with a manifest.** `recoveredBlanking` returns `DownloadManifest?` (nil after a second failure, having logged). The validate route reads only `!= nil`, byte-identical to its old Bool. The seed route needs the value: the seed's `manifest` is what the announcement's `inheritedPages` and the run's fetch filter read, so carrying the pre-recovery copy would announce and fetch against claims the recovery had just retracted. *Enforced by the type system* — there is no Bool to accidentally discard the manifest behind.

**DEC-C — exit 3 returns `.failure` out of the bracket rather than throwing through it.** `withdrawingCountedBasisMovement` reads the credited count, runs the movement, then reads again; a throw unwinds past the second reading, so nothing is withdrawn. That was harmless before, because the only thing that could throw there was the write that would have done the lowering. It is NOT harmless now: exit 3's compensation can succeed, lowering the record from C to C−k while the monotonic floor keeps holding C — G-15-7's masking shape, reintroduced through the very recovery added to close WR-03. `prepareWorkingSeed` therefore returns `Result<WorkingSeed, any Error>` from the bracketed closure and rethrows outside it. The pre-removal steps (`setupWorkingFolder`, `ensureWorkingManifest`) still throw straight through, unchanged, because nothing they can fail after has moved the record. *Derived by argument* — no test pins the floor on this path (no session exists in Case A's fixture), and it is recorded here as an argued property rather than an asserted one.

**DEC-D — the `scanSucceeded` decision, stated deliberately as the gap asked.** The gap offered two remedies: revert the source to the pre-removal classification, or subtract the removed pages from the pessimistic branch. The SUBTRACTION was chosen and 15-67's DEC-F stands. Reverting would re-split the seed's evidence — the credit rule reading the pre-removal probe while the blanking rule read the post-removal one — which is the exact defect DEC-F closed, and it would also make `scanSucceeded` say "this preparation could enumerate" when its last enumeration failed. The subtraction instead ranks the removal ABOVE the rescan in the evidence order: a page whose file this pass deleted is positively absent by this pass's own act, and no probe's health can overrule an act. The resulting basis can still under-report toward re-fetching, which D-G4-01 and the retirement ledger both choose on purpose; it can no longer over-report at all. *Enforced by test* (D2, from the failing regime) *and pinned unchanged from the healthy regime* (D3).

**DEC-E — exits 1 and 2 share one predicate.** They are distinguished by mechanism (a failed enumeration vs. the loop's own refusal lines) but not by outcome: both hand back a record that still claims a removed page. The seed route asks `claimsAnyPage(in: removedPages)` over the loop's ANSWER, exactly as the validate route does, rather than branching on the reason. A disposition keyed on the reason would be a second rule to keep in step with the loop's refusal lines, which is the class of drift this plan exists to close.

**DEC-F — the deviation on Case A's staging (see Deviations).**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Case A's staging changed from a permanent to a TRANSIENT unwritable manifest**

- **Found during:** Task 1 (RED authoring)
- **Issue:** The plan specified a permanently immutable manifest and asked Case A to assert "record and disk agree for the removed pages … which is RED pre-fix", with the post-fix state being "the run fails as a recoverable failed download AND the divergence is compensated on the next converging pass". Those two cannot both hold. With the write failing permanently the recovery's write fails too, so post-fix the record ALSO still claims the removed page — the agreement assertion is red in both regimes. And the "next converging pass" heals both regimes identically, because by then the removed page is a positive absence that the ordinary guards blank with nothing special-cased; that assertion is green in both. The fixture as written could not discriminate in either direction — the exact failure class this phase has shipped repeatedly.
- **Fix:** The staging models the TRANSIENT the recover-once path exists for, which `recoveredBlanking`'s own doc names ("an enumeration that failed once, a write that failed once, a folder busy for an instant"). `SeedManifestWriteRecoveryFileManager` lifts the immutable flag at the SECOND gallery-folder listing after the removal — positionally-independently the recovery's own fresh scan, since the classification scan precedes the removal, the blanking pass's rescan is the first after it, and only a retry takes a second. Pre-fix nothing retries, the flag is never lifted, and the record goes on claiming a page whose file the preparation deleted.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift`
- **Verification:** RED produced 6 issues on Case A, including a rebuilt coordinator reading `.completed` with `completedPageCount == 2` over a destroyed file; GREEN produces `pages[2] == ""`, `completedPageCount == 1` and `.inactive` on the same rebuilt coordinator.
- **Committed in:** `1c15cc6f`

**2. [Rule 1 - Bug] Case A's post-removal listing tally asserted as a floor rather than an exact count**

- **Found during:** Task 2 (first GREEN run)
- **Issue:** The RED case asserted `postRemovalListingCount == 2`. Post-fix the real count is 4: a recovery whose write SUCCEEDS re-indexes the folder, and `galleryFolderRecord`'s two rendering resolutions (`localCoverURL`, `imageURLs`) list it again. The exact count was a guess about a choreography the case does not own.
- **Fix:** The tally is asserted as `>= 2` ("the recovery's own fresh scan ran"), with the PRECISE pin moved onto `releasedTransientCount == 1` — the transient lifts exactly once, at the second post-removal listing — and the double's doc now names the trailing listings and says why they cannot move which listing releases the transient (they follow the release rather than gating it).
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift`
- **Verification:** Suite green; the load-bearing record/disk assertions were unaffected in both regimes.
- **Committed in:** `8e263e8d`

---

**Total deviations:** 2 auto-fixed (2 bugs, both in the RED fixture rather than in production).
**Impact on plan:** No scope change. Both corrections make the plan's own acceptance criteria reachable — "Case A fails pre-fix with the record claiming pages whose files the pass deleted, observed across a rebuilt coordinator" is satisfied exactly, which the plan's literal staging could not have satisfied.

## Banked Falsifiability

RED (`1c15cc6f`), verbatim from the run:

- Case A (exit 3), 6 issues: `control.postRemovalListingCount → 1` (nothing retried), `control.releasedTransientCount → 0`, `diskManifest.pages[2] → "sha256:done"` (the record claims a page whose file the pass deleted), `diskManifest.completedPageCount → 2`, and across a REBUILT coordinator `reread.completedPageCount → 2` and `reread.displayStatus → .completed` — a persisted, relaunch-surviving complete record over a destroyed file.
- Case B1 (exit 1), 2 issues: `announced.completedUnitCount → 2` against an honest ceiling of 1, and `announced.subtitle → "2 / 3 pages · 1 gallery"` against `"1 / 3 pages · 1 gallery"`.
- Case B2 (healthy rescan): **passed pre-fix**, which is the boundary evidence — the fix moves the failing regime and leaves the healthy one exactly where it was.

Everything the fix does not own also passed pre-fix inside the failing cases: `#expect(throws:)` on the preparation (the atomic write over an immutable target really does throw), the refuted file's absence, the injected listing failure's consumption count, and `pendingPageIndices == [1, 2, 3]`.

## Verification

Serialized, one `xcodebuild` invocation at a time:

1. Gated suites — `DownloadSeedRecoveryTests` + `DownloadValidationReconciliationTests` + `DownloadValidationRejectionArmTests` + `DownloadCoordinatorRepairSeedTests`: **26 tests in 3 suites passed**, with NO expectation edits anywhere in the validate-route suites.
2. Full `FeatureTests`: **957 tests across 22 targets (166 suites), 0 failures** — the 954 baseline plus this plan's 3 cases.
3. Clean app build (`generic/platform=iOS Simulator`, fresh derived data): **BUILD SUCCEEDED, 0 errors, 0 warnings**.
4. SwiftLint `--strict` run DIRECTLY over all 4 touched files (the app scheme's gate does not cover `Tests/`): **0 violations**.

Acceptance-criterion greps:

- `rg -n 'Validation removed refuted page files the record still claims' AppPackage/Sources/DownloadClient` → **1 call site** (`PersistenceNormalize.swift:441`, inside the shared implementation).
- `rg -n 'withdrawingCountedBasisMovement' …/DownloadClient+PersistenceNormalize.swift` → **1 call site** (line 316) plus 3 doc mentions; the validate route still supplies exactly one wrapper.
- `ExecutionSupport.swift` bracket calls → **2, both pre-existing**: `prepareWorkingSeed`'s (line 350) and the announcement's sibling (line 713). None added inside `prepareWorkingSeed`'s body or the shared core.
- `rg -n 'func reconcileWorkingManifestAgainstPageFiles' AppPackage/Sources/DownloadClient` → **1 declaration**; no new blanking loop and no new blanking predicate.

## Issues Encountered

None beyond the two fixture corrections recorded as deviations.

## Outstanding / Non-blocking

- **`DownloadClient+ExecutionSupport.swift` is now 999 of 1000 lines — ONE line of headroom.** The next change to that file must SPLIT it before adding anything; a single added line is a lint ERROR, not a warning. The natural seam is the seed-reconciliation cluster (`AuthorizedReconciliation`, `authorizedReconciliationScan` and `inheritedPages`) moving to its own `DownloadClient+SeedReconciliation.swift`, mirroring 15-67's DEC-E split of `PageFileScan` and the blanking loop. This is recorded as a hard precondition rather than a suggestion.
- **Device item, carried from 15-VERIFICATION.md:** UAT test 2 (system card fraction + cancel parity) needs a physical-device iOS 26 re-run now that gap 3 has closed on the announced-basis path. It cannot be observed from the simulator and is not attempted here.
- **Accepted residual, dispositioned rather than absorbed:** when a post-removal rescan AND the recovery's own rescan both fail (Case B1's regime), the record legitimately goes on claiming the removed page — a failed listing is a non-answer, and non-answers never license destroying recorded hashes. The trail is the `error` log line with the masked gid and the sorted removed indices, and the run route re-fetches the pages regardless, because they are absent from `existingPages`. The case asserts that standing claim explicitly so the disposition is pinned rather than assumed.
- **`DownloadFeatureTestHelpers.swift` remains at 992/1000** and nothing was added to it, as the plan required.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Gap 3 / review WR-03 is closed at its root: the compensation has one implementation reachable from both routes, every post-removal exit on the seed route is swept with a written disposition, and the announced basis is structurally unable to exceed the honest one. Gaps 1, 4 and 5 remain with their own plans (15-73 onward), and 15-74's forthcoming withdrawal-depth detector is what will enforce the non-nesting discipline this plan relied on by argument.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
