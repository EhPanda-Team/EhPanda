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
  - "Only 782768b2a7 is rendered D-25 scope: Search root, Favorites, and Watched."
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
- D-25 maps only `782768b2a7` to rendered changes across Search root, Favorites, and Watched. The other 14 fix commits are non-rendered semantics or test/audit-only; 3 test commits are recorded separately, including the removed VO-2 regression.
- Final WALK/LOGIN/gate simulator inventory was restored and shut down with baseline settings.

## Task Commits

1. **Task 1: tracer and preparation** — `7122f98c52` (documentation start record)
2. **Task 2: walk and sweep** — `4ff1260158` (flow results documentation)
3. **Task 3: owner listening evidence** — `4ff1260158` (flow results and owner responses)
4. **Task 4: root cause and proposals** — `e41e3b2f1c` (design documentation)
5. **Task 5: orchestrator decision** — `b765777cbd` (decision documentation)
6. **Task 6: fixes and gates** — the 18 historical commits below (15 fix + 3 test), plus gate documentation commits `8f8490f804`, `6f24af6148`, and `daf4719301`.
7. **Task 7: re-walk and closure** — `0320c38919` (`docs(16): record round-2 walkthrough`)

Task 6 historical fix/test commits, each checked against actual git history, are:

| Commit | Subject |
|---|---|
| `0645a87513` | `test(16-25): pin hidden content accessibility` |
| `35904cfc97` | `fix(16-25): visible() hidden content fix` |
| `a618d0b100` | `test(16-25): drop unpinnable VO-2 regression` |
| `6a88427432` | `test(16-25): avoid extra heartbeat clock tick` |
| `c0e123c4e9` | `fix(16-25): home carousel VoiceOver traversal` |
| `8644199063` | `fix(16-25): section heading traits` |
| `ca562ecfbe` | `fix(16-25): reader context menu actions` |
| `f628dcd118` | `fix(16-25): clarify setting accessibility` |
| `5dbf7a82c7` | `fix(16-25): detail accessibility semantics` |
| `ef452df527` | `fix(16-25): gallery and download semantics` |
| `384d90b629` | `fix(16-25): speak binary size units` |
| `52edf543b0` | `fix(16-25): spell out Latin day periods` |
| `013be9af37` | `fix(16-25): restore reader trigger focus` |
| `045c4f8c2b` | `fix(16-25): keep toast after screen content` |
| `6fc494cc72` | `fix(16-25): restore download row focus` |
| `ae0010ad18` | `fix(16-25): focus newly loaded content` |
| `782768b2a7` | `fix(16-25): stabilize sparse search layout` |
| `310a39625f` | `fix(16-25): retire E-1 audit exclusion` |

The 18 historical `fix(16-25)`/`test(16-25)` commits are listed in the cache preparation ledger, with every changed source/test file. The three test commits are `0645a87513` (pin VO-2 regression), `a618d0b100` (remove the unpinnable regression; historical removed test), and `6a88427432` (heartbeat test clock fix). Current source is `310a39625fb2cb7035415c73a91eb3ff4b7266cc`; final by-UDID install evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-walk-install.txt` and `task7-final-login-install.txt`, recording loader SHA `0e44527c4e7b76aba45e7f724900bbbf0290c829f13013354e6d10408883babb` and installed dylib SHA `1b02f72e4aebb0d3dc7830e9c2e129ad4a96d3927d96c638217e9ac2709b6621`.


## Evidence and limits

- Initial `f68610b270` inventory: raw G1=25/G2=2/G3=51/G4=23; swept G1=7/G2=2/G3=46 plus 7 paired G4; excluded G1=18/G2=0/G3=5 plus 16 unpaired G4. Initial runtime was 34 hidden, 4 leaks, 2 not-an-element, 15 unreached; current bounded result is 38/2/15/0.
- Closing gates recorded FeatureTests 1039 passed plus 11 expected failures, zero failed/skipped/Repetition; iPhone UI 39 passed with 2 iPad-only skips; iPad UI 41 passed; lint covered 579 files with zero violations. The full FeatureTests bundle covered 15 historical references (13 existing, 1 moved, 1 merged) without another regression run.
- Voice Control spoken commands and VoiceOver double-tap activation were not measured; Voice Control evidence is native-label proxy evidence only. W-8, W-35, VO-3, W-13 Comments, and W-38 remain unresolved or carried to 16-26. W-33/W-34 await owner phonetic sign-off. L-6 was not independently run and reuses the dated L-5 sample only for date coverage.
- The current D-25 scope supersedes the historical Activity Logs/Laboratory candidates (reverted by `f68610b270`); Gallery Detail is withdrawn. The 45 → 65 Settings decision remains retained. No A11Y-02 requirement is completed here, and Phase 16 is not complete.

## Deviations from Plan

- VO-1 received an extended bounded walk to establish the approved traversal evidence.
- The unpinnable VO-2 regression was removed; E-1's standing audit regression provides the remaining guard.
- W-22 natural colour differences were retained under the approved acceptance.
- Closing gates/runtime and documentation were ordered around the immutable `310a39625f` source and existing evidence.
- Historical pending wording was retained while current Flow/Findings tables were closed semantically.
- Focus candidates were withdrawn or carried where their targets were not met; they were not presented as fixes.
- The complete FeatureTests bundle covered the historical regression references; no redundant second run was performed.

## Next Phase Readiness

16-26 owns the three-screen D-25 re-sweep, carried focus limits, and remaining owner judgments. No source or device work is pending from this documentation result.
