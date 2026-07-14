---
phase: 08-architecture-hygiene-client-seams
plan: 07
subsystem: ui
tags: [gallery-host, swiftui, sharing, settings, detail]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Host-taking Defaults.URL helpers and explicit request host seams
provides:
  - Shared-setting host reads for gallery list cells, category controls, Toplists, and detail UI
  - Shared-setting host inputs for settings WebView URLs and detail download payloads
  - View and reducer layers with no AppUtil.galleryHost consumer reads
affects: [08-08, SettingFeature, DetailFeature, GalleryListComponents, AppComponents, HomeFeature]

# Tech tracking
tech-stack:
  added: []
  patterns: [SharedReader view state, store-owned host reads, reducer-owned host snapshots]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-07-SUMMARY.md
  modified:
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/AppComponents/CategoryView.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift

key-decisions:
  - "Views use an existing store setting when available and add a read-only SharedReader only to leaf views without store access."
  - "Detail download payloads snapshot state.setting.galleryHost at reducer action handling time."
  - "The transitional URLUtil host defaults remain untouched for their scheduled deletion in Plan 08-08."

patterns-established:
  - "Leaf rendering seam: read GalleryHost from SharedReader(.setting) at render time."
  - "Store-backed view seam: use store.setting.galleryHost without duplicating shared state."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: Gallery list cells, category controls, and Toplists derive host-sensitive rendering from shared settings without layout changes.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static AppUtil.galleryHost consumer sweep across GalleryListComponents, AppComponents, and HomeFeature"
        status: pass
    human_judgment: false
  - id: D2
    description: Setting WebView URLs and Detail host-sensitive gating, colors, and download payloads use the selected shared host.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static audits for host-taking myTags/uConfig calls and scoped AppUtil.galleryHost consumer removal"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 07: View and Reducer Host Seams Summary

**Gallery rendering, settings URLs, and detail downloads now resolve the active host from shared Setting state while preserving the existing UI structure and behavior.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-14T09:04:57Z
- **Completed:** 2026-07-14T09:11:19Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Replaced every scoped leaf-cell, component, SettingFeature, DetailFeature, and Toplists `AppUtil.galleryHost` consumer with `setting.galleryHost`, `store.setting.galleryHost`, or `state.setting.galleryHost`.
- Built the manage-tags and uConfig WebView URLs with `Defaults.URL.myTags(host:)` and `Defaults.URL.uConfig(host:)` from the selected shared host.
- Preserved render-time host reads, category colors, Toplists gating, detail login gating, and download payload behavior without changing layout, accessibility semantics, dialog anchors, or control structure.
- Passed the package build and full AppPackage test suite with SwiftLint build-tool plugins enabled.

## Task Commits

1. **Task 1: Convert the leaf-cell and component host reads to setting.galleryHost** - `e3f40c81` (refactor)
2. **Task 2: Convert the Setting and Detail host reads to setting.galleryHost** - `4f2bc3c3` (refactor)

## Files Created/Modified

- `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift` - Uses its existing shared setting for category color selection.
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift` - Uses its existing shared setting for thumbnail category color selection.
- `AppPackage/Sources/AppComponents/CategoryView.swift` - Adds a read-only shared setting to each category cell for host-sensitive colors.
- `AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift` - Gates jump-page controls from reducer-owned setting state.
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift` - Derives the title host and uConfig URL from shared settings.
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift` - Derives favorite-category colors from a shared setting reader.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift` - Builds the manage-tags URL from the selected shared host.
- `AppPackage/Sources/DetailFeature/DetailView.swift` - Uses store setting state for the E-Hentai download-gating term while leaving `CookieUtil.didLogin` unchanged.
- `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` - Uses a shared setting reader for gallery category color rendering.
- `AppPackage/Sources/DetailFeature/DetailReducer+Download.swift` - Captures the reducer state's host in new download payloads.
- `.planning/phases/08-architecture-hygiene-client-seams/08-07-SUMMARY.md` - Records implementation and verification evidence.

## Decisions Made

- Reused store-owned setting state in views and reducers that already exposed it; added `@SharedReader(.setting)` only to leaf SwiftUI views lacking store access.
- Kept every host read at the same render or action-construction boundary as the replaced global read.
- Left the transitional `URLUtil` default arguments and the `Defaults.URL.host` definition for Plan 08-08, which explicitly owns their teardown.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted verification to the package workspace and installed simulator**

- **Found during:** Task 1 verification
- **Issue:** Invoking the package scheme from the repository root selected the app project, and the planned iPhone 16 simulator is not installed.
- **Fix:** Ran the same build and test commands from `AppPackage/` on the available iPhone Air simulator with iOS 26.5.
- **Files modified:** None.
- **Verification:** The package build and full test suite succeeded sequentially.
- **Committed in:** No source change required.

---

**Total deviations:** 1 auto-fixed blocking issue.
**Impact on plan:** Only the local verification path and destination changed; implementation scope and test coverage were unchanged.

## Issues Encountered

- The plan's literal full-tree `AppUtil.galleryHost` grep criterion conflicts with Plan 08-08, which explicitly schedules removal of the `URLUtil` transitional defaults and `Defaults.URL.host`. The scoped consumer sweep across all view/reducer modules is clean; only those scheduled AppModels definitions remain.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All view and reducer consumers now source the host from shared Setting state.
- Plan 08-08 can safely delete `Defaults.URL.host`, the host-derived global properties, `AppUtil.galleryHost`, and the `URLUtil` transitional defaults.
- No blockers remain.

## Self-Check: PASSED

- All ten modified source files exist and both task commits are present in git history.
- `AppUtil.galleryHost` has no matches in the scoped view/reducer modules.
- SettingFeature has no bare `Defaults.URL.myTags` or `Defaults.URL.uConfig` reads.
- `DetailView` retains `CookieUtil.didLogin` while its host term uses `store.setting.galleryHost`.
- The package build and full AppPackage test suite pass on the installed simulator with no changed-code warnings.
- `git show --check` passes for both task commits.
- Changed code adds no warning suppression, localized strings, placeholder behavior, TODOs, FIXME markers, or security-sensitive surface.
- SwiftUI review confirmed no control structure, accessibility modifiers, animations, dialog anchors, or modal placement changed.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
