# 19-31 Investigation: the Front Page cell's page count

Task 1 of `19-31-PLAN.md`. Investigation only: no source file was changed, and no fix is chosen here (Task 2 is the
decision). Owner decision 2026-11-25: 「先查原因再修（建議）」.

Evidence is in `W="$ROOT/.capture/agent-work/phase19-31"` (gitignored): `diag-pad2.txt` and `diag-phone.txt` (the AX5
measurements, with the real-wall renders `wall-*.png` for the iPad), `diag-pad2.sweep.txt` and `diag-phone.sweep.txt`
(every Dynamic Type size), and the diagnostic test as `FrontPageCellDiagnosticTests.swift.txt`. The diagnostic test was
a hosted test in the working tree only and is deleted (`git status --porcelain -- AppPackage` is empty).

## Method

A hosted test (`HostedViewTests`, run inside the app on the two phase simulators, both iOS 27.2, the iPad's scene
834 x 1210 pt) laid out, for the six locales and the page counts 24 to 29:

- the real chain of the picture: `ScrollView(.horizontal)` with a 20 pt content margin, `HomeFrontPageWall`
  (`HomeCoverWallLayout`, `Button`, `HomeFrontPageCell`), once with `horizontalSizeClass` `.regular` (the iPad's
  `.homeFrontPage` cover) and once with `.compact` (`.homeCompact`), top row without a language, bottom row with
  "Deutsch" (language `German`);
- `HomePageLanguage` alone, in the cell's own `VStack(alignment: .leading)` at the cell's width, to read each `Text`'s
  frame;
- each page count's and the language's one-line ideal width (`Text(...).font(.caption).fixedSize()`), and the height
  of one caption line;
- a picture of the wall, read for ink: the leading and trailing x of every text line of the page-count block, as
  offsets from the cell's leading edge (the ink includes about 2 pt of the glyph's own side bearing).

`AccessibilityElements.identifier(of:)` found the cells (`home_front_page_title_<gid>`) and `HostedView.sceneSize()`
gave the scene size. Three control rows (read on the iPad; on the iPhone the window's top safe area shifts their
read region, so only the iPad's are used) put `HomePageLanguage` in a `Button` as the app does, in the same `Button`
with `.multilineTextAlignment(.leading)` on the `Text`'s own side, and in a plain stack.

## Evidence

### The picture, reproduced

The iPad `de` `.accessibility5` wall reproduces `c9-capture-pad/actual/ipad/de/accessibility5/home-populated/portrait-light.png`
(19-24): the cells with 26 and 29 pages break after the number, the rest do not. The break and the centred "26" are
the same in the hosted wall.

iPad (2x), `.regular` style, `.accessibility5`, `de`. Cell width 176.0 pt. One caption line is 51.5 pt.

| count | "n Seiten" one-line ideal width | fits 176.0 pt | lines | leading x of the lines, from the cell's leading edge |
| --- | --- | --- | --- | --- |
| 24 | 175.0 | yes | 1 | 2.0 |
| 25 | 175.0 | yes | 1 | 2.0 |
| 26 | 176.5 | no, by 0.5 pt | 2 | "26" 34.0, "Seiten" 1.5 |
| 27 | 173.5 | yes | 1 | 2.0 |
| 28 | 176.0 | yes, exactly | 1 | 2.0 |
| 29 | 176.5 | no, by 0.5 pt | 2 | "29" 34.0, "Seiten" 1.5 |

The wrapped cells are 488 pt tall, the others 437 pt (51 pt more: one caption line). The `Text`'s own frame for
"26 Seiten" is 116.0 pt wide and 102.5 pt (two lines) tall, at the cell's leading edge; the ink of "26" is 46.5 pt wide
and starts 34.0 pt in, so the two lines are centred inside the 116 pt frame ((116 - 46.5) / 2 = 34.8).

### The three control rows (iPad, `de`, `.regular`, `.accessibility5`, count 26)

| row | leading x of "26" | leading x of "Seiten" |
| --- | --- | --- |
| `Button` as the app has it (`.multilineTextAlignment(.leading)` on the `Button`) | 34.0 | 2.0 |
| `Button`, `.multilineTextAlignment(.leading)` on `HomePageLanguage` inside the label | 2.0 | 2.0 |
| plain stack, no `Button` | 2.0 | 2.0 |

### Widths against the cell, every size

Cell width (pt) / widest page count's one-line width (pt) of the counts 24 to 29, per locale. `*n` marks n of the six
counts wider than the cell. `zh-Hans` and `zh-Hant` are equal. Only the sizes where something is wider, or the two
sizes next to them, are shown; the sweep files hold all twelve sizes and no other size has a page count wider than its
cell.

iPad simulator (2x display scale):

| style, size | en | de | ja | ko | zh |
| --- | --- | --- | --- | --- | --- |
| regular, `.accessibility4` | 176 / 150.0 | 176 / 152.5 | 176 / 153.0 | 176 / 141.0 | 176 / 87.5 |
| regular, `.accessibility5` | 176 / 173.5 | 176 / 176.5 `*2` | 176 / 178.0 `*5` | 176 / 163.5 | 176 / 101.5 |
| compact, `.accessibility3` | 146 / 130.5 | 146 / 132.5 | 146 / 132.5 | 146 / 122.0 | 146 / 76.0 |
| compact, `.accessibility4` | 146 / 150.0 `*6` | 146 / 152.5 `*6` | 146 / 153.0 `*6` | 146 / 141.0 | 146 / 87.5 |
| compact, `.accessibility5` | 146 / 173.5 `*6` | 146 / 176.5 `*6` | 146 / 178.0 `*6` | 146 / 163.5 `*6` | 146 / 101.5 |

iPhone simulator (3x display scale): the same, except that the regular cell is 176.333 pt, so at `.accessibility5`
`de` is 176.333 / 176.333 (fits, exactly) and `ja` is 176.333 / 177.667 `*3`; the compact rows are identical to the
iPad's within 0.4 pt. The widths and the cell widths are rounded to the device's pixels, so a tie such as "de" at
`.accessibility5` flips between devices.

Below the table's sizes nothing is wider: at every size up to `.accessibility3`, on both styles and both devices,
every page count fits its cell with at least 13 pt to spare in the narrowest case (compact `.accessibility3`, `ja`:
146 / 132.5).

The iPad's regular cell is 141 pt at `.xxLarge` and below and 176 pt from `.xxxLarge` up; the compact cell is
116.5 pt and 146 pt (iPhone simulator: 116.667 / 146 and 141 / 176.333). The cover's `ScaledMetric` clamps at 1.25 of
the base height (`GalleryCoverStyle.maximumScale`), so from `.accessibility1` up the cell stops growing while the text
keeps growing: the text overtakes the cell.

### How the lines break in the wrapped cases

- `de`, `en` (space between number and unit): the break falls at the space, "26" / "Seiten", the unit on the second
  line. The pair of lines in the compact cell (146 pt) is the same shape: `en` "24" starts at 33.5, "pages" at 2.5;
  `de` "24" at 35.0, "Seiten" at 1.5.
- `ja` ("24ページ", no space): the break falls inside the unit, not between number and unit. iPad regular
  `.accessibility5`, count 24: the first line's ink runs 2.0 to 132.5 pt, the second line's 52.5 to 87.5 pt (a 35 pt
  wide remainder, centred). The same on the compact cell. So for `ja` the break also splits the unit itself.
- `ko`: wraps in the compact cell only (163.5 against 146); first line 2.0 to 119.5, second 45.0 to 76.0, centred.
- `zh-Hans`, `zh-Hant`: never wrap (101.5 against the narrowest cell, 146).

## Cause

Two causes, independent of each other.

### Cause 1: the page count's text is wider than its cell

The cell is a fixed width, the cover's pixel-rounded width: `HomeFrontPageCell.body`,
`.frame(width: coverSize.width, alignment: .leading)`, `HomeGalleryInformation.swift` line 171. The page count is
`Text(.RLocalizable.pages(count:)).fixedSize(horizontal: false, vertical: true)` (`HomePageLanguage.fields`, line 23),
so it is proposed the cell's 176.0 pt, and "26 Seiten" needs 176.5 pt: it wraps at its one space.

`HomePageLanguage`'s `ViewThatFits(in: .horizontal)` (line 13) cannot help. Its two options, an `HStack` and a `VStack`,
both hold the same single page-count `Text` when the gallery has no language, and a `Text` with
`fixedSize(horizontal: false, ...)` reports its one-line width as its ideal width: 176.5 pt in both options, neither
fits 176.0 pt, so `ViewThatFits` takes the last option and the `Text` wraps. With a language the `VStack` is taken
for the same reason (the `HStack`'s ideal width, 175.0 + 8 + 154.5, is far over 176.0), and the language gets its own
line either way. The language is never the cause of the number's break; the page count's own width against the cell is.

It is 0.5 pt (de, iPad regular) to 2 pt (ja, iPad regular) over at the iPad's `.accessibility5`, and it is 3.7 to
31.7 pt over in the compact cell at `.accessibility4` and `.accessibility5` (the tables above).

### Cause 2: the wrapped lines are centred, not leading

A `Button`'s label text is centre-aligned by the button style, and the `.multilineTextAlignment(.leading)` that
`HomeFrontPageWall.galleryButton` puts on the `Button` (lines 208 to 209) does not reach the page count: the control
rows show the `Button` row identical to the app's (the "26" at 34.0 pt) and the same view with the alignment set on
`HomePageLanguage` inside the label, or with no `Button`, at 2.0 pt. The title is not affected because it sets
`.multilineTextAlignment(.leading)` on itself (line 167); `HomePageLanguage` sets none (lines 9 to 28).

The `Text` is as wide as its longest line ("Seiten", 116.0 pt for the frame) and sits at the cell's leading edge, as the
`VStack(alignment: .leading)` places it, and its two lines are centred inside that frame. That is why the "26" is not
on the leading edge but 34.0 pt in, and why only a wrapped page count shows it: a one-line text has nothing to align.

## Proposed fix

Two changes, in `AppPackage/Sources/HomeFeature/HomeGalleryInformation.swift`. The first is a repair; the second is
where the design question is (see "Cases where the page count cannot fit the cell").

1. **Leading alignment (cause 2).** In `HomePageLanguage.body`, add `.multilineTextAlignment(.leading)` next to
   `.font(.caption)` / `.foregroundStyle(.secondary)` (line 16 to 17), on the view that owns the text, so no
   `Button` can centre it. This changes nothing a reader sees where the text is one line. It also reaches the other use
   of `HomePageLanguage`, `GalleryRankingCell.swift` line 85, which is a leading-aligned `VStack` in the ranking row:
   a wrapped page count there becomes leading-aligned too (not measured; a one-line text is unchanged).

2. **Keeping number and unit on one line (cause 1).** The text must be given its own one-line width instead of the
   cell's. Where the page count's one-line width is within the cell, nothing is needed beyond change 1; where it is
   wider, a layout can only keep it whole by letting it, or the column, exceed the cover's width. The options are listed
   below and none is chosen here.

The new test, `AppPackage/Tests/HostedViewTests/FrontPageCellPageCountTests.swift`, fails before both changes, and its
cases are written so that it fails after change 1 alone wherever a page count is wider than its cell:

- Host the real wall as the diagnostic did: `ScrollView(.horizontal)` with a 20 pt content margin and
  `HomeFrontPageWall`, `columns` of two galleries each (no language, the page counts 24 to 29), a white background,
  light scheme, in a window 1400 x 1000 pt.
- For `identifier` in `en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant`, `horizontalSizeClass` in `.regular`, `.compact`,
  and every `DynamicTypeSize` from `.xSmall` to `.accessibility5` (the arguments of a parameterised test, so they run in
  parallel), find each cell by `AccessibilityElements.identifier(of:)` = `home_front_page_title_<gid>`, and read its
  accessibility frame.
- Draw the window (`drawHierarchy`) and read the ink, a pixel darker than luminance 215, in the cell's bottom
  one-caption-line band (the page count is the last thing in a cell without a language; one caption line is the
  height of a `Text("One line").font(.caption)` hosted in the same environment), over the cell's width plus 15 pt on
  each side.
- Assert, for every cell: the band holds exactly one text line of ink (so the number and the unit are on one line, and
  nothing of a second line is in the band), its leading x is within 4 pt of the cell's leading edge (2 pt is the
  glyph's own side bearing), and its trailing x is not past the cell's trailing edge.
- A second test, with a language ("Deutsch"), asserts the same for the page-count line, which is then the
  second-last line.

Before the change the iPad `de` `.accessibility5` "26" and "29" cells fail the one-line and leading-edge assertions
(two lines, the first at 34.0 pt), and so do the compact cells at `.accessibility4` and `.accessibility5`.

## Does the fix change the cell's visible design?

- Change 1 does not, beyond the repair itself: it only moves a wrapped line from centred to leading.
- Change 2 does, wherever a page count is wider than its cell (next section): whatever keeps it on one line makes the
  cell, or the text beside the next cell, wider than the cover at those sizes. That is more than "keeping the number
  and unit together on the leading edge", so under the plan's second truth it is the owner's decision, to be asked
  in Taiwanese Mandarin with this record and the picture.

## Cases where the page count cannot fit the cell

Yes. The number and the unit together are wider than the cell in these cases (cell width / page-count width, pt),
so no layout inside the cell keeps them on one line:

- compact cell (iPhone, and an iPad in a compact width), `.accessibility4`: `en` 146 / 149.7 to 150.0, `de`
  146 / 152.3 to 152.5, `ja` 146 / 153.0; all six counts;
- compact cell, `.accessibility5`: `en` 146 / 173.5, `de` 146 / 176.3 to 176.5, `ja` 146 / 177.7 to 178.0, `ko`
  146 / 163.3 to 163.5; all six counts (`zh-Hans`, `zh-Hant`: never);
- regular cell on the iPad, `.accessibility5`: `de` 176 / 176.5 (26 and 29, by 0.5 pt), `ja` 176 / 176.5 to 178.0 (five
  of six counts, by up to 2 pt); on the iPhone simulator's 3x rounding the regular cell is 176.333 pt, `de` fits and
  `ja` is over for three counts.

Up to `.accessibility3` and for `zh-Hans`/`zh-Hant` at every size, every page count fits its cell.

Options for those cases (none chosen):

- **A. The column widens to the page count.** The cell's width becomes the larger of the cover's and the page count's
  one-line width (about +3.7 to +31.7 pt in the compact cell at `.accessibility4` and `.accessibility5`, +0.5 to +2 pt
  on the iPad); the cover keeps its size, so the covers move apart by that much, and the title gets the wider width. It
  needs the page count's measured width to reach the cell's frame (a small `Layout`, or a measurement), and the wall's
  `HomeCoverWallLayout` already takes each column's width from the cells' ideal widths.
- **B. The page count overflows the cell on one line** (`fixedSize()` on the text). The overflow is 0.5 to 2 pt on the
  iPad, but 3.7 to 31.7 pt in the compact cell, which is more than the 20 pt gutter between columns at
  `.accessibility5` (en +27.5, de +30.3, ja +31.7, ko +17.3: the first three run into the next column's text, which
  starts at its own leading edge on the same line), so this is safe only where the overflow is under 20 pt.
- **C. Let it wrap and only align it** (change 1 alone). The number and the unit are on separate lines, at the leading
  edge; for `ja` the unit itself is split. This leaves the plan's first truth ("number and unit together") unmet in
  the cases above.
- **D. Truncation, a smaller font or a scale factor.** Not available: the plan's prohibition rules out
  `minimumScaleFactor`, a fixed size and hand-inserted breaks, and a truncated "26 Sei…" is not the page count.

The language going to its own line first (the plan's example) is already what the `VStack` option does and does not
change the number's break, because the break is the page count's own width against the cell.

## Decision

Asked of the owner by the orchestrator on 2026-11-25, in Taiwanese Mandarin, with the hosted render
`$W/phone/wall-compact-AX5-ja.png` shown (「ペー／ジ」 and 「ドイツ／語」 broken mid-word, the second lines centred). The
question gave both causes and offered option A (recommended) or change 1 alone (option C, recorded as a known
limitation). Answer, verbatim: 「欄寬隨文字加寬（建議）」.

- Option: **`fix-other`**, which is option A above extended to the language, with change 1. Decided by: the owner (the
  visible change, the wider column); the orchestrator spelled out the exact fix below within that answer.
- Exact fix, in `AppPackage/Sources/HomeFeature/HomeGalleryInformation.swift`:
  1. `HomePageLanguage` sets `.multilineTextAlignment(.leading)` on itself (change 1), so no `Button` centres its lines.
  2. A `HomeFrontPageCell` with rich information is as wide as the widest of its cover and the one-line widths of its
     page count and, when it has one, its language, in the `HomePageLanguage` arrangement that is shown (the `HStack`
     when both fit on one line at that width, otherwise one line each). It is never narrower than the cover; at sizes
     where the texts fit the cover's width, which is every size up to `.accessibility3`, nothing changes. The cover
     keeps its size and stays on the cell's leading edge; the title takes the cell's width. The wall's columns follow
     from the cells as they already do (`HomeCoverWallLayout`: a column is as wide as its widest cell), so the covers
     move apart by the extra width and the column spacing stays 20 pt.
  3. No text is truncated, scaled or given a fixed size, and no catalog string changes. The cell without rich
     information (`.standard` cover) is unchanged. A doc comment states the reason: the cover's scale stops at
     `GalleryCoverStyle.maximumScale` while the text keeps growing, and the owner chose a wider column over a broken
     page count or language (19-31, 2026-11-25).
- Test: `AppPackage/Tests/HostedViewTests/FrontPageCellPageCountTests.swift` as "## Proposed fix" describes it, with
  these changes:
  - the language case runs for every locale and size of the first test, with the gallery's language shown in that
    locale, and asserts the same one-line and leading-edge rules for the language line as for the page-count line;
  - every cell's cover keeps its unchanged size (its frame equals the cover style's size at that Dynamic Type size,
    to a pixel), and no cell's ink crosses into the next column (the next cell's leading edge is at least the column
    spacing past this cell's trailing ink).
  It fails before the change in the cases listed under "## Cases where the page count cannot fit the cell" and in the
  centred iPad `de` `.accessibility5` cells; after change 1 alone it still fails wherever a page count or language is
  wider than the cover.
