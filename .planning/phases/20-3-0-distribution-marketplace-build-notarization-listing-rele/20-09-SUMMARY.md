---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "09"
subsystem: device-verification
tags: [device, ipad, iphone, release-build, gallery-detail, continued-processing, background-downloads, sc2]

requires: []
provides:
  - "`20-09-DEVICE.md`: the iPad Release cold-launch Gallery Detail check (10 of 10, no stall) and the iPhone repeat of Phase 15 SC2 (as designed), on owner hardware (DEV-18-01, SC7)"
  - "G-20-09-1, found here and then fixed (`94819b027` test, `4092bdddf` fix): a whole-gallery repair stopped after landing k pages now reads Paused k of N with Resume, by every stop route"
  - "The k = 0 residual, closed on direction (EhPanda msgs 2901 and 2903): K0-a (`0d99387a8`, `264c5d927`), B1 (`a0f54806c`, `ae1992b21`) and K0-c by the in-app Pause (`d2c7210c1`, `d47003bca`). A repair stopped before any page lands now reads Paused 0 of N with Resume, immediately or while queued, across a cold launch. G-15-2G kept: a record drops whole only when two independent fresh scans both find every claimed page absent"
affects: []

actuals:
  tokens: 160000
  tasks: 2
  commits: 13

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-09-DEVICE.md
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedRunWriteBackTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadWholesaleAbsenceTests.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+WholesaleAbsenceEvidence.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift

key-decisions:
  - "Both device checks were run entirely by the agent through the Device MCP app, with the owner's consent (owner msgs 2885 and 2887 for the iPad, owner msg 2893 for the iPhone). The owner tapped nothing."
  - "Only the owner's iPad mini and his test iPhone 11 were used. The build used his local signing, copied in for the build and removed afterwards, so no tracked file changed."
  - "G-20-09-1 was first filed, because this plan changes no code. It is not an SC2 failure: the card cancel and an in-app pause leave the same state. It was then fixed on direction, test first, by writing the run's on-disk progress back to the record at the run's exit. G-15-2G was not weakened, so a repair stopped before any page landed kept its pre-repair claim. That k = 0 residual was then closed on the product lead's direction (EhPanda msgs 2901 and 2903): the record drops whole only when two independent fresh scans both find every claimed page positively absent, which a single transient scan can never satisfy."

patterns-established:
  - "On a device under test, bring the app forward with `xcrun devicectl device process launch`. Device MCP's `launch_app` relaunches a running app, and that ends a continued-processing session."

requirements-completed: [DEV-18-01]

coverage:
  - id: D1
    description: "iPad: a Release build is cold-launched ten times; each opens a Home gallery's detail; a stall (more than 30 s) gets a sample and a recording"
    requirement: DEV-18-01
    verification:
      - kind: manual
        ref: "20-09-DEVICE.md Task 1: ten launch rows, detail shown in 3.66 to 5.88 s from the tap, no stall, no EhPanda crash, spin or hang report; screen-recorded"
        status: pass
    human_judgment: false
  - id: D2
    description: "iPhone: Phase 15 SC2 repeated on the same build (two galleries including a repair, background, the system card, cancel from the card, compared with pausing by hand)"
    requirement: DEV-18-01
    verification:
      - kind: manual
        ref: "20-09-DEVICE.md Task 2: three sessions, 23 card reads never going backward and all showing '· 2 galleries', three repairs climbing from their announce, two card cancels pausing every gallery, and the in-app pause baseline for a repair matching the card cancel; screen-recorded"
        status: pass
    human_judgment: false

duration: "device work about 15 min (Task 1) and 35 min (Task 2), plus builds and records"
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 09: the outstanding real-device checks Summary

**Both remaining real-device checks pass on owner hardware with the 3.0.0 (159) Release build.**

- **iPad:** the Phase 16 Gallery Detail stall did not come back in ten cold launches on an iPad mini (iPadOS 27.2).
- **iPhone:** a test iPhone 11 (iOS 27.2) behaved as Phase 15 designed for continued background downloads: the
  system card, repairs, and the card's cancel compared with pausing by hand.
- **One new observation, G-20-09-1, was found and then fixed.** A paused whole-gallery repair read "Downloaded N
  of N" until it was verified again. After the fix, a repair stopped after landing k pages reads "Paused k of N"
  with Resume. The k = 0 case was first left as a decided residual, then closed on the product lead's direction:
  a repair stopped before any page lands now reads "Paused 0 of N" with Resume too.
- The plan itself changed no code. The G-20-09-1 fix came afterwards, on direction: `94819b027` (test) and
  `4092bdddf` (fix). The k = 0 closure is three test-then-fix pairs: K0-a (`0d99387a8`, `264c5d927`), B1
  (`a0f54806c`, `ae1992b21`) and K0-c by the in-app Pause (`d2c7210c1`, `d47003bca`).

## Performance

- **Duration:** Task 1's device work ran from about 05:09Z to 05:20Z on 2026-11-09, and its record was committed
  at 05:21Z. Task 2's device work ran from about 06:06Z to 06:40Z. Builds and records took the rest of the time.
- **Completed:** 2026-11-09
- **Tasks:** 2 of 2
- **Files:** 1 created (`20-09-DEVICE.md`), plus this summary

## Accomplishments

- **Task 1: iPad Release cold launches (owner msgs 2885 and 2887).**
  - **Device and build:** an iPad mini (6th generation), iPadOS 27.2, running a Release build of `8fa2809cb`
    built with the owner's local signing.
  - **Launches:** ten launches, each opening the Home carousel's front gallery. The detail appeared in 3.66 to
    5.88 s from the tap (median 4.5 s), against a 30 s ceiling. There was no stall, so no stall sample was due.
  - **Crash check:** no EhPanda crash, spin or hang report.
  - **Reading:** the simulator-only stall from Phase 16 does not reproduce on real hardware, for this size and
    orientation.
- **Task 2: iPhone SC2 (owner msg 2893, card 2892).**
  - **Setup:** the same build on the owner's test iPhone 11, iOS 27.2. A whole-gallery repair fixture was made
    as in Phase 15 round 6: every image file deleted in Files.app, `manifest.json` kept.
  - **The card:** the system card "Downloading Galleries · N / M pages · 2 galleries" was read 23 times over two
    sessions. The count never went backward. The one plateau was a starved transfer, held by the bounded nudge,
    and each read showed "· 2 galleries".
  - **Repairs:** three repairs (27, 112 and 112 pages) climbed from their announce.
  - **Card cancels:** two cancels from the card paused every gallery in the queue. Afterwards Ix read Paused
    11 / 144, its state from pausing it by hand.
  - **Repair baseline:** the same repair was then paused by hand in the app and ended in exactly the state the
    card cancel left.
  - **Crash check:** no EhPanda crash report.
- **G-20-09-1 (found, then fixed).**
  - **What happened:** once a whole-gallery repair was paused, the row fell back to the record, and the record
    still claimed every page. The row showed "Downloaded N of N" with no Resume, while pages were missing.
  - **The cause:** the G-15-2G whole-gallery guard combined with the G-15-2F run overlay.
  - **What it is not:** an SC2 failure, because both pause routes agree.
  - **The fix:** when `processDownload` exits, it runs the preparation's own reconciliation over a fresh scan
    of the folder. This happens only while the run still owes pages and owns the gallery, inside a D-G7-01
    bracket. The failing test came first in `94819b027`, and the fix is `4092bdddf`.
  - **Tests:** before the fix, two of the three cases in `DownloadInterruptedRunWriteBackTests` failed (in-app
    pause and expiry). After it, `DownloadsFeatureTests` passed 562 of 562. Across the affected targets, 961
    passed, 6 were expected failures, and none of the 967 failed.
  - **On the device:** after an in-app Pause the row read Paused 14 / 112, and that survived a cold launch.
    After a card cancel it read Paused 26 / 112, with Resume both times.
  - **App termination:** there is no hook. The record keeps its stale claim until the next launch. Then the
    queue resumes the run, and its preparation reconciles the folder (Downloading 22 / 112).
  - **The residual (k = 0):** a repair paused before any page landed still read Downloaded 112 of 112 until
    Verify Images, because G-15-2G was kept as it was. It was closed afterwards, below.
- **The k = 0 residual (closed, EhPanda msgs 2901 and 2903).**
  - **K0-a:** a repair stopped after its run announced its measurement but before any page landed. The run-exit
    write-back passes the run's own positive absences as corroboration, so the whole-gallery guard stands aside
    only where the preparation's scan and the exit's fresh scan agree page by page.
  - **B1:** the stops with no run evidence, during the payload fetch (K0-b) and while queued (K0-c). Verify
    Images' full scan keeps "every claimed page positively absent" as in-memory evidence only. A stop consumes it
    once, and blanks only if the folder and claimed hashes are unchanged and its own fresh scan agrees. Delete,
    redownload or update, folder move, completion, a later Verify and relaunch drop the evidence, and a
    reappearing file makes the stop decline. Each drop has a test.
  - **Found on the device:** the in-app Pause of a queued repair cancels the queued work item instead of pausing
    it, so it never reached `commitPause` and still read Downloaded 112 of 112. `d2c7210c1` pins it and
    `d47003bca` runs the same write-back there.
  - **Tests:** `DownloadWholesaleAbsenceTests` 12 of 12. `DownloadsFeatureTests` ran 515: 509 passed, 6 were
    expected failures, and none failed.
  - **On the device (`d47003bca`):** Pause straight after Retry Pages, and Pause while queued behind Ix's
    repair, each read Paused 0 of 112 with Resume. Both survived a cold launch, and Resume finished M at
    112 / 112. Ix, the gallery ahead, ended at 144 / 144 rather than its August Paused 11 / 144.

## Task Commits

1. **Task 1: iPad Release cold launches** — `d7825a89e` (docs)
2. **Task 2: iPhone SC2** — `0e0e23269` (docs)
3. **Plan metadata** — `213d267cf` (docs)
4. **G-20-09-1 failing test** — `94819b027` (test)
5. **G-20-09-1 fix** — `4092bdddf` (fix)
6. **G-20-09-1 device check** — `06a4bee4c` (docs)
7. **K0-a failing test** — `0d99387a8` (test)
8. **K0-a fix** — `264c5d927` (fix)
9. **B1 failing tests** — `a0f54806c` (test)
10. **B1 fix** — `ae1992b21` (fix)
11. **K0-c in-app Pause failing test** — `d2c7210c1` (test)
12. **K0-c in-app Pause fix** — `d47003bca` (fix)
13. **k = 0 device check** — this record update (docs)

## Files Created/Modified

- `.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-09-DEVICE.md`: the device
  record for both checks: setup, consent, method, per-launch and per-step observations, verdicts, G-20-09-1, and
  where the local evidence is.

## Decisions Made

- **Everything was agent-driven.** The owner allowed both devices to be controlled through the Device MCP app,
  so the plan's "he does the device actions" became "the agent does them, he taps nothing". The plan's consent
  checkpoints were met by the owner messages above.
- **The in-app pause baseline for a repair was measured on the device.** It was not inferred from the code,
  because the card cancel left a result that needed comparing: Downloaded 112 of 112 with pages missing.

## Deviations from Plan

### Method

**1. [Method] Task 1 used Device MCP and `xctrace`, not `devicectl device process sample`.**
- **Why:** this devicectl has no `process sample` subcommand.
- **What was done instead:** the stall sample was planned as an `xctrace` Time Profiler attach. It was never
  needed, since no launch stalled.

**2. [Driver error] Round A of Task 2 ended without a card cancel.**
- **What happened:** the driver brought the app forward with Device MCP's `launch_app`. That relaunched the
  app, which ended the process and its session. iOS then showed a "Task failed" card.
- **What was done:** Rounds B and C repeated the cancel step, and every later foreground used
  `xcrun devicectl device process launch`.
- **Effect:** Round A's card and repair observations stand.

**3. [Found on device] The in-app Pause of a queued repair took a route the B1 tests did not drive.**
- **What happened:** the K0-c case paused through `pause(gid:)`, the card and expiry route. The in-app Pause is
  `togglePause`, which cancels a queued repair's work item through `cancelQueuedWorkItem` and never reaches
  `commitPause`. On the iPhone, that read Downloaded 112 of 112 with no Resume.
- **What was done:** a failing test through `togglePause` (`d2c7210c1`), then the same write-back in that exit
  (`d47003bca`), then the device steps again on the new build.
- **Effect:** none left. Step 2 passed on `d47003bca`.

---

**Total deviations:** 3. Two were method changes, and neither affected a verdict. The third was a missed route,
fixed test first and checked again on the device.

## Issues Encountered

- **Thermal state:** the iPhone ran charging, with Device MCP mirroring, and the app logged its thermal state as
  `serious` during Task 2. Downloads kept their normal pace, and no session was reclaimed by the system.
- **No drain frame in the background:** no session drained to completion while the app was in the background.
  So SC2's "including the last" was observed only on the last frames before the cancels, and both of those
  showed "· 2 galleries". This was already passed on device in Phase 15 round 8.

## Next Phase Readiness

- SC7 (both device checks on owner hardware) is met.
- **G-20-09-1 is fixed, and its k = 0 residual is closed.** G-15-2G stays: Verify Images alone still never blanks
  a whole gallery, and a whole record drops only when Verify's scan and a stop's fresh scan both find every
  claimed page absent.
- The local evidence stays in `$HOME/Movies/Device MCP/ehp20-09/`: recordings, screenshots, logs and drivers.
  It is not committed, because it shows adult content and the device names.

## Self-Check: PASSED

- `20-09-DEVICE.md` exists, with ten launch rows. `grep -cE "^\| *[0-9]+ *\| *[0-9.]+ s"` gives 10.
- It has two outcome lines. `grep -ciE "outcome: (as designed|gap)"` gives 2.
- `git diff --stat 8fa2809cb 213d267cf -- AppPackage App` is empty: the plan itself changed no code. The
  G-20-09-1 fix is in `94819b027` and `4092bdddf`, and the k = 0 closure is in `0d99387a8`, `264c5d927`,
  `a0f54806c`, `ae1992b21`, `d2c7210c1` and `d47003bca`.
