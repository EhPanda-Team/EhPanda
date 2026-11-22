---
status: complete
quick_id: 261123-1ep
date: 2026-11-23
commits:
  - d0f7b7655
  - 31b5c32d2
  - 2c915e852
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
- Simulator UI check (owner request, 2026-11-23), on a Debug build of `0358eac52` running on a
  task-created iPhone Air (iOS 27.2) with the stubbed network fixtures:
  - Search tab results for `language:english`: Save Search is right after Quick Search and enabled.
    The sheet shows Cancel and Confirm, an empty name and the keyword in Search Terms. Cancel
    returned to the results without saving. Confirm with the name "English" returned to the
    results. The entry appeared in Quick Search, and the action was then disabled.
  - Submitting the name moved focus to Search Terms, both in the new sheet and in Quick Search's
    own New Saved Search editor, which confirms the moved submit handling.
  - Detail tag search results (`o:"non-h imageset$"`): the same menu position and sheet. Confirm
    saved the entry and disabled the action.
  - en, de, ja, ko, zh-Hans and zh-Hant: the label fits the menu in each. The action stayed
    disabled for the saved keyword across relaunches.

## Notes

- The worktree was cut from `main`. Before the first commit the work was rebased onto `develop`
  (531db50b1), where the project's work and the source note live.
- The planning and execution steps ran inline in the orchestrating session, with no planner or
  executor subagents, because the owner's decisions and the code context were already in hand.
- No analytics signal was added. The signal set was signed off in 20-13, and a "saved from
  results" signal would need the owner's decision.
- **Defect found during the UI check, fixed in `2c915e852` (owner go-ahead, 2026-11-23):** in the
  saved-search editor, the Search Terms `TextEditor` laid out at one line (22 pt) from the second
  presentation on (the first was 38 pt), so text was clipped at the top and bottom of its row. It
  showed in the new sheet and in Quick Search's existing Edit Saved Search screen.
  - Cause: the `TextEditor`'s own sizing in a form row. With the tag-suggestion row taken out, the
    clipping was identical (22 pt on the second and later presentations), so 261113-h72's
    suggestions are not the cause.
  - Fix: Search Terms is now a native `TextField(axis: .vertical)`. It sizes the same on every
    presentation, grows with its text and lines up with the Name field (the editor's text sat 5 pt
    further in). Return now ends editing instead of inserting a newline, which suits a one-line
    query.
  - The owner chose no placeholder (2026-11-23). A text field's label only becomes its
    placeholder, so the label is empty and `.accessibilityLabel(.searchTerms)` names the field for
    VoiceOver, which the `TextEditor` never did. `TagSuggestionView.Source.textEditor` is renamed
    `.multilineField`, with its docs updated.
  - Checked in the simulator: a prefilled sheet opened three times, the empty New Saved Search
    screen, Edit Saved Search with saved text, long text wrapping over three lines, and Return.
    Tag suggestions could not appear there (no tag database on a fresh simulator); their code is
    unchanged apart from the rename.
  - Gate: clean app build (0 warnings), SwiftLint `--strict` clean, and QuickSearchFeatureTests,
    SearchFeatureTests, DetailFeatureTests, AppFeatureTests and AppToolsTests: TEST SUCCEEDED,
    863 cases passed, 0 failed.
