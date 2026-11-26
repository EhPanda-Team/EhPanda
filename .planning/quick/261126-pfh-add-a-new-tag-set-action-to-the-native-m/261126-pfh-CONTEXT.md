# Quick 261126-pfh: add a New Tag Set action to the native My Tags page

Owner request (2026-11-26): "i've the design session made an ui for you, implement the add new tag set feature".
Branch `develop`; commits go on top, nothing is rewritten, nothing is pushed. This lifts the "creating sets stays out of
scope" line of quick 261122-fv8 D-08 for creating only; renaming and deleting sets stay out of scope.

## The design (owner-provided, EhPanda App Design canvas, page "Screens v1.1.0")

- `MyTagsView`: the tag set section (Tag Set picker, Enabled, Default Color) gains a last row, **New Tag Set…**, drawn
  as a tint-coloured button row. The section footer stays as it is.
- `MyTags-NewTagSet-iPhone`: the row presents the app's `appAlert` with its text field, focused, so the keyboard is up
  and the alert sits above it. Title "New Tag Set", message "Enter a name for this tag set.", the field with the prompt
  "Name". Cancel closes it. Create (disabled while the trimmed name is empty) asks the site to create the set, then the
  page selects it and loads it: a new set has no tags, so the tags section shows the existing empty state
  (`MyTags-States`, "No Tags Yet" with Add Tag) under the tag set section.

## The site contract (read 2026-11-26 from the site's live `ehg_mytags.c.js`)

`do_tagset_create()` prompts for a name, then `do_tagset_post("create")`: it sets the hidden `tagset_action` to
`create` and the hidden `tagset_name` to the name, and submits `form#tagset_form` (`method="post"`, `action=""`, so it
posts to the page's own URL, `/mytags` or `/mytags?tagset=<n>` of the set being shown). A browser sends that form's
fields in order: `tagset_action`, `tagset_name`, `tagset_enable=on` only when the shown set's box is checked, and
`tagset_color` (the shown set's colour, `""` or `#RRGGBB`); the picker `<select>` has no name and is not sent. This is
the same form `UpdateMyTagSetRequest` already posts with `tagset_action=update`.

Not knowable without the owner's signed-in account, so the implementation must not depend on it: what page the site
answers a create with (the new set's page through a redirect, or the shown set's page), and any limit on the number or
names of sets. A refusal is expected to come back like the other form posts, as a page with the reason in `#msg`.

## Decisions (orchestrator, 2026-11-26; locked for planning)

- **N-1 Row.** `MyTagsView`'s tag set section gets a last row, a `Button` with the label `my_tags.new_tag_set`, in the
  section like the other rows (tint-coloured text, no chevron). It sends a new action that presents the alert. It is
  disabled while a create is on its way. It is the action source of the alert and of its failure alert, so both attach
  to this row (AGENTS.md dialog placement), through a new `AlertSource` case for the failure alert.
- **N-2 Alert.** An `AppAlertState` with a text field: title `my_tags.new_tag_set.title`, message
  `my_tags.new_tag_set.message`, field placeholder `my_tags.new_tag_set.name`, buttons Create
  (`my_tags.new_tag_set.create`, sends the create) and Cancel (`.RLocalizable.cancel`, role cancel). The name lives in
  the feature's state, bound through `appAlert(_:text:)` as the page-jump alert does, and is empty each time the alert
  opens. The field is focused by the existing modifier.
- **N-3 Create disabled while the trimmed name is empty.** `appAlert` cannot disable a button today. Extend the shared
  component, not a local workaround: `AppAlertTextFieldState` gains an option (named by the planner) that disables
  every non-cancel button while the field's text, trimmed of whitespace and newlines, is empty. Default off, so the
  page-jump alert is unchanged. Document the WHY. The reducer also refuses an empty trimmed name (defence in depth).
- **N-4 Request.** A new `CreateMyTagSetRequest` in `Request+MyTags.swift`, beside `UpdateMyTagSetRequest`, posting the
  browser's fields in the browser's order to `Defaults.URL.myTags(host:tagSetID:)` of the shown set: `tagset_action=
  create`, `tagset_name=<trimmed name>`, `tagset_enable=on` when the shown set is enabled, `tagset_color=<the shown
  set's colour or "">`. It answers the parsed page like the other form posts. `MyTagsClient` gains `createTagSet` (live,
  test and `failing` values like its siblings). The file's header note on replaying writes does not cover a create (a
  replayed create could make two sets): the planner checks how `fetch` retries a POST and states in the request's doc
  comment what a retry does here; if a retry could duplicate the set, this request must not be retried.
- **N-5 Finding the new set.** The site's answer page is taken into the cache (`take`), and the new set is the id its
  picker lists that the cache did not have before the post. With exactly one such id, the page selects it (the
  selection is kept with the cache, as `tagSetSelected` does) and loads it through the existing `fetchTagSet` path, so
  the loading view shows until its (empty) page arrives, and the set's name, Enabled and colour come from the site.
  When the page carries a `#msg` reason, or no new id appears, nothing is selected and the failure alert shows: title
  `my_tags.create_tag_set_failed`, message the `#msg` text, else a fitting existing `AppError`'s `alertText` (the
  planner picks the error case and says why). A failed request shows the same alert with the error's `alertText`.
- **N-5a More than one new id** (orchestrator, after planning): possible only when another client made a set while
  the page was open. Nothing is selected, no failure alert shows (a set was made), and every set is read again with
  `fetchMyTags`, as the plan specifies.
- **N-6 Picker after create.** The picker lists the new set by the name the site gives it, from the loaded page. While
  `MyTags.applying(_:)` drops a set the cache lacks ("stays out until the next fetch"), the new set must not be lost:
  the planner makes the new id reach `tagSets` (for example by loading it with `fetchTagSet` and inserting its page in
  the picker's order) without changing `applying(_:)`'s contract for the other callers, or states why it is changed.
- **N-7 Scope.** No rename, no delete, no change to Add to My Tags elsewhere in the app. iPad pushes the same page in
  the Settings sheet, so it gets the row and alert with no separate work.
- **N-8 Tests.** Reducer tests (TestStore, parallel, isolated storage) for: the row opens the alert with an empty name;
  Create with a name posts it and then selects and loads the new set; a `#msg` refusal and a failed request show the
  failure alert on the row and select nothing; an empty or whitespace name sends nothing. A request test for the posted
  fields and their order (the existing request tests show how), and a parser fixture only if a new page shape is
  needed (synthetic, no account data). A test for the alert option of N-3 if the component has tests of its kind.
- **N-9 Live check.** The create cannot be exercised against the site without the owner's account; it is not done by
  the executor. The SUMMARY lists it as the owner's device check (create a set, see it selected and empty, see it on
  the site).

## Copy (final; each locale written by its own writer from the facts, then read by its own blind reviewer)

All keys are module-local to `SettingFeature`'s `Localizable.xcstrings` unless the planner finds a key must be shared.
String values only, no format arguments. Store `…` as U+2026 and zh-Hant's `⋯` as U+22EF, exactly as below; German
keeps the plain space before `…`, as the app's other German strings do.

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `my_tags.new_tag_set` | New Tag Set… | Neues Tag-Set … | 新規タグセット… | 새 태그 세트… | 新建标签组… | 新增標籤組⋯ |
| `my_tags.new_tag_set.title` | New Tag Set | Neues Tag-Set erstellen | 新規タグセット | 새 태그 세트 | 新建标签组 | 新增標籤組 |
| `my_tags.new_tag_set.message` | Enter a name for this tag set. | Gib einen Namen für das neue Tag-Set ein. | 新しいタグセットの名前を入力してください。 | 이 태그 세트의 이름을 입력하십시오. | 为新标签组输入名称。 | 輸入新標籤組的名稱。 |
| `my_tags.new_tag_set.name` | Name | Name | タグセット名 | 이름 | 标签组名称 | 標籤組名稱 |
| `my_tags.new_tag_set.create` | Create | Erstellen | 作成 | 생성 | 创建 | 建立 |
| `my_tags.create_tag_set_failed` | Couldn’t Create Tag Set | Tag-Set nicht erstellt | タグセットを作成できません | 태그 세트를 생성하지 못함 | 无法创建标签组 | 無法建立標籤組 |

The executor copies these values verbatim; it does not write or change copy. If a key cannot be added as specified,
it stops and reports.

## Rules

- Follow `CLAUDE.md` / `AGENTS.md`: read the root `.swiftlint.yml` first, no suppressions; `Feature` suffix for any new
  reducer; dialog placement (on the row); scroll-edge policy unchanged; parallel tests (no `.serialized`); document the
  WHY of deliberate designs; remove emptied actions.
- One atomic commit per task, signed, `TZ=Asia/Shanghai`, author and committer dates +08:00, subject <= 50 characters,
  no attribution lines. Nothing is pushed.
- One `xcodebuild test` at a time (check `pgrep -x xcodebuild` / `pgrep -x xctest` first; another project's run may be
  going, wait for it). Simulator "EhPanda iPhone Air (phase19)", id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`. Tests:
  `xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=…' -only-testing:<Target>`.
- 0 warnings, lint clean (`--strict`), including the test files.
