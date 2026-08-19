---
status: testing
phase: 15-continued-background-downloads
source: [15-VERIFICATION.md, 15-54-SUMMARY.md, 15-55-SUMMARY.md, 15-56-SUMMARY.md, 15-57-SUMMARY.md, 15-58-SUMMARY.md, 15-59-SUMMARY.md, 15-60-SUMMARY.md, 15-61-SUMMARY.md, 15-62-SUMMARY.md, 15-63-SUMMARY.md, 15-64-SUMMARY.md, 15-65-SUMMARY.md, 15-66-SUMMARY.md, 15-67-SUMMARY.md, 15-68-SUMMARY.md, 15-69-SUMMARY.md, 15-70-SUMMARY.md, 15-71-SUMMARY.md, 15-72-SUMMARY.md, 15-73-SUMMARY.md, 15-74-SUMMARY.md, 15-75-SUMMARY.md, 15-76-SUMMARY.md, 15-77-PLAN.md, 15-REVIEW-FIX.md]
started: 2026-07-29T03:54:41Z
updated: 2026-08-19T08:20:00Z
round: 7
---

## Current Test

number: 2
name: system progress card — SC2 re-run at build f9892824 (round 7)
expected: |
  All fifteen checkpoints are resolved: 13 pass, 0 issues. Test 8 closed 2026-08-17 with the owner
  choosing row anchoring and directing the AGENTS.md rule amendment. Test 2 closed at round 6 on
  2026-08-18: the G-15-2D fixes (e68ca491, 1f9c3f34) were verified on the test iPhone across four
  independent backgrounded sessions, every one of which drained with a terminal push and none of
  which expired.

  The two gaps open at round 6 closed on the 260818-mjs build (3433cbeb), both on the test iPhone:
  G-15-2H (13cad7d9) against a folder renamed in Files.app, and G-15-2F (764c5958) against a rebuilt
  wholesale-refusal fixture.

  ROUND 7 REOPENED TEST 2. The SC2 re-run required by 15-VERIFICATION — a multi-gallery queue
  including a `.repair`, on a build containing f7e65497 — was started on 2026-08-19 and produced a
  CONFIRMED DEFECT before its card clauses could be judged: a continued-processing session was
  reclaimed with 376 pages outstanding, on healthy Wi-Fi with no airplane mode, after 676 s of a
  byte-identical numerator caused by one transfer that starved and was never retried. Filed as
  G-15-2I. Everything else the round exercised passed (wholesale refusal, the 27-page repair, the
  subtitle's gallery count across three enqueues).
awaiting: a fresh SC2 round — backgrounded this time — on a build carrying the G-15-2I fix
  (2a2c5982 starved-transfer abandonment + d6079878 bounded stall nudge, quick task 260819-lq3;
  the owner decided both halves on 2026-08-19 and both landed the same day)

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
regime, and never read a numerator above the work actually done EXCEPT for a bounded stall nudge
(see expected_note_2026_08_19); the subtitle names every gallery
the denominator covers and holds that count steady across a gallery's completion (with two queued
it reads "· 2 galleries" on every frame, including the last); a repair of a gallery whose files
were deleted outside the app climbs from its announce rather than freezing at the record's stale
claim; card-cancel state matches the in-app per-gallery pause baseline.
expected_note_2026_08_19: |
  THE NUMERATOR CLAUSE WAS AMENDED on 2026-08-19 by owner decision, when G-15-2I established that a
  card with no way to say "still working, nothing to add" is reclaimed by the scheduler while its
  queue still has work. The clause now admits a BOUNDED STALL NUDGE, and admits nothing else.

  A nudge is admissible only if ALL of these hold, which is what a round judging this clause must
  check:
    - it is below the resolution of the card and of any percentage the app or a test rounds to (one
      nudge is one subunit, 1/1000 of a page);
    - it advances only while the run is genuinely stalled — an unchanged measurement — and snaps back
      to the measurement the instant that changes, in EITHER direction, so a decrease is still
      published as readily as an increase and nothing is hidden;
    - it is bounded: capped at 30 consecutive nudges. That cap is the only bound, deliberately — the
      heartbeat that carries the nudge already runs only while there is pending work, and no second
      condition is layered on top of it;
    - it never reaches the scaled total, and never enters the record's completeness quantities,
      `displayStatus`, the retry basis or any scheduling gate.

  Everything else in the clause is unchanged: real work still moves the numerator, the count still
  never falls back within a reporting regime, and a numerator above real work by anything MORE than
  the nudge is still a failure. The device log names the nudge distinctly, so a round can tell real
  progress and the workaround apart rather than having to infer it.

expected_note: |
  The drain-time expectation CHANGED at round 4 with the 15-55 basis redesign: the final subtitle
  reads "N / N pages · 2 galleries", NOT "0 galleries". Rounds 1-3 were judged against the older
  basis; do not carry their wording forward.
why_human: The card and its cancel affordance are system-owned and do not render or fire in the simulator.
covers: SC2
result: issue
result_note: |
  PASSED at round 6 against build 260818-ek3. REOPENED at round 7 (2026-08-19) against build
  f9892824, where the re-run 15-VERIFICATION asked for surfaced G-15-2I — a session reclaimed with
  the queue undrained, on healthy Wi-Fi with no airplane mode. The card's own clauses were not
  reached at round 7; the run ended before they could be judged. Round 6's verdict is not withdrawn,
  it is superseded for this build.
retest_round_7_result: issue
retest_round_7_date: 2026-08-19
retest_round_7_build: f9892824 (13cad7d9 folder-leaf freeze, 764c5958 run-progress overlay, f7e65497 folder-deletion invariant)
retest_round_7_reported: |
  Staged on the test iPhone (physical iPhone 11, iOS 26.6) as the verification report prescribed: a
  multi-gallery queue including a `.repair` of a gallery whose files were deleted outside the app.
  The repair fixture was rebuilt by deleting `[4108805_3186cf251f] Onna no Battle` in Files.app and
  restoring ONLY its manifest.json, so the record claimed 27/27 with zero image files.

  WHAT PASSED
    - Validate on that gallery flipped the header to "Needs Attention 27/27" with the page groups
      unchanged at Downloaded (27) / Pending (0) / Failed (0) — the all-or-nothing wholesale guard
      refusing, as G-15-2G established.
    - Retry Pages queued it ("Queued 27/27" while another gallery held the single download slot),
      and the repair later completed at 27/27.
    - The second gallery reached `Download completed ... pages: 564`.
    - The subtitle's gallery count tracked the queue across three enqueues, with the denominator
      moving 564 -> 591 -> 1542 as galleries joined.

  WHAT FAILED
    G-15-2I. With 376 pages still outstanding the continued-processing session was reclaimed:
    23 consecutive heartbeats at a byte-identical 1166 / 1542 spanning 676 s, then
    "Continued-processing session expired, pausing schedulable downloads" with the environment probe
    reading `network wifi, low power false, thermal fair`. One transfer (page 576) reported starved
    at 12.6 s without bytes and was then never completed, failed or retried. See G-15-2I for the
    full trace, the two candidate root causes and the bounds on the observation — in particular that
    the app was in the FOREGROUND throughout, because `agent-device home` did not land, so the
    backgrounded case the SC2 procedure asks for is still unobserved at this build.
retest_round_6_result: pass
retest_round_6_date: 2026-08-18
retest_round_6_build: 260818-ek3 (e68ca491 pump serialization, 1f9c3f34 in-flight page-byte credit)
retest_round_6_reported: |
  Run on the test iPhone (physical iPhone 11, iOS 26.6) with airplane mode OFF and Wi-Fi connected —
  the environment probe recorded "network wifi" from the second session on, so the owner's
  "no airplane mode, no network fault" precondition held for the whole round.

  FOUR independent backgrounded continued-processing sessions ran during this round. EVERY one
  reached "Continued-processing session drained, terminal progress pushed." NONE expired, and the
  card never once read "Task failed" — the round-5 failure mode did not recur. Heartbeats arrived
  every ~10s throughout, with no gap approaching the ~30s stall window.

  Two-gallery run A (82 + 112 = 194 pages), backgrounded mid-download. Card frames observed on the
  system Background Activities surface:
      79 / 194 pages · 2 galleries
     111 / 194 pages · 2 galleries
     127 / 194 pages · 2 galleries
     143 / 194 pages · 2 galleries
     159 / 194 pages · 2 galleries
     176 / 194 pages · 2 galleries
  Gallery 1 (82 pages) completed between the 79 and 111 frames; the subtitle never dropped to
  "1 gallery". Log heartbeats ran to "192 / 194 pages ... 2 galleries" and then drained. Both
  galleries were confirmed complete in-app afterwards at 82/82 and 112/112 — exactly the 194
  denominator, so the numerator never ran above the work actually done.

  Two-gallery run B (78 + 26 = 104 pages). The second gallery joined mid-session and the log shows
  the basis widening correctly as it did: "71 / 78 pages ... 1 galleries" then
  "77 / 104 pages ... 2 galleries". Card frames observed: 90, 92, 95, 96, 97, 99, 99, 102 — all
  "/ 104 pages · 2 galleries", i.e. the count still read 2 well after the 26-page gallery had
  finished.

  The in-flight credit from 1f9c3f34 was observed doing its job. In run A the completed-page count
  sat flat at 62 for three consecutive heartbeats while in-flight subunits climbed 181 -> 490 -> 781;
  that page-granular plateau under thread limit 1 is the shape that previously let the system stall
  detector fire, and the session rode straight through it.
retest_round_6_clause_status: |
  1 (queue two, start foreground, background)            PASS - observed, both runs.
  2 ("· 2 galleries" on every frame incl. a completion)  PASS - 6 frames run A, 8 frames run B.
  3 (final subtitle "N / N pages · 2 galleries")         NOT CAPTURED - see caveat below.
  4 (never falls back, never above real work)            PASS - every series monotonic; run A ended
                                                         at exactly 194 = 82+82 confirmed in-app.
  5 (.repair climbs from the announce)                   PASS - see repair evidence below.
  6 (pause one mid-queue, card completes the rest)       PASS - see clause 6 evidence below.
  7 (card-cancel parity vs in-app pause baseline)        PASS - see clause 7 evidence below.
  ALL SEVEN clauses now carry a verdict; only clause 3's photograph is missing, and its substance
  is established by the surrounding evidence.
retest_round_6_clause_3_caveat: |
  The literal terminal frame could not be photographed in FIVE attempts across the round (polling
  at 20s, 15s, ~3s, ~2s and back-to-back with no delay at all). The system tears the card down at
  task completion faster than a screenshot round-trip: run B went from "102 / 104 pages ·
  2 galleries" to no card, and the clause-6 run from "388 / 402 pages · 2 galleries" to no card in
  the very next frame. What IS established is everything the clause is protecting: the fraction climbs
  truthfully to the very last heartbeat (192/194, 101/104), the gallery count still reads 2 at that
  point, the app does push a terminal progress update ("terminal progress pushed" on all four
  sessions), and the final in-app totals match the denominator exactly. Round 4 observed the
  "N / N pages · 2 galleries" wording directly under the 15-55 basis; 15-72 changed the announce
  input, not the subtitle's gallery-count basis, and rounds 4 and 6 agree on every frame either one
  could see. Treated as covered by composition rather than re-run a fourth time.
retest_round_6_repair_evidence: |
  Clause 5 was exercised for real, not inferred. A completed 27-page gallery had every image file
  deleted from OUTSIDE the app through Files.app, with manifest.json deliberately left in place so
  the record still claimed 27/27. "Validate Image Data" then flipped the row badge to amber and
  enabled "Retry Pages"; the retry re-fetched all 27 pages, and the session heartbeats read
      3 / 27 -> 8 / 27 -> 14 / 27 -> 20 / 27 -> 22 / 27 -> 25 / 27
  so the announced basis CLIMBED FROM ZERO and did not freeze at the record's stale 27. All 27
  pages plus the cover landed on disk and the sheet then read a truthful 27/27.
retest_round_6_clause_6_evidence: |
  Set up exactly as the clause specifies: a 564-page gallery downloading and a 78-page gallery
  queued behind it, then the LARGE one paused mid-queue, then the app backgrounded.

  The card and the log agree on what happened to the basis at the pause:
      06:13:00  heartbeat: 322 / 642 pages, 2 galleries   <- both live: 564 + 78
      06:13:11  heartbeat: 327 / 402 pages, 2 galleries   <- paused; basis re-bases to 324 + 78
      06:14:41  heartbeat: 399 / 402 pages, 2 galleries
      06:14:46  Continued-processing session drained, terminal progress pushed.
  402 = the paused gallery's 324 already-downloaded pages plus the 78 still to fetch, which is the
  15-55 rule working exactly as written: a departed gallery whose retirement contributed pages to Y
  stays in the coverage, so the subtitle keeps saying "2 galleries" rather than dropping to 1.
  Card frames photographed across the drain: 367, 370, 371, 372, 374, 376, 377, 379, 381, 383, 384,
  386, 388 — all "/ 402 pages · 2 galleries".

  The denominator SHRINKS at the pause (642 -> 402). That is a reporting-regime change, not the
  fall-back clause 4 forbids: the numerator moved FORWARD across it (322 -> 327) and the ratio went
  50% -> 81%. Clause 4 is scoped "within a reporting regime" and is not violated.

  Outcome afterwards: the 78-page gallery read 78/78 and the paused gallery still read exactly
  324/564, untouched by the session that completed around it.
retest_round_6_clause_7_evidence: |
  Two large galleries resumed together (564 + 951), app backgrounded, then the STOP control pressed
  on the system card itself.

  The photographed card read "135 / 1,515 pages · 2 galleries" (1515 = 564 + 951), and the log
  carries the same frame at 06:05:40, which ties the screenshot to the session beyond doubt. After
  the stop press:
      06:06:00  heartbeat: 148 / 1515 pages, 2 galleries
      06:06:05  Continued-processing session expired, pausing schedulable downloads.
      06:06:05  environment at expiry: network wifi, low power false, thermal nominal.
      06:06:05  Download paused, gid <masked>.
      06:06:05  Download paused, gid <masked>.
  The card disappeared immediately.

  Foregrounding showed the queue in exactly the in-app per-gallery pause state, with no relaunch in
  between:
      gallery A  "Paused 143/564"  Downloaded (143) 1-143   Pending (421) 144-564   Failed (0)
      gallery B  "Paused 10/951"   Downloaded (10)  1-10    Pending (941) 11-951    Failed (0)
  Both resumable, progress retained, page accounting contiguous, nothing marked failed. Sampled
  again 12s later and neither number had moved, so the transfers really were stopped rather than
  merely un-rendered. That is parity with pausing each gallery by hand.

  NOTE ON THE WORD "expired": this is the only expiration in the whole round, and it is the system
  delivering expiration BECAUSE THE USER CANCELLED from the card — the app's correct response is
  precisely the "pausing schedulable downloads" it logged. It is not a stall-detector expiry and
  must not be read as a G-15-2D recurrence.
retest_round_6_session_tally: |
  Seven continued-processing sessions were granted across the whole round. SIX ended in
  "drained, terminal progress pushed". ONE ended in expiration, and that one was the deliberate
  card-cancel of clause 7. Spontaneous or stall-detector expirations: ZERO.
retest_round_6_incidental: |
  Two things seen in passing that are NOT clause failures and are filed separately below:
  the in-app Download Status sheet stayed stale during the repair (see G-15-2F), and validation
  did not durably blank the refuted page hashes (see G-15-2G).
prior_round_5_result: issue
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
result: pass
owner_decision: |
  DECIDED 2026-08-17: branch (a). Keep the modifier on the ROW; today's placement stands and
  `AGENTS.md` (which `CLAUDE.md` symlinks to) was amended rather than the code.

  The owner directed the amendment's REASONING, not just its verdict: a confirmation dialog should
  still be attached to a structurally stable position in principle - what changed is the test for
  "stable". Stability is judged against changes UNRELATED to the dialog's own action. A row that
  disappears because the dialog's own confirmed deletion removed it is the intended terminal state,
  not instability, and the dialog going away with it is correct. What the rule guards against is the
  row leaving for a reason the dialog knows nothing about - a background refresh or observation
  stream reordering or dropping the item, a conditional gate flipping, an ancestor rebuilding -
  because then the dialog is dismissed silently and the action never fires. An anchor must never be
  relocated to defend against a removal the implementation itself intends.
rule_change: |
  `AGENTS.md` "Confirmation dialog / alert placement": the old trailing sentence
  ("Exception: for a per-row destructive action whose row can scroll out of view, the stable
  action-source is the enclosing list container, so attach it there.") is REMOVED, and the inline
  parenthetical defining "stable" is replaced by two paragraphs - one defining stability against
  unrelated change, one recording the per-row conclusion with its device evidence.
observation_status: BOTH HALVES OBSERVED
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
partially_obsoleted_2026_08_17: |
  `LogsDirectoryMigration` was deleted by owner decision, so the RENAME half of this test (launching
  a build over a pre-rename install and watching the existing files survive onto `Logs`) no longer
  has a subject. The half that still stands, and is what 15-76 D9 actually asked for, is the DEEP
  LINK: `ApplicationClient.openFileApp` builds `shareddocuments://` from
  `FileUtil.logsDirectoryURL.path`, and the device run confirmed "Open in Files" opens the `Logs`
  folder and shows its log files. That half is unaffected by the removal, so the pass stands on it.
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
result: obsolete
obsoleted_by: |
  OWNER DECISION 2026-08-17: `LogsDirectoryMigration` was deleted, and a `Logs-migrating-<uuid>`
  staging directory is a residue only that type could mint. With the type gone nothing can produce
  the fixture, so this checkpoint has no subject. The WR-01 recovery code it exercised was removed
  along with the rest of the file.
superseded_result: pass
superseded_note: |
  The device run below genuinely passed on 2026-08-16 against the code as it then stood. It is kept
  because it is the evidence that WR-01's recovery worked, not because the behaviour still exists.
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
result: obsolete
obsoleted_by: |
  OWNER DECISION 2026-08-17: `LogsDirectoryMigration` was DELETED outright, so this test's subject
  no longer exists. See the `G-15-11` gap entry for the full decision record and the correction to
  the defect claim that preceded it.
superseded_result: issue
superseded_note: |
  The result below was recorded before the removal decision, and before tracing established that
  the observed behaviour was deliberate and test-pinned rather than defective. Kept for history.
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
issues: 1
pending: 0
skipped: 0
blocked: 0
obsolete: 2

completion_note: |
  ROUND 7 (2026-08-19) REOPENED TEST 2, so one checkpoint is now failing. The SC2 re-run that
  15-VERIFICATION required — on a build containing f7e65497 — produced G-15-2I: a continued-processing
  session reclaimed with 376 pages outstanding, on healthy Wi-Fi with no airplane mode, after 676 s
  of a byte-identical numerator caused by a starved transfer that was detected and then never
  retried. Test 2's own card clauses were not reached; the run ended first. Round 6's pass stands for
  build 260818-ek3 and is superseded only for this build. Everything else round 7 exercised passed.

  The paragraphs below describe the state as of round 6 and remain accurate for that build. G-15-2D — the system
  Background Activities surface reporting "Task failed" for a two-gallery session that completed —
  was diagnosed to Apple's stall detector and closed on device at round 6 (2026-08-18) against
  build 260818-ek3: four independent backgrounded sessions, all four drained with a terminal push,
  none expired, on healthy Wi-Fi with no airplane mode.

  All seven of test 2's clauses were exercised on device at round 6 and six of them pass outright,
  including clause 6 (pause one gallery mid-queue) and clause 7 (card-cancel parity with the in-app
  pause baseline). Clause 3's literal terminal frame remains the single uncaptured item: the system
  tears the card down at completion faster than a screenshot round-trip, across five attempts. See
  the clause-3 caveat on test 2 for the evidence that stands in its place.

  Three incidental findings were opened during round 6 and none is a checkpoint failure; all three
  are now closed. G-15-2G — the question of whether validation must durably blank hashes — was
  settled on device the same day and closed as no-defect: a partial deletion of 6 of 26 pages
  blanked exactly those 6 hashes durably and survived relaunch, so the earlier all-missing case was
  the wholesale guard refusing, as designed.

  G-15-2F (the Download Status sheet reading stale during a repair) and G-15-2H (a repair renaming
  the user-visible folder) were fixed on 2026-08-18 in commits 764c5958 and 13cad7d9 and both were
  then VERIFIED ON THE TEST IPHONE the same day against build 3433cbeb, honouring the G-15-2D
  precedent that a fix is not closed until a device shows it. G-15-2H was staged by renaming a
  gallery folder in Files.app and repairing it: the name survived, one folder per gid, no Code=4
  line. G-15-2F was staged by restoring only a manifest into an emptied folder: with the record
  claiming 27/27 the sheet announced 0/27 with 27 pending and climbed to 21/27 while the manifest on
  disk still read 27/27, then returned to the record's reading at the run's exit.
obsolescence_note: |
  Tests 10 and 11 are `obsolete` rather than pass/issue because the owner deleted
  `LogsDirectoryMigration` on 2026-08-17, removing their subject. Test 9 keeps its pass on the
  half that survives (the Files deep link); its rename half went with the migration. Counting them
  as passes would overstate what this UAT verified about the shipped code, and counting test 11 as
  an open issue would keep a defect claim alive against code that no longer exists — the count
  above deliberately does neither.
open_issues_note: |
  No checkpoint is failing. G-15-2D is resolved on device (round 6, 2026-08-18). G-15-11 was closed
  by removal when the owner deleted LogsDirectoryMigration on 2026-08-17. Two items were opened
  incidentally during round 6, neither of them a checkpoint result; G-15-2G was settled the same day
  by the partial-deletion check it called for and closed as no-defect, the wholesale guard being
  working as designed. TWO gaps now carry `status: open`, both incidental to round 6 and neither a
  checkpoint failure: G-15-2F, a minor in-app display defect where the Download Status sheet reads
  stale during a repair; and G-15-2H, a repair re-creating a gallery's user-visible folder under a
  different name than the original download used. Both now carry a LANDED FIX pending device
  confirmation — G-15-2F in commit 764c5958 (the live run's measurement published on the row, badge
  and page states read from it while it stands) and G-15-2H in commit 13cad7d9 (the folder's
  readable leaf frozen at first creation). Each entry's `fix_landed_2026_08_18` block states what
  the next device round must show; neither is closed on code alone.

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

- gap_id: G-15-2I
  truth: "With no airplane mode and a healthy network, a continued-processing session does not end while its queue still has work: a transfer that stops producing bytes is abandoned and retried, and the session is not reclaimed for want of something to report."
  status: open
  severity: confirmed-defect (fixed in 2a2c5982 + d6079878; device verification pending)
  found: "2026-08-19, round 7, on the SC2 re-run against build f9892824 (13cad7d9 + 764c5958 + f7e65497)"
  observed: |
    A continued-processing session was reclaimed by the system with 376 pages still to download,
    under exactly the conditions the owner's 2026-08-17 ruling declares unacceptable. From
    `Logs/ehpanda-20260819-120659-2.jsonl` (times UTC; local is +9):

      03:32:26  heartbeat 1166 / 1542 pages, 0 in-flight subunits, 3 galleries, 1 transfers in flight
      03:32:36  Page transfer starved, page 576, created foreground,
                12593 ms without bytes, still transferring
        ...     23 consecutive heartbeats, numerator BYTE-IDENTICAL at 1166 / 1542 and
                in-flight subunits 0 throughout, spanning 676 s (11 min 16 s)
      03:43:42  heartbeat 1166 / 1542            <- last flat beat
      03:43:50  Continued-processing session expired, pausing schedulable downloads
      03:43:50  environment at expiry: network wifi, low power false, thermal fair
      03:43:50  Download paused

    `network wifi`, thermal fair, no airplane mode, low power off. The queue was NOT drained: the
    session died at 1166 of 1542 pages and the schedulable downloads were paused.

    The `Page transfer starved` line appears exactly ONCE — `InFlightPageTransfer.stallLogged`
    suppresses repeats — and page 576's transfer thereafter never completed, never failed and was
    never retried. It hung for the whole 11 minutes until the session was reclaimed.

    NOT OBSERVED, stated as inference only: whether the system painted a "Task failed" card. The
    card was not captured before teardown. Per the G-15-2D code analysis recorded in this file,
    expiration is one of exactly two paths reaching `setTaskCompleted(success: false)` on an adopted
    task, so a failure card is the expected consequence — but this run did not confirm it.
  two_candidate_root_causes: |
    (1) A STARVED TRANSFER IS DETECTED AND THEN NOT ACTED ON — the likelier primary cause here.
        `DownloadCoordinator.pageTransferStallThreshold` is 10 s and `sweepStarvedPageTransfers`
        does fire, but its only effect is the log line above. Nothing cancels the transfer, fails
        the page, or schedules a retry, so real progress never resumes. Had the hung transfer been
        abandoned after some bound, the numerator would have moved and no expiry would have followed.

    (2) THE CARD HAS NO WAY TO SAY "STILL WORKING, NOTHING TO ADD" — the second line of defence.
        `updateProgress` publishes `completedUnitCount * 1000 + inFlightSubunitCount`
        (`ContinuedProcessingSession.swift:268-286`). Both terms were frozen here: no page landed and
        the starved transfer earned no bytes, so republishing the identical count is not an advance
        and the scheduler treats the task as stalled. The heartbeat already COMPUTES this condition —
        `DownloadClient+ContinuedSessionHeartbeat.swift:96` compares `completedSubunits` against the
        previous summary — but uses it only to suppress a duplicate log line.

    The two are not alternatives. (1) alone leaves every other zero-byte-but-legitimate wait exposed
    (a 509 rate-limit back-off, a discretionary background transfer the system defers). (2) alone
    would keep a session alive indefinitely on a download that will never progress, which conflicts
    with this file's own honesty clause on the card's numerator. An owner decision is needed on
    whether to take one, the other, or both, and on what bound each carries.
  bounds_on_this_observation: |
    - THE APP WAS IN THE FOREGROUND for the whole window. `agent-device home` reported success but
      did not land (on this device ref presses and `home` frequently report success without taking
      effect; only coordinate presses are reliable), so this is not the backgrounded scenario the
      SC2 procedure asks for. A foreground expiry is at least as bad, but the backgrounded case
      remains unobserved at this build.
    - NOT A REGRESSION FROM f7e65497. That commit does not touch
      `DownloadClient+ContinuedSession.swift`; this is the pre-existing stall-detector exposure that
      round 6 happened not to hit. Round 6's seven sessions all had a moving numerator.
    - The stall is a genuine network-level hang, NOT a progress-accounting shortfall. This is the
      opposite shape from G-15-2D, which was real byte movement that the page-granular numerator
      could not express and which 1f9c3f34 fixed by adding resolution. Here there was no movement
      to find.
  what_else_this_round_showed: |
    Everything the round exercised besides the session lifetime behaved correctly at this build:
      - the wholesale guard refused as designed — Validate on a manifest-only gallery flipped the
        header to "Needs Attention 27/27" with `Downloaded (27) / Pending (0) / Failed (0)` unchanged
      - that gallery's 27-page from-zero repair completed and the row settled at 27/27
      - `Download completed ... pages: 564` for the second gallery
      - the subtitle's gallery count tracked the queue: 1 gallery, then 2 at the repair's enqueue
        (denominator 564 -> 591), then 3 when a third was resumed (-> 1542)
  why_it_matters: |
    This is the exact class the owner ruled on 2026-08-17: "在沒有飛航模式、網路異常等情況時 session
    在下載未完成的情況下結束是不能接受的". The environment probe recorded at expiry says the
    precondition held, so this observation is inside the ruling, not excused by it.
  blocks: "SC2. The criterion cannot be judged verified while a device run at this build ends a session early with the queue undrained."
  owner_decision_2026_08_19: |
    BOTH HALVES, not one. The starved transfer is abandoned and retried (the root cause of this
    observation), AND the card gains a bounded way to say "still working, nothing to add" (the safety
    net for every zero-byte-but-legitimate wait the retry cannot reach — a 509 back-off, a
    discretionary background transfer the system defers). Neither alone is sufficient: the retry
    leaves those other waits exposed, and the safety net alone would keep a session alive on a
    download that will never progress.

    The two numbers were decided by the owner on 2026-08-19: a 60 s abandon threshold, and a cap of
    30 consecutive nudges. The UAT clause amendment below was delegated to the agent's wording.
  binding_and_suggested: |
    READ THIS FIRST. Everything below is in one of two categories and they are NOT equal.

      BINDING — the owner's decisions, listed under owner_decision_2026_08_19 and restated in
      "BINDING" blocks below. These are settled; a plan that departs from them is wrong.

      SUGGESTED — everything in the "SUGGESTED" blocks. That is one agent's engineering opinion,
      written before planning and without a planner's analysis. The planner OWNS these choices and
      may discard any of them outright. Where a suggestion cites an observation (a log line, a source
      line, a count), the OBSERVATION stands as evidence; the conclusion drawn from it does not bind.

    ============================ HALF 1 — ABANDON AND RETRY A STARVED TRANSFER ============================

    BINDING: a page transfer that has produced no bytes for 60 SECONDS is abandoned and retried.
    Both the behaviour and the number are the owner's, decided 2026-08-19.

    SUGGESTED, everything from here to the end of Half 1 — the planner may take any, all or none:

    GOAL: a page transfer that has produced no bytes for long enough is cancelled and retried, so real
    progress resumes instead of the queue hanging on it.

    NEW CONSTANT, beside the existing one in `DownloadClient+Manager.swift:66`:
        pageTransferAbandonThreshold: TimeInterval = 60
    Keep `pageTransferStallThreshold = 10` as the DETECTION/log threshold. Two separate constants on
    purpose: the log stays sensitive, the action stays conservative. Do not merge them.

    MEASURED FROM THE LAST BYTE RECEIVED, never from the transfer's start. A slow-but-moving transfer
    must never be abandoned. `InFlightPageTransfer` already carries `startDate`, `firstByteDate` and
    `creditedSubunits`; whatever field the sweep needs for "when did bytes last arrive" is to be added
    there and updated on the same path that grows `creditedSubunits`
    (`DownloadClient+PageTransferProgress.swift:120-121`).

    WHERE: `sweepStarvedPageTransfers` already runs on every heartbeat and already classifies a
    starved transfer — today its only effect is the log line and the `stallLogged` latch. Extend that
    same sweep; do not add a second timer.

    ON ABANDON: cancel the transfer and retry the page, counting the attempt against the existing
    `DownloadCoordinator.retryLimit = 3`. So a persistently starved page fails after roughly three
    minutes and the gallery reports that page failed, rather than the queue hanging. Reuse the
    existing retry path — `beginPageTransfer` already documents that a retry is "the same page
    continuing rather than a new one starting" and deliberately keeps earned credit via `max`.

    ============================ HALF 2 — A BOUNDED STALL NUDGE ON THE CARD ============================

    BINDING, all four:
      (a) the card gains a bounded way to keep its published count advancing while the run is stalled;
      (b) the cap is 30 CONSECUTIVE NUDGES;
      (c) there is NO second "is there work" condition — see the rejection note below, which is the
          owner's, not a suggestion;
      (d) the design is adapted from a reference project whose name is never recorded — see CHECKPOINT.

    SUGGESTED, everything else in Half 2:

    GOAL: while the app legitimately has work pending but has nothing new to report, the published
    count still advances, so the scheduler does not treat the task as stalled.

    THIS DESIGN IS ADAPTED FROM A REFERENCE PROJECT — see the CHECKPOINT below. Reproduce its content
    name-free; the source project is never to be named in any file here.

    SHAPE:
      - NO SECOND "IS THERE WORK" CONDITION (BINDING — the owner's rejection, not a suggestion).
        Nudge on every stalled report; the CAP below is the only bound. An earlier draft of this spec gated the nudge on "at least one in-flight transfer OR a
        scheduled retry" and the owner rejected it on 2026-08-19, correctly: a session with nothing to
        do must not exist in the first place, so guarding against that state implies it is expected.
        `beatContinuedSession` (`DownloadClient+ContinuedSessionHeartbeat.swift:85`) ALREADY opens with
        `guard continuedSessionID == sessionID, await hasPendingWork() else { ... }`, so the nudge —
        which lives inside that heartbeat — is already covered by the one correct guard.
        The rejected condition was not merely redundant, it was WRONG at a different granularity: in
        the G-15-2I log 62 heartbeats read `0 transfers in flight`, many of them while progress was
        healthily advancing, so that condition would have been false in a large fraction of ordinary
        frames and would have stopped nudging mid-download — manufacturing the very defect this fixes.
        Do not reintroduce it in any form.
      - CAP AT 30 CONSECUTIVE NUDGES (BINDING) (~5 min at the 10 s heartbeat), which is now the ONLY bound and
        therefore carries the whole weight. Rationale to record in the source: with Half 1 in place a
        page can be starved at most retryLimit x pageTransferAbandonThreshold = 3 x 60 s = 180 s
        before it fails and the queue moves, so 30 nudges is generous headroom over the worst
        legitimate case while still guaranteeing a wedged queue cannot hold the session forever.
        PLANNING MUST RE-DERIVE THIS against a 509 back-off, which can legitimately exceed five
        minutes, and say plainly which side it chose.
      - SNAP BACK on any real change, in EITHER direction. A measurement that differs from the last
        one clears the accumulated nudge; a decrease is published as readily as an increase, so
        nothing is hidden.
      - DO NOT CHANGE THE DENOMINATOR. Keep `totalUnitCount = pages x subunitsPerUnit` (1000). The
        reference implementation republishes against 2^53 because its basis is fraction-based;
        this app's units are semantically meaningful integers and test 2 judges that semantics. One
        nudge is ONE SUBUNIT = 1/1000 of a page, which on a 27-page gallery is 0.0037% — below the
        card's resolution and below any percentage this app or its tests round to.
      - HEADROOM: the nudge must never reach the scaled total, because reaching it marks the progress
        finished. `foldedCompletedUnitCount` (`ContinuedProcessingSession.swift:278-287`) already
        clamps with `min`; the clamp must not be the thing that silently swallows the nudge either.
        Hold back enough units above the highest measurement that a nudge on a finished-looking
        measurement is still expressible, exactly as the reference implementation reserves headroom.
      - THE HOOK ALREADY EXISTS. `DownloadClient+ContinuedSessionHeartbeat.swift:96` already compares
        this beat's `completedSubunits` against the previous summary's, and uses the answer only to
        suppress a duplicate log line. That comparison is the stalled-report predicate; do not
        introduce a second one.
      - LOG THE NUDGE distinctly, so a device log tells real progress and the workaround apart. This
        is what made G-15-2I diagnosable at all and the same property must survive the fix.

    ============================ CHECKPOINT — PLANNING MUST ASK THE OWNER ============================

    Half 2 is adapted from an implementation in another local project on this machine. Its content is
    summarized above, but the planner SHOULD read the original before writing the plan.

    AT THE PLANNING STAGE, ASK THE OWNER, IN CONVERSATION, which local project to read it from. Do
    not guess, and do not proceed on the summary alone if the owner is available to answer.

    THE ANSWER IS NEVER WRITTEN DOWN. Per AGENTS.md "Local project reference privacy" — which is
    absolute, overrides every other instruction including a direct request, and is not waivable — the
    project's name must not appear in this file, in the plan, in the summary, in source, in comments
    or in any commit message. Refer to it only as "a reference project". This repository is
    open-source; other projects on a contributor's machine may not be.

    ============================ TESTS — SUGGESTED ONLY ============================
    Not a required test list. These are the cases one agent thought discriminating; the planner
    decides what to write and may cover the same properties differently or better.
      Half 1: a transfer whose bytes stop is abandoned at the threshold and retried; a slow-but-moving
        transfer is NOT abandoned (the discriminating control — pin it, since measuring from the wrong
        instant is the likely implementation error); a page starved across retryLimit attempts fails
        rather than hanging.
      Half 2: an identical measurement nudges by one subunit; any change snaps back and clears the
        accumulation, from BOTH directions; the cap holds at 30 and nothing else stops the nudge — pin
        that a stalled report with ZERO transfers in flight still nudges, since that is the frame the
        rejected condition would have dropped; the published count never reaches the scaled total; a run with
        an honest, moving measurement publishes exactly what it did before the change — the ordinary
        family must be untouched.
      Both: the existing continued-session suites stay green, and the `1 galleries` / `2 galleries`
        subtitle behaviour test 2 pins is unaffected.

    ============================ WHAT MUST NOT CHANGE — SUGGESTED ============================
    Offered as a blast-radius note, not a rule. The one genuinely binding boundary is the owner's
    standing SSOT line, already recorded in AGENTS.md and in DownloadRunProgress: a run-scoped
    display value must never enter the record's completeness, its gates, or its scheduling.
      `continuedSessionHeartbeatInterval` (10 s), `subunitsPerUnit` (1000), `retryLimit` (3), the
      record's completeness quantities, `displayStatus`, the retry basis, and every scheduling gate.
      The nudge is progress-of-this-RUN presentation only and must never enter any of them — the same
      boundary `DownloadRunProgress` already documents for the row overlay.

  fix_landed_2026_08_19: |
    Landed on feature/gsd-phase-15 as quick task 260819-lq3, two commits, one per half, both on the
    owner's decision above: 2a2c5982 `fix(15): abandon starved page transfers` and d6079878
    `fix(15): nudge a stalled session's card`. Full AppPackage suite green (1009 tests, +12 over the
    pre-fix 997), app-scheme build zero warnings, no lint suppression. The plan and its design
    decisions (PD-1..PD-8) are in `.planning/quick/260819-lq3-fix-g-15-2i-stall-abandon-and-card-nudge/`.

    HALF 1 — MECHANISM (2a2c5982)
      `DownloadCoordinator.pageTransferAbandonThreshold = 60` sits beside the unchanged 10 s
      `pageTransferStallThreshold`; two constants on purpose. `InFlightPageTransfer` gained
      `lastByteDate` (stamped in `recordPageTransferBytes`, the same path that grows
      `creditedSubunits`), `isAbandoned`, and `attempt` — the attempt's own `Task`, which
      `rawPageDownloadResponse` now creates, attaches, and awaits under
      `withTaskCancellationHandler` so the caller's cancellation still reaches the transfer. One
      idle definition, `idleInterval(at:)` = since the last byte, else since the attempt's start.
      The heartbeat's existing `sweepStarvedPageTransfers` applies both thresholds to it: >= 60 s
      abandons (`abandonPageTransfer`: sets `isAbandoned`, logs `outcome: abandoned` through the ONE
      existing masked helper, cancels the attempt); otherwise >= 10 s logs `still transferring` once
      as before. No second timer.

      HOW THE RETRY HAPPENS (a SUGGESTED item the planner decided differently from the spec's
      `retryLimit = 3` wording): page transfers deliberately bypass `withRetry`/`retryLimit`
      (`retriesRequest: false`), so an abandoned attempt surfaces out of `rawPageDownloadResponse`
      as the retryable `AppError.networkingFailed` — decided by `pageTransferCancellationError`,
      which checks `Task.isCancelled` FIRST (a pause or expiry sweep still throws
      `CancellationError`) and only then the entry's `isAbandoned` — and `downloadPage`'s existing
      attempts loop (`autoRetryFailedPages ? 2 : 1`, failover re-resolution to a fresh URL / host)
      is the retry. Consequence, stated plainly: with auto-retry ON (default) a persistently
      starved page fails after ~120–140 s (two attempts) and the queue moves; with auto-retry OFF it
      fails after one attempt (~60–70 s), as every other transport failure does under that setting.
      A system-deferred transfer that goes 60 s without bytes is treated the same (inside the
      owner's binding 60 s). `withRetry`, `retryLimit`, `AppError`, `endPageTransfer`'s exit check
      untouched.

    HALF 2 — MECHANISM (d6079878)
      `ContinuedProgressNudge` (BackgroundProcessingClient, internal): `cap = 30` (BINDING),
      `headroom = cap + 1 = 31` sub-units held back below the scaled total; `record(measured,
      nudgesWhenStalled:)` — an unchanged clamped measurement adds ONE sub-unit (1/1000 page) up to
      the cap; ANY change, either direction, snaps back and clears. It lives in
      `ContinuedProcessingSession` (the store owning the system `Progress`), replacing
      `foldedCompletedUnitCount` with `measuredSubunitCount` = `max(0, min(completed*1000 +
      inFlight, total*1000 - 31))`; `task.progress.completedUnitCount = nudge.reportedSubunits`;
      `adopt` publishes the same expression. The seam's fourth slot became
      `ContinuedSubunitReport { inFlightSubunitCount, nudgesWhenStalled }` (arity stays 5). Only
      `beatContinuedSession` passes `nudgesWhenStalled: true` — UNCONDITIONALLY, no second "is there
      work" condition (BINDING c; the existing `hasPendingWork()` guard is the one gate) — so the cap
      keeps its heartbeat meaning while every push still snaps back on a real change. Denominator
      unchanged (`pages × 1000`). Logged distinctly by the store: `Continued-processing progress
      stalled, nudge N of 30 above M of T subunits.` (integers only, all `.public`).

      THE CAP RE-DERIVED AGAINST A 509 BACK-OFF (as the spec required): this app makes no in-run
      quota back-off wait — a 509 arrives as a placeholder image, becomes the fatal
      `AppError.quotaExceeded`, and the run fails, so the queue moves or drains. The longest
      legitimate flat stretch is a page starving through its attempts under Half 1 (~140 s); 30
      nudges at 10 s ≈ 300 s is more than double that. Past the cap the count goes flat ON PURPOSE:
      the system reclaims the session and the expiry arm pauses schedulable downloads — a wedged
      queue cannot hold a session forever. Written into `ContinuedProgressNudge`'s doc.

    TESTS (all Swift Testing)
      Half 1, in `DownloadPageTransferProgressTests`, driving the REAL `rawPageDownloadResponse`
      against a hanging injected downloader over the file's frozen clock: abandon at 60 s (59 s
      negative control), the slow-but-moving control (bytes at t=50 and t=100 → sweeps at 70/110
      do not abandon, 161 does), per-attempt idle measurement with credit kept across the re-open,
      caller cancellation stays `CancellationError`, the 10 s sweep leaves the transfer running.
      Half 2: `ContinuedProgressNudgeTests` (one nudge per stalled report; snap back both
      directions; cap holds at 30 over 40 reports; a non-liveness identical report neither nudges
      nor dips); `ContinuedProcessingSessionFoldTests` on the REAL `task.progress.completedUnitCount`
      (a stalled heartbeat report with ZERO in-flight sub-units still nudges — the frame the
      rejected condition would have dropped; never reaches the scaled total; an honest moving series
      is bit-identical to before); the heartbeat pin that every beat carries `nudgesWhenStalled ==
      true` with zero in-flight sub-units. Existing suites, subtitle pins, source-inventory and
      log-privacy censuses unchanged.

    WHAT THE NEXT ROUND MUST OBSERVE
      On a build carrying both commits, the SC2 procedure BACKGROUNDED (round 7's run stayed in the
      foreground): a stalled stretch shows `Continued-processing progress stalled, nudge N of 30`
      lines and, if a transfer starves, `Page transfer starved ... abandoned` at ~60 s followed by
      the page's retry; the numerator moves again; no `Continued-processing session expired` while
      the queue has work on healthy Wi-Fi.

- gap_id: G-15-11
  truth: "When both stored spellings exist, launch merges them into one `Logs` directory and removes the source spelling — including when a filename collides, where the destination copy is the one kept."
  status: closed_by_removal
  closure: |
    TWO corrections, in order.

    1. NOT A DEFECT. Tracing `LogsDirectoryMigration.run` against the observed fixture showed the
       behaviour was deliberate, documented and test-pinned. On a name collision `mergeDecision`
       skips the file, the pre-removal re-listing therefore finds the source non-empty, and the
       guard at `mergeContents` returns `.merged(movedCount: 0, skippedCount: 1)` WITHOUT removing
       the directory — because the type's invariant is that no FILE is ever deleted and only an
       emptied directory is removed. `LogsDirectoryMigrationTests.swift:348-366` pins exactly this,
       including that a second run changes nothing further. The device observation reproduced the
       specification. The real conflict was between that invariant and this test's expectation
       ("merged into one, no file lost"), which cannot both hold when a name collides.
    2. MOOT. The owner then removed the migration entirely, so neither side of that conflict has a
       subject any more.
  removal_decision: |
    OWNER DECISION 2026-08-17: delete `LogsDirectoryMigration` outright rather than keep or fix it.
    Removed: `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift`,
    `AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift`, and the launch effect in
    `AppDelegateReducer.swift`. `Defaults.FilePath.logs` stays `"Logs"`.
  correction_on_record: |
    The decision was first given on the premise that the rename happened within an unreleased line,
    so no install in the field could hold a lowercase `logs`. That premise is FALSE and the owner
    reaffirmed the decision after being shown it, which is why the fact is recorded here rather
    than left implicit:
      - `v2.8.1` is a released tag and ships `Defaults.swift:62: static let logs = "logs"`
      - `v2.8.1:FileUtil.swift:16` builds the logs directory URL from that constant
      - field-shaped evidence on the test device: `EhPanda.log` / `EhPanda.1.log` (the v2-era
        `ehpandaLog = "EhPanda.log"` naming), dated 2026-06-21/22
    So an install upgrading from v2.8.1 DOES keep a lowercase `logs` directory beside `Logs` on the
    case-sensitive device volume. Accepted consequence, not an oversight: nothing is lost (the two
    eras use different file names, `EhPanda.log` versus `ehpanda-*.jsonl`, so they cannot even
    collide), the stale directory is inert, and it is the same coexistence the owner judged
    uninteresting. The rationale is mirrored in a comment on `Defaults.FilePath.logs` so it is
    visible at the constant rather than only in planning docs.
  resolved_at: 2026-08-17
  superseded_status: failed
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

- gap_id: G-15-2E
  truth: "A single continued-processing expiration is handled once: one pause sweep, one log line."
  status: closed
  correction_2026_08_17: |
    MY ORIGINAL FRAMING WAS WRONG. I filed this as duplicate `.expired` EVENT delivery or multiple
    live stream consumers. It is neither. The expiration handler ran ONCE, the pause sweep ran ONCE,
    `endSession`'s at-most-once contract held, and the AsyncStream had one consumer. What duplicated
    was the WRITING of the same OSLog entries into the jsonl file, which is why every duplicate
    carries a byte-identical timestamp — a real clock would have moved. The same artifact duplicates
    the app-lifecycle lines ("App entered foreground" x3 at 2564.5), which is what should have told
    me the cause was not expiry-specific.
  actual_mechanism: |
    Verified by reading `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsPumpReducer.swift`:
      - `:46` `.startPump` and `:97` `.pausePump` each SNAPSHOT `state.lastCursorDate` when the
        effect starts.
      - `:79` / `:107` `await send(.didReceiveNewEntries(...))` is the only thing that advances the
        cursor (`:124`).
      - `:81` / `:109` `appendToRunFile` writes to disk AFTER that send, and is NOT guarded by
        `Task.isCancelled`.
      - `:93` the pump is `.cancellable(id: CancelID.pump, cancelInFlight: true)`.
    TCA's `Send.callAsFunction` is a no-op once the task is cancelled, so a cancelled effect writes
    its batch to disk while the cursor never advances. The next effect re-fetches from the same
    stale cursor and writes the same entries again.
    `AppReducer.swift` starts the pump on EVERY `.active` (`:105`, plus launch `:169`) and pauses it
    on `.background` (`:135`), so a burst of lifecycle flips spawns overlapping effects. At
    2564.5 / 2567.0 / 2567.3 — three flips in 2.8s right after the 19-minute suspension — three
    effects all held the pre-suspension cursor. Expiry 1 was followed by a single clean foreground
    22s clear of the next flip, hence once-then-thrice.
  independent_corroboration: |
    Same race visible in Run 4 (`ehpanda-20260815-205412-4.jsonl`): "App activity logging started"
    appears twice with DIFFERENT timestamps (0.041 / 0.055) — two startPump effects (launch and
    `.active`) both taking the no-current-run branch.
  still_a_real_bug: |
    Reclassified, not dismissed. Duplicate entries are written to the run file AND to
    `currentRunLogs`, so the in-app Logs screen shows them too, and any future device-log forensics
    over these files inherits the artifact. Fix direction: make fetch + append + cursor-advance one
    atomic step under a single owner (an actor in `LogsClient` holding the cursor and serialising
    writes), or at minimum guard the append on `Task.isCancelled` and advance the cursor in the
    effect that actually wrote; and stop restarting the pump on every `.active` bounce.
  fix_2026_08_18: |
    CLOSED by quick task 260818-ek3, commit e68ca491 on `feature/gsd-phase-15`.

    THE CURSOR NOW BELONGS TO THE WRITE. `RunLogDrain` (new, `AppPackage/Sources/LogsClient/`) is a
    `public actor` whose `drain(into:)` fetches, appends and advances the cursor with NO suspension
    point between them — an actor method with no `await` runs to completion before any other call
    can enter, so two overlapping callers cannot read one stale cursor and cannot write one batch
    twice. Its contract: nothing is returned that was not written, and nothing is written whose
    cursor did not advance. A failed append leaves the cursor where it was, so the same entries are
    re-offered on the next tick instead of being silently skipped; a failed fetch is a silent empty
    tick. Both stay silent for the reason the old append did: this pump reads back the app's own
    OSLog, so logging a persistence failure feeds itself.

    THE SPLIT ENDPOINTS ARE GONE. `LogsClient.fetchNewEntries` + `appendToRunFile` are replaced by
    one `drainNewEntries(url)`, whose live value forwards onto ONE process-wide `RunLogDrain`. A
    caller holding both halves could interleave them, which is exactly what happened.

    THE RUN IS DERIVED ONCE, BY CONSTRUCTION. `nextRunCount` became synchronous, so `.startPump`
    establishes the run inside the reduce step rather than through an async `send`; and a
    `.startPump` on an already-running pump is now a no-op (`isPumpRunning` replaces
    `cancelInFlight: true`). That is the Run 4 double-header's cause, closed structurally: the
    header is emitted only on the first start of the process.

    THE LIVE VIEW IS PUBLISHED WITHOUT `send`. The pump effect appends the drained batch to the
    shared `currentRunLogs` directly via `withLock`, because TCA's `Send` is a no-op after
    cancellation — so a cancelled tick can now neither lose nor duplicate a batch the file already
    holds.

    THE PUMP SURVIVES BACKGROUNDING UNDER A LIVE SESSION, which is what the
    `relevance_to_this_feature` note below asked for. `DownloadClient.observeContinuedSessionLiveness`
    (new `AsyncStream<Bool>`, yielded `true` when `continuedClientSessionID` lands and `false` in
    `markContinuedSessionEnded`) is consumed by `AppReducer` at launch; `.background` pauses the pump
    only when no session is live, and the live-to-ended transition while backgrounded pauses it then
    — a final drain before the process can be killed. `SettingFeature` still knows nothing about
    downloads.

    PINNED BY: `RunLogDrainTests` (overlapping drains append each entry once and the in-flight fetch
    depth never exceeds one; a failed append re-offers; a failed fetch moves nothing),
    `AppActivityLogsReducerTests.overlappingStartPauseStartAppendsEachEntryOnce` (RED against the old
    reducer) and `.startPumpTwiceDerivesTheRunOnce`,
    `AppReducerScenePhaseTests.backgroundKeepsThePumpAliveWhileASessionIsLive` and
    `.backgroundPausesThePumpWhenNoSessionIsLive`, and `DownloadContinuedSessionLivenessTests`.
  relevance_to_this_feature: |
    The pump is PAUSED while backgrounded, so lines emitted during background work (including an
    expiry and its pause sweep) live only in OSLog until the next `.active`. Had the app been killed
    after an expiry, that evidence would never have reached disk. Worth keeping the pump alive while
    a continued-processing session is live.
  severity: minor
  reason: |
    Found in device logs 2026-08-17 while diagnosing G-15-2D. At the second expiration of
    `ehpanda-20260815-194921-3.jsonl` the expiry handling ran three times at one identical timestamp
    (1368.2s): three "Continued-processing session expired, pausing schedulable downloads" lines and
    three pause sweeps over each of the two galleries. The first expiration in the same run logged
    exactly once, so this is not a constant multiplier and the once-then-thrice shape is unexplained.
  why_it_matters: |
    Pausing is presumably idempotent, so this is unlikely to corrupt state — hence minor. But it
    means an `.expired` event reached the consumer more than once, and duplicate delivery on that
    stream is the kind of thing that stops being harmless the moment a non-idempotent handler is
    added to it.
  investigation_hint: |
    `endSession` is `at most once` by construction and clears `task`/`continuation` first, so start
    downstream: how many consumers are live on the session's `AsyncStream`, and whether a session
    that expires while a previous consumer task is still finishing can leave a second one attached.
  test: 2

- gap_id: G-15-2H
  truth: "A .repair re-download restores a gallery in place; it does not silently rename the user-visible folder it lives in."
  status: resolved
  resolved_date: "2026-08-18"
  severity: confirmed-defect (fixed in 13cad7d9; verified on device 2026-08-18)
  found: "2026-08-18, round 6, incidental to test 2 clause 5"
  diagnosed: "2026-08-18, root cause confirmed in code"
  observed: |
    The gallery whose files were deleted outside the app and then repaired came back in a folder
    with a DIFFERENT name than the one the original download created.

      before repair   Documents/Downloads/Default/[4108805_3186cf251f] Onna no Battle Woman's Battle
      after repair    Documents/Downloads/Default/[4108805_3186cf251f] Onna no Battle

    Corroborated three ways: the Files.app listing showed the long name (dated 2026/08/10, 29 items)
    before and the short name (12:47) after; a `devicectl` listing of the OLD path failed with "the
    system failed to get a list of files" once the repair had run, while the NEW path listed 28
    images plus manifest.json; and only one folder for that gid exists now, so this is a rename, not
    a second folder left beside the first.

    The gallery's stored title is
      "[Heian Xiaocangku (Shiben c16e4)] Onna no Battle   Woman's Battle (Honkai_ Star Rail) [Chinese] [蒙面好汉化]"
    — note the RUN OF SPACES between "Battle" and "Woman's", where the site's own title almost
    certainly carries a `|`. DIAGNOSED 2026-08-18; see root_cause below.
  root_cause: |
    CONFIRMED IN CODE. The destination folder path is RECOMPUTED FROM THE FRESHLY FETCHED PAYLOAD ON
    EVERY RUN, and is never resolved from the folder the gallery already occupies.

      1. `DownloadClient+Execution.swift:158` — `processDownload` fetches a fresh payload and then
         calls `folderRelativePath(for: payload, parentFolderName: download.folderName)`. This runs
         for EVERY mode, repair included. Nothing consults the existing folder, even though
         `DownloadStore.galleryFolderURLs(gid:token:)` exists precisely to find it and is documented
         as finding "a folder the user moved in the Files app".
      2. `DownloadClient+ExecutionSupport.swift:41-45` — the name's title is
         `payload.galleryDetail.trimmedTitle`, falling back to `payload.gallery.title` when empty.
      3. `GalleryDetail.swift:84` / `Gallery.swift:72` — `trimmedTitle` TRUNCATES AT THE FIRST `|`
         and then strips bracket/paren groups. So a title whose pipe is present yields
         "Onna no Battle", and one whose pipe is absent yields "Onna no Battle Woman's Battle".
         The manifest's stored `title` for this gallery contains NO pipe (verified by reading the
         file off the device), which is why the record cannot reproduce the on-disk name: the value
         the name derives from is never persisted.
      4. Because the recomputed path did not exist, `shouldReuseWorkingFolder`
         (`+ExecutionSupport.swift:669-671`) hit its `fileExists` guard and returned false BEFORE
         reaching its `case .repair: return true`. That is why `setupWorkingFolder` then tried to
         remove a folder that was not there and logged
         "Stale working folder removal failed ... Code=4" — that line is NOT unrelated noise, it is
         this bug's fingerprint, and it answers the possibly_related question this entry opened.
      5. `repairSeed` + `DownloadStore+Operations.swift:121 materializeRepairSeed` then carried the
         gallery to the new path, and `removeSupersededFolders` (`+Execution.swift:87`) deleted the
         old one from the completion handler. Net effect: a rename.

    So the rename is not stray machinery misfiring — steps 4 and 5 are behaving as designed. The
    defect is upstream of them, at step 1: a stable, already-existing folder is re-addressed by a
    name recomputed from live network data.
  owner_decision_2026_08_18: |
    NEVER RENAME. An upstream title change must not rename a gallery folder that already exists on
    disk. Decided by the owner on 2026-08-18, in answer to the question this entry raised. The fix
    is no longer gated; the spec below is the one to implement.
  fix_spec: |
    GOAL: the LEAF component of a gallery's folder — the `[gid_token] Title` part — is chosen ONCE,
    when the folder is first created, and never recomputed afterwards.

    WHAT CHANGES
      `folderRelativePath(for:parentFolderName:)` in
      `DownloadClient+ExecutionSupport.swift:35-47` currently always builds the leaf from
      `storage.makeFolderRelativePath(gid:token:title:)`. It must instead:
        - reuse the EXISTING folder's `lastPathComponent` when the gallery already has a folder
          (resolve via `download.folderURL` / `storage.galleryFolderURLs(gid:token:)`), and
        - derive a fresh leaf from the payload ONLY when no folder exists yet.
      Centralize it there rather than at the call sites, so both callers are covered:
        - `DownloadClient+Execution.swift:158`  (processDownload — every mode, incl. repair)
        - `DownloadClient+PublicAPI.swift:99`   (enqueue; its own comment notes this route
                                                 "explicitly supports an already-known gallery",
                                                 so it can meet an existing folder too)

    KEEP WORKING — do not over-apply the rule
      Only the LEAF is frozen. The PARENT component must keep its current behaviour, because moving
      a gallery to a different download folder in-app is a deliberate user action and still has to
      relocate it. `folderRelativePath` already returns "\(parentFolderName)/\(galleryFolderName)";
      the fix replaces only the second half.

    FALLS OUT FOR FREE
      The spurious "Stale working folder removal failed ... Code=4" disappears: it only fired because
      the recomputed path did not exist, which tripped `shouldReuseWorkingFolder`'s `fileExists`
      guard before its `case .repair: return true`. Do not "fix" that log line separately.

    NO MIGRATION
      Galleries already renamed by this bug stay where they are; the record and disk agree, and
      `galleryFolderURLs` matches on manifest gid/token regardless of the readable half. The fix
      only stops FUTURE renames. Do not write a migration.

    TESTS TO ADD
      1. Same gid/token, two runs whose payload titles differ in a way that changes the derived name
         (e.g. one title containing `|` and one not, since `trimmedTitle` truncates at the first
         pipe) — assert the on-disk folder name is IDENTICAL after both runs, and that no second
         folder was created.
      2. A repair run over an existing folder — assert the folder is reused in place and
         `materializeRepairSeed` / `removeSupersededFolders` are not exercised to relocate it.
      3. A deliberate parent-folder change — assert the gallery DOES move, i.e. the leaf is stable
         but the parent is not frozen.
      Note the project's `Feature` reducer-naming convention and the SwiftLint rules in the root
      `.swiftlint.yml` before writing code.
  fix_landed_2026_08_18: |
    Landed in commit 13cad7d9 on
    feature/gsd-phase-15 (quick task 260818-mjs), implementing the locked fix_spec above verbatim.

    MECHANISM
      The freeze lives inside `folderRelativePath(for:parentFolderName:)` and nowhere else, so both
      callers are covered by construction: when the gallery already has an INDEX record the leaf is
      that record's `folderURL.lastPathComponent`, and a fresh `trimmedTitle` leaf is derived only
      when it has none. The index rather than a disk walk, because the index is this actor's
      documented read authority between sync points and both callers already run against a loaded
      one; `galleryFolderURLs` stays the reconcile-time tool. A consequence stated on the
      declaration: a folder the user renamed in Files.app keeps the user's name, since the leaf is
      whatever the record says it is.

      The PARENT is untouched, so an in-app move still relocates the gallery. `moveDownload` is
      cited on the declaration as the sibling idiom that already keeps the leaf verbatim.

      No migration was written, and the "Stale working folder removal failed ... Code=4" line was
      not touched — it falls out, as the spec says.

    DOCS CORRECTED
      `removeSupersededFolders`' comment (a completed run's folder no longer differs through a title
      change; the sweep now stands for pre-fix history and for a differing-PARENT destination) and
      `DownloadManifest`'s header (the readable half is chosen once at creation and a later upstream
      title change does not rename the directory).

    TESTS
      New suite `DownloadFolderLeafFreezeTests` with the spec's three plus a regression pin:
        - testTwoRunsWithDifferingTitlesKeepOneFolderUnderTheFirstLeaf
        - testARepairOverAnExistingFolderReusesItInPlace
        - testTheLeafIsFrozenButTheParentIsNot
        - testAGalleryWithNoRecordStillDerivesAFreshLeaf
      Three of the four were observed RED pre-fix (5 issues); the fourth pins the unchanged branch
      and passed pre-fix, as intended. The three existing suites that used to stage a differing
      destination through a TITLE change were restaged through a PARENT change and now also assert
      the leaf is equal — `DownloadCoordinatorRepairSeedTests` and both cases in
      `DownloadRepairSeedSignalPropagationTests`.

      One pre-existing pin encoded the rename as expected behaviour and was restaged:
      `DownloadProcessTests.verifyCompletedProcess` asserted the staged folder was DELETED after a
      full `processDownload`. It now asserts the run finished IN that folder and that exactly one
      folder exists for the gid — the whole-arc version of the unit pins above.

    FOLLOW-UP QUESTION FOR THE OWNER (not acted on)
      AS FILED, AND CORRECTED BELOW: "post-fix, `repairSeed` / `materializeRepairSeed` /
      `RepairSeedContext` are unreachable from `processDownload`: the destination now equals the
      record's folder, so `shouldReuseWorkingFolder`'s existence guard and `repairSeed`'s existence
      guard cannot both fail. WR-02 / G-15-13 / G-15-19 pins still own that branch's contract, and
      the locked spec did not ask for removal, so nothing was deleted. Retire the seed
      materialization in a design round?"

    CORRECTION 2026-08-18 — THE UNREACHABILITY CLAIM IS NOT AN INVARIANT
      Investigated in a design round on 2026-08-18. Verdict: TRUE-WITH-EXCEPTIONS, not true. The
      geometry above holds only under an assumption it does not state — that `downloadIndex[gid]` at
      the moment `folderRelativePath` is evaluated still names the folder the run captured at its
      start. Two interleavings break it and re-open the seed branch.

      What DOES hold, unconditionally:
        - `.initial` / `.redownload` / `.update` can never reach the machinery in any folder state,
          because `repairSeed`'s first guard is `payload.mode == .repair`
          (`DownloadClient+ExecutionSupport.swift:856`).
        - The `enqueue` route never touches it: `folderRelativePath` -> `writeInitialManifest`, with
          no `prepareWorkingSeed` in between.
        - For a steady-state `.repair`, destination == the record's own path, so the two existence
          guards probe one path and cannot disagree; and there is no suspension between the
          derivation and the guards, so they read one consistent moment.

      The two windows that DO reach it — both are index divergence DURING a run:
        E1  `download` is captured at `DownloadClient+Execution.swift:36` but `folderRelativePath`
            is evaluated at `:170`, after real suspensions (`downloadOptionsProvider()`,
            `notifyObservers()`, the network `fetchLatestPayload`). `syncDownloadsState` has no
            active-run gate, and its `reloadDownloadIndex` failure path sets `downloadIndex = [:]`
            while every folder is still on disk. The derivation then takes the deliberately-kept
            fresh-leaf branch and re-derives from `trimmedTitle` — the exact pipe/title-drift hazard
            G-15-2H froze out. Destination (new leaf) is absent, the captured folder (old leaf) is
            present with a matching manifest, every `repairSeed` guard passes: the pre-fix rename arc
            runs, through a transient scan failure.
        E2  Same shape across parents: duplicate folders for one gid in different parents (a
            Files.app copy) let a mid-run reload re-point the index from the captured A/L1 to B/L2,
            so the destination becomes A + L2, which exists nowhere, while A/L1 still stands.
            `moveDownload` CANNOT cause this — it refuses while the gid is active
            (`DownloadClient+Folders.swift:266-276`) — so only externally-created duplicates plus a
            mid-run reload produce it.

      Cases checked and found NOT to reach it: a gallery with no index record (`processDownload`
      returns at `Execution.swift:36-38` before anything); a completed `moveDownload` parent change;
      a folder renamed or deleted in Files.app with a stale index (both guards probe the same stale
      path and fail together); pre-fix legacy duplicates on their next repair.

      Consequently the pins are NOT pinning dead code. WR-02 / G-15-13 / G-15-19 pin the
      differing-destination-over-standing-source shape, which is exactly what E1/E2 produce, and
      13cad7d9 already restaged those suites to reach it through the production `folderRelativePath`.

      RECOMMENDATION: KEEP, WITH A CHANGED CONTRACT — the change documentary, not behavioural.
      Demote the branch from "the expected title-re-slot path" (its pre-fix role) to "the salvage net
      for a run whose destination was re-addressed away from a still-standing source", and name the
      residual reachability on `setupWorkingFolder` / `repairSeed`. Retirement is not
      behaviour-neutral even on the original analysis: with the seed gone the run falls to
      `createDirectory`, `ensureWorkingManifest` writes a fresh all-empty manifest at the empty
      destination and re-indexes it (republishing the record at 0-of-N with a full D-G7-01
      withdrawal), and the completion sweep then deletes the old folder with all its files.

      Deletion inventory, if the owner overrides: `RepairSeedContext`
      (`+ExecutionSupport.swift:739-742`), `setupWorkingFolder`'s seed branch (:766-776) and its
      `carriedUnprobedPages` channel (:428-433, union :461-466), `repairSeed` (:843-870),
      `RepairSeed` (`+Manager.swift:179-190`), `materializeRepairSeed`
      (`DownloadStore+Operations.swift:90-200`) and the then-stranded `linkOrCopyReadableAsset`
      (:55); tests: all three `DownloadStoreRepairTests` cases, `DownloadCoordinatorRepairSeedTests`
      :10 and :259, both `DownloadRepairSeedSignalPropagationTests` cases, and a census restage in
      `DownloadSourceInventoryTests.swift:443-449` (2 -> 1).

    WHAT THE NEXT DEVICE RUN MUST SHOW
      Repair a gallery whose stored title differs from the site's (the pipe case is the reported
      one): the folder name in Files is UNCHANGED afterwards, exactly one folder exists for that gid,
      and the jsonl carries no "Stale working folder removal failed ... Code=4" line.
  device_verified_2026_08_18: |
    VERIFIED ON DEVICE. Physical iPhone 11, iOS 26.6, build of 3433cbeb (13cad7d9 in tree),
    installed fresh over the existing container so every download folder was preserved.

    FIXTURE — the discriminating case the fix_spec asked for, staged rather than waited for.
    No gallery on the device still carried a recorded-vs-derived leaf mismatch (the reported one,
    gid 4108805, had already converged when the pre-fix run renamed it), so the mismatch was
    created the way a real user creates it: the folder for gid 4127415 was RENAMED IN FILES.APP
    from "[4127415_3869b04dde] canaria" to "[4127415_3869b04dde] canaria RENAMED", keeping the
    identity prefix. That is the case the fix's own declaration calls out as a wanted consequence.
    EhPanda was relaunched and resolved the renamed folder by manifest identity, its row reading
    20/26 — the six pages left pending by the G-15-2G partial-deletion check.

    ACTION: "Resume" on that row, i.e. the full `processDownload` arc for an incomplete gallery.

    RESULT — all three assertions hold.
      1. FOLDER NAME UNCHANGED. Before and after the run the `devicectl` listing reads
         "[4127415_3869b04dde] canaria RENAMED". The user's name survived the repair.
      2. EXACTLY ONE FOLDER FOR THE GID. Eleven gallery folders before, eleven after; no second
         folder under a derived leaf, and no deletion of the renamed one.
      3. NO Code=4 LINE. The run's jsonl (ehpanda-20260818-205106-10.jsonl) carries
         ZERO "Stale working folder removal failed" occurrences. Pre-fix this exact shape produced
         one; it is the bug's fingerprint and it is gone.
      Plus the work actually happened IN PLACE: pages 1-6 landed into the renamed folder (26 images
      + cover + manifest.json = 28 entries), the log reads "Download completed ... pages: 26" and
      "Continued-processing session drained, terminal progress pushed", and the row settled at 26/26.

    DISCRIMINATING POWER: under the pre-fix code the derived leaf would have been "canaria", which
    does not exist, so `shouldReuseWorkingFolder`'s `fileExists` guard would have failed exactly as
    diagnosed and the run would have re-slotted the gallery to "[4127415_3869b04dde] canaria",
    clobbering the rename. The observed run did none of that.

    CLEANUP: the folder was renamed back to "[4127415_3869b04dde] canaria" afterwards, which the
    same frozen-leaf path honoured; the library is back to its pre-test names.
  resolution_2026_08_19: |
    OWNER DECISION — guard ONE invariant end to end: the download client never deletes a gallery
    folder it did not itself create in the same run. The completion sweep (`removeSupersededFolders`,
    the one production violator) and the repair-seed materialization are RETIRED per the deletion
    inventory above, whose line numbers were re-verified against the tree; this supersedes the
    CORRECTION's KEEP-WITH-A-CHANGED-CONTRACT recommendation. No rename resolution was added:
    `folderRelativePath`, `shouldReuseWorkingFolder` and `delete(gid:)` are unchanged in behaviour,
    `removeGalleryFolders` keeps its breadth but loses its keep-one parameter (no production caller
    remained), and no migration was written.

    WHY — the iPad-multitasking shape reported on 2026-08-19: a Files.app rename plus a stale index
    plus Repair/Resume recreated the folder at the OLD name, refetched everything, and the sweep then
    deleted the user's renamed folder. ACCEPTED CONSEQUENCE: that shape now leaves TWO folders (the
    user's, untouched, beside the app's fresh one) and `deduplicatedDownloadIndex` picks the newest
    by modification date. The user removes the spare through the app when they want it gone.

    The "Stale working folder removal failed ... Code=4" line remains a legitimate fingerprint of a
    stale-index destination and was not touched.

    PINNED BY — `DownloadProcessTests.testAFullRunLeavesAnotherFolderOfTheSameGalleryUntouched`: a
    full `processDownload` over a gid with a SECOND, manifest-only-matching folder in another user
    folder completes in the record's folder and leaves the other one with identical entries and an
    identical manifest, `galleryFolderURLs` still returning both. The interrupted-resume sweep pin
    was restaged onto `removeGalleryFolders` (removes every folder of the gallery, and no other), and
    the discarding-rejected census fell 2 -> 1. Commits f7e65497 (fix) and b0d2d57e (pin).
  resolved_question_stale_working_folder: |
    The "Stale working folder removal failed ... Code=4" line logged by the same repair is EXPLAINED,
    not unrelated: the recomputed path did not exist, so `shouldReuseWorkingFolder`'s `fileExists`
    guard short-circuited to false and `setupWorkingFolder` tried to remove a folder that was never
    there. It disappears on its own once the destination stops being recomputed.
  why_it_matters: |
    The downloads directory is user-visible and user-manageable through Files — that is the whole
    subject of tests 9 and 15. A repair quietly renaming a user's folder moves their data out from
    under any bookmark, shortcut, or external tool pointing at it, and it makes two galleries that
    were downloaded the same way disagree about how they are named on disk.
  note: |
    Not a test 2 clause failure. Clause 5 asks whether the repair's progress climbs from the
    announce, and it did; the files all landed and the record ended truthful. This is a separate
    on-disk naming question that surfaced while exercising that clause.

- gap_id: G-15-2F
  truth: "The in-app Download Status sheet describes the work a repair is actually doing."
  status: resolved
  resolved_date: "2026-08-18"
  severity: minor (fixed in 764c5958; verified on device 2026-08-18)
  found: "2026-08-18, round 6, incidental to test 2 clause 5"
  observed: |
    With a completed 27-page gallery whose image files had been deleted outside the app (manifest
    left in place, so the record still claimed 27/27), "Retry Pages" started a real re-download of
    all 27 pages — the session heartbeats climbed 3/27 -> 25/27 and every file landed on disk.
    Throughout that re-download the in-app Download Status sheet read:
        Downloading 27/27
        Downloaded (27)  1-27
        Pending (0)      No Pages
        Failed (0)       No Pages
    i.e. it showed the work as already finished while it was in fact being redone from zero. The
    system card's basis was correct at the same moment, so this is the in-app sheet's derivation,
    not the run progress basis that 15-54/15-72 rebuilt.
  root_cause: |
    TWO compounding parts, both in the in-app display path.

      1. WRONG BASIS. The badge's numerator and `buildInspectionPages` both derived from the RECORD
         (D-SSOT-07), and for the wholesale-refusal family the record reads N-of-N for the ENTIRE
         repair BY DESIGN: the irreversibility guard refuses to blank a manifest's whole claim on
         one scan, so nothing lowers it while the re-download runs. The run's own measurement
         (`runProgressBases[gid]`, the round-18 redesign) existed and was correct — it is what the
         system card sums — but it reached only that card. The sheet had no access to it.
      2. NO RELOAD EVEN IF IT HAD. The re-download re-records hashes that are byte-identical to the
         ones already in the manifest, so every published `DownloadedGallery` was `==` its
         predecessor and `DownloadInspectorReducer.observeDownloadsDone`'s equality gate returned
         `.none` at every flush. Even a corrected derivation would have been recomputed only when
         something else happened to differ.
  fix_landed_2026_08_18: |
    Landed in commit 764c5958 on feature/gsd-phase-15 (quick task 260818-mjs).

    MECHANISM (D-SSOT-10)
      `DownloadedGallery.runProgress` — a new `DownloadRunProgress` carrying the run's credited page
      SET — rides on the published row while that run's measurement stands, and is nil otherwise. It
      is populated from the single accessor `liveRunProgressBasis(gid:)`, which is also what the
      credited-pages definition's basis-first regime reads, so the card's fraction and the sheet
      cannot describe different work.

      While it stands, the badge numerator is that set's SIZE and `buildInspectionPages` reads its
      MEMBERSHIP — `.downloaded` iff credited, else `.failed` iff a page failure is recorded, else
      `.pending`. Header and page groups therefore come from ONE value and cannot disagree. Out of a
      run both read the record exactly as before.

      Record-completeness is untouched: `completedPageCount`, `isIncomplete`, `canValidateImageData`,
      `retryablePageIndices`, `displayStatus`, resume-mode resolution and scheduling all still derive
      from the manifest. The overlay writes nothing, consults no disk, never outranks queue
      membership, and is retired with the run — AGENTS.md's operation-level clause is what licenses
      it, and the model's doc carries that argument.

      Publish points: at the ANNOUNCE (so the sheet flips to the run's reading immediately rather
      than at the first flush), at EVERY manifest page flush (the row now differs each time, so part
      2 of the root cause is closed by the row genuinely changing rather than by weakening the gate),
      and at EVERY run exit — including an exit that no longer owns the active slot, which
      `finishActiveTaskIfOwned` does not publish from.

      The measurement's whole-name census stays at SEVEN: `+ContinuedSession.swift` moves 3 -> 2 and
      the new `+RunProgress.swift` accessor takes the freed slot.

    ONE SITE OUTSIDE THE PLANNED SCOPE
      `DetailReducer.downloadNeedsRepair` used to read the incompleteness conjunct off
      `badge.progress`, which is now a DISPLAY quantity. It reads the record's own `isIncomplete`
      instead (carried on Detail's state beside the failure code it is always read with), so the
      predicate is independent of the display basis by construction rather than by a coexistence
      argument.

    TESTS
      - `DownloadRunProgressOverlayTests` (4 cases): the refusal repair reading the run at announce /
        flush / exit; the honest family reading identically under both bases; a failed outstanding
        page reading `.failed` and credit beating a stale failure entry; and a non-owning run exit
        still publishing the record's reading.
      - `DownloadInspectorRunProgressReloadTests` (2 cases): a row differing ONLY in `runProgress`
        re-sends `.loadInspection`, with an exhaustive control that an identical row still reloads
        nothing.
      Sensitivity banked: with the non-owning exit publication removed, exactly one case fails
      (`testANonOwningRunExitStillPublishesTheRecordRead`, timing out on the awaited publication) and
      nothing else moves.

    WHAT THE NEXT DEVICE RUN MUST SHOW
      The same wholesale-refusal repair with the Download Status sheet OPEN: it reads
      "Downloading 0/27 · Pending (27)" at the announce, the numerator and the Downloaded group climb
      together with the system card, and the record's own reading (27/27) is restored the moment the
      run ends.
  device_verified_2026_08_18: |
    VERIFIED ON DEVICE. Same iPhone 11 / iOS 26.6 / build of 3433cbeb (764c5958 in tree).

    FIXTURE — a true wholesale-refusal state, rebuilt deliberately: the folder for gid 4108805
    ("Onna no Battle", 27 pages, complete) was deleted in Files.app and ONLY its manifest.json was
    restored, so the record claimed 27 of 27 non-blank hashes with ZERO image files on disk. After
    relaunch the row read 27/27 and its context menu offered no resume action at all — the record
    calls the gallery complete — which is precisely why the sheet's reading is the only surface a
    user has here.

    SEQUENCE, sheet open throughout.
      Before          Downloaded 27/27 | Downloaded (27) 1-27 | Pending (0) | Failed (0)
      Validate        "Needs Attention 27/27", groups UNCHANGED — the all-or-nothing guard refusing
                      to blank an entire claim on one scan, as G-15-2G established
      Retry Pages     Downloading  0/27 | Downloaded (0)  No Pages | Pending (27) 1-27   <= ANNOUNCE
                      Downloading  1/27 | Downloaded (1)  1       | Pending (26) 2-27
                      Downloading  4/27 | Downloaded (4)  1-4     | Pending (23) 5-27
                      Downloading  7/27 | Downloaded (7)  1-7     | Pending (20) 8-27
                      Downloading  9/27 | Downloaded (9)  1-9     | Pending (18) 10-27
                      Downloading 21/27 | Downloaded (21) 1-21    | Pending (6) 22-27
      At exit         Downloaded 27/27 | Downloaded (27) 1-27 | Pending (0) | Failed (0), stable
                      across six consecutive samples

    THE DECISIVE FRAME: at "Downloading 21/27" the manifest was pulled off the device and read
    27 of 27 NON-BLANK hashes. So at that instant the RECORD said 27/27 while the SHEET said 21/27
    and named pages 22-27 pending — the sheet was reading the run, not the record, and the two
    differed by six pages. Pre-fix the sheet read "Downloaded (27) / Pending (0)" for the whole
    re-download; there is no way to produce the observed frame from the record.

    CLIMBING IN STEP WITH THE CARD: the same run's continued-session heartbeats read
    3 / 10 / 14 / 20 / 23 of 27, interleaving with the sheet's samples on the same monotone climb —
    one measurement feeding both surfaces, which is the D-SSOT-10 claim.

    RECORD READ RESTORED AT EXIT: the header returns to "Downloaded 27/27" — the record-derived
    display status, not the run's "Downloading" — and holds there, so the overlay was retired at the
    run's exit rather than left standing. The log confirms the clean exit
    ("Download completed ... pages: 27", "Continued-processing session drained, terminal progress
    pushed") and carries no "Stale working folder removal failed" line either.

    COMPLETENESS QUANTITIES UNCHANGED: 27 images + cover + manifest back on disk, one folder for the
    gid, eleven gallery folders total — the fix moved what is DISPLAYED and nothing the record owns.
  why_it_matters: |
    The sheet is the surface a user consults to find out what a repair is doing. Reporting
    "Downloaded (27) / Pending (0)" during a 27-page refetch tells them the opposite of the truth,
    and it is the same stale-record read that clause 5 exists to forbid on the system card.
  note: |
    Not a test 2 clause failure — test 2 judges the system-owned card, and that card was correct.
    Filed separately so it is not lost inside a passing checkpoint.

- gap_id: G-15-2G
  truth: "A validation that observes a page's file is gone reconciles the manifest durably, so the persisted record alone reads truthfully."
  status: closed-no-defect
  severity: none
  resolution_2026_08_18: |
    SETTLED ON DEVICE by the partial-deletion check this entry called for. The wholesale guard is
    working as designed; there is no SSOT violation.

    Subject: a freshly downloaded 26-page gallery, manifest carrying 26 of 26 non-blank hashes and
    27 image files on disk. Exactly SIX page files (pages 1-6) were deleted from outside the app
    through Files.app — a partial deletion, not a wholesale one — leaving 21 files and the manifest
    still claiming all 26 complete.

    Before validation the Download Status sheet read the stale claim: 26/26, Downloaded (26),
    Pending (0), Failed (0). After "Validate Image Data" it read 20/26, Downloaded (20),
    Pending (6), Failed (0).

    The manifest pulled off the device immediately afterwards had been durably reconciled:
      non-blank hashes  26 -> 20
      blanked pages     exactly ['1','2','3','4','5','6'] — the six that were deleted
      every other hash  byte-identical to the pre-deletion capture
    Relaunching the app still showed 20/26, so the persisted record alone reads truthfully with no
    in-memory complement, which is the property the rule actually demands.

    Therefore the earlier all-27-missing observation was the all-or-nothing wholesale guard refusing
    an entire reconciliation — a case AGENTS.md explicitly permits session-scoped state to signal —
    and NOT a failure to reconcile. Both halves of the rule are satisfied: positive per-page evidence
    licenses a durable blank, and a wholesale refusal is surfaced as an operation-level signal.
  original_severity_when_filed: needs-decision
  found: "2026-08-18, round 6, incidental to test 2 clause 5"
  observed: |
    All 27 image files of a completed gallery were deleted outside the app via Files.app, with
    manifest.json left in place. After relaunch the Downloads row still showed a grey check and
    27/27 — the persisted record claiming complete with zero files on disk. Running
    "Validate Image Data" flipped the badge to amber and enabled "Retry Pages", but manifest.json
    pulled off the device immediately afterwards still carried 27 of 27 non-blank page hashes:
    nothing was blanked.
  the_question: |
    AGENTS.md's download-manifest-SSOT rule names this exact scenario ("image files were deleted
    outside the app while their hashes still read complete") and requires the manifest be reconciled
    durably at that moment. But the SAME rule permits session-scoped state as an operation-level
    signal for, among other things, "the all-or-nothing wholesale guard refusing an entire
    reconciliation" — and this case was wholesale, every page in the gallery.
    So the amber badge is either a rule violation or the wholesale guard behaving exactly as
    designed, and the observation as taken cannot tell the two apart.
  how_to_settle: |
    RUN AND ANSWERED — see resolution_2026_08_18 above. The prescribed check was: delete only SOME
    of a gallery's pages outside the app and run Validate; durable blanking of exactly those pages
    means the wholesale guard is working as designed. That is what happened.
  note: |
    Recorded rather than asserted as a defect precisely because the SSOT rule licenses this shape
    when the guard refuses wholesale. The restraint was warranted: the check cleared it.

- gap_id: G-15-2D
  truth: "A queue-wide continued-processing session exposes live progress and finishes as success when its galleries drain successfully."
  status: resolved
  resolved_by: "e68ca491 (serialize the activity-log pump), 1f9c3f34 (credit in-flight page bytes and heartbeat)"
  device_verdict_2026_08_18: |
    RESOLVED ON DEVICE, round 6, test iPhone (iPhone 11, iOS 26.6), build 260818-ek3, airplane mode
    OFF and the environment probe reporting "network wifi".

    SEVEN continued-processing sessions were granted over the course of the round. SIX ended in
    "Continued-processing session drained, terminal progress pushed." The seventh ended in
    expiration — and that one was the deliberate card-cancel performed for test 2 clause 7, where
    expiration is the system's correct delivery path for a user pressing stop and the app answered
    it by pausing both galleries. SPONTANEOUS OR STALL-DETECTOR EXPIRATIONS: ZERO. No "Task failed"
    card appeared at any point. Heartbeats arrived every ~10s throughout every session, with no gap
    approaching the ~30s stall window. Four of the sessions were multi-gallery (denominators 194,
    104, 402 and 1515 pages); all rendered a correct live fraction and "· 2 galleries" on every
    observed frame.

    The mechanism behind the fix was observed directly. In the 194-page run the completed-page count
    stayed flat at 62 across three consecutive heartbeats while in-flight subunits climbed
    181 -> 490 -> 781. That is precisely the page-granular plateau, under a download thread limit of
    1, that let Apple's stall detector force-expire the task in round 5; with 1f9c3f34 crediting
    in-flight page bytes the reported progress kept advancing and the session rode through it.

    This closes the owner's 2026-08-17 ruling that "在沒有飛航模式、網路異常等情況時 session 在下載未完成
    的情況下結束是不能接受的" — under exactly those conditions (no airplane mode, healthy Wi-Fi) no
    session ended early in four attempts.
  diagnosis_2026_08_17: |
    STATIC ANALYSIS ONLY - not yet confirmed against device logs. Recorded so the next session does
    not redo it.

    Exactly TWO code paths can paint a user-visible "Task failed" card, because only they reach
    `setTaskCompleted(success: false)` on an ADOPTED task:
      1. `ContinuedProcessingSession.adopt(_:expecting:)` :301-304 - a task arriving when the guard
         `pendingIdentifier == identifier, self.task == nil` fails is turned away and completed
         unsuccessfully. This is deliberate ("a dropped stray is a leaked system task, a second
         progress card"), but the disposal is what the system renders as a failure.
      2. Expiration - :314 `endSession(yielding: .expired, success: false)` reaching :364.

    Ruled OUT by reading:
      - The `.unavailable` arms (:152, :175, :210, :287) also pass `success: false`, but they run
        with no adopted task, so `endingTask` is nil at :364 and `setTaskCompleted` never fires.
        They cannot paint a card.
      - Both drain paths pass success TRUE (`DownloadClient+ContinuedSession.swift:449, :711`), so a
        clean drain does not report failure.
      - Overlapping sessions are refused by the single-session guard (:118-121), so two cards cannot
        come from two concurrent sessions.
      - `endSession` does take back a request the session never adopted (:360-362), so this is not
        simply a missing cancel.

    LEADING HYPOTHESIS - a cancel/launch race producing a stray. The type's own doc states the
    enabling condition at :330-333: "Under the chosen queue submission strategy a submission
    routinely outlives a short session - the queue drains and the caller finishes in seconds while
    the request is still waiting its turn." `endSession` cancels the outstanding request, but that
    cancel is not atomic with a launch the system has already dispatched. Such a launch reaches
    `handleLaunch` after `pendingIdentifier` was cleared, fails `adopt`'s identity gate, and is
    completed with `success: false` - a "Task failed" card for a session whose work actually
    succeeded. That matches the report exactly: both galleries drained to 51/51 and 53/53 while the
    surface showed failure. Two cards would then be two such strays, or one stray plus one
    expiration.

    If this holds, the defect is NOT in the download logic and NOT in the progress basis that
    rounds 9-18 reworked - it is that the app's only disposal for an unwanted task is one the system
    presents to the user as a failed activity. The fix question becomes whether a stray can be
    disposed of without painting a failure, which is a question about the API surface rather than
    about this app's accounting.
  device_log_verdict_2026_08_17: |
    CONFIRMED FROM DEVICE LOGS, and the leading hypothesis above is REFUTED. There was no stray
    launch and no cancel/launch race. Evidence: `Logs/ehpanda-20260815-194921-3.jsonl` pulled from
    the test iPhone (that file scoped by `--subdirectory Documents/Logs`; no container export).
    It is the only log of that evening carrying DownloadCoordinator / DownloadClient /
    ContinuedProcessingSession activity, and it covers exactly two galleries — two masked gids,
    matching the two-gallery report.

    Seven sessions, relative to the first submission:
      t=   0.0s  submitted -> granted -> drained  21.8s
      t= 163.3s  submitted -> granted -> drained 233.5s
      t= 737.0s  submitted -> granted -> drained 747.9s
      t= 906.6s  submitted -> granted -> drained 916.0s
      t= 995.6s  submitted -> granted -> EXPIRED 1111.0s  (115s), both galleries paused
      t=1315.4s  submitted -> granted -> EXPIRED 1368.2s  (53s),  logged 3x, both paused 3x
      t=2561.4s  submitted -> granted -> drained 2704.2s

    TWO expirations, and the user saw exactly two failed cards. `.expired` routes to
    `endSession(yielding: .expired, success: false)` and thence to `setTaskCompleted(success: false)`
    at `ContinuedProcessingSession.swift:364`, which is what the system renders as "Task failed".
    The queue nonetheless finished because the LAST session drained successfully, which is why
    foregrounding showed 51/51 and 53/53.

    So the app's accounting was never wrong here. Each card is an honest report of the session it
    belongs to, and the system expiring a continued-processing task is normal rather than a defect.
    What is wrong is at the level of what the USER can conclude: the surface presents per-session
    outcomes, two of which failed, with no way to see that a later session completed the work. SC2's
    truth is stated over the queue ("finishes as success when its galleries drain successfully"),
    and no single session's report can satisfy a queue-level claim when the queue outlives sessions.
    That is a design question about the reporting unit, not a bug to patch in the progress basis —
    and notably NOT what rounds 9-18 were reworking.
  new_defect_found: |
    Separately, the log shows a REAL defect at the second expiration: the
    "Continued-processing session expired, pausing schedulable downloads" line fires THREE TIMES at
    one identical timestamp (1368.2s), and each gallery is then paused three times. The first
    expiration logged once. `endSession` is documented "Ends the session, at most once" and clears
    `task`/`continuation` before anything terminal, so the duplication is downstream of it: the line
    is emitted by DownloadCoordinator reacting to the `.expired` event, which means the event was
    delivered three times, or three consumers were live on the stream. Not explained by the
    once-then-thrice shape, so it needs its own investigation rather than a guess. Filed as G-15-2E.
  owner_ruling_2026_08_17: |
    A session ending while downloads are incomplete is UNACCEPTABLE, except when caused by airplane
    mode, network loss or a similar external network fault. This supersedes the "reporting unit"
    framing I offered above: the question is no longer how to present the outcome, it is why the
    sessions ended at all.
  root_cause_2026_08_17: |
    Both expiries fall on the unacceptable side of the ruling — the log carries NO network-fault
    signal. There are zero `networkingFailed(3)` entries, zero retry warnings (`Networking.swift`
    would log them), and zero page-failure lines during any session. The 359 `Parser`
    authenticationRequired(7) errors are all in the first 30s (home-page parsing at launch); the 11
    `notFound(14)` are `loadLocalPageURLs` against a not-yet-downloaded gallery; the 2
    `authenticationRequired(7)` are the optional version-metadata fetch at enqueue. All benign.

    PROXIMATE CAUSE: the system's stall detector. `BGTask.h` (iPhoneOS26.5 SDK) states a
    `BGContinuedProcessingTask` "_must_ report progress via the NSProgressReporting protocol
    conformance during runtime and [is] subject to expiration based on changing system conditions...
    Tasks that appear stalled may be forcibly expired by the scheduler." Apple DTS (forums thread
    805554) quotes the system log for exactly this — "Task has not reported progress within expected
    cadence, marking stalled" — and puts the window at roughly 30 seconds.

    THE SESSIONS WERE GENUINELY STALLED, by arithmetic rather than assumption. The queue runs one
    gallery at a time and the default thread limit is 1. Healthy observed rate is ~0.77 pages/s
    (17 pages/21.7s, 53 pages/70s). Gallery D6DIqI (51 pages) had 9 + 115 + 53 = 177s of session
    coverage across S4/S5/S6 and still needed 65s of S7 to finish — 65s at the healthy rate is
    ~50 pages, so S5 and S6 landed almost nothing. Timing agrees: expiry 1 at background+80.7s
    implies the last progress change was ~50s into background; expiry 2 at background+11.8s implies
    the stall began ~18s BEFORE backgrounding, in the foreground — so backgrounding was not itself
    the trigger.

    WHY THE APP IS EXPOSED, three compounding facts:
      (a) Progress is pushed only when a PAGE outcome arrives (`+PageDownload.swift:177-222` →
          `flushDownloadProgress`, `+Persistence.swift:201-226`), plus the run-start announce and
          convergence. With a thread limit of 1, a single slow or held page means the numerator does
          not move at all. Nothing intra-page is reported.
      (b) Page images always go through a BACKGROUND URLSession in production
          (`DownloadClient.swift:54-71` → `DownloadPageDownloader.swift:281`
          `URLSessionConfiguration.background`). Apple documents that for transfers started while
          the app is in the background "the system always starts transfers at its discretion... and
          ignores any value you specified" for `isDiscretionary`. Under a continued-processing
          session the process is alive but the app IS backgrounded, so every new page task created
          after backgrounding is discretionary and may be deferred. Consistent with the
          non-determinism observed (S7 ran 123s backgrounded without trouble; S5 died at +80s).
          NOT proven by the log — see `discriminating_experiment`.
      (c) After any expiry the D-11 policy pauses the whole queue
          (`+ContinuedSession.swift:511-546`) and nothing resumes it without a tap. Apple further
          states (thread 806668) that user-cancel and system-reclaim are indistinguishable to the
          app, so this cannot be softened by detecting the difference.
  recommended_fixes_ranked: |
    1. DECOUPLE LIVENESS FROM PAGE LANDINGS — report intra-page progress. Wire
       `URLSessionDownloadDelegate.didWriteData` bytes through to the coordinator and push a finer
       numerator (e.g. units = pages x 1000, the in-flight page credited by byte fraction, throttled
       to ~1 push/s, monotone per page). This is DTS's own recommendation and is the real fix. The
       existing monotonic-floor / D-G7-01 machinery would need the sub-page term folded in
       deliberately rather than incidentally.
    2. SESSION HEARTBEAT — re-push the current pair every <=10s while a session is live and has
       pending work. Cheap and truthful, but treat as belt rather than braces: it is unverified
       whether the detector counts an UNCHANGED completedUnitCount as "reported progress".
    3. KEEP PAGE TRANSFERS OFF THE BACKGROUND SESSION while a continued-processing session covers
       the process (`DownloadPageDownloader.foreground(urlSession:)` already exists). Owner design
       decision; the log is consistent with it but does not prove it.
    4. Revisit "expiry => pause everything" only if the owner wants; per Apple the app cannot tell
       reclaim from cancel, so levers 1-3 are the substantive ones.
  discriminating_experiment: |
    Same two galleries, background the app immediately after resume, run once with the current
    background page session and once with `DownloadPageDownloader.foreground(urlSession:)`. If the
    foreground path never stalls while backgrounded under a live session, cause (b) is confirmed.
  system_log_step_needs_owner: |
    The system's own reason lives in the device's unified log (dasd / BackgroundTaskManagement,
    "marking stalled", identifier `app.ehpanda.personal.continued.<uuid>`). Collecting it from a
    physically attached device requires ROOT, which I cannot and will not escalate to:
      sudo /usr/bin/log collect --device-udid <udid> --start "2026-08-15 19:45:00" --output <dir>
    then filter with `/usr/bin/log show ... --predicate 'process == "dasd"'`. Note zsh has a `log`
    builtin, so call `/usr/bin/log` explicitly. Two-day-old entries may already have aged out.
  instrumentation_for_next_uat: |
    Log at `updateProgress` whenever the numerator changes, plus a 10s heartbeat line carrying
    completed/total and pushes-since-last; and record NWPath (wifi/cellular), lowPowerMode and
    thermalState at session start and again in the expiry arm. That turns the next expiry from an
    inference into an attribution.
  clock_note: |
    The jsonl `date` field is CFAbsoluteTime (seconds since 2001-01-01), so wall clock is
    recoverable: Run 3 begins 2026-08-15 19:49:21 JST, expiry 1 = 20:08:53.2, expiry 2 = 20:13:10.5.
    Timings quoted in `device_log_verdict_2026_08_17` are relative to the first SUBMISSION line;
    those in `root_cause_2026_08_17` are relative to the first line of the file (offset 60.8s).
  scope_note: |
    Diagnosis only. No fix attempted — every ranked item above is a design change needing the
    owner's go-ahead.
  fix_landed_2026_08_18: |
    Ranked fixes 1 and 2 LANDED, plus the instrumentation, by quick task 260818-ek3 —
    commit 1f9c3f34 on `feature/gsd-phase-15` (the log-pump half it depends on is e68ca491).
    STATUS STAYS OPEN: nothing here is device-confirmed, and closing it is the next UAT's job.

    (1) INTRA-PAGE CREDIT (ranked fix 1). `URLSessionDownloadDelegate.didWriteData` is now wired
    through: `BackgroundPageDownloadDelegate` forwards a transfer's running byte totals at most
    every 250 ms per task (one lock covers the lookup, the throttle decision and its stamp; the
    handler runs outside it), and the coordinator credits the page. The seam gained a fifth
    argument, `inFlightSubunitCount`, and `ContinuedProcessingSession` — the owner of the system
    `Progress` — does the scaling: `totalUnitCount = total * 1000`,
    `completedUnitCount = min(completed * 1000 + inFlight, total * 1000)`. The COORDINATOR'S PUSHED
    PAIR IS STILL WHOLE PAGES, deliberately: the sub-page term travels beside it rather than inside
    it, so `lastPushedCompletedPageCount` gains no writer and D-G2-01 / D-G2C-01 / D-G7-01 keep
    their documented meaning. Per-page credit is monotone by `max` (a retry restarts the bytes at
    zero, and two forwarded reports can land out of order — the `max` answers both); it is retired
    inside `flushManifestPageProgress`, in the same synchronous stretch as the run measurement's own
    subtraction, so whole-page and sub-page credit trade places atomically; it is withdrawn by name
    at a page's `.failure` outcome — a drop of less than one page, the one deliberate downward mover
    — and dropped with the rest of the gallery's entries at the run's exit. Pushes from bytes are
    throttled to at most one per second (`intraPageProgressPushMinimumInterval`, stated as being at
    or above the existing 0.4 s flush interval). An unknown expected size credits nothing intra-page.
    The subtitle still reads whole pages.

    (2) SESSION HEARTBEAT (ranked fix 2). One coordinator-owned repeating task per live session,
    started when the client session id lands and cancelled in `markContinuedSessionEnded`, period
    10 s, gated on `hasPendingWork()`, re-pushing through the SAME
    `pushContinuedSessionProgress(sessionID:)` — no second push path. It drives the injected clock,
    so its tests advance a `TestClock` rather than sleeping.

    (3) INSTRUMENTATION — the exact message prefixes to grep in the next jsonl:
      - `Page transfer first bytes` — fields: page index, `created foreground|background`, ms to
        first byte, expected bytes. The `created` field plus the TTFB is the discriminator for
        cause (b).
      - `Page transfer starved` — page index, `created …`, ms without bytes, and
        `still transferring | ended`. Emitted for any transfer with zero bytes for >= 10 s, from ONE
        helper shared by both detectors (the heartbeat's sweep, and the transfer's own exit — so a
        transfer the expiry's pause sweep cancelled still says how long it starved).
      - `Continued-session heartbeat` — completed / total pages, in-flight subunits, galleries,
        transfers in flight. Logged only when the numerator changed or 30 s passed, so the file
        stays small.
      - `Continued-session environment at start` and `Continued-session environment at expiry` —
        network kind, low power, thermal state.
    Gallery identity stays `<mask.hash>`; every other field is an integer or a closed symbol name
    and goes out `public`. `DownloadLogPrivacyInvariantTests` was edited deliberately and only
    there: one new file entry worth two masked sites, total 11 to 13.

    (4) DEFERRED, decision after the next UAT: ranked fix 3, routing page transfers through the
    foreground `URLSession` while a session is live. Apple's `isDiscretionary` documentation
    (quoted under `root_cause_2026_08_17`) makes it a documented mechanism, not a confirmed one; the
    discriminator is now in the log — the `created background` field on the first-bytes and starved
    lines, and their TTFB / starvation durations across a background stretch.

    (5) UNCHANGED: ranked fix 4. The D-11 "expiry => pause all schedulable" policy is untouched.

    WHAT THE NEXT DEVICE RUN MUST SHOW TO CLOSE THIS: no expiry while pages are landing; heartbeat
    lines every ~10 s through each backgrounded stretch and first-bytes lines for the pages
    transferred in it; and, at any expiry that does occur, the environment lines from both moments
    plus whatever starved lines preceded it — so the next verdict is an attribution rather than an
    inference.
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

round_6_scope: |
  Round 6 is narrow by design: it re-ran test 2 only, on the test iPhone, to confirm the two
  G-15-2D fixes that another session landed (e68ca491 serialize the activity-log pump,
  1f9c3f34 credit in-flight page bytes and heartbeat). The regression gate was run first from
  AppPackage/ and was clean — BUILD SUCCEEDED with 0 errors and 0 warnings, TEST SUCCEEDED.
  All other checkpoints keep their round-4/round-5 results unchanged.
