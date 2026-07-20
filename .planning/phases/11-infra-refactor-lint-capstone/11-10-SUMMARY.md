---
phase: 11-infra-refactor-lint-capstone
plan: 10
subsystem: ui-lifecycle
tags: [tca, swiftui, lifecycle, lint, setting, downloads, filters]
requires:
  - "Presentation-driven lifecycle shapes from 11-07/11-08/11-09"
  - "`tabPresentationEffect` (11-07) as the tab-root seam"
provides:
  - "`SettingPath.State.onPresentedAction` — every Setting screen's load, declared on the route"
  - "`SettingReducer.present` — push-and-start in one expression"
  - "Dismissal interception in `SettingReducer` for the EhSetting profile teardown"
  - "`EhSetting.empty(ehProfiles:)` — a fixture lever that avoids restating forty defaults"
affects:
  - "AppFeature (`tabPresentationEffect` now starts the Downloads tab)"
  - "HomeFeature / SearchFeature / DetailFeature (six Filters presenters)"
  - "AppModels (`EhSetting.empty` refactored into a parameterized form)"
tech-stack:
  added: []
  patterns:
    - "`StackAction.popFrom` as the dismissal-interception seam — `forEach` runs the parent *before* the pop, so the popped element's final state is still readable"
    - "Route-key dedupe: value equality stops identifying duplicates once presentation mutates the top element"
key-files:
  created:
    - AppPackage/Tests/SettingFeatureTests/SettingPresentationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsPresentationLifecycleTests.swift
    - AppPackage/Tests/HomeFeatureTests/FiltersPresentationLifecycleTests.swift
  modified:
    - AppPackage/Sources/SettingFeature/SettingPath.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/AppModels/Support/EhSetting.swift
    - AppPackage/Sources/FiltersFeature/FiltersView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
    - AppPackage/Tests/SettingFeatureTests/AccountSettingReducerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerRefreshTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
decisions:
  - "All 8 sites migrated. Zero D-02 exception candidates from this plan — the onDisappear teardown found a real seam (`StackAction.popFrom`) rather than needing one."
  - "AccountSetting's login re-check needs no re-fire: its jar subscription outlives the login push, and login state on screen is read from `@SharedReader(.didLogin)`, which the same jar feeds. Pitfall 4 resolved by observation, not by re-firing."
  - "`SettingPath` dedupe now compares route, not value — presentation mutates the top element, so a fresh `.init()` no longer equals it. Caught by an existing test; a Rule 1 bug this migration would otherwise have shipped."
  - "`EhSettingReducer.setDefaultProfile` deleted rather than re-sent: the popped child's effects are cancelled by the pop, so the parent runs the write itself, and the action had exactly one call site."
metrics:
  duration: ~70 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 10: Lifecycle Migration — Setting / Filters / Downloads Summary

All 8 lifecycle sites across SettingFeature, FiltersFeature and DownloadsFeature migrated to presentation-driven lifecycle. The three modules are lifecycle-modifier-free with **zero** exception candidates, and no TCA action named `onAppear`/`onDisappear` survives in any of them.

## Site count

Plan said 8. Re-enumerated at HEAD before starting: **8** actual modifier sites — the first plan count in this phase that was exact. Plus two `onAppear`-named actions in DownloadsFeature and one in SettingFeature, all renamed.

| # | Site | Where it went |
|---|---|---|
| 1 | `AccountSettingView:57` cookie load + jar subscription | `AccountSettingReducer.onPresented`, sent on push |
| 2 | `EhSettingView:42` `fetchEhSetting` | sent on push via `SettingPath.State.onPresentedAction` |
| 3 | `EhSettingView:47` profile teardown (`onDisappear`) | `SettingReducer`'s `.path(.popFrom)` intercept |
| 4 | `GeneralSettingView:138` `calculateWebImageDiskCache` | sent on push |
| 5 | `AppActivityLogsView:50` `refreshAvailableRuns` | sent on push |
| 6 | `FiltersView:49` `fetchFilters` | all six presenting reducers send it when they set the destination |
| 7 | `DownloadsView:54` tab-root load | `AppReducer.tabPresentationEffect(for: .downloads)` |
| 8 | `DownloadsView+Subviews:110` inspector load | `DownloadsReducer.inspectorButtonTapped` |

## Presentation pairing

**Setting (sites 1, 2, 4, 5).** The pairing lives on the route, matching 11-08's gallery shape: `SettingPath.State.onPresentedAction` maps each screen to its load action, `appendGuardingDuplicate` now returns the new `StackElementID?`, and a single private `SettingReducer.present(_:_:)` pushes and sends in one expression. All six push sites (`settingRowTapped`, `pushLogin`, and the four `delegate`-driven ones) route through it, so a Setting screen added without a declared load is a visible omission on the route enum rather than a permanently blank screen.

**Filters (site 6).** Six presenters — Frontpage, Popular, Watched, Search, SearchRoot, DetailSearch — each already had an identical `state.destination = .filters(FiltersReducer.State())` line and now each sends `.destination(.presented(.filters(.fetchFilters)))`. No shared helper: the six live in four modules with four different `Action` types, so a generic seam would have cost more than the six one-line sends.

**Downloads (sites 7, 8).** The tab root hooks tab activation, which `tabPresentationEffect` already owned for Home/Favorites/Search — its `case .downloads, .setting: return .none` split into a `.downloads` send and a `.setting` no-op. `hasLoadedInitialDownloads` already made the action idempotent, so re-activating a populated tab still only refreshes folders. The inspector is a `@Presents` sheet with one construction site and takes 11-08's modal shape.

## The `onDisappear` teardown (site 3)

The plan expected this one to need a documented exception. It did not: `forEach` runs the parent reducer **before** it pops the element (documented behaviour — "gives the parent feature an opportunity to inspect the child state one last time"), so `SettingReducer` reads the popped `EhSettingReducer.State` on `.path(.popFrom(id:))` and persists the last-viewed EhPanda profile itself. It has to be the parent that runs it: the child's own effects are cancelled by the pop, so a send to the element would be dropped.

`EhSettingReducer.Action.setDefaultProfile` was deleted rather than kept — the view's `onDisappear` was its only call site, and the parent already owns this exact cookie write in `handleFetchEhProfileIndexDone`.

**Known parity gap, deliberate:** re-selecting the Setting tab clears the whole stack via `path.removeAll()` in `AppReducer`, which is not a `popFrom`, so the profile is not persisted on that path. The old `onDisappear` did fire there. This is a narrow case (tab reselect while sitting on the EhSetting screen, having changed profile but not submitted) and closing it means teaching the tab-reselect branch about child teardown — outside this plan's diff. Flagged below.

## Pitfall 4 — AccountSetting's login-state re-check

Audited: **no re-fire is needed, and none was dropped.**

`AccountSettingReducer.onAppear` did two things — `loadCookies` once, and start a `cookieClient.cookiesDidChange()` subscription. That subscription is the re-check. It outlives a push of the login screen (the Account element stays on the stack, so TCA does not cancel its effects) and reloads the cookie rows on every jar change. The login/logout state the screen renders is `@SharedReader(.didLogin)` in `AccountSection`, fed by the same jar. So returning from the in-app login flow updates the screen through observation, exactly as it did before — the `onAppear` re-fire was redundant with machinery that already existed.

The reducer case carries a comment recording this, so the next reader does not mistake the single fire for a lost refresh.

## Rule 1 bug found and fixed: stack dedupe

`settingRowTappedGuardsAgainstAdjacentDuplicate` failed after the migration. `appendGuardingDuplicate` deduped by **value** (`last != element`), which worked only because a pushed screen's state stayed identical to a fresh `.init()`. Presentation-driven loading breaks that: the moment Account is pushed it loads cookies, so a second tap no longer compares equal and the screen stacks twice.

Fixed by comparing a `routeKey` (the case) instead, matching the gallery stacks' guard. Setting screens carry no per-screen identity, so the case alone is the route. `SettingPresentationTests.dedupedPushStartsNothing` pins the follow-on invariant: a deduped push must also start nothing.

## Verification

- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings (run after each task).
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures (63s).
- SwiftLint over `AppPackage/Sources AppPackage/Tests App ShareExtension` — **clean, 0 output**.
- Lifecycle-token grep across SettingFeature + FiltersFeature + DownloadsFeature — **0 matches**. Remaining repo-wide hits are ReadingFeature's three documented exceptions (11-09) and plan 11-11's three component sites.
- `onAppear`/`onDisappear`-named actions in the three modules — **0**. All remaining textual hits are prose comments.
- `.swiftlint.yml` untouched — the `lifecycle_modifiers` flip belongs to 11-11.
- `LINT-01` left open — it flips at 11-29.

New tests: `SettingPresentationTests` (route→load mapping for all eleven screens, three store-level push pairings, dedupe-starts-nothing, and both pop branches), `DownloadsPresentationLifecycleTests` (tab activation, inspector presentation), `FiltersPresentationLifecycleTests` (Frontpage standing in for the six identical presenters).

## Deviations from Plan

### Auto-fixed / expanded scope

**1. [Rule 1 - Bug] Stack dedupe compared value, not route**

- **Found during:** Task 1
- **Issue:** Detailed above. An existing test caught it; unfixed it would have let a rapid double-tap on a Setting row push the same screen twice.
- **Fix:** `SettingPath.State.routeKey`; `appendGuardingDuplicate` compares it.
- **Commit:** `52a30332`

**2. [Rule 3 - Blocking] Nine files outside the plan's `files_modified` were touched**

- **Found during:** Tasks 1 and 2
- **Issue:** Neither Filters nor the Downloads tab root has a presenting reducer inside its own module. The six Filters presenters live in HomeFeature (×3), SearchFeature (×2) and DetailFeature; the Downloads tab seam lives in AppFeature. Leaving any one unpaired ships a Filters sheet showing defaults instead of the user's saved filters — which the first edit then writes back, silently destroying them.
- **Fix:** Paired all six presenters and `tabPresentationEffect`.
- **Commit:** `1d43fdf3`

**3. [Rule 3 - Blocking] `AppModels.EhSetting.empty` refactored into `empty(ehProfiles:)`**

- **Found during:** Task 1
- **Issue:** Testing the pop teardown needs an `EhSetting` carrying a *named* `EhPanda` profile; `.empty`'s profile is unnamed, so `ehpandaProfile` is nil and the teardown is a no-op. `EhSetting.init` takes forty arguments, so a fixture meant restating all of them in the test.
- **Fix:** `.empty` became `.empty(ehProfiles: [.empty])` over a new parameterized `empty(ehProfiles:)`. No behaviour change; the existing constant is byte-identical.
- **Commit:** `52a30332`

**4. [Rule 3 - Blocking] Three existing tests needed dependency stubs or relaxation**

- **Found during:** Tasks 1 and 2
- **Issue:** Same cause as 11-08's deviation 3 — presenting now runs the child's effects inside the presenter's store. `SettingReducerNavigationTests` hit an unimplemented `libraryClient`/`logsClient` on every General/Account/Logs push; `DownloadAutomationTests`' tab-fallback test hit an unimplemented `downloadClient` once landing on Downloads started the tab.
- **Fix:** Stubbed the reached clients (`.noop`), added the two `calculateWebImageDiskCache` receives to the two exhaustive Setting tests, and had the automation test assert the new `.downloads(.onPresented)` coupling before relaxing.
- **Commits:** `52a30332`, `1d43fdf3`
- **Note:** no assertion was weakened to make a test pass; the added receives are new, exact assertions.

**5. [Scope] `accountDelegatePushEhSettingAppendsEhSetting` replaced by a mapping assertion**

- **Found during:** Task 1
- **Issue:** Presenting EhSetting now sends `fetchEhSetting`, and `EhSettingRequest` takes its `URLSession` as an `init` default the reducer never overrides. A store-level push of that screen would issue a **real network request** from the test suite.
- **Fix:** The delegate-push store test was replaced by an exhaustive route→load mapping assertion in `SettingPresentationTests` covering all eleven screens, including `.ehSetting`. The account→login delegate push is still asserted at store level. The lost coverage is exactly the piece the missing network seam blocks; the file carries a comment saying so.

## D-02 exception candidates for owner review (11-29)

**None.** All 8 sites migrated. Nothing in these three modules needs a `swiftlint:disable:next lifecycle_modifiers` directive from 11-11.

## Flagged for owner review

**1. Parity gap: EhSetting profile teardown on tab reselect.** Detailed above. Re-selecting the Setting tab calls `path.removeAll()`, which is not a `popFrom`, so the pop intercept does not fire and the last-viewed EhPanda profile is not persisted. Reachable only by opening EhSetting, changing the profile picker, and then tapping the Setting tab bar item rather than going back. Closing it means routing the tab-reselect clear through a teardown-aware path — a behaviour change in `AppReducer` outside this plan's remit. Worth a decision, not a rush.

**2. Downloads no longer refreshes folders on pop-back.** The old view `onAppear` re-fired whenever the tab's root view reappeared, including after popping back from a pushed gallery detail; on that path it re-ran `fetchFolders`. Tab activation now fires once per activation. Downloads themselves stay live through `observeDownloads`, and every folder mutation already refetches, so the only way to see a stale folder list is an external change to the folder set while a detail screen is open. Judged parity-equivalent; flagged because it is a real timing change.

**3. Device UAT: the Filters sheet.** Six screens present it and all six were changed the same way. UAT: from Frontpage, Popular, Watched, Search (both the root search bar and a search result), and a gallery's "search this tag" screen, open the filter sheet and confirm it shows the filters you last saved rather than defaults — then edit one, close, reopen, and confirm the edit stuck.

**4. Device UAT: Setting screens.** Open Account, General, EhSetting (via Account → Account Configuration) and Activity Logs and confirm each populates as before: cookie rows filled, image-cache size shown, EhSetting form loaded, run list populated. Then on EhSetting change the profile and navigate back, and confirm the app reopens on that profile next time.

**5. Test coverage remains asymmetric — still no network seam.** Unchanged from 11-07/11-08/11-09: `NetworkingFeature` request types take `urlSession: URLSession = .shared` as an `init` default and reducers never pass one, so a `TestStore` cannot stub a fetch. Here it cost the EhSetting store-level push test (deviation 5). Root-fixing means threading an injectable session through every request type — real work, still well outside this phase.

## Self-Check: PASSED

- `AppPackage/Tests/SettingFeatureTests/SettingPresentationTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadsPresentationLifecycleTests.swift` — FOUND
- `AppPackage/Tests/HomeFeatureTests/FiltersPresentationLifecycleTests.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-10-SUMMARY.md` — FOUND
- Commit `52a30332` — FOUND
- Commit `1d43fdf3` — FOUND
- Commit `fca74f4a` — FOUND
