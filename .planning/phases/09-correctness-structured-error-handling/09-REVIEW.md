---
phase: 09-correctness-structured-error-handling
reviewed: 2026-07-16T11:08:09Z
depth: standard
files_reviewed: 63
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/ActivityView.swift
  - AppPackage/Sources/AppComponents/AppAlertState.swift
  - AppPackage/Sources/AppComponents/ErrorInfoView.swift
  - AppPackage/Sources/AppComponents/PreviewImageView.swift
  - AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings
  - AppPackage/Sources/AppComponents/TagSuggestionView.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/AppModels/Gallery/Category.swift
  - AppPackage/Sources/AppModels/Persistence/JSONValue.swift
  - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
  - AppPackage/Sources/AppModels/Support/AppError+Context.swift
  - AppPackage/Sources/AppModels/Support/AppError.swift
  - AppPackage/Sources/AppTools/DataCache.swift
  - AppPackage/Sources/AppTools/Defaults.swift
  - AppPackage/Sources/AppTools/Extensions.swift
  - AppPackage/Sources/DetailFeature/Components/LinkedText.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/FileClient/FileClient.swift
  - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
  - AppPackage/Sources/ImageClient/ImageClient.swift
  - AppPackage/Sources/LibraryClient/LibraryClient.swift
  - AppPackage/Sources/LogsClient/LogsClient.swift
  - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
  - AppPackage/Sources/NetworkingFeature/Request+Account.swift
  - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
  - AppPackage/Sources/NetworkingFeature/Request+GData.swift
  - AppPackage/Sources/NetworkingFeature/Request+Image.swift
  - AppPackage/Sources/NetworkingFeature/Request.swift
  - AppPackage/Sources/ParserFeature/Parser+Detail.swift
  - AppPackage/Sources/ParserFeature/Parser+Image.swift
  - AppPackage/Sources/ParserFeature/Parser+List.swift
  - AppPackage/Sources/ParserFeature/Parser+Profile.swift
  - AppPackage/Sources/ParserFeature/Parser+Shared.swift
  - AppPackage/Sources/ParserFeature/Parser+Torrent.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/Support/LiveTextView.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsPumpReducer.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsReducer.swift
  - AppPackage/Sources/SettingFeature/Components/WebView.swift
  - AppPackage/Sources/SystemNotificationExt/View+Toast.swift
  - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
  - AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift
  - AppPackage/Tests/AppModelsTests/AnyHashableBoxTests.swift
  - AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift
  - AppPackage/Tests/AppModelsTests/CategoryFilterValueTests.swift
  - AppPackage/Tests/AppModelsTests/ErrorContextSanitizerTests.swift
  - AppPackage/Tests/FeatureTests.xctestplan
  - AppPackage/Tests/SystemNotificationExtTests/.swiftlint.yml
  - AppPackage/Tests/SystemNotificationExtTests/ToastInteractionTests.swift
findings:
  critical: 0
  warning: 5
  info: 0
  total: 5
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-07-16T11:08:09Z
**Depth:** standard
**Files Reviewed:** 63
**Status:** issues_found

## Summary

This standard-depth review used the generic-agent workaround for the `gsd-code-reviewer` role. The two prior blockers are resolved: gallery diagnostics no longer retain secret-bearing route components, and diagnostic toasts now provide a persistent native Button with focus, announcement, exactly-once routing, and Reduce Motion handling. Five non-blocking robustness, accessibility, localization, and test-reliability issues remain.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Persistent diagnostic toasts have a swipe-only dismissal action

**File:** `AppPackage/Sources/SystemNotificationExt/View+Toast.swift:69-72,105-117`

**Issue:** A diagnostic toast can be dismissed without opening its details only through the downward `DragGesture`. The native Button makes the detail route accessible, but it does not expose the distinct dismissal operation to VoiceOver, Switch Control, Voice Control, or Full Keyboard Access. Because diagnostic toasts no longer time out, an assistive-technology user who does not want to open the sheet has no equivalent way to clear the persistent overlay. This violates the project's accessibility rule that swipe-only actions need an accessibility alternative.

**Fix:** Add a localized accessibility dismissal action that calls the same UUID-gated `dismiss(presentedID:)` path, or render a native close control alongside the diagnostic Button. Keep the drag gesture as the pointer/touch shortcut.

```swift
.accessibilityAction(named: Text(.dismiss)) {
    dismiss(presentedID: id)
}
```

### WR-02: Diagnostic context labels bypass localization

**File:** `AppPackage/Sources/AppComponents/ErrorInfoView.swift:27-34`

**Issue:** Context rows display `ContextKey.rawValue`, whose values are fixed English strings (`Action`, `Reason`, `Status Code`, and `Gallery ID`). The surrounding error-detail UI is translated into six locales, so non-English users receive a partially untranslated user-facing surface.

**Fix:** Give `ContextKey` a localized display label backed by the AppComponents or AppModels string catalog and pass that resource to `LabeledContent`. Keep any stable programmatic identifier separate from presentation text.

### WR-03: The public top-level `Context` alias collides with SwiftUI protocol APIs

**File:** `AppPackage/Sources/AppModels/Support/AppError+Context.swift:57`

**Issue:** Exporting the generic name `Context` from AppModels shadows `UIViewControllerRepresentable.Context` and related framework context types. This phase already had to qualify four unrelated representable methods with `Self.Context`, demonstrating a concrete cross-module source-compatibility cost rather than a naming preference.

**Fix:** Rename the alias to `ErrorContext` or nest it under `ErrorInfo`, then update the structured-error call sites and tests.

### WR-04: Localization parity tests depend on the runner language

**File:** `AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift:13-91`

**Issue:** The parity table compares localized production strings against hard-coded English. It passes only when the test host selects English and can fail on a differently localized simulator or CI runner even when production localization is correct.

**Fix:** Run string-value checks under an explicitly controlled English locale, or derive expected text from the corresponding localized resources under the active locale. Keep locale-independent assertions for case mapping, retryability, and `LocalizedError` forwarding.

### WR-05: Toast interaction tests stop below the SwiftUI integration boundary

**File:** `AppPackage/Tests/SystemNotificationExtTests/ToastInteractionTests.swift:12-57`

**Issue:** The new tests exercise `ToastInteractionState` and factory flags directly, but none drives `ToastViewModifier` to prove that Button activation, replacement, the drag path, and task cancellation actually call that state machine and mutate the presentation binding as expected. A wiring regression can therefore leave all five tests green while breaking the user interaction the target was introduced to protect.

**Fix:** Add a small host-level integration test around the modifier using the project's supported SwiftUI inspection/UI-testing approach. Verify current Button activation invokes `onErrorTap` once and clears the binding, replacement rejects the old control, and dismissal never invokes the callback. Keep the existing fast value-type tests as the unit layer.

---

_Reviewed: 2026-07-16T11:08:09Z_
_Reviewer: generic-agent workaround (gsd-code-reviewer instructions)_
_Depth: standard_
