---
phase: 261122-iew-e-hentai-settings-saves-each-option-on-i
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Package.swift
  - AppPackage/Sources/EhSettingClient/.swiftlint.yml
  - AppPackage/Sources/EhSettingClient/EhSettingClient.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer+Option.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
  - AppPackage/Sources/AppComponents/CategoryView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Tests/SettingFeatureTests/EhSettingReducerTests.swift
  - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
  - AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift
  - .planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md
autonomous: true
requirements: [QUICK-261122-iew]

estimate:
  tokens: 190000
  raw_tokens: 190000
  tasks: 2
  confidence: low

must_haves:
  truths:
    - "Every option of the E-Hentai Settings form saves on its own (D-02): toggles, pickers (menu, inline, segmented), category cells and excluded-language cells on change; sliders once, when the drag ends; Ratings Color and each favorites name on Return; the Excluded Uploaders editor when focus leaves it. Each save posts the whole current form through `EhSettingClient.submitChanges` (D-04)."
    - "The page has no toolbar items: the Save and Website buttons, the web view sheet and its reducer path are gone (D-05)."
    - "While a save or profile action is unanswered, only its own control is disabled; a `profile` update disables the profile section's five controls; every other control stays usable; no LoadingView, spinner, alert or toast appears for it (D-03). LoadingView shows only for `loadingState == .loading`, and the first load keeps its loading and failed states."
    - "Only the most recently started request's answer is applied to the form; an older answer only re-enables its option. A failed latest request quietly refetches the settings under the same revision, keeps its option disabled until the refetch returns, and its success is applied; a failed refetch only re-enables the option (D-04)."
    - "No site answer (first load, save answer, profile-action answer, refetch) ever starts a save: the save trigger is `onChange` on `BindingReducer` alone, and the draft controls follow the model without writing it (D-02)."
    - "An option save's answer leaves `editingProfileName` as typed; the first load and profile-action answers reset it to the selected profile's name (D-04)."
    - "Tests decide every request's outcome through the injected `EhSettingClient`, whose test value is unimplemented; the SettingFeatureTests target passes with tests in parallel, no `.serialized`, no lint suppression and no new build warning (D-06)."
  artifacts:
    - path: "AppPackage/Sources/EhSettingClient/EhSettingClient.swift"
      provides: "The EhSettingClient dependency: fetchSettings, submitChanges, performProfileAction; live, noop, unimplemented, failing(_:); EhSettingClientKey; DependencyValues.ehSettingClient"
      contains: "public struct EhSettingClient: Sendable"
    - path: "AppPackage/Sources/EhSettingClient/.swiftlint.yml"
      provides: "The project lint rules for the new module"
      contains: "parent_config: ../../../.swiftlint.yml"
    - path: "AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer+Option.swift"
      provides: "EhSettingReducer.Option (one case per saved control) and Option.changes(from:to:), the only option-to-field mapping"
      contains: "public enum Option: Hashable, Sendable"
    - path: "AppPackage/Tests/SettingFeatureTests/EhSettingReducerTests.swift"
      provides: "Swift Testing reducer tests for the first load, per-option saves, latest-wins answers, the quiet refetch and Option.changes"
      contains: "struct EhSettingReducerTests"
  key_links:
    - from: "AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift"
      to: "AppPackage/Sources/EhSettingClient/EhSettingClient.swift"
      via: "@Dependency(\\.ehSettingClient) and ehSettingClient.fetchSettings / submitChanges / performProfileAction"
      pattern: "ehSettingClient\\.submitChanges"
    - from: "AppPackage/Sources/EhSettingClient/EhSettingClient.swift"
      to: "AppPackage/Sources/NetworkingFeature/Request+Account.swift"
      via: "live functions that build EhSettingRequest, SubmitEhSettingChangesRequest and EhProfileRequest exactly as the reducer did"
      pattern: "SubmitEhSettingChangesRequest\\("
    - from: "AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift"
      to: "AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer+Option.swift"
      via: "BindingReducer().onChange(of: \\.ehSetting) calling Option.changes(from:to:)"
      pattern: "Option\\.changes\\(from:"
    - from: "AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift"
      to: "AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift"
      via: "each control's .disabled(updatingOptions.contains(...)) reading State.updatingOptions"
      pattern: "updatingOptions\\.contains\\("
---

<objective>
Make the E-Hentai Settings page save each option on its own, following the owner-approved Screens v1.1.0 design and
the locked decisions D-01 to D-07 in `261122-iew-CONTEXT.md`. A change to any control saves to the site at once.
There is no Save or Website button, no page-wide loading state for a save, and no error handling for saves. Only the
changed option's control is disabled until the site answers, and the form then shows the site's latest state.

Purpose: one tap is one saved setting, with no separate Save step and no stale form.
Output: the `EhSettingClient` module (D-06), the per-option save in `EhSettingReducer` (D-01 to D-05), draft sliders
and text fields (D-02), the tests (D-06), the doc comments (D-07), two commits and `261122-iew-SUMMARY.md`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/quick/261122-iew-e-hentai-settings-saves-each-option-on-i/261122-iew-CONTEXT.md
@AGENTS.md
@.swiftlint.yml
@AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
@AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
@AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift
@AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
@AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
@AppPackage/Sources/GalleryClient/GalleryClient.swift
@AppPackage/Sources/NetworkingFeature/Request+Account.swift
@AppPackage/Sources/AppModels/Support/EhSetting.swift
@AppPackage/Sources/AppComponents/CategoryView.swift
@AppPackage/Sources/AppComponents/SettingTextField.swift
@AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift
@AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift
@AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift

Read only the frontmatter and the top of `.planning/STATE.md`; it is long. Also read the local `AGENTS.local.md`
(commit identity, signing, privacy in generated docs). Do not read `AIRBUILD.md`.

### Execution fidelity

Follow this plan exactly. If you cannot proceed exactly as written for any reason, pause at once and ask the
orchestrator for instructions. That covers ambiguity, conflicting requirements, missing information, unexpected
repository state, a compiler error or lint rule that forces a different shape, a test that cannot be written as
described, and any other deviation. Do not choose, invent or implement a solution or deviation on your own. Never
suppress or disable a lint rule, never add `.serialized`, and never add `withKnownIssue`.

### Facts verified at planning (HEAD `102d1709c`, branch `quick/261122-iew-ehsetting-autosave`)

- **Requests.** Inside `AppPackage/Sources/SettingFeature/EhSetting/`, the page's three requests are built only in
  `EhSettingReducer.swift` (one `EhSettingRequest`, one `SubmitEhSettingChangesRequest`, one `EhProfileRequest`).
  `SettingReducer+Body.swift` builds its own `EhProfileRequest` for the app's EhPanda profile. That one is out of
  scope and stays as it is. `SubmitEhSettingChangesRequest` and `EhProfileRequest` both parse their response with
  `Parser.parseEhSetting`, so each answer is the site's settings page after the change (D-04).
- **TCA `onChange`.** The checked-out TCA documents that `onChange` "is only capable of detecting changes made by the
  reducer it is directly attached to". Its `(oldValue, newValue) -> Reducer` overload is soft-deprecated
  (`deprecated: 9999`). Use the current overload `onChange(of:) { oldValue, state in ... return effect }`, as
  `AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift` does. This is D-02's `BindingReducer().onChange`
  written with the non-deprecated overload.
- **`@State` is a macro in SDK 27.** Declare a seeded `@State` without an initial value and assign it last in an
  explicit `init` with `_name = State(initialValue: ...)`, as `HomeFeature/GalleryCardCell.swift` does. A view that
  holds such a `@State` gets no usable memberwise init, so it needs an explicit `init`.
- **Unused `public import` warns.** Once `Destination` (which carried a `URL`) is gone, no public declaration of
  `EhSettingReducer.swift` uses Foundation, so `public import Foundation` there becomes `import Foundation`.
- **Already dead, left alone (D-05).** `setKeyboardHidden` is never sent. The reducer's
  `@Dependency(\.cookieClient)` is unused; leave both.
- **The profile picker.** `EhProfileSection`'s `.onChange(of: ehProfile)` sends a profile switch whenever the selected
  profile changes, including when a site answer changes it. D-02 keeps it as it is.
- **port/462 collision.** The `port/462` branch rewrites `FavoritesSection`'s `ForEach` as
  `ForEach(Array(tuples.enumerated()), id: \.element.0) { index, tuple in` followed by `let nameBinding = tuple.1`,
  and recolours the dot. Task 2 adopts that exact `ForEach` header and `nameBinding` line, so a later merge differs
  only in the dot's colour and the field lines.
- **Snapshot scenarios.** `ScenarioCatalog+Settings.swift` builds the page state with `setEhSetting(_:)` for
  `settings-pages-site-settings`, `-confirmation` and `-error`. Those images lose the two toolbar buttons. That is an
  expected visual change; refreshing the snapshot baseline is outside this task. Record it in the SUMMARY.
- **Stale prose this plan must fix.** `SettingReducerNavigationTests.swift` lines 134-136 say a store-level push of
  `.ehSetting` would issue a real request because the reducer builds `EhSettingRequest` itself. `ExcludeLanguageToggle`'s
  doc comment (`EhSettingView+Sections3.swift` lines 274-280) claims a site answer never flips an exclusion. After
  this task a quiet refetch can flip one. `SCROLL-EDGE-INVENTORY.md` lines 45 and 56 list the EhSetting web view
  sheet.
- **Dead string after the toolbar goes.** The `save` key in `AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings`
  (lines 4723-4764, from `"save" : {` to its closing `},`) is used only by the Save button. `website` is still used
  by `AccountSettingView` and `LoginView` and stays.
- **Swift Testing gotcha.** `#expect(value.mutatingCall() == x)` does not compile; evaluate into a `let` first.

### Verification conventions (every command runs from the checkout root)

- Logs go to `.build/261122-iew/` (`.build` is gitignored). Run `mkdir -p .build/261122-iew` first.
- **Simulator.** Use the simulator id the orchestrator gives as `SIM_ID`. At planning it is the shut-down
  `EhPanda iPhone Air (261122-iew)`. Never touch another project's simulator.
- **One test invocation at a time.** Before every `xcodebuild test` or `build-for-testing`, wait until `pgrep -x
  xcodebuild` prints nothing. Run long commands in the background and wait for them to finish. Never kill an
  xcodebuild process.
- **BUILD (N).** `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination
  'generic/platform=iOS Simulator' > .build/261122-iew/build-N.log 2>&1`. It passes when the log contains
  `** BUILD SUCCEEDED **` and `grep -E '(^|: )(warning|error): ' .build/261122-iew/build-N.log | grep -v -e
  'SwiftUINavigation+.swift:10:14' -e 'DownloadClient+Networking.swift:153' | sort -u` prints nothing. Any other
  line, even from a file this plan does not touch, means stop and ask.
- **LINT (N).** `SWIFTLINT=$(ls $HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint | head -1);
  "$SWIFTLINT" lint --strict --quiet AppPackage/Sources AppPackage/Tests > .build/261122-iew/lint-N.txt 2>&1; echo $?`
  must print `0`, and the file must be empty. The build log does not carry the lint plugin's output, so this
  command is the lint gate, Tests included.
- **TEST (N).** `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination
  "platform=iOS Simulator,id=$SIM_ID" -only-testing:SettingFeatureTests -collect-test-diagnostics never >
  .build/261122-iew/test-N.log 2>&1`. It passes when the log contains `** TEST SUCCEEDED **` and a Swift Testing
  `Test run with <n> tests` line that reports passing, with no `✘` line. Record `<n>` per run in the SUMMARY.
- **TESTBUILD (N).** `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests
  -destination 'generic/platform=iOS Simulator' > .build/261122-iew/testbuild-N.log 2>&1`. It passes on
  `** TEST BUILD SUCCEEDED **` with the same warning filter as BUILD. It compiles every FeatureTests target,
  VisualSnapshotTests and NetworkingFeatureTests included.
- **Baseline (once, before Task 1, untouched tree).** Run BUILD, LINT and TEST with N=baseline. If any fails, stop
  and ask. Record the test count.
- **Commit (end of each task).** Run `git status --short` first. It may list only the task's `<files>` and the
  untracked `.planning/quick/261122-iew-e-hentai-settings-saves-each-option-on-i/`. If any other path changed, stop
  and ask. Stage exactly the task's files with `git add <paths>`. Commit with the message given in the task, using
  the identity, signing and timezone rules in `AGENTS.local.md`, and check them the way that file says. Never stage
  the planning directory; the orchestrator records the docs.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Tracer: the page's three requests through an injected EhSettingClient, proven by a first-load reducer test</name>
  <files>AppPackage/Package.swift, AppPackage/Sources/EhSettingClient/.swiftlint.yml, AppPackage/Sources/EhSettingClient/EhSettingClient.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift, AppPackage/Tests/SettingFeatureTests/EhSettingReducerTests.swift, AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift</files>
  <precondition>The working tree is on `quick/261122-iew-ehsetting-autosave` at `102d1709c` or a descendant, the Baseline run passed, and the orchestrator has given `SIM_ID`.</precondition>
  <read_first>AppPackage/Sources/GalleryClient/GalleryClient.swift (the precedent: struct of `@Sendable … async throws(AppError)` closures, `private static func` live bodies, `IssueReporting.unimplemented("Client.closure", throwing: AppError.unknown)`, the key and `DependencyValues` accessor), AppPackage/Package.swift lines 85-100 and 426-440 (how `galleryClient` is registered), AppPackage/Sources/NetworkingFeature/Request+Account.swift lines 247-380</read_first>
  <action>
Per D-06, add the client module and move the page's three requests onto it. App behavior does not change.

1. `AppPackage/Sources/EhSettingClient/.swiftlint.yml` holds exactly the one line `parent_config: ../../../.swiftlint.yml`.

2. `AppPackage/Sources/EhSettingClient/EhSettingClient.swift`. Imports: `public import AppModels`,
   `public import ComposableArchitecture`, `import NetworkingFeature`. Its public types use only AppModels and TCA
   types, so the NetworkingFeature import stays internal.
   - `public struct EhSettingClient: Sendable` with three `public var` closures, each
     `@Sendable (…) async throws(AppError) -> EhSetting` with `///` docs:
     `fetchSettings: (_ host: GalleryHost)` (the first load, and the refetch after a failed save);
     `submitChanges: (_ host: GalleryHost, _ ehSetting: EhSetting)` (posts the whole form);
     `performProfileAction: (_ host: GalleryHost, _ action: EhProfileAction?, _ name: String?, _ set: Int)`.
   - The type's `///` doc states why it exists, in the shape of GalleryClient's. A reducer that builds its request
     inside an effect leaves a test no way to choose the outcome. Through this dependency a test states each answer,
     and the unimplemented test value reports any request a test did not stub. `live` builds exactly the requests
     the reducer built before. The EhPanda profile request in `SettingReducer+Body.swift` is not part of this
     client.
   - `public static let live` binds three `private static func`s by reference. They are `settings(host:)`,
     `changes(host:ehSetting:)` and `profileAction(host:action:name:set:)`, and each returns
     `try await EhSettingRequest(host: host).response()`, `try await SubmitEhSettingChangesRequest(host: host,
     ehSetting: ehSetting).response()` and `try await EhProfileRequest(host: host, action: action, name: name, set:
     set).response()` respectively. Pass no session argument.
   - `public static let unimplemented`: every closure is `IssueReporting.unimplemented("EhSettingClient.<closure>",
     throwing: AppError.unknown)`.
   - `public static let noop` (the preview value) is a site that accepts every change. `submitChanges` answers the
     `ehSetting` it was given. `fetchSettings` and `performProfileAction` answer `EhSetting.empty`. Write each closure
     as a literal with an explicit signature, for example `{ (_: GalleryHost) async throws(AppError) -> EhSetting in
     .empty }`.
   - `public static func failing(_ error: AppError) -> Self` fails every closure with `error` and reports nothing.
     Use explicit-signature literals the same way.
   - `public enum EhSettingClientKey: DependencyKey` with `liveValue = EhSettingClient.live`,
     `previewValue = EhSettingClient.noop` and `testValue = EhSettingClient.unimplemented`, plus
     `extension DependencyValues { public var ehSettingClient: EhSettingClient }` with get/set through the key.

3. `AppPackage/Package.swift`:
   - Add `case ehSettingClient = "EhSettingClient"` to `enum Module` directly after `case downloadsFeature`.
   - Add a `.target(module: .ehSettingClient, dependencies: [.module(.appModels), .module(.networkingFeature),
     .targetDependency(.composableArchitecture)])` directly before the `galleryClient` target. Give it a two-line
     comment in the `galleryClient` comment's style: the E-Hentai Settings page's three requests, behind one
     dependency so a test decides their outcome.
   - Add `.module(.ehSettingClient),` directly after `.module(.dfClient),` in both the `settingFeature` target's and
     the `settingFeatureTests` target's dependencies. Nothing else in the file changes.

4. `EhSettingReducer.swift`: add `import EhSettingClient` between `import CookieClient` and
   `public import Foundation`, and add `@Dependency(\.ehSettingClient) private var ehSettingClient` after the
   existing dependencies. In the three effects, replace only the request expression with
   `try await ehSettingClient.fetchSettings(host)`, `try await ehSettingClient.submitChanges(host, ehSetting)` and
   `try await ehSettingClient.performProfileAction(host, action, name, set)`. Keep the guards, `.cancellable`, the
   `Result.Swift::init` wrappers and the sends as they are. Remove `import NetworkingFeature`, which nothing else in
   the file uses.

5. New `AppPackage/Tests/SettingFeatureTests/EhSettingReducerTests.swift`. Imports in this order: AnalyticsClient,
   AppModels, ComposableArchitecture, EhSettingClient, `@testable import SettingFeature`, Testing. Declare
   `@Suite struct EhSettingReducerTests`, with `@MainActor` on the store-driving members, not on the type (same
   comment as `SettingPresentationTests.swift`'s header). Add a fixture
   `static func site(profileName: String = "EhPanda") -> EhSetting` that returns
   `.empty(ehProfiles: [EhProfile(value: 1, name: profileName, isSelected: true)])`. Add two tests, each with its own
   `TestStore(initialState: EhSettingReducer.State(), reducer: EhSettingReducer.init)`, `$0.analyticsClient = .noop`,
   and the client closure it needs stubbed with an explicit-signature literal:
   - `theFirstLoadAppliesTheSiteSettings`: `fetchSettings` answers `site()`. Send `.fetchEhSetting` and expect
     `loadingState = .loading`. Receive `\.fetchEhSettingDone` and expect `loadingState = .idle`,
     `ehSetting = site()`, `ehProfile` = its one profile and `editingProfileName = "EhPanda"`.
   - `aFailedFirstLoadShowsTheFailure`: `$0.ehSettingClient = .failing(.networkingFailed)`. Send `.fetchEhSetting`
     (`.loading`), then receive `\.fetchEhSettingDone` and expect `loadingState = .failed(.networkingFailed)`.

6. `SettingReducerNavigationTests.swift` lines 134-136: replace that three-line comment with two lines saying that
   `.ehSetting`'s push is asserted at the mapping level in `SettingPresentationTests`, and that its first load goes
   through `EhSettingClient`, which `EhSettingReducerTests` drives with a stubbed client.

Commit message: `Inject E-Hentai settings requests`.
  </action>
  <verify>
    <automated>BUILD 1, LINT 1 and TEST 1 pass (Verification conventions); EhSettingReducerTests' two cases are in the passing count. Then each gate prints its expected value:
`grep -v '^\s*//' AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift | grep -cE 'EhSettingRequest\(|SubmitEhSettingChangesRequest\(|EhProfileRequest\('` [HEAD=3 EXPECT==0];
`grep -v '^\s*//' AppPackage/Sources/EhSettingClient/EhSettingClient.swift | grep -cE 'EhSettingRequest\(|SubmitEhSettingChangesRequest\(|EhProfileRequest\('` (the file is absent at HEAD) [HEAD=0 EXPECT==3];
`grep -c 'ehSettingClient\.' AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift` [HEAD=0 EXPECT==3];
`grep -c 'case ehSettingClient = "EhSettingClient"' AppPackage/Package.swift` [HEAD=0 EXPECT==1];
`grep -c 'module: \.ehSettingClient,' AppPackage/Package.swift` [HEAD=0 EXPECT==1];
`grep -c '\.module(\.ehSettingClient)' AppPackage/Package.swift` [HEAD=0 EXPECT==2];
`grep -cx 'parent_config: ../../../.swiftlint.yml' AppPackage/Sources/EhSettingClient/.swiftlint.yml` (the file is absent at HEAD; it must hold only this line) [HEAD=0 EXPECT==1];
`grep -c 'import NetworkingFeature' AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift` [HEAD=1 EXPECT==0];
`grep -c 'never overrides' AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift` [HEAD=1 EXPECT==0];
`grep -c 'EhSettingReducerTests' AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift` [HEAD=0 EXPECT==1];
after the commit, `git log -1 --format=%s` [EXPECT=`Inject E-Hentai settings requests`].</automated>
  </verify>
  <done>The page's three requests reach the network only through `EhSettingClient.live`. A test states each outcome, and an unstubbed request is reported. The first-load tests pass through the injected path. The app behaves exactly as before, and the commit is signed with +08:00 dates.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Save each option on its own: Option identity, per-option revisions, drafts and per-control disabling</name>
  <files>AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer+Option.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift, AppPackage/Sources/AppComponents/CategoryView.swift, AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings, AppPackage/Tests/SettingFeatureTests/EhSettingReducerTests.swift, AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift, .planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md</files>
  <precondition>Task 1 is committed (`git log -1 --format=%s` prints `Inject E-Hentai settings requests`).</precondition>
  <read_first>AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift (as Task 1 left it), the four view files, AppPackage/Sources/AppComponents/CategoryView.swift lines 88-132, AppPackage/Sources/AppComponents/SettingTextField.swift, AppPackage/Tests/SettingFeatureTests/AccountSettingReducerTests.swift lines 10-40 (the `AsyncStream.makeStream()` gating idiom), AppPackage/Sources/HomeFeature/GalleryCardCell.swift lines 220-230 (seeded `@State`)</read_first>
  <behavior>
    Write these cases in `EhSettingReducerTests` first and watch them fail (a compile failure counts as red); then implement until they pass. One commit at the end.
    - Option.changes: equal settings give `[]`. Changing `galleryName`, `ratingsColor` and `useMultiplePageViewer` (nil to true) gives `[.galleryName, .ratingsColor, .useMultiplePageViewer]`, in form order. `disabledCategories[3]`, `favoriteCategories[0]`, `favoriteCategories[9]` and `excludedLanguages[49]` changed give `[.disabledCategory(3), .favoriteCategory(0), .favoriteCategory(9), .excludedLanguage(49)]`. An index only one side has counts (an eleventh `disabledCategories` element gives `[.disabledCategory(10)]`). Settings that differ only in `ehProfiles` give `[]`.
    - A binding change of `galleryName` sets `updatingOptions == [.galleryName]` and `latestRevision == 1`, leaves `loadingState` `.idle`, and posts the whole edited form once. Its answer, a site form that also differs in `ratingsColor`, empties `updatingOptions` and becomes `ehSetting`.
    - With two changes in flight (`galleryName` at revision 1, `showFilteredRemovalCount` at revision 2, the second post carrying both changes), the first answer only removes `.galleryName` and leaves the form as the user set it. The second answer empties the set and is applied.
    - An older answer that failed while a newer request is in flight only removes its option and starts no refetch.
    - A failed latest save keeps its option in `updatingOptions`, quietly refetches through `fetchSettings`, and the refetched settings are applied with the option removed. If the refetch also fails, the option is removed and the form keeps the user's value. `loadingState` stays `.idle` throughout.
    - A second change to an option that is already updating starts no second save: the form takes the value, but `updatingOptions` and `latestRevision` do not change and only one form is posted.
    - `fetchEhSettingDone(.success(other))` on a loaded page, with `other` different in several options, applies `other` and starts no save.
    - With `editingProfileName` set to "Typed" through its binding, an option save's answer leaves it "Typed".
    - `performAction(action: .rename, name: "Renamed", set: 1)` sets `updatingOptions == [.profile]` at revision 1. A second `performAction` while it is updating changes nothing. The answer, whose selected profile is named "Renamed", sets `editingProfileName = "Renamed"` and empties the set.
  </behavior>
  <action>
This task is one commit even though it touches 12 files. The per-option save and the draft and disabled controls
only work together: a commit with the save but without the drafts would save on every slider tick and keystroke and
fight the user's drag with site answers.

**A. `EhSettingReducer+Option.swift` (new; D-01).** `import AppModels` (internal: only the internal function uses
EhSetting). `extension EhSettingReducer { public enum Option: Hashable, Sendable { … } }`, declaring these cases in
this order, which is the form's order: `loadThroughHathSetting`, `hahRegion`, `imageResolution`,
`useOriginalImages`, `imageSizeWidth`, `imageSizeHeight`, `galleryName`, `archiverBehavior`, `disabledCategory(Int)`,
`displayMode`, `searchRangeIndicatorStyle`, `enableGalleryThumbnailSelector`, `favoriteCategory(Int)`,
`favoritesSortOrder`, `searchResultCount`, `thumbnailLoadTiming`, `thumbnailConfigSize`, `thumbnailConfigRows`,
`coverScaleFactor`, `ratingsColor`, `tagWatchingThreshold`, `tagFilteringThreshold`, `showFilteredRemovalCount`,
`excludedLanguage(Int)`, `excludedUploaders`, `viewportVirtualWidth`, `commentsSortOrder`, `commentVotesShowTiming`,
`tagsSortOrder`, `galleryPageNumbering`, `useMultiplePageViewer`, `multiplePageViewerStyle`,
`multiplePageViewerShowThumbnailPane`, `profile`. Each scalar case is named after the `EhSetting` field it saves. The
`///` doc says an option is one saved control, the unit whose control is disabled while the site answers, and that
the profile section's controls share `profile`.

Add `static func changes(from old: EhSetting, to new: EhSetting) -> [Self]` with a `///` doc. It lists the options
whose values differ, in form order. It compares each scalar field on its own and each array index by index, and an
index only one side has counts as changed. It is the only place that maps options to `EhSetting` fields, and it
never lists `profile`. Build the result in a local `var` through a local generic function, for example
`compare(_ option: Self, _ field: KeyPath<EhSetting, some Equatable>)`. Call it once per scalar case in form order,
and add the per-index options at their places through a `private static func changedIndices<Element: Equatable>(_ old:
[Element], _ new: [Element]) -> [Int]`. That function returns the offsets where `zip(old, new)` differs, followed by
`min(old.count, new.count)..<max(old.count, new.count)`. Do not use index subscripts on the arrays, per the
`unchecked_subscript_index_access` rule, and wrap single-line closures in parentheses, per
`single_line_trailing_closure`.

**B. `EhSettingReducer.swift` (D-02, D-03, D-04, D-05, D-07).**
- State: remove `@Presents public var destination` and `public var submittingState`. Add
  `public var updatingOptions: Set<Option> = []`, documented: the options whose save or profile action the site has
  not answered, each one's control disabled until then. Add `public var latestRevision = 0`, documented: the revision
  of the most recently started save or profile action. Every request posts or acts on the whole form, so the newest
  answer already shows the site after every older change. Only it is applied; an older answer only re-enables its
  option.
- Change `setEhSetting(_:)` to `mutating func setEhSetting(_ ehSetting: EhSetting, resettingProfileName: Bool)`.
  It assigns `ehSetting` and `ehProfile` as now, and sets `editingProfileName = ehProfile.name` only when
  `resettingProfileName` is true. Doc: true for the first load and profile-action answers, false for an option
  save's answer, so a profile name being typed is not wiped by an unrelated save.
- Remove the `Destination` reducer enum, `case destination`, `case presentWebView`, `case submitChanges`,
  `case submitChangesDone` and `case performActionDone`, and every match of them. Also remove the
  `.haptics(unwrapping: \.destination …)` call, `.ifLet(\.$destination …)`, the two
  `extension EhSettingReducer.Destination…` lines at the end, `@Dependency(\.hapticsClient)` and
  `import HapticsClient`. `CancelID` keeps only `fetchEhSetting`. Change `public import Foundation` to
  `import Foundation`.
- Add `case updateDone(option: Option, revision: Int, result: Result<EhSetting, AppError>)` and
  `case refetchDone(option: Option, revision: Int, result: Result<EhSetting, AppError>)`.
- Add a private helper `startUpdate(of option: Option, state: inout State, request: @escaping @Sendable () async
  throws(AppError) -> EhSetting) -> Effect<Action>`. It inserts `option` into `updatingOptions`, increments
  `latestRevision`, captures the new value as `revision`, and returns a `.run` that wraps `request()` in
  `Result.Swift::init { () async throws(AppError) in … }` and sends `.updateDone(option:revision:result:)`. Add no
  `.cancellable`: saves are never cancelled by another save (D-04).
- Body: replace the bare `BindingReducer()` with
  `BindingReducer().onChange(of: \.ehSetting) { oldValue, state in … }`. Guard that `oldValue` and `state.ehSetting`
  are both non-nil, else `.none`. Capture `state.setting.galleryHost` and the new form. For each option in
  `Option.changes(from: oldValue, to: newForm)` that is not in `updatingOptions`, call `startUpdate` with a request
  that runs `ehSettingClient.submitChanges(host, newForm)`. Return `.merge` of those effects. Its `///` comment
  (D-07) says it is attached to `BindingReducer` alone, so it sees only the form's own writes. The answers the
  `Reduce` below applies never reach it, so a site answer cannot start a save, and an option already updating is
  ignored because its control is disabled anyway.
- `.performAction(action, name, set)`: guard that `.profile` is not in `updatingOptions`, then call `startUpdate(of:
  .profile, …)` with a request that runs `ehSettingClient.performProfileAction(host, action, name, set)`.
- `.fetchEhSettingDone` success calls `setEhSetting(ehSetting, resettingProfileName: true)`. Its failure path is
  unchanged.
- `.updateDone`: if `revision != state.latestRevision`, remove the option and return `.none`. On success, remove the
  option and call `setEhSetting(ehSetting, resettingProfileName: option == .profile)`. On failure, keep the option
  and return a `.run` that fetches `ehSettingClient.fetchSettings(host)` (Result-wrapped) and sends
  `.refetchDone(option:revision:result:)` with the same revision.
- `.refetchDone`: always remove the option. Apply the settings with
  `setEhSetting(_, resettingProfileName: option == .profile)` only on success with
  `revision == state.latestRevision`; otherwise `.none`. Document the case (D-07): a failed latest request
  refetches so that a save which did not take shows the site's value; if the refetch fails too, only the control is
  re-enabled. There is no alert, toast or error state for saves.
- Replace the comment above `.signalsErrors(of: \.loadingState.failed, on: .ehSetting)` with: only the first load's
  failure is shown, so only it is counted. A failed save or profile action shows nothing, and the latest one
  quietly refetches.

**C. `EhSettingView.swift` (D-03, D-05).** Remove the web view `.sheet`, `.toolbar(content: toolbar)`, the
`// MARK: Toolbar` and the `toolbar()` function. The LoadingView's visibility becomes
`store.loadingState == .loading`. Remove `import AppTools`, `import SFSafeSymbols` and `import SFSafeSymbolsExt`,
which only the toolbar used. In `form(ehSetting:ehProfile:)`, pass `updatingOptions: store.updatingOptions` to every
section. The `ErrorView` overlay, the focus `onChange`, the scroll-edge modifiers and the title stay.

**D. Sections: add the option set and disable each control (D-03).** In every section struct, declare
`let updatingOptions: Set<EhSettingReducer.Option>` directly after `@Binding var ehSetting: EhSetting`. In
`EhProfileSection`, declare it directly after `@Binding var ehProfile: EhProfile`. Then add
`.disabled(updatingOptions.contains(.<case>))` to each control, using the case named after the field the control
binds:
- Pickers: `loadThroughHathSetting`, `hahRegion`, `imageResolution`, `galleryName`, `archiverBehavior`, `displayMode`,
  `searchRangeIndicatorStyle`, `favoritesSortOrder`, `searchResultCount`, `thumbnailLoadTiming`,
  `thumbnailConfigSize` and `thumbnailConfigRows` (on the segmented `Picker`), `commentsSortOrder`,
  `commentVotesShowTiming`, `tagsSortOrder`, `galleryPageNumbering`, `multiplePageViewerStyle`.
- Toggles: `useOriginalImages`, `enableGalleryThumbnailSelector`, `showFilteredRemovalCount`,
  `useMultiplePageViewer`, `multiplePageViewerShowThumbnailPane`.
- `ValuePicker`s: `imageSizeWidth`, `imageSizeHeight`, `coverScaleFactor`, `tagWatchingThreshold`,
  `tagFilteringThreshold`, `viewportVirtualWidth`.
- `EhProfileSection`: the Selected Profile picker, Set as Default and Delete Profile get
  `.disabled(updatingOptions.contains(.profile))`. Rename and Create New become
  `.disabled(isFocused || updatingOptions.contains(.profile))`. The profile name field stays enabled; per D-02 it is
  never saved on submit.
- Front page categories: `CategoryView.swift` gains `private let disabledIndices: Set<Int>` (`///`: the cells, by
  their index in `bindings`, whose control is disabled) and `public init?(bindings: [Binding<Bool>],
  disabledIndices: Set<Int> = [])`. Its `ForEach` becomes `ForEach(Array(tuples.enumerated()), id: \.element.1) {
  index, tuple in` around `CategoryCell(isFiltered: tuple.0, category: tuple.1).disabled(disabledIndices.contains(index))`.
  `FiltersView` and the preview stay unchanged. `FrontPageSettingsSection` passes `disabledIndices:` as
  `Set(categoryBindings.indices.filter({ updatingOptions.contains(.disabledCategory($0)) }))`.
- Excluded languages: the `rows` element type becomes `(title: LocalizedStringResource, bindings: [Binding<Bool>],
  firstIndex: Int)`, where `firstIndex` is `cells.startIndex - leading.count`. That is the `excludedLanguages` index
  of the row's column 0, so the cell at column `offset` is index `firstIndex + offset`. Add that sentence to the
  `rows` doc. `ExcludeRow` and `ExcludeLanguageBlock` gain `let firstIndex: Int` and
  `let updatingOptions: Set<EhSettingReducer.Option>` after `isFirstRow`, and both call sites pass them. Each real
  cell (`ExcludeToggle` in the row, `ExcludeLanguageToggle` in the block) gets
  `.disabled(updatingOptions.contains(.excludedLanguage(firstIndex + offset)))`. Both
  `ExcludedLanguagesSection(ehSetting: $ehSetting)` previews pass `updatingOptions: []`.
- `ExcludeLanguageToggle`'s doc comment (`EhSettingView+Sections3.swift` lines 274-280): keep the first two
  sentences. Replace the third sentence, which starts "The feedback hangs off the value", with one true statement:
  the feedback hangs off the value rather than off a wrapped binding, so it also marks a switch that a site answer
  moves back after a save that did not take. At the default size the grid's cell, whose feedback belongs to its
  tap, stays silent then.

**E. Draft controls (D-02, D-07).**
- `ValuePicker` (Sections1): keep `@Binding var value: Float` as the form's value and its init signature. Add
  `@State private var draft: Float` and `@State private var isDragging = false`, and assign
  `_draft = State(initialValue: value.wrappedValue)` last in its init. Both `Slider`s bind `$draft` and pass
  `onEditingChanged: editingChanged` as their last argument. Add
  `private func editingChanged(_ isEditing: Bool)`: it sets `isDragging = isEditing`, and when `isEditing` is false
  and `draft != value` it writes `value = draft`. The value label shows `draft`. Add
  `.onChange(of: value)`: when not dragging, `draft` takes the new value. Add `.onChange(of: draft)`: when not
  dragging and `draft != value`, it writes `value = draft` at once. Attach both to the `LabeledContent`. The second
  handler is a planner addition within D-02. A change that arrives with no drag session, such as an assistive
  adjustment, ends no drag, so without it that change would never be saved. A drag still writes once, at its end.
  The `///` doc on `ValuePicker` states these three whys: one save per drag, a site answer moving the thumb, and
  changes made outside a drag.
- New `struct DraftTextField: View` in Sections1 under `// MARK: Shared Helpers`, after `ValuePicker` and inside
  `extension EhSettingView`. Its init mirrors `SettingTextField`'s exactly: `text:`, `title:`,
  `promptText: = nil`, `width: = 50`, `alignment: = .center`, `background: = nil`. It holds `@Binding private var
  text: String` (the form's value), `@State private var draft: String` seeded last in the init,
  `@FocusState private var isFocused: Bool` and the stored parameters. The body is `SettingTextField(text: $draft, …)`
  with `.focused($isFocused)` and `.onSubmit(submit)`, where `private func submit()` writes `text = draft` when they
  differ. `.onChange(of: isFocused)`: when focus leaves, `draft = text`, which puts back an unsubmitted edit.
  `.onChange(of: text)`: when not focused, `draft` takes the new value. The `///` doc states that every form write
  saves to the site, so the field writes only on Return, and that leaving without Return restores the saved value,
  so the field never shows text that was not saved. It also states that while not focused the draft follows the
  form, so a site answer shows in it.
- `RatingsSection` (Sections2): replace the `SettingTextField` with `DraftTextField` (same arguments) plus
  `.disabled(updatingOptions.contains(.ratingsColor))`, and remove `@FocusState var isFocused` and its `.focused`.
- `FavoritesSection` (Sections2), minimal per the port/462 note: change the `ForEach` header to exactly
  `ForEach(Array(tuples.enumerated()), id: \.element.0) { index, tuple in`, followed by `let nameBinding = tuple.1`.
  The dot becomes `.foregroundStyle(tuple.0.color(host: setting.galleryHost))`. The field becomes
  `DraftTextField(text: nameBinding, title: .favoriteCategoryName, width: nil, alignment: .leading, background:
  .clear).disabled(updatingOptions.contains(.favoriteCategory(index)))`. Remove `@FocusState private var isFocused`
  and its `.focused`. Change nothing else in the section except the sort-order picker's `.disabled` from D.
- `ExcludedUploadersSection` (Sections3): add an explicit
  `init(ehSetting: Binding<EhSetting>, updatingOptions: Set<EhSettingReducer.Option>)` that assigns `_ehSetting`,
  `updatingOptions`, and last `_draft = State(initialValue: ehSetting.wrappedValue.excludedUploaders)`. Declare
  `@State private var draft: String` and make the focus state `@FocusState private var isFocused`. The
  `TextEditor` binds `$draft` and gets `.disabled(updatingOptions.contains(.excludedUploaders))`. Add
  `.onChange(of: isFocused)`: when focus leaves and `draft != ehSetting.excludedUploaders`, it writes
  `ehSetting.excludedUploaders = draft`. Add `.onChange(of: ehSetting.excludedUploaders)`: when not focused, `draft`
  takes the new value. The footer counts `draft.ehSettingLineCount`. The section's `///` doc says the editor has no
  submit, because Return inserts a line, so it saves when editing ends.
- Follow the lint rules from the start: no closure `Binding`, parenthesized single-line closures, labeled tuple
  types, lines within 120 columns.

**F. Other files.**
- `ScenarioCatalog+Settings.swift`: change `site.setEhSetting(ehSetting)` to
  `site.setEhSetting(ehSetting, resettingProfileName: true)`. Nothing else changes.
- `AnalyticsEmissionTests.swift`, `onlyAFailedSettingsFetchRecordsAnErrorSignal`: replace `$0.hapticsClient = .noop`
  with `$0.ehSettingClient = .failing(.networkingFailed)` and add `import EhSettingClient` in sorted position. Send
  `.fetchEhSettingDone(.failure(.networkingFailed))`, then `.updateDone(option: .galleryName, revision: 0, result:
  .failure(.networkingFailed))`, then `.updateDone(option: .profile, revision: 0, result: .failure(.parseFailed))`,
  then `finish()`. The expected list stays `[.errorSurfaced(.networkingFailed, screen: .ehSetting)]`. Update the
  comment above it: the page shows the first load's failure. A failed save or profile action shows nothing; the
  latest one quietly refetches, and a failed refetch only re-enables its control. Neither is counted.
- `Localizable.xcstrings`: delete the `save` entry, lines 4723-4764 (the toolbar's Save label, now unused), and
  change nothing else in the file.
- `SCROLL-EDGE-INVENTORY.md`: on line 45, `AccountSettingView/EhSettingView/LoginView apply` becomes
  `AccountSettingView/LoginView apply`. On line 56, `EhSettingView.swift Form and WebView sheet root; direct hosts.`
  becomes `EhSettingView.swift Form; direct host.`

**G. Tests (D-06), in `EhSettingReducerTests.swift`.** Cover every `<behavior>` case. Add a file-private
`struct HeldAnswers: Sendable` built on `AsyncStream<Result<EhSetting, AppError>>.makeStream()`, one stream per
expected request. It keeps the streams in a `LockIsolated` queue and the continuations in a `let` array.
`func next() async throws(AppError) -> EhSetting` pops the next stream in start order and returns
`try result.get()` of its first element. If no stream is left or one ends empty, it records an `Issue` and throws
`AppError.unknown`. `func answer(_ index: Int, with result: Result<EhSetting, AppError>)` yields and finishes that
stream. Stub `submitChanges`, `performProfileAction` and `fetchSettings` with explicit-signature literals that
record what was posted in a `LockIsolated<[EhSetting]>` and return `try await answers.next()`. Leave every closure a
case does not expect unimplemented, so an unexpected request is reported. Use an exhaustive `TestStore` with
`$0.analyticsClient = .noop`, and send changes as `.binding(.set(\.ehSetting, edited))`. Build loaded state with a
helper that calls `setEhSetting(site(), resettingProfileName: true)` on a fresh `State()`. End each store case with
`await store.finish()`. The cases run in parallel; no `.serialized`.

Commit message: `Save each E-Hentai setting on its own`.
  </action>
  <verify>
    <automated>BUILD 2, LINT 2, TEST 2 and TESTBUILD 2 pass (Verification conventions), and every `<behavior>` case is in TEST 2's passing count. Then each gate prints its expected value:
`cat AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift | grep -v '^\s*//' | grep -cE 'submittingState|presentWebView|Destination|webView|submitChangesDone|performActionDone|hapticsClient|case submitChanges|toolbar'` [HEAD=33 EXPECT==0];
`grep -cF '$0.visible(store.loadingState == .loading)' AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift` [HEAD=0 EXPECT==1];
`grep -c 'onChange(of: \\.ehSetting)' AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift` [HEAD=0 EXPECT==1];
the control gate, which counts controls with no disabling, `(for o in loadThroughHathSetting hahRegion imageResolution useOriginalImages imageSizeWidth imageSizeHeight galleryName archiverBehavior displayMode searchRangeIndicatorStyle enableGalleryThumbnailSelector favoritesSortOrder searchResultCount thumbnailLoadTiming thumbnailConfigSize thumbnailConfigRows coverScaleFactor ratingsColor tagWatchingThreshold tagFilteringThreshold showFilteredRemovalCount excludedUploaders viewportVirtualWidth commentsSortOrder commentVotesShowTiming tagsSortOrder galleryPageNumbering useMultiplePageViewer multiplePageViewerStyle multiplePageViewerShowThumbnailPane 'disabledCategory(' 'favoriteCategory(' 'excludedLanguage('; do grep -qF "updatingOptions.contains(.$o" AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift || echo "UNGATED $o"; done) | grep -c UNGATED` [HEAD=33 EXPECT==0];
`grep -o 'updatingOptions.contains(.profile)' AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift | wc -l` [HEAD=0 EXPECT==5];
the mapping gate, which counts options with no field mapping, `F=AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer+Option.swift; (for o in loadThroughHathSetting hahRegion imageResolution useOriginalImages imageSizeWidth imageSizeHeight galleryName archiverBehavior disabledCategory displayMode searchRangeIndicatorStyle enableGalleryThumbnailSelector favoriteCategory favoritesSortOrder searchResultCount thumbnailLoadTiming thumbnailConfigSize thumbnailConfigRows coverScaleFactor ratingsColor tagWatchingThreshold tagFilteringThreshold showFilteredRemovalCount excludedLanguage excludedUploaders viewportVirtualWidth commentsSortOrder commentVotesShowTiming tagsSortOrder galleryPageNumbering useMultiplePageViewer multiplePageViewerStyle multiplePageViewerShowThumbnailPane; do [ "$(grep -v '^\s*//' "$F" 2>/dev/null | grep -ow "$o" | wc -l)" -ge 2 ] || echo "UNMAPPED $o"; done) | grep -c UNMAPPED` (the file is absent at HEAD) [HEAD=33 EXPECT==0];
`grep -c 'onEditingChanged: editingChanged' AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift` [HEAD=0 EXPECT==2];
`grep -c 'DraftTextField(' AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift` [HEAD=0 EXPECT==2];
`grep -c 'TextEditor(text: \$draft)' AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift` [HEAD=0 EXPECT==1];
`grep -c 'payload is fetched once per profile' AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift` [HEAD=1 EXPECT==0];
`grep -c '^    "save" : {' AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings` [HEAD=1 EXPECT==0];
`git diff --numstat HEAD -- AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings` before the commit [EXPECT=`0	42	…`];
`python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings; echo $?` [EXPECT=0];
`grep -c 'AccountSettingView/LoginView apply' .planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md` [HEAD=0 EXPECT==1];
`grep -c 'EhSettingView.swift Form; direct host.' .planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md` [HEAD=0 EXPECT==1];
`grep -c 'resettingProfileName: true' AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift` [HEAD=0 EXPECT==1];
after the commit, `git log -1 --format=%s` [EXPECT=`Save each E-Hentai setting on its own`].</automated>
    <human-check>
      On a simulator signed in to an E-Hentai account, open Settings, then E-Hentai Settings. Flip a toggle, pick a menu value, tap a front-page category and an excluded-language cell, drag the Cover Scaling slider, type a Ratings Color and press Return, type in a favorites name and tap elsewhere, then edit Excluded Uploaders and tap elsewhere. Repeat one slider change with VoiceOver's adjust gesture. Reopen the page after each kind of change.
      <expected>The navigation bar has no Save or Website button. No spinner or loading overlay appears for any change. Only the changed control is disabled until the site answers: system controls dim, and a tap on a disabled category or exclusion cell does nothing. Every other control stays usable. A slider saves once when the drag ends, and its label follows the thumb during the drag. Ratings Color saves on Return. The favorites name typed without Return goes back to its saved text. Excluded Uploaders saves when focus leaves, and its line-count footer follows the typing. The VoiceOver adjustment is saved. After reopening, every saved value is shown as set.</expected>
    </human-check>
  </verify>
  <done>Every option saves on its own and only its control waits for the site. The form shows the latest answer; an older answer is dropped; a failed latest save quietly refetches. The page has no toolbar items and shows no loading state for saves. The tests in `<behavior>` pass in parallel. The commit is signed with +08:00 dates. `261122-iew-SUMMARY.md` records the test counts, the expected snapshot change of the three site-settings scenarios, and the ValuePicker non-drag write the planner added within D-02.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app → gallery site (the user's account settings) | Every save posts the whole form to `uconfig.php`. A wrong, stale or repeated post changes the user's real account settings. |
| site answer → form | The parsed settings page replaces the form; it must never be mistaken for a user edit. |
| test process → network | Tests must not reach, or silently depend on, the live site. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261122-iew-01 | Tampering | `EhSettingReducer` `.updateDone` / `.refetchDone` (an older answer overwriting newer edits) | high | mitigate | `latestRevision` latest-wins: only the newest request's answer or refetch is applied; tests cover two requests in flight and an older failure. |
| T-261122-iew-02 | Tampering | save trigger (a site answer re-posting the form in a loop) | high | mitigate | The save trigger is `onChange` on `BindingReducer` alone. Draft controls follow the model without writing it. Tests show that a first-load answer and a save answer start no save. |
| T-261122-iew-03 | Denial of service | sliders and text fields flooding the site with posts | medium | mitigate | A slider writes once per drag. Text fields write on Return, the editor when focus leaves. At most one request per option is in flight, because an updating option is ignored and its control disabled. |
| T-261122-iew-04 | Information disclosure | tests reaching the live site | medium | mitigate | `EhSettingClientKey.testValue` is unimplemented and no test uses `live`; the test network guard stays linked. |
| T-261122-iew-05 | Repudiation | saves that fail without any message | low | accept | Owner decision (D-04): there is no error UI for saves. The latest failed request refetches, so the form shows what the site actually holds. |
| T-261122-iew-SC | Tampering | npm/pip/cargo installs | low | accept | No package is installed; Package.swift gains only a local target and local edges. |
</threat_model>

<verification>
- Baseline at the untouched tree: BUILD, LINT and TEST green, test count recorded.
- After each task: BUILD (no warning other than the two known ones), LINT (exit 0, empty), and TEST green. After
  Task 2, TESTBUILD too, which compiles VisualSnapshotTests and NetworkingFeatureTests.
- All gates in both `<verify>` blocks print their EXPECT values.
- No `.serialized`, no `swiftlint:disable`, no `withKnownIssue`, no closure `Binding` added, and every touched Swift
  file stays within the 1000-line `file_length` limit.
- `git log -2 --format='%G? %aI %cI %s'` shows the two task commits, signed, with +08:00 dates.
</verification>

<success_criteria>
- D-01 to D-07 are implemented as written. The planner's additions are the ValuePicker non-drag write, the
  `ExcludeLanguageToggle` comment correction, the dead `save` string removal and the inventory update, each named
  in the SUMMARY.
- The page's three requests go through `EhSettingClient`. Tests decide every outcome, and an unstubbed request is
  reported.
- Two signed commits: `Inject E-Hentai settings requests` and `Save each E-Hentai setting on its own`.
</success_criteria>

<output>
Create `.planning/quick/261122-iew-e-hentai-settings-saves-each-option-on-i/261122-iew-SUMMARY.md` when done (do not
commit it; the orchestrator records it in its docs commit).
</output>
