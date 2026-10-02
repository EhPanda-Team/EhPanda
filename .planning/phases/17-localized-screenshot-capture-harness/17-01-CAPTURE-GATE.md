---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 1
status: awaiting-capture-strategy-decision
---

# Home full-content feasibility gate

The genuine app-host gate is cleared. Task 1 remains incomplete: neither tested
single-hierarchy renderer supplies a faithful complete Home image and exact census.
Task 2 and all later waves remain unstarted. No successful SUMMARY or baseline promotion
is authorized by this evidence.

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
- Latest clean build-for-testing: exit 0, no compiler/deprecation/lint diagnostics;
  `/tmp/ehpanda-phase17-layer-parity-clean-2.log`.
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

Latest command:

```sh
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=35988D34-B4E9-44C6-82B5-CDA2CF391339' \
  -parallel-testing-enabled NO -only-testing:VisualSnapshotTests/VisualTracerTests \
  -resultBundlePath /tmp/ehpanda-phase17-layer-parity.xcresult
```

Exit 65; 2 actual tests, 1 passed, 1 failed, 0 skipped/Repetition nodes, no runtime
warnings. Failure is nativeViewportPixelsChanged; census/last-item acceptance is still
unproven. After the test engine completed, only its optional simctl diagnose collector
was stopped so xcodebuild could finalize the same failure. No failure retry was enabled.

Evidence is retained in `/tmp/ehpanda-phase17-layer-parity.xcresult`, full log
`/tmp/ehpanda-phase17-layer-parity.log`, exported attachment manifest
`/tmp/ehpanda-phase17-layer-parity-attachments/manifest.json`, and its unpacked directory.
The archive contains native viewport, layer viewport, full candidate and geometry JSON.
The earlier drawHierarchy evidence is retained in
`/tmp/ehpanda-phase17-home-single-hierarchy-2.xcresult` and its exported attachments.
Neither is an approved reference.

## Decision required

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
