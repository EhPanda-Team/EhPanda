---
phase: 15
slug: continued-background-downloads
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-28
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `15-RESEARCH.md` § Validation Architecture. Task IDs are filled in by
> `/gsd-validate-phase` once plans exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (bundled with Xcode 26.6) |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` (22 targets, includes `DownloadsFeatureTests` and `AppFeatureTests`) |
| **Quick run command** | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DownloadsFeatureTests` |
| **Full suite command** | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone 17'` |
| **Estimated runtime** | ~50 seconds (full suite) |

**Two standing execution constraints:** run **one** `xcodebuild test` invocation at a time —
overlapping runs, or `pkill`-ing one mid-launch, wedges `testmanagerd`. And `xcodebuild`
buffers stdout until exit, so silence is not a hang.

---

## Sampling Rate

- **After every task commit:** quick run command (`-only-testing:DownloadsFeatureTests`) plus a
  clean app-scheme build, which runs SwiftLint via the build plugin
- **After every plan wave:** full suite command (`FeatureTests` plan)
- **Before `/gsd-verify-work`:** full suite green, all grep gates at zero, then the owner's
  device UAT for SC1/SC2
- **Max feedback latency:** ~50 seconds

---

## Per-Task Verification Map

Task IDs are TBD until plans are written; the rows below are the behavior contract each plan
task must map onto.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | SC1 | — | A D-07 tap starts exactly one session when work is pending | unit | `… -only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC1 | — | A second D-07 tap while a session is live starts no second session (D-06/D-08) | unit | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC1 | — | No session started when `hasPendingWork()` is false | unit | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC1 | — | Session completed with `success: true` when the queue drains via `scheduleNextIfNeeded()` | unit | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC1 | — | Session **not** completed on foreground return (D-08) | unit | `… -only-testing:AppFeatureTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC1 | — | A large queue outlasts the old grace window after backgrounding | **manual (device)** | — owner device scenario | n/a | ⬜ pending |
| TBD | TBD | TBD | SC2 | — | Card progress = completed/total pages across schedulable galleries; totals recompute when a gallery joins (D-10/D-06) | unit | spy records `(completed, total)` pairs; frozen `now:` clock | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC2 | — | `completedUnitCount` never regresses within a session | unit | same suite | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC2 | — | `.expired` pauses **every** schedulable gallery with in-app pause semantics (D-11) | unit | assert `displayStatus` + `schedulingBlockedGalleryIDs` match a per-gallery `pause(gid:)` baseline | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC2 | — | Card renders real progress and its cancel affordance stops the queue | **manual (device)** | — | n/a | ⬜ pending |
| TBD | TBD | TBD | SC2 | T-15 privacy | Card carries **no** gallery title/tag text (D-09) | unit + manual | assert strings passed to `start`/`updateProgress` contain only counts; device screenshot confirms | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC3 | — | `.unavailable` produces no reducer action, no `AppError`, no toast | unit | TestStore receives nothing | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC3 | — | Queue state after `.unavailable` is identical to the no-session path (no lost/duplicated work) | unit | run same queue with `.noop` vs `.unavailable` client, compare manifests | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC4 | — | `testValue` unimplemented — an unexpected call fails the test loudly | unit | construct coordinator with `BackgroundProcessingClient()`, assert issue reported | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SC4 | — | No `BGTaskScheduler` reference in Swift sources outside the client module | static | `grep -rn --include='*.swift' "BGTaskScheduler" App AppPackage ShareExtension \| cut -d: -f1 \| sort -u` returns exactly the client-module paths | ✅ | ⬜ pending |
| TBD | TBD | TBD | SC4 | — | The plist's only scheduler mention is the permitted-identifiers key it must keep | static | `grep -c "BGTaskScheduler" App/Info.plist` and `grep -c "BGTaskSchedulerPermittedIdentifiers" App/Info.plist` both return `1` | ✅ | ⬜ pending |
| TBD | TBD | TBD | — | — | Existing scheduling behavior unchanged | regression | `… -only-testing:DownloadsFeatureTests/DownloadSchedulingTests` | ✅ exists | ⬜ pending |
| TBD | TBD | TBD | — | — | `hasPendingWork()` still reflects queue state | regression | `… -only-testing:DownloadsFeatureTests` (`testHasPendingWorkReflectsQueueState`) | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**`DownloadSchedulingTests` must stay green.** It was flaky and was made deterministic; a
failure there is a real regression, not flake.

**Why the SC4 static gate is split in two.** `App/Info.plist` must keep the key
`BGTaskSchedulerPermittedIdentifiers` for the phase to work at all, and that key's *name*
contains the scheduler type name as a substring by construction. A single unrestricted
`grep -rn "BGTaskScheduler" App AppPackage` can therefore never return only client-module hits,
however correct the code is — it would be an unsatisfiable gate, not a strict one. The first
row scopes the module assertion to Swift sources; the second pays for that exemption with a
stricter check on the exempted file, requiring its scheduler mentions and its
permitted-identifiers-key mentions to be equal and to be exactly one. Nothing can hide behind
the exemption, and the plist stays fully in scope for every other gate — including the
`downloads.processing` / `downloads.assertion` zero-gates, which is where a regression there
would surface first.

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` — session
      lifecycle, progress, expiration → pause-all (replaces `DownloadBackgroundAssertionTests.swift`)
- [ ] `BackgroundProcessingClientSpy` — `Mutex`-backed recorder plus a controllable event
      continuation (model on `BackgroundTaskClientSpy`, already `Sendable` + `Mutex`)
- [ ] Repoint/prune `DownloadBackgroundProcessingTests.swift` — rename; drop the
      `runQueueUntilIdle` and `AppReducer` `.background` cases; keep `hasPendingWork`
- [ ] `DownloadAutomationTests.swift:49` — drop the `hasPendingWork` façade override
- [ ] `testingHasContinuedSession()` in `DownloadClient+Testing.swift` (replaces
      `testingHasBackgroundAssertion()`)
- [ ] Framework install: none — Swift Testing and the `FeatureTests` plan already exist

The existing `makeBlockingCoordinator` helper (in `DownloadBackgroundAssertionTests.swift`)
builds a coordinator whose single queued download blocks forever — the fixture the
session-lifecycle tests need. Preserve it when that file is replaced.

---

## Manual-Only Verifications

The iOS SDK states the Simulator does not support background processing, so every
system-granted behavior is device-only. This is inherent to the API, not a coverage gap.

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A queued download outlasts the old grace window after backgrounding | SC1 | System must actually grant the session; unsupported in Simulator | Steps 1–4 below |
| System card shows real progress with neutral strings | SC2 | Card is system UI outside the app process | Steps 3–5 below |
| Card cancel leaves the queue paused, identical to in-app pause | SC2 | Cancel arrives only from real system UI | Step 6 below |
| No crash / no duplicated pages after force-quit mid-session | SC1 | Process lifecycle not reproducible in unit tests | Step 7 below |

**Device observation script (owner-run, iOS 26 device):**

1. Queue ≥ 3 galleries totalling ≥ 300 pages.
2. Tap start; confirm downloads begin **immediately** (work must not wait on the session).
3. Background the app. Confirm the system card appears with the neutral title + count
   subtitle and **no gallery title**.
4. Leave backgrounded past ~60s (comfortably beyond the old `beginBackgroundTask` window).
   Confirm the card's counts advance.
5. Foreground; confirm the card persists (D-08) and in-app progress matches the card.
6. Background again, tap **cancel** on the card. Foreground; confirm every gallery is
   Paused, identical to having tapped pause on each.
7. Separately: force-quit from the app switcher mid-session and relaunch; confirm no crash
   and no duplicated pages.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] Device observation script run by the owner for SC1/SC2
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
