---
phase: 02-native-masonry-grid-swap
plan: 04
subsystem: build
tags: [spm, dependency-removal, waterfallgrid, l10n, xcstrings, acknowledgements]

# Dependency graph
requires:
  - phase: 02-native-masonry-grid-swap (plan 03)
    provides: production MasonryLayout swap, no WaterfallGrid reference in source
provides:
  - WaterfallGrid removed from Package.swift (declaration, product alias, both target deps) and Package.resolved (SR-4)
  - Dead spike osLogExt module dependency removed from the galleryListComponents target (Plan-03 residue)
  - AboutView acknowledgements refreshed — WaterfallGrid row dropped; Colorful→ColorfulX and SwiftCommonMark→swift-markdown repointed (value/link/l10n key names); vendored (UIImageColors, SystemNotification) and forked (SwiftyOpenCC) rows kept
affects: [phase-03 (SwiftUIPager removal will follow the same acknowledgement-refresh pattern)]

# Tech tracking
tech-stack:
  added: []
  removed:
    - "WaterfallGrid (paololeonardi/WaterfallGrid) — SPM dependency fully removed"
    - "osLogExt module dependency on galleryListComponents target — leftover spike scaffolding"
  patterns:
    - "String Catalog key rename = generated-symbol rename: renaming acknowledgement.colorful → acknowledgement.colorfulX changes the build-generated .Constant.acknowledgementColorfulX symbol; AboutView updated in lockstep"

key-files:
  created: []
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - AppPackage/Sources/SettingFeature/Components/AboutView.swift
    - AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings

key-decisions:
  - "Owner: remove the WaterfallGrid acknowledgement row (not the Phase-1 keep-precedent) AND repoint the two other truly-stale rows to their replacements — Colorful→ColorfulX, SwiftCommonMark→swift-markdown — updating display text, link URL, and the l10n key names"
  - "Owner: KEEP the vendored (UIImageColors→ImageColors, SystemNotification→SystemNotificationExt) and forked (SwiftyOpenCC/OpenCC) rows — their code still ships, so the rows are valid attribution"
  - "Removed the dead osLogExt spike dependency Plan 03 should have swept (its own manifest comment flagged it for Plan-03 removal); folded into this plan's manifest edit"

# Coverage
coverage:
  - id: D1
    description: "WaterfallGrid absent from Package.swift (declaration, product alias, both target deps) and Package.resolved; no source import (SR-4)"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "grep -c WaterfallGrid Package.swift = 0; grep -ci waterfallgrid Package.resolved = 0; grep -rc 'import WaterfallGrid' Sources/ = 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Full package builds and whole suite green after removal"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package → TEST SUCCEEDED, 424 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "AboutView acknowledgement disposition is an explicit owner decision, not a silent drop"
    requirement: DEP-04
    verification:
      - kind: manual
        ref: "Owner: remove WaterfallGrid row; repoint Colorful→ColorfulX & SwiftCommonMark→swift-markdown; keep vendored/forked rows"
        status: pass
    human_judgment: true

# Metrics
duration: 12min
completed: 2026-07-11
status: complete
---

# Phase 2 Plan 4: WaterfallGrid Dependency Removal + Acknowledgement Refresh Summary

**WaterfallGrid is gone from `Package.swift` and `Package.resolved` (SR-4), no source imports it, and the full suite is green. The dead osLogExt spike dependency Plan 03 left behind was swept. The AboutView acknowledgement disposition was taken as an explicit owner decision: the WaterfallGrid row is removed, the two other truly-stale rows are repointed to their real replacements (Colorful→ColorfulX, SwiftCommonMark→swift-markdown, including link URLs and l10n key names), and the vendored/forked rows are kept as valid attribution.**

## SR-4 Verification (grep results)

| Check | Result |
|---|---|
| `grep -c 'WaterfallGrid' AppPackage/Package.swift` | 0 |
| `grep -ci 'waterfallgrid' AppPackage/Package.resolved` | 0 (only the derived `originHash` changed; no version drift) |
| `grep -rc 'import WaterfallGrid' AppPackage/Sources/` | 0 |
| `xcodebuild test -scheme AppPackage-Package` | `** TEST SUCCEEDED **`, 424 tests, 0 failures |

## Acknowledgement-Row Decision (Task 2 checkpoint)

The plan offered keep-ack (Phase-1 precedent) vs remove-ack for the WaterfallGrid row. The owner chose **remove**, and extended the scope: refresh the other stale rows too. Each acknowledged library was cross-checked against the current dependency set to separate *truly gone* from *replaced/vendored*:

| Row | Status | Action |
|---|---|---|
| WaterfallGrid | removed this phase | **Row deleted**; both `acknowledgement.waterfallGrid[_link]` keys removed across all locales |
| SwiftCommonMark | removed Phase 1, replaced by Apple swift-markdown (not vendored) | **Repointed → swift-markdown**: value `SwiftCommonMark`→`swift-markdown`, link →`github.com/apple/swift-markdown`, key `acknowledgement.swiftCommonMark`→`acknowledgement.swiftMarkdown` (all 6 locales) |
| Colorful | replaced Phase 1 by ColorfulX (same author, bundled) | **Repointed → ColorfulX**: value/link were already ColorfulX from Phase 1; renamed the stale key `acknowledgement.colorful`→`acknowledgement.colorfulX` |
| UIImageColors | vendored → app-owned `ImageColors` (jathu attribution kept) | **Kept** — code still ships, valid attribution |
| SystemNotification | vendored → app-owned `SystemNotificationExt` | **Kept** — code still ships, valid attribution |
| SwiftyOpenCC | still bundled as EhPanda-Team fork (product `OpenCC`) | **Kept** — still a dependency |
| Kanna, Kingfisher, SwiftUIPager, SFSafeSymbols, EhTagTranslationDatabase, TCA | still bundled | **Kept** |

AboutView drops from 12 to 11 acknowledgement rows. Because the `.Constant.*` symbols are generated from the String Catalog keys, renaming a key renames its build-generated symbol; AboutView's references were updated in lockstep and the build confirms the new symbols (`acknowledgementColorfulX`, `acknowledgementSwiftMarkdown`) resolve.

## Task Commits

1. **Task 1: Remove WaterfallGrid from Package.swift + regenerate Package.resolved** (with the dead osLogExt spike dep swept in the same manifest edit) — `7a5bb0bf` (feat)
2. **Task 2: Acknowledgement-row refresh (owner decision)** — `171b3ebc` (feat)

## Files Created/Modified
- `AppPackage/Package.swift` — removed the four WaterfallGrid lines (declaration, product alias, app-target dep, galleryListComponents-target dep) with trailing-comma repair; removed the dead `.module(.osLogExt)` spike dependency + its comment from the galleryListComponents target.
- `AppPackage/Package.resolved` — regenerated via `swift package resolve --package-path AppPackage`; the `waterfallgrid` pin dropped, `originHash` updated, no other pin changed.
- `AppPackage/Sources/SettingFeature/Components/AboutView.swift` — deleted the WaterfallGrid row; repointed the Colorful and SwiftCommonMark rows to the new `.Constant.acknowledgementColorfulX`/`…SwiftMarkdown` symbols.
- `AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings` — deleted both `acknowledgement.waterfallGrid[_link]` keys (all locales); renamed `colorful[_link]`→`colorfulX[_link]`; renamed `swiftCommonMark[_link]`→`swiftMarkdown[_link]` and repointed value→`swift-markdown` / link→`github.com/apple/swift-markdown` across all 6 locales (`shouldTranslate:false`, so every locale carries the value verbatim).

## Decisions Made
- **Remove + repoint, not blanket-remove:** the owner's "remove stale rows" was applied precisely — only libraries that ship in *no* form (WaterfallGrid, SwiftCommonMark, Colorful) were removed/repointed; libraries whose code the app still ships (vendored UIImageColors/SystemNotification, forked SwiftyOpenCC) were kept as valid attribution rather than stripped.
- **Repoint over delete** for SwiftCommonMark and Colorful: the app *does* ship their replacements (swift-markdown, ColorfulX), so the courtesy row is retargeted to the real successor instead of dropped — ColorfulX was previously bundled but unacknowledged; it is now acknowledged.
- **osLogExt spike dep removed here:** Plan 03's manifest comment marked it for Plan-03 removal but it was missed; caught during this plan's manifest edit and swept (dead — no GalleryListComponents source imports OSLogExt after Plan 03).

## Deviations from Plan

### 1. [Owner-directed scope expansion] Refreshed two more stale acknowledgement rows

- The plan's remove-ack option covered only the WaterfallGrid row. The owner directed also refreshing the other stale rows, repointing SwiftCommonMark→swift-markdown and Colorful→ColorfulX (value, link, and l10n key names) rather than deleting them, and keeping the vendored/forked rows. Additive, owner-approved; full suite re-run green.

### 2. [Residue cleanup] Removed the dead osLogExt spike dependency

- The `.module(.osLogExt)` dependency on the galleryListComponents target was spike scaffolding whose own comment said "Removed in Plan 03." Plan 03 removed the source imports but left the manifest dependency. Swept here (dead code); folded into Task 1's manifest edit since it is the same file.

### 3. [Environment] Test destination + scheme resolution

- `-destination '…name=iPhone 16 Pro'` (not installed) → ran against booted iPhone Air by id; `-scheme AppPackage-Package` resolves only from the `AppPackage/` package directory. No source change. (Same substitution noted across 02-01..02-03.)

**Total deviations:** 1 owner-directed scope expansion + 1 residue cleanup + 1 environment. No unapproved scope creep.

## Issues Encountered
- Benign negative-path test logs (`Download failed … Network Error`, `Login failed`) appear in the run output — expected failure-path test output, not failures. All Swift Testing runs `✔ passed` (424 tests, 0 failures).

## User Setup Required
None.

## Next Phase Readiness
- DEP-04 is fully delivered: the app-owned `MasonryLayout` renders the thumbnail grid and WaterfallGrid is removed from the dependency set (SR-4).
- Phase 3 (SwiftUIPager→TabView) will remove SwiftUIPager; its still-valid acknowledgement row should get the same treatment (remove or repoint) at that time.
- `DeviceUtil.isPadWidth` and its five other consumers remain untouched (Phase 5 / UIARCH-01 scope, D-34).

## Self-Check: PASSED

- Both task commits present (`7a5bb0bf`, `171b3ebc`).
- `grep -c WaterfallGrid Package.swift` = 0; `grep -ci waterfallgrid Package.resolved` = 0; `grep -rc 'import WaterfallGrid' Sources/` = 0.
- `Package.resolved` diff = only the waterfallgrid pin + `originHash`; no version drift.
- AboutView = 11 acknowledgement rows; no WaterfallGrid/SwiftCommonMark/bare-Colorful symbols; new `acknowledgementColorfulX`/`acknowledgementSwiftMarkdown` symbols present and build-resolved.
- Constant.xcstrings: waterfall keys gone; swiftMarkdown value=`swift-markdown` & link=`github.com/apple/swift-markdown` in all 6 locales; colorfulX keys present.
- `xcodebuild test -scheme AppPackage-Package` → `** TEST SUCCEEDED **`, exit 0, 424 tests / 0 failures.

---
*Phase: 02-native-masonry-grid-swap*
*Completed: 2026-07-11*
