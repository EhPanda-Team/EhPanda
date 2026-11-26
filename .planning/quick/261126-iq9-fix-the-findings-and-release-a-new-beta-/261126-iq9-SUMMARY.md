---
phase: 261126-iq9-fix-the-findings-and-release-a-new-beta-
plan: 01
subsystem: reader, toast, settings
tags: [webtoon, schema-migration, toast, safe-area, external-link-arrow]
requires: []
provides:
  - Webtoon verdict from the gallery's middle three pages, fetched at open, old negatives re-checked (W-1 to W-4)
  - Toast on the host's bottom safe-area edge, clearance from each host's own layout (T-1)
  - One shared external-link arrow for About and General (A-1)
affects: [ReadingFeature, AppModels, SystemNotification, AppFeature, SettingFeature, DetailFeature, AppComponents]
key-files:
  created:
    - AppPackage/Tests/HostedViewTests/ToastPlacementTests.swift
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Webtoon.swift
    - AppPackage/Sources/AppModels/Persistent/GalleryHistoryEntry.swift
    - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
    - AppPackage/Sources/SystemNotification/View+Toast.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/SettingFeature/Login/LoginView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/AppComponents/ViewModifiers.swift
    - AppPackage/Sources/SettingFeature/Components/AboutView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Tests/ReadingFeatureTests/WebtoonReadingTests.swift
    - AppPackage/Tests/AppModelsTests/SchemaMigrationTests.swift
    - AppPackage/Tests/AppModelsTests/StrictDecodingTests.swift
    - AppPackage/Tests/AppModelsTests/GalleryHistoryOperationsTests.swift
decisions:
  - "GalleryHistoryEntry adopts MigratableModel with a SchemaV2 that drops a v1 isWebtoon false (W-4)"
  - "The toast has no fixed bottom constant; hosts outside the safe area pass bottomInset (T-1)"
  - "The tab-bar root's toast moved into each tab's content (T-1)"
status: complete
commits: 3
plan_head_before: 345a454bc34817e281200a35cc4ffc20b289dfa2
plan_head_after: ba7f0e1fa63521bb9916f493976da520699266cc
actuals:
  tokens: 13300
  tasks: 3
  commits: 3
---

# Phase 261126-iq9 Plan 01: Fix the findings Summary

Webtoon detection now samples the gallery's middle three pages and asks for them at open, the toast stands on its host's safe-area edge with a small gap instead of a fixed 88 pt, and About's link rows end with the external-link arrow through one shared helper.

## Commits (three signed, +08:00, nothing pushed)

| Task | Hash | Subject |
|------|------|---------|
| 1 | 0e21abbd1 | reader: detect webtoons from the middle pages |
| 2 | cf8e0995c | toast: clear the host's bottom chrome once |
| 3 | ba7f0e1fa | settings: mark About links as external |

Each shows `G` in `git log --format=%G?` with author and committer dates at +08:00. The plan's base was HEAD `345a454bc` (the orchestrator's plan commit on top of `e9f5b11f8`).

## Test runs

xcodebuild in this environment (Xcode 27.2) does not print any `Test run with N tests` line, so that part of the plan's grep gate printed nothing on every run. Every run printed `** TEST SUCCEEDED **`, and the per-case `Test case '...' passed` lines in the logs (under `.capture/261126-iq9/`) were used as the evidence instead.

| Run | Targets | Result |
|-----|---------|--------|
| Task 1 first run | ReadingFeatureTests, AppModelsTests, AppFeatureTests | FAILED: my new open-time test omitted the `fetchThumbnailURLs` receive that marks the batch loading; fixed in the test |
| Task 1 | same | TEST SUCCEEDED, no warnings, all new Webtoon, SchemaMigration, StrictDecoding and GalleryHistory cases listed as passed |
| Task 2 RED | HostedViewTests/ToastPlacementTests | compile error `extra argument 'bottomInset'` against the old modifier (expected RED) |
| Task 2 | HostedViewTests, SystemNotificationTests, AppToolsTests | TEST SUCCEEDED, no warnings; both ToastPlacementTests and the five ReduceMotionGatingSourceTests pass |
| Task 3 | AppToolsTests, SettingFeatureTests | TEST SUCCEEDED, no warnings |
| Final | FeatureTests plan, `-skip-testing:VisualSnapshotTests` | TEST SUCCEEDED, 3645 `passed` case lines, 0 `failed`, no warnings (the known FavoritesFeatureTests flake did not occur) |

Lint (`swiftlint lint --strict --quiet`) is clean on each task's trees and, at the end, on `App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension`. All `[HEAD=.. EXPECT=..]` gates printed their EXPECT values (Task 1: 0, 0, 2, 1, 1; Task 2: 0, 1, 1, and 15 screenshots; Task 3: 1, 1, 1).

## What changed

- **W-1/W-2/W-3:** `webtoonSamplePages(pageCount:)` returns `(m-1)...(m+1)` with `m = (pageCount + 1) / 2`; `webtoonReducer` decides after every action and, on `.onPresented` with the option on, no verdict and an online reader, sends `.fetchImageURLs` for each middle page whose size is unknown. A failed batch records nothing and sends nothing further.
- **W-4:** `GalleryHistoryEntry` is a `MigratableModel` with `SchemaV2` (drops `isWebtoon: false`), `init(from:)` through `SchemaMigrator`, identity guards in `init(currentFrom:)`, `schemaVersion` default 2. A stored v1 array read through `@Shared(.galleryHistory)` loses only its negatives, and the next write stores every element at v2 (test through the real app-storage key).
- **T-1:** `toast(_:bottomInset:onErrorTap:)`; `.padding(.bottom)` replaces the constant 88; TabBarView's toast moved into each tab's content; LoginView's toast moved after `.ignoresSafeArea`; the reader passes `store.showsPanel ? lowerPanelHeight : 0`; Archives passes its measured pinned footer height (0 at accessibility sizes).
- **A-1:** `withExternalLinkArrow()` in AppComponents; About's `LinkRow` and General's privacy row use it.

## Visual check (T-1, A-1)

Two simulators of this task's own were created and deleted afterwards: iPhone Air `5A38885C-4EE6-4FC1-BC13-C13AB9CB8E15` and iPad Pro 11-inch (M5) `BBF726E6-00DD-4C49-9479-7077E0FA23AD` (both iOS 27.2). `xcrun simctl list devices | grep EhPanda` now lists only the two phase19 simulators, the iPhone Shutdown and the iPad Booted, as before. The app was driven with `device-mcp-cli` (the Device MCP command line), screenshots taken with `xcrun simctl io`. Frames come from the element list where it gave them, otherwise from the PNG (iPhone 3 px per pt, iPad 2 px per pt, pixel scans or visual reading).

| File (under `.capture/261126-iq9/evidence/`, kept out of git like every capture) | Host | Launch | Measured gap (pt) | Pass |
|---|---|---|---|---|
| iphone-root-deeplink-error.png | tab-bar root (deep-link error) | A, Home | toast bottom 813, tab bar top about 830: 17 | yes |
| iphone-root-deeplink-error-search-tab.png | tab-bar root, after Search tab | A | one `toast_message`, same frame 756..813: 17 | yes |
| iphone-tab-galleryinfo-copied.png | Gallery Info pushed in a tab (Detail stand-in) | A | about 16 above tab bar | yes |
| iphone-sheet-galleryinfo-copied.png | Gallery Info in the gallery sheet | A | bottom 49 pt above screen bottom (window 40..60) | yes |
| iphone-reader-panel-hidden.png | reader, panel hidden | A, gid 3103480 | 49 above screen bottom | yes |
| iphone-reader-panel-shown.png | reader, panel shown | A | toast bottom 742, lower panel top 758: 16 | yes |
| iphone-archives-pinned.png | Archives sheet, pinned footer | B | toast bottom 721, footer top about 740: about 19 | yes |
| iphone-archives-ax.png | Archives sheet, scrolling arrangement (AX M) | B, `UICTContentSizeCategoryAccessibilityM` | 49 above screen bottom (see note) | yes, with the note below |
| iphone-account-copied.png | Account (Setting tab) | B | about 16 above tab bar | yes |
| iphone-login-error.png | Login (pushed) | A | toast 756..813, tab bar top about 830: 17 | yes |
| ipad-root-deeplink-error.png | tab-bar root (top tab bar) | A | toast bottom 1174, screen 1210: 36 (window 28..48) | yes |
| ipad-tab-galleryinfo-copied.png | Gallery Info in the gallery form sheet | A | about 15 above the sheet bottom (window 8..28) | yes |
| ipad-setting-sheet-account-copied.png | Account in the Setting sheet | B | about 15 above the sheet bottom | yes |
| ipad-reader-panel-hidden.png | reader, panel hidden | A | bottom 1174: 36 above screen bottom | yes |
| ipad-reader-panel-shown.png | reader, panel shown | A | toast bottom 1054, lower panel top 1070: 16 | yes |
| iphone-about-links.png | About | A (Task 3) | every link row ends with the up-right arrow, no chevron | yes |
| iphone-general-privacy.png | General | A (Task 3) | Privacy Policy row shows the same arrow, as before | yes |

Notes for the orchestrator on the visual check:

- On iPad a gallery opened from Home is always presented as a form sheet, so the "tab" Gallery Info check on iPad is the form-sheet case (file name kept as the plan gave it).
- In the Archives scrolling arrangement (iphone-archives-ax.png) I scrolled the page to its end to reach the Download button, so the toast lands over that button's lower part. That is the designed placement for a scrolling page (the toast stands on the sheet's bottom edge over scrolled content), but it is literally a toast overlapping a control. Flagging it against the plan's "overlaps no control" clause.
- Opening the Home-card gallery (gid 2668617) in the reader left every page on its failure placeholder, because the stub's multi-page viewer fixture is for gid 3103480; the reader and Archives checks therefore opened gid 3103480 through the deep link, as the sheet check does.
- Hosts covered by placement class only (no stub trigger): Torrents, the download inspector, Downloads, My Tags, Comments and the gallery lists (FrontPage, Popular, Toplists, Watched, History, Favorites, Search, DetailSearch). They keep their unchanged attachment.

## Deviations from Plan

None to the code or the commits. Process notes:

1. **[Process] A xcodebuild was already running (another process, pid printed by `pgrep`) when I started the Task 2 RED run.** I ran the RED compile anyway because the gate command ran in one line without a stop; nothing was killed and the run only produced the expected compile error. Every later invocation waited for `pgrep -x xcodebuild; pgrep -x xctest` to be empty.
2. **[Process] Task 2 RED ordering.** I had already edited `View+Toast.swift` before writing the RED run, so I temporarily restored the HEAD version of that one file from `git show HEAD:...`, ran the new test (compile error `extra argument 'bottomInset'`), and restored my edit byte for byte. No stash was used.
3. **[Process] The `Test run with N tests` lines never print** with this Xcode (see Test runs).
4. `Text(.RLocalizable.consentPrivacyLink).withExternalLinkArrow()` in `GeneralSettingView.swift` is split over two lines (`Text(...)` then `.withExternalLinkArrow()`), same expression.

## Items for the orchestrator (from the plan's output spec)

- **Engine cost (settled fact 4):** `SchemaMigrator.migrate` round-trips every element through `JSONValue` even at the current version: about 12 ms for 1,000 history entries against about 1.3 ms direct (optimized build). Not changed.
- **Gallery Info stand-in for Detail (fact 7):** Detail's own toasts come only from My Tags (needs a real account), so Gallery Info, pushed on the same stack under the same tab bar with the same attachment, stood in.
- **Option turned on mid-session:** it does not ask for the middle pages (W-2 scopes the fetch to the gallery's open); the verdict still lands the moment the known sizes allow one.
- **CONTEXT's host list named eight of the thirteen `.toast(` hosts;** all thirteen are covered by Task 2's table.
- Reversibility (W-4): a build from before the first commit rejects a v2 history and resets it, the same property `Setting`'s v2 already has.

## Follow-up fix (2026-11-26, after beta 165)

The owner reported that on build 165, gallery 4354007 (26 pages, opened online) still switched only on reaching
page 12. Cause: with a multi-page viewer, the open-time request for the middle pages fell into the opening page's
batch, already loading, and was dropped; that batch fetches only the viewer's list, which then resolves pages 1 to 3
and the shown page. `webtoonReducer` now also asks for the middle pages when a viewer's list arrives with its keys
(`fetchMPVKeysDone` success with `mpvKey` set), page by page; a list that sizes them asks for nothing, and a refused
list leaves no key and asks for nothing (W-3). Three cases in `WebtoonReadingTests` cover it (the first failed before
the fix); ReadingFeatureTests passed (341 cases), lint strict clean. Not verified on a device: the viewer needs the
owner's account.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or file access; the open-time fetch uses the existing page-address request (T-261126-iq9-01 accepted in the plan).

## Self-Check: PASSED

- Commits `0e21abbd1`, `cf8e0995c`, `ba7f0e1fa` are ancestors of HEAD and `git rev-list --count 345a454bc..HEAD` is 3.
- `AppPackage/Tests/HostedViewTests/ToastPlacementTests.swift` exists; the 17 evidence PNGs exist under `.capture/261126-iq9/evidence/` (gitignored).
- `git status --short` showed only the untracked `evidence/` folder, since moved to `.capture/261126-iq9/evidence/` (plan artifacts are the orchestrator's to commit).
