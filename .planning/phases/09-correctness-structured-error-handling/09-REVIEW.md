---
phase: 09-correctness-structured-error-handling
reviewed: 2026-07-15T09:08:58Z
depth: standard
files_reviewed: 59
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
findings:
  critical: 2
  warning: 4
  info: 0
  total: 6
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-07-15T09:08:58Z
**Depth:** standard
**Files Reviewed:** 59
**Status:** issues_found

## Summary

The structured-error foundation, presentation routing, client propagation changes, and documented optional-failure survivors were reviewed across the exact 59-file scope. Two ship-blocking issues remain: the diagnostic path exposes gallery tokens, and the only route to error details is a transient toast that assistive-technology users may never discover. Four robustness and localization issues should also be corrected.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Diagnostic URL context exposes gallery access tokens

**File:** `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift:210-214`

**Issue:** The failure context stores `url.path` verbatim. Handleable gallery URLs use path component 3 as the gallery/image token (`/g/<gid>/<token>` and `/s/<key>/<gid>-<page>`), so the new user-visible diagnostic sheet displays a token even though `AppError+Context.swift` explicitly promises that tokens never enter context. “Path-only” is not a sufficient redaction boundary for this URL format. This can leak access-bearing identifiers through screenshots, support reports, or screen sharing.

**Fix:** Never place the raw path in `Context`. Add a route-aware diagnostic sanitizer that emits only a route kind and safe identifiers, or omit `.url` and store only the parsed gallery ID. Enforce the sanitizer at the context API boundary so callers cannot accidentally bypass it.

```swift
let analysis = urlClient.analyzeURL(url)
var context: Context = [
    .action: "Fetch gallery",
    .reason: AnyHashableBox(error.localizedDescription)
]
if let gid = urlClient.parseGalleryID(url) {
    context[.gid] = AnyHashableBox(gid)
}
context[.url] = AnyHashableBox(analysis.isGalleryImageURL ? "/s/<redacted>" : "/g/<redacted>")
```

### CR-02: Error details are discoverable only through an unannounced three-second toast

**File:** `AppPackage/Sources/SystemNotificationExt/View+Toast.swift:53-59,84-93`

**Issue:** The error-detail route is activated only by tapping a dynamically inserted gesture view. The toast is not announced and does not receive accessibility focus, and it disappears after three seconds. Adding `.isButton` changes the announced trait but does not notify a VoiceOver user that the control appeared; keyboard and Switch Control users can likewise miss the only activation window. The structured detail surface is therefore effectively unreachable for an important class of users.

**Fix:** Make error toasts persistent until activated or explicitly dismissed, render the activation source as a native `Button` (or provide an explicit accessibility action), and announce/focus the newly presented error. Keep swipe dismissal available independently of auto-hide.

```swift
Button {
    if let errorInfo = store.state.errorInfo {
        onErrorTap(errorInfo)
    }
} label: {
    ToastMessageView(content: toast)
}
.buttonStyle(.plain)
.onAppear {
    if store.state.errorInfo != nil {
        AccessibilityNotification.Announcement(toast.title).post()
    }
}
```

## Warnings

### WR-01: Toast motion ignores Reduce Motion

**File:** `AppPackage/Sources/SystemNotificationExt/View+Toast.swift:59-65`

**Issue:** Every toast uses a moving edge transition and `.bouncy` animation without consulting `accessibilityReduceMotion`. Error presentation can therefore produce motion the user explicitly disabled.

**Fix:** Read `@Environment(\.accessibilityReduceMotion)` in the modifier, use an opacity-only transition when enabled, and disable the bouncy animation (or replace it with a short opacity animation).

### WR-02: Diagnostic context labels bypass localization

**File:** `AppPackage/Sources/AppComponents/ErrorInfoView.swift:24-31`

**Issue:** Context rows display `ContextKey.rawValue`, whose values are fixed English strings (`Action`, `Reason`, `Status Code`, and `Gallery ID`). The surrounding error-detail UI is translated into six locales, so non-English users receive a partially untranslated diagnostic surface.

**Fix:** Give `ContextKey` a localized label backed by the string catalog and pass that resource to `LabeledContent`; keep the raw identifier separate from presentation text.

### WR-03: The public top-level `Context` alias collides with SwiftUI protocol APIs

**File:** `AppPackage/Sources/AppModels/Support/AppError+Context.swift:57`

**Issue:** Exporting the generic name `Context` from `AppModels` shadows `UIViewControllerRepresentable.Context` and other framework context types. This phase already had to modify four unrelated representables to spell `Self.Context`, demonstrating a real cross-module source-compatibility cost. Future imports can trigger the same ambiguity.

**Fix:** Rename the alias to `ErrorContext` (or nest it under `ErrorInfo`) and update the small number of structured-error call sites.

### WR-04: Localization parity tests depend on the runner language

**File:** `AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift:13-91`

**Issue:** The tests compare localized production strings against hard-coded English. They pass only when the test host selects English and become flaky or fail on a differently localized simulator/CI environment, even when production localization is correct.

**Fix:** Build expected values from the corresponding localized resources under the active locale, or run an explicitly English-only string-value test under a controlled localization configuration. Keep locale-independent tests for case mapping, retryability, and `LocalizedError` forwarding.

---

_Reviewed: 2026-07-15T09:08:58Z_
_Reviewer: generic-agent workaround (gsd-code-reviewer instructions)_
_Depth: standard_
