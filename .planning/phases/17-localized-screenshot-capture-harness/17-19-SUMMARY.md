---
phase: 17-localized-screenshot-capture-harness
plan: "19"
subsystem: navigation
tags: [size-class, idiom-census, settings, detail-routing, owner-decision, verification]
requires:
  - phase: 17-18
    provides: Search and Downloads routing and the census items handed on by 17-16 to 17-18
provides:
  - Settings presentation, simulator pass and remaining-idiom census sections of 17-LAYOUT-AUDIT.md
  - The owner's keep decision for each of the five remaining device-idiom places
affects: [17-14, 17-23]
actuals:
  tasks: 3
  commits: 1
tech-stack:
  added: []
  patterns: []
key-files:
  created:
    - .planning/phases/17-localized-screenshot-capture-harness/17-19-SUMMARY.md
  modified:
    - .planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md
key-decisions:
  - "Owner, 2026-11-03 (msg 1409, answering msg 1408): keep all five remaining device-idiom places (reader lower Close, Library sidebar, Home title, device name in error details, Duo/iPad capability). Nothing goes to a separate change plan."
  - "The optional Home-title cleanup (dropping the redundant `.pad` term) is not taken."
patterns-established: []
requirements-completed: [CAP-17-06, CAP-17-07]
coverage:
  - id: D1
    description: Settings is a sheet only when both window size classes are regular and the Settings tab is not already selected, and inline otherwise.
    requirement: CAP-17-07
    verification:
      - kind: unit
        ref: "AppFeatureTests/TabBarSettingPresentationTests on EhPanda iPhone Air (iOS 27.2): 8 cases, 0 failed, 0 Repetition, exit 0"
        status: pass
      - kind: unit
        ref: "AppFeatureTests/TabBarSettingPresentationTests on EhPanda iPad Pro 11-inch (M5) (iOS 27.2): 8 cases, 0 failed, 0 Repetition, exit 0"
        status: pass
    human_judgment: false
  - id: D2
    description: One simulator pass shows Detail as a sheet only at regular/regular and Settings inline when compact, on iPad full width, a narrow iPad window and iPhone landscape.
    requirement: CAP-17-07
    verification:
      - kind: manual
        ref: "Scratch UI-test driver (never committed): iPad full width Detail = 580x660 form sheet, Settings = sheet; iPad 375 pt window Detail = push with Back and tab bar, Settings inline; iPhone landscape Detail = push with Back and tab bar, Settings inline"
        status: pass
    human_judgment: false
  - id: D3
    description: Every remaining device-idiom read in AppPackage/Sources has a census row and the owner's recorded keep or change answer.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "git grep -nE \"userInterfaceIdiom|deviceState|deviceType|== \\.pad|case \\.pad\" -- AppPackage/Sources: every hit classified; five owner rows, each 'keep' (2026-11-03, msg 1409)"
        status: pass
    human_judgment: true
duration: 45min
completed: 2026-11-03
status: complete
source_head: 5a7fe7f13
---

# Phase 17 Plan 19: Settings presentation, idiom census and owner decisions Summary

**Settings and Detail follow the both-regular rule in all three window shapes, the Settings tests
pass on iPhone Air and iPad Pro 11-inch, and the owner chose to keep all five remaining device-idiom
places (2026-11-03, msg 1409). No app source changed.**

## Performance

- Tasks: 3/3 (T1 Settings tests, T2 simulator pass and census, T3 owner checkpoint answered).
- Files: `17-LAYOUT-AUDIT.md` gained three 17-19 sections; this summary; STATE/ROADMAP records.

## Accomplishments

- **T1.** Recorded the Settings rule (`WindowSizeClasses.swift:17-19`, `AppReducer.swift:248-258`,
  `:514-516`). `TabBarSettingPresentationTests` passes on both devices.
- **T2.** The first simulator pass, at `6bccf8468`, recorded Settings, Home, Library, the reader
  and the error details in the three shapes. Detail was blocked because the UI-test stub had no
  `api.php` route. Quick task 261103-test-plan-repairs fixed that, and a second pass at HEAD's
  source recorded Detail: a sheet at iPad full width, a push in the 375 pt iPad window and a push in
  iPhone landscape. All three match D02. The census classifies every grep hit.
- **T3.** The owner was asked on 2026-11-03 (msg 1408) and answered "keep all five" (msg 1409).
  Each row records the decision, the date and the reason.

## Task Commits

1. 17-19 T1 to T3, audit sections and plan metadata: a single `docs(17-19)` commit on
   `feature/gsd-phase-17`.

## Verification

```sh
git merge-base --is-ancestor 8fb2374536 HEAD   # exit 0
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:AppFeatureTests/TabBarSettingPresentationTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:AppFeatureTests/TabBarSettingPresentationTests'
git grep -nE "userInterfaceIdiom|deviceState|deviceType|== \.pad|case \.pad" -- AppPackage/Sources
grep -c "Owner decision" .planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md   # 6 (header + 5 rows)
```

| Device | Exit | Test cases | Failed | Skipped | Repetition |
|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | 8 | 0 | 0 | 0 |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | 8 | 0 | 0 | 0 |

Simulator pass, second run: tablet `TEST SUCCEEDED` (2 tests). The phone run recorded Detail and
Settings, then failed in the driver's own reader step (see Issues). Result bundles stay local under
`/tmp/ehp-17finish/runs/`, and screenshots stay outside the repository.

## Deviations from Plan

1. **Runtest recipe.** The project's `runtest` recipe ran the tests, one invocation at a time, in
   place of raw `xcodebuild test`. Retries can't be turned off from the command line:
   `xcodebuild` rejects `-test-iterations 1`. So, as in 17-14, any Repetition node counts as a
   failure. The Settings runs had none.
2. **Two simulator passes.** The plan asks for one pass. The first pass couldn't open a gallery
   (the stub gap, since fixed), so a second pass repeated the three shapes for Detail only. Its
   worktree held HEAD's source plus the uncommitted `waitUntilHittable` test helper.
3. **One commit** for the task output and plan metadata, as in 17-16 to 17-18.

**Total deviations:** 3 procedural. **Impact:** none on the evidence.

## Issues Encountered

- The driver's reader step failed on the phone in the second pass: `reading_view` didn't appear
  after the warm deep link. The step belongs to the throwaway driver and wasn't needed for Detail.
  The reader rows come from the first pass. Not an app defect claim.
- The Duo branch can't be simulated. Unit tests cover it, and this pass does not.

## Next

17-14 T2's behavior gate, then 17-23. The scratch worktree stays until the phase closes, and
nothing in it is committed. The two project simulators are shut down and kept, because 17-14 and
17-23 still need them.

## Self-Check: PASSED
