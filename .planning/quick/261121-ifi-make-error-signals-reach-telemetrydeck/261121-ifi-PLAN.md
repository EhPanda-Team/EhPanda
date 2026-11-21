---
phase: 261121-ifi-make-error-signals-reach-telemetrydeck
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift
  - AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift
  - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift
  - AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift
  - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
  - AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
  - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
  - AppPackage/Sources/SearchFeature/SearchReducer.swift
  - AppPackage/Sources/DetailFeature/DetailReducer.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesReducer.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift
  - AppPackage/Sources/DetailFeature/FolderManager/FolderManagerReducer.swift
  - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
  - AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift
  - AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift
  - AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift
  - AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/DetailFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift
  - AppPackage/Tests/ReadingFeatureTests/AnalyticsEmissionTests.swift
  - "(conditional) existing test files under AppPackage/Tests/ whose stores newly reach AnalyticsClient.send through a failure transition; only the store's analytics dependency or an exhaustive state assertion changes (see the sweep rule)"
autonomous: true
requirements: [QUICK-261121-ifi]

estimate:
  tokens: 300000
  raw_tokens: 300000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "An unsupported deep link shows its error toast and sends exactly one errorSurfaced(.unsupportedDeepLink, screen: .deepLink); a deep-link gallery that fails to load sends exactly one errorSurfaced(<its kind>, screen: .deepLink); a caption-only or loading toast sends nothing (Approach decision)."
    - "No toast-setting action is left in PresentationFeature: every way the toast becomes an error toast, including a direct state assignment, is counted, because the signal follows the state and not an action (Approach decision)."
    - "Every inline error state a view renders (list, footer, Home's popular block, detail and its archives, torrents and detail-search screens, the folder manager, the download inspector, the E-Hentai settings page and the reader page) sends exactly one errorSurfaced(kind, screen:) per transition into .failed; re-assigning the same failed state sends nothing; a retry that fails again sends again (Claude's discretion, as recorded in CONTEXT)."
    - "Each signal carries the screen as a closed ErrorScreen spelling under the parameter key Error.screen; every ErrorScreen case is used by at least one call site and every call site uses exactly one case (Screen parameter, owner decision 2026-11-21)."
    - ".notFound is sent as its own kind wherever it is shown, History included (Empty results, owner decision 2026-11-21)."
    - "Within one reader presentation a given error kind on the reader screen is sent at most once, however many pages fail with it; the next presentation starts fresh (Reader page-image failures, owner decision 2026-11-21)."
    - "The payload stays a closed AppErrorKind id, its category and the Error.screen spelling: no String, URL or content value; errorSurfaced stays at Basic; login failures still send only loginFailed; failure states that no view renders send nothing."
  artifacts:
    - path: "AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift"
      provides: "The state-observing reducer operator that turns transitions into .failed (or into an error toast) into errorSurfaced signals"
      contains: "func signalsErrors"
    - path: "AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift"
      provides: "The closed ErrorScreen vocabulary (17 cases)"
      contains: "enum ErrorScreen"
    - path: "AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift"
      provides: "errorSurfaced carrying the screen"
      contains: "case errorSurfaced(AppErrorKind, screen: ErrorScreen)"
    - path: "AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift"
      provides: "The Error.screen parameter key, minted at the single literal site"
      contains: "\"Error.screen\""
    - path: "AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift"
      provides: "Transition, dictionary and per-kind de-duplication semantics of the operator"
    - path: "AppPackage/Sources/ReadingFeature/ReadingReducer.swift"
      provides: "The per-presentation set of error kinds already sent"
      contains: "surfacedErrorKinds"
  key_links:
    - from: "AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift"
      to: "AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift"
      via: ".signalsErrors(of: \\.toast?.errorInfo?.error, on: .deepLink)"
      pattern: "signalsErrors\\(of: \\\\.toast"
    - from: "AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift"
      to: "AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift"
      via: ".signalsErrors(of: \\.loadingState.failed, on: .frontPage) and the footer twin"
      pattern: "signalsErrors\\(of:"
    - from: "AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift"
      to: "AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift"
      via: "AnalyticsSignal.errorSurfaced(_:screen:) rendered as .error(id:category:parameters: [Error.screen: screen])"
      pattern: "errorScreen"
    - from: "AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift"
      to: "AppPackage/Sources/ReadingFeature/ReadingReducer.swift"
      via: "surfacedErrorKinds emptied at .onPresented and passed as oncePerKindIn"
      pattern: "surfacedErrorKinds"
---

<objective>
Make user-visible errors reach TelemetryDeck, as Phase 14 D-05 family 4 intended ("which `AppError` cases reach
users"). Two defects, one fix shape: (1) `errorSurfaced` is emitted only from an action nothing sends, because commit
`04b198b26` replaced the last sender with a direct toast assignment; (2) inline errors (`LoadingState.failed`) were
never counted. The fix observes state instead of actions, through one reducer operator in `AnalyticsClient`, so a
later direct assignment can never bypass the signal again. The signal gains a closed `ErrorScreen` parameter
(`Error.screen`), the reader de-duplicates per presentation and kind, and `.notFound` counts as its own kind.

Purpose: TelemetryDeck shows 0 error events in 30 days against 1,442 users; family 4 is dark.
Output: the operator, the vocabulary change, 24 call sites on 17 reducers, emission tests through real reducer paths,
and `261121-ifi-SUMMARY.md`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/quick/261121-ifi-make-error-signals-reach-telemetrydeck/261121-ifi-CONTEXT.md
@AGENTS.md
@.swiftlint.yml
@AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift
@AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift
@AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift
@AppPackage/Sources/AnalyticsClient/AppErrorKind.swift
@AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
@AppPackage/Sources/HapticsClient/Reducer+Haptics.swift

### Execution fidelity

Follow this plan exactly. If anything cannot be done exactly as written (ambiguity, conflicting requirements,
missing information, unexpected repository state, a lint rule or compiler error that forces a different shape, or any
deviation at all), stop immediately and ask the orchestrator. Do not choose, invent or implement a solution on your
own. CONTEXT.md's decisions are locked; this plan cites them by their CONTEXT headings (CONTEXT has no D-NN numbers):
"Approach", "Screen parameter (owner decision, 2026-11-21)", "Reader page-image failures (owner decision,
2026-11-21)", "Empty results, `.notFound` (owner decision, 2026-11-21)" and "Claude's Discretion".

### Design (decided at planning, Claude's discretion where CONTEXT leaves it open)

- **Operator, not per-site sends.** A new file `AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift`
  extends `Reducer` (precedent: `HapticsClient/Reducer+Haptics.swift`; `AnalyticsClient` already depends on
  ComposableArchitecture and every feature module already depends on `AnalyticsClient`, so `Package.swift` does not
  change). Public forms, all named `signalsErrors`, all built on TCA's `onChange(of:_:)` as the Approach decision
  suggests:
  1. `signalsErrors(of error: @escaping (State) -> AppError?, on screen: ErrorScreen)`: sends
     `errorSurfaced(AppErrorKind(new), screen:)` when the projected value changes and the new value is non-nil.
     Call sites pass `\.loadingState.failed` (the `@CasePathable @dynamicMemberLookup` member of `LoadingState`), or
     `\.toast?.errorInfo?.error` for the toast.
  2. `signalsErrors<Key: Hashable>(of loadingStates: @escaping (State) -> [Key: LoadingState], on screen: ErrorScreen)`
     (Task 2): when the dictionary changes, one signal per key whose new value is `.failed(e)` and differs from its
     old value (an absent old key counts as different).
  3. The same dictionary form with a third parameter `oncePerKindIn surfacedKinds: WritableKeyPath<State,
     Set<AppErrorKind>>` (Task 3): kinds already in the set are skipped, each remaining kind is sent once and
     inserted into the set in the same reduce.
  Each form returns one `.run(operation:)` effect that sends its signals in a deterministic order (newly failed
  kinds ordered by `AppErrorKind.rawValue`, duplicates kept in the non-de-duplicating form), resolves the client
  with a local `@Dependency(\.analyticsClient)` inside the inner reducer (precedent: the local `@Shared` in
  `PresentationFeature`'s `updateReadingProgress` arm), and follows the existing `analyticsClient.send(...)` emission
  form. Transition rule (Claude's discretion in CONTEXT): one transition into `.failed` is one signal; the same
  failed value re-assigned while still failed is not a transition; a retry that goes through `.loading` and fails
  again is a new transition.
- **Attach point.** In each reducer, append the call(s) to the end of the modifier chain that starts at the
  reducer's own main `Reduce` (after its existing `.haptics`/`.ifLet`/`.forEach`), or to the composed body property
  where the body lives elsewhere (`HomeReducer+Body.swift` `reducerBody`, `DetailReducer.swift` `detailBody`,
  `ReadingReducer+Body.swift` `mainReducer`). No observed property is a view binding (checked: no `$store.*LoadingState`
  and no binding to `toast` exists), so `BindingReducer` never needs observing. Keep every call on one line so the
  census gates below can count it.
- **Vocabulary.** `ErrorScreen` in `AnalyticsVocabulary.swift`: `public enum ErrorScreen: String, CaseIterable,
  Equatable, Sendable`, raw values implicit (the file's rule 1), cases in this order: `deepLink, home, frontPage,
  popular, watched, toplists, history, favorites, search, detail, detailSearch, archives, torrents, folderManager,
  downloadInspector, reading, ehSetting` (17). The two PresentationFeature toasts get their own `deepLink` case (both
  come from deep-link or clipboard handling). `AnalyticsSignal.errorSurfaced` becomes
  `case errorSurfaced(AppErrorKind, screen: ErrorScreen)`; rendering becomes `.error(id: kind.rawValue, category:
  kind.category, parameters: [ParameterKey.errorScreen: screen.rawValue])` with
  `static let errorScreen = "Error.screen"` in `ParameterKey`. `AnalyticsSignal+Level.swift` keeps `.errorSurfaced`
  at Basic and needs no edit (owner approved the parameter under the 20-12 sign-off rule; no level description
  changes). `TelemetrySDK.swift` already forwards `parameters` to `errorOccurred` and needs no edit.
- **Reader.** `ReadingReducer.State` gains `surfacedErrorKinds: Set<AppErrorKind>` (empty by default, same access
  level as its neighbours, beside `sessionStartDate`), emptied in `.onPresented` next to `sessionStartDate`, which is
  where a reading session starts; `imageURLLoadingStates` is observed with `oncePerKindIn: \.surfacedErrorKinds`.
- **Only rendered failures count.** The signal is "errorSurfaced": a failure state no view renders is not counted.
  This excludes five states that CONTEXT's domain summary listed as rendering `ErrorView` but which, checked against
  the views at planning time, do not (see the table).

### Every `.failed(` line at planning time (HEAD `e82010b40`, live `git grep -n '\.failed(' -- AppPackage/Sources App ShareExtension`: 78 lines; 69 code assignments, 57 covered)

Paths are under `AppPackage/Sources/`. A covered line is covered because the operator observes the property it
writes, so every present and future write to that property is counted.

| File | Lines | Observed property (key) | Screen / disposition | Task |
|---|---|---|---|---|
| AppFeature/DataFlow/PresentationFeature.swift | 176, 250 (`state.toast = .error(errorInfo)`) | `toast` via `\.toast?.errorInfo?.error` | `deepLink` | 1 |
| HomeFeature/FrontPage/FrontPageReducer.swift | 130 (`.notFound`), 139, 207 (`.notFound`), 215 | `loadingState` | `frontPage` | 1 |
| HomeFeature/FrontPage/FrontPageReducer.swift | 183 | `footerLoadingState` | `frontPage` | 1 |
| HomeFeature/Popular/PopularReducer.swift | 109 (`.notFound`), 115 | `loadingState` | `popular` | 2 |
| HomeFeature/Watched/WatchedReducer.swift | 176 (`.notFound`), 185, 268 (`.notFound`), 276 | `loadingState` | `watched` | 2 |
| HomeFeature/Watched/WatchedReducer.swift | 230 | `footerLoadingState` | `watched` | 2 |
| HomeFeature/Toplists/ToplistsReducer.swift | 177 (`.notFound`), 185 | `rawLoadingState` (dictionary keyed by `ToplistsType`) | `toplists` | 2 |
| HomeFeature/Toplists/ToplistsReducer.swift | 226 | `rawFooterLoadingState` (dictionary keyed by `ToplistsType`) | `toplists` | 2 |
| HomeFeature/History/HistoryReducer.swift | 131, 141, 171 (all `.notFound`, local), 174 | `loadingState` | `history` | 2 |
| HomeFeature/History/HistoryReducer.swift | 211 | `footerLoadingState` | `history` | 2 |
| HomeFeature/HomeReducer+Body.swift | 230 (`.notFound`), 236 | `popularLoadingState` (rendered by `HomeNavigationView`'s `ErrorView`) | `home` | 2 |
| HomeFeature/HomeReducer+Body.swift | 257, 263 | `frontPageLoadingState` | EXCLUDED: `HomeSectionsView` reads only `== .loading` | - |
| HomeFeature/HomeReducer+Body.swift | 283, 289 | `toplistsLoadingState` (dictionary keyed by `Int`) | EXCLUDED: `HomeSectionsView` reads only the loading half | - |
| FavoritesFeature/FavoritesReducer.swift | 276 (`.notFound`), 293, 378 (`.notFound`), 386 | `rawLoadingState` (dictionary keyed by favorites `Int` index) | `favorites` | 2 |
| FavoritesFeature/FavoritesReducer.swift | 340 | `rawFooterLoadingState` (dictionary keyed by `Int`) | `favorites` | 2 |
| SearchFeature/SearchReducer.swift | 183 (`.notFound`), 192, 275 (`.notFound`), 283 | `loadingState` | `search` | 2 |
| SearchFeature/SearchReducer.swift | 237 | `footerLoadingState` | `search` | 2 |
| DetailFeature/DetailReducer+Fetch.swift | 81 | `DetailReducer.State.loadingState` (attach in `DetailReducer.swift` `detailBody`) | `detail` | 3 |
| DetailFeature/DetailSearch/DetailSearchReducer.swift | 145 (`.notFound`), 153 | `loadingState` | `detailSearch` | 3 |
| DetailFeature/DetailSearch/DetailSearchReducer.swift | 202 | `footerLoadingState` | `detailSearch` | 3 |
| DetailFeature/Archives/ArchivesReducer.swift | 83 (`.notFound`), 95 | `loadingState` | `archives` | 3 |
| DetailFeature/Torrents/TorrentsReducer.swift | 123 (`.notFound`), 128 | `loadingState` | `torrents` | 3 |
| DetailFeature/FolderManager/FolderManagerReducer.swift | 132, 147, 152, 167, 183 | `loadingState` | `folderManager` | 3 |
| DownloadsFeature/DownloadInspectorReducer.swift | 124 | `loadingState` | `downloadInspector` | 3 |
| SettingFeature/EhSetting/EhSettingReducer.swift | 130 | `loadingState` | `ehSetting` | 3 |
| SettingFeature/EhSetting/EhSettingReducer.swift | 160, 189 | `submittingState` | EXCLUDED: `EhSettingView` reads only `== .loading` | - |
| ReadingFeature/ReadingReducer+Body.swift | 154 (`.webImageFailed`) | `imageURLLoadingStates` (dictionary keyed by page `Int`) | `reading`, once per kind per presentation | 3 |
| ReadingFeature/ReadingReducer+ImageFetch.swift | 166, 205, 262, 293 (`.notFound`); 178, 216, 269, 316, 362 | `imageURLLoadingStates` (dictionary keyed by page `Int`) | `reading`, once per kind per presentation | 3 |
| ReadingFeature/ReadingReducer+ImageFetch.swift | 41, 48 | `previewLoadingStates` | EXCLUDED: no view reads it | - |
| DetailFeature/Previews/PreviewsReducer.swift | 218, 224 | `loadingState` | EXCLUDED: `PreviewsView` never reads `loadingState` | - |
| SettingFeature/SettingReducer+Body.swift | 177 | `tagTranslatorLoadingState` | EXCLUDED: `GeneralSettingView` reads only the loading half | - |
| SettingFeature/Login/LoginReducer.swift | 250 (and its toast at 257) | `loginState` | EXCLUDED: login sends only `loginFailed` (CONTEXT, out of scope) | - |
| not `LoadingState` writes | LiveTextTranslation/LiveTextLanguageResolver.swift 40, 57 and LiveTextTranslator.swift 254 (another enum); DownloadsFeature/DownloadsView+Subviews.swift 28 (view pattern), 242 (another enum), 390 (preview fixture); DetailFeature/FolderManager/FolderManagerView.swift 73 (view pattern); DownloadsFeature/DownloadInspectorReducer.swift 18 and FavoritesFeature/FavoritesReducer.swift 62 (doc comments) | - | n/a | - |

`LoadingState` properties never written `.failed` (`DownloadsReducer.loadingState`,
`AppActivityLogsReducer.loadingState`, `GeneralSettingReducer.loadingState`) are not observed. The only
`ErrorInfo`-carrying toasts are PresentationFeature 176 and 250 and LoginReducer 257; every other toast is
caption-only and stays silent. `CommentsReducer` has its own unrelated toast action and is not touched.

Call-site census this plan ends with (24 calls; each screen case used at least once):
PresentationFeature 1, FrontPageReducer 2, PopularReducer 1, WatchedReducer 2, ToplistsReducer 2, HistoryReducer 2,
HomeReducer+Body 1, FavoritesReducer 2, SearchReducer 2, DetailReducer 1, DetailSearchReducer 2, ArchivesReducer 1,
TorrentsReducer 1, FolderManagerReducer 1, DownloadInspectorReducer 1, EhSettingReducer 1, ReadingReducer+Body 1;
PreviewsReducer, LoginReducer and SettingReducer+Body 0.

### Test sweep rule (all tasks)

`AnalyticsClientKey.testValue` is `.unimplemented`, so an existing test whose store drives a newly observed state
into `.failed` without overriding the client now fails with an unimplemented `AnalyticsClient.send` issue. For each
such failure: if the test is about analytics, assert the recorded signals; otherwise add `$0.analyticsClient = .noop`
to that store's dependencies (the established pattern, about 130 sites). An exhaustive store that asserts reader
state after a page failure also asserts the new `surfacedErrorKinds` value. Never change `testValue`, never wrap in
`withKnownIssue`, never add `.serialized`. A failure of any other shape: stop and ask. Merged effects run
concurrently, so where one action also sends another signal (for example `searchPerformed` on a failed search, or
`readingSessionEnded` on dismissal), assert the `errorSurfaced` signals as an exact filtered subsequence and the other
signal separately; never assert cross-signal order.

### Verification conventions (every command runs from the checkout root)

- Simulator: the project rule requires a project-prefixed simulator. Resolve it with
  `SIM=$(xcrun simctl list devices available | grep -F "EhPanda iPhone Air (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')`.
  At planning time one exists (iOS 27.2 runtime, Shutdown); if it is gone, create it with
  `xcrun simctl create "EhPanda iPhone Air" com.apple.CoreSimulator.SimDeviceType.iPhone-Air <newest installed iOS runtime id from xcrun simctl list runtimes>`,
  and delete it after the final run only if this run created it. Never touch other projects' simulators.
- One test invocation on the machine at a time: before each `xcodebuild test*`, wait until `pgrep -x xcodebuild`
  finds nothing. Never kill another session's process.
- One scratch derived-data folder for the whole plan: `.build/261121-ifi/dd` (gitignored).
- Baseline (once, before Task 1, at the untouched HEAD):
  `mkdir -p .build/261121-ifi && xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/261121-ifi/dd -skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile > .build/261121-ifi/build-baseline.log 2>&1; grep -q "TEST BUILD SUCCEEDED" .build/261121-ifi/build-baseline.log && grep -E ": warning: " .build/261121-ifi/build-baseline.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u > .build/261121-ifi/warnings-baseline.txt`
  then `SWIFTLINT=.build/261121-ifi/dd/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint; "$SWIFTLINT" lint --strict --quiet App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension > .build/261121-ifi/lint-baseline.txt; echo $?`
  and record both baselines in the SUMMARY. If HEAD is not lint-clean or the build fails, stop and ask.
- BUILD (per task N):
  `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/261121-ifi/dd -skipMacroValidation -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile > .build/261121-ifi/build-taskN.log 2>&1; grep -q "TEST BUILD SUCCEEDED" .build/261121-ifi/build-taskN.log && grep -E ": warning: " .build/261121-ifi/build-taskN.log | sed -E 's/:[0-9]+:[0-9]+: /: /' | sort -u | comm -13 .build/261121-ifi/warnings-baseline.txt - | tee .build/261121-ifi/new-warnings-taskN.txt; test ! -s .build/261121-ifi/new-warnings-taskN.txt`
  (compiles every FeatureTests target, VisualSnapshotTests included). A new warning from a file this plan did not
  touch, caused only by recompilation, is recorded with its file and is not a failure; any warning in a touched file is.
- LINT (per task N): the baseline lint command written to `.build/261121-ifi/lint-taskN.txt` must exit 0 with empty
  output. It lints Tests too, which the build plug-in does not.
- TEST (per task N, after BUILD passed in the same derived data). Every task runs the whole plan except
  VisualSnapshotTests (it needs the regression gate's pinned environment and is compiled by BUILD), because
  `AppReducer` composes every feature and a new emission in one module can surface in another module's tests:
  `xcodebuild test-without-building -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath .build/261121-ifi/dd -skip-testing:VisualSnapshotTests -collect-test-diagnostics never -resultBundlePath .build/261121-ifi/taskN.xcresult > .build/261121-ifi/test-taskN.log 2>&1; grep -q "TEST EXECUTE SUCCEEDED" .build/261121-ifi/test-taskN.log && xcrun xcresulttool get test-results summary --path .build/261121-ifi/taskN.xcresult | grep -E '"failedTests" : 0'`
  Read per-target counts from the xcresult summary, not from the log alone, before reporting. Existing
  `withKnownIssue` expected failures are not failures. Tests run in parallel.
- Commits: one signed commit per task, message of 50 characters or fewer, following the commit identity, signing
  and UTC+8 timestamp rules the project instructions point to (AGENTS.md and its local companion file). Verify
  signature `G` and both offsets `+08:00` after each commit. Suggested messages: Task 1 "Send error signals from
  state changes", Task 2 "Signal inline errors on list screens", Task 3 "Signal detail, settings and reader errors".
- Census helper used by the gates (paste as written):
  `cs() { grep -v '^[[:space:]]*//' "$1" | grep -c '\.signalsErrors(of:'; }`
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Tracer: errorSurfaced carries the screen, the toast and the Front Page list send it through state observation</name>
  <files>AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift, AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift, AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift, AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift, AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift, AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift, AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift, AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift, AppPackage/Tests/AnalyticsClientTests/AnalyticsVocabularyTests.swift, AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift, plus sweep-rule fixes</files>
  <precondition>`git grep -c '\.failed(' -- AppPackage/Sources App ShareExtension` exits 0 and its per-file counts sum to 78, and `git grep -c 'setToast' -- AppPackage/Sources/AppFeature AppPackage/Tests/AppFeatureTests` exits 0 and its counts sum to 5 (observed at HEAD e82010b40); otherwise stop and ask, because the site table was authorized from that observation.</precondition>
  <read_first>
    - .swiftlint.yml (custom rules: single_line_trailing_closure means a one-line `map`/`filter`/`sorted`/`forEach` closure is written in parentheses; labeled_tuple_elements; optional_try is banned; sorted_imports; force_unwrapping; line_length 120; file_length 1000)
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift, AnalyticsSignal+Rendering.swift (the two literal enums at the bottom), AnalyticsVocabulary.swift (header rules 1 and 2, `SearchSurface` as the model), AppErrorKind.swift, AnalyticsSignal+Level.swift, AnalyticsClient.swift (`send`, `testValue`)
    - AppPackage/Sources/HapticsClient/Reducer+Haptics.swift (the reducer-operator precedent)
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift (whole), AppPackage/Sources/AppComponents/AppAlertState.swift (`errorInfo`, `.error(_:)`, `.loading()`), AppPackage/Sources/AppModels/Support/AppError+Context.swift (`ErrorInfo`), AppPackage/Sources/AppModels/Support/Misc.swift (`LoadingState`)
    - AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift (body and the fetch arms)
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift, AnalyticsVocabularyTests.swift, ContentLeakProbe.swift (`Mirror.leafRenderings`), AppPackage/Tests/AppFeatureTests/AnalyticsEmissionTests.swift, PresentationFeatureTests.swift (deep-link test shape), AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift (FrontPage store and spy)
    - TCA's `onChange(of:_:)` in `.build/261121-ifi/dd/SourcePackages/checkouts/swift-composable-architecture/Sources/ComposableArchitecture/Reducer/Reducers/OnChange.swift` (present after the baseline build)
    - Skills to load: pfw-composable-architecture, swift-testing-pro, pfw-testing
  </read_first>
  <behavior>
    - Vocabulary: `ErrorScreen.allCases.map(\.rawValue)` equals exactly `["deepLink", "home", "frontPage", "popular", "watched", "toplists", "history", "favorites", "search", "detail", "detailSearch", "archives", "torrents", "folderManager", "downloadInspector", "reading", "ehSetting"]` (17), and the spellings are distinct (added to `everySpellingIsDistinctWithinItsOwnEnum`).
    - Rendering: the errorSurfaced fixture becomes `.errorSurfaced(.init(.copyrightClaim(sentinel)), screen: .reading)` rendering to `.error(id: "copyrightClaim", category: .appState, parameters: ["Error.screen": "reading"])`; the vocabulary stays twenty signals wide; the existing reserved-key and sentinel sweeps cover the new key with no change to them.
    - Operator (ErrorSignalReducerTests, a private fixture reducer whose state holds a `LoadingState` and whose actions set it): idle to `.failed(.networkingFailed)` records exactly `[.errorSurfaced(.networkingFailed, screen: .search)]`; re-assigning the same failed value records nothing more; failed, then `.loading`, then the same failure records two; `.failed(a)` then `.failed(b)` records a then b; an action that changes nothing observed records nothing; `.failed(.fileOperationFailed(<sentinel>))` records `.fileOperationFailed` and the sentinel survives in no `Mirror(reflecting:).leafRenderings` leaf of the recorded signals.
    - PresentationFeature (AppFeatureTests): `.handleDeepLink(https://example.com/not-a-gallery)` sets the toast to `.error(ErrorInfo(error: .unsupportedDeepLink, context: .unsupportedLink(url:)))` and records exactly `[.errorSurfaced(.unsupportedDeepLink, screen: .deepLink)]`; a second unsupported link while that toast is still shown records nothing more; after `.toast(.dismiss)` a third records a second signal; from an initial `toast = .loading()`, `.fetchGalleryDone(url:, result: .failure(.networkingFailed))` records exactly `[.errorSurfaced(.networkingFailed, screen: .deepLink)]`; `.presentErrorInfo` still records nothing (existing test kept).
    - FrontPage (HomeFeatureTests): `.fetchGalleriesDone(.failure(.networkingFailed))` records exactly `[.errorSurfaced(.networkingFailed, screen: .frontPage)]`; `.fetchMoreGalleriesDone(.failure(.parseFailed))` records exactly `[.errorSurfaced(.parseFailed, screen: .frontPage)]`.
  </behavior>
  <action>
    Vocabulary (Screen parameter, owner decision 2026-11-21): add `ErrorScreen` to `AnalyticsVocabulary.swift` exactly as in the Design section, with a doc comment saying it names the screen an error was shown on, one case per screen that renders an inline error plus `deepLink` for the deep-link toasts, and that it is a closed spelling so no free-form screen name can travel (D-06, D-09). Change the signal case to `case errorSurfaced(AppErrorKind, screen: ErrorScreen)` with a one-line doc comment (an error toast or a rendered inline error state turning on; kind and screen only). Render it as the Design section states, adding `errorScreen = "Error.screen"` to `ParameterKey`; this file stays the only place the literal is minted. Do not edit `AnalyticsSignal+Level.swift` or `TelemetrySDK.swift`.

    Operator (Approach): create `AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift` with form 1 from the Design section (`public`), built on `onChange(of:_:)`, resolving the client through a local `@Dependency(\.analyticsClient)` and returning one `.run(operation:)` effect. Doc-comment the why: the signal follows the state, not an action, because commit 04b198b26 moved the last toast to a direct assignment and silently disabled the action-based signal; the transition rule from the Design section; and that only failure states a view renders are observed (the signal is "surfaced"). Imports stay sorted; `AppModels` is already imported publicly by the module.

    PresentationFeature (Approach; "remove emptied actions"): delete the `setToast` case from `Action` and its reducer arm, since nothing sends it. Keep the two direct `state.toast = .error(errorInfo)` assignments as they are. Append `.signalsErrors(of: \.toast?.errorInfo?.error, on: .deepLink)` after the existing `.ifLet(\.$toast, action: \.toast)`. Reword the `presentErrorInfo` comment so it says the error was already counted when the toast turned into an error toast (no reference to the deleted action). The `analyticsClient` dependency stays (presentGalleryDetail uses it).
    <!-- planner-discipline-allow: setToast -->

    FrontPage: append `.signalsErrors(of: \.loadingState.failed, on: .frontPage)` and `.signalsErrors(of: \.footerLoadingState.failed, on: .frontPage)` to the end of the body's main chain (after the last `.ifLet`).

    Tests: create `AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift` for the operator behaviors (a private `@Reducer` fixture or a `Reduce` with `.signalsErrors` applied, a `LockIsolated` spy as in the other suites, `@MainActor` on members, not the type). Update the rendering fixture and add `errorScreenSpellsEveryCase` to the vocabulary tests. In `AppFeatureTests/AnalyticsEmissionTests.swift`, delete the two tests that send the deleted action and add the deep-link tests from the behavior list in their place (CONTEXT: replaced, not kept beside); build URLs with `try #require(URL(string:))`. Add the two FrontPage tests to `HomeFeatureTests/AnalyticsEmissionTests.swift` using the existing FrontPage store shape. Then apply the test sweep rule to whatever the TEST gate reports.
  </action>
  <verify>
    <automated>Baseline first (once), then BUILD, LINT and TEST with N=1; then the gates.
    `git grep -q 'setToast' -- AppPackage/Sources/AppFeature AppPackage/Tests/AppFeatureTests; echo $?` prints 1 (git grep: 0 = a match, 1 = none, 128 = error) [HEAD=0 EXPECT==1].
    `grep -c '"Error.screen"' AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift` prints 1 [HEAD=0 EXPECT==1]; `grep -v '^[[:space:]]*//' AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift | grep -c 'public enum ErrorScreen'` prints 1 [HEAD=0 EXPECT==1]; with the census helper, `cs AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` prints 1 [HEAD=0 EXPECT==1] and `cs AppPackage/Sources/HomeFeature/FrontPage/FrontPageReducer.swift` prints 2 [HEAD=0 EXPECT==2]; `test -f AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift` succeeds [HEAD=absent EXPECT==present]; `wc -l` of every touched file is at most 1000.</automated>
  </verify>
  <done>An unsupported deep link and a failed deep-link gallery fetch each send exactly one errorSurfaced(kind, screen: .deepLink) through the real reducer path; a failed Front Page fetch and a failed footer fetch each send one errorSurfaced(kind, screen: .frontPage); the dead toast action is gone; BUILD, LINT and TEST pass; the task is committed and verified signed with +08:00 dates.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: List screens: Popular, Watched, Toplists, History, Home, Favorites and Search, with the dictionary form</name>
  <files>AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift, AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift, AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift, AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift, AppPackage/Sources/HomeFeature/History/HistoryReducer.swift, AppPackage/Sources/HomeFeature/HomeReducer+Body.swift, AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift, AppPackage/Sources/SearchFeature/SearchReducer.swift, AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift, AppPackage/Tests/HomeFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/FavoritesFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/SearchFeatureTests/AnalyticsEmissionTests.swift, plus sweep-rule fixes</files>
  <read_first>
    - AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift (as Task 1 left it)
    - Each reducer listed in files: its `body` (or `reducerBody` in HomeReducer+Body.swift) and the fetch arms the table lists; ToplistsReducer.swift and FavoritesReducer.swift `State` (the dictionaries and their key types)
    - AppPackage/Sources/HomeFeature/HomeNavigationView.swift (the popular `ErrorView`) and HomeSectionsView.swift (why the front-page and toplists cards are excluded)
    - The three test targets' AnalyticsEmissionTests.swift (spies and store makers; Home's `makeHomeStore`) and SearchReducer.swift's `fetchGalleriesDone` (it also sends `searchPerformed`)
  </read_first>
  <behavior>
    - Operator dictionary form (ErrorSignalReducerTests): two keys failing in one action record two signals; re-assigning one key's same failed value records nothing; a key going failed, then loading, then failed again records again; a new key whose first value is `.failed` records; a key removed or set to `.idle` records nothing.
    - Popular: `.fetchGalleriesDone(.failure(.networkingFailed))` records exactly `[.errorSurfaced(.networkingFailed, screen: .popular)]`.
    - Watched: `.fetchGalleriesDone(.failure(.networkingFailed))` then `.fetchMoreGalleriesDone(.failure(.parseFailed))` record exactly those two with `screen: .watched`.
    - Toplists: `.fetchGalleriesDone` failing for one `ToplistsType` records one `screen: .toplists` signal, a second type failing records another, the footer `.fetchMoreGalleriesDone` failing records one more.
    - History (Empty results decision): with an empty in-memory history, `.fetchGalleries` records exactly `[.errorSurfaced(.notFound, screen: .history)]`; sending it again while still `.failed(.notFound)` records nothing more.
    - Home: `.fetchPopularGalleriesDone(.failure(.networkingFailed))` records exactly `[.errorSurfaced(.networkingFailed, screen: .home)]`; `.fetchFrontPageGalleriesDone(.failure(...))` and `.fetchToplistsGalleriesDone(<catIndex>, .failure(...))` record nothing (exclusions pinned).
    - Favorites: `.fetchGalleriesDone` failing for a favorites index records one `screen: .favorites` signal; the footer `.fetchMoreGalleriesDone` failing records one more.
    - Search: `.fetchGalleriesDone(.failure(.networkingFailed))` records `.errorSurfaced(.networkingFailed, screen: .search)` exactly once (plus the existing `searchPerformed`, asserted separately); the footer `.fetchMoreGalleriesDone` failure records one `screen: .search` signal.
  </behavior>
  <action>
    Operator: add form 2 from the Design section (`public`, generic over `Key: Hashable`, same effect and dependency shape as form 1, deterministic order per the Design section), with a doc comment saying a dictionary holds one list's states per key (a toplists type, a favorites category, a reader page) and each key's transition counts on its own. Add the dictionary behaviors to ErrorSignalReducerTests.

    Wire per the table (Claude's discretion: footer failures and retries count like any other transition): PopularReducer `\.loadingState.failed` on `.popular`; WatchedReducer `\.loadingState.failed` and `\.footerLoadingState.failed` on `.watched`; ToplistsReducer `\.rawLoadingState` and `\.rawFooterLoadingState` (dictionary form) on `.toplists`; HistoryReducer `\.loadingState.failed` and `\.footerLoadingState.failed` on `.history` (`.notFound` included, per the Empty results decision); HomeReducer+Body `reducerBody` `\.popularLoadingState.failed` on `.home`, with a one-line comment that the front-page and toplists card states are not observed because Home never shows their failure; FavoritesReducer `\.rawLoadingState` and `\.rawFooterLoadingState` (dictionary form) on `.favorites`; SearchReducer `\.loadingState.failed` and `\.footerLoadingState.failed` on `.search`. Each call goes at the end of that reducer's main chain as the Design section says; add `import AnalyticsClient` (sorted) where a file lacks it.

    Tests: add the listed cases to the Home, Favorites and Search AnalyticsEmissionTests files with their existing spies and store makers (in-memory storage where the store reads shared state). Then apply the test sweep rule.
  </action>
  <verify>
    <automated>Run BUILD, LINT and TEST with N=2; then with the census helper: `cs AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift` prints 1 [HEAD=0 EXPECT==1], `cs AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift` prints 2 [HEAD=0 EXPECT==2], `cs AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift` prints 2 [HEAD=0 EXPECT==2], `cs AppPackage/Sources/HomeFeature/History/HistoryReducer.swift` prints 2 [HEAD=0 EXPECT==2], `cs AppPackage/Sources/HomeFeature/HomeReducer+Body.swift` prints 1 [HEAD=0 EXPECT==1], `cs AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift` prints 2 [HEAD=0 EXPECT==2], `cs AppPackage/Sources/SearchFeature/SearchReducer.swift` prints 2 [HEAD=0 EXPECT==2]; the Home card exclusion is kept by the Home emission test, not by a grep; `wc -l` of every touched file is at most 1000.</automated>
  </verify>
  <done>Every rendered list, footer and Home popular failure sends one errorSurfaced(kind, screen:) per transition with the screen the table names, `.notFound` included; Home's unrendered card failures send nothing; BUILD, LINT and TEST pass; the task is committed and verified signed with +08:00 dates.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Detail sub-screens, folder manager, download inspector, E-Hentai settings and the reader with per-presentation de-duplication</name>
  <files>AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift, AppPackage/Sources/DetailFeature/DetailReducer.swift, AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift, AppPackage/Sources/DetailFeature/Archives/ArchivesReducer.swift, AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift, AppPackage/Sources/DetailFeature/FolderManager/FolderManagerReducer.swift, AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift, AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift, AppPackage/Sources/ReadingFeature/ReadingReducer.swift, AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift, AppPackage/Tests/AnalyticsClientTests/ErrorSignalReducerTests.swift, AppPackage/Tests/DetailFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/DownloadsFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift, AppPackage/Tests/ReadingFeatureTests/AnalyticsEmissionTests.swift, plus sweep-rule fixes</files>
  <read_first>
    - AppPackage/Sources/AnalyticsClient/Reducer+ErrorSignals.swift (as Task 2 left it)
    - AppPackage/Sources/DetailFeature/DetailReducer.swift (`detailBody`), DetailReducer+Fetch.swift (`fetchGalleryDetailDone`), DetailSearchReducer.swift, ArchivesReducer.swift (`fetchArchiveDone`), TorrentsReducer.swift (`fetchGalleryTorrentsDone`), FolderManagerReducer.swift (`createFolder` with an invalid name, the `invalidFolderNameError`), DownloadInspectorReducer.swift (`loadInspectionDone` and its request-ID guard), EhSettingReducer.swift (`fetchEhSettingDone`, `submitChangesDone`), PreviewsReducer.swift and PreviewsView.swift (why Previews is excluded)
    - AppPackage/Sources/ReadingFeature/ReadingReducer.swift (`State`: `sessionStartDate`, `imageURLLoadingStates`, `previewLoadingStates`), ReadingReducer+Body.swift (`mainReducer`, `.onPresented`, `.onWebImageFailed`, `.onPerformDismiss`), ReadingReducer+ImageFetch.swift (`fetchThumbnailURLsDone`, `fetchPreviewURLsDone`)
    - The four test targets' AnalyticsEmissionTests.swift (spies, store makers; the reader's `makeReadingStore`), AppPackage/Tests/DownloadsFeatureTests/FolderManagerReducerTests.swift (an invalid folder name and the store's dependencies), AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift (the login-only pins, which must keep passing unchanged)
  </read_first>
  <behavior>
    - Operator de-dup form (ErrorSignalReducerTests): two keys failing with the same kind record one signal and put the kind in the set; a third key failing with that kind records nothing; a different kind records once; after the test empties the set, the first kind records again; a re-assigned same failed value records nothing.
    - Detail: `.fetchGalleryDetailDone(.failure(.networkingFailed))` records exactly `[.errorSurfaced(.networkingFailed, screen: .detail)]`.
    - DetailSearch: `.fetchGalleriesDone(.failure(...))` and the footer `.fetchMoreGalleriesDone(.failure(...))` record one `screen: .detailSearch` signal each.
    - Archives: `.fetchArchiveDone(..., .failure(.networkingFailed))` records exactly one `screen: .archives` signal; Torrents: `.fetchGalleryTorrentsDone(.failure(.networkingFailed))` records exactly one `screen: .torrents` signal.
    - Previews (DetailFeatureTests): `PreviewsReducer` `.fetchPreviewURLsDone` failing records nothing (exclusion pinned).
    - FolderManager (DownloadsFeatureTests): `.createFolder` with an invalid folder name records exactly `[.errorSurfaced(.fileOperationFailed, screen: .folderManager)]`.
    - DownloadInspector (DownloadsFeatureTests): `.loadInspectionDone` with the state's current request ID and a failure records exactly one `screen: .downloadInspector` signal.
    - EhSetting (SettingFeatureTests): `.fetchEhSettingDone(.failure(.networkingFailed))` records exactly `[.errorSurfaced(.networkingFailed, screen: .ehSetting)]`; `.submitChangesDone(.failure(...))` and `.performActionDone(.failure(...))` record nothing (exclusion pinned).
    - Reader (Reader page-image failures decision): after `.onPresented`, `.onWebImageFailed` for two pages records exactly one `.errorSurfaced(.webImageFailed, screen: .reading)`; `.fetchThumbnailURLsDone(<page>, .failure(.networkingFailed))` records one `.errorSurfaced(.networkingFailed, screen: .reading)`; a further `.webImageFailed` page records nothing; `.fetchPreviewURLsDone(<page>, .failure(...))` records nothing (exclusion pinned); after `.onPerformDismiss` and a new `.onPresented`, `.onWebImageFailed` records `.webImageFailed` again. Assert the errorSurfaced subsequence exactly; `readingSessionEnded` from the dismissal is asserted separately.
  </behavior>
  <action>
    Operator: add form 3 from the Design section (`public`, the dictionary form plus `oncePerKindIn surfacedKinds: WritableKeyPath<State, Set<AppErrorKind>>`), inserting each sent kind into the set in the same reduce; doc-comment that it exists for the reader, where one network or host failure can fail every page of a gallery and the owner chose one signal per kind per reading session. Add the de-dup behaviors to ErrorSignalReducerTests.

    Wire per the table: DetailReducer `detailBody` `\.loadingState.failed` on `.detail`; DetailSearchReducer `\.loadingState.failed` and `\.footerLoadingState.failed` on `.detailSearch`; ArchivesReducer `\.loadingState.failed` on `.archives`; TorrentsReducer `\.loadingState.failed` on `.torrents`; FolderManagerReducer `\.loadingState.failed` on `.folderManager`; DownloadInspectorReducer `\.loadingState.failed` on `.downloadInspector`; EhSettingReducer `\.loadingState.failed` on `.ehSetting`, with a one-line comment that `submittingState` is not observed because the page never shows its failure. Add `import AnalyticsClient` (sorted) where a file lacks it. Do not touch PreviewsReducer, LoginReducer or SettingReducer+Body.

    Reader (Reader page-image failures decision): add `surfacedErrorKinds: Set<AppErrorKind>` to `ReadingReducer.State` as the Design section says, with a doc comment that it holds the kinds already sent in this presentation; empty it in `.onPresented` beside `state.sessionStartDate = date.now`, extending that arm's comment to say the error de-duplication starts there too; append `.signalsErrors(of: \.imageURLLoadingStates, on: .reading, oncePerKindIn: \.surfacedErrorKinds)` to `mainReducer`'s chain after `.ifLet(\.$toast, action: \.toast)`, with a one-line comment that `previewLoadingStates` is not observed because no view shows its failure.

    Tests: add the listed cases to the Detail, Downloads, Setting and Reading AnalyticsEmissionTests files with their existing spies and store makers. Apply the test sweep rule (ReadingReducer and FolderManager are also composed in FavoritesFeatureTests and DownloadsFeatureTests). Finally run the census and per-case gates below and the final whole-plan TEST run (it is this task's TEST gate).
  </action>
  <verify>
    <automated>Run BUILD, LINT and TEST with N=3 (this TEST run is the final whole-plan run); then the census: `cs() { grep -v '^[[:space:]]*//' "$1" | grep -c '\.signalsErrors(of:'; }; for s in AppFeature/DataFlow/PresentationFeature.swift:1 HomeFeature/FrontPage/FrontPageReducer.swift:2 HomeFeature/Popular/PopularReducer.swift:1 HomeFeature/Watched/WatchedReducer.swift:2 HomeFeature/Toplists/ToplistsReducer.swift:2 HomeFeature/History/HistoryReducer.swift:2 HomeFeature/HomeReducer+Body.swift:1 FavoritesFeature/FavoritesReducer.swift:2 SearchFeature/SearchReducer.swift:2 DetailFeature/DetailReducer.swift:1 DetailFeature/DetailSearch/DetailSearchReducer.swift:2 DetailFeature/Archives/ArchivesReducer.swift:1 DetailFeature/Torrents/TorrentsReducer.swift:1 DetailFeature/FolderManager/FolderManagerReducer.swift:1 DownloadsFeature/DownloadInspectorReducer.swift:1 SettingFeature/EhSetting/EhSettingReducer.swift:1 ReadingFeature/ReadingReducer+Body.swift:1 DetailFeature/Previews/PreviewsReducer.swift:0 SettingFeature/Login/LoginReducer.swift:0 SettingFeature/SettingReducer+Body.swift:0; do f=AppPackage/Sources/${s%%:*}; w=${s##*:}; g=$(cs "$f"); [ "$g" = "$w" ] || echo "MISMATCH $f got=$g want=$w"; done` prints no line (MISMATCH line count [HEAD=17 EXPECT==0]).
    The per-case gate (keep the braces in `${c}`: in zsh, the default shell here, a bare `$c[` is parsed as a subscript and the gate silently prints nothing): `git grep -h '\.signalsErrors(of:' -- AppPackage/Sources > .build/261121-ifi/calls.txt; st=$?; [ $st -le 1 ] || echo "GIT ERROR $st"; grep -v '^[[:space:]]*//' .build/261121-ifi/calls.txt > .build/261121-ifi/calls-code.txt; for c in deepLink home frontPage popular watched toplists history favorites search detail detailSearch archives torrents folderManager downloadInspector reading ehSetting; do grep -q "on: \.${c}[,)]" .build/261121-ifi/calls-code.txt || echo "UNUSED $c"; done` prints no line (output line count [HEAD=17 EXPECT==0]).
    The assignment invariant: `git grep -n '= \.failed(' -- AppPackage/Sources > .build/261121-ifi/failed-sites.txt; echo $?` prints 0, then `grep -Evc '^[^:]+:[0-9]+:[[:space:]]*//' .build/261121-ifi/failed-sites.txt` prints 69, because the plan adds and removes no failure assignment [HEAD=69 EXPECT==69 GUARD MUTATION: adding or deleting any code-level failure assignment under AppPackage/Sources].
    `grep -c 'surfacedErrorKinds' AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift` prints at least 2 [HEAD=0 EXPECT>=2]; `wc -l` of every touched file is at most 1000.</automated>
    <human-check>Owner, after the next build that carries a TelemetryDeck app ID reaches users: TelemetryDeck lists `TelemetryDeck.Error.*` events whose parameters include `Error.screen` with one of the 17 spellings. Builds from source carry no app ID and send nothing, so this cannot be checked locally.</human-check>
  </verify>
  <done>Every rendered inline error on the detail sub-screens, the folder manager, the download inspector, the E-Hentai settings page and the reader sends errorSurfaced(kind, screen:) per the table, the reader at most once per kind per presentation; excluded states send nothing; the census and per-case gates pass; the final whole-plan run passes with 0 failed; the task is committed and verified signed with +08:00 dates; the SUMMARY records baselines, per-task gate results, per-target test counts, the exclusions with their evidence, and the follow-up that the insights collector's signal catalogue (kept outside this repository) must be re-derived.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app → TelemetryDeck | Every errorSurfaced payload leaves the device; only closed spellings may cross (D-06, D-09). |
| AppError → AnalyticsSignal | `AppError` cases carry scraped or file-system strings; the mirror must drop them before rendering. |
| user consent level → SDK | errorSurfaced may leave only at Basic or Full, as the approved Basic description says. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-261121-ifi-01 | Information disclosure | `Error.screen` value and the error id | high | mitigate | `ErrorScreen` is a closed `String`-raw enum with implicit spellings pinned in AnalyticsVocabularyTests; the id comes from `AppErrorKind`, which binds no associated value; the operator test proves a `.fileOperationFailed(<sentinel>)` leaves no sentinel in any reflected leaf; the rendering fixture's sentinel sweep covers the new key. |
| T-261121-ifi-02 | Information disclosure | consent level | high | mitigate | `AnalyticsSignal+Level.swift` keeps `.errorSurfaced` at Basic unchanged; the level gate suite runs on the rendering fixtures, so the new shape is gated exactly as before; no level description changes (owner decision). |
| T-261121-ifi-03 | Tampering | SDK reserved parameter keys | medium | mitigate | The new key is dot-namespaced (`Error.screen`) and the existing reserved-key test sweeps every rendered key case-insensitively. |
| T-261121-ifi-04 | Denial of service | vendor signal volume and cost | medium | mitigate | Transition-only emission (no signal while a state stays failed) and the reader's per-presentation, per-kind de-duplication bound the volume; covered by ErrorSignalReducerTests and the reader emission test. |
| T-261121-ifi-05 | Information disclosure | login failure text | high | mitigate | LoginReducer is not observed (census gate prints 0 for it); SettingFeatureTests' existing login-only pins keep asserting that no errorSurfaced accompanies `loginFailed`. |
| T-261121-ifi-06 | Repudiation | silent loss of the signal | medium | mitigate | The signal follows state, not an action, so a direct assignment cannot bypass it; the census and per-case gates and the per-screen emission tests through real reducer paths pin every call site. |
| T-261121-ifi-SC | Tampering | npm/pip/cargo installs | low | accept | This plan installs no package and changes no `Package.swift` dependency; nothing to vet. |
</threat_model>

<verification>
- Baseline, then BUILD, LINT and TEST after every task (Verification conventions); the Task 3 TEST run is the final
  whole-plan run (FeatureTests minus VisualSnapshotTests, which BUILD compiles), 0 failed, per-target counts recorded.
- Census: 24 `.signalsErrors(of:` call sites across 17 files, 0 in PreviewsReducer, LoginReducer and
  SettingReducer+Body; every one of the 17 `ErrorScreen` cases used; code-level `= .failed(` assignments still 69.
- The dead toast action is gone from AppFeature sources and tests; `"Error.screen"` is minted once.
- Every touched file is at most 1000 lines; LINT exits 0 with empty output.
</verification>

<success_criteria>
- Real reducer paths, not hand-sent actions, prove: one deep-link toast signal per error toast, one signal per
  transition into a rendered `.failed` on each of the 17 screens, `.notFound` counted (History included), reader
  de-duplicated per kind per presentation, unrendered failure states silent, login unchanged.
- The vocabulary change is the one the owner approved: `errorSurfaced(AppErrorKind, screen: ErrorScreen)` at Basic,
  key `Error.screen`, closed spellings pinned.
- Three signed commits with +08:00 dates; SUMMARY written with baselines, gate results, exclusions and the
  out-of-repo follow-up (re-derive the insights collector's signal catalogue).
</success_criteria>

<output>
Create `.planning/quick/261121-ifi-make-error-signals-reach-telemetrydeck/261121-ifi-SUMMARY.md` when done
</output>
