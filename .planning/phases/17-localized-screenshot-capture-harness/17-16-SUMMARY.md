---
phase: 17-localized-screenshot-capture-harness
plan: "16"
subsystem: ui
tags: [size-class, layout, verification, swiftui]
requires:
  - phase: 17-06
    provides: Completed capture foundation the reduced plan order follows
provides:
  - View-layout section of 17-LAYOUT-AUDIT.md with five sites, their reads at HEAD and landing commits
affects: [17-17, 17-18, 17-19, 17-23]
actuals:
  tokens: 2300
  tasks: 1
  commits: 1
tech-stack:
  added: []
  patterns: [verification record of landed work with ancestor-checked commits and result bundles]
key-files:
  created:
    - .planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md
  modified: []
key-decisions:
  - "Ran the plan's xcodebuild command through the project's runtest recipe (airbuild-xcode test) with the same test plan, destinations and -only-testing filters."
  - "Committed the audit section and plan metadata in one signed commit, following the owner's 2026-11-03 request for fewer commits; the task produced only planning documents."
patterns-established:
  - "Layout audit rows cite file:line at HEAD, the trait or fitting read, and the ancestor-checked landing commit."
requirements-completed: [CAP-17-06, CAP-17-07]
coverage:
  - id: D1
    description: The five view-layout sites read size classes, suggestion placement or container fitting at HEAD, with no idiom read.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "git merge-base --is-ancestor e03456839a HEAD; git merge-base --is-ancestor 30ef583d21 HEAD (exit 0 each)"
        status: pass
      - kind: other
        ref: "grep -nE 'userInterfaceIdiom|deviceType|DeviceClient|\\.pad\\b' over the five files (exit 1, no matches)"
        status: pass
    human_judgment: false
  - id: D2
    description: The existing Home and Search behavioral tests pass on phone and tablet.
    requirement: CAP-17-06
    verification:
      - kind: unit
        ref: "FeatureTests -only-testing:HomeFeatureTests -only-testing:SearchFeatureTests on EhPanda iPhone Air (iOS 27.2): 90 passed, 0 failed, 0 Repetition"
        status: pass
      - kind: unit
        ref: "FeatureTests -only-testing:HomeFeatureTests -only-testing:SearchFeatureTests on EhPanda iPad Pro 11-inch (M5) (iOS 27.2): 90 passed, 0 failed, 0 Repetition"
        status: pass
    human_judgment: false
duration: 20min
completed: 2026-11-03
status: complete
source_head: aece2e0d7
---

# Phase 17 Plan 16: Landed size-class view layouts Summary

**All five view-layout sites read size classes, the system's suggestion placement or container fitting at HEAD; no idiom read remains in them, and Home and Search tests pass on iPhone Air and iPad Pro 11-inch.**

## Performance

- Tasks: 1/1; files: 1 created (`17-LAYOUT-AUDIT.md`) plus this summary and the STATE/ROADMAP records.
- Duration: about 20 minutes, mostly the two test runs.

## Accomplishments

- Both landing commits are ancestors of HEAD: `e03456839a` and `30ef583d21`.
- Recorded each site at HEAD: Home Toplists (`horizontalSizeClass`, `HomeView+Sections.swift:484`),
  GalleryCardCell (`ViewThatFits` container fitting; its earlier size-class read was replaced by the
  title setting in `1cc211aee`), Search keywords (`horizontalSizeClass`,
  `SearchRootView+Keywords.swift:43`), TagSuggestion (`searchSuggestionsPlacement`) and NewDawn
  (canvas `size.width >= 500`, D28).
- Idiom grep over the five files finds nothing, so this plan hands no item to the 17-19 census.

## Task Commits

1. 17-16-T1, audit section and plan metadata: see the plan's single `docs(17-16)` commit on
   `feature/gsd-phase-17`.

## Verification

```sh
git merge-base --is-ancestor e03456839a HEAD   # exit 0
git merge-base --is-ancestor 30ef583d21 HEAD   # exit 0
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:HomeFeatureTests -only-testing:SearchFeatureTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:HomeFeatureTests -only-testing:SearchFeatureTests'
```

| Device | Exit | Passed | Failed | Skipped | Repetition |
|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | 90 (Home 74, Search 16) | 0 | 0 | 0 |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | 90 (Home 74, Search 16) | 0 | 0 | 0 |

Result bundles: `/tmp/ehpanda-17-16-18/17-16-phone.xcresult`, `/tmp/ehpanda-17-16-18/17-16-tablet.xcresult`
(local only). No app source diff.

## Deviations from Plan

1. **Test runner.** The plan's `<verify>` names a raw `xcodebuild test` command; the repository's
   AirBuild instructions require the project's `runtest` recipe. It calls `airbuild-xcode test`
   with the same project, scheme, test plan, destination and filters, adding only
   `-collect-test-diagnostics never` and a result bundle path. No retry or repetition flag is set.
2. **Commit shape.** The task output and plan metadata share one commit, per the owner's request
   for fewer commits.

**Total deviations:** 2 procedural. **Impact:** none on the evidence.

## Issues Encountered

None. No defect found.

## Coverage Note

No manual simulator pass is part of this plan. Snapshot coverage of these layouts moved to
Phase 18 (VIS-18-01).

## Next

Ready for 17-17.

## Self-Check: PASSED
