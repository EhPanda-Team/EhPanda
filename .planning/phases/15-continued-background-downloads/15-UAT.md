---
status: testing
phase: 15-continued-background-downloads
source: [15-VERIFICATION.md, 15-54-SUMMARY.md, 15-55-SUMMARY.md, 15-56-SUMMARY.md, 15-57-SUMMARY.md, 15-58-SUMMARY.md, 15-59-SUMMARY.md, 15-60-SUMMARY.md, 15-61-SUMMARY.md, 15-62-SUMMARY.md, 15-63-SUMMARY.md, 15-64-SUMMARY.md, 15-65-SUMMARY.md, 15-66-SUMMARY.md, 15-67-SUMMARY.md, 15-68-SUMMARY.md, 15-69-SUMMARY.md, 15-70-SUMMARY.md, 15-71-SUMMARY.md, 15-72-SUMMARY.md, 15-73-SUMMARY.md, 15-74-SUMMARY.md, 15-75-SUMMARY.md, 15-76-SUMMARY.md, 15-77-PLAN.md, 15-REVIEW-FIX.md]
started: 2026-07-29T03:54:41Z
updated: 2026-08-17T16:45:00Z
round: 5
---

## Current Test

number: —
name: all runnable tests resolved
expected: |
  Every runnable observation in this UAT is now complete. Test 8's iPad half was observed
  2026-08-17 on the test iPad, leaving only the owner's anchoring choice. The two open issues
  (G-15-2D, G-15-11) await diagnosis.
awaiting: owner anchoring choice for test 8; diagnosis of G-15-2D and G-15-11

## Tests

### 1. Backgrounded queue outlasts the old grace window

test: On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages,
start in the foreground, background the app for more than 60 seconds, then foreground and compare
persisted page counts against the queue.
expected: Pages keep landing while backgrounded, well past the old grace window; no page lost or duplicated.
why_human: The simulator neither grants continued-processing tasks nor suspends the process as a device does.
covers: SC1
result: pass

### 2. System progress card renders real progress and its cancel matches the in-app pause baseline

test: Observe the system progress card across a multi-gallery queue — including a `.repair`
re-download — then cancel from the card, foreground, and compare queue state against pausing each
gallery by hand.
expected: One neutral card whose counts advance with real work, never fall back within a reporting
regime, and never read a numerator above the work actually done; the subtitle names every gallery
the denominator covers and holds that count steady across a gallery's completion (with two queued
it reads "· 2 galleries" on every frame, including the last); a repair of a gallery whose files
were deleted outside the app climbs from its announce rather than freezing at the record's stale
claim; card-cancel state matches the in-app per-gallery pause baseline.
expected_note: |
  The drain-time expectation CHANGED at round 4 with the 15-55 basis redesign: the final subtitle
  reads "N / N pages · 2 galleries", NOT "0 galleries". Rounds 1-3 were judged against the older
  basis; do not carry their wording forward.
why_human: The card and its cancel affordance are system-owned and do not render or fire in the simulator.
covers: SC2
result: issue
retest_round_5_reported: |
  On the test iPhone (physical iPhone 11, iOS 26.6), two paused galleries were resumed from
  27/51 and 6/53 and EhPanda was backgrounded. The system Background Activities surface rendered
  "Downloading galleries — Task failed" instead of any progress fraction or "· 2 galleries".
  Expanding Background Activities showed two EhPanda cards with the same failure. Foregrounding
  the app showed that both galleries had nevertheless drained to 51/51 and 53/53.
retest_round_5_severity: major
retest_round_5_outcome: |
  Failed before the fraction, stable-gallery-count, repair, pause-liveness, and card-cancel clauses
  could be judged. The system-owned surface reports failure for completed work and never exposes
  the required progress representation.
retest_round: 5
retest_reason: |
  15-72 changed how the announced basis is computed, which is the quantity this card renders.
  `authorizedReconciliationScan` now answers with the pages it destroyed, `WorkingSeed` carries
  them, and `inheritedPages` subtracts them in BOTH branches — so a failed post-removal rescan can
  no longer promote a deleted page to presumed-done and inflate the announce. `scanSucceeded`
  deliberately stays sourced from the post-removal rescan (15-67 DEC-F stands). 15-VERIFICATION.md
  asked for a physical-device iOS 26 re-run of this test once that gap closed (15-72 coverage D5).
  The round-4 observation does not carry forward: it was taken against the basis this plan changed.
retest_steps_round_5: |
  1. Queue at least two galleries, start in the foreground, then background the app.
  2. EVERY frame reads "· 2 galleries" — during the first gallery, across its completion, and while
     only the second remains. The count must never drop to "1 gallery".
  3. At drain the final subtitle reads "N / N pages · 2 galleries".
  4. The fraction must never fall back within a reporting regime, and must never read a numerator
     ABOVE the work actually done — the over-reporting direction is what 15-72 closed.
  5. `.repair` a gallery whose files were deleted outside the app: progress CLIMBS from the
     announce, never freezes at the record's stale claim.
  6. Pause one gallery mid-queue; the card still reaches completion for the rest.
  7. Cancel from the card, foreground, and compare queue state against the in-app per-gallery
     pause baseline.
prior_round_4_result: pass
prior_round_4_reason: |
  Passed on device 2026-08-09 against the 15-55 subtitle basis. Superseded by the 15-72 announced-
  basis change, not by any defect found in round 4.
retest_round_4_reason: |
  G-15-2C closed by plan 15-55 (D-G2C-01): the subtitle gallery count's basis changed from the
  live schedulable set to the denominator's coverage — live schedulable galleries plus every
  departed gallery whose retirement contributed pages to Y, zero-page retirements excluded. The
  15-22 terminal push survives as defence, but nothing depends on the OS rendering it anymore:
  every frame is truthful. Fidelity-audited 2026-08-09 (four auditors, zero deviations), full
  FeatureTests green (TEST SUCCEEDED, orchestrator-run). The card is system-rendered and has
  surprised this phase three times, so SC2 stays failed until a device says otherwise.
retest_steps_round_4: |
  1. Queue at least two galleries, start in the foreground, then background the app.
  2. EVERY frame of the card should read "· 2 galleries" — during the first gallery, across the
     first gallery's completion, and while only the second remains. The count must never drop
     to "1 gallery".
  3. At drain, the final subtitle reads "N / N pages · 2 galleries" (no longer "0 galleries" —
     the expected observation changed with the basis redesign).
  4. Exercise the `.repair` re-download of a gallery whose files were deleted outside the app:
     progress must CLIMB from the announce, never freeze at the record's stale claim.
  5. Pause one gallery mid-queue; the card still reaches completion for the rest.
  6. Cancel from the card, foreground, and compare queue state against the in-app per-gallery
     pause baseline.
retest_round_3_result: issue
retest_round_3_reported: "After both galleries completed, the card still displayed 1 gallery. The count appears to describe only the currently active gallery set, but it should describe every gallery represented by the denominator in X / Y pages."
retest_round_3_severity: major
user_hypothesis: |
  The gallery count is derived from the current active queue membership rather than the same
  cumulative session basis as totalUnitCount. If totalUnitCount Y represents pages from Z
  galleries, the subtitle should display Z galleries, including galleries that already completed.
retest_round: 3
retest_reason: |
  Both gaps this test produced are now closed in code. G-15-2's liveness clause was confirmed on
  device at the round-2 retest; G-15-2B (the stale "1 gallery" subtitle at drain) was closed by
  plan 15-22's terminal push and is reconciled resolved above. Since that retest the phase ran
  rounds 9-18 of gap closure over the same surface, ending in plan 15-54's numerator REDESIGN
  (commits a6105b0b, d155236a, 5df56a8e, d4d568c6): the fraction the card shows is no longer
  inferred from the on-disk index record and corrected, it is measured by a run-owned
  `RunProgressBasis`. That changes what this run should observe (see expected), so the previous
  device observation does not carry forward. Deterministic in tests — 888/0 green, 374 in the
  downloads target — but the card is system-rendered and has surprised this phase twice, and
  15-VERIFICATION.md holds SC2 at failed until a device says otherwise.
retest_steps: |
  1. Queue at least two galleries, start in the foreground, then background the app.
  2. Watch the card across the FIRST gallery's completion: counts keep advancing, subtitle keeps
     naming the galleries that actually remain.
  3. Watch the card as the LAST gallery completes: the final subtitle must describe zero remaining
     galleries (e.g. "N / N pages · 0 galleries"), not a leftover "1 gallery".
  4. Exercise a re-download of a gallery whose files were deleted outside the app (Files.app) while
     its record still claims pages — the `.repair` route. The progress series must CLIMB from the
     announce; it must not sit frozen at the record's old claim.
  5. Pause one gallery mid-queue and confirm the card can still reach completion.
  6. Cancel from the card, foreground, and compare queue state against pausing each gallery by hand.
prior_round_2_result: issue
prior_round_2_reported: "it now doesn't complete the background task when one of the tasks finished, but still the notification description updated to \"1 gallery\" when both completed"
prior_round_2_severity: major
prior_round_2_outcome: |
  Liveness half of G-15-2 confirmed fixed on device: the session no longer finishes when the first
  gallery of the queue completes. Subtitle half still failing — narrowed to G-15-2B.
prior_round_1_result: issue
prior_round_1_reported: "pass but please note the following issue: when there are multiple galleries and one of them finished earlier than others, the background task report completion and the description become \"1 gallery\" only. leaving other tasks in active status but probably not continuing in background."
prior_round_1_severity: major
note: "Card rendering (one neutral card) and card-cancel parity with the in-app pause baseline matched on the round-1 run; every defect since has been in the numbers and the subtitle, not the affordance."

### 3. Refusal, indefinite queuing, expiration and process death lose no work and show no error

test: Exercise a refused or indefinitely queued submission and a system expiration; force-quit
mid-session and relaunch.
expected: No crash, no visible error, no duplicated or lost pages, and persisted work resuming on foreground.
why_human: Real scheduler decisions and process death are not reproducible in unit tests.
covers: SC3
result: pass
note: "Duplicate pages are structurally precluded by index-keyed page filenames; lost pages were checked via the inspector's per-page status and its hash-verifying Validate action."

### 4. Collected diagnostics carry no gallery title and no unmasked identifier

test: Take a sysdiagnose or collected log archive after a real download session and search it for
gallery titles and unmasked gallery identifiers.
expected: No gallery title and no unmasked identifier from the DownloadClient module appears in
collected diagnostics.
why_human: The invariant suite proves the source spellings; only a real collected archive proves
what the system actually persists.
covers: Privacy gate (gap C closure)
result: pass

### 5. Repair progress climbs from the current run's measured work

test: Delete files outside the app while a completed gallery's persisted record still claims
those pages, trigger its `.repair` re-download, background the app, and observe the system card.
expected: The progress series climbs from the current run's measured starting point instead of
freezing at the persisted record's stale completed-page claim.
why_human: The continued-processing card is system-owned and does not render in the simulator.
covers: SC2 repair progress
result: pass
retest_round: 2
retest_reason: |
  G-15-5 closed by plans 15-56/15-57 and hardened by the SSOT collapse (15-58/59/60) plus the
  review-fix pass (10/10). Validate now durably reconciles the manifest (missing files AND
  readable-but-corrupt files blank under guards; the corrupt file is removed so repair re-fetches
  it), validationErrors is operation-level only and cleared at every enqueue, the inspector
  derives page states from the manifest, and Resume starts the repair through the existing
  machinery. Fidelity-audited 2026-08-09, suite green. Device must confirm the end-to-end flow.
retest_steps: |
  1. Complete a gallery download; delete some of its image files outside the app (Files.app).
  2. BEFORE running Validate: the inspector now mirrors the manifest's claim (still shows the
     pages as downloaded) — this is the SSOT-consistent expected behavior, not a bug; badge and
     inspector must AGREE.
  3. Run Validate Image Data: the record durably drops the missing pages (e.g. 26/36), the
     yellow state appears, and Resume is ENABLED.
  4. Force-quit and relaunch BEFORE resuming: the 26/36 count and the incomplete state must
     survive relaunch (no silent snap back to 36/36).
  5. Tap Resume: a `.repair` download starts immediately and re-fetches exactly the missing
     pages; on completion both the badge and the inspector read 36/36.
  6. Optional (corrupt-in-place): corrupt a page file's bytes outside the app, run Validate —
     the page is durably dropped and the corrupt file removed; Resume repairs it.
prior_round_1_result: issue
prior_round_1_reported: "After Validate Image Data marked 10 missing pages as pending, Pause and Retry Failed Pages were both disabled, and no Resume or other action was available to start the repair download. After relaunching the app, the yellow missing-page state disappeared and the page count displayed 36 / 36 even though 10 pages remained pending, leaving the persisted and displayed state inconsistent."
prior_round_1_severity: major

### 6. Pause and system-card cancellation converge on the in-app baseline

test: During a multi-gallery queue, pause one gallery in the app and confirm the remaining work
can finish. Start another queue, cancel from the system card, foreground the app, and compare its
queue state with pausing every gallery individually in the app.
expected: Pausing one gallery does not strand the remaining session; cancelling from the system
card leaves the same queue state as the in-app per-gallery pause baseline.
why_human: The system-owned cancel affordance does not fire in the simulator.
covers: SC2 pause and cancel parity
result: pass

### 7. Swipe-delete choreography settles instead of flickering

test: On device, swipe a downloads row to reveal Delete and tap it. Watch the row while the
confirmation is up. Cancel. Repeat and confirm the deletion. Also open the row's context menu and
look at its Delete.
expected: Tapping the swipe Delete settles the row closed — no vanish, no reappear — and the
confirmation comes up over a row that is still there. Cancelling leaves the row at rest.
Confirming animates the row out ONCE as the standard List delete collapse, with no snap and no
intermediate state. The confirmation's own Delete button and the context-menu Delete both still
read as destructive (red).
why_human: This is an animation sequence. Plan 15-77 built Candidate 0 (drop `role: .destructive`
from the swipe button, tint red, animate the removal) and gated it on an owner device evaluation —
and that verdict was never recorded: no 15-77-SUMMARY.md exists, though its commits (8277ded7,
15afbde4) are on the branch.
covers: UAT-FU-2 (Deferred Follow-Ups, test 6)
note: |
  15-RESEARCH established (docs-index sweep, VERIFIED) that the full three-part hold-open
  choreography is IMPOSSIBLE with native `.swipeActions` through the iOS 27 beta, so Candidate 0 is
  deliberately an approximation of the original ask, and that gap is exactly the kill criterion.
  A kill verdict routes Candidate 1 (in-house custom swipe container) to a follow-up planning
  round; it must not be half-built here.
result: pass
device_result: |
  Passed on the test iPhone (physical iPhone 11, iOS 26.6). Tapping the swipe action's Delete
  settled the row closed while the row remained present under the confirmation. Cancel left the
  row at rest. Confirming produced one standard List collapse with no vanish/reappear flicker.
  The confirmation Delete and the context-menu Delete were both red.

### 8. The delete confirmation anchors where the owner wants it

test: On iPhone and on iPad, swipe-delete a downloads row and look at where the confirmation is
anchored — on iPad, note where the popover arrow points. Compare against the list-level Move
dialog, which is attached to the container.
expected: Owner-decidable, not pass/fail. Today the dialog is attached to the ROW
(DownloadsView.swift:227-229), so it anchors at the row. The project's own placement rule carries
an exception saying a per-row destructive action in a scrolling List should attach to the enclosing
List instead — which would anchor it at the list top on every delete.
why_human: WR-05 was deliberately left unfixed. Both branches are owner decisions: (a) amend the
`Confirmation dialog / alert placement` rule in CLAUDE.md to carve out per-row destructive actions
whose anchoring is user-visible under iOS 26, keeping today's placement; or (b) hoist the modifier
to the List and accept the list-top anchor, which also makes DownloadRowFeature's per-row state
vestigial.
covers: WR-05 (15-REVIEW-FIX.md, skipped issue)
note: |
  The exception predates the iOS 26 change where `.confirmationDialog` anchors to its attachment
  view on iPhone too (WWDC25 284/323), which the phase's own choreography research flags for
  re-evaluation. Whichever branch is chosen, the untested half is worth closing: no test asserts
  what happens when a row with a presented dialog leaves `rows` (today the dialog vanishes silently
  and the deletion never fires).
result: [pending]
awaiting: owner choice between (a) keep row anchoring and amend the CLAUDE.md rule, and (b) hoist to List
observation_status: BOTH HALVES OBSERVED - only the owner branch remains
device_observation_iphone: |
  On the test iPhone (physical iPhone 11, iOS 26.6), the confirmation was attached to the
  triggering row and its popover arrow pointed at that row.
device_observation_ipad: |
  Observed 2026-08-17 on the test iPad (iPad mini 6th generation, physical, connected over USB),
  driven with agent-device. The branch build was installed fresh, one gallery was downloaded to
  create a row (33/33 pages), and the row was swiped to reveal Delete.

  Tapping the swipe Delete raised a POPOVER anchored to the row:
    - the arrow points UP, directly at the bottom edge of the triggering row
    - the popover body hangs below that row, horizontally centred on it
    - the row remains fully present and intact above the popover, matching test 7's iPhone finding
      that the row settles rather than vanishing
    - contents: title "Delete Download?", body "This will remove the downloaded gallery from this
      device.", and a single red destructive "Delete"
  Confirming removed the row and the list returned to its empty state.

  So today's row attachment produces exactly the behaviour the placement rule's exception would
  give up: the arrow identifies WHICH row is about to be deleted. Under branch (b) the same popover
  would anchor at the list top and point at nothing meaningful.
code_contrast_confirmed: |
  Both attachment sites were read to confirm the contrast the test asks for, and they are already
  deliberately split, with a comment saying so:
    - `DownloadsView.swift:56-58` - the list-level MOVE-TO-FOLDER dialog, scoped to `store` and
      attached to the container. Its preceding comment already states "The delete confirmation is
      per-row and lives on the row (see `DownloadRow`); this one is the list-level move-to-folder
      dialog."
    - `DownloadsView.swift:227-229` - the per-row DELETE confirmation, scoped to `rowStore` and
      attached to the row.
owner_decision_input: |
  The iPad evidence favours branch (a) on anchoring correctness: a popover that points at the row
  being destroyed is the affordance's whole value on iPad, and the list-top anchor discards it.
  What the evidence does NOT settle is the reason the exception exists in the first place - a row
  that scrolls out of view while its dialog is up tears the dialog down with it. That hazard is
  real under either branch and is still untested (see `note`): no test asserts what happens when a
  row with a presented dialog leaves `rows`, where today the dialog vanishes silently and the
  deletion never fires. Choosing (a) should therefore carry that test as its condition, rather than
  treating the anchoring observation as closing the whole question.

### 9. The logs directory reads `Logs` and its Files-app link opens it

test: Launch a build over a pre-rename install — one whose container already holds a lowercase
`logs` folder with files in it — then open the logs directory from the app's Files-app link.
expected: The existing log files survive the rename, the folder displays as `Logs`, and the deep
link opens THAT folder — not a missing path and not the old spelling.
why_human: 15-76 D9 — `ApplicationClient.openFileApp` builds `shareddocuments://` from
`FileUtil.logsDirectoryURL.path`, so the path derives from the constant by argument, but no test
and no device run has observed the link actually opening.
covers: 15-76 D9
result: pass
device_result: |
  Passed on the test iPhone (physical iPhone 11, iOS 26.6). In Files, the existing `Logs`
  folder containing 12 items was renamed to lowercase `logs`. After terminating and cold-launching
  EhPanda, Files showed `Logs` with 14 items (the original contents plus new run logs). From App
  Activity Logs, "Open in Files" opened the `Logs` folder directly and displayed its log files.

### 10. A stranded migration staging directory is recovered on the next launch

test: With the app not running, put a `Logs-migrating-<uuid>` directory holding a log file into the
app's Documents container, and launch. Do it twice: once with no `Logs` folder present, once with a
populated `Logs` alongside it.
expected: Launch folds the residue into `Logs` (or moves it there when `Logs` is absent). The
container ends with no `Logs-migrating-*` directory left, and no log file is lost in either shape.
A second launch over the same state changes nothing further.
why_human: The recovery is unit-covered (six new cases in WR-01), but a residue is produced only by
a real interrupted rename, and no run has staged one in a device container.
covers: WR-01 (15-REVIEW-FIX.md)
result: pass
device_result: |
  Passed on the test iPhone (physical iPhone 11, iOS 26.6). With no destination present, a
  stranded staging directory containing the existing logs was recovered as `Logs`, with the
  original files retained and no staging directory left. With a populated `Logs` alongside a
  UUID-style staging directory holding one uniquely named 177-byte log copy, a true process
  termination and cold launch removed the staging directory and increased `Logs` from 17 to 19
  items (the staged copy plus the new launch log). A second true cold launch left no staging
  residue and retained all files; only the verification-created duplicate was then removed.

### 11. Both stored spellings merge into one

test: On a case-sensitive volume — a real device container — arrange for both `logs` and `Logs` to
exist with different files in each, then launch.
expected: The two are merged into `Logs` with no file lost; a name that collides in both keeps the
destination copy.
why_human: 15-76 D8. The classification half (`twoStoredSpellingsAreAMerge`) and the application
half (the two `mergeContents` cases) are each pinned on this host, but the case that joins them
(`bothStoredSpellingsRouteToAMerge`) is SKIPPED here — this Mac's APFS volume is case-insensitive
and cannot stage the fixture. Nothing has observed the composition.
covers: 15-76 D8
note: "Answer 'blocked' if the device's Files app will not let you create the second spelling — that is a legitimate staging limit, not a defect."
result: issue
reported: |
  The different-file half passes; the COLLIDING-NAME half does not merge. With populated `Logs`
  holding `ehpanda-20260804-115144-1.jsonl` at 54 KB and lowercase `logs` holding a different
  177-byte file renamed to that exact name, two consecutive true cold launches each wrote a new
  log into `Logs` (22 → 23 → 24 items) while lowercase `logs` survived untouched at 21:25 with its
  1 colliding item. The destination copy was correctly preserved (still 54 KB, never overwritten),
  but the two spellings were never merged into one and the source directory was never removed.
severity: major
device_result: |
  Observed on the test iPhone (physical iPhone 11, iOS 26.6) 2026-08-15, driven with
  agent-device against Files plus CoreDevice process control.

  PASSING half — different files: lowercase `logs` held two 177-byte files while populated `Logs`
  held 19 items; after a true cold launch only `Logs` remained, with 22 items (both source files
  plus the new launch log).

  FAILING half — colliding name. Pre-launch state verified in Files:
    - `Logs/ehpanda-20260804-115144-1.jsonl` = 54 KB (destination)
    - `logs/ehpanda-20260804-115144-1.jsonl` = 177 bytes (source)
  EhPanda PID 1788 terminated via CoreDevice, process absence confirmed (0 matches), then
  cold-launched as PID 1850. Result: `Logs` 22 → 23 items, destination file still 54 KB, and
  lowercase `logs` STILL PRESENT holding its 177-byte file. A second terminate/launch cycle
  reproduced it exactly: `Logs` 23 → 24 items, `logs` unchanged at 21:25 / 1 item.

  The listing is provably fresh, not a cached Files view: the same refresh that still showed
  `logs` also showed `Logs` growing by the newly written launch log on each cycle.
note_on_handoff: |
  The paused handoff recorded this cold launch as already performed. The filesystem contradicted
  that — `logs` had survived and `Logs` was untouched since 20:56, while the running process was
  PID 1788 rather than the recorded 1736. The launch had happened BEFORE the 21:25 rename was
  committed, so the fixture was never actually exercised until this run.

### 12. A refused Pause or Resume says why instead of doing nothing

test: In the download inspector, drive a Pause or Resume tap into a refusal and watch the bottom of
the screen.
expected: A toast appears whose message matches the refusal — not silence, and not a generic
failure string — and the inspector reloads behind it.
why_human: 15-73 D7. The rendered toast (Liquid Glass bottom toast, auto-hide) is a visual outcome
the TestStore cases cannot observe; they pin only the state that drives it.
covers: 15-73 D7
note: |
  Scope is the INSPECTOR only. The downloads LIST offers the same Pause/Resume from a swipe action
  and a context menu and is knowingly still silent on both arms — closing that needs a toast
  surface DownloadsReducer does not own. It is recorded in the reducer's type doc and in
  deferred-items.md rather than fixed, so it is out of scope here by decision, not by oversight.
result: pass
closure: composition
closure_rationale: |
  Closed by composition rather than by direct observation of a refused tap, because every link in
  the chain is now independently established and nothing in the unobserved segment is arm-specific.

  1. STATE — both refusal arms pin their exact caption in
     `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift`
     (`.error(caption: AppError.notFound.alertText)` and the `.unknown` equivalent), so the toast
     the reducer sets for a refusal is deterministically covered.
  2. PRESENTATION — BOTH styles of the same `AppAlertState` surface were observed rendering on
     the test iPhone (physical iPhone 11, iOS 26.6), captured via zero-delay snapshots:
       - `.success` — "Success" / "Image data is valid"
       - `.error(caption:)` — Warning icon / "Error" / "Page 1 is missing."
     Both arrive through `state.toast` and `.ifLet(\.$toast, action: \.toast)`, the identical path
     a refusal uses.
  3. RESIDUAL — what remains unobserved is SwiftUI presenting a value type it already presents for
     another action, differing only in a caption string constant that step 1 pins.

  The `.error` observation is what makes this airtight: an earlier draft of this closure rested on
  the `.success` style alone, which left the error styling itself unwitnessed.
device_evidence_bonus: |
  "Page 1 is missing." is `download_store.page_missing` rendering correctly with its `%lld`
  argument on device — an incidental but real data point for test 14's reframing, since it shows
  one of the eight keys resolving through the shared bundle at runtime.
why_not_observed_directly: |
  The refusal could not be induced from the device UI. Both arms are race-only: `canTogglePause`
  already excludes every status that triggers a refusal, so the control is tappable only while the
  rendered snapshot disagrees with the client, and the inspector's reload closes that window first.
device_attempts: |
  Attempted on the test iPhone (physical iPhone 11, iOS 26.6) 2026-08-15 with agent-device.
  `togglePause` has exactly two refusal exits (DownloadClient+PublicAPI.swift:189-214): `.notFound`
  when `fetchDownload` misses, and `.unknown` when `displayStatus` is `.completed`/`.error`/
  `.updateAvailable`. `canTogglePause` already excludes all three of those statuses, so the control
  is only tappable while the RENDERED snapshot disagrees with the client — i.e. a genuine race.

  Arm 1 (`.notFound`) — drove a gallery to `.inactive` via Validate (17/17 → Paused 14/17, Resume
  enabled), then deleted its whole gallery folder in Files and returned. The inspector reloaded on
  foreground and withdrew the Resume control entirely, so there was nothing left to tap.

  Arm 2 (`.unknown`) — drove FAR_SIDE to Paused 34/42 (8 pages deleted externally), tapped Resume,
  backgrounded immediately so the UI froze on `.active`, and let the repair drain in the
  background. It completed to 42/42 while backgrounded. On foreground the inspector had already
  reloaded to `.completed` and disabled the control before a tap landed, even tapping with no
  intervening delay.
partial_evidence: |
  The toast SURFACE is confirmed to render on device and is accessibility-visible: running
  Validate Image Data and snapshotting with zero delay captured the bottom toast reading
  "Success" / "Image data is valid" (DownloadInspectorReducer's `validateImageDataDone` →
  `toastConfig`, the same `AppAlertState` surface `actionFailureToast` feeds).

  What remains unobserved is only the refusal-specific mapping — that a refused Pause/Resume
  renders `.notFound` → "There seems to be nothing here." or `.unknown` → "An unknown error
  occurred. / Please try again later." The rendering machinery beneath it is now device-proven.
note_on_reachability: |
  Worth recording as a finding in its own right: WR-04/WR-05 are defensive handlers for a window
  the UI makes very hard to open. That is not evidence they are wrong — a race handler that is
  hard to trigger by hand is still correct — but it does mean this checkpoint cannot be closed by
  manual device testing. Closing it would need either a debug affordance that forces the refusal
  or acceptance that the TestStore cases (which already pin the state that drives the toast) plus
  the now-proven toast surface are together sufficient.

  RESOLVED: the second option was taken (see `closure_rationale`). The first option turned out to be
  cheaper than this note assumed - `UITestAutomation.swift` already installs `EHPANDA_UITEST_*`
  dependency overrides under `#if DEBUG` and `DownloadClient` is a struct of closures, so forcing
  either arm is one override at an existing sanctioned seam. Routed to `deferred-items.md` rather
  than done here: adding production code during close-out re-opens review for a residual risk that
  is a SwiftUI presentation identity.

### 13. Ratify the hang-detector wait bound

test: Nothing to run. Read 15-74-SUMMARY DEC-E and say whether the refusal stands.
expected: Plan 15-74 asked for `timeout: .seconds(1)` on the two missing-notification detectors;
the executor declined it on recorded evidence and kept the inherited 10-second `waitForTaskValue`
default. This is IN-01, carried unaddressed through three review rounds. The bound trades
test-harness fragility against how quickly a real regression is caught.
why_human: 15-74 D5 — an owner judgment the executor deliberately refused to auto-pass rather than
ratify on its own authority.
covers: 15-74 D5
result: pass
owner_decision: |
  RATIFIED 2026-08-17: the refusal stands. The inherited ten-second `waitForTaskValue` default is
  kept at both detectors. One second is refuted by plan 15-21's recorded 13.2s wall time at this
  exact call site, and no middle value has a basis, because scheduler delay under a parallel suite
  is unbounded rather than merely large.
follow_up: |
  Ratifying the NUMBER does not vindicate the INSTRUMENT, and that distinction is recorded rather
  than glossed. The source comment's own crux - wall time cannot distinguish "never arrives" from
  "not yet scheduled" - remains true at ten seconds. Two structural facts make the clock avoidable
  altogether: `DownloadObserverHub.observe` builds the stream with `AsyncStream.makeStream(of:)`
  (unbounded buffer) and registers the continuation before returning
  (`DownloadClient+Manager.swift:760-786`), and `delete(gid:)` awaits `notifyObservers()` on every
  exit path (`DownloadClient+PublicAPI.swift:236, 249, 256, 267`). So when `delete` returns the
  notification is either already buffered or will never come, which admits a sentinel FENCE and an
  assertion about sequence instead of time. The preferred shape needs no production change.
  Routed to `deferred-items.md`; keeping ten seconds is a settlement, not a resolution.
agent_recommendation: |
  RECOMMEND: the refusal stands — keep the inherited 10-second `waitForTaskValue` default.
  The evidence is decisive in one direction: the repo records this exact case timing out at 13.2s
  wall under contention, so a 1-second bound would fail against work the harness has actually
  observed. That makes it a flake generator, and a detector that cries wolf gets muted or deleted,
  which costs more than slow detection. The only thing given up is that a genuine regression takes
  up to 10s to surface in a failing test — paid once per real regression, against a false failure
  paid on every contended run.
  NOT self-ratified: this checkpoint exists precisely because the executor declined to decide it on
  its own authority, and an agent ratifying it reproduces the problem the checkpoint prevents.

### 14. Decide whether error-message text gets pinned

test: Nothing to run. Decide whether the eight download error-message keys should have their
rendered text asserted by test.
expected: After 15-75's key-spelling consolidation, all ten keys resolve correctly against the
shipped bundle at this HEAD, but only the two continued-session keys have their rendered VALUE
asserted by a test. The other eight are "verified at this HEAD", not pinned — which was equally
true before 15-75; the move neither created nor closed the gap.
why_human: 15-75 D7 — whether error text is worth a test is a cost call the owner owns.
covers: 15-75 D7
result: pass
owner_decision: |
  CLOSED 2026-08-17 with the question reframed. Do NOT value-pin the eight rendered strings: a test
  asserting a catalog value against itself is near-tautological, cannot judge whether the wording is
  right, and re-breaks on every copy and translation edit.
reframing: |
  The property actually at risk is not copy coverage, it is BRIDGE INTEGRITY.
  `ResourceStringSymbols.swift` hand-types the key literal in all 43 accessors (34 `var` + 9 `func`
  - an earlier count of 34 in this file was wrong, it omitted the parameterised accessors). The
  compiler never checks those literals against the `.xcstrings` catalogs, so a renamed, mistyped or
  deleted key still compiles and renders the raw key name into user-facing UI. Behavioural tests
  cannot catch it: state and logic stay correct, only rendering degrades. The eight download keys
  are roughly a quarter of that exposure and are merely the part this phase happened to touch, so
  scoping any fix to them would have been arbitrary.
resolution_path: |
  The right fix is build-time, not a runtime test. `STRING_CATALOG_GENERATE_SYMBOLS = YES` is already
  set and Xcode already generates internal symbols for the Resources module whose names match the
  hand-written ones 1:1, with semantic labels already generated for `%#@name@` substitution keys.
  The hand-written layer survives only because those generated symbols are `internal` while
  `Resources` must export them - access level is the reason it exists, labels only secondary. Keep
  every public signature and forward each body to the generated symbol; the key literals vanish and
  a bad key becomes a compile error, which makes any runtime resolution test redundant.
  Routed to `deferred-items.md` as a Resources-module change: it predates this phase, spans all 43
  accessors across every module's strings, and folding it into close-out would spread review scope
  well outside downloads.
device_note: |
  Incidental supporting observation from test 12's toast capture on the test iPhone: the error
  toast rendered "Page 1 is missing.", i.e. `download_store.page_missing` resolving correctly
  through the shared bundle with its `%lld` argument at runtime on a real device.
consistency_note: |
  The two `continued_session` keys stay value-pinned, and that is NOT an inconsistency to resolve.
  They take arguments, so the full rendered string is what proves plural categories and argument
  positions are correct - a different property from resolution, legitimately needing a stronger
  assertion.
agent_recommendation: |
  RECOMMEND: do not pin the eight rendered values; if anything is added, pin RESOLUTION only.
  Value-pinned copy tests re-break on every wording edit and every translation pass, and what they
  actually catch — a key that stopped resolving and renders its raw identifier — is catchable
  without freezing the sentence. A resolution assertion (each key resolves to something other than
  its own key name) buys the regression coverage at a fraction of the maintenance.
  Weighing against: the two continued-session keys ARE value-pinned today, so leaving the other
  eight unpinned keeps an inconsistency in the suite. That inconsistency is the real argument for
  acting, and it resolves either way — pin all ten, or relax the two to resolution checks.
  NOT self-ratified: 15-75 D7 assigns this cost call to the owner.

### 15. A folder made outside the app is fully manageable inside it

test: In the Files app, create folders under the app's Downloads directory named `Art  Books` (two
spaces), ` Photos` (leading space) and `Misc etc.` (trailing dot). In the app: list them, rename
one, delete another, and move a gallery into the third.
expected: All three are listed verbatim. Delete and rename both succeed on the name as shown — no
"The folder name is invalid." Moving a gallery into `Art  Books` puts it in THAT folder, not a
newly created near-duplicate `Art Books`.
why_human: This regression shipped green twice — through a code review and a verification cycle —
because the escape catalog only ever staged refusals. 15-70 added the positive half, but its
fixtures stage folders with `FileManager.createDirectory` under the test's own name. Only the Files
app proves the real producing surface can make these names and that the app's listing round-trips
them.
covers: CR-01 / 15-VERIFICATION.md gap 1
note: "A folder whose name contains a control character, or a symlink to a directory, is still refused by design (15-70 DEC-C) — those are not this test."
result: pass
device_result: |
  Passed on the test iPhone (physical iPhone 11, iOS 26.6) 2026-08-15, driven with
  agent-device. All three fixtures were created through the real Files app, which accepted every
  name: `Art  Books` (two spaces), ` Photos` (leading space) and `Misc etc.` (trailing dot).

  1. LIST — EhPanda's folder menu showed all three alongside `Default`, with the interior double
     space and the trailing dot intact. The leading-space folder renders as "Photos" in the
     accessibility label, but Files sorted it ahead of `Art  Books` under an ascending name sort,
     which only holds if the leading space is really on disk; the same trimming appears in Files
     itself, so it is an AX display artifact, not app behavior.
  2. DELETE — a full swipe on `Misc etc.` (trailing dot) raised the standard confirmation
     ("This will delete the folder and all downloaded galleries inside it.") and Delete removed it.
     No "The folder name is invalid."
  3. RENAME — a partial swipe on the leading-space folder revealed Rename Folder; renaming it to
     `Photos Renamed` succeeded and the row re-sorted. The app therefore acted on the true on-disk
     name rather than the trimmed display name.
  4. MOVE — long-press on a gallery in `Default` → Move to Folder listed `Art  Books` and
     `Photos Renamed`; choosing `Art  Books` completed with no error. Verified in Files:
     `Art  Books` 0 → 1 item, `Default` 6 → 5 items, and the Downloads directory still held
     exactly 3 items — no near-duplicate `Art Books` was created.

## Summary

total: 15
passed: 12
issues: 2
pending: 1
skipped: 0
blocked: 0

pending_note: |
  Test 8 is the only pending item and has NOTHING left to run: both the iPhone and iPad halves are
  now observed on physical hardware. What remains is purely the owner's branch choice between
  keeping row anchoring (amending the CLAUDE.md placement rule) and hoisting the modifier to the
  List.
open_issues_note: |
  The two issues are G-15-2D (test 2, the system Background Activities surface reporting
  "Task failed" for work that completed) and G-15-11 (test 11, the colliding-name merge leaving the
  source spelling stranded). Neither is diagnosed yet.

round_5_scope: |
  Round 5 covers everything delivered after round 4 closed on 2026-08-09: plans 15-61 … 15-77 and
  the fourth code review's fixes (WR-01 … WR-04, with WR-05 skipped as an owner decision).
  Tests 1 and 3-6 keep their round-4 pass results; test 2 returns to pending because 15-72 changed
  the announced basis it renders.

## Automated Coverage (round 5)

Deliverables from summaries 15-61 … 15-76 whose `coverage:` blocks classify as auto-covered by
passing tests are recorded here rather than as checkpoints, matching this file's convention across
rounds 1-4 (human checkpoints only in `## Tests`). 85 coverage entries across 16 summaries; 79
auto-passed, 6 routed to human judgment and carried above as tests 7 and 11-14.

| Summary | Entries | Auto-passed | Human |
|---|---|---|---|
| 15-61 | 3 | 3 | — |
| 15-62 | 4 | 4 | — |
| 15-63 | 4 | 4 | — |
| 15-64 | 8 | 8 | — |
| 15-65 | 3 | 3 | — |
| 15-66 | 5 | 5 | — |
| 15-67 | 4 | 4 | — |
| 15-68 | 4 | 4 | — |
| 15-69 | 10 | 10 | — |
| 15-70 | 4 | 4 | — |
| 15-71 | 3 | 3 | — |
| 15-72 | 5 | 4 | D5 → test 2 (round 5) |
| 15-73 | 7 | 6 | D7 → test 12 |
| 15-74 | 5 | 4 | D5 → test 13 |
| 15-75 | 7 | 6 | D7 → test 14 |
| 15-76 | 9 | 7 | D8 → test 11, D9 → test 9 |

15-76's D8 and D9 additionally carry a `classify-coverage` error (`invalid_status`: their
`verification[0].status` reads `partial`, which is not one of pass/fail/unknown). Both are treated
as human checkpoints regardless — the fail-safe path — so nothing is dropped, but the two status
values are worth correcting in 15-76-SUMMARY.md.

Plan 15-77 has NO SUMMARY.md, so it has no coverage block at all. Its deliverable is carried as
test 7 via the plan's own `must_haves` and its commits on the branch.

## Gaps

- gap_id: G-15-11
  truth: "When both stored spellings exist, launch merges them into one `Logs` directory and removes the source spelling — including when a filename collides, where the destination copy is the one kept."
  status: failed
  reason: |
    User-observed on device: with a colliding filename present in both spellings, two consecutive
    true cold launches left lowercase `logs` in place holding its colliding file. The destination
    copy was correctly preserved at 54 KB, but the merge never completed and the source directory
    was never removed, so the stale spelling persists indefinitely across launches.
  severity: major
  test: 11
  observed_on: "the test iPhone, physical iPhone 11, iOS 26.6"
  evidence: |
    Pre-launch: `Logs/ehpanda-20260804-115144-1.jsonl` 54 KB; `logs/ehpanda-20260804-115144-1.jsonl`
    177 bytes. Launch 1 (PID 1788 terminated, absence confirmed, relaunched 1850): `Logs` 22 → 23
    items, destination still 54 KB, `logs` still present with 1 item. Launch 2: `Logs` 23 → 24
    items, `logs` unchanged. The freshness of the read is established by `Logs` growing on each
    cycle in the same listing that still showed `logs`.
  contrast: |
    The different-file merge on the same device PASSES and removes the source spelling, so the
    failure is specific to the collision path — not to merging in general.
  hypothesis: |
    Not yet diagnosed. The shape is consistent with the per-item move failing on the colliding
    name and that failure either aborting the merge or being skipped without resolution, leaving
    the source directory non-empty so its removal cannot succeed. Worth checking whether the
    destination-wins branch deletes the source item after choosing the destination copy.
  artifacts: []
  missing: []

- gap_id: G-15-2D
  truth: "A queue-wide continued-processing session exposes live progress and finishes as success when its galleries drain successfully."
  status: open
  reason: |
    Physical-device round-5 retest: the Background Activities surface showed "Downloading
    galleries — Task failed" for a two-gallery session that nevertheless completed both galleries
    to 51/51 and 53/53. No fraction or gallery count rendered, so none of Test 2's progress clauses
    could be observed.
  severity: major
  test: 2
  observed_on: "the test iPhone, physical iPhone 11, iOS 26.6"
  evidence: |
    The compact card showed one failed EhPanda background activity. Expanding Background Activities
    showed two EhPanda cards with the same "Task failed" subtitle. Foreground state then showed both
    galleries complete.

- gap_id: G-15-2
  truth: "One queue-wide continued-processing session stays alive until the whole queue drains; its subtitle keeps describing the remaining galleries, not just one."
  status: partially_resolved
  resolved_by: [15-20-PLAN.md, 15-21-PLAN.md]
  resolved_at: 2026-08-04
  retest_verdict: |
    Device retest 2026-08-04 confirms the liveness clause: the session no longer finishes when the
    first gallery of the queue completes. The subtitle clause is still failing and continues as the
    narrowed gap G-15-2B below.
  fix_plans: [15-20, 15-21]
  fix_commits: [425b5a8b, 925669bf, b76c310c, 00bfd9ad]
  fix_note: |
    All five `missing[]` items below are addressed in code and covered by tests. The fix is a
    cumulative session-scoped retirement ledger (`retiredSessionPages` +
    `reconcileRetiredSessionPages`), applied as a push-time membership sweep at the single point
    that already reads the schedulable set — so completion, pause, delete, cancel and a scheduling
    block all retire through one formula with no departure-reason branch in production code.
    The three defect-encoding test expectations were rewritten, not supplemented. Removing the
    ledger's contribution was observed to fail 8 cases, so the coverage is not vacuous.
    NOT marked `resolved`: the fix has never been re-observed on a physical device, and the card
    is system-rendered. Test 2 above is the confirming run.
  reason: "User reported: when there are multiple galleries and one of them finished earlier than others, the background task report completion and the description become \"1 gallery\" only. leaving other tasks in active status but probably not continuing in background."
  severity: major
  test: 2
  root_cause: "Session progress is summed over the *currently schedulable* gallery set, so a finished gallery leaves the numerator and denominator together, while the monotonic floor `lastPushedCompletedPageCount` holds the numerator at its pre-shrink queue-wide value. The second clamp then lifts the denominator back up to meet that stale floor, pinning the fraction at exactly 1.0 and collapsing the subtitle to the remaining gallery count."
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      issue: "schedulableProgress() (33-42) builds numerator, denominator and galleryCount from one shrinking basis; pushContinuedSessionProgress() (267-286) clamps completed against a monotonic floor and then raises pageCount to match it"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift"
      issue: "settleCompletedDownload (238-242) removes the finished gallery from queueStore — the shrink trigger; correct in itself and must stay"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
      issue: "tests at 342-372 and 413-435 assert the defective output ('6 / 6 pages · 1 gallery', '2 / 2 pages · 0 galleries') as expected — the bug is encoded in the suite, which is why it shipped green; must be rewritten, not supplemented"
  missing:
    - "Replace the shrinking accounting basis with a cumulative session-scoped ledger: when a gallery leaves the schedulable set by completing, fold its pageCount and final completedPageCount into a retired-work accumulator added to BOTH numerator and denominator of every later push"
    - "Let completedUnitCount rise naturally and monotonically across gallery boundaries so the max() floor becomes redundant defence rather than the mechanism"
    - "Keep the denominator growing only when galleries join (preserves D-06/D-10); keep subtitle galleryCount as the remaining schedulable count (already correct)"
    - "Decide during planning whether a gallery leaving by pause/delete also retires into the ledger — it must not inflate the denominator with work that will never be done"
    - "Rewrite DownloadContinuedSessionTests expectations at 342-372 and 413-435 to assert queue-wide progress across a gallery completion"
  debug_session: ".planning/debug/continued-session-ends-on-first-gallery-completion.md"
  liveness_note: "No per-gallery completion predicate exists — finish() is gated on hasPendingWork() == false, so the session's end condition is genuinely queue-wide. The hazard is indirect: every later flush pushes the same frozen completedUnitCount, destroying the liveness signal the scheduler uses to detect a stalled task, which invites a forced expiration that routes to pauseAllSchedulable and pauses the remaining galleries. Not cosmetic."

- gap_id: G-15-2B
  truth: "When the queue drains, the card's subtitle describes the galleries that actually remain schedulable — it must not report a leftover gallery once every queued gallery has completed."
  status: resolved
  resolved_by: 15-22-PLAN.md
  resolved_at: 2026-08-08
  resolution_note: |
    Plan 15-22 (`gap_ids: [G-15-2B]`) added the terminal push to the drain branch of
    `reconcileContinuedSession` and executed to a matching 15-22-SUMMARY.md. Reconciled here on
    resume per the gap-closure protocol. NOT independently re-observed on a device — test 2 below
    is the confirming run, and its expectation has since been widened by the round-18 redesign.
    The push itself was subsequently hardened across rounds 9-18 (15-23 made the drain re-check
    drain-ness rather than session identity; 15-54 replaced the numerator basis the push reports).
  reason: "User reported: it now doesn't complete the background task when one of the tasks finished, but still the notification description updated to \"1 gallery\" when both completed"
  severity: major
  test: 2
  observed: |
    Two galleries queued and run to completion on a physical device. The session correctly stays
    alive past the first gallery's completion (G-15-2's liveness clause is fixed), but the final
    subtitle still reads "1 gallery" after both galleries have completed, rather than describing
    zero remaining schedulable galleries.
  narrowed_from: G-15-2
  root_cause: |
    There is no terminal push. The subtitle can only be written by
    `backgroundProcessingClient.updateProgress`, whose single call site is inside
    `pushContinuedSessionProgress`, which has exactly two callers — the `hasPendingWork() == true`
    branch of `reconcileContinuedSession`, and the throttled manifest flush inside a live page
    loop. When the last gallery settles, `finishActiveTaskIfOwned` converges on
    `scheduleNextIfNeeded`, whose tail reconciles the session; `hasPendingWork()` is now false, so
    control takes the drain branch, which calls `markContinuedSessionEnded` and `finish` — and
    `finish` carries no subtitle (it only reaches `setTaskCompleted(success:)`). The last string
    the card ever receives is the one written by the `force: true` flush at the end of the final
    gallery's page loop, taken while `activeGalleryID` still names that gallery. A gallery being
    downloaded is always `.active` and therefore always schedulable, so that string always ends
    "1 gallery".
  diagnosis_verdict: |
    Stale value from a MISSING terminal push — not a wrong count. Every value ever pushed is
    correct for the instant it was taken, `galleryCount` comes straight from the snapshot's
    `schedulableDownloads().count` and is never derived from a pre-removal or cached read, and a
    `galleryCount == 0` push is structurally unreachable in production (it would need
    `activeTask != nil` with an empty schedulable set, but `displayStatus(for:)` forces `.active`
    whenever `activeGalleryID == gid` and `shouldSchedule` short-circuits `.active` to true).
    The retirement ledger is NOT implicated: `reconcileRetiredSessionPages` touches only
    `retiredSessionPages`/`observedSchedulablePages`, which feed numerator and denominator only.
  coverage_gap: |
    No test covers the terminal push, which is why this shipped green.
    `DownloadContinuedSessionLedgerTests.swift:93` pins a drained
    "20 / 20 pages · 0 galleries" but manufactures that fourth push by calling
    `pushContinuedSessionProgress(sessionID:)` DIRECTLY after the last `settleCompletedDownload` —
    a call the product never makes, because at that point `reconcileContinuedSession` takes the
    drain branch. The three tests that do drive a real drain through production entry points
    assert only `finishCount`/`finishSuccesses` and never inspect `spy.progressUpdates`; the two
    production-path cases that do assert a subtitle (pause, delete) both stop one gallery short of
    an empty queue. Contract-unfaithful test double, same failure mode as the earlier gap rounds.
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      issue: "277-289 — the drain branch of reconcileContinuedSession ends the session with no push. This is the defect. (385-420 pushContinuedSessionProgress is correct in itself, simply never invoked at drain.)"
    - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
      issue: "185-188, 250-272 — finish/endSession carry no subtitle (endSession(yielding: nil,) → setTaskCompleted only), confirming the last updateProgress is terminal"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift"
      issue: "61 — the force: true flush that writes the stale final string"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift"
      issue: "97-99 — .active derivation that keeps the running gallery permanently in its own schedulable set, making a 0-gallery push structurally unreachable"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
      issue: "93 — synthesizes the terminal push the product omits, by invoking pushContinuedSessionProgress directly"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
      issue: "221-236, 263-279, 805-835 — the three real-drain tests, none asserting a subtitle"
  missing:
    - "Emit one final push in the drain branch of reconcileContinuedSession before ending the session. Order is load-bearing: it must sit AFTER the existing `continuedClientSessionID == nil` deferral (281-284) and BEFORE markContinuedSessionEnded, which clears continuedSessionID (failing the push's own ownership guard) and zeroes retiredSessionPages (the ledger the terminal fraction needs). With the ledger intact this yields \"N / N pages · 0 galleries\"."
    - "Decide during planning whether a push immediately followed by setTaskCompleted actually repaints on device — a real empirical risk, since the card is system-rendered and has surprised this phase twice. If it does not repaint, the alternative is to change galleryCount's basis to the session's whole coverage so no stale value is possible — that is a documented-contract change, not a bug fix, and must be decided deliberately."
    - "Assert the last recorded subtitle on a PRODUCTION-PATH drain — extend testDrainingTheQueueCompletesTheSessionWithSuccess and testCancellingTheLastQueuedWorkItemCompletesTheSession to inspect spy.progressUpdates.last. Do NOT add another directly-invoked push, or the same blind spot reopens."
    - "No localization work needed: the string catalog already renders 0 correctly via the plural `other` category."
  secondary_note: |
    Non-blocking, but it constrains the fix choice: post-ledger the pushed pair mixes bases — the
    fraction is session-cumulative while the count is live-only — so a mid-run read is e.g.
    "16 / 20 pages · 1 gallery" where the 20 spans three galleries. Documented as deliberate.
  debug_session: ".planning/debug/continued-session-subtitle-stuck-at-one-gallery.md"

- gap_id: G-15-2C
  truth: "The gallery count displayed beside X / Y pages equals the number of galleries whose pages are represented by denominator Y, including galleries that already completed during the session."
  status: resolved
  resolved_by: 15-55-PLAN.md
  resolved_at: 2026-08-09
  resolution_note: |
    D-G2C-01 coverage basis landed (coverageGalleryCount: live schedulable + positive
    retirements), contract docs and every pinned subtitle rewritten, terminal push kept as
    defence. Fidelity-audited zero-deviation 2026-08-09; full suite green. NOT yet re-observed
    on a device — test 2 round 4 above is the confirming run, with the expected observation
    changed to "· 2 galleries" on every frame.
  reason: "User reported: after both galleries completed, the card still displayed 1 gallery. The count appears to describe only the currently active gallery set, but it should describe every gallery represented by the denominator in X / Y pages."
  severity: major
  test: 2
  user_hypothesis: "The subtitle count uses live queue membership while totalUnitCount uses a cumulative session basis; both should use the same gallery coverage basis."
  root_cause: |
    Two coupled causes behind one observable defect. (1) Basis, the design cause: the pushed pair
    mixes bases by documented contract — the fraction is session-cumulative (live sum +
    retiredSessionPages on both sides, DownloadClient+ContinuedSession.swift:804-808) while
    galleryCount is the live schedulable count only (:819 via :138; doc :10-15, D-G2-01). A
    downloading gallery is always .active (DownloadClient+Persistence.swift:97-99) hence always
    schedulable (DownloadClient+Scheduling.swift:125-127), so every frame computable while the
    last gallery downloads — including the final forced flush
    (DownloadClient+PageDownload.swift:56-64 → DownloadClient+Persistence.swift:224) —
    necessarily reads "· 1 gallery" beside a denominator spanning the whole session. The user's
    truth is violated by this contract on every mid-run frame, independent of anything at drain.
    (2) Render, the mechanism exposing it at drain: the only frame that can say otherwise is the
    15-22 terminal push (:573), and static analysis proves it fires on EVERY production drain
    route, computes the correct "N / N pages · 0 galleries", and is strictly ordered before
    setTaskCompleted (both awaited across the MainActor; updateProgress unthrottled,
    ContinuedProcessingSession.swift:227-242; completion :364). The device still renders the
    forced flush's "1 gallery" — the system-owned card does not repaint an update issued
    immediately before task completion. That is exactly the empirical risk G-15-2B's missing[]
    flagged, now confirmed on device. The 15-54 numerator redesign is not implicated
    (numerator-only by its own contract, :88).
  diagnosis_evidence: |
    Terminal push verified present, correctly positioned (after the client-id deferral :568,
    before markContinuedSessionEnded :585), correctly valued (empty schedulable set → count 0,
    ledger → N/N), on every drain-shaped exit — completion, last-item cancel and pause-drain all
    converge on scheduleNextIfNeeded's reconciling tail; expiration/unavailable dismiss or never
    show the card — eliminating the missed-push hypothesis. The client seam has no throttle/drop
    and each updateProgress is awaited to completion, so out-of-order delivery cannot explain the
    stale string, leaving the OS render race as the only mechanism consistent with the device
    observation. All four production pushes (:573, :589, Persistence:224, ExecutionSupport:494)
    share line 819's live-only count; task.updateTitle has exactly one call site — no second
    writer with a different basis exists. The coverage count is directly derivable from state the
    push already reads: live snapshot galleries + retiredSessionPages entries;
    reconcileRetiredSessionPages already deduplicates rejoins (:652-654).
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      issue: ":819 live-only galleryCount (the defect under the user's truth); :10-15 and :88 the documented mixed-basis contract to rewrite; :573 terminal push (correct but unrenderable at drain)"
    - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
      issue: ":227-242 and :364 prove app-side choreography is correct — the failure to display the terminal frame is OS-side"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
      issue: "subtitle expectations at :237, :286, :315, :344-345, :402-403, :439, :490-491, :525-526 pin the live-only basis — must be rewritten, not supplemented"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
      issue: "subtitle expectations at :43, :57, :98-101, :186-187, :227, :239, :278, :285, :322, :329, :380-382, :428, :436, :461, :472, :509 pin the live-only basis — same rewrite"
  missing:
    - "Change galleryCount's basis to the denominator's coverage — live schedulable galleries plus departed galleries whose retiredSessionPages entries contribute pages to Y — computed inside pushContinuedSessionProgress from state it already reads. Under the new basis every frame of a two-gallery run reads \"2 galleries\", so the card is truthful whether or not the OS renders the final frame — the render-race dependency disappears rather than being raced harder."
    - "Rewrite the documented contract (D-G2-01 note at :10-15 and the count doc at :88) to the coverage basis; the mixed-basis secondary_note from G-15-2B becomes obsolete."
    - "Rewrite the pinned subtitle expectations in DownloadContinuedSessionTests and DownloadContinuedSessionLedgerTests to the coverage basis — rewrite, not supplement."
    - "Decide during planning whether a zero-page retirement counts as represented by Y — the letter of the user's truth says no."
    - "Keep the 15-22 terminal push as harmless defence."
  debug_session: ".planning/debug/continued-session-gallery-count-basis.md"

- gap_id: G-15-5
  truth: "After validation marks missing image files as pending, the user can immediately start a repair download, and the missing-page indicator, displayed page count, and persisted pending-page state remain consistent across relaunch."
  status: resolved
  resolved_by: [15-56-PLAN.md, 15-57-PLAN.md]
  resolved_at: 2026-08-09
  resolution_note: |
    Root fix (D-G5B-01): validate durably reconciles the manifest under the D-G5-01 guards;
    validationErrors reduced to operation-level and cleared at every enqueue (WR-03 closed the
    fifth entrance); affordances swept (retry basis, downloadNeedsRepair, dead canRetry).
    Hardened by the owner-directed SSOT collapse (15-58/59/60: content-evidence arm with
    removal-under-guards, manifest-derived inspector, invariant property suite) and the 10/10
    review-fix pass. Fidelity-audited zero-deviation 2026-08-09; full suite green. NOT yet
    re-observed on a device — test 5 round 2 above is the confirming run.
  reason: "User reported: after Validate Image Data marked 10 missing pages as pending, Pause and Retry Failed Pages were disabled and no Resume or other repair-start action was available. After relaunch, the yellow missing state disappeared and the UI displayed 36 / 36 while 10 pages were still pending."
  severity: major
  test: 5
  root_cause: |
    One root state produces all three observed defects. validateImageData records its
    missingFiles verdict ONLY in the coordinator's in-memory validationErrors dictionary
    (DownloadClient+Manager.swift:430; the doc at DownloadClient+PersistenceNormalize.swift:89
    says so explicitly: "session-scoped status, not persisted") and never reconciles the
    persisted manifest, whose page hashes still claim all 36 pages (manifest.completedPageCount
    counts non-empty hashes — untouched by external file deletion). The resulting shape —
    displayStatus == .error (transient) over a complete-claiming record — is a hole between
    every gate. (1) No start affordance: Pause needs .active/.inactive/.queued (canTogglePause,
    DownloadedGallery+SupportTypes.swift:66-72) — false at .error, and togglePause hard-fails
    .error anyway (DownloadClient+PublicAPI.swift:196-198); "Retry Failed Pages" needs .failed
    pages (canRetryFailedPages), but externally-deleted pages derive .pending in
    buildInspectionPages (file absent, no recorded page failure —
    DownloadClient+PublicAPIHelpers.swift:18-51); the "pending" the user saw is derived at
    inspection time from live file presence, not something validation wrote. The only enabled
    inspector action is Validate itself — a circular dead end. The Downloads row/context menu
    have no retry (canRetry has zero consumers — dead code), and Detail's .error button offers
    only destructive .redownload because downloadNeedsRepair demands completedPageCount == 0
    (DetailReducer.swift:93-97), a condition that only holds AFTER a repair run's blanking loop
    already ran, never at the validate-discovers-missing moment. (2) Relaunch loses the yellow
    state: validationErrors dies with the process; displayStatus
    (DownloadClient+Persistence.swift:90-114) re-derives .completed from the intact hash claims
    (the yellow is the .error badge color, DownloadedGallery+Extensions.swift:11). (3) "36 / 36"
    vs "10 pending": two independent bases — the badge counts persisted non-empty manifest
    hashes (DownloadedGallery+Manifest.swift:67-73) while the inspector page groups scan live
    file presence. Hash-blanking exists only inside prepareWorkingSeed (D-G5-01,
    reconcileWorkingManifestAgainstPageFiles) — reachable only after a repair STARTS, which this
    state cannot.
  diagnosis_evidence: |
    storage.validate is pure read-only (DownloadStore+Operations.swift:209-311); validation's
    sole mutation is the transient dictionary write — no auto-enqueue was ever designed at this
    seam. The design intent (validation error → repair) exists in mode resolution — queuedMode's
    ".error where fileOperationFailed → .repair" branch
    (DownloadClient+SchedulingHelpers.swift:16-20) — but it is a fallback only consulted for
    already-enqueued galleries; every UI enqueue path pins an explicit mode first. The needed
    repair-starter already exists: retryPages(gid:pageIndices:)
    (DownloadClient+RetryHelpers.swift:45-95) clears validationErrors, pins .repair with a page
    selection, enqueues and schedules — the inspector just hardcodes failedPageIndices into it.
    Shape sweep: the all-pages-missing shape hits the identical dead end; the paused-gallery
    shape is unreachable (validate gated off .inactive); a genuinely-incomplete inactive record
    already resumes to .repair correctly — the hole is exactly the complete-claiming-record
    shape. Hazard for the fix: validationErrors outranks queueStore in displayStatus, so an
    enqueue without clearing it would read .error, never .queued, and stay unschedulable — every
    existing enqueue path clears it first; any new affordance must too. Naming note: the "It
    closes G-15-5" doc on the blanking loop (DownloadClient+ExecutionSupport.swift:540) refers
    to an earlier, same-numbered gap (record reading complete DURING a repair run); the current
    G-15-5 is the validate-time hole beside it.
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift"
      issue: ":90-110 — validate writes only the transient dictionary; never reconciles the manifest"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift"
      issue: ":90-114 — displayStatus derivation: the transient .error / relaunch .completed flip"
    - path: "AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift"
      issue: ":57-115 — all gating predicates exclude the complete-claiming .error shape; canRetry is dead code"
    - path: "AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift"
      issue: "inspector's 3-action set; retry hardcoded to .failed pages (with DownloadsView+Subviews.swift:59-96)"
    - path: "AppPackage/Sources/DetailFeature/DetailReducer.swift"
      issue: ":93-97 — downloadNeedsRepair's completedPageCount == 0 basis can never hold at validate time"
    - path: "AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift"
      issue: ":67-73 — persisted-hash count basis, diverging from live file-presence scans in DownloadClient+PublicAPIHelpers.swift:18-51"
  missing:
    - "Preferred root fix: on a missingFiles verdict, durably reconcile the manifest — blank the missing pages' hashes under the same positive-signal guards D-G5-01 already implements — so the record honestly reads incomplete → .inactive → Resume enables → resumeMode resolves .repair; state survives relaunch and both count bases converge at 26/36."
    - "Additive affordance fix: route pending+failed indices into the existing retryPages(gid:pageIndices:) from the inspector for the .error/fileOperationFailed shape."
    - "Either way, clear validationErrors at/before enqueue — it outranks queueStore in displayStatus, so an enqueue without clearing reads .error and stays unschedulable."
    - "Sweep downloadNeedsRepair's completedPageCount == 0 basis and the dead canRetry predicate."
  debug_session: ".planning/debug/repair-unstartable-after-validate.md"

## Deferred Follow-Ups

- test: 6
  idea: "Rename the logs folder so its displayed name begins with an uppercase letter."
  scope: out_of_scope
  deferred_at: 2026-08-08

- test: 6
  idea: |
    Keep a DownloadsView gallery row's swipe-action offset in place while its deletion alert is
    presented. Cancelling should return the row to its resting position; confirming deletion
    should continue the row in the swipe direction and remove it. Eliminate the current
    disappear-reappear-disappear sequence in which the row vanishes when the alert appears,
    returns while awaiting confirmation, and vanishes again only after Delete is confirmed.
  scope: out_of_scope
  deferred_at: 2026-08-08
