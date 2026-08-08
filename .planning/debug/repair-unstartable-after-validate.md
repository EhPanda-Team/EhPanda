---
status: diagnosed
trigger: "G-15-5: After Validate Image Data marks missing pages pending, no start affordance (Pause + Retry Failed Pages disabled, no Resume); after relaunch the yellow missing-page indicator disappears and count shows 36 / 36 while 10 pages remain pending."
created: 2026-08-08T00:00:00Z
updated: 2026-08-08T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — one root state, three surface manifestations. Validation records its missingFiles finding ONLY in the in-memory `validationErrors` dictionary and never reconciles the durable manifest, whose 36 intact hashes keep the record claiming complete. Every start affordance is gated on shapes this state never has.
test: Static code reading complete — all gating predicates, the validate write path, displayStatus derivation, both count bases, and every enqueue path traced.
expecting: n/a (diagnosis complete)
next_action: Return ROOT CAUSE FOUND to orchestrator (goal: find_root_cause_only — no fix applied).

reasoning_checkpoint:
  hypothesis: "Validation stores its missingFiles verdict only in the transient `validationErrors` dictionary (displayStatus → .error) while the persisted manifest keeps all 36 non-empty page hashes (completedPageCount == 36, isComplete == true, isIncomplete == false). The `.error`+complete-claim shape satisfies no start-affordance gate anywhere, and the transient marker evaporates on relaunch, leaving the complete-claiming record to render .completed / 36 of 36 while the inspector's live file scan still derives 10 pending."
  confirming_evidence:
    - "DownloadClient+PersistenceNormalize.swift:90-110 — validateImageData writes ONLY validationErrors[gid]; doc comment at :89 states 'session-scoped status (validationErrors), not persisted'"
    - "DownloadClient+Manager.swift:430 — validationErrors is a plain in-memory actor property"
    - "DownloadStore+Operations.swift:209-311 — storage.validate is read-only; never blanks a hash"
    - "DownloadClient+Persistence.swift:90-114 — displayStatus: validationErrors → .error (branch 1); after relaunch (empty dict) manifest.isComplete → .completed"
    - "DownloadedGallery+SupportTypes.swift:66-72,109-111 — canPauseOrResume=[.active,.inactive], canTogglePause adds .queued, canRetryFailedPages = failed pages only"
    - "DownloadClient+PublicAPIHelpers.swift:18-51 — buildInspectionPages: missing file + no recorded page failure → .pending (never .failed)"
    - "DetailReducer.swift:93-97 — downloadNeedsRepair requires completedPageCount == 0; false at 36 → Detail .error button offers destructive .redownload only"
  falsification_test: "If any UI-reachable code path enqueued a `.repair` for an .error-status complete-claiming record, or if validateImageData persisted anything, the hypothesis would be wrong. Grepped all enqueue sites (resume, performRetry, performRetryPages) and all affordance gates — none reachable from this state."
  fix_rationale: "n/a — diagnose-only mode; fix direction recorded in Resolution"
  blind_spots: "Cannot run the app (shared machine, xcodebuild forbidden); diagnosis is static. Device-observed symptom text matches every derived behavior exactly, including the yellow color (.error → .yellow, DownloadedGallery+Extensions.swift:11)."

## Symptoms

expected: "After validation marks missing image files as pending, the user can immediately start a repair download, and the missing-page indicator, displayed page count, and persisted pending-page state remain consistent across relaunch."
actual: "After Validate Image Data marked 10 missing pages as pending, Pause and Retry Failed Pages were both disabled, and no Resume or other action was available to start the repair download. After relaunching the app, the yellow missing-page state disappeared and the page count displayed 36 / 36 even though 10 pages remained pending, leaving the persisted and displayed state inconsistent."
errors: None reported
reproduction: 15-UAT.md Test 5 — complete a 36-page gallery download; delete 10 image files via Files.app; run "Validate Image Data" in the download inspector; attempt to start the .repair re-download; force-quit, relaunch, re-inspect.
started: Discovered during UAT 2026-08-08 on physical iOS 26 device; targets the .repair route added this phase.

## Eliminated

- hypothesis: "Validation mutates per-page states to pending (a write that then gets lost)"
  evidence: "storage.validate (DownloadStore+Operations.swift:209) is pure read-only; the 'pending' the user saw is DERIVED at inspection time by buildInspectionPages from live file presence (missing file, no recorded failure → .pending). Validation writes nothing but validationErrors[gid]."
  timestamp: 2026-08-08

- hypothesis: "Relaunch overwrites a persisted pending-page state"
  evidence: "Nothing pending-shaped is ever persisted. The manifest's page hashes (the only durable page state) are untouched by validation; relaunch re-derives .completed from those intact hashes. Nothing is overwritten — the transient marker (validationErrors) simply dies with the process."
  timestamp: 2026-08-08

- hypothesis: "A repair-start affordance exists but is wrongly disabled by a predicate bug"
  evidence: "No repair-start affordance exists for this state anywhere: inspector has exactly 3 actions (Pause/Retry-Failed/Validate; DownloadsView+Subviews.swift:63-96); Downloads row/context menu offer no retry (canRetry at DownloadedGallery+SupportTypes.swift:57 has ZERO consumers — dead code); Detail's .error button exists but routes to destructive .redownload because downloadNeedsRepair demands completedPageCount == 0."
  timestamp: 2026-08-08

- hypothesis: "The design expects validation to auto-enqueue the repair and the enqueue silently fails"
  evidence: "validateImageData (DownloadClient+PersistenceNormalize.swift:90-110) contains no enqueue, no scheduling call, nothing but the dictionary write + notifyObservers. No auto-enqueue was ever designed at this seam."
  timestamp: 2026-08-08

## Evidence

- timestamp: 2026-08-08
  checked: "DownloadClient+PersistenceNormalize.swift:90-110 (validateImageData) + DownloadStore+Operations.swift:209-311 (storage.validate)"
  found: "Validate is a read-only probe. On missingFiles it writes validationErrors[gid] = DownloadFailure(code: .fileOperationFailed) — an in-memory actor dictionary (DownloadClient+Manager.swift:430) — and notifies observers. Doc comment: 'The result is session-scoped status (validationErrors), not persisted.' Manifest hashes are never blanked."
  implication: "The durable source of truth still claims 36/36 complete. Everything downstream flows from this."

- timestamp: 2026-08-08
  checked: "DownloadClient+Persistence.swift:90-114 (displayStatus derivation)"
  found: "Priority order: validationErrors → .error; activeGalleryID → .active; queueStore → .queued; manifest.isComplete → .updateAvailable/.completed; downloadErrors → .error; else .inactive. Post-validate (same session): .error. Post-relaunch (validationErrors empty, hashes intact): .completed."
  implication: "The yellow badge (DownloadedGallery+Extensions.swift:11, .error → .yellow) exists only while the process lives. Also: validationErrors outranks queueStore, so any future enqueue-with-uncleared-validation-error would read .error, never .queued → shouldSchedule false → unstartable; every existing enqueue path (resume, performRetry, performRetryPages) clears it first, and a fix must too."

- timestamp: 2026-08-08
  checked: "Inspector action gating — DownloadsView+Subviews.swift:59-96, DownloadedGallery+SupportTypes.swift:57-115, DownloadInspection.swift:46-48, buildInspectionPages (DownloadClient+PublicAPIHelpers.swift:18-51)"
  found: "Pause: canTogglePause = displayStatus in [.active,.inactive,.queued] → false at .error. Retry Failed Pages: canRetryFailedPages = pages with status .failed — but externally-deleted pages derive .pending (file absent, no entry in failedPageErrors since no download attempt ever failed) → disabled. Validate: canValidateImageData = [.completed,.updateAvailable].contains(status) || lastError?.code == .fileOperationFailed — the second disjunct is TRUE post-validate (lastError = the validationErrors entry) → the only enabled action re-runs validation. Circular dead end."
  implication: "Sub-defect 1 mechanism complete: the post-validate state (.error + 0 failed pages + complete-claiming manifest) satisfies no start gate."

- timestamp: 2026-08-08
  checked: "togglePause client path — DownloadClient+PublicAPI.swift:173-199"
  found: "switch displayStatus: .completed/.error/.updateAvailable → .failure(.unknown). Even an enabled Pause/Resume would hard-fail for this state."
  implication: "The dead end is enforced at both the view gate and the client."

- timestamp: 2026-08-08
  checked: "Detail surface — DetailView.swift:253-268 (handleDownloadAction), DetailReducer.swift:93-97 (downloadNeedsRepair), DetailView+HeaderSection.swift:292-303"
  found: ".completed → delete only (trash). .error → retryDownloadButtonTapped(downloadNeedsRepair ? .repair : .redownload); downloadNeedsRepair = badge.status == .error && completedPageCount == 0 && failureCode == .fileOperationFailed. Here completedPageCount == 36 (manifest claim) → FALSE → button offers destructive .redownload (deletes folder, refetches all 36). performRetry pins queuedModes[gid] = .redownload explicitly, bypassing the client's own repair resolution."
  implication: "No surface anywhere offers the non-destructive .repair for this state. downloadNeedsRepair's completedPageCount == 0 condition only holds after a run's blanking loop (D-G5-01) has already run — i.e., after a repair already started; it can never hold at the validate-discovers-missing moment."

- timestamp: 2026-08-08
  checked: "Client mode-resolution intent — DownloadClient+SchedulingHelpers.swift:6-36 (queuedMode), :38-69 (resumeMode); DownloadClient+RetryHelpers.swift:45-95 (retryPages)"
  found: "queuedMode's fallback branch '.error where lastError?.code == .fileOperationFailed → .repair' resolves exactly this state correctly — but it is only consulted (Execution.swift:29) for a gallery ALREADY enqueued without an explicit intent (relaunch-interrupted shape); every UI enqueue path writes an explicit queuedModes entry first. Meanwhile retryPages(gid:pageIndices:) already implements the exact needed repair-starter: clears failure state (incl. validationErrors via clearDownloadFailureState), sets queuedModes = .repair with a page selection, enqueues, schedules. The inspector merely never routes .pending pages into it — DownloadInspectorReducer hardcodes retryPages(inspection.failedPageIndices)."
  implication: "The design intent (validation error → repair) exists in mode resolution, and the machinery to start it exists in retryPages; only the affordance wiring is missing."

- timestamp: 2026-08-08
  checked: "Count bases — DownloadedGallery+Manifest.swift:67-73, DownloadedGallery+SupportTypes.swift:31-39, buildInspectionPages"
  found: "Basis A (badge '36 / 36'): manifest.completedPageCount = count of NON-EMPTY HASH VALUES in the persisted manifest — the record's claim; untouched by external file deletion. Basis B (inspector '10 pending'): buildInspectionPages scans the live filesystem per page (existingPageRelativePaths + fileExists). The two disagree exactly when files vanish outside the app and no run has blanked hashes. Both render side-by-side inside the inspector (badge in header cell vs page groups)."
  implication: "Sub-defect 3 is a two-bases divergence: persisted hash-claim vs live file scan. Named write sites: hashes written by refreshManifestPageFileHashes (monotone upward, never blanked outside a run); blanking happens ONLY in reconcileWorkingManifestAgainstPageFiles inside prepareWorkingSeed — i.e., only after a repair run starts, which this state cannot start."

- timestamp: 2026-08-08
  checked: "Shape sweep per phase lessons"
  found: "ALL-pages-missing shape: identical dead end (validation → .error; all pages .pending; Detail still sees completedPageCount == 36 claim → .redownload only). Paused-gallery shape: not reachable — canValidateImageData excludes .inactive without a fileOperationFailed error, and a genuinely-incomplete inactive record already resumes to .repair via resumeMode's isIncomplete branch (the working path). Historical note: the doc comment 'It closes G-15-5' on the blanking loop (ExecutionSupport.swift:540) refers to an EARLIER same-numbered gap (record reading complete DURING a repair run); D-G5-01 deliberately runs only at run preparation and was never wired to validation time — the current G-15-5 is the validate-time hole beside it."
  implication: "One root cause, not three; the dead end is state-shape-complete, not branch-specific."

## Resolution

root_cause: "Validate Image Data records its missingFiles verdict only in the coordinator's in-memory `validationErrors` dictionary and never reconciles the persisted manifest, whose page hashes still claim all 36 pages. This single state — displayStatus .error (transient) over a complete-claiming record — produces all three observed defects: (1) no start affordance, because every gate keys on shapes this state never has (Pause needs .active/.inactive/.queued; Retry Failed Pages needs .failed pages, but externally-deleted pages derive .pending; Detail's repair needs completedPageCount == 0, but the claim is 36; the only enabled inspector action is Validate itself — a circular dead end — and togglePause would hard-fail .error anyway); (2) relaunch loses the yellow state, because validationErrors dies with the process and displayStatus re-derives .completed from the intact hash claims; (3) '36 / 36' vs '10 pending', because the badge counts persisted non-empty hashes while the inspector's page groups scan live file presence — two independent bases that diverge whenever files vanish outside the app and no run has blanked the hashes (blanking exists only inside prepareWorkingSeed, reachable only after a repair starts, which this state cannot)."
fix: "(direction only — diagnose-only mode) Preferred root fix: on a missingFiles validation verdict, durably reconcile the manifest by blanking the missing pages' hashes with the same positive-signal-guarded blanking discipline D-G5-01 already uses (reconcileWorkingManifestAgainstPageFiles / its guards): the record then honestly reads isIncomplete → displayStatus .inactive → Resume enables → resumeMode resolves .repair; the state survives relaunch and both count bases converge (26/36). Alternative/additive affordance fix: surface a repair-start in the inspector — retryPages(gid:pendingAndFailedIndices) already clears validationErrors, pins .repair with a page selection, enqueues and schedules; widen the Retry action's basis beyond .failed for the .error/fileOperationFailed shape. Constraint for any fix: validationErrors outranks queueStore in displayStatus, so the chosen path must clear validationErrors at/before enqueue (all existing enqueue paths do). Also worth sweeping: downloadNeedsRepair's completedPageCount == 0 basis, and dead canRetry."
verification: "Not performed (goal: find_root_cause_only)."
files_changed: []
