---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: awaiting-capture-architecture-direction
recorded: 2026-10-03
---

# Native hierarchy render-size finding and next decision

The owner supplied another research agent's standalone Simulator probe report. The root
located and reviewed the preserved probe sources, PNGs and original recorded tool outputs.
No probe app, build or native XCTest was rerun in this review. The existing three-run
harness recovery cycle remains exhausted; Task 2 and the full matrix remain incomplete.

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
to repeat the external result. Owner approval of a capture architecture remains pending.

## Why an apparently successful library call returns a transparent image

The pinned SnapshotTesting 1.19.6 source in Common/View.swift calls
`view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)` inside a renderer closure,
without checking its Boolean return. Its renderer is not explicitly opaque. Our latest
original PNG has every alpha byte zero, and the standalone probe records false with
transparent output at the same extent. Source inspection supports this propagation path;
the strict harness comparison correctly rejects the empty result.

The current FullContentHost bound of 32768 pixels is an algorithm/resource guard, not
a validated native hierarchy rendering limit. It permits an extent beyond the observed
native ceiling and checks only height. It remains unchanged until an approved strategy
defines both per-render admissibility and composite-output bounds.

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

## Concrete proposed revision for owner review

Recommended direction: a native hierarchy capture strategy that renders bounded regions
and combines them while keeping the actual content root's bounds, effective safe areas,
traits and layout stable across regions. Preserve native 3x glass appearance and the
actual production views. Define native per-render dimension guards separately from the
permitted final composite extent. Report render failure explicitly rather than treating
a requested PNG size as evidence of a successful draw.

The proposed initial work is a bounded feasibility cycle of at most three sequential
native runs, owned by FullContentHost.swift and FullContentFeasibilityTests.swift. First
prove effective safe-area/layout stability and region overlap continuity on actual
Comments, then retain existing complete native viewport parity, exact item/tail census,
artwork and restored-host checks. Keep the existing Home proof as a regression gate.
Matrix expansion follows a passing actual-content gate, not the standalone clip result.
Implementation details need SDK/API research; no safe-area override or tiling code is
represented as already correct or adopted.

This is a proposal, not an amendment to approved execution scope. Plan 17-01 explicitly
says no stitching or acceptance change is approved. The execute-plan workflow's Rule 4
requires a decision before architectural changes. A layer-render fallback with accepted
glass differences would instead require an explicit acceptance revision; none is granted.
No source, dependency pin, baseline, SUMMARY or completion count changes from this review.
