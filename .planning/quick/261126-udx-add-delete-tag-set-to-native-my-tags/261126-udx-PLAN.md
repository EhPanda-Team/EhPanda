---
phase: 261126-udx-add-delete-tag-set-to-native-my-tags
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/AppModels/Tags/MyTags.swift
  - AppPackage/Sources/ParserFeature/Parser+MyTags.swift
  - AppPackage/Sources/TestingSupport/HTMLFilename.swift
  - AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet3.html
  - AppPackage/Tests/AppModelsTests/MyTagsTests.swift
  - AppPackage/Tests/ParserFeatureTests/Other/MyTagsParserTests.swift
  - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift
  - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
  - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift
  - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift
  - AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift
autonomous: true
requirements: [U-1, U-2, U-3, U-4, U-5, U-6, U-7, U-8, U-9]

estimate:
  tokens: 160000
  raw_tokens: 160000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "A set's page offers deleting it exactly when its tag set form (#tagset_outer) carries a control whose onclick calls do_tagset_delete and that has no disabled attribute (U-1a); every page the app reads brings that offer into the in-memory cache, and the offer is never stored, so the stored User.myTags keeps its shape and decodes as before, and a set read back from storage offers nothing (U-1)."
    - "The tag set section ends with New Tag Set and then, only while the shown set's page offers it, a destructive Delete Tag Set row; the row presents a confirmation with no title, the message, Delete and Cancel, anchored on the row, and Cancel sends nothing (U-2, U-3)."
    - "While the row's own failure alert is up, the row stays in the hierarchy even if the answer withdrew the offer, disabled when not offered, so the refusal is seen on the row; once the alert is dismissed the row follows the offer again (U-2a)."
    - "Delete posts tagset_action=delete, the empty tagset_name, tagset_enable=on only when the set is enabled, and tagset_color (#RRGGBB or empty), in that order, to the shown set's /mytags page, and puts it on the wire once (U-5)."
    - "When the answer has no #msg and its picker no longer lists the set, the page chooses the site's first listed set (kept with the cache) and shows it from the answer when that is the set it shows, else reads it with the loading view (U-6)."
    - "A #msg refusal, an answer that still lists the set, or a failed request shows Couldn't Delete Tag Set on the Delete Tag Set row with the site's reason, the unknown error's text or the error's text, and keeps the chosen set (U-6)."
    - "While a create or a delete is on its way, New Tag Set and Delete Tag Set are both disabled and neither a create nor a delete is sent (U-4)."
    - "The three copy keys are in SettingFeature's Localizable.xcstrings in all six locales with CONTEXT's values verbatim, the catalog still in Xcode's canonical form (Copy)."
  artifacts:
    - path: "AppPackage/Sources/AppModels/Tags/MyTags.swift"
      provides: "The per-set delete offer, kept in memory and left out of the stored shape"
      contains: "public private(set) var isDeletable = false"
    - path: "AppPackage/Sources/ParserFeature/Parser+MyTags.swift"
      provides: "The offer read from the page's tag set form"
      contains: "do_tagset_delete("
    - path: "AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet3.html"
      provides: "A synthetic empty set whose page carries the delete control"
      contains: "onclick=\"do_tagset_delete()\""
    - path: "AppPackage/Sources/NetworkingFeature/Request+MyTags.swift"
      provides: "The delete request, posted once"
      contains: "public struct DeleteMyTagSetRequest: Request"
    - path: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      provides: "deleteTagSet in live, noop, unimplemented and failing"
      contains: "public var deleteTagSet: @Sendable ("
    - path: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      provides: "The confirmation, the delete and the choice of the first set"
      contains: "case deleteTagSetDone(tagSetID: Int, result: Result<MyTagsPage, AppError>)"
    - path: "AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift"
      provides: "The Delete Tag Set row carrying the confirmation and its failure alert"
      contains: "Button(.myTagsDeleteTagSet, role: .destructive)"
  key_links:
    - from: "AppPackage/Sources/ParserFeature/Parser+MyTags.swift"
      to: "AppPackage/Sources/AppModels/Tags/MyTags.swift"
      via: "the parsed MyTagSet carries isDeletable; applying(_:) and MyTagsRequest carry the set whole into the cache"
      pattern: "isDeletable: offersDelete"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift"
      to: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      via: "the row shows on showsDeleteTagSetRow, is enabled on canDeleteTagSet, and presents the scoped confirmation"
      pattern: "\\.confirmationDialog\\(\\$store\\.scope\\(\\\\\\.\\$deleteTagSetDialog, action: \\\\\\.deleteTagSetDialog\\)\\)"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      to: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      via: "the confirmed delete sends the shown set through deleteTagSet"
      pattern: "myTagsClient\\.deleteTagSet\\(host, tagSet\\)"
    - from: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      to: "AppPackage/Sources/NetworkingFeature/Request+MyTags.swift"
      via: "live deleteTagSet builds DeleteMyTagSetRequest, which posts with attempts 1"
      pattern: "DeleteMyTagSetRequest\\(host: host, tagSet: tagSet\\)"
---

## Blocking questions

None. Every locked decision (U-1 to U-9), the two decisions below and the copy table are planned as written.

## Orchestrator decisions on the planner's notes (2026-11-26; locked, recorded here, not in CONTEXT)

- **U-1a A disabled control is not an offer.** The parser's XPath excludes a control with a `disabled` attribute
  (`[not(@disabled)]`), and the parser tests gain a case with a disabled Delete control (an inline variant of
  `MyTagsTagSet3`) that reads as not offered. Planned in S2, S4d and Task 1.
- **U-2a The row stays while its own failure alert is up.** The Delete Tag Set row stays in the hierarchy while
  `alertSource == .deleteTagSet` and the alert is presented, even if the answer page no longer offers deleting, so a
  refusal is always seen on the row it belongs to (AGENTS.md dialog placement: an anchor must not leave for a reason
  the dialog knows nothing about). Once the alert is dismissed the row follows the offer again. While shown that way
  the row is disabled if not offered. A reducer test covers a refusal whose answer drops the offer: the alert shows
  and the row's visibility predicate stays true until dismissal. Planned in S5c, S6b, S11c and Task 3.

<objective>
Add Delete Tag Set to the native My Tags page exactly as CONTEXT's locked decisions U-1 to U-9 and its copy table say,
in three signed commits on top of `develop` (nothing pushed):

1. The model keeps, per set and in memory only, whether the set's page offers deleting it; the parser reads it from
   the page; a synthetic fixture carries the control (U-1).
2. `DeleteMyTagSetRequest` and `MyTagsClient.deleteTagSet` post the site's delete form once, never retried (U-5).
3. The page's tag set section gets the Delete Tag Set row while the shown set is offered, its confirmation, the delete,
   the choice of the site's first set, the failure alert on the row, one flag holding both rows while a create or a
   delete is on its way, the three copy keys and the reducer tests (U-2, U-3, U-4, U-6, U-7, U-8).

Purpose: the owner can delete a tag set from the app, as the site's Delete button does, for exactly the sets the site
offers it for, and land on the site's first set.
Output: three signed `+08:00` commits; `261126-udx-SUMMARY.md` (not committed) listing the owner's device check (U-9).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/261126-udx-add-delete-tag-set-to-native-my-tags/261126-udx-CONTEXT.md
@.planning/quick/261126-pfh-add-a-new-tag-set-action-to-the-native-m/261126-pfh-SUMMARY.md
@.planning/STATE.md
@CLAUDE.md
@.swiftlint.yml

### Execution fidelity (applies to every step)

Follow this plan exactly. If anything cannot be done exactly as written (ambiguity, conflicting requirements, missing
information, unexpected repository state, a compiler error or lint rule that forces a different shape, a test that
fails, a gate that prints anything but its EXPECT value, a copy value that differs from CONTEXT, a needed user-facing
string, or any other deviation), stop immediately and ask the orchestrator. Do not choose, invent or implement a
solution on your own. The only latitude: re-wrapping comment prose this plan gives when a line would pass 120 columns
(the wording is fixed).

### Precondition (check before Task 1; halt if it does not hold)

- `git status --short` prints nothing but `?? .planning/quick/261126-udx-add-delete-tag-set-to-native-my-tags/` (or
  nothing at all once the orchestrator has committed this directory). In particular the orchestrator's `MyTagsView`
  change (the `emptyTags` property) is committed, and no `ScratchMyTagsRenderTests.swift` exists under
  `AppPackage/Tests/`.
- `grep -c 'private var emptyTags: some View' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift` prints `1`.
- Record `git rev-parse --short HEAD` as BASE in the SUMMARY; the final invariant gate diffs against it.

### Where and how you work

- This checkout, branch `develop` (HEAD `6fb749ed6` when this plan was written, plus the orchestrator's `MyTagsView`
  and plan commits). New commits go on top; no new branch, no rebase, no amend, no push, nothing on GitHub, no bare
  `git stash`. Never commit this PLAN, the SUMMARY, STATE.md or anything under
  `.planning/quick/261126-udx-add-delete-tag-set-to-native-my-tags/` (the orchestrator commits planning artifacts).
- Read `AGENTS.local.md` before the first commit and follow it; never copy its content into any artifact.
- Read the root `.swiftlint.yml` before writing Swift. No `swiftlint:disable` of any kind, no rule changes, no
  `.serialized`.
- Do not touch `MyTagsView`'s `emptyTags` property or the empty-state section that uses it.
- Logs and scratch files go under `.capture/261126-udx/` (gitignored). The SUMMARY carries no absolute home paths
  (write `$HOME/...`) and names no other local project.
- Code comments use decision IDs (U-1 to U-9) and the quick task id, never agent names.
- Every Swift, HTML and Python block this plan gives under "Shapes" is copied exactly as written, at the indentation
  written.
- The executor writes no copy: the three strings come from CONTEXT's table through the script in S7, unchanged.

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
  `mkdir -p .capture/261126-udx && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never <-only-testing:Target ...> 2>&1 | tee .capture/261126-udx/<log>.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'`
  It passes when it prints `** TEST SUCCEEDED **` and `grep -cE "Test case '.*' failed" .capture/261126-udx/<log>.log`
  prints `0`. Xcode 27.2 prints no `Test run with N tests` line; the per-case `Test case '...' passed` lines are the
  evidence (a parameterized test prints one line per argument).
- Warnings: `grep -E ': warning: ' .capture/261126-udx/<log>.log | sort -u` must print nothing. A warning in a file
  this plan does not touch: stop and report it (do not fix it).
- Lint, from the repository root, on the task's trees:
  `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet <trees>`
  must print nothing and exit 0.
- Known flake: if the only failure of the final full run is
  `FavoritesFeatureTests/LoginReturnObservationTests/cookieLoginTriggersReloadWithoutAViewCallback`, re-run
  `-only-testing:FavoritesFeatureTests` once; it must pass; record both runs in the SUMMARY.

### Settled facts (checked by the planner against the tree at `6fb749ed6`; do not re-derive)

1. **Retries.** `Request.fetch(_:in:attempts:)` re-sends a request on any thrown transport error up to `attempts`
   times (default 4). `postMyTagsForm` already forwards `attempts` (quick 261126-pfh), and the create passes 1. A
   delete the site took whose answer was lost would be posted again to a set that is gone, so U-5's condition holds:
   the delete is posted with `attempts: 1`.
2. **Storage.** `User`, `MyTags` and `MyTagSet` use synthesized `Codable`; `User` is stored whole as JSON under the
   app storage key `user` (`AppModels/Persistence/AppSharedKeys.swift`). Sharing's `AppStorageKey` ignores its own
   writes (`SharedAppStorageLocals.isSetting` in swift-sharing's `AppStorageKey.swift`), so a value written through
   `withLock` is not decoded back into memory: a `MyTagSet` property left out of `CodingKeys` lives as long as the
   cache in memory and is in no stored copy. The stored keys of a set stay `id`, `name`, `isEnabled`, `color` (absent
   when nil) and `tags`.
3. **Every page reaches the cache whole.** Each page the app reads goes through `MyTags.applying(_:)`, which puts
   `page.tagSet` in place of the stored set: this page's `take`, Add Tag's add and Edit Tag's remove in
   `MyTagEditorFeature`, and the gallery's Add to My Tags. `MyTagsRequest` builds `MyTags` from each set's parsed
   `tagSet`. So a field the parser sets on `MyTagSet` reaches the cache from every read with no change to those
   callers, and `MyTagsResponse` needs no new field.
4. **No other constructor.** `MyTagSet(...)` is built in production only by the parser; tests and previews build it by
   hand. `MyTagsClient` is built only in `MyTagsClient.swift` (`live`, `noop`, `unimplemented`, `failing(_:)`).
5. **Ephemeral dialogs.** `ConfirmationDialogState` is ephemeral like `AppAlertState`: `.ifLet(\.$deleteTagSetDialog,
   action: \.deleteTagSetDialog)` with no child reducer sets the state to nil when a button's action arrives, and the
   scoped binding sends `.dismiss` when Cancel (or a tap outside the iPad popover) closes it. `EhSettingReducer`'s
   Delete Profile and `EhProfileSection`'s `.confirmationDialog(_:)` on its row are the pattern.
6. **Copy symbols.** Keys of `SettingFeature/Resources/Localizable.xcstrings` generate internal
   `LocalizedStringResource` members named after the key, so the three keys become `.myTagsDeleteTagSet`,
   `.myTagsDeleteTagSetMessage` and `.myTagsDeleteTagSetFailed`, visible to `SettingFeatureTests` through
   `@testable import SettingFeature`. No catalog in the repository has these keys or symbols. The catalog is in Xcode's
   canonical form; the S7 script was dry-run on a copy: it inserts 123 lines (3 keys x 41) and deletes none, and its
   `check` prints `ok`.
7. **Pointer hover audit.** A default-style `Button` in a `Form`, as the New Tag Set row, keeps the system's pointer
   response; `AppToolsTests/PointerHoverAuditTests` flags plain or unhighlighted buttons, tap gestures and custom
   button styles only, so the row needs no hover helper.
8. **TestStore and the shared cache.** When the cache changes in two received actions of one test, the first step's
   closure already sees the later change, so such a test turns exhaustivity off and checks the cache at the end
   (quick 261126-pfh, SUMMARY deviation 2). A test whose cache changes in one received action asserts it in that step,
   as `swipingRemovesTheTagAtOnceAndTakesThePage` does. Several stores in one test share one cache, so a test of
   `canDeleteTagSet` drives one store.
9. **Rename sites.** `isCreatingTagSet` appears on 5 code lines of `MyTagsFeature.swift`, 1 of `MyTagsView.swift` and
   9 of `MyTagsFeatureTests.swift`, nowhere else.
10. **Parser XPath.** The picker is already read from `//div[@id='tagset_outer']//select`; the tags form's
    `Delete Selected` (`do_usertags_post('mass')`) lies outside `#tagset_outer`, so it cannot be read as the offer.

### Planner's choices where CONTEXT leaves them open (each is final for the executor)

- **P-1 (U-1) Where the offer lives: `MyTagSet.isDeletable`, in memory, left out of `CodingKeys`.** The offer is a fact
  about one set that only its page states, so it travels with the set: every page read anywhere replaces the set in
  the cache (settled fact 3), which keeps the row truthful after Add Tag or Edit Tag's remove changed the set in the
  sheet; the stored shape is unchanged, so `User.myTags` decodes as before; and a set read back from storage offers
  nothing, so a set with no page read since launch shows no row. Rejected: a set of offered ids in `MyTagsFeature`'s
  state (it never sees the pages the editor sheet reads, so the row would go stale there), and a stored field (a
  stored offer would outlive its page and show the row at the next launch before any read).
- **P-2 (U-1, U-1a) The control.** Any element under `div#tagset_outer` whose `onclick` contains
  `do_tagset_delete(` and that has no `disabled` attribute.
- **P-3 (U-1, U-8) Fixture.** `MyTagsTagSet3.html`: set 3, "Fixture Holds", empty, Enabled unchecked, no colour, the
  picker listing sets 1, 2 and 3, and a Delete button drawn after New and Rename in their markup. It is synthetic: no
  page with the control has been read, and the fixture says so where it is registered.
- **P-4 (U-3) The confirmation names its set.** `DeleteTagSetDialog.delete(tagSetID:)` carries the id of the set it
  was opened for; Delete deletes only if that set is still the one shown and its page still offers it.
- **P-5 (U-4) One flag.** `isCreatingTagSet` becomes `isChangingTagSets`, set by a create and by a delete and read by
  both rows and both requests: nothing ever needs to know which of the two is on its way, and one flag cannot let
  both be on their way at once.
- **P-6 (U-5) One form builder.** The update, the create and the delete post the same four fields; a fileprivate
  `tagSetFormFields(action:name:isEnabled:color:)` builds them for all three. The existing request tests pin the
  update and create bodies byte for byte.
- **P-7 (U-6) The site's first set.** `page.tagSetIDs.first ?? page.tagSet.id`: the picker always lists the page's own
  set, so the fallback names the same set the answer shows.
- **P-8 (U-6) Error for "still listed, no #msg".** `AppError.unknown`, as the create uses when no new id appears.
- **P-9 (Copy) Inserted by script.** S7 reads the three rows from CONTEXT's table and writes them; nobody retypes copy.
- **P-10 Task shape.** Three layered tasks with one green commit each instead of a tracer: the path (form post,
  `MyTagsClient`, reducer, row) is the one `CreateMyTagSetRequest` already proves.

### Source coverage

| Source item | Where |
|---|---|
| U-1 offer, per set, not breaking the stored cache, no row without a fresh page | Task 1 (S1, S2, S3, S4), Task 3 (`canDeleteTagSet`) |
| U-1a a disabled control is not an offer; parser test with a disabled Delete | Task 1 (S2b, S4d) |
| U-2 row after New Tag Set, destructive, dialog and failure alert on the row, new `AlertSource` | Task 3 (S5b, S6b) |
| U-2a row kept, disabled if not offered, while its own failure alert is up; reducer test | Task 3 (S5c, S6b, S11c) |
| U-3 confirmation state and buttons | Task 3 (S5e) |
| U-4 both rows disabled while a create or a delete is on its way | Task 3 (P-5, S5c, S6b) |
| U-5 request, fields in order, `attempts: 1` with its WHY, client in live/noop/unimplemented/failing | Task 2 (S8, S9) |
| U-6 answer taken, success choice and read, failures keep the selection | Task 3 (S5e) |
| U-7 no rename; iPad by the same page | Task 3 (no rename anywhere) |
| U-8 reducer, request and parser tests | Task 1 (S3, S4), Task 2 (S10), Task 3 (S11) |
| U-9 live check in the SUMMARY | Output |
| Copy table, three keys, six locales | Task 3 (S7) |
| Design: row after New Tag Set; dialog without title; first set shown after a delete | Task 3 |

### Shapes (copy exactly)

#### S1: `AppPackage/Sources/AppModels/Tags/MyTags.swift` (Task 1)

Replace the whole `MyTagSet` declaration (its doc line `/// One tag set of My Tags: its name, ...` through the
struct's closing `}`) with:

```swift
/// One tag set of My Tags: its name, whether it is enabled, its default colour, its tags in the page's order, and
/// whether the site offers to delete it.
public struct MyTagSet: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    /// Only the tags of an enabled set take effect, on the site and in the app's highlight.
    public var isEnabled: Bool
    /// The colour of the set's tags that have none of their own.
    public var color: SiteColor?
    public var tags: [MyTag]
    /// Whether the set's page, as last read, offers deleting the set (U-1 of quick 261126-udx). Which sets the site
    /// offers it for is its own rule, unknown here, so only the page says it; every page read brings its word into
    /// the cache with the rest of the set.
    ///
    /// Never stored: `CodingKeys` leaves it out, so a stored set keeps the shape it always had and decodes as before,
    /// and a set read back from storage offers nothing until a page of it is read again. A stored offer could outlive
    /// the page that made it.
    public private(set) var isDeletable = false

    /// The stored fields; `isDeletable` is left out on purpose (see its note).
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isEnabled
        case color
        case tags
    }

    public init(
        id: Int,
        name: String,
        isEnabled: Bool,
        color: SiteColor?,
        tags: [MyTag],
        isDeletable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.color = color
        self.tags = tags
        self.isDeletable = isDeletable
    }
}
```

Nothing else in the file changes.

#### S2: `AppPackage/Sources/ParserFeature/Parser+MyTags.swift` (Task 1)

S2a. In `parseMyTags`'s doc comment, directly after the line `    /// the edit API's credentials.`, insert:

```swift
    /// A control in the tag set form whose `onclick` calls `do_tagset_delete` offers deleting the shown set (U-1 of
    /// quick 261126-udx), unless it is disabled (U-1a). Which sets the site offers it for is its own rule, unknown
    /// here, so only the page says it.
```

S2b. Directly after the line that starts `        let message = doc.at_xpath("//div[@id='msg']")`, insert:

```swift
        let deleteControl = "//div[@id='tagset_outer']//*[contains(@onclick, 'do_tagset_delete(')][not(@disabled)]"
        let offersDelete = doc.at_xpath(deleteControl) != nil
```

S2c. In the `MyTagSet(` of the returned page, the line `                tags: tags` becomes `                tags: tags,`
and is followed by `                isDeletable: offersDelete`.

#### S3: the fixture (Task 1)

S3a. Create `AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet3.html` with exactly this content
(ending in one newline after `</html>`):

```html
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>E-Hentai Galleries: My Tags</title>
</head>
<body>
<div class="stuffbox" id="outer">
<script type="text/javascript">
var api_url = "https://api.e-hentai.org/api.php";
var apiuid = 1234567;
var apikey = "0123456789abcdef";
var tagset_color = "";
var tagset_name = "Fixture Holds";
var baseurl = "https://e-hentai.org/mytags";
var default_color = "000000";
</script>
<h1>My Tags</h1>
<form id="tagset_form" action="" method="post">
<div id="tagset_outer">
<div><input type="button" onclick="do_tagset_create()" value="New" /> <input type="button" onclick="do_tagset_rename()" value="Rename" /> <input type="button" onclick="do_tagset_delete()" value="Delete" /></div>
<div>
<input type="hidden" id="tagset_action" name="tagset_action" value="" />
<input type="hidden" id="tagset_name" name="tagset_name" value="" />
<select onchange="change_tagset(this.value)">
<option value="1">Tagset #1 (4)</option>
<option value="2">Fixture Picks (1)</option>
<option value="3" selected="selected">Fixture Holds (0)</option>
</select>
</div>
<div><label class="lc" title="Flag the tags of this tagset in galleries"><input type="checkbox" name="tagset_enable" id="tagset_enable" onchange="allow_tagsave(-1)" /><span></span> Enable</label></div>
<div><button id="colorsetter" class="jscolor {onFineChange:'update_tagcolor(-1,this,false)',valueElement:null,value:'000000'}" tabindex="-1"></button></div>
<div><input type="text" name="tagset_color" id="tagcolor" value="" placeholder="#default" size="7" maxlength="7" autocomplete="off" oninput="update_tagcolor(-1,this,true)" title="Tagset color" /></div>
<div><input type="button" id="tagsave" onclick="do_tagset_update()" value="Save" disabled="disabled" /></div>
</div>
</form>
<form id="usertag_form" action="" method="post">
<input type="hidden" id="usertag_action" name="usertag_action" value="" />
<div id="usertags_outer">
<div id="usertag_0">
<div><div class="tagcomplete"><input type="text" id="tagname_new" name="tagname_new" value="" placeholder="Enter a single tag to flag, watch or hide" size="40" maxlength="200" oninput="allow_tagsave(0)" autocomplete="off" /></div></div>
<div><label class="lc" title="Watched"><input type="checkbox" id="tagwatch_0" name="tagwatch_new" onchange="document.getElementById('taghide_0').checked=false;allow_tagsave(0)" /><span></span> Watched</label></div>
<div><label class="lc" title="Hidden"><input type="checkbox" id="taghide_0" name="taghide_new" onchange="document.getElementById('tagwatch_0').checked=false;allow_tagsave(0)" /><span></span> Hidden</label></div>
<div><button id="colorsetter_0" class="jscolor {onFineChange:'update_tagcolor(0,this,false)',valueElement:null,value:'3377FF'}" tabindex="-1"></button></div>
<div><input type="text" id="tagcolor_0" name="tagcolor_new" class="tagcolor" value="" placeholder="#default" size="7" maxlength="7" autocomplete="off" oninput="update_tagcolor(0,this,true)" title="Tag color" /></div>
<div><input type="text" id="tagweight_0" name="tagweight_new" value="10" placeholder="10" size="3" maxlength="3" oninput="allow_tagsave(0)" title="Tag weight" /></div>
<div><input type="submit" id="tagsave_0" value="Add" disabled="disabled" onclick="do_usertags_post('add'); return false" /></div>
</div>
</div>
<div id="usertags_mass">
<div><select id="usertag_target" name="usertag_target"><option value="0">Delete Selected</option><option value="1">Move to Tagset #1</option><option value="2">Move to Fixture Picks</option></select></div>
<div><input type="button" value="Apply to Selected" onclick="do_usertags_post('mass')" /></div>
</div>
</form>
</div>
</body>
</html>
```

S3b. In `AppPackage/Sources/TestingSupport/HTMLFilename.swift`, directly after the line
`    case myTagsTagSet2 = "MyTagsTagSet2"`, insert:

```swift
    // An empty set whose page offers deleting it (quick 261126-udx). No page with that control has been read, so its
    // Delete button is drawn after New and Rename in their markup, calling the site's `do_tagset_delete()`.
    case myTagsTagSet3 = "MyTagsTagSet3"
```

#### S4: tests of Task 1

S4a. `AppPackage/Tests/AppModelsTests/MyTagsTests.swift`: the file's header comment (its first two `//` lines,
starting `// The My Tags model`) becomes:

```swift
// The My Tags model (port of PR 462 item 10): site colours, the kind, the highlight (design approved 2026-11-22), the
// cache's selection and updates, a set's delete offer, which is never stored (quick 261126-udx), and the optional
// field on the stored user. The tags and sets are invented.
```

S4b. In the same file, directly after the test `aPageOfASetTheCacheLacksTakesItsPlaceInThePickersOrder` (after its
closing `    }`), insert a blank line and:

```swift
    // Every page read brings its set's delete offer into the cache, the pages Add Tag and Edit Tag's remove answer with
    // included, and the sets the page does not show keep theirs (U-1 of quick 261126-udx).
    @Test
    func aPagesDeleteOfferReplacesItsSetsAndTheOtherSetsKeepTheirs() {
        let set1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        let offered1 = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [], isDeletable: true)
        let offered2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [], isDeletable: true)
        let filled2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [Self.artist])
        let cache = MyTags(tagSets: [set1, offered2], selectedTagSetID: 2)

        let withdrawn = cache.applying(Self.page(filled2, tagSetIDs: [1, 2]))
        let offeredBoth = cache.applying(Self.page(offered1, tagSetIDs: [1, 2]))

        #expect(withdrawn == MyTags(tagSets: [set1, filled2], selectedTagSetID: 2))
        #expect(offeredBoth == MyTags(tagSets: [offered1, offered2], selectedTagSetID: 2))
    }

    // A set's delete offer is never stored (U-1 of quick 261126-udx): the stored set keeps the five fields it always
    // had, so a cache stored before decodes as it did, and a set read back offers nothing until its page is read.
    @Test
    func aSetsDeleteOfferIsNeverStoredAndAStoredSetDecodesWithoutIt() throws {
        let read = MyTagSet(
            id: 2, name: "Fixture Picks", isEnabled: false, color: Self.green, tags: [Self.artist], isDeletable: true
        )
        let encoded = try JSONEncoder().encode(read)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object.keys.sorted() == ["color", "id", "isEnabled", "name", "tags"])

        let decoded = try JSONDecoder().decode(MyTagSet.self, from: encoded)
        #expect(!decoded.isDeletable)
        #expect(
            decoded == MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: Self.green, tags: [Self.artist])
        )

        let stored = Data(#"{"id":1,"name":"Tagset #1","isEnabled":true,"tags":[]}"#.utf8)
        #expect(
            try JSONDecoder().decode(MyTagSet.self, from: stored)
                == MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        )
    }
```

S4c. `AppPackage/Tests/ParserFeatureTests/Other/MyTagsParserTests.swift`: directly after the doc line
`/// inline pages are `MyTagsTagSet1` with one detail changed.`, insert:

```swift
/// `MyTagsTagSet3` is an empty set whose page offers deleting it (quick 261126-udx).
```

S4d. In the same file, directly after the test `aColouredDisabledSetReadsItsColourAndState` (after its closing
`    }`), insert a blank line and:

```swift
    // A control in the tag set form whose `onclick` calls `do_tagset_delete` offers deleting the shown set (U-1 of
    // quick 261126-udx).
    @Test
    func aPageWithTheDeleteControlOffersDeletingItsSet() throws {
        let page = try Parser.parseMyTags(doc: htmlDocument(filename: .myTagsTagSet3))

        #expect(page == MyTagsPage(
            tagSet: MyTagSet(id: 3, name: "Fixture Holds", isEnabled: false, color: nil, tags: [], isDeletable: true),
            tagSetIDs: [1, 2, 3],
            apiuid: 1234567,
            apikey: "0123456789abcdef",
            message: nil
        ))
    }

    // Neither page of 2026-11-22 carries the control, and the tags form's Delete Selected is not it.
    @Test(arguments: [HTMLFilename.myTagsTagSet1, .myTagsTagSet2])
    func aPageWithoutTheDeleteControlOffersNoDelete(filename: HTMLFilename) throws {
        let page = try Parser.parseMyTags(doc: htmlDocument(filename: filename))

        #expect(!page.tagSet.isDeletable)
    }

    // A disabled Delete control offers nothing (U-1a of quick 261126-udx).
    @Test
    func aPageWhoseDeleteControlIsDisabledOffersNoDelete() throws {
        let html = try htmlString(filename: .myTagsTagSet3)
        let target = #"onclick="do_tagset_delete()" value="Delete" />"#
        try #require(html.contains(target))
        let disabled = #"onclick="do_tagset_delete()" value="Delete" disabled="disabled" />"#
        let document = try Kanna.HTML(html: html.replacing(target, with: disabled), encoding: .utf8)
        let page = try Parser.parseMyTags(doc: document)

        #expect(!page.tagSet.isDeletable)
    }
```

#### S5: `AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift` (Task 3; after the rename of step 1)

S5a. The type's doc comment: after its last line (`/// 261126-pfh).`), append:

```swift
///
/// Delete Tag Set shows while the shown set's page offers deleting it, and stays, disabled, while its own failure
/// alert is up. It asks in a confirmation, then has the site delete the set; the page then chooses the site's first
/// set and shows it, and a refusal or a failure shows the alert on the row (quick 261126-udx).
```

S5b. `AlertSource` gains a last case after `case newTagSet`, and a new enum follows `NewTagSetAlert`:

```swift
        /// The Delete Tag Set row, whose delete was refused or failed.
        case deleteTagSet
```

```swift
    /// The Delete Tag Set confirmation's action besides Cancel; it names the set it was opened for (U-3).
    public enum DeleteTagSetDialog: Equatable, Sendable {
        case delete(tagSetID: Int)
    }
```

(The enum goes directly after `NewTagSetAlert`'s closing `    }`, preceded by a blank line.)

S5c. In `State`:
- directly after `@Presents public var newTagSetAlert: AppAlertState<NewTagSetAlert>?`, insert:

```swift
        /// The confirmation that deletes the shown tag set (U-3 of quick 261126-udx).
        @Presents public var deleteTagSetDialog: ConfirmationDialogState<DeleteTagSetDialog>?
```

- replace the two doc lines above `public var isChangingTagSets = false` (they start
  `/// A create is on its way: the New Tag Set row is disabled`) with:

```swift
        /// A create or a delete of a tag set is on its way (U-4 of quick 261126-udx): New Tag Set and Delete Tag Set
        /// are disabled, and another create or delete is refused, until the site answers. One flag serves both: a
        /// delete answered while a create is on its way would confuse the create's search for its new id, and a
        /// create answered while a delete is on its way would confuse the delete's check that its set is gone.
```

- directly after `public var tagSetWellColor: Color { selectedTagSet?.color?.color ?? .clear }`, insert:

```swift
        /// Whether the shown set's page offers deleting it (U-1 of quick 261126-udx), which Delete Tag Set needs to be
        /// shown and enabled; a set read back from storage, with no page of it read since, offers nothing.
        public var canDeleteTagSet: Bool { selectedTagSet?.isDeletable ?? false }
        /// Delete Tag Set shows while the shown set is offered, and also while its own failure alert is up (U-2a of
        /// quick 261126-udx): the alert is anchored on the row, so an answer that withdraws the offer must not take
        /// the row, and the refusal with it, away before the alert is dismissed. Shown that way it is disabled.
        public var showsDeleteTagSetRow: Bool {
            canDeleteTagSet || (alertSource == .deleteTagSet && alert != nil)
        }
```

S5d. In `Action`, directly after `case newTagSetAlert(PresentationAction<NewTagSetAlert>)`, insert
`        case deleteTagSetDialog(PresentationAction<DeleteTagSetDialog>)`, and directly after
`case createTagSetDone(knownTagSetIDs: [Int], result: Result<MyTagsPage, AppError>)`, insert:

```swift
        case deleteTagSetTapped
        case deleteTagSetDone(tagSetID: Int, result: Result<MyTagsPage, AppError>)
```

S5e. In `body`:
- the first case becomes `            case .alert, .toast, .delegate, .newTagSetAlert(.dismiss), .deleteTagSetDialog(.dismiss):`
- the three comment lines above `case .newTagSetAlert(.presented(.create)):` (they start
  `// A blank name is refused here too`) become:

```swift
            // A blank name is refused here too, though Create waits for one (N-3), and so is a create while a create
            // or a delete is on its way (U-4 of quick 261126-udx): a create is not safe to send twice
            // (`CreateMyTagSetRequest`). The sets the cache has now are the ones the site's answer is read against
            // (N-5).
```

- directly after the `case .createTagSetDone(_, .failure(let error)):` case (after its closing `)` line), insert a
  blank line and:

```swift
            // The confirmation names the set it was opened for, the one the page shows (U-3).
            case .deleteTagSetTapped:
                guard let tagSet = state.selectedTagSet else { return .none }
                state.deleteTagSetDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .RLocalizable.delete)
                } actions: {
                    ButtonState(role: .destructive, action: .delete(tagSetID: tagSet.id)) {
                        TextState(localized: .RLocalizable.delete)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .myTagsDeleteTagSetMessage)
                }
                return .none

            // Only the set the confirmation names is deleted, while it is still the one shown and its page still
            // offers it, and not while a create or a delete is on its way (U-4). The form is the shown set's own.
            case .deleteTagSetDialog(.presented(.delete(let tagSetID))):
                guard !state.isChangingTagSets, let tagSet = state.selectedTagSet,
                      tagSet.id == tagSetID, tagSet.isDeletable
                else { return .none }
                state.isChangingTagSets = true
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.deleteTagSet(host, tagSet)
                    }
                    await send(.deleteTagSetDone(tagSetID: tagSetID, result: result))
                }

            // The answer is taken into the cache, so a set the site dropped leaves the picker (U-6). The delete took
            // when the page gives no reason and its picker no longer lists the set: the page then chooses the site's
            // first set, kept with the cache as a choice in the picker is, and shows it, from the answer when that is
            // the set it shows, else through a read with the loading view. A reason, or the set still listed, fails
            // the delete and keeps the choice.
            case .deleteTagSetDone(let tagSetID, .success(let page)):
                state.isChangingTagSets = false
                take(page, into: &state)
                if let message = page.message {
                    return presentAlert(&state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: message)
                }
                guard !page.tagSetIDs.contains(tagSetID) else {
                    // Neither gone nor a reason: as with a create whose answer lists no new set, all the app knows
                    // is that the site did not do it.
                    return presentAlert(
                        &state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: AppError.unknown.alertText
                    )
                }
                // The picker always lists the page's own set, so the fallback names the set the answer shows.
                let firstTagSetID = page.tagSetIDs.first ?? page.tagSet.id
                state.$user.withLock({ $0.myTags = $0.myTags?.selecting(firstTagSetID) })
                guard firstTagSetID != page.tagSet.id else { return .none }
                state.loadingState = .loading
                return fetchTagSet(firstTagSetID, host: state.setting.galleryHost)

            case .deleteTagSetDone(_, .failure(let error)):
                state.isChangingTagSets = false
                return presentAlert(
                    &state, .deleteTagSet, title: .myTagsDeleteTagSetFailed, message: error.alertText
                )
```

S5f. After `        .ifLet(\.$newTagSetAlert, action: \.newTagSetAlert)`, add
`        .ifLet(\.$deleteTagSetDialog, action: \.deleteTagSetDialog)`.

#### S6: `AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift` (Task 3; after the rename of step 1)

S6a. The type's doc comment (the four lines starting `/// The My Tags page (port of PR 462 item 10`) becomes:

```swift
/// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): the tag set (its picker, Enabled and default
/// colour, New Tag Set, and Delete Tag Set while the site offers it) and its tags, one row each; a row opens Edit Tag
/// and a trailing swipe removes the tag. Add Tag sits in the toolbar. Signed out it shows Log In; loading, the loading
/// view; failed, the error with Open in Browser.
```

S6b. In `form(_:)`'s first `Section`, directly after `.appAlert(alert(for: .newTagSet))` (the New Tag Set row's last
modifier) and before `} footer: {`, insert:

```swift
                // Shown while the set's page offers deleting it, and kept, disabled, while its own failure alert is up
                // (U-2a), so a refusal whose answer withdraws the offer is still seen on this row.
                if store.showsDeleteTagSetRow {
                    Button(.myTagsDeleteTagSet, role: .destructive) {
                        store.send(.deleteTagSetTapped)
                    }
                    .disabled(store.isChangingTagSets || !store.canDeleteTagSet)
                    // On the row that opens them, the confirmation and its failure alert (AGENTS.md dialog
                    // placement): on iPad the confirmation is a popover whose arrow points at this row.
                    .confirmationDialog($store.scope(\.$deleteTagSetDialog, action: \.deleteTagSetDialog))
                    .appAlert(alert(for: .deleteTagSet))
                }
```

Nothing else in the file changes (the `emptyTags` property, the footer, the toolbar and the scroll-edge modifier stay
as they are).

#### S7: `.capture/261126-udx/insert_copy.py` (Task 3; scratch, never committed)

Run from the repository root: `python3 -I .capture/261126-udx/insert_copy.py insert` (inserts, then checks) and
`python3 -I .capture/261126-udx/insert_copy.py check` (prints `ok` when every key holds CONTEXT's values). The script
has no `\u` escapes; the characters it checks are named with `chr(...)`.

```python
import json
import sys
from pathlib import Path

CONTEXT = Path(".planning/quick/261126-udx-add-delete-tag-set-to-native-my-tags/261126-udx-CONTEXT.md")
CATALOG = Path("AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings")
KEYS = [
    "my_tags.delete_tag_set",
    "my_tags.delete_tag_set.message",
    "my_tags.delete_tag_set_failed",
]
LOCALES = ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"]


def canonical(catalog):
    return json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : "))


def copy_table():
    rows = {}
    for line in CONTEXT.read_text(encoding="utf-8").splitlines():
        if line.startswith("| `my_tags."):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            assert len(cells) == 1 + len(LOCALES), line
            rows[cells[0].strip("`")] = dict(zip(LOCALES, cells[1:]))
    assert list(rows) == KEYS, list(rows)
    for key, values in rows.items():
        for locale, value in values.items():
            assert value and "%" not in value, (key, locale)
    return rows


def entry(values):
    localizations = {}
    for locale in sorted(values):
        localizations[locale] = {"stringUnit": {"state": "translated", "value": values[locale]}}
    return {"extractionState": "manual", "localizations": localizations}


def load():
    text = CATALOG.read_text(encoding="utf-8")
    catalog = json.loads(text)
    assert canonical(catalog) == text, "not in Xcode's canonical form"
    assert list(catalog["strings"]) == sorted(catalog["strings"]), "keys not sorted"
    return catalog


def insert():
    catalog = load()
    rows = copy_table()
    strings = dict(catalog["strings"])
    assert not set(KEYS) & set(strings), "a key is already there"
    for key in KEYS:
        strings[key] = entry(rows[key])
    catalog["strings"] = {key: strings[key] for key in sorted(strings)}
    CATALOG.write_text(canonical(catalog), encoding="utf-8")
    check()


def check():
    strings = load()["strings"]
    rows = copy_table()
    for key in KEYS:
        assert strings[key] == entry(rows[key]), key

    def value(key, locale):
        return strings[key]["localizations"][locale]["stringUnit"]["value"]

    message = "my_tags.delete_tag_set.message"
    for locale in ["en", "de", "ko"]:
        assert value(message, locale).endswith(chr(0x3F)), locale
    for locale in ["ja", "zh-Hans", "zh-Hant"]:
        assert value(message, locale).endswith(chr(0xFF1F)), locale
    assert chr(0x2019) in value("my_tags.delete_tag_set_failed", "en")
    print("ok")


if __name__ == "__main__":
    {"insert": insert, "check": check}[sys.argv[1]]()
```

#### S8: `AppPackage/Sources/NetworkingFeature/Request+MyTags.swift` (Task 2)

S8a. Replace the file's header comment (the five `//` lines starting `// The My Tags reads and writes`) with:

```swift
// The My Tags reads and writes (port of PR 462 item 10; the site contract read live on 2026-11-22). Every request but
// the create and the delete keeps `fetch`'s default four attempts: the reads are GETs, and a replayed write asks the
// site for the same end state (an add of a tag the set holds is taken unchanged, a remove of a tag the set no longer
// holds removes nothing, an edit or a tag set update sets the same values), so a lost response is safe to ask for
// again. A replayed create would make another set (N-4 of quick 261126-pfh), and a replayed delete would find its set
// gone and come back refused though the delete took (U-5 of quick 261126-udx), so both are put on the wire once.
```

S8b. In `extension Request`, directly after the closing `    }` of `postMyTagsForm(...)`, insert a blank line and:

```swift
    /// The tag set form's fields in the browser's order, as the site's `do_tagset_post` submits the form: the action,
    /// the name (the new set's for a create, else the form's empty field), the Enabled box, which sends nothing when
    /// unchecked, and the colour, empty for none.
    fileprivate func tagSetFormFields(
        action: String,
        name: String,
        isEnabled: Bool,
        color: SiteColor?
    ) -> [URLQueryItem] {
        var fields = [
            URLQueryItem(name: "tagset_action", value: action),
            URLQueryItem(name: "tagset_name", value: name)
        ]
        if isEnabled {
            fields.append(URLQueryItem(name: "tagset_enable", value: "on"))
        }
        fields.append(URLQueryItem(name: "tagset_color", value: color?.hex ?? ""))
        return fields
    }
```

S8c. In `UpdateMyTagSetRequest`, replace the body of `response()` (from `        var fields = [` through the
`return try await postMyTagsForm(...)` line) with:

```swift
        let fields = tagSetFormFields(action: "update", name: "", isEnabled: isEnabled, color: color)
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSetID)
        return try await postMyTagsForm(fields, to: url, in: urlSession)
```

S8d. In `CreateMyTagSetRequest`, replace the body of `response()` (from `        var fields = [` through the
`return try await postMyTagsForm(...)` line) with:

```swift
        let fields = tagSetFormFields(
            action: "create", name: name, isEnabled: shownTagSet.isEnabled, color: shownTagSet.color
        )
        let url = Defaults.URL.myTags(host: host, tagSetID: shownTagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
```

S8e. After the closing `}` of `CreateMyTagSetRequest`, insert a blank line and:

```swift
/// Deletes a tag set through the tag set form's Delete (`tagset_action=delete`), as the site's `do_tagset_delete`
/// posts it once its confirmation is accepted: the form of the set the page shows, which is the set deleted, to that
/// set's page, its fields in the browser's order. Those are the form's empty `tagset_name`, as with an update, the
/// set's Enabled box, which sends nothing when unchecked, and its colour. Answers the page the site returns, which
/// carries the reason when it refused.
///
/// Put on the wire once (U-5 of quick 261126-udx). A delete the site took whose response was lost looks the same here
/// as one it never received, and posting it again would find the set gone, so the site's answer would read as a
/// refusal of a delete that took. A lost response shows the failure instead, and the next read of My Tags shows
/// whether the set is gone.
public struct DeleteMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        tagSet: MyTagSet,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.tagSet = tagSet
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    /// The set to delete, the one the page shows, whose form the delete is posted from.
    public let tagSet: MyTagSet
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let fields = tagSetFormFields(action: "delete", name: "", isEnabled: tagSet.isEnabled, color: tagSet.color)
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
    }
}
```

#### S9: `AppPackage/Sources/MyTagsClient/MyTagsClient.swift` (Task 2)

S9a. The struct's first doc paragraph (two lines, starting `/// Every My Tags call a reducer makes`) becomes:

```swift
/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, and the
/// create and the delete of a tag set (port of PR 462 item 10; the create, quick 261126-pfh; the delete, quick
/// 261126-udx).
```

S9b. After the `createTagSet` property (its closing line `    ) async throws(AppError) -> MyTagsPage`), insert:

```swift
    /// Deletes `tagSet`, the set the page shows, from its own form; answers the page the site returned. Put on the
    /// wire once (`DeleteMyTagSetRequest`).
    public var deleteTagSet: @Sendable (
        _ host: GalleryHost,
        _ tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
```

S9c. In `live`, `createTagSet: requestCreateTagSet` gains a trailing comma and is followed by
`        deleteTagSet: requestDeleteTagSet`. After the closing `}` of `requestCreateTagSet(...)`, insert a blank line and:

```swift
    private static func requestDeleteTagSet(
        host: GalleryHost,
        tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage {
        try await DeleteMyTagSetRequest(host: host, tagSet: tagSet).response()
    }
```

S9d. In `noop`, the `createTagSet` closure's closing `        }` becomes `        },` and is followed by:

```swift
        deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        }
```

S9e. In `unimplemented`, the `createTagSet` entry's closing `        )` becomes `        ),` and is followed by:

```swift
        deleteTagSet: IssueReporting.unimplemented(
            "MyTagsClient.deleteTagSet", throwing: AppError.unknown
        )
```

S9f. In `failing(_:)`, the `createTagSet` closure's closing `            }` becomes `            },` and is followed by:

```swift
            deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            }
```

#### S10: `AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift` (Task 2)

S10a. Directly after the test `theFetchReadsEveryTagSetInThePickersOrder` (after its closing `    }`), insert a blank
line and:

```swift
    // Each set's page says whether it offers deleting the set, and the fetch keeps each set's word (U-1 of quick
    // 261126-udx).
    @Test
    func theFetchKeepsEachSetsDeleteOffer() async throws {
        let set1URL = try #require(Self.tagSet1URL)
        let set2URL = try #require(Self.tagSet2URL)
        let page1 = try fixture(.myTagsTagSet1)
        let html2 = try htmlString(filename: .myTagsTagSet2)
        let rename = #"<input type="button" onclick="do_tagset_rename()" value="Rename" />"#
        try #require(html2.contains(rename))
        let delete = #" <input type="button" onclick="do_tagset_delete()" value="Delete" />"#
        let page2 = Data(html2.replacing(rename, with: rename + delete).utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([
            set1URL: [.http(status: 200, data: page1)],
            set2URL: [.http(status: 200, data: page2)]
        ]))
        defer { cleanUp(session: session, handle: handle) }

        let response = try await capture { () async throws(AppError) -> MyTagsResponse in
            try await MyTagsRequest(host: .ehentai, urlSession: session).response()
        }
        .get()

        #expect(response.myTags.tagSets.map(\.isDeletable) == [false, true])
    }
```

S10b. Directly after the test `aTagSetCreateIsNotRetriedAfterATransportFailure` (after its closing `    }`), insert a
blank line and:

```swift
    // The delete posts the set's own form, as a browser does once the site's confirmation is accepted: the empty name,
    // then an unchecked Enabled box sends no field, and no colour sends the field empty.
    @Test
    func aTagSetDeletePostsTheSetsFormInOrder() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet1)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.http(status: 200, data: page), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
        let enabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: true, color: green, tags: [])
        let disabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])

        let first = try await deleteTagSet(enabled, session: session).get()
        let second = try await deleteTagSet(disabled, session: session).get()

        #expect(first.tagSet.id == 1)
        #expect(second.tagSet.id == 1)
        let requests = handle.receivedRequests
        #expect(requests.map(\.httpMethod) == ["POST", "POST"])
        expectEquivalentURL(requests.first?.url, url)
        #expect(requests.first?.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(requests.map({ body(of: $0) }) == [
            "tagset_action=delete&tagset_name=&tagset_enable=on&tagset_color=%2322AA55",
            "tagset_action=delete&tagset_name=&tagset_color="
        ])
    }

    // A delete the site took whose answer was lost looks like one it never saw, and posting it again would find the
    // set gone and come back refused though the delete took, so a delete is put on the wire once (U-5).
    @Test
    func aTagSetDeleteIsNotRetriedAfterATransportFailure() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet1)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.transportFailure(.networkConnectionLost), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let shown = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])

        let result = await deleteTagSet(shown, session: session)

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: url) == 1)
    }
```

S10c. Directly after the private helper `createTagSet(named:shown:session:)` (after its closing `    }`), insert a
blank line and:

```swift
    private func deleteTagSet(_ tagSet: MyTagSet, session: URLSession) async -> Result<MyTagsPage, AppError> {
        await capture { () async throws(AppError) -> MyTagsPage in
            try await DeleteMyTagSetRequest(host: .ehentai, tagSet: tagSet, urlSession: session).response()
        }
    }
```

#### S11: `AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift` (Task 3; after the rename of step 1)

S11a. The file's header comment (the first three `//` lines, starting `// The My Tags page`) becomes:

```swift
// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): reading, choosing a tag set, its Enabled flag
// and default colour, Add Tag and Edit Tag, removing, New Tag Set (quick 261126-pfh), Delete Tag Set (quick
// 261126-udx), the site's page as the fallback, and the Account row that opens it. The tags, sets and credentials are
// invented.
```

S11b. Directly after `private static let createRefusal = "Sample refusal from the site"`, insert
`    private static let deleteRefusal = "Sample delete refusal from the site"`; directly after the `set3` line, insert:

```swift
    private static let offeredSet2 = MyTagSet(
        id: 2, name: "Fixture Picks", isEnabled: false, color: green, tags: [], isDeletable: true
    )
```

S11c. Directly before the `@MainActor` line that precedes `private func makeStore(`, insert these tests, each followed
by a blank line:

```swift
    // The row follows the shown set's page (U-1): none for set 2 as the cache holds it, with no page of it read; then
    // the row for its page that offers deleting it; then none for set 1, whose page does not.
    @MainActor
    @Test
    func theDeleteRowShowsOnlyWhileTheShownSetsPageOffersIt() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2)) {
            $0.fetchTagSet = { (_: GalleryHost, tagSetID: Int) async throws(AppError) in
                Self.page(tagSetID == 2 ? Self.offeredSet2 : Self.set1)
            }
        }
        store.exhaustivity = .off
        #expect(!store.state.canDeleteTagSet)

        await store.send(.refresh)
        await store.receive(\.fetchTagSetDone.success)
        #expect(store.state.canDeleteTagSet)

        await store.send(.tagSetSelected(1))
        await store.receive(\.fetchTagSetDone.success)
        #expect(!store.state.canDeleteTagSet)
    }

    @MainActor
    @Test
    func theDeleteRowOpensTheConfirmationAndCancelSendsNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2))

        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: 2)
        }
        await store.send(.deleteTagSetDialog(.dismiss)) {
            $0.deleteTagSetDialog = nil
        }
    }

    @MainActor
    @Test
    func aConfirmedDeleteChoosesTheFirstSetTheAnswerShows() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (host: GalleryHost, tagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("delete \(host.rawValue) \(tagSet.id)") })
                return Self.page(Self.set1, tagSetIDs: [1])
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1], selectedTagSetID: 1) })
        }
        #expect(!store.state.canDeleteTagSet)
        #expect(calls.value == ["delete E-Hentai 2"])
    }

    @MainActor
    @Test
    func aConfirmedDeleteReadsTheFirstSetWhenTheAnswerShowsAnother() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2, Self.set3], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (host: GalleryHost, tagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("delete \(host.rawValue) \(tagSet.id)") })
                return Self.page(Self.set3, tagSetIDs: [1, 3])
            }
            $0.fetchTagSet = { (host: GalleryHost, tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("read \(host.rawValue) \(tagSetID)") })
                return Self.page(Self.set1, tagSetIDs: [1, 3])
            }
        }
        // The cache is a shared reference, so a step's closure would already see the later read's answer; the cache
        // is checked at the end, as the presenting test does.
        store.exhaustivity = .off

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.success) {
            $0.loadingState = .idle
        }
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.set3], selectedTagSetID: 1))
        #expect(calls.value == ["delete E-Hentai 2", "read E-Hentai 1"])
    }

    @MainActor
    @Test
    func aRefusedDeleteShowsTheSitesReasonOnTheRowAndKeepsTheSet() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) in
                Self.page(Self.offeredSet2, message: Self.deleteRefusal)
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: Self.deleteRefusal)
        }
        #expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2))
        #expect(store.state.canDeleteTagSet)
        #expect(store.state.showsDeleteTagSetRow)
    }

    // A refusal whose answer no longer offers deleting the set still shows on the row (U-2a): the row stays, disabled
    // as the set is no longer offered, until its alert is dismissed, and then follows the offer again.
    @MainActor
    @Test
    func aRefusalThatWithdrawsTheOfferKeepsTheRowUntilItsAlertIsDismissed() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set2, message: Self.deleteRefusal)
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 2) })
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: Self.deleteRefusal)
        }
        #expect(!store.state.canDeleteTagSet)
        #expect(store.state.showsDeleteTagSetRow)

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(!store.state.showsDeleteTagSetRow)
    }

    @MainActor
    @Test
    func aDeleteWhoseAnswerStillListsTheSetShowsTheUnknownError() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1)
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: AppError.unknown.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == 2)
    }

    @MainActor
    @Test
    func aFailedDeleteShowsTheErrorOnTheRowAndKeepsTheSet() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2)) {
            $0.deleteTagSet = { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await confirmDelete(of: 2, in: store)
        await store.receive(\.deleteTagSetDone) {
            $0.isChangingTagSets = false
            $0.alertSource = .deleteTagSet
            $0.alert = .failure(title: .myTagsDeleteTagSetFailed, message: AppError.networkingFailed.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == 2)
    }

    // One flag holds both rows while a create or a delete is on its way (U-4); a create and a delete both raise it
    // (`create(_:in:)`, `confirmDelete(of:in:)`), and `aSecondCreateWhileOneIsOnItsWaySendsNothing` is the create's
    // side.
    @MainActor
    @Test
    func aDeleteWhileACreateOrADeleteIsOnItsWaySendsNothing() async {
        let store = makeStore(
            myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: 2), isChangingTagSets: true
        )

        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: 2)
        }
        await store.send(.deleteTagSetDialog(.presented(.delete(tagSetID: 2)))) {
            $0.deleteTagSetDialog = nil
        }
    }

    // The confirmation names its set (U-3): a set no longer shown, or one whose page does not offer deleting it, is
    // not deleted.
    @MainActor
    @Test(arguments: zip([2, 1], [1, 1]))
    func aDeleteOfASetNotShownOrNotOfferedSendsNothing(shownTagSetID: Int, confirmedTagSetID: Int) async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.offeredSet2], selectedTagSetID: shownTagSetID))

        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: shownTagSetID)
        }
        await store.send(.deleteTagSetDialog(.presented(.delete(tagSetID: confirmedTagSetID)))) {
            $0.deleteTagSetDialog = nil
        }
    }
```

S11d. Directly before the type's last helper, `page(_:tagSetIDs:message:)` (the line starting
`    private static func page(`), insert these two helpers, each followed by a blank line:

```swift
    /// Taps Delete Tag Set on the shown set `tagSetID` and confirms, asserting each step; the set's page offers it.
    @MainActor
    private func confirmDelete(of tagSetID: Int, in store: TestStoreOf<MyTagsFeature>) async {
        await store.send(.deleteTagSetTapped) {
            $0.deleteTagSetDialog = Self.deleteTagSetDialog(for: tagSetID)
        }
        await store.send(.deleteTagSetDialog(.presented(.delete(tagSetID: tagSetID)))) {
            $0.deleteTagSetDialog = nil
            $0.isChangingTagSets = true
        }
    }
```

```swift
    /// The Delete Tag Set confirmation as U-3 specifies it, opened for the set `tagSetID`.
    private static func deleteTagSetDialog(
        for tagSetID: Int
    ) -> ConfirmationDialogState<MyTagsFeature.DeleteTagSetDialog> {
        ConfirmationDialogState(titleVisibility: .hidden) {
            TextState(localized: .RLocalizable.delete)
        } actions: {
            ButtonState(role: .destructive, action: .delete(tagSetID: tagSetID)) {
                TextState(localized: .RLocalizable.delete)
            }
            ButtonState(role: .cancel) {
                TextState(localized: .RLocalizable.cancel)
            }
        } message: {
            TextState(localized: .myTagsDeleteTagSetMessage)
        }
    }
```
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Read and keep, per set and in memory only, whether the site offers deleting it (U-1)</name>
  <files>AppPackage/Sources/AppModels/Tags/MyTags.swift, AppPackage/Sources/ParserFeature/Parser+MyTags.swift, AppPackage/Sources/TestingSupport/HTMLFilename.swift, AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet3.html, AppPackage/Tests/AppModelsTests/MyTagsTests.swift, AppPackage/Tests/ParserFeatureTests/Other/MyTagsParserTests.swift</files>
  <precondition>The Precondition section above holds (clean tree apart from this quick task's directory; the orchestrator's MyTagsView commit is in HEAD).</precondition>
  <read_first>
    - AppPackage/Sources/AppModels/Tags/MyTags.swift lines 116-210 (`MyTagSet`, `MyTags`, `applying(_:)`)
    - AppPackage/Sources/ParserFeature/Parser+MyTags.swift (whole file)
    - AppPackage/Sources/TestingSupport/HTMLFilename.swift lines 45-56 and AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet1.html (the markup S3a follows)
    - AppPackage/Tests/AppModelsTests/MyTagsTests.swift (whole file) and AppPackage/Tests/ParserFeatureTests/Other/MyTagsParserTests.swift (whole file)
    - .swiftlint.yml (custom rules)
  </read_first>
  <behavior>
    - The page of `MyTagsTagSet3` parses to set 3, "Fixture Holds", disabled, no colour, no tags, `isDeletable` true, with picker ids [1, 2, 3], the fixtures' credentials and no message (U-1).
    - The pages `MyTagsTagSet1` and `MyTagsTagSet2` parse with `isDeletable` false; the tags form's Delete Selected does not count (U-1).
    - `MyTagsTagSet3` with its Delete control given `disabled="disabled"` parses with `isDeletable` false (U-1a).
    - A page's set replaces the stored one together with its offer, in both directions, and the set the page does not show keeps its own offer (U-1).
    - A set encoded with `isDeletable` true stores exactly the keys `color`, `id`, `isEnabled`, `name`, `tags`; decoded, it offers nothing and equals the same set built without the offer; a stored set without `color` decodes as before (U-1).
  </behavior>
  <action>
Write the tests first (RED: `isDeletable` and `.myTagsTagSet3` do not exist, so the test targets do not compile; run
`-only-testing:ParserFeatureTests -only-testing:AppModelsTests` once to see it, log `task1-red.log`), then the code.

1. Tests and test data (U-8: the parser test with and without the control, and with a disabled one per U-1a; the
   model's storage contract of U-1):
   apply S3a (the new synthetic fixture), S3b (its `HTMLFilename` case), S4a and S4b (`MyTagsTests.swift`), S4c and
   S4d (`MyTagsParserTests.swift`).
2. `MyTags.swift` (U-1, P-1, settled facts 2 and 3): apply S1. `isDeletable` is `public private(set) var` with the
   default `false`, left out of the private `CodingKeys`, so the stored shape is unchanged; the initializer takes it
   last with the default `false`, so every existing call site compiles unchanged. `MyTags`, `applying(_:)` and the
   rest of the file are not touched.
3. `Parser+MyTags.swift` (U-1, U-1a, P-2, settled fact 10): apply S2a to S2c.
4. Run the verify lines, then commit.

Commit subject: `tags: read whether a tag set can be deleted`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-udx && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:ParserFeatureTests -only-testing:AppModelsTests -only-testing:NetworkingFeatureTests -only-testing:SettingFeatureTests -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-udx/task1-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-udx/task1-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-udx/task1-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsParserTests/[A-Za-z]+" .capture/261126-udx/task1-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=7 EXPECT==10]</automated>
    <automated>grep -oE "Test case 'MyTagsTests/[A-Za-z]+" .capture/261126-udx/task1-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=12 EXPECT==14]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/AppModels AppPackage/Sources/ParserFeature AppPackage/Sources/TestingSupport AppPackage/Tests/AppModelsTests AppPackage/Tests/ParserFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppModels/Tags/MyTags.swift | grep -c 'public private(set) var isDeletable = false'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppModels/Tags/MyTags.swift | grep -c 'private enum CodingKeys: String, CodingKey'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/ParserFeature/Parser+MyTags.swift | grep -cF "[contains(@onclick, 'do_tagset_delete(')][not(@disabled)]"   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/ParserFeature/Parser+MyTags.swift | grep -c 'isDeletable: offersDelete'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -c 'onclick="do_tagset_delete()"' AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet3.html   [HEAD: no such file; EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/TestingSupport/HTMLFilename.swift | grep -c 'case myTagsTagSet3 = "MyTagsTagSet3"'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on `isDeletable` or `myTagsTagSet3`; then ParserFeatureTests, AppModelsTests, NetworkingFeatureTests, SettingFeatureTests and DetailFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the five new tests listed as passed; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: read whether a tag set can be deleted` holding exactly the six files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: The delete request and client, posted once; one builder for the tag set form (U-5)</name>
  <files>AppPackage/Sources/NetworkingFeature/Request+MyTags.swift, AppPackage/Sources/MyTagsClient/MyTagsClient.swift, AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift</files>
  <read_first>
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift (whole file)
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift (whole file)
    - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift (whole file)
  </read_first>
  <behavior>
    - Two deletes of set 2, one enabled with #22AA55, one unchecked with no colour, post to `https://e-hentai.org/mytags?tagset=2` as `application/x-www-form-urlencoded` with the bodies `tagset_action=delete&tagset_name=&tagset_enable=on&tagset_color=%2322AA55` and `tagset_action=delete&tagset_name=&tagset_color=`, and answer the parsed page (U-5).
    - A delete whose first attempt fails with a lost connection answers `.failure(.networkingFailed)` after exactly one attempt, though the stub holds a 200 for a second (U-5).
    - The fetch of every set keeps each set's offer: set 1's page without the control and set 2's page with it give [false, true] (U-1).
    - The update and create bodies stay byte for byte as their existing tests pin them (P-6).
  </behavior>
  <action>
Write the tests first (RED: `DeleteMyTagSetRequest` does not exist, so the request tests do not compile; run
`-only-testing:NetworkingFeatureTests` once to see it, log `task2-red.log`), then the code.

1. Tests: apply S10a, S10b and S10c to `MyTagsRequestTests.swift` (U-8: the posted fields and their order; the single
   attempt; the fetch keeping each set's offer). No new fixture: S10a varies `MyTagsTagSet2` in place, as the refusal
   test varies `MyTagsTagSet1`.
2. `Request+MyTags.swift` (U-5, P-6, settled fact 1): apply S8a (the header note now names the delete's exception),
   S8b (`tagSetFormFields`), S8c and S8d (the update and the create build their fields through it; their URLs and
   attempts are unchanged) and S8e (`DeleteMyTagSetRequest`, after `CreateMyTagSetRequest`, posting with
   `attempts: 1`; its doc comment states why it is not retried).
3. `MyTagsClient.swift` (U-5, settled fact 4): apply S9a to S9f, so `deleteTagSet` exists in the type, `live`, `noop`
   (throws `.notFound`, as the other writes), `unimplemented` and `failing(_:)`.
4. Run the verify lines, then commit.

Commit subject: `tags: ask the site to delete a tag set`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-udx && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:NetworkingFeatureTests -only-testing:SettingFeatureTests -only-testing:DetailFeatureTests -only-testing:DownloadsFeatureTests 2>&1 | tee .capture/261126-udx/task2-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-udx/task2-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-udx/task2-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsRequestTests/[A-Za-z]+" .capture/261126-udx/task2-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=12 EXPECT==15]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/NetworkingFeature AppPackage/Sources/MyTagsClient AppPackage/Tests/NetworkingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'public struct DeleteMyTagSetRequest: Request'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'attempts: 1)'   [HEAD=1 EXPECT==2]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'URLQueryItem(name: "tagset_action"'   [HEAD=2 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'tagSetFormFields('   [HEAD=0 EXPECT==4]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'deleteTagSet:'   [HEAD=0 EXPECT==5]</automated>
  </verify>
  <done>The RED run failed to compile on `DeleteMyTagSetRequest`; then NetworkingFeatureTests, SettingFeatureTests, DetailFeatureTests and DownloadsFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the three new request tests and the two existing tag set form tests listed as passed; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: ask the site to delete a tag set` holding exactly the three files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Delete Tag Set on the My Tags page: row, confirmation, delete, the first set chosen and shown, one flag for both rows, copy, tests (U-2, U-3, U-4, U-6, U-7, U-8)</name>
  <files>AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift, AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift, AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings, AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift</files>
  <read_first>
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift and AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift (whole files)
    - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift (whole file)
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift lines 98-120 and AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift lines 36-50 (the Delete Profile confirmation on its row)
    - .planning/quick/261126-udx-add-delete-tag-set-to-native-my-tags/261126-udx-CONTEXT.md, the Copy table
  </read_first>
  <behavior>
    - With set 2 as the cache holds it (no page read) the row is absent; after its page that offers deleting it is read the row shows; after set 1, whose page does not, is chosen and read the row is absent (U-1, U-2).
    - The row opens the confirmation (no title, the message, Delete naming set 2, Cancel); Cancel closes it and sends nothing (U-3).
    - Delete posts set 2 once; an answer showing set 1 with picker [1] and no reason drops set 2, chooses set 1 (kept with the cache) and reads nothing more (U-6).
    - An answer showing set 3 with picker [1, 3] chooses set 1, shows the loading view and reads set 1; the cache ends as [set 1, set 3] with set 1 chosen (U-6).
    - A `#msg` refusal shows Couldn't Delete Tag Set with the site's reason on the row; an answer that still lists set 2 shows it with `AppError.unknown.alertText`; a failed request with the error's `alertText`; in each set 2 stays chosen (U-6).
    - A delete while a create or a delete is on its way sends nothing, and a delete of a set that is not the one shown, or whose page does not offer it, sends nothing (U-4, U-3).
    - A refusal whose answer shows set 2 no longer offered shows its alert while `showsDeleteTagSetRow` stays true and `canDeleteTagSet` is false (the row kept, disabled); after the alert is dismissed `showsDeleteTagSetRow` is false (U-2a).
    - Every existing My Tags test passes after the rename of `isCreatingTagSet` to `isChangingTagSets` (P-5).
  </behavior>
  <action>
1. Rename (P-5, settled fact 9): run, from the repository root,
   `sed -i '' 's/isCreatingTagSet/isChangingTagSets/g' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift`.
   Every later shape of this task is written against the renamed text.
2. Tests first (U-8): apply S11a to S11d to `MyTagsFeatureTests.swift`. They run in the suite's existing
   `@Suite(.isolatedAppStorage)`, in parallel, `@MainActor` on members only. RED: run `-only-testing:SettingFeatureTests`
   once; it fails to compile on the missing actions and symbols; log `task3-red.log`.
3. Copy (CONTEXT Copy table, P-9): create `.capture/261126-udx/insert_copy.py` with S7's exact content and run
   `python3 -I .capture/261126-udx/insert_copy.py insert` from the repository root; it must print `ok`. The three keys
   are module-local to SettingFeature's `Localizable.xcstrings` (every use is in SettingFeature and its tests), string
   values only. If the script asserts, stop and report its message.
4. `MyTagsFeature.swift`: apply S5a to S5f. This gives the confirmation of U-3 naming its set (P-4), the delete of U-5
   guarded by U-4's flag and by the shown, offered set, the answer of U-6 taken into the cache with the choice and the
   read of the site's first set (P-7) through the existing id-taking `fetchTagSet`, and the failure alert on
   `AlertSource.deleteTagSet` with P-8's `AppError.unknown` for an answer that still lists the set, and
   `showsDeleteTagSetRow`, true while the shown set is offered or while the row's own failure alert is up (U-2a).
5. `MyTagsView.swift`: apply S6a and S6b. The row is the tag set section's last row, after New Tag Set, present while
   `showsDeleteTagSetRow` (U-1, U-2, U-2a), a default-style destructive `Button` (no hover helper: settled fact 7),
   disabled by the same flag as New Tag Set (U-4) and whenever the shown set is not offered (U-2a), with the
   confirmation and its failure alert attached to it (U-2, AGENTS.md dialog placement). iPad pushes this same view in the Settings sheet, so nothing else changes; no rename anywhere
   (U-7).
6. Run the verify lines, then commit.

Commit subject: `settings: add Delete Tag Set to My Tags`
  </action>
  <verify>
    <automated>python3 -I .capture/261126-udx/insert_copy.py check   [HEAD: KeyError: 'my_tags.delete_tag_set' (keys absent); EXPECT: ok]</automated>
    <automated>git diff --numstat -- AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings   [HEAD: no output; EXPECT before the commit: "123	0	AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings"]</automated>
    <automated>mkdir -p .capture/261126-udx && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:SettingFeatureTests -only-testing:AppToolsTests 2>&1 | tee .capture/261126-udx/task3-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-udx/task3-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-udx/task3-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsFeatureTests/[A-Za-z]+" .capture/261126-udx/task3-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=24 EXPECT==34]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/SettingFeature AppPackage/Tests/SettingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>cat AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift | grep -v '^\s*//' | grep -c 'isCreatingTagSet'   [HEAD=15 EXPECT==0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF '.disabled(store.isChangingTagSets)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF '.disabled(store.isChangingTagSets || !store.canDeleteTagSet)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF 'Button(.myTagsDeleteTagSet, role: .destructive)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF '.confirmationDialog($store.scope(\.$deleteTagSetDialog, action: \.deleteTagSetDialog))'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF '.appAlert(alert(for: .deleteTagSet))'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -cF 'if store.showsDeleteTagSetRow {'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'canDeleteTagSet || (alertSource == .deleteTagSet && alert != nil)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'ConfirmationDialogState(titleVisibility: .hidden)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'try await myTagsClient.deleteTagSet(host, tagSet)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF '.ifLet(\.$deleteTagSetDialog, action: \.deleteTagSetDialog)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -cF 'AppError.unknown.alertText'   [HEAD=1 EXPECT==2]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -c 'case deleteTagSet$'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing actions; `insert_copy.py check` prints `ok` and the catalog diff is 123 insertions, 0 deletions; SettingFeatureTests and AppToolsTests pass (TEST SUCCEEDED, 0 failed cases) with the ten new My Tags tests listed as passed (34 distinct names), every existing My Tags test still passing after the rename, and the pointer-hover audit unchanged; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `settings: add Delete Tag Set to My Tags` holding exactly the four files.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user to site | A confirmed delete crosses into a destructive form post on the account's My Tags page |
| site to app | The page's delete control, picker ids, `#msg` reason and credentials are parsed and drive the row and the choice |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261126-udx-01 | Tampering | `deleteTagSetDialog(.presented(.delete(tagSetID:)))` | high | mitigate | The confirmation names the set it was opened for; the reducer deletes only when that set is still the one shown and its page still offers it, and posts the shown set's own form to its own page (tested: `aDeleteOfASetNotShownOrNotOfferedSendsNothing`) |
| T-261126-udx-02 | Repudiation | a replayed delete after a lost answer | medium | mitigate | `DeleteMyTagSetRequest` posts with `attempts: 1` (tested: one attempt after a lost connection), so a delete the site took is never answered as a refusal by its own replay |
| T-261126-udx-03 | Denial of service | a create and a delete crossing | medium | mitigate | One flag disables both rows and refuses both requests while either is on its way (tested for the delete; the create's existing test covers its side) |
| T-261126-udx-04 | Information disclosure | the per-set offer and the stored `User` | low | mitigate | `isDeletable` is left out of `CodingKeys`: nothing new is stored, the stored shape is unchanged (tested by its encoded keys), credentials stay in feature state as before |
| T-261126-udx-05 | Spoofing | the site's `#msg` reason in the failure alert | low | accept | Existing parser: trimmed text, at most 200 characters, shown as plain text through `TextState`, never as markup or a link |
| T-261126-udx-06 | Elevation of privilege | a page marking a set deletable | low | accept | The site is the authority for which sets it offers; the app adds a confirmation and never deletes a set the shown page does not offer |
| T-261126-udx-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs and no dependency change (`AppPackage/Package.swift` untouched) |
</threat_model>

<verification>
After Task 3, once, from the repository root (TEST rules apply):
- Full plan: `mkdir -p .capture/261126-udx && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -skip-testing:VisualSnapshotTests 2>&1 | tee .capture/261126-udx/full-plan.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'` prints `** TEST SUCCEEDED **`; `grep -cE "Test case '.*' failed" .capture/261126-udx/full-plan.log` prints `0`; `grep -E ': warning: ' .capture/261126-udx/full-plan.log | sort -u` prints nothing.
- Lint over every source tree: `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` prints nothing.
- Invariant (no suppression, no serialization added): `git diff <BASE> -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'` prints `0` (BASE as recorded under Precondition).
- `git log -3 --format='%G? %aI %cI %s'` shows the three subjects, each `G` with two `+08:00` instants; `git status --short` shows nothing but untracked planning files of this quick task; nothing is pushed.
</verification>

<success_criteria>
- U-1: the parser reads the delete control of the shown set's tag set form into `MyTagSet.isDeletable`; every page read brings it into the cache; it is never stored, the stored `User.myTags` decodes as before, and a set read back from storage shows no row.
- U-1a: a Delete control with a `disabled` attribute is not an offer (tested).
- U-2: the tag set section ends with New Tag Set, then the destructive Delete Tag Set row while the shown set is offered, carrying its confirmation and its failure alert (`AlertSource.deleteTagSet`).
- U-2a: the row stays, disabled when not offered, while its own failure alert is up, and follows the offer again once the alert is dismissed (tested).
- U-3: the confirmation has no title, the message, a destructive Delete and Cancel, as Delete Profile; Cancel sends nothing.
- U-4: while a create or a delete is on its way, both rows are disabled and neither request is sent.
- U-5: `DeleteMyTagSetRequest` posts the four fields in order to the shown set's page, once, with its WHY documented; `MyTagsClient.deleteTagSet` exists in live, noop, unimplemented and failing.
- U-6: the answer is taken into the cache; success chooses the site's first set (kept with the cache) and shows it from the answer or through a read; a `#msg`, a set still listed or a failed request shows Couldn't Delete Tag Set on the row and keeps the choice.
- U-7: no rename; iPad uses the same page.
- U-8: the reducer, request, parser and model tests listed in the tasks pass in parallel.
- U-9: the SUMMARY lists the owner's device check.
- Three signed `+08:00` commits, 0 warnings, lint clean, full FeatureTests plan green (VisualSnapshotTests skipped).
</success_criteria>

<output>
Create `.planning/quick/261126-udx-add-delete-tag-set-to-native-my-tags/261126-udx-SUMMARY.md` when done (not
committed). Record: BASE; the three commit hashes and subjects with their `%G? %aI %cI`; each test run (log name,
targets, TEST SUCCEEDED or the RED compile error, failed-case count, the new test names seen as passed); the gate
outputs; and, for the orchestrator:

- **Owner's device check (U-9)**, not done by the executor because it needs the owner's signed-in account and deletes
  a set on the site: on iPhone (Setting tab) and on iPad (Settings sheet), open Account, My Tags. Note for which sets
  the tag set section shows Delete Tag Set after New Tag Set (and that it matches the sets whose site page shows an
  enabled Delete button, U-1a). On an offered set, tap it: the confirmation shows "Delete this tag set?" with Delete
  and Cancel (on iPad a popover pointing at the row; a tap outside cancels). Cancel changes nothing. Delete: the set
  leaves the picker and the site's first set is shown (after the loading view if the site answered with another
  page), and the set is gone from the site's own My Tags page. Also worth noting there: which page the site answered
  the delete with, and any refusal wording it shows.
- The planner's choices P-1 to P-10, one line each, and how U-1a and U-2a were carried out.
</output>
