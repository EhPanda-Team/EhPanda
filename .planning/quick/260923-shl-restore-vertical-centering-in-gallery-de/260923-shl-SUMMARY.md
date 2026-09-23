---
quick_id: 260923-shl
status: complete
date: 2026-09-23
description: Restore vertical centering in gallery detail cells while preserving Dynamic Type layouts
---

# Gallery cell vertical centering restored

Code commit: `9bfbc483` — `fix(quick-260923-shl): restore gallery cell vertical centering`.

## Result and rationale

The detailed gallery row now uses `HStack(spacing: 10)` for its side-by-side arrangement,
restoring SwiftUI's default vertical center alignment. This is the only production diff.
Short text centers against the cover; when text is taller, the cover centers against the text.
Neither member receives a new height constraint.

Historical revision `1f6408b3`, immediately before the Dynamic Type commit `59fb2eb9`, used
this centered arrangement. Its title was followed directly by the uploader/language row.
The committed cell history, including its earlier names back to 2021, contained no vertical
spacer between them. Historical simulator captures confirmed the centered default-size layout
and the old horizontal clipping at AX3 and AX5.

The owner chose to restore centering after reviewing those captures. The earlier uncommitted
spacer/minimum-height attempt was removed completely. Current shared cover sizing, the 10-point
horizontal gap, adaptive metadata pairs, line-limit rules, and narrow accessibility stacking
remain intact; the historical accessibility clipping is not reintroduced.

## Verification

Xcode 27.0; iOS/iPadOS 27.0 simulators. A temporary app entry point rendered the actual
`GalleryDetailCell` in a button inside a list, using the same sample gallery and neutral local
gradient artwork for each comparison.

| Check | Result |
| --- | --- |
| Capture build, arm64 and x86_64 | Passed; zero warnings and errors |
| Normal app build after restoring the app entry point, arm64 and x86_64 | Passed; zero warnings and errors |
| Changed-file strict uncached SwiftLint | Passed; zero violations |
| `git diff --check` | Passed |
| iPhone and iPad: Large cold entry, then live AX1, AX3, AX5 changes | Passed visual inspection; centered horizontal rows and readable stacked rows |
| iPhone and iPad: AX5 cold entry | Same row geometry as the live AX5 result |
| iPhone and iPad: long title, tag, and active download badge at Large and AX5 | Natural row growth; existing Large title limit preserved; AX5 content wraps |
| iPhone: scroll to the bottom of the long AX5 row | Category, date, and download progress remain reachable and readable |

Build logs: `/tmp/ehpanda-gallery-centered/capture-build.log` and
`/tmp/ehpanda-gallery-centered/final-build.log`.

Local screenshots and accessibility outlines are retained under
`$HOME/.codex/visualizations/2026/09/23/01a0cd47-faa4-72d1-a902-b7c300d9d089/gallery-centered/`.
The main comparisons are `iphone-{large,ax3,ax5}.png` and `ipad-{large,ax3,ax5}.png`;
additional captures cover AX1, cold AX5, and long-content cases. The corresponding historical
captures are in the sibling `gallery-before-dynamic-type/` directory.

## Scope and cleanup

- This is simulator visual verification, not an exhaustive screen, orientation, multitasking,
  VoiceOver, or physical-device sweep. The full feature and UI test plans were not rerun for
  this one-line alignment change.
- The temporary app entry point was restored byte-for-byte. The normal app was rebuilt and
  reinstalled on both dedicated simulators; Large text, light appearance, and their original
  shutdown state were restored.
- GSD documentation was recorded retrospectively at the owner's request, inline without
  subagents. No roadmap change, push, lint suppression, or unrelated source change is included.
