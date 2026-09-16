---
phase: 16-dynamic-type-accessibility
plan: 25
subsystem: accessibility
tags: [swiftui, voiceover, dynamic-type, walkthrough]
requires:
  - phase: 16-dynamic-type-accessibility
    provides: approved audit protocol and pre-existing accessibility fixes
provides:
  - round-2 bounded walkthrough closure with carried items
  - E-1 retirement evidence and D-25 classification
affects: [16-26]
tech-stack:
  added: []
  patterns: [bounded VoiceOver evidence, source-backed accessibility ledger]
key-files:
  created: [.planning/phases/16-dynamic-type-accessibility/16-25-SUMMARY.md]
  modified:
    - AppPackage/Sources/AppComponents/ViewModifiers.swift
    - AppPackage/Sources/AppComponents/SubSection.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
    - AppPackage/Sources/SearchFeature/SearchRootView.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/SettingFeature/Login/LoginView.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/DetailFeature/Components/PostCommentView.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/GalleryListComponents/Resources/Localizable.xcstrings
    - AppPackage/Sources/DetailFeature/GalleryDetail+Accessibility.swift
    - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift
    - AppPackage/Sources/DetailFeature/GalleryComment+Accessibility.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/SystemNotification/View+Toast.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionHeartbeatTests.swift
    - EhPandaUITests/AccessibilityAuditUITests.swift
key-decisions:
  - "Only 7edfb1a7 is rendered D-25 scope: Search root, Favorites, and Watched."
  - "Task 7 closes with carried items; unresolved focus and phonetic judgments remain for 16-26."
requirements-completed: []
coverage: []
duration: bounded walkthrough and documentation session
completed: 2026-09-17
status: complete
---

# Phase 16 Plan 25: Dynamic Type Accessibility Summary

Round-2 VoiceOver, display, hide-inventory, E-1, and D-25 evidence was recorded with explicit carried limits.

## Accomplishments

- Canonical Flow and Findings cells retain first-run text and append bounded `walk 2:` evidence with `$HOME` paths.
- Current hide status is 38 hidden, 2 not an element, 15 unreached with concrete reasons, and 0 pending; historical pending wording remains historical.
- E-1 was retired after phone and iPad after-fix audits passed with Repetition 0; `testReadingControlPanelAudit` is the standing regression.
- D-25 maps only `7edfb1a7` to rendered changes across Search root, Favorites, and Watched. The other 14 fix commits are non-rendered semantics or test/audit-only; 3 test commits are recorded separately, including the removed VO-2 regression.
- Final WALK/LOGIN/gate simulator inventory was restored and shut down with baseline settings.

## Task Commits

1. **Task 1: tracer and preparation** — `401fee9d` (documentation start record)
2. **Task 2: walk and sweep** — `16c2e149` (flow results documentation)
3. **Task 3: owner listening evidence** — `16c2e149` (flow results and owner responses)
4. **Task 4: root cause and proposals** — `55d54d0a` (design documentation)
5. **Task 5: orchestrator decision** — `05c0863d` (decision documentation)
6. **Task 6: fixes and gates** — the 18 historical commits below (15 fix + 3 test), plus gate documentation commits `4f1a59ca`, `91f99833`, and `ad941bab`.
7. **Task 7: re-walk and closure** — `77d16bef` (`docs(16): record round-2 walkthrough`)

Task 6 historical fix/test commits, each checked against actual git history, are:

| Commit | Subject |
|---|---|
| `50e8412d` | `test(16-25): pin hidden content accessibility` |
| `26625a78` | `fix(16-25): visible() hidden content fix` |
| `5c210835` | `test(16-25): drop unpinnable VO-2 regression` |
| `a0a2cbb3` | `test(16-25): avoid extra heartbeat clock tick` |
| `962f60c9` | `fix(16-25): home carousel VoiceOver traversal` |
| `a8cb5d53` | `fix(16-25): section heading traits` |
| `6b7ef86a` | `fix(16-25): reader context menu actions` |
| `464d1584` | `fix(16-25): clarify setting accessibility` |
| `772e8f85` | `fix(16-25): detail accessibility semantics` |
| `f811bf5e` | `fix(16-25): gallery and download semantics` |
| `700db090` | `fix(16-25): speak binary size units` |
| `a12b9903` | `fix(16-25): spell out Latin day periods` |
| `a90750a7` | `fix(16-25): restore reader trigger focus` |
| `c30fbe08` | `fix(16-25): keep toast after screen content` |
| `aa3d9947` | `fix(16-25): restore download row focus` |
| `24f5847a` | `fix(16-25): focus newly loaded content` |
| `7edfb1a7` | `fix(16-25): stabilize sparse search layout` |
| `b01add4c` | `fix(16-25): retire E-1 audit exclusion` |

The 18 historical `fix(16-25)`/`test(16-25)` commits are listed in the cache preparation ledger, with every changed source/test file. The three test commits are `50e8412d` (pin VO-2 regression), `5c210835` (remove the unpinnable regression; historical removed test), and `a0a2cbb3` (heartbeat test clock fix). Current source is `b01add4c11b1f9c355ac8f2e055ed8b24fe8146c`; final by-UDID install evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-walk-install.txt` and `task7-final-login-install.txt`, recording loader SHA `0e44527c4e7b76aba45e7f724900bbbf0290c829f13013354e6d10408883babb` and installed dylib SHA `1b02f72e4aebb0d3dc7830e9c2e129ad4a96d3927d96c638217e9ac2709b6621`.


## Evidence and limits

- Initial `cc05aca6` inventory: raw G1=25/G2=2/G3=51/G4=23; swept G1=7/G2=2/G3=46 plus 7 paired G4; excluded G1=18/G2=0/G3=5 plus 16 unpaired G4. Initial runtime was 34 hidden, 4 leaks, 2 not-an-element, 15 unreached; current bounded result is 38/2/15/0.
- Closing gates recorded FeatureTests 1039 passed plus 11 expected failures, zero failed/skipped/Repetition; iPhone UI 39 passed with 2 iPad-only skips; iPad UI 41 passed; lint covered 579 files with zero violations. The full FeatureTests bundle covered 15 historical references (13 existing, 1 moved, 1 merged) without another regression run.
- Voice Control spoken commands and VoiceOver double-tap activation were not measured; Voice Control evidence is native-label proxy evidence only. W-8, W-35, VO-3, W-13 Comments, and W-38 remain unresolved or carried to 16-26. W-33/W-34 await owner phonetic sign-off. L-6 was not independently run and reuses the dated L-5 sample only for date coverage.
- The current D-25 scope supersedes the historical Activity Logs/Laboratory candidates (reverted by `cc05aca6`); Gallery Detail is withdrawn. The 45 → 65 Settings decision remains retained. No A11Y-02 requirement is completed here, and Phase 16 is not complete.

## Deviations from Plan

- VO-1 received an extended bounded walk to establish the approved traversal evidence.
- The unpinnable VO-2 regression was removed; E-1's standing audit regression provides the remaining guard.
- W-22 natural colour differences were retained under the approved acceptance.
- Closing gates/runtime and documentation were ordered around the immutable `b01add4c` source and existing evidence.
- Historical pending wording was retained while current Flow/Findings tables were closed semantically.
- Focus candidates were withdrawn or carried where their targets were not met; they were not presented as fixes.
- The complete FeatureTests bundle covered the historical regression references; no redundant second run was performed.

## Next Phase Readiness

16-26 owns the three-screen D-25 re-sweep, carried focus limits, and remaining owner judgments. No source or device work is pending from this documentation result.
