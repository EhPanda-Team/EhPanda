---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: adopted-full-matrix-failed
recorded: 2026-10-03
---

# Native hierarchy render-size finding and adopted architecture

The owner supplied another research agent's standalone Simulator probe report. The root
located and reviewed the preserved probe sources, PNGs and original recorded tool outputs.
No probe app, build or native XCTest was rerun in this review. The historical three-run
harness recovery cycle was exhausted. The owner subsequently adopted and committed the
architecture below; that prior bound no longer applies. Root has now completed clean integration and both actual matrix invocations.
Clean integration passes; the matrices fail Downloads parity. See 17-01-FEASIBILITY-GATE.md.

Reviewed copies and SHA-256 manifest are preserved in
`/tmp/ehpanda-phase17-size-probe-evidence/`: `probe.swift`, `probe2.swift`, `cmp.swift`,
`probe-results.log`, `out/` and `manifest.json`. Original scratchpad files remain unchanged.
The result log contains extracted original output lines, not newly executed observations.
Probe sources are experimental UIKit/SwiftUI code, not proposed repository implementation.

## Established operating limit on the tested Simulators

The recorded Boolean result from drawHierarchy changes at the native screen-scaled
dimension boundary. A plain gradient reproduces the failure without navigation, a List
or glass; ScrollView and glass-toolbar List probes show the same height transition.

| Simulator / native scale | View size in points | Native-scaled dimension | Recorded result |
|---|---|---|---|
| iPhone Air / 3x | 420 x 2730 | height 8190 | true; nontransparent output |
| iPhone Air / 3x | 420 x 2731 | height 8193 | false; render-server error; transparent output |
| iPhone Air / 3x | 2730 x 912 | width 8190 | true |
| iPhone Air / 3x | 2731 x 912 | width 8193 | false; render-server error |
| iPhone Air / 3x | 840 x 2700 | 2520 x 8100; over 20 MP | true |
| iPad Air 11-inch / 2x | 400 x 4096 | height 8192 | true |
| iPad Air 11-inch / 2x | 400 x 4097 | height 8194 | false; render-server error |
| iPad Air 11-inch / 2x | 4096 x 600 / 4097 x 600 | width 8192 / 8194 | true / false |

These controls support a per-dimension ceiling of 8192 native screen pixels on those
Simulators, rather than total pixel area or glass being a necessary trigger. The planned
harness tablet is a different model; these standalone findings are not a passed tablet
coordinate or physical-device validation. Fractional point boundaries were not probed.
Do not present this as a documented universal Apple limit.

The current Comments extent is 420 x 2798 points at native 3x: height 8394 pixels.
Home's passing extent is 420 x 1374 points at native 3x: height 4122 pixels.
The observed operating ceiling explains this specific Comments render-server failure.

## Withdrawn 1x proposal

The first probe explicitly sets renderer scale to 1x or 2x at height 2798 points on the
3x iPhone; drawHierarchy remains false despite smaller output bitmaps. The second probe
overrides window displayScale traits to 1 or 2; logs still show screenScale 3 and failure.
The same distinction appears on the 2x iPad. The render-server size check follows native
screen scale in these experiments, not the requested output renderer/trait scale.

The prior configurable-output-scale / initial-1x proposal is therefore withdrawn as a
remedy for this failure. No 1x plan revision, source change or additional run is needed
to repeat the external result. The owner-adopted slicing architecture below supersedes that approval checkpoint.

## Why an apparently successful library call returns a transparent image

The pinned SnapshotTesting 1.19.6 source in Common/View.swift calls
`view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)` inside a renderer closure,
without checking its Boolean return. Its renderer is not explicitly opaque. Our latest
original PNG has every alpha byte zero, and the standalone probe records false with
transparent output at the same extent. Source inspection supports this propagation path;
the strict harness comparison correctly rejects the empty result.

The current FullContentHost bound of 32768 pixels is an algorithm/resource guard, not
a validated native hierarchy rendering limit. It permits an extent beyond the observed
native ceiling and checks only height. The adopted strategy retains this composite budget and separately enforces the
8192-native-pixel width/read-height ceiling.

The probe logs IOSurface maxima of 16384 and successful Metal texture creation at 8192.
Trying 8193 reaches Metal validation rejection. The matching Metal dimension is a plausible
mechanism, not proof of the render server's internal allocation path. Physical-device
limits remain untested. The earlier glass discussions concern ordinary-sized output and
do not establish the same cause as this size-controlled reproduction.

## Tiling feasibility evidence and its limits

Drawing a bounded clip of an over-limit root succeeds in the probe. Both 1399-point tiles
return true on the 3x iPhone. However, moving the clip changes the hosted view's effective
top safe area from 68 to zero on tile two even while its recorded frame in the window
remains 420 x 2798 at origin zero. The resulting layout seam rejects this naive algorithm.

The probe's pixel comparator checks only the first 2334 rows of a 2736-row viewport,
excluding 402 rows at the bottom. Recorded zero differences establish that top region,
including the toolbar, not complete viewport parity, tail/census or seamless composition.
Neither the passing clip calls nor these PNGs complete the actual Comments gate.

## Adopted revision — owner direction, committed e9e183f6

The owner chose render-server slices and committed the implementation. FullContentHost
keeps its converged full-height layout stationary. RenderServerCapture requests each
bounded rect with resizableSnapshotView(from:afterScreenUpdates:withCapInsets:), draws
the attached replicant and checks drawHierarchy's Boolean. Each slice is at most 8192
native screen pixels tall. Adjacent slices overlap by 64 points; their 8-bit sRGB RGBA
bytes must match exactly or seamMismatch rejects the capture. CPU composition makes
one final image. The full-height 32768-pixel guard is a composite memory budget.

This satisfies D-08 through one output image from one committed layout. Slices read
regions of that stationary frame; no scrolling or moving clip changes the layout.
The rejected moving-clip experiment above remains historical evidence, not the adopted
algorithm. Standalone probe3 evidence under the preserved evidence directory compared
all 8190 rows against a whole 2730-point capture. Its preserved viewport comparator
covers the top 2334 of 2736 rows; complete native viewport parity is instead established
by the incremental actual Comments test, and must pass again in the matrix.

The owner reports incremental build success and six passing actual phone tests:
RenderServerCaptureTests x2, testCommentsNativeCapture and VisualTracerTests x3.
Comments is 420 x 2798 points, 1260 x 8394 pixels, two slices, exact VC1..VC12 census,
strict native viewport parity and two stable iterations. The one render-server error
belongs to the deliberate direct-draw failure pin, not the sliced capture.

The final clean gate passes with zero compiler/deprecation/SwiftLint diagnostics. Both
actual default-traits matrices capture Home and Comments, then fail strict native viewport
parity at Downloads: 147 phone and 55 tablet pixels differ by at most one channel byte.
Tablet Downloads uses one read under the size limit, so this failure is not explained by
slice seams or the dimension ceiling. Combined final accounting is 4 captured, 2 failed
and 26 pending; AX5 OCR overlap and actual landscape remain unverified. Earlier Reader
diagnostics also show top blur and a black overlap band. The full gate remains failed;
architecture approval is settled, acceptance and baseline approval are not.

Current same-frame refinements reserve 64-point read context on each side within the
ceiling, crop the owned slice without redraw and copy canonical sRGB bytes on the CPU.
The complete 64-point overlap remains byte-identical or the capture throws. These changes
fix the observed crop-edge mismatch without moving the committed hierarchy. D-08's
architecture requirement remains satisfied; actual fidelity must still pass every gate.
The prior three-run bound does not apply to this owner-adopted architecture.
