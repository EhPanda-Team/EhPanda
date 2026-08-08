---
status: diagnosed
trigger: "G-15-2C: On a physical iOS 26 device, the system continued-processing card's subtitle still reads '1 gallery' after every queued gallery has completed — even after the terminal-push fix (15-22), drain re-check hardening (15-23), and round-18 RunProgressBasis numerator redesign (15-54)."
created: 2026-08-08T00:00:00Z
updated: 2026-08-08T00:00:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED (two coupled layers). Layer 1 — mechanism: the code-side terminal push is
  proven present, correctly positioned, correctly valued ("N / N pages · 0 galleries") and strictly
  ordered before setTaskCompleted on the MainActor on EVERY production drain route; the device
  still rendering "1 gallery" therefore isolates the failure to the system-owned card's
  write-to-render pipeline — an update issued immediately before task completion does not repaint,
  exactly the empirical risk G-15-2B's missing[] flagged. Layer 2 — basis: galleryCount is
  live-only by documented design while the fraction is session-cumulative, so every push during
  the last gallery's page loop necessarily ends "· 1 gallery", making the un-renderable terminal
  push the ONLY frame that could ever say otherwise. The user's articulated G-15-2C truth (count =
  galleries represented by denominator Y, cumulative) rejects that documented contract: under a
  coverage basis every frame of a two-gallery run reads "2 galleries" and no terminal repaint is
  needed for the count to be truthful.

reasoning_checkpoint:
  hypothesis: "The card shows a stale '1 gallery' because (a) every push computable while any gallery downloads carries the live-only schedulable count, which is >= 1 by the .active derivation, and (b) the sole zero-count frame — the drain terminal push — is issued microseconds before setTaskCompleted and the system-rendered card does not repaint it; the fix the user asked for (coverage-basis count) removes dependency (b) entirely."
  confirming_evidence:
    - "ContinuedSession.swift:819 galleryCount = snapshot.sessionProgress.galleryCount = schedulableDownloads().count (:138); doc :10-15 documents live-only as deliberate (D-G2-01); :88 states 15-54 left it untouched; 15-54-PLAN/SUMMARY contain zero galleryCount/subtitle mentions."
    - "Drain trace fully verified against current code: forced flush paints '…· 1 gallery' (PageDownload:56-64 → Persistence:224, gallery still .active per Persistence:97-99 + Scheduling:125-127); settle → defer → spawned Task → scheduleNextIfNeeded tail (:34-35) → drain branch → terminal push :573 with empty schedulable set (count 0) → markContinuedSessionEnded :585 → finish :586 → setTaskCompleted (ContinuedProcessingSession:364). All awaited sequentially — no reordering possible between these two pushes; no concurrent push exists at drain."
    - "ContinuedProcessingSession.updateProgress (:227-242) has no throttle, no coalescing, no drop once sessionID matches and the task is held; task.updateTitle has exactly one call site; device user SAW the card, so the task was adopted (task non-nil)."
    - "Round-3 device observation: '1 gallery' after both completed — the string the forced flush painted, not the string the terminal push wrote to the task object."
  falsification_test: "If a device run showed 'N / N pages · 0 galleries' at drain, layer 1 would be falsified (the OS does repaint); if any production drain route were found bypassing reconcileContinuedSession's drain branch, the OS-render conclusion would be premature and that path gap would be the cause instead — the exit-path sweep found none."
  fix_rationale: "Changing galleryCount's basis to the denominator's coverage (live schedulable galleries + departed galleries whose retiredSessionPages contribute pages to Y) makes every painted frame satisfy the user's stated truth, independent of whether the OS renders the final frame — it removes the render-race dependency instead of racing it harder."
  blind_spots: "Static analysis cannot observe the OS render pipeline; layer 1's 'does not repaint' is established by elimination (correct string provably written before completion, wrong string displayed), not by direct observation. Cannot rule out that a deliberate delay between the terminal push and finish would repaint — but that would still not satisfy the user's cumulative-basis truth, so the fix direction does not depend on it."

test: complete — exhaustive subtitle-writer enumeration, full drain trace, all-exit-path sweep,
  client choreography audit, test-expectation census.
expecting: n/a
next_action: none — diagnosis complete, hand to /gsd-plan-phase --gaps for G-15-2C.

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Final subtitle at queue drain must describe zero remaining galleries (e.g. "N / N pages · 0 galleries"), not a leftover "1 gallery". User's articulated basis truth: the gallery count beside "X / Y pages" must equal the number of galleries whose pages are represented by denominator Y — cumulative session coverage, including galleries already completed during the session.
actual: "After both galleries completed, the card still displayed 1 gallery. The count appears to describe only the currently active gallery set, but it should describe every gallery represented by the denominator in X / Y pages." (verbatim, round-3 device retest, 2026-08-08)
errors: None reported
reproduction: 15-UAT.md Test 2 — queue two galleries on a physical device, background the app, let both complete, observe the system card's final subtitle.
started: Round-3 UAT retest 2026-08-08, after 15-22 (terminal push), 15-23 (drain re-check), 15-54 (RunProgressBasis) all landed (commits a6105b0b, d155236a, 5df56a8e, d4d568c6).

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: "Candidate class 1 — the terminal push is bypassed on the production drain path
    taken in this scenario (some drain route skips the 15-22 push)."
  evidence: >
    Exit-path sweep over current code found every drain-shaped exit converging on the ONE drain
    branch that contains the push. Completion: processDownload defer → finishActiveTaskIfOwned
    (Execution.swift:249-276) → spawned Task → scheduleNextIfNeeded, whose tail always reconciles
    (Scheduling.swift:34-35); the schedulesNext:false collision branch reconciles directly
    (Execution.swift:271). Cancel of the last queued work item: cancelQueuedWorkItem →
    scheduleNextIfNeeded (Scheduling.swift:351). Pause: every commitPause exit converges on
    scheduleNextIfNeeded. The drain branch (ContinuedSession.swift:562-588) pushes at :573 after
    the client-id deferral (:568) and before markContinuedSessionEnded (:585). Expiration and
    .unavailable end the session without a push, but on those routes the card is system-dismissed
    or never existed, so no stale subtitle can survive them.
  timestamp: 2026-08-08

- hypothesis: "The terminal push fires but is dropped or throttled client-side, or reports a
    wrong count (1 instead of 0) at drain."
  evidence: >
    ContinuedProcessingSession.updateProgress (:227-242) is unconditional once the sessionID
    matches and a task is held — no throttle, no rate limit, no drop arm. The one flush throttle
    in the system (Persistence.swift:207-212) is bypassed by force: true and does not sit on the
    reconcile path at all. At drain the snapshot's schedulable set is empty (the completed gallery
    left queueStore via settleCompletedDownload and its complete manifest fails shouldSchedule;
    activeGalleryID is nil after finishActiveTaskIfOwned), so galleryCount is exactly 0 and the
    fraction is retired/retired = N/N. The string catalog renders 0 through the plural `other`
    category (verified in G-15-2B, unchanged).
  timestamp: 2026-08-08

- hypothesis: "Out-of-order delivery — the forced flush's '1 gallery' frame lands AFTER the
    terminal '0 galleries' frame, leaving the stale string as the last painted one."
  evidence: >
    The two pushes are causally serialized, not concurrent: the forced flush's updateProgress is
    AWAITED to completion inside downloadPages (PageDownload.swift:56-64) before completeDownload
    → settle → defer → reconcile can even begin, and the terminal push is computed strictly later
    in that same chain. The documented two-in-flight displacement window
    (ContinuedSession.swift:744-750) requires a second pusher concurrently in flight; at drain no
    page loop is live and no other production pusher exists (writer census: ContinuedSession:573,
    :589, Persistence:224, ExecutionSupport:494 — the last two require a live run).
  timestamp: 2026-08-08

- hypothesis: "The round-18 RunProgressBasis redesign (15-54) changed or broke the gallery-count
    arithmetic."
  evidence: >
    The redesign is numerator-only by its own contract: ContinuedSession.swift:88 — "The
    per-gallery pageCount denominator and the schedulable galleryCount are untouched by the rule;
    only the numerator's basis is." 15-54-PLAN.md and 15-54-SUMMARY.md contain zero occurrences of
    galleryCount/gallery count/subtitle. galleryCount still flows snapshot → push verbatim
    (:138 → :819).
  timestamp: 2026-08-08

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-08
  checked: prior sessions continued-session-ends-on-first-gallery-completion.md (G-15-2) and
    continued-session-subtitle-stuck-at-one-gallery.md (G-15-2B)
  found: G-15-2B's root cause was NO terminal push; its missing[] explicitly flagged the
    empirical risk that "a push immediately followed by setTaskCompleted" might not repaint
    on the system-rendered card, and named the alternative — change galleryCount's basis to
    the session's whole coverage so no stale value is possible.
  implication: The round-3 device observation is the flagged risk materializing, IF the
    terminal push provably fires and orders correctly in current code. Verify that first.

- timestamp: 2026-08-08
  checked: current DownloadClient+ContinuedSession.swift (post-15-54 tree, HEAD d101206b)
  found: (a) The terminal push EXISTS — reconcileContinuedSession drain branch, line 573
    (D-G2B-01), positioned after the continuedClientSessionID deferral (568) and before
    markContinuedSessionEnded (585), with a post-hop drain re-check (581, D-G3-01). (b) The
    pushed pair mixes bases BY DOCUMENTED DESIGN: fraction = live sum + retiredSessionPages
    on both sides (lines 804-808), galleryCount = snapshot.sessionProgress.galleryCount
    (line 819) = schedulableDownloads().count (line 138) — doc lines 10-15: "The gallery
    count is the remaining schedulable galleries and only those" (D-G2-01 extending D-10).
  implication: Candidate class 1 narrows to "does the drain route reach line 573"; class 3
    is confirmed as a documented live-only count basis vs the user's cumulative-coverage truth.

- timestamp: 2026-08-08
  checked: BackgroundProcessingClient/ContinuedProcessingSession.swift (whole file)
  found: updateProgress (227-242) is @MainActor, unconditional once sessionID matches and a
    task is held — NO throttle, NO coalescing, NO drop path. It writes task.progress.total,
    task.progress.completed, then task.updateTitle(task.title, subtitle:). finish (248-251)
    → endSession (347-369) → setTaskCompleted(success:) at 364, no subtitle. The coordinator
    AWAITS updateProgress across the MainActor hop before calling finish, so the subtitle
    write is strictly ordered before setTaskCompleted on the MainActor.
  implication: Client-side, the terminal push cannot be eaten. If it fires, the task object
    receives "N / N pages · 0 galleries" before completion. Any failure to display is
    OS-side rendering, not app choreography.

- timestamp: 2026-08-08
  checked: production drain trace through current code — DownloadClient+PageDownload.swift
    56-64 (force: true flush), +Persistence.swift 201-226 (flushDownloadProgress → push at
    224), +Execution.swift 9-57/59-81/243-276 (processDownload defer → settleCompletedDownload
    → finishActiveTaskIfOwned spawns Task → scheduleNextIfNeeded), +Scheduling.swift 27-36
    (tail reconciles), +PendingWork.swift 10-15 (hasPendingWork)
  found: Exact sequence for the two-gallery device run, all causally ordered in one chain:
    (1) final gallery's page loop ends → forced flush pushes "N / N pages · 1 gallery"
    (activeGalleryID == gid keeps the gallery .active → schedulable → count 1); this
    updateProgress is AWAITED to completion before control returns. (2) completeDownload →
    settleCompletedDownload removes gid from queueStore. (3) processDownload's defer clears
    ownership, spawns Task → scheduleNextIfNeeded → core finds nothing → tail
    reconcileContinuedSession. (4) hasPendingWork() false (activeTask nil, schedulable set
    empty) → drain branch → terminal push computes galleryCount = 0, fraction = 0+retired /
    0+retired = N/N → awaited updateProgress paints "N / N pages · 0 galleries". (5) re-check
    passes → markContinuedSessionEnded → finish → setTaskCompleted(true).
  implication: The terminal push DOES fire on the exact route the user exercised, with the
    correct string, strictly before completion. Candidate class 1 (path gap) is eliminated
    for the completion-drain route. No concurrent push exists at drain time (no page loop is
    live), so out-of-order delivery cannot explain the stale string either.

- timestamp: 2026-08-08
  checked: all session exit paths for terminal-push coverage (round-8 lesson: sweep every
    exit) — drain via completion (above), drain via cancelQueuedWorkItem (+Scheduling.swift
    334-353 → scheduleNextIfNeeded → same drain branch), drain via pause (commitPause exits
    all converge on scheduleNextIfNeeded), .expired (+ContinuedSession.swift 420-423 →
    markContinuedSessionEnded then pauseAllSchedulable — no push, but the card is
    system-dismissed on expiration so no stale render survives), .unavailable (no card
    exists), client-refused start (no card exists)
  found: Every drain-shaped exit converges on the ONE drain branch at reconcileContinuedSession;
    no production drain route bypasses the terminal push.
  implication: Class 1 fully eliminated. Remaining: class 2 (OS does not render an update
    issued immediately before setTaskCompleted) as the mechanism, and class 3 (live-only
    count basis) as the design that makes the terminal render the ONLY thing standing
    between the user and a stale "1 gallery".

- timestamp: 2026-08-08
  checked: current client seam — BackgroundProcessingClient.swift (:54, :77-78, live value) and
    ContinuedTaskScheduling.swift (:139-140 protocol shim over BGContinuedProcessingTask)
  found: task.updateTitle(_:subtitle:) has exactly one production call site
    (ContinuedProcessingSession.swift:241); backgroundProcessingClient.updateProgress has exactly
    one call site (ContinuedSession.swift:821, inside pushContinuedSessionProgress);
    pushContinuedSessionProgress has four production callers — drain terminal push (:573), live
    reconcile branch (:589), flush ride-along (Persistence.swift:224), and the D-G5-01 run-start
    announcement (ExecutionSupport.swift:494, new since round 9) — plus the test-only forwarder
    (Testing.swift:80). All four production pushes share line 819's live-only galleryCount.
  implication: There is no second subtitle writer that could carry a different count basis; a
    basis fix at the one push site covers every production frame.

- timestamp: 2026-08-08
  checked: which test expectations pin the live-only count basis (census, current tree)
  found: DownloadContinuedSessionTests.swift pins live-only counts at :237, :286
    ("0 / 1 page · 0 galleries"), :315 ("5 / 16 pages · 2 galleries"), :344-345, :402-403
    ("6 / 14 pages · 2 galleries" → "10 / 14 pages · 1 gallery"), :439, :490-491
    ("2 / 6 pages · 1 gallery" → "6 / 6 pages · 0 galleries"), :525-526.
    DownloadContinuedSessionLedgerTests.swift pins them at :43 (drainedPair
    "20 / 20 pages · 0 galleries"), :57 (departedPair "6 / 10 pages · 1 gallery"), :98-101 (the
    3→2→1→0 series), :186-187, :227, :239, :278, :285, :322, :329, :380-382 (rejoin 2→1→2),
    :428, :436, :461, :472, :509. Client-level fixtures in the BackgroundProcessing tests
    (:17-82, :179) are pass-through strings, basis-agnostic.
  implication: A coverage-basis fix must REWRITE these expectations (e.g. the drained
    three-gallery series becomes 3 galleries on every frame; the pause departedPair becomes
    "6 / 10 pages · 2 galleries" since the paused gallery's 6 retired pages remain in Y) — not
    supplement them. This is the same encoded-defect pattern G-15-2 and G-15-2B both hit.

- timestamp: 2026-08-08
  checked: what a coverage-basis count would be computed FROM, in current state
  found: The denominator of every push is liveProgress.pageCount + retiredSessionPages.values sum
    (:804-808). The galleries represented in it are exactly: the live schedulable set
    (snapshot.finishedPages.keys) plus the departed galleries holding a retiredSessionPages entry.
    reconcileRetiredSessionPages already deduplicates a rejoining gallery (removes its ledger entry
    at :652-654 before the live sum counts it again), so the union is naturally double-count-free.
    Zero-valued ledger entries exist (a departed gallery that finished nothing retires 0, :677),
    and such a gallery contributes no pages to Y.
  implication: The coverage count is directly derivable from state the push already reads —
    galleryCount = snapshot count + (number of retiredSessionPages entries, optionally filtered to
    > 0). Whether a zero-page retirement counts as "represented by Y" is the one open semantic
    decision for the fix planner (the letter of the user's truth says no; counting it changes
    nothing else).

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: >
  Two coupled causes, one observable defect. (1) BASIS — the design cause: the pushed pair mixes
  two bases by documented contract (ContinuedSession.swift:10-15, D-G2-01): the fraction is
  session-cumulative (live sum + retiredSessionPages on both sides, :804-808) while galleryCount
  is the LIVE schedulable count only (:819 ← :138). A gallery being downloaded is always .active
  (Persistence.swift:97-99) and therefore always schedulable (Scheduling.swift:125-127), so every
  frame computable while the last gallery downloads — including the final forced flush
  (PageDownload.swift:56-64 → Persistence.swift:224) — necessarily reads "… · 1 gallery" beside a
  denominator spanning the whole session. The user's G-15-2C truth (count = galleries represented
  by denominator Y, cumulative, including completed ones) is violated by this contract on every
  mid-run frame of every multi-gallery session, independent of anything at drain. (2) RENDER — the
  mechanism that exposes it at drain: the only production frame that can carry a different count is
  the drain branch's terminal push (:573, added by 15-22), and static analysis proves it fires on
  every production drain route, computes the correct "N / N pages · 0 galleries", and is strictly
  ordered before setTaskCompleted (both awaited across the MainActor; updateProgress is
  unthrottled, ContinuedProcessingSession.swift:227-242; completion at :364). The device
  nevertheless renders the forced flush's "1 gallery" — so the system-owned card does not repaint
  an update issued immediately before task completion. That is the empirical risk G-15-2B's
  missing[] explicitly flagged, now confirmed on device: the terminal-push strategy bets the
  card's last word on an OS render race the app can neither win nor observe. The 15-54 numerator
  redesign is not implicated (numerator-only by contract, :88; its plan/summary never mention the
  count). Fixing the basis (cause 1) removes all dependency on the unwinnable render race
  (cause 2); fixing only the race is impossible from the app's side and would still violate the
  user's stated truth.
fix: >
  (not applied — diagnose-only mode) Direction: change galleryCount's basis to the denominator's
  coverage — live schedulable galleries plus departed galleries whose retiredSessionPages entries
  contribute pages to Y — computed inside pushContinuedSessionProgress from state it already
  reads. Update the documented contract (ContinuedSession.swift:8-15 and the :88 sentence);
  rewrite (not supplement) the live-only test expectations censused in Evidence; decide the
  zero-page-retirement semantic; keep the terminal push as harmless defence. Under the new basis a
  two-gallery run reads "2 galleries" on every frame, so the card is truthful whether or not the
  OS renders the final frame.
verification: (not applied)
files_changed: []
