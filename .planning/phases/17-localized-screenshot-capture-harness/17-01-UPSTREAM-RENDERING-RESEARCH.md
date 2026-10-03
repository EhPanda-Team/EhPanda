---
phase: 17-localized-screenshot-capture-harness
plan: "01"
task: 2
status: upstream-research-complete-size-probe-supersedes-root-cause-uncertainty
recorded: 2026-10-03
---

# Upstream snapshot rendering research

Subsequent owner-supplied standalone probe evidence is reviewed in
`17-01-RENDER-SIZE-GATE.md`. Its native-scale size bisect explains the transparent long
capture on the tested Simulators and disproves the proposed 1x remedy. The historical
search findings below remain accurate; their root-cause uncertainty and pending-1x
direction are superseded by that size gate. Capture architecture is still unapproved.

The owner requested official SnapshotTesting issues/discussions research after reviewing
the A/B/diff images. This is read-only upstream research and offline PNG inspection;
no additional native XCTest run, scale revision or capture acceptance occurred.
Task 2 remains incomplete and recovery cycle 2 remains exhausted at three runs.

## Corrected local evidence

The latest direct SwiftUI native-hierarchy result's original full PNG is 1260 x 8394.
All 10,576,440 pixels have alpha zero; minimum and maximum alpha are both zero.
Its 1260 x 2736 viewport crop likewise has 3,447,360 transparent pixels and no visible
pixels. The earlier RGB-only inspection's `allBlack:true` means RGB channels are zero;
it did not examine opacity. The correct diagnosis for this saved result is fully
transparent output, not an opaque black screenshot. A black image preview was misleading.

Inspection source: `/tmp/ehpanda-phase17-preview-transparency.swift`.
Report: `/tmp/ehpanda-phase17-recovery2-swiftui-native-alpha.json`.
Checkerboard previews are derived display aids, not capture evidence or reference images:
`/tmp/ehpanda-phase17-b-transparency-preview.png` and
`/tmp/ehpanda-phase17-full-transparency-preview.png`.
The separately computed RGBA max-channel diff is all white because every pixel differs
in alpha; it is an offline display artifact, not an exported library difference attachment.
Original PNGs and failed xcresult remain unchanged.

The actual run log reports `Render server returned error for view` on the UIHostingView.
The normal viewport rendered. The native hierarchy full capture did not. Strict parity
failed before OCR/census/tail/restoration acceptance.

## Closely related upstream reports

| Primary source | Report and response | Relationship to this failure |
|---|---|---|
| [Discussion #1031](https://github.com/pointfreeco/swift-snapshot-testing/discussions/1031), opened 2025-10-01; converted from issue #1029 | SwiftUI glass button yields a correctly sized, fully transparent PNG on iOS 26 / library 1.18.7. Maintainer Stephen Celis requires an application test host and explicit `drawHierarchyInKeyWindow: true`; a participant confirms success. Brandon Williams attributes that original situation to Apple's rendering tools. | Same transparent-output symptom and relevant glass rendering. Our failing native run already has an app host, scene-backed key window and the explicit flag, so the posted remedy alone does not explain or fix this case. |
| [Discussion #1039](https://github.com/pointfreeco/swift-snapshot-testing/discussions/1039), opened 2025-12-24; converted from issue #1038 | A NavigationStack toolbar `.borderedProminent` button makes the whole PNG transparent, while the live app and preview render. Ordinary device size is 1170 x 2532; no replies at lookup. | Shows this symptom is not intrinsically a long-image symptom. It implicates toolbar/effect rendering as a diagnostic lead, not a proven cause of our differently styled button. |
| [Issue #1019](https://github.com/pointfreeco/swift-snapshot-testing/issues/1019), opened 2025-09-10; open at lookup | UIKit UIGlassEffect tint produces dark or incorrect recording. Comments recommend app-hosted hierarchy rendering and discuss the distinction between frame-only and scene-backed windows. | Supports investigating rendering context. The proposed tint-removal workaround changes the appearance under test and is not adopted. Our host already uses UIWindow(windowScene:). |
| [Issue #1125](https://github.com/pointfreeco/swift-snapshot-testing/issues/1125), opened 2026-09-29; open at lookup | On iOS 27 build 24A434 with library 1.19.5/1.19.6, a scene-less render window produces NavigationStack offsets; sizeThatFits safe-area mismatch clips content. Reported scene attachment fixes the offset. | Same runtime/library, but reports displacement/clipping, not transparent full output. Our native strategy uses a scene-backed key window; the default layer strategy creates a separate window. Do not apply safe-area removal to native layout without an approved design change. |
| [Issue #264](https://github.com/pointfreeco/swift-snapshot-testing/issues/264#issuecomment-547158482), opened 2019-10-28; closed | Reporter captures all scroll content using custom ViewImageConfig size; [maintainer reply](https://github.com/pointfreeco/swift-snapshot-testing/issues/264#issuecomment-547217792) confirms this is their usual approach. | Confirms the owner's point that custom dimensions are supported. It does not prove every modern native glass hierarchy can render at every size. |

The GitHub REST API supplied current issue bodies/comments where the unauthenticated
HTML view omitted comments or web retrieval failed. GitHub GraphQL supplied discussion
search results. All claims above come from the official repository; participant reports
are identified as such and do not establish our root cause.

## Other diagnostic finding

[PR #1109](https://github.com/pointfreeco/swift-snapshot-testing/pull/1109), open/unmerged
at lookup, addresses image-difference crashes from nonuniform pixel formats by normalizing
to 8-bit RGBA. It fixes reported issue #1097. This resembles the difference-reader concern
already addressed in our diagnostic comparison inputs, but does not explain transparent
capture output and does not establish the cause of our secondary InvalidTransition.
No dependency update or upstream source modification is made from this research.

## Search limits and next diagnostic direction

Official issue/PR search for the exact phrase `Render server` returned zero matches;
discussion search for that exact phrase also returned zero. A broader `render` discussion
query returned 23 entries, including the two transparent-output reports above. Searches
covered transparent, blank, height, large, drawHierarchyInKeyWindow/size and 8192.
The 8192 query returned zero issue/PR matches. These are search results, not proof that
no report or platform limit exists. No exact upstream report or released remedy for our
native 3x Comments long capture was established.

Inference: toolbar/glass rendering context and the change from native viewport to full
height deserve direct isolation before attributing the failure to resolution. A useful
future bounded probe would compare the same root, native scale and hierarchy API at
viewport versus full height, record drawHierarchy's success Boolean, and inspect the
actual key window's scene, root controller, safe areas and traits at rendering time.
Neither removing glass nor loosening pixel precision would demonstrate the required
actual-screen capture.

The unapproved 1x proposal remains a hypothesis and is not implemented. New native runs
still need owner direction because the authorized retry cycle is exhausted. Research
does not approve a new cycle, baseline, matrix expansion or plan completion.
