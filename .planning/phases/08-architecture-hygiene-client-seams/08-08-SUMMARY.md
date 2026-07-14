---
phase: 08-architecture-hygiene-client-seams
plan: 08
subsystem: architecture
tags: [gallery-host, sharing, user-defaults, url-construction, teardown]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Explicit GalleryHost request, reducer, view, and URL-building seams from Plans 08-02 through 08-07
provides:
  - URL builders and host-derived Defaults helpers with no global host fallback
  - Shared Setting as the only persisted active-gallery-host source
  - AppUserDefaults reduced to the clipboard change counter
affects: [08-09, 08-13, 08-14, AppModels, SettingFeature, NetworkingFeature]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit host parameters, Shared setting source of truth, compile-enforced dependency teardown]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-08-SUMMARY.md
  modified:
    - AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift
    - AppPackage/Sources/AppModels/Utilities/URLUtil.swift
    - AppPackage/Sources/AppModels/Utilities/AppUtil.swift
    - AppPackage/Sources/AppTools/UserDefaultsUtil.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift
    - AppPackage/Sources/SettingFeature/SettingReducer.swift
    - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
    - AppPackage/Package.swift

key-decisions:
  - "GalleryInfosView reads the active host from SharedReader(.setting) at render time, matching the phase's leaf-view host seam."
  - "Test-only URL fallbacks use the deterministic E-Hentai host instead of recreating a mutable global default."
  - "SettingFeature drops its now-unused UserDefaultsClient dependency together with the obsolete mirror-action test."

patterns-established:
  - "Host-dependent URL construction requires a GalleryHost argument at every call site."
  - "The persisted Setting blob is the sole active-gallery-host source; losing it intentionally resets the host to .ehentai."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: Gallery-host globals and transitional URL defaults are deleted while all production and test callers supply an explicit host.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static sweeps for Defaults.URL.host, AppUtil.galleryHost, host defaults, and host-derived property reads"
        status: pass
    human_judgment: false
  - id: D2
    description: The galleryHost UserDefaults mirror, restore path, action, view trigger, dependency, and action-only test are removed.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static SettingFeature and AppUserDefaults mirror/action sweeps"
        status: pass
    human_judgment: false

# Metrics
duration: 7min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 08: Gallery Host Teardown Summary

**The active gallery host now lives only in shared Setting state, with every URL consumer requiring an explicit host and no UserDefaults mirror or global fallback remaining.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-14T09:18:41Z
- **Completed:** 2026-07-14T09:25:41Z
- **Tasks:** 2
- **Files modified:** 14

## Accomplishments

- Deleted `Defaults.URL.host`, its eight host-derived global properties, `AppUtil.galleryHost`, and all thirteen transitional `URLUtil` host defaults.
- Threaded explicit host values into the final GalleryInfos and deterministic test consumers surfaced by compile-time teardown.
- Removed the `galleryHostChanged` action and view trigger, launch restore, `AppUserDefaults.galleryHost`, dead SettingFeature client dependency, and obsolete action-only test.
- Passed the package build and full AppPackage test suite, including the NetworkingFeature request URL parity baselines.

## Task Commits

1. **Task 1: Delete the host globals and URLUtil transitional default** - `304ceac4` (refactor)
2. **Task 2: Remove the UserDefaults galleryHost mirror and shrink AppUserDefaults** - `5b99f937` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift` - Keeps only explicit host-taking URL helper functions.
- `AppPackage/Sources/AppModels/Utilities/URLUtil.swift` - Requires GalleryHost for every host-dependent builder.
- `AppPackage/Sources/AppModels/Utilities/AppUtil.swift` - Removes the gallery-host accessor while retaining the Plan 08-14 residue.
- `AppPackage/Sources/AppTools/UserDefaultsUtil.swift` - Reduces AppUserDefaults to `clipboardChangeCount`.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift` - Removes the mirror action, effect, and dependency.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift` - Removes the mirror-driving host onChange modifier.
- `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift` - Removes launch restoration and documents Setting-only persistence semantics.
- `AppPackage/Sources/SettingFeature/SettingReducer.swift` - Removes the dead UserDefaultsClient dependency.
- `AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift` - Supplies the shared host to the torrent metadata URL.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFilterAndBadgeTests.swift` - Supplies a deterministic host to filter URL tests.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - Supplies an explicit host to a metadata stub fallback.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingTests.swift` - Supplies an explicit host to an image test fallback.
- `AppPackage/Package.swift` - Removes SettingFeature's unused UserDefaultsClient dependency.
- `AppPackage/Tests/SettingFeatureTests/AccountSettingReducerTests.swift` - Deletes the obsolete mirror-action-only suite.
- `.planning/phases/08-architecture-hygiene-client-seams/08-08-SUMMARY.md` - Records implementation and verification evidence.

## Decisions Made

- Used `@SharedReader(.setting)` in the leaf GalleryInfos view because it has no parent setting state, preserving render-time host selection without state drilling.
- Used `.ehentai` only for deterministic test fallback URLs; production host selection remains entirely caller-owned.
- Removed the dead SettingFeature dependency and obsolete action-only test rather than leaving architecture that could imply the mirror still exists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Threaded host through compile-exposed stragglers**

- **Found during:** Task 1 build and Task 2 full-suite verification.
- **Issue:** GalleryInfosView and six DownloadsFeature test URL constructions still relied on the deleted defaults or derived globals.
- **Fix:** Added a shared-setting host read to GalleryInfosView and explicit deterministic E-Hentai hosts to the tests.
- **Files modified:** `GalleryInfosView.swift` and three DownloadsFeature test files.
- **Verification:** The package build and full test suite succeeded; static sweeps find no global/default consumer.
- **Committed in:** `304ceac4` and `5b99f937`.

**2. [Rule 3 - Blocking] Adapted verification to the package workspace and installed simulator**

- **Found during:** Task 1 verification.
- **Issue:** The package scheme is resolved from `AppPackage/`, and the planned iPhone 16 destination is not installed.
- **Fix:** Ran the same build and full-suite gates sequentially from `AppPackage/` on the available iPhone Air simulator with iOS 26.5.
- **Files modified:** None.
- **Verification:** Both commands exited successfully with no changed-code warnings.
- **Committed in:** No source change required.

---

**Total deviations:** 2 auto-fixed blocking issues.
**Impact on plan:** The fixes completed the intended teardown at all compile-time consumers; behavior and requirement scope were unchanged.

## Issues Encountered

None - all compile-exposed callers were corrected and the final verification gates passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 08-09 through 08-14 can build on a single-source active host with no global or UserDefaults compatibility path.
- AppUserDefaults is ready for its planned fold into UserDefaultsClient in Plan 08-13.
- No blockers remain.

## Self-Check: PASSED

- Both task commits are present and every surviving key file exists; the planned obsolete test file deletion is intentional.
- AppUserDefaults contains exactly `clipboardChangeCount`.
- Static sweeps return no `Defaults.URL.host`, `AppUtil.galleryHost`, URLUtil host default, host-derived global-property read, `galleryHostChanged`, mirror write/restore, or host onChange trigger.
- The package build and full AppPackage suite pass sequentially with SwiftLint build-tool plugins enabled.
- `git diff --check` and `git show --check` pass for both task commits.
- Changed code adds no warning suppression, localized strings, placeholder behavior, TODOs, FIXME markers, or security-sensitive surface.
- SwiftUI and TCA review confirmed the final leaf view reads shared state at render time and removed actions have no call sites or empty stubs.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
