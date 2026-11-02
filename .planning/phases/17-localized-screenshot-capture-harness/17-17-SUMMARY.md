---
phase: 17-localized-screenshot-capture-harness
plan: "17"
subsystem: navigation
tags: [size-class, routing, tca, verification]
requires:
  - phase: 17-16
    provides: Layout audit record and created phone/tablet test devices
provides:
  - Home and Library routing section of 17-LAYOUT-AUDIT.md (rule, app-root application, covering tests)
affects: [17-18, 17-19, 17-23]
actuals:
  tokens: 1900
  tasks: 1
  commits: 1
tech-stack:
  added: []
  patterns: [single app-root presentation decision from reported window size classes]
key-files:
  created: []
  modified:
    - .planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md
key-decisions:
  - "Recorded Home's Duo split-layout path (WindowDevice .duo, D31) for the 17-19 census instead of treating it as part of the size-class rule."
  - "Recorded the missing Home .compactHeight test as a coverage observation, not a defect: Home shares openGalleryDetail with the hosts whose .compactHeight cases pass."
patterns-established: []
requirements-completed: [CAP-17-06, CAP-17-07]
coverage:
  - id: D1
    description: Home and Library (Favorites) gallery taps open Detail as a sheet only when both window size classes are regular, decided once at the app root.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "git merge-base --is-ancestor 605b4e4749 HEAD (exit 0)"
        status: pass
      - kind: unit
        ref: "AppFeatureTests/GalleryDetailRoutingTests + CaptureRouteTests on EhPanda iPhone Air (iOS 27.2): 15 test cases, 20 argument runs, 0 failed, 0 Repetition"
        status: pass
      - kind: unit
        ref: "AppFeatureTests/GalleryDetailRoutingTests + CaptureRouteTests on EhPanda iPad Pro 11-inch (M5) (iOS 27.2): 15 test cases, 20 argument runs, 0 failed, 0 Repetition"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-11-03
status: complete
source_head: 4ea5dbd22
---

# Phase 17 Plan 17: Landed Home and Library routing Summary

**Home and Library gallery taps reach one app-root decision, `WindowSizeClasses.presentsModally` (regular in both dimensions → sheet, otherwise push); the routing tests pass on iPhone Air and iPad Pro 11-inch.**

## Performance

- Tasks: 1/1; files: `17-LAYOUT-AUDIT.md` extended, plus this summary and the STATE/ROADMAP records.
- Duration: about 15 minutes, including a wait for another project's test run to release the shared runtest slot.

## Accomplishments

- `605b4e4749` is an ancestor of HEAD.
- Recorded the rule (`WindowSizeClasses.swift:17-19`), how the root view reports it
  (`TabBarView.swift:66-71`, `onChange(initial: true)`), and its single application in
  `AppReducer.openGalleryDetail` (`:521-529`) for Home (`:292-293`) and Library's Favorites (`:298-299`).
  No per-feature `isRegularWidth` state exists.
- Mapped the covering cases: GalleryDetailRoutingTests (Favorites and Search in `.compactWidth`,
  `.compactHeight`, `.regular`) and CaptureRouteTests (Home compact push, Home regular present,
  and the launch-automation routes).

## Task Commits

1. 17-17-T1, audit section and plan metadata: the plan's single `docs(17-17)` commit on
   `feature/gsd-phase-17`.

## Verification

```sh
git merge-base --is-ancestor 605b4e4749 HEAD   # exit 0
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:AppFeatureTests/GalleryDetailRoutingTests -only-testing:AppFeatureTests/CaptureRouteTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:AppFeatureTests/GalleryDetailRoutingTests -only-testing:AppFeatureTests/CaptureRouteTests'
```

| Device | Exit | Test cases | Argument runs | Failed | Skipped | Repetition |
|---|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | 15 | 20 | 0 | 0 | 0 |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | 15 | 20 | 0 | 0 | 0 |

Result bundles: `/tmp/ehpanda-17-16-18/17-17-phone.xcresult`, `/tmp/ehpanda-17-16-18/17-17-tablet.xcresult`
(local only). No app source diff.

## Deviations from Plan

Same two procedural deviations as 17-16: the plan's `xcodebuild test` ran through the project's
`runtest` recipe with identical test plan, destinations and filters, and the task output shares one
commit with the plan metadata. The first submission was refused because another project held the
shared runtest slot; it was resubmitted after the slot freed and nothing was cancelled.

**Total deviations:** 2 procedural. **Impact:** none on the evidence.

## Issues Encountered

No defect found. Two observations, both recorded in the audit:

- Coverage: no test drives a Home tap in `.compactHeight` (iPhone landscape). The shared helper is
  exercised in that window by Favorites, Search and Downloads.
- For the 17-19 census: `HomeReducer.usesSplitLayout` reads `WindowDevice` `.duo`; in that posture
  Home opens Detail in its own opposite-pane sheet rather than asking the app root (D31 capability
  exception).

## Next

Ready for 17-18.

## Self-Check: PASSED
