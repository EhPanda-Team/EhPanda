---
phase: 261126-wzg-my-tags-editor-suggestions-color-weight
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/AppModels/Tags/SiteTagSuggestion.swift
  - AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift
  - AppPackage/Tests/AppModelsTests/SiteTagSuggestionTests.swift
  - AppPackage/Tests/ParserFeatureTests/Other/TagSuggestParserTests.swift
  - AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift
  - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
  - AppPackage/Tests/NetworkingFeatureTests/TagSuggestRequestTests.swift
  - AppPackage/Sources/AppComponents/TagSuggestionView.swift
  - AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings
  - AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift
  - AppPackage/Sources/MyTagEditor/MyTagEditorView.swift
  - AppPackage/Sources/MyTagEditor/HexColorField.swift
  - AppPackage/Sources/MyTagEditor/Resources/Localizable.xcstrings
  - AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift
  - AppPackage/Tests/AppFeatureTests/TagNameSuggestionTests.swift
autonomous: true
requirements: [G-1, G-2, G-3, G-4]

estimate:
  tokens: 220000
  raw_tokens: 220000
  tasks: 5
  confidence: low

must_haves:
  truths:
    - "In Add Tag, once at least two characters follow the namespace, the editor asks the site's api.php `tagsuggest` 200 ms after the text last changed, with the text as the site's tag completer sends it (quotes removed, a loose namespace such as `f:` written out); a change of the text cancels the question on its way, and fewer than two characters ask nothing and show no site rows (G-1)."
    - "The site's suggestions show as rows under the tag field whatever Show Tag Suggestions says, in the site's order, narrowed to the entries whose `namespace:tag` holds the field's text at the start of a word; with Translate Tags on, the local translations' matches the site did not list follow them and every row shows its translated name; with it off, the site's rows show alone by their own names (G-1)."
    - "A row the site found through an alias shows the alias's canonical tag with a third line `my_tags.alias` naming the alias; a tap on any row fills the field with that row's `namespace:tag`, the canonical tag for an alias (G-1)."
    - "A failed question (no connection, the site's `error`, an expired session) shows no site rows and no alert (G-1)."
    - "While the hex field's text is neither empty nor a code, the Color section's footer is `my_tags.hex_invalid` in red, the well keeps the last valid colour and confirm is disabled, in Add Tag and in Edit Tag; submitting it restores the last valid code; empty or valid text shows the existing footers (G-2)."
    - "Weight is a trailing number field (prompt 0, `.numbersAndPunctuation`, at most three characters, accessibility label Weight) beside the Stepper over -99...99: a typed number moves the Stepper at once, clamped; submit or leaving the field writes the clamped weight back, and an empty or unreadable text returns to the last weight; the Stepper's changes show in the field; the Stepper's halves stop at the range's ends (G-3)."
    - "The suggestion, colour and weight reducer tests, the model, parser and request tests and the row-merge test listed in the tasks pass in parallel; `my_tags.alias` (AppComponents) and `my_tags.hex_invalid` (MyTagEditor) carry CONTEXT's values in all six locales (G-4, Copy)."
  artifacts:
    - path: "AppPackage/Sources/AppModels/Tags/SiteTagSuggestion.swift"
      provides: "The site's suggestion entries, the query the site's completer sends, and its word-start filter"
      contains: "public struct TagSuggestQuery: Equatable, Hashable, Sendable"
    - path: "AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift"
      provides: "The tagsuggest answer, read from the object and from the empty array"
      contains: "public static func parseTagSuggestions(data: Data) throws(AppError) -> [SiteTagSuggestion]"
    - path: "AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift"
      provides: "The suggestion request in its own file"
      contains: "public struct TagSuggestRequest: Request"
    - path: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      provides: "suggestTags in live, noop, unimplemented and failing"
      contains: "public var suggestTags: @Sendable ("
    - path: "AppPackage/Sources/AppComponents/TagSuggestionView.swift"
      provides: "The form placement for one tag: site rows, merged translation matches, the alias line"
      contains: "struct TagNameSuggestion: Identifiable"
    - path: "AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift"
      provides: "The debounced question, the colour text check and the weight text"
      contains: ".cancellable(id: CancelID.suggestions, cancelInFlight: true)"
    - path: "AppPackage/Sources/MyTagEditor/MyTagEditorView.swift"
      provides: "The suggestions under the field, the red footer, the weight field beside the Stepper"
      contains: ".keyboardType(.numbersAndPunctuation)"
    - path: "AppPackage/Sources/MyTagEditor/HexColorField.swift"
      provides: "A host-kept text and the invalid-code test"
      contains: "public nonisolated static func isInvalidCode(_ text: String) -> Bool"
  key_links:
    - from: "AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift"
      to: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      via: "the debounced effect asks myTagsClient.suggestTags(host, query)"
      pattern: "try await myTagsClient\\.suggestTags\\(host, query\\)"
    - from: "AppPackage/Sources/MyTagsClient/MyTagsClient.swift"
      to: "AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift"
      via: "live suggestTags builds TagSuggestRequest"
      pattern: "TagSuggestRequest\\(host: host, query: query\\)"
    - from: "AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift"
      to: "AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift"
      via: "the answer is parsed by Parser.parseTagSuggestions"
      pattern: "parseResponse\\(data: data, Parser\\.parseTagSuggestions\\)"
    - from: "AppPackage/Sources/MyTagEditor/MyTagEditorView.swift"
      to: "AppPackage/Sources/AppComponents/TagSuggestionView.swift"
      via: "the tag field's rows come from the site's filtered answer and the translations when Translate Tags is on"
      pattern: "siteSuggestions: store\\.siteSuggestions"
    - from: "AppPackage/Sources/MyTagEditor/MyTagEditorView.swift"
      to: "AppPackage/Sources/MyTagEditor/HexColorField.swift"
      via: "the editor keeps the hex field's text so its footer and confirm can read it"
      pattern: "text: \\$store\\.colorText"
---

## Blocking questions

None. G-1 to G-4 and the copy table are planned as written. Two readings are recorded as planner's choices for the
orchestrator to see: P-8 (Show Tag Suggestions no longer gates anything in this field, and the local matches follow
Translate Tags) and P-12 (a typed number moves the Stepper at once; submit or leaving the field only rewrites the
text).

<objective>
Close the Add Tag and Edit Tag gaps exactly as CONTEXT's locked decisions G-1 to G-4 and its copy table say, in five
signed commits on top of `develop` once quick 261126-udx has landed (nothing pushed):

1. The model of the site's tag suggestions, the query its tag completer sends, and the parser of its answer (G-1).
2. `TagSuggestRequest` in its own file and `MyTagsClient.suggestTags` (G-1).
3. Add Tag lists the site's suggestions under the field, debounced and cancelled as the site does, merged with the
   local translation matches under Translate Tags, with the alias line and its insert (G-1, copy `my_tags.alias`).
4. The red footer and the confirm gate for an invalid colour code (G-2, copy `my_tags.hex_invalid`).
5. The weight field beside the Stepper (G-3).

Every task carries its tests (G-4).

Purpose: the editor offers what the site's own tag field offers, so the native My Tags page can replace the site's.
Output: five signed `+08:00` commits; `261126-wzg-SUMMARY.md` (not committed) listing the owner's device checks.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/261126-wzg-my-tags-editor-suggestions-color-weight/261126-wzg-CONTEXT.md
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

- Quick 261126-udx has landed: `git log --format=%s -50 | grep -cxF -e 'tags: read whether a tag set can be deleted'
  -e 'tags: ask the site to delete a tag set' -e 'settings: add Delete Tag Set to My Tags'` prints `3`, and
  `grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'deleteTagSet:'` prints `5`.
- `git status --short` prints nothing but untracked (`??`) paths under
  `.planning/quick/261126-wzg-my-tags-editor-suggestions-color-weight/` (or nothing at all once the orchestrator has
  committed them). No `ScratchMyTagsRenderTests.swift` exists under `AppPackage/Tests/`.
- `grep -rn 'SiteTagSuggestion\|TagSuggestQuery\|TagSuggestRequest\|suggestTags' AppPackage | wc -l` prints `0`, and
  `grep -rn 'my_tags.alias\|my_tags.hex_invalid' AppPackage | wc -l` prints `0`.
- `python3 -I Scripts/lint/app_storage_isolation.py check` prints `0 break(s) of the app-storage isolation rule.`
- Record `git rev-parse --short HEAD` as BASE in the SUMMARY; the final invariant gate diffs against it.

### Where and how you work

- This checkout, branch `develop` (HEAD `eabe37ace` when this plan was written, plus quick 261126-udx's commits and
  the orchestrator's planning commits). New commits go on top; no new branch, no rebase, no amend, no push, nothing on
  GitHub, no bare `git stash`. Never commit this PLAN, the SUMMARY, STATE.md or anything under
  `.planning/quick/261126-wzg-my-tags-editor-suggestions-color-weight/` (the orchestrator commits planning artifacts).
- Read `AGENTS.local.md` before the first commit and follow it; never copy its content into any artifact.
- Read the root `.swiftlint.yml` before writing Swift. No `swiftlint:disable` of any kind, no rule changes, no
  `.serialized`.
- `MyTagsClient.swift` is the one file quick 261126-udx also changed: this plan only adds to it (S6), anchored on the
  text udx leaves. Nothing under `AppPackage/Sources/SettingFeature/` changes; `MyTagsView` keeps calling
  `HexColorField` through the initializer it uses today.
- Logs and scratch files go under `.capture/261126-wzg/` (gitignored). The SUMMARY carries no absolute home paths
  (write `$HOME/...`) and names no other local project.
- Code comments use decision IDs (G-1 to G-4) and the quick task id, never agent names.
- Every Swift and Python block under "Shapes" is copied exactly as written, at the indentation written. An edit
  shape gives whole lines: "Replace" swaps exactly the first block for the second; "Directly below" and "Directly
  above" insert the second block next to the first block, which stays as it is. A note under a block says when it
  starts or ends with a blank line.
- The executor writes no copy: the two strings come from CONTEXT's table through the script in S8, unchanged.

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
  `mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never <-only-testing:Target ...> 2>&1 | tee .capture/261126-wzg/<log>.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'`
  It passes when it prints `** TEST SUCCEEDED **` and `grep -cE "Test case '.*' failed" .capture/261126-wzg/<log>.log`
  prints `0`. Xcode 27.2 prints no `Test run with N tests` line; the per-case
  `Test case '<Suite>/<name>(<labels>)' passed on ...` lines are the evidence (a parameterized test prints one line
  per argument).
- A RED run (the task's tests written, its code not yet) uses the same form with its own log name; it must print
  `** TEST FAILED **` with a compile error that names the symbol the task gives.
- Warnings: `grep -E ': warning: ' .capture/261126-wzg/<log>.log | sort -u` must print nothing. A warning in a file
  this plan does not touch: stop and report it (do not fix it).
- Lint, from the repository root, on the task's trees:
  `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet <trees>`
  must print nothing and exit 0.
- Known flake: if the only failure of the final full run is
  `FavoritesFeatureTests/LoginReturnObservationTests/cookieLoginTriggersReloadWithoutAViewCallback`, re-run
  `-only-testing:FavoritesFeatureTests` once; it must pass; record both runs in the SUMMARY.
- No test reaches the network: the request tests run through the token-isolated `URLProtocol` session of
  `NetworkingFeatureTests/Support`, and the reducer tests replace `myTagsClient` and the clock.

### Settled facts (checked by the planner against the tree at `eabe37ace`; do not re-derive)

1. **The JSON API path.** `UpdateMyTagRequest` (`Request+MyTags.swift`) already posts JSON to
   `Defaults.URL.api(host:)` through `encodeJSONObject(_:)`, `fetch(_:in:)` (default attempts),
   `parseResponse(data:_:)` and `mapAppError(error:)`, all on the `Request` protocol in `Request.swift`. `Defaults`
   comes from AppTools, so the new request file imports it as `Request+MyTags.swift` does.
2. **The site's completer** (`tagcompleter` in the site's `ehg_mytags.c.js`, read 2026-11-26): it removes `"` and `'`,
   rewrites the namespace with `^(x|mix).*:`, `^(mis).*:`, `^(co).*:`, `^(lo).*:` and then single letters in the
   order t, f, m, r, l, p, c, g, a, o (case-sensitive, `.*:` running to the last colon), asks only when
   `text.replace(/^.*:/, "")` has at least two characters, waits 200 ms, and lists the entries for which
   `(^| |:)<text>` matches `ns:tn` case-insensitively, walking the answer object in key order. An integer-keyed
   object is walked in ascending key order by every browser.
3. **Translations.** `TagTranslator.translations` is keyed by `namespace.rawValue + key` with no colon;
   `TagTranslation.getSuggestion(keyword:originalKeyword:matchesNamespace:)` gives the weight and the key and value
   ranges the row highlights. `TagSuggestion` has an init whose range arguments default to nil.
4. **One user of the tag-name mode.** The form mode of `TagSuggestionView` (its third `Source` case) is used only by
   `MyTagEditorView`; the search field and multi-line uses pass `keyword:` and keep their behaviour.
5. **One builder of the client.** `MyTagsClient` is built only in `MyTagsClient.swift` (`live`, `noop`,
   `unimplemented`, `failing(_:)`); `noop` is the preview value and `unimplemented` the test value.
6. **HexColorField** lives in MyTagEditor and is also used by `SettingFeature/MyTags/MyTagsView.swift` (tag set
   default colour) through `init(_:color:well:prompt:)`, whose signature this plan keeps.
7. **App-storage isolation.** Reader modules include AppComponents and MyTagEditor; AppModels, ParserFeature and
   NetworkingFeature are not reader modules. So `TagNameSuggestionTests` (imports AppComponents) carries
   `@Suite(.isolatedAppStorage)` and imports TestingSupport, `MyTagEditorTests` keeps its trait, and the model,
   parser and request suites carry no trait (the gate also fails a trait where none is needed).
8. **Copy symbols.** Keys of a module's `Resources/Localizable.xcstrings` generate internal `LocalizedStringResource`
   members: `my_tags.alias` (with `%@`) becomes `.myTagsAlias(_ arg1: String)` in AppComponents, and
   `my_tags.hex_invalid` becomes `.myTagsHexInvalid` in MyTagEditor. No catalog has either key. Both catalogs are in
   Xcode's canonical form with sorted keys; the S8 script was dry-run on copies: each key adds 41 lines and deletes
   none, and `check` prints `ok`.
9. **Lint names.** SwiftLint's `inclusive_language` rejects a declaration containing "master" and `type_name`
   rejects a two-letter type, so the site's master tag (`mid`, `mns`, `mtn`) is `canonical` here and the row id type
   is `RowID`. The planner ran `swiftlint lint --strict` on every final file of this plan with the root config: clean.
10. **Existing reducer tests.** `addingSendsTheTagTakesThePageAndCloses` sends `.binding(\.name)`, which from Task 3
    starts the debounce on the store's `TestClock`; confirm cancels it before the clock moves, so that test needs no
    change for Task 3. The two tests that set `weight` through a binding gain the field's text in Task 5 (S18b,
    S18c).
11. **Pointer hover audit.** `AppToolsTests/PointerHoverAuditTests` counts plain and unhighlighted buttons, tap
    gestures and custom button styles per file. `TagSuggestionView` keeps its one unhighlighted button with its hover
    helper; the editor adds a `TextField` and keeps the `Stepper`, neither of which the audit counts.
12. **Type-checked shapes.** The planner type-checked every Swift shape as the tree stands after each of the five
    tasks against the modules built in DerivedData, and ran the app-storage gate on a copy of the tree with all of
    them: `0 break(s)`.

### Planner's choices where CONTEXT leaves them open (each is final for the executor)

- **P-1 Task shape.** Five layered tasks, one green commit each, instead of a tracer: the request path (a JSON post to
  `api.php` through `Request`) is the one `UpdateMyTagRequest` already proves, and the orchestrator asked for one
  commit per piece (request, editor suggestions, colour, weight).
- **P-2 Where things live.** The model in a new `AppModels/Tags/SiteTagSuggestion.swift`, the parser in a new
  `Parser+TagSuggest.swift`, the request in its own `Request+TagSuggest.swift` (G-1), none of them in the My Tags
  files udx changes. The call joins `MyTagsClient`, the editor's existing dependency, rather than a new client: one
  dependency for every My Tags call.
- **P-3 The query.** `TagSuggestQuery.init?(_:)` follows settled fact 2: quotes removed, the namespace before the last
  colon rewritten case-sensitively in the site's order, nil while fewer than two characters follow the last colon
  (counted as Swift characters; JavaScript counts UTF-16 units, which differs only for characters outside the Basic
  Multilingual Plane). `text` is what is sent and filtered by, `term` what the rows highlight.
- **P-4 The answer.** Entries in ascending id order; an entry whose namespace the app does not know, whose name is
  empty or whose key is no integer is left out, and so is an alias whose canonical tag is such; `mid: null` is no
  alias; `login` throws `loginRequired`, `error` throws `unknown`, anything else without the tags `parseFailed`. Every
  failure shows nothing (G-1). Reads keep `fetch`'s default four attempts.
- **P-5 Which entries show.** The state keeps the site's whole last answer; the rows are its entries whose
  `namespace:tag` holds the current query text at a word start (start, space or colon), case-insensitively and
  literally (the site builds a regular expression from the text; the app matches the text as written). So the rows
  narrow while the next answer is on its way, as the site's list does. The answer is cleared below the threshold, on a
  failure, on a choice and on confirm.
- **P-6 Repeated text.** A change that leads to the same query text asks again after the wait (the site skips it); the
  rows stay meanwhile, so nothing flickers.
- **P-7 Merge without duplicates (G-1 asks the planner to state it).** The site's rows first, in the site's order;
  then the local translation matches in the order `TagTranslationHandler` gives them today, leaving out every match
  whose `namespace:tag` a site row already puts in the field. An alias row and the row of its canonical tag both stay,
  as on the site. A site row shows the translated name when the translations hold the tag it inserts, else its own
  name. At most ten rows show, under one count header, as today.
- **P-8 Settings.** The site's rows show whatever Show Tag Suggestions says (G-1). The local matches and translated
  names show only with Translate Tags on (the view passes no translations otherwise), so Show Tag Suggestions no longer
  gates anything in this field. Show Images in Tags still decides the row images.
- **P-9 Choosing.** A tap fills the field with the row's `namespace:tag` (the canonical tag for an alias), clears the
  site's rows and cancels a question on its way; the field's new text is not asked about until it changes again. The
  local matches re-read the new text as they do today.
- **P-10 Debounce.** A `.run` effect sleeps 200 ms on `continuousClock`, then asks; it is cancellable by one id with
  `cancelInFlight`, so a change restarts the wait and drops a question on its way. Below the threshold the id is
  cancelled. Tests drive a `TestClock`.
- **P-11 Colour.** The reducer keeps the hex field's text (`colorText`); `HexColorField` gains an initializer taking
  the text from its host and keeps its self-kept one for the My Tags page. Invalid means: not empty after trimming
  spaces, and not a code after trimming spaces. Spaces around a code are now ignored while typing too (submit already
  ignored them), which also applies to the My Tags page's default colour field. The footer is a `ColorFooter` value
  computed in state, so the tests read it.
- **P-12 Weight.** The reducer keeps the field's text (`weightText`). A readable number moves `weight` at once,
  clamped into -99...99, so the Stepper follows while typing; more than three characters are cut to three; submit and
  leaving the field write `weight` back into the text, so 150 shows 99 and an empty or unreadable text shows the last
  weight. The field is 48 pt at the body size and scales with it: 3 em, with the 16 pt em that `HexColorField`'s
  120 pt for 7.5 em uses. It sits 12 pt before the Stepper inside `LabeledContent`, which stacks at accessibility
  sizes.
- **P-13 Names.** `canonical` and `RowID` (settled fact 9); `SiteTag`, `SiteTagSuggestion`, `TagSuggestQuery`,
  `TagSuggestRequest`, `suggestTags`, `TagNameSuggestion`.
- **P-14 Copy inserted by script.** S8 reads the two rows from CONTEXT's table and writes them; nobody retypes copy.

### Source coverage

| Source item | Where |
|---|---|
| G-1 from the 2nd character after the namespace, the site's rewrite, quotes removed | Task 1 (S1, S3), Task 3 (S10f, S12c) |
| G-1 rows under the field in the form placement, whatever Show Tag Suggestions says | Task 3 (S9b, S11a, P-8) |
| G-1 debounced 200 ms, cancelled when the text changes | Task 3 (S10f, S12c, P-10) |
| G-1 a failed request shows no rows and no alert | Task 1 (S2, S4), Task 2 (S7), Task 3 (S10h, S12c) |
| G-1 Translate Tags adds the local matches and translated names; merge without duplicates | Task 3 (S9b, S9e, S19, P-7) |
| G-1 alias row: canonical tag, third line `my_tags.alias`, a tap inserts the canonical tag | Task 1 (S1), Task 3 (S9c, S9d, S9e, S10h, S12c, S19) |
| G-1 a chosen suggestion fills the field | Task 3 (S10h, S11a) |
| G-1 request in its own file, parser test of the object and the empty array, synthetic ids | Task 1 (S2, S4), Task 2 (S5, S7) |
| G-2 red footer, well keeps the last valid colour, confirm disabled, submit restores, empty and valid keep the footers | Task 4 (S13, S14, S15, S20) |
| G-3 number field, prompt 0, `.numbersAndPunctuation`, three characters, label Weight, -99...99, clamp, return, sync, Stepper ends | Task 5 (S16, S17, S18) |
| G-4 feature tests (debounce, cancel, alias insert, threshold, rewrite, failure, footer and confirm, weight parse, clamp, sync); request and parser tests | Tasks 1 to 5 |
| Copy `my_tags.alias`, `my_tags.hex_invalid`, six locales, module-local catalogs | Task 3 and Task 4 (S8) |
| Design "Add Tag and Edit Tag": weight field 3 em with tabular digits, alias third line, no Preview section | Task 3 (S9d), Task 5 (S17b) |
| Owner's device checks (the live site needs the owner's account) | Output |

### Shapes (copy exactly)

#### S1: `AppPackage/Sources/AppModels/Tags/SiteTagSuggestion.swift` (Task 1, new file)

The whole file:

```swift
import Foundation

// The site's tag suggestions (G-1 of quick 261126-wzg): what the tag completer of its My Tags page (`tagcompleter` in
// `ehg_mytags.c.js`, read 2026-11-26) asks the API's `tagsuggest` for, and which entries of the answer it lists.

/// A tag as the site names it: its namespace and its name.
public struct SiteTag: Equatable, Hashable, Sendable {
    public let namespace: TagNamespace
    public let name: String

    public init(namespace: TagNamespace, name: String) {
        self.namespace = namespace
        self.name = name
    }

    /// `namespace:name`, the form the site's tag field takes.
    public var fullName: String {
        namespace.rawValue + ":" + name
    }
}

/// One entry of the site's answer to `tagsuggest`: a tag, or an alias, which the site files under its canonical tag.
public struct SiteTagSuggestion: Equatable, Hashable, Identifiable, Sendable {
    /// The site's id of the suggested tag, an alias's own for an alias; the answer is keyed by it.
    public let id: Int
    /// The suggested tag; for an alias, the alias.
    public let tag: SiteTag
    /// The canonical tag an alias stands for (the answer's `mid`, `mns` and `mtn`); nil when the entry is no alias.
    public let canonical: SiteTag?

    public init(id: Int, tag: SiteTag, canonical: SiteTag?) {
        self.id = id
        self.tag = tag
        self.canonical = canonical
    }

    /// The tag choosing the entry puts in the field: an alias's canonical tag, as the site's list inserts it, else the
    /// tag itself.
    public var insertedTag: SiteTag {
        canonical ?? tag
    }

    /// Whether the site's list shows the entry for `query`: the entry's own `namespace:name` holds the query's text at
    /// the start of a word (its start, or after a space or a colon), in any case, as the list's `(^| |:)<text>` test
    /// does. The text is matched as written, where the site's list would read it as a pattern.
    public func matches(_ query: TagSuggestQuery) -> Bool {
        let name = " " + tag.fullName
        return name.range(of: " " + query.text, options: .caseInsensitive) != nil
            || name.range(of: ":" + query.text, options: .caseInsensitive) != nil
    }
}

/// What the site's tag completer sends for the text of its tag field, if anything: the text without its quotes, a
/// loose namespace written out (`f:` as `female:`), and nothing while fewer than two characters follow the namespace.
public struct TagSuggestQuery: Equatable, Hashable, Sendable {
    /// The loose namespaces the completer writes out, in the order it tries them: when the text's namespace (what comes
    /// before its last colon) starts with a prefix, the first such prefix's namespace replaces it. The prefixes are
    /// lower case only, as the site's are.
    private static let looseNamespaces: [(prefix: String, namespace: TagNamespace)] = [
        ("x", .mixed), ("mix", .mixed), ("mis", .temp), ("co", .cosplayer), ("lo", .location),
        ("t", .temp), ("f", .female), ("m", .male), ("r", .reclass), ("l", .language),
        ("p", .parody), ("c", .character), ("g", .group), ("a", .artist), ("o", .other)
    ]

    /// The text sent: the field's text without its quotes, a loose namespace written out.
    public let text: String
    /// What follows the namespace in `text`, after its last colon (all of it when it has none); two characters or
    /// more.
    public let term: String

    /// The query for `fieldText`; nil when fewer than two characters follow the namespace.
    public init?(_ fieldText: String) {
        var text = fieldText.filter({ $0 != "\"" && $0 != "'" })
        if let colon = text.lastIndex(of: ":"),
           let loose = Self.looseNamespaces.first(where: { text[..<colon].hasPrefix($0.prefix) }) {
            text = loose.namespace.rawValue + text[colon...]
        }
        let term = text.lastIndex(of: ":").map({ String(text[text.index(after: $0)...]) }) ?? text
        guard term.count >= 2 else { return nil }
        self.text = text
        self.term = term
    }
}
```

#### S2: `AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift` (Task 1, new file)

The whole file:

```swift
public import AppModels
public import Foundation

extension Parser {
    /// The API's answer to `tagsuggest` (G-1 and G-4 of quick 261126-wzg): every entry the tag field could take, in
    /// ascending id order, the order the site's list shows them in (the answer is an object keyed by id, which a
    /// browser walks by ascending integer key). With no match the site answers an empty array instead of an object.
    /// An entry with a namespace the app does not know, an empty name or a key that is no id is left out, and so is
    /// an alias whose canonical tag is such; a `mid` of null is no alias. `login` (an expired session) throws
    /// `loginRequired`, `error` (a refusal) `unknown`, and any other answer without the tags `parseFailed`.
    public static func parseTagSuggestions(data: Data) throws(AppError) -> [SiteTagSuggestion] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw .parseFailed
        }
        guard let answer = object as? [String: Any] else { throw .parseFailed }
        if answer["login"] != nil {
            throw .loginRequired
        }
        if answer["error"] != nil {
            throw .unknown
        }
        if let tags = answer["tags"] as? [Any] {
            guard tags.isEmpty else { throw .parseFailed }
            return []
        }
        guard let tags = answer["tags"] as? [String: Any] else { throw .parseFailed }
        return tags
            .compactMap({ siteTagSuggestion(id: $0.key, entry: $0.value) })
            .sorted(by: { $0.id < $1.id })
    }

    private static func siteTagSuggestion(id: String, entry: Any) -> SiteTagSuggestion? {
        guard let id = Int(id),
              let entry = entry as? [String: Any],
              let tag = siteTag(namespace: entry["ns"], name: entry["tn"])
        else { return nil }
        guard let mid = entry["mid"], !(mid is NSNull) else {
            return SiteTagSuggestion(id: id, tag: tag, canonical: nil)
        }
        guard let canonical = siteTag(namespace: entry["mns"], name: entry["mtn"]) else { return nil }
        return SiteTagSuggestion(id: id, tag: tag, canonical: canonical)
    }

    private static func siteTag(namespace: Any?, name: Any?) -> SiteTag? {
        guard let namespace = (namespace as? String).flatMap(TagNamespace.init(rawValue:)),
              let name = name as? String, !name.isEmpty
        else { return nil }
        return SiteTag(namespace: namespace, name: name)
    }
}
```

#### S3: `AppPackage/Tests/AppModelsTests/SiteTagSuggestionTests.swift` (Task 1, new file)

The whole file:

```swift
import AppModels
import Testing

// The site's tag completer as the app follows it (G-1 and G-4 of quick 261126-wzg; `tagcompleter` in the site's
// `ehg_mytags.c.js`, read 2026-11-26): the text it sends, when it sends nothing, which entries of the answer its list
// keeps, and what choosing one inserts. The tags are invented.
struct SiteTagSuggestionTests {
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )

    @Test(arguments: [
        ("x:sample", "mixed:sample"),
        ("mix:sample", "mixed:sample"),
        ("mixed:sample", "mixed:sample"),
        ("mis:sample", "temp:sample"),
        ("misc:sample", "temp:sample"),
        ("co:sample", "cosplayer:sample"),
        ("cos:sample", "cosplayer:sample"),
        ("lo:sample", "location:sample"),
        ("t:sample", "temp:sample"),
        ("f:sample", "female:sample"),
        ("m:sample", "male:sample"),
        ("r:sample", "reclass:sample"),
        ("l:sample", "language:sample"),
        ("lang:sample", "language:sample"),
        ("p:sample", "parody:sample"),
        ("c:sample", "character:sample"),
        ("char:sample", "character:sample"),
        ("g:sample", "group:sample"),
        ("a:sample", "artist:sample"),
        ("o:sample", "other:sample")
    ])
    func aLooseNamespaceIsWrittenOut(typed: String, sent: String) {
        #expect(TagSuggestQuery(typed)?.text == sent)
    }

    // No namespace, an upper-case or unknown one, or a space before it is sent as typed; quotes are removed; the
    // namespace runs to the last colon.
    @Test(arguments: [
        ("sample gl", "sample gl"),
        ("F:sample", "F:sample"),
        ("zz:sample", "zz:sample"),
        (" f:sample", " f:sample"),
        (#""f:sample gl""#, "female:sample gl"),
        ("f:x:sample", "female:sample")
    ])
    func otherTextsAreSentAsTheSiteSendsThem(typed: String, sent: String) {
        #expect(TagSuggestQuery(typed)?.text == sent)
    }

    @Test
    func theTermIsWhatFollowsTheNamespace() {
        #expect(TagSuggestQuery("f:sample gl")?.term == "sample gl")
        #expect(TagSuggestQuery("sample gl")?.term == "sample gl")
    }

    @Test(arguments: ["", "s", "female:", "female:s", "f:s", #""s""#])
    func fewerThanTwoCharactersAfterTheNamespaceAskNothing(typed: String) {
        #expect(TagSuggestQuery(typed) == nil)
    }

    // The site's list keeps an entry whose own `namespace:tag` holds the text at the start of a word, in any case.
    @Test(arguments: ["female:sample gl", "f:sample gl", "FEMALE:SAMPLE", "sample gl", "glass", "fem"])
    func anEntryMatchesTheTextAtAWordStart(typed: String) throws {
        #expect(Self.glasses.matches(try #require(TagSuggestQuery(typed))))
    }

    @Test(arguments: ["male:sample", "ample", "lasses", "female:gl", "sample  gl"])
    func anEntryDoesNotMatchTheTextInsideAWord(typed: String) throws {
        #expect(!Self.glasses.matches(try #require(TagSuggestQuery(typed))))
    }

    // An alias is matched by its own name and inserts its canonical tag; a tag inserts itself.
    @Test
    func anAliasInsertsItsCanonicalTag() throws {
        let alias = SiteTagSuggestion(
            id: 9002,
            tag: SiteTag(namespace: .female, name: "sample glass frames"),
            canonical: SiteTag(namespace: .female, name: "sample spectacles")
        )

        #expect(alias.matches(try #require(TagSuggestQuery("sample gl"))))
        #expect(!alias.matches(try #require(TagSuggestQuery("sample sp"))))
        #expect(alias.insertedTag.fullName == "female:sample spectacles")
        #expect(Self.glasses.insertedTag.fullName == "female:sample glasses")
    }
}
```

#### S4: `AppPackage/Tests/ParserFeatureTests/Other/TagSuggestParserTests.swift` (Task 1, new file)

The whole file:

```swift
import AppModels
import Foundation
import ParserFeature
import Testing

/// The API's answers to `tagsuggest` in the shapes probed on 2026-11-26 (G-1 and G-4 of quick 261126-wzg), with
/// invented ids and tags.
struct TagSuggestParserTests {
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )

    // The probed object: a tag, and an alias whose canonical tag a choice inserts; the entries come in ascending id
    // order.
    @Test
    func anAnswerReadsItsTagsAndAliasesInIdOrder() throws {
        let answer = #"{"tags":{"9102":{"ns":"female","tn":"sample glass frames","mid":9101,"mns":"female","#
            + #""mtn":"sample spectacles"},"9001":{"ns":"female","tn":"sample glasses"}}}"#

        #expect(try Parser.parseTagSuggestions(data: Data(answer.utf8)) == [
            Self.glasses,
            SiteTagSuggestion(
                id: 9102,
                tag: SiteTag(namespace: .female, name: "sample glass frames"),
                canonical: SiteTag(namespace: .female, name: "sample spectacles")
            )
        ])
    }

    // With no match the site answers an empty array, as PHP writes an empty map.
    @Test
    func anAnswerWithoutAMatchIsAnEmptyArray() throws {
        #expect(try Parser.parseTagSuggestions(data: Data(#"{"tags":[]}"#.utf8)).isEmpty)
    }

    // An entry the field could not take is left out and the rest kept: a namespace the app does not know (for an
    // alias, its canonical tag's too), an empty name, a key that is no id. A `mid` of null is no alias, as on the site.
    @Test
    func anEntryTheFieldCouldNotTakeIsLeftOut() throws {
        let answer = #"{"tags":{"9001":{"ns":"female","tn":"sample glasses"},"9002":{"ns":"sample","tn":"sample"},"#
            + #""9003":{"ns":"female","tn":"sample lens","mid":9004,"mns":"sample","mtn":"sample"},"#
            + #""9005":{"ns":"female","tn":""},"9006":{"ns":"female","tn":"sample frame","mid":null},"#
            + #""x":{"ns":"female","tn":"sample keyless"}}}"#

        #expect(try Parser.parseTagSuggestions(data: Data(answer.utf8)) == [
            Self.glasses,
            SiteTagSuggestion(id: 9006, tag: SiteTag(namespace: .female, name: "sample frame"), canonical: nil)
        ])
    }

    // `login` is an expired session, `error` a refusal; anything else without the tags fails as a parse failure.
    @Test(arguments: [
        (#"{"login":"sample"}"#, AppError.loginRequired),
        (#"{"error":"Sample refusal"}"#, AppError.unknown),
        ("{}", AppError.parseFailed),
        ("[]", AppError.parseFailed),
        (#"{"tags":[{"ns":"female","tn":"sample glasses"}]}"#, AppError.parseFailed),
        (#"{"tags":"sample"}"#, AppError.parseFailed),
        ("<html></html>", AppError.parseFailed)
    ])
    func anAnswerWithoutTheTagsFails(answer: String, error: AppError) {
        #expect(throws: error) {
            try Parser.parseTagSuggestions(data: Data(answer.utf8))
        }
    }
}
```

#### S5: `AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift` (Task 2, new file)

The whole file:

```swift
public import AppModels
import AppTools
public import Foundation
import ParserFeature

/// The site's tag suggestions for a tag being typed (G-1 of quick 261126-wzg), as the tag completer of its My Tags
/// page asks the API for them: `tagsuggest` with the query's text and nothing else, which the site answers signed in
/// or not. Answers every entry, in the order the site's list shows them; which of them the list keeps for the text is
/// `SiteTagSuggestion.matches(_:)`.
///
/// A read: it keeps `fetch`'s default attempts. The editor cancels it with its effect when the text changes.
public struct TagSuggestRequest: Request {
    public init(
        host: GalleryHost,
        query: TagSuggestQuery,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.query = query
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let query: TagSuggestQuery
    public let urlSession: URLSession

    public func response() async throws(AppError) -> [SiteTagSuggestion] {
        var request = URLRequest(url: Defaults.URL.api(host: host))
        request.httpMethod = "POST"
        request.httpBody = try encodeJSONObject(["method": "tagsuggest", "text": query.text])

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            return try parseResponse(data: data, Parser.parseTagSuggestions)
        } catch {
            throw mapAppError(error: error)
        }
    }
}
```

#### S6: `AppPackage/Sources/MyTagsClient/MyTagsClient.swift` (Task 2; anchored on the file as quick 261126-udx leaves it)

Eight edits, in this order. Each anchor is text udx's S9 wrote or left; if one is not found exactly once, stop and ask.

**S6a.** Replace:

```swift
/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, and the
/// create and the delete of a tag set (port of PR 462 item 10; the create, quick 261126-pfh; the delete, quick
/// 261126-udx).
```

with:

```swift
/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, the
/// create and the delete of a tag set, and the site's tag suggestions (port of PR 462 item 10; the create, quick
/// 261126-pfh; the delete, quick 261126-udx; the suggestions, quick 261126-wzg).
```

**S6b.** Replace:

```swift
        _ tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
}
```

with:

```swift
        _ tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
    /// The site's suggestions for the tag being typed, as its own tag field asks for them (`TagSuggestRequest`).
    public var suggestTags: @Sendable (
        _ host: GalleryHost,
        _ query: TagSuggestQuery
    ) async throws(AppError) -> [SiteTagSuggestion]
}
```

**S6c.** Replace:

```swift
        deleteTagSet: requestDeleteTagSet
    )
```

with:

```swift
        deleteTagSet: requestDeleteTagSet,
        suggestTags: requestSuggestTags
    )
```

**S6d.** Directly below these lines:

```swift
        try await DeleteMyTagSetRequest(host: host, tagSet: tagSet).response()
    }
```

insert:

```swift

    private static func requestSuggestTags(
        host: GalleryHost,
        query: TagSuggestQuery
    ) async throws(AppError) -> [SiteTagSuggestion] {
        try await TagSuggestRequest(host: host, query: query).response()
    }
```

(The inserted block starts with a blank line.)

**S6e.** Replace:

```swift
    /// Answers the fetch with no tag sets, so no tag carries a symbol and no tag menu item shows, and fails every
    /// other call as not found, since a page has no empty answer.
```

with:

```swift
    /// Answers the fetch with no tag sets, so no tag carries a symbol and no tag menu item shows, and the tag
    /// suggestions with none; fails every other call as not found, since a page has no empty answer.
```

**S6f.** Replace:

```swift
        deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        }
    )
```

with:

```swift
        deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        suggestTags: { (_: GalleryHost, _: TagSuggestQuery) async throws(AppError) -> [SiteTagSuggestion] in
            []
        }
    )
```

**S6g.** Replace:

```swift
        deleteTagSet: IssueReporting.unimplemented(
            "MyTagsClient.deleteTagSet", throwing: AppError.unknown
        )
    )
```

with:

```swift
        deleteTagSet: IssueReporting.unimplemented(
            "MyTagsClient.deleteTagSet", throwing: AppError.unknown
        ),
        suggestTags: IssueReporting.unimplemented(
            "MyTagsClient.suggestTags", throwing: AppError.unknown
        )
    )
```

**S6h.** Replace:

```swift
            deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            }
        )
```

with:

```swift
            deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            },
            suggestTags: { (_: GalleryHost, _: TagSuggestQuery) async throws(AppError) -> [SiteTagSuggestion] in
                throw error
            }
        )
```

#### S7: `AppPackage/Tests/NetworkingFeatureTests/TagSuggestRequestTests.swift` (Task 2, new file)

The whole file:

```swift
import AppModels
import Foundation
import NetworkingFeature
import Testing

// The tag suggestion request (G-1 and G-4 of quick 261126-wzg) through a token-isolated URLProtocol session, so it
// never opens a socket and never reaches the site. The answers are in the shapes probed on 2026-11-26, with invented
// ids and tags.
struct TagSuggestRequestTests {
    private static let ehentaiAPIURL = URL(string: "https://e-hentai.org/api.php")
    private static let exhentaiAPIURL = URL(string: "https://exhentai.org/api.php")
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )

    // The question is the method and the query's text, nothing else, posted as JSON to the selected host's API.
    @Test(arguments: [GalleryHost.ehentai, .exhentai])
    func aQuestionPostsTheQuerysTextToTheHostsAPI(host: GalleryHost) async throws {
        let url = try #require(host == .ehentai ? Self.ehentaiAPIURL : Self.exhentaiAPIURL)
        let answer = Data(#"{"tags":{"9001":{"ns":"female","tn":"sample glasses"}}}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: answer)]]))
        defer { cleanUp(session: session, handle: handle) }
        let query = try #require(TagSuggestQuery("f:sample gl"))

        let suggestions = try await suggest(query, host: host, session: session).get()

        #expect(suggestions == [Self.glasses])
        #expect(handle.receivedRequests.count == 1)
        let request = try #require(handle.receivedRequests.first)
        #expect(request.httpMethod == "POST")
        expectEquivalentURL(request.url, url)
        let body = try #require(request.httpBody)
        #expect(try JSONDecoder().decode([String: String].self, from: body) == [
            "method": "tagsuggest", "text": "female:sample gl"
        ])
    }

    @Test
    func anAnswerWithoutAMatchIsNoSuggestion() async throws {
        let url = try #require(Self.ehentaiAPIURL)
        let answer = Data(#"{"tags":[]}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: answer)]]))
        defer { cleanUp(session: session, handle: handle) }
        let query = try #require(TagSuggestQuery("sample gl"))

        let suggestions = try await suggest(query, host: .ehentai, session: session).get()

        #expect(suggestions.isEmpty)
    }

    // A refusal fails the question; the editor shows no rows for a failure, and no alert.
    @Test
    func aRefusalFailsTheQuestion() async throws {
        let url = try #require(Self.ehentaiAPIURL)
        let answer = Data(#"{"error":"Sample refusal"}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: answer)]]))
        defer { cleanUp(session: session, handle: handle) }
        let query = try #require(TagSuggestQuery("sample gl"))

        let result = await suggest(query, host: .ehentai, session: session)

        #expect(result == .failure(.unknown))
    }

    private func suggest(
        _ query: TagSuggestQuery,
        host: GalleryHost,
        session: URLSession
    ) async -> Result<[SiteTagSuggestion], AppError> {
        await capture { () async throws(AppError) -> [SiteTagSuggestion] in
            try await TagSuggestRequest(host: host, query: query, urlSession: session).response()
        }
    }

    private func cleanUp(session: URLSession, handle: StubHandle) {
        session.invalidateAndCancel()
        handle.tearDown()
    }
}
```

#### S8: `.capture/261126-wzg/insert_copy.py` (Task 3, used again in Task 4; gitignored, never committed)

The whole file:

```python
"""Inserts or checks one copy key of quick 261126-wzg, taken verbatim from CONTEXT's copy table.

    python3 -I .capture/261126-wzg/insert_copy.py insert <key>
    python3 -I .capture/261126-wzg/insert_copy.py check <key>

Run from the repository root. `insert` writes the key into its module's catalog in Xcode's canonical form (keys
sorted, two-space indent, " : " separators, no trailing newline) and then checks it; `check` prints `ok` when the
catalog holds exactly CONTEXT's six values for the key and not the other key.
"""
import json
import sys
from pathlib import Path

CONTEXT = Path(".planning/quick/261126-wzg-my-tags-editor-suggestions-color-weight/261126-wzg-CONTEXT.md")
CATALOGS = {
    "my_tags.alias": Path("AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings"),
    "my_tags.hex_invalid": Path("AppPackage/Sources/MyTagEditor/Resources/Localizable.xcstrings"),
}
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
    assert sorted(rows) == sorted(CATALOGS), list(rows)
    for locale, value in rows["my_tags.alias"].items():
        assert value.count("%") == 1 and value.count("%@") == 1, locale
    for locale, value in rows["my_tags.hex_invalid"].items():
        assert "%" not in value and "#1F3A93" in value, locale
    return rows


def entry(values):
    localizations = {}
    for locale in sorted(values):
        localizations[locale] = {"stringUnit": {"state": "translated", "value": values[locale]}}
    return {"extractionState": "manual", "localizations": localizations}


def load(path):
    text = path.read_text(encoding="utf-8")
    catalog = json.loads(text)
    assert canonical(catalog) == text, f"{path} is not in Xcode's canonical form"
    assert list(catalog["strings"]) == sorted(catalog["strings"]), f"{path} keys are not sorted"
    return catalog


def insert(key):
    path = CATALOGS[key]
    catalog = load(path)
    rows = copy_table()
    strings = dict(catalog["strings"])
    assert key not in strings, f"{key} is already in {path}"
    strings[key] = entry(rows[key])
    catalog["strings"] = {name: strings[name] for name in sorted(strings)}
    path.write_text(canonical(catalog), encoding="utf-8")
    check(key)


def check(key):
    strings = load(CATALOGS[key])["strings"]
    rows = copy_table()
    assert strings[key] == entry(rows[key]), key
    for other in CATALOGS:
        if other != key:
            assert other not in strings, f"{other} must not be in {CATALOGS[key]}"
    print("ok")


if __name__ == "__main__":
    {"insert": insert, "check": check}[sys.argv[1]](sys.argv[2])
```

#### S9: `AppPackage/Sources/AppComponents/TagSuggestionView.swift` (Task 3)

**S9a.** Replace:

```swift
/// Tag suggestions for a `searchSuggestions` closure.
```

with:

```swift
/// Tag suggestions for a `searchSuggestions` closure, or for one tag typed in a form.
```

**S9b.** Replace:

```swift
        case multilineField
        /// One tag in a form (My Tags' Add Tag): the text is never rewritten while typing, and a chosen suggestion
        /// replaces it with the tag as the site keeps it, `namespace:tag` (design approved 2026-11-22).
        case tagName
    }

    @Environment(\.searchSuggestionsPlacement) private var searchSuggestionsPlacement
    @Binding private var keyword: String
    private let translations: [String: TagTranslation]
    private let showsImages: Bool
    private let isEnabled: Bool
    private let source: Source

    @State private var translationHandler = TagTranslationHandler()

    public init(
        keyword: Binding<String>, translations: [String: TagTranslation], showsImages: Bool, isEnabled: Bool,
        source: Source = .searchField
    ) {
        _keyword = keyword
        self.translations = translations
        self.showsImages = showsImages
        self.isEnabled = isEnabled
        self.source = source
    }

    public var body: some View {
        if isEnabled {
            if searchSuggestionsPlacement != .menu, source == .searchField || !translationHandler.suggestions.isEmpty {
                Text(.matchesCount(count: translationHandler.suggestions.count))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            let suggestions = translationHandler.suggestions
            ForEach(suggestions.prefix(min(suggestions.count, 10))) { suggestion in
                SuggestionCell(
                    suggestion: suggestion,
                    showsImages: showsImages,
                    action: { complete(with: suggestion) }
                )
            }
            .onChange(of: keyword) {
                switch source {
                case .searchField:
                    translationHandler.analyze(text: &keyword, translations: translations)
                case .multilineField, .tagName:
                    translationHandler.analyze(readingText: keyword, translations: translations)
                }
            }
        }
    }

    private func complete(with suggestion: TagSuggestion) {
        switch source {
        case .searchField, .multilineField:
            translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword)
        case .tagName:
            keyword = "\(suggestion.tag.namespace.rawValue):\(suggestion.tag.key)"
        }
    }
}
```

with:

```swift
        case multilineField
    }

    /// What the rows complete.
    private enum Completion {
        /// A keyword, completed in place; nothing shows while `isEnabled` is off.
        case keyword(Binding<String>, source: Source, isEnabled: Bool)
        /// One tag in a form, which the host fills with the `namespace:tag` of the chosen row.
        case tag(String, siteSuggestions: [SiteTagSuggestion], choose: (String) -> Void)
    }

    @Environment(\.searchSuggestionsPlacement) private var searchSuggestionsPlacement
    private let completion: Completion
    private let translations: [String: TagTranslation]
    private let showsImages: Bool

    @State private var translationHandler = TagTranslationHandler()

    public init(
        keyword: Binding<String>, translations: [String: TagTranslation], showsImages: Bool, isEnabled: Bool,
        source: Source = .searchField
    ) {
        completion = .keyword(keyword, source: source, isEnabled: isEnabled)
        self.translations = translations
        self.showsImages = showsImages
    }

    /// One tag typed in a form, My Tags' Add Tag (design approved 2026-11-22; G-1 of quick 261126-wzg): the site's
    /// suggestions for `tag` first, as the host has them, then the matches in `translations` the site did not
    /// suggest, every row by its translated name when `translations` has one. Without translations the site's rows
    /// show alone, by their own names. `tag` is never rewritten while typing, and a chosen row hands `choose` the
    /// `namespace:tag` it puts in the field: for an alias, its canonical tag.
    public init(
        tag: String,
        siteSuggestions: [SiteTagSuggestion],
        translations: [String: TagTranslation],
        showsImages: Bool,
        choose: @escaping (String) -> Void
    ) {
        completion = .tag(tag, siteSuggestions: siteSuggestions, choose: choose)
        self.translations = translations
        self.showsImages = showsImages
    }

    public var body: some View {
        switch completion {
        case .keyword(let keyword, let source, let isEnabled):
            if isEnabled {
                keywordRows(keyword: keyword, source: source)
            }
        case .tag(let tag, let siteSuggestions, let choose):
            tagRows(tag: tag, siteSuggestions: siteSuggestions, choose: choose)
        }
    }

    @ViewBuilder
    private func keywordRows(keyword: Binding<String>, source: Source) -> some View {
        if searchSuggestionsPlacement != .menu, source == .searchField || !translationHandler.suggestions.isEmpty {
            Text(.matchesCount(count: translationHandler.suggestions.count))
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }

        let suggestions = translationHandler.suggestions
        ForEach(suggestions.prefix(min(suggestions.count, 10))) { suggestion in
            SuggestionCell(
                suggestion: suggestion,
                alias: nil,
                showsImages: showsImages,
                action: { translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword.wrappedValue) }
            )
        }
        .onChange(of: keyword.wrappedValue) {
            switch source {
            case .searchField:
                translationHandler.analyze(text: &keyword.wrappedValue, translations: translations)
            case .multilineField:
                translationHandler.analyze(readingText: keyword.wrappedValue, translations: translations)
            }
        }
    }

    @ViewBuilder
    private func tagRows(
        tag: String,
        siteSuggestions: [SiteTagSuggestion],
        choose: @escaping (String) -> Void
    ) -> some View {
        let rows = TagNameSuggestion.rows(
            site: siteSuggestions,
            translationMatches: translationHandler.suggestions,
            tag: tag,
            translations: translations
        )
        if searchSuggestionsPlacement != .menu, !rows.isEmpty {
            Text(.matchesCount(count: rows.count))
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }

        ForEach(rows.prefix(10)) { row in
            SuggestionCell(
                suggestion: row.suggestion,
                alias: row.alias,
                showsImages: showsImages,
                action: { choose(row.insertedName) }
            )
        }
        .onChange(of: tag) { _, newTag in
            translationHandler.analyze(readingText: newTag, translations: translations)
        }
    }
}
```

**S9c.** Replace:

```swift
    private let suggestion: TagSuggestion
    private let showsImages: Bool
    private let action: () -> Void

    init(suggestion: TagSuggestion, showsImages: Bool, action: @escaping () -> Void) {
        self.suggestion = suggestion
        self.showsImages = showsImages
```

with:

```swift
    private let suggestion: TagSuggestion
    /// The alias the site found the tag through, as `namespace:tag`, named on a third line (G-1 of quick 261126-wzg).
    /// Only a form's tag rows have one, and they never show in a search field's menu.
    private let alias: String?
    private let showsImages: Bool
    private let action: () -> Void

    init(suggestion: TagSuggestion, alias: String?, showsImages: Bool, action: @escaping () -> Void) {
        self.suggestion = suggestion
        self.alias = alias
        self.showsImages = showsImages
```

**S9d.** Replace:

```swift
                        Text(suggestion.displayKey.localizedKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
```

with:

```swift
                        Text(suggestion.displayKey.localizedKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let alias {
                            Text(.myTagsAlias(alias))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
```

**S9e.** Directly above these lines:

```swift
// MARK: TagTranslationHandler
```

insert:

```swift
// MARK: TagNameSuggestion
/// A row of the suggestions for one tag typed in a form (G-1 of quick 261126-wzg): one of the site's, or a match of
/// the local translations the site did not list.
struct TagNameSuggestion: Identifiable {
    enum RowID: Hashable {
        /// One of the site's, by the site's id of the suggested tag.
        case site(Int)
        /// A translation's match, by its `namespace:tag`.
        case translation(String)
    }

    let id: RowID
    /// What the row shows: the tag it puts in the field, by its translated name when the translations have one, with
    /// what the field's text matches in it highlighted.
    let suggestion: TagSuggestion
    /// The alias the site found the tag through, as `namespace:tag`; nil for a row that is no alias.
    let alias: String?
    /// The `namespace:tag` choosing the row puts in the field.
    let insertedName: String

    /// The site's suggestions in the site's order, then the translation matches in theirs, leaving out a match whose
    /// tag a site row already puts in the field. The site's rows stay as the site lists them, so an alias row and the
    /// row of its canonical tag both show, as on the site.
    static func rows(
        site: [SiteTagSuggestion],
        translationMatches: [TagSuggestion],
        tag: String,
        translations: [String: TagTranslation]
    ) -> [TagNameSuggestion] {
        let query = TagSuggestQuery(tag)
        let siteRows = site.map { suggestion in
            let inserted = suggestion.insertedTag
            let translation = translations[inserted.namespace.rawValue + inserted.name]
                ?? TagTranslation(namespace: inserted.namespace, key: inserted.name, value: "")
            return TagNameSuggestion(
                id: .site(suggestion.id),
                suggestion: translation.getSuggestion(
                    keyword: query?.term ?? "",
                    originalKeyword: tag,
                    matchesNamespace: query?.text.hasPrefix(inserted.namespace.rawValue + ":") == true
                ),
                alias: suggestion.canonical == nil ? nil : suggestion.tag.fullName,
                insertedName: inserted.fullName
            )
        }
        let siteNames = Set(siteRows.map(\.insertedName))
        let translationRows = translationMatches.compactMap { match -> TagNameSuggestion? in
            let name = match.tag.namespace.rawValue + ":" + match.tag.key
            guard !siteNames.contains(name) else { return nil }
            return TagNameSuggestion(id: .translation(name), suggestion: match, alias: nil, insertedName: name)
        }
        return siteRows + translationRows
    }
}

```

(The inserted block ends with a blank line.)

#### S10: `AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift` (Task 3)

**S10a.** Replace:

```swift
/// outcome (`Delegate`). Close discards the changes without asking.
@Reducer
```

with:

```swift
/// outcome (`Delegate`). Close discards the changes without asking.
///
/// Add Tag lists the site's suggestions for the typed tag, as the site's own tag field does: it asks 200 ms after the
/// text last changed, a change cancels the question on its way, and nothing is asked while fewer than two characters
/// follow the namespace; a failed question shows no rows and no alert (G-1 of quick 261126-wzg).
@Reducer
```

**S10b.** Replace:

```swift
        case removed
    }

    @ObservableState
```

with:

```swift
        case removed
    }

    private enum CancelID {
        case suggestions
    }

    @ObservableState
```

**S10c.** Replace:

```swift
        public var weight: Int

        /// Add Tag for `tagSet`: a new tag starts Normal (owner decision, 2026-11-26), without a colour of its own, at
```

with:

```swift
        public var weight: Int
        /// The site's last answer for the typed tag, every entry as the site gave it (G-1 of quick 261126-wzg). It
        /// stays while the next answer is on its way, so the rows narrow as the text grows, as the site's list does.
        public var siteSuggestionAnswer: [SiteTagSuggestion] = []

        /// Add Tag for `tagSet`: a new tag starts Normal (owner decision, 2026-11-26), without a colour of its own, at
```

**S10d.** Replace:

```swift
            set { color = SiteColor(newValue) }
        }

        var trimmedName: String {
```

with:

```swift
            set { color = SiteColor(newValue) }
        }

        /// The site's suggestions under the tag field: the entries of its last answer whose name holds the field's
        /// query at the start of a word, as the site's list keeps them; none while the query is too short (G-1 of
        /// quick 261126-wzg).
        public var siteSuggestions: [SiteTagSuggestion] {
            guard let query = TagSuggestQuery(name) else { return [] }
            return siteSuggestionAnswer.filter({ $0.matches(query) })
        }

        var trimmedName: String {
```

**S10e.** Replace:

```swift
        case removeDone(Result<MyTagsPage, AppError>)
        case delegate(Delegate)
    }

    @Dependency(\.dismiss) private var dismiss
```

with:

```swift
        case removeDone(Result<MyTagsPage, AppError>)
        case suggestDone(Result<[SiteTagSuggestion], AppError>)
        case suggestionChosen(String)
        case delegate(Delegate)
    }

    @Dependency(\.continuousClock) private var clock
    @Dependency(\.dismiss) private var dismiss
```

**S10f.** Replace:

```swift
            switch action {
            case .binding, .alert, .delegate:
```

with:

```swift
            switch action {
            case .binding(\.name):
                // The site's tag completer (G-1 of quick 261126-wzg): it asks 200 ms after the text last changed, a
                // change cancels the question on its way, and a text with fewer than two characters after the
                // namespace asks nothing and shows no rows.
                guard let query = TagSuggestQuery(state.name) else {
                    state.siteSuggestionAnswer = []
                    return .cancel(id: CancelID.suggestions)
                }
                let host = state.setting.galleryHost
                return .run { send in
                    try await clock.sleep(for: .milliseconds(200))
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.suggestTags(host, query)
                    }
                    await send(.suggestDone(result))
                }
                .cancellable(id: CancelID.suggestions, cancelInFlight: true)

            case .binding, .alert, .delegate:
```

**S10g.** Replace:

```swift
                    return .run { send in
                        let result = await Result.Swift::init { () async throws(AppError) in
                            try await myTagsClient.addTag(host, draft, tagSetID)
                        }
                        await send(.addDone(result))
                    }
```

with:

```swift
                    // The field is sent as it is, so its suggestions are no longer wanted (G-1 of quick 261126-wzg).
                    state.siteSuggestionAnswer = []
                    return .merge(
                        .cancel(id: CancelID.suggestions),
                        .run { send in
                            let result = await Result.Swift::init { () async throws(AppError) in
                                try await myTagsClient.addTag(host, draft, tagSetID)
                            }
                            await send(.addDone(result))
                        }
                    )
```

**S10h.** Replace:

```swift
                return presentAlert(&state, .remove, title: .RLocalizable.myTagsRemoveFailed, message: error.alertText)
            }
```

with:

```swift
                return presentAlert(&state, .remove, title: .RLocalizable.myTagsRemoveFailed, message: error.alertText)

            case .suggestDone(.success(let suggestions)):
                state.siteSuggestionAnswer = suggestions
                return .none

            case .suggestDone(.failure):
                // A failed question shows no rows and no alert (G-1 of quick 261126-wzg).
                state.siteSuggestionAnswer = []
                return .none

            case .suggestionChosen(let tag):
                // A chosen row fills the field, an alias's canonical tag for an alias; the site's rows go until the
                // text changes again (G-1 of quick 261126-wzg).
                state.name = tag
                state.siteSuggestionAnswer = []
                return .cancel(id: CancelID.suggestions)
            }
```

#### S11: `AppPackage/Sources/MyTagEditor/MyTagEditorView.swift` (Task 3)

**S11a.** Replace:

```swift
            if store.isNameEditable {
                TagSuggestionView(
                    keyword: $store.name,
                    translations: tagTranslator.translations,
                    showsImages: store.setting.showImagesInTags,
                    isEnabled: store.setting.showTagsSearchSuggestion,
                    source: .tagName
                )
            }
```

with:

```swift
            if store.isNameEditable {
                // The site's suggestions whatever Show Tag Suggestions says; with Translate Tags, the translations'
                // matches and names too (G-1 of quick 261126-wzg).
                TagSuggestionView(
                    tag: store.name,
                    siteSuggestions: store.siteSuggestions,
                    translations: store.setting.translateTags ? tagTranslator.translations : [:],
                    showsImages: store.setting.showImagesInTags,
                    choose: { store.send(.suggestionChosen($0)) }
                )
            }
```

#### S12: `AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift` (Task 3)

**S12a.** Replace:

```swift
// cache, the alert on the control that failed, and the outcome the host is told. The tags and sets are invented.
```

with:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions (quick
// 261126-wzg). The tags, sets and suggestions are invented.
```

**S12b.** Directly below these lines:

```swift
    private static let set2 = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: slate, tags: [])
```

insert:

```swift
    private static let sampleGlasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )
    private static let sampleFrames = SiteTagSuggestion(
        id: 9002,
        tag: SiteTag(namespace: .female, name: "sample glass frames"),
        canonical: SiteTag(namespace: .female, name: "sample spectacles")
    )
    private static let unsampleGlow = SiteTagSuggestion(
        id: 9003, tag: SiteTag(namespace: .other, name: "unsample glow"), canonical: nil
    )
```

**S12c.** Directly above these lines:

```swift
    @MainActor
    private func makeStore(
```

insert:

```swift
    // The site's tag completer asks 200 ms after the text last changed, and its list keeps the answer's entries whose
    // name holds the text at the start of a word (G-1, G-4 of quick 261126-wzg).
    @MainActor
    @Test
    func theSuggestionsAreAskedForOnceTheTextRestsAndListTheWordStartMatches() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (host: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append("\(host.rawValue) \(query.text)") })
                return [Self.sampleGlasses, Self.sampleFrames, Self.unsampleGlow]
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(199))
        #expect(calls.value.isEmpty)
        await clock.advance(by: .milliseconds(1))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses, Self.sampleFrames, Self.unsampleGlow]
        }
        #expect(calls.value == ["E-Hentai sample gl"])
        #expect(store.state.siteSuggestions == [Self.sampleGlasses, Self.sampleFrames])
    }

    // A change of the text cancels the question it replaces, and the wait starts again (G-1, G-4).
    @MainActor
    @Test
    func aChangedTextCancelsTheQuestionItReplaces() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return [Self.sampleGlasses, Self.sampleFrames]
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(150))
        await store.send(.binding(.set(\.name, "sample gla"))) {
            $0.name = "sample gla"
        }
        await clock.advance(by: .milliseconds(150))
        #expect(calls.value.isEmpty)
        await clock.advance(by: .milliseconds(50))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses, Self.sampleFrames]
        }
        #expect(calls.value == ["sample gla"])
    }

    // Nothing is asked while fewer than two characters follow the namespace, and going back under two clears the
    // rows (G-1, G-4).
    @MainActor
    @Test
    func fewerThanTwoCharactersAfterTheNamespaceAskNothing() async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return [Self.sampleGlasses]
            }
        }

        await store.send(.binding(.set(\.name, "s"))) {
            $0.name = "s"
        }
        await store.send(.binding(.set(\.name, "female:s"))) {
            $0.name = "female:s"
        }
        await clock.advance(by: .milliseconds(200))
        #expect(calls.value.isEmpty)
        await store.send(.binding(.set(\.name, "female:sa"))) {
            $0.name = "female:sa"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses]
        }
        #expect(store.state.siteSuggestions == [Self.sampleGlasses])
        await store.send(.binding(.set(\.name, "female:s"))) {
            $0.name = "female:s"
            $0.siteSuggestionAnswer = []
        }
        await clock.advance(by: .milliseconds(200))
        #expect(calls.value == ["female:sa"])
    }

    // The question carries the text as the site's completer sends it: a loose namespace written out, the quotes
    // removed (G-1, G-4).
    @MainActor
    @Test(arguments: [
        ("f:sample", "female:sample"),
        ("x:sample", "mixed:sample"),
        ("mis:sample", "temp:sample"),
        ("co:sample", "cosplayer:sample"),
        ("lo:sample", "location:sample"),
        ("lang:sample", "language:sample"),
        (#""a:sample""#, "artist:sample"),
        ("sample", "sample")
    ])
    func aLooseNamespaceIsWrittenOutBeforeTheQuestion(typed: String, sent: String) async {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return []
            }
        }

        await store.send(.binding(.set(\.name, typed))) {
            $0.name = typed
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success)
        #expect(calls.value == [sent])
    }

    // An alias's row puts its canonical tag in the field, and the site's rows go until the text changes again (G-1,
    // G-4).
    @MainActor
    @Test
    func choosingAnAliasPutsItsCanonicalTagInTheField() async throws {
        let calls = LockIsolated<[String]>([])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, query: TagSuggestQuery) async throws(AppError) in
                calls.withValue({ $0.append(query.text) })
                return [Self.sampleGlasses, Self.sampleFrames]
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses, Self.sampleFrames]
        }
        let alias = try #require(store.state.siteSuggestions.first(where: { $0.canonical != nil }))
        await store.send(.suggestionChosen(alias.insertedTag.fullName)) {
            $0.name = "female:sample spectacles"
            $0.siteSuggestionAnswer = []
        }
        await clock.advance(by: .milliseconds(200))
        #expect(calls.value == ["sample gl"])
        #expect(store.state.siteSuggestions.isEmpty)
        #expect(store.state.canConfirm)
    }

    // A failed question shows no rows and no alert (G-1, G-4).
    @MainActor
    @Test
    func aFailedQuestionShowsNoRowsAndNoAlert() async {
        let answers = LockIsolated<[Result<[SiteTagSuggestion], AppError>]>([
            .success([Self.sampleGlasses]), .failure(.networkingFailed)
        ])
        let clock = TestClock()
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) }, clock: clock) {
            $0.suggestTags = { (_: GalleryHost, _: TagSuggestQuery) async throws(AppError) in
                try answers.withValue({ $0.removeFirst() }).get()
            }
        }

        await store.send(.binding(.set(\.name, "sample gl"))) {
            $0.name = "sample gl"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.success) {
            $0.siteSuggestionAnswer = [Self.sampleGlasses]
        }
        await store.send(.binding(.set(\.name, "sample gla"))) {
            $0.name = "sample gla"
        }
        await clock.advance(by: .milliseconds(200))
        await store.receive(\.suggestDone.failure) {
            $0.siteSuggestionAnswer = []
        }
        #expect(store.state.siteSuggestions.isEmpty)
        #expect(store.state.alert == nil)
    }

```

(The inserted block ends with a blank line.)

**S12d.** Replace:

```swift
        dismissed: LockIsolated<Int>,
        client: (inout MyTagsClient) -> Void
```

with:

```swift
        dismissed: LockIsolated<Int> = LockIsolated(0),
        clock: any Clock<Duration> = TestClock(),
        client: (inout MyTagsClient) -> Void
```

**S12e.** Replace:

```swift
        return TestStore(initialState: initial, reducer: MyTagEditorFeature.init) {
            $0.dismiss = DismissEffect { dismissed.withValue({ $0 += 1 }) }
```

with:

```swift
        return TestStore(initialState: initial, reducer: MyTagEditorFeature.init) {
            $0.continuousClock = clock
            $0.dismiss = DismissEffect { dismissed.withValue({ $0 += 1 }) }
```

#### S13: `AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift` (Task 4)

**S13a.** Replace:

```swift
        case remove
    }

    @CasePathable
```

with:

```swift
        case remove
    }

    /// What the Color section's footer says.
    public enum ColorFooter: Equatable, Sendable {
        /// The hex field holds neither nothing nor a code; said in red (G-2 of quick 261126-wzg).
        case invalidCode
        /// The tag has a colour of its own.
        case ownColor
        /// The tag takes its set's default colour.
        case tagSetColor
        /// Neither the tag nor its set has a colour.
        case noColor
    }

    @CasePathable
```

**S13b.** Replace:

```swift
        public var color: SiteColor?
        public var weight: Int
```

with:

```swift
        public var color: SiteColor?
        /// The hex field's text, kept here so confirm can wait while it is not a code (G-2 of quick 261126-wzg).
        public var colorText: String
        public var weight: Int
```

**S13c.** Directly below these lines:

```swift
            self.color = nil
```

insert:

```swift
            self.colorText = ""
```

**S13d.** Directly below these lines:

```swift
            self.color = tag.color
```

insert:

```swift
            self.colorText = tag.color?.hex ?? ""
```

**S13e.** Replace:

```swift
        /// Add: the field holds a tag. Edit: something changed. Neither while a request is on its way.
        public var canConfirm: Bool {
            guard running == nil else { return false }
```

with:

```swift
        /// Add: the field holds a tag. Edit: something changed. Neither while a request is on its way, nor while the
        /// hex field holds an invalid code (G-2 of quick 261126-wzg).
        public var canConfirm: Bool {
            guard running == nil, !isColorTextInvalid else { return false }
```

**S13f.** Directly below these lines:

```swift
            set { color = SiteColor(newValue) }
        }

```

insert:

```swift
        /// Whether the hex field holds neither nothing nor a code (G-2 of quick 261126-wzg).
        public var isColorTextInvalid: Bool {
            HexColorField.isInvalidCode(colorText)
        }

        /// The Color section's footer: while the code is invalid, that it is (G-2 of quick 261126-wzg); else which
        /// colour applies.
        public var colorFooter: ColorFooter {
            if isColorTextInvalid {
                return .invalidCode
            }
            if color != nil {
                return .ownColor
            }
            return tagSetColor == nil ? .noColor : .tagSetColor
        }

```

(The inserted block ends with a blank line.)

#### S14: `AppPackage/Sources/MyTagEditor/MyTagEditorView.swift` (Task 4)

**S14a.** Replace:

```swift
            HexColorField(.myTagsColor, color: $store.color, well: $store.wellColor, prompt: store.tagSetColor?.hex)
```

with:

```swift
            HexColorField(
                .myTagsColor,
                text: $store.colorText,
                color: $store.color,
                well: $store.wellColor,
                prompt: store.tagSetColor?.hex
            )
```

**S14b.** Replace:

```swift
        } footer: {
            Text(colorFooter)
        }
    }

    private var colorFooter: LocalizedStringResource {
        if store.color != nil {
            return .myTagsColorFooterOwn
        }
        return store.tagSetColor == nil ? .myTagsColorFooterNone : .myTagsColorFooterTagSet
    }
```

with:

```swift
        } footer: {
            colorFooter
        }
    }

    /// Which colour applies, or, in red while the hex field holds an invalid code, that it does (G-2 of quick
    /// 261126-wzg).
    @ViewBuilder private var colorFooter: some View {
        switch store.colorFooter {
        case .invalidCode:
            Text(.myTagsHexInvalid)
                .foregroundStyle(.red)
        case .ownColor:
            Text(.myTagsColorFooterOwn)
        case .tagSetColor:
            Text(.myTagsColorFooterTagSet)
        case .noColor:
            Text(.myTagsColorFooterNone)
        }
    }
```

#### S15: `AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift` (Task 4)

**S15a.** Replace:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions (quick
// 261126-wzg). The tags, sets and suggestions are invented.
```

with:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions and the
// colour code's check (quick 261126-wzg). The tags, sets and suggestions are invented.
```

**S15b.** Directly below these lines:

```swift
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)
```

insert:

```swift
    private static let navy = SiteColor(red: 0x1F, green: 0x3A, blue: 0x93)
```

**S15c.** Directly above these lines:

```swift
    @MainActor
    private func makeStore(
```

insert:

```swift
    // Empty text, spaces alone, or six hex digits with or without `#` and spaces around them is no invalid code (G-2
    // of quick 261126-wzg).
    @Test(arguments: ["", "  ", "#1F3A93", "1f3a93", " #1F3A93 "])
    func anEmptyTextOrACodeIsNoInvalidCode(text: String) {
        #expect(!HexColorField.isInvalidCode(text))
    }

    @Test(arguments: ["#", "#1F3A9", "#1F3A930", "#GGGGGG", "1F 3A93"])
    func anythingElseIsAnInvalidCode(text: String) {
        #expect(HexColorField.isInvalidCode(text))
    }

    // While the hex field holds an invalid code, the Color footer says so and confirm waits; an empty or a valid
    // text shows the footer of the colour in use and lets confirm go (G-2, G-4).
    @MainActor
    @Test
    func anInvalidCodeTakesTheColorFooterAndHoldsConfirmBack() async {
        let store = makeStore(state: { MyTagEditorFeature.State(adding: "artist:sample artist", tagSet: Self.set2) })
        #expect(store.state.colorFooter == .tagSetColor)
        #expect(store.state.canConfirm)

        await store.send(.binding(.set(\.colorText, "#1F3A9"))) {
            $0.colorText = "#1F3A9"
        }
        #expect(store.state.colorFooter == .invalidCode)
        #expect(!store.state.canConfirm)

        // The field writes the colour of a valid code itself, as it does in the sheet.
        await store.send(.binding(.set(\.colorText, "#1F3A93"))) {
            $0.colorText = "#1F3A93"
        }
        await store.send(.binding(.set(\.color, Self.navy))) {
            $0.color = Self.navy
        }
        #expect(store.state.colorFooter == .ownColor)
        #expect(store.state.canConfirm)

        await store.send(.binding(.set(\.colorText, "  "))) {
            $0.colorText = "  "
        }
        #expect(store.state.colorFooter == .ownColor)
        #expect(store.state.canConfirm)
    }

    // An edit waits for a valid code too, whatever else changed; a tag's own colour starts in the field (G-2, G-4).
    @MainActor
    @Test
    func anEditWithAnInvalidCodeCannotBeConfirmed() async {
        var coloured = Self.glasses
        coloured.color = Self.slate
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: coloured, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            }
        )
        #expect(store.state.colorText == "#A0B0C0")
        #expect(store.state.colorFooter == .ownColor)

        await store.send(.binding(.set(\.kind, .hidden))) {
            $0.kind = .hidden
        }
        #expect(store.state.canConfirm)
        await store.send(.binding(.set(\.colorText, "zz"))) {
            $0.colorText = "zz"
        }
        #expect(store.state.colorFooter == .invalidCode)
        #expect(!store.state.canConfirm)
        await store.send(.confirmTapped)
        await store.send(.binding(.set(\.colorText, ""))) {
            $0.colorText = ""
        }
        #expect(store.state.canConfirm)
    }

```

(The inserted block ends with a blank line.)

**S15d.** Replace:

```swift
        client: (inout MyTagsClient) -> Void
    ) -> TestStoreOf<MyTagEditorFeature> {
```

with:

```swift
        client: (inout MyTagsClient) -> Void = { _ in }
    ) -> TestStoreOf<MyTagEditorFeature> {
```

#### S16: `AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift` (Task 5)

**S16a.** Replace:

```swift
        public var weight: Int
        /// The site's last answer for the typed tag, every entry as the site gave it (G-1 of quick 261126-wzg). It
```

with:

```swift
        public var weight: Int
        /// The weight field's text. A number typed moves `weight` at once, clamped into the site's range; submit or
        /// leaving the field writes `weight` back, so an empty or unreadable text returns to it (G-3 of quick
        /// 261126-wzg).
        public var weightText: String
        /// The site's last answer for the typed tag, every entry as the site gave it (G-1 of quick 261126-wzg). It
```

**S16b.** Directly below these lines:

```swift
            self.weight = MyTag.defaultWeight
```

insert:

```swift
            self.weightText = String(MyTag.defaultWeight)
```

**S16c.** Directly below these lines:

```swift
            self.weight = tag.weight
```

insert:

```swift
            self.weightText = String(tag.weight)
```

**S16d.** Directly below these lines:

```swift
        case suggestionChosen(String)
```

insert:

```swift
        case weightFieldCommitted
```

**S16e.** Replace:

```swift
                .cancellable(id: CancelID.suggestions, cancelInFlight: true)

            case .binding, .alert, .delegate:
```

with:

```swift
                .cancellable(id: CancelID.suggestions, cancelInFlight: true)

            case .binding(\.weightText):
                // Three characters at most, as the site's field takes; a number moves the Stepper at once, clamped
                // into the site's range (G-3 of quick 261126-wzg).
                if state.weightText.count > 3 {
                    state.weightText = String(state.weightText.prefix(3))
                }
                if let typed = Int(state.weightText) {
                    state.weight = min(max(typed, MyTag.weightRange.lowerBound), MyTag.weightRange.upperBound)
                }
                return .none

            case .binding(\.weight):
                // The field follows the Stepper (G-3 of quick 261126-wzg).
                state.weightText = String(state.weight)
                return .none

            case .binding, .alert, .delegate:
```

**S16f.** Replace:

```swift
                state.siteSuggestionAnswer = []
                return .cancel(id: CancelID.suggestions)
            }
```

with:

```swift
                state.siteSuggestionAnswer = []
                return .cancel(id: CancelID.suggestions)

            case .weightFieldCommitted:
                // Submit or leaving the weight field shows the weight in force: the typed number clamped, or the last
                // weight for an empty or unreadable text (G-3 of quick 261126-wzg).
                state.weightText = String(state.weight)
                return .none
            }
```

#### S17: `AppPackage/Sources/MyTagEditor/MyTagEditorView.swift` (Task 5)

**S17a.** Directly below these lines:

```swift
    @SharedReader(.tagTranslator) private var tagTranslator: TagTranslator
```

insert:

```swift
    /// The weight field: 3 em at the body size, scaling with it (G-3 of quick 261126-wzg).
    @ScaledMetric(relativeTo: .body) private var weightFieldWidth = 48.0
    @FocusState private var isWeightFieldFocused: Bool
```

**S17b.** Replace:

```swift
    private var weightSection: some View {
        Section {
            Stepper(value: $store.weight, in: MyTag.weightRange) {
                LabeledContent(.myTagsWeight) {
                    Text(store.weight, format: .number)
                        .monospacedDigit()
                }
            }
        } footer: {
```

with:

```swift
    /// A number field and the Stepper, 12 pt apart at the trailing side, following each other; the Stepper's halves
    /// stop at the ends of the site's range (G-3 of quick 261126-wzg).
    private var weightSection: some View {
        Section {
            LabeledContent(.myTagsWeight) {
                HStack(spacing: 12) {
                    TextField(text: $store.weightText, prompt: Text(0, format: .number)) {
                        Text(.myTagsWeight)
                    }
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .accessibilityLabel(.myTagsWeight)
                    .frame(width: weightFieldWidth)
                    .focused($isWeightFieldFocused)
                    .onSubmit {
                        store.send(.weightFieldCommitted)
                    }
                    .onChange(of: isWeightFieldFocused) {
                        guard !isWeightFieldFocused else { return }
                        store.send(.weightFieldCommitted)
                    }
                    Stepper(value: $store.weight, in: MyTag.weightRange) {
                        Text(.myTagsWeight)
                    }
                    .labelsHidden()
                    .accessibilityValue(store.weight.formatted())
                }
            }
        } footer: {
```

#### S18: `AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift` (Task 5)

**S18a.** Replace:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions and the
// colour code's check (quick 261126-wzg). The tags, sets and suggestions are invented.
```

with:

```swift
// cache, the alert on the control that failed, and the outcome the host is told; the site's suggestions, the colour
// code's check and the weight field (quick 261126-wzg). The tags, sets and suggestions are invented.
```

**S18b.** Directly below these lines:

```swift
        await store.send(.binding(.set(\.weight, -5))) {
            $0.weight = -5
```

insert:

```swift
            $0.weightText = "-5"
```

**S18c.** Directly below these lines:

```swift
        await store.send(.binding(.set(\.weight, 99))) {
            $0.weight = 99
```

insert:

```swift
            $0.weightText = "99"
```

**S18d.** Directly above these lines:

```swift
    @MainActor
    private func makeStore(
```

insert:

```swift
    // The weight field starts at the weight, and the field and the Stepper follow each other (G-3, G-4 of quick
    // 261126-wzg).
    @MainActor
    @Test
    func theWeightFieldAndTheStepperFollowEachOther() async {
        #expect(MyTagEditorFeature.State(tagSet: Self.set2).weightText == "10")
        let store = makeStore(
            state: {
                MyTagEditorFeature.State(
                    editing: Self.artist, tagSet: Self.set1, apiuid: 1234567, apikey: "0123456789abcdef"
                )
            }
        )
        #expect(store.state.weightText == "10")

        await store.send(.binding(.set(\.weight, 11))) {
            $0.weight = 11
            $0.weightText = "11"
        }
        await store.send(.binding(.set(\.weightText, "-5"))) {
            $0.weightText = "-5"
            $0.weight = -5
        }
        await store.send(.weightFieldCommitted)
    }

    // A typed number moves the Stepper clamped into −99…99 at once; submit or leaving the field writes the clamped
    // weight back; the field takes three characters at most (G-3, G-4).
    @MainActor
    @Test
    func aTypedWeightIsClampedIntoTheSitesRange() async {
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) })

        await store.send(.binding(.set(\.weightText, "150"))) {
            $0.weightText = "150"
            $0.weight = 99
        }
        await store.send(.weightFieldCommitted) {
            $0.weightText = "99"
        }
        await store.send(.binding(.set(\.weightText, "-123"))) {
            $0.weightText = "-12"
            $0.weight = -12
        }
        await store.send(.binding(.set(\.weightText, "-100"))) {
            $0.weightText = "-10"
            $0.weight = -10
        }
        await store.send(.binding(.set(\.weightText, "1234"))) {
            $0.weightText = "123"
            $0.weight = 99
        }
        await store.send(.weightFieldCommitted) {
            $0.weightText = "99"
        }
    }

    // An empty or unreadable weight leaves the Stepper where it was, and submit or leaving the field returns the text
    // to it (G-3, G-4).
    @MainActor
    @Test(arguments: ["", "-", "1-", "abc"])
    func anEmptyOrUnreadableWeightReturnsToTheLastOne(text: String) async {
        let store = makeStore(state: { MyTagEditorFeature.State(tagSet: Self.set2) })

        await store.send(.binding(.set(\.weightText, text))) {
            $0.weightText = text
        }
        await store.send(.weightFieldCommitted) {
            $0.weightText = "10"
        }
    }

```

(The inserted block ends with a blank line.)

#### S19: `AppPackage/Tests/AppFeatureTests/TagNameSuggestionTests.swift` (Task 3, new file)

The whole file:

```swift
@testable import AppComponents
import AppModels
import Testing
import TestingSupport

// The rows under My Tags' Add Tag field (G-1 of quick 261126-wzg): the site's suggestions first, in the site's order,
// then the local translations' matches the site did not list; an alias row puts its canonical tag in the field and
// names the alias. The tags and their translations are invented.
@Suite(.isolatedAppStorage)
struct TagNameSuggestionTests {
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )
    private static let frames = SiteTagSuggestion(
        id: 9002,
        tag: SiteTag(namespace: .female, name: "sample glass frames"),
        canonical: SiteTag(namespace: .female, name: "sample spectacles")
    )

    @Test
    func theSitesRowsComeFirstAndATranslationMatchTheyListIsLeftOut() {
        let listed = TagTranslation(namespace: .female, key: "sample glasses", value: "Translated Sample Glasses")
        let unlisted = TagTranslation(namespace: .female, key: "sample glassware", value: "Translated Sample Glassware")
        let matches = [
            TagSuggestion(tag: listed, weight: 2, originalKeyword: "sample gl", matchesNamespace: false),
            TagSuggestion(tag: unlisted, weight: 1, originalKeyword: "sample gl", matchesNamespace: false)
        ]

        let rows = TagNameSuggestion.rows(
            site: [Self.glasses, Self.frames],
            translationMatches: matches,
            tag: "sample gl",
            translations: ["femalesample glasses": listed, "femalesample glassware": unlisted]
        )

        #expect(rows.map(\.id) == [.site(9001), .site(9002), .translation("female:sample glassware")])
        #expect(rows.map(\.insertedName) == [
            "female:sample glasses", "female:sample spectacles", "female:sample glassware"
        ])
        #expect(rows.map(\.alias) == [nil, "female:sample glass frames", nil])
        #expect(rows.map(\.suggestion.tag) == [
            listed, TagTranslation(namespace: .female, key: "sample spectacles", value: ""), unlisted
        ])
    }

    // Without translations a site row shows the tag by its own name, the typed term and namespace highlighted.
    @Test
    func withoutTranslationsASiteRowShowsItsOwnName() throws {
        let rows = TagNameSuggestion.rows(
            site: [Self.glasses], translationMatches: [], tag: "f:sample gl", translations: [:]
        )

        let row = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(row.suggestion.tag == TagTranslation(namespace: .female, key: "sample glasses", value: ""))
        #expect(row.suggestion.keyRange != nil)
        #expect(row.suggestion.matchesNamespace)
        #expect(row.alias == nil)
    }
}
```

#### S20: `AppPackage/Sources/MyTagEditor/HexColorField.swift` (Task 4, replaces the file's content)

The whole file:

```swift
public import AppModels
public import SwiftUI

/// A colour as the site keeps it, for a tag and for a tag set's default: a hex field and the system colour well, 12
/// pt apart at the trailing side (port of PR 462 item 10, design approved 2026-11-22).
///
/// The field shows `color` as `#RRGGBB`, or nothing with `prompt` (else `#RRGGBB`) when there is none. It takes six
/// hex digits with or without `#`, in any case, spaces around them ignored: the well follows as soon as the text is a
/// valid code, and submit writes the code back in upper case; submitting an empty field clears the colour, and an
/// invalid code returns to the last valid one. Picking in the well (`well`, no opacity: the site keeps `#rrggbb`)
/// writes its colour.
///
/// The field keeps its text itself, unless the host passes it (`text`) to tell while it is not a code (G-2 of quick
/// 261126-wzg, `isInvalidCode(_:)`).
public struct HexColorField: View {
    @ScaledMetric(relativeTo: .body) private var fieldWidth = 120.0
    /// The text while the host does not keep it.
    @State private var ownText = ""
    /// The host's text, when the host keeps it.
    private let hostText: Binding<String>?
    @Binding private var color: SiteColor?
    @Binding private var well: Color
    private let title: LocalizedStringResource
    private let prompt: String?

    /// A field that keeps its text itself.
    public init(_ title: LocalizedStringResource, color: Binding<SiteColor?>, well: Binding<Color>, prompt: String?) {
        self.init(title, hostText: nil, color: color, well: well, prompt: prompt)
    }

    /// A field whose text the host keeps, so the host can tell while it is not a code (G-2 of quick 261126-wzg).
    public init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        color: Binding<SiteColor?>,
        well: Binding<Color>,
        prompt: String?
    ) {
        self.init(title, hostText: text, color: color, well: well, prompt: prompt)
    }

    private init(
        _ title: LocalizedStringResource,
        hostText: Binding<String>?,
        color: Binding<SiteColor?>,
        well: Binding<Color>,
        prompt: String?
    ) {
        self.title = title
        self.hostText = hostText
        _color = color
        _well = well
        self.prompt = prompt
    }

    /// Whether `text` is neither empty nor a code (G-2 of quick 261126-wzg). Spaces alone count as empty, as
    /// submitting them clears the colour.
    public nonisolated static func isInvalidCode(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && code(in: text) == nil
    }

    /// The colour `text` holds as a code, spaces around it ignored as submit ignores them; nil for anything else.
    private nonisolated static func code(in text: String) -> SiteColor? {
        SiteColor(hex: text.trimmingCharacters(in: .whitespaces))
    }

    /// The field's text: the host's when it keeps it, else the field's own.
    private var text: Binding<String> {
        hostText ?? $ownText
    }

    public var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                TextField(text: text, prompt: promptText) {
                    Text(.myTagsHexColor)
                }
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .accessibilityLabel(.myTagsHexColor)
                .frame(width: fieldWidth)
                .onSubmit {
                    submit()
                }
                ColorPicker(selection: $well, supportsOpacity: false) {
                    Text(title)
                }
                .labelsHidden()
            }
        } label: {
            Text(title)
        }
        // The field follows a colour set elsewhere (the well, Use Default Color), and leaves a code being typed alone.
        .onChange(of: color, initial: true) { _, newValue in
            if Self.code(in: text.wrappedValue) != newValue {
                text.wrappedValue = newValue?.hex ?? ""
            }
        }
        .onChange(of: text.wrappedValue) { _, newValue in
            if let typed = Self.code(in: newValue), typed != color {
                color = typed
            }
        }
    }

    private var promptText: Text {
        if let prompt {
            return Text(verbatim: prompt)
        }
        return Text(.myTagsHexPrompt)
    }

    private func submit() {
        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            color = nil
        } else if let typed = SiteColor(hex: trimmed) {
            color = typed
            text.wrappedValue = typed.hex
        } else {
            text.wrappedValue = color?.hex ?? ""
        }
    }
}
```
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: The site's tag suggestions: the query, the entries and the parser (G-1, G-4)</name>
  <files>AppPackage/Sources/AppModels/Tags/SiteTagSuggestion.swift, AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift, AppPackage/Tests/AppModelsTests/SiteTagSuggestionTests.swift, AppPackage/Tests/ParserFeatureTests/Other/TagSuggestParserTests.swift</files>
  <precondition>The Precondition section above holds (udx landed, clean tree apart from this quick task's directory).</precondition>
  <read_first>
    - .planning/quick/261126-wzg-my-tags-editor-suggestions-color-weight/261126-wzg-CONTEXT.md (Site contract, G-1)
    - AppPackage/Sources/AppModels/Tags/TagNamespace.swift and AppPackage/Sources/AppModels/Tags/MyTags.swift lines 1-50 (`SiteColor`, the file's style)
    - AppPackage/Sources/ParserFeature/Parser+MyTags.swift lines 1-20 (the parser files' imports and style)
    - AppPackage/Tests/ParserFeatureTests/Other/MyTagsParserTests.swift lines 1-20
    - .swiftlint.yml (custom rules)
  </read_first>
  <behavior>
    - `TagSuggestQuery` sends `x:`, `mix:`, `mixed:` as `mixed:`; `mis:`, `misc:`, `t:` as `temp:`; `co:`, `cos:` as `cosplayer:`; `lo:` as `location:`; `f:` female, `m:` male, `r:` reclass, `l:`, `lang:` language, `p:` parody, `c:`, `char:` character, `g:` group, `a:` artist, `o:` other (G-1).
    - It sends a text without namespace, an upper-case or unknown namespace, or one after a space as typed; it removes quotes; the namespace runs to the last colon; `term` is what follows it (G-1).
    - It is nil for "", "s", "female:", "female:s", "f:s" and a quoted "s" (G-1).
    - An entry matches a query whose text starts a word of its own `namespace:tag` in any case, and not one inside a word; an alias matches by its own name and inserts its canonical tag (G-1).
    - The parser reads the probed object in ascending id order with an alias's canonical tag, reads `{"tags":[]}` as no entries, leaves out entries it cannot take, reads `mid: null` as no alias, and fails `login` as `loginRequired`, `error` as `unknown` and every other shape as `parseFailed` (G-1, G-4).
  </behavior>
  <action>
Write the tests first (RED: `SiteTagSuggestion` and `TagSuggestQuery` do not exist, so AppModelsTests does not
compile; run `-only-testing:AppModelsTests` once with log `task1-red.log` to see it), then the code.

1. Tests (G-4; synthetic ids and tags only): create `AppPackage/Tests/AppModelsTests/SiteTagSuggestionTests.swift`
   with S3 and `AppPackage/Tests/ParserFeatureTests/Other/TagSuggestParserTests.swift` with S4. Neither suite carries
   the app-storage trait (settled fact 7).
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `SiteTagSuggestion`, `SiteTag`
   or `TagSuggestQuery`.
3. Model (G-1, P-3, P-5, P-13): create `AppPackage/Sources/AppModels/Tags/SiteTagSuggestion.swift` with S1.
4. Parser (G-1, P-4): create `AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift` with S2.
5. Run the verify lines, then commit.

Commit subject: `tags: read the site's tag suggestions`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:AppModelsTests 2>&1 | tee .capture/261126-wzg/task1-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 and 4; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzg/task1-red.log | grep -cE 'SiteTagSuggestion|SiteTag|TagSuggestQuery'   [EXPECT>=1]</automated>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:AppModelsTests -only-testing:ParserFeatureTests 2>&1 | tee .capture/261126-wzg/task1-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzg/task1-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzg/task1-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'SiteTagSuggestionTests/[A-Za-z]+" .capture/261126-wzg/task1-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=0 EXPECT==7]</automated>
    <automated>grep -cE "Test case 'SiteTagSuggestionTests/[^']*' passed" .capture/261126-wzg/task1-tests.log   [HEAD=0 EXPECT==45]</automated>
    <automated>grep -oE "Test case 'TagSuggestParserTests/[A-Za-z]+" .capture/261126-wzg/task1-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=0 EXPECT==4]</automated>
    <automated>grep -cE "Test case 'TagSuggestParserTests/[^']*' passed" .capture/261126-wzg/task1-tests.log   [HEAD=0 EXPECT==10]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/AppModels AppPackage/Sources/ParserFeature AppPackage/Tests/AppModelsTests AppPackage/Tests/ParserFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>python3 -I Scripts/lint/app_storage_isolation.py check   [HEAD: 0 break(s); EXPECT: 0 break(s) of the app-storage isolation rule.]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppModels/Tags/SiteTagSuggestion.swift | grep -cF 'public struct TagSuggestQuery: Equatable, Hashable, Sendable'   [HEAD: no such file; EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/ParserFeature/Parser+TagSuggest.swift | grep -cF '.sorted(by: { $0.id < $1.id })'   [HEAD: no such file; EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing model types; then AppModelsTests and ParserFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the seven model tests (45 cases) and four parser tests (10 cases) listed as passed; no warning, lint clean, isolation gate clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: read the site's tag suggestions` holding exactly the four files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: The suggestion request in its own file and MyTagsClient.suggestTags (G-1, G-4)</name>
  <files>AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift, AppPackage/Sources/MyTagsClient/MyTagsClient.swift, AppPackage/Tests/NetworkingFeatureTests/TagSuggestRequestTests.swift</files>
  <precondition>Task 1 is committed; `grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'deleteTagSet:'` prints 5.</precondition>
  <read_first>
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift (`UpdateMyTagRequest`, the JSON post this request follows)
    - AppPackage/Sources/NetworkingFeature/Request.swift lines 140-220 (`parseResponse`, `mapAppError`, `encodeJSONObject`)
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift (whole file, as udx left it)
    - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift lines 1-40 and 330-343, AppPackage/Tests/NetworkingFeatureTests/Support/RequestHarness.swift
  </read_first>
  <behavior>
    - The request posts exactly `{"method":"tagsuggest","text":"female:sample gl"}` for the typed `f:sample gl` to `https://e-hentai.org/api.php` or `https://exhentai.org/api.php`, by the host, and answers the parsed entries (G-1).
    - `{"tags":[]}` answers no entries; `{"error":...}` fails as `unknown` (G-1, G-4).
    - `MyTagsClient.suggestTags` exists in `live` (the request), `noop` (no entries), `unimplemented` and `failing(_:)`.
  </behavior>
  <action>
Write the test first (RED: `TagSuggestRequest` does not exist; run `-only-testing:NetworkingFeatureTests` once with log
`task2-red.log`), then the code.

1. Test (G-4): create `AppPackage/Tests/NetworkingFeatureTests/TagSuggestRequestTests.swift` with S7. It uses the
   existing stub session and `capture`, so it never opens a socket.
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `TagSuggestRequest`.
3. Request (G-1, P-2, P-4): create `AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift` with S5.
4. Client (P-2, settled fact 5): apply S6a to S6h to `MyTagsClient.swift`, each anchor found exactly once in the file
   as udx left it. Nothing else in the file changes.
5. Run the verify lines, then commit.

Commit subject: `tags: ask the site for tag suggestions`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:NetworkingFeatureTests 2>&1 | tee .capture/261126-wzg/task2-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 and 4; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzg/task2-red.log | grep -c 'TagSuggestRequest'   [EXPECT>=1]</automated>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:NetworkingFeatureTests -only-testing:DetailFeatureTests -only-testing:SettingFeatureTests -only-testing:DownloadsFeatureTests 2>&1 | tee .capture/261126-wzg/task2-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzg/task2-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzg/task2-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'TagSuggestRequestTests/[A-Za-z]+" .capture/261126-wzg/task2-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=0 EXPECT==3]</automated>
    <automated>grep -cE "Test case 'TagSuggestRequestTests/[^']*' passed" .capture/261126-wzg/task2-tests.log   [HEAD=0 EXPECT==4]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/NetworkingFeature AppPackage/Sources/MyTagsClient AppPackage/Tests/NetworkingFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/NetworkingFeature/Request+TagSuggest.swift | grep -cF 'encodeJSONObject(["method": "tagsuggest", "text": query.text])'   [HEAD: no such file; EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagsClient/MyTagsClient.swift | grep -c 'suggestTags:'   [HEAD (after udx)=0 EXPECT==5]</automated>
  </verify>
  <done>The RED run failed to compile on `TagSuggestRequest`; then NetworkingFeatureTests, DetailFeatureTests, SettingFeatureTests and DownloadsFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the three request tests (4 cases) listed as passed; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: ask the site for tag suggestions` holding exactly the three files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Add Tag lists the site's suggestions, merged with the translations, with the alias line (G-1, G-4)</name>
  <files>AppPackage/Sources/AppComponents/TagSuggestionView.swift, AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings, AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift, AppPackage/Sources/MyTagEditor/MyTagEditorView.swift, AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift, AppPackage/Tests/AppFeatureTests/TagNameSuggestionTests.swift</files>
  <precondition>Task 2 is committed.</precondition>
  <read_first>
    - AppPackage/Sources/AppComponents/TagSuggestionView.swift (whole file)
    - AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift and AppPackage/Sources/MyTagEditor/MyTagEditorView.swift (whole files)
    - AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift (whole file) and AppPackage/Tests/AppFeatureTests/TagSuggestionTokenizationTests.swift lines 1-20
    - AppPackage/Sources/AppModels/Tags/TagTranslation.swift (`getSuggestion`) and AppPackage/Sources/AppModels/Tags/TagSuggestion.swift
    - CLAUDE.md "Labeled localized-format arguments" and "Non-translated keys need every locale filled"
  </read_first>
  <behavior>
    - Typing "sample gl" asks nothing for 199 ms and asks `sample gl` on E-Hentai at 200 ms; the rows are the answer's word-start matches (`unsample glow` is left out) (G-1, G-4).
    - A change 150 ms into the wait cancels it; only the new text is asked, 200 ms after the change (G-1, G-4).
    - "s" and "female:s" ask nothing; "female:sa" asks; going back to "female:s" clears the rows and asks nothing more (G-1, G-4).
    - The question carries `female:`, `mixed:`, `temp:`, `cosplayer:`, `location:`, `language:`, `artist:` (quotes removed) and a bare text as typed (G-1, G-4).
    - Choosing an alias row puts its canonical tag `female:sample spectacles` in the field, clears the rows, asks nothing more, and confirm is enabled (G-1, G-4).
    - A failed question clears the rows and presents no alert (G-1, G-4).
    - The merged rows are the site's in its order, then the translation matches the site did not list; the alias row names the alias and inserts the canonical tag; without translations a site row shows its own name with the typed term and namespace highlighted (G-1, P-7).
  </behavior>
  <action>
Write the tests first (RED: the editor has no `suggestDone`, `siteSuggestionAnswer` or `siteSuggestions`, so
DetailFeatureTests does not compile; run `-only-testing:DetailFeatureTests` once with log `task3-red.log`), then the
code and the copy.

1. Tests (G-4): apply S12a to S12e to `MyTagEditorTests.swift`; create
   `AppPackage/Tests/AppFeatureTests/TagNameSuggestionTests.swift` with S19 (it carries `@Suite(.isolatedAppStorage)`
   and imports TestingSupport, settled fact 7).
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `suggestDone`,
   `siteSuggestionAnswer`, `siteSuggestions`, `suggestionChosen` or `TagNameSuggestion`.
3. `TagSuggestionView.swift` (G-1, P-7, P-8, settled fact 4): apply S9a to S9e. The form mode for one tag is now the
   `tag:` initializer; the old third `Source` case and its private completion function are gone with their only
   caller.
4. `MyTagEditorFeature.swift` (G-1, P-5, P-9, P-10): apply S10a to S10h.
5. `MyTagEditorView.swift` (G-1, P-8): apply S11a.
6. Copy (CONTEXT copy table, P-14): copy S8 to `.capture/261126-wzg/insert_copy.py` exactly, then from the repository
   root run `python3 -I .capture/261126-wzg/insert_copy.py insert my_tags.alias`; it prints `ok`. The script writes
   the AppComponents catalog only.
7. Run the verify lines, then commit.

Commit subject: `tags: suggest the site's tags in Add Tag`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-wzg/task3-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 to 6; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzg/task3-red.log | grep -cE 'suggestDone|siteSuggestionAnswer|siteSuggestions|suggestionChosen|TagNameSuggestion'   [EXPECT>=1]</automated>
    <automated>python3 -I .capture/261126-wzg/insert_copy.py check my_tags.alias   [HEAD: KeyError: 'my_tags.alias'; EXPECT: ok]</automated>
    <automated>git diff --numstat -- AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings   [HEAD: no output; EXPECT before the commit: "41	0	AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings"]</automated>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests -only-testing:AppFeatureTests -only-testing:AppToolsTests -only-testing:SettingFeatureTests 2>&1 | tee .capture/261126-wzg/task3-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzg/task3-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzg/task3-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagEditorTests/[A-Za-z]+" .capture/261126-wzg/task3-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=8 EXPECT==14]</automated>
    <automated>grep -oE "Test case 'TagNameSuggestionTests/[A-Za-z]+" .capture/261126-wzg/task3-tests.log | sort -u | wc -l | tr -d ' '   [HEAD=0 EXPECT==2]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/AppComponents AppPackage/Sources/MyTagEditor AppPackage/Tests/DetailFeatureTests AppPackage/Tests/AppFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>python3 -I Scripts/lint/app_storage_isolation.py check   [HEAD: 0 break(s); EXPECT: 0 break(s) of the app-storage isolation rule.]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/TagSuggestionView.swift | grep -c 'tagName'   [HEAD=3 EXPECT==0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -c 'tagName'   [HEAD=1 EXPECT==0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -c 'showTagsSearchSuggestion'   [HEAD=1 EXPECT==0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -cF 'translations: store.setting.translateTags ? tagTranslator.translations : [:]'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/AppComponents/TagSuggestionView.swift | grep -cF 'Text(.myTagsAlias(alias))'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF 'try await clock.sleep(for: .milliseconds(200))'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF '.cancellable(id: CancelID.suggestions, cancelInFlight: true)'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing editor members; `insert_copy.py check my_tags.alias` prints `ok` and the catalog diff is 41 insertions, 0 deletions; DetailFeatureTests, AppFeatureTests, AppToolsTests and SettingFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the six new editor tests (14 distinct names) and the two merge tests listed as passed and the pointer-hover audit unchanged; no warning, lint clean, isolation gate clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: suggest the site's tags in Add Tag` holding exactly the six files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 4: An invalid colour code turns the footer red and holds confirm back (G-2, G-4)</name>
  <files>AppPackage/Sources/MyTagEditor/HexColorField.swift, AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift, AppPackage/Sources/MyTagEditor/MyTagEditorView.swift, AppPackage/Sources/MyTagEditor/Resources/Localizable.xcstrings, AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift</files>
  <precondition>Task 3 is committed; `.capture/261126-wzg/insert_copy.py` exists from Task 3.</precondition>
  <read_first>
    - AppPackage/Sources/MyTagEditor/HexColorField.swift (whole file) and AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift (its `HexColorField(` call, which stays as it is)
    - AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift and AppPackage/Sources/MyTagEditor/MyTagEditorView.swift (whole files, as Task 3 left them)
    - AppPackage/Sources/AppModels/Tags/MyTags.swift lines 10-50 (`SiteColor.init?(hex:)`, `hex`)
  </read_first>
  <behavior>
    - Empty text, spaces alone, `#1F3A93`, `1f3a93` and ` #1F3A93 ` are no invalid code; `#`, `#1F3A9`, `#1F3A930`, `#GGGGGG` and `1F 3A93` are (G-2).
    - In Add Tag with a set colour: the footer starts as the set's colour; `#1F3A9` makes it the invalid footer and disables confirm; `#1F3A93` with its colour makes it the own-colour footer and enables confirm; spaces alone keep the own-colour footer and confirm (G-2, G-4).
    - In Edit Tag the tag's own colour starts in the field as `#A0B0C0`; with another change made, `zz` disables confirm and confirm sends nothing; an emptied field enables it again (G-2, G-4).
  </behavior>
  <action>
Write the tests first (RED: the editor has no `colorText` or `colorFooter` and the field no `isInvalidCode`; run
`-only-testing:DetailFeatureTests` once with log `task4-red.log`), then the code and the copy.

1. Tests (G-4): apply S15a to S15d to `MyTagEditorTests.swift`.
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `colorText`, `colorFooter` or
   `isInvalidCode`.
3. `HexColorField.swift` (G-2, P-11, settled fact 6): replace the whole file with S20. Its existing initializer keeps
   its signature, so `MyTagsView` compiles unchanged.
4. `MyTagEditorFeature.swift` (G-2, P-11): apply S13a to S13f.
5. `MyTagEditorView.swift` (G-2): apply S14a and S14b.
6. Copy (P-14): from the repository root run `python3 -I .capture/261126-wzg/insert_copy.py insert
   my_tags.hex_invalid`; it prints `ok`. The script writes the MyTagEditor catalog only.
7. Run the verify lines, then commit.

Commit subject: `tags: flag an invalid color code in the editor`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-wzg/task4-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 to 6; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzg/task4-red.log | grep -cE 'colorText|colorFooter|isInvalidCode'   [EXPECT>=1]</automated>
    <automated>python3 -I .capture/261126-wzg/insert_copy.py check my_tags.hex_invalid   [HEAD: KeyError: 'my_tags.hex_invalid'; EXPECT: ok]</automated>
    <automated>python3 -I .capture/261126-wzg/insert_copy.py check my_tags.alias   [HEAD (after Task 3): ok; EXPECT: ok]</automated>
    <automated>git diff --numstat -- AppPackage/Sources/MyTagEditor/Resources/Localizable.xcstrings   [HEAD: no output; EXPECT before the commit: "41	0	AppPackage/Sources/MyTagEditor/Resources/Localizable.xcstrings"]</automated>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests -only-testing:SettingFeatureTests 2>&1 | tee .capture/261126-wzg/task4-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzg/task4-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzg/task4-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagEditorTests/[A-Za-z]+" .capture/261126-wzg/task4-tests.log | sort -u | wc -l | tr -d ' '   [HEAD (after Task 3)=14 EXPECT==18]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/MyTagEditor AppPackage/Tests/DetailFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>git diff --name-only HEAD -- AppPackage/Sources/SettingFeature   [EXPECT: no output]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/HexColorField.swift | grep -cF 'public nonisolated static func isInvalidCode(_ text: String) -> Bool'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF 'guard running == nil, !isColorTextInvalid else { return false }'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -cF 'text: $store.colorText,'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -cF 'Text(.myTagsHexInvalid)'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing colour members; `insert_copy.py check` prints `ok` for both keys and the MyTagEditor catalog diff is 41 insertions, 0 deletions; DetailFeatureTests and SettingFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the four new colour tests (18 distinct editor test names) listed as passed; nothing under SettingFeature changed; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: flag an invalid color code in the editor` holding exactly the five files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 5: A number field beside the weight Stepper (G-3, G-4)</name>
  <files>AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift, AppPackage/Sources/MyTagEditor/MyTagEditorView.swift, AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift</files>
  <precondition>Task 4 is committed.</precondition>
  <read_first>
    - AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift and AppPackage/Sources/MyTagEditor/MyTagEditorView.swift (whole files, as Task 4 left them)
    - AppPackage/Sources/AppModels/Tags/MyTags.swift lines 55-70 (`MyTag.weightRange`, `MyTag.defaultWeight`)
    - AppPackage/Tests/DetailFeatureTests/MyTagEditorTests.swift (whole file, as Task 4 left it)
  </read_first>
  <behavior>
    - A new tag's field reads "10"; an edited tag's field reads its weight; a Stepper change shows in the field; a typed "-5" moves the weight to -5 (G-3, G-4).
    - "150" moves the weight to 99 at once and submit writes "99"; "-123" is cut to "-12" (weight -12); "-100" to "-10" (weight -10); "1234" to "123" (weight 99, then "99" on submit) (G-3, G-4).
    - "", "-", "1-" and "abc" leave the weight at 10, and submit writes "10" back (G-3, G-4).
  </behavior>
  <action>
Write the tests first (RED: the editor has no `weightText` or `weightFieldCommitted`; run
`-only-testing:DetailFeatureTests` once with log `task5-red.log`), then the code.

1. Tests (G-4): apply S18a to S18d to `MyTagEditorTests.swift` (S18b and S18c add the field's text to the two
   existing tests that set the weight through the Stepper's binding, settled fact 10).
2. RED run as above; its log must show `** TEST FAILED **` and a compile error naming `weightText` or
   `weightFieldCommitted`.
3. `MyTagEditorFeature.swift` (G-3, P-12): apply S16a to S16f.
4. `MyTagEditorView.swift` (G-3, P-12): apply S17a and S17b.
5. Run the verify lines, then commit.

Commit subject: `tags: type a tag's weight in the editor`
  </action>
  <verify>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests 2>&1 | tee .capture/261126-wzg/task5-red.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [RED, before steps 3 and 4; EXPECT: ** TEST FAILED **]</automated>
    <automated>grep -E ': error: ' .capture/261126-wzg/task5-red.log | grep -cE 'weightText|weightFieldCommitted'   [EXPECT>=1]</automated>
    <automated>mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -only-testing:DetailFeatureTests -only-testing:SettingFeatureTests 2>&1 | tee .capture/261126-wzg/task5-tests.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'   [EXPECT: ** TEST SUCCEEDED **]</automated>
    <automated>grep -cE "Test case '.*' failed" .capture/261126-wzg/task5-tests.log   [EXPECT=0]</automated>
    <automated>grep -E ': warning: ' .capture/261126-wzg/task5-tests.log | sort -u   [EXPECT: no output]</automated>
    <automated>grep -oE "Test case 'MyTagEditorTests/[A-Za-z]+" .capture/261126-wzg/task5-tests.log | sort -u | wc -l | tr -d ' '   [HEAD (after Task 4)=18 EXPECT==21]</automated>
    <automated>SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet AppPackage/Sources/MyTagEditor AppPackage/Tests/DetailFeatureTests   [EXPECT: no output, exit 0]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -cF '.keyboardType(.numbersAndPunctuation)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -cF '.labelsHidden()'   [HEAD=1 EXPECT==2]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorView.swift | grep -cF '.accessibilityValue(store.weight.formatted())'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF 'state.weight = min(max(typed, MyTag.weightRange.lowerBound), MyTag.weightRange.upperBound)'   [HEAD=0 EXPECT==1]</automated>
    <automated>grep -v '^\s*//' AppPackage/Sources/MyTagEditor/MyTagEditorFeature.swift | grep -cF 'case .weightFieldCommitted:'   [HEAD=0 EXPECT==1]</automated>
  </verify>
  <done>The RED run failed to compile on the missing weight members; DetailFeatureTests and SettingFeatureTests pass (TEST SUCCEEDED, 0 failed cases) with the three new weight tests (21 distinct editor test names) and the two adjusted tests listed as passed; no warning, lint clean; every gate prints its EXPECT value; one signed `+08:00` commit `tags: type a tag's weight in the editor` holding exactly the three files.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app to site | The typed tag text is posted to the site's `api.php` with the session's cookies, as the site's own My Tags page posts it |
| site to app | The `tagsuggest` answer (namespaces, names, alias pairs, `error`, `login`) is parsed and shown as rows |
| user to site | The colour and weight a confirm sends cross into the site's add and edit calls |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261126-wzg-01 | Denial of service | `MyTagEditorFeature` `.binding(\.name)` | medium | mitigate | One question at a time: 200 ms on the clock after the text rests, cancelled by one id with `cancelInFlight`, and nothing below two characters (tested: `aChangedTextCancelsTheQuestionItReplaces`, `fewerThanTwoCharactersAfterTheNamespaceAskNothing`) |
| T-261126-wzg-02 | Tampering | `Parser.parseTagSuggestions` | medium | mitigate | Only entries with a known namespace, a non-empty name and an integer key are kept; any other shape fails as `parseFailed` and shows nothing (tested: `anEntryTheFieldCouldNotTakeIsLeftOut`, `anAnswerWithoutTheTagsFails`) |
| T-261126-wzg-03 | Tampering | confirm with a colour code being typed | medium | mitigate | Confirm stays disabled while the hex text is not a code, so only the last valid colour can be sent (tested: `anInvalidCodeTakesTheColorFooterAndHoldsConfirmBack`, `anEditWithAnInvalidCodeCannotBeConfirmed`) |
| T-261126-wzg-04 | Tampering | the weight sent | low | mitigate | The typed weight is clamped into -99...99 before it reaches `weight`, the only value a confirm sends (tested: `aTypedWeightIsClampedIntoTheSitesRange`) |
| T-261126-wzg-05 | Information disclosure | `TagSuggestRequest` | low | accept | Only the method and the typed text are sent, the same request the site's own page makes for the same account; no credentials beyond the session cookies |
| T-261126-wzg-06 | Spoofing | names in the rows | low | accept | The rows show the site's tag names through the same `SuggestionCell` path the translation rows use today; the alias line is a localized format with the name as its argument |
| T-261126-wzg-07 | Elevation of privilege | an expired session's `login` answer | low | accept | Read as `loginRequired` and shown as no rows, never followed as a redirect; the page's own reads surface the login state |
| T-261126-wzg-SC | Tampering | npm/pip/cargo installs | high | accept | No package installs and no dependency change (`AppPackage/Package.swift` untouched) |
</threat_model>

<verification>
After Task 5, once, from the repository root (TEST rules apply):
- Full plan: `mkdir -p .capture/261126-wzg && set -o pipefail && xcodebuild test -scheme EhPanda -testPlan FeatureTests -destination 'id=19DB23C0-8C35-49C7-9A7D-5D99566BF092' -collect-test-diagnostics never -skip-testing:VisualSnapshotTests 2>&1 | tee .capture/261126-wzg/full-plan.log | grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*'` prints `** TEST SUCCEEDED **`; `grep -cE "Test case '.*' failed" .capture/261126-wzg/full-plan.log` prints `0`; `grep -E ': warning: ' .capture/261126-wzg/full-plan.log | sort -u` prints nothing.
- Lint over every source tree: `SWIFTLINT="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -n 1)" && "$SWIFTLINT" lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` prints nothing.
- `python3 -I Scripts/lint/app_storage_isolation.py check` prints `0 break(s) of the app-storage isolation rule.`
- Invariant (no suppression, no serialization added): `git diff <BASE> -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'` prints `0` (BASE as recorded under Precondition).
- `git diff --stat <BASE> -- AppPackage/Sources/SettingFeature AppPackage/Package.swift` prints nothing.
- `git log -5 --format='%G? %aI %cI %s'` shows the five subjects, each `G` with two `+08:00` instants; `git status --short` shows nothing but untracked planning files of this quick task; nothing is pushed.
</verification>

<success_criteria>
- G-1: in Add Tag, from the second character after the namespace, the site's suggestions show under the field as rows whatever Show Tag Suggestions says, asked 200 ms after the text rests with the site's rewrite and cancelled by a change; with Translate Tags on the local matches the site did not list follow and the names are translated (P-7); an alias row shows its canonical tag and the `my_tags.alias` line, and a tap inserts the canonical tag; a chosen row fills the field; a failure shows no rows and no alert; the request has its own file and type.
- G-2: an invalid hex text shows `my_tags.hex_invalid` in red, keeps the well, disables confirm in both modes; submit restores; empty or valid text keeps the existing footers.
- G-3: the weight field (trailing, prompt 0, `.numbersAndPunctuation`, three characters, labelled Weight) and the Stepper follow each other over -99...99; submit or leaving clamps; empty or unreadable returns to the last weight.
- G-4: the reducer tests (debounce, cancel, threshold, rewrite, alias insert, failure, footer and confirm gating, weight parsing, clamping and sync), the row-merge tests and the model, parser and request tests pass in parallel.
- Copy: `my_tags.alias` in AppComponents' catalog and `my_tags.hex_invalid` in MyTagEditor's, CONTEXT's values in all six locales.
- Five signed `+08:00` commits, 0 warnings, lint clean, full FeatureTests plan green (VisualSnapshotTests skipped).
</success_criteria>

<output>
Create `.planning/quick/261126-wzg-my-tags-editor-suggestions-color-weight/261126-wzg-SUMMARY.md` when done (not
committed). Record: BASE; the five commit hashes and subjects with their `%G? %aI %cI`; each test run (log name,
targets, TEST SUCCEEDED or the RED compile error, failed-case count, the new test names seen as passed); the gate
outputs; and, for the orchestrator:

- **Owner's device checks**, not done by the executor because the live site needs the owner's signed-in account. On
  iPhone and on iPad (the sheet stacked over Settings), in Account, My Tags, a tag set, Add Tag:
  1. Type `f:gl`: nothing shows until typing pauses, then the site's rows appear under the field (with Show Tag
     Suggestions off as well); typing on narrows them; with one character after the namespace (`f:g`) the site's rows
     go.
  2. Type a tag the owner knows is an alias: its row shows the canonical tag with the third line "Also known as ..."
     (in each language checked); a tap puts the canonical tag in the field.
  3. Translate Tags on: the rows show translated names and local matches the site did not list follow the site's
     rows, without a tag listed twice; Translate Tags off: only the site's rows, by their own names.
  4. With the device offline, typing shows no site rows and no alert.
  5. Color: type `#1F3A9`: the footer turns red with the new sentence, the well keeps the old colour, the checkmark
     is disabled; finish the code: the footer and the checkmark return; type `#1F3A9` and press Done: the field
     returns to the last valid code. Same in Edit Tag.
  6. Weight: type `150`: the Stepper's value jumps to 99, and Done or tapping elsewhere shows 99 in the field; clear
     the field and leave it: the last weight comes back; the Stepper's plus is disabled at 99 and its minus at -99;
     the keyboard offers the minus sign; VoiceOver reads the field and the Stepper as Weight.
  7. Text size Accessibility 3 and 5: nothing in the Weight and Color rows clips or overlaps.
  8. Confirm an added tag chosen from a suggestion: the tag lands in the set on the site's own My Tags page.
- The planner's choices P-1 to P-14, one line each, noting P-8 and P-12 for the owner.
</output>
