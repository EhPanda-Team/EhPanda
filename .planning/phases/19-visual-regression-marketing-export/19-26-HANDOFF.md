# 19-26 Handoff (2026-11-27)

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
- Task 2 (owner checkpoint) is in progress: the owner has answered most kinds (below); four points are open.
- Task 3 has not started. No provider file, source file, STATE.md or ROADMAP.md was changed for 19-26 yet.
- The worktree's HEAD was found detached on 2026-11-27 09:15 +0900 at the branch tip (cause unknown, nothing lost);
  it was re-attached with `git switch claude/phase19-deferred-0c4fb6`. Check `git status -sb` before committing.

## Do not delete (local only, not in git)

- The worktree folder itself.
- `.capture/agent-work/phase19-26` (286 MB): the twelve input runs' `heights.jsonl` (`phone-*`, `pad-*`),
  `proposal.json` (Task 3's `apply --proposal` input; the verify command compares a regenerated copy with it),
  `interrupted-pad-landscape-xSmall` (the set-aside partial run), the driver logs, `owner-answers.md` (the same
  answers as below), and `site-settings-full` (the 7,600 pt site settings picture shown to the owner).
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

## Open, to put to the owner (Taiwanese Mandarin, AskUserQuestion)

1. `app-wide-app-alert` is both an alert and a keyboard state: keep it as an alert at the screen height
   (recommended) or remove it. Asked once; the owner answered other points instead.
2. The 17 `did not converge` states (`19-26-HEIGHTS.md` "## Findings"). Site settings showed the measuring can be
   misled by a view that grows with the window; check each kind first with one picture at a fixed height (temporary
   `.committed` height in the provider, `run-snapshot-local.sh --mode candidate` for one configuration, then revert),
   and bring a picture per kind with a recommendation. 19-30-SUMMARY notes constant offsets (+32 pt, +67 pt) for some.
3. The 10 `error` states (settle timeouts, `freeze-changed-pixels`, iPad landscape `interaction:no-keyboard`): read
   the logs, sort real defects from measuring flukes, then ask.
4. Approval of the heights to commit, after 1 to 3 decide which states keep the screen height.

## Task 3 work the answers add (beyond the plan's text)

Amend `19-26-PLAN.md` with the owner's decisions before executing, then: the `viewport` case (plan `<behavior>`); the
keyboard states' removal (inventory, providers, matrix counts, shard plan, the storage projection); compare mode
without the `page-height` check (tests for both modes); the page need ignoring a `TextEditor`'s internal content
height (test first); the sheet-content design (owner first); `apply` and `check-sources`; the verification sample and
timing ratio. Note for later, not part of 19-26: the "Excluded Uploaders" editor's code asks for 30% of the container
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
