---
status: diagnosed
trigger: "G-05-1 — Phase 5 rotation/adaptive-layout regressions across About, reader loading pages, Home slideshow, Filters sheets, and Favorites date-seek."
created: 2026-07-13
updated: 2026-07-13
---

# Phase 05 Layout Regressions

## Current Focus

- phase: diagnosis complete
- hypothesis: The six reports are independent SwiftUI composition defects: compact navigation removes large-subtitle-only content; reader placeholders derive only from horizontal extent; Home sizes the carousel slot and cell independently; page-range fields render a semantic label/prompt inside a fixed 50-point field; reusable sheet roots omit cancellation actions; and Favorites overpacks four controls into one custom toolbar item while the date-seek button can also be explicitly disabled by absent metadata.
- test: Compare each current view hierarchy to its parent proposal/presentation contract and to the introducing commits; seek contradictory state wiring and other plausible causes.
- expecting: Each report maps to a concrete modifier or presentation boundary, while reducer paths remain internally coherent.
- next_action: return diagnose-only root cause to the orchestrator

## Symptoms

- expected: Universal rotation and adaptive layouts preserve visible content, correctly sized reader loading pages and Home slideshow cards, unclipped filter controls, dismissible sheets, and a responsive Favorites date-seek toolbar item.
- actual: About copyright/version is hidden in landscape; reader loading-page height is too small in landscape; Home slideshow card sizing is broken; Filters page-range prompt is clipped; Filters and potentially other sheets lack an untitled cancel-role dismiss button; Favorites date-seek toolbar item is unresponsive.
- errors: None reported.
- started: Discovered during Phase 5 UAT.
- reproduction: Phase 5 UAT Test 1.

## Fault Tree

- adaptive geometry regressions
  - hard-coded portrait dimensions or obsolete screen-bounds assumptions
  - container-relative sizing applied at the wrong hierarchy level
  - content omitted rather than made scrollable under constrained height
- presentation regressions
  - sheets rely only on drag dismissal and omit a cancel-role toolbar action
  - toolbar item has a gesture/action overlay or disabled/hit-testing state
- state regressions
  - button action is sent but presentation state is not reachable
  - state is correct but view hierarchy prevents interaction

## Evidence

- User/UAT report identifies six deterministic regressions and no runtime errors.
- About places copyright and version exclusively in `ToolbarItem(placement: .largeSubtitle)` (`AboutView.swift:45-55`). Compact/landscape navigation bars do not expose the large-title subtitle slot, and the strings have no second rendering path. Git blame traces this design to `f61208866`, not to the Phase 5 container work.
- Commit `69c035d4` replaced the reader loading/failed page's explicit width and height with `.containerRelativeFrame(.horizontal)` followed by a fixed `0.7` aspect ratio (`ReadingViewComponents.swift:224-236,258-277`). The placeholder never receives the outer reader height, although Phase 5 otherwise captures both dimensions. Thus the page is resolved from a one-axis proposal and can no longer choose an aspect-fit size against the landscape viewport.
- The Home carousel computes `cardWidth = carouselWidth * 0.8`, applies it to the Button slot, and uses the same value for snapping (`HomeView+Sections.swift:125-184`). Commit `da6cd6d2` then independently added another `.containerRelativeFrame(.horizontal) { width * 0.8 }` inside `GalleryCardCell` (`GalleryCardCell.swift:85`). This contradicts 05-06-PLAN's explicit instruction that the cell fill the already-sized slot; the nested modifier resolves against the ScrollView container/content-margin contract rather than simply filling the Button, so visual width can diverge from the pitch and margins.
- Commit `2e45c6da` changed page-range `SettingTextField`s from empty titles to `.pagesRange`. Each field is fixed to 50 points (`SettingTextField.swift:38-44`) while the row already renders `Text(.pagesRange)` (`FiltersView.swift:183-194`). The semantic title/prompt is therefore redundant visually and, where rendered by the TextField style, cannot fit the 50-point field. There is no flexible-width fallback in the HStack.
- `FiltersView`, `QuickSearchView`, and `DateSeekPickerView` each create their own `NavigationStack` but expose no dismissal environment/action and no cancellation-role toolbar item. They are reused as `.sheet` content from Frontpage, Popular, Watched, Search, DetailSearch, SearchRoot, and Favorites, so drag dismissal is their only generic escape. By contrast, DownloadInspector and FolderManager explicitly install cancellation actions, confirming the missing contract rather than a global sheet problem.
- Favorites puts four independent controls inside one `CustomToolbarItem`; that helper wraps all content in one `ToolbarItem`/`HStack` (`FavoritesView.swift:101-119`, `ToolbarItems.swift:24-30`). This is the only direct four-control use: other multi-action list screens move date seek into `ToolbarFeaturesMenu`. The date button also executes only `navigation.map(action)` and is disabled when `rawDateSeekNavigation[index]` is nil (`ToolbarItems.swift:114-130`), leaving an apparently present calendar control with no response. The reducer path itself is coherent: a non-nil value sends `.dateSeekButtonTapped`, which assigns `.dateSeek` destination, and the view scopes that destination into a sheet.
- Phase 5 verification was static for these surfaces: `05-VERIFICATION.md` verified the carousel's shared outer `carouselWidth` wiring but did not detect the second inner width calculation; runtime rotation remained a manual gate. This explains why build/lint checks passed while UAT found the defects.

## Eliminated

- Reader state/rotation mapping as the cause of the loading-page size: page mapping tests and the reported gesture/state UAT pass; the defect is isolated to placeholder sizing modifiers introduced by `69c035d4`.
- Favorites reducer destination wiring as the primary cause: `.dateSeekButtonTapped` deterministically assigns destination state and the `.sheet` observes that exact destination case. The interaction boundary is the disabled/overpacked toolbar control before the reducer action.
- A general sheet-presentation failure: sheets present successfully; only content roots that omit a cancellation action lack an explicit dismiss control, while neighboring sheet roots with `.cancellationAction` are dismissible.

## Resolution

- root_cause: Six independent view-contract violations were grouped by UAT: (1) About stores persistent metadata in a large-title-only toolbar placement that disappears in compact landscape bars; (2) reader loading/failed pages were migrated in `69c035d4` to width-only container sizing plus a portrait aspect ratio, ignoring available landscape height; (3) Home's carousel slot is already 80% width but `da6cd6d2` adds a second inner 80% container-relative sizing layer, allowing the rendered card to diverge from the scroll pitch; (4) `2e45c6da` gives both fixed 50-point range fields a redundant localized pages-range label/prompt that clips; (5) reusable NavigationStack sheet roots (at least Filters, Quick Search, and Date Seek) omit a cancellation-role dismiss action; and (6) Favorites packs four controls into one custom ToolbarItem and its date button is explicitly inert whenever optional date-seek metadata is nil, so the calendar can be visible but untappable before any reducer action is sent.
- fix: not applied (diagnose-only mode)
- verification: source-level differential diagnosis with introducing-commit evidence; no Swift source modified
- files_changed: []
