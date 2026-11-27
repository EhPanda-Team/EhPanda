# Quick 261126-wzf: My Tags tag set rename and the expired session

Owner request (2026-11-26): the native My Tags page should replace the site's /mytags page; the owner approved the
gap designs. This task covers the tag set section's gaps. Branch `develop`; it runs after quick 261126-udx (Delete
Tag Set) lands and builds on it.

## The design (owner-approved 2026-11-26)

EhPanda App Design canvas, page "Screens v1.1.0", section 21, canvas version 1795703968-3cc3, and its behaviour file
`app/behavior/21-my-tags.md` in the local `ehpanda-design` repository (sections named below). The boards and the
behaviour file are the spec for layout, states and interaction; where they and this file differ on copy, this file
wins (the design's English is placeholder). Owner decisions that stay (2026-11-26): a swipe removes one tag at once
(D-05), a tag without a colour shows "No Color" (D-06), Enabled and Default Color save at once (no Save button), New
Tag Set starts empty. D-09 (My Tags hidden under Bypass SNI Filtering) is unchanged and out of scope.

Owner decisions on the first plan (2026-11-27), which override the boards where they differ:
- The rename field starts with the set's name filled in, not selected (the cursor at its end, the user edits it).
  Selecting it would need a keyboard-notification workaround on iOS 27, which the owner declined.
- The Tag Set picker stays the native menu `Picker` with the names alone; it shows no tag counts. A menu `Picker` drops
  a row's second line on iOS 27 and the owner declined imitating the picker's row. The design session updates the
  boards. Reading each set's count moves to quick 261126-wzj, whose Move menu (a native `Menu`) shows it, together
  with the `my_tags.tag_count` and `my_tags.no_tags` copy.

Boards: `MyTags-TagSet-States` (Rename Tag Set, Rename Failed), `MyTagsView` (component: the "Rename Tag
Set…" row after "New Tag Set…", before "Delete Tag Set"), `MyTags-iPad-States`, `MyTags-States` (Signed out).
Behaviour file sections: "Rename Tag Set", "MyTags-States".

## Site contract (the site's live `ehg_mytags.c.js`, read 2026-11-26)

- Rename: `do_tagset_rename()` prompts, then sets the hidden `tagset_name` to the new name and `do_tagset_post("rename")`:
  `form#tagset_form` posts `tagset_action=rename`, `tagset_name=<name>`, `tagset_enable=on` when the shown set's box
  is checked, `tagset_color` (the shown set's colour or ""), to the shown set's `/mytags[?tagset=<n>]`. The same form
  the update, create and delete requests post (one field builder already serves them after 261126-udx).
- An API answer with a `login` key means the session expired (the site's `api_response` then goes to the login page).
  A form page answered while signed out: what it looks like is unknown without the account; the existing signed-out
  detection is to be reused, not guessed.

## Decisions (orchestrator, 2026-11-26; locked for planning)

- **W-1 Rename row and alert.** "Rename Tag Set…" is a tint button row after "New Tag Set…". It presents the app's
  `appAlert` with a text field, focused, the selected set's name filled in and not selected (owner 2026-11-27). Rename
  is disabled while the trimmed name is empty or equal to the current name; the reducer refuses those too. Cancel
  closes it. The field's prompt reuses `my_tags.new_tag_set.name`. The row is disabled while a create, rename or
  delete is on its way (extend 261126-udx's shared in-flight flag; one such request at a time). Its failure alert
  attaches to the row through a new `AlertSource` case.
- **W-2 Rename request.** `RenameMyTagSetRequest` posting the contract's fields in order, answering the parsed page.
  Retried or not: the planner checks whether a replay could rename twice harmfully (it cannot: same name) and states
  it; prefer the same `attempts` reasoning as the create and delete, documented.
- **W-3 After a rename.** The picker shows the new name at once (optimistic), the tags stay. The answer page is taken
  into the cache; success is no `#msg` reason and the set listed under the new name. On failure the old name returns
  and the alert shows (title `my_tags.rename_failed`, message the `#msg` text or the error's `alertText`).
- **W-4 Tag counts.** Removed by the owner (2026-11-27): the picker shows no counts; see above.
- **W-5 Expired session.** When a read or write answers that the session is no longer signed in (an API `login` answer,
  or the signed-out state the app already detects), the page shows its existing Signed out state (`NotLoginView`,
  whose Log In opens login and reloads after it), not a generic error alert. The planner finds where each request's
  answer is decoded today (`Request+MyTags.swift`) and maps the `login` answer to a dedicated, existing-or-new
  `AppError` case the feature turns into the signed-out state; it does not guess a form-page shape.
- **W-6 Tests.** Reducer tests for rename (opens with the name, disabled when empty or unchanged, success keeps the new
  name, refusal and failure restore the old name and alert, in-flight flag), request tests for the fields and order,
  and a test that a `login` answer leads to the signed-out state.

## Copy

Each locale was written by its own writer from the facts, then read by its own blind reviewer, then checked side
by side (2026-11-26). The executor copies the values verbatim and does not write or change copy. `…` is U+2026, zh-Hant `⋯` is U+22EF, German keeps the space before `…`,
apostrophes and quotes are the curly forms shown. If a key cannot be added exactly as specified, the executor stops
and reports.

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `my_tags.rename_tag_set` | Rename Tag Set… | Tag-Set umbenennen … | タグセット名を変更… | 태그 세트 이름 변경… | 重命名标签组… | 重新命名標籤組⋯ |
| `my_tags.rename_tag_set.title` | Rename Tag Set | Tag-Set umbenennen | タグセット名を変更 | 태그 세트 이름 변경 | 重命名标签组 | 重新命名標籤組 |
| `my_tags.rename_tag_set.message` | Enter a new name for this tag set. | Gib einen neuen Namen für dieses Tag-Set ein. | このタグセットの新しい名前を入力してください。 | 이 태그 세트의 새 이름을 입력하십시오. | 为此标签组输入新名称。 | 輸入這個標籤組的新名稱。 |
| `my_tags.rename` | Rename | Umbenennen | 変更 | 변경 | 重命名 | 重新命名 |
| `my_tags.rename_failed` | Couldn’t Rename Tag Set | Tag-Set nicht umbenannt | タグセット名を変更できません | 태그 세트 이름을 변경하지 못함 | 无法重命名标签组 | 無法重新命名標籤組 |

## Rules

As for quick 261126-udx: CLAUDE.md / AGENTS.md, the root `.swiftlint.yml` first, no suppressions; `Feature` suffix;
dialog placement on the action source; scroll-edge policy unchanged; parallel tests; document the WHY; remove
emptied actions. One atomic signed commit per task, `TZ=Asia/Shanghai`, author and committer dates +08:00, subject
<= 50 characters, no attribution lines, nothing pushed. One `xcodebuild test` at a time (check `pgrep -x xcodebuild`
/ `pgrep -x xctest` first; another project's or session's run may be going, wait for it). Simulator "EhPanda iPhone
Air (phase19)", id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`. 0 warnings, lint `--strict` clean, test files included.
The live site cannot be exercised without the owner's account: the SUMMARY lists the owner's device checks.
