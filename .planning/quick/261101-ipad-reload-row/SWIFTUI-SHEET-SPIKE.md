# Pure SwiftUI opposite-side sheets: probe results — 2026-11-01

## Question

`HomePaneSheet` exists because a nested SwiftUI sheet experiment on iOS 27.1 placed Duo's nested
Detail on the wrong half (`8c332e2a2`, [Duo Home evidence](../261015-duo-session-record/evidence/home.md)).
After `350773d46` the owner asked to evaluate whether SwiftUI's own presentation can now replace it.
This is a probe-stage evaluation; EhPanda's source is unchanged by it.

## Method

A single-file SwiftUI app (`.capture/home-toolbar-review/swiftui-sheet/SheetProbe.swift`, local)
mirrors split Home: two `NavigationStack` panes in a `TabView`, a list sheet opened on the side
opposite its pane with `.presentationPlacement(.leading/.trailing)`, a nested gallery sheet opened
opposite again, and a `fullScreenCover` on the gallery like Detail's reader. It prints the presented
controller chain (frame, UIKit `preferredPlacement`, presenter). Simulator: iPhone Duo, iOS 27.2
(24B91016s), posed with `agent-device fold`; the window is 951 × 669 when open.

## Results

| Case | SwiftUI | `HomePaneSheet` (measured in EhPanda) |
|---|---|---|
| Half-open, list sheet | right x=483 w=459 / left x=8 w=459 | x=483.5 w=459.3 / x=8 w=459.3 |
| Half-open, nested gallery | opposite half, x=8 or x=483, w=459 | same |
| Nested gallery with reader cover presented and dismissed | stays on its half | not re-measured |
| Close → half-open with sheets up | retained, back to x=483 / x=8 | retained, same frames |
| Fully open, no sizing | **w=653**, crosses the fold (x=290 / x=8) | x=475.5 w=467.3, inside the half |
| Fully open, custom `PresentationSizing` width W | honoured for any W, 8 pt outer margin | — |
| Placement changed to `.automatic` while presented | **outer sheet keeps trailing; nested reports center but does not move** | applied on every update |
| iPad, `.sheet` beside Home's stack, idle or presented | Reload stays in the tab row (y=36) | breaks it unless inside the stack |

The 27.1 wrong-half composition no longer reproduces in the probe, including the reader cover, but
the probe does not contain EhPanda's real Detail view.

## Gaps for a pure SwiftUI replacement

1. **Fully open width.** Staying inside the half needs `window / 2 - outer margin`. The system's
   outer margin is not exposed: `PresentationSizingContext` has no members on the 27.2 SDK, so the
   width would need a hard-coded 8 pt or a measure-and-feed-back loop from inside the sheet.
2. **Live placement.** Duo's recorded behaviour is that existing sheets return to automatic
   placement outside the split posture. SwiftUI does not re-apply `presentationPlacement` to an
   already-presented sheet; meeting it would require dismissing and re-presenting.

## Owner decision — 2026-11-01

Keep `HomePaneSheet` as it is. No in-app SwiftUI prototype is made and neither gap is worked around.
Revisit only when the SDK exposes the sheet's outer margin to sizing and re-applies placement to a
presented sheet.

## Not covered

EhPanda's real Detail composition; Duo rotation (the inner display ignores the XCTest/agent-device
orientation setter, consistent with `DuoPose`); RTL; Dynamic Type; Stage Manager.
