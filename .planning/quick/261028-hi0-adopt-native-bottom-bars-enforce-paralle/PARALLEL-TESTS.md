# Parallel-test audit

Status: lint policy and normal test-plan parallelism implemented and tested; runner changes pending
owner decision on the concrete exceptions below.
Date: 2026-10-28.

Owner follow-up: **“discuss later.”** The exception discussion is deferred, and none of the three
exceptions is approved. UI adoption continues independently. A command disabling concurrent
destinations was rejected by automatic approval review; the current UI verification instead launches
independent iPhone/iPad jobs concurrently, each with parallel workers enabled and no serial flag.

## Baseline and implemented enforcement

- No executable `.serialized` trait occurs in the package tests or UI tests. The occurrence in
  `CookieClientTests/DidLoginKeyTests.swift` is explanatory prose, not a trait.
- `no_serialized_test` is now an error rule. Ordinary, backtick, whitespace and parameterized-test
  spellings each produced one error with exit code 2. Line comments, documentation comments,
  documentation fields, comment URLs and string literals produced zero violations and exit code 0.
  Actual SwiftLint 0.65.1 was used, with no configuration warnings.
- Every Swift package test directory has a parent SwiftLint configuration. Both test source trees
  pass the new rule with zero violations; no lint exception was added.
- All 24 targets in `AppPackage/Tests/FeatureTests.xctestplan` and the normal `UITests.xctestplan`
  target now explicitly declare `parallelizable: true`. No worker cap or serialization trait was added.
- Swift Testing already schedules tests concurrently within a process. MainActor isolation of
  UIKit work is not a whole-suite serialization waiver. XCTest worker parallelism is a separate
  setting. See [Apple's parallelization documentation](https://developer.apple.com/documentation/testing/parallelization).

## Existing serial settings and proposed decisions

| Site | Concrete dependency | Proposed handling |
|---|---|---|
| `Scripts/verify-full-content-capture.py`: Gate common flags and execution flags | Geometry/capture probes require the host-selected simulator's orientation and content size to persist across successive XCTest and hosted-test invocations. The runner sets content size with simctl, checks the original device remains booted, and rejects result-device IDs other than that exact device. | Make ordinary feature/UI execution parallel by default. Request a narrow exception for the existing exact-device capture sequence; require a named capture mode, not a blanket serial flag inherited by all callers. |
| `Scripts/visual/run-single-pass.py`: enumeration flags | Ordinary selected UI tests can use isolated XCTest workers. Its per-device file lock coordinates independent host invocations, not cases within a run. The common Gate currently serializes the actual run too. | Enable parallel enumeration/execution; preserve per-device ownership and exact test identity/count/repetition checks. Establish how result metadata identifies workers before changing device validation. |
| `Scripts/visual/run-library-validation.py`: enumeration flags and inherited Gate | Library feature tests have isolated mutable fixtures; its result validator also assumes a single exact device ID. | Enable parallel feature execution and validate worker provenance without weakening test accounting. |
| `Scripts/run-duo-ui-tests.py` | All workers would share one `request` and `acknowledgement` file, while the host pose driver always targets the original UDID. Cloned workers would manipulate a different display and race the shared mailbox. | Request an exception only for this host-driven hinge/orientation workflow, or separately refactor it to route per-worker pose requests to the actual worker. |
| `AppshotCapture.xctestplan`: target `parallelizable: false` | A single selected `AppshotCaptureUITests/testCapture()` invocation participates in an external capture session tied to its configured device. There are no multiple XCTest test methods here to parallelize. | Request an exception for this dedicated capture plan, preserving parallelism across independent external capture jobs. Do not apply this exception to the normal UITests plan. |

**No exception is approved yet.** Existing serial settings are recorded as pending, not grandfathered.
The proposed exception scopes are capture/geometry sequences, the host-driven Duo pose runner, and
the one-test external capture plan. They do not cover the FeatureTests plan or normal UI regressions.
Approval must be explicit because the owner's request permits serial execution only with owner approval.

## Defects found and repaired during execution

The Python visual-tooling suite ran 205 tests. Three errors reference the removed
`wait_for_test_window` / `runner.time` process-polling implementation; current code uses a per-device
file lock instead. Those stale tests were replaced with behavior checks for same-device exclusion,
different-device independence and release on failure. The corrected suite passes **206 tests**.
An additional baseline error came from sandboxed `swift package dump-package`; normal package-cache
access resolves it. No Python failure was suppressed or marked expected.

The first parallel FeatureTests run found an unimplemented `DownloadClient.setIsInBackground` call
from the host application's scene callback during `RenderServerCaptureTests`' pixel-budget test.
Global dependency preparation did not bind the host Store's fixtures across XCTest dependency scopes.
The application now explicitly installs its existing inert visual-host dependencies on that Store.
The shared configuration also provides fresh in-memory storage. Release behavior is unchanged.
A new regression sends a background transition while an unrelated test dependency scope is current;
the Store retains its fixtures and updates its scene state without an unimplemented endpoint.

## Execution evidence

| Check | Result | Evidence |
|---|---|---|
| SwiftLint rule fixtures | Four prohibited spellings rejected; comments and strings accepted; no configuration warnings | `/tmp/ehpanda-261028-lint-fixtures.json` |
| New rule against both real test trees | Zero violations | `/tmp/ehpanda-261028-lint-tests.json` |
| Strict lint of all three changed Swift files | Passed | SwiftLint 0.65.1, `lint --strict --no-cache` |
| Python visual-tooling suite | 206 passed | `/tmp/ehpanda-261028-python-tests-fixed.log` |
| Initial parallel FeatureTests | 1 unexpected failure, 9 pre-existing expected outcomes; host fixture defect described above | `/tmp/ehpanda-261028-feature-tests.xcresult` |
| Corrected-source parallel FeatureTests | 1,431 identities: 1,422 passed, 9 pre-existing expected outcomes, 0 failed/skipped; 0 Repetition nodes | `/tmp/ehpanda-261028-feature-tests-scoped.xcresult` |
| Concurrent-destination UI checks | Two selected methods passed on both iPhone and iPad, four executions; 0 failed/skipped/repeated | `/tmp/ehpanda-261028-parallel-ui.xcresult` |
| Parallel-worker UI checks | The same two methods passed on separate cloned workers on each of iPhone/iPad, four executions; 0 failed/skipped/repeated | `/tmp/ehpanda-261028-parallel-ui-workers.xcresult` |

FeatureTests ran with `-parallel-testing-enabled YES` on an iPhone 17 simulator with iOS 27.0.
The log identifies cloned XCTest workers. Parameter expansion yields 2,059 device-level executions
(2,050 passed and 9 expected outcomes); those are distinct from the 1,431 test identities. No expected
outcome annotation was added. A compile-only intermediate attempt caught and fixed the new test's
dependency-key qualification and missing SwiftUI import before the final successful run.

The UI selection covers `GalleryLayoutUITests/testGridLoadsNextPageFromTrailingVisibility` and
`LibraryPresentationUITests/testCategoryNavigationReturnsAndSwitchesSources`. The first UI run used
concurrent destinations; Xcode explicitly reports that this mode does not parallelize workers within
each destination. The separate worker-mode check adds `-disable-concurrent-destination-testing` with
`-parallel-testing-enabled YES`: destinations execute successively, while two cloned workers execute
the test classes concurrently on each destination. Both logs and result counts confirm four passing
executions. The result summary attributes those worker runs to the original destination device IDs;
the log independently names Clone 1 and Clone 2 for each. This establishes ordinary worker result
provenance, but does not make host-directed orientation or pose commands reach clones.

Verification uses a temporary copy
of the generated `.xctestrun` with repetition policy removed, preserving the original manifest and
repository test-plan retry settings. A green retry is not counted as acceptance.

Device-dependent capture and Duo pose execution still require their own prerequisites and approved
scope. Ordinary parallel tests do not verify those external workflows. After the pending decision,
change the common runner and its callers together, prove cloned-worker result attribution, and run
the affected contract and native checks before closing this task.

## UI adoption verification follow-up

The concurrent iPhone/iPad jobs each dispatch three active XCTest class workers. The initial
11-method selection yields 10 passes and one Search hit-region failure per device. After correcting
the actual labels, three affected/relevant methods pass once per device (6/6), with no skips or
repetition nodes. The corrected iPad run uses two active workers; an iPhone worker launch failure
leaves its scheduler using one worker, with no configured cap or serial flag. The initial run proves
three active class workers per device. The failed bundles and launch diagnostics remain available; no serialization
setting or audit exclusion hides them. See [the detailed record](UI-IMPLEMENTATION.md).
