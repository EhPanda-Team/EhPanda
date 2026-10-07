---
phase: 17-localized-screenshot-capture-harness
plan: "04"
subsystem: testing
tags: [swift, capture, fixtures, offline-replay, isolation, ui-tests, diagnostics]
requires:
  - phase: 17-03
    provides: The real marketing fixture schema (manifest.json, selection.json) and the provisional nonexplicit version marketing-fdcb0fc6d3c54a29
  - phase: 17-01
    provides: The public regression export schema the capture also validates
provides:
  - A Debug-only capture launch (EHPANDA_CAPTURE_CONFIGURATION, EHPANDA_CAPTURE_FIXTURES) that validates one fixture version completely and installs an isolated, offline scene before the app builds any state
  - An exact URL replay that answers only listed GET requests with verified bytes and records every other request
  - The selected Home scene through an injected Home client, in configured order
  - Capture diagnostics (screenID, selectionID, fixtureVersion, galleryIDs, page, readiness, pendingImages, unknownRequests) readable by UI tests from one invisible accessibility element
  - CaptureIsolationUITests, which proves the actual app shows the selection offline across a reset relaunch
affects: [17-05, 17-06, 17-07, 17-11, marketing]
actuals:
  tokens: 44254
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [validate-then-install before the first store, exact-URL offline replay with refusal accounting, read-time computed accessibility diagnostics, capture-owned caches reset per launch, dependency-bound cache housekeeping]
key-files:
  created:
    - AppPackage/Sources/HomeFeature/HomeClient.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
    - AppPackage/Tests/HomeFeatureTests/HomeClientTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureFixtureTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift
    - EhPandaUITests/CaptureIsolationUITests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/HomeFeature/HomeReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/AppFeature/RootView.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift
    - AppPackage/Sources/LibraryClient/LibraryClient.swift
    - AppPackage/Sources/AppTools/DataCache.swift
    - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
    - AppPackage/Tests/AppFeatureTests/TabBarSettingPresentationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
    - Scripts/visual/README.md
key-decisions:
  - Development uses the available nonexplicit fixture while the agent prepares provisional galleries and fixtures for both content sets (owner delegation, 2026-10-07).
  - Home gets an injected client for its popular, frontpage and Toplists fetches; capture overrides it with the selection, parsed from the saved detail pages (owner, 2026-10-07).
  - The live Home client arranges the carousel, so capture can return the configured order unchanged (owner, 2026-10-07).
  - The Toplists loading skeleton uses blank galleries without a cover, so Home makes no third-party request (owner, 2026-10-07).
  - A capture launch takes exactly its two keys, refuses any other EHPANDA_ key, and ends with a nonsecret message on any failed check.
  - Diagnostics travel through one invisible, capture-only accessibility element whose value is computed when a test reads it.
patterns-established:
  - Capture scene data comes only from the validated fixture bytes; a file replaced after validation never reaches a scene.
  - Everything a capture caches lives in its own directory, emptied at every launch, and cache housekeeping acts only on those copies.
requirements-completed: []
coverage:
  - id: D1
    description: A capture launch validates configuration and fixture completely (exact file set, lengths, SHA-256, canonical paths, links, media types, selection identity, aggregate digest and version) and refuses malformed or mismatched input before any state exists.
    requirement: CAP-17-01
    verification:
      - kind: unit
        ref: AppPackage/Tests/AppFeatureTests/CaptureFixtureTests.swift (7 tests, 20 tampering cases) and CaptureSceneTests.swift (15 tests, 9 malformed configurations); .capture/17-04-t2-verify-03/ on both devices
        status: pass
    human_judgment: false
  - id: D2
    description: The actual app shows exactly the selected Home galleries offline, with every image from the fixture and no refused request, and shows the same scene again after a relaunch that resets the capture's storage.
    requirement: CAP-17-04
    verification:
      - kind: ui
        ref: EhPandaUITests/CaptureIsolationUITests.swift on iPhone Air and iPad Pro 11-inch (M5); .capture/17-04-final-ui-01/
        status: pass
    human_judgment: false
  - id: D3
    description: Capture state cannot reach personal settings, caches or downloads, and unknown requests fail the capture.
    requirement: CAP-17-07
    verification:
      - kind: unit
        ref: CaptureSceneTests (isolated stores, storage reset, replay refusal, diagnostics); the first actual-app run failing closed on an unlisted request, .capture/17-04-isolation-ui-02/
        status: pass
    human_judgment: false
duration: about 3 hours 20 minutes from the first owner decision (2026-10-07, 01:27 to 04:48 UTC)
completed: 2026-10-07
status: complete
source_head: 2ea65ac65f
---

# Phase 17 Plan 04: Isolated offline capture scenes Summary

**The actual app can now launch on one validated fixture version, offline and isolated from the
device's own account, settings, caches and downloads, and show the selected Home scene. UI tests
read what the capture shows from one invisible diagnostics element. On both pinned devices the
real nonexplicit fixture shows exactly its 17 selected galleries with every image delivered from
the fixture and no request refused, again after a reset relaunch.**

## Performance

- The first owner decision was recorded at 2026-10-07T01:26:50Z; the last source commit landed at
  2026-10-07T04:47:55Z.
- Tasks: 2/2. Source commits: 5. Documentation commits: 5 (four owner decisions and this
  completion record).
- Realized source diff: about 44,500 tokens (chars/4), against an estimate of 48,000.

## Accomplishments

- **Launch keys.** `EHPANDA_CAPTURE_CONFIGURATION` holds `{purpose, scenarioID, fixtureID}` with
  exact keys and `[a-z][a-z0-9-]*` identifiers; `EHPANDA_CAPTURE_FIXTURES` names an absolute
  fixture version directory. Any other `EHPANDA_` key beside them, or only one of them, refuses the
  launch. `UITestAutomation.resolve` validates before `prepare` installs; any failure ends the
  launch with a message naming the check, never file contents. Everything is `#if DEBUG`.
- **Fixture validation.** `CaptureFixture.load` accepts the public export (17-01) and the real
  marketing schema (17-03) by `purpose`, and rejects the other purpose's schema, unknown or missing
  keys, non-canonical, repeated or escaping paths, unsupported media types, links (including the
  version directory itself, reached with a trailing slash), unlisted or missing files, length and
  SHA-256 mismatches, a selection that differs from the one named, and an aggregate digest or
  version that differs from the listed assets. The aggregate digests match the fixture tools'
  goldens. Scenes read only the verified bytes.
- **Scenes.** A marketing configuration's `fixtureID` names a selection set and `scenarioID` the
  screen; `home` is the only scene so far. Home's injected client returns the hero, Frontpage and
  each Toplists period in configured order, built by the app's parser from the saved detail pages,
  and the hero's `selectedIndex` must be Home's starting card. A public configuration validates
  its fixture and is refused until 17-11 adds public scenes.
- **Isolation.** Before the first store: in-memory app storage, inert cookies, analytics,
  clipboard, logs, downloads and DF, a fixed clock (2025-01-01T00:00:00Z) and incrementing IDs.
  The reader cache, Kingfisher's cache and SDWebImage's shared cache live in `EhPandaCapture` under
  the app's temporary directory, emptied at every launch, and their purge housekeeping acts only on
  those copies; Kingfisher's default cache keeps no housekeeping in a capture.
- **Replay.** `CaptureReplay` answers a `GET` of an exact listed URL with the verified bytes, the
  recorded media type and a Content-Length, and fails and records everything else. The shared
  loading system and Kingfisher's session pass through it; web images are configured synchronously
  at install, so no image request precedes the replay.
- **Diagnostics.** `CaptureDiagnostics` reports the shown screen, selection, version, gallery
  order, reader page, readiness (`loading`, `ready`, `failed`), images delivered but not yet cached,
  and refused requests. Home is ready once its lists hold galleries, nothing loads, the current
  card's cover is cached and nothing waits for the cache; a failed load or a refused request makes
  it `failed`. A capture-only, 1-point transparent accessibility element on the root view computes
  the JSON when a test reads it.
- **Actual-app test.** `CaptureIsolationUITests` copies the runner-named fixture
  (`TEST_RUNNER_EHPANDA_CAPTURE_SOURCE`) into its own temporary directory, launches the app, waits
  for Home to settle, compares the diagnostics with the selection, and repeats after a relaunch,
  attaching the raw diagnostics and a screenshot each time. Without the input it fails.
- **Production changes (owner-approved).** HomeFeature has an injected `HomeClient` whose live
  value wraps the existing requests and arranges the carousel; the Toplists loading skeleton no
  longer requests a GitHub image. `DataCache` purge observers are bound to the injected cache
  (unchanged behavior in production).

## Task Commits

1. `e40453c008`, `7dc6cb2a7f`, `f2417396be`: owner decisions (initial nonexplicit fixture, injected Home
   client, carousel arrangement in the live client), recorded in 17-04-PLAN.md.
2. `72f29f5f88`, T1: the injected Home client and its arrangement tests.
3. `2c63c45c27`, T1: configuration, fixture validation, replay, scene preparation and their tests.
4. `c961dacdf4`, `fbd71f24bc`: owner decision and fix for the Toplists skeleton's GitHub request.
5. `74159f1861`, T2: capture diagnostics, the actual-app isolation UI test and README.
6. `2ea65ac65f`, review fix: every capture cache and its housekeeping stay capture-owned.

## Verification

The plan's commands, run sequentially; device IDs were resolved by model name on the iOS 27
runtime before each run:

```sh
xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator'
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:AppFeatureTests/CaptureSceneTests -only-testing:AppFeatureTests/CaptureFixtureTests
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$TABLET_UDID" -only-testing:AppFeatureTests/CaptureSceneTests -only-testing:AppFeatureTests/CaptureFixtureTests
```

The actual-app test, which the FeatureTests plan does not include:

```sh
TEST_RUNNER_EHPANDA_CAPTURE_SOURCE="$PWD/.capture/marketing/current" xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination "platform=iOS Simulator,id=$UDID" -only-testing:EhPandaUITests/CaptureIsolationUITests
```

| Check | Evidence | Result |
|---|---|---|
| T1 build (plan command) | `.capture/17-04-t1-verify-02/` | Passes in a fresh DerivedData, then again on the final source; the capture keys are only in `EhPanda.debug.dylib` |
| Release build | `.capture/17-04-release-check-01/` | Passes; no Release binary holds a capture key, `capture_diagnostics`, a capture type or any `EHPANDA_` string |
| T2 contracts (plan command), phone and tablet | `.capture/17-04-t2-verify-03/` | 22 tests in 2 suites pass on each device |
| Actual-app capture, phone and tablet | `.capture/17-04-final-ui-01/` | Passes on iPhone Air and iPad Pro 11-inch (M5), one attempt each: `ready`, the 17 selected galleries in order, no pending image or refused request, at both launches |
| Actual-app capture without its input | `.capture/17-04-isolation-ui-01-missing-source/` | Fails, naming the missing runner variable |
| Actual-app capture fails closed | `.capture/17-04-isolation-ui-02/` | The first run reported the refused GitHub request as `failed` (R-5) |
| Full FeatureTests plan | `.capture/17-04-cache-isolation-gate-01/` | 22 of 22 Swift Testing runs pass; XCTest fails only the 10 VisualSnapshotTests cases below; no warning |
| Strict SwiftLint, the 21 Swift files 17-04 touched | `.capture/17-04-final-lint-01/` | No violations, no suppression |

The full plan ran before a final doc-comment wording change in `CaptureScenePreparation.swift`;
every other check ran on the final source.

Each actual-app run attaches the raw diagnostics JSON and a screenshot per launch, kept in the
result bundles. Every full-plan run of 17-04, from the first (`.capture/17-04-home-client-02/`),
fails the same 10 VisualSnapshotTests cases with the same messages. Each fails an environment
precondition of the visual gate runner that a plain FeatureTests run does not set: the `en_US`
locale, the phone idiom, a requested text size or orientation, or the selected-coordinate input.
17-04 changes none of them.

## Review

The inline review (17-04-REVIEW.md) reread every 17-04 source and test change after T2 was
committed. It found three isolation gaps, each fixed in `2ea65ac65f` and proved again by the
actual-app test on both devices:

- SDWebImage's shared cache stayed in the app's own caches, so capture readiness could count an
  image the user's cache held, and a later Setting scene would show the user's cache size.
- The reader cache's background purge was bound to the app's canonical cache, so a capture launch
  swept the user's reader cache when it went to the background.
- Kingfisher's default cache, the user's, kept its memory, background and termination cleanup in a
  capture launch.

It also records the unused replay accessor that T2 removed, and the Toplists skeleton's GitHub
request that the first actual-app run caught and the owner resolved.

## Decisions and Deviations

- **Owner decisions, 2026-10-07**, each recorded in 17-04-PLAN.md: use the initial nonexplicit fixture while the agent prepares the explicit fixture; give Home an injected client for its fetches;
  let the live Home client arrange the carousel; drop the cover from the Toplists loading skeleton.
- **Files beyond the plan's list.** The plan routes Home data "through existing injected request
  clients", but Home called its requests directly, so the owner approved `HomeClient`
  (HomeFeature, Package.swift). The diagnostics needed `CaptureDiagnostics.swift` and an anchor in
  `RootView.swift`; the review fixes touched `LibraryClient.swift` and `DataCache.swift`; the
  owner's skeleton decision touched `HomeView+Sections.swift`; three existing test files follow the
  `UITestAutomation` and `HomeClient` signatures.
- The plan names `scripts/visual`; the repository directory is `Scripts/visual`.
- A marketing configuration's `fixtureID` names one of `selection.json`'s scene sets
  (`nonexplicit`); a public one names an entry of the export's `fixtureIDs`. The fixture version
  comes from the manifest, so a configuration never pins one.
- Only the `home` scenario exists. Other screens belong to 17-05, Live Text and Downloads to
  17-06, and public scenes to 17-11; until then a public configuration validates its fixture and
  is refused.
- The download client is inert in a capture until 17-06 seeds capture-owned download folders: the
  live client would adopt the app's background session and could fetch outside the replay.
- A failed capture launch ends with `fatalError("EhPanda refused the capture launch: …")` naming
  the failed check. A UI test sees the app terminate; the message is in the crash report.
- The isolation UI test is runner-driven: `TEST_RUNNER_EHPANDA_CAPTURE_SOURCE` names the fixture
  on the host, and the test copies it into the runner's temporary directory before each launch,
  so the app never reads `.capture/` directly.
- The UITests plan retries a failed test up to three times, and xcodebuild cannot turn that off
  from the command line: it rejects `-test-iterations 1`, alone or with `-retry-tests-on-failure`
  (`.capture/17-04-final-ui-01/usage-error/`, `usage-error-2/`). Each recorded actual-app run is
  checked instead to hold exactly one attempt: its result bundle has no repetition node.
- No acceptance criterion or threshold changed.

## Unresolved Gates

1. **Agent-assisted gallery preparation for both sets.** The agent prepares the explicit fixture alongside the nonexplicit fixture, validates each selection and captures only its declared content.
2. **Deterministic dark Home card colors, before 17-05's cold-rerun gate.** On the iPhone (dark
   appearance) the launch and the relaunch settle the focused card's gradient on different colors,
   while the iPad (light) screenshots are byte-identical. A likely cause is `ImageColors` ordering
   equally counted colors by hash order. A fix changes production output, so it needs an owner
   decision.
3. **Readiness for the dark card's color analysis and cross-fade.** Home readiness covers lists and
   images only; 17-05 owns the per-frame settle rule.
4. **Final selection** with owner authority remains the Phase 17 closure checkpoint (17-21).

## Issues Encountered

- The first actual-app run caught Home's Toplists skeleton requesting a GitHub image (R-5).
- An early UI run failed to find its fixture because `TEST_RUNNER_EHPANDA_CAPTURE_SOURCE` was passed
  as an xcodebuild argument; the runner only receives it from xcodebuild's environment.
- The pinned iPhone Air was found at the AX5 text size during T2, although the owner state is
  Large. It was restored to Large and confirmed after a reboot, with dark appearance and Reduce
  Motion on, then shut down. The iPhone pass recorded at AX5 (`.capture/17-04-isolation-ui-04/`)
  was rerun at Large.

## User Setup Required

None for the nonexplicit set. The agent prepares both content sets; final owner confirmation remains a closure checkpoint.

## Next Plan Readiness

17-05 can extend the capture launch to its eight screen IDs. `CaptureScenePreparation.install`
already validates the fixture and isolates the process; a new scene adds its data to `CaptureScene`
and its readiness to `CaptureDiagnostics`, which UI tests read through the `capture_diagnostics`
element (Scripts/visual/README.md). The actual-app pattern is `CaptureIsolationUITests`. Phase
progress is 5/24 plans; CAP-17-01, CAP-17-04 and CAP-17-07 stay open until both sets are acquired
and every declaring plan finishes.
