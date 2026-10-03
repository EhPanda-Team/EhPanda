---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: parity-resolved-partial-matrix
recorded: 2026-10-04
source_head: 8e2122c92b7fcd6dea4cb8ee1cdafd3490513f2a
---

# Native hierarchy rendering findings and adopted architecture

The owner-adopted stationary architecture is retained in 73bf3e4b59 and refined by
3b4e460722 / 8e2122c92b. The previous 9906f9a619 Downloads/Reader failures are resolved in
supplied portrait captures. Current matrix: 12 captured, 2 failed, 18 pending; remaining
failures concern phone AX5 Home's container-responsive layout and iPad programmatic
landscape orientation. See 17-01-FEASIBILITY-GATE.md for independently inspected counts,
source-provenance boundaries and exact evidence. No architecture re-approval is pending.

## Distinct measured dimension limits

| Capture operation | Measured boundary on iOS 27 Simulator | Current harness rule |
|---|---|---|
| Direct drawHierarchy | Valid through 8192 native pixels; above is refused | Intentional failure control in tests |
| resizableSnapshotView replicant read | 8190 valid; exactly 8192 can return true with opaque black on 2x iPad | At most 8191 native pixels per dimension |
| Final CPU composite | Independent of individual render reads | At most 32768 pixels tall |

Replicant maximumSliceHeight(forScreenScale:) is floor(8191 / native scale): 4095 pt
at 2x and 2730 pt at 3x. Context is reserved inside that height. The old iPad Reader
middle read was exactly 4096 pt x2 and hit the silent-black boundary. Boolean success
is necessary but does not establish readable/fidelity-correct content. Strict overlap,
viewport parity and census still reject bad output. No physical-device limit is proven.

The tablet probes additionally show that a window narrower than its scene can return
opaque black on every tested path despite drawHierarchy true. Test fixtures now span the
running scene's width and derive dimensions from native scale. Landscape must use actual
rotated scene geometry; fake portrait-window resizing is not a verified alternative.

## Other resolved parity causes

Liquid Glass performs a one-time settling change around 0.45 seconds after window entry
on the measured runtime. Viewport references now require consecutive byte-identical
samples spanning at least 500 ms, with bounded failure. This resolves the toolbar delta.

A full-height key window loses status-bar hiding authority. A full-screen non-key
companion at .normal mirrors the native viewport's measured visibility, preserving safe
area and the native soft top edge. Status drift throws and the companion is cleaned up.
This resolves the Reader top blur in supplied actual captures.

Reader resampling caused glyph-edge differences between clipped and unclipped renders.
The accepted export retains 8:11 and renders each coordinate's pages at its actual pixel
width, with whole-pixel height rounding and a measured non-resampling assertion. It keeps
the default 800 x 1100 export unchanged. Phone-landscape eight-page 2:3 bitmaps alone
would total 32832 px, exceeding the composite budget; retained 8:11 totals 30096 px.
Landscape execution itself remains pending.

Standalone evidence: `/tmp/ehpanda-phase17-size-probe-evidence/probe4-9-render-parity/`,
`tablet-window-width/`, `reader-page-geometry/` and the owner-provided reader E1/E2/E3
experiments. Current capture source is in 8e2122c92b; source/provenance limitations for
supplied gates are explicit in 17-01-FEASIBILITY-GATE.md.

D-08 remains one image from one stationary committed layout. Replicants read bounded
regions without scrolling; complete 64-point overlap bytes must match exactly and CPU
composition copies them. The older recovery bound is superseded. Home viewport design
and actual scene rotation still need resolution before full matrix acceptance.

## Historical direct-size probes and initial slice adoption

The records below describe earlier source/evidence. In particular, statements allowing
8192 pixels for every replicant read and the previous failed-parity accounting are
superseded by the distinct limits and current evidence above.

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

## Adopted revision — owner direction, committed 73bf3e4b59

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
