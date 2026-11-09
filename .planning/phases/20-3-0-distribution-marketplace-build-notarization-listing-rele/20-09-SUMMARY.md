---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "09"
subsystem: device-verification
tags: [device, ipad, iphone, release-build, gallery-detail, continued-processing, background-downloads, sc2]

requires: []
provides:
  - "`20-09-DEVICE.md`: the iPad Release cold-launch Gallery Detail check (10 of 10, no stall) and the iPhone repeat of Phase 15 SC2 (as designed), on owner hardware (DEV-18-01, SC7)"
  - "G-20-09-1, for the owner to decide: after a whole-gallery repair is paused, by either route, the row reads Downloaded N of N until Verify Images"
affects: []

actuals:
  tokens: 160000
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-09-DEVICE.md
  modified: []

key-decisions:
  - "Both device checks were run entirely by the agent through the Device MCP app, with the owner's consent (owner msgs 2885 and 2887 for the iPad, owner msg 2893 for the iPhone). The owner tapped nothing."
  - "Only the owner's iPad mini and his test iPhone 11 were used. The build used his local signing, copied in for the build and removed afterwards, so no tracked file changed."
  - "G-20-09-1 is filed rather than fixed, because this plan changes no code. It is not an SC2 failure: the card cancel and an in-app pause leave the same state."

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
- **One new observation, G-20-09-1, is filed for the owner.** A paused whole-gallery repair reads "Downloaded N of
  N" until it is verified again.
- No code changed.

## Performance

- **Duration:** Task 1's device work ran from about 05:09Z to 05:20Z on 2026-11-09, and its record was committed
  at 05:21Z. Task 2's device work ran from about 06:06Z to 06:40Z. Builds and records took the rest of the time.
- **Completed:** 2026-11-09
- **Tasks:** 2 of 2
- **Files:** 1 created (`20-09-DEVICE.md`), plus this summary

## Accomplishments

- **Task 1: iPad Release cold launches (owner msgs 2885 and 2887).**
  - **Device and build:** an iPad mini (6th generation), iPadOS 27.2, running a Release build of `ac03a2ca6`
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
- **G-20-09-1 (owner decides).**
  - **What happens:** once a whole-gallery repair is paused, the row falls back to the record, and the record
    still claims every page. The row shows "Downloaded N of N" with no Resume, while pages are missing.
  - **The cause:** the G-15-2G whole-gallery guard combined with the G-15-2F run overlay.
  - **To fix it:** two options are written in the device record, and either one is a code change.
  - **What it is not:** an SC2 failure, because both pause routes agree.

## Task Commits

1. **Task 1: iPad Release cold launches** — `4906e86c2` (docs)
2. **Task 2: iPhone SC2** — `908fcb50a` (docs)
3. **Plan metadata** — this summary (docs)

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

---

**Total deviations:** 2. Both were method changes, and neither affected a verdict.

## Issues Encountered

- **Thermal state:** the iPhone ran charging, with Device MCP mirroring, and the app logged its thermal state as
  `serious` during Task 2. Downloads kept their normal pace, and no session was reclaimed by the system.
- **No drain frame in the background:** no session drained to completion while the app was in the background.
  So SC2's "including the last" was observed only on the last frames before the cancels, and both of those
  showed "· 2 galleries". This was already passed on device in Phase 15 round 8.

## Next Phase Readiness

- SC7 (both device checks on owner hardware) is met.
- **G-20-09-1 awaits the owner's decision:** fix it in a closure plan, or accept it as a known limitation for
  3.0.
- The local evidence stays in `$HOME/Movies/Device MCP/ehp20-09/`: recordings, screenshots, logs and drivers.
  It is not committed, because it shows adult content and the device names.

## Self-Check: PASSED

- `20-09-DEVICE.md` exists, with ten launch rows. `grep -cE "^\| *[0-9]+ *\| *[0-9.]+ s"` gives 10.
- It has two outcome lines. `grep -ciE "outcome: (as designed|gap)"` gives 2.
- `git diff --stat -- AppPackage App` is empty for this plan.
