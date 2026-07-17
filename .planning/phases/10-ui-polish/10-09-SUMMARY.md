---
phase: 10-ui-polish
plan: 09
subsystem: ui
tags: [swiftui, preview-macro, tca, swiftlint]

# Dependency graph
requires:
  - phase: 10-ui-polish (plan 08)
    provides: "First 8 of 42 preview-struct migrations + the named-case exemplar (DateSeekPickerView)"
provides:
  - "Remaining 34 legacy PreviewProvider structs migrated to the #Preview macro"
  - "Zero legacy preview structs anywhere in the codebase (D-07 global grep gate at zero)"
affects: [10-ui-polish plan 11 (Phase 11 preview ratchet rules)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Whole-screen TCA previews: named #Preview case carrying the existing store construction verbatim (reducer: SomeFeature.init shorthand)"

key-files:
  created: []
  modified:
    - "34 screen files across SettingFeature, HomeFeature, SearchFeature, DetailFeature, and 7 one-each modules"

key-decisions:
  - "Pragmatic D-08 tier: one named case per screen (Initial), Loaded where a .preview fixture already existed — no deep-store matrix built"
  - "TagDetailView preview dropped its .preferredColorScheme(.dark) to satisfy D-09 (no color-scheme pinning)"

patterns-established:
  - "Named #Preview blocks with the store shorthand form for whole-screen TCA views"

requirements-completed: [POLISH-03]

coverage:
  - id: D1
    description: "All 34 remaining legacy PreviewProvider structs migrated to named #Preview macro cases"
    requirement: POLISH-03
    verification:
      - kind: other
        ref: "grep -rnF PreviewProvider AppPackage/Sources AppPackage/Tests App ShareExtension --include=*.swift | wc -l => 0"
        status: pass
      - kind: integration
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'id=<booted-sim>' => BUILD SUCCEEDED, 0 warnings"
        status: pass
      - kind: other
        ref: "swiftlint (artifactbundle) over 34 migrated files => 0 violations"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 09: Complete #Preview Migration Summary

**Migrated the remaining 34 legacy `PreviewProvider` structs to named `#Preview` macro cases, driving the global D-07 grep gate to zero across the whole codebase.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-07-18
- **Tasks:** 3
- **Files modified:** 34

## Accomplishments
- Migrated 17 screens in Task 1 (10 SettingFeature + 7 one-each: ReadingView, TabBarView, FavoritesView, DownloadsView, QuickSearchView, FiltersView, ReadingSettingView)
- Migrated 17 screens in Task 2 (6 HomeFeature + 2 SearchFeature + 9 DetailFeature)
- Global D-07 grep gate now returns zero hits — the full 42-struct inventory (10-08's 8 + this plan's 34) is fully migrated
- Build succeeded with zero warnings; SwiftLint clean over all migrated files

## Task Commits

1. **Task 1: Migrate SettingFeature (10) + one-each screens (7)** - `001e23ef` (refactor)
2. **Task 2: Migrate HomeFeature (6) + SearchFeature (2) + DetailFeature (9)** - `520946f2` (refactor)
3. **Task 3: Global D-07 grep gate + build/lint** - verification only, no code change

## Files Created/Modified

All 34 files had their trailing `struct X_Previews: PreviewProvider { static var previews … }` replaced with a named `#Preview("…")` block preserving the original store/state construction:

- SettingFeature: SettingView, AccountSettingView, AboutView, DownloadSettingView, LaboratorySettingView, AppearanceSettingView, EhSettingView, GeneralSettingView, LoginView, AppActivityLogsView
- one-each: ReadingView, TabBarView, FavoritesView, DownloadsView, QuickSearchView, FiltersView, ReadingSettingView
- HomeFeature: HomeView, ToplistsView, PopularView, WatchedView, HistoryView, FrontpageView
- SearchFeature: SearchRootView, SearchView
- DetailFeature: DetailView, TorrentsView, CommentsView, FolderManagerView, GalleryInfosView, ArchivesView, DetailSearchView, TagDetailView, PreviewsView

## Decisions Made
- **Naming:** `#Preview("Initial")` for default empty-state screens; `#Preview("Loaded")` for the four screens whose old preview already built a `.preview` gallery fixture (ReadingView, DetailView, GalleryInfosView, PreviewsView) and TagDetailView (loaded tag detail). Pragmatic D-08 tier — no deep-store matrix invented.
- **TagDetailView:** removed the legacy `.preferredColorScheme(.dark)` modifier to comply with D-09 (default environment, no color-scheme pinning). This is the only content change beyond the mechanical struct→macro swap.

## Deviations from Plan

None - plan executed exactly as written. (The plan's `xcodebuild -scheme AppPackage-Package` did not exist in this project; the `EhPanda` app scheme was used instead, which compiles every AppPackage module including DEBUG previews. This is a scheme-name substitution to run the same build gate, not a scope change.)

## Issues Encountered
- The plan-specified `AppPackage-Package` scheme and `iPhone 17 Pro` destination were unavailable. Resolved by building the `EhPanda` app scheme (compiles all modules) against the booted `iPhone 17e` simulator by device id.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- POLISH-03 / ROADMAP criterion 12 fully satisfied; D-07 complete codebase-wide.
- No blockers for remaining Phase 10 plans (10-10, 10-11, 10-12).

## Self-Check: PASSED

- All 34 files confirmed migrated (global `PreviewProvider` grep = 0)
- Commits `001e23ef` and `520946f2` exist in git log
- Build succeeded, SwiftLint clean

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
