---
phase: 261126-pfh-add-a-new-tag-set-action-to-the-native-m
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/AppComponents/AppAlertState.swift
  - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift
  - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
  - AppPackage/Sources/AppModels/Tags/MyTags.swift
  - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift
  - AppPackage/Tests/AppModelsTests/MyTagsTests.swift
  - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift
  - AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift
autonomous: true
requirements: [N-1, N-2, N-3, N-4, N-5, N-6, N-7, N-8, N-9]

estimate:
  tokens: 170000
  raw_tokens: 170000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "The My Tags tag set section ends with a tint-coloured New Tag Set row (no chevron), disabled while a create is on its way; it opens the native alert titled New Tag Set with the message, the focused Name field, Create and Cancel, and the name is empty every time the alert opens (N-1, N-2)."
    - "Create is disabled while the typed name, trimmed of whitespace and newlines, is empty; Cancel never is; an alert whose field does not ask for it, the page jump included, keeps every button enabled (N-3)."
    - "Create posts tagset_action=create, the trimmed name, tagset_enable=on only when the shown set is enabled, and tagset_color (the shown set's #RRGGBB or empty), in that order, to the shown set's /mytags page, and puts it on the wire once (N-4)."
    - "With exactly one set id in the answer's picker that the cache lacked before the post and no #msg, the page chooses it (kept with the cache), shows the loading view, reads it, and then lists it in the picker in the site's order with the site's name, Enabled and colour, its tags section showing No Tags Yet (N-5, N-6)."
    - "A #msg refusal, an answer with no new set, or a failed request shows the alert titled Couldn't Create Tag Set on the New Tag Set row with the site's reason, the unknown error's text, or the error's text, and chooses nothing; a blank name and a second create while one is on its way send nothing (N-3, N-5)."
    - "The six copy keys are in SettingFeature's Localizable.xcstrings in all six locales with CONTEXT's values verbatim, the catalog still in Xcode's canonical form (Copy)."
  artifacts:
    - path: "AppPackage/Sources/AppComponents/AppAlertState.swift"
      provides: "The text-field alert option that holds every non-cancel button until the field has text"
      contains: "public func enablesButton(role: ButtonStateRole?, text: String) -> Bool"
    - path: "AppPackage/Sources/NetworkingFeature/Request+MyTags.swift"
      provides: "The create request, posted once"
      contains: "public struct CreateMyTagSetRequest: Request"
    - path: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      provides: "createTagSet in live, noop, unimplemented and failing"
      contains: "public var createTagSet: @Sendable ("
    - path: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      provides: "The New Tag Set alert, the create and the choice of the new set"
      contains: "case createTagSetDone(knownTagSetIDs: [Int], result: Result<MyTagsPage, AppError>)"
    - path: "AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift"
      provides: "The New Tag Set row carrying both alerts"
      contains: "Button(.myTagsNewTagSet)"
  key_links:
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift"
      to: "AppPackage/Sources/AppComponents/AppAlertState.swift"
      via: "the row's appAlert(_:text:) binds the name and renders the field that requiresText"
      pattern: "text: \\$store\\.newTagSetName\\.sending\\(\\\\\\.newTagSetNameChanged\\)"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      to: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      via: "Create sends the trimmed name and the shown set through createTagSet"
      pattern: "myTagsClient\\.createTagSet\\(host, name, shownTagSet\\)"
    - from: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      to: "AppPackage/Sources/NetworkingFeature/Request+MyTags.swift"
      via: "live createTagSet builds CreateMyTagSetRequest, which posts with attempts 1"
      pattern: "CreateMyTagSetRequest\\(host: host, name: name, shownTagSet: shownTagSet\\)"
    - from: "AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift"
      to: "AppPackage/Sources/AppModels/Tags/MyTags.swift"
      via: "the new set's read goes through take, whose applying(_:) puts the page's own set into tagSets"
      pattern: "fetchTagSet\\(newTagSetID, host: state\\.setting\\.galleryHost\\)"
---

<objective>
Add New Tag Set to the native My Tags page exactly as CONTEXT's locked decisions N-1 to N-9 and its copy table say,
in three signed commits on top of `develop` (nothing pushed):

1. The shared text-field alert gains an option that holds every non-cancel button until the field has text (N-3).
2. `CreateMyTagSetRequest` and `MyTagsClient.createTagSet` post the site's create form once, never retried (N-4), and
   the model documents and tests the `applying(_:)` behaviour the new set relies on (N-6).
3. The page's tag set section gets the New Tag Set row, its alert, the create, the choice and read of the new set, the
   failure alert on the row, the six copy keys and the reducer tests (N-1, N-2, N-5, N-6, N-8).

Purpose: the owner can make a tag set from the app, as the site's New button does, and land on it, empty, ready for
Add Tag.
Output: three signed `+08:00` commits; `261126-pfh-SUMMARY.md` (not committed) listing the owner's device check (N-9).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/261126-pfh-add-a-new-tag-set-action-to-the-native-m/261126-pfh-CONTEXT.md
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

### Where and how you work

- This checkout, branch `develop` (HEAD `12d91afcf` when this plan was written; the orchestrator's plan commit may sit
  on top). New commits go on top; no new branch, no rebase, no amend, no push, nothing on GitHub, no bare `git stash`.
  Never commit this PLAN, the SUMMARY, STATE.md or anything under
  `.planning/quick/261126-pfh-add-a-new-tag-set-action-to-the-native-m/` (the orchestrator commits planning artifacts).
- Read `AGENTS.local.md` before the first commit and follow it; never copy its content into any artifact.
- Read the root `.swiftlint.yml` before writing Swift. No `swiftlint:disable` of any kind, no rule changes, no
  `.serialized`.
- Logs and scratch files go under `.capture/261126-pfh/` (gitignored). The SUMMARY carries no absolute home paths
  (write `$HOME/...`) and names no other local project.
- Code comments use decision IDs (N-1 to N-9) and the quick task id, never agent names.
- Every Swift block this plan gives under "Shapes" is copied exactly as written, at the indentation written.
- The executor writes no copy: the six strings come from CONTEXT's table through the script in S7, unchanged.

### COMMIT (each task ends with exactly one)

Stage only the task's own files by path (`git add <path> ...`, whole files, never `-A`, `-p` or `-U0` hunks), check
`git diff --cached --stat` lists exactly them, then `TZ=Asia/Shanghai git commit -m "<subject>"` with the subject the
task gives (no body, no attribution or co-author lines). Verify `git log -1 --format='%G? %aI %cI'` prints `G` and two
`+08:00` instants; if signing fails, follow AGENTS.local.md, then retry the same commit.

### TEST (shared rules)

- Before every `xcodebuild` invocation, `pgrep -x xcodebuild; pgrep -x xctest` must print nothing. If either prints a
  pid, wait (poll every 30 s with `pgrep -x`, never `pgrep -f`) and never kill anything. One invocation at a time.
- Tests run on `EhPanda iPhone Air (phase19)`, id `19DB23C0-8C35-49C7-9A7D-5D99566BF092`, from the repository root, in
  this form (fill the targets and the log name):
  `mkdir -p .capture/261126-pfh && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never <-only-testing:Target ...> 2>&1 | tee .capture/261126-pfh/<log>.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'`
  It passes when it prints `** TEST SUCCEEDED **` and `grep -cE "Test case '.*' failed" .capture/261126-pfh/<log>.log`
  prints `0`. Xcode 27.2 prints no `Test run with N tests` line; the per-case `Test case '...' passed` lines are the
  evidence (a parameterized test prints one line per argument).
- Warnings: `grep -E ': warning: ' .capture/261126-pfh/<log>.log | sort -u` must print nothing. A warning in a file
  this plan does not touch: stop and report it (do not fix it).
- Lint, from the repository root, on the task's trees:
  `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet <trees>`
  must print nothing and exit 0.
- Known flake: if the only failure of the final full run is
  `FavoritesFeatureTests/LoginReturnObservationTests/cookieLoginTriggersReloadWithoutAViewCallback`, re-run
  `-only-testing:FavoritesFeatureTests` once; it must pass; record both runs in the SUMMARY.

### Settled facts (checked by the planner against the tree at `12d91afcf`; do not re-derive)

1. **Retries.** `Request.fetch(_:in:attempts:)` (`NetworkingFeature/Request.swift`) re-sends a request on any thrown
   transport error up to `attempts` times (default 4); HTTP statuses are returned, not retried. `LoginRequest` and the
   report request pass `attempts: 1` because a POST the server may have acted on must not be replayed. A create the
   site took whose response was lost would be posted again and could make a second set, so N-4's condition holds: the
   create is posted with `attempts: 1`. Every other My Tags request keeps the default.
2. **`applying(_:)` already keeps the page's own set (N-6).** Its `compactMap` maps the page's own id to `page.tagSet`
   before it looks in the cache, so the set a page shows takes its place in the picker's order even when the cache
   lacks it; only the other ids the cache lacks stay out. So reading the new set through `fetchTagSet` puts it in
   `tagSets` with no code change; Task 2 only documents and tests this, the contract for other callers is unchanged.
3. **Why `fetchTagSet` takes an id.** `State.selectedTagSetID` is `selectedTagSet?.id ?? 1`, and
   `MyTags.selectedTagSet` falls back to the first set when the chosen id is not in `tagSets`. Right after a create the
   new id is chosen but not yet in `tagSets`, so `state.selectedTagSetID` names the first set. Task 3 gives
   `fetchTagSet` the id explicitly; its two existing callers pass `state.selectedTagSetID`, unchanged in effect.
4. **Ephemeral alerts.** `AppAlertState` is `_EphemeralState`: `.ifLet(\.$newTagSetAlert, action:
   \.newTagSetAlert)` with no child reducer sets the state to nil when a button's action arrives, and the scoped
   binding sends `.dismiss` when Cancel closes the alert.
5. **Copy symbols.** Keys of `SettingFeature/Resources/Localizable.xcstrings` generate internal
   `LocalizedStringResource` members named after the key (`my_tags.empty.title` is `.myTagsEmptyTitle`), so the six
   keys become `.myTagsNewTagSet`, `.myTagsNewTagSetTitle`, `.myTagsNewTagSetMessage`, `.myTagsNewTagSetName`,
   `.myTagsNewTagSetCreate` and `.myTagsCreateTagSetFailed`, visible to `SettingFeatureTests` through `@testable import
   SettingFeature`. No catalog in the package has these keys. The catalog is in Xcode's canonical form (byte-identical
   to `json.dumps(indent=2, ensure_ascii=False, separators=(",", " : "))`, keys in Python's sorted order, no trailing
   newline); the S7 script was dry-run on a copy: it inserts 246 lines (6 keys x 41) and deletes none.
6. **Pointer hover audit.** `AppToolsTests/PointerHoverAuditTests` flags plain or unhighlighted buttons, tap gestures
   and custom button styles only. A default-style `Button` in a `Form` keeps the system's pointer response, as the
   page's other rows do, so the row needs no hover helper.
7. **No component test exists for `appAlert`.** No test drives `appAlert` or `AppAlertTextFieldState` (there is no
   AppComponents test target; SystemNotificationTests covers the toast style). Under N-8 no component test is added;
   the rule is pinned through the My Tags alert in Task 3 (`createWaitsForANameAndCancelNeverWaits`), its one user.
8. **Builder.** In the iOS 27.2 SDK `ViewModifier.body(content:)` carries `@ContentBuilder`, so a `let` before the
   `content.alert(...)` expression compiles inside the builder.
9. **Client construction.** `MyTagsClient` is built only in `MyTagsClient.swift` (`live`, `noop`, `unimplemented`,
   `failing(_:)`); no other file calls its memberwise initializer.
10. **Package settings.** `MemberImportVisibility`, `InternalImportsByDefault` and `ExistentialAny` are on. Files that
    import only `SwiftUI` already call `trimmingCharacters(in:)` (for example `MyTagEditor/HexColorField.swift`), so
    `AppAlertState.swift` needs no new import.

### Planner's choices where CONTEXT leaves them open (each is final for the executor)

- **P-1 (N-3) Option name and shape.** `AppAlertTextFieldState.requiresText: Bool` (default `false`) and a pure
  `enablesButton(role:text:) -> Bool` on the same type, which the modifier calls per button. The rule lives in the
  state type so it is plain logic, testable without presenting an alert. The modifier reads the bound text in its own
  `body`, so every keystroke re-renders the alert's buttons.
- **P-2 (N-2) Binding.** The name binds through `$store.newTagSetName.sending(\.newTagSetNameChanged)`, the binding
  style of every other control on this page, rather than adding `BindableAction` to the reducer for one field.
- **P-3 (N-1, N-2) Two presentations on the row.** The name alert is its own `@Presents var newTagSetAlert:
  AppAlertState<NewTagSetAlert>?` (the only alert here with an action); its failure alert goes through the page's
  existing `alert` with the new `AlertSource.newTagSet`, as N-1 says. Both `.appAlert` modifiers sit on the row.
- **P-4 (N-5) "Before the post".** The ids the cache holds are captured when Create is handled and carried back in
  `createTagSetDone(knownTagSetIDs:result:)`, so a read landing while the post is on its way cannot hide the new set.
- **P-5 (N-5) Error for "no new id, no #msg".** `AppError.unknown`: the page was read (so not `.parseFailed`, whose
  text says the response could not be read), it is not an empty page (so not `.notFound`, "There seems to be nothing
  here."), and the site gave no reason; `.unknown`'s text says an unknown error occurred and to try again later.
- **P-6 (N-5, not covered by CONTEXT) More than one new id.** Possible only if another client made a set while the
  page was open. It is neither "exactly one" (so nothing is chosen) nor "no new id" (a set was made, so no failure
  alert): the page reads every set again (`fetchMyTags`), so each new set shows in the picker with its site name. The
  orchestrator may override this before execution.
- **P-7 (N-4) Request shape.** `CreateMyTagSetRequest(host:name:shownTagSet:urlSession:)` takes the shown set whole
  (its id, Enabled and colour are the form's other fields); `postMyTagsForm` gains `attempts: Int = 4` (fetch's own
  default) and the create passes `attempts: 1`.
- **P-8 (N-3) Defence in depth.** Besides a blank trimmed name, the reducer refuses a second create while one is on
  its way: a create is not safe to send twice.
- **P-9 (N-5) `#msg` and a new id together.** N-5's order holds: a reason on the page fails the create and nothing is
  chosen.
- **P-10 (Copy) Inserted by script.** S7 reads the six rows from CONTEXT's table and writes them; nobody retypes copy.
- **P-11 Task shape.** Three layered tasks with one green commit each, as the orchestrator proposed, instead of a
  tracer: the path (form post, `MyTagsClient`, reducer, page) is the one `UpdateMyTagSetRequest` already proves.

### Shapes (copy exactly)

#### S1: `AppPackage/Sources/AppComponents/AppAlertState.swift` (Task 1)

S1a. In `AppAlertTextFieldState`, replace the lines from `    public var placeholder: TextState` through the closing
`    }` of `init(placeholder:keyboard:)` with:

```swift
    public var placeholder: TextState
    public var keyboard: Keyboard
    /// Holds every button but the cancel one while the field's text, trimmed of whitespace and newlines, is empty.
    ///
    /// For an alert whose action means nothing without a value, such as naming a new tag set (N-3 of quick
    /// 261126-pfh). A native alert cannot check its own field, and any button closes it: a button the reducer would
    /// only refuse would close the alert with nothing done and no word why. Off by default, so an alert that takes
    /// any text keeps every button enabled; the page jump checks its number itself.
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

S1b. In the doc comment of `appAlert(_:text:)`, directly after the line that ends
`text: $store.pageIndex)`.`, add this line:

```swift
    /// A field that ``AppAlertTextFieldState/requiresText`` holds every button but Cancel until `text` has some.
```

S1c. In `AppAlertViewModifier`:
- directly after the line `    func body(content: Content) -> some View {`, insert:

```swift
        // Read here, in the modifier's own body, so the field's text is a dependency of this view: each keystroke
        // renders the alert again, its buttons held or released by the field (`requiresText`).
        let fieldText = text?.wrappedValue
```

- inside `ForEach(store.buttons) { button in`, directly after the `Button`'s closing `}` of its `label:` closure
  (the line after `Text(button.label)`), insert at the `Button`'s own indentation (20 spaces):

```swift
                    .disabled(!Self.enables(button, field: store.textField, text: fieldText))
```

- after the closing `    }` of `body(content:)`, before the struct's closing `}`, insert a blank line and:

```swift
    /// Whether `button` can be tapped while the bound field holds `text`; with no bound field none is shown, and
    /// nothing is held.
    private static func enables(
        _ button: ButtonState<Action>,
        field: AppAlertTextFieldState?,
        text: String?
    ) -> Bool {
        guard let field, let text else { return true }
        return field.enablesButton(role: button.role, text: text)
    }
```

Nothing else in the file changes (the existing `lifecycle_modifiers` comment and its disable line stay as they are).

#### S2: `AppPackage/Sources/NetworkingFeature/Request+MyTags.swift` (Task 2)

S2a. Replace the file's header comment (the four `//` lines starting `// The My Tags reads and writes`) with:

```swift
// The My Tags reads and writes (port of PR 462 item 10; the site contract read live on 2026-11-22). Every request but
// the create keeps `fetch`'s default four attempts: the reads are GETs, and a replayed write asks the site for the
// same end state (an add of a tag the set holds is taken unchanged, a remove of a tag the set no longer holds removes
// nothing, an edit or a tag set update sets the same values), so a lost response is safe to ask for again. A replayed
// create would make another set, so `CreateMyTagSetRequest` is put on the wire once (N-4 of quick 261126-pfh).
```

S2b. Replace `postMyTagsForm` (its doc line and the whole function) with:

```swift
    /// Posts a My Tags form, its fields in order, to `url`, and parses the page the site answers with. `attempts` is
    /// `fetch`'s; its default suits a write the site can be asked for again (see the note above).
    fileprivate func postMyTagsForm(
        _ fields: [URLQueryItem],
        to url: URL,
        in session: URLSession,
        attempts: Int = 4
    ) async throws(AppError) -> MyTagsPage {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(fields.formURLEncodedString().utf8)
        request.setURLEncodedContentType()
        let (data, _) = try await fetch(request, in: session, attempts: attempts)
        return try myTagsPage(data: data)
    }
```

S2c. After the closing `}` of `UpdateMyTagSetRequest`, insert a blank line and:

```swift
/// Creates a tag set through the tag set form's New (`tagset_action=create`), as the site's `do_tagset_create` posts
/// it: the form of the set the page shows, to that set's page, its fields in the browser's order. Besides the new
/// set's name, those are the shown set's Enabled box, which sends nothing when unchecked, and its colour. Answers the
/// page the site returns, which carries the reason when it refused.
///
/// Put on the wire once (N-4 of quick 261126-pfh). A create is not an end state the site can be asked for again: one
/// the site took whose response was lost looks the same here as one it never received, and posting it again could
/// make a second set. A lost response costs the user one more Create instead, and a set the site did make shows at
/// the next read of My Tags.
public struct CreateMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        name: String,
        shownTagSet: MyTagSet,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.name = name
        self.shownTagSet = shownTagSet
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    /// The new set's name; the page sends it trimmed.
    public let name: String
    /// The set the page shows, whose form the create is posted from.
    public let shownTagSet: MyTagSet
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        var fields = [
            URLQueryItem(name: "tagset_action", value: "create"),
            URLQueryItem(name: "tagset_name", value: name)
        ]
        if shownTagSet.isEnabled {
            fields.append(URLQueryItem(name: "tagset_enable", value: "on"))
        }
        fields.append(URLQueryItem(name: "tagset_color", value: shownTagSet.color?.hex ?? ""))
        let url = Defaults.URL.myTags(host: host, tagSetID: shownTagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
    }
}
```

#### S3: `AppPackage/Sources/MyTagsClient/MyTagsClient.swift` (Task 2)

S3a. The struct's first doc paragraph (two lines, starting `/// Every My Tags call a reducer makes`) becomes:

```swift
/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, and the
/// create of a tag set (port of PR 462 item 10; the create, quick 261126-pfh).
```

S3b. After the `updateTagSet` property (its closing line `    ) async throws(AppError) -> MyTagsPage`), insert:

```swift
    /// Creates a tag set named `name` from the form of `shownTagSet`, the set the page shows; answers the page the
    /// site returned. Put on the wire once (`CreateMyTagSetRequest`).
    public var createTagSet: @Sendable (
        _ host: GalleryHost,
        _ name: String,
        _ shownTagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
```

S3c. In `live`, `updateTagSet: requestUpdateTagSet` gains a trailing comma and is followed by
`        createTagSet: requestCreateTagSet`. After the closing `}` of `requestUpdateTagSet(...)`, insert a blank line and:

```swift
    private static func requestCreateTagSet(
        host: GalleryHost,
        name: String,
        shownTagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage {
        try await CreateMyTagSetRequest(host: host, name: name, shownTagSet: shownTagSet).response()
    }
```

S3d. In `noop`, the `updateTagSet` closure's closing `        }` becomes `        },` and is followed by:

```swift
        createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        }
```

S3e. In `unimplemented`, the `updateTagSet` entry's closing `        )` becomes `        ),` and is followed by:

```swift
        createTagSet: IssueReporting.unimplemented(
            "MyTagsClient.createTagSet", throwing: AppError.unknown
        )
```

S3f. In `failing(_:)`, the `updateTagSet` closure's closing `            }` becomes `            },` and is followed by:

```swift
            createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            }
```

#### S4: `AppPackage/Sources/AppModels/Tags/MyTags.swift` and `AppPackage/Tests/AppModelsTests/MyTagsTests.swift` (Task 2)

S4a. The two doc lines of `applying(_:)` (starting `/// The cache with `page`'s set in place of the one stored`)
become (the code is unchanged):

```swift
    /// The cache with `page`'s set in place of the one stored, in the order of the page's picker. The page's own set
    /// takes its place even when the cache lacks it, as the set New Tag Set made does when the page reads it (N-6 of
    /// quick 261126-pfh); any other set the picker lists but the cache lacks stays out until the next fetch, and a set
    /// the picker no longer lists is dropped.
```

S4b. In `MyTagsTests.swift`, directly after the test `aPageReplacesItsSetInThePickersOrderAndKeepsTheSelection`
(after its closing `    }`), insert a blank line and:

```swift
    // New Tag Set reads the set it made, which the cache lacks (N-6 of quick 261126-pfh): the page's own set takes its
    // place in the picker's order, while set 4, which the cache lacks too, stays out until the next fetch.
    @Test
    func aPageOfASetTheCacheLacksTakesItsPlaceInThePickersOrder() {
        let first = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [Self.glasses])
        let second = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: Self.green, tags: [Self.artist])
        let made = MyTagSet(id: 3, name: "Fixture Holds", isEnabled: false, color: nil, tags: [])
        let cache = MyTags(tagSets: [first, second], selectedTagSetID: 3)

        let applied = cache.applying(Self.page(made, tagSetIDs: [1, 3, 2, 4]))

        #expect(applied == MyTags(tagSets: [first, made, second], selectedTagSetID: 3))
    }
```

#### S5: `AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift` (Task 3)

S5a. The type's doc comment: after its last line (`/// never persisted.`), append:

```swift
///
/// New Tag Set asks for a name in an alert, then has the site create the set from the form of the set shown; the
/// page then chooses the new set and reads it, and a refusal or a failure shows the alert on the row (quick
/// 261126-pfh).
```

S5b. `AlertSource` gains a last case, and a new enum follows it:

```swift
    /// A control whose request failed, so the alert shows on it.
    public enum AlertSource: Equatable, Sendable {
        case enabled
        case defaultColor
        case tag(Int)
        /// The New Tag Set row, whose create was refused or failed.
        case newTagSet
    }

    /// The New Tag Set alert's action besides Cancel.
    public enum NewTagSetAlert: Equatable, Sendable {
        case create
    }
```

S5c. In `State`, after `@Presents public var toast: AppAlertState<Never>?`, insert:

```swift
        /// The alert that names a new tag set (N-2 of quick 261126-pfh).
        @Presents public var newTagSetAlert: AppAlertState<NewTagSetAlert>?
```

and after `public var confirmedTagSet: MyTagSet?`, insert:

```swift
        /// The name typed into the New Tag Set alert; emptied each time the alert opens.
        public var newTagSetName = ""
        /// A create is on its way: the New Tag Set row is disabled, and another create is refused, until the site
        /// answers.
        public var isCreatingTagSet = false
```

S5d. In `Action`, after `case toast(PresentationAction<Never>)`, insert
`        case newTagSetAlert(PresentationAction<NewTagSetAlert>)`, and after
`case removeTagDone(tagID: Int, result: Result<MyTagsPage, AppError>)`, insert:

```swift
        case newTagSetTapped
        case newTagSetNameChanged(String)
        case createTagSetDone(knownTagSetIDs: [Int], result: Result<MyTagsPage, AppError>)
```

S5e. In `body`, the first case becomes `            case .alert, .toast, .delegate, .newTagSetAlert(.dismiss):`.
In `.tagSetSelected` and `.refresh`, `return fetchTagSet(state)` becomes
`return fetchTagSet(state.selectedTagSetID, host: state.setting.galleryHost)`. After the
`case .removeTagDone(let tagID, .failure(let error)):` case (after its `)` line), insert a blank line and:

```swift
            // The name starts empty each time (N-2); Create waits for one (N-3).
            case .newTagSetTapped:
                state.newTagSetName = ""
                state.newTagSetAlert = AppAlertState(
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
                return .none

            case .newTagSetNameChanged(let name):
                state.newTagSetName = name
                return .none

            // A blank name is refused here too, though Create waits for one (N-3), and so is a second create while
            // one is on its way: a create is not safe to send twice (`CreateMyTagSetRequest`). The sets the cache
            // has now are the ones the site's answer is read against (N-5).
            case .newTagSetAlert(.presented(.create)):
                let name = state.newTagSetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !state.isCreatingTagSet, let shownTagSet = state.selectedTagSet
                else { return .none }
                state.isCreatingTagSet = true
                let knownTagSetIDs = state.user.myTags?.tagSets.map(\.id) ?? []
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.createTagSet(host, name, shownTagSet)
                    }
                    await send(.createTagSetDone(knownTagSetIDs: knownTagSetIDs, result: result))
                }

            // The new set is the one id the answer's picker lists that the cache lacked before the post (N-5). It is
            // chosen, kept with the cache as a choice in the picker is, and read, so the loading view shows until its
            // page arrives with the name, Enabled and colour the site gave it; that read puts it in the picker (N-6).
            // A reason on the page, or no new id, fails the create. More than one new id means a set was also made
            // elsewhere meanwhile: none is chosen, and every set is read again so each shows with its name.
            case .createTagSetDone(let knownTagSetIDs, .success(let page)):
                state.isCreatingTagSet = false
                take(page, into: &state)
                if let message = page.message {
                    return presentAlert(&state, .newTagSet, title: .myTagsCreateTagSetFailed, message: message)
                }
                let newTagSetIDs = page.tagSetIDs.filter({ !knownTagSetIDs.contains($0) })
                guard let newTagSetID = newTagSetIDs.first else {
                    // Neither the new set nor a reason: the page was read (no parse failure), so all the app knows
                    // is that the set is not there.
                    return presentAlert(
                        &state, .newTagSet, title: .myTagsCreateTagSetFailed, message: AppError.unknown.alertText
                    )
                }
                guard newTagSetIDs.count == 1 else { return .send(.fetchMyTags) }
                state.$user.withLock({ $0.myTags = $0.myTags?.selecting(newTagSetID) })
                state.loadingState = .loading
                return fetchTagSet(newTagSetID, host: state.setting.galleryHost)

            case .createTagSetDone(_, .failure(let error)):
                state.isCreatingTagSet = false
                return presentAlert(
                    &state, .newTagSet, title: .myTagsCreateTagSetFailed, message: error.alertText
                )
```

S5f. After `        .ifLet(\.$toast, action: \.toast)`, add `        .ifLet(\.$newTagSetAlert, action: \.newTagSetAlert)`.

S5g. Replace the private `fetchTagSet` helper (the one that takes the whole state) with:

```swift
    /// Reads the set `tagSetID`'s page on `host`, in place of any read still on its way. It takes the id rather than
    /// reading the state's: right after a create, the new set is chosen but not yet in the cache, so the state's
    /// `selectedTagSetID` still names the first set.
    private func fetchTagSet(_ tagSetID: Int, host: GalleryHost) -> Effect<Action> {
        .run { send in
            let result = await Result.Swift::init { () async throws(AppError) in
                try await myTagsClient.fetchTagSet(host, tagSetID)
            }
            await send(.fetchTagSetDone(result))
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }
```

#### S6: `AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift` (Task 3)

S6a. The type's doc comment becomes:

```swift
/// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): the tag set (its picker, Enabled and default
/// colour, and New Tag Set) and its tags, one row each; a row opens Edit Tag and a trailing swipe removes the tag. Add
/// Tag sits in the toolbar. Signed out it shows Log In; loading, the loading view; failed, the error with Open in
/// Browser.
```

S6b. In `form(_:)`'s first `Section`, directly after `.appAlert(alert(for: .defaultColor))` (the `HexColorField`'s
last modifier) and before `} footer: {`, insert:

```swift
                Button(.myTagsNewTagSet) {
                    store.send(.newTagSetTapped)
                }
                .disabled(store.isCreatingTagSet)
                // On the row that opens them, the name alert and its failure alert (AGENTS.md dialog placement).
                .appAlert(
                    $store.scope(\.$newTagSetAlert, action: \.newTagSetAlert),
                    text: $store.newTagSetName.sending(\.newTagSetNameChanged)
                )
                .appAlert(alert(for: .newTagSet))
```

#### S7: `.capture/261126-pfh/insert_copy.py` (Task 3; scratch, never committed)

Run from the repository root: `python3 .capture/261126-pfh/insert_copy.py insert` (inserts, then checks) and
`python3 .capture/261126-pfh/insert_copy.py check` (prints `ok` when every key holds CONTEXT's values). The script has
no `\u` escapes; the characters it checks are named with `chr(...)`.

```python
import json
import sys
from pathlib import Path

CONTEXT = Path(".planning/quick/261126-pfh-add-a-new-tag-set-action-to-the-native-m/261126-pfh-CONTEXT.md")
CATALOG = Path("AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings")
KEYS = [
    "my_tags.new_tag_set",
    "my_tags.new_tag_set.title",
    "my_tags.new_tag_set.message",
    "my_tags.new_tag_set.name",
    "my_tags.new_tag_set.create",
    "my_tags.create_tag_set_failed",
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

    for locale in ["en", "de", "ja", "ko", "zh-Hans"]:
        assert value("my_tags.new_tag_set", locale).endswith(chr(0x2026)), locale
    assert value("my_tags.new_tag_set", "zh-Hant").endswith(chr(0x22EF))
    assert value("my_tags.new_tag_set", "de").endswith(chr(0x20) + chr(0x2026))
    assert chr(0x2019) in value("my_tags.create_tag_set_failed", "en")
    print("ok")


if __name__ == "__main__":
    {"insert": insert, "check": check}[sys.argv[1]]()
```

#### S8: `AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift` (Task 3)

S8a. The file's header comment (the first three `//` lines, starting `// The My Tags page`) becomes:

```swift
// The My Tags page (port of PR 462 item 10, design approved 2026-11-22): reading, choosing a tag set, its Enabled flag
// and default colour, Add Tag and Edit Tag, removing, New Tag Set (quick 261126-pfh), the site's page as the fallback,
// and the Account row that opens it. The tags, sets and credentials are invented.
```

S8b. After `private static let refusal = "No matching tag found"`, insert
`    private static let createRefusal = "Sample refusal from the site"`; after the `set2` line, insert
`    private static let set3 = MyTagSet(id: 3, name: "Fixture Holds", isEnabled: false, color: nil, tags: [])`.

S8c. Directly before the `@MainActor` line that precedes `private func makeStore(`, insert these tests, each followed by
a blank line:

```swift
    @MainActor
    @Test
    func theRowOpensTheAlertWithAnEmptyName() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]))

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged("Leftover")) {
            $0.newTagSetName = "Leftover"
        }
        await store.send(.newTagSetAlert(.dismiss)) {
            $0.newTagSetAlert = nil
        }
        await store.send(.newTagSetTapped) {
            $0.newTagSetName = ""
            $0.newTagSetAlert = Self.newTagSetAlert
        }
    }

    // The alert's field holds Create until a name is typed, and never Cancel (N-3); an alert whose field does not
    // ask for it, as the page jump's, holds nothing.
    @MainActor
    @Test
    func createWaitsForANameAndCancelNeverWaits() async throws {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1]))
        store.exhaustivity = .off

        await store.send(.newTagSetTapped)
        let alert = try #require(store.state.newTagSetAlert)
        let field = try #require(alert.textField)
        let createButton = try #require(alert.buttons.first(where: { $0.role == nil }))
        let cancelButton = try #require(alert.buttons.first(where: { $0.role == .cancel }))
        for blank in ["", "   ", " \n\t "] {
            #expect(!field.enablesButton(role: createButton.role, text: blank))
            #expect(field.enablesButton(role: cancelButton.role, text: blank))
        }
        #expect(field.enablesButton(role: createButton.role, text: " Fixture Holds "))
        #expect(AppAlertTextFieldState(placeholder: TextState(verbatim: "Page")).enablesButton(role: nil, text: ""))
    }

    @MainActor
    @Test
    func aNameIsPostedAndTheNewSetIsChosenAndRead() async {
        let calls = LockIsolated<[String]>([])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (host: GalleryHost, name: String, shownTagSet: MyTagSet) async throws(AppError) in
                calls.withValue({ $0.append("create \(host.rawValue) [\(name)] \(shownTagSet.id)") })
                return Self.page(Self.set1, tagSetIDs: [1, 2, 3])
            }
            $0.fetchTagSet = { (host: GalleryHost, tagSetID: Int) async throws(AppError) in
                calls.withValue({ $0.append("read \(host.rawValue) \(tagSetID)") })
                return Self.page(Self.set3, tagSetIDs: [1, 2, 3])
            }
        }

        await create("  Fixture Holds \n", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isCreatingTagSet = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 3) })
            $0.loadingState = .loading
        }
        await store.receive(\.fetchTagSetDone.success) {
            $0.loadingState = .idle
            $0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2, Self.set3], selectedTagSetID: 3) })
        }
        #expect(store.state.selectedTagSet == Self.set3)
        #expect(calls.value == ["create E-Hentai [Fixture Holds] 1", "read E-Hentai 3"])
    }

    @MainActor
    @Test
    func aRefusedCreateShowsTheSitesReasonOnTheRowAndChoosesNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1, message: Self.createRefusal)
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isCreatingTagSet = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .newTagSet
            $0.alert = .failure(title: .myTagsCreateTagSetFailed, message: Self.createRefusal)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == nil)
    }

    @MainActor
    @Test
    func aCreateWhoseAnswerListsNoNewSetShowsTheUnknownError() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1)
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isCreatingTagSet = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
            $0.alertSource = .newTagSet
            $0.alert = .failure(title: .myTagsCreateTagSetFailed, message: AppError.unknown.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == nil)
    }

    @MainActor
    @Test
    func aFailedCreateShowsTheErrorOnTheRowAndChoosesNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw .networkingFailed
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isCreatingTagSet = false
            $0.alertSource = .newTagSet
            $0.alert = .failure(title: .myTagsCreateTagSetFailed, message: AppError.networkingFailed.alertText)
        }
        #expect(store.state.user.myTags?.selectedTagSetID == nil)
    }

    // Two new ids mean a set was also made elsewhere meanwhile: none is chosen, and every set is read again.
    @MainActor
    @Test
    func aCreateWhoseAnswerListsTwoNewSetsReadsEverySetAgain() async {
        let set4 = MyTagSet(id: 4, name: "Fixture Extras", isEnabled: false, color: nil, tags: [])
        let everySet = MyTags(tagSets: [Self.set1, Self.set2, Self.set3, set4])
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2])) {
            $0.createTagSet = { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) in
                Self.page(Self.set1, tagSetIDs: [1, 2, 3, 4])
            }
            $0.fetchMyTags = { (_: GalleryHost) async throws(AppError) in
                MyTagsResponse(myTags: everySet, apiuid: 1234567, apikey: "0123456789abcdef")
            }
        }

        await create("Fixture Holds", in: store)
        await store.receive(\.createTagSetDone) {
            $0.isCreatingTagSet = false
            $0.apiuid = 1234567
            $0.apikey = "0123456789abcdef"
        }
        await store.receive(\.fetchMyTags) {
            $0.loadingState = .loading
        }
        await store.receive(\.fetchMyTagsDone.success) {
            $0.loadingState = .idle
            $0.$user.withLock({ $0.myTags = everySet })
        }
    }

    @MainActor
    @Test(arguments: ["", "   ", " \n\t "])
    func aBlankNameSendsNothing(name: String) async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]))

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged(name)) {
            $0.newTagSetName = name
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
        }
    }

    @MainActor
    @Test
    func aSecondCreateWhileOneIsOnItsWaySendsNothing() async {
        let store = makeStore(myTags: MyTags(tagSets: [Self.set1, Self.set2]), isCreatingTagSet: true)

        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged("Fixture Holds")) {
            $0.newTagSetName = "Fixture Holds"
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
        }
    }
```

S8d. `makeStore(...)` gains the parameter `isCreatingTagSet: Bool = false,` on its own line directly after
`credentials: Bool = false,`, and the line `state.isCreatingTagSet = isCreatingTagSet` directly after the
`if credentials { ... }` block.

S8e. Replace the `page(_:message:)` helper at the end of the type with:

```swift
    /// Opens New Tag Set, types `name` and taps Create, asserting each step; `name` is not blank.
    @MainActor
    private func create(_ name: String, in store: TestStoreOf<MyTagsFeature>) async {
        await store.send(.newTagSetTapped) {
            $0.newTagSetAlert = Self.newTagSetAlert
        }
        await store.send(.newTagSetNameChanged(name)) {
            $0.newTagSetName = name
        }
        await store.send(.newTagSetAlert(.presented(.create))) {
            $0.newTagSetAlert = nil
            $0.isCreatingTagSet = true
        }
    }

    /// The New Tag Set alert as N-2 and N-3 specify it.
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

    private static func page(_ tagSet: MyTagSet, tagSetIDs: [Int] = [1, 2], message: String? = nil) -> MyTagsPage {
        MyTagsPage(
            tagSet: tagSet, tagSetIDs: tagSetIDs, apiuid: 1234567, apikey: "0123456789abcdef", message: message
        )
    }
```

#### S9: `AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift` (Task 2)

S9a. Directly after the test `aTagSetUpdatePostsTheFormsFieldsInOrder` (after its closing `    }`), insert a blank line
and:

```swift
    // The create posts the shown set's form with the new name, as a browser does: an unchecked Enabled box sends no
    // field, and no colour sends the field empty.
    @Test
    func aTagSetCreatePostsTheShownSetsFormWithTheNameInOrder() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.http(status: 200, data: page), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
        let enabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: true, color: green, tags: [])
        let disabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])

        let first = try await createTagSet(named: "Picks & Holds", shown: enabled, session: session).get()
        let second = try await createTagSet(named: "Fixture Holds", shown: disabled, session: session).get()

        #expect([first.tagSet.id, second.tagSet.id] == [2, 2])
        let requests = handle.receivedRequests
        #expect(requests.map(\.httpMethod) == ["POST", "POST"])
        expectEquivalentURL(requests.first?.url, url)
        #expect(requests.first?.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(requests.map({ body(of: $0) }) == [
            "tagset_action=create&tagset_name=Picks%20%26%20Holds&tagset_enable=on&tagset_color=%2322AA55",
            "tagset_action=create&tagset_name=Fixture%20Holds&tagset_color="
        ])
    }

    // A create the site took whose answer was lost looks like one it never saw, and posting it again could make a
    // second set, so a create is put on the wire once (N-4).
    @Test
    func aTagSetCreateIsNotRetriedAfterATransportFailure() async throws {
        let url = try #require(Self.tagSet1URL)
        let page = try fixture(.myTagsTagSet1)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.transportFailure(.networkConnectionLost), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let shown = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])

        let result = await createTagSet(named: "Fixture Holds", shown: shown, session: session)

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: url) == 1)
    }
```

S9b. Directly after the private helper `updateTagSet(isEnabled:color:session:)` (after its closing `    }`), insert a
blank line and:

```swift
    private func createTagSet(
        named name: String,
        shown shownTagSet: MyTagSet,
        session: URLSession
    ) async -> Result<MyTagsPage, AppError> {
        await capture { () async throws(AppError) -> MyTagsPage in
            try await CreateMyTagSetRequest(
                host: .ehentai, name: name, shownTagSet: shownTagSet, urlSession: session
            )
            .response()
        }
    }
```
</context>

<tasks>

<task type="auto">
  <name>Task 1: A text-field alert that holds its buttons until the field has text (N-3)</name>
  <files>AppPackage/Sources/AppComponents/AppAlertState.swift</files>
  <read_first>
    - AppPackage/Sources/AppComponents/AppAlertState.swift (whole file)
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift lines 129-151 and AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift line 40 (the page-jump alert, which must stay unchanged)
    - .swiftlint.yml (custom rules)
  </read_first>
  <action>
Per N-3 and P-1, extend the shared component, not a local workaround:

1. Apply S1a: `AppAlertTextFieldState` gains `public var requiresText: Bool` (documented WHY), the initializer gains
   `requiresText: Bool = false` as its last parameter (default off, so the page-jump alert in `ToplistsReducer` is
   unchanged and its call site is not touched), and the pure `enablesButton(role:text:)` holds every button whose role
   is not `.cancel` while the text trimmed of whitespace and newlines is empty.
2. Apply S1b: one doc line on `appAlert(_:text:)` naming the option.
3. Apply S1c: `AppAlertViewModifier.body(content:)` reads the bound text once at the top (so a keystroke re-renders
   the alert), each alert `Button` gets `.disabled(!Self.enables(...))`, and the private static `enables` helper returns
   `true` whenever there is no field state or no bound text (a field is only shown with a bound text).
4. Nothing else in the file changes; no new import (settled fact 10).
5. Run the verify lines, then commit.

Commit subject: `alert: hold buttons until a field has text`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-pfh && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:HomeFeatureTests -only-testing:SystemNotificationTests -only-testing:AppToolsTests 2>&1 | tee .capture/261126-pfh/task1-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-pfh/task1-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-pfh/task1-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/AppComponents   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/AppAlertState.swift | grep -c 'public var requiresText: Bool'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/AppAlertState.swift | grep -c 'public func enablesButton(role: ButtonStateRole?, text: String) -> Bool'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/AppAlertState.swift | grep -c '\.disabled(!Self\.enables(button, field: store\.textField, text: fieldText))'   [HEAD=0 EXPECT=1]</automated>
  </verify>
  <done>HomeFeatureTests, SystemNotificationTests and AppToolsTests pass (TEST SUCCEEDED, 0 failed cases), no warning, lint clean; the three gates print their EXPECT values; one signed `+08:00` commit `alert: hold buttons until a field has text` holding exactly `AppAlertState.swift`.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: The create request and client, posted once; the model contract the new set relies on (N-4, N-6)</name>
  <files>AppPackage/Sources/NetworkingFeature/Request+MyTags.swift, AppPackage/Sources/MyTagsClient/MyTagsClient.swift, AppPackage/Sources/AppModels/Tags/MyTags.swift, AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift, AppPackage/Tests/AppModelsTests/MyTagsTests.swift</files>
  <read_first>
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift (whole file) and AppPackage/Sources/NetworkingFeature/Request.swift lines 56-86 (`fetch` and its `attempts`)
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift (whole file)
    - AppPackage/Sources/AppModels/Tags/MyTags.swift lines 147-207 (`MyTags`, `applying(_:)`)
    - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift (whole file), AppPackage/Tests/NetworkingFeatureTests/ReportRequestBaselineTests.swift lines 52-68 (the not-retried pattern), AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift lines 1-60
    - AppPackage/Tests/AppModelsTests/MyTagsTests.swift lines 1-15 and 88-102, and its `page(_:tagSetIDs:)` helper
  </read_first>
  <behavior>
    - Two creates from shown set 2, one enabled with #22AA55 named `Picks & Holds`, one unchecked with no colour named `Fixture Holds`, post to `https://e-hentai.org/mytags?tagset=2` as `application/x-www-form-urlencoded`, with the bodies `tagset_action=create&tagset_name=Picks%20%26%20Holds&tagset_enable=on&tagset_color=%2322AA55` and `tagset_action=create&tagset_name=Fixture%20Holds&tagset_color=`, and answer the parsed page (set 2) (N-4).
    - A create whose first attempt fails with a lost connection answers `.failure(.networkingFailed)` after exactly one attempt, though the stub holds a 200 for a second (N-4).
    - `applying(_:)` of a page of set 3, which the cache lacks, with picker ids [1, 3, 2, 4] gives [set 1, set 3, set 2] with the selection kept; set 4 stays out (N-6).
  </behavior>
  <action>
Write the tests first (RED: `CreateMyTagSetRequest` does not exist, so the request tests do not compile; run
`-only-testing:NetworkingFeatureTests` once to see it, log `task2-red.log`), then the code.

1. Tests: apply S9a and S9b to `MyTagsRequestTests.swift` and S4b to `MyTagsTests.swift` (N-8: the posted fields and
   their order; the single attempt; the model contract). No new fixture: the existing synthetic `MyTagsTagSet1` and
   `MyTagsTagSet2` pages are the answers (N-8 allows a fixture only for a new page shape).
2. `Request+MyTags.swift` (N-4, P-7, settled fact 1): apply S2a (header note now names the create's exception),
   S2b (`postMyTagsForm` forwards `attempts`, default 4) and S2c (`CreateMyTagSetRequest`, after
   `UpdateMyTagSetRequest`, posting with `attempts: 1`; its doc comment states why it is not retried).
3. `MyTagsClient.swift` (N-4): apply S3a to S3f, so `createTagSet` exists in the type, `live`, `noop` (throws
   `.notFound`, as the other writes), `unimplemented` and `failing(_:)`.
4. `MyTags.swift` (N-6, settled fact 2): apply S4a; the code of `applying(_:)` is not touched.
5. Run the verify lines, then commit.

Commit subject: `tags: ask the site to create a tag set`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-pfh && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:NetworkingFeatureTests -only-testing:AppModelsTests -only-testing:SettingFeatureTests -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-pfh/task2-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-pfh/task2-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-pfh/task2-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsRequestTests/[A-Za-z]+" .capture/261126-pfh/task2-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=10 EXPECT=12]</automated>
    <automated>grep -oE "Test case 'MyTagsTests/[A-Za-z]+" .capture/261126-pfh/task2-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=11 EXPECT=12]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/NetworkingFeature AppPackage/Sources/MyTagsClient AppPackage/Sources/AppModels AppPackage/Tests/NetworkingFeatureTests AppPackage/Tests/AppModelsTests   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'public struct CreateMyTagSetRequest: Request'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+MyTags.swift | grep -c 'fetch(request, in: session, attempts: attempts)'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'createTagSet:'   [HEAD=0 EXPECT=5]</automated>
    <automated>sed 's|^ *///||' AppPackage/Sources/AppModels/Tags/MyTags.swift | tr '\n' ' ' | tr -s ' ' | grep -c "The page's own set takes its place even when the cache lacks it"   [HEAD=0 EXPECT=1]</automated>
    <automated>git diff --numstat -- AppPackage/Sources/AppModels/Tags/MyTags.swift   [HEAD: no output; EXPECT before the commit: "4	2	AppPackage/Sources/AppModels/Tags/MyTags.swift"]</automated>
  </verify>
  <done>The RED run failed to compile on `CreateMyTagSetRequest`; then NetworkingFeatureTests, AppModelsTests, SettingFeatureTests and DetailFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the three new tests listed as passed; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: ask the site to create a tag set` holding exactly the five files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: New Tag Set on the My Tags page: row, alert, create, the new set chosen and read, copy, tests (N-1, N-2, N-5, N-6, N-7, N-8)</name>
  <files>AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift, AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift, AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings, AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift</files>
  <read_first>
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift and AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift (whole files)
    - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift (whole file)
    - AppPackage/Sources/AppComponents/AppAlertState.swift as Task 1 left it (`AppAlertTextFieldState`, `failure(title:message:)`)
    - .planning/quick/261126-pfh-add-a-new-tag-set-action-to-the-native-m/261126-pfh-CONTEXT.md, the Copy table
  </read_first>
  <behavior>
    - The row opens the alert (title, message, Name field that requiresText, Create, Cancel) with an empty name, also after a name was typed and the alert cancelled (N-1, N-2).
    - Create waits for a name: blank, spaces and whitespace with newlines hold Create and never Cancel; ` Fixture Holds ` releases Create; a field that does not ask for it holds nothing (N-3).
    - `  Fixture Holds \n` is posted trimmed from shown set 1; the answer's picker [1, 2, 3] has one new id, 3, which is chosen (kept with the cache) with the loading view shown, then read; set 3 enters the picker after set 2 and is the selected set (N-5, N-6).
    - A `#msg` refusal shows Couldn't Create Tag Set with the site's reason on the row; an answer with no new set shows it with `AppError.unknown.alertText`; a failed request with the error's `alertText`; in each nothing is chosen (N-5).
    - An answer with two new ids chooses nothing, shows no alert and reads every set again (P-6).
    - A blank name ("", spaces, whitespace with newlines) sends nothing, and so does a second create while one is on its way (N-3, P-8).
  </behavior>
  <action>
Write the tests first (RED: the actions and symbols do not exist yet, so `MyTagsFeatureTests` does not compile; run
`-only-testing:SettingFeatureTests` once to see it, log `task3-red.log`), then the code.

1. Tests (N-8): apply S8a to S8e to `MyTagsFeatureTests.swift`. They run in the suite's existing
   `@Suite(.isolatedAppStorage)`, in parallel, `@MainActor` on members only.
2. Copy (CONTEXT Copy table): create `.capture/261126-pfh/insert_copy.py` with S7's exact content, run
   `python3 .capture/261126-pfh/insert_copy.py insert` from the repository root; it must print `ok`. The six keys are
   module-local to SettingFeature's `Localizable.xcstrings` (no key needs sharing: every use is in SettingFeature and
   its tests), string values only. If the script asserts, stop and report its message.
3. `MyTagsFeature.swift`: apply S5a to S5g. This gives the alert of N-2 with the field option of N-3
   (`requiresText: true`), the name bound per P-2 and emptied on open, the create of N-4 with the defence of N-3 and
   P-8, the choice and read of the new set of N-5 and N-6 through the id-taking `fetchTagSet` (settled fact 3), the
   failure alert on `AlertSource.newTagSet` with P-5's `AppError.unknown` for an answer with no new set and no reason,
   and P-6's re-read for more than one new id.
4. `MyTagsView.swift`: apply S6a and S6b. The row is the tag set section's last row, a default-style `Button` (tint
   text, no chevron, no hover helper: settled fact 6), disabled while a create is on its way, and both alerts attach
   to it (N-1, AGENTS.md dialog placement). The section footer, the toolbar and the scroll-edge modifier are unchanged.
   iPad pushes this same view in the Settings sheet, so nothing else changes (N-7). Rename and delete stay out (N-7).
5. Run the verify lines, then commit.

Commit subject: `settings: add New Tag Set to My Tags`
  </action>
  <verify>
    <automated>python3 .capture/261126-pfh/insert_copy.py check   [HEAD: KeyError: 'my_tags.new_tag_set' (keys absent); EXPECT: ok]</automated>
    <automated>git diff --numstat -- AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings   [HEAD: no output; EXPECT before the commit: "246	0	AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings"]</automated>
    <automated>mkdir -p .capture/261126-pfh && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:SettingFeatureTests -only-testing:AppToolsTests 2>&1 | tee .capture/261126-pfh/task3-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-pfh/task3-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-pfh/task3-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagsFeatureTests/[A-Za-z]+" .capture/261126-pfh/task3-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=15 EXPECT=24]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/SettingFeature AppPackage/Tests/SettingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -c '\.appAlert('   [HEAD=3 EXPECT=5]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift | grep -c 'Button(.myTagsNewTagSet)'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -c 'fetchTagSet(state.selectedTagSetID, host: state.setting.galleryHost)'   [HEAD=0 EXPECT=2]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -c 'fetchTagSet(_ state: State)'   [HEAD=1 EXPECT=0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -c 'requiresText: true'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -c 'AppError.unknown.alertText'   [HEAD=0 EXPECT=1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift | grep -c 'case newTagSet$'   [HEAD=0 EXPECT=1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing actions; `insert_copy.py check` prints `ok` and the catalog diff is 246 insertions, 0 deletions; SettingFeatureTests and AppToolsTests pass (TEST SUCCEEDED, 0 failed cases) with the nine new My Tags tests listed as passed (24 distinct names) and the pointer-hover audit unchanged; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `settings: add New Tag Set to My Tags` holding exactly the four files.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user to site | The typed name crosses into a form post to the account's My Tags page |
| site to app | The answer page (its picker ids, `#msg` reason, credentials) is parsed and shown |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261126-pfh-01 | Tampering | `CreateMyTagSetRequest` form body | medium | mitigate | The name is one `URLQueryItem` value, percent-encoded by `formURLEncodedString()`, so `&`, `=` and `+` in a name cannot add or change fields; the request test posts `Picks & Holds` and asserts the exact body |
| T-261126-pfh-02 | Denial of service | duplicate sets on the account | medium | mitigate | The create is posted with `attempts: 1` (tested: one attempt after a lost connection), the row is disabled while a create is on its way, and the reducer refuses a second create then (tested) |
| T-261126-pfh-03 | Spoofing | the site's `#msg` reason in the failure alert | low | accept | Existing parser: trimmed text, at most 200 characters, shown as plain text through `TextState`, never as markup or a link |
| T-261126-pfh-04 | Information disclosure | edit API credentials of the answer page | low | accept | Unchanged: `take` keeps them in feature state only; `MyTags` has no credential field and nothing new is persisted |
| T-261126-pfh-05 | Denial of service | an answer listing many new ids | low | accept | One `fetchMyTags` per create at most (P-6); it is cancellable and replaces any read on its way |
| T-261126-pfh-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs and no dependency change (`AppPackage/Package.swift` untouched) |
</threat_model>

<verification>
After Task 3, once, from the repository root (TEST rules apply):
- Full plan: `mkdir -p .capture/261126-pfh && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -skip-testing:VisualSnapshotTests 2>&1 | tee .capture/261126-pfh/full-plan.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'` prints `** TEST SUCCEEDED **`; `grep -cE "Test case '.*' failed" .capture/261126-pfh/full-plan.log` prints `0`; `grep -E ': warning: ' .capture/261126-pfh/full-plan.log | sort -u` prints nothing.
- Lint over every source tree: `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` prints nothing.
- Invariant (no suppression, no serialization added): `git diff 12d91afcf -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'` prints `0`.
- `git log -3 --format='%G? %aI %cI %s'` shows the three subjects, each `G` with two `+08:00` instants; `git status --short` shows only the untracked quick task directory; nothing is pushed.
</verification>

<success_criteria>
- N-1: the tag set section ends with the New Tag Set row, disabled while a create is on its way, carrying the name alert and its failure alert (`AlertSource.newTagSet`).
- N-2: the alert has the title, message, focused Name field, Create and Cancel from the copy table; the name is empty each time it opens and binds through `appAlert(_:text:)`.
- N-3: `requiresText` on the shared component holds every non-cancel button while the trimmed text is empty, default off; the reducer also refuses a blank name.
- N-4: `CreateMyTagSetRequest` posts the browser's fields in order to the shown set's page, once; `MyTagsClient.createTagSet` exists in live, noop, unimplemented and failing.
- N-5: exactly one new id is chosen (kept with the cache) and read through `fetchTagSet`; `#msg`, no new id and a failed request show Couldn't Create Tag Set on the row and choose nothing.
- N-6: the new set reaches `tagSets` through the read, with `applying(_:)`'s code and its contract for other callers unchanged (documented and tested).
- N-7: no rename, no delete, Add to My Tags elsewhere untouched; iPad uses the same page.
- N-8: the reducer, request and model tests listed in the tasks pass in parallel.
- N-9: the SUMMARY lists the owner's device check.
- Three signed `+08:00` commits, 0 warnings, lint clean, full FeatureTests plan green (VisualSnapshotTests skipped).
</success_criteria>

<output>
Create `.planning/quick/261126-pfh-add-a-new-tag-set-action-to-the-native-m/261126-pfh-SUMMARY.md` when done (not
committed). Record: the three commit hashes and subjects with their `%G? %aI %cI`; each test run (log name, targets,
TEST SUCCEEDED or the RED compile error, failed-case count, the new test names seen as passed); the gate outputs; and,
for the orchestrator:

- **Owner's device check (N-9)**, not done by the executor because it needs the owner's signed-in account and changes
  it on the site: on iPhone (Setting tab) and on iPad (Settings sheet), open Account, My Tags; the tag set section ends
  with New Tag Set; it opens the alert with the keyboard up and the Name field focused; Create stays disabled until a
  name is typed (spaces alone keep it disabled); Create shows the loading view, then the new set is selected in the
  picker under the name the site gives it, Enabled and the colour as the site set them, and its tags section shows No
  Tags Yet with Add Tag; the set appears on the site's own My Tags page. Also worth noting there: which page the site
  answered the create with, and any limit it reports.
- The planner's choices P-1 to P-11, one line each, with P-6 (more than one new id) called out as a case CONTEXT does
  not cover.
- That `appAlert` has no component test of its kind (settled fact 7), so the option is pinned through the My Tags
  alert test.
</output>
