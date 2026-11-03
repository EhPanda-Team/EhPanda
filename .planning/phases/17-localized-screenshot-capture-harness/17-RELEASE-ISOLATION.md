# 17-RELEASE-ISOLATION: Release ships and activates no capture facility

Plan 17-14 Task 2 (CAP-17-07), run once at Phase 17 close on 2026-11-03.

## Source and toolchain

- App source: `6bccf8468` (`feature/gsd-phase-17`). It was built from a clean detached worktree
  `.airbuild/worktree/ehpanda-1714-release` at that commit. The scanner commits that follow
  (`b840641ff`, `af70958e0`) touch only `Scripts/visual/`.
- Xcode 27.2 (27B52), iOS Simulator 27.2 (24B8117), SwiftLint 0.65.1 (the SwiftLintPlugins binary
  the build resolved).
- Simulators: `EhPanda iPhone Air` and `EhPanda iPad Pro 11-inch (M5)`, iOS 27.2. Their UDIDs were
  resolved on this host and are not recorded here.

## Builds

The project's `runbuild` ran a build script local to that worktree, in
`.airbuild/airbuild.yaml`, which is git-ignored. `airbuild-xcode` accepts only archive and test,
so the script calls `xcodebuild` directly:

```sh
xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$A/release/DerivedData" \
  CODE_SIGN_IDENTITY=- CLANG_COVERAGE_MAPPING=NO LD_GENERATE_MAP_FILE=YES | tee "$A/release/build.log"
xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$A/debug/DerivedData" \
  CODE_SIGN_IDENTITY=- | tee "$A/debug/build.log"
```

The same script then runs `airbuild-xcode archive` (see below). The `runbuild` exit is 0. Each step
ran under `set -o pipefail`, and each log ends in `** BUILD SUCCEEDED **` or
`** ARCHIVE SUCCEEDED **`.

**Coverage instrumentation (found and corrected).** The first Release build had no override. It
compiled every Swift and C file with `-profile-coverage-mapping -profile-generate` /
`-fprofile-instr-generate` (506 compile lines), so its link map carried `___profc_` counters that
name every function. The reason: `xcodebuild build -showBuildSettings -configuration Release`
reports `CLANG_COVERAGE_MAPPING = YES`, inherited from the scheme's test plans. `xcodebuild archive
-showBuildSettings -destination generic/platform=iOS`, the shipped CI path in
`.github/workflows/deploy.yml`, reports `CONFIGURATION = Release` with no `CLANG_COVERAGE_MAPPING`.
So the shipped archive isn't instrumented, but a plain build is. `-enableCodeCoverage NO` is
refused outside testing (exit 64). The final build sets `CLANG_COVERAGE_MAPPING=NO` and has 0
instrumented compile lines. The scanner now fails any instrumented compile (`instrumented`), and
`Scripts/visual/README.md` gives the corrected command.

AirBuild's own `airbuild-xcode archive` builds a **Debug simulator** archive
(`Debug-iphonesimulator` paths, 8656 lines). It isn't the shipped artifact, so it isn't used as
Release evidence.

## Scan

```sh
python3 -B Scripts/visual/verify-release.py \
  --app "$A/release/DerivedData/Build/Products/Release-iphonesimulator/EhPanda.app" \
  --build-log "$A/release/build.log" \
  --link-map "$I/EhPanda.build/EhPanda-LinkMap-normal-arm64.txt" \
  --link-map "$I/EhPanda.build/EhPanda-LinkMap-normal-x86_64.txt" \
  --link-map "$I/ShareExtension.build/ShareExtension-LinkMap-normal-arm64.txt" \
  --link-map "$I/ShareExtension.build/ShareExtension-LinkMap-normal-x86_64.txt" \
  --device "$PHONE_UDID" \
  --debug-control "$A/debug/DerivedData/Build/Products/Debug-iphonesimulator/EhPanda.app" \
  --output "$OUT"
```

(`$A` = `.airbuild/artifacts` in the worktree; `$I` = its
`release/DerivedData/Build/Intermediates.noindex/EhPanda.build/Release-iphonesimulator`.)

**Exit 0, `PASS: 0 finding(s)`.**

| Evidence | Result |
|---|---|
| Payload | 377 files in `EhPanda.app` (the share extension included). No test bundle, fixture, HTML page, snapshot reference, `.debug.dylib` or `__preview.dylib`. No `EHPANDA_`, `APPSHOT_`, `Appshot`, `capture_diagnostics`, `EhPandaCapture`, capture or UI-test-stub type name, `SnapshotTesting` or `XCUI` string in any file. |
| Dependency graph | 150 targets in the log's `Target dependency graph`. None is a test, snapshot or UI-test target. |
| Package resolution | 31 packages resolved for the whole project. `swift-snapshot-testing` is resolution-only: it is in neither the graph nor a link map. |
| Compiles | 1613 compiler invocations, none defining `DEBUG` and none instrumented. |
| Link maps | App: 187 objects and 290 544 live symbols (arm64), 187 and 279 067 (x86_64). Share extension: 24/338 and 24/307. No XCTest, Testing, XCUIAutomation or SnapshotTesting object or library. No live capture symbol. |
| Inert shell (accepted, not a finding) | `UITestAutomation` stays in Release with 11 live symbols per app slice. All of them are its type metadata or its two DEBUG-gated members: `shouldDetectClipboardURL` (returns `false` outside DEBUG; read by `AppReducer`) and `prepareIfNeeded` (empty outside DEBUG). No `prepare(environment:)`, `configureVisualTestHost`, `fixedDate` or other member is linked. Its name in the `EhPanda` binary is recorded under `accepted`. |
| Launched activation | The Release app was installed on the phone simulator and launched with `EHPANDA_CAPTURE_CONFIGURATION`, `EHPANDA_CAPTURE_FIXTURES`, `APPSHOT_SCENE`, `EHPANDA_UITEST_STUB_NETWORK`, `EHPANDA_VISUAL_TEST_HOST` and `EHPANDA_AUTOMATION_TAB` set (`PROBE_ENVIRONMENT`). It was still running after 8 s. The Debug control, launched the same way, had ended, because `UITestAutomation.prepare` refuses that set. So the probe would activate capture code if Release read it. The simulator was shut down afterwards and the app uninstalled. |

`XCTest` text is not evidence. Release binaries contain swift-issue-reporting and swift-case-paths
strings such as `XCTestConfigurationFilePath`, `XCTestObservationCenter` and "A failure was
recorded without linking the XCTest framework": their run-time test-host detection, compiled into
every configuration. Linkage is what would ship XCTest, and no link map lists it.

**Negative check on real artifacts.** I scanned the Debug build's app and log with the same
scanner. It exits 1 with 991 findings:

- 483 `debug-define` and 492 `instrumented` compile lines;
- 11 capture strings (`EHPANDA_`, `APPSHOT_`, `CaptureDiagnostics`, `CaptureFixture`,
  `CaptureLiveText`, `CaptureRendering`, `CaptureScene`, `CaptureTagTranslation`,
  `EhPandaCapture`, `UITestStub`, `capture_diagnostics`);
- 4 payload files (both `.debug.dylib`, both `__preview.dylib`);
- a Debug product path.

## Scanner tests

`python3 -B -m unittest discover -s Scripts/visual -p test_release.py`: **19 tests, OK.**

- **RED:** with `test_release.py` alone, all 19 error with `FileNotFoundError` (no scanner). Against
  the first scanner draft, the 9 new behavior tests failed, before the indented graph, `XCTest`,
  coverage and shell changes.
- **Seeded bad payload:** `test_seeded_bad_payload_fails_on_every_leak` seeds capture strings, a
  `.debug.dylib`, an HTML fixture, a `__Snapshots__` directory and a SnapshotTesting string in the
  extension. `main` exits 1 and reports each leak.

## Lint

```sh
"$SWIFTLINT" lint --strict --no-cache --config .swiftlint.yml \
  AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests
```

Exit 0: `Found 0 violations, 0 serious in 753 files.` No suppression was added.

## Behavior tests

Runs went through the project's `runtest` recipe, one at a time, phone before tablet. Retries
weren't overridden; any Repetition node counts as a failure.

| Plan, device (iOS 27.2) | Exit | Cases | Passed | Failed | Skipped | Expected failures | Repetition nodes |
|---|---|---|---|---|---|---|---|
| FeatureTests, EhPanda iPhone Air | 65 | 1510 | 1499 | 2 | 0 | 9 | 0 |
| FeatureTests, EhPanda iPad Pro 11-inch (M5) | 65 | 1510 | 1494 | 7 | 0 | 9 | 0 |
| UITests, EhPanda iPhone Air | 65 | 91 | 48 | 23 | 20 | 0 | 71 |
| UITests, EhPanda iPad Pro 11-inch (M5) | 65 | 91 | 48 | 26 | 17 | 0 | 78 |

Failures by cause. None of them is in the Release isolation tooling.

- **UI-test stub has no `/api.php` route (phone 15, tablet 17).** `300a29ac4` (2026-11-02) adds a
  `POST /api.php` metadata request to every gallery list (`galleriesWithTitles`).
  `UITestStubURLProtocol.fixtureName` answers it with 404, so Home and Favorites show "Couldn't Read
  Page". Affected suites: AccessibilityAudit (6, plus `testPadSettingAndDetailModalsAudit` on the
  tablet), GalleryCard 3, GalleryLayout 3, LibraryPresentation 3 and, on the tablet,
  `DeepLinkPadUITests`. Reproduced by launching the Debug app with only the stub environment.
- **Detail overflow control not found (5 on each device).** ShareSheet 1, DetailNavigationTitle 4.
  Not root-caused.
- **Env-gated capture tests (3 on each device).** `MarketingCaptureUITests` (2) and
  `CaptureIsolationUITests` (1) need `TEST_RUNNER_EHPANDA_CAPTURE_*`. The UITests plan skips only
  `AppshotCaptureUITests`.
- **Tablet reader rotation (1).** `ReaderPageSyncUITests.testTurningTheDeviceKeepsTheResumedPageAtTheTop`:
  after turning to landscape, the indicator names a page that the screen doesn't show. Not
  root-caused.
- **FeatureTests on both devices (2).**
  - `CaptureSceneTests.sceneSettingsAreTheDefaultsWithTheBypassOn` gets `displayJapaneseTitle: true`.
    `300a29ac4` also changed `CaptureScenePreparation`.
  - `VisualTracerTests.testHomeFullContentTracer` reports `clippedItem("Visual Home Gallery 1")`.
- **FeatureTests, tablet only (5).** `DownloadContinuedSession` Interleave 1, Expiration 3, Ledger 1:
  timeouts or ordering races.

## Verdict

Release payload, dependency and activation evidence is clean, the scanner rejects a seeded bad
payload, and lint is clean. **The behavior gate fails:** FeatureTests and UITests fail on both
devices for the reasons above. They are regressions or test-plan gaps in app and test code, outside
this plan's tooling scope. Per the plan's success criteria, T2's acceptance stays open and the gate
pauses for orchestrator direction.
