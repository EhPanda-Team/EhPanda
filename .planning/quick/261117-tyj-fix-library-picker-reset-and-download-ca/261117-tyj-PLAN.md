---
phase: 261117-tyj-fix-library-picker-reset-and-download-ca
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/AppModels/Support/TabBarItemType.swift
  - AppPackage/Sources/AppModels/Download/DownloadFolderFilter.swift
  - AppPackage/Sources/AppModels/Persistent/LibraryPickerChoice.swift
  - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
  - AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
  - AppPackage/Tests/AppModelsTests/Persistent/LibraryPickerChoiceTests.swift
  - AppPackage/Tests/AppModelsTests/SchemaMigrationTests.swift
  - AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift
  - AppPackage/Tests/AppFeatureTests/LibraryNavigationTests.swift
  - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionDeletion.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionDeletionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureManifestPatching.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
autonomous: true
requirements: [A-1, A-2, B-1, B-2, B-3]

estimate:
  tokens: 190000
  raw_tokens: 190000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "On the compact layout, where the Library shows its title-menu picker (iPhone, a folded Duo), the group the user last chose there (Favorites with a category, or Downloads with a folder filter, whether chosen in the picker or inside the Favorites or Downloads screen) is what the Library opens on after a relaunch (A-1, A-2)."
    - "A selection made on the sidebar layout (iPad, a Duo showing panes) is never persisted and never overwrites the remembered picker choice, and a sidebar launch opens with no restored selection, as today (A-2)."
    - "When the compact layout has no selection (a cold launch, or a fold from the sidebar with nothing selected), it opens the remembered picker choice, and Favorites at the current index only when nothing is remembered; a selection carried over between layouts within one process is shown as today and is not persisted by the carry-over (A-2)."
    - "A remembered Downloads folder that no longer exists opens as Downloads / All through the existing DownloadsReducer fallback, and All is what is remembered from then on (A-1)."
    - "Stubbed-network UI-test launches start with no remembered picker choice; hosted visual tests and Appshot captures keep their own in-memory storage, so no choice leaks between tests or captures."
    - "When the user deletes a gallery during a continued session, singly or by deleting the download folder that holds it, its pages leave both X and Y and it stops counting toward N, whatever its state was: active, queued, paused, or completed earlier in the session (B-1, B-2)."
    - "After that deletion the numerator may step back once; later real work then raises it from the reduced value, because the monotonic floor gave back exactly the deleted gallery's counted pages (B-1)."
    - "Paused galleries, completed galleries, the queued-work-item cancel and the expiration pause-all still retire their finished pages and stay counted (D-G2-01 and D-G2C-01 unchanged for them)."
    - "A deletion that lands inside the session start's client hop (B-3), or that cancels the gallery's own run, ends in the same accounting; a deleted gid downloaded again later in the same session counts only its new work."
  artifacts:
    - path: "AppPackage/Sources/AppModels/Persistent/LibraryPickerChoice.swift"
      provides: "The remembered compact-layout picker choice (SchemaVersioned, strict decode)"
      contains: "struct LibraryPickerChoice"
    - path: "AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift"
      provides: "The optional libraryPickerChoice app-storage key"
      contains: "libraryPickerChoice"
    - path: "AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift"
      provides: "The shared remembered choice beside the in-memory selection, and the renamed compact initial-selection action"
      contains: "showInitialSelection"
    - path: "AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift"
      provides: "The single compact-only persist hook and the compact restore"
      contains: "onChange(of: \\.libraryState.selection)"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionDeletion.swift"
      provides: "The deletion boundary that withdraws a deleted gallery from the session"
      contains: "func withdrawDeletedGalleryFromSession(gid: String)"
    - path: "AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift"
      provides: "A-1 / A-2 compact restore and seeding, sidebar non-persistence, carry-over, fold and fallback cases"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionDeletionTests.swift"
      provides: "B-1 / B-2 / B-3 cases for every gallery state, the hop, the run race, the rejoin and the folder deletion"
  key_links:
    - from: "every Library selection change made by AppReducer's main Reduce"
      to: "@Shared(.libraryPickerChoice)"
      via: ".onChange(of: \\.libraryState.selection) writing the new group only while !usesSidebar"
      pattern: "libraryPickerChoice"
    - from: "LibraryFeature compact resolution (the layout turning compact, or the compact picker cleared, with nothing selected)"
      to: "AppReducer .library(.showInitialSelection)"
      via: "the remembered group, else Favorites at the current index, pushed into the sources through librarySelectionEffect"
      pattern: "showInitialSelection"
    - from: "DownloadsReducer .fetchFoldersDone fallback"
      to: "remembered .downloads(.all)"
      via: "AppReducer .library(.syncFromSources) changing the selection on the compact layout"
      pattern: "syncFromSources"
    - from: "DownloadCoordinator.delete(gid:) and deleteFolder(name:)"
      to: "withdrawDeletedGalleryFromSession(gid:)"
      via: "synchronous call beside the index-record removal (B-1, B-2)"
      pattern: "withdrawDeletedGalleryFromSession"
    - from: "ensureContinuedSession seed"
      to: "state every in-hop writer acts on"
      via: "seed placed before the client start's main-actor hop"
      pattern: "backgroundProcessingClient.start"
    - from: "DownloadSourceInventoryTests floor census"
      to: "lastPushedCompletedPageCount writers"
      via: "expectedFloorWriters / expectedFloorWriterTotal"
      pattern: "expectedFloorWriterTotal = 6"
---

<objective>
Fix the two owner-reported bugs exactly as the owner decided in
`.planning/quick/261117-tyj-fix-library-picker-reset-and-download-ca/261117-tyj-CONTEXT.md`
(decisions A-1, A-2, B-1, B-2 and B-3, LOCKED).

- Bug A (A-1, A-2): the Library picker forgets the last selection and opens on Favorites after every
  relaunch, because nothing about the selection is persisted. Remember the full `LibraryGroup` the
  user last chose on the compact layout, where the title-menu picker shows (A-2: only there, never
  from the sidebar), open it when the compact layout has no selection, and let the existing
  missing-folder fallback turn a vanished folder into All.
- Bug B (B-1, B-2, B-3): the continued-processing card's "N galleries" keeps counting galleries the
  user deleted, because D-G2-01 retires a deleted gallery's finished pages into the ledger like any
  other departure. A user deletion, single or by folder (B-2), must take the gallery out of X, Y and
  N, and give its counted pages back to the monotonic floor, including inside the session start's
  client hop (B-3).

Purpose: the owner sees the iPhone Library reopen where it was left, and a download card whose
gallery count matches the galleries the session still covers.

Output: three atomic commits — the remembered picker choice (Task 1), the session-start seed moved
ahead of the client hop (Task 2, the refactor the owner approved as B-3; see "Design notes"), and
the deletion boundary with its rewritten doc contracts (Task 3).

Out of scope, untouched: the download queue operations (item 1 of
`.planning/notes/2026-11-16-reported-download-library-issues.md`) and
`.planning/notes/2026-11-17-save-keyword-as-saved-search.md`.

Execution rule: follow this plan exactly. If any step cannot be done as written (ambiguity, a
contradiction with source, a compile or test outcome the plan does not foresee, a needed deviation),
stop and ask the orchestrator. Do not choose a workaround.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@AGENTS.md
@.swiftlint.yml
@.planning/quick/261117-tyj-fix-library-picker-reset-and-download-ca/261117-tyj-CONTEXT.md
@.planning/notes/2026-11-16-reported-download-library-issues.md

## Design notes (read before Task 1)

### Bug A: a remembered picker choice beside the live selection (A-1, A-2)

A-2 limits what is remembered to the compact layout, where the Library shows its title-menu picker
(`usesSidebar == false`: an iPhone, or a Duo that shows no panes). The sidebar layout (an iPad, or a
Duo showing panes) neither persists its selection nor overwrites the remembered one. So the live
selection cannot itself be the persisted record. `LibraryFeature.State.selection` is shared by both
layouts and carries over between them within one process (A-2 keeps that as today), and at State
init the layout is still unknown (`device == nil` reads as sidebar). A restore at init would either
restore on the sidebar, against A-2, or need a layout guess. The selection therefore stays a plain
in-memory `LibraryGroup?`, unchanged in type and initializer, and a separate record remembers the
last group chosen on the compact layout.

**The record.** `LibraryPickerChoice` is a struct carrying `SchemaVersion`, like every other
persisted model in `AppSharedKeys.swift`. A bare enum cannot carry the version field, and the
version is the migration seam if `LibraryGroup` ever changes shape. It holds a non-optional
`group: LibraryGroup`, the full group per A-1: the source together with the favorites category
index or the download folder filter. The key is optional
(`AppStorageKey<LibraryPickerChoice?>.Default`, string `libraryPickerChoice`, default `nil`), the
first optional key in that file. A record exists only once a choice was made on the compact layout,
so "nothing remembered" is the absence of a record, not a record without a group. A groupless record
is unrepresentable, and clearing it removes the stored data. The decoder is strict. A blob with a
newer version, a missing or malformed group, or a favorites category outside `FavoritesType`'s
indices (-1...9) throws, and Sharing falls back to `nil`, so the compact layout opens Favorites as
it did before the fix. Folder existence is not validated in the decoder: it is runtime evidence,
and the Downloads fallback handles it.

**One write site.** AppReducer's main `Reduce` performs every change of the selection: the picker
select (`.library(.select)`, also used by launch automation), a category change inside Favorites
(`.favorites(.setFavoritesIndex)`), and a folder-filter change inside Downloads together with the
missing-folder fallback (both through `.library(.syncFromSources)`). It also performs the compact
initial selection below. `LibraryFeature`'s own `.select` only repeats the value that `Reduce`
already set. A single `.onChange(of: \.libraryState.selection)` attached to that `Reduce` writes
`LibraryPickerChoice(group:)` whenever the new selection is non-nil and the layout is compact. It
covers every current route by construction, and any future one, where per-case writes could
silently miss one (the fallback, for example). The consequences follow from the rule without extra
branches:

- A sidebar change never writes, so it cannot overwrite the remembered choice (A-2).
- An unknown layout reads as sidebar, so nothing is written before the layout is known.
- A layout flip is not a selection change, so a carried-over selection is not written by the flip
  (A-2: carry-over as today). A change the user then makes on the compact layout is written.
- `nil` is not a choice and is never written.
- The compact initial selection is written too, because it is what the picker then shows. When it
  restored the remembered record, the write stores the same value.

**The restore.** It belongs where the compact layout first resolves an empty selection. That is
`LibraryFeature`'s initial-Favorites action, sent when the layout turns compact with nothing
selected (the `onChange(of: \.usesSidebar)` hook) or when the compact picker is cleared. The case
is renamed `showInitialSelection`, because it now opens the remembered choice. Its AppReducer
handler keeps the nil guard, picks `pickerChoice?.group`, falls back to
`.favorites(favoritesState.favoritesIndex)` only when nothing is remembered, and returns
`librarySelectionEffect`. That is the same push a picker select uses: it seeds `favoritesIndex` or
`folderFilter` and starts the presentation. The sources are not seeded directly, because that would
bypass `setFavoritesIndex`'s reading-request reset and category fetch. The earlier plan's
`AppReducer.State.init()` seeding is dropped. The selection starts `nil` as today, and the sources'
defaults agree with `nil`. A pull can land between the restore and its push, for example
`syncFromSources` after a folder fetch that was already in flight. It briefly sets the selection,
and therefore the record, to the source's default. The push carries the group captured at the
restore and always follows, so both converge on the restored group. Every picker select has the
same window today.

**Sidebar launches** (an iPad, a Duo opening with panes) never turn compact, so the initial
selection never fires and the sidebar shows its prompt, as today (A-2). If a Duo later folds with
nothing selected, the fold opens the remembered choice (A-2).

**Vanished folder** (A-1). The compact restore of `.downloads(.folder(X))` pushes X into
`folderFilter`. The Downloads presentation fetches the folders, `DownloadsReducer` resets the filter
to `.all` when X is missing, and `syncFromSources` changes the selection to `.downloads(.all)` on the
compact layout, which the hook remembers. If the fallback runs on the sidebar, nothing is written,
and the next compact restore takes the same route.

**Test and capture isolation.** Hosted visual tests (`configureVisualTestHost`), Appshot captures
(`CaptureScenePreparation`) and the visual snapshot matrix already run on `UserDefaults.inMemory`.
Stubbed-network UI-test launches use the app's real defaults and reset what they depend on through
`UITestAutomation.StoragePreset.apply()`. That preset also clears the remembered choice, so every
stubbed launch's compact Library opens Favorites as before, and `EHPANDA_AUTOMATION_TAB`'s group is
still applied afterwards by the launch automation. Because the selection keeps its type and
initializer, the existing tests and snapshot scenarios that set it need no change. Only tests that
touch the remembered choice hold their own in-memory suite.

### Bug B: where a deletion leaves the session, and why Task 2 is needed

Today a deleted gallery is a departure like any other. `reconcileRetiredSessionPages` retires its last
observation into `retiredSessionPages`, which keeps it in X, Y and N (`coverageGalleryCount` counts
positive ledger entries). D-G7-01's bracket deliberately reads a vanished gallery as no movement, so
nothing gives its pages back to `lastPushedCompletedPageCount`.

B-1 is implemented at the deletion boundary, the only code that knows why the gallery left, so
`reconcileRetiredSessionPages` remains free of departure-reason branches (no reason parameter, no
reason branch). A new coordinator method, `withdrawDeletedGalleryFromSession(gid:)` in a new file
`DownloadClient+ContinuedSessionDeletion.swift`, runs synchronously beside each index-record removal
of a successful user deletion. It removes the gallery's ledger entry and its last observation, and
subtracts what they held from the floor. The two entries are mutually exclusive by reconcile's
construction: a reconcile drops the ledger entry of every gallery it observes live, and observation
is replaced wholesale. So "ledger entry, else last observation, else zero" is exactly what the
session currently counts for that gallery. For a gallery with no record left it is also exactly what
the next reconcile would retire. Because the call is synchronous with the record removal, no push can
observe a record-less gallery that is still observed. A push that ran earlier, during the deletion's
own awaits (the deletion's scheduling block hides the gallery, so that push retires it), is answered
by the ledger branch. The coverage definition is untouched: a deleted gallery is in neither the live
set nor the ledger. The floor may hold less than the withdrawn value (for example, run-exit freeze
progress that was not yet pushed). It then sits below the honest numerator, which the push's `max`
makes inert. The floor can never hold more than the withdrawn value, so it never under-withdraws.

**Why Task 2 (a broader refactor, stated openly; approved by the owner as B-3).** `ensureContinuedSession` currently merges its
pre-hop snapshot into the observation maps and the floor AFTER the client start's main-actor hop.
A deletion that lands inside that hop (delete starts after the opening snapshot and removes the
record before `start` returns) finds nothing to withdraw, and the post-hop merge then re-seeds the
deleted gallery from the stale snapshot. The next reconcile retires it, and it stays in X, Y and N,
which violates B-1. The post-hop position is also why three earlier rounds each had to add a
separate merge for another in-hop writer: the keep-observed merge (15-25), the max-generation merge
(CR-02), and the additive floor merge with its negative transient (15-26). Moving the seed into the
start's synchronous reset stretch, before `start` is awaited, removes that whole class: every in-hop
writer (a push's reconcile, a D-G7-01 withdrawal, a run-exit freeze, and now the deletion boundary)
acts on seeded state, exactly as at any later moment. A refused start tears everything down, as
today. A start superseded during the hop finds its seed already cleared by whatever superseded it (the
teardown, or a successor's own synchronous reset). That keeps the property the post-hop position
provided: a superseded start leaves nothing behind. The merge and additive forms are kept. They are
exact when nothing interleaves, and they keep the seed correct if a suspension is ever introduced into
the snapshot read. That case is governed by the existing "does not suspend today" note. The owner
approved this refactor as B-3, so a deletion during the start window also leaves the session.

Rejoin under the same gid: every queue-mobilizing entrance advances the queue-intent generation
(CR-02, census-owned). The deleted predecessor's `observedIncompleteSessionGenerations` entry
therefore cannot credit the successor, and the boundary must NOT clear that map (CR-02 records that
no per-path clear is wanted). The successor is observed fresh by the next snapshot.

Scope of "user deletion": `delete(gid:)`'s success path, and `deleteFolder(name:)`'s per-gallery
removal, which the owner ruled a user deletion too (B-2). Not covered: `delete(gid:)`'s `.notFound` branch and
its failed-removal branch. In both, this call removed no record, and a record that vanished
otherwise remains a departure the reconcile values (AGENTS.md: external folder mutations are not
chased).

### Verification conventions (every command runs from the checkout root)

- Simulator: the project rule requires a project-prefixed simulator. If
  `xcrun simctl list devices available | grep -F "EhPanda iPhone Air ("` finds nothing, create it with
  `xcrun simctl create "EhPanda iPhone Air" com.apple.CoreSimulator.SimDeviceType.iPhone-Air com.apple.CoreSimulator.SimRuntime.iOS-27-0`
  (iOS 27.0, the CI runtime), use it for every test run, and delete it with
  `xcrun simctl delete "EhPanda iPhone Air"` after the final run if this plan created it. The id in
  `.planning/config.json` `test_command` no longer exists. Never touch other projects' simulators.
- One test invocation on the machine at a time: before each `xcodebuild test*`, wait until
  `pgrep -x xcodebuild` finds nothing. Never kill another session's process.
- One scratch derived-data folder for the whole plan: `.build/261117-tyj/dd` (gitignored).
- Baseline (once, before Task 1, at the untouched HEAD):
  `mkdir -p .build/261117-tyj && xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/261117-tyj/dd -skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile > .build/261117-tyj/build-baseline.log 2>&1; grep -q "TEST BUILD SUCCEEDED" .build/261117-tyj/build-baseline.log && grep -E ": warning: " .build/261117-tyj/build-baseline.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u > .build/261117-tyj/warnings-baseline.txt`
  then `SWIFTLINT=.build/261117-tyj/dd/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint; "$SWIFTLINT" lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension > .build/261117-tyj/lint-baseline.txt; echo $?`
  and record both baselines in the SUMMARY. If HEAD is not lint-clean or the build fails, stop and
  ask.
- Per-task build gate (BUILD):
  `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/261117-tyj/dd -skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile > .build/261117-tyj/build-taskN.log 2>&1; grep -q "TEST BUILD SUCCEEDED" .build/261117-tyj/build-taskN.log && grep -E ": warning: " .build/261117-tyj/build-taskN.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u | comm -13 .build/261117-tyj/warnings-baseline.txt - | tee .build/261117-tyj/new-warnings-taskN.txt; test ! -s .build/261117-tyj/new-warnings-taskN.txt`
  This compiles every FeatureTests target, VisualSnapshotTests included.
- Per-task lint gate (LINT): the baseline lint command above, written to
  `.build/261117-tyj/lint-taskN.txt`, must exit 0 with empty output (or show no line beyond the
  recorded baseline). This lints Tests too, which the app-scheme build plug-in does not.
- Per-task test gate (TEST), after BUILD passed in the same derived data:
  `xcodebuild test-without-building -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=EhPanda iPhone Air,OS=27.0' -derivedDataPath .build/261117-tyj/dd <only-testing flags> -collect-test-diagnostics never -resultBundlePath .build/261117-tyj/taskN.xcresult > .build/261117-tyj/test-taskN.log 2>&1; grep -q "TEST EXECUTE SUCCEEDED" .build/261117-tyj/test-taskN.log && xcrun xcresulttool get test-results summary --path .build/261117-tyj/taskN.xcresult | grep -E '"failedTests" : 0'`
  Read per-target counts from the xcresult summary, not from the log alone, before reporting.
  Existing expected-failure diagnostics (withKnownIssue cases) are not failures. Tests run in
  parallel: never add `.serialized` or `-parallel-testing-enabled NO`.
- Commits: one signed commit per task, message of 50 characters or fewer, following the commit
  identity, signing and UTC+8 timestamp rules the project instructions point to (AGENTS.md and its
  local companion file). Verify signature `G` and both offsets `+08:00` after each commit.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Remember the compact picker's choice and open it when the compact layout has no selection (A-1, A-2)</name>
  <files>AppPackage/Sources/AppModels/Support/TabBarItemType.swift, AppPackage/Sources/AppModels/Download/DownloadFolderFilter.swift, AppPackage/Sources/AppModels/Persistent/LibraryPickerChoice.swift, AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift, AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift, AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift, AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift, AppPackage/Tests/AppModelsTests/Persistent/LibraryPickerChoiceTests.swift, AppPackage/Tests/AppModelsTests/SchemaMigrationTests.swift, AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift, AppPackage/Tests/AppFeatureTests/LibraryNavigationTests.swift, AppPackage/Tests/AppFeatureTests/UITestStubTests.swift</files>
  <read_first>
    - .swiftlint.yml (custom rules: single_line_trailing_closure means a one-line `withLock` closure is written in parentheses, `withLock({ ... })`; optional_try is banned; sorted_imports; file_length 1000; line_length 120)
    - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift (header and the key declaration form, for example the `setting` key), SchemaVersion.swift, VersionedSchema.swift
    - AppPackage/Sources/AppModels/Moderation/BlockedCommentUser.swift (the SchemaVersioned plus hand-written strict decoder pattern to mirror)
    - AppPackage/Sources/AppModels/Persistent/User.swift (`FavoritesType` and its `index`, the authority for valid favorites indices)
    - AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift (whole), LibraryView.swift (every selection route goes through `.select`), AppPackage/Sources/AppComponents/LibraryTitleMenu.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift: the main `Reduce`, the existing `BindingReducer().onChange(of: \.presentationState.destination)` for the modifier form, the `.library(...)` cases, `.favorites(.setFavoritesIndex)`, the `.downloads(.binding(\.folderFilter))` / `.fetchFoldersDone` / `.createDefaultFolderDone` relay, `librarySelectionEffect`, `tabPresentationEffect`, and the launch automation's `initialLibraryGroup` select
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift (`onPresented`, `fetchFolders`, the `fetchFoldersDone` fallback to `.all`) and AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift `setFavoritesIndex` (why the sources are pushed, not seeded)
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift (`StoragePreset`, `configureVisualTestHost`) and CaptureScenePreparation.swift (in-memory storage)
    - AppPackage/Tests/AppFeatureTests/CaptureRouteTests.swift `makeStore` (one `UserDefaults.inMemory` suite for state AND store, and its `.noop` client set), UITestStubTests.swift `theStoragePresetReplacesTheBlockListAndTheDisplayName`, LibraryNavigationTests.swift (whole)
    - Sharing's `AppStorageKey.swift` in `.build/261117-tyj/dd/SourcePackages/checkouts/swift-sharing/Sources/Sharing/SharedKeys/` (present after the baseline build): the optional-Codable `appStorage(_:store:)` overload `where Self == AppStorageKey<Value?>`, and `OptionalLookup`, where writing `nil` removes the stored data
    - Skills to load: pfw-sharing, pfw-composable-architecture, swift-testing-pro
  </read_first>
  <behavior>
    - Model (LibraryPickerChoiceTests): a choice round-trips for `.favorites(-1)`, `.favorites(9)`, `.downloads(.all)` and `.downloads(.folder("Reading"))`; a blob with schemaVersion 2 throws; a favorites index of 10 or -2 throws; a blob without a group throws. Through `@Shared(.libraryPickerChoice)` on an in-memory suite, no stored data reads `nil`, a corrupt blob under `libraryPickerChoice` reads `nil`, and writing `nil` removes the suite's `libraryPickerChoice` data.
    - `LibraryPickerChoice.hasWellFormedSchemas` holds (added to the existing invariant test).
    - In the feature cases below, "stored" means the record decoded from the suite's `libraryPickerChoice` data, and absent data means nothing is remembered.
    - Compact cold launch with a remembered `.downloads(.folder("Reading"))` and the folders `["Reading"]`: `.library(.deviceChanged(.other))` leads to `.library(.showInitialSelection)`, which selects it; `downloadsState.folderFilter` becomes `.folder("Reading")`; after the presentation settles, the selection and the stored record both read `.downloads(.folder("Reading"))`.
    - Compact cold launch with a remembered `.favorites(3)`: it is selected, `favoritesState.favoritesIndex` becomes 3, and the stored record stays `.favorites(3)`.
    - A folded Duo cold launch (`.duo(.closed)`, then a 390x844 viewport) with a remembered `.downloads(.all)` restores it.
    - Sidebar launches restore nothing, parameterized over `.pad` and over `.duo(.fullyOpen)` with a 1000x700 viewport, each case on its own suite: with a remembered `.favorites(3)`, reporting the device (and, for the Duo, the viewport) leaves the selection `nil` and the stored record `.favorites(3)`.
    - Sidebar changes never persist, parameterized over the same two sidebar layouts, each case on its own suite, with the folders `["Inbox", "Reading"]` and starting from a remembered `.favorites(-1)`: `.library(.select(.downloads(.folder("Reading"))))`, then a folder-filter binding change to `.folder("Inbox")`, then `.library(.select(.favorites(-1)))` followed by `.favorites(.setFavoritesIndex(3))`. The selection follows each change, and the stored record stays `.favorites(-1)`. A second run of the same steps with nothing remembered leaves the stored data absent.
    - Compact changes persist (`.other`, the folders `["Inbox", "Reading"]`, nothing remembered at the start): `.library(.select(.downloads(.folder("Reading"))))` stores it; a folder-filter binding change to `.folder("Inbox")` stores `.downloads(.folder("Inbox"))`; `.library(.select(.favorites(-1)))`, then `.favorites(.setFavoritesIndex(3))`, stores `.favorites(3)`.
    - Missing-folder fallback on the compact layout: with a remembered `.downloads(.folder("Gone"))` and the folders `["Inbox"]`, after the restore and the presentation, `folderFilter` is `.all`, the selection is `.downloads(.all)` and the stored record is `.downloads(.all)`.
    - Carry-over: on a Duo with panes, with the folders `["Reading"]` and a remembered `.favorites(-1)`, `.library(.select(.downloads(.folder("Reading"))))`, then a 700x1000 viewport (compact). The selection stays `.downloads(.folder("Reading"))`, `.library(.showInitialSelection)` does not run, and the stored record stays `.favorites(-1)`.
    - Fold with nothing selected: on a Duo with panes, with the selection `nil` and a remembered `.downloads(.all)`, a 700x1000 viewport leads to `.library(.showInitialSelection)`, which selects `.downloads(.all)`.
    - Nothing remembered on the compact layout: the existing `phoneEntryUsesRememberedFavoritesWithoutResettingItsNavigation` still opens `.favorites(3)` at the current index without resetting the navigation, and now also asserts the write of `LibraryPickerChoice(group: .favorites(3))`.
    - `StoragePreset.apply()` clears a stored choice.
  </behavior>
  <action>
Implement A-1 and A-2 exactly as "Design notes / Bug A" describes. Write the failing tests first, then the implementation.

1. Models (AppModels). Add synthesized `Codable` conformance to `LibraryGroup` in `Support/TabBarItemType.swift` and to `DownloadFolderFilter`. Create `Persistent/LibraryPickerChoice.swift` with a public `LibraryPickerChoice: Codable, Equatable, Sendable, SchemaVersioned` struct. It has a `schemas` list holding a v1 base `SchemaV1` (mirror `BlockedCommentUser`), a `public var schemaVersion: SchemaVersion<LibraryPickerChoice> = 1`, a `public let group: LibraryGroup` (non-optional), `public init(group: LibraryGroup)`, and a hand-written strict `init(from:)` in a `// MARK: Manually decode` extension. That decoder decodes `schemaVersion`, decodes `group` as required (`decode`, never `decodeIfPresent`), and throws `DecodingError.dataCorrupted` when the group is `.favorites(index)` and no element of `FavoritesType.allCases` has that `index`. Doc-comment the WHY:
   - this is the group last chosen on the compact layout's title-menu picker (261117-tyj, A-1 and A-2; owner decisions), and the sidebar layout never writes it;
   - it is a struct so it can carry `SchemaVersion`;
   - `group` is non-optional because "nothing remembered" is the absence of the record;
   - the decode is strict, so a blob the picker cannot show reads as nothing remembered;
   - folder existence is not validated here, because it is runtime evidence that the Downloads fallback handles.
2. Key. In `AppSharedKeys.swift`, add a `// MARK: Library` section declaring `libraryPickerChoice` on `AppStorageKey<LibraryPickerChoice?>.Default`, in the same form as the `setting` key, under the key string `libraryPickerChoice` with default `nil`. Its doc comment covers what it holds, why it is optional (absence means nothing remembered, and clearing removes the stored data), and its sole writer, reader and clearer: AppReducer's compact-only hook writes it, the compact initial selection reads it, and `UITestAutomation.StoragePreset` clears it. Extend the header's paragraph on models that hand-write a strict decoder so it also names `LibraryPickerChoice` and why (it rejects a favorites category the Library cannot show). Change nothing else in that header.
3. Library feature. In `LibraryFeature.State`, keep `selection` a plain `LibraryGroup?` and keep `init(selection:)` unchanged. Add `@Shared(.libraryPickerChoice) var pickerChoice: LibraryPickerChoice?` with a doc comment: per A-2 it is the remembered compact choice, written only by AppReducer's compact-only hook and read by the compact initial selection. Doc-comment `selection` with the WHY: it is what both layouts show, it is kept in memory only and carries over between layouts within one process, and it is never itself persisted, because only compact choices are remembered (A-2). Rename the initial-Favorites case of `LibraryFeature.Action` to `showInitialSelection`, at its declaration, its two send sites (the `.select` case and the `onChange(of: \.usesSidebar)` hook) and the no-op case list. Doc-comment the case: it is sent when the compact layout has no selection (the layout turned compact, or the compact picker was cleared), and AppReducer resolves it.
4. App reducer (`AppReducer.swift`).
   - Rename the handler of that case to `.library(.showInitialSelection)`. Keep its nil guard. Select `state.libraryState.pickerChoice?.group`, fall back to `.favorites(state.favoritesState.favoritesIndex)` only when nothing is remembered, and return `librarySelectionEffect(selection, state: &state)`. Comment the WHY above the case, in the file's `//` style: the compact layout's first resolution of an empty selection is where a restore belongs, because the layout is unknown at State init (A-2); the push seeds the sources exactly like a picker select; seeding them directly would bypass `setFavoritesIndex`; a pull that lands before the push converges, because the push carries the restored group.
   - Attach `.onChange(of: \.libraryState.selection)` to the main `Reduce`, right after its closing brace and before the first `Scope`, with the two-parameter closure form `{ _, state in ... }`. When `state.libraryState.usesSidebar` is false and the new selection is non-nil, it writes `LibraryPickerChoice(group:)` through `state.libraryState.$pickerChoice.withLock({ ... })`. It always returns `.none`. Comment the WHY above it: A-2 (only the compact picker's choice is remembered); why one hook (every selection route runs through this `Reduce`, and LibraryFeature's own `.select` only repeats the value it set); and the consequences listed in the design notes (sidebar, unknown layout, carry-over, `nil`, the initial selection).
   - Change nothing else in AppReducer. Add no State initializer, and leave `.library(.select)`, `.favorites(.setFavoritesIndex)`, `.library(.syncFromSources)`, `librarySelectionEffect` and `tabPresentationEffect` as they are.
5. UI-test isolation. In `UITestAutomation.StoragePreset.apply()`, also clear `@Shared(.libraryPickerChoice)` with `withLock({ $0 = nil })`. Extend the `StoragePreset` doc and the `apply()` doc so they say a stubbed launch starts with no remembered Library picker choice. Do not add an environment key.
6. Tests (Swift Testing). Every test that reads or writes the remembered choice holds ONE `UserDefaults.inMemory` suite and uses it both while building the state and in the TestStore's `withDependencies` (the `CaptureRouteTests.makeStore` pattern). A parameterized case builds its own suite inside the test body, never a shared static.
   - New `AppPackage/Tests/AppModelsTests/Persistent/LibraryPickerChoiceTests.swift` covers the model behaviors. Add `#expect(LibraryPickerChoice.hasWellFormedSchemas)` to `SchemaMigrationTests.everyModelDeclaresWellFormedSchemas`.
   - New `AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift` covers the feature behaviors. Give it two helpers.
     - A store helper. It takes the remembered choice, the starting `libraryState.device` and `viewport` (`nil` and `.zero` for a cold launch), and the folder list. It presets the choice through `@Shared(.libraryPickerChoice)` inside `withDependencies` on the case's suite, and builds `AppReducer.State()` there. The TestStore gets the same suite, plus the `.noop` analytics, cookie, haptics, home, logs and userDefaults clients that `CaptureRouteTests.makeStore` installs, and a `.noop` `downloadClient` copy whose `fetchFolders` returns the folder list. Its exhaustivity is `.off(showSkippedAssertions: false)`.
     - A stored-record helper that decodes the suite's `libraryPickerChoice` data with `JSONDecoder` through `try`, returning `nil` when the data is absent.
     - Assert received actions with `store.receive(\.library.showInitialSelection)` where a case names it. Settle with `await store.finish()` after every step whose result is asserted, then assert the selection, the source parameter and the stored record. If `finish()` times out, stop and ask; do not add skips.
   - In `LibraryNavigationTests`:
     - Rename the initial-selection send and receive to `showInitialSelection`.
     - Build `phoneEntryUsesRememberedFavoritesWithoutResettingItsNavigation`'s state and store on one `UserDefaults.inMemory` suite. Assert the write inside its `showInitialSelection` receive as `$0.libraryState.$pickerChoice.withLock({ $0 = LibraryPickerChoice(group: .favorites(3)) })`. Keep its exhaustive assertions otherwise.
     - Rename the test about a delayed initial resolution not replacing an explicit Downloads selection to `delayedInitialSelectionDoesNotReplaceAnExplicitDownloadSelection`.
     - Leave the other tests in the file unchanged.
   - Add `theStoragePresetClearsTheRememberedLibraryPickerChoice` to `UITestStubTests`, in the `withDependencies { $0.defaultAppStorage = .inMemory }` form of its neighbor.
   - No other existing test changes. If any other test fails or seems to need a change, stop and ask.

Do not touch `LibraryTitleMenu`, `LibraryView`, the Downloads and Favorites reducers, the tab bar, or any VisualSnapshotTests or capture test. Nothing else is persisted: not the expansion flags, not the tab, and not the sidebar's selection.
  </action>
  <verify>
    <automated>Run BUILD, LINT and TEST from "Verification conventions" with N=1 and `-only-testing:AppModelsTests -only-testing:AppFeatureTests -only-testing:DownloadsFeatureTests`; then the absence gate `! grep -rq 'showInitialFavorites' AppPackage/Sources AppPackage/Tests` and the presence gates `grep -q 'case showInitialSelection' AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift`, `grep -v '^[[:space:]]*//' AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift | grep -q 'appStorage("libraryPickerChoice")'` and `grep -F -q 'onChange(of: \.libraryState.selection)' AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` (all four fail at HEAD, pass after).</automated>
    <human-check>On devices (owner, end of quick task). iPhone: choose Downloads > a folder in the title menu, force-quit, relaunch, open Library: the same folder shows. Choose Favorites, then a category inside the Favorites screen, and repeat: the same category shows. Delete the remembered folder in Files and relaunch: Downloads / All shows. iPad: pick a sidebar row, force-quit, relaunch: the sidebar opens with nothing selected, as before the fix.</human-check>
  </verify>
  <done>The compact layout's last choice persists under `libraryPickerChoice` with strict, versioned decoding. A compact layout with no selection opens it and seeds the sources, and opens Favorites at the current index only when nothing is remembered. Sidebar selections are never persisted and never overwrite it, and sidebar launches restore nothing. Carry-over is unchanged. A vanished folder resolves to and is remembered as All. Stubbed UI-test launches clear it. All three test targets pass, BUILD has no new warnings, LINT is clean, and one signed commit (for example "Remember the Library picker choice") is made.</done>
</task>

<task type="auto">
  <name>Task 2: Seed the continued session before the client start's hop (B-3, prerequisite of B-1)</name>
  <files>AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift, AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift, AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift</files>
  <read_first>
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift `ensureContinuedSession` (whole function and its doc), `pushContinuedSessionProgress` doc (start-window paragraph), `freezeSessionCreditForRetiringRun`
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift `lastPushedCompletedPageCount` doc (writer 2 and the negative-transient paragraph)
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift `withdrawingCountedBasisMovement` doc (the unclamped-subtraction paragraph) and the announce doc that mentions the seed merging (near line 643)
    - .planning/phases/15-continued-background-downloads/15-25-PLAN.md Step 4 and 15-26-PLAN.md (why the merges exist)
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift `testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed`, DownloadContinuedSessionLedgerTests.swift `testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed`, DownloadSourceInventoryTests.swift floor-writer census doc
    - Skills to load: swift-concurrency-pro, swift-testing-pro
  </read_first>
  <action>
Move the session-start seed into the start's synchronous reset stretch, as "Design notes / Bug B / Why Task 2" describes; the owner approved this refactor (per B-3). This is a behavior-preserving refactor for every existing case.

1. In `ensureContinuedSession`, move the three seed statements unchanged in form so they come right after `let snapshot = await schedulableSnapshot()` and before the opening-progress construction and `await backgroundProcessingClient.start(...)`. The three statements are: the floor's additive `max(snapshot...displayCompletedPageCount + lastPushedCompletedPageCount, 0)`, the keep-observed `observedSchedulablePages.merge`, and the max-generation `observedIncompleteSessionGenerations.merge`. Keep the reset at the top, the refusal rollback, the ownership re-check, the client-id stamp, liveness, logging, heartbeat, the consuming task and the deferred reconcile where they are.
2. Replace the three long post-hop comments with one compact comment at the new position. It must state: the seed belongs to the start's synchronous stretch, so every writer that can land inside the client hop (a push's reconcile, a D-G7-01 withdrawal, a run-exit freeze, a deletion) acts on seeded state as at any later moment; why the post-hop placement needed one compensation per writer; how a refused or superseded start still leaves nothing behind; and why the merge and additive forms stay. Add an entry to the function doc's interleaving-dispositions list for writers landing inside the hop.
3. Rewrite, not annotate, every doc contract that describes the post-hop seed:
   - `lastPushedCompletedPageCount` writer 2 becomes the seed from the opening snapshot, before the client hop.
   - The negative-transient paragraph is replaced. The hop no longer needs a negative floor. A negative value can still follow a withdrawal larger than what the floor held, and it is inert because the push compares it with a never-negative display count, which is why neither writer clamps.
   - The bracket doc's unclamped-subtraction paragraph is rewritten to match.
   - The ExecutionSupport announce doc's mention of the seed merge is rewritten.
   - `pushContinuedSessionProgress`'s start-window sentence about the withdrawal being the scalar's only writer in the hop is rewritten.
   - The DownloadSourceInventoryTests floor-census doc's description of the seed writer is rewritten. The table numbers stay at 4 + 1 = 5.
   - The doc comments of `testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed` and `testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed` are rewritten to the new mechanism, including their inline comments that mention the pre-hop or merged seed. Their names and expectations are unchanged.
   Find every such sentence with `grep -rn -i "additive merge\|seed merge\|seed's merge\|pre-hop\|post-start seed\|reads NEGATIVE\|drives it negative\|keep-observed" AppPackage/Sources AppPackage/Tests` and resolve each hit. A hit that still reads true (for example "the opening is the pre-hop snapshot") may stay.
4. Keep every touched file at or under 1000 lines by keeping the rewritten prose tight. Never suppress `file_length`. No new tests in this task: the discriminating case for the new position is Task 3's hop-deletion test, which fails with this task reverted. The existing hop cases must stay green unchanged.
  </action>
  <verify>
    <automated>Run BUILD, LINT and TEST with N=2 and `-only-testing:DownloadsFeatureTests`; then `awk '/^[[:space:]]*observedSchedulablePages\.merge\(/{m=NR} /^[[:space:]]*lastPushedCompletedPageCount = max\(/{f=NR} /await backgroundProcessingClient\.start\(/{s=NR} END{exit !(m && f && s && m < s && f < s)}' AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` exits 0 (fails at HEAD: merge at 468 and floor seed at 448 follow start at 411) and `wc -l` of every touched file is at most 1000.</automated>
  </verify>
  <done>The seed precedes the client start; every doc contract that described the post-hop merge is rewritten; DownloadsFeatureTests is fully green with the hop cases unchanged; no new warnings; LINT clean; one signed commit (for example "Seed continued session before client start").</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: A deleted gallery leaves the continued session entirely (B-1, B-2)</name>
  <files>AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionDeletion.swift, AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift, AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift, AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift, AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift, AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionDeletionTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureManifestPatching.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift</files>
  <read_first>
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift `delete(gid:)`; DownloadClient+Folders.swift `deleteFolder(name:)`
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift header, `coverageGalleryCount`, `reconcileRetiredSessionPages` (doc and body), `pushContinuedSessionProgress` floor paragraph
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift `withdrawingCountedBasisMovement` (whole doc)
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift `lastPushedCompletedPageCount`, `retiredSessionPages`, `observedSchedulablePages`, `observedIncompleteSessionGenerations` docs; `advanceQueueIntentGeneration`
    - .planning/phases/15-continued-background-downloads/15-55-PLAN.md and 15-UAT.md G-15-2C entry (D-G2C-01 history)
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift (the two delete cases, `departedPair`, the private manifest helpers, the hop case's start-gate staging), DownloadContinuedSessionBasisTests.swift (parked active-run staging with `BlockingRunnerControl`), DownloadFeatureTestHelpers.swift (`makeQueuedCoordinator`, `makeStartPayload`, `expectTheCompletedSeriesNeverLosesGround`), DownloadSourceInventoryTests.swift (floor census, client-double censuses: use only `BackgroundProcessingClientSpy`, never a hand-built client double)
    - Skills to load: swift-concurrency-pro, swift-testing-pro
  </read_first>
  <behavior>
    - Two galleries, large 10 pages with 6 done and small 4 pages with 0 done. The opening push reads "6 / 14 pages · 2 galleries". After `delete(gid: large)` the last push reads "0 / 4 pages · 1 gallery". After small reaches 2 of 4, a push reads "2 / 4 pages · 1 gallery", not the absorbed "6 / 6 pages · 1 gallery".
    - Same staging, with large first paused (retired: "6 / 10 pages · 2 galleries") and alternatively first completed and settled (retired whole: "10 / 14 pages · 2 galleries"), then deleted: "0 / 4 pages · 1 gallery", and later work on small is visible as above (parameterized over the prior departure, one fixture per case).
    - Deleting the only gallery drains the session: terminal pair "0 / 1 pages · 0 galleries", `finishSuccesses == [true]`, no rejected updates (the empty-denominator display clamp is the existing drain behavior).
    - Deleting the ACTIVE gallery (parked run released on cancellation, observed by a push first) removes it from X, Y and N, and later work on the survivor is not absorbed.
    - Deletion inside the client-start hop (start gate armed, `delete` run between `gate.entered()` and `gate.release()`): the start submission still reads "6 / 14 pages · 2 galleries", the first push after the start reads "0 / 4 pages · 1 gallery", and later work is not absorbed. This case fails with Task 2 reverted.
    - Rejoin: after deleting large, enqueueing the same gid again through the public enqueue route with `makeStartPayload` yields a push reading "0 / 14 pages · 2 galleries"; at 3 of 10 for the new large it reads "3 / 14 pages · 2 galleries".
    - Folder deletion (B-2): `deleteFolder(name: "Folder")` holding both galleries drains to "0 / 1 pages · 0 galleries" instead of retiring large's 6 pages.
    - Unchanged: the pause case in DownloadContinuedSessionLedgerTests still reads `departedPair` ("6 / 10 pages · 2 galleries").
    - The floor-writer census reads 4 in `+ContinuedSession.swift`, 1 in `+ExecutionSupport.swift`, 1 in `+ContinuedSessionDeletion.swift`, total 6. The bracket census is unchanged at 8.
  </behavior>
  <action>
Implement B-1 and B-2 at the deletion boundary, exactly as "Design notes / Bug B" describes. Write the failing tests first.

1. Boundary. Create `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionDeletion.swift` with a module-internal, synchronous, actor-isolated `func withdrawDeletedGalleryFromSession(gid: String)` on `DownloadCoordinator`. It returns at once when `continuedSessionID` is nil. Otherwise it removes `gid` from `retiredSessionPages` and from `observedSchedulablePages` (always both), and subtracts the sum of what the two removals returned from `lastPushedCompletedPageCount`, unclamped, like the D-G7-01 withdrawal. It touches no file, no index record, no queue, no `observedIncompleteSessionGenerations`, and no run basis. Its doc comment is the single full statement of the rule and must cover:
   - B-1 (261117-tyj; owner decision), with the accepted one-time step back;
   - why the boundary, not the reconcile, classifies the reason;
   - why "ledger entry, else last observation" is exactly what the session counts (mutual exclusivity by reconcile's construction);
   - why the call is synchronous with the record removal, and how a push during the deletion's own awaits is answered by the ledger branch;
   - the hop (seeded before it, Task 2);
   - over-withdrawal being inert and under-withdrawal impossible;
   - why the generation map is not cleared (CR-02 handles the rejoin);
   - the displaced pre-deletion frame across a push's client hop, repainted by the deletion's own convergence push;
   - that it is a floor writer owned by the census;
   - that it must stay outside any D-G7-01 bracket (none of its callers opens one);
   - which paths call it and which do not: `delete(gid:)`'s success path and `deleteFolder(name:)`'s per-gallery removal (B-2) call it; the not-found and failed-removal branches remove no record here.
2. Call sites. In `delete(gid:)`'s success path, call the boundary on the line right after the index record is removed, before `releaseScheduling(gid:)`, with a one-line comment pointing to the rule. In `deleteFolder(name:)`'s per-gallery loop, do the same right after each record removal, because deleting a folder is a user deletion too (per B-2). Add no other call site.
3. Rewrite, not annotate, every doc contract B-1 changes, keeping each file at or under 1000 lines (tighten prose; point to the boundary's doc instead of repeating it):
   - the file header's D-G2-01 and D-G2C-01 paragraphs (a user-deleted gallery is the one gallery that leaves rather than retires; coverage still means live plus positive ledger entries, and a deleted gallery is in neither);
   - `coverageGalleryCount`'s doc (one sentence for the deleted gallery);
   - `reconcileRetiredSessionPages`'s doc: the D-G2-01 formula's list of departures it covers (completion, pause, the queued-work-item cancel, the expiration pause-all, and a record dropped at a scan boundary); reason 1's wording about deleted galleries; the no-departure-reason paragraph's list of treated-alike departures (the reconcile still classifies nothing, because a user deletion never reaches it); the never-rewinds claim, now true for every departure except a user deletion's owner-accepted step;
   - the code comment on the no-record branch (a record that vanished without this session's deletion boundary);
   - `pushContinuedSessionProgress`'s floor paragraph (the boundary is the other deliberate withdrawal);
   - the paragraph of `withdrawingCountedBasisMovement`'s doc that excludes deletions from the withdrawal. A deletion is still not a movement the bracket may wrap, and a vanished reading still reads as the before-count, but now because the deletion boundary withdraws a user deletion's count and a scan-boundary disappearance is valued once by the reconcile;
   - `lastPushedCompletedPageCount`'s writer list (six writers; add the boundary as writer 6; correct the bracket call-site sentence to seven production sites, adding `+WholesaleAbsenceEvidence.swift`'s stop-time write-back, plus the probe);
   - `retiredSessionPages`'s doc (a deletion removes the entry);
   - `observedSchedulablePages`'s doc (its departure-path list no longer includes a user deletion, which the boundary removes instead).
   Verify with `grep -n -i "delet" AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` that every remaining mention of deletion agrees with B-1. Mentions about working-folder or page-file deletion are unrelated.
4. Tests.
   - Move the private `completeManifest` and `patchManifest` helpers out of DownloadContinuedSessionLedgerTests into a new `DownloadFeatureManifestPatching.swift` extension on `DownloadFeatureTestCase`. DownloadFeatureTestHelpers.swift is at 996 lines.
   - Move the two existing delete cases out of DownloadContinuedSessionLedgerTests and rewrite them, not supplement them, into the new `DownloadContinuedSessionDeletionTests.swift` with the B-1 expectations. Add the remaining behavior cases there.
   - Rewrite LedgerTests' suite header (galleries leave "by being deleted" and the pause-and-delete paragraph) and `departedPair`'s doc so they describe the pause route only and point to the deletion suite.
   - Assert each deletion case's series per regime: run `expectTheCompletedSeriesNeverLosesGround` on the pushes recorded before the `delete` call, assert the post-deletion pair exactly, then assert that later work raises it. Never run the guard across the deliberate step.
   - Update DownloadSourceInventoryTests' `expectedFloorWriters` (add `"DownloadClient+ContinuedSessionDeletion.swift": 1`) and `expectedFloorWriterTotal` (6), and rewrite the census doc to name the boundary. The file is at exactly 1000 lines, so the rewrite must not add net lines.
  </action>
  <verify>
    <automated>Run BUILD, LINT and TEST with N=3 and `-only-testing:DownloadsFeatureTests`; then the presence gates `grep -v '^[[:space:]]*//' AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift | grep -q 'withdrawDeletedGalleryFromSession(gid: '`, the same command on AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift, and `grep -q 'expectedFloorWriterTotal = 6' AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` (all three fail at HEAD); the absence gates `! grep -q 'Deletions never withdraw' AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift`, `! grep -q 'pause, delete, cancel and expiration' AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` and `! grep -q 'pause, delete, the queued-work-item cancel' AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` (all three fail at HEAD); and `wc -l` of every touched file is at most 1000.</automated>
    <human-check>On a device (owner, end of quick task): queue three galleries, start, background the app; delete one (finished or mid-run) from the app; the card's "N galleries" drops by one and stays there, X / Y no longer include it, and the bar keeps rising with the remaining work.</human-check>
  </verify>
  <done>A user deletion, single or by folder (B-2), removes the gallery from X, Y and N in every state and gives its counted pages back to the floor; paused, completed, cancelled and expired departures are unchanged; every B-1-affected doc contract is rewritten; DownloadsFeatureTests is green including the new suite; censuses updated; no new warnings; LINT clean; one signed commit (for example "Drop deleted galleries from the session").</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app defaults domain → Library state | The remembered picker choice is read back when the compact layout first resolves an empty selection; it may be corrupt, from a newer build, or hand-edited on a jailbroken device. |
| user deletion → continued-session accounting | A user action rewrites session-scoped accounting that the system scheduler reads as task progress. |
| UI-test launch environment → app storage | Automated launches share the app's real defaults domain with each other. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261117-tyj-01 | Tampering | `LibraryPickerChoice` decode | low | mitigate | Strict decoder: `SchemaVersion` range check, a missing or malformed group throws, the favorites index must be a `FavoritesType` index; Sharing falls back to `nil` (nothing remembered, Favorites at the current index); covered by LibraryPickerChoiceTests. |
| T-261117-tyj-02 | Information disclosure | persisted folder name in defaults | low | accept | On-device only, in the same domain as `Setting`, under the already-declared UserDefaults API reason; never logged or sent to analytics. |
| T-261117-tyj-03 | Denial of service | floor withdrawal at deletion | medium | mitigate | An under-withdrawal would let the floor absorb later work, and the scheduler then force-expires a "stalled" task. The withdrawal reads exactly the session's count (ledger entry, else observation), runs synchronously with the record removal, the hop case is closed by Task 2, and the floor census pins the writer. |
| T-261117-tyj-04 | Tampering | gallery folders (deletion invariant) | high | mitigate | The boundary performs no file operation and only runs after the existing removal succeeded; folder deletion scope is unchanged (AGENTS.md download-folder invariant). |
| T-261117-tyj-05 | Tampering | cross-test leakage of the remembered picker choice | low | mitigate | `StoragePreset.apply()` clears it for every stubbed launch; hosted tests and captures use in-memory storage; unit tests that touch it inject their own `UserDefaults.inMemory`, one suite per case. |
| T-261117-tyj-SC | Tampering | dependency installs | low | accept | No package, pip or npm installs in this plan. |
</threat_model>

<verification>
After Task 3, run the whole FeatureTests plan once on `EhPanda iPhone Air` (iOS 27.0) with
`-skip-testing:VisualSnapshotTests`, because that target needs the pinned regression environment (it
was compiled by every BUILD gate). Use test-without-building on `.build/261117-tyj/dd` with result
bundle `.build/261117-tyj/final.xcresult`, and read the per-target counts from the xcresult summary.
Then delete `EhPanda iPhone Air` if this plan created it, and confirm `git status` shows only the
three commits' files plus the untracked quick-task folder.

## Multi-Source Coverage Audit

| Source | Item | Covered by |
|--------|------|------------|
| GOAL | Library picker remembers the last selection | Task 1 |
| GOAL | Card's galleries count excludes deleted galleries | Tasks 2 and 3 |
| REQ / CONTEXT | A-1: persist the full LibraryGroup (source plus category or folder) | Task 1, steps 1 to 4 (`LibraryPickerChoice.group`) |
| CONTEXT | A-1: restore on the iPad / Duo sidebar layout too | Superseded by A-2 (sidebar launches restore nothing); Task 1 sidebar-launch case |
| CONTEXT | A-1: vanished folder falls back to All via the DownloadsReducer route | Task 1 (fallback case) |
| CONTEXT | A-1: follow AppSharedKeys conventions (appStorage, strict decode, SchemaVersion) | Task 1, steps 1 and 2 |
| REQ / CONTEXT | A-2: remember only the compact picker's choice, including the category or folder chosen there | Task 1, step 4 (the compact-only hook) and the compact-change cases |
| CONTEXT | A-2: sidebar selections neither persisted nor overwriting; sidebar launches restore nothing | Task 1, step 4 and the sidebar-change and sidebar-launch cases |
| CONTEXT | A-2: an empty compact selection opens the remembered choice, Favorites at the current index only when nothing is remembered | Task 1, step 4 (`showInitialSelection`) and the cold-launch, fold and phone-entry cases |
| CONTEXT | A-2: in-process carry-over between layouts stays as today | Task 1 (selection unchanged in type; carry-over case) |
| REQ / CONTEXT | B-1: deleted gallery leaves X, Y and N in every state | Task 3 (state cases) |
| CONTEXT | B-1: floor gives back the deleted gallery's counted portion | Task 3, step 1 and the "later work" assertions |
| CONTEXT | B-1: pause, completion, cancel and expiration unchanged | Task 3 (pause case kept on `departedPair`; no change to reconcile logic) |
| CONTEXT | B-1: rewrite the D-G2-01, D-G2C-01 and D-G7-01 contracts, not annotate | Task 3, step 3 (and Task 2 for the seed contracts) |
| REQ / CONTEXT | B-2: deleting a download folder is a user deletion too | Task 3, step 2 (`deleteFolder(name:)` call site) and the folder-deletion case |
| REQ / CONTEXT | B-3: seed moved ahead of the client start's hop, so a deletion in the start window leaves the session | Task 2, and Task 3's hop-deletion case |
| Orchestrator | Hop interleaving, run race, same-gid rejoin, single coverage definition, floor census, sibling rule | Tasks 2 and 3 (hop, active-run and rejoin cases; coverage untouched; census updated; boundary outside any bracket) |
| Deferred | Queue operations; save keyword as saved search | Not planned (deferred by the owner) |

## Open questions for the owner

None.
</verification>

<success_criteria>
- A-1 / A-2: on the compact layout the Library reopens on the exact group (source plus category or
  folder) last chosen there; sidebar selections are never remembered and sidebar launches restore
  nothing; carry-over is unchanged; a vanished folder becomes All and stays All; UI tests and
  captures stay isolated.
- B-1 / B-2 / B-3: deleting a gallery, singly or with its folder, removes it from X, Y and N in
  every state, including inside the start hop,
  across its own run's cancellation, and on a same-gid rejoin; the floor gives its counted pages back;
  every other departure is unchanged.
- Every B-1-changed doc contract (D-G2-01, D-G2C-01, D-G7-01, the floor writer inventory, the seed
  rules) is rewritten, and the WHY of the new persistence design is documented.
- Three signed commits; the FeatureTests plan (VisualSnapshotTests skipped, compiled) is green; no new
  warnings; SwiftLint clean with no suppression; no new `.serialized`; no file above 1000 lines.
</success_criteria>

<output>
Create `.planning/quick/261117-tyj-fix-library-picker-reset-and-download-ca/261117-tyj-SUMMARY.md` when done
</output>
