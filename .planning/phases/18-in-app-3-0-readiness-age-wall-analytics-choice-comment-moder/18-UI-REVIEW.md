# Phase 18 — UI Review

**Audited:** 2026-11-07 (UTC 01:55–03:55), at `38bae2250`; fixes re-captured at `87a02f2dd` and `d8e82f4a7`
**Updated:** 2026-11-07 (UTC 06:20), after the 18-UAT gap fixes: top fix 1, the dark card pills and the AX5
comment-link scroll are fixed (`18e85bd92`, `75ed2912e`, `b48e5d0ec`); the Blocked Users title at AX5 stays open
(see Pillar 4). The scores below are the audit's.
**Baseline:** `18-UI-SPEC.md` (C-1 to C-13) and the mockups in `mockups/`
**Screenshots:** captured in the Simulator, not with Playwright (native app, no dev server). An uncommitted
capture-only UI test (`Phase18UIReviewCaptureUITests`, kept outside the repo with the shots in
`$TMPDIR/p18ui/`) walked every Phase 18 screen with the DEBUG launch keys and fixtures and kept a screenshot per
state. No screenshot is in the repo.

| Device | Light, default size | Dark, default size | Light, AX5 | Dark, AX5 |
|--------|---------------------|--------------------|------------|-----------|
| iPhone Air (`FFE7E686…`) | 22 states, twice (before and after the fixes) | 22 states | 22 states, twice | 22 states, twice |
| iPad Pro 11-inch M5 (`B470DB46…`) | first launch, comments, block, collapse, reveal | — | — | first launch, comments, block, collapse, reveal |

The 22 phone states: age wall unticked, ticked and AX5 bottom; analytics choice empty, Basic picked and AX5 bottom;
comments list, `…` menu, Block alert, collapsed row, revealed row, revealed menu (Unblock), posting warning; Detail
strip, strip card menu, collapsed card; Settings → General analytics (Minimal, picker open, Full); Account → Blocked
Users row; Blocked Users list, swipe to Unblock, empty state; the Report form from the menu. The pad skipped dark at
the default size and light at AX5 (the layouts are the same as the phone's apart from the width rules, which the two
it ran cover). After `d8e82f4a7` the comment states (list, menu, Block alert, collapsed row, revealed row and menu)
were captured once more on the phone in light and dark at the default size and light at AX5, and on the pad in light
at the default size.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | Every visible string matches the approved copy (both copy checks pass); the one content defect, the Report prefill joining a comment's runs, is fixed (`38bae2250`) |
| 2. Visuals | 3/4 | Matches the mockups at the default size; at AX5 three layouts broke words or truncated, two fixed here, one open; a fix's default-size regression (Hide as "Hi/d/e") was caught on re-capture and fixed |
| 3. Color | 3/4 | Accent only where C-Color allows it; the dark Detail-card pills are nearly invisible on `systemGray5`, as specified |
| 4. Typography | 3/4 | Text styles only, as specified; at AX5 a revealed comment's date truncates and the Blocked Users large title truncates |
| 5. Spacing | 4/4 | Every first-launch and card value is on the 4pt scale; no arbitrary value except a hit-area inset |
| 6. Experience Design | 3/4 | Every C-1…C-13 state was reached and looked right; a comment link's scroll stops short at AX5 (known, open) |

**Overall: 20/24**

---

## Top 3 Priority Fixes

1. **A revealed comment's date truncates at AX5** (fixed, `18e85bd92`; tests `77a5e6e8a`) — "+7 10/27/24, 3…" in
   the revealed row, while the same comment's date wraps ("+7 10/27/24, / 3:24 PM") before it is blocked. Breaks the
   spec rule "nothing truncates at any size" on the one row a user has chosen to read. The row did re-measure: it was
   863pt tall, with the cell centred in it and 52pt to spare. The revealed cell stacks the C-7 line over the
   comment, and a `VStack` offered its own height hands it out in equal shares rather than by each child's ideal,
   so the comment got less than it needed and its header, the one part that gives way, lost the date's second line.
   The line and the comment now each take their ideal height. `RevealedCommentCellLayoutTests` reproduces it outside
   the list (52pt short at AX5, 40pt at AX3); the UI test compares the date's frame before the block and after Show
   at AX5 (190×105pt before, 243×53pt after, until the fix).
2. **The Detail strip's collapsed card broke "Un-block" at AX5** (fixed, `87a02f2dd`) — the two C-8 pills shared one
   line in a 380pt card. They now stack where they don't fit, as C-6's row does.
3. **The revealed comment's C-7 line** (fixed in three steps: `7bdb55c3f`, `c2b7d9d5d`, `d8e82f4a7`) — at AX5 the
   label broke inside words beside a two-line "Hi/de". The first fix stacked the line whenever it didn't fit on
   one line, which in a phone's comments sheet is already the case at the default size, so Hide dropped under the
   label, unlike mockup 09. The second put Hide back beside the label but let the label take its width first; on
   the iPhone Air (307pt row) the label just fits on one line and Hide broke into "Hi/d/e" at the default size,
   seen when re-capturing. Now Hide keeps its size beside the wrapping label below accessibility sizes and goes
   under the label at accessibility sizes. The layout test runs at the measured iPhone Air row width and a 375pt
   phone's.

Further warnings: the dark collapsed-card pills (Color; fixed, `75ed2912e`), the AX5 comment-link scroll
(Experience Design; fixed, `b48e5d0ec`) and the Blocked Users large title at AX5 (Typography; open).

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

- `18-copy-check.py`: "36 keys x 6 locales verbatim; 60 retired texts absent". `18.1-copy-check.py`: "22 keys × 6
  locales, 0 dropped keys present (7 checked)". Rerun at `38bae2250`.
- On screen (en), each string matched the Copywriting Contract: the age wall title, body, declaration, Continue and
  footnote; "Choose what / EhPanda shares" (C-3 line-break rule held on the phone at the default size and at AX5, and
  on the pad); the joined `consent.body` + `consent.footer` paragraph; the three level names and descriptions and
  "Recommended" on Basic only; "Report on E-Hentai", "Block 黑锋血色", "Unblock 黑锋血色"; the Block alert; the
  posting warning ("Post this comment?", Edit, Post Anyway; the matched word is not shown); "Comment from a user
  you've blocked" with Show / Unblock / Hide, no name on the collapsed row or card; Blocked Users, its footer and
  "You haven't blocked anyone."; the Settings footer showing the selected level's description.
- **Fixed — Report prefill (C-13, Phase 18.1 code):** Details quoted the comment through `plainTextContent`, which
  joins the comment's runs with nothing, so a text run and the link after it read as one word
  ("赛博亚历山大图书馆EhPanda UITest Fixture Alt"). `ReportPrefill.commentText(of:)` now puts each text, link or URL
  run on its own line (`38bae2250`, `ReportPrefillTests` + `CommentModerationReducerTests`). Re-captured: the two
  runs are on two lines. `plainTextContent`, used by the comment editor, is unchanged; the editor still joins runs
  the same way (18.1 gap list).

### Pillar 2: Visuals (3/4)

- Default size, light and dark, phone and pad: the age wall, the analytics choice, the comment menu, the Block
  alert, the collapsed row, the Detail strip card, Settings and Blocked Users match mockups 01–05, 07, 08, 10–15,
  20–24. The pad's collapsed row uses the one-line candidate (label, then Show and Unblock on the right), as
  mockup 22.
- AX5: both first-launch screens keep Continue pinned and the content scrolls under it with the soft edge, the
  checkbox and radio glyphs sit above their text, the age-wall footnote is the last scroll item (mockups 16–18).
  Settings uses the label-above-picker layout (C-9). The Report form wraps and the pinned Send Report grows.
- **Fixed — revealed comment line (C-7):** see Top fix 3. Re-captured at `d8e82f4a7` (iPhone Air light and dark
  default, light AX5; iPad light default): at the default size the label wraps to two lines beside a one-line Hide
  pill, as mockup 09; at AX5 the label wraps in whole words and Hide sits under it on one line. The capture at
  `87a02f2dd` had shown the default-size "Hi/d/e" that `d8e82f4a7` fixes.
- **Fixed — collapsed Detail card at AX5 (C-8):** see Top fix 2. Re-captured at `87a02f2dd` (iPhone Air light
  default, light and dark AX5): Show and Unblock stack and keep whole words at AX5 and share one line at the
  default size. The dark pills' faint fill was the Color warning, fixed in `75ed2912e`.
- **Fixed — revealed comment's date at AX5:** see Top fix 1 (`18e85bd92`).
- Not a defect: the system alert at AX5 hyphenates the Block body ("com-ments"); this is the system alert's own
  layout and the spec chose alerts on purpose (C-4).

### Pillar 3: Color (3/4)

- Accent use in the Phase 18 code (`grep accentColor|tint(`): `FirstLaunchContinueButton` (Continue fill),
  `CheckboxToggleStyle:63` (ticked glyph), `ChoiceCard:48,79` (selected stroke and radio), `ReportFormView:308`
  (Send Report fill). The Privacy Policy link is `.tint(.primary)` (`AnalyticsChoiceView:83`); the pills are
  `.tint(.primary)` (`BlockedCommentRow`). No hard-coded colour. Matches "Accent reserved for".
- Continue: white on the light accent, black on the dark accent, as specified; the dimmed state uses the system's
  disabled glass.
- **Fixed — dark collapsed card pills (C-8)** (`75ed2912e`; test `1aaddb87e`): in dark mode the Show and Unblock
  capsules (`secondarySystemGroupedBackground`, #1C1C1E) on the card's `systemGray5` (#2C2C2E) were hard to see as
  buttons; the labels read, the capsule shapes barely did. UI-SPEC rev 1.1 (`2bb5352ed`) changed C-8: in dark the
  pills are `systemGray3` (#48484A) with a 1pt `systemGray` edge (#8E8E93, 4.3:1 against the card); light keeps the
  white capsule with no edge. `BlockedCommentCardPillColorTests` renders the card in each appearance and counts the
  pixels of each colour.

### Pillar 4: Typography (3/4)

- New text uses text styles only (`.title.bold()`, `.body`, `.headline`, `.subheadline`, `.footnote`, `.caption`
  semibold for Recommended) and scales to AX5 without clipping on the first-launch screens, Settings and the
  Report form.
- **Fixed — revealed comment's date truncates at AX5** (Top fix 1, `18e85bd92`).
- **Warning — Blocked Users large title at AX5 (open):** "Blocked Use…" in the navigation bar on the list, swipe and
  empty screens. C-11 asks for a system large title, and the navigation bar truncates one that does not fit; the
  empty-state heading under it wraps in full. UI-SPEC rev 1.1 now asks for
  `.toolbarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)` on C-11 and C-12, but
  AGENTS.md's accessibility navigation policy forbids dynamic-type branches and text-size-dependent title
  fallbacks, and no owner exception covers this screen (the only one is the compact Library title menu). Not
  implemented: it needs the owner's exception or a spec that keeps one title mode at every size.

### Pillar 5: Spacing (4/4)

- First launch (`AgeWallView`, `AnalyticsChoiceView`, `FirstLaunchGateView`, `ChoiceCard`, `CheckboxToggleStyle`,
  `FirstLaunchContinueButton`): 4, 8, 12, 16, 24, 32 and the 48/96 top paddings, the 560pt column, 24pt margins,
  8pt over and 16pt under Continue — all as the Spacing Scale. The one value off the scale is
  `AnalyticsChoiceView.linkHitPadding = 14`, a padding that is added and taken back to give the Privacy Policy link
  a 44pt hit height, not visual space.
- C-6/C-7/C-8 use 8 and 10 as specified; the cards keep equal sizes in the strip at every captured size.

### Pillar 6: Experience Design (3/4)

- States reached and correct: age wall unticked (Continue dimmed) and ticked; analytics with no selection
  (Continue dimmed) and Basic picked; the menu on someone else's comment; Block confirmation; the collapsed row
  and card; Show, Hide, and Unblock in the menu of a revealed comment; the posting warning over the kept text of a
  fixture comment that trips the filter; the Settings level
  change with its footer; Blocked Users list, swipe to Unblock, empty state; the Report form opened directly from
  the menu.
- Report form states (loading, sending, sent, failed, unavailable) were not re-captured here; `ReportFormUITests`
  covers them on both devices (see `18-UAT.md`).
- **Fixed — AX5 comment-link scroll** (`b48e5d0ec`; test `bc18ca733`): `CommentsView` called
  `proxy.scrollTo(scrollCommentID, anchor: .top)` once, animated, after 0.75s; at AX5 it sometimes stopped short of
  the linked comment (recorded in 18.1-04, deviation 8; the UI tests swipe to work around it, `a1afdc81c`). The list
  aims at rows it has not built by their estimated heights, far below the real ones at AX5, so the travel stopped
  a row and a half short (1 of 3 cold launches on the iPhone Air, the same offset each time). After the travel, the
  scroll is now made again without animation on three turns of the main queue, 0.1s apart, once the rows around the
  comment have their real heights: 6/6 cold launches land.

---

## Files Audited

- `AppPackage/Sources/AppFeature/FirstLaunch/{AgeWallView,AnalyticsChoiceView,FirstLaunchGateView}.swift`
- `AppPackage/Sources/AppComponents/{CheckboxToggleStyle,ChoiceCard,FirstLaunchContinueButton}.swift`
- `AppPackage/Sources/DetailFeature/Moderation/{BlockedCommentRow,BlockedCommentCard,ReportPrefill,ReportFormView}.swift`
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift`, `DetailView+Subviews.swift`,
  `DetailView+CommentCells.swift`
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift`,
  `SettingFeature/BlockedUsers/BlockedUsersView.swift`, `SettingFeature/AccountSetting/AccountSettingView.swift`
- `18-UI-SPEC.md`, `mockups/01…34`
