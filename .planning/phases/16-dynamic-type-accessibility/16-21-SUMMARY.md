---
phase: 16-dynamic-type-accessibility
plan: 21
subsystem: accessibility
tags: [reduce-motion, accessibilityReduceMotion, list-animation, transition, source-scan, swift-testing, d-29, d-31]

# Dependency graph
requires:
  - phase: 16-20
    provides: "The five gate shapes (`reduceMotion ? nil : .default`, `withAnimation(reduceMotion ? nil : …)`, offset collapse, pulse stand-in), the Settings-switch route to toggle Reduce Motion on iPhone 17e `67377A20…`, the install-over protocol and the evidence-root layout"
  - phase: 16-14
    provides: "`AppToolsTests` as the home of repository-walking suites (`CategoryColorsetInvariantTests`), whose root-finding helpers this plan extracted into `RepositoryWalk`"
provides:
  - "Lists and sheets: the identity-keyed Downloads list, the Search root's three suggestion sections, Quick Search's words and edit mode, FolderManager's folders and new-folder row, Torrents' rows, General's three tag-row flags and Home's popular-section insertion all run `reduceMotion ? nil : .default` — rows appear, disappear and shift instantly under Reduce Motion, with the delete flow and manifest SSOT untouched"
  - "Inspector: the validation spinner's transition is `.opacity` under Reduce Motion (scale dropped); the site is source-correct but the transition is inert either way (see Issues) and the digit rolls beside it are untouched"
  - "`ReduceMotionGatingSourceTests` (AppToolsTests): five exact, two-directional equalities over `AppPackage/Sources` — per-file environment reads (17 over 16 files), per-file `reduceMotion ?` ternaries (22 over 14 files), the `withAnimation(reduceMotion` total (2), per-file executable-line mentions of the gate value (52), and the repo-wide `.contentTransition(.numericText` pin (11) with a same-line no-gate check — so a regression and an over-gate both fail"
  - "`RepositoryWalk` (AppToolsTests): the shared repository-root walk, now used by both scanning suites in the target"
  - "Live verification of every site in both Reduce Motion states on the simulator, toggled through the real Settings switch and restored (recordings under `$HOME/Library/Caches/ehpanda-phase16/round2/reduce-motion/16-21/`)"
affects: [16-24, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 8922
  tasks: 3
  commits: 3
  plan_head_before: 465a5c9a07422d0f6580835b24db902fb1b57093

tech-stack:
  added: []
  patterns:
    - "List-diff gating: a `private var listAnimation: Animation? { reduceMotion ? nil : .default }` per view that keys more than one `.animation(_:value:)` on membership; one inline predicate where a view keys a single value"
    - "Source-scan pins in two directions: a per-file table listing only files with a non-zero count, asserted with `==` against the live census, so a count that moves in either direction — or a file that joins or leaves — fails; the joined-text total is asserted separately so two same-named files cannot collapse into one"
    - "When one token cannot see every shape of a gate (a ternary broken across lines, a `||` or `&&` composition), pin the bare identifier's per-file mention count as well: any new gate of any shape moves it"
    - "Repository-root discovery lives once per test target (`RepositoryWalk.repositoryRoot(from: #filePath)`), not per suite"
    - "Motion evidence for list diffs: a 30 fps recording cropped to the list and tiled at 30 fps around the change; the OFF verdict is an intermediate frame (a row between two positions, or at partial opacity), the ON verdict is two consecutive frames with nothing between"
    - "Simulator toggles (the app's `Toggle`s and Settings' Reduce Motion switch) need `sim-use tap --duration 0.05`; a plain tap sometimes lands without flipping the switch"

key-files:
  created:
    - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
    - AppPackage/Tests/AppToolsTests/RepositoryWalk.swift
  modified:
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/SearchFeature/SearchRootView.swift
    - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift
    - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerView.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/HomeFeature/HomeView.swift
    - AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift

key-decisions:
  - "Home is gated: the keyed `.animation(…, value: store.popularLoadingState)` wraps the scroll content only (the overlays are attached after it), and `fetchPopularGalleriesDone` settles the state and lands the galleries in one action, so what it drives is the card section's insertion pushing the sections below it down — position motion. Confirmed live: OFF, the `Frontpage` heading moves down across ~5 frames while the content crossfades in; ON, the crossfade still plays but the heading holds one position from its first frame. The body-form `.visible(!popularGalleries.isEmpty)` fade and the two overlay fades are untouched."
  - "FolderManager's `editingField` is gated together with `folders`: `.newFolder` inserts the new-folder row at the top and pushes every folder row down, and the rename swap rides the same keyed animation (source-verified; the sheet is login-gated, D-09)."
  - "Quick Search's `listEditMode` is gated: the reorder and delete controls slide into every row when edit mode starts (observed OFF as a 4-frame slide from the left; ON, in place in one frame)."
  - "Body-form `.animation(.default) { $0.visible(…) }` closures at every touched site stay byte-identical: they are opacity crossfades (loading / error / empty-state swaps, the Home content fade), out of scope by D-29."
  - "The scan counts three explicit token shapes and one catch-all. `reduceMotion ?` is the ternary table; `withAnimation(reduceMotion` is pinned as a total; `accessibilityReduceMotion` is the read table; and the bare gate-value mention census is what pins the shapes the ternary token cannot see — the toast transition's ternary broken across lines (`reduceMotion` / `? .opacity`), `PrivacyMaskModifier`'s `reduceMotion || blur != 0 ?`, and `HeaderSection`'s `&& !reduceMotion` / `&& reduceMotion`. Every table is exact and lists only non-zero files, so it is two-directional."
  - "`RepositoryWalk` was extracted rather than duplicated: both scanning suites in `AppToolsTests` need the root walk, so `CategoryColorsetInvariantTests` lost its private copies (`repositoryRootMarkers`, `repositoryRoot()`, `isRepositoryRoot`, `repositoryRelativePath`) and calls the shared enum; its scan, pins and messages are otherwise unchanged."
  - "The delete-then-cancel step was done under the orchestrator's coordinate rule and with a substitution: on iOS 26 the row's `Delete Download?` confirmation is a popover anchored to the row with a single `Delete` button and no `Cancel` frame, so it was dismissed by a coordinate tap on the popover's own scrim 370 pt below the button (never by alias); the Home-button substitution was tried first and does not dismiss a popover."
  - "`requirements-completed` stays empty as in 16-15 … 16-20: A11Y-02 is the whole of round 2 and closes with the phase."

patterns-established:
  - "An inert gate is still recorded, not silently 'fixed': the inspector transition sits on an opacity-toggled view and never plays; the plan's gate was applied as written, the observation went to `deferred-items.md`, and the pin counts the site as it is."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Downloads: the identity-keyed list animation and the inspector spinner transition are gated (Task 1, committed by the previous executor)"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "greps at HEAD: `accessibilityReduceMotion` = 1 in DownloadsView.swift, SearchRootView.swift, QuickSearchView.swift, FolderManagerView.swift; `reduceMotion ? .opacity` = 1 in DownloadsView+Subviews.swift; `numericText` in DownloadsView+Subviews.swift = 2 before and after; `DownloadInspectorPageGroupRow` (the `countAnimation` block) byte-identical to 465a5c9a; lint build `** BUILD SUCCEEDED **`, 0 `Violation:` lines"
        status: pass
      - kind: unit
        ref: "DownloadsFeatureTests on 67377A20… — 488 tests / 84 suites passed (previous executor's run); re-run inside the full FeatureTests plan below"
        status: pass
      - kind: manual_procedural
        ref: "downloads-filter-off.mp4 (30 fps: the Aroma row caught at two intermediate positions while the rows above fade) vs downloads-filter-on.mp4 (each membership change lands in one frame at final positions); delete-cancel-off.mp4 / delete-cancel-on.mp4 (swipe → popover → scrim dismissal; three rows and the 114-entry folder intact after each)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Search root, Quick Search and FolderManager list diffs are gated"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "`listAnimation` ×3 in SearchRootView.swift, ×2 in QuickSearchView.swift, ×2 in FolderManagerView.swift (source-verified; FolderManager is login-gated)"
        status: pass
      - kind: manual_procedural
        ref: "search-root-off.mp4 (`Recently Searched` fades while `Recently Seen` slides up over ~8 frames) vs search-root-on.mp4 (section vanishes and `Recently Seen` jumps between consecutive frames); quicksearch-edit-off.mp4 (delete controls slide in over ~4 frames) vs quicksearch-edit-on.mp4 (in place in one frame); quicksearch-delete-off.mp4 (row fades over ~8 frames as the section collapses) vs quicksearch-delete-on.mp4 (row and section space gone between consecutive frames)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Torrents, General tag rows and Home's popular-section insertion are gated; crossfades and the cache-size digit roll stay"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "greps: `accessibilityReduceMotion` = 1 in TorrentsView.swift, GeneralSettingView.swift, HomeView.swift; `rowAnimation` ×3 on the tag flags, `.animation(.default, value: store.diskImageCacheSize)` unchanged; lint build `** BUILD SUCCEEDED **`, 0 violations"
        status: pass
      - kind: manual_procedural
        ref: "torrents-off.mp4 (row arrives with one partial-opacity frame) vs torrents-on.mp4 (absent → fully drawn between consecutive frames); general-off.mp4 (three rows fade while `Import Custom Translations` and Navigation slide up over ~8 frames) vs general-on.mp4 (rows and shifted sections appear in one frame at final positions; the native switch knob still animates); home-off.mp4 (`Frontpage` heading shifts down across ~5 frames as the cards fade in) vs home-on.mp4 (heading fixed from its first frame, crossfade kept)"
        status: pass
    human_judgment: false
  - id: D4
    description: "`ReduceMotionGatingSourceTests` pins the D-29 inventory exactly and in both directions"
    requirement: A11Y-02
    verification:
      - kind: unit
        ref: "xcodebuild test … -only-testing:AppToolsTests/ReduceMotionGatingSourceTests on 67377A20…: RED (empty tables) — suite failed, 5/5 tests, 26 issues; GREEN — 5/5 passed; mutation (Torrents gate removed + General digit roll over-gated) — 3/5 failed (ternary table, mention census, numericText 10 ≠ 11), reverted"
        status: pass
      - kind: unit
        ref: "Full FeatureTests plan, one invocation, on 67377A20…: `** TEST SUCCEEDED **`, 22 targets, 1,060 tests in 185 suites, 0 failures, 0 `Violation:` lines"
        status: pass
    human_judgment: false
  - id: D5
    description: "Simulator idempotency: Reduce Motion toggled through the real Settings switch and restored; baselines unchanged; nothing uninstalled or erased; the re-downloaded gallery intact"
    verification:
      - kind: other
        ref: "`ReduceMotionEnabled` 1 (as left) → 0 (start of OFF pass) → 1 (ON pass) → 0 (restored, read back, switch unselected in settings-reduce-motion-off-restored.png); `appearance light` / `content_size large` / `increase_contrast disabled` before and after; `4178996` shows 112/112 in `Default` (downloads-list-state.png) and its folder holds 114 entries before and after both delete-then-cancel passes; Quick Search left empty, history keyword removed; `simctl shutdown` → Shutdown; `agent-device close` → sessions 0"
        status: pass
    human_judgment: false

# Metrics
duration: 1h 38m
completed: 2026-09-12
status: complete
---

# Phase 16 Plan 21: Reduce Motion gating — lists, sheets, settings + inventory pin Summary

**Every remaining D-29 list-diff site (Downloads, Search root, Quick Search, FolderManager, Torrents, General tag rows, Home's card insertion) and the inspector transition now read `accessibilityReduceMotion` at the animating view and go instant or opacity-only under Reduce Motion, verified in both states through the real Settings switch; and `ReduceMotionGatingSourceTests` freezes the whole D-29 inventory as five exact two-directional equalities (reads 17, ternaries 22, `withAnimation` 2, mentions 52, `numericText` 11 and none gated), proven RED → GREEN with a mutation check in each direction.**

## Performance

- **Duration:** 1h 38m from the Task 1 commit to the Task 3 commit (`b5e69032` 2026-09-11T22:11:50Z → `bb265cb1` 2026-09-11T23:49:11Z); this continuation ran 2026-09-11T22:56Z → 23:49Z. Task 1's own start is not on record (it was executed by the previous executor).
- **Started:** 2026-09-11T22:11:50Z (Task 1 commit; earliest recorded point)
- **Completed:** 2026-09-11T23:49:34Z
- **Tasks:** 3
- **Files modified:** 9 source/test files (+ `deferred-items.md`), 2 created

## Accomplishments

- Eight view files gated with a doc-commented reason at each site; no environment value mirrored into TCA state or set in a `#Preview` (RESEARCH Pitfall 10); no static layout changed, no D-25 screen added (D-24).
- Every crossfade, every `.contentTransition(.numericText…)` and the Downloads inspector's `countAnimation` block are byte-identical (D-29 out-of-scope list honoured; repo-wide `numericText` count 11 before and after).
- Both Reduce Motion states observed live on iPhone 17e `67377A20…` for all eight sites (FolderManager source-verified: login-gated), the setting toggled through Settings › Accessibility › Motion and restored to `0`.
- A permanent, cheap regression gate: `ReduceMotionGatingSourceTests` (0.24 s) fails on a dropped gate, a new gate anywhere in `AppPackage/Sources`, and a gate on a digit roll.
- Lint build green (0 violations, no suppression); the full `FeatureTests` plan green in one invocation (1,060 tests / 185 suites / 22 targets).

## Task 1 record (committed by the previous executor as `b5e69032`, re-verified at HEAD)

| Site | Gate | Reason |
|---|---|---|
| `DownloadsView+Subviews.swift` `DownloadInspectorValidationActionLabel` spinner `.transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.85)))` | scale dropped | the spinner's arrival grows from 85 % — size motion |
| `DownloadsView.swift` `.animation(reduceMotion ? nil : .default, value: store.filteredDownloads.map(\.id))` | `nil` | identity-keyed membership: a confirmed delete collapses the row, a folder or keyword filter slides the rest; the Phase 15 comment kept, one line appended (delete flow and manifest unchanged) |
| `SearchRootView.swift` `SuggestionsPanel` `listAnimation` ×3 (`quickSearchWords`, `historyGalleries`, `historyKeywords`) | `nil` | whole sections insert and remove as words, keywords and galleries come and go |
| `QuickSearchView.swift` `listAnimation` ×2 (`quickSearchWords`, `listEditMode`) | `nil` | rows insert / delete / reorder; edit mode slides the reorder and delete controls into every row |
| `FolderManagerView.swift` `listAnimation` ×2 (`folders`, `editingField`) | `nil` | folders come and go as rows; `.newFolder` inserts the top row and pushes every folder down; the rename swap rides the same keyed animation |

Greps at HEAD: `accessibilityReduceMotion` = 1 in each of the four list files; `reduceMotion ? .opacity` = 1 in `DownloadsView+Subviews.swift`; `numericText` in that file = 2 before and after; the `DownloadInspectorPageGroupRow` block is byte-identical to `465a5c9a`; `swiftlint:disable` added by this plan = 0. The previous executor recorded `DownloadsFeatureTests` 488 tests / 84 suites passed on `67377A20…`; the full plan below re-ran them.

## Task 2 per-site gating (`9841ff22`)

| Site (at HEAD) | Motion | Gate | Degrades to |
|---|---|---|---|
| `TorrentsView.swift` `.animation(reduceMotion ? nil : .default, value: store.torrents)` | fetched torrents arrive as whole rows | `nil` | rows appear in place; the loading / error overlay crossfades above it unchanged |
| `GeneralSettingView.swift` `rowAnimation` on `tagTranslatorHasCustomTranslations`, `setting.enableTagsExtension`, `tagTranslatorEmpty` | the three tag flags insert and remove whole rows of the Tags section, shifting everything below | `nil` | rows appear and disappear instantly; `Text(store.diskImageCacheSize).contentTransition(.numericText()).animation(.default, value:)` untouched (digit change) |
| `HomeView.swift` `.animation(reduceMotion ? nil : .default, value: store.popularLoadingState)` | the card section's insertion pushes Frontpage / Toplists / Misc down (judgement in `key-decisions`) | `nil` | sections take their final position in one frame; the `.visible(!popularGalleries.isEmpty)` fade and both overlay fades stay |

Body-form `.animation(.default) { … }` closures in the touched files (`DownloadsView.swift:31`, `TorrentsView.swift:39,48`, `HomeView.swift:72,83,95`, `GeneralSettingView.swift:76,87`) are opacity crossfades and are byte-identical.

## Reduce Motion OFF / ON observations

Simulator: iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` (iOS 26.5), found booted with the app installed by the previous executor from the Task 2 tree (install-over per `16-SWEEP.md § Protocol`, `CFBundleIdentifier = app.ehpanda.personal`; the tree was committed unchanged as `9841ff22`, so no re-install was needed) and with `ReduceMotionEnabled` reading `1`. Baselines re-read at the start and end: `appearance light`, `content_size large`, `increase_contrast disabled`. Reduce Motion was switched OFF first (Settings › Accessibility › Motion, the switch knob at ≈(330, 145) pt; read back `0`; `settings-reduce-motion-off-start.png`), the OFF pass run, then ON (`sim-use tap --duration 0.05` — a plain tap did not flip it once; read back `1`; `settings-reduce-motion-on.png`), the ON pass run, then restored (`0`, switch unselected; `settings-reduce-motion-off-restored.png`). No credential entered (D-09); nothing uninstalled, erased or reset. Evidence root `$HOME/Library/Caches/ehpanda-phase16/round2/reduce-motion/16-21/` (never in the repo; image check 0 before every commit). Each recording (`sim-use record-video`, 30 fps, full scale) was read as a contact sheet cropped to the list and tiled at 30 fps around the change; sheets stayed in the session scratchpad.

| Site | OFF (recording) | ON (recording) | Verdict |
|---|---|---|---|
| Inspector spinner (`4178996` › Pages › Validate Image Data) | `inspector-off.mp4`: the spinner is on screen for 3 consecutive 30 fps frames at full size and opacity, then gone in one; no scale-in, no fade | `inspector-on.mp4`: identical — 3 frames, constant size and opacity | **indistinguishable by design of the site**: `visible(_:)` is an opacity toggle, so the view is never inserted and no `.transition` (scale or opacity) plays; gate source-correct, transition inert (see Issues) |
| Downloads list — keyword filter `Aroma` then cleared | `downloads-filter-off.mp4`: at the change the Aroma row is caught at two intermediate positions while the rows above fade (slide over ~3 frames) | `downloads-filter-on.mp4`: 3 rows → 2 → 1, each in one frame at final positions, no fade | pass |
| Downloads list — delete-then-cancel on `4178996` | `delete-cancel-off.mp4` + `delete-dialog-off.png` / `delete-cancelled-off.png`: trailing swipe → `Delete` swipe action → row-anchored popover (`Delete Download?`, one `Delete` button) → scrim dismissal; three rows remain, folder 114 entries | `delete-cancel-on.mp4`: same flow; three rows remain, folder 114 entries | flow intact in both states (T-16-19); no membership change to animate on cancel |
| Search root — remove the `Recently Searched` keyword `rm1621a` | `search-root-off.mp4`: the section fades while `Recently Seen` slides up over ~8 frames | `search-root-on.mp4`: section gone and `Recently Seen` in place between consecutive frames | pass |
| Quick Search — Edit mode on / off (`listEditMode`) | `quicksearch-edit-off.mp4`: delete controls slide in from the left over ~4 frames, labels shift right | `quicksearch-edit-on.mp4`: controls in place in one frame | pass |
| Quick Search — delete `rm1621b` (`quickSearchWords`) | `quicksearch-delete-off.mp4`: the row fades over ~8 frames as the section's bottom edge collapses | `quicksearch-delete-on.mp4`: row and section space gone between consecutive frames | pass |
| Quick Search — add `rm1621b` | `quicksearch-add-off.mp4`: the insertion lands behind the editor's pop transition (row already in place when the list reappears) | — | not observable in either state; covered by the delete and edit-mode observations of the same `listAnimation` |
| FolderManager (`folders`, `editingField`) | — | — | **source-verified**: the sheet is login-gated (D-09); same `listAnimation` shape as the observed Quick Search sites |
| Torrents (`4178996` › More › Torrents (1)) | `torrents-off.mp4`: the row arrives with one partial-opacity frame | `torrents-on.mp4`: absent → fully drawn between consecutive frames | pass (the sheet's own presentation is the OS transition, not a site) |
| General › Enable Tags Extension on / off | `general-off.mp4`: the three rows fade while `Import Custom Translations` and Navigation slide up over ~8 frames | `general-on.mp4`: rows and shifted sections appear in one frame at final positions; the native switch knob still animates; the translator's `ProgressView` crossfade beside the label still plays | pass; switch left off as found |
| Home — popular section arriving after relaunch | `home-off.mp4`: `Frontpage` / `Toplists` headings move down across ~5 frames while the whole content crossfades in | `home-on.mp4`: content still crossfades in; the `Frontpage` heading holds one position from its first frame | pass — confirms the gating judgement |

Restore: `ReduceMotionEnabled` `0` read back; baselines unchanged; the Quick Search words I added (`rm1621a`, `rm1621b`) deleted and the history keyword removed, leaving Quick Search empty and the panel as found; the search field's leftover text cleared; `xcrun simctl shutdown` → Shutdown; `agent-device close` → sessions 0. No D-25 screen added (D-24): nothing here changes static layout.

## Task 3 — `ReduceMotionGatingSourceTests` (`bb265cb1`)

**RED** (empty tables, all totals 0): `xcodebuild test … -only-testing:AppToolsTests/ReduceMotionGatingSourceTests` on `67377A20…` — `Suite ReduceMotionGatingSourceTests failed … with 26 issues`, all five tests failing, each printing the live census (e.g. reads `["…/DownloadsView+Subviews.swift": 2, …]` against `[:]`).

**GREEN** (tables derived from the live tree with a script replicating the suite's rule — substring occurrences over non-comment lines, per file — then pinned as equalities): 5 / 5 passed in 0.24 s, `** TEST SUCCEEDED **`.

**Mutation** (two edits at once): `TorrentsView.swift` gate removed (`.animation(.default, value: store.torrents)`) and `GeneralSettingView.swift` digit roll over-gated (`.contentTransition(reduceMotion ? .identity : .numericText())`) → `ternaryPredicatesMatchTheRecordedInventory`, `gateMentionsMatchTheRecordedInventory` and `numericTextSitesStayUngated` (total 10 ≠ 11) failed, 3 / 5; both files reverted with `git checkout --`, tree confirmed clean of the mutation.

Pinned table (path relative to `AppPackage/Sources`; reads / `reduceMotion ?` / mentions):

| File | reads | ternaries | mentions | shapes the ternary token misses |
|---|---|---|---|---|
| `AppComponents/ViewModifiers.swift` | 1 | 0 | 2 | `reduceMotion \|\| blur != 0 ? nil : …` |
| `DetailFeature/Comments/CommentsView.swift` | 1 | 1 | 2 | (`withAnimation` gate, pinned total) |
| `DetailFeature/DetailView+HeaderSection.swift` | 1 | 0 | 3 | `&& !reduceMotion`, `&& reduceMotion` |
| `DetailFeature/DetailView.swift` | 1 | 3 | 4 | |
| `DetailFeature/FolderManager/FolderManagerView.swift` | 1 | 1 | 2 | |
| `DetailFeature/Torrents/TorrentsView.swift` | 1 | 1 | 2 | |
| `DownloadsFeature/DownloadsView+Subviews.swift` | 2 | 3 | 8 | parameter plumbing (`reduceMotion: reduceMotion`, `let reduceMotion: Bool`); the unused `progressAnimation` predicate counts |
| `DownloadsFeature/DownloadsView.swift` | 1 | 1 | 2 | |
| `HomeFeature/GalleryCardCell.swift` | 1 | 2 | 9 | parameter plumbing into `CardGradientView` |
| `HomeFeature/HomeView.swift` | 1 | 1 | 2 | |
| `QuickSearchFeature/QuickSearchView.swift` | 1 | 1 | 2 | |
| `ReadingFeature/ReadingView.swift` | 1 | 3 | 4 | (`withAnimation` gate, pinned total) |
| `ReadingFeature/Support/ControlPanel.swift` | 1 | 2 | 3 | |
| `SearchFeature/SearchRootView.swift` | 1 | 1 | 2 | |
| `SettingFeature/GeneralSetting/GeneralSettingView.swift` | 1 | 1 | 2 | |
| `SystemNotification/View+Toast.swift` | 1 | 1 | 3 | the transition's ternary broken across lines |
| **Totals** | **17** | **22** | **52** | `withAnimation(reduceMotion` = **2** |

`numericText` pin: `.contentTransition(.numericText` = **11** repo-wide (`ArchivesView.swift` 2, `DetailView+Subviews.swift` 3, `DownloadsView+Subviews.swift` 2, `DownloadBadgeLabel.swift` 1, `ReadingToolbar.swift` 1, `DownloadSettingView.swift` 1, `GeneralSettingView.swift` 1) — equal to `grep -rc "contentTransition(.numericText" AppPackage/Sources | awk -F: '{s+=$2} END {print s}'` at HEAD; none of those lines mentions the gate value. The read table is compared for key-set equality with the mention census, and every file in the ternary table and the `withAnimation` census must be in the read table.

Test-target helpers: `RepositoryWalk` (new, `AppToolsTests`) carries `repositoryRootMarkers`, `repositoryRoot(from: #filePath)`, `isRepositoryRoot`, `relativePath(of:under:)`; `CategoryColorsetInvariantTests` now calls it and lost its four private copies (−42 lines; its scan, pins and messages unchanged, and it passed in the full run). The census / executable-line helpers stay in a `private extension` of the new suite — they are the `DownloadSourceInventoryTests` pattern, not something the colorset suite needs. Standalone SwiftLint 0.65.0 over the three test files with the target's `.swiftlint.yml`: exit 0, no violations, no suppression.

## Task Commits

1. **Task 1: Downloads inspector + list, Search root, Quick Search, FolderManager** — `b5e69032` (feat; previous executor)
2. **Task 2: Torrents, General settings, Home; simulator verification in both states** — `9841ff22` (feat)
3. **Task 3: `ReduceMotionGatingSourceTests`** — `bb265cb1` (test; RED → GREEN in one commit — the RED state is the recorded run above, not a separate commit, as the plan's `test(16-21)` message names one commit)

**Plan metadata:** the docs commit carrying this file.

## Files Created/Modified

- `AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift` — the five censuses and their pinned tables; doc comment states the WHY (D-29 judged once, frozen so neither a regression nor an over-gate lands silently) and the shapes the mention census exists for.
- `AppPackage/Tests/AppToolsTests/RepositoryWalk.swift` — shared repository-root discovery for the target's scanning suites.
- `AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift` — uses `RepositoryWalk`; private copies removed.
- `AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift`, `…/SettingFeature/GeneralSetting/GeneralSettingView.swift`, `…/HomeFeature/HomeView.swift` — Task 2 gates with doc comments.
- `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift`, `…/DownloadsView.swift`, `…/SearchFeature/SearchRootView.swift`, `…/QuickSearchFeature/QuickSearchView.swift`, `…/DetailFeature/FolderManager/FolderManagerView.swift` — Task 1 gates (previous executor).
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — two `Found during 16-21` entries (below).

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

No deviation rule (1–4) fired: no bug, missing functionality or blocker in the code, and no architectural question. The differences below are between the plan's environment / line references and HEAD, applied per the orchestrator's pre-authorisations, plus one substitution under its destructive-control rule.

1. **Simulator and test destination (env fact 5).** iPhone 17e `67377A20…` for every test run and both passes instead of the plan's `88B217DA…`; commands otherwise as written.
2. **Delete-then-cancel (env fact 1).** The row's confirmation is a row-anchored popover with no `Cancel` frame (AX tree: `Delete Download?`, the description, one `Delete` button (91,240 208x48) and the `dismiss popup` group). The Home-button substitution was tried first and does not dismiss a popover, so it was dismissed by a coordinate tap on the scrim at (195, 660) — verified empty with `describe-ui --point` before tapping, 370 pt below the `Delete` button — never by `--label` or alias. Both times the gallery and its folder were verified intact afterwards.
3. **Quick Search removals are confirmations of my own items.** The plan asks to add and then remove a Quick Search item; the removal's `Delete` confirmation (and the final cleanup of `rm1621a`) was confirmed by coordinate on the exact `Delete` frame read from the tree, for words this plan had created seconds earlier. The Search root's keyword removal is an `xmark` button, no dialog.
4. **Sites not observable as written.** The Quick Search insertion lands behind the editor's pop (recorded, not judgeable); the inspector transition is inert (Issues). Both are recorded as such rather than as passes.
5. **Evidence form (env fact 6).** Recordings tiled at 30 fps rather than paired screenshots — a `.default` animation is shorter than the tool round-trip; 22 recordings and 6 screenshots, none in the repo.
6. **One TDD commit.** The plan names one `test(16-21)` commit; RED is recorded above as a run, not committed.
7. **Task 3 touched `CategoryColorsetInvariantTests.swift`** (not in the plan's `files_modified`) to use the extracted `RepositoryWalk`, per the plan's own instruction not to duplicate the walk silently.

## Issues Encountered

- **Simulator incident (previous executor, recorded verbatim from the orchestrator):** while opening the Downloads inspector, a `sim-use tap --label "dismiss popup"` on the row's `Delete Download?` alert resolved to (195, 422) inside the `Delete` button frame and confirmed the deletion of public gallery `4178996` (Yumenekoya, 112 pages) from folder `Default`. The orchestrator ordered it re-downloaded; that re-download completed before this continuation. Observed state at the start of this continuation: the `Default` row shows `4178996` complete at **112/112** (`downloads-list-state.png`), its folder `Documents/Downloads/Default/[4178996_918d284b74] …` holds 114 entries; `Second` untouched (`4183242` 28/28 complete, `4179873` paused 1/205). Verified again after each delete-then-cancel pass (114 entries, three rows). This continuation never used `--label` / alias resolution near any destructive control.
- **Inspector transition is inert (out of scope, appended to `deferred-items.md`).** `visible(_:)` is `opacity(isVisible ? 1 : 0)`, so the `ProgressView` is never inserted or removed and its `.transition` never plays in either state; the validation of 112 files takes ≈100 ms, so the spinner shows for three 30 fps frames at constant size and opacity. The plan's gate was applied as written and is pinned as it is; the fix (an `if isValidating { … }` so the transition is real, or dropping the transition) belongs with the already-deferred unused `progressAnimation` in the same view.
- **Tab-bar alias failure on Home.** `sim-use tap '#gearshape.circle'` failed to resolve on the Home tab (hint only, no tap), and the following coordinate taps landed on a Home gallery's Detail: at (195, 238) it opened the Detail, and at (333, 344) it hit the read-only stats row — far from the header's trash button at (201, 272). Nothing changed; navigation was redone by tab-bar coordinates with a frame read before recording. Every later tab switch used coordinates.
- **One stray Home press.** After the first OFF filter recording I pressed the simulator's Home button (intending to dismiss the keyboard); the app was foregrounded again with `simctl launch`, no state affected.
- **SwiftUI toggles need a hold.** The app's `Toggle` and Settings' Reduce Motion switch ignored a plain `sim-use tap` on some attempts; `--duration 0.05` flipped them every time (recorded in `patterns`).
- **Access levels in a `private extension`.** The first RED build failed because helpers taking the private `ScannedFile` were not themselves `private`; fixed before the RED run (the RED run recorded above is the fixed file with empty tables).

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-22 mitigated (the numericText pin and the exhaustive tables; mutation check in both directions). T-16-19 mitigated (only `.animation` modifiers changed on the Downloads list; the delete flow observed intact in both states; `DownloadsFeatureTests` green inside the full plan). T-16-03 mitigated (no re-install needed — the installed tree equals `9841ff22`; nothing uninstalled, erased or reset; Reduce Motion and baselines restored and read back).

## Deferred items appended

- `DownloadInspectorValidationActionLabel`: the gated `.transition` is inert because the spinner's visibility is an opacity toggle (this plan).
- (Previous executor, kept) `DownloadInspectorValidationActionLabel.progressAnimation` is declared but referenced nowhere.

## User Setup Required

None.

## Next Phase Readiness

- Ready for 16-22 (wave 20). The D-29 inventory is frozen: any later plan that adds or removes a Reduce Motion gate must update `ReduceMotionGatingSourceTests` deliberately, and a gate on a digit roll fails it.
- Open for the owner: the inert inspector transition + unused `progressAnimation` pair in `DownloadsView+Subviews.swift` (deferred), and whether the Downloads delete popover should carry an explicit Cancel for assistive use (it has none; dismissal is the scrim).

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-12*

## Self-Check: PASSED

SUMMARY present; the two created and three Task 2 files present; commits `b5e69032`, `9841ff22`, `bb265cb1` found in history; 0 absolute home paths in the SUMMARY and `deferred-items.md`; 0 image files in `git status`.
