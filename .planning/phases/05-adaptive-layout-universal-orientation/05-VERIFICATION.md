---
phase: 05-adaptive-layout-universal-orientation
verified: 2026-07-13T06:49:58Z
status: human_needed
score: 4/7 must-haves verified
behavior_unverified: 3
overrides_applied: 0
behavior_unverified_items:
  - truth: "Every app surface rotates under OS control without forced-portrait snap-back, and the reader preserves its page across portrait/landscape and single-/dual-page transitions."
    test: "Rotate representative app surfaces and the reader through portrait and landscape, including single-page, dual-page, RTL, and a resumed landscape dual-page session."
    expected: "Every surface follows the device with no snap-back; dual-page eligibility follows the reader container; the logical reading page and resumed page remain correct."
    why_human: "The lock is absent and the size flow is wired, but OS rotation, presentation behavior, and live scroll-position preservation are not exercised by a behavioral UI test."
  - truth: "The SpatialTapGesture and MagnifyGesture migration preserves live tap-to-turn, double-tap zoom, pinch, pan, and paging coexistence."
    test: "Exercise single taps in all zones, double-tap zoom, pinch zoom, pan, horizontal paging, RTL page turns, and the scale==1 tap gate on a running reader."
    expected: "Gestures retain their prior zones, direction, anchor, clamps, and mutual gating without recognizer conflicts."
    why_human: "Unit tests prove the extracted arithmetic, but they do not drive SwiftUI's composed gesture recognizers or the paging ScrollView."
  - truth: "Live Text paths and interactive overlays remain pixel-aligned with recognized glyphs after the GeometryReader replacement."
    test: "Enable Live Text on a page with recognized text in portrait and landscape, in single- and dual-page modes."
    expected: "Every highlight, selection surface, and focus outline stays aligned with its source glyphs."
    why_human: "The shared-size data flow is statically verifiable, but no deterministic image or snapshot fixture exercises rendered OCR alignment."
human_verification:
  - test: "Universal rotation and reader state"
    expected: "Home, detail, grid, settings, and reader surfaces rotate without snap-back; reader page, dual-page mapping, RTL order, and resume position stay correct."
    why_human: "This depends on UIKit orientation governance and live SwiftUI scroll state."
  - test: "Reader gesture and assistive-technology coexistence"
    expected: "Tap-to-turn, double-tap, pinch, pan, paging, VoiceOver, and Switch Control remain operable without conflicts; tap-to-turn remains disabled while zoomed."
    why_human: "Pure gesture math tests cannot exercise recognizer arbitration or assistive-technology interaction."
  - test: "Live Text alignment"
    expected: "OCR boxes and interactive overlays align with glyphs in portrait/landscape and single-/dual-page layouts."
    why_human: "No stable OCR rendering fixture exists for an automated pixel assertion."
  - test: "Representative adaptive-layout visual pass"
    expected: "Compact/regular widths, split view, maximum Dynamic Type, dark appearance, Increase Contrast, the home carousel, category/grid layouts, previews, archives, and settings remain readable, centered, and unclipped."
    why_human: "The implementation proves container-relative inputs, but visual parity across the supported environment matrix is appearance-sensitive."
---

# Phase 5: Adaptive Layout & Universal Orientation Verification Report

**Phase Goal:** Let size classes and the OS govern layout and orientation, retiring screen-metric math, the custom touch handler, and the custom orientation lock while preserving reading and rotation behavior.
**Verified:** 2026-07-13T06:49:58Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Device identity is a single injected `DeviceType` fact, and phone/pad navigation semantics remain intact. | ✓ VERIFIED | `DeviceClient` exposes only `deviceType`; `DeviceType.current` appears only in `DeviceClient.live`; all gallery hosts pass the injected closure into `GalleryNavigation`; the targeted iPad modal-routing test passed. |
| 2 | The app has no custom orientation lock and every surface rotates under OS control without reader-state drift. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `AppDelegate` has no `supportedInterfaceOrientationsFor` override; `AppOrientationMask`, `AppDelegateClient`, `setOrientationPortrait`, and `Setting.enablesLandscape` are absent; both iPhone and iPad plist arrays declare all four orientations. Actual rotation and scroll-state preservation require runtime UAT. |
| 3 | Layout no longer depends on process-global screen/window metrics, device-derived sizing defaults, or `GeometryReader`. | ✓ VERIFIED | Repository-wide source scans find no `DeviceUtil`, metric breakpoints, `GeometryReader`, or device-derived `Defaults.FrameSize`/`ImageSize` values. Converted sites use size class, `containerRelativeFrame`, or `onGeometryChange`; `DeviceUtil.swift` is deleted. |
| 4 | The Home carousel derives both card width and centered peek inset from one local container width. | ✓ VERIFIED | `HomeView+Sections.swift` captures `carouselWidth` once, computes `cardWidth` and `centeringMargin` from it, and uses those values for frame, snapping geometry, and scroll-content margins. |
| 5 | Live Text uses one captured nonzero size for OCR paths and interactive overlay geometry with pixel-identical rendering. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `LiveTextView` captures `CGSize` with `onGeometryChange`, guards `.zero`, and feeds that size into normalized paths, frames, and positions. Pixel alignment is not exercised by an automated rendering fixture. |
| 6 | One reader container size drives gesture arithmetic, landscape/dual-page decisions, page mapping, placeholder width, and control-panel layout. | ✓ VERIFIED | `ReadingView` has one `onGeometryChange` writer to `gestureHandler.containerSize`; all downstream calculations consume that value. Targeted `GestureHandlerTests`, `PageHandlerTests`, and `ContainerDataSourceTests` passed. |
| 7 | Native spatial-tap and magnify sources preserve live zoom/pan/tap/paging behavior. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `ReadingView+Gestures.swift` uses `SpatialTapGesture.location` and `MagnifyGesture.startAnchor`; `TouchHandler` and root wiring are gone; arithmetic tests pass. SwiftUI gesture composition itself has no UI-level behavioral test. |

**Score:** 4/7 truths verified (3 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `AppPackage/Sources/AppTools/DeviceType.swift` | Platform idiom enum with the approved lint reason | ✓ VERIFIED | Substantive enum covers supported idioms and is wired only through the client live value. |
| `AppPackage/Sources/DeviceClient/DeviceClient.swift` | Single injected `deviceType()` fact | ✓ VERIFIED | Live, preview, test, and dependency-key values are implemented; consumers import the module directly. |
| `AppPackage/Sources/AppModels/Persistent/Setting.swift` | In-place schema without `enablesLandscape` | ✓ VERIFIED | The field and initializer parameter are absent; the remaining reader preferences are intact. |
| `AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift` | Deterministic clamp, anchor, and tap-zone locks | ✓ VERIFIED | Covers phone/iPad portrait and landscape sizes, multiple scales, LTR/RTL zones, and vertical panel behavior; targeted execution passed. |
| `AppPackage/Sources/ApplicationClient/ApplicationClient.swift` | Private window lookup after `DeviceUtil` deletion | ✓ VERIFIED | The lookup is private and is consumed by `setUserInterfaceStyle`; it is not used for layout. A non-blocking multi-scene robustness warning remains below. |
| Removed globals/modules | No `DeviceUtil`, `TouchHandler`, `AppOrientationMask`, or `AppDelegateClient` artifact or package edge | ✓ VERIFIED | Source/file/package scans find no live artifact, import, target, or dependency edge. References left in tests are explanatory comments only. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `DeviceType.current` | Application consumers | `DeviceClient.live` and `@Dependency(\.deviceClient)` | WIRED | The platform global is isolated to one live closure; view and reducer consumers read the injected fact. |
| Gallery list reducers | App-level modal or inline navigation | `GalleryNavigation.routeGalleryDetail(deviceType:)` and delegates | WIRED | Home, Search, Favorites, and Downloads provide the injected device closure; AppReducer handles modal delegates. |
| App orientation declaration | UIKit rotation | Four-orientation plist arrays with no delegate override | WIRED | Both phone and iPad declarations include portrait, upside-down, landscape-left, and landscape-right. Runtime behavior remains human-only. |
| Reader container | Gesture/page/control calculations | One `onGeometryChange` assignment to `gestureHandler.containerSize` | WIRED | The same observed size controls landscape derivation, gesture thresholds/clamps, page data source, placeholders, and `ControlPanel`. |
| Native gestures | `GestureHandler` | Spatial tap location and magnify start anchor | WIRED | Tap-to-turn is attached at scale 1; drag plus tap is high priority only while zoomed; paging is disabled while scale differs from 1. |
| Live Text container | Canvas and interactive overlays | Captured nonzero `CGSize` | WIRED | OCR paths, highlight frames, and highlight positions use the same observed size. |
| Home carousel container | Card and scroll geometry | `carouselWidth` | WIRED | Card width, pitch, centering margin, and nearest-center math share one local width source. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `ReadingView` | `gestureHandler.containerSize` | SwiftUI container geometry observation | Feeds aspect ratio, dual-page source/config, gestures, placeholder fractions, and panel preview sizing | ✓ VERIFIED |
| `LiveTextView` | `size` | SwiftUI geometry observation | Multiplies normalized OCR bounds into Canvas paths and interactive overlay frames/positions | ✓ VERIFIED |
| Home carousel | `carouselWidth` | Horizontal scroll container geometry | Produces focused card width, centered margins, and snap-index calculations | ✓ VERIFIED |
| Gallery routing | `deviceType()` | Injected live/test closure | Selects modal presentation for pad and inline push otherwise | ✓ VERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Reader gesture math, page mapping, and container data-source behavior | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' test -only-testing:ReadingFeatureTests/GestureHandlerTests -only-testing:ReadingFeatureTests/PageHandlerTests -only-testing:ReadingFeatureTests/ContainerDataSourceTests -quiet` | Exit 0 in 8.8 seconds | ✓ PASS |
| Injected iPad navigation routing | `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' test -only-testing:DownloadsFeatureTests/DownloadsReducerActionTests/testDownloadsReducerDelegatesModalDetailOnPad -quiet` | Exit 0 in 7.5 seconds | ✓ PASS |

The test invocations were run sequentially against the iOS 26.5 `iPhone Air` simulator destination.

### Probe Execution

No phase plan declared a standalone executable probe. The smallest reliable named behavioral tests were run instead.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| UIARCH-01 | Phase 05 plans 01, 03–10 | Adaptive layout and native reader input | ⚠️ HUMAN NEEDED | Structural removal, wiring, and pure behavior tests pass; live gesture composition, visual parity, and OCR rendering remain manual. |
| UIARCH-03 | Phase 05 plans 02, 09–10 | Universal OS-governed orientation | ⚠️ HUMAN NEEDED | Lock artifacts and flows are absent and plist support is complete; actual rotation/no-snap-back behavior needs device or simulator UAT. |

No Phase 05 requirement is orphaned: ROADMAP and REQUIREMENTS both map exactly UIARCH-01 and UIARCH-03 to this phase.

### Anti-Patterns Found

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, or placeholder implementation marker was found in the Phase 05 production/package scope. `git diff --check` passed, and no removed package/module reference remains.

### Advisory Review Findings

The two warnings in `05-REVIEW.md` do not block the Phase 05 goal:

1. `ApplicationClient` still chooses an arbitrary connected scene when applying an application-wide appearance update. The rehome is substantive and preserves the former behavior, and the lookup is not used for layout or orientation; multi-scene appearance robustness remains follow-up debt.
2. The archive download control still lacks native button and disabled accessibility semantics. `deferred-items.md` establishes that this predates the Phase 05 size-class edit, so it is unrelated accessibility debt rather than a regression in the adaptive-layout goal.

### Human Verification Required

1. **Universal rotation and reader state:** Rotate home, detail, grid, settings, and reader surfaces. In the reader, cover single-page, dual-page, RTL, and landscape resume. Expect no forced-portrait snap-back and no logical-page drift.
2. **Gesture and accessibility coexistence:** Exercise tap zones, double-tap, pinch, pan, paging, VoiceOver, and Switch Control. Expect preserved direction, anchors, clamps, gating, and assistive operation.
3. **Live Text alignment:** Inspect recognized text in portrait/landscape and single-/dual-page modes. Expect paths and interactive overlays to remain aligned with glyphs.
4. **Adaptive-layout visual matrix:** Check representative converted layouts in compact/regular widths and split view, including maximum Dynamic Type, dark appearance, Increase Contrast, home carousel centering, and the expected landscape-phone grid density. Expect readable, unclipped, centered layouts.

### Gaps Summary

No implementation gap or blocking requirement failure was found. The code and targeted tests establish the new architecture and its pure behavior, but three runtime truths cannot be promoted to verified without the documented UI/device checks. The phase therefore remains `human_needed`.

---

_Verified: 2026-07-13T06:49:58Z_
_Verifier: the agent (gsd-verifier methodology via generic-agent fallback)_
