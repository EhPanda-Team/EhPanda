# Quick 261126-wzj: My Tags context menu, select mode, move and bulk delete

Owner request (2026-11-26): the native My Tags page should replace the site's /mytags page; the owner approved the
gap designs. This task covers the tags section's gaps. Branch `develop`; it runs after quick 261126-wzf lands (it
needs that task's per-set tag counts for the Move menu).

## The design (owner-approved 2026-11-26)

EhPanda App Design canvas, page "Screens v1.1.0", section 21, canvas version 1795703968-3cc3, and its behaviour file
`app/behavior/21-my-tags.md` in the local `ehpanda-design` repository (sections named below). The boards and the
behaviour file are the spec for layout, states and interaction; where they and this file differ on copy, this file
wins (the design's English is placeholder). Owner decisions that stay (2026-11-26): a swipe removes one tag at once
(D-05), a tag without a colour shows "No Color" (D-06), Enabled and Default Color save at once (no Save button), New
Tag Set starts empty. D-09 (My Tags hidden under Bypass SNI Filtering) is unchanged and out of scope.

Boards: `MyTags-Tags-States` (Context Menu, Select, 3 Selected, Move Menu, Delete Tags, Move Failed), `MyTagsView`
(component: `selecting`, `selected`), `MyTags-iPhone` and `MyTags-iPad` (Select toolbar item), `MyTags-iPad-States`.
Behaviour file sections: "Context menu", "Select, Move and Delete Tags".

## Site contract (the site's live `ehg_mytags.c.js`, read 2026-11-26)

`do_usertags_mass()` posts `form#usertag_form` with `usertag_action=mass`, one `modify_usertags[]=<tag id>` per
selected tag, and `usertag_target`: `0` deletes them, a tag set id moves them into that set (the button then reads
"Confirm Move"). `RemoveMyTagsRequest` already posts this form with target `0` for one id; it generalizes to a list
and a target. Deleting confirms first on the site ("Are you sure you wish to delete N tags from "<set>"?").

## Decisions (orchestrator, 2026-11-26; locked for planning)

- **J-1 Context menu.** A tag row's `.contextMenu`: Show Galleries (`magnifyingglass`), Edit (`square.and.pencil`,
  the app's existing Edit string), Select (`checkmark.circle`), a divider, Remove (`trash`, destructive, removes at
  once like the swipe, D-05). Show Galleries pushes the app's existing Detail Search for `namespace:"tag$"` (the
  query a tag tap in Detail makes) on the Settings stack, inside the Settings sheet on iPad; the planner finds how
  Settings can push it (the existing destination or a new one) and states it.
- **J-2 Select mode.** A text toolbar item `my_tags.select`, before Add Tag, shown only while the set has tags, starts
  `List` selection with edit mode; the context menu's Select starts it with that row selected. In select mode: rows
  show selection circles and no chevron, a tap toggles; swipe and context menu are off; the tag set section is
  disabled; the title is `my_tags.select_tags` or `my_tags.selected_count`; leading `my_tags.select_all` or
  `my_tags.deselect_all` when all are selected; trailing Done (the app's existing Done) ends it; no back button.
  iPhone hides the tab bar and shows a bottom toolbar: Move (`folder`, accessibility `my_tags.move`) leading, Delete
  (`trash`) trailing, both disabled with nothing selected; iPad shows the same toolbar at the bottom of the Settings
  sheet. Native APIs only (`List(selection:)`, `EditButton`-style edit mode, `.toolbar(.hidden, for: .tabBar)`,
  `ToolbarItem(placement: .bottomBar)`); no custom bars.
- **J-3 Move.** Move is a `Menu` with the header `my_tags.move_to` and every other set with its tag count
  (`my_tags.tag_count` / `my_tags.no_tags`); disabled when there is only one set. Choosing a set posts the mass form
  with that target; the loading view shows; on success the page shows the set without the moved tags and select mode
  ends. On failure select mode and the selection stay and the alert shows on the Move control (`my_tags.move_failed`,
  message the `#msg` text or the error's `alertText`).
- **J-4 Delete.** Delete presents a `.confirmationDialog` from the Delete button (title hidden), message
  `my_tags.delete_tags.message` (count and the set's name), destructive `my_tags.delete_tags` (count), Cancel. Then
  the mass form with target `0`, as J-3, failure alert `my_tags.delete_tags_failed` on the Delete control.
- **J-5 Success detection.** Success is no `#msg` reason and none of the sent tag ids left in the answer page's set;
  the answer page is taken into the cache. A refusal keeps the selection.
- **J-6 One request at a time.** While a move or delete is on its way, Move, Delete, Select All and Done are disabled.
- **J-7 Tests.** Reducer tests for entering and leaving select mode (toolbar and context menu), toggling, select all
  and deselect all, Move and Delete enabling, move success and failure, delete confirmation, success and failure, the
  in-flight guard; request tests for the mass form with several ids and a target; Show Galleries' push.

## Copy

Each locale was written by its own writer from the facts, then read by its own blind reviewer, then checked side
by side (2026-11-26). The executor copies the values verbatim and does not write or change copy. `{count}` marks the
number: a COUNT key becomes a labeled `%#@count@` substitution with an integer plural variable (CLAUDE.md "Labeled
localized-format arguments"; en/de `one` + `other`, ja/ko/zh-Hans/zh-Hant `other` only), so the generated symbol takes
`count:`. `%@` stays positional (a String). Zero tags never reaches `my_tags.tag_count`: the app shows
`my_tags.no_tags` for a set without tags. `…` is U+2026, zh-Hant `⋯` is U+22EF, German keeps the space before `…`,
apostrophes and quotes are the curly forms shown. If a key cannot be added exactly as specified, the executor stops
and reports. Edit, Done and Cancel reuse their existing keys; `my_tags.move` is the VoiceOver label of the Move button.

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `my_tags.select` | Select | Auswählen | 選択 | 선택 | 选择 | 選取 |
| `my_tags.select_tags` | Select Tags | Tags auswählen | タグを選択 | 태그 선택 | 选择标签 | 選取標籤 |
| `my_tags.selected_count` | one: {count} Tag Selected / other: {count} Tags Selected | one: {count} Tag ausgewählt / other: {count} Tags ausgewählt | other: {count}個を選択中 | other: {count}개 선택됨 | other: 已选择 {count} 个标签 | other: 已選取 {count} 個標籤 |
| `my_tags.select_all` | Select All | Alle auswählen | すべてを選択 | 모두 선택 | 全选 | 全選 |
| `my_tags.deselect_all` | Deselect All | Alle abwählen | すべての選択を解除 | 모두 선택 해제 | 取消全选 | 取消全選 |
| `my_tags.move` | Move | Verschieben | 移動 | 이동 | 移动 | 移動 |
| `my_tags.move_to` | Move to Tag Set | In Tag-Set verschieben | 移動先 | 이동할 태그 세트 | 移动到其他标签组 | 移到其他標籤組 |
| `my_tags.delete_tags.message` | one: Delete {count} tag from “%@”? / other: Delete {count} tags from “%@”? | one: {count} Tag aus dem Tag-Set „%@“ löschen? / other: {count} Tags aus dem Tag-Set „%@“ löschen? | other: タグセット「%@」から{count}個のタグを削除しますか？ | other: ‘%@’ 태그 세트에서 태그 {count}개를 삭제하시겠습니까? | other: 要从标签组“%@”中删除这 {count} 个标签吗？ | other: 要從「%@」刪除 {count} 個標籤嗎？ |
| `my_tags.delete_tags` | one: Delete Tag / other: Delete {count} Tags | one: {count} Tag löschen / other: {count} Tags löschen | other: {count}個のタグを削除 | other: 태그 {count}개 삭제 | other: 删除 {count} 个标签 | other: 刪除 {count} 個標籤 |
| `my_tags.move_failed` | Couldn’t Move Tags | Tags nicht verschoben | タグを移動できません | 태그를 이동하지 못함 | 无法移动标签 | 無法移動標籤 |
| `my_tags.delete_tags_failed` | Couldn’t Delete Tags | Tags nicht gelöscht | タグを削除できません | 태그를 삭제하지 못함 | 无法删除标签 | 無法刪除標籤 |
| `my_tags.show_galleries` | Show Galleries | Galerien mit diesem Tag anzeigen | このタグのギャラリーを表示 | 이 태그가 붙은 갤러리 보기 | 查看带有此标签的画廊 | 顯示含有此標籤的畫廊 |

## Rules

As for quick 261126-udx: CLAUDE.md / AGENTS.md, the root `.swiftlint.yml` first, no suppressions; `Feature` suffix;
dialog placement on the action source; scroll-edge policy unchanged; parallel tests; document the WHY; remove
emptied actions. One atomic signed commit per task, `TZ=Asia/Shanghai`, author and committer dates +08:00, subject
<= 50 characters, no attribution lines, nothing pushed. One `xcodebuild test` at a time (check `pgrep -x xcodebuild`
/ `pgrep -x xctest` first; another project's or session's run may be going, wait for it). Simulator "EhPanda iPhone
Air (phase19)", id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`. 0 warnings, lint `--strict` clean, test files included.
The live site cannot be exercised without the owner's account: the SUMMARY lists the owner's device checks.
