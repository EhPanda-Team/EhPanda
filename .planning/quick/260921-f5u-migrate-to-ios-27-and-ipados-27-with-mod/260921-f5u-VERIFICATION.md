# iOS 27 migration verification

Status: migration implementation and verification complete, with the pre-existing W-38 failure explicitly carried. The final reader invocation finalized normally with exit 65. The full iPad UI suite remains red; it is not reported as passing.

## Environment

- Xcode 27.0, build 27A266a; Swift 6.4; iOS 27.0 SDK.
- iPhone Air, iOS 27.0: `35988D34-B4E9-44C6-82B5-CDA2CF391339`.
- iPad Pro 11-inch (M5, 16 GB), iPadOS 27.0: `E70AEE51-3CC5-4420-9E1C-DE8190DB6FC2`, created for this task with display name `EhPanda iPad Air 27`. The device type, rather than the arbitrary display name, identifies the hardware.
- All logs, screenshots and result bundles are local under `/tmp/ehpanda-ios27`.
- Normal macro and package-plugin validation is enabled. No validation bypass flag was used in these local invocations.

## Baseline observations

The pre-edit FeatureTests runs emitted failures in Favorites login observation and Settings translation import. The iPad reproduced the Settings failure. The baseline Home accessibility test emitted one passing test. The test processes did not finalize promptly: later sampling identified Xcode waiting for `simctl diagnose`, which uses a 600-second timeout. Starting a further build before those processes exited caused a build database lock. Only the task-owned overlapping processes and their orphan diagnostic collectors were terminated. Those interrupted invocations are not recorded as passing Xcode runs.

Evidence: `baseline-feature-iphone-2.log`, `baseline-feature-ipad-2.log`, `baseline-home-iphone-2.log`, and `task1-build-iphone.log`.

Known baseline failures:

1. `FavoritesFeatureTests/LoginReturnObservationTests.cookieLoginTriggersReloadWithoutAViewCallback`: a second login/fetch pair remained unasserted. The test's refresh helper deletes credentials before replacing them, so it does not guarantee the continuously signed-in scenario described by the assertion.
2. `SettingFeatureTests/SettingReducerNavigationTests.generalFilePickedImportsAndStoresTagTranslator`: shared translation state changed during the originating send, before the expected response assertion, with an immediately returning async stub.

The baseline also emitted existing known issues for cancelled effects in two Settings tests; no new suppression is authorized by this migration.

## Task 1 platform slice

```sh
xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda \
  -destination 'platform=iOS Simulator,id=35988D34-B4E9-44C6-82B5-CDA2CF391339'
```

Result: **BUILD SUCCEEDED**, exit 0, 10.232 seconds. Log: `task1-build-serial.log`.

```sh
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination 'platform=iOS Simulator,id=35988D34-B4E9-44C6-82B5-CDA2CF391339' \
  -only-testing:EhPandaUITests/AccessibilityAuditUITests/testHomeRootAudit \
  -resultBundlePath /tmp/ehpanda-ios27/task1-home-serial.xcresult
```

Result: **TEST SUCCEEDED**, exit 0, one passing test, zero failures. Test duration 7.586 seconds; full invocation 621.727 seconds. Log: `task1-home-serial.log`. A process sample (`xcode-finalization-sample.txt`) shows `XCTHRunDestinationAllocator.collectSimulatorDiagnostics` waiting for `XCTHProcessInvocation.simCtlDiagnose` after the test finished. Diagnostic collection hit its native 600-second timeout, after which Xcode finalized the passing result bundle. This is a toolchain diagnostic-collection failure, not a test assertion failure; diagnostic collection was not disabled.

The UI-test compile exposed main-actor snapshot access warnings in `SurfaceInventory.visibleBounds(in:)`; the approved fix marks that snapshot-reading method `@MainActor`.

## Task 2 build and baseline test repairs

The complete native API batch built successfully in `task2-build-serial.log`: exit 0, 20.396 seconds. Normal build-plugin lint remained enabled.

The first focused repair run (`focused-baseline-repairs.xcresult` / `.log`) failed at compile time because `AsyncSequence.first` is a predicate-taking method, not an element property. The mock now awaits a local iterator's `next()`; no assertion was removed. The next invocation (`focused-baseline-repairs-2.xcresult` / `.log`) finalized successfully in 30.270 seconds: Home and Favorites each ran their login-observation case and passed. Its method-level Settings filter selected zero tests, which is not counted as verification of that case.

The complete `SettingFeatureTests/SettingReducerNavigationTests` suite was then run in `focused-settings-suite.xcresult` / `.log`: **12 tests passed**, including `generalFilePickedImportsAndStoresTagTranslator`, exit 0, 13.370 seconds. The login tests finish their controlled notification streams and await their observation effects; the import test explicitly releases the asynchronous result after the initiating send has been asserted. Production reducer behavior is unchanged.

The YAML workflows parse with Ruby's YAML parser, and their installed-Xcode/SDK guard succeeds against Xcode 27.0 and SDK 27.0. This is local syntax and guard verification, not hosted CI execution.

## Complete feature plan

`final-feature-both.xcresult` / `.log`: **TEST SUCCEEDED**, exit 0, 88.151 seconds. A single native Xcode invocation ran `-testPlan FeatureTests` with both device destinations. The finalized result reports 1,379 passing cases, 11 expected failures, zero unexpected failures and zero skips on each device. At the aggregate level this is 1,055 unique tests (1,044 passed and 11 expected failures), with 2,780 runs including dynamic parameters across both devices. No runtime warnings were reported by the result summary. Expected failures are pre-existing test annotations; this migration added no expected failure or skip.

## Visual evidence collected

The installed app was launched with its existing fixture network configuration and the test runner's bundled fixture directory. Home was inspected before and after scrolling on iPhone Air. The large title collapsed naturally, and the scrolled image shows progressive blur beneath the title and reload control. Both remain legible.

- `task1-home-initial.png`
- `task1-home-scrolled.png`

These screenshots remain local and are not repository artifacts. The earlier `task1-home.png` captured SpringBoard after XCTest teardown and is not app verification evidence.

## Gates recorded before the initial UI runs (historical)

- Native Tab/navigation modernization is applied; the 46-row source inventory is closed.
- Run final FeatureTests and complete UI suites on both device classes after the final source change.
- Resolve the initial migration UI test's iPad search assumption and investigate slow iPhone landscape cold entry.
- Confirm a finalized result bundle and successful Xcode exit for each final passing test run.
- Hosted CI execution remains unverified; local workflow syntax and toolchain guard checks have passed.

## Initial migration UI regression run

`native-ui-both-initial.xcresult` / `.log` finalized with exit 65. Both devices passed Detail overflow disabled/enabled actions and system Share presentation. The reader landscape case passed first on iPad (35.951 seconds); iPhone first timed out entering Detail (118.582 seconds), then passed on the configured retry (100.029 seconds). The slow cold entry remains an investigation item; a successful retry does not erase it. `phone-landscape-stall.sample` captures repeated SwiftUI layout/SizeFitting work on the app's main thread.

Both Search cases passed on iPhone. On iPad each failed all three configured attempts because the new test expected a Close control absent from native iPad search. The corrected test submits a real query after clear and returns from results using native navigation. The result's internal QoS warnings originate in XCTest infrastructure. Diagnostic collection again reached its native timeout; it was not disabled.

## Additional native visual samples

Phone Search was observed at AX1, AX3 and AX5, including focus, text entry and native clear. The native overflow opened Quick Search and its New Word editor. Detail overflow preserved disabled Archives and enabled Torrents/Share; Share opened the system activity collection and dismissed back to Detail. Evidence includes `search-ax1.png`, `search-ax3.png`, `search-ax5-focused.png` and `detail-native-share.png`.

On iPad, Frontpage's native automatic title and search drawer were observed at AX1, AX3 and AX5, including focused AX5 with the keyboard. The iPad drawer does not expose the iPhone's Close button. Evidence: `ipad-frontpage-ax1.png`, `ipad-frontpage-ax3.png`, `ipad-frontpage-ax5.png`, `ipad-frontpage-ax5-focused.png`. Settings on iPhone was inspected at standard and AX5 sizes; `phone-settings-ax5-scrolled.png` shows the native progressive top blur with legible navigation controls. `phone-general-ax5-initial.png` did not navigate to General and is not General-page evidence.

These are representative native scroll-host and accessibility samples, not proof of every state, orientation, authenticated page or system-owned internal scroll view. Exhaustive page modifier coverage is tracked separately in the source inventory.

The final native Tab implementation was inspected on Settings and General on iPhone. `final-phone-general.png` and `final-phone-general-scrolled.png` show the Form before/after scrolling; the latter visibly blurs content behind the legible General title. `final-phone-general-ax5.png` records settled AX5 entry. sim-use's accessibility outline was empty during these captures, so row selection used coordinates grounded in the immediately observed screenshot; this is a tooling limitation, not evidence of a passing accessibility audit. The XCTest audit remains a separate gate.

`final-phone-general-ax5-scrolled.png` confirms the same soft top blur at AX5. On iPad, the corrected Search interaction was also exercised manually at standard size: input `artist:fixture`, Clear, tap the returned field, input `fixture`, submit with the native keyboard Search action, and return with the native back control. The results page visibly shows `fixture`. Evidence: `ipad-search-refocus-filled.png`, `ipad-search-refocus-cleared.png`, `ipad-search-refocused.png`, `ipad-search-results.png`, `ipad-search-returned.png`. Automated AX5 and cross-device verification of that corrected flow remains pending.

## Revised native UI run

After native Tab and remaining navigation API modernization, all four iPhone cases passed on the first attempt: Detail 25.867 seconds, reader landscape 34.404, Search AX5 43.387 and standard Search 43.353. Both simulators report system content size `large`; the AX5 test explicitly supplies its launch argument. The iPad Detail case passed in 27.116 seconds and reader in 100.820 seconds. The iPad reader's last behavior assertion succeeded at 35.15 seconds; portrait restoration then waited from 35.31 to 95.32 seconds for the app's event-loop idle notification. The app log records a native scroll-geometry multiple-updates-per-frame warning during that window. This is retained for measured diagnosis, not claimed fixed by the faster phone result.

Both iPad Search cases failed all three configured attempts at text entry after Clear: native Clear had removed keyboard focus. The next test revision explicitly taps the field again before submitting. All clear-state and navigation assertions remain intact. Evidence: `native-ui-both-revised.xcresult` / `.log`, finalized with exit 65; `native-ui-both-revised-summary.json`.

Strict no-cache SwiftLint checked all 66 changed Swift files after the native navigation patch and reported zero violations, exit 0. Evidence: `final-changed-swiftlint.log`.

## Existing Share extension support boundary

The pre-existing, owner-approved `LSApplicationWorkspace` handoff remains private API. The installed iOS 27 SDK and current [Apple extension-opening contract](https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)) establish no public replacement for the Share extension point. This migration preserves the existing behavior and exercises its end-to-end UI test; it does not claim to eliminate every pre-existing workaround or to make that private route supported. No new private handoff API or validation bypass is introduced.

## Interrupted complete UI plan

`full-ui-both.xcresult` / `.log` was gracefully interrupted after concrete failures and is not a passing full-plan result. The phone had reported 25 passes, one expected platform skip and a Search root audit failure. That audit identifies the history row delete button at 14 by 12.67 points. The iPad had reported 12 passes before cold Gallery Detail stalled and failed after 182.096 seconds. The app consumed approximately 100% CPU. Simultaneous process samples show active SwiftUI graph/layout work in the app and an XCTest runner waiting for accessibility responses. The last painted Home frame does not identify which pending view graph caused the stall.

Evidence: `ipad-detail-stall-app.sample`, `ipad-detail-stall-runner.sample`, `ipad-detail-stall-screen.png`, and the preserved live logs under `full-ui-observed-logs/`. The rotation sampler was stopped after interruption because this invocation never reached the reader case. No test was skipped or relaxed to resolve either failure; both require corrections followed by a complete rerun.

The interrupted invocation finalized with exit 73. Its aggregate summary contains 30 passed tests, two expected platform skips and three failed tests: the real Search hit-region failure plus two cancellation records. Gallery Detail's failed first attempt was followed by a passing configured retry; that does not erase the preserved stall evidence. `full-ui-both-summary.json` records this distinction.

An independent review of the final migration source found no concrete introduced correctness defects in the seven native overflow menus, reader visibility priorities, native Tab selection, title/search bindings, dialog anchors or recorded scroll-edge propagation. Runtime verification remains separate and incomplete.

## Layout attribution and full-rebuild findings

Temporary fixture-gated, nonobservable diagnostics now record route assignment, body evaluation, viewport/carousel changes and card layout calls. The first diagnostic build was interrupted before completing UI verification (exit 75); two temporary discardable-let lint warnings were corrected with explicit returns, and strict lint then reported zero violations across the nine diagnostic/touch-target files. The recorder and all call sites must be removed before final validation.

The first instrumented stall records `route.openURL`, `route.detailAssigned`, and two Detail evaluations with no loaded detail and loading active. Home evaluated three times and received three initial viewport sizes. No carousel or card-layout callback occurred. The second instrumented stalled process shows the same sequence. This narrows the candidate to initial presentation/layout; it does not prove which nested SwiftUI fitting operation causes the cycle. Evidence: `diagnostic-first-launch-events.log`, `diagnostic-second-launch-events.log`, `ipad-native-launch-trace.sample`, `ipad-diagnostic-second-stall.sample`.

The native SwiftUI template cannot record on this simulator because its Hitches instrument is unsupported. A Time Profiler recording with the SwiftUI instrument completes but reports no SwiftUI data. These traces therefore cannot provide SwiftUI graph attribution. Attaching the profiler also coincided with an invalid-target accessibility-audit failure in the first case of the second diagnostic invocation; that invocation is diagnostic evidence, never final passing verification.

The full recompilation additionally exposed the iOS 27 background-task submission deprecation and a Swift 6.4 nested weak-capture warning in downloads. Amendment 13 authorizes native asynchronous submission with explicit lifecycle ownership and the narrow capture correction, plus deterministic regression coverage.

## Controlled layout experiments

The model-conditional loading refactor still stalled after actual Detail data arrived on both devices (`detail-loading-controlled-both`). Root probes then attributed the repeated size query to Detail, not Home: width 580, unchanged returned size 580 by 860.6765. The measurements returned, but the graph repeatedly requested them while the app consumed approximately one CPU core. Evidence: `layout-root-attribution.sample`, `layout-root-attribution-events.log`.

Flattening the header's nested fitting into six explicit alternatives did not resolve it (`detail-flat-fit-both`). A narrow header-action probe subsequently appears in the sampled fitting stack and records tens of thousands of measurement/alignment queries. Evidence: `header-action-attribution.sample`, `header-action-events.log`. These interrupted diagnostic experiments are failed/incomplete evidence, never successful verification. Their identified post-abort collectors were stopped after preserving logs/samples; final passing runs must use normal collection and finalize.

A native single-instance header Layout is now under verification. It measures the real intrinsic controls and chooses the same responsive preferences without constructing alternate button trees. Temporary attribution will be removed before final suites. In the first comparison, three phone Gallery Detail entries passed in 9.357, 9.789 and 9.947 seconds, and the first landscape reader passed in 34.872 seconds. The iPad reached Detail without the sustained fitting loop but failed its audit with invalid-target-app and its reader hit test. A read-only screenshot shows a SpringBoard `Open in EhPanda?` confirmation obstructing the simulator; this requires a clean preflight and repeat, not relaxed assertions. The screenshot captured after test teardown is evidence of the obstructing system prompt, not a detail-layout visual.

The first clean feature invocation (`final-feature-native27.xcresult` / `.log`) exited 75 during compilation. No tests ran. Swift Testing rejected a nested `#require` inside the HTTP response requirement; the URL requirement is being extracted into its own statement. The downloader snapshot still emitted an implicit-strong/inner-weak capture warning, requiring an explicit outer Task capture list. Review additionally requires asynchronous cleanup for held test gates on throwing assertion paths. Strict standalone SwiftLint had passed all 76 changed/new Swift files before this compile; lint and parse do not substitute for compilation.

Temporary diagnostic calls, recorder types and layout probes are absent from the source. The original Detail loading behavior is restored; only the single-instance responsive header layout remains from the layout experiments.

## Native API feature regression corrections

`final-feature-native27-2` compiled successfully with the deprecated background-submission call and nested weak-capture warnings resolved. Both devices passed all new header placement cases and all five held-submission lifecycle cases. Four test identities failed on each destination: the missing-bundle case incorrectly awaited a submission that must never exist; the new real-transfer fixture returned `fileOperationFailed("Page 156 is missing.")`; and the construction/suspension source censuses correctly detected the added coordinator client double. These remain failures until corrected and rerun. The census is a timing contract: reviewing the new double must precede updating its expected population. Normal Xcode diagnostic collection remains enabled.

The transfer failure occurred during fixture construction: `addingCurrentFileHashes` correctly requires a file for every page presented to it. The test fixture now hashes its 155 existing pages first, then appends page 156 with an empty hash. The final record remains 156 pages with 155 completed. The nil-bundle path no longer waits for nonexistent submission work. The added client double opens all three endpoints with the established suspension convention; the rederived census records four doubles and twelve suspension sites, preserving the guard rather than excluding the new file. Production source is unchanged by these corrections.

A final independent source review found no concrete introduced blocker in the retained native header layout, asynchronous submission ownership, networking capture, native API replacements or page coverage. Runtime test results remain the separate completion gate.

`final-feature-native27-2` finalized normally with exit 65: 1,066 unique tests, 1,051 passed, four failed, eleven pre-existing expected failures, and zero skips across 2,804 runs. After the fixture-hash and census correction, `final-feature-native27-3` exposed a second fixture error: image dispatch uses `/api.php` on the gallery host, while the new duplicated router returned JPEG bytes there. The operation failed its page before reaching the downloader and the test waited for a transfer that would never start. Its raw Downloads logs were preserved under `final-feature-native27-3-observed-logs`; the stalled invocation was interrupted, its identified post-abort collector stopped, and it exited 75. This is incomplete/failed evidence. Replacing the duplicated handler with the suite's existing body-aware download router corrects the fixture without a production change or relaxed assertion. A focused integration rerun precedes another complete feature plan.

The first focused rerun (`held-coordinator-corrected`) then identified the omitted cover allowlist: the shared router properly refused the gallery fixture's real cover URL with unsupported-URL, before page transfer. Its log is retained as `held-coordinator-cover-failure.txt`; the invocation and its identified post-abort collector were stopped, exit 75. The test now parses the fixture's actual cover URL into the explicit allowlist and has an operation-completion acknowledgement: if the scheduled operation returns before transfer starts, the awaited result fails a requirement and executes cleanup. This retains the real transfer assertion and avoids an indefinite wait on an already-ended operation.

## Final feature verification

`held-coordinator-complete-fixture.xcresult` / `.log` finalized with exit 0 in 13.963 seconds: exactly one selected integration test passed, zero failures/skips. The subsequent complete `final-feature-native27-4.xcresult` / `.log` finalized with exit 0 on both destinations. The summary reports 1,066 unique tests: 1,055 passed and eleven pre-existing expected failures, zero unexpected failures and zero skips. Including dynamic parameters and devices, there were 2,804 runs; each device records 1,391 passes and eleven expected failures. The new real-transfer integration passed in 0.300 seconds on both. Both source censuses passed. No runtime warnings are reported. The final source has zero strict SwiftLint violations across 77 changed/new Swift files, and `git diff --check` passes.

Both simulators were observed at SpringBoard with no system dialog before starting the complete `UITests` plan in `final-ui-native27`. No test settings, retries, assertion filters or diagnostic collection were disabled.

## Remaining portrait-restoration layout defect

In `final-ui-native27`, all applicable accessibility audits pass first attempt on both devices, including repeated cold Gallery Detail. The phone native-overflow reader case completes in 35.751 seconds. On iPad its behavior assertions finish around 35 seconds, then portrait restoration again consumes one CPU core and waits for event-loop idle; XCTest ultimately reports a 100.677-second pass. That result does not close the runtime defect. `final-ipad-portrait-layout.sample` captures this remaining loop. Unlike the earlier Detail fitting attribution, the sample contains repeated `GalleryCardCell.body` and its fitting content on the underlying Home screen. Read-only source analysis is in progress while the remaining unmodified UI tests run. No sampling instrument was injected into source and no assertion or wait was relaxed.


The full UI invocation was interrupted with exit 75 after preserving its logs. Phone reader synchronization cases passed; iPad autoplay failed twice by selecting the background Detail More button, then passed its third attempt. The iPad scrolling case reproduced the existing W-38 indicator/content discrepancy (indicator 2 versus visible page 3). The phone Share case was still waiting for Safari idle after long-pressing its fixture link. The invocation is incomplete/failed, not a green full plan. Logs are retained under `final-ui-native27-observed-logs/`.

`carousel-rotation-trace.xcresult` finalized with exit 0, but its 102.167-second reader case again includes the sixty-second portrait idle timeout and does not close the defect. The bounded trace (`carousel-values.txt`) shows that after width changes from 1,210 to 834 points, targets 42–47 retain the correct local pitch but share an approximately 11,552-point extra origin. The absolute-offset index formula therefore reports the preceding logical card and continuously rewrites its idle target. This is a lazy-stack estimation error in app selection math, not evidence for changing center anchors. The anchor-only experiment was drafted but never applied. Apple's [lazy-stack explanation](https://developer.apple.com/videos/play/wwdc2026/321/) explicitly recommends relative visible target geometry instead of absolute content offsets.

The reader test now scopes native overflow identity to `reading_view`; the prior app-global first match could select the obscured Detail toolbar. The migration reader case now asserts portrait restoration and Read hittability within fifteen seconds, including normal XCTest idling. No production toolbar was relocated and no idle wait was disabled.


## Responsive header visual verification

Both devices were checked at standard size and by changing the running app through AX1, AX3 and AX5. The category and persistent action controls remain disjoint, preserve their intrinsic sizes and reflow; controls below the viewport remain reachable by native scrolling. On the phone at AX5, scrolling reveals the complete Read control and tapping it opens the reader. The scrolled header visibly shows the requested progressive top blur. Evidence: `header-phone-{standard,ax1,ax3,ax5,ax5-scrolled,ax5-reader}.png` and `header-ipad-{standard,ax1,ax3,ax5}.png`.

RTL was verified at AX5 on both devices (`header-*-rtl-bothflags.png`): the category moves to the right, controls to the left, and horizontal action order mirrors once. The older documented `AppleTextDirection` argument alone did not mirror SwiftUI here; adding the native `NSForceRightToLeftWritingDirection` test preference produced the observed mirrored layout. These are temporary launch preferences, not application source changes.

The unchanged isolated Share test has passed first attempt on both destinations (phone 161.454 seconds, tablet 275.621 seconds). Its sixty-second waits are Safari animation-idle notifications: Safari samples show its main thread waiting, not the app layout loop. Normal Xcode diagnostics are still finalizing; exit status will be recorded when complete.


The standard-size iPad Download menu opens from the persistent header control (`header-ipad-download-menu.png`). Changing from standard to AX5 dismisses that native menu while the overall header changes arrangement; this is recorded as observed behavior, not a claimed menu-retention pass. No download action was selected. Standard text size and normal launch direction were restored afterward.


`share-isolated27` finalized with exit 0 on both destinations. Normal diagnostic collection reached its six-hundred-second timeout on both devices; collection settings were not changed and no collector was interrupted. The final result is a passing handoff with recorded Safari idle-notification delays.


The relative-card experiment (`carousel-relative27`) passes the reader restoration timing assertion on both devices (36.974 and 38.135 seconds for the complete cases), but fails the additional semantic review: iPad begins on buffered card 43 and ends on 47. The trace shows the viewport resizing before the state-driven card width, followed by competing candidates from successive layouts. It is not accepted as a completed fix. Native container-relative sizing and explicit center preservation are the next controlled correction; the new Home regression requires the same actual centered gallery through both rotation directions.

`carousel-relative27` finalized normally with exit 0 after standard diagnostic collection. Its assertions passed, but the trace-proven selection change remains a rejected experiment. The next comparison includes the new same-gallery regression, with timing measured after synchronized frame and label queries.

`carousel-native-sizing27` fails the same-gallery Home regression on all three attempts on both devices. Reader restoration remains fast (35.859 and 36.768 seconds). The test/application logs are preserved in `carousel-native-sizing27-observed-logs`; the rejected diagnostic invocation was interrupted after test actions completed. The sizing change alone is not accepted.

`carousel-frame-identity27` fails all Home attempts on both destinations and was interrupted after preserving complete logs (exit 75). Independent accessibility frames agree with native geometry: the explicit-center experiment actually places the initial card left of center. Native target 43 stays unchanged until the app candidate writes 44. This attributes selection loss to geometry issuing navigation commands. Amendment 20 is rejected and its presentation changes are reverted; native accessibility-focus identity will replace the inferred idle-geometry handoff.

The first `carousel-focus-identity27` invocation started after a patch-path application error, so it did not contain the intended focus correction. It was cancelled and its identified post-cancellation collector released (exit 75); it is invalid verification evidence. The source was then applied from the reviewed draft, its required focus state and absence of geometry target writes checked explicitly, and `carousel-focus-identity27-2` started with normal settings.


`carousel-focus-identity27-2` finalized normally with exit 0. Home rotation passes first attempt on phone (15.918 seconds) and tablet (17.165 seconds), preserving the selected gallery and actual centered frames through both directions. Reader restoration also passes; each device executes both cases with zero failures. Geometry no longer commands target changes.

Both devices completed six forward and six reverse gestures, advancing exactly one native target per gesture and returning to the original logical card. A separate phone run completed 44 reverse flicks, target 43 through minus one, with every transition asserted from the bounded trace. This verifies wrap/rebase and negative IDs. Evidence is in `carousel-manual-{phone,ipad}.log`, `carousel-negative-phone.log` and start/loop screenshots.

Actual VoiceOver gestures traverse the six-card initial window on both devices and return from Frontpage to the last card. The iPad also traverses all six backward. Native iOS 27 target changes precede focus notifications and occur during interacting phases; the experimental focus synchronizer never writes on either device. It is removed as unnecessary compatibility machinery. The clean build still requires the same VoiceOver walkthrough after removing that attachment. The first-use VoiceOver tutorial was dismissed with a rapid native double tap; keyboard chords did not navigate these simulators, so verification uses actual one-finger VoiceOver flicks. The earlier phone negative-window attempt reached Reload when going before its first currently exposed card; it is not counted as the complete initial six-card walkthrough. No production change was made to alter that native ordering.

## Final clean source review and suite

The planner approved amendment 23's clean source: no focus synchronizer or diagnostics remain; relative card geometry only updates the semantic page index; the original sizing, margins, native anchors and settlement rebasing remain. The Home regression asserts the actual card midpoint within one point at initial entry and after each rotation, and includes synchronized frame/label queries in its transition budget. The complete clean UI plan is running as `final-ui-native27-clean`, with normal validation, retries and diagnostics. Both simulators were restored to their original VoiceOver-off state before invocation.

A broader strict lint pass included all 80 changed/new Swift files and found one existing violation missed by the prior 77-file source selection: `AppPackage/Package.swift` has 1,129 lines against the 1,000-line limit. The prior clean lint result applies to its narrower recorded scope. The manifest is being simplified without changing the evaluated package graph; no rule exclusion or suppression is permitted.

All five migration-specific UI cases passed on their first attempt on both devices in `final-ui-native27-clean`. Home rotation retained actual centering (14.310 seconds phone, 15.284 seconds tablet for the complete test); reader landscape/portrait recovery took 35.434/36.632 seconds. All applicable native accessibility audits passed. The complete invocation is not green: iPad autoplay failed all three attempts because the scoped More control was not hittable after selecting Off, and iPad scrolling reproduced W-38. The earlier selector-scope correction alone does not resolve autoplay. Its root cause remains under investigation using failure hierarchy/presentation evidence; no test assertion or owner-withdrawn reader fix is changed.

The clean-build VoiceOver walkthrough passed on both devices after removal of the focus attachment: six distinct cards forward and backward, Frontpage exit and return, zero focus resets. The phone started at Home, then Reload; iPad started at Reload after its native tab group. Evidence: `clean-vo-{phone,ipad}-walk.json`, corresponding native focus logs, final accessibility outlines and screenshots. VoiceOver was restored to off on both. Native accessibility services persisted an explicit false preference after shutdown; the enabled state matches the original baseline, and no VoiceOver touch process remains.

Autoplay attribution: the iPad session log at 15:43:11.188–11.260 places the indicator under a navigation bar with no `reading_view` ancestor, while its page scroll view remains inside that ancestor. At 15:43:13.451 the old scoped query returns zero overflow matches. With VoiceOver off, manual one-second playback, Off, and More worked normally; the More menu displayed Reading Setting. Evidence: `autoplay-manual-running.txt`, `autoplay-manual-off-settled.txt`/`.png`. The correction targets the navigation bar containing the existing reader indicator and requires unique bar/button matches. No app code change or timing relaxation is needed.

`final-ui-native27-clean` finalized normally with exit 65. Phone: 51 cases, 49 passed, two pre-existing iPad-only skips, zero failures. iPad: 49 passing cases and six failed attempts across two cases (autoplay toolbar lookup and W-38 scrolling), no skips. All remaining suites, including Share handoff, passed first attempt. Failed attempts remain in the result bundle.

The first simplified manifest passed syntax but failed full SwiftPM type-check because its default shared plugin value is main-actor-isolated. The existing helper extension now declares `@MainActor`; no unchecked isolation or suppression is used. `package-before-cleanup.json` and `package-after-cleanup.json`, evaluated from the same path/toolchain, are completely equal, with all 66 targets and plugins preserved. Strict SwiftLint then passed all 80 changed/new Swift files, zero violations (`final-strict-lint-clean.log`). The corrected reader selector is being checked by the complete reader class on both destinations as `final-reader-native-toolbar27`.

## Final reader test actions

With the corrected semantic toolbar selector, `final-reader-native-toolbar27` reports five passing phone cases and four passing iPad cases. iPad W-38 scrolling failed all three configured attempts; no other case failed. Autoplay passed first attempt in 81.235 seconds on phone and 82.940 seconds on iPad. All existing assertions, retries, normal idling and timeout values remain intact. The test actions finished at 16:09:15 and 16:10:17 JST respectively; normal native diagnostic collection is still finalizing.

The full-plan pass criterion is explicitly limited by this existing owner-carried issue. The migration-specific APIs, navigation/search, carousel behavior and feature tests are verified; the global iPad UI suite is not labeled passing and Phase 16 is not closed. The owner-withdrawn W-38 implementation is not reinstated or replaced within this migration.

The final scrolling failures are retained exactly: the first iPad attempt did not advance (indicator 2, visible page 2), and the next two reproduced the W-38 disagreement (indicator 2, visible page 3). The case remains red; no attempt is reclassified as a pass or an expected failure.


## Finalized reader result and source closure

`final-reader-native-toolbar27.xcresult` finalized normally with exit 65 at 16:20 JST. The result summary records five unique tests, four passed and one failed, across twelve device/repetition runs: iPhone five passed, zero failed; iPad four passed and three failed attempts of the same scrolling case. There are zero skips and zero expected failures. Autoplay, resume, tap-zone and slider cases pass on both devices. The scrolling failure details above remain unchanged.

The result retains twelve internal QoS priority-inversion warnings; these are not silently dropped or counted as app concurrency diagnostics. Native diagnostic collection completed through its normal toolchain timeout path, without disabling collection or interrupting the invocation.

All source changes are committed through `d7f8b191`. The final checks cover the graph-identical manifest cleanup and semantic reader selector, strict SwiftLint over all 80 changed/new Swift files, completed FeatureTests and UI results, the clean-build native VoiceOver walks, and the 46-page scroll-edge inventory. The final documentation commit closes this quick migration with W-38 explicitly carried; it does not close Phase 16 or claim a green global iPad UI plan.
