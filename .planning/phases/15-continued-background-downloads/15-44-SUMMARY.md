---
phase: 15-continued-background-downloads
plan: 44
subsystem: downloads
tags: [documentation, source-census, swift-testing, background-tasks, scheduling]

requires:
  - phase: 15-continued-background-downloads
    provides: "the schedulableDownloads() read, its active-gallery union (WR-01), the G-15-8 release-then-converge paragraph, and the DownloadSourceInventoryTests census pattern established by 15-40"
provides:
  - "A schedulableDownloads() header that names its three actual callers, locates the scheduler's own scoped read, and explains why the read-scope divergence is inert"
  - "A G-15-8 paragraph whose blocked-gid claim covers both the shared readers and the scheduler's same-predicate scoped read, with no single-authority wording left"
  - "A device-verified post-launch registration note beside ContinuedTaskScheduling.live.register, citing 15-UAT.md test 1 and the bundle-scoped wildcard"
  - "testSchedulableDownloadsCallSitesMatchTheRecordedCensus — a drift-failing census that owns the corrected caller list"
affects: [scheduling-liveness fixes, continued-session card work, any future BGTaskScheduler registration change]

tech-stack:
  added: []
  patterns:
    - "A corrected doc census is paired with a drift-failing equality in DownloadSourceInventoryTests rather than left unowned"
    - "A device-proven system-scheduler contract fact is recorded at its call site in the App/Info.plist note shape (structural impossibility + device evidence + asymmetry)"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift

key-decisions:
  - "schedulableDownloads() is documented as the SHARED READ for three named callers, not as an authority the scheduler reads; what the scheduler shares is the isSchedulableDownload predicate."
  - "The read-scope divergence (the active-gallery union) is documented as inert with its two supporting facts — the guard activeTask == nil early return, and the synchronous pairing of every activeGalleryID assignment with its activeTask assignment — plus the standing re-validation condition."
  - "WR-02's registration-timing concern is answered with a note, not a code change: the design is device-proven by 15-UAT.md test 1 and pre-launch registration is structurally impossible under a per-session UUID identifier."
  - "The census counts per-file AND a separately-counted joined total; the observed RED proved the per-file table is the half that catches a same-file drift."

patterns-established:
  - "Doc-census ownership: every caller list a load-bearing comment carries gets a DownloadSourceInventoryTests equality with a fragment-assembled token, a known-member guard, and both a per-file table and a joined total."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "The schedulableDownloads() header names its three real callers, locates scheduleNextIfNeededCore's own scoped read, states that only the predicate is shared, and explains why the active-gallery divergence is inert"
    requirement: "SC1"
    verification:
      - kind: other
        ref: "grep -c 'all select through this' AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift -> 0"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testSchedulableDownloadsCallSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D2
    description: "The G-15-8 paragraph's blocked-gid claim describes every schedulableDownloads() reader plus the scheduler's same-predicate scoped read, with no single-authority wording"
    requirement: "SC2"
    verification:
      - kind: other
        ref: "grep -c 'the scheduler all read' AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift -> 0; grep -c 'single authority' -> 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "The device-verified post-launch registration note stands beside ContinuedTaskScheduling.live.register, naming the wildcard entry, the per-session minting site, and 15-UAT.md test 1"
    verification:
      - kind: other
        ref: "grep -c '15-UAT' AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift -> 1; grep -c 'PRODUCT_BUNDLE_IDENTIFIER).continued' -> 1"
        status: pass
    human_judgment: false
  - id: D4
    description: "The corrected caller list is owned by a census that fails the build on drift"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testSchedulableDownloadsCallSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D5
    description: "No production behavior moved — every Sources edit is comment-only"
    verification:
      - kind: other
        ref: "git diff -U0 -- AppPackage/Sources | grep -vE '^[+-]\\s*(///|//)' returned no changed executable line"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests (872 tests, 0 failures)"
        status: pass
    human_judgment: false

duration: 29min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 44: Read-authority corrections, the registration note, and a caller census Summary

**`schedulableDownloads()` is now documented as the shared read of three named callers with the scheduler's own scoped read located beside it, the post-launch `BGTaskScheduler.register` exemption is recorded at its site with its device evidence, and a drift-failing census owns the caller list that was false in two files for five rounds.**

## Performance

- **Duration:** 29 min
- **Started:** 2026-08-05T15:47:00Z
- **Completed:** 2026-08-05T16:16:14Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Both "one authority" sites corrected from a fresh enumeration rather than from the gap record's wording, each stating what is genuinely shared (the `isSchedulableDownload` predicate) and where the scheduler's own read lives.
- The inert-divergence reason recorded with BOTH of its supporting facts, the second of which the gap record did not state: the `guard activeTask == nil` early return, and the fact that every production non-`nil` `activeGalleryID` assignment sits in the same synchronous step as its `activeTask` assignment.
- The device-proven post-launch registration exemption recorded beside `live.register` in the `App/Info.plist` note shape, so WR-02's question is answered at the site instead of re-opened from the same absence.
- `testSchedulableDownloadsCallSitesMatchTheRecordedCensus` added, and its RED observed by perturbation rather than asserted.

## Fresh enumerations (the derivation every corrected sentence stands on)

### 1. `schedulableDownloads()` across `AppPackage/Sources`, classified

`grep -rn "schedulableDownloads" AppPackage/Sources` at the pre-edit HEAD (`94e67ad9`) returned 11 matches:

| Location | Classification |
|---|---|
| `+PendingWork.swift:42` | **declaration** (`func schedulableDownloads() async -> [DownloadedGallery]`) |
| `+PendingWork.swift:14` | **call site** — `hasPendingWork()`, the pending-work gate |
| `+ContinuedSession.swift:145` | **call site** — `schedulableSnapshot()`, the card's session snapshot |
| `+ContinuedSession.swift:396` | **call site** — `pauseAllSchedulable(expiring:)`, the expiration sweep |
| `+Manager.swift:387` | doc mention (the false single-authority claim; corrected here) |
| `+Scheduling.swift:230` | doc mention |
| `+ExecutionSupport.swift:233` | doc mention |
| `+Folders.swift:158` | doc mention |
| `+ContinuedSession.swift:201` | doc mention |
| `+ContinuedSession.swift:389` | doc mention |
| `+ContinuedSession.swift:450` | doc mention |

**Three call sites; the declaration; seven doc mentions.** Note the line numbers differ from the ones the G-15-24 record cites (`+ContinuedSession.swift:122` and `:357`): 15-42 and 15-43 shifted that file, which is exactly why the enumeration was re-run instead of trusted. The SET of callers is unchanged.

`scheduleNextIfNeededCore` is not among them. Read fresh at `+Scheduling.swift:38-67`:

```swift
private func scheduleNextIfNeededCore() async {
    let queuedGIDs = queueStore.gids
    let downloads = queuedGIDs.isEmpty
        ? await indexedDownloads()
        : await indexedDownloads(gids: queuedGIDs)
    await taskRunner.beforeActiveTaskCheck()
    guard activeTask == nil else {
        await reconcileActiveDownloadState()
        return
    }
    let nextDownload = queuedGIDs.isEmpty
        ? nextUnqueuedSchedulableDownload(from: downloads)
        : nextQueuedDownload(orderedGIDs: queuedGIDs, downloads: downloads)
    ...
```

It performs its own read (`queueStore.gids` → `indexedDownloads()` / `indexedDownloads(gids: queuedGIDs)`) and reaches `isSchedulableDownload` through `nextQueuedDownload` (`:93`) and `nextUnqueuedSchedulableDownload` (`:103`). **The predicate is shared; the read scope is not.**

### 2. Why the divergence is inert — derived, not copied

The divergence is `+PendingWork.swift:45-47`, the active-gallery union, which the scheduler's queue-scoped read does not carry. The gap record gives one reason (the `guard activeTask == nil` return). Enumerating the writers gives the second half, which the record does not state:

```
+Scheduling.swift:59-60     activeGalleryID = nextDownload.gid ; activeTask = Task { ... }   (only non-nil assignment)
+Scheduling.swift:297-298   activeTask = nil ; activeGalleryID = nil
+Execution.swift:252-253    activeTask = nil ; activeGalleryID = nil
+Folders.swift:106-107      activeTask = nil ; activeGalleryID = nil
+PublicAPI.swift:207-208    activeTask = nil ; activeGalleryID = nil
+PersistenceNormalize.swift:71  activeGalleryID = nil  (only when !hasActiveTask — the reverse pairing)
+Testing.swift:19-20, :24   DEBUG-only test seam
```

Every pair is adjacent and synchronous, so no actor reentrancy can observe a non-`nil` `activeGalleryID` without a live `activeTask`. A gallery the union would add is therefore a gallery whose active task has already turned that scheduler pass back at the guard. Both halves are stated in the corrected header, with the re-validation condition (remove the guard, or let `activeGalleryID` outlive its task).

### 3. `BGTaskScheduler` single-file verdict — CONFIRMED

`grep -rn "BGTaskScheduler" AppPackage/Sources App/ ShareExtension/` returned four matches, all in `ContinuedTaskScheduling.swift` (`:64` `cancelAllTaskRequests`, `:67` `register`, `:90` `submit`, `:93` `cancel`), plus `App/Info.plist:5` (`BGTaskSchedulerPermittedIdentifiers`). `App/` contains exactly one Swift file (`EhPandaApp.swift`) and it names no scheduler API; `AppDelegateReducer.swift` registers nothing.

### 4. `register` caller trace and the identifier's minting site

`scheduling.register` has exactly one call site: `ContinuedProcessingSession.swift:141`, inside `start(title:subtitle:completedUnitCount:totalUnitCount:)`. The identifier it registers is minted two lines above at `:139`:

```swift
let identifier = "\(bundleIdentifier).continued.\(UUID().uuidString)"
```

`App/Info.plist:5-8` permits exactly one pattern:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER).continued.*</string>
</array>
```

A fresh UUID per session means no concrete identifier exists before a session starts — pre-launch registration is structurally impossible, not merely unimplemented.

### 5. 15-UAT.md test 1, read fresh

> **1. Backgrounded queue outlasts the old grace window** — test: on a physical iOS 26 device, queue at least three galleries totaling at least 300 pages, start in the foreground, background the app for more than 60 seconds, then foreground and compare persisted page counts against the queue. expected: pages keep landing while backgrounded, well past the old grace window; no page lost or duplicated. **result: pass**

That outcome is reachable only if the post-launch registration was honoured and the system launched the task. The note cites exactly these facts and claims nothing beyond them.

## Corrections, before and after

### Site 1 — `DownloadClient+PendingWork.swift` header

**Before:**

> The one authority for selecting work the scheduler can run.
>
> Scheduling, the pending-work gate and the continued-session card all select through this function, so queue lifetime and reported counts cannot acquire separate definitions.

**After:**

> The shared read behind every consumer that asks what work is schedulable right now.
>
> It has exactly three call sites — the pending-work gate (`hasPendingWork()`, just above), the continued-session card's snapshot (`schedulableSnapshot()`) and the expiration sweep (`pauseAllSchedulable(expiring:)`) — so queue lifetime and the card's reported counts cannot acquire separate definitions. That list is owned rather than asserted: `DownloadSourceInventoryTests` counts these call sites and fails when one is added or removed, because this sentence has now been wrong twice in a doc nothing checked.
>
> **The scheduler is NOT one of those callers (G-15-24).** `scheduleNextIfNeededCore` (`+Scheduling.swift`) performs its own read — `queueStore.gids`, then `indexedDownloads()` or `indexedDownloads(gids: queuedGIDs)` — and reaches `isSchedulableDownload` through `nextQueuedDownload` / `nextUnqueuedSchedulableDownload`. What the two share is the PREDICATE, not the read scope, so widening or narrowing THIS read does not move the scheduler with it.
>
> The divergence is the active-gallery union below, which the scheduler's queue-scoped read does not carry. It is inert today, for a reason that must be re-checked the moment either half changes: `scheduleNextIfNeededCore` selects nothing behind its `guard activeTask == nil`, and the only production assignment of a non-`nil` `activeGalleryID` sits in the same synchronous step as the `activeTask` assignment while every clear of `activeTask` clears the gid alongside it — `normalizeInterruptedDownloads` only ever clears the reverse pairing, a gid whose task is already gone. So a gallery this union would add is one whose active task has already turned that scheduler pass back at the guard. Removing the guard, or letting `activeGalleryID` outlive its task, re-opens the question.

The WR-01 union rationale paragraph below it is untouched — it is true and load-bearing.

### Site 2 — `DownloadClient+Manager.swift`, the G-15-8 paragraph

**Before:**

> A gid left blocked is invisible to `schedulableDownloads()` — the single authority the card, the pending-work gate and the scheduler all read — so a convergence landing inside that window can declare the queue drained over work that is merely hidden, and an exit that releases without converging leaves the gallery queued and idle with no fallback tier to restart it (D-03).

**After:**

> A gid left blocked is invisible to every `schedulableDownloads()` reader — the pending-work gate, the continued-session card's snapshot and the expiration sweep — because `isSchedulableDownload` fails on a held block before it asks anything else. `scheduleNextIfNeededCore` does not read through that function, but it applies the same predicate to its own queue-scoped read, so the blocked gid is skipped there too. A convergence landing inside that window can therefore declare the queue drained over work that is merely hidden, and an exit that releases without converging leaves the gallery queued and idle with no fallback tier to restart it (D-03).

The "because `isSchedulableDownload` fails on a held block before it asks anything else" clause is derived from `+Scheduling.swift:118-123` (`schedulingBlockedGalleryCounts[download.gid] == nil && shouldSchedule(download:)`), read fresh; the surrounding release-then-converge rule is untouched.

### Site 3 — the registration note (new), beside `ContinuedTaskScheduling.live.register`

> Registration happens POST-LAUNCH, at the first session start, and cannot be moved to launch. `ContinuedProcessingSession.start` mints the identifier per session as `"\(bundleIdentifier).continued.\(UUID().uuidString)"` — a fresh UUID every time, because a handler can never be unregistered and a second registration of one identifier kills the app — under the `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` wildcard declared in App/Info.plist's `BGTaskSchedulerPermittedIdentifiers`. No concrete identifier exists before a session starts, so there is nothing to register at `didFinishLaunching`, and this closure has exactly one caller.
>
> The design is device-proven rather than merely unfalsified: 15-UAT.md test 1 reads `result: pass` on physical iOS 26 hardware, with pages continuing to land well past the deleted 60-second grace window — an outcome reachable only if this post-launch registration was honoured and the system actually launched the task.
>
> The failure modes are asymmetric, as with the UIBackgroundModes note in App/Info.plist: moving registration earlier is structurally impossible under a per-session identifier, while re-raising the lazy-registration concern without new device evidence re-opens a question this record already answers.

## The census, derived and reconciled

Token: `schedulableReadToken = "schedulable" + "Downloads()"`, fragment-assembled on the file's `schedulingBlockCallToken` idiom, so a repository grep gate counting the inventory cannot match the suite that pins it. It reuses `callSiteCount` unchanged, which drops every comment line and every line containing `"func " + token` — so the declaration and all seven doc mentions are excluded and only calls count.

Derived expectation:

| File | Calls |
|---|---|
| `DownloadClient+ContinuedSession.swift` | 2 (`schedulableSnapshot`, `pauseAllSchedulable`) |
| `DownloadClient+PendingWork.swift` | 1 (`hasPendingWork`) |
| **joined total** | **3** |

**Reconciliation against Task 1's docs:** the derived census agrees with the corrected sentences exactly — three call sites, in the two files the header names, with the scheduler absent. No doc sentence needed fixing in Step 2, and no discrepancy was found. It also agrees with the verification's enumeration (one in the pending-work gate, two in the continued-session file) despite that record's stale line numbers, which is the distinction that mattered: the SET was right, the positions were not.

**Falsifiability — observed, not argued.** The census asserts current source, so no honest RED exists at HEAD. Instead the equality was perturbed and the failure observed: setting the `DownloadClient+ContinuedSession.swift` entry to `3` produced

```
✘ Expectation failed: (callSites → ["DownloadClient+PendingWork.swift": 1, "DownloadClient+ContinuedSession.swift": 2])
  == (Self.expectedSchedulableReadCallSites → ["DownloadClient+ContinuedSession.swift": 3, "DownloadClient+PendingWork.swift": 1])
```

then the perturbation was reverted and the case re-ran green. The three real drifts the case catches:

1. **The scheduler gains this read** — a new key appears (`DownloadClient+Scheduling.swift`), so the per-file table breaks AND the joined total moves to 4.
2. **A fourth reader appears** — either a new key or an incremented existing key; the joined total moves either way.
3. **A caller is removed** — a key drops to a lower value or vanishes; both halves move.

The perturbation above is the same shape as case 2-within-one-file, and it is the case where the joined total (still 3) does **not** move — proving the per-file table is not redundant with it.

## Task Commits

1. **Task 1: correct both authority claims and record the registration note** — `dd9fc9ec` (docs)
2. **Task 2: pin the corrected caller list with a call-site census** — `8a909db6` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` — header rewritten: three call sites named, the scheduler's own read located, the shared predicate stated, the inert divergence explained with its re-validation condition, the census pointed at.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — the G-15-8 paragraph's single-authority parenthetical replaced with the reader list plus the scheduler's same-predicate scoped read.
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` — device-verified post-launch registration note added beside `live.register`.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — `schedulableReadToken`, `expectedSchedulableReadCallSites`, `expectedSchedulableReadCallTotal` and `testSchedulableDownloadsCallSitesMatchTheRecordedCensus` (312 lines total, well under the 1000-line lint ceiling).

## Decisions Made

- Documented `schedulableDownloads()` as a shared READ with three named callers rather than as any kind of authority, because "authority" is what invited the scheduler into the sentence twice.
- Kept the second half of the inertness argument (the synchronous `activeGalleryID`/`activeTask` pairing) even though the gap record did not state it — without it, "the guard returns whenever an active gallery exists" is an assertion the reader cannot check.
- Answered WR-02 with a note only. The plan's prohibition and the round-13 scope note both forbid a registration-timing change, and the device record refutes the concern.
- Placed the note on the `register` closure inside `live` rather than on the `ContinuedTaskScheduling` type, so a reader arriving at the registration call reads it without navigating.

## Deviations from Plan

None - plan executed exactly as written.

Two plan-stated line references were found stale and re-derived rather than followed, which is the behavior the plan mandated rather than a deviation: the G-15-24 record cites the `schedulableSnapshot()` and `pauseAllSchedulable` call sites at `+ContinuedSession.swift:122` and `:357`, and they now sit at `:145` and `:396` after 15-42 and 15-43. The caller SET is unchanged.

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No production behavior change; every Sources edit comment-only | **held** | `git diff -U0 -- AppPackage/Sources` filtered for non-`//` changed lines returned nothing; 49 insertions / 8 deletions, all comment lines |
| No registration-timing change | **held** | `ContinuedTaskScheduling.swift` diff is 18 added comment lines and nothing else |
| No sentence written from the gap record's wording alone | **held** | Every corrected sentence traces to an enumeration above; two of the record's own line numbers were found stale by that process |
| No lint or concurrency escape hatch; no weakened or deleted case | **held** | SwiftLint `--strict` clean on all four files, 0 violations; no `swiftlint:disable` anywhere in the diff; the census is additive — no existing case touched |

## Verification

- **Comment-only proof:** `git diff -U0 -- AppPackage/Sources | grep -E '^[+-]' | grep -vE '^[+-]\s*(///|//)'` → empty.
- **Acceptance greps:** `all select through this` → 0; `the scheduler all read` → 0; `single authority` → 0; `15-UAT` in `ContinuedTaskScheduling.swift` → 1; `PRODUCT_BUNDLE_IDENTIFIER).continued` → 1; `testSchedulableDownloadsCallSitesMatchTheRecordedCensus` → 1.
- **Lint:** SwiftLint `--strict` on all four touched files — 0 violations, 0 serious. No line exceeds 120 characters.
- **Targeted run:** `-only-testing:DownloadsFeatureTests/DownloadSourceInventoryTests` — 3 tests, 3 passed, `** TEST SUCCEEDED **`.
- **Full run:** one `xcodebuild test -scheme EhPanda -testPlan FeatureTests` invocation — 872 tests, `** TEST SUCCEEDED **`, zero `✘` in the log (the 2 reported "known issues" are pre-existing `withKnownIssue` expectations, not failures).
- xcodebuild invocations never overlapped; the perturbation run was awaited to completion before the full run started.

## Issues Encountered

None. One process note: the perturbation run exceeded the 600-second foreground tool budget and was moved to the background; it was polled to completion (`until ! pgrep -f xcodebuild …`) before any further invocation, preserving the never-overlap rule.

## Threat Flags

None — the diff adds no network, auth, file-access or schema surface. The two registers in the plan's threat model (`T-15-44-01` doc-premise tampering, `T-15-44-02` note overstatement, `T-15-44-03` a future pre-launch registration move) are mitigated as planned: the census fails on caller drift, the note cites only verbatim UAT facts, and the structural impossibility plus the asymmetry are recorded at the site.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- G-15-24 is closed: both authority sites read true against fresh enumerations, the caller list is pinned by a drift-failing census, and the registration exemption is recorded with its device evidence.
- Remaining in phase 15: plan 15-45 (the G-15-25 hygiene group).
- Independent of the gap rounds, 15-UAT.md test 2 still needs its physical-device re-run on iOS 26 covering the `.redownload` route and a `.repair` gallery in a multi-gallery queue. Nothing in this plan discharges it.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — FOUND
- Commit `dd9fc9ec` — FOUND
- Commit `8a909db6` — FOUND

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
