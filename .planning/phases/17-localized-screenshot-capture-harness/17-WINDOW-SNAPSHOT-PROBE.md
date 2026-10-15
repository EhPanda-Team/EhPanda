# Phase 17: Reduced-width snapshot feasibility

Date: 2026-09-23
Status: Feasible for configured view-container sizes; inclusion in the phase matrix awaits the owner.

## Question and result

The owner requested research before choosing whether iPad reduced-window layouts belong in the snapshot matrix.

An isolated runtime probe confirmed that swift-snapshot-testing can render a SwiftUI view at reduced container sizes on iPadOS 27. The rendered content receives the requested width and horizontal size class. Exported images show real layout changes: a horizontal cover/title arrangement at regular width becomes a vertical arrangement at compact width, and text wraps to the smaller width.

This establishes configured view-layout snapshot feasibility. It does not establish actual iPadOS window-resizing automation, system window chrome capture, live resizing behavior, or correctness of every EhPanda screen.

## Method

- Unmodified `SnapshotTesting` target sources from upstream swift-snapshot-testing **1.19.4**, commit `59a99c458de4d2dee580529b61b4f78dca7b7fa6`.
- Isolated temporary Swift package and XCTest target under `/tmp/ehpanda-phase17-window-probe/`; no app/package dependency or production source changes.
- Built and tested with Xcode 27 on the **iPad Pro 11-inch (M5)** simulator, iPadOS **27.0**, OS build **24A434**.
- The probe used `Snapshotting<AdaptiveProbe, UIImage>.image(layout: .device(config: ...), traits: ...)` with the default view-rendering path (`drawHierarchyInKeyWindow: false`).
- The SwiftUI probe contained `NavigationStack`, `ScrollView`, title text and an adaptive cover/title layout. `onGeometryChange` independently recorded the actual content width and SwiftUI horizontal size class.
- Assertions checked iPad device idiom, output image size, actual layout width and horizontal size class. Three PNGs were retained as XCTest attachments and visually inspected.

## Measured cases

| Configuration | Container / image size in points | PNG pixels | SwiftUI horizontal size class | Observed layout |
| --- | --- | --- | --- | --- |
| Library full-width preset | 1194 x 834 | 2388 x 1668 | regular | Cover and title beside each other |
| Library one-third preset | 375 x 834 | 750 x 1668 | compact | Cover above title; text rewrapped |
| Custom size and traits | 500 x 700 | 1000 x 1400 | compact | Cover above title; different text wrapping |

The library's `iPadPro11` presets describe an older device geometry. These numbers are experimental containers, **not** approved production dimensions for the selected M5 device. Planning must derive current device/window geometry and matching traits rather than infer them from the preset name. The custom case confirms that an exact built-in device preset is unnecessary.

## Evidence

- Test source: `/tmp/ehpanda-phase17-window-probe/Tests/WindowProbeTests/WindowSizeTests.swift`.
- Build/test log: `/tmp/ehpanda-phase17-window-probe/run1.log`.
- Finalized result: `/tmp/ehpanda-phase17-window-probe/run1.xcresult`.
- Exported image mapping: `/tmp/ehpanda-phase17-window-probe/attachments/manifest.json`.
- Result: Xcode exit **0**, **1 test passed**, **0 failures**, **0 skips**, three measured image cases, no failure-retry option enabled. Result summary reported no runtime warnings.
- An initial command was rejected before test execution because `-test-iterations 1` is invalid; its created result directory then required a fresh result path. These are setup errors, not test executions or passing evidence.
- Upstream library code emitted SDK deprecation warnings during compilation. No warnings were suppressed and no dependency source was patched. This is a feasibility result, not a claim that integrating this library has already met the repository's clean-build bar.
- All images remain outside the repository.

## Supported planning choice and boundaries

It is technically valid to offer **full-size plus explicitly configured narrower view-layout snapshots**. Width, height, safe area, device idiom, size classes and display scale must be supplied coherently. A smaller output image alone is insufficient; test assertions should establish that content was laid out at that size.

The probe does not verify `.fixed(width:height:)` separately, the key-window rendering mode, visual-effect fidelity, native menu/alert/sheet capture, actual scene-resize interactions or long-run reproducibility. Those claims require relevant integration evidence. Keep marketing screenshot capture separate, as already decided.

## Follow-up: identifying an actual reduced iPad window

The owner correctly distinguished configured snapshot dimensions from a real resized iPadOS scene. This probe controls view-container size and injected traits; it does not activate or identify a particular iPadOS window-management mode.

Inspection of the installed Xcode 27 iOS Simulator SDK's public UIKit headers and SwiftUI/SwiftUICore interfaces found no general iPadOS boolean for "this is a reduced/windowed iPad view."

- `UIWindowScene.isFullScreen` exists, but its public header explicitly says it is supported only on Mac Catalyst. It is not a supported iPadOS mode detector.
- `UIWindowScene.effectiveGeometry.coordinateSpace.bounds.size` provides actual scene dimensions, and `windowScene(_:didUpdateEffectiveGeometry:)` reports geometry changes.
- `effectiveGeometry.isInteractivelyResizing` reports an ongoing resize interaction. It does not mean that an already-resized, stationary window is small.
- `horizontalSizeClass` and `verticalSizeClass` classify the available layout environment, not the window-management mode. A reduced iPad window can still have regular width; a compact child presentation does not establish that its entire scene is reduced.
- For SwiftUI layout, choose broad arrangements with size classes and use actual container geometry or adaptive layout for finer fitting. Neither "all narrow iPad windows are compact" nor "regular means full screen" is a valid assumption.

Configured snapshot dimensions and traits do not independently verify code that reads real scene geometry or reacts to real scene resize events. Name any selected snapshot cases by their **container dimensions and traits**, and reserve actual-window claims for scene-level runtime evidence.

## Primary sources

- [SwiftUI snapshot layout and hosting implementation](https://github.com/pointfreeco/swift-snapshot-testing/blob/59a99c458de4d2dee580529b61b4f78dca7b7fa6/Sources/SnapshotTesting/Snapshotting/SwiftUIView.swift).
- [ViewImageConfig, iPad split presets, window sizing and trait injection](https://github.com/pointfreeco/swift-snapshot-testing/blob/59a99c458de4d2dee580529b61b4f78dca7b7fa6/Sources/SnapshotTesting/Common/View.swift).
- [Upstream iPad split snapshot tests](https://github.com/pointfreeco/swift-snapshot-testing/blob/main/Tests/SnapshotTestingTests/SnapshotTestingTests.swift).
- [Apple: UIWindowScene.isFullScreen](https://developer.apple.com/documentation/uikit/uiwindowscene/isfullscreen); platform support also checked in the installed SDK's `UIWindowScene.h`.
- [Apple: Make your UIKit app more flexible, scene geometry and resizing example](https://developer.apple.com/videos/play/wwdc2025/282/).
- [Apple: Building a desktop-class iPad app](https://developer.apple.com/documentation/uikit/building-a-desktop-class-ipad-app).
