---
phase: 19-visual-regression-marketing-export
plan: "22"
subsystem: ui
tags: [toast, tab-bar-clearance, new-dawn, site-file-size, localized-number-format, hosted-tests]

requires:
  - phase: 19-21
    provides: "the hosted-test method (RED and GREEN on the phase simulators, the local single-scenario capture) used again here"
provides:
  - "C3: `toast(_:bottomClearance:onErrorTap:)` keeps the standard spacing above its host's bottom safe area; only the app root adds the tab bar's height, measured from the selected tab's own safe area; `ToastPlacementTests`"
  - "C5: New Dawn draws only the sun or moon body in light and dark, and its scroll view insets its content for the bottom safe area; `NewDawnLayoutTests`"
  - "C16: `SiteFileSize`, one type for every size the site gives as text (gallery strip, Gallery Info, torrents, archives); `SiteFileSizeTests`, `TorrentFileSizeTests`"
affects: [19-13, 19-26]

actuals:
  tokens: 11500
  tasks: 3
  commits: 3

plan_head_before: 2faff08d1372d5c0a192bc086129f72a5018c067
plan_head_after: 9693f7c95d8e3b02bd92d907376b142a021f543a

key-files:
  created:
    - AppPackage/Sources/DetailFeature/SiteFileSize.swift
    - AppPackage/Tests/HostedViewTests/ToastPlacementTests.swift
    - AppPackage/Tests/HostedViewTests/NewDawnLayoutTests.swift
    - AppPackage/Tests/HostedViewTests/TorrentFileSizeTests.swift
    - AppPackage/Tests/DetailFeatureTests/SiteFileSizeTests.swift
  modified:
    - AppPackage/Sources/SystemNotification/View+Toast.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/AppComponents/NewDawnView.swift
    - AppPackage/Sources/DetailFeature/GalleryDetail+FileSize.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/GalleryInfo/GalleryInfoView.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Tests/DetailFeatureTests/GalleryDetailFileSizeTests.swift
    - AppPackage/Tests/HostedViewTests/HostedView.swift
    - AppPackage/Tests/HostedViewTests/AccessibilityElements.swift
    - AppPackage/Tests/HostedViewTests/ReportFormCentredStateTests.swift
  deleted:
    - AppPackage/Sources/DetailFeature/GalleryDetail+Accessibility.swift

key-decisions:
  - "The tab bar's clearance is measured, not fixed: the selected tab's bottom safe-area inset less the tab view's own, each held as `@State`, with `tabBarClearance` computed from them (one source, no third stored copy)."
  - "At regular width (the iPad's top tab bar) the clearance is 0, and the tab-root test expects the plain-screen placement there."
  - "A size the site gives as text is parsed only from digits, an optional decimal part, one space and KiB, MiB or GiB; anything else is shown exactly as given."

requirements-completed: [VIS-18-01]
status: complete
---

# Phase 19 Plan 22: Toast offset, New Dawn, localized file sizes (C3, C5, C16) Summary

**The toast sits just above the home indicator on screens without a tab bar and just above the tab bar on the app root, New Dawn shows only the sun or moon with its reward line inside the bottom safe area, and torrent and archive sizes follow the reader's number format through the same type as the gallery's own size; each fix is one signed commit with a hosted test that failed before the fix and passes after it.**

All local runs of this plan (the RED and GREEN test runs and the picture checks) ran on the iOS 27.2 simulator runtime (owner decision 2026-11-24). Every measured value below is therefore an iOS 27.2 value. Strict SwiftLint ran from the standalone binary 0.65.1 (the SPM artifact the build plugin uses), from each module's own directory.

## Accomplishments

- **Task 1, C3** (`d2e05f8d0`): `View+Toast.swift` replaces the fixed 88 pt bottom padding with `.padding(.bottom)` and adds `bottomClearance: CGFloat = 0` (documented as the height of a bar over the host but outside its safe area), applied as extra bottom padding. `TabBarView` holds `selectedTabBottomInset` and `tabViewBottomInset` as `@State`, written by `.onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom }` on each tab's root (only while that tab is selected) and on `tabs`, and passes the computed `tabBarClearance` to the root `.toast`. No other call site changed. `ToastPlacementTests`: a plain screen at the scene's size, and the app root (branch by the window's horizontal size class, see Deviations).
- **Task 2, C5** (`c1f2dda56`): the dark-only block of eight beams is gone (light never drew beams), the disc is kept in both appearances, and the greeting's scroll view now ignores only the top safe area (`.ignoresSafeArea(edges: .top)`), with the comment above it rewritten. `NewDawnLayoutTests`: the dark sun has no yellow outside its disc, the reward line ends above the bottom safe-area edge at `.accessibility5`, and the greeting still does not scroll at `.large`.
- **Task 3, C16** (`9693f7c95`): `SiteFileSize` (`count`, `unit`, `init?(siteText:)`, `formattedCount(locale:)`, `formatted(locale:)`, `spokenUnit()`), `GalleryDetail.fileSize`, the Detail strip, Gallery Info, the torrent cell and the archive card moved onto it; `formattedSizeCount` and `accessibilitySizeUnit` are deleted (no wrapper) and `GalleryDetail+Accessibility.swift`, which held only the latter, is deleted. The torrent cell's accessibility label is the formatted count and the spoken unit.

## RED and GREEN evidence (iOS 27.2)

| Task | RED (before the fix) | GREEN (after) |
| --- | --- | --- |
| C3, iPhone Air | `Failed 6 2`: the plain screen's capsule is 88.0 pt above the safe-area edge (limit 20); on the app root the capsule is 39.0 pt above the tab bar's top (tab bar top 829.0), allowed 8...24 | `** TEST SUCCEEDED **`, `Passed 8 0` (`ToastPlacementTests` 2, `ReportFormCentredStateTests` 2, `SystemNotificationTests` 4) |
| C3, iPad Pro 11-inch | `Failed 6 2`: the plain screen's capsule is 88.0 pt above the edge; on the app root, under the top tab bar, also 88.0 pt above the edge (limit 20) | `** TEST SUCCEEDED **`, `Passed 8 0` |
| C5, iPhone Air | `Failed 3 2`: 56025 pixels of the sun's yellow lie outside the disc (dark); the reward line ends at 895.99, below the safe-area edge 878.0; the default-size case passed on the old code (a guard that the fix must keep) | `** TEST SUCCEEDED **`, `Passed 3 0` |
| C16, iPhone Air | `Failed 2 1`: the cell's label reads "26.2 MiB" (the labels include "Abgeschlossene Downloads: 1.280", so the de_DE environment was in force); the "not a site size is unchanged" case passed on the old code | `** TEST SUCCEEDED **`, `Passed 203 0` (all of `DetailFeatureTests`, which holds `SiteFileSizeTests` and the moved `GalleryDetailFileSizeTests`, and `TorrentFileSizeTests`) |

`SiteFileSizeTests` has no runtime RED: `SiteFileSize` did not exist, so the test could not compile before the fix, and the plan names only the hosted test as the one that must fail. The runs are in `$W` (`$ROOT/.capture/agent-work/phase19-22`, ignored): `c3-red`, `c3-red2`, `c3-green`, `c5-red`, `c5-green`, `c16-red`, `c16-green` (`.xcresult` and `.log` per device, the UDID in the name).

Acceptance: `grep -c 'padding(.bottom, 88)' View+Toast.swift` prints 0; `grep -c bottomClearance TabBarView.swift` prints 1; `grep -c beamContext NewDawnView.swift` prints 0; `grep -c 'ignoresSafeArea(edges: .vertical)' NewDawnView.swift` prints 0; the `formattedSizeCount`/`accessibilitySizeUnit` count over Sources and Tests is 0; `grep -c 'Text(torrent.fileSize)' TorrentsView.swift` prints 0; strict lint of `SystemNotification`, `AppFeature`, `AppComponents`, `DetailFeature`, `Tests/DetailFeatureTests` and `Tests/HostedViewTests` prints nothing. No `GeometryReader`, lifecycle modifier or SwiftLint suppression was added.

## Picture checks (iPhone Air, iOS 27.2; `page-height` errors are expected and allowed, the states still declare `.screen`)

- **C3, `SettingsSnapshotTests/testLoginError`, `en-large`** (`$W/c3-capture`): the run reports `error=4`, all four `page-height` (portrait needs 944 pt, committed 912; landscape needs 740, committed 420). In portrait the Error toast sits just above the bottom edge (about 16 pt above it), well below the circular sign-in button; nothing overlaps it. In landscape the toast sits below the button and its subtitle reads in full on one line ("The site refused the login without saying why."). **The one-line truncation remains in portrait:** the subtitle reads "The site refused the login without saying…", cut with an ellipsis at the end of the capsule's single line (the designed line budget at and below the default size, `ToastMessageView.subtitleLineLimit`; not changed here). **Question for the owner: does that truncation stay as it is, or is it a further fix?** The C3 verdict named only the offset.
- **C3, `AppWideSnapshotTests/testToastSuccess`, `en-large`** (same folder): the Success toast ("Copied to Clipboard") sits just above the floating tab bar on the Search tab, with a gap of the standard spacing, and clears it.
- **C5, `DetailPagesMoreSnapshotTests/testNewDawn`, `en-accessibility5`** (`$W/c5-capture`): `error=4`, all `page-height` (portrait needs 2148 pt, committed 912; landscape needs 1668, committed 420). The portrait light picture shows the teal-to-indigo gradient with only the yellow disc at the top right, no rays, and the title text over the gradient; the portrait dark picture shows the grey gradient with the same disc alone; the landscape dark picture shows the disc alone with the title's last word crossing its edge but no ray. The pictures are cut at the screen height, so the reward line's end is not in them (it is covered by `theRewardLineEndsAboveTheBottomSafeArea`; the full height is 19-26's).
- **C16, `DetailPagesMoreSnapshotTests/testTorrents` and `DetailPagesSnapshotTests/testArchives`, `de-large`** (`$W/c16-capture`): `error=4`, all `page-height` (landscape needs 656 pt, committed 420; the portrait pictures recorded). The Torrents page shows "26,2 MiB" and "51 MiB" (the site's "51.0" shows as 51, as the gallery's size does); the Archive page shows "12,4 MiB", "18,6 MiB", "26,2 MiB", "34,8 MiB", "51 MiB" and, for the unavailable original archive, "N/A" unchanged, with the price "Kostenlos" untouched.

## Notes for the owner's review in 19-13

- **C5, light:** the rays were drawn only in the dark appearance; light never drew beams, so the change is visible in dark only.
- **C5, default size:** the greeting is now centred between the top margin and the bottom safe area, so at the default size it sits half the bottom inset higher than before (17 pt on a 34 pt inset). At `.large` it still does not scroll (`theGreetingDoesNotScrollAtTheDefaultSize` passes before and after).
- **C5, accessibility5 on the iPhone Air, portrait:** the greeting fits without scrolling at the scene's size (the end of its scroll range is 21.7 pt before its top), and on the old code its reward line ended at 896 pt, inside the 34 pt bottom inset (safe-area edge 878). It is the position of the line, not scrolling, that the test pins.

## C16 sweep (plan step 5; both greps run over `AppPackage/Sources`)

| Hit | Shows | Decision |
| --- | --- | --- |
| `BlockedUsersView.swift:59` `Text(user.name)` | a user name | not a number; unchanged |
| `GalleryDetailCell.swift:299` `Text(gallery.formattedDateString)` | a date the app formats | already in the reader's format; unchanged |
| `TorrentsView.swift:90` `Text(torrent.fileName)` | a file name | a name; unchanged |
| `TorrentsView.swift:216` `Text(torrent.uploader)` | an uploader name | a name; unchanged |
| `TorrentsView.swift:217` `Text(torrent.formattedDateString)` | a date the app formats | already in the reader's format; unchanged |
| `DetailView+CommentCells.swift:95` `Text(comment.author)` | an author name | unchanged |
| `DetailView+CommentCells.swift:109` `Text(comment.formattedDateString)` | a date the app formats | unchanged |
| `DetailView+CommentCells.swift:111` `Text(comment.accessibilityAttributedDateString)` | a spoken date the app formats | unchanged |
| `CommentsView.swift:424` `Text(comment.author)` | an author name | unchanged |
| `CommentsView.swift:439` `Text(comment.formattedDateString)` | a date the app formats | unchanged |
| `CommentsView.swift:441` `Text(comment.accessibilityAttributedDateString)` | a spoken date the app formats | unchanged |
| `ArchivesView.swift:333` `Text(archive.price)` | an archive's price ("180", "Free", "N/A") | a price, not a decimal size; listed, not changed |
| `ArchivesView.swift:322` `Text(archive.fileSize)` (a hit of the first grep before the fix; the table lists the greps as run after it) | the archive's size as text | fixed: `SiteFileSize(siteText:)` with the environment locale, as given when it is not a site size |
| `TorrentsView.swift:158` `Text(torrent.fileSize)` (the plan's task target, likewise a hit before the fix) | the torrent's size as text | fixed, with the spoken label |
| second grep (`"…\(gallery.id)"` accessibility identifiers in `HomeFeature` and `GalleryListComponents`, and the URL path in `CommentReportTarget.swift:31`) | identifiers and a URL path, never shown text | not user-visible text; unchanged |

No other hit shows a site-given decimal number as raw text.

## Deviations from Plan (each approved by the orchestrator, or noted as a test detail)

1. **The iPad tab-root test branches on the window's horizontal size class** (approved, option A). On the iPad there is no `UITabBar` in the hosted hierarchy (the tab bar is the top bar), so the plan's "above the `UITabBar`'s top by 8...24 pt" cannot be written there; my first RED showed it failing for the wrong reason (no tab bar found) and I stopped. The test now branches on `root.traitCollection.horizontalSizeClass`: compact width requires a `UITabBar` and keeps the 8...24 pt; regular width (the iPad's top tab bar, clearance 0 as the C3 truth says) expects the plain-screen placement (at most 20 pt above the safe-area edge). It is not keyed on whether a `UITabBar` is found. The re-run RED failed the iPad tab-root case on the 88 pt offset.
2. **`tabBarClearance` is computed** (approved): two measured `@State` values and `tabBarClearance = max(0, selected - host)`, so there is one source and no third stored copy.
3. **Shared hosted-test helpers** (approved): `AccessibilityElements.identifier(of:)` and `HostedView.sceneSize()` (reusing `foregroundScene()`) were added to the two support files, and `ReportFormCentredStateTests` was switched to the shared identifier read and its private copy deleted. Two support files and one 19-21 test file beyond the plan's `files_modified`, in the Task 1 commit; `ReportFormCentredStateTests` passes on both devices in the Task 1 GREEN.
4. **The torrent test checks the accessibility label** (approved): the label contains "26,2" and no label contains "26.2". The visible string is proven by `SiteFileSizeTests` in `de_DE` and by the de-large picture check above.
5. **Test details of C5, not plan deviations:** my first draft of the reward-line test also required that the greeting scrolls at `.accessibility5` on the scene; it does not (see the notes), so that premise was dropped and the test scrolls to the end of the scroll range, which is the rest position when the greeting fits (`max(end of range, -top inset)`). The first draft's RED is kept as `first-draft-c5-red`. The sun test has a premise check that the page shows a sun at all.
6. **Test hosts at file scope** (lint): the toast test's host reducer and view are file-private types after the test struct, because the `nesting` rule warns at depth 2 and the build plugin fails strict.
7. **`GalleryDetail+Accessibility.swift` is deleted**, not left empty: its only member moved to `SiteFileSize.spokenUnit()`.
8. **The archive card shows the formatted size only**; the plan asked for the spoken label on the torrent cell, and the archive card's combined element is unchanged.
9. **Process notes:** three runs were lost to compile errors in my new tests (a missing `import AppModels`, a message built with `+`, a line over 120 characters in the build plugin's lint); they are kept as `compile-error-*` and are not counted. Several runs started late because other projects' `xcodebuild` runs on the host held the one-at-a-time wait for up to an hour.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. T-19-49 (a toast hidden under a bar) is mitigated by the hosted tests on the iPhone and the iPad for a plain screen and the tab root; T-19-50 (a misparsed site size) by the strict pattern, with `SiteFileSizeTests` covering "N/A", "312 MB", "", "26,2 MiB", a missing or extra space, two decimal points and non-Latin digits, which all give `nil` and so are shown as given.

## Self-Check: PASSED

Commits `d2e05f8d0`, `c1f2dda56` and `9693f7c95` are in the branch history (signed, +08:00 dates); the five created files and the deletion named in `key-files` are in the tree.
