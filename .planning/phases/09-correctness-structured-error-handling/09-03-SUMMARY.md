---
phase: 09-correctness-structured-error-handling
plan: 03
subsystem: ui
tags: [swiftui, error-handling, toast, accessibility, localization]

requires:
  - phase: 09-01
    provides: ErrorInfo, typed context, localized solutions, and AppError parity guarantees
provides:
  - Redacted native ErrorInfoView with diagnostic and environment sections
  - ErrorInfo-bearing AppAlertState toast factory
  - Tappable toast routing seam for later presentation integration
affects: [error-presentation, app-routing, SystemNotificationExt, QUAL-04]

tech-stack:
  added: []
  patterns: [native Form diagnostics, modifier-level toast tap routing, direct module ownership]

key-files:
  created:
    - AppPackage/Sources/AppComponents/ErrorInfoView.swift
  modified:
    - AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings
    - AppPackage/Sources/AppComponents/AppAlertState.swift
    - AppPackage/Sources/SystemNotificationExt/View+Toast.swift
    - AppPackage/Package.swift

key-decisions:
  - "Keep ErrorInfoView entirely native and data-minimal: Form, LabeledContent, and only whitelisted context/environment values."
  - "Route error-toast activation through a modifier closure and an accessibility button trait; the Action == Never store never sends an action."
  - "Declare AppModels directly on SystemNotificationExt because its public toast API exposes ErrorInfo."

patterns-established:
  - "Diagnostic surfaces render ContextKey.rawValue and AnyHashableBox.displayValue only, sorted for deterministic presentation."
  - "Button-less presentation state carries navigation payloads while host closures own routing."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: "ErrorInfoView conditionally renders description, solution, context, and a redacted environment with a native close action."
    requirement: QUAL-04
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package -destination generic/platform=iOS"
        status: pass
      - kind: other
        ref: "Static redaction and six-locale catalog gates from 09-03-PLAN.md"
        status: pass
    human_judgment: true
    rationale: "Native Form layout, toolbar dismissal, Dynamic Type, and VoiceOver reading order require simulator or device evaluation."
  - id: D2
    description: "AppAlertState<Never>.error(ErrorInfo) preserves the payload, uses alertText, remains button-less, and participates in content equality and hashing."
    requirement: QUAL-04
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package -destination generic/platform=iOS plus source acceptance gates"
        status: pass
    human_judgment: false
  - id: D3
    description: "The toast modifier invokes its host closure for ErrorInfo-bearing toasts while preserving swipe dismissal and the three-second timer."
    requirement: QUAL-04
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package -destination generic/platform=iOS plus no-store.send static gate"
        status: pass
    human_judgment: true
    rationale: "Tap timing, exactly-once activation, swipe coexistence, and visual parity require interactive simulator or device evaluation."

duration: 7min
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 03: Structured Error Failure Surface Summary

**A redacted native error-detail Form now sits behind ErrorInfo-bearing, host-routable Liquid Glass failure toasts.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-15T06:08:02Z
- **Completed:** 2026-07-15T06:14:42Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Added an iOS/iPadOS-only `ErrorInfoView` with conditional Description, Suggested Solution, and Context sections plus a tightly redacted Environment section and native close toolbar action.
- Added all eight user-facing labels in the AppComponents string catalog across English, German, Japanese, Korean, Simplified Chinese, and Traditional Chinese.
- Extended button-less error toasts to retain `ErrorInfo`, display `AppError.alertText`, and route activation through an accessible modifier-level host closure without sending an impossible `Never` action.
- Preserved the existing Liquid Glass renderer, downward-swipe behavior, and three-second auto-hide implementation.

## Task Commits

Each task was committed atomically:

1. **Task 1: ErrorInfoView native diagnostic surface** — `bab8f779` (feat)
2. **Task 2: ErrorInfo-bearing AppAlertState toast** — `62cf1851` (feat)
3. **Task 3: Toast onErrorTap routing seam** — `f57f08a0` (feat)

Post-review cleanup: `6cc11ca9` (chore) removed one redundant import without changing behavior.

## Files Created/Modified

- `AppPackage/Sources/AppComponents/ErrorInfoView.swift` — native, dismissable, redacted diagnostic Form.
- `AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings` — eight failure-surface labels translated into all six supported locales.
- `AppPackage/Sources/AppComponents/AppAlertState.swift` — optional ErrorInfo payload, content equality/hashing, and button-less error factory.
- `AppPackage/Sources/SystemNotificationExt/View+Toast.swift` — host tap closure, conditional accessibility button semantics, and documented cancellation survivor.
- `AppPackage/Package.swift` — direct AppModels ownership for SystemNotificationExt's public ErrorInfo API.

## Decisions Made

- Kept the detail surface entirely native so system Form, Section, LabeledContent, NavigationStack, and toolbar semantics supply adaptive layout and accessibility behavior.
- Rendered context rows in stable label order and exposed only the existing ContextKey whitelist plus display-safe boxed values.
- Added `.isButton` only when a toast actually carries ErrorInfo, preserving loading/success semantics while making the tappable failure toast discoverable to VoiceOver.
- Added AppModels as a direct SystemNotificationExt dependency instead of relying on AppComponents' transitive dependency.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Declared direct module ownership for the public tap API**

- **Found during:** Task 3 (View+Toast routing seam)
- **Issue:** `View+Toast.swift` now imports and publicly exposes `ErrorInfo`, but SystemNotificationExt did not directly declare AppModels.
- **Fix:** Added `.module(.appModels)` to SystemNotificationExt's target dependencies.
- **Files modified:** `AppPackage/Package.swift`
- **Verification:** The package manifest resolved and the generic iOS package build succeeded.
- **Committed in:** `f57f08a0`

---

**Total deviations:** 1 auto-fixed (1 missing critical functionality)
**Impact on plan:** The added manifest edge makes the planned public API explicit and stable; no feature scope changed.

## Issues Encountered

- The package scheme is available from `AppPackage/`, not the repository root. All successful verification builds ran from the package directory.
- Xcode build-service access required the approved unsandboxed build path; the final generic iOS build succeeded.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 09-04 can present `ErrorInfoView(errorInfo:)`, replace routed failure factories with `.error(errorInfo)`, and pass `onErrorTap` from the root toast host.
- Interactive phase verification should confirm tap-within-three-seconds behavior, native dismissal, Dynamic Type, and VoiceOver reading order.

## Self-Check: PASSED

- All five created/modified implementation artifacts exist.
- Task commits `bab8f779`, `62cf1851`, `f57f08a0`, and cleanup commit `6cc11ca9` exist in history.
- The final generic iOS `AppPackage-Package` build succeeded with SwiftLint plugins active.
- Redaction gates contain no AppUtil, DeviceUtil, macOS, Firebase, analytics, cookie, token, or credential references.
- `View+Toast.swift` contains no `store.send`, and the cancellation-swallow survivor has an adjacent just-cause comment.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
