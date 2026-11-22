# 19-20 probes

The measuring mode (`Scripts/visual/run-snapshot-local.sh --measure-heights`) takes no picture: each coordinate gets
one line in `heights.jsonl` with the window height its page needs, found by growing the window until the need holds
still. Runs below are local runs on the project simulators; `$W` is `$MAIN/.capture/agent-work/phase19-20` (ignored by
git, no picture and no height file is in the repository). Nothing is committed to the provider files.

## Task 1: tracer, `settings-root`

`SettingsSnapshotTests/testRoot` on the iPhone, `en-large` and `en-accessibility5`, both orientations, light and dark
(`$W/tracer`): `measured=8 cannot-cover=0 did-not-converge=0 error=0 notApplicable=0`; no `results.jsonl` and no
picture was written. Each measured need equals the height 19-19 committed for the same coordinate
(`19-19-TALL-WINDOW.md`), and dark gives the same value as light.

| coordinate (iPhone, `en`) | measured need (light = dark) | steps | 19-19 committed | equal |
| --- | --- | --- | --- | --- |
| `large`, portrait | 912 pt | 0 | 912 pt | yes |
| `large`, landscape | 633 pt | 1 | 633 pt | yes |
| `accessibility5`, portrait | 912 pt | 0 | 912 pt | yes |
| `accessibility5`, landscape | 850 pt | 1 | 850 pt | yes |

A page that fits the screen (portrait) is measured at the device height in no steps; landscape overflows the 420 pt
screen and is covered after one growth step. The measuring mode and the check of 19-19 therefore agree for the tracer
state.

## Task 3: probes on the hard cases

Measuring mode only, both themes, one run each, `en` and the text size named, outputs under `$W/probe-<name>`. Nothing
is committed to the provider files. "Need" is the whole-point window height the page needs, `screen` the device height
(iPhone 912 pt portrait and 420 pt landscape, iPad 1210 pt portrait), `steps` how many times the window was grown.

### Conclusions

| # | probe (run) | conclusion |
| --- | --- | --- |
| 1 | `HomeSnapshotTests/testHomePopulated`, iPhone `en-large` (`probe-home-populated`) | taller, coverable: 1755 pt portrait, 1725 pt landscape, 1 step each, light = dark |
| 2 | `CommentsSnapshotTests/testPostFilled`, iPhone `en-large` (`probe-post-filled`) | finding, cannot cover: a keyboard is up, so the sheet's bottom inset grows with the window and the need never converges. Under the plan's order it ended earlier as `error`, a settle timeout before the user step (a caret, `settle-timeout:pixels:78,187,4x25`) |
| 3 | `SearchSnapshotTests/testTypingSuggestions`, iPhone `en-large` (`probe-typing-suggestions`) | finding, cannot cover: a keyboard is up, so the scroll view's bottom inset grows with the window and the need never converges (`did-not-converge`, 3980 pt portrait, 6049 pt landscape at the last step) |
| 4 | `ReaderSnapshotTests/testVertical`, iPhone `en-large` (`probe-reader-vertical`) | finding, a state the design lists as `.screen` that measures taller: 4672 pt portrait, 10214 pt landscape |
| 5 | `AppWideSnapshotTests/testAppAlert`, iPhone `en-large` (`probe-app-alert`) | finding, cannot cover: a keyboard is up (the alert's text field), so the bottom inset grows with the window and the need never converges. Under the plan's order it ended earlier as `error`, a settle timeout before the user step (`settle-timeout:animation:UIImageView:contents`) |
| 6 | `SettingsPagesSnapshotTests/testGeneralCacheConfirmation`, iPhone `en-large` (`probe-cache-confirmation`) | taller, coverable: 939 pt portrait (27 pt over the screen), 884 pt landscape, 1 step each |
| 7 | `AppWideSnapshotTests/testErrorInfo`, iPad `en-accessibility5` portrait (`probe-pad-error-info`) | finding, cannot cover: the form sheet's collection view does not grow with the window (need 1930 pt after 1 step) |
| 8 | `DownloadsSnapshotTests/testInspector`, iPad `en-accessibility5` portrait (`probe-pad-inspector`) | finding, cannot cover: the sheet's collection view does not grow with the window (need 4357 pt after 3 steps) |
| 9 | `HomeSnapshotTests/testHomePopulated`, iPad `en-large` portrait (`probe-pad-home-populated`) | taller, coverable: 1858 pt, 1 step, light = dark; equals the need the check reported in 19-19 |

### Per coordinate

`measured` unless stated. Light and dark are listed where they differ.

| probe | coordinate | status | need (pt) | screen (pt) | steps | reason |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | portrait | measured | 1755 | 912 | 1 | |
| 1 | landscape | measured | 1725 | 420 | 1 | |
| 2 | portrait, landscape | error | | 912, 420 | 0 | `settle-timeout:pixels:78,187,4x25` (light), `pixels:78,186,5x27` (dark), landscape `pixels:504,101,5x25` |
| 3 | portrait | did-not-converge | 3980 | 912 | 12 | |
| 3 | landscape | did-not-converge | 6049 | 420 | 12 | |
| 4 | portrait | measured | 4672 light, 4666 dark | 912 | 1 | |
| 4 | landscape | measured | 10214 light, 10201 dark | 420 | 1 | |
| 5 | portrait, landscape | error | | 912, 420 | 0 | `settle-timeout:animation:UIImageView:contents` |
| 6 | portrait | measured | 939 | 912 | 1 | |
| 6 | landscape | measured | 884 | 420 | 1 | |
| 7 | portrait | cannot-cover | 1930 | 1210 | 1 | `cannot-cover:UpdateCoalescingCollectionView` |
| 8 | portrait | cannot-cover | 4357 | 1210 | 3 | `cannot-cover:UpdateCoalescingCollectionView` |
| 9 | portrait | measured | 1858 | 1210 | 1 | |

### What the probes show

- **Probes 2 and 5 show the interact-order defect.** The measuring mode settles and freezes the page at native
  size, and only then runs the user step (design section 3's order, as 19-19's tall window does). These two states
  reach their still picture through that step: `comments-post-filled`'s step holds the caret solid and the page
  still, `app-wide-app-alert`'s holds the alert's caret. Before the step the caret blinks (a 4 x 25 pixel box) or the
  alert is still animating, so the first settle times out and the measurement ends as `error` with no need. The
  tall-window capture of 19-19 settles before the user step in the same way, so any state whose step makes the page
  still would fail the same way there when committed taller than the screen. The owner decided on 2026-11-23 to split
  the steps; a separate plan implements it (see the experiment below).
- **Probes 2, 3 and 5 cannot be covered by any window height: a keyboard is up in all three.** The keyboard stays at
  the screen bottom, so the scroll view's adjusted bottom inset grows by exactly the window's growth and the need
  never converges (evidence in the experiment below). Probe 3 shows it in the plan's order already.
- **Probe 4:** the design lists the reader among the pages that never scroll (`.screen`), but its vertical list needs
  4672 / 4666 pt (portrait) and 10214 / 10201 pt (landscape) on the iPhone, and 9265 pt on the iPad (19-19). Light and
  dark differ by a few points, so the tallest of both themes (and six languages) is what a height would carry.
- **Probes 7 and 8: a form sheet does not grow with the window**, on a second sheet (19-19 found it for the Error
  Info sheet: 1570 pt, then 1930 pt). The inspector took three steps before the finding; the page behind the sheet is
  one reason it may have been the most-overflowing scroll view at first (not established). The same scroll view class
  is named in both.
- **The sliced path on a real page (owed by 19-19).** The measuring mode settles a window above 8191 device pixels on
  the render-server path (owned-row digests of native-size reads). Probe 4's first growth step sets the window to the
  reader's need, 4672 pt at 3x = 14,016 px in portrait (10,214 pt = 30,642 px in landscape), so that settle took the
  render-server path on a real page. The measuring mode takes no picture, so this is the settle half only: the
  composite of native-size reads of a real page above the limit is still not shown.
- Light and dark give the same need in every probe that measured, except the reader (4672 / 4666 and 10214 / 10201 pt).

## Experiment: the user step before the native settle ("order B")

Exploratory, requested by the orchestrator, never committed. Order B in both the measuring mode and the tall window's
attempt: host at native size, run the user step once (nothing runs it again after growth), settle, freeze and verify,
grow, settle, then measure or capture. Up to the growth this is the order of a `.screen` capture. iPhone `en-large`,
both orientations, light and dark; light = dark in every row. Runs: `$W/cur-*` (current order, made for this
experiment), `$W/b-*` and `$W/d-*` (order B), `$W/cand-*` (candidate captures).

### Table 1: current order and order B (status, need in pt, steps)

| state (user step) | coordinate | current order | order B |
| --- | --- | --- | --- |
| `comments-post-filled` (`holdStill`, caret) | portrait | error `settle-timeout:pixels:78,187,4x25`, 0 | did-not-converge, 14383, 12 |
| | landscape | error `settle-timeout:pixels:504,101,5x25`, 0 | did-not-converge, 12882, 12 |
| `search-typing-suggestions` | portrait | did-not-converge, 3980, 12 | did-not-converge, 3980, 12 |
| | landscape | did-not-converge, 6049, 12 | did-not-converge, 6049, 12 |
| `app-wide-app-alert` (`holdAlertCaret`) | portrait | error `settle-timeout:animation:UIImageView:contents`, 0 | did-not-converge, 1991, 12 |
| | landscape | error, same reason, 0 | did-not-converge, 4697, 12 |
| `settings-pages-general-full` (`scrollToBottom`) | portrait | measured 912, 0 | measured 912, 0 |
| | landscape | measured 868, 2 | measured 868, 2 |
| `settings-pages-general-cache-confirmation` (`RevealStep.reveal`) | portrait | measured 939, 1 | measured 939, 1 |
| | landscape | measured 884, 1 | measured 884, 1 |
| `home-loading` (`freezeIndicators`) | portrait | error `settle-timeout:animation:UIImageView:contents`, 0 | measured 941, 1 |
| | landscape | error, same reason, 0 | measured 903, 1 |

Order B removes the settle timeouts before the user step (`post-filled`, `app-alert`, `home-loading`), and
`home-loading` then measures. It does not make the three keyboard states converge. A temporary print of the
most-overflowing scroll view at each growth step shows why: its content height is constant (1456 pt for the
post-filled sheet's collection view, 679 pt for the search page's hosting scroll view, 500 pt for the alert page's
collection view), its bounds follow the window, and its adjusted bottom inset grows by exactly the window's growth at
every step (post-filled portrait: window 1603 pt with bottom inset 1038, window 13318 pt with bottom inset 12753;
typing-suggestions: 1148 pt with 583, 3744 pt with 3179; app-alert: 995 pt with 404, 1908 pt with 1317; landscape
shows the same, for example typing-suggestions at 5616 pt with 5420). The keyboard stays at the bottom of the screen
while the window extends below it, and the page's inset follows the window. The need counts that inset as overflow, so
it never holds still.

### Table 2: scroll offsets in the tall window (candidate captures at one-off measured heights)

Read with `xcresulttool` from `XCTAttachment`s. `delta = contentOffset.y + adjustedContentInset.top`; 0 means the
page's top is in view. The scroll view is the page's collection view in every row.

| state, coordinate | native, after the user step and settle | grown, after settle |
| --- | --- | --- |
| `general-full`, landscape (420 to 868 pt) | offsetY 312.67, top inset -78, delta 390.67 (scrolled to the bottom); contentH 758 | offsetY -78, delta 0; contentH 770; boundsH 868 |
| `cache-confirmation`, portrait (912 to 939 pt) | offsetY -95, top inset -122, delta 27; contentH 783 | offsetY -122, delta 0; boundsH 939 |
| `cache-confirmation`, landscape (420 to 884 pt) | offsetY 386, top inset -78, delta 464; contentH 786 | offsetY -78, delta 0; boundsH 884 |

`general-full` portrait fits the screen and takes the non-tall path, so it has no row. After growth the offset is
always clamped back to the top (the largest valid offset is about -78 or -122 pt, so nothing scrolls): the position
the user step scrolled to is lost, and each picture's top shows the page's top (the back button, the title and the first
row) with the whole page below it. `general-full`'s content is 12 pt taller at offset 0 (758 to 770 pt).

### Table 3: what the pictures show

| picture | top of the picture | note |
| --- | --- | --- |
| `general-full`, landscape, 912 x 868 | back button, "General" title, first rows | the whole page, down to the footer text |
| `cache-confirmation`, portrait, 420 x 939 | back button, "General" title, Language row | the popover's arrow points at "Clear Image Cache" |
| `cache-confirmation`, landscape, 912 x 884 | back button, "General" title, Language row | the popover loses its anchor: it sits at the upper left over the Navigation rows with no arrow toward "Clear Image Cache", with some blur at its left edge |

The popover is presented at native size, before the growth, and the grown layout moves the row it was anchored to.

### Restore

The experiment edited `HostedWindowCapture.swift`, `TallWindow.swift`, `SnapshotMatrixCase.swift` and
`GeneralSettingViewSnapshot.swift` (a one-off `.committed` value through `snapshot_heights.py apply`). All four were
restored with `git checkout -- <file>`; `git diff -- AppPackage` is empty and the md5 checksums equal those taken
before:

```
08deac330c80e8ecc9cde2a2f9c3daac  HostedWindowCapture.swift
c3f79c84ca49940e58399676a11055d9  TallWindow.swift
1b8efe294cd2b7ca954a0eeb79bcd891  SnapshotMatrixCase.swift
476c183a81a1337d77e4d9b67546a69a  GeneralSettingViewSnapshot.swift
96167108d0ff6abd9bf63d06373ed615  FiltersViewSnapshot.swift (not touched, checked)
```
