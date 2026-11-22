# 261123-1ep: Save the current keyword as a saved search

Source: [owner note 2026-11-17](../../notes/2026-11-17-save-keyword-as-saved-search.md), promoted
by the owner's task card on 2026-11-23. Owner decisions were gathered before any code was written
(AskUserQuestion, 2026-11-23) and are locked.

## Owner decisions

- **D-01 Flow:** the action opens a prefilled New Saved Search editor; it does not save silently.
- **D-02 Editor sheet:** the sheet holds only the editor, with Cancel on the leading side and
  Confirm on the trailing side. Both return straight to the search results. The Quick Search list
  is not shown underneath. The existing editor view is reused.
- **D-03 Name:** the name starts empty (it is optional); Search Terms is prefilled with the keyword.
- **D-04 Label and position:** English "Save Search" (zh-Hant 「儲存為快速搜尋」), placed directly
  after Quick Search in the toolbar overflow menu. Each locale is written natively.
- **D-05 Disabled states:** the action is disabled when the keyword is empty, when a saved search
  with the same search text already exists, and when the saved-search limit is reached.
- **D-06 Scope:** both search results pages: the Search tab results (`SearchView`) and the tag
  search results reached from a gallery's details (`DetailSearchView`).
- **D-07 After saving:** Confirm saves and dismisses the sheet, back to the results.

## Implementation decisions (agent, within the owner's decisions)

- The saved keyword is `lastKeyword`, the keyword the results page shows as its title and pages
  with. "Empty" and "already saved" compare whitespace-trimmed text; an existing saved search
  matches by `effectiveSearchText`, the text that tapping it runs.
- A new `NewSavedSearchFeature` reducer in `QuickSearchFeature` owns the editor sheet: it holds the
  draft saved search, appends it under the limit on Confirm and dismisses itself. The eligibility
  rule lives on it as one static function both hosts call, so the rule exists once.
- `EditSavedSearchView` takes over its own submit focus handling (name → search terms → none), so
  the Quick Search list and the new sheet share it instead of each carrying a copy.
- `SaveSearchButton` joins the shared toolbar items in `AppComponents`, labelled from a new
  shared `save_search` key in the Resources catalog with a `.RLocalizable.saveSearch` forwarder.
  Symbol: `text.badge.plus`, the add counterpart of Quick Search's `text.magnifyingglass`.
- No analytics signal is added: the signal set was signed off in 20-13 and needs the owner.

## Tasks

1. Implement the reducer, editor sheet, toolbar action on both hosts, the shared string in all six
   locales, and the scroll-edge inventory row for the new presentation root.
2. Add parallel-safe Swift Testing coverage for `NewSavedSearchFeature` and both hosts.
3. Gate: clean build of the app scheme (0 errors, warnings and lint violations) and the
   QuickSearch, Search and Detail test targets. One commit per finished task (≤ 50 characters).
4. Mark the note promoted, write SUMMARY.md and record the task in STATE.md.
