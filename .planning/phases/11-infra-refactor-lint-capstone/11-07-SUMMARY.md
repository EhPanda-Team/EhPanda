---
phase: 11-infra-refactor-lint-capstone
plan: 7
subsystem: ui-lifecycle
tags: [tca, swiftui, lifecycle, lint]
requires:
  - "StackState presentation seams in HomeReducer / SearchRootReducer"
  - "AppReducer tab-activation flow"
provides:
  - "Presentation-driven lifecycle idiom for pushed screens and tab roots"
  - "appendGuardingDuplicate returning the new StackElementID"
  - "HomeFeatureTests target"
affects:
  - "AppFeature (AppReducer tab wiring)"
  - "DetailFeature (GalleryNavigation helper signature)"
tech-stack:
  added: []
  patterns:
    - "Child `onPresented` action sent by the presenting reducer's state transition"
    - "Tab-root `onPresented` sent by AppReducer on tab activation and at launch-ready"
key-files:
  created:
    - AppPackage/Tests/HomeFeatureTests/HomePresentationLifecycleTests.swift
    - AppPackage/Tests/HomeFeatureTests/.swiftlint.yml
  modified:
    - AppPackage/Sources/HomeFeature/HomeView.swift
    - AppPackage/Sources/HomeFeature/HomeReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
    - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
    - AppPackage/Sources/HomeFeature/History/HistoryView.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/SearchFeature/SearchRootView.swift
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/SearchFeature/SearchView.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/DetailFeature/GalleryNavigation.swift
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan
decisions:
  - "Two lifecycle shapes, not one: pushed screens get their `onPresented` from the presenting reducer's append; tab roots get theirs from AppReducer on tab activation."
  - "GalleryCardCell's bloom uses `.onChange(of:initial:)` instead of a lint exception — no D-02 disable was needed anywhere in this plan."
  - "`appendGuardingDuplicate` now returns the new `StackElementID?` (`@discardableResult`) so a deduped push kicks nothing off."
metrics:
  duration: ~55 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 07: Lifecycle Migration — Home / Search / Favorites Summary

All 10 lifecycle-modifier sites across HomeFeature, SearchFeature, and FavoritesFeature migrated to presentation-driven lifecycle. Zero exceptions were needed: the three modules are now lifecycle-modifier-free with no `swiftlint:disable` anywhere.

## Site count

Plan said 10 (Home 7, Search 2, Favorites 1). Re-enumerated at HEAD: **exactly 10** — the plan's count was correct.

| Module | Sites | Where they went |
|---|---|---|
| HomeFeature | 7 | 5 sub-pages → `onPresented` on push; HomeView → tab activation; GalleryCardCell → `.onChange(initial:)` |
| SearchFeature | 2 | SearchView → `onPresented` on push; SearchRootView → tab activation |
| FavoritesFeature | 1 | FavoritesView → tab activation |

## What was built

**Pushed screens (Frontpage, Popular, Toplists, Watched, History, Search).** Each child reducer gained an `onPresented` action carrying exactly what its view's `onAppear` closure did — the `observeDownloads` send plus the fetch-if-empty guard, minus the `DispatchQueue.main.async` hop that only existed to dodge a SwiftUI during-view-update warning. `HomeReducer.sectionTapped` / `.miscTapped` and `SearchRootReducer.pushSearch` now return that action addressed at the element they just appended.

To address it they need the new element's id, so `StackState.appendGuardingDuplicate` (DetailFeature) became `@discardableResult ... -> StackElementID?`. A `nil` return means the push was deduped, which is exactly the case where nothing should start — the dedup guard and the lifecycle guard are now the same guard. All pre-existing call sites compile unchanged.

**Tab roots (Home, Favorites, SearchRoot).** These live for the whole session inside `TabView`, so "presentation" means "this tab became the active one". `AppReducer.tabPresentationEffect(for:)` maps a tab to its root's `onPresented`; it fires from the `else` branch of `.tabBar(.setTabBarItemType)` (a genuine tab switch — the re-tap branch already had its own refresh behaviour) and once at `.setting(.loadUserSettingsDone)` for the tab shown at cold launch. That launch hook is deliberately *after* settings load rather than at `onLaunchFinish`: the fetches read `setting.galleryHost`, which is only known then.

**Renames.** No TCA action named `onAppear` survives in these three modules. No test referenced them (the only `.onAppear` test references are in SettingFeature/DetailFeature/DownloadsFeature — later plans), so nothing broke.

**GalleryCardCell.** The store-less colour-bloom `onAppear` collapsed into the `.onChange(of: colors)` already sitting next to it, using `initial: true` — an appearance-time fire that is not a banned token. Two modifiers became one and no lint exception was needed. See "Flagged" below.

## Verification

- `xcodebuild build -scheme EhPanda` — succeeded, 0 errors, 0 warnings.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (all targets, run twice: once per task).
- New `HomeFeatureTests` — 8/8 pass.
- Lifecycle-token grep across the three modules — **0 matches** (comment mentions only, which the rule excludes via `excluded_match_kinds`).
- `.swiftlint.yml` untouched, per the phase's one-flip-with-the-last-fix rule (11-11).
- `LINT-01` left open — it spans all 30 plans and flips at 11-29.

**A1 (threat T-11-09) verified.** `poppingCancelsTheChildObservation` pushes History, starts a `downloadClient.observeDownloads` stream that never yields and never finishes, pops the element, and awaits `store.finish()`. It completes — proving TCA's `forEach` cancels the child's in-flight effects with its element, so a presentation-started observation cannot outlive its screen. The test hangs if that ever regresses.

## Deviations from Plan

### Auto-fixed / expanded scope

**1. [Rule 3 - Blocking] AppReducer and GalleryNavigation modified, though not in `files_modified`**

- **Found during:** Task 1
- **Issue:** Three of the ten sites are tab roots. A tab root has no presenting reducer inside its own module — the presenter is `AppReducer` in AppFeature. Likewise, addressing a freshly pushed element requires its id, which `appendGuardingDuplicate` (DetailFeature) discarded.
- **Fix:** Added `AppReducer.tabPresentationEffect(for:)` + two call sites and `import AppModels`; made `appendGuardingDuplicate` return `StackElementID?`.
- **Commits:** `cdf8b7d3`, `2278ff33`

**2. [Rule 2 - Missing infrastructure] Created the `HomeFeatureTests` target**

- **Found during:** Task 1
- **Issue:** The plan's `<verify>` blocks name `HomeFeature` and `SearchFeature` schemes; neither exists, and neither module had a test target, so the plan's "assert the load effect on the presentation action" requirement had nowhere to live.
- **Fix:** Registered `HomeFeatureTests` (Package.swift enum case + `.testTarget`, `.swiftlint.yml` with `parent_config`, xctestplan entry) and wrote `HomePresentationLifecycleTests`.
- **Commit:** `cdf8b7d3`

## Flagged for owner review

**1. Test coverage is asymmetric, because there is no network seam.** `NetworkingFeature` request types take `urlSession: URLSession = .shared` as an init default, and reducers construct them without passing one — so a `TestStore` cannot stub a fetch. Only History is exercised end-to-end through the stack (its `fetchGalleries` reads local browsing history and settles offline). The other five pushed screens are covered by asserting `onPresented` against a *populated* state, which proves the guard but not the fetch. SearchFeature and FavoritesFeature got no new test target at all for the same reason. Root-fixing this means threading an injectable session through every request type — real work, and far outside this plan. Flagging rather than inventing a partial seam.

**2. `GalleryCardCell` bloom wants device UAT.** `.onChange(of: colors, initial: true)` is documented to fire at appearance time, the same bucket as `onAppear`, so ColorfulX should still snap `[.black]` first and lerp to the palette. If the initial fire lands *before* the first paint instead, the gradient pops to full intensity with no bloom. Not observable in tests or previews — worth one look on device (dark mode, focused card) during phase verification. If it regressed, the fallback is the D-02 exception the plan anticipated.

**3. Idempotence audit: all sites are idempotent; two behave slightly better than before.**
   - Every migrated fetch is `isEmpty`-guarded and every `observeDownloads` is `.cancellable(cancelInFlight: true)`, so re-presentation is safe.
   - Favorites and Search tab roots now re-run their (guarded) presentation action on *every* tab activation, where `onAppear` fired only on the tab's first build. Net effect: download badges re-subscribe and Search's "recently seen" re-checks on each visit — both already guarded, both arguably more correct. No duplicate loads.
   - Home's launch load now waits for settings instead of racing them. Strictly safer.

**4. Deep-link coverage (Pitfall 4) needed no extra work.** Grep confirms the only construction sites of these six child states are the two presenting reducers touched here. Deep-link, clipboard, and launch-automation routes all enter through `.gallery(...)` / `GalleryPath`, which is Detail's surface (a later plan).

## Self-Check: PASSED

- `AppPackage/Tests/HomeFeatureTests/HomePresentationLifecycleTests.swift` — FOUND
- `AppPackage/Tests/HomeFeatureTests/.swiftlint.yml` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-07-SUMMARY.md` — FOUND
- Commit `cdf8b7d3` — FOUND
- Commit `2278ff33` — FOUND
