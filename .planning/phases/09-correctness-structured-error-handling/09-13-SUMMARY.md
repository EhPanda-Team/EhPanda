---
phase: 09-correctness-structured-error-handling
plan: 13
subsystem: ui
tags: [swiftui, accessibility, swift-testing, error-handling]

requires:
  - phase: 09-12
    provides: Privacy-safe ErrorInfo context at the gallery failure boundary
provides:
  - Persistent native diagnostic-toast activation for assistive technology and keyboard input
  - Exactly-once toast interaction lifecycle with stale replacement and dismissal invalidation
  - Reduce-Motion-aware toast presentation and deterministic Swift Testing coverage
affects: [system-notifications, error-routing, accessibility, phase-verification]

tech-stack:
  added: []
  patterns:
    - Native Button activation backed by a consumable value-type presentation identity
    - Accessibility focus and announcement for dynamically inserted diagnostics
    - Motion-free opacity transition under Reduce Motion

key-files:
  created:
    - AppPackage/Tests/SystemNotificationExtTests/.swiftlint.yml
    - AppPackage/Tests/SystemNotificationExtTests/ToastInteractionTests.swift
  modified:
    - AppPackage/Sources/AppComponents/AppAlertState.swift
    - AppPackage/Sources/SystemNotificationExt/View+Toast.swift
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan

key-decisions:
  - "ErrorInfo-bearing toasts remain until native Button activation or downward-swipe dismissal; ordinary success and caption-error toasts retain their three-second timeout."
  - "ToastInteractionState consumes only the current UUID and clears it before host routing, so stale, repeated, replacement, and dismissal events cannot route ErrorInfo."
  - "The diagnostic Button keeps ToastMessageView as its visible label so Voice Control names and visible text remain aligned."

patterns-established:
  - "Transient presentation callbacks validate and consume a presentation UUID before invoking their host closure."
  - "Dynamic diagnostic controls receive accessibility focus and an announcement without branching on a running assistive technology."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: "ErrorInfo-bearing toasts are persistent native Buttons with focus and announcement handling."
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "xcodebuild build -scheme AppPackage-Package -destination generic/platform=iOS"
        status: pass
    human_judgment: true
    rationale: "VoiceOver speech and focus, Voice Control naming, Switch Control scanning, and Full Keyboard Access activation require simulator or device evaluation."
  - id: D2
    description: "Current-toast activation routes once while replacement, dismissal, and stale events route nothing."
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SystemNotificationExtTests/ToastInteractionTests.swift"
        status: pass
    human_judgment: false
  - id: D3
    description: "Only diagnostic errors persist, and Reduce Motion replaces the moving bouncy transition with opacity."
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SystemNotificationExtTests/ToastInteractionTests.swift#onlyDiagnosticErrorsRemainPresented"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme AppPackage-Package -destination generic/platform=iOS"
        status: pass
    human_judgment: true
    rationale: "The timeout policy is automated, but the motion preference's rendered transition requires visual evaluation."

duration: 17min
completed: 2026-07-16
status: complete
---

# Phase 09 Plan 13: Accessible Diagnostic Toast Lifecycle Summary

**Persistent native diagnostic controls now focus and announce errors while a UUID-gated lifecycle guarantees exactly-once detail routing.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-07-16T10:43:00Z
- **Completed:** 2026-07-16T10:59:35Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Replaced the timed custom ErrorInfo gesture with a persistent, plain-styled native Button that supports VoiceOver, Voice Control, Switch Control, and Full Keyboard Access semantics.
- Added accessibility focus and announcement handling while keeping the existing visible toast text as the control label.
- Added a small value-type lifecycle that consumes current activation once and rejects repeated, stale, replaced, or dismissed presentation identities.
- Preserved three-second auto-hide for caption errors and successes, retained explicit downward-swipe dismissal, and removed moving/bouncy presentation under Reduce Motion.
- Added a dedicated, root-linted SystemNotificationExtTests target with five parallel-safe Swift Testing regressions.

## Task Commits

The TDD work was committed in red-green order:

1. **RED: Add failing toast lifecycle and timeout-policy tests** — `11431c3b` (test)
2. **GREEN: Implement persistent accessible diagnostic toasts** — `650d9315` (feat)

## Files Created/Modified

- `AppPackage/Sources/AppComponents/AppAlertState.swift` — makes ErrorInfo-bearing error toasts persistent.
- `AppPackage/Sources/SystemNotificationExt/View+Toast.swift` — native Button activation, focus/announcement, lifecycle gating, swipe invalidation, and Reduce Motion behavior.
- `AppPackage/Package.swift` — registers the directly owned SystemNotificationExtTests target.
- `AppPackage/Tests/SystemNotificationExtTests/.swiftlint.yml` — inherits the repository's root lint configuration.
- `AppPackage/Tests/SystemNotificationExtTests/ToastInteractionTests.swift` — exactly-once, replacement, dismissal, stale-event, and timeout-policy coverage.
- `AppPackage/Tests/FeatureTests.xctestplan` — includes SystemNotificationExtTests in the feature test plan.

## Decisions Made

- Kept the stable host toast overlay and existing `onErrorTap` closure; only the activation control and presentation lifecycle changed.
- Cleared both the interaction identity and presentation binding before calling the host route, making reentrant or repeated activation unable to route twice.
- Allowed diagnostic toasts to use the existing downward swipe even though they no longer auto-hide; loading toasts remain reducer-owned and non-dismissible.
- Used a short opacity transition under Reduce Motion so presentation remains perceivable without spatial or bouncy movement.

## Deviations from Plan

None - plan executed as specified, including TDD red-green ordering.

## Issues Encountered

- The first RED compile exposed a missing Foundation import in the new test file; after correcting the test harness, the intended RED failure was the absent `ToastInteractionState` symbol.
- Simulator and Xcode cache services required the approved unsandboxed Xcode path. The final focused test suite and generic iOS package build both succeeded.

## User Setup Required

None - no external service configuration required.

## Verification

- Focused `SystemNotificationExtTests`: **5 tests passed** in one Swift Testing suite.
- Generic iOS `AppPackage-Package` build: **BUILD SUCCEEDED** with SwiftLint build-tool plugins active.
- Static acceptance gates confirm no `onTapGesture`, SwiftLint suppression, XCTest, serialization, or sleep exists in the new interaction tests.

## Next Phase Readiness

- All Phase 9 gap-closure plans are implemented and ready for phase re-verification.
- Device/simulator UAT should verify VoiceOver announcement/focus, Voice Control naming, Switch Control scanning, Full Keyboard Access activation, persistent availability beyond three seconds, downward-swipe dismissal, and the Reduce Motion transition.

## Self-Check: PASSED

- All six created or modified artifacts exist.
- Task commits `11431c3b` and `650d9315` exist in branch history.
- The focused suite and generic iOS package build pass.
- No stub, new trust boundary, SwiftLint suppression, or absolute home path was introduced.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-16*
