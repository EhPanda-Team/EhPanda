---
phase: 261126-wzf-my-tags-tag-set-rename-counts-and-sessio
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/AppModels/Tags/MyTags.swift
  - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift
  - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
  - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift
  - AppPackage/Tests/AppModelsTests/MyTagsTests.swift
  - AppPackage/Sources/AppComponents/AppAlertState.swift
  - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift
  - AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Tests/SettingFeatureTests/MyTagsRenameTests.swift
  - AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift
  - AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift
  - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
  - AppPackage/Tests/SettingFeatureTests/MyTagsSessionTests.swift
autonomous: true
requirements: [W-1, W-2, W-3, W-5, W-6]

estimate:
  tokens: 170000
  raw_tokens: 170000
  tasks: 4
  confidence: low

must_haves:
  truths:
    - "My Tags has a tint `Rename Tag Set…` row after `New Tag Set…` and before Delete Tag Set; it opens the app's text-field alert with the shown set's name filled in, focused and not selected; Rename is disabled while the trimmed name is empty or still the set's name, the reducer refuses both, Cancel closes it, and the row is disabled while a create, a rename or a delete is on its way (W-1)."
    - "Rename posts the shown set's form to its page once, its fields in order: `tagset_action=rename`, `tagset_name=<new name>`, `tagset_enable=on` when the set is enabled, `tagset_color` (W-2)."
    - "The picker shows the new name at once and the tags stay; the answer page is taken into the cache; a `#msg` reason, an answer that lists the set under another name or shows another set, or a failure, leaves the old name (or the site's) in place and shows `my_tags.rename_failed` on the Rename row with the reason or the error's text (W-3)."
    - "The Tag Set picker stays the native menu `Picker` with the names alone, unchanged (owner, 2026-11-27)."
    - "An edit API answer with a non-null `login` fails as `loginRequired`; a My Tags read or write that fails as `loginRequired` shows the page's existing Log In view instead of an error or an alert; Edit Tag keeps its alert and tells the page, which shows Log In beneath it; after a sign-in from that view every set is read again (W-5)."
    - "The rename, session, editor, request and model tests listed in the tasks pass in parallel, and the five copy keys carry CONTEXT's values in all six locales (W-6, Copy)."
  artifacts:
    - path: "AppPackage/Sources/AppModels/Tags/MyTags.swift"
      provides: "The rename of one set in the cache, for the optimistic name and its rollback"
      contains: "public func renaming(_ tagSetID: Int, to name: String) -> MyTags"
    - path: "AppPackage/Sources/NetworkingFeature/Request+MyTags.swift"
      provides: "The rename request, and the edit API's login answer read as loginRequired"
      contains: "public struct RenameMyTagSetRequest: Request"
    - path: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      provides: "renameTagSet in live, noop, unimplemented and failing"
      contains: "public var renameTagSet: @Sendable ("
    - path: "AppPackage/Sources/AppComponents/AppAlertState.swift"
      provides: "A text-field alert that edits a value holds its buttons while the value is unchanged"
      contains: "public var editedValue: String?"
    - path: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      provides: "The rename flow and the signed-out state of an ended session"
      contains: "public var isSessionExpired: Bool { loadingState == .failed(.loginRequired) }"
    - path: "AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift"
      provides: "The Rename row with its alerts, and Log In for an ended session"
      contains: "Button(.myTagsRenameTagSet)"
    - path: "AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift"
      provides: "Edit Tag tells its host that the session ended"
      contains: "case signedOut"
    - path: "AppPackage/Sources/SettingFeature/SettingReducer+Body.swift"
      provides: "A sign-in reads every My Tags page on the stack again"
      contains: ".merge(myTagsReads)"
    - path: "AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings"
      provides: "The five rename copy keys"
      contains: "\"my_tags.rename_failed\" : {"
  key_links:
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      to: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      via: "the presented rename asks myTagsClient.renameTagSet(host, name, tagSet)"
      pattern: "try await myTagsClient\\.renameTagSet\\(host, name, tagSet\\)"
    - from: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      to: "AppPackage/Sources/NetworkingFeature/Request+MyTags.swift"
      via: "live renameTagSet builds RenameMyTagSetRequest"
      pattern: "RenameMyTagSetRequest\\(host: host, name: name, tagSet: tagSet\\)"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      to: "AppPackage/Sources/AppComponents/AppAlertState.swift"
      via: "the rename alert's field edits the set's name, which holds Rename until it changes"
      pattern: "editedValue: tagSet\\.name"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift"
      to: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      via: "the content shows NotLoginView while signed out or once the session ended"
      pattern: "if !didLogin \\|\\| store\\.isSessionExpired \\{"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      to: "AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift"
      via: "Edit Tag's signedOut delegate puts the page in its signed-out state"
      pattern: "case \\.destination\\(\\.presented\\(\\.editor\\(\\.delegate\\(\\.signedOut\\)\\)\\)\\):"
    - from: "AppPackage/Sources/SettingFeature/SettingReducer+Body.swift"
      to: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      via: "loginDone sends fetchMyTags to every My Tags page on the stack"
      pattern: "action: \\.myTags\\(\\.fetchMyTags\\)"
---

## Blocking questions

None. W-1 to W-3, W-5, W-6 and the copy table are planned as CONTEXT now states them; W-4 was removed by the owner
(2026-11-27) and moves to quick 261126-wzj. Revised 2026-11-27 on the owner's decisions: the rename field is not
selected and the Tag Set picker stays as it is. The planner readings P-1 to P-19 below keep their numbers; the ones
the owner's decisions withdrew say so. Three of them touch what the owner sees or must check and are called out again
in the Output: P-9 (how a rename's answer is judged), P-15 (Edit Tag keeps its alert, Log In shows beneath it) and
P-17 (form pages keep the existing signed-out detection, which the owner's account has to confirm).

<objective>
Close the tag set gaps of the native My Tags page exactly as CONTEXT's locked decisions W-1 to W-3, W-5 and W-6 and
its copy table say, in four signed commits on top of `develop` after quick 261126-wzg (nothing pushed):

1. `RenameMyTagSetRequest`, `MyTagsClient.renameTagSet` and the cache's rename (W-2, W-3).
2. The Rename Tag Set row and its alert, with the new name shown at once and put back on failure (W-1, W-3; the
   five rename copy keys).
3. Edit Tag and the edit API: a `login` answer fails as `loginRequired` and the sheet tells its host (W-5).
4. The My Tags page shows Log In for an ended session and reads every set again after a sign-in (W-5).

Every task carries its tests (W-6). The Tag Set picker is not touched (owner, 2026-11-27).

Purpose: the native page offers what the site's tag set form offers, so it can replace the site's /mytags page.
Output: four signed `+08:00` commits; `261126-wzf-SUMMARY.md` (not committed) listing the owner's device checks.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/261126-wzf-my-tags-tag-set-rename-counts-and-sessio/261126-wzf-CONTEXT.md
@.planning/STATE.md
@CLAUDE.md
@.swiftlint.yml

### Execution fidelity (applies to every step)

Follow this plan exactly. If anything cannot be done exactly as written (ambiguity, conflicting requirements, missing
information, unexpected repository state, an anchor below not found exactly once, a compiler error or lint rule that
forces a different shape, a test that fails, a gate that prints anything but its EXPECT value, a copy value that
differs from CONTEXT, a needed user-facing string, or any other deviation), stop immediately and ask the orchestrator.
Do not choose, invent or implement a solution on your own. The only latitude: re-wrapping comment prose this plan
gives when a line would pass 120 columns (the wording is fixed).

### Precondition (check before Task 1; halt if it does not hold)

- Quick 261126-wzg has landed: `git merge-base --is-ancestor 4b8fdf6ba HEAD && echo landed` prints `landed`, and
  `grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'suggestTags:'` prints `5`.
- `git status --short` prints nothing but paths under
  `.planning/quick/261126-wzf-my-tags-tag-set-rename-counts-and-sessio/` and
  `.planning/quick/261126-wzj-my-tags-select-move-and-context-menu/` (or nothing at all once the orchestrator has
  committed them).
- `grep -rn 'RenameMyTagSetRequest\|renameTagSet\|isSessionExpired\|editedValue' AppPackage | wc -l` prints `0`, and
  `grep -rn 'my_tags.rename' AppPackage | wc -l` prints `0`.
- `python3 -I Scripts/lint/app_storage_isolation.py check` prints `0 break(s) of the app-storage isolation rule.`
- Record `git rev-parse --short HEAD` as BASE in the SUMMARY; the final invariant gates diff against it.

### Where and how you work

- This checkout, branch `develop` (HEAD `2b3c2baef` when this plan was written, plus the orchestrator's planning
  commits). New commits go on top; no new branch, no rebase, no amend, no push, nothing on GitHub, no bare
  `git stash`. Never commit this PLAN, the SUMMARY, STATE.md or anything under `.planning/quick/` (the orchestrator
  commits planning artifacts).
- Read `AGENTS.local.md` before the first commit and follow it; never copy its content into any artifact.
- Read the root `.swiftlint.yml` before writing Swift. No `swiftlint:disable` of any kind, no rule changes, no
  `.serialized`. `AppAlertState.swift` already holds one lint suppression above the alert field's focusing
  `onAppear`; no shape touches it.
- Logs and scratch files go under `.capture/261126-wzf/` (gitignored). The SUMMARY carries no absolute home paths
  (write `$HOME/...`) and names no other local project.
- Code comments use decision IDs (W-1 to W-6) and the quick task id, never agent names.
- Every Swift and Python block under "Shapes" is copied exactly as written, at the indentation written. An edit
  shape gives whole lines: "Replace" swaps exactly the first block for the second; "Directly below" and "Directly
  above" insert the second block next to the first block, which stays as it is. A note under a block says when it
  starts or ends with a blank line. Each anchor is matched against the file as the earlier shapes and tasks leave it.
- The executor writes no copy: the five strings come from CONTEXT's table through the script in S6, unchanged.
- The Tag Set picker in `MyTagsView.swift` stays exactly as it is (owner, 2026-11-27).

### COMMIT (each task ends with exactly one)

Stage only the task's own files by path (`git add <path> ...`, whole files, never `-A`, `-p` or `-U0` hunks), check
`git diff --cached --stat` lists exactly them, then `TZ=Asia/Shanghai git commit -m "<subject>"` with the subject the
task gives (no body, no attribution or co-author lines; every subject here is under 50 characters). Verify
`git log -1 --format='%G? %aI %cI'` prints `G` and two `+08:00` instants; if signing fails, follow AGENTS.local.md,
then retry the same commit.

### TEST (shared rules)

- Before every `xcodebuild` invocation, `pgrep -x xcodebuild; pgrep -x xctest` must print nothing. If either prints a
  pid, wait (poll every 30 s with `pgrep -x`, never `pgrep -f`) and never kill anything. One invocation at a time.
- Tests run on `EhPanda iPhone Air (phase19)`, id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`, from the repository root, in
  this form (fill the targets and the log name):
  `mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never <-only-testing:Target ...> 2>&1 | tee .capture/261126-wzf/<log>.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'`
  It passes when it prints `** TEST SUCCEEDED **` and `grep -cE "Test case '.*' failed" .capture/261126-wzf/<log>.log`
  prints `0`. Xcode 27.2 prints no `Test run with N tests` line; the per-case
  `Test case '<Suite>/<name>(<labels>)' passed on ...` lines are the evidence (a parameterized test prints one line
  per argument).
- A RED run (the task's tests written, its code not yet) uses the same form with its own log name; it must print
  `** TEST FAILED **` with a compile error that names a symbol the task gives.
- Warnings: `grep -E ': warning: ' .capture/261126-wzf/<log>.log | sort -u` must print nothing. A warning in a file
  this plan does not touch: stop and report it (do not fix it).
- Lint, from the repository root, on the task's trees:
  `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet <trees>`
  must print nothing and exit 0.
- Known flake: if the only failure of the final full run is
  `FavoritesFeatureTests/LoginReturnObservationTests/cookieLoginTriggersReloadWithoutAViewCallback`, re-run
  `-only-testing:FavoritesFeatureTests` once; it must pass; record both runs in the SUMMARY.
- No test reaches the network: the request tests run through the token-isolated `URLProtocol` session of
  `NetworkingFeatureTests/Support`, and the reducer tests replace `myTagsClient` (and, in the Settings-level test,
  the analytics, cookie and haptics clients with their `noop` values).

### Settled facts (checked by the planner against the tree at `2b3c2baef`; do not re-derive)

1. **The tag set form after quick 261126-udx.** `Request+MyTags.swift` holds the shared builder
   `tagSetFormFields(action:name:isEnabled:color:)` and `postMyTagsForm(_:to:in:attempts:)`, which parses the answer
   page through `myTagsPage(data:)`. `CreateMyTagSetRequest` and `DeleteMyTagSetRequest` pass `attempts: 1`; the
   file's header comment says why. `Defaults.URL.myTags(host:tagSetID:)` is the set's page. `AppPackage` sources are
   identical at `8b2f97005` and `2b3c2baef` (the latter changed documents only).
2. **The page's tag set state.** `MyTagsFeature.State.isChangingTagSets` disables New Tag Set and Delete Tag Set and
   refuses another create or delete; `AlertSource` names the control an alert attaches to; `presentAlert(_:_:title:
   message:)` and `take(_:into:)` are the page's helpers; `selectedTagSet` is the shown set.
3. **The stored cache.** `MyTagSet`'s stored fields are listed in its private `CodingKeys`; `name` is one of them and
   a `let` today. Making it `public internal(set) var` changes neither its coding nor any caller outside AppModels.
4. **The Tag Set picker** is `Picker(.myTagsTagSet, selection:)` with `.pickerStyle(.menu)` and one `Text` per set;
   this plan leaves it as it is.
5. **The text-field alert.** `AppAlertTextFieldState(placeholder:keyboard:requiresText:)` and
   `enablesButton(role:text:)` live in AppComponents' `AppAlertState.swift`; the view modifier enables each button
   through `enablesButton` from the field's live text, and focuses the field as the alert appears. Its other user
   with a text field is Toplists' jump-to-page alert in HomeFeature, so Task 2 runs HomeFeatureTests.
6. **Signed-out detection today.** Form pages and reads go through `parseResponse(doc:_:)`, whose failure carries
   `Parser.parseResponseError` (the kokomade wall, the exhentai restriction text, `bounce_login.php`), which
   `mapAppError(error:)` turns into `AppError.loginRequired`. The edit API's `SetUserTagReply` decodes `tagid` and
   `error` only. The site's `api_response` treats `void 0 != a.login` as an ended session (loose, so `null` is none).
7. **Signing in again.** `MyTagsView` shows `NotLoginView` while `!didLogin` (`@SharedReader(.didLogin)`); its Log In
   sends `.delegate(.pushLogin)`, which Settings answers by pushing Login. The page's `onPresented` watch sends
   `loginSucceeded` only on a signed-out to signed-in change of the cookies, which an ended session whose cookies
   stay never makes. The page's read is `.cancellable(id: CancelID.fetch, cancelInFlight: true)`. Settings'
   `.path(.element(id: _, action: .login(.loginDone)))` merges the post-login effects.
8. **Test files.** `MyTagsFeatureTests.swift` has 833 lines; the rename tests would take it past SwiftLint's
   `file_length` of 1000, so the new reducer tests live in new files of the same target.
9. **App-storage isolation.** SettingFeature, AppComponents and MyTagEditor are reader modules: the two new
   SettingFeatureTests files carry `@Suite(.isolatedAppStorage)` and import TestingSupport, `MyTagEditorTests` keeps
   its trait, and the AppModels and Networking suites carry none.
10. **Copy symbols.** SettingFeature's catalog holds none of the five keys and is in Xcode's canonical form. Its keys
    generate `.myTagsRenameTagSet`, `.myTagsRenameTagSetTitle`, `.myTagsRenameTagSetMessage`, `.myTagsRename` and
    `.myTagsRenameFailed`; `.myTagsNewTagSetName` exists. The S6 script was dry-run on a copy: the five keys add 205
    lines and delete none, and `check` prints `ok`.
11. **Replayed and tested shapes.** The planner applied every shape, task by task, to a clean copy of the tree at
    `2b3c2baef`; every anchor matched exactly once, as whole lines, and each task's result matched byte for byte the
    tree it then tested. At each task's commit it ran that task's test targets, and after Task 4 the full
    FeatureTests plan with `-skip-testing:VisualSnapshotTests`, strict lint on
    `App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` and the app-storage gate.

### Planner readings (P-n; each is final for the executor, listed for the orchestrator to confirm)

Numbers are kept from the first plan; the owner's decisions of 2026-11-27 withdrew P-2, P-3, P-11 and P-12 and
replaced P-7.

- **P-1 Task shape.** Four layered tasks, one green commit each, instead of a tracer: the rename path (a tag set form
  post through `postMyTagsForm`, `MyTagsClient`, the reducer, a row) is the one the create and the delete already
  prove; rename and the ended session each get a request commit and a page commit.
- **P-2** Withdrawn (owner, 2026-11-27): no tag count is read or kept here; quick 261126-wzj plans it.
- **P-3** Withdrawn with P-2: the parser is not changed.
- **P-4 Rename put on the wire once (W-2).** A replay asks for the same name, so it cannot rename twice; but a rename
  the site took whose response was lost would be replayed as a rename to the name the set already has, whose answer
  is unknown here, and a refusal would read as the failure of a rename that took (as with udx's delete). So
  `attempts: 1`, documented on the request and in the file's header. A lost response shows the failure; the next read
  shows the site's name.
- **P-5 The call.** `MyTagsClient.renameTagSet(host, name, tagSet)` mirrors `createTagSet(host, name, tagSet)`; the
  request posts the given set's form (its id, Enabled box and colour) with the new name.
- **P-6 `editedValue` is kept, for the hold alone (W-1).** The alert enables its own buttons from its field's live
  text through `enablesButton(role:text:)` (settled fact 5); the feature has no way to disable an alert button
  except through the alert's state, and rebuilding the alert on every keystroke would keep the rule in two places.
  So the shared `AppAlertTextFieldState` gains `editedValue`, the value the field edits: every button but Cancel is
  held while the trimmed text is still that value, and the reducer refuses it too (P-8). Without it nothing changes
  for New Tag Set or Toplists.
- **P-7 Not selected (W-1, owner 2026-11-27).** The field starts with the set's name and nothing selects it: no
  keyboard observer, no selection state, no change to the field's `TextField`. Where the cursor lands is the
  system's for a field focused with text in it; the owner checks it is at the end (Output).
- **P-8 Names compared trimmed.** Rename's gate and the reducer trim spaces and newlines and compare with the set's
  stored name; the trimmed name is what is sent and shown, as New Tag Set does with its name.
- **P-9 Judging the answer (W-3).** The answer page goes into the cache first. The rename took when the page shows
  the renamed set, gives no `#msg` reason and lists the set under exactly the name sent. A reason: the alert shows
  it (the cache already holds the page's old name). The set under another name with no reason: the alert shows the
  unknown error and the cache keeps the site's name. A page showing another set: the old name is put back and the
  alert shows its reason or the unknown error. A failure: the old name is put back and the alert shows the error's
  text.
- **P-10 Row, guard and alert placement (W-1).** The row sits after New Tag Set, before Delete Tag Set, disabled
  while `isChangingTagSets`, the flag now covering all three requests. The alert names the set it was opened for;
  the reducer refuses a rename while a change is on its way, for a set no longer shown, or to a blank or unchanged
  name. Both the text-field alert and the failure alert (`AlertSource.renameTagSet`) attach to the Rename row.
- **P-11** Withdrawn (owner, 2026-11-27): the Tag Set picker stays the native menu `Picker` with the names alone.
- **P-12** Withdrawn with P-11: no count copy is added here.
- **P-13 The login answer (W-5).** Only the edit API answers JSON with `login`: `UpdateMyTagRequest` throws the
  existing `AppError.loginRequired` when the answer carries `login` with any value but null (settled fact 6), before
  it reads `error`. No new `AppError` case. Quick 261126-wzg's suggestion request already fails on `login` and, by
  its G-1, shows nothing; it is unchanged.
- **P-14 One basis for the signed-out state.** `isSessionExpired` is `loadingState == .failed(.loginRequired)`, not a
  new flag: every read starts by loading, which clears it, and any other failure shows its error as today. A write
  that fails as `loginRequired` sets that state instead of an alert, after its optimistic change is undone as for any
  failure.
- **P-15 Edit Tag (W-5).** The sheet keeps its alert and the changes (closing it would discard them) and sends
  `Delegate.signedOut`; the page beneath shows Log In. The owner sees Log In once the sheet is closed.
- **P-16 Reading again after a sign-in (W-5).** Settings' `loginDone` also sends `.fetchMyTags` to every My Tags page
  on its stack, since the page's own watch never fires when the cookies stayed (settled fact 7). When both fire, the
  page's `cancelInFlight` read keeps one.
- **P-17 Form pages keep the existing detection (W-5).** No new marker is added for a form page answered while
  signed out: W-5 forbids guessing its shape. If the site answers with a page the existing detection does not know,
  the parser fails as `parseFailed` and the page shows the error (a read) or the alert (a write), as today. The
  owner's account settles it (Output).
- **P-18 New test files.** `MyTagsRenameTests` and `MyTagsSessionTests` sit beside `MyTagsFeatureTests` (settled fact
  8).
- **P-19 Copy inserted by script.** S6 reads the five rows from CONTEXT's table and writes them as plain strings (none
  takes an argument); nobody retypes copy.

### Source coverage

| Source item | Where |
|---|---|
| W-1 tint row after New Tag Set, the app's alert, name filled in, focused, not selected | Task 2 (S7, S8, S9, S10, P-6, P-7, P-10) |
| W-1 Rename disabled for an empty or unchanged trimmed name; the reducer refuses both; Cancel closes | Task 2 (S7a, S8, S10, P-6, P-8) |
| W-1 prompt reuses `my_tags.new_tag_set.name`; one create, rename or delete at a time; alert on the row | Task 2 (S8, S9, S10, P-10) |
| W-2 `RenameMyTagSetRequest`, fields in order, `attempts` reasoning documented | Task 1 (S2, S3, S4, P-4, P-5) |
| W-3 optimistic name, tags stay, answer into the cache, success read, old name and alert on failure | Task 1 (S1, S5), Task 2 (S8, S10, P-9) |
| W-4 tag counts | Removed by the owner (2026-11-27); quick 261126-wzj plans the counts |
| W-5 `login` answer mapped to `loginRequired`; the existing detection reused, not guessed | Task 3 (S11, S13, P-13, P-17) |
| W-5 the page shows its Signed out state, not an alert; Log In reloads after the sign-in | Task 3 (S12, S14), Task 4 (S15 to S18, P-14 to P-16) |
| W-6 rename reducer tests, request field tests, login to signed out | Tasks 1 to 4 |
| Copy: five keys, six locales | Task 2 (S6, P-19) |
| Owner decisions 2026-11-27: name not selected; Tag Set picker untouched | Task 2 (P-7), Verification (picker invariant) |
| Design: Rename row between New Tag Set and Delete Tag Set; Rename Failed; Signed out | Tasks 2 and 4 |
| Owner's device checks (the live site needs the owner's account) | Output |

### Shapes (copy exactly)

#### S1: `AppPackage/Sources/AppModels/Tags/MyTags.swift` (Task 1)

**S1a.** Replace:

```swift
public struct MyTagSet: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
```

with:

```swift
public struct MyTagSet: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    /// Set here only by `MyTags.renaming(_:to:)`, so a rename shows at once (W-3 of quick 261126-wzf).
    public internal(set) var name: String
```

**S1b.** Directly above:

```swift
    /// The cache with `tag` in place of the tag of the same id in the set `tagSetID`.
```

insert:

```swift
    /// The cache with the set `tagSetID` named `name` (W-3 of quick 261126-wzf): the picker shows a rename at once,
    /// and a rename that failed puts the old name back the same way.
    public func renaming(_ tagSetID: Int, to name: String) -> MyTags {
        let tagSets = self.tagSets.map { tagSet in
            guard tagSet.id == tagSetID else { return tagSet }
            var renamed = tagSet
            renamed.name = name
            return renamed
        }
        return MyTags(tagSets: tagSets, selectedTagSetID: selectedTagSetID)
    }

```

The inserted block ends with a blank line.

#### S2: `AppPackage/Sources/NetworkingFeature/Request+MyTags.swift` (Task 1)

**S2a.** Replace:

```swift
// The My Tags reads and writes (port of PR 462 item 10; the site contract read live on 2026-11-22). Every request but
// the create and the delete keeps `fetch`'s default four attempts: the reads are GETs, and a replayed write asks the
// site for the same end state (an add of a tag the set holds is taken unchanged, a remove of a tag the set no longer
// holds removes nothing, an edit or a tag set update sets the same values), so a lost response is safe to ask for
// again. A replayed create would make another set (N-4 of quick 261126-pfh), and a replayed delete would find its set
// gone and come back refused though the delete took (U-5 of quick 261126-udx), so both are put on the wire once.
```

with:

```swift
// The My Tags reads and writes (port of PR 462 item 10; the site contract read live on 2026-11-22). Every request but
// the create, the rename and the delete keeps `fetch`'s default four attempts: the reads are GETs, and a replayed
// write asks the site for the same end state (an add of a tag the set holds is taken unchanged, a remove of a tag the
// set no longer holds removes nothing, an edit or a tag set update sets the same values), so a lost response is safe
// to ask for again. A replayed create would make another set (N-4 of quick 261126-pfh), a replayed delete would find
// its set gone and come back refused though the delete took (U-5 of quick 261126-udx), and a replayed rename would
// ask the site for the name the set already has, whose answer is unknown here (W-2 of quick 261126-wzf), so all
// three are put on the wire once.
```

**S2b.** Replace:

```swift
    /// The tag set form's fields in the browser's order, as the site's `do_tagset_post` submits the form: the action,
    /// the name (the new set's for a create, else the form's empty field), the Enabled box, which sends nothing when
    /// unchecked, and the colour, empty for none.
```

with:

```swift
    /// The tag set form's fields in the browser's order, as the site's `do_tagset_post` submits the form: the action,
    /// the name (the new set's for a create, the new one for a rename, else the form's empty field), the Enabled box,
    /// which sends nothing when unchecked, and the colour, empty for none.
```

**S2c.** Directly above:

```swift
/// Deletes a tag set through the tag set form's Delete (`tagset_action=delete`), as the site's `do_tagset_delete`
```

insert:

```swift
/// Renames a tag set through the tag set form's Rename (`tagset_action=rename`), as the site's `do_tagset_rename`
/// posts it once its prompt is answered: the form of the set the page shows, which is the set renamed, to that set's
/// page, its fields in the browser's order. Those are the new name, the set's Enabled box, which sends nothing when
/// unchecked, and its colour. Answers the page the site returns, which carries the reason when it refused.
///
/// Put on the wire once (W-2 of quick 261126-wzf). A replay asks for the same name, so it cannot rename twice; but a
/// rename the site took whose response was lost would then ask the site for the name the set already has, and what
/// the site answers to that is unknown here: a refusal would read as the failure of a rename that took, as a replayed
/// delete would (U-5 of quick 261126-udx). A lost response shows the failure instead, and the next read of My Tags
/// shows the name the site has.
public struct RenameMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        name: String,
        tagSet: MyTagSet,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.name = name
        self.tagSet = tagSet
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    /// The set's new name; the page sends it trimmed.
    public let name: String
    /// The set to rename, the one the page shows, whose form the rename is posted from.
    public let tagSet: MyTagSet
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let fields = tagSetFormFields(action: "rename", name: name, isEnabled: tagSet.isEnabled, color: tagSet.color)
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
    }
}

```

The inserted block ends with a blank line.

#### S3: `AppPackage/Sources/MyTagsClient/MyTagsClient.swift` (Task 1)

**S3a.** Replace:

```swift
/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, the
/// create and the delete of a tag set, and the site's tag suggestions (port of PR 462 item 10; the create, quick
/// 261126-pfh; the delete, quick 261126-udx; the suggestions, quick 261126-wzg).
```

with:

```swift
/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, the
/// create, the rename and the delete of a tag set, and the site's tag suggestions (port of PR 462 item 10; the create,
/// quick 261126-pfh; the delete, quick 261126-udx; the suggestions, quick 261126-wzg; the rename, quick 261126-wzf).
```

**S3b.** Replace:

```swift
        _ shownTagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
    /// Deletes `tagSet`, the set the page shows, from its own form; answers the page the site returned. Put on the
```

with:

```swift
        _ shownTagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
    /// Renames `tagSet`, the set the page shows, to `name` from its own form; answers the page the site returned. Put
    /// on the wire once (`RenameMyTagSetRequest`).
    public var renameTagSet: @Sendable (
        _ host: GalleryHost,
        _ name: String,
        _ tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
    /// Deletes `tagSet`, the set the page shows, from its own form; answers the page the site returned. Put on the
```

**S3c.** Replace:

```swift
        createTagSet: requestCreateTagSet,
        deleteTagSet: requestDeleteTagSet,
```

with:

```swift
        createTagSet: requestCreateTagSet,
        renameTagSet: requestRenameTagSet,
        deleteTagSet: requestDeleteTagSet,
```

**S3d.** Directly above:

```swift
    private static func requestDeleteTagSet(
```

insert:

```swift
    private static func requestRenameTagSet(
        host: GalleryHost,
        name: String,
        tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage {
        try await RenameMyTagSetRequest(host: host, name: name, tagSet: tagSet).response()
    }

```

The inserted block ends with a blank line.

**S3e.** Replace:

```swift
        createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
```

with:

```swift
        createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        renameTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
```

**S3f.** Directly below:

```swift
        createTagSet: IssueReporting.unimplemented(
            "MyTagsClient.createTagSet", throwing: AppError.unknown
        ),
```

insert:

```swift
        renameTagSet: IssueReporting.unimplemented(
            "MyTagsClient.renameTagSet", throwing: AppError.unknown
        ),
```

**S3g.** Directly below:

```swift
            createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            },
```

insert:

```swift
            renameTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            },
```

#### S4: `AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift` (Task 1)

**S4a.** Directly above:

```swift
    @Test
    func anEditPostsSetUserTagWithTheTagsStateColourAndWeight() async throws {
```

insert:

```swift
    // The rename posts the set's own form with the new name, as a browser does once the site's prompt is answered: an
    // unchecked Enabled box sends no field, and no colour sends the field empty (W-2 of quick 261126-wzf).
    @Test
    func aTagSetRenamePostsTheSetsFormWithTheNewNameInOrder() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.http(status: 200, data: page), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
        let enabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: true, color: green, tags: [])
        let disabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])

        let first = try await renameTagSet(enabled, to: "Picks & Holds", session: session).get()
        let second = try await renameTagSet(disabled, to: "Fixture Holds", session: session).get()

        #expect(first.tagSet.id == 2)
        #expect(second.tagSet.id == 2)
        let requests = handle.receivedRequests
        #expect(requests.map(\.httpMethod) == ["POST", "POST"])
        expectEquivalentURL(requests.first?.url, url)
        #expect(requests.first?.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(requests.map({ body(of: $0) }) == [
            "tagset_action=rename&tagset_name=Picks%20%26%20Holds&tagset_enable=on&tagset_color=%2322AA55",
            "tagset_action=rename&tagset_name=Fixture%20Holds&tagset_color="
        ])
    }

    // A rename the site took whose answer was lost would be asked again for the name the set already has, an answer
    // unknown here, so a rename is put on the wire once (W-2 of quick 261126-wzf).
    @Test
    func aTagSetRenameIsNotRetriedAfterATransportFailure() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.transportFailure(.networkConnectionLost), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let shown = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])

        let result = await renameTagSet(shown, to: "Fixture Holds", session: session)

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: url) == 1)
    }

```

The inserted block ends with a blank line.

**S4b.** Directly above:

```swift
    private func deleteTagSet(_ tagSet: MyTagSet, session: URLSession) async -> Result<MyTagsPage, AppError> {
```

insert:

```swift
    private func renameTagSet(
        _ tagSet: MyTagSet,
        to name: String,
        session: URLSession
    ) async -> Result<MyTagsPage, AppError> {
        await capture { () async throws(AppError) -> MyTagsPage in
            try await RenameMyTagSetRequest(host: .ehentai, name: name, tagSet: tagSet, urlSession: session).response()
        }
    }

```

The inserted block ends with a blank line.

#### S5: `AppPackage/Tests/AppModelsTests/MyTagsTests.swift` (Task 1)

**S5.** Directly above:

```swift
    @Test
    func aGalleryTagIsNamedAsMyTagsTitlesItAndTakesTheCacheElseTheListColour() {
```

insert:

```swift
    // A rename shows in the cache at once, and a failed one puts the old name back the same way (W-3 of quick
    // 261126-wzf); the set keeps everything else, the other sets and the choice stay, and an unknown id changes
    // nothing.
    @Test
    func aRenameNamesOneSetAndKeepsTheRest() {
        let first = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [Self.glasses])
        let second = MyTagSet(
            id: 2, name: "Fixture Picks", isEnabled: false, color: Self.green, tags: [Self.artist], isDeletable: true
        )
        let cache = MyTags(tagSets: [first, second], selectedTagSetID: 2)

        let renamed = cache.renaming(2, to: "Fixture Holds")

        let holds = MyTagSet(
            id: 2, name: "Fixture Holds", isEnabled: false, color: Self.green, tags: [Self.artist], isDeletable: true
        )
        #expect(renamed == MyTags(tagSets: [first, holds], selectedTagSetID: 2))
        #expect(renamed.renaming(2, to: "Fixture Picks") == cache)
        #expect(cache.renaming(9, to: "Fixture Holds") == cache)
    }

```

The inserted block ends with a blank line.

#### S6: `.capture/261126-wzf/insert_copy.py` (Task 2, new file)

The whole file:

```python
"""Inserts or checks the copy keys of quick 261126-wzf, taken verbatim from CONTEXT's copy table.

    python3 -I .capture/261126-wzf/insert_copy.py insert <key> ...
    python3 -I .capture/261126-wzf/insert_copy.py check <key> ...

Run from the repository root. Every key goes into SettingFeature's catalog. `insert` writes each key in Xcode's
canonical form (keys sorted, two-space indent, " : " separators, no trailing newline) and then checks it; `check`
prints `ok` when the catalog holds exactly CONTEXT's six values for every key given. No key takes an argument.
"""
import json
import sys
from pathlib import Path

CONTEXT = Path(".planning/quick/261126-wzf-my-tags-tag-set-rename-counts-and-sessio/261126-wzf-CONTEXT.md")
CATALOG = Path("AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings")
LOCALES = ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"]
KEYS = [
    "my_tags.rename_tag_set",
    "my_tags.rename_tag_set.title",
    "my_tags.rename_tag_set.message",
    "my_tags.rename",
    "my_tags.rename_failed",
]


def canonical(catalog):
    return json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : "))


def copy_table():
    rows = {}
    for line in CONTEXT.read_text(encoding="utf-8").splitlines():
        if line.startswith("| `my_tags."):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            assert len(cells) == 1 + len(LOCALES), line
            rows[cells[0].strip("`")] = dict(zip(LOCALES, cells[1:]))
    assert sorted(rows) == sorted(KEYS), list(rows)
    for key, values in rows.items():
        for locale, value in values.items():
            assert "%" not in value and "{" not in value and value.strip() == value and value, (key, locale)
    return rows


def entry(values):
    localizations = {
        locale: {"stringUnit": {"state": "translated", "value": values[locale]}} for locale in sorted(values)
    }
    return {"extractionState": "manual", "localizations": localizations}


def load():
    text = CATALOG.read_text(encoding="utf-8")
    catalog = json.loads(text)
    assert canonical(catalog) == text, f"{CATALOG} is not in Xcode's canonical form"
    assert list(catalog["strings"]) == sorted(catalog["strings"]), f"{CATALOG} keys are not sorted"
    return catalog


def insert(keys):
    catalog = load()
    rows = copy_table()
    strings = dict(catalog["strings"])
    for key in keys:
        assert key in KEYS, key
        assert key not in strings, f"{key} is already in {CATALOG}"
        strings[key] = entry(rows[key])
    catalog["strings"] = {name: strings[name] for name in sorted(strings)}
    CATALOG.write_text(canonical(catalog), encoding="utf-8")
    check(keys)


def check(keys):
    strings = load()["strings"]
    rows = copy_table()
    for key in keys:
        assert key in KEYS, key
        assert strings[key] == entry(rows[key]), key
    print("ok")


if __name__ == "__main__":
    {"insert": insert, "check": check}[sys.argv[1]](sys.argv[2:])
```

#### S7: `AppPackage/Sources/AppComponents/AppAlertState.swift` (Task 2)

**S7a.** Replace:

```swift
    public var requiresText: Bool

    public init(placeholder: TextState, keyboard: Keyboard = .default, requiresText: Bool = false) {
        self.placeholder = placeholder
        self.keyboard = keyboard
        self.requiresText = requiresText
    }

    /// Whether a button of `role` can be tapped while the field holds `text`: always, unless the field
    /// `requiresText`, which holds every button but Cancel until `text` holds more than whitespace and newlines.
    public func enablesButton(role: ButtonStateRole?, text: String) -> Bool {
        guard requiresText, role != .cancel else { return true }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
```

with:

```swift
    public var requiresText: Bool
    /// The value the field edits, for an alert that changes one, such as a tag set's name (W-1 of quick 261126-wzf);
    /// nil for an alert that asks for a value afresh.
    ///
    /// The host starts the field with it, unselected, for the user to edit (W-1). The alert holds every button but
    /// Cancel while the trimmed text is still this value: such a button would change nothing, and the reducer would
    /// only refuse it, closing the alert with no word why.
    public var editedValue: String?

    public init(
        placeholder: TextState,
        keyboard: Keyboard = .default,
        requiresText: Bool = false,
        editedValue: String? = nil
    ) {
        self.placeholder = placeholder
        self.keyboard = keyboard
        self.requiresText = requiresText
        self.editedValue = editedValue
    }

    /// Whether a button of `role` can be tapped while the field holds `text`: Cancel always; any other button unless
    /// the field `requiresText` and `text` holds nothing but whitespace and newlines, or `text`, trimmed of them, is
    /// still the `editedValue`.
    public func enablesButton(role: ButtonStateRole?, text: String) -> Bool {
        guard role != .cancel else { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if requiresText, trimmed.isEmpty {
            return false
        }
        return trimmed != editedValue
    }
```

**S7b.** Replace:

```swift
    /// state, e.g. `.appAlert($store.scope(state: \.alert, action: \.alert), text: $store.pageIndex)`.
    /// A field that ``AppAlertTextFieldState/requiresText`` holds every button but Cancel until `text` has some.
```

with:

```swift
    /// state, e.g. `.appAlert($store.scope(state: \.alert, action: \.alert), text: $store.pageIndex)`.
    /// A field that ``AppAlertTextFieldState/requiresText`` holds every button but Cancel until `text` has some, and
    /// one with an ``AppAlertTextFieldState/editedValue`` holds them while `text` is still that value.
```

#### S8: `AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift` (Task 2)

**S8a.** Directly below:

```swift
/// Delete Tag Set shows while the shown set's page offers deleting it, and stays, disabled, while its own failure
/// alert is up. It asks in a confirmation, then has the site delete the set; the page then chooses the site's first
/// set and shows it, and a refusal or a failure shows the alert on the row (quick 261126-udx).
```

insert:

```swift
///
/// Rename Tag Set asks for the new name in an alert that starts with the set's name, then has the site rename the set
/// from its own form; the picker shows the new name at once, and a refusal or a failure puts the old name back and
/// shows the alert on the row (quick 261126-wzf).
```

**S8b.** Directly below:

```swift
        /// The New Tag Set row, whose create was refused or failed.
        case newTagSet
```

insert:

```swift
        /// The Rename Tag Set row, whose rename was refused or failed.
        case renameTagSet
```

**S8c.** Directly below:

```swift
    public enum NewTagSetAlert: Equatable, Sendable {
        case create
    }
```

insert:

```swift

    /// The Rename Tag Set alert's action besides Cancel; it names the set it was opened for, as the delete's
    /// confirmation does (W-1 of quick 261126-wzf).
    public enum RenameTagSetAlert: Equatable, Sendable {
        case rename(tagSetID: Int)
    }
```

The inserted block starts with a blank line.

**S8d.** Directly below:

```swift
        @Presents public var newTagSetAlert: AppAlertState<NewTagSetAlert>?
```

insert:

```swift
        /// The alert that renames the shown tag set (W-1 of quick 261126-wzf).
        @Presents public var renameTagSetAlert: AppAlertState<RenameTagSetAlert>?
```

**S8e.** Replace:

```swift
        public var newTagSetName = ""
        /// A create or a delete of a tag set is on its way (U-4 of quick 261126-udx): New Tag Set and Delete Tag Set
        /// are disabled, and another create or delete is refused, until the site answers. One flag serves both: a
        /// delete answered while a create is on its way would confuse the create's search for its new id, and a
        /// create answered while a delete is on its way would confuse the delete's check that its set is gone.
        public var isChangingTagSets = false
```

with:

```swift
        public var newTagSetName = ""
        /// The name typed into the Rename Tag Set alert; the set's own name each time the alert opens (W-1 of quick
        /// 261126-wzf).
        public var renameTagSetName = ""
        /// A create, a rename or a delete of a tag set is on its way (U-4 of quick 261126-udx): New Tag Set, Rename Tag
        /// Set and Delete Tag Set are disabled, and another create, rename or delete is refused, until the site
        /// answers, one such request at a time (W-1 of quick 261126-wzf). One flag serves all three: a delete
        /// answered while a create is on its way would confuse the create's search for its new id, a create answered
        /// while a delete is on its way would confuse the delete's check that its set is gone, and either answered
        /// while a rename is on its way could move or take away the set the rename's answer is read for.
        public var isChangingTagSets = false
```

**S8f.** Directly below:

```swift
        case newTagSetAlert(PresentationAction<NewTagSetAlert>)
```

insert:

```swift
        case renameTagSetAlert(PresentationAction<RenameTagSetAlert>)
```

**S8g.** Directly below:

```swift
        case createTagSetDone(knownTagSetIDs: [Int], result: Result<MyTagsPage, AppError>)
```

insert:

```swift
        case renameTagSetTapped
        case renameTagSetNameChanged(String)
        case renameTagSetDone(tagSetID: Int, oldName: String, newName: String, result: Result<MyTagsPage, AppError>)
```

**S8h.** Replace:

```swift
            case .alert, .toast, .delegate, .newTagSetAlert(.dismiss), .deleteTagSetDialog(.dismiss):
                return .none
```

with:

```swift
            case .alert, .toast, .delegate, .newTagSetAlert(.dismiss), .renameTagSetAlert(.dismiss),
                 .deleteTagSetDialog(.dismiss):
                return .none
```

**S8i.** Directly above:

```swift
            // The confirmation names the set it was opened for, the one the page shows (U-3).
            case .deleteTagSetTapped:
```

insert:

```swift
            // The alert names the set it was opened for, the one the page shows, and starts with its name, which
            // Rename waits to see changed (W-1).
            case .renameTagSetTapped:
                guard let tagSet = state.selectedTagSet else { return .none }
                state.renameTagSetName = tagSet.name
                state.renameTagSetAlert = AppAlertState(
                    title: {
                        TextState(localized: .myTagsRenameTagSetTitle)
                    },
                    textField: AppAlertTextFieldState(
                        placeholder: TextState(localized: .myTagsNewTagSetName),
                        requiresText: true,
                        editedValue: tagSet.name
                    ),
                    actions: {
                        ButtonState(action: .rename(tagSetID: tagSet.id)) {
                            TextState(localized: .myTagsRename)
                        }
                        ButtonState(role: .cancel) {
                            TextState(localized: .RLocalizable.cancel)
                        }
                    },
                    message: {
                        TextState(localized: .myTagsRenameTagSetMessage)
                    }
                )
                return .none

            case .renameTagSetNameChanged(let name):
                state.renameTagSetName = name
                return .none

            // Only the set the alert names is renamed, while it is still the one shown, to a name neither blank nor its
            // own, though Rename waits for one (W-1), and not while a create, a rename or a delete is on its way (U-4).
            // The picker shows the new name at once (W-3); the form is the set's own.
            case .renameTagSetAlert(.presented(.rename(let tagSetID))):
                let name = state.renameTagSetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !state.isChangingTagSets, let tagSet = state.selectedTagSet, tagSet.id == tagSetID,
                      !name.isEmpty, name != tagSet.name
                else { return .none }
                state.isChangingTagSets = true
                state.$user.withLock({ $0.myTags = $0.myTags?.renaming(tagSetID, to: name) })
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.renameTagSet(host, name, tagSet)
                    }
                    await send(
                        .renameTagSetDone(tagSetID: tagSetID, oldName: tagSet.name, newName: name, result: result)
                    )
                }

            // The answer is taken into the cache, so the picker shows the name the site has (W-3). The rename took
            // when the page gives no reason and shows the set under its new name; a reason, or another name, fails
            // it. A page that shows another set says nothing of this one's name, so the old name returns.
            case .renameTagSetDone(let tagSetID, let oldName, let newName, .success(let page)):
                state.isChangingTagSets = false
                take(page, into: &state)
                guard page.tagSet.id == tagSetID else {
                    state.$user.withLock({ $0.myTags = $0.myTags?.renaming(tagSetID, to: oldName) })
                    return presentAlert(
                        &state,
                        .renameTagSet,
                        title: .myTagsRenameFailed,
                        message: page.message ?? AppError.unknown.alertText
                    )
                }
                if let message = page.message {
                    return presentAlert(&state, .renameTagSet, title: .myTagsRenameFailed, message: message)
                }
                guard page.tagSet.name == newName else {
                    // Neither the new name nor a reason: as with a create whose answer lists no new set, all the app
                    // knows is that the site did not do it.
                    return presentAlert(
                        &state, .renameTagSet, title: .myTagsRenameFailed, message: AppError.unknown.alertText
                    )
                }
                return .none

            case .renameTagSetDone(let tagSetID, let oldName, _, .failure(let error)):
                state.isChangingTagSets = false
                state.$user.withLock({ $0.myTags = $0.myTags?.renaming(tagSetID, to: oldName) })
                return presentAlert(&state, .renameTagSet, title: .myTagsRenameFailed, message: error.alertText)

```

The inserted block ends with a blank line.

**S8j.** Directly below:

```swift
        .ifLet(\.$newTagSetAlert, action: \.newTagSetAlert)
```

insert:

```swift
        .ifLet(\.$renameTagSetAlert, action: \.renameTagSetAlert)
```

#### S9: `AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift` (Task 2)

**S9a.** Replace:

```swift
/// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): the tag set (its picker, Enabled and default
/// colour, New Tag Set, and Delete Tag Set while the site offers it) and its tags, one row each; a row opens Edit Tag
/// and a trailing swipe removes the tag. Add Tag sits in the toolbar. Signed out it shows Log In; loading, the loading
/// view; failed, the error with Open in Browser.
```

with:

```swift
/// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): the tag set (its picker, Enabled and default
/// colour, New Tag Set, Rename Tag Set, and Delete Tag Set while the site offers it) and its tags, one row each; a row
/// opens Edit Tag and a trailing swipe removes the tag. Add Tag sits in the toolbar. Signed out it shows Log In;
/// loading, the loading view; failed, the error with Open in Browser.
```

**S9b.** Directly below:

```swift
                .appAlert(alert(for: .newTagSet))
```

insert:

```swift
                Button(.myTagsRenameTagSet) {
                    store.send(.renameTagSetTapped)
                }
                .disabled(store.isChangingTagSets)
                // On the row that opens them, the rename alert and its failure alert (AGENTS.md dialog placement).
                .appAlert(
                    $store.scope(\.$renameTagSetAlert, action: \.renameTagSetAlert),
                    text: $store.renameTagSetName.sending(\.renameTagSetNameChanged)
                )
                .appAlert(alert(for: .renameTagSet))
```

#### S10: `AppPackage/Tests/SettingFeatureTests/MyTagsRenameTests.swift` (Task 2, new file)

The whole file:

```swift
import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
import MyTagsClient
import Resources
@testable import SettingFeature
import Sharing
import Testing
import TestingSupport

// Rename Tag Set on the My Tags page (quick 261126-wzf): the alert and what Rename waits for, the post, the new name
// shown at once, and the old name put back on a refusal or a failure. The sets and credentials are invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagsRenameTests {
    private static let refusal = "Sample rename refusal from the site"
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: green, tags: [])
    private static let holds = MyTagSet(id: 2, name: "Fixture Holds", isEnabled: false, color: green, tags: [])

    // The row opens the alert with the shown set's name, which each opening starts with again (W-1).
    @MainActor
    @Test
    func theRowOpensTheAlertWithTheSetsName() async {
        let store = makeStore()

        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        await store.send(.renameTagSetNameChanged("Leftover")) {
            $0.renameTagSetName = "Leftover"
        }
        await store.send(.renameTagSetAlert(.dismiss)) {
            $0.renameTagSetAlert = nil
        }
        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
    }

    // Rename waits while the name is blank or, trimmed, still the set's own; Cancel never waits (W-1).
    @MainActor
    @Test
    func renameWaitsForANewNameAndCancelNeverWaits() async throws {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.renameTagSetTapped)
        let alert = try #require(store.state.renameTagSetAlert)
        let field = try #require(alert.textField)
        let renameButton = try #require(alert.buttons.first(where: { $0.role == nil }))
        let cancelButton = try #require(alert.buttons.first(where: { $0.role == .cancel }))
        for unchanged in ["", "   ", "Fixture Picks", " Fixture Picks \n"] {
            #expect(!field.enablesButton(role: renameButton.role, text: unchanged))
            #expect(field.enablesButton(role: cancelButton.role, text: unchanged))
        }
        #expect(field.enablesButton(role: renameButton.role, text: " Fixture Holds "))
        #expect(field.enablesButton(role: renameButton.role, text: "fixture picks"))
    }

    // The picker shows the new name at once, and the site's answer keeps it; the set's own form is posted with the
    // trimmed name (W-1 to W-3).
    @MainActor
    @Test
    func aNewNameShowsAtOnceIsPostedAndTakesTheAnswer() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore {
            $0.renameTagSet = { (host: GalleryHost, name: String, tagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("rename \(host.rawValue) [\(name)] \(tagSet.id) \(tagSet.name)") })
                return Self.page(Self.holds)
            }
        }

        await rename(to: "  Fixture Holds \n", in: store)
        #expect(store.state.selectedTagSet == Self.holds)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.holds], selectedTagSetID: 2))
        #expect(calls.value == ["rename E-Hentai [Fixture Holds] 2 Fixture Picks"])
    }

    // A refusal leaves the set as the site has it, under its old name, with the site's reason on the row (W-3).
    @MainActor
    @Test
    func aRefusedRenamePutsTheOldNameBackWithTheSitesReasonOnTheRow() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set2, message: Self.refusal)
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: Self.refusal)
        }
    }

    // An answer that shows the set under a name other than the new one, with no reason, fails the rename with the
    // unknown error, and the picker shows the name the site has (W-3).
    @MainActor
    @Test
    func aRenameWhoseAnswerShowsAnotherNameShowsTheUnknownError() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set2)
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: AppError.unknown.alertText)
        }
    }

    // An answer that shows another set says nothing of the renamed set's name, so the old name returns, with the
    // unknown error (W-3).
    @MainActor
    @Test
    func aRenameWhoseAnswerShowsAnotherSetPutsTheOldNameBack() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1)
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: AppError.unknown.alertText)
        }
    }

    @MainActor
    @Test
    func aFailedRenamePutsTheOldNameBackWithTheErrorOnTheRow() async {
        let store = makeStore {
            $0.renameTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await rename(to: "Fixture Holds", in: store)
        await store.receive(\.renameTagSetDone) {
            $0.isChangingTagSets = false
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .renameTagSet
            $0.alert = .failure(title: .myTagsRenameFailed, message: AppError.networkingFailed.alertText)
        }
    }

    // A blank name or the set's own is refused here too, though Rename waits for a new one (W-1).
    @MainActor
    @Test(arguments: ["", "   ", "Fixture Picks", " Fixture Picks \n"])
    func aBlankOrUnchangedNameSendsNothing(name: String) async {
        let store = makeStore()

        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        // The set's own name is already the alert's starting value, so that send changes nothing.
        if name == "Fixture Picks" {
            await store.send(.renameTagSetNameChanged(name))
        } else {
            await store.send(.renameTagSetNameChanged(name)) {
                $0.renameTagSetName = name
            }
        }
        await store.send(.renameTagSetAlert(.presented(.rename(tagSetID: 2)))) {
            $0.renameTagSetAlert = nil
        }
    }

    // One such request at a time (W-1): a rename while a create, a rename or a delete is on its way sends nothing, and
    // so does a rename of a set no longer shown.
    @MainActor
    @Test(arguments: zip([true, false], [2, 1]))
    func aRenameWhileATagSetChangeIsOnItsWayOrOfASetNotShownSendsNothing(
        isChangingTagSets: Bool,
        renamedTagSetID: Int
    ) async {
        let store = makeStore(isChangingTagSets: isChangingTagSets)

        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        await store.send(.renameTagSetNameChanged("Fixture Holds")) {
            $0.renameTagSetName = "Fixture Holds"
        }
        await store.send(.renameTagSetAlert(.presented(.rename(tagSetID: renamedTagSetID)))) {
            $0.renameTagSetAlert = nil
        }
    }

    /// A page with set 2 shown and chosen, as every test here starts.
    @MainActor
    private func makeStore(
        isChangingTagSets: Bool = false,
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagsFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        var state = MyTagsFeature.State()
        state.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
        state.isChangingTagSets = isChangingTagSets
        return TestStore(initialState: state, reducer: MyTagsFeature.init) {
            $0.myTagsClient = myTagsClient
        }
    }

    /// Opens Rename Tag Set on set 2, types `name` and taps Rename, asserting each step: the in-flight flag rises and
    /// the picker shows the trimmed name at once. `name`, trimmed, is neither blank nor the set's own.
    @MainActor
    private func rename(to name: String, in store: TestStoreOf<MyTagsFeature>) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        await store.send(.renameTagSetTapped) {
            $0.renameTagSetName = "Fixture Picks"
            $0.renameTagSetAlert = Self.renameTagSetAlert
        }
        await store.send(.renameTagSetNameChanged(name)) {
            $0.renameTagSetName = name
        }
        await store.send(.renameTagSetAlert(.presented(.rename(tagSetID: 2)))) {
            $0.renameTagSetAlert = nil
            $0.isChangingTagSets = true
            $0.$user.withLock({ $0.myTags = $0.myTags?.renaming(2, to: trimmed) })
        }
    }

    /// The Rename Tag Set alert as W-1 specifies it, opened for set 2.
    private static var renameTagSetAlert: AppAlertState<MyTagsFeature.RenameTagSetAlert> {
        AppAlertState(
            title: {
                TextState(localized: .myTagsRenameTagSetTitle)
            },
            textField: AppAlertTextFieldState(
                placeholder: TextState(localized: .myTagsNewTagSetName),
                requiresText: true,
                editedValue: "Fixture Picks"
            ),
            actions: {
                ButtonState(action: .rename(tagSetID: 2)) {
                    TextState(localized: .myTagsRename)
                }
                ButtonState(role: .cancel) {
                    TextState(localized: .RLocalizable.cancel)
                }
            },
            message: {
                TextState(localized: .myTagsRenameTagSetMessage)
            }
        )
    }

    private static func page(_ tagSet: MyTagSet, message: String? = nil) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: [1, 2], apiuid: 1234567, apikey: "0123456789abcdef", message: message)
    }
}
```

#### S11: `AppPackage/Sources/NetworkingFeature/Request+MyTags.swift` (Task 3)

**S11a.** Replace:

```swift
/// The API answers `{"tagid": <id>}` when it took the edit and `{"error": "<reason>", …}` when it refused it. Its
/// success is no proof the tag exists: an unknown tag id is answered the same way and changes nothing.
```

with:

```swift
/// The API answers `{"tagid": <id>}` when it took the edit and `{"error": "<reason>", …}` when it refused it. Its
/// success is no proof the tag exists: an unknown tag id is answered the same way and changes nothing. An answer with
/// `login` means the session is no longer signed in, which the site's page answers by going to its login page; it
/// fails as `loginRequired` (W-5 of quick 261126-wzf).
```

**S11b.** Replace:

```swift
                let reply = try JSONDecoder().decode(SetUserTagReply.self, from: body)
                if let error = reply.error {
```

with:

```swift
                let reply = try JSONDecoder().decode(SetUserTagReply.self, from: body)
                if reply.asksToLogIn {
                    throw AppError.loginRequired
                }
                if let error = reply.error {
```

**S11c.** Replace:

```swift
/// The edit API's reply: the tag's id when it took the edit, the reason when it refused it.
private struct SetUserTagReply: Decodable {
    let tagID: Int?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case tagID = "tagid"
        case error
    }
}
```

with:

```swift
/// The edit API's reply: the tag's id when it took the edit, the reason when it refused it, and whether it asks for a
/// login (W-5 of quick 261126-wzf).
private struct SetUserTagReply: Decodable {
    let tagID: Int?
    let error: String?
    /// The reply carries `login` with any value but null, the test the site's `api_response` makes
    /// (`void 0 != a.login`) before it goes to the login page.
    let asksToLogIn: Bool

    private enum CodingKeys: String, CodingKey {
        case tagID = "tagid"
        case error
        case login
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagID = try container.decodeIfPresent(Int.self, forKey: .tagID)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        if container.contains(.login) {
            asksToLogIn = try !container.decodeNil(forKey: .login)
        } else {
            asksToLogIn = false
        }
    }
}
```

#### S12: `AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift` (Task 3)

**S12a.** Replace:

```swift
/// outcome (`Delegate`). Close discards the changes without asking.
```

with:

```swift
/// outcome (`Delegate`). Close discards the changes without asking. A request answered that the session ended keeps the
/// sheet open with its alert and tells the host too, whose page shows its signed-out state (W-5 of quick 261126-wzf).
```

**S12b.** Replace:

```swift
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        case saved
        case removed
    }
```

with:

```swift
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        case saved
        case removed
        /// A request answered that the session is no longer signed in (W-5 of quick 261126-wzf). The sheet stays open
        /// with the changes and its alert; the host shows its signed-out state beneath it.
        case signedOut
    }
```

**S12c.** Replace:

```swift
            case .addDone(.failure(let error)):
                state.running = nil
                return presentAlert(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, message: error.alertText)
```

with:

```swift
            case .addDone(.failure(let error)):
                state.running = nil
                return presentFailure(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, error: error)
```

**S12d.** Replace:

```swift
            case .updateDone(_, .failure(let error)):
                state.running = nil
                return presentAlert(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, message: error.alertText)
```

with:

```swift
            case .updateDone(_, .failure(let error)):
                state.running = nil
                return presentFailure(&state, .confirm, title: .RLocalizable.myTagsSaveFailed, error: error)
```

**S12e.** Replace:

```swift
            case .removeDone(.failure(let error)):
                state.running = nil
                return presentAlert(&state, .remove, title: .RLocalizable.myTagsRemoveFailed, message: error.alertText)
```

with:

```swift
            case .removeDone(.failure(let error)):
                state.running = nil
                return presentFailure(&state, .remove, title: .RLocalizable.myTagsRemoveFailed, error: error)
```

**S12f.** Directly above:

```swift
    private func presentAlert(
        _ state: inout State,
        _ source: Control,
```

insert:

```swift
    /// A request's failure: the alert on the control that sent it; an ended session also tells the host (W-5 of quick
    /// 261126-wzf).
    private func presentFailure(
        _ state: inout State,
        _ source: Control,
        title: LocalizedStringResource,
        error: AppError
    ) -> Effect<Action> {
        let alert = presentAlert(&state, source, title: title, message: error.alertText)
        guard error == .loginRequired else { return alert }
        return .merge(alert, .send(.delegate(.signedOut)))
    }

```

The inserted block ends with a blank line.

#### S13: `AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift` (Task 3)

**S13.** Directly above:

```swift
    /// The edit API's request body; the credentials are the fixtures' invented ones.
```

insert:

```swift
    // An answer with `login` means the session ended: any value but null, as the site's own script reads it, fails the
    // edit as `loginRequired` (W-5 of quick 261126-wzf).
    @Test(arguments: [#"{"login":1}"#, #"{"login":"sample"}"#])
    func aLoginAnswerFailsTheEditAsLoginRequired(reply: String) async throws {
        let url = try #require(Self.apiURL)
        let data = Data(reply.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: data)]]))
        defer { cleanUp(session: session, handle: handle) }
        let tag = MyTag(
            id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
        )

        let result = await capture { () async throws(AppError) -> MyTagEditReply in
            try await UpdateMyTagRequest(
                host: .ehentai, apiuid: 1234567, apikey: "0123456789abcdef", tag: tag, urlSession: session
            )
            .response()
        }

        #expect(result == .failure(.loginRequired))
    }

    // A null `login` is no such answer, as the site's script reads it (W-5 of quick 261126-wzf).
    @Test
    func aNullLoginIsNoLoginAnswer() async throws {
        let url = try #require(Self.apiURL)
        let reply = Data(#"{"login":null,"tagid":101}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: reply)]]))
        defer { cleanUp(session: session, handle: handle) }
        let tag = MyTag(
            id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
        )

        #expect(try await update(tag, session: session) == .accepted)
    }

```

The inserted block ends with a blank line.

#### S14: `AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift` (Task 3)

**S14a.** Replace:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions, the colour
// code's check and the weight field (quick 261126-wzg). The tags, sets and suggestions are invented.
```

with:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions, the colour
// code's check and the weight field (quick 261126-wzg); an ended session (quick 261126-wzf). The tags, sets and
// suggestions are invented.
```

**S14b.** Directly above:

```swift
    // The site's tag completer asks 200 ms after the text last changed, and its list keeps the answer's entries whose
    // name holds the text at the start of a word (G-1, G-4 of quick 261126-wzg).
```

insert:

```swift
    // An edit or a remove answered that the session ended keeps the sheet open with its alert and tells the host, whose
    // page shows its signed-out state beneath it (W-5 of quick 261126-wzf).
    @MainActor
    @Test
    func anEndedSessionKeepsTheAlertAndTellsTheHost() async {
        let dismissed = LockIsolated(0)
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: Self.glasses, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            },
            dismissed: dismissed
        ) {
            $0.updateTag = { (_: GalleryHost, _: Int, _: String, _: MyTag) async throws(AppError) -> MyTagEditReply in
                throw .loginRequired
            }
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
        }

        await store.send(.binding(.set(\.weight, 99))) {
            $0.weight = 99
            $0.weightText = "99"
        }
        await store.send(.confirmTapped) {
            $0.running = .confirm
        }
        await store.receive(\.updateDone) {
            $0.running = nil
            $0.alertSource = .confirm
            $0.alert = .failure(title: .RLocalizable.myTagsSaveFailed, message: AppError.loginRequired.alertText)
        }
        await store.receive(\.delegate.signedOut)
        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        await store.send(.removeTapped) {
            $0.running = .remove
        }
        await store.receive(\.removeDone.failure) {
            $0.running = nil
            $0.alertSource = .remove
            $0.alert = .failure(title: .RLocalizable.myTagsRemoveFailed, message: AppError.loginRequired.alertText)
        }
        await store.receive(\.delegate.signedOut)
        #expect(dismissed.value == 0)
    }

```

The inserted block ends with a blank line.

#### S15: `AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift` (Task 4)

**S15a.** Replace:

```swift
/// shows the alert on the row (quick 261126-wzf).
@Reducer
```

with:

```swift
/// shows the alert on the row (quick 261126-wzf).
///
/// A read or a write the site answers as signed out shows Log In, as the page does signed out, instead of the error or
/// an alert; so does Edit Tag's, beneath its sheet. A sign-in then reads every set again (W-5 of quick 261126-wzf).
@Reducer
```

**S15b.** Directly below:

```swift
        /// The site's page the browser sheet shows; get-only, so the sheet binds through `browserChanged`.
        public var browserURL: URL? { destination?.browser }
```

insert:

```swift
        /// The site answered a read or a write as signed out (W-5 of quick 261126-wzf): the page shows Log In, as it
        /// does signed out, until a read after a sign-in succeeds, since every read starts by loading.
        public var isSessionExpired: Bool { loadingState == .failed(.loginRequired) }
```

**S15c.** Directly above:

```swift
            case .fetchMyTagsDone(.failure(let error)), .fetchTagSetDone(.failure(let error)):
                state.loadingState = .failed(error)
                return .none
```

insert:

```swift
            // A read answered as signed out fails as `loginRequired`, which shows Log In (`isSessionExpired`).
```

**S15d.** Replace:

```swift
                state.confirmedTagSet = nil
                return presentAlert(&state, source, title: .RLocalizable.myTagsSaveFailed, message: error.alertText)
```

with:

```swift
                state.confirmedTagSet = nil
                return presentFailure(&state, source, title: .RLocalizable.myTagsSaveFailed, error: error)
```

**S15e.** Replace:

```swift
            case .removeTagDone(let tagID, .failure(let error)):
                return presentAlert(
                    &state, .tag(tagID), title: .RLocalizable.myTagsRemoveFailed, message: error.alertText
                )
```

with:

```swift
            case .removeTagDone(let tagID, .failure(let error)):
                return presentFailure(&state, .tag(tagID), title: .RLocalizable.myTagsRemoveFailed, error: error)
```

**S15f.** Replace:

```swift
            case .createTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentAlert(
                    &state, .newTagSet, title: .myTagsCreateTagSetFailed, message: error.alertText
                )
```

with:

```swift
            case .createTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentFailure(&state, .newTagSet, title: .myTagsCreateTagSetFailed, error: error)
```

**S15g.** Replace:

```swift
                state.$user.withLock({ $0.myTags = $0.myTags?.renaming(tagSetID, to: oldName) })
                return presentAlert(&state, .renameTagSet, title: .myTagsRenameFailed, message: error.alertText)
```

with:

```swift
                state.$user.withLock({ $0.myTags = $0.myTags?.renaming(tagSetID, to: oldName) })
                return presentFailure(&state, .renameTagSet, title: .myTagsRenameFailed, error: error)
```

**S15h.** Replace:

```swift
            case .deleteTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentAlert(
                    &state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: error.alertText
                )
```

with:

```swift
            case .deleteTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentFailure(&state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, error: error)
```

**S15i.** Directly below:

```swift
            case .destination(.presented(.editor(.delegate(.removed)))):
                state.toast = .success(caption: .RLocalizable.myTagsRemoved)
                return .none
```

insert:

```swift

            // Edit Tag keeps its alert, and the page beneath shows Log In (W-5 of quick 261126-wzf).
            case .destination(.presented(.editor(.delegate(.signedOut)))):
                state.loadingState = .failed(.loginRequired)
                return .none
```

The inserted block starts with a blank line.

**S15j.** Directly above:

```swift
    private func presentAlert(
        _ state: inout State,
        _ source: AlertSource,
```

insert:

```swift
    /// A write's failure: an answer as signed out shows Log In instead of an alert (W-5 of quick 261126-wzf); any other
    /// failure shows the alert on the control that sent it.
    private func presentFailure(
        _ state: inout State,
        _ source: AlertSource,
        title: LocalizedStringResource,
        error: AppError
    ) -> Effect<Action> {
        guard error != .loginRequired else {
            state.loadingState = .failed(.loginRequired)
            return .none
        }
        return presentAlert(&state, source, title: title, message: error.alertText)
    }

```

The inserted block ends with a blank line.

#### S16: `AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift` (Task 4)

**S16a.** Replace:

```swift
/// opens Edit Tag and a trailing swipe removes the tag. Add Tag sits in the toolbar. Signed out it shows Log In;
/// loading, the loading view; failed, the error with Open in Browser.
```

with:

```swift
/// opens Edit Tag and a trailing swipe removes the tag. Add Tag sits in the toolbar. Signed out, or once the site
/// answers as signed out, it shows Log In; loading, the loading view; failed, the error with Open in Browser.
```

**S16b.** Replace:

```swift
    /// The page in its state: Log In signed out, the error with Open in Browser, the set's form, else loading.
    @ContentBuilder private var content: some View {
        if !didLogin {
```

with:

```swift
    /// The page in its state: Log In signed out or once the site answers as signed out (W-5 of quick 261126-wzf), the
    /// error with Open in Browser, the set's form, else loading.
    @ContentBuilder private var content: some View {
        if !didLogin || store.isSessionExpired {
```

#### S17: `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift` (Task 4)

**S17a.** Replace:

```swift
            // Login is a top-level stack element; it self-dismisses on success while Setting runs
            // the post-login setup.
            case .path(.element(id: _, action: .login(.loginDone))):
                return .merge(
```

with:

```swift
            // Login is a top-level stack element; it self-dismisses on success while Setting runs
            // the post-login setup. A My Tags page on the stack reads every set again too (W-5 of quick
            // 261126-wzf): a session the site ended leaves its cookies in place, so the page's own watch for a
            // sign-in, which waits for them to arrive, never fires.
            case .path(.element(id: _, action: .login(.loginDone))):
                let myTagsReads = state.path.ids
                    .filter({ state.path[id: $0]?.is(\.myTags) == true })
                    .map({ Effect<Action>.send(.path(.element(id: $0, action: .myTags(.fetchMyTags)))) })
                return .merge(
```

**S17b.** Replace:

```swift
                    .send(.fetchMyTags),
                    .send(.fetchEhProfileIndex)
                )
```

with:

```swift
                    .send(.fetchMyTags),
                    .send(.fetchEhProfileIndex),
                    .merge(myTagsReads)
                )
```

#### S18: `AppPackage/Tests/SettingFeatureTests/MyTagsSessionTests.swift` (Task 4, new file)

The whole file:

```swift
import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import HapticsClient
import MyTagEditor
import MyTagsClient
import Resources
@testable import SettingFeature
import Sharing
import Testing
import TestingSupport

// The My Tags page when the site answers as signed out (quick 261126-wzf): a read, a write and Edit Tag's request show
// Log In instead of the error or an alert, and a sign-in reads every set again. The tags, sets and credentials are
// invented.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct MyTagsSessionTests {
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [glasses])
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])
    private static let response = MyTagsResponse(
        myTags: MyTags(tagSets: [set1, set2]), apiuid: 1234567, apikey: "0123456789abcdef"
    )

    // A read answered as signed out shows Log In rather than the error, and the next read starts by loading, which
    // clears it (W-5).
    @MainActor
    @Test
    func aReadAnsweredAsSignedOutShowsLogInUntilAReadSucceeds() async {
        let reads = LockIsolated(0)
        let store = makeStore {
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) -> MyTagsResponse in
                reads.withValue({ $0 += 1 })
                guard reads.value > 1 else { throw .loginRequired }
                return Self.response
            }
        }

        await store.send(.fetchMyTags) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchMyTagsDone.failure) {
            $0.loadingState = .failed(.loginRequired)
        }
        #expect(store.state.isSessionExpired)
        #expect(store.state.alert == nil)

        await store.send(.fetchMyTags) {
            $0.loadingState = .loading
        }
        #expect(!store.state.isSessionExpired)
        await store.receive(\.fetchMyTagsDone.success) {
            $0.loadingState = .idle
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
    }

    // A chosen set's read answered as signed out shows Log In too (W-5).
    @MainActor
    @Test
    func aSetsReadAnsweredAsSignedOutShowsLogIn() async {
        let store = makeStore {
            $0.fetchTagSet = { (_: GalleryHost, _: Int) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
        }

        await store.send(.tagSetSelected(2)) {
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.failure) {
            $0.loadingState = .failed(.loginRequired)
        }
        #expect(store.state.isSessionExpired)
    }

    // A write answered as signed out shows Log In and no alert; a write that changed the set at once still puts it
    // back, and the tag set rows are released (W-5).
    @MainActor
    @Test
    func aWriteAnsweredAsSignedOutShowsLogInWithoutAnAlert() async {
        let off = MyTagSet(id: 1, name: "Tagset #1", isEnabled: false, color: nil, tags: [Self.glasses])
        let store = makeStore {
            $0.updateTagSet = { (_: GalleryHost, _: Int, _: Bool, _: SiteColor?) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
            $0.removeTags = { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .loginRequired
            }
        }

        await store.send(.enabledChanged(false)) {
            $0.confirmedTagSet = Self.set1
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [off, Self.set2]) })
        }
        await store.receive(\.updateTagSetDone) {
            $0.confirmedTagSet = nil
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
            $0.loadingState = .failed(.loginRequired)
        }

        await store.send(.removeSwiped(Self.glasses))
        await store.receive(\.removeTagDone)

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged("Fixture Holds")) {
            $0.newTagSetName = "Fixture Holds"
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
            $0.isChangingTagSets = true
        }
        await store.receive(\.createTagSetDone) {
            $0.isChangingTagSets = false
        }
        #expect(store.state.isSessionExpired)
        #expect(store.state.alert == nil)
    }

    // Edit Tag keeps its alert, and the page beneath shows Log In (W-5).
    @MainActor
    @Test
    func editTagsEndedSessionShowsLogInBeneathIt() async {
        let store = makeStore(credentials: true)
        store.exhaustivity = .off

        await store.send(.tagTapped(Self.glasses))
        await store.send(.destination(.presented(.editor(.delegate(.signedOut)))))
        #expect(store.state.isSessionExpired)
        #expect(store.state.destination?.editor != nil)
    }

    // Log In opens the login page; once it is done, the My Tags page on the stack reads every set again, whatever its
    // cookies said before (W-5).
    @MainActor
    @Test
    func aSignInReadsTheMyTagsPageOnTheStackAgain() async throws {
        var state = SettingReducer.State()
        state.path.append(.myTags(.init()))
        let store = TestStore(initialState: state, reducer: SettingReducer.init) {
            $0.analyticsClient = .noop
            $0.cookieClient = .noop
            $0.hapticsClient = .noop
            $0.myTagsClient.fetchMyTags = { (_: GalleryHost) async throws(AppError) in Self.response }
        }
        store.exhaustivity = .off
        let myTagsID = try #require(store.state.path.ids.last)

        await store.send(.path(.element(id: myTagsID, action: .myTags(.delegate(.pushLogin)))))
        let loginID = try #require(store.state.path.ids.last)
        #expect(store.state.path[id: loginID]?.is(\.login) == true)
        await store.send(.path(.element(id: loginID, action: .login(.loginDone(.success(nil))))))
        await store.receive(\.path[id: myTagsID].myTags.fetchMyTags)
        await store.receive(\.path[id: myTagsID].myTags.fetchMyTagsDone.success)
        #expect(store.state.user.myTags == Self.response.myTags)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    private func makeStore(
        credentials: Bool = false,
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagsFeature> {
        var myTagsClient = MyTagsClient.unimplemented
        client(&myTagsClient)
        var state = MyTagsFeature.State()
        state.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2]) })
        if credentials {
            state.apiuid = 1234567
            state.apikey = "0123456789abcdef"
        }
        return TestStore(initialState: state, reducer: MyTagsFeature.init) {
            $0.myTagsClient = myTagsClient
        }
    }

    /// The New Tag Set alert as N-2 and N-3 of quick 261126-pfh specify it.
    private static var newTagSetAlert: AppAlertState<MyTagsFeature.NewTagSetAlert> {
        AppAlertState(
            title: {
                TextState(localized: .myTagsNewTagSetTitle)
            },
            textField: AppAlertTextFieldState(
                placeholder: TextState(localized: .myTagsNewTagSetName),
                requiresText: true
            ),
            actions: {
                ButtonState(action: .create) {
                    TextState(localized: .myTagsNewTagSetCreate)
                }
                ButtonState(role: .cancel) {
                    TextState(localized: .RLocalizable.cancel)
                }
            },
            message: {
                TextState(localized: .myTagsNewTagSetMessage)
            }
        )
    }
}
```

</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RenameMyTagSetRequest, MyTagsClient.renameTagSet and the cache's rename (W-2, W-3, W-6)</name>
  <files>AppPackage/Sources/AppModels/Tags/MyTags.swift, AppPackage/Sources/NetworkingFeature/Request+MyTags.swift, AppPackage/Sources/MyTagsClient/MyTagsClient.swift, AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift, AppPackage/Tests/AppModelsTests/MyTagsTests.swift</files>
  <precondition>The Precondition section above holds (wzg landed, clean tree apart from the planning directories).</precondition>
  <read_first>
    - .planning/quick/261126-wzf-my-tags-tag-set-rename-counts-and-sessio/261126-wzf-CONTEXT.md (Site contract, W-2, W-3)
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift (whole file; `tagSetFormFields`, `postMyTagsForm`, `CreateMyTagSetRequest`, `DeleteMyTagSetRequest`)
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift (whole file)
    - AppPackage/Sources/AppModels/Tags/MyTags.swift lines 110-240 (`MyTagSet`, `MyTags`)
    - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift (the create and delete tests and their helpers) and AppPackage/Tests/NetworkingFeatureTests/Support/RequestHarness.swift
    - .swiftlint.yml (custom rules)
  </read_first>
  <behavior>
    - A rename posts `tagset_action=rename&tagset_name=Picks%20%26%20Holds&tagset_enable=on&tagset_color=%2322AA55` for an enabled set with a colour, and `tagset_action=rename&tagset_name=Fixture%20Holds&tagset_color=` for a disabled set without one, to that set's page, and answers the parsed page (W-2).
    - A rename that fails in transport is put on the wire once (W-2, P-4).
    - `MyTags.renaming(_:to:)` renames one set and keeps every other set, the tags and the selection; renaming back restores the cache; an unknown id changes nothing (W-3).
    - `MyTagsClient.renameTagSet` exists in `live` (the request), `noop` (throws `notFound`), `unimplemented` and `failing(_:)` (P-5).
  </behavior>
  <action>
Write the tests first (RED: `RenameMyTagSetRequest` does not exist; run `-only-testing:NetworkingFeatureTests` once with
log `task1-red.log`), then the code.

1. Tests (W-6): apply S4a and S4b to `MyTagsRequestTests.swift` and S5 to `MyTagsTests.swift`. Both use the existing
   stub session and fixtures, so nothing opens a socket; neither suite carries the app-storage trait (settled fact 9).
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `RenameMyTagSetRequest`.
3. Model (W-3, settled fact 3): apply S1a and S1b to `MyTags.swift`.
4. Request (W-2, P-4): apply S2a to S2c to `Request+MyTags.swift`; the rename reuses `tagSetFormFields` and
   `postMyTagsForm` with `attempts: 1`.
5. Client (P-5): apply S3a to S3g to `MyTagsClient.swift`. Nothing else in the file changes.
6. Run the verify lines, then commit.

Commit subject: `tags: ask the site to rename a tag set`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:NetworkingFeatureTests 2>&1 | tee .capture/261126-wzf/task1-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 to 5; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzf/task1-red.log | grep -c 'RenameMyTagSetRequest'   [EXPECT>=1]</automated>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:AppModelsTests -only-testing:NetworkingFeatureTests -only-testing:SettingFeatureTests -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-wzf/task1-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzf/task1-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzf/task1-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsRequestTests/[A-Za-z]+" .capture/261126-wzf/task1-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=15 EXPECT==17]</automated>
    <automated>grep -cE "Test case 'MyTagsRequestTests/[^']*' passed" .capture/261126-wzf/task1-tests.log   [HEAD=18 EXPECT==20]</automated>
    <automated>grep -oE "Test case 'MyTagsTests/[A-Za-z]+" .capture/261126-wzf/task1-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=14 EXPECT==15]</automated>
    <automated>grep -cE "Test case 'MyTagsTests/[^']*' passed" .capture/261126-wzf/task1-tests.log   [HEAD=22 EXPECT==23]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/AppModels AppPackage/Sources/NetworkingFeature AppPackage/Sources/MyTagsClient AppPackage/Tests/AppModelsTests AppPackage/Tests/NetworkingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>python3 -I Scripts/lint/app_storage_isolation.py check   [HEAD: 0 break(s); EXPECT: 0 break(s) of the app-storage isolation rule.]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -cF 'tagSetFormFields(action: "rename", name: name, isEnabled: tagSet.isEnabled, color: tagSet.color)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -cF 'attempts: 1)'   [HEAD=2 EXPECT==3]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'renameTagSet:'   [HEAD=0 EXPECT==5]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppModels/Tags/MyTags.swift | grep -cF 'public func renaming(_ tagSetID: Int, to name: String) -> MyTags'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppModels/Tags/MyTags.swift | grep -cF 'public internal(set) var name: String'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on `RenameMyTagSetRequest`; then AppModelsTests, NetworkingFeatureTests, SettingFeatureTests and DetailFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with 17 request test names (20 cases) and 15 model test names (23 cases) listed as passed; no warning, lint clean, isolation gate clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: ask the site to rename a tag set` holding exactly the five files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: The Rename Tag Set row and its alert, with the new name shown at once (W-1, W-3, W-6)</name>
  <files>AppPackage/Sources/AppComponents/AppAlertState.swift, AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift, AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift, AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings, AppPackage/Tests/SettingFeatureTests/MyTagsRenameTests.swift</files>
  <precondition>Task 1 is committed.</precondition>
  <read_first>
    - AppPackage/Sources/AppComponents/AppAlertState.swift (whole file)
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift and AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift (whole files; the New Tag Set and Delete Tag Set flows this follows)
    - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift lines 1-60 and its New Tag Set tests
    - CLAUDE.md "Confirmation dialog / alert placement" and "Non-translated keys need every locale filled"
  </read_first>
  <behavior>
    - The row opens the alert titled `my_tags.rename_tag_set.title` with the shown set's name in the field (its `editedValue`), the prompt `my_tags.new_tag_set.name`, Rename and Cancel, and the message `my_tags.rename_tag_set.message` (W-1, P-6).
    - Rename is held while the trimmed text is empty or the set's name and enabled for a new name; Cancel is never held (W-1, P-6, P-8).
    - A new name shows in the picker at once, sets the in-flight flag, is posted for the shown set, and the answer page is taken (W-3).
    - A refusal (`#msg`) puts the old name back and shows `my_tags.rename_failed` with the reason on the Rename row; an answer listing another name shows the unknown error; an answer showing another set puts the old name back; a failure puts the old name back with the error's text (W-3, P-9).
    - A blank, spaces-only or unchanged name sends nothing, nor does a rename while a tag set change is on its way or of a set no longer shown (W-1, P-10).
  </behavior>
  <action>
Write the tests first (RED: the page has no rename members and the alert field no `editedValue`, so
SettingFeatureTests does not compile; run `-only-testing:SettingFeatureTests` once with log `task2-red.log`), then the
code and the copy.

1. Tests (W-6): create `AppPackage/Tests/SettingFeatureTests/MyTagsRenameTests.swift` with S10 (it carries
   `@Suite(.isolatedAppStorage)` and imports TestingSupport, settled fact 9; P-18).
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `renameTagSetTapped`,
   `renameTagSetAlert`, `RenameTagSetAlert`, `renameTagSetName`, `editedValue` or a `myTagsRename` symbol.
3. `AppAlertState.swift` (W-1, P-6, P-7): apply S7a and S7b. The field's `TextField`, its focusing `onAppear` and the
   file's existing lint suppression above it stay as they are; nothing selects the text.
4. `MyTagsFeature.swift` (W-1, W-3, P-8 to P-10): apply S8a to S8j.
5. `MyTagsView.swift` (W-1, P-10): apply S9a and S9b. Both the text-field alert and the failure alert attach to the
   Rename row (CLAUDE.md alert placement); the Tag Set picker is not touched.
6. Copy (CONTEXT copy table, P-19): copy S6 to `.capture/261126-wzf/insert_copy.py` exactly, then from the
   repository root run
   `python3 -I .capture/261126-wzf/insert_copy.py insert my_tags.rename_tag_set my_tags.rename_tag_set.title my_tags.rename_tag_set.message my_tags.rename my_tags.rename_failed`;
   it prints `ok`. The script writes SettingFeature's catalog only.
7. Run the verify lines, then commit.

Commit subject: `settings: add Rename Tag Set to My Tags`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:SettingFeatureTests 2>&1 | tee .capture/261126-wzf/task2-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 to 6; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzf/task2-red.log | grep -cE 'renameTagSetTapped|renameTagSetAlert|RenameTagSetAlert|renameTagSetName|editedValue|myTagsRename'   [EXPECT>=1]</automated>
    <automated>python3 -I .capture/261126-wzf/insert_copy.py check my_tags.rename_tag_set my_tags.rename_tag_set.title my_tags.rename_tag_set.message my_tags.rename my_tags.rename_failed   [HEAD: KeyError: 'my_tags.rename_tag_set'; EXPECT: ok]</automated>
    <automated>git diff --numstat -- AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings   [HEAD: no output; EXPECT before the commit: "205	0	AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings"]</automated>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:SettingFeatureTests -only-testing:HomeFeatureTests -only-testing:AppToolsTests 2>&1 | tee .capture/261126-wzf/task2-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzf/task2-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzf/task2-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsRenameTests/[A-Za-z]+" .capture/261126-wzf/task2-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=0 EXPECT==9]</automated>
    <automated>grep -cE "Test case 'MyTagsRenameTests/[^']*' passed" .capture/261126-wzf/task2-tests.log   [HEAD=0 EXPECT==13]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/AppComponents AppPackage/Sources/SettingFeature AppPackage/Tests/SettingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>python3 -I Scripts/lint/app_storage_isolation.py check   [HEAD: 0 break(s); EXPECT: 0 break(s) of the app-storage isolation rule.]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/AppAlertState.swift | grep -cF 'editedValue: String? = nil'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/AppAlertState.swift | grep -cF 'return trimmed != editedValue'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'editedValue: tagSet.name'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF '.ifLet(\.$renameTagSetAlert, action: \.renameTagSetAlert)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'try await myTagsClient.renameTagSet(host, name, tagSet)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF 'Button(.myTagsRenameTagSet)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF '.appAlert(alert(for: .renameTagSet))'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing rename members; `insert_copy.py check` prints `ok` for the five keys and the catalog diff is 205 insertions, 0 deletions; SettingFeatureTests, HomeFeatureTests and AppToolsTests pass (TEST SUCCEEDED, 0 failed cases) with the nine rename test names (13 cases) listed as passed; no warning, lint clean, isolation gate clean; every gate prints its EXPECT value; one signed `+08:00` commit `settings: add Rename Tag Set to My Tags` holding exactly the five files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: A login answer fails Edit Tag as loginRequired and the sheet tells its host (W-5, W-6)</name>
  <files>AppPackage/Sources/NetworkingFeature/Request+MyTags.swift, AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift, AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift, AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift</files>
  <precondition>Task 2 is committed.</precondition>
  <read_first>
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift (`UpdateMyTagRequest`, `SetUserTagReply`, as Task 1 left it)
    - AppPackage/Sources/NetworkingFeature/Request.swift lines 140-220 (`parseResponse`, `mapAppError`)
    - AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift (whole file)
    - AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift (whole file) and the edit tests in AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift
  </read_first>
  <behavior>
    - An edit answered `{"login":1}` or `{"login":"sample"}` fails as `loginRequired`; `{"login":null,"tagid":101}` is accepted (W-5, P-13).
    - Edit Tag answered as signed out (an update, a remove) keeps the sheet and its alert on the control that sent it, and sends `.delegate(.signedOut)` (W-5, P-15).
  </behavior>
  <action>
Write the tests first (RED: `MyTagEditorFeature.Delegate` has no `signedOut`; run `-only-testing:DetailFeatureTests`
once with log `task3-red.log`), then the code.

1. Tests (W-6): apply S13 to `MyTagsRequestTests.swift` and S14a and S14b to `MyTagEditorTests.swift`.
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `signedOut`.
3. Request (W-5, P-13): apply S11a to S11c to `Request+MyTags.swift`.
4. Editor (W-5, P-15): apply S12a to S12f to `MyTagEditorFeature.swift`.
5. Run the verify lines, then commit.

Commit subject: `tags: report an expired session from the editor`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-wzf/task3-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 and 4; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzf/task3-red.log | grep -c 'signedOut'   [EXPECT>=1]</automated>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:NetworkingFeatureTests -only-testing:DetailFeatureTests -only-testing:SettingFeatureTests 2>&1 | tee .capture/261126-wzf/task3-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzf/task3-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzf/task3-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsRequestTests/[A-Za-z]+" .capture/261126-wzf/task3-tests.log | sort -u | wc -l | tr -d ' '   [HEAD (after Task 1)=17 EXPECT==19]</automated>
    <automated>grep -cE "Test case 'MyTagsRequestTests/[^']*' passed" .capture/261126-wzf/task3-tests.log   [HEAD (after Task 1)=20 EXPECT==23]</automated>
    <automated>grep -oE "Test case 'MyTagEditorTests/[A-Za-z]+" .capture/261126-wzf/task3-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=21 EXPECT==22]</automated>
    <automated>grep -cE "Test case 'MyTagEditorTests/[^']*' passed" .capture/261126-wzf/task3-tests.log   [HEAD=39 EXPECT==40]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/NetworkingFeature AppPackage/Sources/MyTagEditor AppPackage/Tests/NetworkingFeatureTests AppPackage/Tests/DetailFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>python3 -I Scripts/lint/app_storage_isolation.py check   [HEAD: 0 break(s); EXPECT: 0 break(s) of the app-storage isolation rule.]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -cF 'throw AppError.loginRequired'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF 'case signedOut'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF 'presentFailure(&state'   [HEAD=0 EXPECT==3]</automated>
  </verify>
  <done>The RED run failed to compile on `signedOut`; then NetworkingFeatureTests, DetailFeatureTests and SettingFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with 19 request test names (23 cases) and 22 editor test names (40 cases) listed as passed; no warning, lint clean, isolation gate clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: report an expired session from the editor` holding exactly the four files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: My Tags shows Log In for an ended session and reads again after a sign-in (W-5, W-6)</name>
  <files>AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift, AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift, AppPackage/Sources/SettingFeature/SettingReducer+Body.swift, AppPackage/Tests/SettingFeatureTests/MyTagsSessionTests.swift</files>
  <precondition>Task 3 is committed.</precondition>
  <read_first>
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift and AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift (whole files, as Task 2 left them)
    - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift lines 230-290 (`fetchMyTags`, the `loginDone` case)
    - AppPackage/Tests/SettingFeatureTests/MyTagsLaunchFetchTests.swift (a Settings-level store with its noop clients)
  </read_first>
  <behavior>
    - A read answered as signed out shows Log In and no alert; the next read starts by loading, which clears it (W-5, P-14).
    - A chosen set's read answered as signed out shows Log In (W-5).
    - A write (Enabled, a swipe removal, New Tag Set) answered as signed out shows Log In with no alert; the Enabled change is put back and the tag set rows are released (W-5, P-14).
    - Edit Tag's `signedOut` leaves the sheet up and the page beneath in its signed-out state (W-5, P-15).
    - Log In pushes Login; its `loginDone` makes the My Tags page on the stack read every set again (W-5, P-16).
  </behavior>
  <action>
Write the tests first (RED: the page has no `isSessionExpired`; run `-only-testing:SettingFeatureTests` once with log
`task4-red.log`), then the code.

1. Tests (W-6): create `AppPackage/Tests/SettingFeatureTests/MyTagsSessionTests.swift` with S18 (it carries
   `@Suite(.isolatedAppStorage)` and imports TestingSupport, settled fact 9; P-18).
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `isSessionExpired`.
3. `MyTagsFeature.swift` (W-5, P-14, P-15): apply S15a to S15j. Every write failure now goes through
   `presentFailure`, which shows the signed-out state for `loginRequired` and the alert for anything else.
4. `MyTagsView.swift` (W-5): apply S16a and S16b. The view keeps its `scrollEdgeEffectStyle` modifiers and the Tag
   Set picker as they are.
5. `SettingReducer+Body.swift` (W-5, P-16): apply S17a and S17b.
6. Run the verify lines, then commit.

Commit subject: `settings: show Log In when My Tags is signed out`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:SettingFeatureTests 2>&1 | tee .capture/261126-wzf/task4-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 to 5; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzf/task4-red.log | grep -c 'isSessionExpired'   [EXPECT>=1]</automated>
    <automated>mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:SettingFeatureTests -only-testing:AppFeatureTests 2>&1 | tee .capture/261126-wzf/task4-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzf/task4-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzf/task4-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsSessionTests/[A-Za-z]+" .capture/261126-wzf/task4-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=0 EXPECT==5]</automated>
    <automated>grep -cE "Test case 'MyTagsSessionTests/[^']*' passed" .capture/261126-wzf/task4-tests.log   [HEAD=0 EXPECT==5]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/SettingFeature AppPackage/Tests/SettingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>python3 -I Scripts/lint/app_storage_isolation.py check   [HEAD: 0 break(s); EXPECT: 0 break(s) of the app-storage isolation rule.]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'presentFailure(&state'   [HEAD=0 EXPECT==5]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'message: error.alertText'   [HEAD (after Task 2)=5 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'case .destination(.presented(.editor(.delegate(.signedOut)))):'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF 'if !didLogin || store.isSessionExpired {'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/SettingReducer+Body.swift | grep -cF '.merge(myTagsReads)'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on `isSessionExpired`; then SettingFeatureTests and AppFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the five session tests listed as passed; no warning, lint clean, isolation gate clean; every gate prints its EXPECT value; one signed `+08:00` commit `settings: show Log In when My Tags is signed out` holding exactly the four files.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app to site | The rename form (new name, Enabled, colour) and the edit API's JSON are posted with the session's cookies, as the site's own My Tags page posts them |
| site to app | The answer page (the picker's names, `#msg`) and the edit API's answer (`tagid`, `error`, `login`) are parsed into the cache and the page's state |
| user to site | The typed tag set name crosses into the site's rename |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261126-wzf-01 | Tampering | `RenameMyTagSetRequest` replay after a lost response | medium | mitigate | Put on the wire once (`attempts: 1`), documented (P-4); tested by `aTagSetRenameIsNotRetriedAfterATransportFailure` |
| T-261126-wzf-02 | Tampering | the typed name in the form body | low | mitigate | Trimmed, refused when blank or unchanged (P-6, P-8), and form-encoded through `URLQueryItem` by the shared builder (tested: `&` and `#` arrive as `%26` and `%23` in `aTagSetRenamePostsTheSetsFormWithTheNewNameInOrder`; `aBlankOrUnchangedNameSendsNothing`) |
| T-261126-wzf-03 | Spoofing | an answer page read as a rename that took | medium | mitigate | Success only when the page shows the renamed set by id, with no `#msg` and exactly the sent name; anything else alerts and restores (P-9; tested by the four answer tests in `MyTagsRenameTests`) |
| T-261126-wzf-04 | Tampering | concurrent tag set changes | medium | mitigate | One create, rename or delete at a time through `isChangingTagSets`, and the alert names its set (P-10; tested by `aRenameWhileATagSetChangeIsOnItsWayOrOfASetNotShownSendsNothing`) |
| T-261126-wzf-05 | Elevation of privilege | the edit API's `login` answer | medium | mitigate | Read as `loginRequired`, never followed as a redirect; the page shows its own Log In, which runs the app's login flow (P-13, P-14; tested by `aLoginAnswerFailsTheEditAsLoginRequired`, `aNullLoginIsNoLoginAnswer` and `MyTagsSessionTests`) |
| T-261126-wzf-06 | Denial of service | two reads after a sign-in | low | accept | The page's read is `cancelInFlight`, so a second read replaces the first (settled fact 7); at most one extra request, as when the page's own watch fires today |
| T-261126-wzf-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs and no dependency change (`AppPackage/Package.swift` untouched) |
</threat_model>

<verification>
After Task 4, once, from the repository root (TEST rules apply):
- Full plan: `mkdir -p .capture/261126-wzf && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -skip-testing:VisualSnapshotTests 2>&1 | tee .capture/261126-wzf/full-plan.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'` prints `** TEST SUCCEEDED **`; `grep -cE "Test case '.*' failed" .capture/261126-wzf/full-plan.log` prints `0`; `grep -E ': warning: ' .capture/261126-wzf/full-plan.log | sort -u` prints nothing.
- Lint over every source tree: `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` prints nothing.
- `python3 -I Scripts/lint/app_storage_isolation.py check` prints `0 break(s) of the app-storage isolation rule.`
- Invariant (no suppression, no serialization added): `git diff <BASE> -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'` prints `0` (BASE as recorded under Precondition).
- Invariant (the Tag Set picker untouched, owner 2026-11-27): `git diff <BASE> -- AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cE '^[-+].*(Picker|pickerStyle)'` prints `0`.
- Invariant (scroll-edge policy kept): `git diff <BASE> -- AppPackage | grep -cE '^-.*scrollEdgeEffectStyle'` prints `0`, and `grep -c 'scrollEdgeEffectStyle(.soft, for: .top)' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift` prints `2`.
- `git diff --stat <BASE> -- AppPackage/Package.swift EhPanda.xcodeproj App ShareExtension` prints nothing.
- `git log -4 --format='%G? %aI %cI %s'` shows the four subjects, each `G` with two `+08:00` instants; `git status --short` shows nothing but planning files under `.planning/quick/`; nothing is pushed.
</verification>

<success_criteria>
- W-1: the tint `Rename Tag Set…` row sits after `New Tag Set…` and before Delete Tag Set; its alert starts with the shown set's name, focused and not selected; Rename is disabled for an empty or unchanged trimmed name and the reducer refuses both; Cancel closes; the row is disabled while a create, rename or delete is on its way; the failure alert attaches to the row.
- W-2: `RenameMyTagSetRequest` posts `tagset_action=rename`, the name, the Enabled box and the colour, in order, to the shown set's page, once, with the reason documented.
- W-3: the new name shows at once and the tags stay; the answer page is taken; a reason, another name, another set or a failure ends with the old (or the site's) name and `my_tags.rename_failed` with the reason or the error.
- The Tag Set picker is the native menu `Picker` with the names alone, unchanged (owner, 2026-11-27; W-4 removed).
- W-5: a `login` answer fails as `loginRequired`; the page shows Log In instead of an error or an alert for any read or write so answered, beneath Edit Tag too; a sign-in from it reads every set again.
- W-6: the rename, session, editor, request and model tests pass in parallel.
- Copy: the five keys carry CONTEXT's values in all six locales.
- Four signed `+08:00` commits, 0 warnings, lint clean, full FeatureTests plan green (VisualSnapshotTests skipped).
</success_criteria>

<output>
Create `.planning/quick/261126-wzf-my-tags-tag-set-rename-counts-and-sessio/261126-wzf-SUMMARY.md` when done (not
committed). Record: BASE; the four commit hashes and subjects with their `%G? %aI %cI`; each test run (log name,
targets, TEST SUCCEEDED or the RED compile error, failed-case count, the new test names seen as passed); the gate
outputs; and, for the orchestrator:

- **Owner's device checks**, not done by the executor because the live site needs the owner's signed-in account. On
  iPhone and on iPad, in Account, My Tags:
  1. Tap Rename Tag Set…: the alert shows the set's name, focused, not selected, with the cursor at its end (P-7);
     Rename is disabled while the field is empty, spaces only or the same name. Rename: the picker shows the new name
     at once, and the site's own My Tags page shows it too.
  2. Rename with the device offline: the old name returns and "Couldn’t Rename Tag Set" shows with the error. Rename
     to a name the site rejects or changes (for example a very long one): note what the site answers and what the
     app shows (P-9).
  3. While a rename is on its way, New Tag Set, Rename Tag Set and Delete Tag Set are disabled.
  4. Text size Accessibility 3 and 5: the Rename row does not clip or overlap.
  5. If the site can be made to end the session while the app keeps its cookies (for example by signing out of the
     site in a browser with the same session): switch tag sets or toggle Enabled; the page shows Log In, with no
     alert; Log In, sign in, and the page reads every set again. In Edit Tag, Save: the sheet keeps its alert;
     close it: Log In is beneath (P-15).
  6. In the same state, a form write (Enabled, New Tag Set, Rename): note whether the page shows Log In or the error;
     the error means the site's signed-out answer to a form post is a page the existing detection does not know
     (P-17).
- The planner readings P-1 to P-19, one line each (P-2, P-3, P-11 and P-12 as withdrawn), noting P-7, P-9, P-15 and
  P-17 for the owner.
</output>
