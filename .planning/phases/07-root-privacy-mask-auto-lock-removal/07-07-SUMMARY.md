---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 07
subsystem: ui
tags: [swiftui, privacy-mask, reading, settings, parameter-drilling]

# Dependency graph
requires:
  - phase: 07-01
    provides: self-sourcing privacyMask modifier and shared in-memory blur state
  - phase: 07-05
    provides: DownloadsFeature privacy-mask sweep with a temporary ReadingView compatibility argument
  - phase: 07-06
    provides: DetailFeature privacy-mask sweep with temporary ReadingView compatibility arguments
provides:
  - Package-wide removal of blurRadius view-initializer drilling
  - Forty self-sourcing privacy-mask call sites, including the AppActivityLogs run-picker sheet
  - ReadingFeature and SettingFeature modal roots driven directly by privacyMask()
  - Complete removal of the legacy autoBlur modifier
affects: [07-08, UIARCH-04, privacy-audit]

# Tech tracking
tech-stack:
  added: []
  patterns: [self-sourcing modal privacy masks, visual state excluded from view initializers]

key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/SettingFeature/SettingView.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/SettingFeature/Login/LoginView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/AppComponents/ViewModifiers.swift

key-decisions:
  - "07-07: Privacy-mask coverage is counted as forty application call sites; the public function declaration and its shared-key documentation are intentionally excluded from that call-site audit."
  - "07-07: The AppActivityLogs mask is attached directly to the RunPickerSheet presented root, preserving native sheet focus management while protecting the separate modal surface."

patterns-established:
  - "Separately presented SwiftUI roots attach privacyMask() themselves and never receive visual privacy state through an initializer."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: No AppPackage view initializer or caller retains blurRadius drilling, and all forty root/modal applications self-source privacyMask().
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg audits: AppPackage/Sources blurRadius=0, autoBlur=0, privacy-mask call sites=40"
        status: pass
      - kind: integration
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination generic/platform=iOS Simulator"
        status: pass
    human_judgment: false
  - id: D2
    description: The AppActivityLogs run-picker sheet is a stable, independently masked modal root.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "AppActivityLogsView.swift static sheet-root audit and module privacyMask() count"
        status: pass
    human_judgment: true
    rationale: "Static analysis proves modifier placement, but App Switcher/background concealment of the presented sheet requires the phase-level device UAT scheduled for 07-08."
  - id: D3
    description: The legacy autoBlur modifier and every call site are removed without residue.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg -n autoBlur AppPackage/Sources returns no matches"
        status: pass
      - kind: integration
        ref: "strict SwiftLint over all eleven modified Swift files"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 07: Final Privacy-Mask Parameter Sweep Summary

**Reading and Settings modal roots now self-source one shared privacy mask, all blur initializer drilling is gone, and the legacy modifier has been deleted.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-13T18:18:12Z
- **Completed:** 2026-07-13T18:24:04Z
- **Tasks:** 3
- **Files modified:** 11

## Accomplishments

- Removed `blurRadius` from `ReadingView`, four SettingFeature view types, every preview, and every remaining caller across AppPackage.
- Converted the two ReadingFeature sheets and three SettingFeature web-view sheets to self-sourcing `.privacyMask()` applications.
- Added the missing mask directly to the AppActivityLogs run-picker sheet, closing the D-16 modal-root audit gap.
- Deleted `.autoBlur(radius:)`; the package now has zero `blurRadius` and zero `autoBlur` tokens with exactly forty mask application sites.

## Task Commits

Each task was committed atomically:

1. **Task 1: Strip ReadingView blur drilling and remove all reader caller arguments** - `2032f70b` (refactor)
2. **Task 2: Strip SettingFeature blur drilling and mask the AppActivityLogs run-picker** - `c2ec5f19` (refactor)
3. **Task 3: Delete the legacy autoBlur modifier** - `e59834c4` (refactor)

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - Removed its blur initializer input and self-sourced both modal masks.
- `AppPackage/Sources/DetailFeature/DetailView.swift` - Removed the temporary reader compatibility argument.
- `AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift` - Removed the additional temporary reader argument found by the package-wide audit.
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift` - Removed the temporary reader compatibility argument.
- `AppPackage/Sources/SettingFeature/SettingView.swift` - Removed the public blur initializer and its three destination passes.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift` - Removed blur state and self-sourced the web-view sheet mask.
- `AppPackage/Sources/SettingFeature/Login/LoginView.swift` - Removed blur state and self-sourced the web-view sheet mask.
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift` - Removed blur state and self-sourced the web-view sheet mask.
- `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift` - Attached a mask to the presented run-picker root.
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` - Removed both remaining `SettingView` blur arguments.
- `AppPackage/Sources/AppComponents/ViewModifiers.swift` - Deleted the unused legacy `autoBlur` extension.

## Decisions Made

- Counted privacy-mask coverage by application sites rather than raw textual matches. The source tree contains forty calls plus the required public `privacyMask()` declaration and an existing documentation reference; retaining both non-call matches is correct.
- Kept the AppActivityLogs presentation as a native `.sheet` and attached the modifier to its presented `RunPickerSheet` root. SwiftUI therefore retains automatic modal focus trapping and dismissal semantics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed the omitted PreviewsView reader argument**
- **Found during:** Task 1 (Strip ReadingView blur drilling and remove all reader caller arguments)
- **Issue:** The task named only DetailView and DownloadsView as reader callers, but `DetailFeature/Previews/PreviewsView.swift` also retained `ReadingView(blurRadius: 0)`. Leaving it would fail compilation after the initializer removal and violate the package-wide zero-token gate.
- **Fix:** Read the additional caller and removed its temporary argument in the same atomic task.
- **Files modified:** `AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift`
- **Verification:** A package-wide multiline caller audit finds no `ReadingView` call containing `blurRadius`; the AppFeature graph builds successfully.
- **Committed in:** `2032f70b`

---

**Total deviations:** 1 auto-fixed (1 blocking inconsistency).
**Impact on plan:** The extra edit was required to satisfy the plan's own package-wide invariant and kept all reader callers compiling after the initializer removal.

## Issues Encountered

- The plan's literal `grep -rc 'privacyMask()' AppPackage/Sources` criterion reports 42 textual matches, not 40, because it also counts the public function declaration and an existing documentation comment. An application-site audit excludes those two non-call matches and proves the intended total is exactly 40; no valid source was distorted to satisfy the faulty raw grep.
- The complete AppFeature simulator build succeeded. A later log-only incremental rerun could not reconnect to sandboxed CoreSimulator services; strict SwiftLint still reported zero violations across all eleven changed files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 07-08 to test scene-phase privacy state and perform the device-level no-leak audit across the settled forty mask roots.
- No source, SwiftLint, SwiftUI presentation, or accessibility regressions were found in the changed wiring.

## Self-Check: PASSED

- All eleven modified source files and this summary exist.
- Task commits `2032f70b`, `c2ec5f19`, and `e59834c4` are present in git history.
- AppPackage has zero `blurRadius` tokens, zero `autoBlur` tokens, and exactly forty `.privacyMask()` application sites.
- The AppActivityLogs run-picker sheet owns the new mask at its presented root.
- `git diff --check`, the complete AppFeature simulator build, and strict SwiftLint passed.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
