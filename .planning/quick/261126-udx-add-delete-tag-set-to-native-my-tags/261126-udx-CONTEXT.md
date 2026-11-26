# Quick 261126-udx: add Delete Tag Set to the native My Tags page

Owner request (2026-11-26): "check the latest artifact and implement the delete tag set feature." Branch `develop`;
commits go on top, nothing is rewritten, nothing is pushed. This lifts quick 261126-pfh N-7's "deleting sets stays
out of scope" for deleting only; renaming stays out of scope.

## The design (owner-provided, EhPanda App Design canvas, page "Screens v1.1.0")

- `MyTagsView` (component): the tag set section ends with **New Tag Set…** and then **Delete Tag Set**, a destructive
  row shown only while the site offers to delete the selected set (`canDeleteTagSet`).
- `MyTags-States`, cell "Delete Tag Set": Set 2, an empty set, with the confirmation dialog the row presents from
  itself (on iPad a popover whose arrow points at the row): message "Delete this tag set?", the destructive Delete and
  Cancel (a popover draws no cancel button; a tap outside cancels). No title. Switches and menu pickers dim while it
  is up (the system does this). Delete asks the site to delete the set; the page then selects the site's first set
  and loads it.

## The site contract (read 2026-11-26 from the site's live `ehg_mytags.c.js`)

`do_tagset_delete()` confirms, then `do_tagset_post("delete")`: it sets the hidden `tagset_action` to `delete` and
submits `form#tagset_form` (`method="post"`, `action=""`, so it posts to the shown set's `/mytags[?tagset=<n>]`). The
browser sends the form's fields in order: `tagset_action=delete`, `tagset_name=` (the hidden field, empty, as with
`update`), `tagset_enable=on` only when the shown set's box is checked, and `tagset_color` (the shown set's colour,
`""` or `#RRGGBB`). This is the form `UpdateMyTagSetRequest` and `CreateMyTagSetRequest` already post.

The page offers deleting through a button in `#tagset_outer` whose `onclick` calls `do_tagset_delete()`, beside New
and Rename. Which sets the site offers it for (for example only empty sets, never the first) is not knowable without
the owner's account, so the app must not guess a rule: it shows the row exactly when the shown set's page carries
that control. The synthetic fixtures carry no such control today; a new synthetic fixture (no account data) carries
it. What page the site answers a delete with, and its refusal wording, are also unknown; a refusal is expected as a
page with the reason in `#msg`, like the other form posts.

## Decisions (orchestrator, 2026-11-26; locked for planning)

- **U-1 The offer.** The parser reads whether the shown set's page offers deleting (a control in the tag set form whose
  `onclick` calls `do_tagset_delete`). Where the app keeps that per set is the planner's call, stated with its reason;
  it must not break decoding of the persisted `User.myTags` cache (`MyTagSet` is `Codable` and stored), and a set the
  app has no fresh page for shows no row.
- **U-2 Row.** In `MyTagsView`'s tag set section, after New Tag Set…, a `Button(role: .destructive)` labelled
  `my_tags.delete_tag_set`, present only when U-1 says the selected set is offered. It is the action source of the
  confirmation dialog and of its failure alert, so both attach to this row (AGENTS.md dialog placement), the failure
  alert through a new `AlertSource` case.
- **U-3 Confirmation.** A TCA `ConfirmationDialogState`, `titleVisibility: .hidden`, title `.RLocalizable.delete`,
  message `my_tags.delete_tag_set.message`, buttons Delete (`.RLocalizable.delete`, destructive, sends the delete) and
  Cancel (`.RLocalizable.cancel`, cancel), as `EhSettingReducer`'s Delete Profile does.
- **U-4 One request at a time.** While a create or a delete is on its way, both New Tag Set… and Delete Tag Set are
  disabled (a delete landing during a create would confuse the create's new-id detection, and the reverse).
- **U-5 Request.** A new `DeleteMyTagSetRequest` in `Request+MyTags.swift`, beside the create, posting the fields of
  the contract in order to the shown set's URL, with `attempts: 1` and a doc comment saying why (a replay after a lost
  answer finds the set gone and would surface a refusal for a delete that succeeded). `MyTagsClient` gains
  `deleteTagSet` (live, test and `failing`, like its siblings).
- **U-6 After the answer.** The answer page is taken into the cache. Success: no `#msg` reason and the deleted id is
  no longer in the answer's picker. Then the page selects the site's first listed set (kept with the cache, as
  `tagSetSelected` does) and shows it: from the answer page if that is the set it shows, else through the existing
  `fetchTagSet` path with the loading view. Failure: a `#msg` reason, or the id still listed, or a failed request,
  keeps the selection and shows the failure alert on the row: title `my_tags.delete_tag_set_failed`, message the
  `#msg` text, else the error's `alertText` (for the id still listed, the same `AppError` the create uses when no new
  id appears, for the same reason).
- **U-7 Scope.** No rename. iPad gets the same row and dialog in the Settings sheet with no separate work.
- **U-8 Tests.** Reducer tests (TestStore, parallel, isolated storage): the row shows only for an offered set; the row
  opens the dialog; Delete posts and then selects and shows the first set (both the answer-page and the fetch path);
  `#msg`, id-still-listed and a failed request show the failure alert and keep the selection; Cancel sends nothing;
  the rows are disabled while a create or a delete is on its way. A request test for the fields and their order. A
  parser test for the offer, with and without the control.
- **U-9 Live check.** Deleting cannot be exercised without the owner's account; the SUMMARY lists it as the owner's
  device check (which sets the site offers it for, and what page it answers with).

## Copy

Each locale is written by its own writer from the facts, then read by its own blind reviewer. Final values are in
the table below; the executor copies them verbatim into `SettingFeature`'s `Localizable.xcstrings` and does not
write or change copy.

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `my_tags.delete_tag_set` | Delete Tag Set | Tag-Set löschen | タグセットを削除 | 태그 세트 삭제 | 删除标签组 | 刪除標籤組 |
| `my_tags.delete_tag_set.message` | Delete this tag set? | Dieses Tag-Set wirklich löschen? | このタグセットを削除しますか？ | 이 태그 세트를 삭제할까요? | 确定要删除这个标签组吗？ | 確定要刪除這個標籤組嗎？ |
| `my_tags.delete_tag_set_failed` | Couldn’t Delete Tag Set | Tag-Set nicht gelöscht | タグセットを削除できません | 태그 세트를 삭제하지 못함 | 无法删除标签组 | 無法刪除標籤組 |

String values only, no format arguments; the apostrophe is U+2019, the Japanese and Chinese question marks are
full-width (U+FF1F), the Korean one is ASCII, as in each locale's existing strings. If a key cannot be added as
specified, the executor stops and reports.

## Rules

As for quick 261126-pfh: CLAUDE.md / AGENTS.md, the root `.swiftlint.yml` first, no suppressions; `Feature` suffix;
dialog placement on the row; scroll-edge policy unchanged; parallel tests; document the WHY; remove emptied actions.
One atomic signed commit per task, `TZ=Asia/Shanghai`, author and committer dates +08:00, subject <= 50 characters,
no attribution lines, nothing pushed. One `xcodebuild test` at a time (check `pgrep -x xcodebuild` / `pgrep -x
xctest` first; another project's run may be going, wait for it). Simulator "EhPanda iPhone Air (phase19)", id
`19DB23C0-8C35-49C7-9A7D-5D99566BF092`. 0 warnings, lint `--strict` clean, test files included.
