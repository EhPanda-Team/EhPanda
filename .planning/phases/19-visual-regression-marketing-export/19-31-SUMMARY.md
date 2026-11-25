---
phase: 19-visual-regression-marketing-export
plan: "31"
subsystem: ui
tags: [home-front-page, page-count, dynamic-type, layout, hosted-tests]

requires:
  - phase: 19-24
    provides: "the 8-gallery Front Page fixture that exposed the broken page count, and the hosted-test method (a Home view at a Dynamic Type size and locale)"
provides:
  - "A Front Page cell with rich information is as wide as the widest of its cover and the one-line widths of its page count and language, never narrower than the cover; `HomePageLanguage` aligns its lines leading so a `Button` cannot centre them; `FrontPageCellPageCountTests` (every locale, size class and Dynamic Type size)"
affects: [19-25, 19-26]

actuals:
  tokens: 10800
  tasks: 3
  commits: 3

plan_head_before: 2e42d7ededfada63ab88e90d2080925c817fedb9
plan_head_after: 94f5d3b8deb5897e17e40e4592ee126213e3231e

key-files:
  created:
    - .planning/phases/19-visual-regression-marketing-export/19-31-INVESTIGATION.md
    - AppPackage/Tests/HostedViewTests/FrontPageCellPageCountTests.swift
  modified:
    - AppPackage/Sources/HomeFeature/HomeGalleryInformation.swift

key-decisions:
  - "The cell's width is decided by a private `HomeFrontPageCellLayout` in `HomeGalleryInformation.swift` (cover, title, fields as its three subviews), because a `VStack` cannot give the cover a width of its own while the cell takes the width its fields need. It asks the fields for the width they need at the cover's width, which they answer when `HomePageLanguage` keeps its fields whole (`keepsFieldsWhole`, off by default so the ranking cell's use is unchanged)."
  - "The page count and the language are never truncated, scaled or given a fixed size, and no catalog string changed (the owner chose a wider column over a broken field)."

requirements-completed: [VIS-18-01]
status: complete
---

# Phase 19 Plan 31: The Front Page cell's page count Summary

**A Front Page cell keeps its page count and its language whole and on its leading edge at every Dynamic Type size: the cell is as wide as the widest of its cover and its fields (never narrower than the cover), the cover keeps its size, and the wall's columns follow; a hosted test over 144 locale, size class and size cases failed before and passes after.**

All local runs ran on the iOS 27.2 simulator runtime (owner decision 2026-11-24); every measured value is an iOS 27.2 value. Evidence is in `$W` (`$ROOT/.capture/agent-work/phase19-31`, ignored).

## Accomplishments

- **Task 1, the investigation** (`f2d32f440`, `19-31-INVESTIGATION.md`): two causes with measured numbers. The page count's one-line width exceeded the cell's fixed cover width (176.5 pt against 176.0 pt for `de` "26 Seiten" on the iPad at `.accessibility5`, and by up to 31.7 pt in the compact cell at `.accessibility4` and `.accessibility5`), so the `Text` wrapped; and a `Button` style centres its label's lines, so the `.multilineTextAlignment(.leading)` set on the `Button` never reached the page count and the wrapped "26" sat 34 pt in from the cell's edge.
- **Task 2, the decision**: the owner chose option A, the wider column. The orchestrator asked the owner in Taiwanese Mandarin and recorded the decision under "## Decision" of the investigation (commit `0c866ded3`, made by the orchestrator, not by me). The owner's answer, verbatim: 「欄寬隨文字加寬（建議）」. The orchestrator also spelled out the exact fix and test within that answer.
- **Task 3, the fix** (`94f5d3b8d`): in `HomeGalleryInformation.swift`
  - `HomePageLanguage` sets `.multilineTextAlignment(.leading)` on itself, and has a `keepsFieldsWhole` flag (default `false`) that gives its two `Text`s `fixedSize(horizontal: true, vertical: true)`;
  - a rich `HomeFrontPageCell` is laid out by the private `HomeFrontPageCellLayout`: the cover at its own size on the leading edge, the title at the column's width, the fields (`keepsFieldsWhole: true`); the column is `max(cover width, fields' needed width)`, the fields' needed width asked at the cover's width; the cell without rich information (`.standard` cover) keeps its `VStack` and `.frame(width: coverSize.width, alignment: .leading)`;
  - a doc comment states the reason (the cover's scale stops at `GalleryCoverStyle.maximumScale` while the text keeps growing; the owner chose a wider column over a broken field, 19-31, 2026-11-25).
  - Where the fields fit the cover, which is every size up to `.accessibility3`, the column is the cover's width as before.

- **Review cleanup** (`d78bbf204`, `refactor(19-31): drop the lone cover stack`): the cell without rich information is `cover.frame(width: coverSize.width, alignment: .leading)`, no one-child `VStack` around the cover; nothing else changed. The iPhone half of the verify block ran again: `** TEST SUCCEEDED **`, `Passed 387 246 0 141`; strict lint of `Sources/HomeFeature` prints nothing.

## RED and GREEN evidence (iOS 27.2)

`FrontPageCellPageCountTests` is one parameterised test with 144 cases (six locales, `.regular` and `.compact`, the twelve Dynamic Type sizes). Each case hosts the real wall (two galleries a column for the counts 24 to 29, the lower one with the language "Deutsch" in that locale) and checks every cell: its width is the widest of the cover and its fields' one-line widths (probed) and no wider than a pixel's rounding, its height is the cover, the two reserved title lines and the expected field lines, the field lines are exactly one text line each in the cell's bottom band and start within a glyph's side bearing of the cell's leading edge and do not end past its trailing edge, no ink comes within the 20 pt column spacing of the next column, and the cover's drawn size equals the cover style's size at that Dynamic Type size to a pixel and starts on the cell's leading edge.

| Step | iPad (2x) | iPhone (3x) |
| --- | --- | --- |
| RED, before any change (`red-final-pad`, `red-final-phone`) | `TEST FAILED`, 9 of 144 cases fail: compact `.accessibility4` (`en`, `de`, `ja`), compact `.accessibility5` (`en`, `de`, `ja`, `ko`), regular `.accessibility5` (`de`, `ja`); 98 width, 98 height, 58 leading-edge, 6 line-count expectations failed | `TEST FAILED`, 8 of 144: the same except regular `.accessibility5` fails for `ja` only (`de` fits the 176.333 pt cell exactly at 3x); 90 width, 90 height, 54 leading-edge, 6 line-count expectations |
| Change 1 alone, in the working tree (`c1-pad`, `c1-phone`) | the same 9 cases still fail: the 58 leading-edge expectations are gone, the 98 width, 98 height and 6 line-count expectations remain | the same 8 cases still fail: 54 leading-edge gone, 90 width, 90 height and 6 line-count remain |
| GREEN, with the fix (`green-pad`) | `TEST SUCCEEDED`, 144 of 144 pass | covered by the verify run below |

The plan's verify block ran on both phone and pad (`fix-<udid>.xcresult`, `-only-testing:` `FrontPageCellPageCountTests`, `SlideshowInformationLayoutTests`, `VisualSnapshotTests`, `HomeFeatureTests`): iPhone `** TEST SUCCEEDED **`, `Passed 387 246 0 141` (total, passed, failed, skipped), iPad `** TEST SUCCEEDED **`, `Passed 387 246 0 141`. Strict SwiftLint of `AppPackage/Sources/HomeFeature` and `AppPackage/Tests/HostedViewTests` prints nothing.

Three RED runs were corrections of the test itself before the final one, not of the plan: a `@Test` takes at most two argument collections (the size class and size are one argument now); the first leading-edge tolerance of 4 pt failed a kana's own side bearing (up to about a quarter of the line, 9.5 pt at `.accessibility4`), so the tolerance is `max(4, 0.3 * line height)`; and a band one line tall could not see a wrapped second line, so the expected cell height decides that.

## Picture checks (by eye with the Read tool)

`HomeSnapshotTests/testHomePopulated`, candidate mode, `$W/capture-pad` and `$W/capture-phone`. The runs report `error` for the expected `page-height` coordinates only (the 912 pt iPhone and 1210 pt iPad committed heights against the page's: the iPad needs 1858 pt at `en-large` and 4605 pt at `de-accessibility5`, 4707 pt before the fix in 19-24, 102 pt less as the two wrapped lines are gone; the iPhone 1755 pt at `en-large` and 4094 to 4271 pt at `accessibility5` (`de`, `ja`) in portrait, 1725 pt and 4142 to 4352 pt in landscape; the full height is 19-26's). Every picture is recorded.

- **iPad, `de-accessibility5`, portrait** (`$W/capture-pad/actual/ipad/de/accessibility5/home-populated/portrait-light.png`): the Front Page's second column shows "26 Seiten" on one line on the cell's leading edge, beside "24 Seiten" and "28 Seiten"; the fourth column starts 1 pt further right as the second column is 0.5 pt wider.
- **iPad, `en-large`, portrait** (`$W/capture-pad/actual/ipad/en/large/home-populated/portrait-light.png`): unchanged: 4 columns of two rows, titles on two lines, "24 pages", "26 pages" and the rest on one line each.
- **iPhone, `de-accessibility5`, `ja-accessibility5` and `en-large`, portrait** (`$W/capture-phone/actual/iphone/de/accessibility5/home-populated/portrait-light.png`, `.../ja/accessibility5/...`, `.../en/large/...`): the committed 912 pt cuts the page above the Front Page's text at `accessibility5` (the covers of the Front Page begin at the bottom edge), so the page count is not in those two pictures; the Start card is as in 19-24. The `en-large` picture shows the Front Page: three columns, "24 pages", "26 pages", "28 pages" and "25 pages", "27 pages", "29 pages" on one line each, unchanged.
- **The iPhone's Front Page at `accessibility5`**, which the capture cannot show, was read from the real wall hosted in the test target (the diagnostic test of the investigation, put back in the working tree for this one run and deleted again; renders `$W/wall-fix-phone/wall-compact-AX5-ja.png` and `.../wall-compact-AX5-de.png`): every "24 ページ" to "29 ページ" and "24 Seiten" to "29 Seiten" is one line on the cell's leading edge, the lower row's "ドイツ語" and "Deutsch" are one line each under it, the covers are the same size as before and sit on the leading edge, and the columns are wider than the covers (176 to 178 pt for `ja` and `de` against the 146 pt cover; each column 20 pt from the next).

## Deviations from Plan

None. The plan's file list names `HomeGalleryInformation.swift` and the new test only, and those are the only two files the fix commit touches; the private layout lives in `HomeGalleryInformation.swift`, as `HomeEqualColumnsLayout` does.

## Out of scope, noted

- `HomePageLanguage` is also used by `GalleryRankingCell.swift` (line 85). Its default `keepsFieldsWhole = false` leaves its text wrapping as before; only the leading alignment of a wrapped line changes there, and nothing was measured on the ranking row. If a Button there centres its page count the same way, the alignment now sets it right.
- The iPhone's committed 912 pt capture height does not reach the Front Page at `accessibility5`; that is 19-26's full-height work.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. T-19-67 (a visible design change made without the owner) is mitigated: the wider column was the owner's own choice, asked before it was built.

## Self-Check: PASSED

Commits `f2d32f440`, `0c866ded3` and `94f5d3b8d` are in the branch history, signed, with +08:00 dates. `19-31-INVESTIGATION.md` and `FrontPageCellPageCountTests.swift` exist; the fix commit deleted no file.
