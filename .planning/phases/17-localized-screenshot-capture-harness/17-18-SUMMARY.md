---
phase: 17-localized-screenshot-capture-harness
plan: "18"
subsystem: navigation
tags: [size-class, routing, downloads, search, verification]
requires:
  - phase: 17-17
    provides: App-root routing rule recorded in the layout audit
provides:
  - Search and Downloads routing section of 17-LAYOUT-AUDIT.md and the routeGalleryDetail removal check
affects: [17-19, 17-23]
actuals:
  tokens: 1900
  tasks: 1
  commits: 1
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - .planning/phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md
key-decisions:
  - "Checked the download invariants (manifest SSOT, same-run deletion, row-anchored dialogs) by reading 605b4e4749's Downloads and Search diffs, which touch only the tap route, plus the passing Downloads automation tests."
patterns-established: []
requirements-completed: [CAP-17-06, CAP-17-07]
coverage:
  - id: D1
    description: Search and Downloads gallery taps follow the app-root window-size-class rule, and routeGalleryDetail no longer exists.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "git merge-base --is-ancestor 605b4e4749 HEAD (exit 0); git grep -n routeGalleryDetail -- AppPackage (exit 1)"
        status: pass
      - kind: unit
        ref: "AppDownloadDetailRoutingTests + DownloadAutomationTests + GalleryNavigationTests on EhPanda iPhone Air (iOS 27.2): 11 cases, 0 failed, 0 Repetition"
        status: pass
      - kind: unit
        ref: "AppDownloadDetailRoutingTests + DownloadAutomationTests + GalleryNavigationTests on EhPanda iPad Pro 11-inch (M5) (iOS 27.2): 11 cases, 0 failed, 0 Repetition"
        status: pass
    human_judgment: false
  - id: D2
    description: Download manifest SSOT, the same-run deletion invariant and row-anchored confirmation dialogs are unchanged by the routing migration.
    requirement: CAP-17-06
    verification:
      - kind: other
        ref: "git show 605b4e4749 -- DownloadsReducer.swift SearchRootReducer.swift GalleryNavigation.swift (routing-only diff)"
        status: pass
      - kind: unit
        ref: "DownloadsFeatureTests/DownloadAutomationTests, 8 cases on phone and tablet"
        status: pass
    human_judgment: false
duration: 10min
completed: 2026-11-03
status: complete
source_head: 2f61e27aa
---

# Phase 17 Plan 18: Landed Search and Downloads routing Summary

**Search and Downloads taps now only ask the app root to open Detail, which applies the same both-regular rule; the idiom helper `routeGalleryDetail` is gone, and the routing, automation and navigation tests pass on iPhone Air and iPad Pro 11-inch.**

## Performance

- Tasks: 1/1; files: `17-LAYOUT-AUDIT.md` extended, plus this summary and the STATE/ROADMAP records.
- Duration: about 10 minutes.

## Accomplishments

- `605b4e4749` is an ancestor of HEAD.
- Recorded the Search (`SearchRootReducer.swift:133` → `AppReducer.swift:295-296`) and Downloads
  (`DownloadsReducer.swift:184` → `AppReducer.swift:301-307`, download-seeded modal) routes.
- `git grep -n routeGalleryDetail -- AppPackage` finds nothing; GalleryNavigation keeps
  `presentationEffect`, `nextScreen`, `appendGuardingDuplicate` and its route-key and reading-flush
  helpers.
- The migration's Downloads and Search diffs are routing-only, so the manifest, deletion and
  dialog-anchor rules are untouched.

## Task Commits

1. 17-18-T1, audit section and plan metadata: the plan's single `docs(17-18)` commit on
   `feature/gsd-phase-17`.

## Verification

```sh
git merge-base --is-ancestor 605b4e4749 HEAD   # exit 0
git grep -n routeGalleryDetail -- AppPackage   # exit 1
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:DownloadsFeatureTests/AppDownloadDetailRoutingTests -only-testing:DownloadsFeatureTests/DownloadAutomationTests -only-testing:DetailFeatureTests/GalleryNavigationTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:DownloadsFeatureTests/AppDownloadDetailRoutingTests -only-testing:DownloadsFeatureTests/DownloadAutomationTests -only-testing:DetailFeatureTests/GalleryNavigationTests'
```

| Device | Exit | Test cases | Failed | Skipped | Repetition |
|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | 11 (routing 2, automation 8, navigation 1) | 0 | 0 | 0 |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | 11 | 0 | 0 | 0 |

Result bundles: `/tmp/ehpanda-17-16-18/17-18-phone.xcresult`, `/tmp/ehpanda-17-16-18/17-18-tablet.xcresult`
(local only). No app source diff.

## Deviations from Plan

Same two procedural deviations as 17-16 (runtest recipe in place of raw `xcodebuild test`; one
commit for the task output and plan metadata).

**Total deviations:** 2 procedural. **Impact:** none on the evidence.

## Issues Encountered

No defect found. Coverage observation: `GalleryNavigationTests` holds a single case
(`appendGuardingDuplicate`); `presentationEffect` and `nextScreen` are exercised through host
lifecycle suites rather than this file.

## Phase-level verification note

This plan does not ask for a manual simulator pass, and neither do 17-16 or 17-17. Both
project-created test simulators were deleted after the runs.

## Next

Ready for 17-19, which has an owner keep/change checkpoint.

## Self-Check: PASSED
