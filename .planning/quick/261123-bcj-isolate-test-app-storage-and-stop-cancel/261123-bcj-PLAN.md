---
phase: 261123-bcj-isolate-test-app-storage-and-stop-cancel
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Package.swift
  - .swiftlint.yml
  - AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift
  - AppPackage/Tests/AppModelsTests/IsolatedAppStorageTraitTests.swift
  - AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift
  - AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift
  - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift
  - AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift
  - AppPackage/Tests/AppModelsTests/BlockedCommentUserTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadProcessCacheTests.swift
  - AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift
  - AppPackage/Tests/VisualSnapshotTests/VisualTracerTests.swift
  - AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift
  - AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
  - Scripts/lint/app_storage_isolation.py
  - Scripts/lint/test_app_storage_isolation.py
  - Scripts/lint/lint_check.py
  - Scripts/lint/test_lint_check.py
  - .github/workflows/lint.yml
  - Scripts/visual/README.md
  - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Tests/AppFeatureTests/CaptureTagTranslationTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureLiveTextRecordTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureDownloadTests.swift
  - "the Task 3 conversion worklist (46 Swift Testing files and 4 XCTest files, listed in the context section)"
  - "every file the isolation check's apply edits (219 suite declarations in 216 files under the 13 in-scope test targets)"
autonomous: true
requirements: [D-1, D-2, D-3, D-4]
user_setup: []

estimate:
  tokens: 320000
  raw_tokens: 320000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Every Swift Testing suite that can reach app storage (the isolation check's rule, 225 suites) carries .isolatedAppStorage, and each of its test cases, every parameterized argument included, runs on its own plain-named UserDefaults suite whose persistent domain is removed when the case ends (D-1)"
    - "A TestStore, a reducer state's @Shared property and a fresh @Shared reference built inside a case all use the case's suite without the case naming it; a case that reads the value itself uses @Dependency(\\.defaultAppStorage) (D-1)"
    - "No code under AppPackage/Tests uses UserDefaults.inMemory or assigns defaultAppStorage in a Swift Testing file, and the no_in_memory_user_defaults SwiftLint error rejects .inMemory UserDefaults in AppPackage/Tests and EhPandaUITests while .inMemory(\"key\") and FileStorage's .inMemory stay legal (D-1)"
    - "The VisualSnapshotTests XCTest cases get a fresh plain-named suite at every former .inMemory site, its domain removed at the case's teardown (D-1)"
    - "aRevealDoesNotOutliveTheScreen's two screens share the one per-case suite (D-1)"
    - "A cancelled waitUntil, waitUntilSettled, waitUntilCacheCleared or drainDetailMetadataEffects stops polling at once and reports its normal outcome, and sleepIgnoringCancellation's doc states that a loop calling it must check cancellation (D-2)"
    - "CaptureScenePreparation.isolate and UITestAutomation.configureVisualTestHost take their UserDefaults from the caller: unit tests pass the case's suite, the UI-test app's three call sites pass a fresh UserDefaults.inMemory there, as before (D-3)"
    - "The lint gate (Scripts/lint/lint_check.py) runs the app-storage isolation check and fails on any break of it: a suite that can reach app storage without the trait, the trait where the rule does not select it, a carrier without import TestingSupport, a selected test target that does not link TestingSupport; HostedViewTests, VisualSnapshotTests and LiveCheckTests are excluded by name in the check (D-4)"
    - "The full FeatureTests plan (VisualSnapshotTests skipped) passes three runs in a row with 0 failures after Task 3, with no stale-read exception"
  artifacts:
    - path: AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift
      provides: "IsolatedAppStorageTrait (SuiteTrait, TestScoping, TestTrait), Trait.isolatedAppStorage and withIsolatedAppStorage(_:)"
    - path: AppPackage/Tests/AppModelsTests/IsolatedAppStorageTraitTests.swift
      provides: "per-case isolation and end-of-scope removal tests of the trait"
    - path: AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift
      provides: "XCTestCase.makeIsolatedAppStorage() for the XCTest target"
    - path: .swiftlint.yml
      provides: "custom rule no_in_memory_user_defaults"
    - path: Scripts/lint/app_storage_isolation.py
      provides: "the app-storage isolation rule: violations() for the lint gate, and check, report, apply"
    - path: Scripts/lint/test_app_storage_isolation.py
      provides: "hermetic tests of the rule and of apply"
  key_links:
    - from: Scripts/lint/lint_check.py
      to: Scripts/lint/app_storage_isolation.py
      via: "app_storage_findings(ROOT) in main(), every break an error Finding"
    - from: AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift
      to: AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift
      via: "@Suite(.isolatedAppStorage); TestStore builds its reducer inside withDependencies on the task-local values"
    - from: AppPackage/Package.swift
      to: AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift
      via: "TestingSupport depends on composableArchitecture and sharing; seven more test targets link .module(.testingSupport)"
    - from: .swiftlint.yml
      to: AppPackage/Tests
      via: "no_in_memory_user_defaults, included '.*/AppPackage/Tests/.*' and '.*/EhPandaUITests/.*'"
---

<objective>
Remove the stale-read flake class from the test suites and stop cancelled bounded waits from spinning.

1. Tracer (D-1, D-4 tool): the `.isolatedAppStorage` Swift Testing trait (and `withIsolatedAppStorage`) in
   TestingSupport, a test of the trait itself, the app-storage isolation check in `Scripts/lint` with its tests (not yet
   run by the lint gate), and the five suites that already failed or already work around the problem
   (InstallSignalSenderTests, CommentModerationReducerTests, MyTagsFeatureTests, and the two e2427c16b suites
   LibraryPickerChoicePersistenceTests and BlockedCommentUserTests) moved onto it end to end.
2. D-2: the four deadline-bounded wait helpers also stop on `Task.isCancelled`, and `sleepIgnoringCancellation`'s
   doc says why every caller loop must.
3. Expansion (D-1, D-3, D-4 gate): the two UI-test helpers take their storage from the caller, every remaining
   `.inMemory` and plain-named suite in the Swift Testing targets moves to the trait, every suite the rule selects
   carries it, the XCTest files get their own per-site isolation, and both bans land once nothing violates them: the
   SwiftLint rule and the isolation check in the lint gate. The full FeatureTests plan then passes three times in a row.

Purpose: a stale read is now a real failure, so the class must be gone, and a cancelled wait must not burn 30 s at full
speed under a parallel load that is already the cause of slow runs.
Output: three commits and `261123-bcj-SUMMARY.md` in this quick directory.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.swiftlint.yml
@.planning/STATE.md
@.planning/quick/261123-bcj-isolate-test-app-storage-and-stop-cancel/261123-bcj-CONTEXT.md
@.planning/quick/261123-bcj-isolate-test-app-storage-and-stop-cancel/261123-bcj-app_storage_isolation.py
@AppPackage/Package.swift

### Execution fidelity

Follow this plan exactly. If anything cannot be done exactly as written (ambiguity, conflicting requirements, missing
information, unexpected repository state, a compiler error or lint rule that forces a different shape, a test that
fails outside the allowance below, a gate that prints another value, or any deviation at all), stop immediately and
ask the orchestrator. Do not choose, invent or implement a solution on your own. The only latitude granted: wrapping
comment prose to stay within 120 columns (wording fixed where this plan gives it, and a phrase a gate greps for stays
on one line), choosing local variable names inside a function body, and using a scratch script under
`.capture/261123-bcj/` for the mechanical conversion rules R1 to R3 (the outcome gates stay authoritative).

### Where you work

- Only this linked worktree, the current directory (branch `claude/fervent-kowalevski-27fecc`). Every path in this plan
  is relative to it and every command assumes it as the working directory. Never read, write, build in or run git
  against any other checkout. The one exception: reading `$HOME/Fork/EhPanda/AGENTS.local.md` (read-only) to unlock gpg
  if a commit fails because the gpg cache expired. Do not read `AIRBUILD.md`.
- Never use bare `git stash`. Never merge or push. Do not commit this PLAN, the CONTEXT, the two planning reference
  copies (`261123-bcj-app_storage_isolation.py`, `261123-bcj-test_app_storage_isolation.py`), the SUMMARY or STATE.md:
  the orchestrator commits those. Never edit the reference copies.
- Scratch lives under the gitignored `/.capture/`: logs and scripts in `.capture/261123-bcj/`, derived data in
  `.capture/261123-bcj/dd`. Generated docs carry no absolute home path and name no other local project.
- Swift rules binding every edit (CLAUDE.md, `.swiftlint.yml`): no `// swiftlint:disable`, no suppression, no
  `.serialized`, no `try?`, no force unwrap, `line_length` 120 and `file_length` 1000 are errors, `sorted_imports`
  (by module name, attributes ignored), `single_line_trailing_closure`, `optional_try`. No new module (TestingSupport
  already has its `.swiftlint.yml`), no new reducer.
- `AppPackage/Sources` gets exactly four changes in the whole plan: the new trait file (Task 1), and in Task 3 the
  D-3 storage parameter in `AppFeature/UITestSupport/UITestAutomation.swift` and
  `AppFeature/UITestSupport/CaptureScenePreparation.swift` with the one app call site in
  `AppFeature/DataFlow/AppDelegateReducer.swift`. The UI-test app keeps building a fresh `UserDefaults.inMemory` at its
  three call sites, so its behaviour is unchanged (CONTEXT D-3); no other Sources file changes.
- `Scripts/lint` gets the isolation check and its tests in Task 1, and the lint gate's call of it in Task 3 (D-4).
  Python rules: standard library only, 120-column lines, the module and its tests copied byte for byte from the
  planning reference copies named in each task.
- Every file under `AppPackage/Tests/DownloadsFeatureTests` is scanned by `DownloadSourceInventoryTests`: write none of
  its retired phrases (`one`, `sole` or `only` immediately followed by ` authority`) and none of its census tokens
  (`withdrawingCountedBasisMovement(`, `lastPushedCompletedPageCount`, `runProgressBases`, `pendingPageIndices(`,
  `schedulableDownloads()`, `updateProgress:`, `Task.yield()`, the scheduling-block call, the store's enqueue call).
  `DownloadSourceInventoryTests.swift` is exactly 1000 lines and is not edited (the scope rule does not select it).

### Owner decisions implemented (CONTEXT.md, locked)

- D-1: a TestingSupport trait gives each test case its own plain-named `defaultAppStorage` suite and removes its domain
  when the case ends (shape after swift-dependencies' `_DependenciesTrait`); every `.inMemory` in the Swift Testing
  targets moves to it; suites that never set `defaultAppStorage` but can reach app storage get it too; the XCTest files
  get the same isolation through XCTest teardown; a scoped SwiftLint rule bans `.inMemory` user defaults in tests with
  a message pointing at the trait and without matching FileStorage's `.inMemory`; two stores in one case that share
  storage keep sharing it through the one per-case suite; the e2427c16b suites move to the trait too.
- D-2: `waitUntil`, `waitUntilSettled`, `waitUntilCacheCleared` and `drainDetailMetadataEffects` also stop on
  `Task.isCancelled` and then report their normal outcome; `sleepIgnoringCancellation`'s doc states the requirement.
- D-3 (owner, after planning): `CaptureScenePreparation.isolate` and `UITestAutomation.configureVisualTestHost` take
  their `UserDefaults` from the caller; unit-test callers pass the trait's storage; the UI-test app's call sites build
  their own storage as today. After this no test path uses a file-backed suite.
- D-4 (owner, after planning): the scope rule lives in `Scripts/lint` as a permanent check the project's lint gate
  runs and fails on, with tests alongside `Scripts/lint/test_lint_check.py`; the HostedViewTests and
  VisualSnapshotTests exclusions are stated in the check.
- Orchestrator calls (locked): one `makeIsolatedAppStorage()` per former XCTest site, removed through
  `addTeardownBlock`; the e2427c16b suites convert; HostedViewTests is excluded; the trait's own test stays in
  AppModelsTests; each task is self-contained for a fresh executor.

### Design settled by this plan (verified against `.capture/261123-1dk/dd/SourcePackages/checkouts`)

- **Root cause, confirmed in source.** `swift-sharing` `Sources/Sharing/SharedKeys/AppStorageKey.swift:629-640`:
  `UserDefaults.inMemory` names its suite `NSTemporaryDirectory() + "co.pointfree.Sharing.<UUID>"` on iOS 17+, and
  `DefaultAppStorageKey.testValue` (`:623`) is that same value. `AppStorageKey.init` (`:317-322`) reads
  `@Dependency(\.defaultAppStorage)` when the key is built, and the key's id is `(key, store)` (`:313`), so a per-case
  store gives per-case references.
- **The trait.** `AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift` declares
  `public struct IsolatedAppStorageTrait: SuiteTrait, TestScoping, TestTrait` with `public var isRecursive: Bool { true }`
  and `public func provideScope(for test: Test, testCase: Test.Case?, performing function: @concurrent () async throws -> Void) async throws`
  (signature wrapped one parameter per line). This is exactly the witness shape of
  `swift-concurrency-extras` `ConcurrencyExtrasTestSupport/TaskLocalTrait.swift` and `swift-dependencies`
  `DependenciesTestSupport/TestTrait.swift`, both compiled with the same upcoming features as this package
  (`NonisolatedNonsendingByDefault` included). The same file declares, above the struct, the free function
  `public func withIsolatedAppStorage<Result>(_ operation: (UserDefaults) async throws -> Result) async throws -> Result`
  (signature wrapped one parameter per line): `let suiteName = "isolated-app-storage-\(UUID().uuidString)"`;
  `let appStorage = try #require(UserDefaults(suiteName: suiteName))`;
  `defer { appStorage.removePersistentDomain(forName: suiteName) }` written over multiple lines;
  `return try await operation(appStorage)`. It is the one place a suite is made and removed: the trait uses it, and so
  does the one case that needs a second suite beside its own (CaptureSceneTests, Task 3, D-3). The trait's
  `provideScope` body is `try await withIsolatedAppStorage { appStorage in … }` whose closure runs
  `try await withDependencies { $0.defaultAppStorage = appStorage } operation: { try await function() }`, all written
  over multiple lines. It does not reset any other dependency (unlike `_DependenciesTrait`'s root reset), so it composes
  with everything a case sets itself. `extension Trait where Self == IsolatedAppStorageTrait` declares
  `public static var isolatedAppStorage: Self { Self() }`. Imports, in this order: `import ComposableArchitecture`,
  `public import Foundation`, `import Sharing`, `public import Testing` (`Foundation` is public because the public
  function's signature names `UserDefaults`; `withDependencies` and `@Dependency` reach this package through
  ComposableArchitecture's re-export of Dependencies, as in every other module here; Sharing declares
  `defaultAppStorage`).
- **Scope semantics** (Swift Testing 6.4, Xcode 27.2 `Testing.swiftinterface`: `SuiteTrait where Self: TestScoping`
  provides `scopeProvider(for:testCase:)`). A recursive suite trait provides no scope for the suite itself; it is
  inherited by every nested suite and test function, and a test function's scope is provided once per test case. So
  every argument of a parameterized test gets its own suite, and every test of a nested suite or of an `extension` of
  the suite type gets its own. No converted suite keeps storage in a stored property, so nothing depends on where the
  suite instance's `init` runs. The trait goes once on the outermost (top-level) suite type, never again on a nested
  type or test.
- **Inheritance.** `TestStore.init` builds its reducer inside `Dependencies.withDependencies` starting from the current
  task-local values (`swift-composable-architecture` `Sources/ComposableArchitecture/TestStore.swift:537`), `Store`
  likewise, and `@Dependency` resolves `initialValues.merging(DependencyValues._current)` at access time
  (`swift-dependencies` `Sources/Dependencies/Dependency.swift:174-196`). So a case's stores, states and `@Shared`
  references use the case's suite without naming it, and a case or helper that needs the `UserDefaults` value declares
  `@Dependency(\.defaultAppStorage) var <name>` locally.
- **Package.** TestingSupport's dependencies become `.module(.analyticsClient)`, `.targetDependency(.composableArchitecture)`,
  `.targetDependency(.kanna)`, `.targetDependency(.sharing)` (both new entries were already in its link closure through
  AnalyticsClient, so nothing new is linked). Seven test targets that hold selected suites gain `.module(.testingSupport)`
  as the new last element of their `dependencies` array: AnalyticsClientTests, AppModelsTests, DetailFeatureTests,
  SettingFeatureTests (Task 1); FavoritesFeatureTests, GalleryListComponentsTests, SystemNotificationTests (Task 3).
  No third-party package is added; `Package.resolved` does not change. TestingSupport imports `Testing` in a library
  target, as `DependenciesTestSupport` and `SnapshotTesting` do; if the BUILD rejects it, stop and ask.
- **XCTest (VisualSnapshotTests).** That Xcode target cannot link TestingSupport (it is not a product). A new file
  `AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift` (the target is a file-system synchronized group, so the
  file joins it) declares, in `extension XCTestCase`, `func makeIsolatedAppStorage() throws -> UserDefaults`: the same
  `"isolated-app-storage-\(UUID().uuidString)"` name, `try XCTUnwrap(UserDefaults(suiteName: suiteName))`, and the domain
  removal registered with XCTest's teardown: `addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suiteName) }`
  written over multiple lines (only the `Sendable` name is captured; `UserDefaults` is not `Sendable`). Imports:
  `import Foundation`, `import XCTest`. Each former `.inMemory` site calls it once, so the matrix loops keep one fresh
  suite per coordinate as today (CONTEXT, orchestrator call on OQ2).
- **The UI-test helpers take their storage from the caller** (Task 3, D-3). Live observation at `e99c7bd60`:
  `UITestAutomation.configureVisualTestHost(_:firstLaunch:)` (`AppFeature/UITestSupport/UITestAutomation.swift`
  about lines 318-345) and `CaptureScenePreparation.isolate(_:scene:storage:libraryClient:launch:)`
  (`AppFeature/UITestSupport/CaptureScenePreparation.swift` about lines 271-316) each build
  `let appStorage = UserDefaults.inMemory` and install it. Both gain a last parameter `appStorage: UserDefaults` and
  lose that local (the body keeps using the name `appStorage`, so no other body line changes); the comment line
  directly above the local in UITestAutomation.swift ("One suite, held: …") goes with it. The unary overload
  `configureVisualTestHost(_:)` (about line 316, which forwards `firstLaunch: .answered`) is deleted: its one caller is
  UITestStubTests, which then calls the remaining function itself. App call sites, each passing `appStorage: .inMemory`
  so the UI-test app builds a fresh suite at each, as today (two of them run per hosted launch, as today):
  `UITestAutomation.prepare(environment:now:)` (about line 243), `AppDelegateReducer.init`
  (`AppFeature/DataFlow/AppDelegateReducer.swift` about line 56) and `CaptureScenePreparation.install` (about line
  260). All three files already import Sharing, which declares `UserDefaults.inMemory`. Unit-test callers pass the
  case's suite: CaptureRouteTests (about line 92), CaptureTagTranslationTests (about line 76),
  CaptureLiveTextRecordTests (about line 63), CaptureDownloadTests (about line 213), UITestStubTests (about lines 18 and
  331); CaptureSceneTests (about line 529) needs the scene's suite apart from the case's (personal) one and takes it
  from `withIsolatedAppStorage`. No VisualSnapshotTests or HostedViewTests file calls either function (they reach the
  host through `UITestAutomation.prepareIfNeeded()`, the app path).
- **The isolation check** (D-4). `Scripts/lint/app_storage_isolation.py` is a stand-alone, standard-library module,
  copied byte for byte from the reference copy
  `.planning/quick/261123-bcj-isolate-test-app-storage-and-stop-cancel/261123-bcj-app_storage_isolation.py`; its
  docstring states the rule and the out-of-scope targets with their reasons (`OUT_OF_SCOPE = ('VisualSnapshotTests',
  'HostedViewTests', 'LiveCheckTests')`). It serves both as a module (`violations(root)` returns `Violation(path,
  line, message)` values, `ScopeError` when the tree cannot be read) and as a command (`check`, `report`,
  `apply [file ...]`). Its tests, `Scripts/lint/test_app_storage_isolation.py` (12 hermetic cases on a temporary tree,
  copied byte for byte from `261123-bcj-test_app_storage_isolation.py`), sit beside `test_lint_check.py` and are run by
  lint.yml's "Test the scripts" step, which discovers every `test_*.py`. It plugs into the gate as a module, not a
  subprocess: `lint_check.py` imports it, and a new `app_storage_findings(root)` maps each violation to
  `Finding(path, line, 1 if line else 0, 'error', message)` and a `ScopeError` to
  `Finding('', 0, 0, 'error', f'The app-storage isolation check could not read the tree: {error}')`; `main()` adds
  these to its findings before the builds, so the gate fails on any of them through its existing judging (an error is
  never allowed) and reports them in its existing formats. A live test in `test_lint_check.py` asserts the tree has
  none, so the script-test step fails on a break too, before any build. This lands in Task 3, once nothing violates the
  rule; Tasks 1 and 2 use the module as a command only.
- **The lint rule** (Task 3), inserted in `.swiftlint.yml` `custom_rules` directly after the `no_geometry_reader` rule
  (alphabetical), exactly:

```yaml
  # Bans Sharing's `UserDefaults.inMemory` in tests (quick task 261123-bcj, D-1): it names its suite by a path under
  # the temporary directory, and such file-backed suites stop reflecting new writes under parallel test load.
  # `(?!\s*\()` keeps `.inMemory("key")` (InMemoryKey) legal; the lookbehinds keep FileStorage's `.inMemory` legal.
  no_in_memory_user_defaults:
    name: "No In-Memory UserDefaults"
    included:
      - '.*/AppPackage/Tests/.*'
      - '.*/EhPandaUITests/.*'
    regex: '(?<!FileStorage)(?<!defaultFileStorage = )\.inMemory\b(?!\s*\()'
    message: 'UserDefaults.inMemory is a file-backed suite that goes stale under parallel test load. Give the suite .isolatedAppStorage (TestingSupport) and read @Dependency(\.defaultAppStorage); an XCTest case calls makeIsolatedAppStorage().'
    excluded_match_kinds:
      - comment
      - doccomment
      - string
    severity: error
```

- **Lint probe** (Task 3 mutation gate): a temporary file `AppPackage/Tests/AppModelsTests/NoInMemoryUserDefaultsProbe.swift`
  with exactly these eight lines, in order (it is linted, never built, and deleted right after):
  1. `let probe1 = UserDefaults.inMemory`
  2. `func probe2(defaults: UserDefaults = .inMemory) {}`
  3. `let probe3 = withDependencies({ $0.defaultAppStorage = .inMemory }, operation: { 3 })`
  4. `let probe4 = makeState(defaults: .inMemory)`
  5. `let probe5 = Shared(wrappedValue: 0, .inMemory("probe"))`
  6. `let probe6 = FileStorage.inMemory`
  7. `let probe7 = withDependencies({ $0.defaultFileStorage = .inMemory }, operation: { 7 })`
  8. `// UserDefaults.inMemory named in a comment`

  The rule must report lines 1 to 4 and no other line.

### Which suites get the trait (the scope rule; live observation at `e99c7bd60`)

The rule is implemented by `Scripts/lint/app_storage_isolation.py` (Task 1 copies it there; read its docstring), run
as `python3 Scripts/lint/app_storage_isolation.py report|apply|check` from the checkout root. In short: the reader
modules are the Sources modules whose code names an app-storage key from `AppSharedKeys.swift` inside `Shared(`/
`SharedReader(`, closed over the package's module dependencies (17 at HEAD: AnalyticsClient, AppComponents, AppFeature,
DetailFeature, DownloadClient, DownloadsFeature, FavoritesFeature, FiltersFeature, GalleryListComponents, HomeFeature,
MyTagEditor, QuickSearchFeature, ReadingFeature, ReadingSettingFeature, SearchFeature, SettingFeature,
SystemNotification). A test file reaches app storage when its code (comments and strings stripped) imports a reader
module or names `defaultAppStorage`, `UserDefaults`, `.appStorage(` or an app-storage key in `Shared(`/`SharedReader(`;
with MemberImportVisibility on, nothing else in a file can drive a reader module. A top-level suite type needs the trait
when any file declaring or extending it reaches. A per-file rule is used rather than "the suite sets
`defaultAppStorage`" because helpers and reducers reach app storage without the suite naming it, and it is
deliberately broad: a suite that only reads a fresh suite would not go stale, but writes happen deep in reducers and
cannot be told apart statically. Out of scope: VisualSnapshotTests and HostedViewTests (Xcode targets that cannot link
TestingSupport) and LiveCheckTests (XCTest). Measured with the module on a scratch copy of HEAD: report lines
`READER_MODULES 17: …`, `NEEDS 224` (224 suite lines, all `[missing]`, none `[has]`), `VIOLATIONS 231` (224 suites
without the trait, 7 test targets without TestingSupport). Simulated on that copy: Task 1's Package change, the
five-file apply and the trait test give `NEEDS 225`, 6 `[has]`, 219 `[missing]`, `VIOLATIONS 222` (the 3 remaining
targets FavoritesFeatureTests, GalleryListComponentsTests, SystemNotificationTests); Task 3's Package change and full
apply edit 216 files and give `NEEDS 225`, `VIOLATIONS 0`, `check` exit 0, a second apply changes nothing, and every
file stays at or under 120 columns and 1000 lines. Every selected suite except the trait's own test is selected by a
reader-module import or an app-storage key, so no Task 3 conversion can make a converted suite stop being selected.

### Conversion rules (Tasks 1 and 3; for the Swift Testing files, not VisualSnapshotTests)

- R1. Delete every statement that assigns `defaultAppStorage` (`$0.defaultAppStorage = …`, `dependencies.defaultAppStorage = …`),
  whatever its right-hand side (`.inMemory`, `UserDefaults.inMemory`, a local, a parameter, a harness property).
- R2. A `withDependencies { … } operation: { … }` whose update closure R1 left without statements is replaced by the
  operation closure's statements at the call's position, one indentation level out: as a statement, by its statements;
  `let x = withDependencies {…} operation: { S…; return E }` (or a single-expression `{ E }`) by `S…` then `let x = E`;
  `return withDependencies {…} operation: { … }`, or one that is a function's implicit return, by the statements with the
  closure's own `return` kept as the function's. Drop a `try` or `await` that only the wrapper needed; keep the inner
  ones. The BUILD's no-new-warning gate catches a leftover `try`/`await`. An emptied call in any other expression
  position: stop and ask.
- R3. A `TestStore(…) { }` trailing closure or `withDependencies: { }` argument that R1 left empty is removed.
- R4. A storage local (`let X = UserDefaults.inMemory`, or `let X = try #require(UserDefaults(suiteName: …))` with its
  `suiteName` local and its `defer { X.removePersistentDomain(…) }`): if X has no use left after R1 and R5, delete all
  of them; otherwise replace the declaration with `@Dependency(\.defaultAppStorage) var X` and delete the `suiteName`
  local and the `defer`.
- R5. Remove every parameter and stored property of type `UserDefaults` from test helpers (functions, initializers,
  harness types) and every argument passed for them, `.inMemory` arguments included. Where a helper or harness member
  reads the storage itself (`X.data(forKey:)`, `X.object(forKey:)`, `X.set(…)`, passing X on), declare
  `@Dependency(\.defaultAppStorage) var X` as its first statement.
- R6. A `@Test` function whose body no longer contains `try` drops `throws`. Helper signatures stay as they are.
- R7. A helper method whose body R2 reduced to one call forwarding its parameters unchanged is deleted, and its call
  sites call the forwarded API directly (CLAUDE.md: no thin wrappers).
- R8. A comment or doc comment in a touched file that describes the replaced storage (in-memory defaults,
  `UserDefaults.inMemory`, a plain-named suite, a per-case `deinit`) is rewritten to describe the case's suite from
  `.isolatedAppStorage`, in one clause, without restating the trait's why. Other comments stay.
- R9. Nothing else changes in a touched file: no reordering, renaming or import removal; the only import added is
  `import TestingSupport`, by the isolation check's `apply`. The D-3 edits of Task 3 step 3 are the stated exception.
- R10. Stop and ask on any case these rules do not settle: a name collision when inlining, a storage local used in an
  uncovered way, a case that needs two distinct suites (other than the CaptureSceneTests case Task 3 settles), or a
  `defaultAppStorage` assignment whose removal would change which storage a store reads other than to the case's
  suite.

### Task 3 conversion worklist (live observation at `e99c7bd60`; counts exclude comment lines)

`im` = `.inMemory` not followed by `(`; `sn` = `UserDefaults(suiteName`; `as` = `defaultAppStorage =` assignments.

- AnalyticsClientTests: `AnalyticsDefaultParametersTests.swift` (im 1, as 1), `AnalyticsLevelGateTests.swift` (im 1, as 4).
- AppFeatureTests: `AnalyticsEmissionTests.swift` (im 1, as 2), `AppReducerScenePhaseTests.swift` (im 2, as 4),
  `CaptureRouteTests.swift` (im 1, as 2), `CaptureSceneTests.swift` (im 1, as 3), `CaptureScreenDiagnosticsTests.swift`
  (im 1, as 1), `FirstLaunchGateTests.swift` (im 3, as 5), `GalleryDetailRoutingTests.swift` (im 1, as 2),
  `LibraryNavigationTests.swift` (im 1, as 2), `TabBarSettingPresentationTests.swift` (im 1, as 2),
  `UITestStubTests.swift` (im 3, as 3; plus its two `configureVisualTestHost` calls, D-3), and for D-3 only
  `CaptureTagTranslationTests.swift`, `CaptureLiveTextRecordTests.swift`, `CaptureDownloadTests.swift` (im 0, as 0).
- AppModelsTests: `Persistent/LibraryPickerChoiceTests.swift` (im 3, as 3).
- DetailFeatureTests: `DetailCaptureRouteTests.swift` (im 1, as 2), `DetailMyTagsTests.swift` (im 1, as 2),
  `MyTagEditorTests.swift` (im 3, as 4).
- DownloadsFeatureTests: `AppReadingFlushTests.swift` (im 1, sn 2, as 5), `ReadingReducerFlushTests.swift` (sn 2, as 5).
- FavoritesFeatureTests: `AnalyticsEmissionTests.swift`, `LoginReturnObservationTests.swift`, `ReadingEntryTests.swift`,
  `SortSelectionTests.swift` (im 1, as 2 each).
- HomeFeatureTests: `AnalyticsEmissionTests.swift` (im 21, as 22), `FiltersPresentationLifecycleTests.swift` (im 1, as 2),
  `HomeClientTests.swift` (im 1, as 2), `HomeDuoPresentationTests.swift` (im 2, as 4),
  `HomePresentationLifecycleTests.swift` (im 1, as 2), `LoginReturnObservationTests.swift` (im 1, as 2),
  `PaginationContinuationTests.swift` (im 10, as 10).
- ReadingFeatureTests: `AutoPlayHandlerTests.swift`, `ReaderPagesAccessibilityTests.swift`, `ReadingOrientationTests.swift`
  (im 1, as 1 each), `WebtoonReadingTests.swift` (im 3, sn 11, as 5).
- SearchFeatureTests: `AnalyticsEmissionTests.swift` (im 5, as 8), `SearchHistoryRemovalTests.swift` (im 4, as 4).
- SettingFeatureTests: `AppIconReducerTests.swift` (im 3, as 4), `BlockedUsersReducerTests.swift` (im 8, as 13),
  `GeneralSettingReducerTests.swift` (im 4, as 8), `MyTagsLaunchFetchTests.swift` (im 1, as 2),
  `SettingReducerNavigationTests.swift` (im 3, as 4), `SettingReducerTests.swift` (im 1, as 2),
  `SettingWriteThroughTests.swift` (im 1, as 2), `TagDatabaseDigestTests.swift` (sn 1, as 1).
- VisualSnapshotTests (XCTest, own rule in Task 3): `VisualTracerTests.swift` (:61, :174), `FullContentFeasibilityTests.swift`
  (:240, :405), `VisualMatrixTests.swift` (:116), `Matrix/SnapshotMatrixCase.swift` (:166).
  `Matrix/ScenarioCatalog+Settings.swift`'s two `@Shared(.inMemory("…"))` are InMemoryKey and stay.

The four plain-named files outside e2427c16b (AppReadingFlushTests, ReadingReducerFlushTests, WebtoonReadingTests,
TagDatabaseDigestTests) are converted too, so the tests have one pattern (orchestrator call on OQ3).

### Verification conventions (used by every task)

- Shorthands: `Q=.capture/261123-bcj`; `T=Scripts/lint/app_storage_isolation.py` (exists from Task 1 step 1 on);
  `R=.planning/quick/261123-bcj-isolate-test-app-storage-and-stop-cancel` (the planning reference copies live there);
  `C='^[^:]+:[0-9]+:[[:space:]]*//'` (a grep -n line whose code is a comment);
  `ex() { grep -v '^[[:space:]]*//' "$2" | grep -cF -- "$1"; }` (executable-line fixed-string count).
  Tree-wide counters (Swift files under `AppPackage/Tests`, comment lines excluded):
  IM_TESTS `grep -rnE '\.inMemory\b' AppPackage/Tests --include='*.swift' | grep -vE "$C" | grep -cvE '\.inMemory\b[[:space:]]*\('`;
  SN_TESTS `grep -rn 'UserDefaults(suiteName' AppPackage/Tests --include='*.swift' | grep -cvE "$C"`;
  AS_ST `grep -rnE 'defaultAppStorage[[:space:]]*=' AppPackage/Tests --include='*.swift' | grep -v '/VisualSnapshotTests/' | grep -cvE "$C"`;
  TY_ST `grep -rnE ':[[:space:]]*UserDefaults\b' AppPackage/Tests --include='*.swift' | grep -v '/VisualSnapshotTests/' | grep -cvE "$C"`;
  IM_SRC `grep -rnE '\.inMemory\b' AppPackage/Sources --include='*.swift' | grep -vE "$C" | grep -cvE '\.inMemory\b[[:space:]]*\('`.
  HEAD values at `e99c7bd60`: IM_TESTS 117, SN_TESTS 18, AS_ST 176, TY_ST 13, IM_SRC 2 (the two
  `let appStorage = UserDefaults.inMemory` locals; after Task 3 IM_SRC is 3, the three app call sites' `.inMemory`
  arguments, D-3). Each gate carries
  `[HEAD=… EXPECT…]`; HEAD is the value at the commit the task starts from (values for later tasks are derived from
  this plan and marked UNPINNED). A gate whose printed value does not satisfy its EXPECT is a stop-and-ask. Every gate
  of a task runs after its edits and before its COMMIT, against the uncommitted tree (so a bare `git diff` or
  `git status` is intended), except the signature check, which runs after the commit.
- SCOPE (tag): `python3 $T report > $Q/scope-<tag>.txt` (must exit 0). Gates read it as: `grep -cx 'NEEDS <n>'`,
  `grep -cx 'VIOLATIONS <n>'` and `grep -c '^READER_MODULES 17: '` (each must print 1), and the suite-line counts
  `grep -c ' \[has\]$'` and `grep -c ' \[missing\]$'` (must print the stated numbers), all on `$Q/scope-<tag>.txt`.
  The first SCOPE is tag `task1-start`, right after Task 1 copies the module in (a copy changes no Swift file, so it
  reads HEAD; the module finds the checkout root from its own location, so it cannot run from the planning folder).
- PY (tag): `python3 -m unittest discover -s Scripts/lint -p 'test_*.py' > $Q/py-<tag>.txt 2>&1` must exit 0, and
  `grep -cx 'OK' $Q/py-<tag>.txt` must print 1 and `grep -c '^Ran <n> tests in ' $Q/py-<tag>.txt` 1, with n stated
  per task (24 at HEAD: test_lint_check.py alone). This is the command lint.yml's script-test step runs for the
  directory.
- ONE xcodebuild at a time: before every `xcodebuild` and every `lint_check.py` run, `pgrep -x xcodebuild` and
  `pgrep -x xctest` must both print nothing; if either prints a pid, another session's run is in flight: wait for it to
  end (re-check every few minutes) and never kill it. Long commands (every build, test run and `lint_check.py`) run in
  the background; wait for each to finish before the next step.
- SIMULATOR (once, before the baseline): `xcrun simctl list devices | grep -F 'EhPanda iPhone Air (261123-bcj)'` must
  print nothing (otherwise stop and ask); then `mkdir -p .capture/261123-bcj` and
  `xcrun simctl create 'EhPanda iPhone Air (261123-bcj)' com.apple.CoreSimulator.SimDeviceType.iPhone-Air com.apple.CoreSimulator.SimRuntime.iOS-27-2 > .capture/261123-bcj/sim-udid`
  (if it fails, stop and ask). Every command below uses `UDID="$(cat .capture/261123-bcj/sim-udid)"`. Never touch any
  other simulator (other sessions' `261123-355` simulators exist).
- BUILD (tag `baseline` once at the untouched HEAD, then `taskN`):
  `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath .capture/261123-bcj/dd > $Q/build-<tag>.log 2>&1`;
  `grep -q 'TEST BUILD SUCCEEDED' $Q/build-<tag>.log` must exit 0. Baseline:
  `grep -E ': (warning|error): ' $Q/build-baseline.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u > $Q/warnings-baseline.txt`;
  task: `grep -E ': (warning|error): ' $Q/build-taskN.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u | comm -13 $Q/warnings-baseline.txt - > $Q/new-warnings-taskN.txt; test ! -s $Q/new-warnings-taskN.txt`
  must succeed. This build includes the VisualSnapshotTests and HostedViewTests targets.
- SWIFTLINT binary (after the baseline build):
  `SWIFTLINT="$(find "$PWD/.capture/261123-bcj/dd/SourcePackages/artifacts" -path '*SwiftLintBinary.artifactbundle/macos/swiftlint' -type f | head -1)"`
  (stop and ask if empty).
- LINT (tag, directories): `for d in <dirs>; do (cd "$d" && "$SWIFTLINT" lint --strict --quiet) || echo "LINT FAILED $d"; done > $Q/lint-<tag>.txt 2>&1`;
  the file must be empty. LINT-ALL directories: `AppPackage/Sources/TestingSupport`, every `AppPackage/Tests/*/`
  directory, and `EhPandaUITests`.
- TEST (tag): `xcodebuild test-without-building -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath .capture/261123-bcj/dd -collect-test-diagnostics never -skip-testing:VisualSnapshotTests -resultBundlePath $Q/test-<tag>.xcresult > $Q/test-<tag>.log 2>&1`;
  then `xcrun xcresulttool get test-results summary --path $Q/test-<tag>.xcresult > $Q/test-<tag>-summary.json` and
  `python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print(s["result"], s["passedTests"], s["failedTests"]); sys.exit(0 if s["result"]=="Passed" and s["failedTests"]==0 and s["passedTests"]>0 else 1)' $Q/test-<tag>-summary.json`
  must exit 0. Record the counts. The failure allowance differs by tag:
  - `baseline`, `task1`, `task2`: a failure is allowed only in a suite the SCOPE report of that tag lists as
    `[missing]` (it is still on the file-backed storage, the class being removed); for `baseline` that report is
    `$Q/scope-task1-start.txt`, which lists every in-scope suite as `[missing]`. Re-run each failed suite once, right
    away, with the same command plus `-only-testing:<Target>/<Suite>` into tag `<tag>-rerun`; it must pass. Record it.
    Judge `baseline` failures against the report as soon as Task 1 step 1 writes it, before any Swift edit. A failure
    in a suite that carries the trait or that no report lists, or any other failure: stop and ask.
  - `task3-run1`, `task3-run2`, `task3-run3`: no failure is allowed, and nothing is re-run. Any failure, a stale read
    included: stop and ask.
- LINT GATE (tag `baseline` once after the baseline build, `final` once after Task 3's commit):
  `python3 Scripts/lint/lint_check.py --output $Q/lint-check-<tag> --cloned-packages "$PWD/.capture/261123-bcj/dd/SourcePackages" > $Q/lint-check-<tag>.log 2>&1`
  must exit 0 (it builds every test plan fresh, so it is long). If the baseline exits non-zero, stop and ask.
- BASELINE (once, before any edit, at the untouched HEAD `e99c7bd60`, in this order): SIMULATOR, BUILD baseline,
  SWIFTLINT, LINT baseline over LINT-ALL, PY baseline (`Ran 24 tests`), TEST baseline, LINT GATE baseline. The scope
  baseline is Task 1's `task1-start` SCOPE (see SCOPE). Record the warning count, lint results, Python and test counts
  in the SUMMARY. If any step fails outside the TEST allowance, stop and ask.
- COMMIT (task N): stage exactly the task's files (`git add -- <files>`; Task 3 states its own staging);
  `git diff --cached --name-only | sort` must list exactly those files; `TZ=Asia/Shanghai git commit -m "<the task's message>"`
  as the configured identity with its GPG key (signing is on in the repository config; never pass `--no-verify` or
  `--no-gpg-sign`, never bypass a hook). Then `git log -1 --format='%G? %aI %cI'` must print `G` and two dates ending
  `+08:00`. If gpg's cache has expired, follow the unlock steps in `$HOME/Fork/EhPanda/AGENTS.local.md` and retry the
  same command. No attribution lines in the message.
- WRAP-UP (after Task 3's commit): LINT GATE final; then `xcrun simctl shutdown "$UDID"` (ignore "already shut down")
  and `xcrun simctl delete "$UDID"`; `xcrun simctl list devices | grep -F 'EhPanda iPhone Air (261123-bcj)'` must print
  nothing. Then write the SUMMARY.

### Open questions for the orchestrator (new after the revision; the plan proceeds with the stated default)

1. Decided by the planner (D-3 needs a second suite in one case): CaptureSceneTests'
   `theIsolatedStoresKeepPersonalSettingsOutOfTheScene` writes personal settings into one suite and the scene into
   another, so TestingSupport also exposes `withIsolatedAppStorage(_:)`, which the trait itself is built on. The
   personal suite is the case's own; the scene's comes from that function. Confirm the public helper.
2. Decided by the planner: the unary `configureVisualTestHost(_:)` overload (it only forwarded `firstLaunch:
   .answered`, and UITestStubTests was its one caller) is deleted rather than given a storage parameter too.
3. Informational (D-3 as written): the hosted VisualSnapshotTests reach the host through `prepareIfNeeded()`, the
   app path, so the host app's two suites there stay `.inMemory`, as the app's do. Their own per-site storage is
   `makeIsolatedAppStorage()` (Task 3).
4. Decided by the planner (D-4): the gate's summary sentence for a clean run, the `lint.yml` header and the
   `Scripts/visual/README.md` row that describes `lint.yml` gain the isolation check, so the docs say what the gate
   fails on. Confirm.
5. Housekeeping: the two planning reference copies (`261123-bcj-app_storage_isolation.py`,
   `261123-bcj-test_app_storage_isolation.py`) are the source Task 1 copies from, and are redundant afterwards; the
   plan never commits or edits them. Decide whether the orchestrator commits them with the planning docs or deletes
   them after Task 1.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Tracer: the isolatedAppStorage trait, its check, its test, and five suites on it</name>
  <files>Scripts/lint/app_storage_isolation.py, Scripts/lint/test_app_storage_isolation.py, AppPackage/Package.swift, AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift, AppPackage/Tests/AppModelsTests/IsolatedAppStorageTraitTests.swift, AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift, AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift, AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift, AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift, AppPackage/Tests/AppModelsTests/BlockedCommentUserTests.swift</files>
  <read_first>
    - .planning/quick/261123-bcj-isolate-test-app-storage-and-stop-cancel/261123-bcj-app_storage_isolation.py (docstring, `apply`, `report`)
    - .capture/261123-1dk/dd/SourcePackages/checkouts/swift-concurrency-extras/Sources/ConcurrencyExtrasTestSupport/TaskLocalTrait.swift (the witness shape to mirror)
    - .capture/261123-1dk/dd/SourcePackages/checkouts/swift-sharing/Sources/Sharing/SharedKeys/AppStorageKey.swift lines 305-353 and 572-640
    - AppPackage/Sources/TestingSupport/TestHelper.swift and TestFixtures.swift (import style of the module)
    - the five suite files (whole), and AppPackage/Package.swift lines 905-920, 1044-1110, 1183-1193
  </read_first>
  <behavior>
    - everyCaseStartsEmptyAndReadsItsOwnWrite, arguments [1, 2, 3]: each case's defaultAppStorage holds nothing under the probe key, then reads back exactly the value it wrote (no case sees another's write).
    - aScopeGetsItsOwnSuiteAndClearsItAtTheEnd: a scope the trait provides inside a case uses a different suite object from the case's own, and once the scope returns, the scope's suite holds nothing under the key written inside it.
    - aSecondSuiteIsSeparateAndClearedAtTheEnd: withIsolatedAppStorage hands its operation a suite that is not the case's, reads back what the operation wrote, and once it returns that suite holds nothing under the key while the case's suite was never written.
    - The five converted suites pass unchanged in what they assert; aRevealDoesNotOutliveTheScreen's two screens share the case's suite; ownCommentsGetNoReportOrBlock reads the signed-in name through the case's suite.
    - The isolation check's 12 hermetic tests pass beside test_lint_check.py's 24.
  </behavior>
  <action>
Implements D-1 end to end on one path, and brings in the D-4 check as a command (the lint gate starts running it in
Task 3, once nothing violates it). BASELINE runs first, at the untouched HEAD.

1. Copy the isolation check in, byte for byte (D-4): cp $R/261123-bcj-app_storage_isolation.py
Scripts/lint/app_storage_isolation.py and cp $R/261123-bcj-test_app_storage_isolation.py
Scripts/lint/test_app_storage_isolation.py; cmp each copy with its source (both must exit 0). Do not edit either file
in this plan. Then SCOPE task1-start, which must read HEAD: NEEDS 224, VIOLATIONS 231, 0 `[has]`, 224 `[missing]`,
and the READER_MODULES 17 line. Judge the BASELINE test failures against it now (see TEST). Then PY task1-copy must
report `Ran 36 tests` and OK.

2. AppPackage/Package.swift (per the "Package" design bullet): TestingSupport's dependencies become exactly
.module(.analyticsClient), .targetDependency(.composableArchitecture), .targetDependency(.kanna),
.targetDependency(.sharing), one per line; append .module(.testingSupport) as the new last element of the dependencies
array of analyticsClientTests, appModelsTests, detailFeatureTests and settingFeatureTests (add the comma to the previous
last element). Nothing else in the file changes.

3. Create AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift exactly as the "The trait" design bullet
specifies (imports, the free function withIsolatedAppStorage above the struct, type, conformances, isRecursive,
provideScope signature and body built on withIsolatedAppStorage, the static var). The function's doc comment, wording
fixed (wrap at 120 columns): "Runs `operation` with a fresh plain-named `UserDefaults` suite, and removes that suite's
persistent domain when `operation` returns or throws." then a blank doc line, then "The `.isolatedAppStorage` trait
gives every test case its suite this way. A case that needs a second suite beside its own calls this directly." The
struct's doc comment, wording fixed (wrap at 120 columns): "Gives each test case its own plain-named `UserDefaults`
suite as `defaultAppStorage`, and removes that suite's persistent domain when the case ends (quick task 261123-bcj,
D-1)." then a blank doc line, then "Why not Sharing's `UserDefaults.inMemory`, which is also the `defaultAppStorage`
dependency's test value: on iOS 17 and later it names its suite by a path under `NSTemporaryDirectory()`, which makes
the suite file-backed, and in the simulator test process, under parallel load, file-backed suites can stop reflecting
new writes. A later read then returns an earlier value, whether it is a fresh `@Shared` reference loading from the
suite or the app-storage key's external-change subscription reloading into a live one. A plain-named suite stays
read-after-write consistent." then a blank doc line, then "Applied to a suite, the trait is recursive and scopes each
test case: every argument of a parameterized test and every test of a nested suite gets a suite of its own. Everything
a case builds inherits it through the task-local dependencies (a `TestStore` or `Store` builds its reducer on them, and
a reducer state's `@Shared` property is built on them), unless the case overrides `defaultAppStorage` itself; a case
that needs the `UserDefaults` value reads `@Dependency(\.defaultAppStorage)`. Put it once, on the outermost suite type,
on every suite whose files import a module that reads app storage or use app storage directly." then a blank doc line,
then "`Scripts/lint/app_storage_isolation.py` states which suites those are, and the lint gate fails on a suite it
selects that lacks the trait." The static var's doc: "Isolates the app storage of every test case in the suite or
test it is applied to; see ``IsolatedAppStorageTrait``."

4. Create AppPackage/Tests/AppModelsTests/IsolatedAppStorageTraitTests.swift. Imports in this order: import
ComposableArchitecture, import Foundation, import Testing, import TestingSupport. A one-line doc on the type: "What
`.isolatedAppStorage` promises a case: a suite of its own, empty at the start and cleared at the end." Then
@Suite(.isolatedAppStorage) on struct IsolatedAppStorageTraitTests with private static let key = "isolatedAppStorageProbe"
and three tests, per the behavior block:
- @Test(arguments: [1, 2, 3]) func everyCaseStartsEmptyAndReadsItsOwnWrite(_ value: Int): declare
@Dependency(\.defaultAppStorage) var appStorage; #expect(appStorage.object(forKey: Self.key) == nil);
appStorage.set(value, forKey: Self.key); #expect(appStorage.integer(forKey: Self.key) == value).
- @Test func aScopeGetsItsOwnSuiteAndClearsItAtTheEnd() async throws: declare @Dependency(\.defaultAppStorage) var
caseStorage; let caseStorageID = ObjectIdentifier(caseStorage); let scoped = LockIsolated<UncheckedSendable<UserDefaults>?>(nil);
let trait: IsolatedAppStorageTrait = .isolatedAppStorage; let test = try #require(Test.current); then try await
trait.provideScope(for: test, testCase: Test.Case.current) with a multi-line trailing closure that declares @Dependency(\.defaultAppStorage) var
appStorage, expects ObjectIdentifier(appStorage) != caseStorageID, sets 1 under Self.key, then let wrapped =
UncheckedSendable(appStorage) and scoped.setValue(wrapped) (the closure captures only Sendable values); after it, let
suite = try #require(scoped.value).wrappedValue and #expect(suite.object(forKey: Self.key) == nil).
- @Test func aSecondSuiteIsSeparateAndClearedAtTheEnd() async throws: declare @Dependency(\.defaultAppStorage) var
caseStorage; let second = try await withIsolatedAppStorage with a multi-line trailing closure taking appStorage that
does #expect(appStorage !== caseStorage), appStorage.set(2, forKey: Self.key),
#expect(appStorage.integer(forKey: Self.key) == 2) and return appStorage; after it,
#expect(second.object(forKey: Self.key) == nil) and #expect(caseStorage.object(forKey: Self.key) == nil).

5. Convert the five suites by rules R1 to R10, then run python3 $T apply with exactly these five repo-relative paths
(it adds @Suite(.isolatedAppStorage) and import TestingSupport, and must print exactly five `applied` lines). File notes:
- InstallSignalSenderTests.swift: Harness loses its defaults stored property and the defaults: UserDefaults = .inMemory
init parameter (R5); relaunched(responses:) becomes Self(responses: responses); the test at about line 92 unwraps (R2);
Harness.ensureSent() reduces to await sender.ensureSent(), so it is deleted and every harness call site calls
.sender.ensureSent() directly (R7); the state accessor keeps @Shared(.installSignal) var state then return state; the
comments at about lines 13-14 and 280-281 are rewritten (R8).
- CommentModerationReducerTests.swift: makeModerationCommentsStore loses its UserDefaults parameter (R5), its let state =
withDependencies unwraps to let state = CommentsReducer.State(galleryURL: galleryURL, comments: Self.comments), its
TestStore closure loses the assignment; the calls at about lines 373 and 539 drop that argument; the tests at about lines 372, 480, 496 and 532
follow R1 to R4 (each storage local has no use left and is deleted). aRevealDoesNotOutliveTheScreen keeps both screens
on the one per-case suite (D-1: deliberate sharing).
- MyTagsFeatureTests.swift: theAccountRowPushesThePageWhichReads and makeStore follow R1, R2 and R4 (the defaults locals
are deleted; makeStore's statements are inlined with its return TestStore kept).
- LibraryPickerChoicePersistenceTests.swift: delete suiteName, the appStorage property, the throwing initializer and the
isolated de-initializer; the type becomes @MainActor struct LibraryPickerChoicePersistenceTests; stored() declares @Dependency(\.defaultAppStorage)
var appStorage as its first statement; makeStore follows R1 to R3 (its statements inlined, return store kept); the
type's doc paragraphs about the one defaults suite and the plain-named suite are replaced by one sentence saying every
case's stored record lives in the case's suite from .isolatedAppStorage, read straight from it.
- BlockedCommentUserTests.swift: theListPersistsUnderItsKeyAndStartsEmpty follows R4 (defaults becomes
@Dependency(\.defaultAppStorage) var defaults; suiteName and the defer go), R2 and R6 (it drops throws); its doc comment
follows R8.

Do not convert any other suite in this task, and do not touch lint_check.py, test_lint_check.py or any Sources file
other than the new trait file (D-3 lands in Task 3).
  </action>
  <verify>
    <automated>cmp $R/261123-bcj-app_storage_isolation.py Scripts/lint/app_storage_isolation.py [HEAD=absent EXPECT exit 0]; cmp $R/261123-bcj-test_app_storage_isolation.py Scripts/lint/test_app_storage_isolation.py [HEAD=absent EXPECT exit 0]; SCOPE task1-start: grep -cx 'NEEDS 224' [EXPECT==1], grep -cx 'VIOLATIONS 231' [EXPECT==1], grep -c ' \[has\]$' [EXPECT==0], grep -c ' \[missing\]$' [EXPECT==224], grep -c '^READER_MODULES 17: ' [EXPECT==1] (values measured on a scratch copy of HEAD); PY task1-copy: grep -c '^Ran 36 tests in ' [HEAD=Ran 24 EXPECT==1] and grep -cx 'OK' [EXPECT==1]; F=AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift: ex 'public struct IsolatedAppStorageTrait: SuiteTrait, TestScoping, TestTrait {' $F [HEAD=absent EXPECT==1]; ex 'public var isRecursive: Bool { true }' $F [HEAD=absent EXPECT==1]; ex 'performing function: @concurrent () async throws -> Void' $F [HEAD=absent EXPECT==1]; ex 'public func withIsolatedAppStorage<Result>(' $F [HEAD=absent EXPECT==1]; ex 'return try await operation(appStorage)' $F [HEAD=absent EXPECT==1]; ex 'try await withIsolatedAppStorage {' $F [HEAD=absent EXPECT==1]; ex 'public import Foundation' $F [HEAD=absent EXPECT==1]; ex 'let suiteName = "isolated-app-storage-\(UUID().uuidString)"' $F [HEAD=absent EXPECT==1]; ex 'appStorage.removePersistentDomain(forName: suiteName)' $F [HEAD=absent EXPECT==1]; ex 'removePersistentDomain' $F [HEAD=absent EXPECT==1 GUARD MUTATION: a removal of any other domain]; ex '$0.defaultAppStorage = appStorage' $F [HEAD=absent EXPECT==1]; ex 'public static var isolatedAppStorage: Self' $F [HEAD=absent EXPECT==1]; grep -c 'file-backed' $F [HEAD=absent EXPECT>=1]; grep -c 'app_storage_isolation.py' $F [HEAD=absent EXPECT==1]; G=AppPackage/Tests/AppModelsTests/IsolatedAppStorageTraitTests.swift: ex '@Suite(.isolatedAppStorage)' $G [HEAD=absent EXPECT==1], ex 'try await trait.provideScope(' $G [HEAD=absent EXPECT==1], ex 'try await withIsolatedAppStorage {' $G [HEAD=absent EXPECT==1], ex '@Test' $G [HEAD=absent EXPECT==3]; ex 'func ensureSent()' AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift [HEAD=1 EXPECT==0]; ex '.sender.ensureSent()' AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift [HEAD=0 EXPECT>=1]; ex 'storage:' AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift [HEAD=3 EXPECT==0]; ex 'deinit' AppPackage/Tests/AppFeatureTests/LibraryPickerChoicePersistenceTests.swift [HEAD=1 EXPECT==0]; for each of the five suite files: ex '@Suite(.isolatedAppStorage)' [HEAD=0 EXPECT==1] and ex 'import TestingSupport' [HEAD=0 EXPECT==1], and the same two counts on the trait test [HEAD=absent EXPECT==1]; ex '.module(.testingSupport)' AppPackage/Package.swift [HEAD=8 EXPECT==12]; IM_TESTS [HEAD=117 EXPECT==109]; SN_TESTS [HEAD=18 EXPECT==16]; AS_ST [HEAD=176 EXPECT==160]; TY_ST [HEAD=13 EXPECT==9]; IM_SRC [HEAD=2 EXPECT==2 GUARD MUTATION: a Sources .inMemory use edited in Task 1, where D-3 belongs to Task 3]; git status --porcelain > $Q/status-task1.txt (must exit 0), then grep -c '^?? AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift$' $Q/status-task1.txt [HEAD=0 EXPECT==1] and grep -c ' AppPackage/Sources/' $Q/status-task1.txt [HEAD=0 EXPECT==1 GUARD MUTATION: any other Sources file changed] and grep -cx '?? Scripts/lint/app_storage_isolation.py' $Q/status-task1.txt [HEAD=0 EXPECT==1] and grep -cx '?? Scripts/lint/test_app_storage_isolation.py' $Q/status-task1.txt [HEAD=0 EXPECT==1] and grep -c ' Scripts/' $Q/status-task1.txt [HEAD=0 EXPECT==2 GUARD MUTATION: lint_check.py or another script edited early] and grep -c 'Package.resolved' $Q/status-task1.txt [HEAD=0 EXPECT==0 GUARD MUTATION: a package added or re-resolved]; SCOPE task1: grep -cx 'NEEDS 225' [EXPECT==1], grep -cx 'VIOLATIONS 222' [EXPECT==1], grep -c ' \[has\]$' [HEAD(task1-start)=0 EXPECT==6], grep -c ' \[missing\]$' [HEAD(task1-start)=224 EXPECT==219] (simulated on the scratch copy); PY task1: Ran 36 tests, OK; awk 'END { exit NR > 1000 }' exits 0 on every touched Swift file (at most 1000 lines each); BUILD task1; LINT task1 over AppPackage/Sources/TestingSupport AppPackage/Tests/AnalyticsClientTests AppPackage/Tests/AppFeatureTests AppPackage/Tests/AppModelsTests AppPackage/Tests/DetailFeatureTests AppPackage/Tests/SettingFeatureTests; TEST task1-focused (the TEST command plus -only-testing:AppModelsTests/IsolatedAppStorageTraitTests -only-testing:AppModelsTests/BlockedCommentUserTests -only-testing:AnalyticsClientTests/InstallSignalSenderTests -only-testing:DetailFeatureTests/CommentModerationReducerTests -only-testing:SettingFeatureTests/MyTagsFeatureTests -only-testing:AppFeatureTests/LibraryPickerChoicePersistenceTests; no failure allowed); TEST task1</automated>
  </verify>
  <done>Every gate prints its EXPECT value; BUILD, LINT, PY, TEST task1-focused and TEST task1 pass (counts recorded); COMMIT task 1 with message "Add a test trait that isolates app storage" (the ten files of this task) and the signature check prints G and two +08:00 dates.</done>
</task>

<task type="auto">
  <name>Task 2: Bounded waits stop when the waiting task is cancelled</name>
  <files>AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift, AppPackage/Tests/DownloadsFeatureTests/DownloadProcessCacheTests.swift</files>
  <read_first>
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift lines 128-142 and 984-996
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift lines 686-760
    - AppPackage/Tests/DownloadsFeatureTests/DownloadProcessCacheTests.swift lines 268-280
  </read_first>
  <action>
Implements D-2. Change only these loop conditions and one doc comment; no line is added to
DownloadFeatureTestHelpers.swift (996 lines) or DownloadProcessCacheTests.swift.
- DownloadFeatureTestHelpers.swift, drainDetailMetadataEffects: the condition line becomes
`while !condition() && deadline.hasTimeLeft() && !Task.isCancelled {`; the trailing skipReceivedActions call after the
loop stays (its normal outcome).
- DownloadFeatureTestHelpers.swift, waitUntil: the condition line becomes
`while await !condition(), deadline.hasTimeLeft(), !Task.isCancelled {`; the try #require after it stays, so a cancelled
wait whose condition does not hold fails it as today.
- DownloadFeatureTestSupportTypes.swift, waitUntilSettled: the same condition line as waitUntil; it still returns
await condition().
- DownloadProcessCacheTests.swift, waitUntilCacheCleared: the loop's second condition line becomes
`              deadline.hasTimeLeft(), !Task.isCancelled {` (indentation unchanged).
- DownloadFeatureTestSupportTypes.swift, sleepIgnoringCancellation's doc comment: after its last existing line
("/// to that predicate rather than unwind past it."), add exactly these four lines, each indented like the rest of the
doc comment (column 0): a bare "///"; then "/// A cancelled sleep returns at once, so every loop that calls this must
also stop on" as one line; then "/// `Task.isCancelled`: once its task is cancelled, a loop that checks only its own
predicate or" as one line; then "/// deadline spins at full speed until the predicate holds or the deadline passes." as
one line. (Each quoted line is a single source line; this plan only wraps them for reading.)
The other sleepIgnoringCancellation loops already exit on Task.isCancelled (CONTEXT D-2 audit) and stay unchanged.
  </action>
  <verify>
    <automated>H=AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift; S=AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift; P=AppPackage/Tests/DownloadsFeatureTests/DownloadProcessCacheTests.swift; ex 'while !condition() && deadline.hasTimeLeft() && !Task.isCancelled {' $H [HEAD=0 EXPECT==1]; ex 'while !condition() && deadline.hasTimeLeft() {' $H [HEAD=1 EXPECT==0]; ex 'while await !condition(), deadline.hasTimeLeft(), !Task.isCancelled {' $H [HEAD=0 EXPECT==1]; ex 'while await !condition(), deadline.hasTimeLeft() {' $H [HEAD=1 EXPECT==0]; ex 'while await !condition(), deadline.hasTimeLeft(), !Task.isCancelled {' $S [HEAD=0 EXPECT==1]; ex 'while await !condition(), deadline.hasTimeLeft() {' $S [HEAD=1 EXPECT==0]; ex 'deadline.hasTimeLeft(), !Task.isCancelled {' $P [HEAD=0 EXPECT==1]; grep -c 'must also stop on' $S [HEAD=0 EXPECT==1]; awk 'END { print NR }' $H [HEAD=996 EXPECT==996 GUARD MUTATION: a line added to the 996-line helper file]; awk 'END { print NR }' $P [HEAD=310 EXPECT==310 GUARD MUTATION: a line added to the cache test]; git diff --numstat > $Q/numstat-task2.txt (must exit 0), then grep -c 'DownloadFeatureTestSupportTypes.swift$' $Q/numstat-task2.txt [HEAD=0 EXPECT==1] with that line starting '5<TAB>1<TAB>' (one condition line replaced, four doc lines added), the DownloadFeatureTestHelpers.swift line starting '2<TAB>2<TAB>', the DownloadProcessCacheTests.swift line starting '1<TAB>1<TAB>', and awk 'END { print NR }' $Q/numstat-task2.txt [HEAD=0 EXPECT==3] (no other file changed); SCOPE task2: grep -cx 'NEEDS 225' [EXPECT==1], grep -cx 'VIOLATIONS 222' [EXPECT==1], grep -c ' \[has\]$' [HEAD(task1)=6 EXPECT==6], grep -c ' \[missing\]$' [HEAD(task1)=219 EXPECT==219] (unchanged from task1); BUILD task2; LINT task2 over AppPackage/Tests/DownloadsFeatureTests; TEST task2 (includes DownloadSourceInventoryTests)</automated>
  </verify>
  <done>Every gate prints its EXPECT value; BUILD, LINT and TEST task2 pass (counts recorded); COMMIT task 2 with message "Stop cancelled test waits from spinning" (the three files) and the signature check prints G and two +08:00 dates.</done>
</task>

<task type="auto">
  <name>Task 3: Every app-storage suite on the trait, caller-owned UI-test storage, and both bans</name>
  <files>AppPackage/Package.swift, .swiftlint.yml, AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift, AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift, AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift, the Task 3 conversion worklist (context section), every file the isolation check's apply edits, AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift (new), AppPackage/Tests/VisualSnapshotTests/VisualTracerTests.swift, AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift, AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift, AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift, Scripts/lint/lint_check.py, Scripts/lint/test_lint_check.py, .github/workflows/lint.yml, Scripts/visual/README.md</files>
  <read_first>
    - Scripts/lint/app_storage_isolation.py (docstring, `violations`, `apply`) and $Q/scope-task2.txt
    - AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift (withIsolatedAppStorage, from Task 1)
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift lines 236-250 and 300-350; CaptureScenePreparation.swift lines 255-320; AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift lines 48-62
    - AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift lines 513-560; UITestStubTests.swift lines 12-20 and 326-334; the isolate call of CaptureRouteTests (about line 92), CaptureTagTranslationTests (about line 76), CaptureLiveTextRecordTests (about line 63), CaptureDownloadTests (about line 213)
    - each other worklist file around its listed sites (grep -n for inMemory, defaultAppStorage, UserDefaults first, then read those regions)
    - AppPackage/Tests/VisualSnapshotTests/VisualTracerTests.swift lines 55-70 and 170-195, VisualMatrixTests.swift lines 105-120, FullContentFeasibilityTests.swift lines 225-250 and 395-410, Matrix/SnapshotMatrixCase.swift lines 155-175
    - .swiftlint.yml (the no_geometry_reader rule and its neighbours)
    - Scripts/lint/lint_check.py (whole), Scripts/lint/test_lint_check.py (whole), .github/workflows/lint.yml lines 1-14, Scripts/visual/README.md line 31
  </read_first>
  <action>
Implements the rest of D-1, then D-3, then lands both bans (the SwiftLint rule of D-1 and the D-4 gate), in this
order. Placement of D-3 here rather than in Task 1: its six test callers are AppFeatureTests suites this task converts
anyway (CaptureRouteTests, CaptureSceneTests and UITestStubTests are on the worklist), so the API change and every
caller land in one commit without touching those suites twice, and the tracer keeps its one-path shape.

1. AppPackage/Package.swift: append .module(.testingSupport) as the new last element of the dependencies array of
favoritesFeatureTests, galleryListComponentsTests and systemNotificationTests. Nothing else changes.

2. Run python3 $T apply (no file arguments). It must exit 0 and print 216 `applied` lines. Then SCOPE task3-applied:
NEEDS 225, VIOLATIONS 0, 225 `[has]`, 0 `[missing]`.

3. D-3, Sources, per the "UI-test helpers take their storage from the caller" design bullet:
- UITestAutomation.swift: delete the unary configureVisualTestHost overload (its two doc lines, its three lines and the
blank line after it). The remaining configureVisualTestHost gets the parameters `_ dependencies: inout DependencyValues`,
`firstLaunch: FirstLaunchPreset?` and `appStorage: UserDefaults`, one per line; in its body delete the local declaration
that builds the in-memory suite and the one comment line directly above it; nothing else in
the body changes. Its doc comment becomes, wording fixed (wrap at 120 columns): "Install isolated fixtures both for
hosted rendering and explicitly on the app's Store." then "Global preparation alone cannot bind the host Store to
fixtures when XCTest changes scopes." then a blank doc line, then "`appStorage` becomes the host's app storage, and the
first-launch answers `firstLaunch` asks for are written into it; `nil` leaves its never-answered defaults. The UI-test
app passes a fresh `UserDefaults.inMemory`, a unit test the suite of its test case." In prepare(environment:now:) the
call becomes three lines: `configureVisualTestHost(`, then one level in
`&$0, firstLaunch: configuration.firstLaunchPreset, appStorage: .inMemory`, then `)`.
- CaptureScenePreparation.swift: isolate's parameter list gains `appStorage: UserDefaults` as its own last line (comma
added after `launch: CaptureLaunchInputs`); in its body delete only the local declaration that builds the in-memory
suite (the body keeps using `appStorage`). Its doc comment gains a blank doc line and then, wording fixed (wrap at 120
columns): "`appStorage` is the scene's app storage, which the scene's settings are written into: the capture launch
passes a fresh `UserDefaults.inMemory`, a unit test the suite of its test case." In install, the isolate call gains
`appStorage: .inMemory` as its own last argument line, at the indentation of `launch:`, after a comma added to the
`launch:` argument's closing parenthesis line.
- AppDelegateReducer.swift: the middle line of the configureVisualTestHost call becomes
`&dependencies, firstLaunch: configuration.firstLaunchPreset, appStorage: .inMemory`. Nothing else changes.
No other Sources file changes.

4. Convert every Swift Testing file of the worklist by rules R1 to R10 (the files listed under AnalyticsClientTests to
SettingFeatureTests). Notes: UITestStubTests, CaptureRouteTests and CaptureSceneTests also take the D-3 edits below;
the four plain-named files lose their suiteName locals and defers (R4); WebtoonReadingTests' makeState, makeStore,
persistedEntry and seedVerdict, AppReadingFlushTests' and ReadingReducerFlushTests' persistedProgress,
AppReducerScenePhaseTests' helper and both AnalyticsClientTests harnesses lose their UserDefaults parameters and
properties (R5); harness methods that R2 reduces to a forwarding call go (R7). D-3 test edits:
- CaptureRouteTests (about line 92), CaptureTagTranslationTests (about line 76), CaptureLiveTextRecordTests (about line
63), CaptureDownloadTests (about line 213): directly above the line that starts the withDependencies call whose update
closure calls CaptureScenePreparation.isolate, at its indentation, add @Dependency(\.defaultAppStorage) var appStorage;
the isolate call gains `appStorage: appStorage` as its own last argument line, at the indentation of `launch:`, after a
comma added to the `launch:` argument's closing parenthesis.
- UITestStubTests: hostedStoreKeepsItsFixturesWhenTheCallingTestScopeChanges and
aVisualHostShownTheFirstLaunchStartsLocked each get @Dependency(\.defaultAppStorage) var appStorage as their first
statement. In the first, the Store's labeled withDependencies argument, which today names the deleted overload, becomes
a closure over three lines: `withDependencies: {`, then one level in
`UITestAutomation.configureVisualTestHost(&$0, firstLaunch: .answered, appStorage: appStorage)`, then `}`. In the
second, the trailing closure's call becomes
`UITestAutomation.configureVisualTestHost(&$0, firstLaunch: .cleared, appStorage: appStorage)`.
- CaptureSceneTests.theIsolatedStoresKeepPersonalSettingsOutOfTheScene (this settles its two-suite case, so R10 does not
apply to it): the personal local goes (R4: no use left after R1); the personal suite is now the case's own. Inlining
the first and the last withDependencies calls (each left with an empty update closure) would declare `setting` twice
in one scope, so each becomes a `do {` block holding its operation statements, which keeps each declaration in a scope
of its own as before. The middle call becomes `try await withIsolatedAppStorage { sceneStorage in`, then that
withDependencies call one level in, with its update closure reduced to the isolate call and that call given
`appStorage: sceneStorage` as its own last argument line (comma added after the `launch:` argument), its operation
closure unchanged, then `}`. Nothing else in the test changes.

5. XCTest (VisualSnapshotTests), per the "XCTest" design bullet: create AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift
with makeIsolatedAppStorage() and this doc comment, wording fixed: "A fresh plain-named app-storage suite whose
persistent domain is removed when the case tears down: the XCTest counterpart of TestingSupport's `.isolatedAppStorage`
trait, which this target cannot link. Not `UserDefaults.inMemory`, whose suite is file-backed and goes stale under
parallel load. Each call gives a suite of its own, so a capture loop keeps one per coordinate." Then: in
VisualTracerTests.swift at both sites, FullContentFeasibilityTests.swift at about line 240 and SnapshotMatrixCase.swift at
about line 166, the `let appStorage` declaration's right-hand side becomes `try makeIsolatedAppStorage()`; in
VisualMatrixTests.swift at about line 116 and FullContentFeasibilityTests.swift at about line 405, add
`let appStorage = try makeIsolatedAppStorage()` as the statement directly before the withDependencies call (before the
`return` for line 405) and change the assignment to `$0.defaultAppStorage = appStorage`. Every other line of those files
stays, ScenarioCatalog+Settings.swift included.

6. Insert the no_in_memory_user_defaults rule into .swiftlint.yml exactly as the context section gives it, directly
after the no_geometry_reader rule.

7. Lint probe (mutation gate): create AppPackage/Tests/AppModelsTests/NoInMemoryUserDefaultsProbe.swift with exactly the
eight lines of the context section; run (cd AppPackage/Tests/AppModelsTests && "$SWIFTLINT" lint --no-cache --reporter json NoInMemoryUserDefaultsProbe.swift) > $Q/lint-probe.json
(its exit status is ignored); then python3 -c 'import json,sys; v=json.load(open(sys.argv[1])); l=sorted(x["line"] for x in v if x["rule_id"]=="no_in_memory_user_defaults"); print(l); sys.exit(0 if l==[1,2,3,4] else 1)' $Q/lint-probe.json
must exit 0; then delete the probe file, and test ! -e AppPackage/Tests/AppModelsTests/NoInMemoryUserDefaultsProbe.swift.

8. The lint gate runs the isolation check (D-4), per "The isolation check" design bullet:
- Scripts/lint/lint_check.py: after the line `import xml.etree.ElementTree as ElementTree`, add a blank line and
`import app_storage_isolation`. Directly after the lint function, add `def app_storage_findings(root):` with the
docstring "The breaks of the app-storage isolation rule, each an error at its place; a tree the check cannot read is
one finding." Its body calls app_storage_isolation.violations(root) through the module attribute (so a test can patch
it) inside a try; on app_storage_isolation.ScopeError it returns the one-element set of
Finding('', 0, 0, 'error', f'The app-storage isolation check could not read the tree: {error}'); otherwise it returns the
set of Finding(item.path, item.line, 1 if item.line else 0, 'error', item.message) over the violations. In main(), the
`found = set()` line directly after the `packages = …` line is replaced by two lines:
print('Checking the app-storage isolation rule.', flush=True) and found = app_storage_findings(ROOT). In summary(), the
clean-run list becomes two adjacent string literals inside the brackets, one per line, reading together, wording fixed:
"No compiler warning or error, no SwiftLint violation in any target of this repository, and no break of the
app-storage isolation rule." (the first literal ends with "no break of " and the second starts with "the app-storage").
In the module docstring, directly before the paragraph that starts "It builds every test plan", add this paragraph,
wording fixed (wrap at 120 columns): "Before the builds it checks the app-storage isolation rule over the test sources
(`app_storage_isolation.py`, whose docstring states the rule and the targets it leaves out): every Swift Testing suite
that can reach app storage carries TestingSupport's `.isolatedAppStorage` trait, and no other suite does. It reads the
sources alone, so it needs no build. Each break is an error finding, and so is a tree the check cannot read." Nothing
else in the file changes.
- Scripts/lint/test_lint_check.py: add `from unittest import mock` directly after `import unittest`, and
`import app_storage_isolation` directly before `import lint_check`. Before the `if __name__` block, add
class AppStorageIsolationTests(unittest.TestCase) with three tests:
test_each_break_of_the_rule_is_an_error_finding_at_its_place (with mock.patch.object(app_storage_isolation,
'violations', return_value=…) over the two values Violation('AppPackage/Tests/SomeTests/Some.swift', 4, 'The suite Some
can reach app storage and has no .isolatedAppStorage trait.') and Violation('AppPackage/Package.swift', 0, 'The test
target SomeTests holds suites that need .isolatedAppStorage and does not link TestingSupport.'), assertEqual of
lint_check.app_storage_findings(ROOT) with the set of Finding('AppPackage/Tests/SomeTests/Some.swift', 4, 1, 'error',
<the first message>) and Finding('AppPackage/Package.swift', 0, 0, 'error', <the second message>));
test_a_tree_the_check_cannot_read_is_a_finding (patched with side_effect=app_storage_isolation.ScopeError('no app-storage
keys'), assertEqual with the set of the one Finding('', 0, 0, 'error', 'The app-storage isolation check could not read
the tree: no app-storage keys')); test_every_suite_of_this_repository_keeps_the_app_storage_isolation_rule
(assertEqual(lint_check.app_storage_findings(ROOT), set()), on the live tree). Lines stay within 120 columns.
- .github/workflows/lint.yml: after the header line "# repository's code triggers fails, whichever library defined it."
add a bare `#` line and then this paragraph as comment lines, wording fixed (wrap at 118 columns, the script path on
one line): "It fails, too, on a break of the app-storage isolation rule, which it checks before the build
(Scripts/lint/app_storage_isolation.py): a Swift Testing suite that can reach app storage and lacks TestingSupport's
`.isolatedAppStorage` trait, or the trait where the rule does not ask for it."
- Scripts/visual/README.md, the `lint.yml` row: the text "except a warning located inside a third-party package
(`Scripts/lint/lint_check.py`)" is followed by "; a break of the app-storage isolation rule fails it too
(`Scripts/lint/app_storage_isolation.py`)" before the cell's closing ` |`. Nothing else in the file changes.

9. Run the gates, then commit: git add -A -- AppPackage .swiftlint.yml Scripts/lint .github/workflows/lint.yml
Scripts/visual/README.md; git diff --cached --name-only must list only AppPackage/Package.swift, .swiftlint.yml, paths
under AppPackage/Tests/, the three Sources files of step 3, Scripts/lint/lint_check.py, Scripts/lint/test_lint_check.py,
.github/workflows/lint.yml and Scripts/visual/README.md; after staging, git status --porcelain > $Q/status-staged.txt
(must exit 0) and grep -vc ' \.planning/' $Q/status-staged.txt must count exactly the staged files (every other line is
under .planning/), and git diff --name-only (unstaged changes) must print nothing.
  </action>
  <verify>
    <automated>python3 $T check > $Q/check-task3.txt [HEAD(task2)=exit 1 EXPECT exit 0] and grep -c '^0 break(s) of the app-storage isolation rule\.$' $Q/check-task3.txt [EXPECT==1]; SCOPE task3: grep -cx 'NEEDS 225' [EXPECT==1], grep -cx 'VIOLATIONS 0' [HEAD(task2)=VIOLATIONS 222 EXPECT==1], grep -c ' \[has\]$' [HEAD(task2)=6 EXPECT==225], grep -c ' \[missing\]$' [HEAD(task2)=219 EXPECT==0] (simulated); cmp $R/261123-bcj-app_storage_isolation.py Scripts/lint/app_storage_isolation.py and cmp $R/261123-bcj-test_app_storage_isolation.py Scripts/lint/test_app_storage_isolation.py [EXPECT exit 0 GUARD MUTATION: the check edited instead of the tree]; PY task3: grep -c '^Ran 39 tests in ' [HEAD(task2)=Ran 36 EXPECT==1] and grep -cx 'OK' [EXPECT==1]; L=Scripts/lint/lint_check.py: grep -cx 'import app_storage_isolation' $L [HEAD=0 EXPECT==1], grep -c '^def app_storage_findings(root):$' $L [HEAD=0 EXPECT==1], grep -cx '    found = app_storage_findings(ROOT)' $L [HEAD=0 EXPECT==1], grep -cx '    found = set()' $L [HEAD=2 EXPECT==1], grep -c "print('Checking the app-storage isolation rule.', flush=True)" $L [HEAD=0 EXPECT==1], grep -c 'app_storage_isolation.violations(root)' $L [HEAD=0 EXPECT==1]; grep -c '^class AppStorageIsolationTests(unittest.TestCase):$' Scripts/lint/test_lint_check.py [HEAD=0 EXPECT==1]; grep -c 'Scripts/lint/app_storage_isolation.py' .github/workflows/lint.yml [HEAD=0 EXPECT==1]; grep -c 'Scripts/lint/app_storage_isolation.py' Scripts/visual/README.md [HEAD=0 EXPECT==1]; U=AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift, K=AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift, D=AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift: ex 'let appStorage = UserDefaults.inMemory' $U [HEAD=1 EXPECT==0] and $K [HEAD=1 EXPECT==0]; ex 'appStorage: UserDefaults' $U [HEAD=0 EXPECT==1] and $K [HEAD=0 EXPECT==1]; ex 'appStorage: .inMemory' $U [HEAD=0 EXPECT==1], $K [HEAD=0 EXPECT==1], $D [HEAD=0 EXPECT==1]; ex 'static func configureVisualTestHost(' $U [HEAD=2 EXPECT==1]; grep -c 'One suite, held' $U [HEAD=1 EXPECT==0]; IM_SRC [HEAD=2 EXPECT==3 UNPINNED]; S=AppPackage/Tests/AppFeatureTests/UITestStubTests.swift: ex 'withDependencies: UITestAutomation.configureVisualTestHost' $S [HEAD=1 EXPECT==0], ex 'firstLaunch: .answered, appStorage: appStorage)' $S [HEAD=0 EXPECT==1], ex 'firstLaunch: .cleared, appStorage: appStorage)' $S [HEAD=0 EXPECT==1], ex '@Dependency(\.defaultAppStorage) var appStorage' $S [HEAD=0 EXPECT==2]; for each of CaptureRouteTests.swift, CaptureTagTranslationTests.swift, CaptureLiveTextRecordTests.swift, CaptureDownloadTests.swift under AppPackage/Tests/AppFeatureTests: ex 'appStorage: appStorage' [HEAD=0 EXPECT==1] and ex '@Dependency(\.defaultAppStorage) var appStorage' [HEAD=0 EXPECT==1]; CS=AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift: ex 'try await withIsolatedAppStorage {' $CS [HEAD=0 EXPECT==1], ex 'appStorage: sceneStorage' $CS [HEAD=0 EXPECT==1], ex 'let personal' $CS [HEAD=1 EXPECT==0], ex 'do {' $CS [HEAD=0 EXPECT==2]; grep -rn 'configureVisualTestHost' AppPackage/Tests EhPandaUITests --include='*.swift' | grep -c 'appStorage: appStorage' [HEAD=0 EXPECT==2]; ex '.module(.testingSupport)' AppPackage/Package.swift [HEAD=12 EXPECT==15 UNPINNED]; IM_TESTS [HEAD=109 EXPECT==0 UNPINNED]; SN_TESTS [HEAD=16 EXPECT==1 UNPINNED] (the one line is in AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift); AS_ST [HEAD=160 EXPECT==0 UNPINNED]; TY_ST [HEAD=9 EXPECT==0 UNPINNED]; grep -c '@Shared(.inMemory(' AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift [HEAD=2 EXPECT==2 GUARD MUTATION: an InMemoryKey use mistaken for UserDefaults and converted]; ex 'try makeIsolatedAppStorage()' on VisualTracerTests.swift [HEAD=0 EXPECT==2], FullContentFeasibilityTests.swift [HEAD=0 EXPECT==2], VisualMatrixTests.swift [HEAD=0 EXPECT==1], Matrix/SnapshotMatrixCase.swift [HEAD=0 EXPECT==1]; ex 'addTeardownBlock' AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift [HEAD=absent EXPECT==1]; ex 'removePersistentDomain(forName: suiteName)' AppPackage/Tests/VisualSnapshotTests/IsolatedAppStorage.swift [HEAD=absent EXPECT==1]; grep -c '^  no_in_memory_user_defaults:$' .swiftlint.yml [HEAD=0 EXPECT==1]; the lint probe check exits 0 and the probe file is gone; git status --porcelain > $Q/status-task3.txt (must exit 0), then grep -c ' AppPackage/Sources/' $Q/status-task3.txt [HEAD=0 EXPECT==3 GUARD MUTATION: a Sources file outside D-3 edited], grep -cx ' M AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift' [HEAD=0 EXPECT==1], grep -cx ' M AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift' [HEAD=0 EXPECT==1], grep -cx ' M AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift' [HEAD=0 EXPECT==1], grep -c ' Scripts/lint/' $Q/status-task3.txt [HEAD=0 EXPECT==2 GUARD MUTATION: the check module or its tests edited] and grep -c 'Package.resolved' $Q/status-task3.txt [HEAD=0 EXPECT==0 GUARD MUTATION: a package added or re-resolved]; awk 'END { exit NR > 1000 }' exits 0 on every changed Swift file (at most 1000 lines each); BUILD task3; LINT task3 over LINT-ALL plus AppPackage/Sources/AppFeature; TEST task3-run1, then TEST task3-run2, then TEST task3-run3 (one after another, each to completion, zero failures each)</automated>
  </verify>
  <done>Every gate prints its EXPECT value; BUILD, LINT and PY task3 pass; the three full runs pass with zero failures (counts of each recorded); COMMIT task 3 with message "Isolate app storage in every test suite" and the signature check prints G and two +08:00 dates; then WRAP-UP: LINT GATE final exits 0, and in $Q/lint-check-final.log grep -cx 'Checking the app-storage isolation rule.' prints 1 [HEAD=0 EXPECT==1] and grep -c 'and no break of the app-storage isolation rule.' prints 1 [HEAD=0 EXPECT==1] (the gate ran the check and found nothing); the simulator is deleted; the SUMMARY is written, recording the per-task scope reports, the Python counts, the reruns allowed at baseline, task1 and task2 (if any), and the three final counts.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test case → test case | cases share one test process; app storage must not carry state between them |
| test process → simulator preferences store | the trait and the XCTest helper create and remove preference domains |
| future test code → lint rule | a reintroduced `.inMemory` must be rejected at build and lint time |
| future test code → lint gate | a suite that can reach app storage without the trait must fail the gate |
| UI-test app → its app storage | the app's hosted and capture launches keep a fresh suite of their own |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-bcj-01 | Tampering | test isolation (stale or bled app storage) | high | mitigate | per-case plain-named suite with a UUID name (Task 1), on every suite the isolation rule selects (`check` exits 0, Task 3), and the two UI-test helpers given the case's suite instead of building a file-backed one (D-3, Task 3); per-case, end-of-scope and second-suite tests in IsolatedAppStorageTraitTests |
| T-bcj-02 | Tampering | `removePersistentDomain` in the trait and the XCTest helper | medium | mitigate | each removes only the name it generated; gates count exactly one `removePersistentDomain` per file, on `suiteName` |
| T-bcj-03 | Denial of service | cancelled bounded waits spinning up to 30 s | medium | mitigate | `!Task.isCancelled` in all four loop conditions (Task 2 gates) |
| T-bcj-04 | Repudiation | `.inMemory` user defaults reintroduced in tests | medium | mitigate | `no_in_memory_user_defaults` error rule plus the eight-line probe proving positives and negatives (Task 3) |
| T-bcj-05 | Repudiation | a future suite that reaches app storage without `.isolatedAppStorage` | medium | mitigate | `lint_check.py` turns every break of `app_storage_isolation.violations` into an error finding before the builds, an unreadable tree included; mocked and live tests in `test_lint_check.py`, 12 hermetic rule tests, and the final gate log showing the check ran (Tasks 1 and 3, D-4) |
| T-bcj-06 | Tampering | UI-test app storage after the D-3 signature change | low | mitigate | each of the three app call sites passes a fresh `.inMemory`, as before; per-file gates and IM_SRC == 3 (Task 3) |
| T-bcj-SC | Tampering | npm/pip/cargo installs | low | mitigate | no package is installed or added; `Package.resolved` unchanged (gate in Tasks 1 and 3) |
</threat_model>

<verification>
- BASELINE recorded; Tasks 1 and 2 each pass BUILD, LINT and TEST within their allowance (Task 1 also PY); Task 3
  passes BUILD, LINT-ALL, PY, the isolation `check` and three consecutive full TEST runs with zero failures; LINT GATE
  final exits 0 and its log shows the isolation check ran.
- Source audit (all items covered): GOAL (isolate test app storage, stop cancelled waits) Tasks 1-3; D-1 trait shape
  Task 1; D-1 replace every `.inMemory` Tasks 1 and 3; D-1 TestStore inheritance Task 1 (design, the five suites) and
  Task 3; D-1 suites without `defaultAppStorage` Task 3 (scope rule); D-1 XCTest Task 3; D-1 lint rule scoped to test
  directories and not matching FileStorage Task 3 (rule and probe); D-1 deliberate sharing Task 1
  (aRevealDoesNotOutliveTheScreen); D-1 e2427c16b suites Task 1; D-1 doc-comment the why Task 1; D-2 four helpers and
  the doc requirement Task 2; D-3 the two helpers take the caller's storage, unit tests pass the case's suite, the
  UI-test app's call sites keep a fresh `.inMemory` Task 3; D-4 the check in `Scripts/lint` with its tests Task 1, run
  by the lint gate and failing it, with a live test and the docs, Task 3, exclusions stated in the check's docstring
  and `OUT_OF_SCOPE`; orchestrator calls: per-site `makeIsolatedAppStorage()` with `addTeardownBlock` Task 3, the four
  plain-named files converted Task 3, HostedViewTests excluded (the check), the trait test in AppModelsTests Task 1,
  self-contained tasks (context section). REQ: none for a quick task. RESEARCH: none (no research phase). D-3
  supersedes D-1's "the two Sources uses stay".
</verification>

<success_criteria>
- `python3 Scripts/lint/app_storage_isolation.py check` exits 0 with 225 suites on `.isolatedAppStorage`, and the lint
  gate runs that check and exits 0.
- `CaptureScenePreparation.isolate` and `UITestAutomation.configureVisualTestHost` take their `UserDefaults` from the
  caller; no unit test reaches a file-backed suite through them, and the UI-test app passes a fresh `.inMemory`.
- Zero `.inMemory` user defaults, zero `defaultAppStorage` assignments and zero `UserDefaults` parameters or
  properties in the Swift Testing test files; the lint rule rejects the class.
- The full FeatureTests plan passes three times in a row with zero failures.
- Three signed commits with +08:00 dates; nothing merged or pushed; the simulator deleted.
</success_criteria>

<output>
Create `.planning/quick/261123-bcj-isolate-test-app-storage-and-stop-cancel/261123-bcj-SUMMARY.md` when done.
</output>
