---
phase: 261121-neo-design-v1-1-0-on-develop-history-grid-no
plan: 01
subsystem: ui
tags: [swiftui, history-grid, detail-header, download-ring, accessibility, localization]
requires: []
provides:
  - History grid notice set off by the grid's row gap above and below it
  - Full-button download ring with a 12-dash waiting track and saved-pages arc
  - Download and heart glyphs drawn at 1.1x and 1.15x of the scaled .callout size
  - accessibility.queued_progress in six locales
affects: [GalleryListComponents, DetailFeature, AppToolsTests, HostedViewTests]
tech-stack:
  added: []
  patterns: [one-view cross-fade between a dashed and a solid track, Shape that divides the given circle into dashes]
key-files:
  created:
    - AppPackage/Tests/HostedViewTests/HeaderSectionDownloadLabelTests.swift
  modified:
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings
    - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
key-decisions:
  - "Queued, downloading and paused are one button view; the dashed track cross-fades into the solid one over 0.3 s, at once under Reduce Motion (documented exception to D-29)."
  - "The queued VoiceOver label reads 'Queued. Pause download' or 'Queued, n of m. Pause download'."
patterns-established:
  - "DownloadRingDashes: a Shape of twelve butt-capped dashes on the inscribed circle, instead of a point-based dash pattern."
requirements-completed: [QUICK-261121-neo]
status: complete
actuals:
  tokens: 60000
  tasks: 3
  commits: 3
plan_head_before: 7dabc282b
plan_head_after: bd8c5d059a
---

# Phase 261121-neo Plan 01: v1.1.0 design on develop Summary

History grid notice spacing, the full-button detail download ring with glyphs of one size, and the queued download on the same ring with a dashed waiting track and a queued VoiceOver label, as three signed commits on `design/v110-develop`.

## Commits

| Task | Hash | Message | `%G? %aI %cI` |
| ---- | ---- | ------- | ------------- |
| 1 | 2a8acb6ae | Give the History grid notice its own space | `G 2026-11-21T16:13:45+08:00 2026-11-21T16:13:45+08:00` |
| 2 | 29229280d | Match the detail header glyphs and ring | `G 2026-11-21T16:43:29+08:00 2026-11-21T16:43:29+08:00` |
| 3 | bd8c5d059 | Show queued downloads on the progress ring | `G 2026-11-21T16:49:41+08:00 2026-11-21T16:49:41+08:00` |

`git rev-list --count 7dabc282b..HEAD` is 3.

## Baselines

- Baseline build at 7dabc282b: BUILD SUCCEEDED, 0 warnings and 0 errors (`warnings-baseline.txt` empty).
- Baseline lint (GalleryListComponents, DetailFeature, AppToolsTests, HostedViewTests sources): empty.

## Gates

- BUILD tasks 1, 2, 3: BUILD SUCCEEDED, no warning or error the baseline did not have.
- LINT tasks 1, 2, 3: empty (task 3 over DetailFeature, AppToolsTests and HostedViewTests).
- Task 1 gates: `rowSpacing` constant 1, `VStack(spacing: Self.rowSpacing)` 1, `Self.rowSpacing` 3, `.padding(.top, Self.rowSpacing)` 1, `private var grid: some View` 1, `spacing: 16` 0; the padding follows the reporter; no hunk above line 328; file length within 1000.
- Task 2 gates: `isDeterminate` 0, inset 4 and line width 2.5 as scaled metrics, `downloadIconScale` 1.1 and `heartIconScale` 1.15, `.font(downloadIconFont)` 1, `.font(heartIconFont)` 2, `.font(actionIconFont)` 2, `downloadProgressRing(` 1, centred padding 1, `.allowsHitTesting(false)` 1, `queuedSpinner` 1, `ProgressView()` 1, `progressCenterSymbolSize` 2; file at most 1000 lines.
- Task 3 gates: `ProgressView()`, `progressCenterSymbolSize`, `relativeTo: .caption2`, `queuedDownloadProgress`, `activeDownloadProgress`, `queuedSpinner` and `case .inactive: return .playFill` all 0; the `.inactive ? .playFill : .pauseFill` expression 1; `if let ring = downloadRing` 1; `Button(action: downloadAction)` 2; `DownloadRingDashes` struct 1 and use 1; `addRelativeArc(` 1; `lineCap: .butt` 1; the gated animation 1; `.accessibilityQueuedProgress(` 1; both new previews 1; header file 594 lines.
- Catalog: `git diff --numstat` is 221 added and 0 removed; the JSON reload check prints `ok`; the file still ends without a trailing newline.

## Observed Reduce Motion counts

Executable lines in the header file: `reduceMotion ?` 1, `reduceMotion` 4. Tree-wide: `reduceMotion ?` 37, `reduceMotion` 81. All four match the plan (1, 37, 4, 81); no difference to report.

## Tests

- Task 2 run (HostedViewTests only): TEST SUCCEEDED, 11 passed, 0 failed (HeaderSectionActionSpacingTests passed unchanged).
- Task 3 run (FeatureTests plan minus VisualSnapshotTests): TEST SUCCEEDED, 1913 passed, 0 failed, 0 skipped, 9 expected failures (1922 total); no FavoritesFeatureTests flake, so no re-run.
- Test cases per bundle: AnalyticsClientTests 118, AppFeatureTests 212, AppModelsTests 130, AppToolsTests 15, CookieClientTests 20, DetailFeatureTests 197, DownloadsFeatureTests 532, FavoritesFeatureTests 19, FileClientTests 8, GalleryListComponentsTests 13, HomeFeatureTests 81, HostedViewTests 14 (the three new label tests included), ImageClientTests 9, ImageColorsTests 4, LiveCheckTests 11, LiveTextTranslationTests 77, MarkdownExtTests 11, NetworkingFeatureTests 117, ParserFeatureTests 92, ReadingFeatureTests 122, SearchFeatureTests 18, SettingFeatureTests 86, SystemNotificationTests 4, TagTranslationFeatureTests 12. The expected failures are in DownloadsFeatureTests, SettingFeatureTests and AnalyticsClientTests.

## Snapshot scenarios needing re-recording by the owner

The snapshot harness was not run: the tree has no approved baseline (`AppPackage/Tests/VisualSnapshotTests/Baseline` is absent) and the harness writes Reduce Motion and accessibility defaults into the simulator.

- `history-grid`: the notice spacing.
- Every detail scenario, for the larger download and heart glyphs: `gallery-detail-loaded`, `gallery-detail-loading`, `gallery-detail-error`, `gallery-detail-rating`, `gallery-detail-downloading`, `gallery-detail-delete-download-confirmation`, `gallery-detail-retry-confirmation`, `gallery-detail-sheet`.
- `gallery-detail-downloading` also for the ring geometry.
- No scenario renders a queued download.

## Deviations from Plan

None - plan executed as written. Comment prose of the ring's doc comment and the heart and download font comment was wrapped to stay within 120 columns, as the plan allows. The first lint run of task 3 reported one 122-column doc-comment line, which was re-wrapped before the build and the commit.

Process notes (not plan deviations): the baseline build was started and, while it was still fetching packages, the first Task 1 edit was made; the edit was reverted with `git checkout -- <file>` before the build reached any compile step of the module, and restored from a scratch copy after the baseline finished. Test runs waited for another session's `xcodebuild` runs on the machine to end, as the plan requires.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- Commits 2a8acb6ae, 29229280d and bd8c5d059 are ancestors of HEAD.
- `AppPackage/Tests/HostedViewTests/HeaderSectionDownloadLabelTests.swift` exists and is part of commit bd8c5d059.
