---
phase: 05-adaptive-layout-universal-orientation
verified: 2026-07-13T10:26:48Z
status: human_needed
score: 7/13 must-haves verified
behavior_unverified: 3
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 4/7
  gaps_closed:
    - "G-05-1 implementation gaps 1-6 are closed in source; runtime retesting remains."
    - "G-05-4 implementation gaps 7-9 are closed in source; runtime retesting remains."
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "Comprehensive maximum Dynamic Type support"
    addressed_in: "Phase 10"
    evidence: "Phase 10 success criterion 5 owns the maximum Dynamic Type verification and remediation matrix."
behavior_unverified_items:
  - truth: "The six G-05-1 layout and sheet fixes behave correctly in the running app, including Favorites date-seek activation after metadata arrives."
    test: "Repeat the About, reader placeholder, Home carousel, range-field, cancellation, and Favorites checks listed below."
    expected: "All corrected controls remain visible, sized, labeled, dismissible, and actionable across the stated device and orientation matrix."
    why_human: "Source wiring is present, but the affected rendering, sheet dismissal, and metadata-driven menu interaction are not covered by executable UI tests."
  - truth: "Every in-app gallery host pushes on phone and presents on pad, with no host-specific bypass."
    test: "Open gallery details from every Home, Search, Favorites, and Downloads entry point on phone and pad, including nested lists and onward routes."
    expected: "Phone routes push into the navigation stack; pad routes use the app-level detail presentation; external deep links retain their deliberate modal behavior."
    why_human: "Reducer tests cover the shared routing semantics for Downloads, and static inspection finds no bypass, but the exhaustive live host matrix has no permanent behavioral test."
  - truth: "Universal rotation, reader logical-page preservation, and representative adaptive layouts remain correct at runtime."
    test: "Rotate representative app surfaces and the reader through portrait and landscape, including single-page, dual-page, RTL, resumed reading, split view, and freeform windows."
    expected: "The OS controls rotation without snap-back; reader state is preserved; adaptive content remains readable, centered, and unobstructed."
    why_human: "UIKit rotation, SwiftUI presentation, scroll state, window controls, and appearance-sensitive layout require live device or simulator observation."
human_verification:
  - test: "Universal rotation and reader logical state"
    expected: "Home, detail, grid, settings, and reader surfaces rotate without snap-back; single/dual-page mapping, RTL order, the current logical page, and a resumed landscape page remain correct."
    why_human: "This depends on UIKit orientation governance and live SwiftUI scroll state."
  - test: "About metadata in landscape"
    expected: "Version, build, copyright, and related metadata remain visible at the leading edge of the About form."
    why_human: "The section placement is statically correct, but landscape rendering is appearance-sensitive."
  - test: "Reader placeholders"
    expected: "Portrait/landscape and single/dual-page placeholders occupy the same usable footprint as loaded pages instead of collapsing to narrow slivers."
    why_human: "Container-relative sizing is present, but its rendered footprint needs visual confirmation."
  - test: "Home carousel sizing"
    expected: "Phone and pad, portrait and landscape show the intended card width, pitch, centered focus, and neighboring-card peek."
    why_human: "The geometry has one local source of truth, but rendered scroll-target alignment needs visual confirmation."
  - test: "Range fields and reusable sheet cancellation"
    expected: "Filters range fields show no redundant visible title while retaining a useful VoiceOver label; Filters, Quick Search, and Date Seek expose an untitled Cancel control that dismisses each sheet."
    why_human: "Accessibility exposure and presentation dismissal require live interaction."
  - test: "Favorites category, feature menu, and date seek"
    expected: "Category selection is directly reachable; sorting, date seek, and quick search are available from the features menu; date seek is disabled before metadata arrives and opens after it arrives."
    why_human: "Metadata arrival and menu enablement are live state transitions without a UI test."
  - test: "iPad freeform reader controls"
    expected: "Reader upper controls clear the window traffic-light region in freeform windows, while full-screen pad and phone spacing remains unchanged."
    why_human: "Window-control insets are provided only by the live windowing environment."
  - test: "Home card contrast"
    expected: "Home cards remain visible in normal and freeform windows in light mode, dark mode, and Increase Contrast."
    why_human: "The system background is wired, but contrast and compositing are visual properties."
  - test: "Single-window behavior"
    expected: "The app exposes no New Window or multi-scene affordance on supported devices."
    why_human: "The plist disables multiple scenes, but the system UI result is runtime behavior."
  - test: "Gallery-route host matrix"
    expected: "On phone, Home carousel/cover/top lists and nested lists, Search root/nested lists, Favorites, Downloads, Comments, and detail-search onward routes push; on pad, equivalent in-app hosts present details; external deep links remain modal on both."
    why_human: "Static inspection finds no phone bypass, but exhaustive host behavior is not permanently exercised."
  - test: "Representative adaptive-layout matrix"
    expected: "Compact/regular widths, split view, category/grid layouts, previews, archives, and settings remain readable, centered, and unclipped in portrait and landscape."
    why_human: "These are appearance-sensitive layout outcomes. Maximum Dynamic Type is separately deferred to Phase 10."
---

# Phase 5: Adaptive Layout & Universal Orientation Verification Report

**Phase Goal:** Let size classes and the OS govern layout and orientation, retiring screen-metric math, the custom touch handler, and the custom orientation lock while preserving reading and rotation behavior.
**Verified:** 2026-07-13T10:26:48Z
**Status:** human_needed
**Re-verification:** Yes — after gap-closure Plans 05-11 through 05-18

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Device identity is one injected `DeviceType` fact using standard phone/pad idiom semantics. | ✓ VERIFIED | `DeviceClient` exposes only `deviceType`; `DeviceType.current` is confined to the live closure. `DownloadsReducerActionTests` cover phone push and pad delegate outcomes. |
| 2 | Production layout no longer reads process-global screen/window metrics or uses `GeometryReader`. | ✓ VERIFIED | Source scans find no `GeometryReader`, `UIScreen`, `screen.bounds`, or layout-oriented window-bounds access. The remaining connected-scene lookup applies interface style, not layout. |
| 3 | Runtime defaults contain no device-derived layout size. | ✓ VERIFIED | `Defaults+Runtime.swift` retains only device-independent card-cell height; remaining image-size values are fixed/aspect constants rather than global device measurements. |
| 4 | One reader container size drives landscape/dual-page decisions, gestures, page mapping, placeholders, and controls through pure arithmetic. | ✓ VERIFIED | `ReadingView` has one geometry observation writing `gestureHandler.containerSize`; `GestureHandlerTests` and `PageHandlerTests` cover phone/pad portrait/landscape, anchors, clamps, LTR/RTL zones, and page mappings. The post-Plan-18 full `AppPackage` suite passed. |
| 5 | Custom orientation-lock and touch-handler infrastructure is removed, and both device families declare all orientations. | ✓ VERIFIED | `DeviceUtil`, `TouchHandler`, `AppOrientationMask`, `AppDelegateClient`, `setOrientationPortrait`, `enablesLandscape`, and orientation-delegate overrides are absent. Both phone and pad plist arrays contain portrait, upside-down, landscape-left, and landscape-right. |
| 6 | Native gesture composition preserves tap, zoom, pan, paging, and assistive-technology coexistence. | ✓ VERIFIED | `SpatialTapGesture.location` and `MagnifyGesture.startAnchor` feed the tested pure handler. Previous UAT Test 2 passed tap-to-turn, zoom, paging, VoiceOver, and Switch Control; the subsequent gap plans did not alter this gesture path. |
| 7 | Live Text paths and interactive overlays remain aligned with recognized glyphs. | ✓ VERIFIED | One nonzero captured size drives Canvas paths, overlay frames, and positions. Previous UAT Test 3 visually passed portrait/landscape and single/dual-page alignment; subsequent gap plans did not alter the Live Text path. |
| 8 | G-05-1's six reported layout and sheet defects are corrected in the running app. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | All six fixes are present in source: leading About metadata, full-container placeholders, one carousel geometry owner, accessibility-only field titles, stable cancellation actions, and reachable Favorites features/date seek. Runtime retesting remains. |
| 9 | iPad freeform reader controls clear window controls without regressing full-screen or phone spacing. | ⚠️ HUMAN NEEDED | `ControlPanel` observes `containerCornerInsets.topLeading` and conditionally pads the upper panel only for nonzero pad insets. Window-manager behavior needs live observation. |
| 10 | Home cards retain normal contrast in freeform and full-screen appearances. | ⚠️ HUMAN NEEDED | Home's root stack now uses `Color(.systemBackground)`. Light/dark/Increase Contrast compositing needs visual confirmation. |
| 11 | The app exposes a single-window experience. | ⚠️ HUMAN NEEDED | `UIApplicationSupportsMultipleScenes` is false. System-provided window affordances require runtime confirmation. |
| 12 | Every in-app gallery host pushes on phone and presents on pad, with no host-specific bypass. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The shared `GalleryNavigation` helper returns push for phone and present for pad; Home direct/nested, Search direct/nested, Favorites, and Downloads route through it. Static inspection found no phone bypass, but the reported phone sheet needs exhaustive live host confirmation. |
| 13 | All app surfaces rotate under OS control, reader logical state survives rotation/mode changes, and representative adaptive layouts remain correct. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The lock is gone, orientation declarations are complete, and reader data flow is container-relative. Rotation, scroll preservation, split view, and freeform visual behavior remain runtime-only. |

**Score:** 7/13 truths verified; 3 additional truths are present but behavior-unverified, and 3 are human visual/system checks.

## Gap-Closure Reassessment

### G-05-1 — Six Independent View Defects

| Prior gap | Gap plan | Current evidence | Result |
| --- | --- | --- | --- |
| About metadata hidden in landscape | 05-11 | Metadata is in the leading `Form` section and no longer depends on the large-subtitle placement. | SOURCE CLOSED; HUMAN RETEST |
| Reader placeholders collapse to narrow widths | 05-12 | Both placeholders use full horizontal/vertical container-relative frames, with only the horizontal axis divided for page count. | SOURCE CLOSED; HUMAN RETEST |
| Home carousel card size and centering diverge | 05-13 | `CardSlideSection` owns container width, card width, pitch, centering margin, frame, and snap geometry; the card cell no longer applies a second relative width. | SOURCE CLOSED; HUMAN RETEST |
| Range fields show redundant prompt text | 05-14 | The field title is accessibility-only; the visible prompt comes only from `promptText`. | SOURCE CLOSED; HUMAN RETEST |
| Reusable sheets have no obvious dismissal | 05-15 | Filters, Quick Search, and Date Seek each attach a cancellation toolbar action to their stable root and dismiss through the environment. | SOURCE CLOSED; HUMAN RETEST |
| Favorites category/features/date seek are inaccessible or inert | 05-16 | Category selection is direct, feature actions are grouped, and Date Seek has a labeled disabled state until metadata is available. | SOURCE CLOSED; HUMAN RETEST |

No source-level G-05-1 gap remains. Because the original failures were rendering and interaction failures, closure requires the human checks listed below.

### G-05-4 — iPad Windowing and Gallery Routing

| Prior gap | Gap plan | Current evidence | Result |
| --- | --- | --- | --- |
| Reader toolbar overlaps freeform window controls | 05-17 | Pad-only nonzero top-leading container-corner insets offset the stable upper panel. | SOURCE CLOSED; HUMAN RETEST |
| Home cards disappear against freeform window background | 05-17 | Home owns a semantic system background. | SOURCE CLOSED; HUMAN RETEST |
| Unsupported multi-window behavior is exposed | 05-17 | Multiple scenes are disabled in configuration. | SOURCE CLOSED; HUMAN RETEST |
| Phone detail appears modally instead of pushing | 05-18 | Every inspected in-app host uses the shared phone-push/pad-present helper. The Plan 18 audit found no bypass. | NO SOURCE GAP FOUND; HUMAN HOST-MATRIX CHECK |

Plan 18's temporary probe was removed as designed, so its narrated pass is not counted as independent executable verifier evidence. The permanent Downloads reducer tests confirm the shared semantics, while exhaustive host behavior remains a human gate.

## Deferred Items

| Item | Owner | Verification treatment |
| --- | --- | --- |
| Comprehensive maximum Dynamic Type behavior | Phase 10, success criterion 5 | Explicitly deferred. It is not a Phase 5 failure and is excluded from this phase's score and human acceptance matrix. |

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `AppPackage/Sources/AppTools/DeviceType.swift` | Platform idiom enum with an approved lint reason | ✓ VERIFIED | Covers supported idioms; the targeted `tv` lint exception includes the required reason. |
| `AppPackage/Sources/DeviceClient/DeviceClient.swift` | One injected device fact | ✓ VERIFIED | Live, noop, and unimplemented values are substantive; only the live closure accesses the platform global. |
| Reader geometry and gesture sources | One local size flow and native location/anchor input | ✓ VERIFIED | Reader, data source, control panel, placeholders, gestures, and Live Text use captured container geometry. |
| Gallery routing helper and reducer hosts | Shared phone-push/pad-present policy | ✓ VERIFIED | Home, Search, Favorites, and Downloads use the helper; app-level reducers handle pad presentation delegates. |
| Plans 05-11 through 05-18 implementation sites | Closure of UAT gaps | ✓ VERIFIED | Every described code/config change exists and is substantive. Runtime acceptance remains human where noted. |
| Removed globals/modules | No obsolete source, package edge, or live reference | ✓ VERIFIED | No `DeviceUtil`, `TouchHandler`, `AppOrientationMask`, or `AppDelegateClient` artifact or package dependency remains. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `DeviceType.current` | Application consumers | `DeviceClient.live` and dependency injection | WIRED | Platform identity is isolated to one live closure. |
| Reader container | Gestures, page mapping, placeholders, and controls | One `onGeometryChange` assignment | WIRED | The observed size is the common input to downstream layout and pure arithmetic. |
| Native gestures | `GestureHandler` | Spatial-tap location and magnify start anchor | WIRED | Zoom/tap gating and clamp/anchor behavior are covered by unit tests; live recognizer composition passed prior UAT. |
| Live Text container | Canvas and interactive overlays | One captured nonzero `CGSize` | WIRED | Paths, frames, and positions share identical rendered geometry. |
| Home carousel container | Card frame and scroll geometry | `carouselWidth`, `cardWidth`, and pitch derived in one owner | WIRED | Centering, peek, and target math no longer have competing width sources. |
| Gallery list reducers | Inline navigation or app-level presentation | `GalleryNavigation.routeGalleryDetail(deviceType:)` | WIRED | Phone appends the stack; pad emits the presentation delegate. External/deep-link presentation remains deliberately separate. |
| Window environment | Reader upper controls | `containerCornerInsets.topLeading` | WIRED | Only pad freeform's nonzero inset changes the upper-panel padding. |

## Data-Flow Trace

| Artifact | Data variable | Source | Produces real data | Status |
| --- | --- | --- | --- | --- |
| `ReadingView` | `gestureHandler.containerSize` | SwiftUI container observation | Aspect ratio, dual-page eligibility, gesture bounds, page data, placeholders, and controls | ✓ VERIFIED |
| `LiveTextView` | `size` | SwiftUI container observation | Normalized OCR paths and interactive overlay frames/positions | ✓ VERIFIED |
| Home carousel | `carouselWidth` | Horizontal scroll container | Card width, pitch, margins, and nearest-center calculations | ✓ VERIFIED |
| Gallery routing | `deviceType()` | Injected dependency | Push action for phone or presentation delegate for pad | ✓ VERIFIED |
| Favorites date seek | available range metadata | Favorites state | Disabled/enabled menu action and sheet presentation | ✓ WIRED; HUMAN INTERACTION |
| Reader freeform clearance | top-leading corner inset | SwiftUI window environment | Pad-only upper-panel offset | ✓ WIRED; HUMAN VISUAL |

## Behavioral Spot-Checks

| Behavior | Evidence | Result | Status |
| --- | --- | --- | --- |
| Full package regression suite after Plan 18 | The execution orchestrator reports the full `AppPackage` suite completed successfully after the final gap plan. | No failing test was reported. | ✓ PASS |
| Reader pure gesture and page behavior | Permanent `GestureHandlerTests` and `PageHandlerTests` cover the key size, scale, anchor, direction, and mapping matrix and passed within the full suite. | Pure behavior remains locked. | ✓ PASS |
| Shared gallery routing semantics | Permanent Downloads reducer tests cover phone push and pad delegate outcomes and passed within the full suite. | Shared policy remains locked. | ✓ PASS |
| Additional focused project-scheme attempt | The `ReadingFeature` project scheme has no configured test action, so the focused invocation exited before running tests. | Environment/scheme limitation, not a source or test failure; the already-passed full package suite is the applicable result. | ◇ NOT RUN |

No redundant full-suite rerun was performed during independent verification.

## Probe Execution

No phase plan leaves a standalone executable probe. Plan 18 intentionally removed its temporary reducer probe after the audit. That audit is useful supporting context but is not promoted to independent verifier evidence; the unresolved live gallery-route matrix is therefore routed to human verification instead of being marked automatically verified.

## Requirements Coverage

| Requirement | Description | Status | Evidence |
| --- | --- | --- | --- |
| UIARCH-01 | Adaptive layout and native reader input | ⚠️ HUMAN NEEDED | Metric globals and `GeometryReader` are removed; container-relative implementations, pure tests, and prior gesture/Live Text UAT pass. The G-05-1 and window-appearance runtime matrix still needs human confirmation. |
| UIARCH-03 | Universal OS-governed orientation | ⚠️ HUMAN NEEDED | Custom locks are gone and both device families declare all orientations. Actual rotation, state preservation, and representative layouts still need live confirmation. |

No Phase 5 requirement is orphaned: ROADMAP and REQUIREMENTS map UIARCH-01 and UIARCH-03 to this phase.

## Anti-Patterns and Review Findings

No `TODO`, `TBD`, `FIXME`, `XXX`, `HACK`, or placeholder implementation marker was found in the reviewed Phase 5 production/test scope. No unauthorized SwiftLint suppression was added, removed package/module reference remains, or global screen-metric workaround was introduced.

The review's archive-download accessibility warning predates Phase 5 according to file history. Its custom text/gesture control should eventually become a native accessible button, but it is advisory pre-existing debt rather than a regression or Phase 5 blocker.

## Human Verification Required

1. **Universal rotation and reader state:** Rotate Home, detail, grid, settings, and reader screens. Cover single-page, dual-page, RTL, and a resumed landscape dual-page session. Expect no snap-back, incorrect pairing, page drift, or resume drift.
2. **About metadata:** Open About on a landscape phone. Expect all metadata to remain visible in the leading form content.
3. **Reader placeholders:** Load slow or unavailable pages in portrait/landscape and single/dual-page modes. Expect placeholders to match the usable page footprint rather than collapse.
4. **Home carousel:** Check phone/pad in portrait/landscape. Expect stable card width and pitch, a centered focused card, and the intended adjacent-card peek.
5. **Range fields and sheet dismissal:** In Filters, confirm no duplicate visible field title and a useful VoiceOver label. Open Filters, Quick Search, and Date Seek; expect an untitled Cancel control to dismiss each sheet.
6. **Favorites:** Confirm direct category access, the nested features menu, and Date Seek being disabled before range metadata but opening after metadata arrives.
7. **iPad freeform controls:** Resize the reader in a freeform window. Expect the upper controls to clear traffic lights; full-screen pad and phone spacing must remain unchanged.
8. **Home contrast:** Inspect cards in normal/freeform windows under light mode, dark mode, and Increase Contrast. Expect cards and backgrounds to remain distinguishable.
9. **Single-window behavior:** Inspect system app/window menus. Expect no New Window or multi-scene affordance.
10. **Gallery route matrix:** On phone, open details from Home carousel/cover/top lists and nested lists, Search root/nested lists, Favorites, Downloads, Comments, and detail-search onward routes; expect pushes. Repeat equivalent in-app hosts on pad; expect presentation. Confirm external/deep links remain deliberately modal on both.
11. **Representative adaptive layouts:** Check compact/regular widths and split view for category/grid layouts, previews, archives, and settings in portrait/landscape. Expect readable, centered, unclipped content. Maximum Dynamic Type belongs to Phase 10 and is not part of this acceptance pass.

## Gaps Summary

No automated or source-level implementation blocker remains after Plans 05-11 through 05-18. G-05-1 gaps 1-6 and G-05-4 gaps 7-9 are closed in source, and Plan 18 found no phone-routing bypass. The original failures are runtime rendering, system-windowing, presentation, and interaction outcomes, so they cannot be promoted to verified from static evidence alone. Phase 5 therefore remains `human_needed` pending the eleven exact checks above.

---

_Verified: 2026-07-13T10:26:48Z_
_Verifier: the agent (gsd-verifier methodology via generic-agent fallback)_
