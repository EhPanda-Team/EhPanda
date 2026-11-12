---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 1
status: task-1-passed
---

# Home full-content feasibility gate

## Native library correction — 2026-10-03

The owner correctly identified SnapshotTesting's custom-size support and requested
continuation. Pinned 1.19.6 includes SwiftUI `.fixed(width:height:)`, custom
ViewImageConfig and UIKit `.image(size:)`. Earlier candidates used a manual renderer
and SnapshotTesting's UIImage encoding/comparison; they did not exercise these native
capture strategies. Their failures cannot establish library-strategy infeasibility.

The orchestrator withdraws the premature stitching-choice request. A bounded actual
Home probe now exercises native UIViewController capture at measured normal and taller
content-derived sizes, with original traits/safe area and native pixel/geometry evidence.
Original D-08 and all completeness/layout requirements remain. No stitching or acceptance waiver is approved. Historical manual-renderer evidence
is retained below; the integrated native strategy now clears Task 1.

The genuine app-host and Home full-content gates are cleared. Task 1 is complete;
Task 2 is next, and all later waves remain unstarted. This does not complete plan 17-01
or approve any baseline.

## Direct native strategy result — 2026-10-03

The final direct strategy probe ran 2 actual tests: 2 passed, 0 failed/skipped,
0 Repetition nodes, exit 0, no xcresult runtime warnings or unbalanced appearance
transition messages. The library generated the requested 420 x 1374-point image at
3x scale. Its 420 x 912-point crop matches the normal native image exactly. Visual
inspection shows all six principal covers, complete Toplists text and the final Other
section in one image, with no stitching or black tail.

Evidence: `/tmp/ehpanda-phase17-library-custom-height-3.xcresult`,
`/tmp/ehpanda-phase17-library-custom-height-3.log`,
`/tmp/ehpanda-phase17-library-custom-height-3-summary.json`,
`/tmp/ehpanda-phase17-library-custom-height-3-tests.json`, and attachments in
`/tmp/ehpanda-phase17-library-custom-height-3-attachments`.
Clean build: `/tmp/ehpanda-phase17-library-custom-height-clean-4.log`, exit 0,
no compiler/lint diagnostics. Earlier probe 1 had double root sizing; probe 2 fixed
size but emitted appearance messages. Disabling automatic root autoresizing while
SnapshotTesting explicitly owns frame sizing fixes both without detaching the root.

This is native size/viewport proof for the preceding inline fixture, not Task 1
completion. FullContentHost is now being integrated with the native strategy, stable
height convergence and an actual-PNG census using visible public fixture IDs, Vision
and connected artwork pixels. Those updated source/fixture gates pass in the integrated run below.
The phone/tablet feasibility matrix remains Task 2 work.

## Integrated Task 1 GREEN — 2026-10-03

The current source and marked fixture pass all 3 actual VisualTracerTests: active host,
Home full-content tracer and direct custom-height probe. Exit 0; 0 failed/skipped,
0 Repetition nodes; xcresult runtimeWarnings is empty. Complete logs have no unbalanced
appearance transitions or unimplemented dependency failures. Clean build exit 0 has
no compiler/deprecation/lint diagnostics.

Actual PNG recognition finds VH1 through VH6 exactly once. Connected captured pixels
prove each complete cover retains its 8:11 ratio; the final Other section and its cards
are visible. Content height is 1218 points; output is 420 x 1374 points (1260 x 4122 pixels),
with two stable iterations. Its native 420 x 912 crop is pixel-identical to the normal
viewport. The test also asserts restored native root/window/scene geometry, active
attachment, orientation and horizontal scroll frames. The full image was inspected.

SnapshotTesting consumes its controller attachment after rendering. The normal viewport
is drawn in the original real window; the full extent is rendered once by the library.
Successful cleanup restores a fresh UIHostingController with the same actual Content/Store,
which avoids reusing a controller after the library's appearance cleanup. Strict native
pixel and restored geometry checks remain required. This proves this finite Home fixture,
not the unexecuted List/reader or device/size/orientation matrix.

Evidence:

- Clean build: `/tmp/ehpanda-phase17-library-full-content-clean-4.log`.
- Result: `/tmp/ehpanda-phase17-library-full-content-2.xcresult`.
- Log: `/tmp/ehpanda-phase17-library-full-content-2.log`.
- Summary/tests: `/tmp/ehpanda-phase17-library-full-content-2-summary.json` and
  `/tmp/ehpanda-phase17-library-full-content-2-tests.json`.
- Attachments: `/tmp/ehpanda-phase17-library-full-content-2-attachments/manifest.json`.
  Home archive: `8AD80C30-D342-4A47-ABE8-0FA437DF85CD.zip`.
- First integrated run is retained at `/tmp/ehpanda-phase17-library-full-content.xcresult`:
  2 passes/1 failure, rejected for artwork seed selection and appearance messages.
  Sampling beside the actual OCR glyph and rendering once per controller fixes both.

Command (after the clean build):

```sh
xcodebuild test-without-building -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=35988D34-B4E9-44C6-82B5-CDA2CF391339' \
  -parallel-testing-enabled NO -only-testing:VisualSnapshotTests/VisualTracerTests \
  -resultBundlePath /tmp/ehpanda-phase17-library-full-content-2.xcresult
```

## Proven integration

- Native VisualSnapshotTests is hosted by the actual EhPanda executable. Generated
  xctestrun has IsAppHostedTestBundle=true and TestHostPath
  `__TESTROOT__/Debug-iphonesimulator/EhPanda.app`.
- Early DEBUG-only dependency preparation precedes Store/state creation. It requires
  XCTest plus EHPANDA_VISUAL_TEST_HOST=1 and forces offline network stubs.
- Native XCTest resets Dependencies' prepared cache at each case boundary. Visual test
  setUp restores the same opt-in host defaults before UIKit callbacks render; the latest
  run has no DeviceClient crash or unimplemented-dependency failure.
- Bootstrap GREEN: 10 passed, 0 failed/skipped, 0 Repetition nodes, exit 0;
  `/tmp/ehpanda-phase17-bootstrap-green.xcresult`.
- Current clean build-for-testing: exit 0, no compiler/deprecation/lint diagnostics;
  `/tmp/ehpanda-phase17-library-full-content-clean-4.log`.
- Six finite inline public galleries have fixed date, IDs, order, cached synthetic artwork
  and disabled animations. Actual Home content height is 1218 points, exceeding the
  measured 420 x 912-point iPhone Air viewport at 3x scale.

## Rejected capture evidence

| Method | Actual result | Disposition |
| --- | --- | --- |
| Initial partial prototype | Combined only top and bottom viewport images; no complete middle or trustworthy census. | Rejected implementation; replaced. |
| Native drawHierarchy with expanded scroll host | Root/window remain 420 x 912; scroll extent settles at 1374 points in two stable iterations. 1260 x 4122 output has an unrendered region outside the physical viewport; accessibility traversal yields no elements and six zero item counts. | Not complete. |
| Native layer render with the same logical viewport | Some artwork extends below the viewport, but text/sections remain missing; native viewport pixel parity fails. | Not faithful or complete. |

The last candidate differs from the native hierarchy viewport in 477737 of 3447360
pixels (13.8581%). This is diagnostic comparison evidence, not a tolerance adjustment.
The candidate visibly omits the reload affordance and does not render the final Other
section correctly. Missing content is not waived merely because PNG bytes exist.

Historical manual-renderer command:

```sh
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=35988D34-B4E9-44C6-82B5-CDA2CF391339' \
  -parallel-testing-enabled NO -only-testing:VisualSnapshotTests/VisualTracerTests \
  -resultBundlePath /tmp/ehpanda-phase17-layer-parity.xcresult
```

Exit 65; 2 actual tests, 1 passed, 1 failed, 0 skipped/Repetition nodes, no runtime
warnings. Failure was nativeViewportPixelsChanged; that historical run did not prove
census/last-item acceptance. After the test engine completed, only its optional simctl diagnose collector
was stopped so xcodebuild could finalize the same failure. No failure retry was enabled.

Evidence is retained in `/tmp/ehpanda-phase17-layer-parity.xcresult`, full log
`/tmp/ehpanda-phase17-layer-parity.log`, exported attachment manifest
`/tmp/ehpanda-phase17-layer-parity-attachments/manifest.json`, and its unpacked directory.
The archive contains native viewport, layer viewport, full candidate and geometry JSON.
The earlier drawHierarchy evidence is retained in
`/tmp/ehpanda-phase17-home-single-hierarchy-2.xcresult` and its exported attachments.
Neither is an approved reference.

## Historical proposed decision — withdrawn

The execute-plan workflow's Rule 4 says: "architectural changes: STOP, present decision
to user, await approval." The tracer gate also forbids expansion on failed verification.
The plan's bounded feasibility stop remains in force; the owner already approved genuine
app hosting and inline recovery, so neither decision needs to be asked again.

1. Recommended: revise Task 1 and D-08's test-capture method to allow complete native
   viewport tiles assembled into a test-only long image, with overlap checks, complete
   item/last-section evidence from rendered pixels/text and explicit clipping/duplicate
   rejection. Record every normal viewport image independently. Native marketing captures
   remain one normal device-size image per state. This is a proposed change, not approval.
2. Retain the container-height method and commission a new rendering-host design before
   another bounded feasibility attempt. This may require production viewport seams or
   a separate native validation runner; any such scope must be planned explicitly first.

Do not silently stitch, relax census, change native navigation/search/scroll-edge policies,
accept layer rendering differences, fabricate accessibility metadata or edit production
screens under the current Task 1 file scope.
