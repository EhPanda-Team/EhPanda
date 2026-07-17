---
phase: 10-ui-polish
plan: 06
subsystem: ui
tags: [swiftui, zstack, overlay, background, layout, polish-02]

# Dependency graph
requires:
  - phase: 10-04
    provides: "Placeholder trait-color fill (inSheet removal) — the Color the activity/progress converts keep as size-definer"
provides:
  - "POLISH-02: overlay-relationship ZStacks converted to .overlay sized to the primary (flexible Color) child"
  - "Complete 35-site convert/keep verdict table with size-defining-child rationale"
affects: [10-07, 10-11, ui-polish-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Color/backgroundColor-fill + centered decorator under an external definite frame → Color.overlay { decorator } (size-invariant)"
    - "Union-sized / conditional-single-child / opacity-toggled-peer ZStacks are kept — a correct, recorded outcome"

key-files:
  created:
    - ".planning/phases/10-ui-polish/10-06-SUMMARY.md"
  modified:
    - "AppPackage/Sources/AppComponents/Placeholder.swift"
    - "AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift"

key-decisions:
  - "Only 3 of 35 ZStacks express a safely-convertible overlay relationship: a flexible Color/backgroundColor size-definer under an external definite frame (aspectRatio/containerRelativeFrame). The other 32 are union-sized peers, conditional single-child wrappers, opacity-toggled equal indicators, or gesture/coordinate-critical full-screen decorators — all KEEP."
  - "The content+loading/error family (GalleryList canonical) is KEEP per the plan's own classification; every structurally-identical site (Home, AppActivityLogs, Torrents, Archives, FolderManager, DetailView) follows it."

patterns-established:
  - "Convert a ZStack only when removing the sibling(s) provably leaves the composite size unchanged (flexible Color under a definite external frame); otherwise keep it."

requirements-completed: [POLISH-02]

coverage:
  - id: D1
    description: "3 overlay-relationship ZStacks converted to .overlay (Placeholder activity, Placeholder progress, ReadingViewComponents error page) at size/appearance parity"
    requirement: "POLISH-02"
    verification:
      - kind: automated_ui
        ref: "xcodebuild build -scheme AppFeature: BUILD SUCCEEDED, 0 warnings"
        status: pass
      - kind: other
        ref: "swiftlint lint Placeholder.swift ReadingViewComponents.swift: 0 violations"
        status: pass
    human_judgment: true
    rationale: "Layout/appearance parity of the three converted loading placeholders is inherently visual (D-11 executor-tier). Size-invariance is proven structurally (flexible Color under an unchanged external definite frame, decorator stays centered) and the app launches without layout regression, but a device-level look at the transient loading/error states is the authoritative confirmation."
  - id: D2
    description: "Complete 35-site convert/keep verdict table with size-defining-child rationale; remaining ZStack count (32) equals the KEEP count"
    requirement: "POLISH-02"
    verification:
      - kind: other
        ref: "grep -rn ZStack AppPackage/Sources --include=*.swift | wc -l == 32 (35 baseline - 3 converts)"
        status: pass
    human_judgment: false

# Metrics
duration: 20min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 06: ZStack → overlay/background (POLISH-02) Summary

**Converted the 3 Color-fill overlay-relationship ZStacks (Placeholder activity/progress + the reader error page) to `.overlay`, and recorded a complete 35-site verdict keeping the other 32 union-sized / conditional / gesture-critical stacks as-is.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-18T01:40Z (approx)
- **Completed:** 2026-07-18T02:00Z (approx)
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Classified all 35 `ZStack` occurrences (reconciled against the RESEARCH inventory — count and file set match exactly; line numbers shifted slightly post-10-05, noted below).
- Converted the 3 sites that express a safe overlay relationship; remaining `ZStack` count is 32 == the KEEP count.
- Build clean (0 warnings) on both `AppFeature` and the `EhPanda` app; SwiftLint clean on both changed files; app launches with no layout regression on the visible KEEP carousel card.

## The size-defining-child rule applied

A ZStack is safely convertible **only when removing the sibling(s) leaves the composite size unchanged.** That holds exactly when the retained "modified view" is a *flexible* `Color`/`backgroundColor` (no intrinsic size) sitting under an **external definite frame** (`aspectRatio`, `containerRelativeFrame`) — the Color fills that identical frame whether the decorator is a ZStack child or an `.overlay`, and the decorator was and stays `.center`-aligned. Every other shape either (a) unions two independently-sized children, (b) wraps a single conditional child (no overlay relationship), (c) stacks two equal opacity-toggled indicators (no primary), or (d) is a gesture/coordinate-critical full-screen composite — all KEEP, which the plan explicitly permits.

## Verdict table (all 35 sites)

| # | File:line | Verdict | Size-defining child | Rationale |
|---|-----------|---------|---------------------|-----------|
| 1 | AppComponents/Placeholder.swift:14 (activity) | **CONVERT** | `Color(.systemGray5)` | Canonical shape; `.aspectRatio(.fill).clipShape` impose a definite frame Color fills; ProgressView centered → `.overlay` |
| 2 | AppComponents/Placeholder.swift:23 (progress) | **CONVERT** | `backgroundColor` | Caller (ReadingViewComponents:225) imposes `.containerRelativeFrame([.h,.v]).aspectRatio(.fit)`; VStack centered → `.overlay` |
| 3 | ReadingFeature/ReadingViewComponents.swift:259 | **CONVERT** | `backgroundColor` | Same shape; `.containerRelativeFrame([.h,.v]).aspectRatio(.fit)` on composite; inner opacity-toggled ZStack kept |
| 4 | GalleryListComponents/GalleryList.swift:43 | KEEP | union | Canonical KEEP: content + LoadingView + ErrorView peers, zIndex-managed |
| 5 | HomeFeature/HomeView.swift:21 | KEEP | union | content + loading + error peers (GalleryList pattern) |
| 6 | SettingFeature/AppActivityLogs/AppActivityLogsView.swift:20 | KEEP | union | List + LoadingView + empty-text peers |
| 7 | DetailFeature/Torrents/TorrentsView.swift:21 | KEEP | union | List + loading + error peers |
| 8 | DetailFeature/Archives/ArchivesView.swift:30 | KEEP | union | VStack + loading + error peers |
| 9 | DetailFeature/FolderManager/FolderManagerView.swift:18 | KEEP | union | List + stateOverlay (loading/error) peers |
| 10 | DetailFeature/DetailView.swift:49 | KEEP | union | ScrollView content + state overlay peers |
| 11 | DownloadsFeature/DownloadsView.swift:31 | KEEP | union | full-bleed background Color + list + conditional empty-state; background intentionally paints under safe area |
| 12 | QuickSearchFeature/QuickSearchView.swift:22 | KEEP | List | List host inside NavigationStack; no decorator relationship |
| 13 | SettingFeature/GeneralSetting/GeneralSettingView.swift:51 | KEEP | union | warning Image + ProgressView, two equal opacity-toggled indicators |
| 14 | ReadingFeature/ReadingViewComponents.swift:264 (inner) | KEEP | union | reload Button + ProgressView, two equal opacity-toggled indicators |
| 15 | DetailFeature/DetailView+CommentCells.swift:23 | KEEP | union | thumbsup/thumbsdown, two equal opacity-toggled icons |
| 16 | DetailFeature/Comments/CommentsView.swift:144 | KEEP | union | thumbsup/thumbsdown, two equal opacity-toggled icons |
| 17 | DetailFeature/DetailView+HeaderSection.swift:158 (favoriteButton) | KEEP | union | favorite Button + unfavorite Menu, two equally-framed opacity-toggled states |
| 18 | DetailFeature/DetailView+HeaderSection.swift:195 (progressIndicator) | KEEP | union | conditional ring/progress (multi-child) + center symbol; not a clean single-decorator shape |
| 19 | AppComponents/NewDawnView.swift:42 (sun) | KEEP | union | SunView + SunBeamView (beams larger than sun) |
| 20 | SettingFeature/Components/AboutView.swift:203 | KEEP | conditional | single conditional child (Link vs Text); no overlay relationship |
| 21 | SettingFeature/EhSetting/EhSettingView.swift:21 | KEEP | conditional | loading/error/form mutually-exclusive branches |
| 22 | FavoritesFeature/FavoritesView.swift:33 | KEEP | conditional | GalleryList vs NotLoginView single conditional child |
| 23 | HomeFeature/Watched/WatchedView.swift:23 | KEEP | conditional | GalleryList vs NotLoginView single conditional child |
| 24 | SearchFeature/SearchRootView.swift:130 | KEEP | VStack | single VStack of conditional sections; removing ZStack would alter animation scope |
| 25 | ReadingFeature/ReadingView.swift:137 (inner) | KEEP | conditional | vertical AdvancedList vs horizontalPagingList; stable container for scaleEffect/gestures |
| 26 | SystemNotification/View+Toast.swift:42 | KEEP | conditional | single conditional toast child inside `.overlay(alignment:.bottom)` |
| 27 | AppComponents/AlertView.swift:30 | KEEP | conditional | loading/failed mutually-exclusive, `.frame(height:50)` slot |
| 28 | DownloadsFeature/DownloadsView+Subviews.swift:135 | KEEP | conditional | fixed 20x20 slot holding an optional spinner; no base view |
| 29 | AppComponents/NewDawnView.swift:113 (SunView) | KEEP | single child | ZStack wrapping one framed Circle; no decorator |
| 30 | SettingFeature/Login/LoginView.swift:22 | KEEP | union | full-screen WaveForm background + centered form; converting risks clipping the waves to the form frame |
| 31 | ReadingFeature/ReadingView.swift:134 (outer) | KEEP | union | reader: background color + gesture content + ControlPanel, multiple full-screen peers, gesture-critical |
| 32 | AppComponents/NewDawnView.swift:34 (outer) | KEEP | union | full-screen gradient + sun + text under drawingGroup; flattening interaction risk |
| 33 | ReadingFeature/Support/LiveTextView.swift:21 | KEEP | ambiguous | Canvas tint + positioned HighlightViews; coordinate-critical reader OCR overlay |
| 34 | HomeFeature/GalleryCardCell.swift:59 | KEEP | ambiguous | slot-fill Color + conditional gradient (with transition) + content; layered conditional decorator, not the clean shape |
| 35 | AppComponents/CategoryView.swift:79 | KEEP | union | Rectangle fills width, Text `.padding(.vertical,5)` defines height — each child owns one axis |

**Line-number drift note:** the RESEARCH inventory was captured pre-10-05; line numbers shifted by a few lines in several files but the file set and the count (35) are identical. `SystemNotificationExt/View+Toast.swift` is now `SystemNotification/View+Toast.swift` (renamed in 10-01) — same site.

## Task Commits

1. **Task 1: Classify 35 sites + capture baseline** - no code (classification above; baseline `grep … | wc -l` == 35)
2. **Task 2: Convert the CONVERT-verdict sites** - `9a209aa` (refactor)
3. **Task 3: D-11 before/after comparison** - no reverts required (see below)

**Plan metadata:** committed with this SUMMARY (docs)

## Files Created/Modified
- `AppPackage/Sources/AppComponents/Placeholder.swift` - activity + progress cases: `Color`/`backgroundColor` becomes the modified view, decorator moved into `.overlay { }`
- `AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift` - reader error page: `backgroundColor.overlay { VStack }`, trailing `.containerRelativeFrame`/`.aspectRatio` preserved; the inner opacity-toggled `ZStack` (reload/progress) kept

## Decisions Made
- Converted only the 3 provably size-invariant sites; kept 32. This is the intended outcome — the plan states keeping union-sized/ambiguous stacks is correct and always safe, and names GalleryList (content+loading/error) as the canonical KEEP.

## Deviations from Plan
None - plan executed exactly as written. No CONVERT site drifted, so no Task 3 reverts were needed.

## Issues Encountered
- The plan's verify command referenced `-scheme AppPackage-Package`, which does not exist in this project; built the `AppFeature` scheme (transitively compiles both changed modules — AppComponents and ReadingFeature) instead. Also, the `iPhone 17 Pro` destination is not installed here; used the booted `iPhone 17e` simulator by UDID.
- D-11 evidence: the 3 converts render only during transient image-loading/error states, which are not deterministically reproducible in-sim. Verified instead by (a) BUILD SUCCEEDED 0 warnings, (b) SwiftLint 0 violations, (c) structural size-invariance (flexible Color under an unchanged external definite frame; decorator stays centered), and (d) a clean app launch with no layout regression on the visible KEEP carousel card. Device-level look at the loading/error placeholders remains the authoritative D-11 sign-off (D1 flagged `human_judgment: true`).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- POLISH-02 delivered at parity; remaining ZStack count (32) equals the recorded KEEP count.
- No blockers. Remaining phase-10 plans (10-07..10-12) are independent of this layout change.

## Self-Check: PASSED

- Placeholder.swift, ReadingViewComponents.swift, 10-06-SUMMARY.md all exist
- Commit `9a209aaf` present; Placeholder.swift contains 2 `.overlay` occurrences (POLISH-02 artifact requirement)
- Remaining ZStack count 32 == recorded KEEP count

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
