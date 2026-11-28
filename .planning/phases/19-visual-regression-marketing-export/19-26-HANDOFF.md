# 19-26 Handoff (2026-11-28)

Where plan 19-26 stands, for the session that continues it. The continuation runs on the same Mac, in the same
worktree (`.claude/worktrees/phase19-deferred-0c4fb6` of the main checkout, branch `claude/phase19-deferred-0c4fb6`).
Read `AGENTS.md`, `.planning/STATE.md`, `19-26-PLAN.md` and `19-26-HEIGHTS.md` first.

## State

- Branch tip `cd5191b4d` (`docs(19-26): record the measured heights`) plus this file. The branch was pushed to
  `origin` by the owner on 2026-11-27 (tip `810de0f82`, no PR); git on this Mac has no stored GitHub credentials, so a
  later push is the owner's to run. Every push, PR, merge and hosted run needs the owner's go-ahead in words.
- The branch `fix/snapshot-scenarios` was deleted locally and on `origin` on 2026-11-27, with the owner's go-ahead,
  after this branch (which holds equivalents of all its changes) was pushed; its stale worktree entry was pruned.
- Task 1 is done: all measuring runs finished, `propose` returned 0 (118 states proposed, 4,140 finding lines over 54
  states), and `19-26-HEIGHTS.md` holds the runs, the proposal summary, the findings and the storage projection
  (7.877 GB projected against 19-12's 5 GB line; every slice under 1.8 GB).
- Task 2 (owner checkpoint) is in progress: round 3 (below) settled the alert, the menus, and how the Search root and
  the freeze check are fixed. The owner gave the go-ahead (「Yes, start」); both fixes landed, tests first
  (`86c47193b` Search root, `4a87dc8b3` freeze check), and the touched states were re-measured (below). The
  sheet-content design was decided in round 4 (below), built on the owner's 「開始實作」 (`063a110d8`, with two fixes
  `abd193abd` and `4a40eebfb`), and the 30 sheet states re-measured (below). Open: approval of the heights.
- Since the push: `e42b140c0` to `4a40eebfb` (local only, not pushed).
- Task 3 has not started. No provider file, STATE.md or ROADMAP.md was changed for 19-26 yet.

## Re-measure after the two fixes (2026-11-27)

The sixteen touched states (the Search root's eleven, `app-wide-error-info`, the two archives states,
`downloads-grid`, `favorites-signed-out`) over all 18 configurations on the iPhone (both orientations), iPad portrait
and iPad landscape, in `.capture/agent-work/phase19-26/remeasure`: 2,304 lines, no `did not converge`, no `error`.
- The Search root states, Quick Search on the iPhone and the toasts now measure finite content heights (for example
  `search-root-empty` on the iPhone portrait 912, 912 and 1,351 pt at xSmall, large and accessibility5).
- The archives, downloads grid and favorites signed out dark coordinates now measure the same needs as their light
  twins.
- Still `cannot-cover`: the confirmation dialogs' own scroll view at accessibility5 (alerts keep the screen height),
  the iPhone accessibility5 Filters reset dialog (`cannot-cover:popover`), and the iPad sheets (the sheet-content
  design).
- A regenerated proposal with these runs last, `proposal-remeasure.json`, proposes 130 states (118 before) with
  2,684 finding lines (4,140 before). `proposal.json` is unchanged; Task 3's plan amendment names the input it
  applies, and its verify command's `--runs` must add the three `remeasure/*` runs.
- The iPhone run ended `TEST FAILED` on the 24 `cannot-cover:popover` coordinates of
  `quick-search-filters-reset-confirmation` (as in the first accessibility5 run): TCA reports that the binding at
  `FiltersView.swift:38` was set to nil while the store's dialog state stayed set. `FiltersReducer` has no
  `.ifLet(\.$confirmationDialog, action: \.confirmationDialog)` (the only `@Presents` in the sources without one), so
  dismissing the Reset dialog without choosing leaves its state set. An app defect outside 19-26; the owner chose to
  fix it first (「先修這個」): `eb8f4ee04`, tests first (dismissing and confirming both clear the dialog). The 24
  coordinates stay `cannot-cover:popover`.
- The worktree's HEAD was found detached twice on 2026-11-27 at the branch tip (cause unknown, nothing lost); each time
  it was re-attached with `git switch claude/phase19-deferred-0c4fb6`. Check `git status -sb` before committing.

## Sheet fitting and the sheet re-measure (2026-11-27 to 11-28)

- `063a110d8` fits every floating form sheet (the iPad's) to its content through its preferred height, before the
  operating step, after it and after the settle, in the capture and the measuring mode (`SheetFitter`).
- Two defects found by the first re-measure (`remeasure-sheets/`, superseded), fixed in `abd193abd`, tests first:
  the preferred height compounded (the last preferred height plus the overflow, up to 23,111 pt for 1,841 pt of
  content, and negative once SwiftUI put its own back); it is now the content less the sheet's native offset. And the
  page behind a sheet set the need (a 9,257 pt reader behind `reader-settings-sheet`); the page of a sheet state is
  now the front-most sheet and what is presented over it, on both devices (owner: 「sheet 的狀況應當測量 sheet 內容」).
- A third, found by the full re-measure (`remeasure-sheets2/`), fixed in `4a40eebfb`, test first:
  `downloads-inspector` and `-error`, iPad landscape large, the four CJK locales, were `cannot-cover` at 836 pt.
  SwiftUI set the sheet's preferred height to 742.008 pt for 742.5 pt of content, under the fitter's one-pixel
  threshold in points, and UIKit laid the frame out a pixel short (762 pt for 762.5 pt; dump in `inspector-diag/`).
  The fitter now compares and sets the height in whole device pixels.
- Re-measure of the 30 sheet states over all 18 configurations: the iPhone (both orientations) in
  `remeasure-sheets2/phone`, the iPad after `4a40eebfb` in `remeasure-sheets3/` (`pad-portrait` lost six
  configurations to a wipe of `/private/tmp` and DerivedData mid-run, re-run as `pad-portrait-rest`). 0
  `did-not-converge`, 0 `error`. Against `remeasure-sheets2`'s iPad lines only the inspector's 16 lines changed (now
  834 pt) and `report-form-error-alert` moved by 1 to 2 pt both ways (its `VerticalTextView`, the TextEditor fix).
- What is left `cannot-cover` in the sheet states is decided already: the alerts and confirmation dialogs' own
  scroll view at accessibility5 (screen height), the Filters reset dialog's popover at accessibility5, the report
  form's `VerticalTextView` (Task 3's TextEditor fix), and the keyboard state `comments-post-filled` (removed).
- `reader-settings-sheet` now follows its own content: iPhone portrait 918/960/3,277, landscape 797/835/2,052, iPad
  portrait 1,210/1,210/2,735, landscape 856/898/2,735 (xSmall/large/accessibility5).
- `proposal-sheets.json`: `propose --runs phone-* pad-* remeasure/phone remeasure/pad-portrait remeasure/pad-landscape
  remeasure-sheets2/pad-portrait remeasure-sheets2/pad-landscape remeasure-sheets2/phone remeasure-sheets3/pad-portrait
  remeasure-sheets3/pad-portrait-rest remeasure-sheets3/pad-landscape` (later lines replace earlier), 132 states
  proposed, 1,621 finding lines (2,684 in `proposal-remeasure.json`). Task 3's verify `--runs` must list the same runs
  in the same order.

## Do not delete (local only, not in git)

- The worktree folder itself.
- `.capture/agent-work/phase19-26` (748 MB): the twelve input runs' `heights.jsonl` (`phone-*`, `pad-*`),
  `proposal.json` (the first proposal, kept for the record), `proposal-sheets.json` (the proposal put to the owner
  for approval, Task 3's `apply --proposal` input once approved; the verify command compares a regenerated copy with
  it), the sheet re-measures `remeasure-sheets`, `remeasure-sheets2` and `remeasure-sheets3`, the fitting's evidence
  `sheet-fit`, `sheet-diag`, `sheet-detect` and `inspector-diag`,
  `interrupted-pad-landscape-xSmall` (the set-aside partial run), the driver logs, `owner-answers.md` (the same
  answers as below), `site-settings-full` (the 7,600 pt site settings picture shown to the owner), and round 3's
  `recheck-notes.md`, `dnc-probe`, `error-recheck`, `freeze-debug` and `freeze-debug-pad`, the fixes' evidence
  `search-fix` and `freeze-fix`, the re-measure `remeasure` and `proposal-remeasure.json`, and round 4's
  `sheet-probe`.
- `.capture/agent-work/baseline2` (4.7 GB): the 19,512-picture baseline the storage projection and 19-12/19-13 use.
- `.capture/agent-work/baseline1`, `phase19-21` to `phase19-24`, `phase19-31`, `run-44279625701`: earlier plans'
  evidence cited by their records.
- The simulators `EhPanda iPhone Air (phase19)` and `EhPanda iPad Pro 11-inch (M5) (phase19)` and the iOS 27.2
  runtime they use (the measurements are 27.2 values, owner decision of 2026-11-25).

## Owner answers so far (verbatim)

Round 1, the four kinds of the plan's question:
- Kind 1 (states design §2 lists as `.screen` that measured taller): 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」
- Kinds 2 (cannot cover), 3 (keyboard), 4 (popover): 「給我看範例」. Examples shown were baseline2 pictures: iPad
  `downloads-inspector`, iPhone landscape accessibility5 `comments-block-confirmation`, iPhone
  `settings-pages-site-settings`; `search-typing-suggestions`, `comments-post-filled`; iPhone landscape
  `settings-pages-general-cache-confirmation`.

Round 2, a message in place of the answers:
「sheet 的狀況應當測量 sheet 內容
alert 組件不需要測量，所以只確認到存在 alert 就足夠
網站設定你沒給我看到高度到極限無法判斷

第三類拍不到鍵盤的話可以不拍這個狀態

第四類已經拍到 popover 存在，為什麼還要拉高？」

Site settings, after a picture at 7,600 pt (en, large, iPhone portrait, taken with a temporary height that was
reverted): 「整頁有拍到那 7,150 不就可以了嗎」

The role of the `page-height` check:
- 「page height check 應該是用來在制定 baseline 時輔助判斷的工具，而不是 gate 本身。baseline 確定以後就只有在拍攝新 snapshot 時才會用到了」
- Asked whether compare mode should fail, add a note, or not check; answered 「比對時不判失敗，只記一筆提示（建議）」, then
  superseded by 「snapshot testing 很單純，就是比較 snapshot diffs」, then 「但 baseline 必須覆蓋整頁 這樣才能捕捉到變化」.

## What the answers mean (stated to the owner, not contradicted)

- Reader states: keep the screen height, check skipped (`viewport-exempt`), because one screen shows their whole UI.
- Alerts and system confirmation dialogs, including `report-form-error-alert` and the dialogs whose text scrolls
  inside them at accessibility5: keep the screen height; it is enough that the alert is in the picture.
- Popovers whose control lies below the first screen: keep the current scrolled-to-control screen-height pictures.
- Keyboard states `search-typing-suggestions`, `front-page-search`, `comments-post-empty`, `comments-post-filled`:
  removed from the matrix (the capture cannot include the keyboard, which is in its own window).
- Sheets (the iPad form sheets that do not grow with the window): change the scenario so the sheet's own content is
  measured and captured in full. Design it and show the owner before building.
- First-launch states (`agewall-*`, `analytics-choice-*`): commit the measured heights (they do not fit one screen at
  accessibility5).
- Site settings: commit the page's own height (about 7,150 pt at large on the iPhone portrait). The measuring and the
  check read the empty "Excluded Uploaders" `TextEditor`'s internal content height, which grows with the window
  (need = window + 23 pt), so they must read the page's own content instead; tests first.
- The `page-height` check runs only when a baseline or a new snapshot is taken (candidate mode, including 19-27 and
  19-28's hosted runs A and B, so their H items stay valid); compare mode compares pictures only, with no height check
  and no note. Every approved baseline must cover the whole page. Write the owner's words into
  `19-FULL-PAGE-CAPTURE-DESIGN.md` and D-08 of `19-CONTEXT.md`; any screen-height exemption amends the owner's C4
  verdict ("這個適用於所有頁面") and must quote them.

Round 3 (2026-11-27), after a probe of the `did not converge` kinds and re-measures of the `error` states (evidence
in `.capture/agent-work/phase19-26/recheck-notes.md`, `dnc-probe`, `error-recheck`, `freeze-debug`, `freeze-debug-pad`):
- `app-wide-app-alert`: 「當 alert，維持螢幕高（建議）」. Keep it as an alert at the screen height. It fails with
  `no-keyboard` on every iPad landscape coordinate of the local 27.2 main simulator (portrait clones measure it, and
  the hosted 27.0 baseline2 holds all 144 pictures): a local environment problem, recorded, not a page defect.
- Menus (`comments-menu`, `favorites-category-menu`, `toplists-period-menu`,
  `settings-pages-activity-logs-run-picker`): the menu's own scroll view is sized by UIKit to the window, so the need
  is always the window plus a constant (+67 pt at large); at accessibility5 the menu scrolls inside itself. After the
  baseline2 accessibility5 pictures: 「選單可以按你推薦處理」. Keep the screen height; the menu's presence is enough.
- Search root (`search-root-empty`, `search-root-history`, `search-clear-confirmation`, the six `quick-search-*`
  states, and the two toasts, all drawn over the Search root): `SearchRootView`'s suggestions panel takes the scroll
  viewport's height as its `minHeight` (16-25, W-22, `49131e392`), then `.padding(.vertical)` adds 32 pt outside it,
  so the content is always the viewport plus 32 pt (a 2,500 pt window needs 2,532 pt) and an empty Search page
  scrolls 32 pt. Asked 「app 的邏輯有問題嗎？」, told yes, the owner chose 「修 App（建議）」: put the padding inside
  the floor, in its own commit, tests first, checking that W-22's title behaviour holds at every text size; then
  re-measure the eleven states.
- `freeze-changed-pixels` (archives, archives insufficient funds, downloads grid, favorites signed out, Quick Search
  empty): the native and frozen reads differ by rendering rounding only, one step on one channel (65 bytes on a card's
  1 pt border on the iPhone, one byte on the iPad), mostly in dark, once in light. The settle already counts such
  reads as the same still window (`readsMatch`); only the freeze check demands byte-identical reads (19-19 truth,
  design §2). First answer 「先查清楚再定高度」; after the cause: 「改用靜止判斷的規則（建議）」. The freeze check uses
  `readsMatch`, tests first (one-step noise passes, a reflow fails); amend the 19-19 rule with the owner's words;
  re-measure these states.
- The toasts' `settle-timeout:pixels` boxes are the toast itself, over the Search root; the reader states' errors are
  moot (screen height).
- Sheets `app-wide-error-info` and iPad `gallery-detail-sheet` (`did not converge`) fall under the sheet-content design.

Round 4 (2026-11-27), the sheet-content design, after a probe on the iPad (evidence in
`.capture/agent-work/phase19-26/sheet-probe` and `recheck-notes.md`; the temporary probe test was removed):
- What the probe showed: the iPad form sheet stays 580 x 660 pt whatever the window's height, so a sheet whose
  content is taller overflows at every height (`cannot-cover` on 21 iPad sheet states). Setting the presented
  controller's `preferredContentSize.height` once the presentation has finished resizes it (frame = preferred + 20 pt,
  clamped by UIKit to the window minus 32 pt above and below), and the measurement then converges.
- The design put to the owner: after the sheet is up and still, the harness sets the sheet's height; the window's
  height stays the committed source value and grows only when the content needs more than the screen; the iPhone's
  sheets already fill the window and are unchanged; a dialog opened over a sheet is opened by the operating step
  after the sheet is sized; a sheet whose content outgrows the window minus the margins fails the `page-height` check.
- Sheet height: 「貼合內容（建議）」. The sheet takes its content's height, never less than its own size (a sheet that
  fits today is unchanged, no blank below). Fitting takes a second pass (the List grew 912 to 935 pt once taller).
- `reader-settings-sheet`: 「當 sheet，整個內容都拍（建議）」. It leaves the reader's screen-height rule and is captured
  whole like the other sheets (needs today: iPhone 4,666 pt portrait, 10,201 pt landscape; iPad 9,500 to 14,500 pt).
- To check while building: `gallery-detail-sheet` is presented by Home's own `HomePaneSheet`, which sets the sheet's
  `preferredContentSize` from the viewport in the split layout.

## Open, to put to the owner (Taiwanese Mandarin, AskUserQuestion)

1. Approval of the heights to commit: `proposal-sheets.json` (132 states), together with the screen-height
   decisions already made (reader states, alerts and dialogs, menus, `app-wide-app-alert`, popovers) and the
   keyboard states' removal. The sheet fitting was built on 「開始實作」 and re-measured (above).

## Task 3 work the answers add (beyond the plan's text)

Amend `19-26-PLAN.md` with the owner's decisions before executing, then: the `viewport` case (plan `<behavior>`); the
keyboard states' removal (inventory, providers, matrix counts, shard plan, the storage projection); compare mode
without the `page-height` check (tests for both modes); the page need ignoring a `TextEditor`'s internal content
height (test first) and the re-measure of the states it touches (site settings, the report form, settings account);
the screen height for the menus and `app-wide-app-alert`; `apply` and `check-sources`; the verification sample and
timing ratio. Done already, each tests first: the freeze check using `readsMatch` (`4a87dc8b3`), the sheet fitting
(`063a110d8`, `abd193abd`, `4a40eebfb`) and their re-measures; outside 19-26, the Search root padding fix
(`86c47193b`) and the Filters Reset dialog fix (`eb8f4ee04`). Note for later, not
part of 19-26: the "Excluded Uploaders" editor's code asks for 30% of the container
height but renders one line tall in the tall window, a possible app layout defect.

## Re-running a measurement (if ever needed)

The drivers lived in a temporary scratchpad. The commands, from the repository root, with `W=.capture/agent-work/phase19-26`
and `CFG` one text size's six configurations (for example `en-large,de-large,ja-large,ko-large,zh-Hans-large,zh-Hant-large`):

```sh
CLASSES=$(python3 Scripts/visual/snapshot_shard.py classes | paste -sd, -)
Scripts/visual/run-snapshot-local.sh --device phone --simulator 'EhPanda iPhone Air (phase19)' --config "$CFG" --classes "$CLASSES" --measure-heights --workers 3 --out "$W/phone-<size>"
Scripts/visual/run-snapshot-local.sh --device pad --simulator 'EhPanda iPad Pro 11-inch (M5) (phase19)' --orientation portrait --config "$CFG" --classes "$CLASSES" --measure-heights --workers 3 --out "$W/pad-portrait-<size>"
Scripts/visual/run-snapshot-local.sh --device pad --simulator 'EhPanda iPad Pro 11-inch (M5) (phase19)' --orientation landscape --config "$CFG" --classes "$CLASSES" --measure-heights --out "$W/pad-landscape-<size>"
```

One run at a time; a full run takes 1 to 6.5 hours. Tests hit a 600 s cap (`Scripts/visual/run-shard.sh`), which cut
two very tall accessibility5 coordinates; a phone run with `--orientation landscape` halves each test's work.
