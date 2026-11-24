# Phase 19 Plan 23: C6 and C9 investigation

Written 2026-11-24 (Task 1 of 19-23). Decisions are recorded later, under "## C9 decision" and "## C6 decision" (Tasks 2 and 3), and are not part of this commit.

Paths: `$ROOT` is the repository root; `$W` is `$ROOT/.capture/agent-work/phase19-23` (ignored by git). Baseline pictures are read from `$ROOT/.capture/agent-work/baseline2/set/pictures/<device>/<locale>/<size>/<scenario>/<orientation>-<scheme>.png`; a picture key reads `<scenario>__<locale>__<size>__<orientation>__<device>__<scheme>`.

**Runtime note.** The baseline2 pictures were captured on iOS 27.0. Every local capture, hierarchy value and measurement in this record is from the iOS 27.2 simulators (owner decision 2026-11-24). Where the two are compared, the record says so; the reproductions below agree with baseline2.

Diagnostic edits (a hierarchy-dumping `interact` step on the two Reading states, two throw-away hosted tests, and variants of `ReadingSettingView`) lived only in the working tree. They were reverted with `git checkout -- <file>` (tracked files) and deleted (new files) before this commit, and a copy of each is kept in `$W/diagnostics/` (ignored). `git status --porcelain -- AppPackage` is empty at commit.

## C6

**Item.** `reader-settings-sheet` and `settings-pages-reading`: the first row of the Reading settings is cut at its top (owner decision 2026-11-22: investigate and fix at the root).

### Which pictures show the cut

Captured locally (candidate mode, `$W/c6-phone`, `$W/c6-pad`; every run reports `page-height` errors only, which the states' `.screen` heights allow in this plan, and records the pictures) and compared with baseline2:

| Coordinate | Cut? |
| --- | --- |
| iPhone, `ko`, `accessibility5`, portrait, light and dark, both states (`settings-pages-reading__ko__accessibility5__portrait__iphone__*`, `reader-settings-sheet__ko__accessibility5__portrait__iphone__*`) | **yes**: the label "방향" is cut at the top edge of the first card, in baseline2 (27.0) and locally (27.2). The fifth row, "가로 읽기 방향", is cut the same way (it starts under the page's bottom edge, so only its top is visible) |
| iPhone, `ko`, `accessibility5`, landscape, both states | no |
| iPhone, `de`, `accessibility5`, portrait and landscape, both states | **no**, in baseline2 and locally. The `de` first row ("Leserichtung", value "Vertikal") is whole. The 2026-11-22 verdict names `de` as well; no `de` picture of these two states in baseline2 or in the local runs shows the cut |
| iPhone, `en`, `ja`, `zh-Hans`, `zh-Hant`, `accessibility5`, portrait (baseline2 contact sheet of the first card, light and dark) | no |
| iPad, `ko` and `de`, `accessibility5`, portrait, both states (local, `$W/c6-pad`; baseline2 for `ko`) | no |

So the cut is one coordinate family: iPhone portrait, `ko`, `accessibility5`, in both states.

### Hierarchy at capture time (iPhone, `ko`, `accessibility5`, portrait, light; window coordinates in points)

`$W/c6-hier2-phone/c6-hierarchy.jsonl`, written after each state's own step by a temporary `interact` step: the first cells of the form, their accessibility elements' frames, three snapshots per coordinate (after a settle, 1.5 s later, after a second settle). The three snapshots are identical, so the hierarchy was settled.

| State | Cell (y, height) | Its content element's frame (y to y+height) | Above the cell top | Below the cell bottom |
| --- | --- | --- | --- | --- |
| `settings-pages-reading`, row 1 "방향 / 위에서 아래로" | 195.0, 174.7 | 180.0 to 384.7 (204.7 tall) | **15.0** | **15.0** |
| `settings-pages-reading`, row 2 "미리 불러올 페이지 / 10페이지" | 369.7, 236.7 | 384.7 to 591.3 (206.7 tall) | -15.0 (15 inside) | -15.0 |
| `settings-pages-reading`, row 5 "가로 읽기 방향 / 오른쪽에서 왼쪽으로" | 862.7, 174.7 | 847.7 to 1052.3 (204.7 tall) | **15.0** | **15.0** |
| `reader-settings-sheet`, row 1 | 215.0, 174.7 | 200.0 to 404.7 | **15.0** | **15.0** |
| `reader-settings-sheet`, row 5 | 882.7, 174.7 | 867.7 to 1072.3 | **15.0** | **15.0** |

A healthy row (row 2) has its content 15 pt inside the cell on each side. In rows 1 and 5 the content is 30 pt taller than the room it was given, centred, so 15 pt of it lies above the cell top (the label) and 15 pt below the bottom (the value's second line). Row 1's value "위에서 아래로" wraps to two lines (123.3 pt tall element, 149 pt wide); without the second line the content would be about 143 pt, which is what the cell (174.7 = 143 + 2 x 15, give or take 1.7) was sized for. The label is exposed only inside the row's combined element, so the element frame stands for the label's frame: it starts 15 pt above the cell top, which is at least the half point the rule asks for.

### Same cut without the capture harness

A throw-away hosted test (`NavigationStack { ReadingSettingView }` in a plain `UIHostingController` window of the scene's size, `.environment(\.dynamicTypeSize, ...)`, `.environment(\.locale, ...)`) read the same numbers with no snapshot harness involved (`$W/c6-probe.txt`):

| Locale, size, window width | Row 1 content above / below the cell | Row 5 (Landscape Direction) |
| --- | --- | --- |
| `ko`, `accessibility5`, 420 (the scene) | 15 / 15 | 15 / 15 |
| `ko`, `accessibility5`, 300, 340, 380 | 15 / 15 at all three | not read (this dump lists the cells in tree order, not by position; the row is clipped in the capture's hierarchy above) |
| `ko`, `accessibility5`, 430, 440, 450, 460 | -15 / -15 (whole: the value no longer wraps) | 15 / 15 (its longer value still wraps) |
| `ko`, `accessibility3`, 420 | -15 / -15 | 8 / 8 (the long value of row 5 wraps) |
| `ko`, `large`, 420 | whole | whole |
| `de`, `en`, `accessibility5`, 420 | whole (-15 / -15) | not read (no wrap) |

Row 1 is under-sized at every width where its value wraps, and whole at every width where it does not; it is not a borderline of one width.

### Container comparison (step 3)

The scenarios use the app's own views and paths:

- `settings-pages-reading`: `SettingsScenarios.settings([.reading(.init())])` builds a real `SettingView` whose `path` holds the Reading page, so the page is pushed through `destination(_:)` exactly as `settingRowTapped` pushes it. Differences from the running app: no tab bar around it (the app's Settings tab adds a 16 pt bottom content margin only with a bottom tab bar, `softBottomEdge`), and the window is the harness's hosted window of the screen size. Neither touches the top of the first row.
- `reader-settings-sheet`: `GalleryScenarios.reader(.settings)` builds the real `ReadingView` and sends `.presentReadingSetting`, so the sheet is the real `NavigationStack { ReadingSettingView }` inside the reader's `.sheet`, as the toolbar button presents it. The state's page-height gap only differs in that the sheet is presented by an action rather than a tap.
- Both states' title display mode, navigation stack and sheet presentation are the app's; no container difference produces the cut.

### Conclusion: **app defect**

Rule applied: a label frame above its cell's content top by half a point or more in the settled hierarchy means the app's own layout clips it. Here it is 15 pt in a settled hierarchy (three identical reads over 1.5 s), reproduced outside the capture harness, and not tied to the container.

- **Cause.** The stock `Picker(...).pickerStyle(.menu)` row of a `Form`, at an accessibility size where the row stacks its label above its value: the system control reports its value as one line tall while it lays the value out on two lines when the value is wider than the row. The form's cell is sized for the one-line report, so the content overflows the cell by one value line, centred (15 pt at each end). Rows whose value does not wrap are sized correctly (row 2, all of `de`, `en`, `ja`, `zh-*`).
- **Code location.** `AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift`, the `Form`'s five `Picker` rows with `.pickerStyle(.menu)`: Direction (first row), Preload Limit, Landscape Direction, Portrait Direction, Page Spacing. At `ko` `accessibility5` portrait the two whose value wraps are Direction ("위에서 아래로") and Landscape Direction ("오른쪽에서 왼쪽으로"); the same family would show on any other form that stacks a `.menu` Picker whose value wraps (not audited here).
- **Variants tried in the working tree (hierarchy values, `ko`, `accessibility5`, portrait; reverted).**
  - `.fixedSize(horizontal: false, vertical: true)` on the Picker (`$W/c6-var-fixed-phone`): the Picker's ideal height is the one-line height (144.7 pt of content in the 174.7 pt cell), and the wrapped value is squeezed into it; the picture shows the value cut in half. Not a fix.
  - An explicit `VStack { Text(label); Picker(...).labelsHidden() }` (`$W/c6-var-stack-phone`): the cell grows to 203 pt but still starts its content 15 pt above itself; the picture still shows the label cut and a large gap. Not a fix.
  - A `Menu` whose label is a SwiftUI `VStack { Text(label); Text(value) }` over the same `Picker` for the first row (`$W/c6-probe-menu.txt`, `$W/c6-var-menu-phone`): the first cell is 156.0 pt tall and its content fills it exactly (above 0.0 / below 0.0) at `ko` and `de` `accessibility5`; the picture shows the label and the one-line value whole. This variant was built without the stock row's chevron, tint or padding, so it shows that SwiftUI measures its own label correctly, not a finished look.
- **Proposed fix.** Build the rows whose value can wrap as a `Menu` with a SwiftUI label, instead of the stock menu `Picker` row, so SwiftUI lays out and measures the label itself. The row then has to reproduce what the stock row draws (label above value in the accessibility layout and label left, value right otherwise, the tinted value, the up-down chevron through `SFSafeSymbols`, the 15 pt vertical padding, the separator and the VoiceOver label/value/trait), so the first row, and every row of the same kind on the page, would change how it is built. Whether to apply it to every Picker on the page or only to the two that wrap is open. **This changes the visible construction of the page's rows beyond removing the clip** (their hit target, the menu's presentation and the glyph placement can differ from the stock picker), so Task 3's rule sends this to the owner.
- **Test that fails before the fix** (a hosted test, as the rule says for an app defect): `AppPackage/Tests/HostedViewTests/ReadingSettingFirstRowTests.swift` (the file 19-24 names), parallel, no `.serialized`. Host `NavigationStack { ReadingSettingView(store:) }` at the scene's size (`HostedView.sceneSize()`, 420 x 912 on the project iPhone), `.environment(\.dynamicTypeSize, .accessibility5)`, `.environment(\.locale, Locale(identifier: "ko"))`, with the store made as `ReportFormCentredStateTests` and `TorrentFileSizeTests` make theirs (`$0.context = .preview`, `$0.defaultInMemoryStorage = InMemoryStorage()`). For every `UICollectionViewCell` of the form, collect the accessibility elements under it, convert their frames to the window, and require every element's top and bottom to lie within the cell's frame, give or take 0.5 pt. Before the fix it fails on rows 1 and 5 (content 15.0 pt above and 15.0 pt below the cell, measured above); after it, it passes. A second case at `de` and at `ko` `large` keeps the healthy rows healthy (they were whole in this investigation).
- **Does the fix change the page's design beyond removing the clip?** Yes, in construction (a custom `Menu` row replaces the system picker row), and possibly in small visible details; the owner's design view is needed, which is Task 3's second branch. The facts the owner needs: only `ko` at `accessibility5` on the iPhone in portrait is cut; the page is otherwise whole in every captured coordinate; the cut is the system picker row's own sizing, not a padding the page forgot.

## C9

**Item.** `home-populated`: the Front Page shelf shows one narrow column, and stat labels are hyphenated mid-word (owner decision 2026-11-22: investigate and fix).

### Where the single column comes from (the scenario's fixture, not the app)

- `TracerScenarios.home()` sets `state.frontPageGalleries = Array(galleries.dropFirst().prefix(2))`: the shelf receives **2 galleries** (VH2 and VH3). `HomeSectionsView.frontPage` shows the shelf when `frontPageGalleries.count > 1`; `CoverWallSection.dataSource` pairs the galleries in order (an odd trailing gallery is dropped), so 2 galleries make **1 pair, which is 1 column of two rows** (`HomeFrontPageWall` lays the pairs' first elements as the top row and their last elements as the bottom row, `HomeCoverWallLayout`). N galleries give N / 2 columns, rounded down.
- What the app gives it for real: `HomeReducer.setFrontPageGalleries` keeps `prefix(min(count, 25))`, and the shelf's loading placeholder is `Gallery.mockGalleries(count: 25)`: **up to 25 galleries, 12 columns** (the 25th is dropped as an odd trailing one). The parser test fixtures of a Front Page list hold 100 galleries (`ListParserTestType.assertCount`), which the cap cuts to 25. So the single column is the correct rendering of a two-gallery page; the app has no defect there.
- Fixture options the plan lists and the shelf they give: the 8 public fixtures (`homeGalleries` 6 + `homeCarouselNeighbors` 2, all already cached by `cacheHomeArtwork`) give 4 columns; the 6 home galleries give 3 columns; keeping 2 gives 1 column.

### Which views hyphenate, where, and why

Two views draw the slideshow's stat labels, and **both** break words; the plan expected only the first.

1. `HomeCompactSlideshowInformation` (the compact slideshow card, used on every iPhone and whenever the window is not large: `usesCompactInformation = !GalleryViewport.isLarge`). A `ViewThatFits(in: .horizontal)` over a three-column `Grid` (Rating, Pages, Category; its labels and values `.font(.caption)`) with `.fixedSize(horizontal: true, vertical: false)`, and a two-column `Grid` (Rating, Pages) without it. When the first does not fit, the second is taken; when the second does not fit either, `ViewThatFits` still takes its last option and squeezes it into the width it has, so the labels wrap inside words.
2. `HomeSlideshowInformation` (the regular slideshow card on a large iPad window): an `HStack` of two `VStack` columns (Pages and Category), each `.frame(maxWidth: .infinity)`, inside `.frame(maxWidth: 360, alignment: .leading)`. The columns are therefore equal, 166 pt each (360 - 28 spacing, divided by two), whatever their content, and the card's text column is wider (482 pt) but the cap holds the block at 360.

### Hyphenated labels in baseline2 (iOS 27.0), every coordinate found

Found by reading the light pictures of all six locales at `xSmall`, `large` and `accessibility5`, both devices and both orientations (contact sheets in `$W/c9-*.png`); the dark pictures share the layout. Nothing breaks at `xSmall` or `large` anywhere.

| Device, orientation, size | Locale | Broken text | View |
| --- | --- | --- | --- |
| iPhone portrait, `accessibility5` | `en` | label "Rat-ing", label "Pag-es" (Category is dropped) | compact |
| iPhone portrait, `accessibility5` | `de` | label "Be-wer-tung" (three lines), label "Sei-ten" (Kategorie is dropped); the values "4,5" and "24" are pushed below the card's height and are not visible | compact |
| iPhone portrait, `accessibility5` | `ja`, `ko`, `zh-Hans`, `zh-Hant` | labels split between characters, no hyphen ("評 / 価", "ペー / ジ数", "페이 / 지", "评 / 分", "页 / 数", "評 / 分", "頁 / 數") | compact |
| iPhone landscape, `accessibility5` | all | none: the labels sit on one line (`de` shows two columns, Bewertung and Seiten) | compact |
| iPad portrait and landscape, `accessibility5` | `en` | label "Catego-ry", value "Doujin-shi" | regular |
| iPad portrait and landscape, `accessibility5` | `de` | label "Kate-gorie", value "Dou-jinshi" | regular |
| iPad portrait and landscape, `accessibility5` | `ja`, `ko`, `zh-Hans`, `zh-Hant` | none | regular |

### Measurements (iOS 27.2, hosted test kept in the working tree, `$W/c9-measure.txt`; `.accessibility5`, widths in points)

**Compact view.** The width the card gives the information on the project iPhone (scene 420 pt wide): the card is 378 pt (`0.9 x 420`), minus 20 pt padding on each side, minus the cover (146 pt) and 16 pt spacing: **176 pt** (the information element's frames start at 182 and the card's inner edge is 358). Ideal single-line widths of `.caption` labels and of the grids:

| Locale | Rating | Pages | Category | Three-column grid | Two-column grid | Fits in 176? |
| --- | --- | --- | --- | --- | --- | --- |
| `en` | 117.3 | 112.0 | 169.7 | 431.7 | 245.3 | no |
| `de` | **200.3** | 115.7 | 175.0 | 523.0 | 332.0 | no; "Bewertung" alone is wider than 176 |
| `ja` | 80.7 | 161.0 | 161.0 | 434.7 | 257.7 | no |
| `ko` | 74.7 | 111.7 | 149.0 | 367.3 | 202.3 | no |
| `zh-Hans`, `zh-Hant` | 81.3 | 81.3 | 81.3 | 316.7 | 178.7 | no, by 2.7 |

Single line height is 51.3 pt. The real card hosted at 378 pt shows "Rating" 80 x 102.3 and "Pages" 69.3 x 102.3 (two lines each, `en`), "Bewertung" 84 x 153.3 (three lines) and "Seiten" 76.3 x 102.3 (two lines) in `de`, so the squeeze is the cause, as in the pictures. In iPhone landscape the card is wider (computed 675 pt with the scaled cover), the information gets about 473 pt: `en` three columns (431.7) fit, `de` falls to two columns (332.0) and fits, so nothing breaks, as in the pictures.

**Regular view.** The information block is capped at 360 pt, so each equal column is 166 pt. The widest line of each column (`.caption` labels; the Category value is `.subheadline`):

| Locale | Pages label | Category label | Category value | Needs with equal columns (2 x widest + 28) | Needs with content-sized columns (sum + 28) |
| --- | --- | --- | --- | --- | --- |
| `en` | 112.0 | 169.7 | 193.7 | 415.4 | 333.7 |
| `de` | 115.7 | 175.0 | 193.7 | 415.4 | 337.3 |
| `ja` | 161.0 | 161.0 | 137.7 | 350.0 | 350.0 |
| `ko` | 111.7 | 149.0 | 127.3 | 326.0 | 288.7 |
| `zh-*` | 81.3 | 81.3 | 139.0 | 306.0 | 248.3 |

A 166 pt column is narrower than "Category" (169.7), "Kategorie" (175.0) and "Doujinshi" (193.7), which are exactly the broken words; the hosted card shows "Category" 153 x 102.3 and "Doujinshi" 154.7 x 116.7 (two lines each). The block fits at 360 pt in all six locales if the columns are sized by their content (at most 350.0), but not if they stay equal (415.4 for `en` and `de`).

### Options of Task 2, with the exact change and the test that fails before it

Common to every layout option: the owner's requirement is that no stat label breaks mid-word, so the test asserts, for each of the six locales at `.accessibility5`, that every stat label's element is one line tall (51.3 pt) and every label is whole. A layout test that hosts `HomeCompactSlideshowInformation` in the 176 pt column fails before any change for all six locales (the frames above).

- **`fixture-8`**: in `TracerScenarios.home()` (`AppPackage/Tests/VisualSnapshotTests/Matrix/TracerSnapshotTests.swift`) change `state.frontPageGalleries = Array(galleries.dropFirst().prefix(2))` to `galleries + carouselNeighbors()` (8 galleries, 4 columns); every cover is cached by `cacheHomeArtwork`; the fixture export (`PublicVisualFixtures`) is untouched. Test (VisualSnapshotTests): the state's `frontPageGalleries.count == 8`. Fails before: it is 2.
- **`fixture-6`**: the same line with `galleries` (6 galleries, 3 columns). Test: `count == 6`. Fails before: 2.
- **`fixture-keep`**: no change; no test.
- **`layout-lines`** (`HomeCompactSlideshowInformation`): add a last `ViewThatFits` option laying each stat out as one line, label then value, instead of the squeezed grid. **Measured limit:** in the 176 pt column the `de` label "Bewertung" (200.3) is wider than the column by itself, so this option, and `layout-stacked` below, still break a word in `de` on the iPhone in portrait unless the block is given more width (for example the full card width below the cover, 338 pt). Every other locale's single label fits (largest: `de` "Kategorie" 175.0, one point inside; `en` "Category" 169.7).
- **`layout-stacked`** (`HomeCompactSlideshowInformation`): a last option with each stat as label above value, in one column. Same measured limit as `layout-lines`.
- **`layout-icons`** (`HomeCompactSlideshowInformation`): at accessibility sizes the three stats are symbols with their values and the labels become accessibility labels. No visible label can break; the test asserts that no visible label text exists at `.accessibility5` and that each stat has its accessibility label.
- **The regular view needs its own change whichever layout is chosen.** Options for `HomeSlideshowInformation`, each measured above: size the two columns by their content (the block then needs at most 350.0 of the 360 cap in the six locales), or raise the cap, or one stat per line there too. The test (hosted, `.accessibility5`, a regular-width card of 751 pt) asserts every stat label and the Category value is one line tall; before the change `en` and `de` fail ("Category" 153 x 102.3 against 51.3).

### Conclusion

- Single column: the scenario's fixture (2 galleries), not the app.
- Hyphenation: the squeeze of `ViewThatFits`' last option in `HomeCompactSlideshowInformation` on the iPhone in portrait at `accessibility5` (all six locales, hyphens in `en` and `de`), and the equal 166 pt columns under the 360 pt cap in `HomeSlideshowInformation` on the iPad at `accessibility5` (`en` and `de`, including the Category value). Both are app layout.
- Not covered by the matrix: accessibility sizes between `large` and `accessibility5`, and iPhone widths other than the 420 pt scene; the measurements above are for `accessibility5` at those windows.
