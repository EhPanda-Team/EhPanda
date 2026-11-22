---
status: complete
quick_id: 261123-1ep
date: 2026-11-23
commits:
  - d0f7b7655
  - 31b5c32d2
---

# 261123-1ep: Save Search on search results pages

Both search results pages (the Search tab's results and the tag search results reached from a
gallery's details) have a **Save Search** action in the toolbar overflow menu, right after Quick
Search. It opens a sheet that holds only the New Saved Search editor, with the page's keyword as
the search terms and an empty name. Cancel and Confirm both return to the results, and Confirm
saves first. The action is disabled when the keyword is empty, when a saved search already runs
the same text, or when the saved-search limit is reached. This follows owner decisions D-01 to D-07
in [PLAN.md](PLAN.md).

## Changes

- `d0f7b7655` Save a results keyword as a saved search
  - `QuickSearchFeature/NewSavedSearchFeature.swift`: a new reducer for the sheet. It holds the
    draft (its identifier comes from the presenter's `uuid` dependency), appends it under the limit
    on Confirm and dismisses itself. It also has `canSave(keyword:into:)`, the one eligibility rule
    both hosts use: whitespace-trimmed, compared with each saved search's `effectiveSearchText`.
  - `QuickSearchFeature/NewSavedSearchView.swift`: a NavigationStack rooted at the existing
    `EditSavedSearchView`, with a Cancel button. `EditSavedSearchView` now handles its own submit
    focus (name, then search terms), so the Quick Search list and the new sheet share it. On
    `develop` the editor also carries tag suggestions, so the sheet reads the tag translator and
    setting like Quick Search does.
  - `SearchReducer` / `DetailSearchReducer`: a `newSavedSearch` destination, `canSaveSearch`, a
    guarded `saveSearchButtonTapped` and present haptics. Their views add the sheet and the menu
    action, disabled from `canSaveSearch`. The menu uses a plain action button, not a closure
    Binding.
  - `AppComponents/ToolbarItems.swift`: `SaveSearchButton` (`text.badge.plus`, the add counterpart
    of Quick Search's `text.magnifyingglass`).
  - Shared catalog key `save_search` and its `.RLocalizable.saveSearch` forwarder. Each locale is
    written to match its own catalog's name for saved searches: en "Save Search", de "Suche
    speichern", ja 「検索を保存」, ko 「검색 저장」, zh-Hans 「保存为快速搜索」, zh-Hant
    「儲存為快速搜尋」. The two Chinese locales call saved searches 快速搜索/快速搜尋, as their
    existing editor titles do.
  - Scroll-edge inventory row for the new sheet (its Form root already carries the policy).
- `31b5c32d2` Test saving a keyword as a saved search
  - New `QuickSearchFeatureTests` target (with `.swiftlint.yml`, in `FeatureTests.xctestplan`, set
    parallelizable): prefill, eligibility (empty, duplicate by content and by name-only text, limit)
    and Confirm (appends the edited draft and dismisses; at the limit it saves nothing but still
    dismisses).
  - `SearchFeatureTests/SaveSearchTests` and `DetailFeatureTests/DetailSearchSaveSearchTests`: the
    action presents the prefilled editor, does nothing for an empty or already-saved keyword, and
    Confirm saves and closes the sheet back to the results.
  - Every case uses its own in-memory defaults and an incrementing `uuid`. No serialization.

## Verification

- `xcodebuild build -scheme EhPanda` (generic iOS Simulator, Xcode 27.2): BUILD SUCCEEDED, with
  0 errors and 0 warnings in the log.
- Standalone SwiftLint `--strict` over every touched source and test path: 0 violations.
- FeatureTests plan with `-only-testing` QuickSearchFeatureTests, SearchFeatureTests and
  DetailFeatureTests on a task-created iPhone Air (iOS 27.2): TEST SUCCEEDED, and all 16 new tests
  (18 cases) passed. AppToolsTests (source-census tests) passed on its own (61 cases).
- One case, `confirmingAppendsTheEditedDraftAndDismisses`, took 3.7 s when its target ran alone
  (57 s under load from the three targets running together). The case that does not write takes
  0.1 s, so the time is the in-memory defaults write, not a wait in the code. A `finish()`
  timeout would have failed the case.
- Not done: no run in the app or simulator UI.

## Notes

- The worktree was cut from `main`. Before the first commit the work was rebased onto `develop`
  (531db50b1), where the project's work and the source note live.
- The planning and execution steps ran inline in the orchestrating session, with no planner or
  executor subagents, because the owner's decisions and the code context were already in hand.
- No analytics signal was added. The signal set was signed off in 20-13, and a "saved from
  results" signal would need the owner's decision.
