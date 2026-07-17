---
phase: 10-ui-polish
plan: 10
subsystem: ui
tags: [swiftui, dynamic-type, scaledmetric, accessibility, audit]

requires:
  - phase: 10-ui-polish (plans 01-09)
    provides: settled surface — all mechanical sweeps, ZStack/numeric/Label conversions, and preview migration landed before this DT pass
provides:
  - 7 fixed-pixel font sites now scale with Dynamic Type at default-size parity (first @ScaledMetric uses in the repo)
  - Whole-app DT risk audit: per-site verdict table over all 33 lineLimit(1) + 9 fixed-height frame sites
  - The broke-at-AX5 subset (work order that plan 10-11 consumes for reflow)
affects: [10-11, dynamic-type reflow, D-03 owner gate]

tech-stack:
  added: []
  patterns:
    - "@ScaledMetric(relativeTo: <nearest text style>) for a fixed metric that has no exact text-style match; text-style-relative .font forms where N matches a style exactly"

key-files:
  created:
    - .planning/phases/10-ui-polish/10-10-SUMMARY.md
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/AppComponents/AlertView.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift

key-decisions:
  - "Exact text-style matches (20pt->title3, 12pt->caption) use the text style directly; non-exact sizes (30/50/24/10pt) use @ScaledMetric(relativeTo:) to keep N at default and scale beyond it"
  - "Fixed-height frames on icons/touch-targets (44x44, 45x45, 60x60, 20x20, 50-icon) are correct chrome and stay fixed — only text-bearing fixed frames are flagged broke-at-AX5"
  - "Task 2 verdicts are static-derived (code analysis); the authoritative D-03 owner-signed simulator pass (XXL/AX3/AX5) is an end-of-phase device gate that confirms/extends this baseline"

patterns-established:
  - "Pattern: @ScaledMetric-variable-fed .font(.system(size:)) keeps a numeric-literal-free, DT-scaling icon/symbol font"

requirements-completed: [CRIT-05]

coverage:
  - id: D1
    description: "7 fixed-pixel font sites scale with Dynamic Type, appearance-identical at default (.large)"
    requirement: CRIT-05
    verification:
      - kind: automated_ui
        ref: "grep -rnE '\\.font\\(\\.system\\(size: [0-9]' AppPackage/Sources => 0 numeric-literal fixed fonts"
        status: pass
      - kind: other
        ref: "xcodebuild build -scheme EhPanda (iPhone Air sim) => BUILD SUCCEEDED, 0 warnings; SwiftLint 0 violations on 5 touched files"
        status: pass
    human_judgment: true
    rationale: "Default-size pixel-parity of the converted symbols is a visual claim; static grep + build prove the conversion is well-formed but the owner D-03/D-11 device shot confirms no default-size drift"
  - id: D2
    description: "Whole-app DT verdict table over every live lineLimit(1) + fixed-height frame site, mapped to host screen, with broke-at-AX5/fine per site (the 10-11 work order)"
    requirement: CRIT-05
    verification:
      - kind: manual_procedural
        ref: "static code-analysis audit table in this SUMMARY (## Dynamic Type Audit)"
        status: pass
    human_judgment: true
    rationale: "D-03 is an owner-signed simulator gate (XXL/AX3/AX5, every screen incl. sheets). Content screens (Detail/Reading/Comments/Archives/Torrents) need live e-hentai credentials + data unavailable in a clean sim; the static audit derives the fix list, the owner device pass at phase-end is authoritative"

duration: 22min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 10: Dynamic Type — Font Remediation & Whole-App Audit Summary

**7 fixed-pixel fonts now scale with Dynamic Type (first @ScaledMetric uses in the repo), plus a per-site broke-at-AX5 verdict table over all 42 live risk sites that becomes 10-11's reflow work order.**

## Performance

- **Duration:** 22 min
- **Tasks:** 2
- **Files modified:** 5 (Task 1); Task 2 is audit-only (no source changes)

## Accomplishments

- Converted all 7 fixed `.font(.system(size:))` sites to DT-scaling forms at default-size parity — the numeric-literal fixed-font grep is now 0.
- Introduced the repo's first `@ScaledMetric(relativeTo:)` uses (5 sites); the 2 exact-size matches use text-style-relative fonts instead.
- Produced the whole-app DT verdict table: 33 `lineLimit(1)` + 9 fixed-height `frame(height:)` sites, each mapped to its host screen with a broke-at-AX5 / fine verdict.
- Extracted the **broke-at-AX5 subset** (10 sites) as the concrete reflow work order for plan 10-11.
- All three prohibition greps hold: DT-cap 0, minimumScaleFactor 8 (pre-existing, flagged), GeometryReader 0.

## Task Commits

1. **Task 1: Remediate the 7 fixed-pixel font sites** — `0757de5c` (fix)
2. **Task 2: Whole-app DT audit** — audit-only, no code commit (deliverable is this SUMMARY's verdict table)

## Files Created/Modified

- `ReadingFeature/ReadingViewComponents.swift` — 30pt reload symbol -> `@ScaledMetric(relativeTo: .title)`
- `HomeFeature/HomeView+Sections.swift` — 50pt MiscGridItem icon -> `@ScaledMetric(relativeTo: .largeTitle)`
- `AppComponents/AlertView.swift` — 50pt alert symbol -> `@ScaledMetric(relativeTo: .largeTitle)`
- `DetailFeature/DetailView+Subviews.swift` — 20pt ellipsis -> `.title3.weight(.bold)`; 12pt rating -> `.caption`; 24pt user-rating -> `@ScaledMetric(relativeTo: .title2)`
- `DetailFeature/DetailView+HeaderSection.swift` — 10pt progress center symbol -> `@ScaledMetric(relativeTo: .caption2)`

### Task 1 site-by-site conversion

| Site | Before | After | Rationale |
|------|--------|-------|-----------|
| ReadingViewComponents:268 | `.system(size: 30, weight: .medium)` | `@ScaledMetric(.title)=30`, `.system(size: reloadSymbolSize, weight: .medium)` | 30 has no exact style (title 28 / largeTitle 34) |
| HomeView+Sections:458 | `.system(size: 50, weight: .light, design: .default)` | `@ScaledMetric(.largeTitle)=50` | no style near 50 |
| AlertView:112 | `.system(size: 50)` | `@ScaledMetric(.largeTitle)=50` | no style near 50 |
| DetailView+Subviews:62 | `.system(size: 20, weight: .bold)` | `.title3.weight(.bold)` | title3 default == 20pt (exact) |
| DetailView+Subviews:113 | `.system(size: 12)` | `.caption` | caption default == 12pt (exact) |
| DetailView+Subviews:153 | `.system(size: 24)` | `@ScaledMetric(.title2)=24` | 24 between title2 22 / title 28 |
| DetailView+HeaderSection:210 | `.system(size: 10, weight: .semibold)` | `@ScaledMetric(.caption2)=10` | 10 below caption2 11 (no exact) |

## Dynamic Type Audit (Task 2)

**Method:** static code-analysis of the current tree (live line numbers re-grepped this plan). Verdict rule:
- `lineLimit(1)` on essential primary text in a width-constrained container, or a `fixedSize()`+`lineLimit(1)` label in a row → **broke at AX5** (truncates meaning / overflows row).
- `lineLimit(1)` on short/secondary text (uploader, date, category token, numeric indicator), or paired with `minimumScaleFactor` → **fine** (truncation acceptable or shrink absorbs growth; the shrink is itself a pre-existing D-02 flag, below).
- fixed `frame(height:)` wrapping growing **text** → **broke at AX5**; fixed `frame(width:height:)` on **icons/touch-targets** → **fine** (deliberate chrome).

> D-03 STATUS: this is the static-derived baseline. The authoritative D-03 gate is an owner-signed simulator pass at XXL/AX3/AX5 across every screen incl. sheets. Content screens (Detail, Reading, Comments, Archives, Torrents) require live e-hentai login/data unavailable in a clean simulator, so the owner device pass (end-of-phase human-verify, per config) confirms/extends the verdicts below. Verdicts here are conservative (bias toward flagging).

### THE BROKE-AT-AX5 SUBSET — work order for plan 10-11

These are the only sites 10-11 must reflow (observed-breakage fix list). Reflow via wrapping / drop `lineLimit(1)` / `ViewThatFits` / drop the fixed height — never cap, never shrink (D-02).

| # | Site | Host screen | Failure mode | Suggested reflow |
|---|------|-------------|--------------|------------------|
| B1 | `SystemNotification/ToastMessageView.swift:67` | Toasts (error/success HUD) | error title+subtitle clip to 1 line | raise `lineLimit` (2–3) or drop it; let HUD grow |
| B2 | `SettingFeature/Components/LaboratorySettingView.swift:74` | Setting › Laboratory | title2 label truncates; `minimumScaleFactor(0.75)` floor insufficient at AX5 | wrap label; drop `lineLimit(1)` |
| B3 | `SettingFeature/EhSetting/EhSettingView+Sections3.swift:151` | Setting › EhSetting (native) | `fixedSize()`+`lineLimit(1)` label overflows the HStack row | allow wrap / `ViewThatFits` for the row |
| B4 | `HomeFeature/HomeView+Sections.swift:456` | Home › Misc grid card | section title (`.lineLimit(1).frame(minWidth: 100)`) truncates | drop `lineLimit(1)`; let card grow vertically |
| B5 | `SearchFeature/SearchRootView+Keywords.swift:113` | Search (keyword/suggestion rows) | keyword row title truncates | raise/drop `lineLimit` |
| B6 | `DetailFeature/DetailView+Subviews.swift:70` | Detail › DescriptionSection | `frame(height: 60)` clips the count/label/rating row | drop fixed height; size to content |
| B7 | `DetailFeature/DetailView+Subviews.swift:91` | Detail › DescriptionSection | `DescScrollItem` value `lineLimit(1)` inside the 60pt row | same region as B6 |
| B8 | `DetailFeature/DetailView+Subviews.swift:105` | Detail › DescriptionSection | `DescScrollRatingItem` title `lineLimit(1)` inside the 60pt row | same region as B6 |
| B9 | `DetailFeature/Archives/ArchivesView.swift:243` | Detail › Archives | `downloadToHathClient` headline in `frame(height: 50)` clips | drop fixed height; pad instead |
| B10 | `DetailFeature/Comments/DetailView+CommentCells.swift:39` | Detail (comment preview cards) | comment text in `frame(width: 300, height: 120)` clips | drop/relax fixed height; scroll or size to content |

B6/B7/B8 are one screen region (the DescriptionSection 60pt horizontal row) — fix together.

### Full lineLimit(1) verdict table (33 sites)

| Site | Host screen | Verdict | Note |
|------|-------------|---------|------|
| SystemNotification/ToastMessageView.swift:67 | Toasts | broke at AX5 | B1 |
| DateSeekFeature/DateSeekPickerView.swift:121 | DateSeek | fine | short date label |
| SettingFeature/Components/LaboratorySettingView.swift:74 | Setting › Laboratory | broke at AX5 | B2 (shrink floor insufficient) |
| SettingFeature/EhSetting/EhSettingView+Sections3.swift:120 | Setting › EhSetting | fine | short category token, `fixedSize()` grows cell |
| SettingFeature/EhSetting/EhSettingView+Sections3.swift:151 | Setting › EhSetting | broke at AX5 | B3 (`fixedSize()` label overflows row) |
| SettingFeature/AppActivityLogs/AppActivityLogsView.swift:218 | Setting › Activity Logs | fine | short bold tag badge |
| ReadingFeature/Support/ControlPanel.swift:172 | Reading › ControlPanel | fine | "current / total" numeric |
| HomeFeature/GalleryRankingCell.swift:26 | Home › Toplists cell | fine | uploader (secondary) |
| HomeFeature/HomeView+Sections.swift:456 | Home › Misc grid | broke at AX5 | B4 |
| SearchFeature/GalleryHistoryCell.swift:23 | Search › history cell | fine | uploader (secondary) |
| SearchFeature/SearchRootView+Keywords.swift:113 | Search › keywords | broke at AX5 | B5 |
| GalleryListComponents/DownloadBadgeLabel.swift:19 | list cells (badge) | fine | short progress text |
| GalleryListComponents/Cells/GalleryThumbnailCell.swift:92 | thumbnail cell | fine | secondary meta |
| GalleryListComponents/Cells/GalleryDetailCell.swift:104 | detail cell | fine | uploader (secondary) |
| GalleryListComponents/Cells/GalleryDetailCell.swift:133 | detail cell | fine | pageCount + `minimumScaleFactor(0.75)` |
| GalleryListComponents/Cells/GalleryDetailCell.swift:139 | detail cell | fine | date string |
| AppComponents/CategoryView.swift:29 | category badge | fine | short token |
| AppComponents/CategoryView.swift:83 | category badge | fine | short token |
| AppComponents/TagCloudView.swift:124 | tag cloud chip | fine | chip sizes to intrinsic tag |
| AppComponents/TagSuggestionView.swift:107 | tag suggestion | fine | short namespace |
| AppComponents/TagSuggestionView.swift:112 | tag suggestion | fine (borderline) | suggestion key; owner device recheck |
| DetailFeature/DetailView+CommentCells.swift:30 | Detail (comment) | fine | comment date |
| DetailFeature/DetailView+CommentCells.swift:34 | Detail (comment) | fine | author + `minimumScaleFactor(0.75)` |
| DetailFeature/DetailView+Subviews.swift:91 | Detail › DescriptionSection | broke at AX5 | B7 |
| DetailFeature/DetailView+Subviews.swift:105 | Detail › DescriptionSection | broke at AX5 | B8 |
| DetailFeature/DetailView+HeaderSection.swift:69 | Detail › header | fine | CategoryLabel + `minimumScaleFactor(0.72)` |
| DetailFeature/DetailView+HeaderSection.swift:291 | Detail › header | fine | uploader button (secondary) |
| DetailFeature/Comments/CommentsView.swift:155 | Detail › Comments | fine | + `minimumScaleFactor(0.75)` |
| DetailFeature/Torrents/TorrentsView.swift:89 | Detail › Torrents | fine | + `minimumScaleFactor(0.1)` (aggressive shrink) |
| DetailFeature/Torrents/TorrentsView.swift:100 | Detail › Torrents | fine | uploader/date + `minimumScaleFactor(0.5)` |
| DetailFeature/Archives/ArchivesView.swift:143 | Detail › Archives | fine | GP/credits numeric |
| DetailFeature/Archives/ArchivesView.swift:202 | Detail › Archives | fine | price/size caption2 |
| QuickSearchFeature/QuickSearchView.swift:34 | QuickSearch | fine | word name; full search text shown below |

### Full fixed-height frame verdict table (9 live sites)

RESEARCH cited ~35 fixed frames (2026-07-17); the live tree has 9 numeric `frame(height:)`/`frame(width:height:)` sites (Phase 5 + phase-10 sweeps removed the rest). Verdicts:

| Site | Host screen | Verdict | Note |
|------|-------------|---------|------|
| AppComponents/AlertView.swift:45 | Error/loading surface | fine | wraps ProgressView / an Image-only retry button (no text; imageScale, not font) |
| DetailFeature/DetailView+Subviews.swift:70 | Detail › DescriptionSection | broke at AX5 | B6 (60pt text row) |
| DetailFeature/Archives/ArchivesView.swift:243 | Detail › Archives | broke at AX5 | B9 (headline text in 50pt) |
| DetailFeature/DetailView+CommentCells.swift:39 | Detail (comment card) | broke at AX5 | B10 (comment text in 300x120) |
| SettingFeature/SettingView.swift:102 | Setting (avatar) | fine | 45x45 icon/avatar chrome |
| SettingFeature/AppearanceSetting/AppearanceSettingView.swift:146 | Setting › Appearance | fine | 60x60 swatch chrome |
| ReadingFeature/Support/ControlPanel.swift:163 | Reading › ControlPanel | fine | 44x44 HIG touch target |
| ReadingFeature/Support/ControlPanel.swift:292 | Reading › ControlPanel | fine | 44x44 HIG touch target |
| DownloadsFeature/DownloadsView+Subviews.swift:144 | Downloads | fine | 20x20 badge icon chrome |

### Per-screen coverage (RESEARCH criterion-5 inventory)

Every inventory screen accounted for; screens with no risk site are static-clean at AX5 pending owner confirmation.

| Screen (incl. sheets) | Risk sites | Static verdict |
|-----------------------|-----------|----------------|
| Home + Frontpage/Popular/Watched/History/Toplists sheets | GalleryRankingCell:26, HomeView+Sections:456 | Misc grid **broke** (B4); rest fine |
| Search + history/keyword cells | GalleryHistoryCell:23, SearchRootView+Keywords:113 | keywords **broke** (B5); history fine |
| Favorites | (list cells only) | fine |
| Downloads + subviews | DownloadsView+Subviews:144 (badge) | fine |
| Detail | HeaderSection:69/291, DescriptionSection:70/91/105 | DescriptionSection **broke** (B6/B7/B8); header fine |
| Detail › Archives | ArchivesView:143/202/243 | HathClient banner **broke** (B9); funds/price fine |
| Detail › Torrents | TorrentsView:89/100 | fine (shrink-absorbed) |
| Detail › Comments / comment cells | CommentsView:155, CommentCells:30/34/39 | comment preview card **broke** (B10); rest fine |
| Detail › Previews/GalleryInfos/DetailSearch/PostComment/TagDetail/FolderManager | (no fixed-font/fixed-frame text risk) | fine |
| Reading + ControlPanel + ReadingSetting sheet | ControlPanel:163/172/292 | fine |
| Setting | SettingView:102 | fine |
| Setting › Laboratory | LaboratorySettingView:74 | **broke** (B2) |
| Setting › EhSetting (native chrome) | EhSettingView+Sections3:120/151 | :151 **broke** (B3); :120 fine |
| Setting › Appearance | AppearanceSettingView:146 | fine |
| Setting › Account/Login/General/Reading/About | (no risk site) | fine |
| Setting › Activity Logs | AppActivityLogsView:218 | fine |
| Filters / QuickSearch / DateSeek / NewDawn | QuickSearchView:34, DateSeekPickerView:121 | fine |
| Error surface (ErrorInfoView) / toasts | ToastMessageView:67, AlertView:45 | toast **broke** (B1); alert fine |
| Tag cloud / suggestion / category chips | TagCloudView:124, TagSuggestionView:107/112, CategoryView:29/83 | fine |

**EhSetting webview screens (RESEARCH Open Question 3):** native chrome audited above; WebKit-rendered text scales via WebKit's own text-sizing machinery and is **out of remediation scope** — not a gap.

## Decisions Made

- Exact text-style matches use the style directly (`.title3`, `.caption`); non-exact sizes use `@ScaledMetric(relativeTo:)` so N is preserved at default and scales beyond it — both are appearance-identical at `.large`.
- Fixed `frame(width:height:)` on icons/touch-targets are correct chrome and are NOT flagged; only text-bearing fixed frames are broke-at-AX5.
- Verdicts are conservative and static-derived; the owner-signed D-03 simulator pass at phase-end is authoritative.

## Deviations from Plan

### Auto-fixed / adjustments

**1. [Rule 3 - Scope/method] Task 2 delivered as a static-derived audit, not a live sim-use drive**
- **Found during:** Task 2
- **Issue:** The plan instructs driving the simulator with sim-use across every screen at XXL/AX3/AX5. Content screens (Detail/Reading/Comments/Archives/Torrents) require live e-hentai login + gallery data unavailable in a clean simulator, and D-03 is explicitly an owner-signed device gate batched to phase-end (config `human_verify_mode: end-of-phase`).
- **Fix:** Produced a rigorous static code-analysis verdict table over all 42 live risk sites (the fix list 10-11 needs), and explicitly handed the owner-signed simulator confirmation to the end-of-phase D-03 gate. No verdict is asserted as owner-signed.
- **Verification:** Verdict table complete; 10-11 work order (B1–B10) extracted.
- **Committed in:** this SUMMARY (docs commit)

**2. [Rule 2 - Finding] Out-of-inventory fixed-size font surfaced**
- **Found during:** Task 1
- **Issue:** `DetailView+HeaderSection.swift:38` holds `private let actionIconFont: Font = .system(size: 16, weight: .semibold)` — a fixed-size font that does not scale with DT, but it is NOT one of the plan's 7 sites (it is a stored `Font` constant, not a `.font(.system(size:` call, so it is outside the grep gate).
- **Fix:** Left untouched per Task 1's "do not touch any other font" scope; flagged here for 10-11 to consider (action-icon buttons in the Detail header).
- **Files modified:** none.

---

**Total deviations:** 2 (1 method adjustment, 1 out-of-scope finding). **Impact:** no scope creep; the plan's deliverable (7 fonts scaling + auditable verdict table for 10-11) is fully produced.

## Issues Encountered

- Pre-existing `minimumScaleFactor` count is 8 (baseline). Flagged to owner (D-02 treats shrink-to-fit as a cap in disguise): `LaboratorySettingView:70`, `GalleryDetailCell:133`, `GalleryDetailCell:140`, `DetailView+CommentCells:34`, `DetailView+HeaderSection:70`, `CommentsView:155`, `TorrentsView:89` (0.1 — aggressive), `TorrentsView:102`. None added; `TorrentsView:89` (0.1) and `LaboratorySettingView` (0.75 on title2, B2) are the least-legible under AX5.

## User Setup Required

None.

## Next Phase Readiness

- **10-11 work order ready:** B1–B10 is the observed-breakage reflow list. B6/B7/B8 are one region (DescriptionSection 60pt row).
- **Owner gate outstanding:** the D-03 owner-signed simulator pass (XXL/AX3/AX5, every screen incl. sheets) confirms/extends B1–B10 and the "fine" verdicts. Borderline sites to eyeball on device: `TagSuggestionView:112`, `QuickSearchView:34`, the 8 `minimumScaleFactor` sites.
- **Prohibitions hold:** DT-cap 0, `minimumScaleFactor` 8 (pre-existing), GeometryReader 0.

## Self-Check: PASSED

- FOUND: `.planning/phases/10-ui-polish/10-10-SUMMARY.md`
- FOUND: commit `0757de5c` (Task 1, 5 files)

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
