---
phase: 09-correctness-structured-error-handling
verified: 2026-07-15T09:20:15Z
status: gaps_found
score: "9/12 must-haves verified"
behavior_unverified: 1
overrides_applied: 0
gaps:
  - truth: "Surfaced diagnostic context contains no cookie, token, credential, full URL with query, IP address, or home path."
    status: failed
    reason: "PresentationFeature stores url.path verbatim. Supported /g/<gid>/<token> and /s/<key>/<gid>-<page> paths therefore place access-bearing tokens/keys in the user-visible Context section."
    artifacts:
      - path: "AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift"
        issue: "Lines 210-214 put url.path into Context without route-aware redaction."
      - path: "AppPackage/Sources/AppModels/Support/AppError+Context.swift"
        issue: "The public Context API documents that tokens never enter context but does not enforce that invariant."
    missing:
      - "A route-aware diagnostic sanitizer at the Context construction boundary that omits or redacts gallery/image tokens."
      - "Regression tests covering both /g/<gid>/<token> and /s/<key>/<gid>-<page> inputs."
  - truth: "User-relevant failures expose a detail route that is discoverable and reachable with VoiceOver, Voice Control, Switch Control, and keyboard input."
    status: failed
    reason: "The only activation source is an unannounced onTapGesture control that auto-dismisses after three seconds. Adding the button trait does not announce or focus the transient control, so assistive-technology users can miss the only route to ErrorInfoView."
    artifacts:
      - path: "AppPackage/Sources/SystemNotificationExt/View+Toast.swift"
        issue: "Lines 49-65 use onTapGesture, a three-second timer, and no accessibility announcement/focus or persistent alternative."
    missing:
      - "A native Button or equivalent explicit accessibility action for error-detail activation."
      - "Announcement/focus handling for newly presented failures and an activation window that does not time out before assistive-technology users can reach it."
deferred:
  - truth: "optional_try is enabled at error with zero violations."
    addressed_in: "Phase 11"
    evidence: "Phase 11 success criterion 2 explicitly switches optional_try to error after Phase 9's classified residual inventory."
behavior_unverified_items:
  - truth: "Tapping an ErrorInfo-bearing toast invokes onErrorTap exactly once within the timer window while swipe dismissal and replacement cancellation remain correct."
    test: "Present an ErrorInfo toast, activate it before expiry, then separately replace and swipe-dismiss toasts."
    expected: "Activation routes exactly once; replacement or swipe dismissal does not trigger the stale timer or route."
    why_human: "The reducer route test starts after the closure has fired; no UI or modifier-level test exercises the gesture/timer/cancellation interaction."
---

# Phase 9: Correctness & Structured Error Handling Verification Report

**Phase Goal:** Remove the private-category crash landmine and replace silent `try?` with structured error handling behind a user-facing error surface.
**Verified:** 2026-07-15T09:20:15Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | `Category.private.filterValue` is non-fatal, reports developer misuse, returns zero, and all searchable categories remain safe to iterate. | ✓ VERIFIED | `Category.swift:28-49`; focused `privateFilterValueReportsIssueAndReturnsZero()` and `allFilterCategoriesContributeEveryFilterBit()` checks exited 0. |
| 2 | The unchanged 12-case `AppError` supplies stable existing behavior, actionable solutions, and `LocalizedError` forwarding. | ✓ VERIFIED | `AppError.swift:4-128`; the all-cases table and solution/forwarding tests cover the mapping. |
| 3 | `AnyHashableBox`, typed context, `ContextKey`, and `ErrorInfo` are substantive, Sendable, hashable, literal-friendly payloads. | ✓ VERIFIED | `AppError+Context.swift:3-92` and `AnyHashableBoxTests.swift`; types are imported by AppComponents, SystemNotificationExt, and AppFeature. |
| 4 | `ErrorInfoView` renders conditional Description/Solution/Context plus Environment data and a native close action. | ✓ VERIFIED | `ErrorInfoView.swift:16-59`; section titles and labels introduced by the plan have all six locales. |
| 5 | `AppAlertState<Never>.error(ErrorInfo)` retains the payload without sending an impossible action. | ✓ VERIFIED | `AppAlertState.swift:32-38,64-77,165-171`; `View+Toast.swift` contains no `store.send`. |
| 6 | Toast tap, dismissal, replacement cancellation, and three-second timing work together at runtime. | ⚠ PRESENT_BEHAVIOR_UNVERIFIED | The gesture/timer code exists at `View+Toast.swift:49-93`, but no behavioral test exercises the interaction. |
| 7 | Gallery-failure context remains privacy-safe through the presentation route. | ✗ FAILED | `PresentationFeature.swift:210-214` stores raw `url.path`; `URLClient.swift:38-46` proves path component 3 is a token/key for supported routes. |
| 8 | The error-detail route is discoverable and reachable to assistive-technology users. | ✗ FAILED | The only activation source is an unannounced, unfocused `onTapGesture` view that disappears after three seconds (`View+Toast.swift:49-65,84-93`). |
| 9 | FileClient and NetworkingFeature propagate genuine file/decode failures while documented fallbacks preserve prior behavior. | ✓ VERIFIED | Typed `throws(AppError)` boundaries are present; focused module suites were reported green after the wave, and source review found no swallowing catch or path-bearing surfaced reason. |
| 10 | DownloadStore and DownloadClient optional failures are classified without replacing authoritative validation/download failures. | ✓ VERIFIED | All scoped survivors have adjacent just-cause comments; existing authoritative throwing boundaries remain wired to `DownloadFailure`/`AppError`. |
| 11 | AppTools, ParserFeature, client-tail, activity-log, JSONValue, and view/markdown survivors are explicit, behavior-preserving fallbacks. | ✓ VERIFIED | Independent source-aware audit counted 128 `try?` operators and found every one immediately preceded by a just-cause comment; MPV whole-parse JSON decoding uses typed `.parseFailed`. |
| 12 | The Phase 9 source compiles under the current SwiftLint rules with no new suppression, and focused behavioral checks pass. | ✓ VERIFIED | Phase diff adds zero `swiftlint:disable`; `optional_try` remains intentionally commented; focused Xcode tests exited 0 and the supplied final full-suite/SwiftLint gate passed. |

**Score:** 9/12 truths verified (1 present, behavior-unverified)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Enable `optional_try` at error with zero violations. | Phase 11 | Phase 11 success criterion 2 explicitly owns the rule flip after this phase's 128-expression classification. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/AppModels/Gallery/Category.swift` | Safe `.private.filterValue` | ✓ VERIFIED | Substantive switch, non-fatal issue, zero fallback, and tests. |
| `AppPackage/Sources/AppModels/Support/AppError+Context.swift` | Structured payload vocabulary | ⚠ PARTIAL | Types are substantive and wired, but the documented no-token invariant is not enforced at the API boundary. |
| `AppPackage/Sources/AppModels/Support/AppError.swift` | Solutions and `LocalizedError` | ✓ VERIFIED | Additive extensions preserve the 12-case enum. |
| `AppPackage/Sources/AppComponents/ErrorInfoView.swift` | Dismissable native detail surface | ✓ VERIFIED | Four-section data flow and close toolbar action are present. |
| `AppPackage/Sources/SystemNotificationExt/View+Toast.swift` | Error-toast activation seam | ⚠ PARTIAL | Wired to host closure, but assistive-tech reachability fails and runtime gesture/timer behavior lacks a test. |
| `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` | Error route and safe nearest-surface context | ✗ FAILED | Route works; raw path context violates the security prohibition. |
| `AppPackage/Tests/AppModelsTests/CategoryFilterValueTests.swift` | Crash-landmine regression | ✓ VERIFIED | Both focused checks pass. |
| `AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift` | Destination route regression | ✓ VERIFIED | Focused route check passes. |
| `AppPackage/Sources/FileClient/FileClient.swift` | Typed file-operation failures | ✓ VERIFIED | Propagating `AppError` endpoints and fixed non-secret operation descriptors are wired to callers. |
| `AppPackage/Sources/ParserFeature/Parser+List.swift` | Explicit optional-field fallbacks | ✓ VERIFIED | 25 surviving operators each carry an adjacent fallback justification. |
| `AppPackage/Sources/AppTools/DataCache.swift` | Documented best-effort housekeeping | ✓ VERIFIED | Cache failures remain internal and all 13 survivors are documented. |
| `AppPackage/Sources/AppModels/Persistence/JSONValue.swift` | Ordered representation probes | ✓ VERIFIED | Six sequential type probes remain explicit and documented. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `Category.private.filterValue` | `IssueReporting` | `reportIssue` plus `return 0` | ✓ WIRED | Focused test proves the issue and neutral result. |
| `AppError.solution` | AppModels catalog | localized solution resources | ✓ WIRED | Five keys each contain de/en/ja/ko/zh-Hans/zh-Hant. |
| `ErrorInfo.context` | `ErrorInfoView` | sorted context rows | ⚠ PARTIAL | Data flows, but raw English labels and unredacted URL values reach the UI. |
| `AppAlertState.errorInfo` | `View+Toast.onErrorTap` | retained payload and host closure | ⚠ PARTIAL | Code link exists; runtime interaction is untested and accessibility reachability fails. |
| `View+Toast.onErrorTap` | `PresentationFeature.presentErrorInfo` | `TabBarView` closure | ✓ WIRED | `TabBarView.swift:100-105`. |
| `PresentationFeature.destination.errorInfo` | `ErrorInfoView` | TCA item sheet | ✓ WIRED | `TabBarView.swift:73-77`; focused reducer route test passes. |
| `PresentationFeature.fetchGalleryDone` | safe diagnostic context | nearest-surface assembly | ✗ NOT WIRED SAFELY | Uses `url.path` rather than a redacted diagnostic representation. |
| Residual `try?` sites | Phase 11 lint ratchet | adjacent just-cause inventory | ✓ WIRED | Independent audit: 128 operators, all preceded by a comment. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `ErrorInfoView` | description/solution | `ErrorInfo.error` from reducer failure | Yes | ✓ FLOWING |
| `ErrorInfoView` | context rows | `PresentationFeature.fetchGalleryDone` | Yes, but includes a secret-bearing path component | ✗ UNSAFE FLOW |
| `ErrorInfoView` | environment rows | `AppInfo`, `DeviceClient`, `ProcessInfo` | Yes | ✓ FLOWING |
| Error toast | `errorInfo` | `.setToast(.error(errorInfo))` | Yes | ✓ FLOWING |
| Error detail sheet | destination item | `presentErrorInfo` from root toast callback | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Private category is non-fatal and filter iteration remains complete | Focused `xcodebuild test` selecting both AppModels checks | Exit 0 | ✓ PASS |
| `presentErrorInfo` sets the `.errorInfo` destination | Focused `xcodebuild test` selecting `PresentationFeatureTests/presentErrorInfoRoutesToErrorInfoDestination()` | Exit 0 | ✓ PASS |
| Residual optional-try justification audit | Source-aware Ruby scan over `AppPackage/Sources/**/*.swift` | `expressions=128`, `all_preceded_by_comment` | ✓ PASS |
| Toast gesture/timer/replacement behavior | No pre-existing modifier/UI test | Not executable as a single named test | ? SKIP |

### Probe Execution

No probes are declared by Phase 9 plans or summaries, and no conventional project probe applies to this phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| QUAL-03 | 09-02 | Remove the private-category fatal error and cover it. | ✓ SATISFIED | Safe implementation and two focused passing tests. |
| QUAL-04 | 09-01, 09-03 through 09-11 | Structured error handling and a user-facing detail surface. | ✗ BLOCKED | Structured errors and sweep are present, but the surfaced context leaks tokens and the only detail route is not reliably reachable with assistive technology. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` | 210-214 | Raw `url.path` enters user-visible context | BLOCKER | Gallery/image tokens can be disclosed in screenshots, support reports, or screen sharing. |
| `AppPackage/Sources/SystemNotificationExt/View+Toast.swift` | 49-65, 84-93 | Timed custom gesture is the sole error-detail route | BLOCKER | Assistive-technology users can miss the only activation source. |
| `AppPackage/Sources/SystemNotificationExt/View+Toast.swift` | 60-65 | Moving `.bouncy` transition ignores Reduce Motion | WARNING | User motion preference is not honored. |
| `AppPackage/Sources/AppComponents/ErrorInfoView.swift` | 29-34 | `ContextKey.rawValue` is fixed English UI text | WARNING | The otherwise six-locale detail surface is partially untranslated. |
| `AppPackage/Sources/AppModels/Support/AppError+Context.swift` | 57 | Public generic `Context` alias | WARNING | It already forced four unrelated representables to qualify `Self.Context` and remains collision-prone. |
| `AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift` | 13-91 | Hard-coded English localized strings | WARNING | The parity table depends on the runner language instead of controlling locale or deriving localized expectations. |

No phase-added `TODO`, `FIXME`, `XXX`, `HACK`, placeholder implementation, `@unchecked Sendable`, `@preconcurrency`, `NSLock`, or SwiftLint suppression was found.

### Human Verification Required

After the blocking toast accessibility design is corrected, verify VoiceOver announcement/focus, Voice Control and Switch Control activation, full-keyboard reachability, swipe dismissal, exactly-once routing, maximum Dynamic Type layout, and Reduce Motion behavior on a simulator/device. The current static accessibility failure is observable and is therefore a gap, not merely an uncertain human-only item.

### Gaps Summary

The crash-landmine fix, structured error model, typed propagation work, and complete optional-failure inventory are implemented and wired. The phase goal is nevertheless blocked at the user-facing boundary: raw gallery paths violate the phase's explicit no-token security contract, and the three-second custom toast gesture is not a dependable route to error details for assistive-technology users. These are current implementation failures, not work intentionally deferred to a later phase. The `optional_try` rule flip is separately and explicitly deferred to Phase 11.

---

_Verified: 2026-07-15T09:20:15Z_
_Verifier: generic-agent workaround (gsd-verifier instructions)_
