---
phase: 10-ui-polish
plan: 05
subsystem: ui-components
tags: [swiftui, label, sfsafesymbols, accessibility, lint, audit]
requires:
  - AppComponents.ToolbarItems (FiltersButton/QuickSearchButton/JumpPageButton)
provides:
  - Label(_:systemSymbol:)-based toolbar/menu buttons at appearance parity
affects:
  - AppComponents
  - ReadingFeature
  - DetailFeature
tech-stack:
  added: []
  patterns:
    - "Conditional icon-only Label via if/else two-branch (no AnyLabelStyle)"
    - "Menu/context-menu icon+title rows expressed as Label (house style)"
key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/ToolbarItems.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
decisions:
  - "The three ToolbarItems buttons keep a two-branch Label (icon-only when hideText) because no AnyLabelStyle exists; icon-only is applied explicitly rather than relying on toolbar auto-behavior."
  - "Menu/context-menu Image+Text rows (ControlPanel ToolbarFeaturesMenu, DetailView tag context menu) convert to Label — parity-safe house style already proven by DateSeekButton in the same menu."
  - "Toolbar image-only and menu-row trailing-checkmark buttons are left as-is; converting would need new localized title keys or move the icon to the wrong slot (parity veto)."
metrics:
  duration: 16min
  tasks: 2
  files: 3
  completed: 2026-07-17
status: complete
---

# Phase 10 Plan 05: Button Label Conversion + Empty-String Audit Summary

Converted the codebase's text+image buttons to `Label(_:systemSymbol:)` where fitting (three `ToolbarItems` buttons plus six menu/context-menu rows), recorded convert/leave verdicts for every button candidate, and executed the empty-string-literal audit (criterion 9) which returned zero matches as expected.

## What Was Built

**Criterion 10 — Label conversion (converted, 9 sites):**
- `ToolbarItems.swift` — `FiltersButton`, `QuickSearchButton`, `JumpPageButton`: `Image + conditional Text` → `Label(_:systemSymbol:)` with a two-branch `if hideText { … .labelStyle(.iconOnly) } else { … }`. Titles reuse existing `.RLocalizable` strings; no new `.xcstrings` keys.
- `ControlPanel.swift` — three `ToolbarFeaturesMenu` rows (`retryAllFailedImages`, `reloadAllImages`, `readingSetting`) → `Label`.
- `DetailView+Subviews.swift` — four tag `.contextMenu` rows (`detail`, `withdrawVote`, `voteUp`, `voteDown`) → `Label`. `withdrawVote` keeps `.symbolVariant(.fill)` on the `Label` (applies to the icon only).

**Criterion 9 — empty-string audit:** documented result (below), no edits needed.

## Audit Verdict Table (criterion 10 "all buttons")

### Text+image buttons — CONVERTED
| Site | Verdict |
|------|---------|
| ToolbarItems.swift FiltersButton | Converted — Label + icon-only branch |
| ToolbarItems.swift QuickSearchButton | Converted — Label + icon-only branch |
| ToolbarItems.swift JumpPageButton | Converted — Label + icon-only branch |
| ControlPanel.swift retryAllFailedImages | Converted — menu row Label |
| ControlPanel.swift reloadAllImages | Converted — menu row Label |
| ControlPanel.swift readingSetting | Converted — menu row Label |
| DetailView+Subviews.swift tag `detail` | Converted — context-menu Label |
| DetailView+Subviews.swift `withdrawVote` | Converted — Label + `.symbolVariant(.fill)` |
| DetailView+Subviews.swift `voteUp` | Converted — context-menu Label |
| DetailView+Subviews.swift `voteDown` | Converted — context-menu Label |

### Text+image buttons — LEFT (parity veto)
| Site | Reason |
|------|--------|
| SearchRootView+Keywords.swift:106 | Title carries `.frame(maxWidth:.infinity, alignment:.leading)` + `.lineLimit(1)`; a Label's composited title cannot reproduce the fill-width leading layout |
| DetailView+CommentCells.swift:52 | Custom `HStack` with independent `.padding/.frame/.background/.clipShape`; Label's internal spacing differs |
| DetailView+Subviews.swift:125 (giveARating) | `Spacer`-wrapped centering inside the button label; Label cannot contain Spacers |
| DetailView+Subviews.swift:132 (similarGallery) | Same `Spacer`-wrapped centering |

### Menu-row Text + trailing-checkmark buttons — LEFT AS-IS
Reason: a `Label(title, systemSymbol: .checkmark)` puts the icon in the leading slot, while `Menu` renders the selection checkmark natively in the trailing slot. "Where fitting" = no.
- ToolbarItems.swift FavoritesIndexMenu, ToplistsTypeMenu, SortOrderMenu
- ControlPanel.swift dualPageMode, exceptCover, autoPlay-policy rows
- DownloadsView.swift folderFilterButton

### Toolbar text-only / image-only buttons — verdicts
Image-only toolbar buttons (in scope per criterion 10's toolbar clause) — all LEFT:
- EhSettingView.swift:102 (globe), :111 (icloud upload); LoginView.swift:93 (globe); ReadingView.swift:95 (chevron-down dismiss); HomeView.swift:104 (reload); HistoryView.swift:49 (trash); CommentsView.swift:116 (squareAndPencil); FolderManagerView.swift:121 (plus); QuickSearchView.swift:96 (plus), :102 (pencilCircle).
- Reason: these are pure-icon actions with no existing localized title. Converting to a titled `Label` would require inventing new user-facing `.xcstrings` keys (all-locale burden) and risks a title appearing in the toolbar. A dedicated accessibility-naming pass is the right home; a mechanism swap at parity is not.

Text-only toolbar buttons (e.g. `Button(.done)` keyboard action, role-based `.close`/`.cancel` buttons): LEFT — no symbol to pair, `Label` not applicable.

Non-toolbar image-only buttons (ControlPanel dismiss/menu labels, ReadingViewComponents reload, AlertView, inline Detail/Comments/Torrents/FolderManager/QuickSearch buttons, LoginView:47): explicitly out of scope per criterion 10.

## Criterion 9 — Empty-String Literal Audit

Patterns run over `AppPackage/Sources`, `App`, `ShareExtension`:
| Pattern | Matches |
|---------|---------|
| `Text("")` / `Label(""` / `Button("")` / `TextField("")` | 0 |
| `[A-Z][A-Za-z]*\("",` / `[A-Z][A-Za-z]*\(""\)` (any capitalized initializer with an empty string literal) | 0 |

Result: **zero matches**, as research predicted. The `accessibility_empty_string` lint rule (error severity) already guards the a11y-modifier variant. Note: `CommentsView.swift:116` `store.send(.presentPostComment(commentID: ""))` is a domain action argument (lowercase initializer, an empty comment id meaning "new top-level comment"), not a view label — correctly excluded by the capitalized-initializer audit regex and not a violation.

## Verification

- **Build:** `xcodebuild build -scheme EhPanda -destination id=<iPhone 17e sim>` → **BUILD SUCCEEDED**, 0 warnings, 0 errors. (Plan's `AppPackage-Package` scheme does not exist in this project — used the `EhPanda` app scheme, which links `AppFeature` and compiles the whole package.)
- **SwiftLint:** artifactbundle binary `lint --strict` on the three changed files → **0 violations, 0 serious**. Custom rules `system_name_image_parameter`, `label_text_image_shorthand`, `accessibility_empty_string` (all error severity) pass; the build (with the SwiftLint build-tool plugin active) would have failed otherwise.
- **`grep -rnF "systemImage:"`** across sources → 0 hits. The four surviving `Label { … } icon: { … }` closure forms (FolderManagerView, ArchivesView) are pre-existing and NOT the lint-banned shorthand (their titles are a `TextField` view or a formatted `Text(_, format:)`), so they are untouched and legal.
- **D-11 toolbar spot-check (sim-use, iPhone 17e):**
  - Home reload button and Frontpage `FiltersButton` render **icon-only** — no title text appears beside the toolbar icons (parity preserved for the `hideText: true` path). Screenshots: `home.png`, `frontpage.png`.
  - Search "More" menu shows `Filters` and `Quick search` as **icon + title** rows (parity for the `hideText: false` menu path). Screenshot: `searchmenu.png`.

## Deviations from Plan

**1. [Rule 3 - Blocking] Build scheme name in plan does not exist**
- **Found during:** Task 1 verification
- **Issue:** The plan's verify command targets scheme `AppPackage-Package`, which is not present in `EhPanda.xcodeproj` (per-module schemes + an `EhPanda` app scheme exist instead).
- **Fix:** Built the `EhPanda` app scheme (links `AppFeature`, compiles the whole `AppPackage`) on an available `iPhone 17e` simulator (the plan's `iPhone 17 Pro` sim is also absent). No source change.
- **Commit:** n/a (tooling only)

**2. [Scope — criterion 10 "all buttons where fitting"] Converted six menu/context-menu rows beyond the three named ToolbarItems buttons**
- **Rationale:** These `Image + Text` rows in a `Menu`/`.contextMenu` render identically as `Label` (leading icon + title), which is the documented house style already used by `DateSeekButton` in the very same `ToolbarFeaturesMenu`. Leaving them would be an inconsistency; converting completes criterion 10 at parity.
- **Files:** ControlPanel.swift, DetailView+Subviews.swift
- **Commit:** a6027d59

## Commits

- `a6027d59` refactor(10-05): convert text+image buttons to Label

## Self-Check: PASSED
- Modified files exist: ToolbarItems.swift, ControlPanel.swift, DetailView+Subviews.swift (all committed in a6027d59)
- Commit a6027d59 present in git log
- Build succeeded; SwiftLint clean; empty-string audit zero
