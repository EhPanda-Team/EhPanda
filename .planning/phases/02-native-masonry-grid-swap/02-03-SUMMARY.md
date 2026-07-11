---
phase: 02-native-masonry-grid-swap
plan: 03
subsystem: ui
tags: [swiftui, layout, masonry, waterfallgrid, pagination]

# Dependency graph
requires:
  - phase: 02-native-masonry-grid-swap (plan 01)
    provides: MasonryLayout pure core + thin Layout conformance, GalleryListComponentsTests target
  - phase: 02-native-masonry-grid-swap (plan 02)
    provides: SR-1 spike GO, frozen m = 185, auto-load pagination candidate (D-36)
provides:
  - Production .thumbnail swap — GenericList renders through the app-owned MasonryLayout, no WaterfallGrid reference in the file
  - Finalized MasonryLayout (spike instrumentation removed, m frozen at 185, D-33/D-35 policy documented)
  - Auto-load pagination retained as the shipping behavior (D-36): footer inside the masonry row + scroll-geometry/user-phase guards
  - Legacy column reads deleted (columnsInPortrait/columnsInLandscape); DeviceUtil untouched (D-34)
affects: [02-04 WaterfallGrid dependency removal + Package.resolved regen + AboutView acknowledgement decision]

# Tech tracking
tech-stack:
  added: []
  removed:
    - "import WaterfallGrid (call-site reference; the package dependency is removed in Plan 04)"
    - "import OSLogExt + temporary trigger/width diagnostics (spike-only)"
    - "import SFSafeSymbols, import AppTools (dead once the chevron footer and DeviceUtil column reads were removed)"
  patterns:
    - "Synchronous custom Layout replaces an async third-party grid — placement in the same pass as the List row, shedding the library's first-layout opacity flash (D-33)"

key-files:
  created: []
  modified:
    - AppPackage/Sources/GalleryListComponents/MasonryLayout.swift
    - AppPackage/Sources/GalleryListComponents/GenericList.swift

key-decisions:
  - "m stayed 185 (SR-1 keep-185) — no columnCount test re-baselining needed; the Plan 01 table already asserts the real bands"
  - "Removed SFSafeSymbols + AppTools imports too: both became dead as a direct consequence of deleting the chevron footer (spike) and the DeviceUtil column reads (this plan) — leaving them would be an unused-import smell"
  - "WaterfallList struct name kept (internal; renamed in Phase 6 decomposition, out of scope here)"

# Coverage
coverage:
  - id: D1
    description: ".thumbnail renders MasonryLayout as one eager row in List(.plain) with .animation(nil, value: galleries), preserving notice Section, .refreshable, and the D-36 auto-load footer inside the masonry row"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "grep: MasonryLayout {, .animation(nil, value: galleries), .listStyle(.plain), onScrollGeometryChange/onScrollPhaseChange/lastAutoFetchCount all present; no chevron"
        status: pass
    human_judgment: false
  - id: D2
    description: "columnsInPortrait/columnsInLandscape deleted; no view derives column count from UIScreen/DeviceUtil; DeviceUtil.swift unchanged (D-20, D-34)"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "grep -c columnsInPortrait|columnsInLandscape = 0; git diff DeviceUtil.swift empty"
        status: pass
    human_judgment: false
  - id: D3
    description: "No WaterfallGrid reference in GenericList.swift; spike instrumentation removed from both files; full suite green"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "grep -c WaterfallGrid = 0; grep -c 'OSLogExt|logger' = 0; grep -c 'Logger(' MasonryLayout = 0; xcodebuild test -scheme AppPackage-Package → TEST SUCCEEDED (424 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MasonryLayout finalized at frozen m=185, no instrumentation, doc-commented private policy (D-35) + synchronous no-flash rationale (D-33)"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "grep: minCellWidth: CGFloat = 185; D-33 and D-35 present in doc; no UIScreen/DeviceUtil token"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-11
status: complete
---

# Phase 2 Plan 3: Production Masonry Swap Summary

**The `.thumbnail` grid now renders through the app-owned `MasonryLayout` — the spike instrumentation is gone, `m` is frozen at 185, and `GenericList.swift` carries no `WaterfallGrid` reference. The D-36 auto-load pagination is preserved as the shipping behavior, the legacy `columnsInPortrait`/`columnsInLandscape` reads are deleted, `DeviceUtil` is untouched, and the full suite is green.**

## Accomplishments
- **Finalized `MasonryLayout.swift`:** removed the temporary `os.Logger` instance, the `import OSLogExt`, and the `proposal.width` debug line from `sizeThatFits`; the layout is now the clean synchronous form. Froze `minCellWidth` at 185 (SR-1 `keep-185`) and rewrote the doc comments to record the frozen `m` with the measured bands, the private-policy intent (D-35, liftable unchanged by Phase 6), and the synchronous no-flash/no-async-hop rationale (D-33). Reworded the "no screen/device read" doc line so the literal `UIScreen`/`DeviceUtil` tokens no longer appear anywhere in the file.
- **Completed the `GenericList.swift` production swap:** dropped `import WaterfallGrid`; deleted the `columnsInPortrait`/`columnsInLandscape` computed vars (the two legacy reads die with the component, D-34); removed the spike's `import OSLogExt` + file-top `logger` + the `logger.debug("fetchMore auto-trigger…")` line. Refreshed the row comment from spike/rollback framing to the production reality. Preserved the D-36 auto-load exactly: `FetchMoreFooter` inside the `VStack` masonry row, the `onScrollPhaseChange`/`onScrollGeometryChange` trigger, and the `isUserScrolling`/`lastAutoFetchCount`/`fetchMoreThreshold` guards.
- **Swept two dead imports** that became unused as a direct consequence of the above: `SFSafeSymbols` (only the now-removed chevron footer used it) and `AppTools` (only `DeviceUtil.isPadWidth` in the deleted column vars used it).

## Task Commits

Each task was committed atomically:

1. **Task 1: Finalize MasonryLayout.swift — remove spike logging, lock at frozen m, document the policy** — `bcb61ea2` (feat)
2. **Task 2: Complete the GenericList.swift production swap and delete the legacy column reads** — `e682d53a` (feat)

## Files Created/Modified
- `AppPackage/Sources/GalleryListComponents/MasonryLayout.swift` — spike logger/import/log line removed; `m` frozen at 185 with updated policy doc comments (D-33/D-35); no `UIScreen`/`DeviceUtil` token remains.
- `AppPackage/Sources/GalleryListComponents/GenericList.swift` — `WaterfallGrid`/`OSLogExt`/`SFSafeSymbols`/`AppTools` imports removed; `columnsInPortrait`/`columnsInLandscape` deleted; `logger` + debug line removed; production `MasonryLayout` row with the D-36 auto-load preserved.

## Decisions Made
- **`m` unchanged (185):** SR-1 chose `keep-185`, so the `columnCount` test table needs no re-baselining — the Plan 01 suite already asserts the real bands. Task 1's "touch the test file only if `m` changed" branch did not apply.
- **Removed `SFSafeSymbols` + `AppTools` imports:** not named in the plan, but both were rendered dead by this plan's/the spike's deletions; leaving them would be an unused-import smell. The full build confirms nothing else in the file needed them.
- **`WaterfallList` struct name kept:** it is module-internal and is replaced wholesale in Phase 6's decomposition; renaming now is out of scope.

## Deviations from Plan

### 1. [Additive cleanup] Removed two now-dead imports beyond the plan's named list

- The plan named `import WaterfallGrid` and `import OSLogExt` for removal. Deleting the chevron footer (spike) and the `DeviceUtil` column reads (this plan) also made `import SFSafeSymbols` and `import AppTools` unused. Removed both so the file has no dangling imports. No behavior change; the full suite and the SwiftLint build-tool plugin pass clean.

### 2. [Environment] Test destination + scheme resolution

- The plan's `<verify>` hard-codes `-destination '…name=iPhone 16 Pro'` (not installed) and `-scheme AppPackage-Package`. Ran against the booted iPhone Air by id; the `AppPackage-Package` scheme resolves only from the `AppPackage/` package directory (the repo-root `EhPanda.xcodeproj` context does not expose it), so the test was invoked from there. No source change. (Same simulator substitution noted in 02-01/02-02 summaries.)

**Total deviations:** 1 additive cleanup (dead imports) + 1 environment (destination/scheme). No scope creep; no behavior change.

## Issues Encountered
- Benign negative-path test logs surfaced in the run (`[DownloadCoordinator] Download failed … Network Error`, `[SettingReducer] Igneous refresh failed`, `[LoginReducer] Login failed`) — these are expected outputs of failure-path tests, not failures. All Swift Testing runs reported `✔ … passed` (424 tests total, 0 failures).

## User Setup Required
None.

## Next Phase Readiness
- The production swap builds and the full suite is green with the app-owned `MasonryLayout` live; `GenericList.swift` has no `WaterfallGrid` reference.
- **Plan 04** removes the `WaterfallGrid` dependency from `AppPackage/Package.swift`, regenerates `Package.resolved`, and takes the checkpoint decision on the `AboutView` acknowledgement row. After this plan the dependency is declared but unreferenced — Plan 04's removal should build clean.
- `DeviceUtil.isPadWidth` and its five other consumers remain untouched (Phase 5 / UIARCH-01 scope, D-34).

## Self-Check: PASSED

- Both task commits present (`bcb61ea2`, `e682d53a`).
- `grep -c WaterfallGrid GenericList.swift` = 0; `grep -c 'OSLogExt\|logger' GenericList.swift` = 0; `grep -c 'columnsInPortrait\|columnsInLandscape' GenericList.swift` = 0; `grep -c 'Logger(' MasonryLayout.swift` = 0; `grep -c 'UIScreen\|DeviceUtil' MasonryLayout.swift` = 0.
- `MasonryLayout {`, `.animation(nil, value: galleries)`, `.listStyle(.plain)`, `onScrollGeometryChange`, `onScrollPhaseChange`, `lastAutoFetchCount` all present in `GenericList.swift`; no `chevron`.
- `git diff AppPackage/Sources/AppTools/DeviceUtil.swift` empty.
- `xcodebuild test -scheme AppPackage-Package` → `** TEST SUCCEEDED **`, exit 0, 424 tests / 0 failures; SwiftLint plugin clean.

---
*Phase: 02-native-masonry-grid-swap*
*Completed: 2026-07-11*
