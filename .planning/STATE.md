---
gsd_state_version: 1.0
milestone: v3.0.0
milestone_name: milestone
current_phase: 15
current_phase_name: continued-background-downloads
status: executing
stopped_at: Completed 15-70-PLAN.md
last_updated: "2026-08-10T12:16:46.573Z"
last_activity: 2026-08-10
last_activity_desc: "Plan 15-69 executed: verification gap 4 closed — WR-04 and WR-05, the two caller-side consequences of the CR-04 narrowing. `retryPages`' inadmissible-selection exit now returns `.fileOperationFailed(String(localized: .downloadStoreInvalidPageSelection))` while the absent-gallery and absent-folder exits KEEP `.notFound` (DEC-A: absence is what both of them mean), so no localized message conflates \"this download is gone\" with \"the pages you named are outside this gallery\". `normalizeFetchedPayload` is now `throws(AppError)`: a non-nil selection the freshly fetched page count empties raises the named page-selection-outdated error (DEC-B), which propagates through `fetchNormalizeAndDownload` to `processDownload`'s existing catch and settles via `persistFailure` — confirmed line by line to precede `performDownload` entirely, so no working seed, announcement, cover download or `finalizeBatchResult` whole-manifest measurement runs, and the gallery no longer settles into a persistent `.error` record for work nobody requested. The inspector's `retryPagesDone(.failure)` arm sets `state.toast` through a private `AppError.retryFailureToast` mapping (payload for `.fileOperationFailed`, `alertText` otherwise, `localizedDescription` as the never-empty fallback) beside the existing `toastConfig`, wiring the toast surface the view already presents. Two module-local catalog keys added in all six locales, both plain strings (no numeric specifier). Three-state consumer sweep enumerated from source with dispositions for `shouldSchedule`'s gate, the announcement gate, `downloadCoverImage`, `finalizeBatchResult`/`missingFinalizedPageIndices` and the `rawPageSelection` bridge; `pendingPageIndices` keeps its present-empty branch as defence in depth. RED banked 10 verbatim issues; the full-suite gate caught an un-swept assertion (`DownloadRetryUpdateFallbackTests.swift:140` pinned `.notFound` for the update record, which is refused by the SAME exit). Full FeatureTests 950/0 across 22 targets (downloads 431 in 72 suites), clean build 0 warnings, SwiftLint --strict 0 violations in 120 files. Commits `34984354` (RED), `1d966aee` (GREEN). OPEN and independent: CR-01 (unbracketed `advanceQueueIntentGeneration`, gap 1) and gap 2's read-path half; IN-02 (two localized-key spellings in `DownloadStore+Operations.swift`) unrouted."
progress:
  total_phases: 16
  completed_phases: 13
  total_plans: 248
  completed_plans: 241
  percent: 81
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-22)

**Core value:** The load-bearing paths — fetch, parse, read, download galleries — keep working; every task is a foundation change held to behavior/appearance parity.
**Current focus:** Phase 15 — continued-background-downloads

## Current Position

Phase: 15 (continued-background-downloads) — EXECUTING
Plan: 70 of 77
Status: Ready to execute — round-20 gap + follow-up plans 15-70..15-77 planned
Last activity: 2026-08-10 — Plan 15-69 executed: verification gap 4 closed — WR-04 and WR-05, the two caller-side consequences of the CR-04 narrowing. `retryPages`' inadmissible-selection exit now returns `.fileOperationFailed(String(localized: .downloadStoreInvalidPageSelection))` while the absent-gallery and absent-folder exits KEEP `.notFound` (DEC-A: absence is what both of them mean), so no localized message conflates "this download is gone" with "the pages you named are outside this gallery". `normalizeFetchedPayload` is now `throws(AppError)`: a non-nil selection the freshly fetched page count empties raises the named page-selection-outdated error (DEC-B), which propagates through `fetchNormalizeAndDownload` to `processDownload`'s existing catch and settles via `persistFailure` — confirmed line by line to precede `performDownload` entirely, so no working seed, announcement, cover download or `finalizeBatchResult` whole-manifest measurement runs, and the gallery no longer settles into a persistent `.error` record for work nobody requested. The inspector's `retryPagesDone(.failure)` arm sets `state.toast` through a private `AppError.retryFailureToast` mapping (payload for `.fileOperationFailed`, `alertText` otherwise, `localizedDescription` as the never-empty fallback) beside the existing `toastConfig`, wiring the toast surface the view already presents. Two module-local catalog keys added in all six locales, both plain strings (no numeric specifier). Three-state consumer sweep enumerated from source with dispositions for `shouldSchedule`'s gate, the announcement gate, `downloadCoverImage`, `finalizeBatchResult`/`missingFinalizedPageIndices` and the `rawPageSelection` bridge; `pendingPageIndices` keeps its present-empty branch as defence in depth. RED banked 10 verbatim issues; the full-suite gate caught an un-swept assertion (`DownloadRetryUpdateFallbackTests.swift:140` pinned `.notFound` for the update record, which is refused by the SAME exit). Full FeatureTests 950/0 across 22 targets (downloads 431 in 72 suites), clean build 0 warnings, SwiftLint --strict 0 violations in 120 files. Commits `34984354` (RED), `1d966aee` (GREEN). OPEN and independent: CR-01 (unbracketed `advanceQueueIntentGeneration`, gap 1) and gap 2's read-path half; IN-02 (two localized-key spellings in `DownloadStore+Operations.swift`) unrouted.
Next: execute waves 70-77 (/gsd-execute-phase 15) — 15-70..15-76 autonomous, 15-77 (swipe Candidate 0) ends on a BLOCKING owner device checkpoint; then verification round 21. **ROUND 20 RAN 2026-08-10** (review 3c84d648, verification d83b4d71; 2/4 — SC1/SC4 stand, SC2/SC3 fail; all five 15-65..69 closures independently judged closed at their roots): 5 gaps found. (1) BLOCKER regression → 15-70: the delete/rename confinement predicate (`normalizedUserFolderName(rawName) == rawName`) refuses File-Sharing-created folder names the app's own listing produces (`Art  Books`, ` Photos`, `Manga\Vol1`, `Misc etc.`) — delete broken by 15-68, rename since 15-63; fix moves the PREDICATE (admission test that cannot refuse a listed name, every structural refusal kept, destinations keep normalizing), sweeps every name→URL site incl. moveDownload's near-duplicate hazard, adds the POSITIVE admission catalog (own-name non-normalized folders delete AND rename with convergence), deletes dead `removeFolder(relativePath:)`. (2) WR-02 residual → 15-71: `materializeRepairSeed`'s source scan deletes with `discardingRejected: true` while nothing blanks the SOURCE manifest (survives every non-completing run; mtime-bumped source can WIN `deduplicatedDownloadIndex`); fix takes the non-mutating default + per-site entitlement census + interrupted repair-with-rename regression pinning source record/disk agreement and index-winner truthfulness. (3) → 15-72: 15-67's seed route copied the validate route's classify-guard-remove ordering but dropped its compensation (three post-removal exits unhandled, unlogged) AND re-sourced `scanSucceeded` from the post-removal rescan, flipping `inheritedPages` to over-reporting on a post-removal rescan failure; fix lifts `recoveredBlanking` to ONE shared implementation (sibling-only bracket law preserved), sweeps all three exits with dispositions, subtracts `WorkingSeed.removedPages` in `inheritedPages` so over-reporting is structurally impossible, adds failed-write and count-gated failed-rescan regressions. (4) → 15-73: `toggleDownloadPauseDone(.failure)` still silent, the un-swept sibling 25 lines below the WR-04 fix; nine-action `…Done(.failure)` disposition sweep across BOTH reducers, `retryFailureToast`→`actionFailureToast`, both-sides TestStore pins. (5) → 15-74 + 15-75: unowned invariants — 15-65-SUMMARY's FALSE 'proved by construction' nesting claim (the bracket closure is actor-isolated, a nested synchronous advance compiles) corrected + honest source docs + `reportIssue` withdrawal-depth detector; caller-less `downloadsTestFiles(in:)` deleted with census docs rewritten from source; explicit 1s bounds at the two missing-notification detectors; 15-75 converges all 19 localized-key sites on the `.RLocalizable.` majority in one mechanical pass (IN-02, carried three rounds, now routed). PLUS the owner-directed UAT-test-6 deferrals: 15-76 logs→`Logs` one-time migration (literal-name detection, case-only rename, both-exist destination-wins merge; ordering stated as the race-tolerance derivation, not a before-any-write guarantee) and 15-77 swipe-deletion choreography — deep research APPENDED to 15-RESEARCH.md (c4ebd21a; root cause = destructive-role optimistic collapse; native hold-open CONFIRMED ABSENT at iOS 26 after a full docs-index sweep; UIKit's deferred `UIContextualAction` completionHandler unreachable from SwiftUI List; full three-part fidelity = custom swipe container only): Candidate 0 ONLY (role drop + `.tint(.red)` + identity-scoped confirmed-removal animation + reappearance regression; context menu keeps its role), `autonomous: false`, blocking owner device checkpoint carrying the research's gate/kill criteria verbatim incl. VoiceOver custom-actions parity; on kill, Candidate 1 (custom swipe container, 9 gate criteria) routes to a FRESH planning round UNBUILT. Plans committed 9beebb8f + checker-revision 06236e01 (round 2 PASSED after fixing an unfirable rg gate — unescaped parens made `rg -n 'timeout: .seconds(1)'` unmatchable — splitting 15-74's localization task out as 15-75, and replacing the logs plan's ordering claim; a same-class sweep also fixed one 15-73 gate); decision coverage 11/11. Prior context: verification round 20 (code review + /gsd-verify-phase 15). **ROUND 19 RAN 2026-08-10** (review df007657, verification ee9df01c; 2/4 — SC1/SC4 stand, SC2/SC3 fail): 15-61..64 closed the rename-confinement and CR-04 retry-widening blockers at their roots, but the round found 4 gaps, all planned this round (plans committed 1d1953a4; checker PASSED 0 issues; decision coverage 11/11). (1) CR-01 → 15-65: the 15-61 generation fix made `advanceQueueIntentGeneration` an UNBRACKETED downward mover of the credited session basis — `sessionCreditedPages` drops recorded→0 on a generation mismatch, none of its four call sites is enclosed by `withdrawingCountedBasisMovement`, so the stale monotonic floor absorbs the next N pages of genuine work (the G-15-6/G-15-7 masking the module doc forbids); fix wraps the increment inside the function ITSELF so every present and future site is bracketed by construction, audits sibling composition at all four sites, adds a one-at-a-time keeper regression asserting the pushed numerator moves on the FIRST post-requeue page (a single-flush test discriminates nothing), and re-audits the invariant doc at ContinuedSession.swift:230-236 against source. (2) CR-03+WR-01+WR-02 → 15-66/15-67: ordinary read paths still DELETE rejected page files while reconciling nothing — `loadManifest`→`sanitizeLocalFilesIfNeeded`→`scanCompletedFolder` runs two probes purely for their deleting side effect (results discarded), and `storage.validate` + `resumeMode` take the same `discardingRejected` TRUE default, so a zero-byte page is deleted on reader open while its hash stays non-empty across relaunch (CR-01's end state reached by opening the reader instead of tapping Validate); 15-66 flips the family default to non-mutating (mutation opt-in by name; rg-gated exhaustive over all 10 defaulted sites), deletes the side-effect-only `scanCompletedFolder` sweep, records a full caller-disposition table, and pins zero-byte `loadManifest`/`resumeMode` non-mutation from both sides; 15-67 measures the wholesale blanking guard over the combined positively-refuted set (WR-01: a per-page hold could otherwise relax the all-or-nothing threshold below the guard's basis), gives the repair-seed route the validated-record pass's classify-authorize-remove ordering so refuted surviving bytes cannot hold a claimed hash forever (WR-02), corrects the two false doc claims that rested on rejections being deleted, and pins both threshold sides with a crossing fixture. (3) CR-02 → 15-68: `deleteFolder` is the un-swept sibling of the rename fix — it builds its target from an unconfined caller name and `removeFolder`'s guard is lexical prefix containment only, so a nested name like `"MyFolder/[123_abc] Title"` recursively deletes a gallery folder while `downloadIndex`, the queue store and the background-task store keep its entries; fix routes EVERY user-folder mutation (delete, create, move destination, enqueue parent) through the store-owned confined boundary — new `deleteUserFolder(named:)` re-checking confinement and directory type inside the same operate closure, `renameUserFolder`'s ordering — makes `userFolderURL` unreachable as a mutation target, symlink-hardens `removeFolder`, adds the six-argument delete escape suite, and asserts three-store record convergence on both refused and legitimate outcomes. (4) WR-04+WR-05 → 15-69: a refused retry is a silent no-op (`retryPagesDone(.failure)` sets no toast; `.notFound` conflates gallery-gone / folder-gone / selection-out-of-domain) and a selection that only collapses at fetch time settles the run into a persistent `.error` record for work the user never requested; fix adds a distinct localized inadmissible-selection error surfaced as a failure-branch toast (all six locales), makes `normalizeFetchedPayload` throw a named collapse error before any run work, and sweeps every consumer of the three-state selection contract — openly superseding 15-64's preserve-empty return contract with the no-widening property re-pinned from both sides. WR-03/IN-01/IN-02 remain non-blocking INFO residuals outside the gap contract. Round 19 ran over 15-60's property suite, 15-59's display basis, 15-58's content arm, 15-57's affordances, 15-56's validation reconciliation, 15-55's coverage count and 15-54's redesign. **15-60 CLOSED G-15-SSOT's TEST half** — the reason G-15-5 shipped green through 888 tests was never a missing fix but a missing PROPERTY: every suite in the target pinned INSTANCES and the dead-end state fell between them. `DownloadManifestSSOTInvariantTests` (new, 849 lines, 3 `@Test(arguments:)` families × a 9-case named table = **27 case instances**) now states the properties. Family 1, count-basis agreement: badge numerator, rendered `displayCompletedPageCount`, inspector `.downloaded` set, inspector header, `hasDownloadedPages` and `isIncomplete` are one manifest-derived value in every regime, in-session AND on a fresh coordinator over the same storage; the per-regime EXPECTED values are carried in the table, because agreement alone is satisfied by a derivation returning zero everywhere. Family 2, derivation totality, made EXECUTABLE rather than argued: files are deleted/corrupted/planted behind the app's back, a FULL production rescan (`reloadDownloadIndex` — the pull-to-refresh route, deliberately the strongest form of the clause) is run, and every displayed quantity plus `canTogglePause`/`canRetryPages`/`canValidateImageData`/`retryablePageIndices` must be bit-identical — so any display or predicate that consults the disk fails by construction; the mutation's own observability is pinned from the OTHER side (`fileURL` must go nil for a deleted page and appear for a planted one), because an invariance claim over a mutation that silently failed passes vacuously. The sensor's boundary is pinned both ways: gate OPEN → the state must move to the regime 15-58's rules predict (reconciled, or refused with the file still on disk, re-pinning D-SSOT-02's ordering); gate CLOSED (an honestly-incomplete record) → nothing moves at all. Family 3, no-dead-end, enforced by DRIVING production entry points in production order (`togglePause` → `retryPages` → validate-then-start) and requiring `.queued` under the mode the record's shape predicts, with the retry basis asserted NON-EMPTY before the call and the carried selection after it — predicates alone are what G-15-5 had. The terminal boundary is pinned from the other side: a clean complete record offers no resume-shaped start and `togglePause` REFUSES it at the entry point, while the sensor stays reachable. **D-SSOT-09** scopes the continued-processing card's `X / Y` series OUT: its numerator is the run-owned MEASURED `RunProgressBasis` and its denominator a session ledger, so unifying it into the record basis would reintroduce the inference the round-18 redesign deleted — and the exclusion is STRUCTURAL, every fixture uses `BackgroundProcessingClient.noop` so no push is observable from the suite at all. **The suite found NOTHING against unmodified post-15-59 production, and that is the result**: no production file was touched by any commit, no assertion was weakened, and it would have caught G-15-5 in three independent places. Six pruned combinations are recorded with reasons (partial-claim × validated is unreachable through the sensor's gate; queued × relaunch is session state; all-gone × durable is refused by D-SSOT-02; `.active` as a target would race its own fixture; `.updateAvailable` is a remote-version concern; a download-level `.error` from a run's fatal exit is a different signal family whose forward affordance is Detail's retry button, not the inspector's three). Commits d1eab180 (family 1+2, generator, shared-fixture extraction), bcb564b4 (family 3 + full-suite gate) and e02bf4b4 (a post-gate rename, `SSOTStateProbe` → `SSOTStateSnapshot`, with both gates re-run from scratch); full FeatureTests green (397 downloads target in 71 suites, +3/+1; whole plan 906 passed / 0 failed), clean app-scheme build, SwiftLint 0 violations over both files. NO plan-correction checkpoint was needed. The declared conditional file DID fire: the four fixture builders duplicated across two suites now live on `DownloadFeatureTestHelpers.swift`, which is at **970 of the 1000-line limit** — the next addition there needs a split. Open, non-blocking: the two pre-existing private copies stay (undeclared files, collapsible as a pure deletion), alongside 15-59's and 15-58's prose residuals. **15-59 CLOSED G-15-SSOT's DISPLAY half**, which 15-58 left standing: **D-SSOT-07** — `buildInspectionPages` derived a page's status from a LIVE file-presence probe, a second display basis beside the badge's persisted-hash count, and the two diverged in exactly the G-15-5 window (files deleted outside the app, record claiming complete, badge 36/36 while the page list read 10 pending). The probe is DELETED: status is now `(manifest hash, recorded page failure)` alone — non-empty hash → `.downloaded`, else recorded failure → `.failed`, else `.pending` — so the inspector's downloaded set IS the set `completedPageCount` counts and the helper makes no file-system call of its own. The directory listing survives only as a rendering-resource resolver for `relativePath`/`fileURL` (nil when absent), documented at the site with the WHY: pre-validate the inspector shows the record's CLAIM (stale but honest, and consistent with the badge), and Validate is the single tap that senses and reconciles durably. **D-SSOT-08** — the composition hazard that basis change created, and the sharpest finding of the plan: a manifest-derived wholesale-refusal record has NO pending page and NO failed page (it claims everything), so 15-57's `failed ∪ pending` retry basis collapses to EMPTY for precisely the family 15-57 existed to give a start — the button still present, with nothing in it, and no existing test failing. The basis at `.error`/`fileOperationFailed` is therefore the FULL page-index set: the signal is operation-level and record-wide, no per-page subset is derivable from it, the selection is a REQUEST rather than a verdict (the repair run's working seed keeps usable files and its fetch filter re-downloads only what is missing), and outside the shape the basis stays failed-only, pinned from both sides. The set is read off `pages` rather than `1...pageCount` — equal by construction, and the range form would trap on a zero-page record (G-15-14). `pendingPageIndices` was DELETED with its last consumer. The hazard is pinned on the production path: with Task 1 landed and Task 2 not, the arc failed with `displayStatus → .error`, `lastError` still set and `queuedPageSelections` empty — the G-15-5 dead end re-created — and the case now asserts the basis NON-EMPTY before driving `retryPages`. A free consequence worth knowing: `hasDownloadedPages` (which gates the inspector's Validate row) is now `completedPageCount > 0`, so Validate is ENABLED for an all-files-deleted gallery where it used to be greyed out — the single sensor was previously unreachable from the screen reporting the problem. Full 13-row consumer sweep recorded in the summary (2 changed, 11 unchanged with reasons; the repair-preparation scan path untouched by prohibition). Commits 654a912e (derivation + basis suite) and ac6edbd8 (full-set basis + rewritten pins); full FeatureTests green (394 downloads target in 70 suites, +4/+1), clean app-scheme build, SwiftLint 0 violations over all 4 files. Banked falsifiability: 2 of 4 Task-1 cases RED (5 verbatim issues) with the post-validate convergence case passing pre-fix as anticipated; 3 Task-2 cases RED with 9 verbatim issues while both excluded-regime pins passed unchanged. NO plan-correction checkpoint was needed. Open, non-blocking: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01 (every factual claim in the sentence is still true), and 15-58's `DetailDownloadRepairPredicateTests.swift` lines 13/52 residual stands — both comment-only, both undeclared files. **15-58 CLOSED G-15-SSOT**, the last per-page state basis living outside the manifest, on the owner's 2026-08-09 design extension: **D-SSOT-01** — `validateImageData` is the only path that re-reads page bytes, so a readable file whose FRESH hash mismatches its recorded hash is a positive, page-scoped determination of the same strength as a positive absence, and it now blanks durably; a corrupt-in-place gallery therefore reaches the identical end state a missing-file gallery does (`.inactive`, converged count, `canTogglePause`, `resumeMode == .repair`), re-derived by a fresh coordinator over the same storage root. **D-SSOT-04** — the refuted file is REMOVED under `validatedChildURL` containment, and this is not optional: `resolveSourceIfNeeded` filters a run's pending pages down to those whose file is MISSING (so a repair would skip a blanked-but-present page) and `finalizeDownload`'s `addingCurrentFileHashes` merge hashes exactly the blank-hash pages from the files on disk (so the stale bytes would be re-recorded as truth and validate would pass forever). Removal converts the shape into the positively-absent one, so the fetch filter, the finalize merge, the working-seed preparation and the blanking loop all handle it with ZERO new branches — and the ONE loop (`reconcileWorkingManifestAgainstPageFiles`) is still the only blanking path, untouched, with its three refusal lines inherited. **D-SSOT-02** — the all-or-nothing guard now runs over the COMBINED prospective blank set (positively absent ∪ positively mismatched) BEFORE any removal or blanking, because a systematically wrong hash pipeline would mismatch every readable page; with an empty mismatch set it reduces byte-for-byte to the presence arm's guard, which is why 15-56's cases pass untouched. The ordering is proven, not asserted: the refusal case pins the mismatched file STILL ON DISK after the refusing validate, which is only possible if the guard preceded the first destructive act. **D-SSOT-03** — a read failure is a per-page HOLD (hash kept, file kept, entry kept), never blanking authority; the unreadable-is-corrupt equivalence survives only in validate's REPORTING. **D-SSOT-05** — `validationErrors` is now an operation-level signal ONLY: it says the pass could not produce trustworthy evidence for every claimed page (failed listing, unreadable page, failed removal, wholesale refusal, thrown write), never anything about the record. **D-SSOT-06** — AGENTS.md's manifest-SSOT invariant was revised in ONE clause, since its refusal example ("a presence scan cannot license blanking an existing file's hash") became false. Evidence is gathered FRESH, and the suite proves it: the mixed case stages a missing page 1 and a corrupted page 3, the verdict short-circuits naming page 1 only, and page 3 is still reconciled — which a verdict-shaped implementation could not do. No-laundering is pinned structurally (`expectNoBlankHashedPageKeptItsFile` walks every blank-hash page in three cases). Commits 7586dc26 (content arm + four regime cases) and 7a01604f (contract sweep: validationErrors doc, AGENTS.md, D-G5D-01 rationale); full FeatureTests green (390 downloads target, +4), `DownloadLogPrivacyInvariantTests` green in the same run (NO log line was added anywhere — the plan authorized none), clean app-scheme build, SwiftLint 0 violations over all 5 Swift files. Banked falsifiability: 3 of the 4 new arms failed pre-fix (10, 5 and 3 verbatim issues) while 15-56's three presence-arm cases PASSED unchanged — and the combined-wholesale arm ALSO failed pre-fix with 5 issues, which is D-SSOT-02's substance: pre-fix the guard saw only the absent page, so `1 < 2` passed and it PARTIALLY reconciled a shape that must refuse entirely. NO plan-correction checkpoint was needed; the conditional split file (`DownloadValidationContentArmTests.swift`) did NOT trigger (601 lines vs the 1000 limit) and was correctly not created, and no existing test pinned mismatch-stays-refusal (the stance lived only in prose, rewritten in place). Open, non-blocking, recorded in the summary with file+line: `DetailDownloadRepairPredicateTests.swift` lines 13 and 52 still name corrupt-in-place as a complete-claiming family member — comment-only, left out of scope as an undeclared file. 15-57 CLOSED the AFFORDANCE half of G-15-5, so no validated shape is left unstartable: **D-G5C-01** widens the inspector's retry basis — the new `DownloadInspection.retryablePageIndices` is the failed set unioned with the pending set exactly when `displayStatus == .error && lastError?.code == .fileOperationFailed`, and the failed set alone everywhere else — because an externally-deleted page derives `.pending`, never `.failed`, so the old failed-only basis sent an EMPTY selection for precisely the refusal family 15-56 left on that surface, whose Resume path `.error` hard-closes. The widening is bounded by that conjunction on purpose: outside it, pending pages are what Resume exists for, and admitting them would grow a second page-selection-shaped resume. `canRetryFailedPages` is replaced by `canRetryPages`, defined as the non-emptiness of the very array the button sends, so the gate can never enable an empty payload. NO new machinery was needed — the arc case PASSED PRE-FIX at the client layer (0.089s), which is the finding worth carrying: `retryPages` already accepted an arbitrary selection, already cleared `validationErrors` at enqueue and already resolved `.repair`; the affordance wiring was the entire gap. The outranking hazard is pinned on the production path — a complete-claiming record with all files gone, run through `validateImageData` to install the transient error, then `retryPages`, asserting `.queued` (reachable only if the entry was cleared, since `validationErrors` outranks both `activeGalleryID` and queue membership), `queuedMode == .repair` and the carried selection — using 15-56's blocker-gallery form (runner parked on `BlockingRunnerControl.park()`, `control.started()` awaited) so the status is stable rather than momentarily true. **D-G5D-01** sweeps Detail's repair predicate: `downloadNeedsRepair` now requires `completedPageCount < pageCount` instead of `== 0`, a conjunct that could only hold AFTER a repair run's blanking loop had emptied the record and never at the moment a user faced the button — so a mid-run file failure with 26 of 36 pages landed no longer routes to the destructive redownload as its only option; zero-completed records satisfy the new conjunct trivially, making the swept case a strict superset. A COMPLETE-claiming `.error` record deliberately KEEPS `.redownload` (wholesale-unverifiable claims and corrupt-in-place files are not fixed by a presence-based repair; the inspector's D-G5C-01 retry is the surgical alternative), with that boundary's reasoning written on the property. The dead row-retry predicate (`canRetry`, zero consumers) was deleted, and the basis-suite comment that argued from the old zero-completed conjunct was RE-DERIVED: the claim now rests on the failure-code conjunct instead (a networking-shaped error still resolves `.redownload` however many pages landed), and the scenario itself was unchanged. Commits fbbf384f (basis + gate + view + arc) and cb4c73d7 (predicate + deletion + comment); full FeatureTests green (386 downloads target, +5), clean app-scheme build, SwiftLint 0 violations over all 7 touched files (test files linted with the standalone binary, since the app scheme does not lint `Tests/`). Banked falsifiability: the basis cases were RED as 12 compile-error sites, and the D-G5D-01 truth table's 26-of-36 row FAILED pre-fix while the other four rows PASSED — the change is provably confined to the swept row. NO plan-correction checkpoint was needed this time; both clauses that read like conditionals resolved against real source (the basis tests took the plan's own stated fallback into `DownloadRetryPagesTests`, which is also the only placement whose file set closes over the task's `-only-testing` gate). Left for the owner, non-blocking: whether the retry button's label should name missing pages as well as failed ones — one catalog key, no behavior change. 15-56 CLOSED G-15-5's VALIDATE-TIME half (the run-time half was D-G5-01's): **D-G5B-01** makes a `.missingFiles` verdict reconcile the record it judged — `validateImageData` re-reads the disk manifest, takes ONE fresh `storage.pageFileScan`, and runs the existing `reconcileWorkingManifestAgainstPageFiles` inside a sibling `withdrawingCountedBasisMovement` bracket, so the finding lands in the manifest (the SSOT) rather than beside it in `validationErrors`. Blanking evidence is the SCAN, never the verdict — `storage.validate` short-circuits at its first failing page, so its message names one page while the missing SET is what must be blanked. `validationErrors` is CLEARED on the durable arm (it outranks queue and manifest in `displayStatus`, so a leftover entry pins `.error` over an honest record and leaves it unstartable — the diagnosis's flagged hazard) and KEPT on every refusal, which narrows it to the refusal family's surface. Downstream is all pre-existing machinery: `.inactive` derives, `canTogglePause` accepts, `resumeMode` resolves `.repair` through `isIncomplete`, and the manifest write + `updateDownloadIndex` carry it across relaunch. The loop is SHARED not duplicated (1 declaration, 2 callers), so the three refusal lines are inherited verbatim. Two dispositioned residuals, both decisions: the wholesale shape (every claimed page absent) still refuses and reads `.completed` after relaunch until re-validated — the irreversibility defence working as designed, with its in-session affordance landing in 15-57; and corrupt-in-place (file present, bytes wrong) stays on the refusal surface because a PRESENCE scan cannot license destroying the hash of a file that exists. Commits 45bd2ba9 (source + contract docs + the piecewise suite) and 99ec1b19 (the start arc); full FeatureTests green (381 downloads target, +1), clean app-scheme build, SwiftLint 0 violations over all 6 touched files. Banked falsifiability: the durable arm failed pre-fix with 8 verbatim issues (status `.error`, `pages[2]` still `sha256:done`, count 3, `canTogglePause` false) while the refusal arm PASSED pre-fix — the boundary evidence. TWO plan-correction checkpoints were again raised and fixed BEFORE any code: (a) 19d463d8 part 1 — the Step-2 instruction to fix `resumeMode`'s comment targeted `DownloadClient+SchedulingHelpers.swift`, which neither `files_modified` nor the task's `<files>` declared (same defect class as 1ca32386 for 15-55); proof that its conditional fired was supplied (line 51 enumerated a single blanker; case (b)'s predicate would mis-sort a validated-and-refused record into (b) instead of (a)), and the file is now declared with the instruction unconditional; (b) 19d463d8 part 2 — the arc's `displayStatus == .queued` pin RACED, because `togglePause`→`resume`→`scheduleNextIfNeeded` assigns `activeGalleryID` before returning and `displayStatus` reads it ahead of queue membership, so the status is `.active` until `finishActiveTaskIfOwned` nils it a turn later; resolved by a BLOCKER gallery holding the slot on a NAMED suspension point (`BlockingRunnerControl.park()`'s `withCheckedContinuation`, released in teardown) with `control.started()` awaited first, making the occupancy production-issued. That is the THIRD instance this round of a test keyed on a value whose derivation basis was still moving. One self-correction inside 15-56: a `logger.error` added to the reconciliation's catch tripped `DownloadLogPrivacyInvariantTests` (inventory 10→11); the plan states the second caller adds NO new log content, so the line was removed rather than the inventory table edited. 15-55 CLOSED G-15-2C, the device-reported stale gallery count: **D-G2C-01** makes the PUSHED count the denominator's coverage (live schedulable galleries + `retiredSessionPages` entries > 0), computed after `reconcileRetiredSessionPages` by one shared `coverageGalleryCount` that BOTH subtitle writers call (`pushContinuedSessionProgress` and `ensureContinuedSession`'s start submission), so a two-gallery run reads `2 galleries` on EVERY frame and nothing depends on the OS repainting the push issued immediately before `setTaskCompleted` — the render race is removed, not raced harder. A zero-page retirement is NOT counted (boundary pinned both sides on production drains). DEC-B: the snapshot-internal `galleryCount` stays live-only as the coverage sum's live half. Commits 8211abd9 (source + contract docs + boundary suites) and 53d05928 (sweep); full suite 893/0 across all targets (379 downloads), two consecutive green runs, clean app-scheme build with zero lint. TWO plan-correction checkpoints were raised and fixed BEFORE any code: (a) 4de9057a — the cancel-drain boundary pin lives in DownloadContinuedSessionExpirationTests, not the primary suite, and its two-session series changes on BOTH drains; (b) 4b8eb704 — `-only-testing` filters by SUITE while LedgerRefusalTests and RunProofTests are `extension DownloadContinuedSessionLedgerTests` (and ReconciliationTests extends BasisTests), so a task's file ownership must close over its gate's suites; same round found a THIRD literal category, a SYNCHRONIZATION PREDICATE — a `waitUntil` keyed on the gallery count crossing at a departure, which the coverage basis holds constant, so it hung to its deadline; rekeyed to the denominator crossing 16→12 and back to 16. Root cause of the rounds-8..17 loop, Root cause of the rounds-8..17 loop, per the owner-commissioned investigation: the session numerator was INFERRED from the index record (a reading of cumulative disk state, not of session progress) and then patched with a correction tower — trust set (G-15-23), run-owned proof (G-15-26), page-debt subtraction (G-15-30), completeness guard (G-15-34) — and every correction's on/off boundary was a discontinuity that housed the next round's defect. 15-54 (design doc 15-54-PLAN.md, summary 15-54-SUMMARY.md) replaces the inference with a MEASURED run-owned numerator: `RunProgressBasis` (inheritedPages ∪ (initialPendingPages ∖ outstandingPages)), announced at preparation inside its own sibling D-G7-01 bracket, decremented only at the single flush landing point, retired at the run's exit behind the freeze; `inheritedPages` values the record's claims by the blanking loop's positive-signal evidence rule carried on WorkingSeed (scan succeeded → existing ∪ (claimed ∩ unprobed); scan failed → existing ∪ claimed; complete-reading record forfeits the run's own pending pages); `observedIncompleteSessionGIDs` purified to a true observation set; `provenPageWorkRunPageDebts` and the guarded subtraction deleted. Monotone + continuous by construction — the two properties G-15-34 demanded. Closures: G-15-34 at a6105b0b (+ new series pin testAnIncompleteRefusalRepairsPushesClimbFromTheEvidence, announce 0/6 climbing to 6/6, no rewind); G-15-35 at d155236a (performCacheCapture routes through flushManifestPageProgress, orphan store overload deleted); G-15-36 at 5df56a8e (noop suspends at all three endpoints, census walks its module); G-15-37 at d4d568c6 (T-15-09/T-15-03/trust-boundary rewritten to the per-process registeredIdentifier); G-15-38 at a6105b0b (landPageFiles delegates to pageResults). Full suite 888/0 (374 downloads target), two consecutive green runs, lint clean. STILL OPEN independently: 15-UAT.md test 2 physical-device iOS 26 re-run (.redownload + .repair in a multi-gallery queue — NOTE the expected observation changed TWICE: an incomplete-repair series now CLIMBS from the announce instead of freezing at the record's claim (15-54), AND the final subtitle now reads `N / N pages · K galleries` where K counts every gallery that contributed pages to N, so a two-gallery run must read `2 galleries` on every observed frame including the drain — `1 gallery` there is now the failure signal, and `0 galleries` is correct only when the queue drained having finished nothing (15-55)); 15-48's overlapping-run gating owned by no test; reused-identifier second submission (15-51) has no device observation; G-15-33's historical record still carries the round-16 false-premise quotation (historical, left). Known accepted transient (follow-up CLOSED 2026-08-08, on the TEST side): the series assertions were stricter than the production guarantee in TWO ways, and the investigation found the recorded 5→0-shaped inversion was the second rather than the first. (1) Delivery order at the client seam is not computation order — two pushes can be in flight across `updateProgress`'s main-actor hop — so one displaced observation can be recorded ahead of the value superseding it (the drain doc's "one stale-shaped push"). (2) A D-G7-01 withdrawal moves the accounting basis DOWN on purpose, so the numerator is monotone only WITHIN a basis regime; `testAnIncompleteRefusalRepairsPushesClimbFromTheEvidence` opens on the record's claim of four and the announcement corrects it to the evidence's zero, so any convergence push landing in that window — which scheduling alone decides — read as a rewind. Serializing seam issuance was REJECTED, reasons recorded on `pushContinuedSessionProgress`: it does not close (2) at all (the correction is already in computation order), concurrency at that seam is load-bearing and pinned by `testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain` and `testAHeldProgressPushCannotRepaintASuccessorSessionsCard` (a chain deadlocks both, because the client's identity guard — not an ordering queue — is what resolves a late push), and chaining would couple every liveness report to the slowest preceding hop. Landed instead: `expectTheCompletedSeriesNeverRewinds` → `expectTheCompletedSeriesNeverLosesGround`, which accepts exactly one displaced push the next observation repaints and refuses an unrepainted dip, a second dip and a trailing dip (all four arms pinned by the new `DownloadProgressSeriesGuardTests`); and the incomplete-refusal case now CROSSES the discontinuity on purpose — the claim regime staged through `scheduleNextIfNeeded` and quiesced — asserting per regime. Sensitivity reading: with the blanket assertion restored, that case fails on the real series `[4, 4, 0, 2, 4, 6]`; per regime it passes. Full suite 888/0 green. One xcodebuild test invocation at a time on this machine

Progress: [██████████] 97% (14/16 phases)

## Performance Metrics

**Velocity:**

- Total plans completed: 141
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 9 | - | - |
| 02 | 4 | - | - |
| 03 | 5 | - | - |
| 04 | 14 | - | - |
| 07 | 12 | - | - |
| 08 | 18 | - | - |
| 09 | 13 | - | - |
| 11 | 32 | - | - |
| 12 | 6 | - | - |
| 13 | 10 | - | - |
| 14 | 18 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 8min | 2 tasks | 8 files |
| Phase 01 P02 | 8min | 2 tasks | 8 files |
| Phase 01 P03 | 14min | 3 tasks | 150 files |
| Phase 01 P04 | 5min | 3 tasks | 7 files |
| Phase 01 P05 | 7min | 3 tasks | 10 files |
| Phase 01 P06 | 12min | 3 tasks | 2 files |
| Phase 01 P07 | 20min | 3 tasks | 5 files |
| Phase 02 P01 | 8 | 2 tasks | 5 files |
| Phase 02 P02 | iterative | spike + auto-load | 3 files |
| Phase 02 P03 | 6min | 2 tasks | 2 files |
| Phase 02 P04 | 12min | 2 tasks | 4 files |
| Phase 03 P01 | 13min | 2 tasks | 4 files |
| Phase 03 P02 | 12min | 2 tasks | 1 files |
| Phase 03 P03 | 14min | 2 tasks | 4 files |
| Phase 03 P04 | 10min | 2 tasks | 2 files |
| Phase 04 P01 | 11min | 2 tasks | 29 files |
| Phase 04 P02 | 9min | 2 tasks | 3 files |
| Phase 04 P03 | 25min | 2 tasks | 2 files |
| Phase 04 P04 | 18min | 2 tasks | 2 files |
| Phase 04 P05 | 22min | 2 tasks | 2 files |
| Phase 04 P06 | 7min | 2 tasks | 2 files |
| Phase 04 P07 | 8min | 2 tasks | 2 files |
| Phase 04 P08 | 10min | 2 tasks | 5 files |
| Phase 04 P09 | 9min | 2 tasks | 4 files |
| Phase 04 P10 | 7min | 2 tasks | 9 files |
| Phase 04 P11 | 7min | 2 tasks | 8 files |
| Phase 04 P12 | 7min | 2 tasks | 6 files |
| Phase 04 P13 | 8min | 2 tasks | 12 files |
| Phase 04 P14 | 20min | 3 tasks | 30 files |
| Phase 05 P01 | 6min | 2 tasks | 9 files |
| Phase 05 P02 | 9min | 2 tasks | 18 files |
| Phase 05 P03 | 4min | 2 tasks | 5 files |
| Phase 05 P04 | 4min | 2 tasks | 4 files |
| Phase 05 P05 | 7min | 3 tasks | 7 files |
| Phase 05 P06 | 12min | 2 tasks | 2 files |
| Phase 05 P07 | 6min | 2 tasks | 3 files |
| Phase 05 P08 | 15min | 3 tasks | 6 files |
| Phase 05 P09 | 10min | 3 tasks | 7 files |
| Phase 05 P10 | 7min | 3 tasks | 3 files |
| Phase 05 P11 | 3min | 1 tasks | 1 files |
| Phase 05 P12 | 2min | 1 tasks | 1 files |
| Phase 05 P13 | 2min | 1 tasks | 1 files |
| Phase 05 P14 | 4min | 2 tasks | 4 files |
| Phase 05 P15 | 2min | 1 tasks | 1 files |
| Phase 05 P16 | 8min | 1 tasks | 1 files |
| Phase 05 P17 | 3min | 2 tasks | 2 files |
| Phase 05 P18 | 9 min | 1 tasks | 0 files |
| Phase 07 P01 | 8min | 3 tasks | 3 files |
| Phase 07 P02 | 13min | 3 tasks | 7 files |
| Phase 07 P03 | 8min | 3 tasks | 11 files |
| Phase 07 P04 | 8min | 2 tasks | 9 files |
| Phase 07 P05 | 5min | 2 tasks | 5 files |
| Phase 07 P06 | 5min | 2 tasks | 7 files |
| Phase 07 P07 | 6min | 3 tasks | 11 files |
| Phase 07 P08 | 4h30m | 3 tasks | 6 files |
| Phase 07 P09 | 7min | 2 tasks | 2 files |
| Phase 07 P12 | 3min | 2 tasks | 2 files |
| Phase 07 P10 | 11min | 2 tasks | 2 files |
| Phase 08 P01 | 4min | 2 tasks | 3 files |
| Phase 08 P02 | 5min | 2 tasks | 3 files |
| Phase 08 P03 | 6 min | 2 tasks | 11 files |
| Phase 08 P04 | 6 min | 2 tasks | 7 files |
| Phase 08 P05 | 7min | 2 tasks | 5 files |
| Phase 08 P06 | 9min | 2 tasks | 18 files |
| Phase 08 P07 | 6min | 2 tasks | 10 files |
| Phase 08 P08 | 7min | 2 tasks | 14 files |
| Phase 08 P09 | 12 min | 2 tasks | 7 files |
| Phase 08 P10 | 7 min | 2 tasks | 5 files |
| Phase 08 P11 | 8 min | 2 tasks | 3 files |
| Phase 08 P12 | 7 min | 2 tasks | 10 files |
| Phase 08 P13 | 6 min | 2 tasks | 10 files |
| Phase 08 P14 | 4 min | 2 tasks | 4 files |
| Phase 08 P15 | 11 min | 2 tasks | 4 files |
| Phase 08 P18 | 4 min | 2 tasks | 5 files |
| Phase 08 P16 | 6 min | 2 tasks | 4 files |
| Phase 08 P17 | 20min | 2 tasks | 2 files |
| Phase 09 P01 | 19min | 3 tasks | 9 files |
| Phase 09 P02 | 6min | 2 tasks | 2 files |
| Phase 09 P03 | 7min | 3 tasks | 5 files |
| Phase 09 P04 | 8min | 3 tasks | 5 files |
| Phase 09 P05 | 75 | 2 tasks | 11 files |
| Phase 09 P06 | 8min | 2 tasks | 2 files |
| Phase 09 P07 | 6min | 2 tasks | 10 files |
| Phase 09 P08 | 5min | 2 tasks | 3 files |
| Phase 09 P09 | 10min | 2 tasks | 6 files |
| Phase 09 P10 | 4min | 2 tasks | 5 files |
| Phase 09 P11 | 8min | 2 tasks | 6 files |
| Phase 09 P12 | 6min | 2 tasks | 5 files |
| Phase 09 P13 | 17min | 2 tasks | 6 files |
| Phase 10 P01 | 17min | 2 tasks | 16 files |
| Phase 10 P02 | 9min | 3 tasks | 42 files |
| Phase 10 P03 | 15min | 3 tasks | 21 files |
| Phase 10 P04 | 20min | 2 tasks | 8 files |
| Phase 10 P05 | 16min | 2 tasks | 3 files |
| Phase 10 P06 | 20min | 3 tasks | 2 files |
| Phase 10 P07 | 12min | 2 tasks | 6 files |
| Phase 10 P08 | 20min | 2 tasks | 8 files |
| Phase 10 P09 | 12min | 3 tasks | 34 files |
| Phase 10 P10 | 22min | 2 tasks | 5 files |
| Phase 10 P11 | 18min | 2 tasks | 9 files |
| Phase 10 P12 | 12min | 3 tasks | 0 files |
| Phase 11 P1 | 25m | 2 tasks | 4 files |
| Phase 11 P2 | ~20m | 2 tasks | 4 files |
| Phase 11 P3 | ~30m | 2 tasks | 6 files |
| Phase 11 P4 | ~25m | 2 tasks | 7 files |
| Phase 11 P5 | ~20m | 2 tasks | 4 files |
| Phase 11 P6 | ~25m | 2 tasks | 13 files |
| Phase 11 P7 | 55m | 2 tasks | 24 files |
| Phase 11 P8 | ~95 min | 2 tasks | 24 files |
| Phase 11 P9 | ~40 min | 2 tasks | 17 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 11 P10 | ~70 min | 2 tasks | 28 files |
| Phase 11 P11 | ~35 min | 2 tasks | 9 files |
| Phase 11 P12 | ~25 min | 2 tasks | 8 files |
| Phase 11 P14 | ~35 min | 2 tasks | 7 files |
| Phase 11 P15 | ~40 min | 2 tasks | 13 files |
| Phase 11 P16 | ~20 min | 2 tasks | 1 files |
| Phase 11 P17 | ~60 min | 3 tasks | 18 files |
| Phase 11 P18 | ~50 min | 2 tasks | 36 files |
| Phase 11 P19 | ~20 min | 2 tasks | 2 files |
| Phase 11 P20 | ~35 min | 2 tasks | 6 files |
| Phase 11 P21 | ~50 min | 2 tasks | 41 files |
| Phase 11 P22 | ~35 min | 1 tasks | 26 files |
| Phase 11 P22.1 | 50 | 2 tasks | 24 files |
| Phase 11 P23 | ~20 min | 2 tasks | 32 files |
| Phase 11 P24 | ~15 min | 2 tasks | 5 files |
| Phase 11 P25 | 12 min | 2 tasks | 326 files |
| Phase 11 P26 | ~25 min | 2 tasks | 76 files |
| Phase 11 P27 | ~20 min | 2 tasks | 27 files |
| Phase 11 P28 | ~25 min | 2 tasks | 20 files |
| Phase 11 P29 | ~50m | 2 tasks | 3 files |
| Phase 11 P31 | ~50 min | 2 tasks | 3 files |
| Phase 12 P01 | 25min | 2 tasks | 6 files |
| Phase 12 P02 | 13 min | 2 tasks | 3 files |
| Phase 12 P03 | 13min | 2 tasks | 2 files |
| Phase 12 P04 | 11min | 2 tasks | 2 files |
| Phase 12 P05 | 14min | 2 tasks | 1 files |
| Phase 12 P06 | ~2 days (Task 1 ~35min + owner UAT) | 2 tasks | 18 files |
| Phase 13 P01 | 12 min | 2 tasks | 5 files |
| Phase 13 P02 | 11 min | 2 tasks | 6 files |
| Phase 13 P03 | 19 min | 2 tasks | 16 files |
| Phase 13 P04 | 12 min | 2 tasks | 3 files |
| Phase 13 P05 | 18 min | 2 tasks | 3 files |
| Phase 13 P06 | 7 min | 2 tasks | 5 files |
| Phase 13 P07 | 16 min | 3 tasks | 11 files |
| Phase 13 P08 | 23 min | 2 tasks | 11 files |
| Phase 13 P09 | 36 min | 2 tasks | 5 files |
| Phase 14 P02 | ~6 min | 1 tasks | 1 files |
| Phase 14 P03 | 17min | 3 tasks | 9 files |
| Phase 14 P04 | 7min | 3 tasks | 7 files |
| Phase 14 P05 | ~11min | 3 tasks | 3 files |
| Phase 14 P06 | ~17min | 3 tasks | 5 files |
| Phase 14 P07 | 40min | 2 tasks | 23 files |
| Phase 14 P08 | 18min | 2 tasks | 11 files |
| Phase 14 P09 | ~12min | 3 tasks | 9 files |
| Phase 14 P10 | 14min | 3 tasks | 4 files |
| Phase 14 P11 | 18min | 3 tasks | 5 files |
| Phase 14 P12 | 14min | 3 tasks | 9 files |
| Phase 15 P01 | 7min | 2 tasks | 5 files |
| Phase 15 P02 | 14min | 3 tasks | 16 files |
| Phase 15 P03 | 6min | 2 tasks | 2 files |
| Phase 15 P04 | 13min | 3 tasks | 7 files |
| Phase 15 P05 | 15min | 2 tasks | 6 files |
| Phase 15 P06 | 22min | 3 tasks | 5 files |
| Phase 15 P07 | 16min | 3 tasks | 2 files |
| Phase 15 P08 | 32min | 3 tasks | 3 files |
| Phase 15 P09 | 47min | 2 tasks | 4 files |
| Phase 15 P10 | 25min | 2 tasks | 10 files |
| Phase 15 P11 | 10min | 2 tasks | 2 files |
| Phase 15 P12 | 12min | 2 tasks | 7 files |
| Phase 15 P13 | 21min | 2 tasks | 5 files |
| Phase 15 P14 | 11min | 2 tasks | 7 files |
| Phase 15 P15 | 12min | 2 tasks | 2 files |
| Phase 15 P16 | 8min | 2 tasks | 1 files |
| Phase 15 P17 | 21min | 3 tasks | 6 files |
| Phase 15 P18 | 16min | 2 tasks | 10 files |
| Phase 15 P19 | 28min | 3 tasks | 18 files |
| Phase 15 P20 | 25 | 2 tasks | 4 files |
| Phase 15 P21 | 35 | 2 tasks | 1 files |
| Phase 15 P22 | 35 | 2 tasks | 4 files |
| Phase 15 P23 | 22min | 2 tasks | 3 files |
| Phase 15 P24 | 35min | 2 tasks | 4 files |
| Phase 15 P25 | 45min | 2 tasks | 6 files |
| Phase 15 P26 | 45min | 2 tasks | 9 files |
| Phase 15 P27 | 26min | 1 tasks | 2 files |
| Phase 15 P28 | 9min | 2 tasks | 13 files |
| Phase 15 P29 | 70min | 2 tasks | 6 files |
| Phase 15 P30 | 55min | 1 tasks | 3 files |
| Phase 15 P31 | 50min | 1 tasks | 9 files |
| Phase 15 P32 | 50min | 2 tasks | 24 files |
| Phase 15 P33 | 50min | 1 tasks | 4 files |
| Phase 15 P34 | 12min | 2 tasks | 5 files |
| Phase 15 P35 | 22min | 1 tasks | 2 files |
| Phase 15 P36 | 37min | 2 tasks | 4 files |
| Phase 15 P37 | 90min | 2 tasks | 9 files |
| Phase 15 P38 | 105min | 2 tasks | 4 files |
| Phase 15 P39 | 25min | 2 tasks | 5 files |
| Phase 15 P40 | 22min | 2 tasks | 5 files |
| Phase 15 P41 | 41min | 2 tasks | 8 files |
| Phase 15 P42 | 35min | 2 tasks | 3 files |
| Phase 15 P43 | 35m | 2 tasks | 5 files |
| Phase 15 P44 | 29min | 2 tasks | 4 files |
| Phase 15 P45 | 6min | 2 tasks | 6 files |
| Phase 15 P46 | 26min | 2 tasks | 3 files |
| Phase 15 P47 | 27min | 2 tasks | 12 files |
| Phase 15 P48 | 33min | 3 tasks | 9 files |
| Phase 15 P49 | 14min | 2 tasks | 5 files |
| Phase 15 P50 | 41min | 3 tasks | 9 files |
| Phase 15 P51 | 32min | 2 tasks | 3 files |
| Phase 15 P52 | 38min | 2 tasks | 3 files |
| Phase 15 P53 | 45min | 2 tasks | 3 files |
| Phase 15 P54 | ~5h | 5 tasks | 14 files |
| Phase 15 P55 | 95 min | 2 tasks | 8 files |
| Phase 15 P56 | 135min | 2 tasks | 6 files |
| Phase 15 P57 | 30min | 2 tasks | 7 files |
| Phase 15 P58 | 68min | 2 tasks | 6 files |
| Phase 15 P59 | 66min | 2 tasks | 4 files |
| Phase 15 P60 | 32 | 2 tasks | 2 files |
| Phase 15 P61 | 55min | 2 tasks | 5 files |
| Phase 15 P62 | 35min | 2 tasks | 7 files |
| Phase 15 P63 | 30min | 2 tasks | 3 files |
| Phase 15 P64 | 30 min | 2 tasks | 8 files |
| Phase 15 P65 | 40min | 2 tasks | 5 files |
| Phase 15 P66 | 45min | 2 tasks | 14 files |
| Phase 15 P67 | 25min | 2 tasks | 7 files |
| Phase 15 P68 | 40min | 2 tasks | 7 files |
| Phase 15 P69 | 35min | 2 tasks | 13 files |
| Phase 15 P70 | 30min | 2 tasks | 5 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Combine→async/await (Phase 4) stays in this milestone, sequenced after the isolated dep removals.
- Roadmap: WaterfallGrid→Layout (Phase 2) and SwiftUIPager→native paging ScrollView (Phase 3, construct per D-04 not a TabView) are spike-first — validate feasibility before committing.
- Roadmap: Fold cookies→Keychain + networking/cookie/image tests + `.private.filterValue` fix into their open seams (Phases 8–9); defer Parser/Download refactors.
- Roadmap: LINT-01 split — mechanical rules sweep last (Phase 11); refactor-gated rules land with their refactors (`optional_try`→Phase 9; binding/lifecycle/unchecked-subscript→Phases 5–7).
- [Phase 04]: 04-01: Every Request conformer stores an injected URLSession, including DataRequest, with .shared as the behavior-preserving default.
- [Phase 04]: 04-02: Parity capture accepts a closure formed on each concrete request type to avoid protocol-extension static dispatch.
- [Phase 04]: Fetch errors map inside fetch; parse errors map after fetch returns, so parse failures never retry. — Preserves Combine retry placement and one AppError mapping per thrown boundary.
- [Phase 04]: TagTranslator retries metadata but performs its payload download once. — Preserves the frozen two-step Combine chain asymmetry.
- [Phase 04]: Native URLSession structured cancellation remains attached to the caller task. — Stops cancelled HTTP work while TCA preserves identical user-visible behavior.
- [Phase 04]: Login preserves an optional HTTP response while Igneous requires an HTTP response and maps a failed cast to unknown. — Matches the distinct frozen map and compactMap semantics.
- [Phase 04]: Account form and JSON assembly remains duplicated beside temporary publishers until publisher deletion. — Keeps each intermediate commit compiling while frozen structural assertions prove parity.
- [Phase 04]: Async gallery metadata preserves 25-pair chunks, two in-flight requests, and input-order reconstruction. — These are existing flood-control and presentation-order guarantees around the shared gdata transport.
- [Phase 04]: Metadata task-group children return typed Result values. — Preserves AppError typing and structured cancellation across the task-group boundary.
- [Phase 04]: Detail chains retry their first fetch and leave their second fetch un-retried. — Preserves the frozen publisher retry placement for reverse lookup and archive funds.
- [Phase 04]: Image refetch retries its complete three-step chain four times. — Matches the publisher-level genericRetry placement and frozen per-URL attempt counts.
- [Phase 04]: Image fan-out uses a Sendable result record in its throwing task group. — The compiler crashes on the equivalent labeled-tuple expression; the record preserves identical semantics.
- [Phase 04]: Reducer Done actions and handlers remain Result-based during the async consumer switch. — Limits the migration to request acquisition and preserves literal state-machine parity.
- [Phase 04]: TCA request effects use explicit do throws AppError with no casts or unknown fallback. — Keeps typed catch binding load-bearing and makes every failure send explicit.
- [Phase 04]: Reader image effects preserve cancellation identifiers and send ordering during acquisition conversion. — Protects the highest-frequency request path from reducer behavior drift.
- [Phase 04]: DownloadClient and file-operation run/catch effects remain outside the request consumer sweep. — They do not call the request facade and changing them would exceed the plan boundary.
- [Phase 04]: TagTranslator noUpdates remains an explicit failure action during the typed consumer switch. — Exactly preserves the previous inline Result switch outcome.
- [Phase 04]: Throwing DownloadClient functions await typed responses directly while Result-returning APIs rebuild Result explicitly. — Preserves public signatures and minimizes orchestration changes.
- [Phase 04]: Request now requires typed throws and the package source tree is Combine-free. — Makes the compiler enforce async conformance completeness and removes all publisher bridges.
- [Phase 04]: The D-11 scope expanded to all 66 compiler-reported TCA deprecations. — The owner authorized the authoritative compiler inventory so CONC-02 reaches zero warnings.
- [Phase 04]: Presentation modifiers and reducer behavior remain unchanged while scope arguments use TCA 1.26 forms. — Argument-only migrations preserve UI anchors and state-machine semantics.
- [Phase 05]: DeviceType is the sole device-identity representation; boolean isPad is derived only at branch sites.
- [Phase 05]: Gallery navigation accepts the injected main-actor deviceType closure and resolves it inside its effect.
- [Phase 05]: Removed obsolete AppDelegateClient test overrides with the deleted target. — A test-only compatibility target would preserve dead architecture; affected tests pass without it.
- [Phase 05]: AppComponents declares DeviceClient directly because TagSuggestionView owns the injected device fact. — Direct Swift package dependencies make module ownership explicit and compilable.
- [Phase 05]: EhSetting fractions use current container dimensions instead of the old orientation-independent short edge. — This is the locked adaptive-layout delta for rotation and resized containers.
- [Phase 05]: Alert and placeholder widths use the nearest SwiftUI container while preserving their existing factors.
- [Phase 05]: NewDawnView observes only container width and keeps its iPad-specific factor through the injected DeviceClient.
- [Phase 05]: Direct detail width fractions use containerRelativeFrame without geometry state. — This keeps direct fractions container-relative while avoiding unnecessary view state and invalidation.
- [Phase 05]: Archive cells receive the grid's size-class-selected width. — A single selected value keeps adaptive grid metadata and rendered cell frames identical.
- [Phase 05]: Preview thumbnail downsampling uses a fixed 660-pixel cap. — The former regular-width maximum preserves fidelity without coupling image decoding to layout.
- [Phase 05]: Carousel card width, card pitch, and symmetric peek inset derive from one observed container width. — Keeps the coupled view-aligned geometry consistent during rotation and container resizing.
- [Phase 05]: Ranking layout follows horizontal size class while Toplists and title trimming retain device-class semantics through DeviceClient. — Separates adaptive layout decisions from parity-sensitive device identity branches.
- [Phase 05]: Live Text OCR paths and interactive overlays share one captured nonzero size; Canvas uses its closure size only for the full-surface tint. — This preserves normalized coordinate alignment while guarding the initial geometry pass.
- [Phase 05]: Reader gesture math consumes one outer-container size while existing gesture sources continue supplying locations until Plan 05-09.
- [Phase 05]: PageHandler requires isLandscape at every call site; the construction-time resume seed uses portrait mapping until observed geometry is available.
- [Phase 05]: Reader pinch gestures use MagnifyGesture.startAnchor directly while double taps derive their anchor from SpatialTapGesture.location. — Each native gesture source now supplies the coordinate representation its baseline-locked arithmetic expects.
- [Phase 05]: Reader landscape eligibility derives from captured container width greater than height. — One local size now governs dual-page mapping and reader controls under rotation and resized containers.
- [Phase 05]: ApplicationClient selects the last key window from foreground-active scenes, then falls back to the last window of the last scene, preserving the former behavior locally.
- [Phase 05]: Defaults.FrameSize keeps only the device-independent card height and no longer needs main-actor isolation.
- [Phase 05]: Runtime rotation and Live Text visual checks remain explicit manual gates for phase verification rather than being inferred from static or unit-test evidence.
- [Phase 05]: About metadata is the leading Form section so every navigation-bar style preserves it in the scrollable reading order.
- [Phase 05]: Reader placeholders preserve the full vertical container extent while applying the dual-page divisor only to the horizontal axis. — This lets the fixed aspect ratio choose height-bounded sizing in landscape without changing dual-page behavior.
- [Phase 05]: 05-13: CardSlideSection remains the sole owner of carousel card width, pitch, and centered peek; GalleryCardCell fills the proposed slot.
- [Phase 05]: SettingTextField uses its title only as a localized accessibility label; promptText is the sole visible placeholder source.
- [Phase 05]: Each reusable sheet root owns an untitled cancellation-role button at the stable cancellationAction toolbar placement.
- [Phase 05]: Favorites category switching remains direct while sort, date seek, and quick search move into ToolbarFeaturesMenu.
- [Phase 05]: DateSeekButton continues to own its nil-navigation disabled state, and Favorites reducer behavior remains unchanged.
- [Phase 05]: Reader window-control compensation uses the iOS 26 top-leading container corner exclusion and folds in safe-area dimensions only when that exclusion is nonzero.
- [Phase 05]: Home declares systemBackground at its content root so systemGray6 cards stay distinct without changing normal-window appearance.
- [Phase 05]: Multiple-scene support is disabled while every scene would share the single AppDelegate-owned store.
- [Phase 05]: No non-pad gallery-detail entry path bypassed GalleryNavigation; source inventory and reducer probes all resolved phone entries to push. — The no-repro branch requires human confirmation instead of a speculative source change.
- [Phase 05]: Deep-link, URL, and clipboard gallery entries remain the intentional device-independent modal baseline. — These app-route presentations are documented behavior and are separate from host gallery-tap routing.
- [Phase 07]: 07-01: The privacy-mask blur is transient in-memory state and starts at a true zero on every launch.
- [Phase 07]: 07-01: The privacyMask modifier owns a read-only SharedReader so callers need no store scope or blur argument.
- [Phase 07]: loadUserSettingsDone is the single cold-launch clipboard-detection owner; the active scene branch handles later foreground entries. — Pre-load active transitions are ignored, preventing duplicate cold-launch clipboard detection while preserving later foreground behavior.
- [Phase 07]: privacyMaskIntensity remains a version-1 Setting field with default 10 and no migration. — The pre-release schema policy accepts resetting the renamed key to its parity default.
- [Phase 07]: The Privacy Mask slider owns a localized accessibility label and treats its eye icons as decorative. — This keeps the native adjustable control concise for VoiceOver without announcing redundant symbols.
- [Phase 07]: Detail routing blur inputs temporarily default to zero so Home and Favorites can remove drilling before the DetailFeature sweep. — This keeps sequential module commits compiling without retaining blurRadius tokens in migrated modules; plan 07-06 removes the temporary inputs.
- [Phase 07]: DownloadsView keeps the plan-specified ReadingView blurRadius: 0 bridge until 07-07 while all Downloads-owned blur inputs are removed. — ReadingFeature still requires the parameter until its scheduled sweep.
- [Phase 07]: Both Detail-owned ReadingView presentations retain literal blurRadius zero bridges until 07-07. — ReadingView still requires the compatibility parameter; DetailFeature no longer owns or propagates blur state.
- [Phase 07]: 07-07: Privacy-mask coverage is counted as forty application call sites; the public function declaration and shared-key documentation remain valid non-call matches.
- [Phase 07]: 07-07: The AppActivityLogs mask stays on the RunPickerSheet presented root so native sheet accessibility and stable modal coverage are preserved.
- [Phase 07]: The no-content-leak gate combines automated forty-site coverage with owner device-level approval. — Static checks cannot prove App Switcher snapshot concealment or presentation behavior.
- [Phase 07]: Privacy-mask coverage counts forty executable application calls rather than forty-two raw tokens. — The public function declaration and shared-key documentation are valid non-application matches.
- [Phase 07]: The owner post-checkpoint refinement scopes blur animation to the blur transform and keeps Privacy Mask in the first Appearance section. — The owner intentionally refined presentation after verification; current HEAD was rebuilt and retested without rewriting the commit.
- [Phase 07]: 07-09: Scene-phase privacy writes and background latching run before the settings-loaded guard; settings-dependent effects remain gated. — Protects cold-launch App Switcher snapshots without changing initialization-dependent side-effect semantics.
- [Phase 07]: 07-11: Privacy-mask coverage is derived from 39 explicit runtime roots and reconciled against all 41 source presentation modifiers. — A duplicate can no longer compensate for an uncovered root, and preview-only presentations remain explicit exclusions.
- [Phase 07]: 07-11: Privacy blur transitions use no animation when Reduce Motion is enabled. — The true-zero blur and hit-testing threshold remain unchanged.
- [Phase 07]: 07-10: Foreground tests explicitly pause the long-lived activity-log pump after receiving every expected action, preserving TestStore exhaustivity without skipping effects.
- [Phase 07]: 07-10: Clipboard cardinality counts the unconditional changeCount dependency seam; the URL remains nil to isolate foreground dispatch behavior.
- [Phase 08]: QUAL-01 covers cookie-logging privacy only; the former at-rest migration is out of milestone rather than deferred. — D-01 reconciles the milestone contract with the sideload-distribution reliability tradeoff.
- [Phase 08]: D-06 retains URLUtil and FileUtil as pure namespaces instead of adding thin client wrappers. — Pure deterministic helpers gain no substitutability from a client wrapper.
- [Phase 08]: Host-derived Defaults.URL helpers accept GalleryHost explicitly while existing global properties remain available during caller migration.
- [Phase 08]: URLUtil uses AppUtil.galleryHost only as a transitional default; every host-dependent builder body constructs from its GalleryHost argument.
- [Phase 08]: Gallery-list reducers snapshot setting.galleryHost at request construction time. — This matches existing filter and keyword snapshot semantics while making the shared Setting the sole host source for each request.
- [Phase 08]: Setting reducers snapshot setting.galleryHost when constructing each host-dependent effect. — A request keeps one construction-time host across its asynchronous work.
- [Phase 08]: EhSettingFeature state reads shared Setting directly because it previously had no host source. — The reducer now resolves its host explicitly without retaining a global fallback.
- [Phase 08]: Account and routine request baselines use an explicit deterministic E-Hentai host. — Tests no longer depend on the transitional global host mirror.
- [Phase 08]: Detail reducers snapshot setting.galleryHost when constructing each host-dependent effect. — Each in-flight request keeps one consistent construction-time host even if shared settings change later.
- [Phase 08]: CookieClient apiuid reads the selected host URL supplied by its caller. — Explicit caller-owned host selection removes the hidden transitional global-host dependency.
- [Phase 08]: Account request baselines use an explicit deterministic E-Hentai host. — Parity tests should not depend on the transitional mutable global host mirror.
- [Phase 08]: Snapshot GalleryHost at async request construction boundaries. — A stable value keeps in-flight requests tied to the selected origin without consulting mutable global state.
- [Phase 08]: Use saved-download manifest hosts for refreshes and the current shared host for live DownloadClient fetches. — Each flow retains its existing source of truth while making host selection explicit.
- [Phase 08]: Views use existing store settings where available and read-only SharedReader state only in leaf views without store access.
- [Phase 08]: Detail download payloads snapshot state.setting.galleryHost when the start action is handled.
- [Phase 08]: GalleryInfosView reads the active host from SharedReader(.setting) at render time. — The leaf view has no parent Setting state and this matches the established host seam.
- [Phase 08]: Test-only URL fallbacks use an explicit E-Hentai host. — Deterministic tests must not recreate the removed mutable host default.
- [Phase 08]: Use one canonical DataCache actor for the live dependency and system-purge observer. — Preserves coherent cache identity while removing the public singleton seam.
- [Phase 08]: Use UUID-scoped temporary DataCache instances for the default test dependency. — Prevents cross-test cache pollution while allowing explicit per-test injection.
- [Phase 08]: Exercise ImageClient through an injected cache and URLSession while keeping one isolated DataCache actor per test. — This prevents process-global cache pollution and makes every client-layer behavior deterministic.
- [Phase 08]: Render image-test PNG fixtures at scale 1 before asserting decoded pixel dimensions. — UIImage point canvases inherit the simulator display scale; an explicit unit scale keeps the fixture exactly 2 by 2 pixels.
- [Phase 08]: 08-11: Use synthetic credential fixtures and clear every live cookie store after each test. — Keeps credential-shaped test data isolated and short-lived while exercising production cookie parsing.
- [Phase 08]: 08-11: Query skip-server cookies at their /s/ path. — Matches the production cookie path and verifies Foundation URL path filtering rather than bypassing it.
- [Phase 08]: 08-12: Resolve CookieClient at each view owner, including a function-local read in the cross-file Detail toolbar extension. — Private stored dependencies are file-scoped in Swift; local resolution preserves render-time reads without widening access.
- [Phase 08]: 08-12: Keep every login condition and control modifier unchanged apart from its predicate source. — The migration is a seam swap at behavior, appearance, accessibility, and dialog-anchor parity.
- [Phase 08]: 08-13: Preserve the legacy-device sound sequence and modern UIKit feedback calls verbatim inside HapticsClient.live.
- [Phase 08]: 08-13: Keep AppUserDefaults in AppTools as the shared key type while removing only the redundant UserDefaultsUtil wrapper.
- [Phase 08]: 08-14: Preserve Bundle metadata keys, null fallbacks, and XCTestConfigurationFilePath detection when relocating them to AppInfo. — Maintains exact About metadata and test-launch behavior while eliminating AppUtil.
- [Phase 08]: 08-14: Model AppInfo as an uninhabited pure namespace instead of an injected client. — Read-only app facts require no substitution, and a client would be a thin wrapper.
- [Phase 08]: Carry GalleryHost in refetchNormalImageURLsDone so both completion paths preserve request identity. — Response cookie routing must remain tied to immutable request-construction context across shared-host changes.
- [Phase 08]: Observe the isolated CookieClient testing store as the host-routing spy. — The behavior-level assertion proves the destination host without adding a production callback solely for tests.
- [Phase 08]: Track cookie-bearing local assignments for the rest of each Swift file so ordinary alias names cannot bypass the privacy gate. — This conservative file-scoped taint closes the demonstrated data-flow evasion while the production source scan remains green.
- [Phase 08]: Skip the production-only getCookiesDescription consumer inventory when an explicit fixture scan root is supplied. — Fixture scans should fail only for the cookie-logging rule they exercise, while the no-argument production scan retains the clipboard invariant.
- [Phase 08]: Carry GalleryHost in fetchEhProfileIndexDone and createDefaultEhProfile so every profile side effect retains request identity. — Profile completion must not re-read mutable shared host state.
- [Phase 08]: Observe selected-profile routing through an isolated CookieClient testing store while asserting default-profile routing at the follow-up action boundary. — This proves host behavior without process-global cookies or a production-only test callback.
- [Phase ?]: [Phase 08]: 08-17: Model the clipboardChangeCount UserDefaults read as a stored @Sendable endpoint (not a generic instance method) so overrides control reads exactly as they control writes; UserDefaults.standard is read only inside live.
- [Phase 09]: Keep AppError's 12-case enum unchanged and carry per-incident diagnostics in ErrorInfo.
- [Phase 09]: Offer recovery suggestions for networking, authentication, IP restriction, quota, and not-found errors.
- [Phase 09]: Use Self.Context in SwiftUI representables so the public diagnostic Context type cannot shadow protocol context.
- [Phase 09]: 09-02: Treat Category.private as display-only: report filter-math misuse and contribute zero instead of trapping.
- [Phase 09]: 09-02: Keep filter iteration on Category.allFiltersCases, whose ten searchable cases sum to all 1023 filter bits.
- [Phase 09]: 09-03: Keep ErrorInfoView native and data-minimal: Form, LabeledContent, and only whitelisted context/environment values.
- [Phase 09]: 09-03: Route error-toast activation through a modifier closure and accessibility button trait; the Action == Never store never sends an action.
- [Phase 09]: 09-03: Declare AppModels directly on SystemNotificationExt because its public toast API exposes ErrorInfo.
- [Phase 09]: 09-04: Use PresentationFeature rather than PresentationReducer because repository reducers must carry the Feature suffix.
- [Phase 09]: 09-04: Rename appRouteState/appRoute to presentationState/presentation across the complete app-root source surface.
- [Phase 09]: 09-04: Gallery failure diagnostics expose only the action, localized reason, and URL path.
- [Phase 09]: FileClient uses fixed operation descriptors in AppError context so failures never disclose a file path.
- [Phase 09]: Missing cached translations recover through the existing remote fetch, while removal failures reach SettingFeature state.
- [Phase 09]: HTML repair, greeting, archive funds, and Chinese conversion remain optional because each has an explicit behavior-preserving fallback.
- [Phase 09]: All 16 scoped try? sites are intentional probe, metadata, validation, or cleanup fallbacks; genuine manifest and page persistence already propagates through throwing APIs.
- [Phase 09]: All 20 scoped DownloadClient try? sites are intentional parsing probes, metadata probes, optional API fallbacks, cadence writes, or cleanup operations; authoritative failures already propagate.
- [Phase 09]: Cleanup and optional probe failures preserve the primary validation or download result instead of introducing a competing error surface.
- [Phase 09]: 09-08: Keep all 13 DataCache optional operations as documented cache probes, metadata fallbacks, or fire-and-forget housekeeping so failures never replace cache hit/miss outcomes.
- [Phase 09]: 09-08: Preserve the four AppTools utility optional contracts: encoding/decoding return nil, URL detector failure is invalid, and regex failure disables suggestions.
- [Phase 09]: 09-09: Keep 42 ParserFeature try? expressions as documented per-field, per-row, or per-candidate degradations.
- [Phase 09]: 09-09: Convert MPV JSON deserialization to a typed AppError boundary because invalid JSON fails the whole parse.
- [Phase 09]: 09-09: Treat the Parser+Profile BrowsingCountry? raw match as an Optional-type substring, not an optional-try expression.
- [Phase 09]: 09-10: Keep all 17 scoped client and activity-log optional failures as documented intentional fallbacks.
- [Phase 09]: 09-10: Keep image-cache and activity-log persistence failures internal so they do not replace successful image acquisition or interrupt the pump.
- [Phase 09]: 09-11: Keep JSONValue's six sequential decode attempts as type probes because failure selects the next representation.
- [Phase 09]: 09-11: Keep the final view and markdown optional failures internal because each retains an explicit presentation or validation fallback.
- [Phase ?]: 09-12: Gallery diagnostics retain only a validated decimal gallery ID; access-bearing route components never enter Context.
- [Phase 09]: ErrorInfo-bearing toasts remain until native Button activation or downward-swipe dismissal; ordinary success and caption-error toasts retain their three-second timeout.
- [Phase 09]: ToastInteractionState consumes only the current UUID and clears it before host routing, preventing stale, repeated, replacement, and dismissal events from routing ErrorInfo.
- [Phase 09]: The diagnostic Button keeps ToastMessageView as its visible label so Voice Control names and visible text remain aligned.
- [Phase ?]: 10-03: Uneven corner clip relocated from custom UIRectCorner param to native .rect(bottomLeadingRadius:) with default .circular style; no continuous style added (parity preserved)
- [Phase ?]: [Phase 10]: 10-04: \.inSheet env key removed; all former consumers collapsed to the base (inSheet==false) gray per owner decision — trait and Bool-param mechanisms both rejected; the modal DetailView surfaces intentionally shift to base gray.
- [Phase ?]: 10-05: The three ToolbarItems buttons use a two-branch Label (icon-only when hideText); no AnyLabelStyle, so icon-only is explicit not toolbar-inferred.
- [Phase ?]: 10-05: Menu/context-menu Image+Text rows convert to Label (house style); toolbar image-only and trailing-checkmark menu rows are left (new-key/wrong-slot parity veto).
- [Phase ?]: 10-05: Empty-string audit (criterion 9) returned zero matches across AppPackage/Sources, App, ShareExtension; documented as the deliverable.
- [Phase ?]: 10-06: Only 3 of 35 ZStacks convert to .overlay — flexible Color/backgroundColor size-definer under an external definite frame (aspectRatio/containerRelativeFrame); the other 32 (union peers, conditional single-child, opacity-toggled equal indicators, gesture/coordinate-critical) are KEEP, the plan's intended outcome.
- [Phase ?]: 10-07: Paired numeric-text treatment applied inline per site (pair-check grep needs both tokens co-located); animation left ungated because contentTransition(.numericText) is itself Reduce-Motion-aware.
- [Phase ?]: 10-08: RatingView @Previewable requirement met via a Slider driving @Previewable @State (view is display-only, no Binding)
- [Phase ?]: 10-08: built EhPanda app scheme (whole AppPackage graph) since AppPackage-Package scheme is absent; iPhone Air OS27 sim
- [Phase ?]: 10-09: 34 remaining PreviewProvider structs migrated to named #Preview; D-07 global grep gate at zero
- [Phase ?]: 10-10: 7 fixed-pixel fonts scale via @ScaledMetric(relativeTo:) (5 non-exact sizes) + text-style forms (20->title3, 12->caption); first ScaledMetric uses in repo
- [Phase ?]: 10-10: DT audit is static-derived; broke-at-AX5 subset = B1-B10 (10-11 work order); owner-signed D-03 sim pass is end-of-phase authoritative gate; live frame-height risk count is 9 not RESEARCH's 35
- [Phase ?]: 10-11: text-bearing fixed frame(height:) reflowed via @ScaledMetric(relativeTo: dominant style) not minHeight — literal==scaled at .large for exact default parity while frame grows with Dynamic Type
- [Phase ?]: 10-11: B1-B10 broke-at-AX5 all reflowed within D-02 (drop lineLimit/fixedSize for wrap, @ScaledMetric fixed heights); minimumScaleFactor 8->7 (B2 inert shrink removed); device D-03 pass deferred to 10-12
- [Phase ?]: ParserFeature Group A/B optional-try removal routes through one shared Parser.degrading(_:_:) helper — inline do/catch is not expressible inside guard-let chains without changing evaluation order
- [Phase ?]: D-04 group counts corrected: 21 Group A + 12 Group B + 9 Group C (not 23/13/6) — plan 11-02 must propagate 9 sites
- [Phase 11]: 11-02: parseDisplayMode returns String? — a missing display-mode selector is the normal toplist case, not an error
- [Phase 11]: 11-02: parseScriptVariable rebuilt with RegexBuilder — removes the runtime regex-compile failure path entirely
- [Phase ?]: 11-03: DownloadClient manifest identity probes collapse onto one named probeManifest helper with a deliberately silent catch; scans walk arbitrary user folders so logging would be noise
- [Phase ?]: 11-04: DownloadClient probe sites collapse onto two named helpers (probeHTMLDocument, probeFileData) — inline do/catch is not expressible in guard/if-let chains
- [Phase ?]: 11-04: DownloadStore.closeReadHandle promoted to internal for coordinator reuse instead of duplicating the helper
- [Phase ?]: 11-06: Activity-log pump append failures stay silent: logging inside a pump that reads its own OSLog self-feeds
- [Phase ?]: 11-06: LogsClient's two directory guards collapse onto one helper returning [] — both fallbacks derive from an empty list
- [Phase ?]: Presentation-driven lifecycle uses two shapes: pushed screens get onPresented from the presenting reducer's append; tab roots get it from AppReducer on tab activation and at launch-ready
- [Phase ?]: appendGuardingDuplicate now returns the new StackElementID? so a deduped push starts nothing
- [Phase ?]: Detail load pairing lives on GalleryPath.State.onPresentedAction + GalleryNavigation.presentationEffect, so a new gallery screen cannot silently skip a host
- [Phase ?]: PostCommentView lost its onAppearAction parameter: focus is raised by the presenting reducer
- [Phase ?]: Reader lifecycle: 3 of 6 sites migrated to presentation-driven; 3 kept as reason-annotated D-02 exception candidates (lazy-container prefetch, .task(id:) cancellation, view-owned handler teardown)
- [Phase ?]: swiftlint:disable:next directives cannot land before 11-11 uncomments lifecycle_modifiers (trips superfluous_disable_command); 11-11's flip commit must carry the rule AND every exception directive atomically
- [Phase ?]: Setting/Filters/Downloads lifecycle migrated with zero D-02 exceptions; StackAction.popFrom is the dismissal-teardown seam
- [Phase ?]: Pitfall 4 resolved by observation: AccountSetting's jar subscription outlives the login push, so no re-check re-fire is needed
- [Phase ?]: lifecycle_modifiers and binding_initializer flipped to error atomically with the last fixes and all six D-02 directives — a disable directive cannot precede its rule (superfluous_disable_command)
- [Phase ?]: Toast's ToastInteractionState deleted rather than exempted: it mirrored the presentation binding, and its two lifecycle callbacks existed only to maintain the mirror
- [Phase ?]: 11-12: unchecked_subscript_index_access directive deferred to 11-17's flip commit — a directive naming an unregistered rule is a superfluous_disable_command warning
- [Phase ?]: 11-12: AppModels' Gallery.preview/previews/mockGalleries still mint random UUIDs; left for the owner (AppModels→PreviewSupport dep is architectural)
- [Phase ?]: ReadingFeature subscript matches resolved by honest 'page' renames (60 Dictionary sites) + enumerated() restructure (1 Array site); no exception sites, nothing for 11-17 to insert
- [Phase ?]: Draft rule's excluded: '[validatedIndex]' entry confirmed inert (file-path regex); recommend 11-17 delete it or move the escape into the rule regex
- [Phase ?]: ParserFeature's 20 Parser+Detail subscript matches were one design defect: parseInfoPanel returned an 8-slot positional [String]. Replaced with a named-field InfoPanel struct.
- [Phase ?]: parseGalleryTitle now extracts gid/token inside the guard that validates pathComponents.count >= 4, so four list-mode call sites stop indexing a scraped URL on trust.
- [Phase ?]: Plan 11-14 created zero precondition-checked exception sites — 11-17 has no directive to insert in ParserFeature.
- [Phase ?]: 11-16: 22 of ImageColors' 25 subscript matches were one defect — proposed[0...3] was a positional record; replaced with a named-field ProposedColors struct (11-14's pattern, 2nd use)
- [Phase ?]: 11-16: histogram pixel walk rebuilt on makeIterator() + four-way while-let — index arithmetic removed rather than precondition-checked; tally is order-independent so parity holds
- [Phase ?]: 11-16: doc_comment rule defect independently reproduced (2nd confirmation); no clarity loss this time only because the code change made the old subscript wording obsolete
- [Phase ?]: 11-16: zero exception sites again — 4 waves / 172 matches with the sanctioned precondition form never once used; flagged to owner as an untested exception idiom before the flip
- [Phase ?]: 11-16: ImageColors.colors tie-breaks nondeterministically (unstable sort over hash-seeded Dictionary keys) — pre-existing, load-bearing in the parity argument, left unchanged
- [Phase ?]: unchecked_subscript_index_access live at error; doc-comment kind is 'doccomment' not 'doc_comment' (invalid entries silently discard the whole rule config)
- [Phase ?]: Inert validatedIndex excluded entry deleted; 240 matches over 5 waves needed only 2 exception sites
- [Phase ?]: labeled_tuple_elements: draft regex was mis-tuned both ways — its bracket-excluding element class hid 11 genuine sites (incl. a same-typed ([Int: URL], [Int: URL]) pair) while flagging 11 non-sites (tuple assignments via newline-crossing \s, and function-type parameter lists where Swift forbids labels)
- [Phase ?]: (String, TagTranslation?) became a named struct TagTranslationLookup in AppModels, not a labeled typealias — a typealias satisfies the rule but leaves .0/.1 legal, and three sites read .1
- [Phase ?]: Labeling a public positional return creates a constraint the unlabeled version silently absorbed: parseMPVKeys had to adopt ReadingReducer's pre-existing key: label, since differently-labeled tuples do not convert
- [Phase ?]: FileClient.live became a function with injectable Application Support / Caches roots (production defaults); FileClientTests dropped .serialized for per-test UUID roots
- [Phase 11]: Plan 11-20: no Kingfisher seam needed — the production read path resolves @Dependency(\.dataCache), so the two DownloadImageParsing suites were primed against a cache the code no longer reads (their nil assertions were trivial misses, now bracketed by pre/post cache probes)
- [Phase 11]: Plan 11-20: DidLoginKey.subscribe now creates its jar stream synchronously instead of inside the consuming task, fixing a real 1-in-4 flake where a mutation published to zero subscribers was lost
- [Phase ?]: DownloadsFeatureTests fully de-serialized: all 38 traits removed, none retained; .serialized is within-suite only, so no trait could have guarded cross-suite state
- [Phase ?]: DownloadCoordinator gained an injectable clock (now:, defaults to Date()) so the progress-flush throttle's wall-clock branch can be frozen off in tests
- [Phase ?]: TCA TestStore is main-actor-bound; 85/104 DownloadsFeatureTests cases legitimately require @MainActor — the sweep's ceiling is the library, not annotation hygiene
- [Phase ?]: Annotate members, never the suite type: a @MainActor type carries a main-actor protocol conformance that @Sendable dependency closures cannot call
- [Phase ?]: Test plan gap: EhPanda scheme silently skipped CookieClientTests, ImageClientTests and ReadingFeatureTests; added (523 -> 565 tests)
- [Phase ?]: ImageClientTests needs no @MainActor: UIGraphicsImageRenderer/UIImage fixture rendering is not main-actor-bound; all 9 cases freed
- [Phase ?]: DownloadsFeatureTests reaches zero optional-try; 2 of 155 sites became plain try (1.3%) — the target is IO-heavy, 83% are defer-cleanup which cannot throw
- [Phase ?]: removeTemporaryItem moved from the DownloadFeatureTestCase protocol extension to a free function; 7 suites declare no conformance and could not reach it
- [Phase ?]: No hidden broken tests surfaced in this target, unlike 11-09 and 11-20
- [Phase ?]: optional_try flipped to error repo-wide (D-15, no Tests exclusion); doccomment added to excluded_match_kinds because the drafted pair flagged a real doc comment; zero exception directives repo-wide
- [Phase ?]: sorted_imports live at error, 893 violations resolved 100% by --fix across 325 files
- [Phase ?]: Stale top-level excluded: EhPanda/App/Generated removed — the path died with the modularization, nothing replaced it
- [Phase ?]: 325-file autocorrect reviewed by diff-shape assertion (only import lines changed; Swift half net-zero) rather than reading every file
- [Phase ?]: 11-26: single_line_trailing_closure Sources half — 145 sites (not ~149) rewrapped, 130 parenthesized / 7 multi-line; config untouched, flip stays with 11-27
- [Phase ?]: 11-27: single_line_trailing_closure live at error, 0 across all four roots; Tests half was exactly 70 sites (215 phase total)
- [Phase ?]: 11-27: doccomment added to the drafted excluded kinds — the rule contrasts two syntactic forms, so a doc comment quoting the rejected one must not fire; 0 matches today
- [Phase ?]: 11-27: no nested-closure trap in Tests — 4 of 6 nested sites sit in accessor braces, 2 in an unpoliced dependency-override closure; parenthesizing was the only fix, not a silencing shortcut
- [Phase ?]: multiline_function_chains live at error (SwiftLint defaults) — the seventh and final LINT-01 rule flip; 43 chained-call sites reformatted across 19 Sources files
- [Phase ?]: The rule's ~85 raw violations deduplicate to 43 real sites — it reports once per chain-link pair, so the headline count double-counts
- [Phase ?]: 11-31: Page-count icon parity is restored with .imageScale(.medium), not the plan's .small — .small undershoots the pre-sweep glyph by 3.25pt (~20%)
- [Phase ?]: 11-31: The Label icon inflation is list-specific; free-standing, a Label's icon already matches a bare Image exactly (20x16). Re-deriving this outside a List gives the wrong answer.
- [Phase ?]: 11-31: No automated parity test ships — rendering a List for measurement needs a UIWindow, and every scene-free UIWindow initializer is deprecated on iOS 26 with no window scene available in the test host
- [Phase ?]: 12-01: AppError.cloudflareChallengeFailed carries no associated value — per-incident diagnostics stay in ErrorInfo.context, which structurally keeps the clearance value out of every user-visible string
- [Phase ?]: 12-01: The new error's recovery suggestion names the real screen (Account Configuration), not the plan's placeholder wording, so the suggestion points somewhere reachable
- [Phase ?]: 12-01: An unsolved Cloudflare wall is account-level fatal in the page-download batch guard — it blocks every request and the case is non-retryable; unreachable today but the safe arm when D-05 detection widens
- [Phase ?]: 12-01: The clearance pair is a named Sendable struct, not a tuple (labeled_tuple_elements at error), and lives in an InMemoryKey whose strategy IS the C5 no-persistence guarantee
- [Phase ?]: 12-03: ChallengeWebViewController is its own WKHTTPCookieStoreObserver — the store does not retain observers, and the view hierarchy already keeps the controller alive
- [Phase ?]: 12-03: Observer teardown runs in dismantleUIViewController, not deinit — a MainActor-isolated deinit cannot touch WKHTTPCookieStore
- [Phase ?]: 12-03: LoginClient.live is a named function, not a closure literal, so LoginRequest's typed throws(AppError) survives the seam
- [Phase ?]: Folded the Cloudflare challenge flow into LoginReducer rather than a child feature: one destination, one counter and four actions would need the parent's credentials, loginState and CancelID anyway
- [Phase ?]: One shared login effect serves the first POST and every retry, so a retry can never take a path that skips challenge classification
- [Phase ?]: 12-05: Per-case InMemoryStorage override isolates the process-wide @Shared(.cloudflareClearance) holder — isolation by construction, no teardown a future case can forget
- [Phase ?]: 12-05: The challenge bound is proven by walking two full rounds through the reducer, not by asserting on challengeRounds
- [Phase ?]: 12-05: D-02 silence is proven by an exhaustive TestStore receiving nothing after the dismissal — no negative assertion to keep in sync
- [Phase ?]: 12-05: LockIsolated mutates via withValue; withLock belongs to the @Shared projection (first-compile error worth remembering)
- [Phase ?]: 12-06: The Cloudflare clearance is captured by polling the web view's cookie store — WKHTTPCookieStoreObserver alone never fired for page-set cookies on the live wall, and a didFinish check read an empty jar before WebKit propagated it
- [Phase ?]: 12-06: A swipe-dismissal of the challenge sheet is detected by reading the destination BEFORE BindingReducer applies the write — every Destination case is @ReducerCaseIgnored, so PresentationAction.dismiss is never routed and SwiftUI echoes the reducer's own dismissals through the same binding
- [Phase ?]: 12-06: loginDone applies the response's credentials before consulting didLogin — 12-02's clearance retry sets httpShouldHandleCookies = false, so URLSession no longer files the response's Set-Cookie and didLogin saw pre-login state
- [Phase ?]: 12-06: Every login failure arm raises a toast; only the Cloudflare arm had one, and the missing surface is why the didLogin bug presented as total silence
- [Phase ?]: 12-06: AppError.loginCaptchaRequired is deliberately separate from .cloudflareChallengeFailed — both are Cloudflare, but only the edge challenge is clearable by the in-app surface, so conflating them would point at the wrong recovery
- [Phase ?]: 12-06: The login response body is parsed for the forum's error box under BOTH labels it uses; reading only the first is how the Turnstile requirement went unreported through several rounds of diagnosis
- [Phase 13]: GalleryURLParser.Route carries normalized url, gid, pageIndex, commentID, and isGalleryImageURL as the call-site migration contract. — Centralizes normalization and eliminates optional round-trips and empty-string failure sentinels.
- [Phase 13]: Gallery hosts are derived from Defaults.URL anchors and matched exactly with computed www variants. — Preserves the canonical hosts while rejecting substring spoofing and accepting real-world www share links.
- [Phase ?]: 13-02: Context.unsupportedLink(url:) stores a URLComponents-sanitized rendering under ContextKey.link.
- [Phase ?]: 13-02: Unsupported-link diagnostics retain scheme, host, and first path component only; deeper paths become one ellipsis.
- [Phase ?]: 13-02: AppError.unsupportedDeepLink is non-retryable and non-fatal to account-wide download batches.
- [Phase 13]: Use GalleryURLParser route.url after parsing custom-scheme links. — Preserves the former HTTPS normalization while removing the injected client.
- [Phase 13]: Keep fallback, timing, cancellation, and no-op behavior unchanged during the parser seam swap. — Failure policy and deterministic timing changes belong to later Phase 13 plans.
- [Phase 13]: Reducer tests now exercise production GalleryURLParser behavior directly. — The removed deterministic dependency no longer needs noop or custom test overrides.
- [Phase 13]: Clipboard discovery validates route support before entering the explicit-open handler, preserving silence for unsolicited URLs.
- [Phase 13]: Unsupported explicit input uses the sanitized unsupported-link context directly so raw access-bearing URLs do not enter ErrorInfo.
- [Phase 13]: ShareExtension rewrites only URLComponents.scheme and completes the request when conversion cannot produce a URL.
- [Phase 13]: SwiftUI reports sheet dismissal completion as a fact; PresentationFeature alone decides whether to re-present a pending gallery.
- [Phase 13]: Gallery fetching begins immediately while only the final presentation waits for dismissal completion.
- [Phase 13]: A later deep link clears any pending replacement and cancels the superseded fetch so the latest request wins.
- [Phase ?]: 13-06: Toast overlay animation follows the presented AppAlertState UUID, covering presence and replacement at one scoped boundary.
- [Phase ?]: 13-06: Gallery failure reducers replace loading toasts synchronously; only successful resolution clears before routing.
- [Phase ?]: 13-06: The existing id-keyed auto-dismiss task remains unchanged so replacement cancellation and timer restart semantics stay intact.
- [Phase 13]: Use Synchronization.Mutex for the URLProtocol fixture directory. — Foundation URLProtocol callbacks are synchronous, so checked synchronous state is the correct concurrency boundary.
- [Phase 13]: Override clipboard reads only and preserve live save endpoints. — The seam bypasses the paste prompt without changing application write behavior.
- [Phase 13]: Attach reading_page_indicator to ControlPanel's numeric Text. — That is the actual page-index element whose existing label carries current and total pages.
- [Phase 13]: Cold UI-test delivery uses XCUIApplication.open(_:) after the Xcode 26.6 / iOS 26.5 probe proved both URL and hermetic environment delivery.
- [Phase 13]: Warm UI-test delivery uses XCUIDevice.shared.system.open exactly; runner-bundled fixtures keep the UI suite offline and credential-free.
- [Phase 13]: Cold scheme tests explicitly terminate before URL delivery; warm tests prove foreground state and never relaunch after opening.
- [Phase 13]: Reader and toast identifiers are assigned after forming explicit accessibility containers so nested destination markers remain distinct.
- [Phase 13]: Comment deep-link coverage proves detail remains beneath comments by navigating back after locating the linked comment.
- [Phase 14]: D-15: the full eleven-case Category enum ships, including imageSet and private — D-07's nine-name parenthetical was incomplete recitation, not deliberate narrowing
- [Phase 14]: D-16: per-namespace tag counts ship as exact Int values, not through CountBucket — an amendment giving D-08 a second documented exception, at the cost of a larger aggregate re-identification surface
- [Phase 14]: D-17: a random 64-character salt is stored beside the app ID in the gitignored Analytics xcconfig; the value is write-once because changing it after release permanently resets retention and DAU/MAU
- [Phase 14]: D-18: the SwiftLint custom rule rejecting the TelemetryDeck SDK import outside AnalyticsClient is approved, putting plan 14-17's conditional lint task in scope
- [Phase 14]: D-19: TagNamespaceCounts(tags:) and SearchShape(keyword:) live inside AnalyticsClient as the audited reduction boundary — an amendment to D-09 permitting exactly one String parameter on the module's public API
- [Phase ?]: [Phase 14]: 14-03: TagNamespaceCounts stores exact [TagNamespaceKey: Int] counts per D-16; the plan frontmatter's four bucketing assertions are superseded and recorded, not silently diverged from
- [Phase ?]: [Phase 14]: 14-03: TagNamespaceKey (known/unrecognized) is a new closed key type — TagNamespace has no unrecognized case, and widening the key to String would re-admit the scraped raw namespace D-06 forbids
- [Phase ?]: [Phase 14]: 14-03: a namespace's count is the sum of its GalleryTag contents, not the number of GalleryTag values; a zero-content tag contributes no key so absent stays absent
- [Phase ?]: [Phase 14]: 14-03: Category gained an analyticsName spelling rather than shipping its scraped display raw values, making the eleven-case D-15 set a compile-time commitment
- [Phase ?]: [Phase 14]: 14-03: raw values are left implicit throughout the vocabulary (redundant_string_enum_value is on by default) and every spelling is pinned in tests instead — a rename fails a test naming the dashboard column it would orphan
- [Phase ?]: [Phase 14]: 14-03: AnalyticsErrorCategory follows failure origin — thrown-exception for a failed operation, app-state for an account/host gate, user-input for what the user supplied or asked for
- [Phase ?]: [Phase 14]: 14-03: the reflection leak probe lives in one shared test file (Mirror.leafRenderings) rather than duplicated across three suites, and every sentinel sweep carries a vacuity guard
- [Phase ?]: 14-04: D-17's salt rides the same path as the app ID — TELEMETRYDECK_SALT, TelemetryDeckSalt, AppInfo.telemetryDeckSalt — extending plan entries written before the decision
- [Phase ?]: 14-04: The salt is generated by the owner on the release machine, never by the plan — a generated value in the tree would either be committed or presume a write-once choice that is the owner's
- [Phase ?]: 14-04: Committed-outer / optional-inner xcconfig confirmed on this Xcode — #include? of an absent file is a silent no-op, so a clean clone builds warning-free (research assumption A3)
- [Phase ?]: 14-04: Bundle.main from an SPM module reaches the app bundle's substituted keys, proven by PlistBuddy against a built bundle rather than the source plist (research assumption A2)
- [Phase ?]: 14-04: AppInfo's analytics accessors trim before testing emptiness, so a stray space or newline in the local override cannot present as a credential the SDK would reject at runtime
- [Phase ?]: 14-05: AnalyticsSignal is a closed thirteen-case enum no reducer can escape; the single no-default rendering switch is the only site that mints an analytics name or key (D-09)
- [Phase ?]: 14-05: both D-08 exact-Int exceptions render decimal — keyword length (D-07) and per-namespace tag counts (D-16); Task 2's 'one permitted exact Int' wording is superseded
- [Phase ?]: 14-06: AnalyticsClient is the single SDK import site (D-12); its live value is gated on AppInfo.telemetryDeckAppID so a nil credential resolves the whole client to no-op (D-13), and it configures the SDK with both the app ID and the D-17 salt.
- [Phase ?]: 14-06: D-11 default parameters re-read live shared settings per signal via @Shared/@SharedReader declared inside the SDK's defaultParameters closure, never snapshotted at init.
- [Phase ?]: 14-07: hardened all 55 DownloadsFeatureTests TestStore sites to analyticsClient = .noop ahead of wave-6 instrumentation; client testValue = .unimplemented left intact
- [Phase ?]: [Phase 14]: 14-08: Hardened all 28 SettingFeatureTests TestStore sites to analyticsClient = .noop (via factories where present) ahead of wave-6 SettingFeature instrumentation; testValue = .unimplemented left untouched.
- [Phase ?]: [Phase 14]: 14-08: Behavioral probe PASS — a temporary real analyticsClient.send from LoginReducer.login kept the target green, proving per-store dependency resolution, then reverted with an empty git status for AppPackage/Sources.
- [Phase ?]: 14-09: Hardened all 24 TestStores across AppFeatureTests/HomeFeatureTests/DetailFeatureTests/ReadingFeatureTests to analyticsClient = .noop; scoped-child stores in the app-root target included; behavioral probe green from all four modules.
- [Phase ?]: 14-10: analytics SDK initialized once from onLaunchFinish reducer effect, never a view callback (D-14)
- [Phase ?]: 14-10: tabOpened emits only on a genuine tab switch; error-detail drill-down and caption-only toasts emit nothing (T-14-13)
- [Phase ?]: 14-11: Home section/misc taps emit homeSectionViewed through one exhaustive mapping (no default: arm)
- [Phase ?]: 14-11: galleryDetailOpened emits on the Home push case only, avoiding double-count with the iPad modal (T-14-13)
- [Phase ?]: 14-12: performed-search analytics emits from the fetch-completion case (result count known there); the fetch-request and history-keyword cases stay deliberately silent to avoid double-counting and keyword leakage
- [Phase ?]: 14-12: quick-search word usage is a payload-free QuickSearchReducer.wordTapped action — the word is forbidden content (D-06), so the signal carries nothing about it
- [Phase ?]: 15-01: UIBackgroundModes keeps processing with an in-plist rationale comment — no Apple source says it is unnecessary for continued-processing, and a wrong removal fails every submission with notPermitted.
- [Phase ?]: 15-01: RESEARCH A2 settled by observation — $(PRODUCT_BUNDLE_IDENTIFIER) DOES expand inside a BGTaskSchedulerPermittedIdentifiers array entry (built plist prints app.ehpanda.continued.*); no literal fallback needed.
- [Phase ?]: 15-01: Deletions took their orphans with them — AppDelegateReducer's file-scoped logger + OSLogExt import, and the test suite's stale @MainActor rationale comment.
- [Phase 15]: 15-02: Both older background-execution mechanisms are deleted outright; hasPendingWork survives as a mechanism-free schedulable-work predicate in DownloadClient+PendingWork.swift — D-01/D-02 make the deletion the design; deleting before rebuilding keeps every intermediate commit green
- [Phase 15]: 15-02: scheduleNextIfNeeded stays a forwarder over its core, with a comment recording that its tail is the single convergence point every queue mutation reaches — Plan 15-06 re-hangs a session reconcile there; collapsing the forwarder would delete the rationale with the call
- [Phase 15]: 15-02: Shared test fixtures that non-conforming suites must reach live at file scope, reaching protocol-extension factories through a private empty conformer — Seven suites in DownloadsFeatureTests declare no DownloadFeatureTestCase conformance, and a file-scope function has no receiver for a protocol default
- [Phase ?]: [Phase 15]: 15-03: The continued-processing launch handler and expiration handler inherit main-actor isolation directly; no MainActor.assumeIsolated is needed (settles RESEARCH Assumption A3).
- [Phase ?]: [Phase 15]: 15-03: The session store clears its task and continuation before any terminal call, making a second terminal transition structurally impossible rather than merely guarded.
- [Phase ?]: 15-04: Card subtitle declares completed/total/galleries as named lld substitutions, so the generated symbol takes three labeled Int parameters and no String — no gallery identity can reach the system card
- [Phase ?]: 15-04: DownloadCoordinator stores backgroundProcessingClient with a .noop default; the live composition root injects .live, keeping every pre-existing test construction compiling
- [Phase ?]: 15-04: The session spy takes and clears its continuation in one critical section, so a double terminal transition is structurally impossible in tests as it is in production
- [Phase ?]: 15-05: Session lifecycle methods are public, matching the module convention, so the lifecycle suite can drive them without @testable
- [Phase ?]: 15-05: The pushed session total is held at or above the monotonic completed count, so a queue shrink cannot report a fraction above one
- [Phase ?]: 15-06: the card's pushed subtitle is built from the same clamped counts the progress bar receives, so a queue shrink cannot show a full bar beside a zero-of-four caption
- [Phase ?]: 15-06: expiration parity is asserted against a per-gallery pause baseline computed from an identical fixture, never against a hard-coded display status
- [Phase ?]: 15-06: session progress rides the throttled manifest flush (one throttle for both the manifest write and the card), because steady progress reporting is what keeps the scheduler from expiring the task as stalled
- [Phase ?]: The topology decision is enforced by a source-tree invariant that scans the app target, package sources, package tests, the extension and App/Info.plist for eight deleted background-execution spellings, demonstrated failing on a deliberate violation before acceptance
- [Phase ?]: App/Info.plist is exempt only from the scheduler-scope assertion and is paid for by a paired count assertion, because the system key name contains the scheduler type name by construction
- [Phase ?]: Every scanned token is assembled from fragments at run time so the invariant file is not a self-match and the repository grep gates can still read zero
- [Phase ?]: ROADMAP Phase 15 amended to the shipped contract: no fallback tier in SC3, session seam plus coordinator in SC4, and the open scope question recorded as resolved rather than deleted
- [Phase 15]: 15-09: The continued session carries a per-session UUID minted with the liveness flag; every late-arriving teardown, event and post-suspension resume must present it, so a superseded session can no longer detach a live one (CR-02/WR-01).
- [Phase 15]: 15-09: The non-initial cancelQueuedWorkItem branch converges through scheduleNextIfNeeded rather than reconciling inline, so it inherits the reconcile tail like every other queue mutation (WR-04).
- [Phase 15]: 15-10: The background-processing seam returns an optional identified session handle; only that handle's id may complete the store session.
- [Phase 15]: 15-10: The coordinator records the client id only after its ownership re-check and leaves it nil while start is in flight.
- [Phase 15]: 15-10: A refused start rolls back only the requesting coordinator stamp so the next queue-mobilizing action can retry.
- [Phase 15]: 15-10: Shared continued-session fixtures live in DownloadFeatureTestHelpers to preserve the hard file-length gate and support plan 15-11.
- [Phase 15]: Record accepted starts completely before parking behind the deterministic one-shot gate. — The entered signal must expose the exact in-flight identity state without polling.
- [Phase 15]: Model client refusal as an observable call that creates no session identity or event stream. — The spy must reproduce the store contract so coordinator rollback and retry remain testable.
- [Phase 15]: 15-12: Capture title, subtitle, completed count, and total count from one coordinator snapshot before submitting the continued session.
- [Phase 15]: 15-12: Every card progress mutation presents the client session id read after the coordinator's post-suspension ownership re-check.
- [Phase 15]: 15-12: Stage stale progress after seam entry but before the identity guard so S1-to-S2 rejection is deterministic.
- [Phase 15]: 15-13: Preserve the vanished-record delete's not-found contract, but publish settled state and enter scheduling convergence before returning.
- [Phase 15]: 15-13: Keep activeTask as a documented fast path while routing every disk-backed schedulable-work decision through one actor-isolated authority.
- [Phase 15]: 15-13: Observe scheduling with an injected skipped-operation runner and await observer task values instead of polling.
- [Phase 15]: Queue-intent generation is distinct from active-task generation and advances only when a user action writes fresh queue intent.
- [Phase 15]: A superseded expiration pause converges only after its scheduling block is lifted, completing the queue-mobilizing user action that superseded it.
- [Phase 15]: Blocking runners release on cancellation by default while an explicit opt-out preserves a deterministic interleave window.
- [Phase 15]: Drive expiration through the real event handler so coverage includes session teardown before the per-gallery pause.
- [Phase 15]: Hold the scheduled runner after cancellation so retry lands after the first ownership guard and before settled pause writes.
- [Phase 15]: Keep user-initiated pause last-writer-wins behavior as the explicit boundary of the expiration-only generation guard.
- [Phase 15]: Owner selected option-b on 2026-07-29: remove the unread background-processing dependency registration while preserving direct injection and the macro-generated unimplemented client.
- [Phase 15]: A queue drain that cannot name the client session is early rather than authoritative; reconciliation remains debt owned by the current coordinator session.
- [Phase 15]: The session spy records every start attempt but refuses one while an identity is held, releasing that identity only through matching finish or expiration.
- [Phase 15]: Pause error exits converge unconditionally, including expiration-owned pauses, without starting a continued-processing session.
- [Phase 15]: Interrupted-download normalization may omit scheduling only when no active task exists and its caller deliberately requested notification-only reconciliation.
- [Phase 15]: Remove gallery titles from completion and enqueue logs; neither operational message needs content names.
- [Phase 15]: Hash-mask gallery identifiers so download events remain correlatable without disclosing gallery identity.
- [Phase 15]: Keep raw errors, localized descriptions, and rejected-response snippets private throughout DownloadClient.
- [Phase 15]: Scope the log-privacy invariant to DownloadClient after auditing two non-gallery BackgroundProcessingClient fields.
- [Phase 15]: 15-20: D-G2-01 — a gallery leaving the schedulable set retires exactly the pages it finished, added to both sides of the session fraction; one formula covers every departure path
- [Phase 15]: 15-20: The retirement ledger is maintained by a push-time membership sweep, not a hook in settleCompletedDownload, so all six departure paths are covered by construction
- [Phase 15]: 15-20: D-10 is extended (not reopened) — the pushed pair carries retired pages alongside live schedulable work; the user-visible contract is unchanged
- [Phase 15]: 15-21: no production code changed — D-G2-01's single formula already covered pause, delete and rejoin, and every new case passed on its first run
- [Phase 15]: 15-21: cases driving a real product primitive assert the last pushed update; cases asserting a whole pushed series use the deterministic queue-set seam
- [Phase ?]: 15-22: D-G2B-01: the drain branch of reconcileContinuedSession emits exactly one progress push, after the client-session deferral and before markContinuedSessionEnded — a later position compiles and silently does nothing
- [Phase ?]: 15-22: DEC-A left unresolved: the terminal push ships with an identifier-free drain log as the discriminator; rebasing galleryCount onto the session's whole coverage is a documented-contract change withheld from the executor
- [Phase ?]: 15-22: DEC-B: nothing in this plan closes G-15-2B — 15-UAT.md test 2 stays a physical-device gate and SC2 stays PRESENT_BEHAVIOR_UNVERIFIED
- [Phase ?]: 15-23: The drain-branch re-check guards drain-ness (hasPendingWork() == false), not session identity — identity provably cannot change inside the terminal push's main-actor hop, while drain-ness can.
- [Phase ?]: 15-23: The client-seam test double must suspend wherever the live main-actor-confined value does; BackgroundProcessingClientSpy now yields on start/updateProgress/finish.
- [Phase ?]: 15-23: One terminal-shaped progress push is accepted as a transient — the push's arguments are computed before the hop and re-checking ahead of the push cannot exist, because the push is the suspension.
- [Phase ?]: 15-24: D-G4-01: a schedulable gallery's session-completed pages are its record's count only when the record reads incomplete or this session already observed it incomplete; otherwise zero
- [Phase ?]: 15-24: The G-15-4 fix keys on the record and an earned trust set, not on queuedModes: mode-keying would mask mid-run progress and misses the bare re-enqueue route
- [Phase ?]: 15-24: shouldSchedule is deliberately untouched: reordering its completeness check ahead of the work-item short-circuit would make every queued redo unschedulable
- [Phase 15]: 15-25: D-G5-01 — the working manifest never claims a page whose file is absent; reconciled inside prepareWorkingSeed, the one point every start mode's run converges on, so .repair, the .initial reuse and the repair-seed materialization are covered by one rule.
- [Phase 15]: 15-25: Record honesty alone is not observable — the run announces its post-preparation basis through prepareWorkingSeedAnnouncingProgress before any page work, because trust is admitted only inside a push's reconcile and no pre-existing push is guaranteed to run during the incomplete window (deterministically none at one missing page).
- [Phase 15]: 15-25: WR-03 folded in as the one recorded trust-machinery exception — ensureContinuedSession's post-re-check seed merges (formUnion / keep-observed) instead of overwriting, so an observation recorded inside the client-start main-actor hop survives; safe because the superseded-start rule is enforced by the preceding identity guard.
- [Phase 15]: 15-25: The plan's holdNextStart/releaseHeldStart spy artifact was not added — the spy's pre-existing armStartGate() already parks the next accepted start with the identical contract, so a second pair would be a thin wrapper CLAUDE.md forbids.
- [Phase 15]: 15-26 D-G6-01: a coordinator-made basis correction withdraws its counted portion from the monotonic floor in the same synchronous stretch that lowers the basis — the floor masks only movements the coordinator did not deliberately make.
- [Phase 15]: 15-26: the withdrawal lives inside reconcileWorkingManifestAgainstPageFiles (whoever blanks, withdraws), unclamped, with the session-start floor seed converted to max(snapshot + floor, 0) so a hop-window correction is folded in rather than overwritten.
- [Phase 15]: 15-26 WR-01: schedulableDownloads() unions activeGalleryID into its queue-scoped read (dedupe, empty-queue full read preserved); the predicates and scheduleNextIfNeededCore's own read are untouched.
- [Phase 15]: 15-26 WR-02: prepareWorkingSeed is private so the announcing wiring cannot silently revert — the demonstrated suite-green revert is now a compile error.
- [Phase ?]: [Phase 15]: 15-27: The spy's single-session guard and its one-shot refuseNextStart arm are separate refusal causes with separate guards; only the arm's own branch consumes the arm (G-15-10)
- [Phase ?]: [Phase 15]: 15-27: When the double itself is the subject under test, the regression drives the spy's own client endpoints; a coordinator fixture would add choreography that cannot discriminate the defect
- [Phase ?]: All nine session-lifecycle mutators drop to internal, but only six get testing forwarders: a forwarder without a test consumer is the attack surface G-15-11 removes
- [Phase ?]: Every private helper in DownloadContinuedSessionTests.swift was exclusive to the relocated expiration family, so none was lifted into DownloadFeatureTestHelpers.swift
- [Phase ?]: 15-29: the basis withdrawal is keyed on the pre/post downloadIndex[gid] delta (D-G7-01), never on a named mechanism — one non-async bracket wrapping prepareWorkingSeed's whole preparation and writeInitialManifest's body
- [Phase ?]: 15-29: an absent after-reading defaults to the before-count, so a record that vanished during a movement withdraws nothing — departures stay the retirement ledger's alone
- [Phase ?]: 15-29: the bracket is module-internal because writeInitialManifest lives in another file; one implementation stops the rule forking between the run route and the enqueue route
- [Phase ?]: 15-30: Enumeration failure is surfaced as an optional from existingAssetFileURLs; ~10 non-destructive probe callers keep their [] fallback through existingPageRelativePaths, now a pages-only forward to pageFileScan.
- [Phase ?]: 15-30: The wholesale-blank refusal is blankedPageCount < manifest.completedPageCount — only claimed pages are blanked, so equality means every claimed page would go: the signature of per-file probe failure en masse, not proof of loss.
- [Phase ?]: 15-30: An all-pages-vanished repair deliberately falls back to the pre-D-G5-01 arc (empty existingPages makes the run re-fetch; honesty catches up at flush time), accepted against letting one transient enumeration failure destroy every recorded hash.
- [Phase ?]: 15-31: The scheduling block is a per-operation reference count ([String: Int]); schedulability tests ABSENCE of a key, never a stored zero, so releaseScheduling removes the entry at zero and the three readers cannot drift from the count.
- [Phase ?]: 15-31: commitPause's not-found exit converged nowhere and its caller returns .settled verbatim — the plan's expected 'convergence owned one frame up on every path' was false in source, so the exit was fixed rather than documented as intended.
- [Phase ?]: 15-31: An unmatched releaseScheduling logs at .error and leaves the dictionary untouched; decrementing anyway would consume a different live operation's hold and strand that operation's download.
- [Phase ?]: 15-31: The mid-suspension teardown window is narrowed to each operation's own suspensions but deliberately left unstaged — closing it deterministically would need production suspension hooks the gap's suggested_fix does not ask for.
- [Phase 15]: 15-32: The IN-05 union staging premise was false in source — a complete record in the persisted queue reads .queued and is schedulable, so the queued remainder is made unschedulable by a live operation's scheduling block instead.
- [Phase 15]: 15-32: A doc-comment falsifiability claim is run, not asserted — the union was temporarily reverted and the new case observed failing at exactly its first expectation.
- [Phase 15]: 15-33: D-G13-01 — destroying a recorded content hash requires a positive PER-FILE probe determination on top of the positive directory-level one; a listed-but-unanswerable page file is never blanked.
- [Phase 15]: 15-33: The per-file probe is an exhaustively switched AssetFileProbeOutcome (usable / rejected / unprobeable) rather than a second Bool, so a probe exit nobody has enumerated yet cannot default into 'positively absent'; sanitizeAssetFileIfNeeded stays as its Bool forward for the ~10 non-destructive callers.
- [Phase 15]: 15-33: unprobedPages is added ALONGSIDE scanSucceeded, not in place of it — the directory-level and per-file signals answer different questions and the reconciliation consumes them independently.
- [Phase 15]: 15-34: D-G14-01 — a zero-page payload is refused at enqueue with .notFound before any folder or queue mutation, and a zero-page mid-run refetch throws at fetchLatestPayload so the run's existing catch settles the download as failed rather than fake-completing a 0-of-0 record.
- [Phase 15]: 15-34: The zero-page range-guard invariant was swept to its whole class (four sites), so each guard's module-wide comment is derivable in source rather than aspirational.
- [Phase 15]: 15-35 WR-01: a push landing while the client identity is nil is dropped, not replayed — only the drain branch records reconciliation debt, and the next flush or convergence push repaints. The flag is deliberately not set at the skip.
- [Phase 15]: 15-35 WR-02: one canonical wording — 'same-actor calls that do not suspend today; an await introduced inside them reopens this window and needs its own re-validation' — applied at every site claiming about the hasPendingWork/schedulableDownloads chain.
- [Phase 15]: 15-35 WR-04: lastPushedCompletedPageCount names five writers including markContinuedSessionEnded's teardown zero, labeled exhaustive by grep at HEAD.
- [Phase 15]: 15-36: writeSettledPauseRecord is KEPT with a traced reason — its writers are the queue-mobilizing entry points landing inside the unbounded wait, not the cancelled run's teardown
- [Phase 15]: 15-36: commitPause is non-throwing end to end by compiler enforcement; both pause-record helpers drop throws and the unread download parameter
- [Phase 15]: 15-36: an unmatched scheduling release is reported via reportIssue with a static identity-free message before the hash-masked log; the guard still returns without mutating
- [Phase 15]: 15-37: WR-09's dispositioned removal of the superseded-arm ensure was probed and REVERTED — it fails the pinned interleave regression because the mobilizing action's own ensure is swallowed by this pause's scheduling block; the gap's second authorized remedy (observable restatement) landed instead
- [Phase 15]: 15-37: The log-privacy invariant scans BackgroundProcessingClient under the download client's rules with a per-root known member, no allowlist entry and no exemption; extended before the log fix, it failed RED on the raw error value
- [Phase 15]: 15-37: The continued-session state is module-internal; testingContinuedSessionTask() is the suites' one route to the session task, both boundary greps empty
- [Phase 15]: 15-38: The throwing-submission producer asserts a defensive take-back, not the gap's cancels-nothing expectation, which predates 15-37's identity-before-submission reorder.
- [Phase 15]: 15-38: A test double's bounded rendezvous must precede its unbounded one, so the regression the case exists to catch fails at a deadline instead of hanging the suite.
- [Phase ?]: [Phase 15]: 15-39: materializeRepairSeed carries the source scan's non-answers across the seed copy — setupWorkingFolder returns them and prepareWorkingSeed unions them into the destination scan, so the existing D-G13-01 refusal covers laundered pages with no new refusal mechanism.
- [Phase ?]: [Phase 15]: 15-39: A scan-selected page the pre-copy guard skips joins the carried set rather than throwing — carrying re-fetches one page, throwing fails the whole preparation.
- [Phase ?]: [Phase 15]: 15-39: PageFileScan's collapse licence is route-scoped, not call-scoped: a caller may collapse the pairs only if its output can never feed a destructive decision, in this folder or any other.
- [Phase ?]: 15-40: WR-03 and WR-04 both took the comment-only remedy — the gap record's own premises did not survive re-derivation (four of seven probe callers read listing-derived paths, and the suggested comparison change contradicts the verification's own detail)
- [Phase ?]: 15-40: Every inventory a doc still carries is pinned by DownloadSourceInventoryTests, whose scanner skips comment lines so a doc citing an inventory is not part of it
- [Phase ?]: 15-41: WR-06 took both halves — dead disjunct deleted AND the function renamed clearCancellationLikeDownloadErrors, precision over normalize* prefix symmetry
- [Phase ?]: 15-41: IN-03 took the test pin over a recorded derivation — makeInitialManifest + updateDownloadIndex reach captureCachedPage with a zero-page record without any new seam
- [Phase ?]: 15-41: the basis suite split cut on helper usage — landPageFiles stays, restorePermissions travels, nothing promoted; 996 lines becomes 692 + 342
- [Phase 15]: 15-42: the mid-sweep regression stages BOTH galleries queued — a gallery outside the queue is not in the sweep's gid snapshot, gets no iteration, and can express neither the defect nor the fix
- [Phase 15]: 15-42: testingContinuedSessionTask's four-consumer roster replaced by the invariant it stood for (capture before firing the expiration), so an added case cannot falsify it
- [Phase ?]: 15-43: the announcement gate replaces the completeness test rather than OR-ing with it; the one shape that loses its announcement (record incomplete, folder holds every claimed page) fetches nothing, so trusting it would breach D-G4-01's ceiling
- [Phase ?]: 15-43: trust is granted at the run's own preparation, after prepareWorkingSeed's D-G7-01 bracket closes, so the granting movement withdraws nothing and later movements withdraw their counted portion
- [Phase ?]: 15-43: the failed-enumeration companion uses 0o311 and five of six page files, since 0o000 blocks the manifest read and a fully-backed folder routes to .redownload instead of .repair
- [Phase 15]: schedulableDownloads() is the SHARED READ of three named callers, not an authority the scheduler reads; only the isSchedulableDownload predicate is shared. — The scheduler performs its own queue-scoped read, so widening or narrowing this read does not move it; the false claim had survived five rounds in two files.
- [Phase 15]: WR-02's post-launch BGTaskScheduler.register timing is answered with a device-verified note, not a code change. — A per-session UUID identifier under the bundle-scoped wildcard makes pre-launch registration structurally impossible, and 15-UAT.md test 1 passed on physical iOS 26 hardware.
- [Phase 15]: 15-45: restoredIndices drops its prefix(completedCount) bound — proven equal to the whole array from the two writers of completedCount (assigned results.count immediately upstream, incremented only downstream), not asserted.
- [Phase 15]: 15-45: validPageCount(folderURL:manifest:) deleted outright — zero callers repo-wide across App/, ShareExtension/, EhPandaUITests/, AppPackage/Sources and AppPackage/Tests.
- [Phase 15]: 15-45: isReadableAssetFile(at:) deleted rather than kept-with-a-reason — it was a bare forward to the PUBLIC sanitizeAssetFileIfNeeded(at:), so remedy (a)'s precondition is satisfied by its own callee, which all seven production call sites already use.
- [Phase 15]: 15-45: the attributes-throw fallback pin is rerouted, not dropped — testSanitizeAssetFileIfNeededDoesNotDeleteFileWhenAttributesLookupFails keeps the same ThrowingAttributesFileManager staging and both assertions on the production surface.
- [Phase ?]: 15-46: A test double that drives a state-storing production route builds its payload through the production steps that read that state — never a literal. — The normalizer's equality guard returns the payload untouched, so normalizing alone leaves a nil selection and only looks repaired.
- [Phase ?]: 15-46: The binding between a double and the route it models is owned by a named pin case, with the production event holding the state in place named in its doc comment.
- [Phase 15]: 15-47: The session announcement is gated on the run's own pending page list, not the working folder's shortfall against its manifest — the shortfall ignores payload.pageSelection and credits a selected-page retry that fetches nothing (G-15-27).
- [Phase 15]: 15-47: The pending list is derived exactly once per run, inside prepareWorkingSeedAnnouncingProgress, and handed to performDownload via PreparedWorkingRun — pinned by a fourth census in DownloadSourceInventoryTests so a second evaluation fails a build.
- [Phase ?]: [Phase 15]: 15-48: The proof of real page work is owned by the RUN (provenPageWorkRunGIDs) and READ by whatever session is live; the session trust set is seeded from it at every start, never the owner of it.
- [Phase ?]: [Phase 15]: 15-48: The run-end retirement sits in processDownload's defer — the only point all FIVE run exits pass — gated on 'no live run for the same gid at a different generation', because pause/delete/folder operations null activeTask mid-run.
- [Phase ?]: [Phase 15]: 15-48: A guard that passes vacuously before a fix is not a pin until observed failing with the fix's load-bearing half removed; the lifetime pin's sensitivity was measured, not assumed.
- [Phase 15]: 15-49: the census suite's walk was widened to the downloads test target while every census stayed scoped to the client module, because a census counts over the files the scan returns
- [Phase 15]: 15-49: the retired single-authority claim is owned by a fragment-assembled prose assertion observed RED naming both offending paths before either doc was rewritten
- [Phase 15]: 15-49: the spy's parked progress update was DELETED rather than exposed, because both arming cases already pin the parked push after release through a stronger observation
- [Phase 15]: 15-50: The run's proof of page work carries the PAGES it still owes, not a membership; a trusted complete-reading record is credited its record minus that debt (G-15-30).
- [Phase 15]: 15-50: The decrement rides flushManifestPageProgress, not flushDownloadProgress — a background page landing reaches the manifest without passing the throttle.
- [Phase 15]: 15-50: A retiring run freezes its final credited basis into observedSchedulablePages before dropping its debt and its session trust, which makes the departure retirement ordering-insensitive.
- [Phase 15]: The identifier is recorded only where scheduling.register returned true; that single placement is the whole arm split, so a refused registration records nothing and a successful one is never re-registered.
- [Phase 15]: A refused identifier is never re-attempted — the conservative reading of the store's own recorded constraint, taken because departing from it needs device evidence this plan does not have.
- [Phase 15]: The awaiting-window loss of launch discrimination is dispositioned in writing rather than mitigated, because the SDK supplies nothing that could separate a leftover launch from a live one under one identifier.
- [Phase 15]: Both dissolved-subject cases are rebuilt by staging the stale delivery behind adoption, which reaches the surviving property without two identifiers.
- [Phase 15]: 15-52: The client-double census token is the seam's endpoint LABEL, not its type name — a type-name token misses the `Self(` spelling the offending double uses, so its blind spot would sit exactly where the violation lived.
- [Phase 15]: 15-52: The timing census has two halves that fail on different events — a property half (a double stops suspending) and a population half (a new double appears in a file no table knows) — and each was falsified separately before it was trusted.
- [Phase 15]: 15-52: The macro-synthesized unimplemented value and the module's public `live`/`noop` values are classified OUT of the timing obligation; a test census must not demand yields from generated or production code.
- [Phase ?]: [Phase 15]: 15-53: The generation-less retirement arm returns true (superseded, retires nothing); the recorded reason is the asymmetry — one stale proof bounded by the owning run's exit, against dropping a live successor's proof (the G-15-26 zero-progress card).
- [Phase ?]: [Phase 15]: 15-53: DownloadLogPrivacyInvariantTests.scannedFiles() supplies the self-exclusion's SHAPE and binding NAME only — it carries no doc comment, so 15-REVIEW.md:443-445's block quotation of its 'rationale' has no source referent and the G-15-33 gap record inherited a false premise.
- [Phase ?]: [Phase 15]: 15-53: The plainly-worded statement of the retired single-authority claim stays inside the excluded file, so a repository grep no longer sums to zero; the prose assertion, not a grep, is the live guard.
- [Phase 15]: D-G2C-01: the pushed continued-session gallery count is the denominator's coverage — live schedulable galleries plus retiredSessionPages entries greater than zero — via one shared coverageGalleryCount both subtitle writers call. — The OS does not repaint a push issued immediately before setTaskCompleted, so a count that is only correct on the terminal frame is never reliably correct; making every frame truthful removes the render race instead of racing it.
- [Phase 15]: A zero-page retirement is not counted in the coverage, and the boundary is pinned from both sides on production-path drains. — A gallery that departed having finished nothing left no pages in Y, so nothing of it is represented by the denominator the count describes.
- [Phase 15]: A task's file ownership must close over every file of the suites its gate runs, because -only-testing filters by suite and this tree splits suites across files via extension. — LedgerRefusalTests and RunProofTests extend DownloadContinuedSessionLedgerTests, so a gate naming that suite runs files a sibling task owned.
- [Phase 15]: Third test-literal category: a synchronization predicate must key on a facet the basis still moves. — A waitUntil keyed on the gallery count crossing at a departure stopped observing once the coverage basis held that count constant, hanging the case to its deadline; the denominator still crosses at the same production push.
- [Phase 15]: D-G5B-01 — a missingFiles validation verdict reconciles the persisted manifest through the one D-G5-01 blanking loop (fresh scan as evidence, never the first-failure verdict), inside the sibling withdrawingCountedBasisMovement bracket; validationErrors is cleared on the durable arm because it outranks the manifest in displayStatus, and kept on every refusal.
- [Phase ?]: D-G5C-01 (15-57): DownloadInspection.retryablePageIndices unions failed+pending pages exactly at .error with a fileOperationFailed code, and canRetryPages gates on that same basis — so the inspector's retry starts the refusal family, whose pages derive .pending, not .failed
- [Phase ?]: D-G5D-01 (15-57): DetailReducer.downloadNeedsRepair reads record honesty (completedPageCount < pageCount) instead of == 0, so a mid-run file failure with landed pages offers the non-destructive repair; a complete-claiming .error record deliberately keeps the destructive redownload
- [Phase 15]: D-SSOT-01 — positive content-level evidence (a readable file whose fresh hash mismatches its record) licenses durable blanking, so corrupt-in-place reconciles exactly as a missing file does
- [Phase 15]: D-SSOT-02 — the all-or-nothing wholesale guard is evaluated over the COMBINED prospective blank set (positively absent union positively mismatched) BEFORE any removal or blanking
- [Phase 15]: D-SSOT-04 — the refuted file is removed under containment, converting corrupt-in-place into the positively-absent shape, so the one blanking loop stays the only blanking path
- [Phase 15]: D-SSOT-05/06 — validationErrors is an operation-level signal only, and AGENTS.md's SSOT invariant was revised to match the code
- [Phase 15]: D-SSOT-07: inspector page states derive from the manifest (recorded hash, recorded page failure); the directory listing is demoted to a rendering-resource resolver and buildInspectionPages makes no file-system call
- [Phase 15]: D-SSOT-08: at the .error/fileOperationFailed shape the retry basis is the FULL page-index set, because the signal is record-wide and manifest-derived pending is empty for the wholesale-refusal family
- [Phase 15]: D-SSOT-09: the run-owned measured session series is scoped OUT of the record-completeness property families, and the exclusion is structural — every fixture uses a noop background client, so no push is observable from the suite at all
- [Phase 15]: CR-02: incomplete-record observation is evidence about one queue-intent generation, not a durable property of a gallery identifier.
- [Phase 15]: Generation mismatch is the single invalidation mechanism for stale session observations; no retry path gains a clear.
- [Phase 15]: Both observation merges keep the greater generation, so a pre-hop snapshot cannot resurrect an observation an in-hop queue intent invalidated.
- [Phase 15]: CR-01: validation evidence gathering is non-mutating; the combined wholesale guard authorizes absences, rejections and mismatches together before any file is removed
- [Phase 15]: PageFileScan.rejectedPageRelativePaths records a refuted page file only while it SURVIVES, so every discarding caller stays byte-for-byte unchanged
- [Phase 15]: The one blanking loop gained a fourth per-file refusal line rather than the caller mislabelling a surviving refuted file as unprobed
- [Phase ?]: CR-03: the rename source is admitted by exact normalization equality, never normalized — normalizing a source selects a different folder than the caller named
- [Phase ?]: 15-63: lexical standardization and symlink resolution are separate containment questions; both are required and both re-run inside the lock that calls moveItem
- [Phase 15]: CR-04: retryPages filters a caller's page indices against the current record's page domain immediately after the fetch and refuses an empty result before mode resolution, update delegation and every queue or session mutation — The defect was the ORDER: the update delegation and the downstream filtering were each correct where they stood, so admission had to move ahead of both rather than either being replaced.
- [Phase 15]: 15-64: a page selection's PRESENCE is the restriction, so normalizeFetchedPayload keeps an explicitly supplied selection non-nil even when filtering empties it; only nil means unrestricted whole-gallery work — Absence and empty presence are different requests; sharing one value is what let an inadmissible two-index request schedule every page.
- [Phase 15]: 15-64: an update record still refreshes as a WHOLE with no page selection, but only once the request contains at least one admissible page — the exception is documented on the public API and regression-tested from both sides — An update re-fetches against a new page count, so a subset drawn against the old one names pages that may no longer be the same pages; the valid-page requirement is what keeps the exception from being a widening.
- [Phase ?]: 15-65: the D-G7-01 bracket wraps the queue-intent MOVEMENT (advanceQueueIntentGeneration's own increment), not its four call sites, so every present and future queue-mobilizing entrance is enclosed by construction (CR-01)
- [Phase ?]: 15-65: sibling composition is proved by construction — the bracket's closure is non-async and all four callers are async, so nesting is a compile error rather than an inspection result
- [Phase ?]: 15-65: a below-floor masking defect is only observable one landing at a time; the regression's baseline is the re-queue frame, because a withdrawn deliberate movement is MEANT to lower the card
- [Phase 15]: 15-66 CR-03: discardingRejected flipped to non-mutating across all 10 family declarations; entitlement is a pairing (delete only where the same act blanks the record), leaving 4 entitled sites in one actor (the repair seed); scanCompletedFolder deleted and sanitizeLocalFilesIfNeeded renamed clearStaleDownloadErrorIfNeeded
- [Phase ?]: DEC-B (15-67): the wholesale guard's combined basis makes an authorized removal guard-NEUTRAL, so the caller's predicate and the loop's are provably one
- [Phase ?]: DEC-C (15-67): materializeRepairSeed's SOURCE scan stays discarding — its refusals cross a folder boundary and arrive as positive absences, so neither WR-01 nor WR-02 is reachable through it
- [Phase ?]: DEC-E (15-67): split DownloadStore.swift and +ExecutionSupport.swift before growing their contract docs; a 1000-line ceiling reached by prose means the type or the function wants its own file
- [Phase ?]: DEC-A: the user-folder boundary is a closure-taking function (mutatingConfinedUserFolder), so a mutation has nowhere to go but through the confined resolver
- [Phase ?]: DEC-B: userFolderURL(name:) is deleted rather than demoted — unreachability enforced by the symbol's absence, not by an access level the same module could reach
- [Phase ?]: DEC-C: enqueue's parent-folder create is removed as redundant (writeInitialManifest already creates it with intermediates) rather than confined, which would have made a scan-derived non-normalized folder un-enqueueable
- [Phase ?]: DEC-D: deleteFolder keeps its existence pre-check ahead of the store so an absent folder still answers .notFound without moving scheduling state
- [Phase ?]: DEC-E: the delete escape suite installs a foreign active task, because the staged queue intent otherwise starts a run whose failure path dequeues the gid the case asserts is untouched
- [Phase ?]: DEC-A (15-69): only the inadmissible-selection retry exit gets a distinct error; the two absence exits keep .notFound
- [Phase ?]: DEC-B (15-69): a fetch-time page-selection collapse throws a named error at normalizeFetchedPayload instead of returning an empty-but-present payload
- [Phase 15]: 15-70 DEC-A: the user-folder admission predicate is derived from scanDownloads' promotion rule, not from the app's own name generator; normalization stays confined to sites that MINT a name
- [Phase 15]: 15-70 DEC-D: moveDownload admits its picked destination raw — rewriting a listed name created a near-duplicate folder beside the one the user picked

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Deferred follow-up (from Phase 8 UAT): remove dead legacy haptic code (`isLegacyTapticEngine`, `generateLegacyFeedback`) — targets unsupported devices.
- Deferred follow-up (from Phase 11 UAT, G-11-7): harden the `lastAutoFetchCount` one-shot latch in `AutoLoadNextPage` (GalleryList.swift) to re-arm on the server page cursor (`pageNumber`) rather than on `galleries.count`, so a deduped, empty or failed page cannot permanently disarm thumbnail-mode pagination — today only the manual footer retry recovers. Pre-existing (Phase 2 / D-36), not a Phase 11 regression; the detail path no longer depends on it. Needs a device check for chain-fetch regression, since the known failure mode of this tuning is an endless fetch loop pinned at the bottom.
- Standing verification item (from Phase 11 UAT, G-11-7): every future UAT touching gallery list pagination must exercise BOTH `Setting.listDisplayMode` values, `detail` and `thumbnail`. The two modes render through structurally different layouts with different fetch-more triggers, and `detail` being the default masked the thumbnail path historically and masked this regression in reverse. Testing one mode proves nothing about the other.
- Carry-forward (Phase 12 UAT, 12-06): the forum gates its login form behind Cloudflare Turnstile, which contributes a `cf-turnstile-response` field a credential POST cannot produce. While the gate is active, native username/password login cannot complete whatever the password. It is detected, named (`AppError.loginCaptchaRequired`), localized in all six locales, and routed to the web-login fallback. C1 was owner-verified PASS on the live host BEFORE the gate appeared, so Phase 12's goal was met — but C1 is not currently reproducible while the gate is active. Making native login survive an active Turnstile gate needs the form rendered in a web view to obtain a token; that is new scope for a future phase.
- Housekeeping (12-06): `.planning/research/.cache/` is tracked in git — a documentation-tool cache that arguably should be gitignored. Three of its JSON files were swept into commit 5345a9d9 alongside an unrelated one-line change. Left in place (published history, inert content); needs a .gitignore decision before it accumulates.
- Deferred (12-06): the two `diag(12-06)` commits remain in the tree. The DEBUG-only redacted login-exchange dump is a useful diagnostic for this class of problem; decide whether it stays permanently once the login path is stable.
- DownloadContinuedSessionTests.swift sits at 999 of 1000 lines (file_length is error severity); the next added line fails the build. Sanctioned remedy recorded in 15-22-SUMMARY.md: relocate testEmptySchedulableSetStillPushesAPositiveTotal into the ledger suite.

### Roadmap Evolution

- Phase 10 edited: renamed to UI Polish; added POLISH-02 (ZStack->overlay/background)
- Phase 10 edited: edited fields: goal, success_criteria
- Phase 10 edited: added success criterion: remove \.inSheet environment value
- Phase 10 edited: added success criterion: sweep deprecated SwiftUI APIs (e.g. foregroundColor)
- Phase 10 edited: added success criterion: remove custom cornerRadius(_:corners:) modifier, use standard clipShape API
- Phase 10 edited: added success criterion: replace empty string literals passed to views with meaningful strings/hidden labels
- Phase 10 edited: added success criterion: convert text-only/image-only/text+image button labels to Label where fitting
- Phase 10 edited: scoped criterion 10: text+image->Label applies to all buttons; text-only/image-only->Label applies to toolbar buttons only
- Phase 11 edited: added success criterion: remove .serialized from all tests via dependency injection, run suite in parallel
- Phase 11 edited: renamed 'Lint Capstone' -> 'Infra Refactor & Lint Capstone'; goal updated to cover infra refactors (test-isolation) alongside lint ratchet
- Phase 11 edited: criterion 4: also remove @MainActor from tests unless a real main-actor need exists; run in parallel on any thread
- Phase 12 added: added Deep Link Hardening: code-review + durability fixes for deep-link routing, backed by UI automation tests
- Phase 10 edited: added success criterion: rename SystemNotificationExt module -> SystemNotification (full impl, not an extension)
- Phase 13 added: Analytics Instrumentation (TelemetryDeck) - privacy-first opt-in analytics *(historical wording — D-01 then chose on-by-default with no opt-out; the owner reversed D-01 during 14-18, so the phase shipped as Phase 14 on-by-default with a runtime opt-out in General Settings)*
- Phase 12 added (integer, Cloudflare Login Restoration): restore username/password login broken by the Cloudflare challenge wall (403 + cf-mitigated on forums.e-hentai.org); in-app browser clearance capture, in-memory cf_clearance. Cascaded existing phases: Deep Link Hardening 12→13, Analytics/TelemetryDeck 13→14, Dynamic Type Accessibility 14→15 (owner chose integer over decimal 12.1)
- Phase 15 inserted after Phase 14: Continued Background Downloads (BGContinuedProcessingTask); Dynamic Type Accessibility renumbered 15 to 16

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Test infrastructure | Group the deep-link accessibility identifiers into one shared constants file (e.g. `AccessibilityIdentifiers.readingView`, plus a `commentCell(id:)` for the interpolated one). Today the 7 identifiers are literals in `AppPackage/Sources` and are re-typed as 18 literal call sites across the 5 `EhPandaUITests` files, with no compile-time link between the two sides — a rename fails at runtime, not at build time. | Open | Phase 13 UAT (2026-07-23) |

## Session Continuity

Last session: 2026-08-10T12:16:46.563Z
Stopped at: Completed 15-70-PLAN.md
Resume file: None
