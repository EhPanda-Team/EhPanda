---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 17-01-T1
status: revision-approved
updated: 2026-10-02T06:25:40.734Z
---

# Plan 17-01 active-window hosting gate

## Outcome

No task or plan is complete. The clean integration build passes without compiler or lint
warnings. The single discovered tracer fails because the SwiftPM test runner has no
foreground-active `UIWindowScene`. No candidate screenshots were produced. Task 2 and
all later waves remain unstarted. No successful SUMMARY or snapshot baseline exists.

The approved plan requires: "If the package runner cannot supply a valid hosting window
or the actual Home algorithm cannot preserve viewport behavior, STOP for orchestrator
instructions before any expansion."

## Verified evidence

| Check | Actual result | Evidence |
| --- | --- | --- |
| SnapshotTesting resolution | Exactly 1.19.6; test-target dependency only | Both existing resolved lockfiles and `AppPackage/Package.swift` |
| Clean build-for-testing | Exit 0; 46.018 seconds; no compiler/lint warnings | `/tmp/ehpanda-phase17-t1-clean-final.log` |
| Original method filter | Exit 0, zero matched tests; rejected as gate evidence | `/tmp/ehpanda-phase17-t1-tracer-final.xcresult` |
| Test enumeration | One discovered test, identifier ends in `testHomeFullContentTracer()` | `/tmp/ehpanda-phase17-t1-test-enumeration.json` |
| Actual tracer | Exit 65; 1 failed, 0 passed, 0 skipped, 0 expected failures | `/tmp/ehpanda-phase17-t1-host-gate.xcresult` |
| Failure | `Caught error: No foreground-active UIWindowScene is available` | `/tmp/ehpanda-phase17-t1-host-gate-summary.json` |
| Repetition / runtime warnings | Zero Repetition nodes; zero runtime warnings | `/tmp/ehpanda-phase17-t1-host-gate-tests.json` and summary |
| Owner-staged files | Original staged patch remains byte-identical | Compared with `/tmp/ehpanda-phase17-owner-staged.patch` |

The executed hosting probe used **iPhone 17**, UDID
`E72AA324-7276-4A7F-AD88-AEF4FE7CCA10`, iOS 27.0, build 24A434.
It is not capture-matrix evidence for the owner-selected iPhone Air or iPad Pro 11-inch
(M5). Resolve those devices afresh for the eventual accepted geometry/capture checks.

The generated test-run configuration names the Xcode `Agents/xctest` executable as
`VisualSnapshotTests`' test host, rather than the app executable. The runtime failure
confirms the unavailable active scene; it is not a sandbox/cache failure.

## Commands actually executed

```sh
xcodebuild clean build-for-testing -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=E72AA324-7276-4A7F-AD88-AEF4FE7CCA10'

xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=E72AA324-7276-4A7F-AD88-AEF4FE7CCA10' \
  '-only-testing:VisualSnapshotTests/VisualTracerTests/testHomeFullContentTracer()' \
  -parallel-testing-enabled NO \
  -resultBundlePath /tmp/ehpanda-phase17-t1-host-gate.xcresult
```

Commands used sandbox escalation for the normal Xcode caches and CoreSimulator services.
No automatic failure retry was enabled. The installed Xcode help defines
`-retry-tests-on-failure` as a switch, not a boolean-valued argument: omitting it disables
retry. The approved plans' `-retry-tests-on-failure NO` spelling needs correction.
The Swift Testing method selector also needs the discovered `()` suffix. The first
zero-test run was not accepted as a pass and no failed actual tracer was rerun.

## Owner-approved revision — 2026-10-02

Revise the hosting boundary in plan 17-01 to use a **genuine app-hosted visual unit-test
target**. Keep actual production views as the capture subjects and keep third-party
dependency declarations/version pins in `AppPackage/Package.swift`.

The scope change requires coordinated Xcode target/test-host wiring in
`EhPanda.xcodeproj/project.pbxproj`, the shared `EhPanda` scheme, the FeatureTests plan,
and the local package's visual-test/support target exposure. Visual test implementation
remains in the local package layout. Preserve the existing owner-staged project edits
when adding the new target configuration. No offscreen fallback, SDK suppression,
artificial scene, or eager replacement of production views is proposed.

Before any expansion, prove that the new runner supplies a foreground-active scene,
rerun clean integration, and finish the actual Home tracer on the selected phone.
Passing hosting alone does not pass full-content capture: logical viewport preservation,
exact item census, final-section visibility, coherent scale/safe areas and complete
normal/full images must still be measured. Then execute Task 2's full selected-family
feasibility coverage and public fixture export before wave 2.

The owner selected option 1 on 2026-10-02. Plan 17-01 now authorizes the genuine
app-hosted target, scheme/test-plan wiring and local VisualSnapshotSupport library.
The historical failure evidence above remains unchanged. Hosting and full-content
acceptance still require a successful measured run.

## Partial implementation requiring completion

The dependency/test registration and two visual test files remain uncommitted.
`FullContentHost` now uses the scene-based initializer and comparison defaults to
`record: .never`; the tracer explicitly requests temporary candidate recording.

These are unfinished prototypes. In particular, the current label Set cannot establish
duplicate counts, and resizing the hosting controller's root bounds does not establish
that Home retains its original logical viewport. The remaining deterministic controls,
image readiness, semantic/visible census and visual inspection must be completed and
verified before any task commit or success claim. No screenshot or full-content claim
is credited to this source.

## Execution recovery

The executor was requested as typed `gsd-executor`, model `gpt-5.6-luna`, effort `high`.
Requested configuration is known; runtime model/effort metadata is unavailable and is
unverified. It returned an initial sandbox checkpoint; escalation resolved that issue.
After its later unresponsive interval, the orchestrator interrupted it, inspected the
partial files and completed the final clean build and hosting probe. No executor is
currently modifying source, and the final Xcode command has exited.

## Executor recovery checkpoint — 2026-10-02

The owner-approved amendment was committed as `7ade5c1842`. A fresh typed executor was
requested with the project-resolved model `gpt-5.6-luna` and effort `high`; actual runtime
settings remain unverified. It produced partial genuine app-host target wiring, a local
VisualSnapshotSupport prototype and an XCTestCase tracer, but returned no progress
message, task commit or SUMMARY despite repeated requests for more than ten minutes.
The orchestrator interrupted it under the workflow stall-recovery rule. Both executors
are interrupted; no Xcode build/test process remained at the recovery inspection.

The latest build failed compiling `Resources/ResourceStringSymbols.swift`: generated
localized symbols such as `cancel` and `clear` were unavailable. A diagnostic invocation
with `STRING_CATALOG_GENERATE_SYMBOLS=YES` also failed and is not acceptance evidence.
No hosted test ran; there is no active-scene or full-content success. The prototypes still
need complete implementation and review against the amended contract.

Retained logs: `/tmp/ehpanda-phase17-t1-host-build.log`,
`/tmp/ehpanda-phase17-t1-host-build-2.log`,
`/tmp/ehpanda-phase17-t1-host-build-3.log`, and
`/tmp/ehpanda-phase17-symbol-build.log`. These builds used the selected iPhone Air.
The original owner-staged project/probe patch remains byte-identical to
`/tmp/ehpanda-phase17-owner-staged.patch`. New harness project changes are unstaged.

The workflow requires a recovery choice: continue inline, retry with a fresh executor,
or resume waiting. The orchestrator requested this choice and has not inferred approval
for inline execution. This checkpoint does not revoke the approved app-hosting scope.
