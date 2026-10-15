> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/duo-panel`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Fully open half-width slider investigation

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

The Xcode 27.1 SDK declares `ArrangementView`, `SplitArrangementViewStyle`,
`OverlayArrangementViewStyle`, and `splitArrangementLayoutRatio` as available from 27.1,
not 27.0. The app's deployment target remains 27.0.

A standalone SwiftUI probe was compiled against the installed simulator SDK and launched
on the dedicated Duo simulator. No production fully-open reader behavior was changed.

## Results

- At hinge 180 degrees, a `.split.axes(.horizontal)` arrangement with a transparent primary
  region and a secondary slider constrained to 0.5 reported 401 pt (rounded down) of an 803 pt container
  to the slider region. See `arrangement-split-open.png`.
- The arrangement was layered over the reading canvas. Only the controls were arranged;
  the canvas retained its full extent. Putting the canvas itself in the arrangement would
  instead make it participate in the split.
- At the same fully-open pose, `.overlay.axes(.horizontal)` allocated all 803 pt to the
  controls. See `arrangement-overlay-open.png`. It does not force a persistent half-width
  layout when no active fold divides the view.
- The half-width ratio is relative to the arrangement's available bounds. Asymmetric safe
  areas can place its midpoint away from the physical hinge. Exact hinge alignment requires
  querying the division reserved region, including inactive regions while flat, or otherwise
  accounting for physical safe-area offsets.
- A half-folded overlay probe screenshot was black and is not accepted as verification.
  Its folded behavior is documented below but was not established by that capture.

## Suitable implementation

For a persistent half-width slider while fully open, place an arrangement in the controls
layer, use `.split.axes(.horizontal)`, and set the secondary's horizontal minimum, ideal,
and maximum ratios to 0.5. The empty primary must be a transparent layout-participating
view rather than `EmptyView`. Preserve the reader's full-sized page container separately.
Scope any such layout to the owner's chosen Duo posture; the system arrangement also works
on other devices and does not itself impose the app's Duo-only requirement.

This is a verified feasibility prototype, not an adopted product behavior.

## Official references

- [Adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/):
  arrangements, reserved regions and the difference between split and overlay behavior.
- [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview)
- [Split layout ratio](https://developer.apple.com/documentation/swiftui/view/splitarrangementlayoutratio(minhorizontal:idealhorizontal:maxhorizontal:minvertical:idealvertical:maxvertical:))

Source: `ArrangementProbe.swift`; captures and the disposable app are in this directory.
