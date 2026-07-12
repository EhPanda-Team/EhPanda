---
phase: 01-isolated-dependency-modernization
reviewed: 2026-07-12T12:01:06Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - AppPackage/Package.resolved
  - AppPackage/Package.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/FileClient/FileClient.swift
  - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
  - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
  - AppPackage/Sources/LegacyCFReadStream/.swiftlint.yml
  - AppPackage/Sources/LegacyCFReadStream/LegacyCFReadStream.swift
  - AppPackage/Sources/MarkdownExt/.swiftlint.yml
  - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
  - AppPackage/Sources/NetworkingFeature/DFExtensions.swift
  - AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings
  - AppPackage/Sources/TagTranslationFeature/TagTranslation+Markdown.swift
  - AppPackage/Tests/FeatureTests.xctestplan
  - AppPackage/Tests/FileClientTests/FileClientTests.swift
  - AppPackage/Tests/MarkdownExtTests/.swiftlint.yml
  - AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift
  - AppPackage/Tests/SwiftyOpenCCTests/.swiftlint.yml
  - AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift
  - AppPackage/Tests/TagTranslationFeatureTests/.swiftlint.yml
  - AppPackage/Tests/TagTranslationFeatureTests/TagTranslationMarkdownTests.swift
  - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
findings:
  critical: 0
  warning: 4
  info: 0
  total: 4
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-07-12T12:01:06Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

The review found four warnings: inconsistent dependency locks, an animated gradient that ignores Reduce Motion, invalid buffer-lifetime ordering, and network-dependent tests presented as deterministic.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: The two committed SwiftPM lockfiles resolve different dependency versions

**File:** `AppPackage/Package.resolved:1-4`, `AppPackage/Package.resolved:240-246`, `EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:1-4`, `EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:240-246`
**Issue:** The package lock resolves `SwiftLintPlugins` 0.64.1, while the Xcode workspace lock resolves 0.63.2; their `originHash` values also differ. Consequently, command-line package builds and Xcode builds do not use the same dependency graph or lint implementation, so a change can pass in one supported build path and fail in the other.
**Fix:** Regenerate both lockfiles from the same `Package.swift` dependency graph and commit matching pins.

### WR-02: The gallery's continuous gradient animation ignores Reduce Motion

**File:** `AppPackage/Sources/HomeFeature/GalleryCardCell.swift:52-61`, `AppPackage/Sources/HomeFeature/GalleryCardCell.swift:80`, `AppPackage/Sources/HomeFeature/GalleryCardCell.swift:102-115`
**Issue:** A focused card always inserts a continuously animated `ColorfulView`, animates its initial palette transition, and cross-fades focus changes. The view never reads `accessibilityReduceMotion`, so users who explicitly disable motion still receive the Metal gradient motion and transitions.
**Fix:** Read `accessibilityReduceMotion` and render a static palette without transition or view animation when it is enabled.

### WR-03: `HTTPBody()` deinitializes a buffer after freeing it

**File:** `AppPackage/Sources/NetworkingFeature/DFExtensions.swift:120-124`
**Issue:** The deferred cleanup calls `buffer.deallocate()` before `buffer.deinitialize(count:)`. The second operation therefore uses an invalid pointer. `UInt8` currently has trivial destruction, but the lifetime ordering is still invalid and can be caught by memory-safety tooling.
**Fix:** Remove the unnecessary `deinitialize` call for the raw byte buffer, or perform it before `deallocate()`.

### WR-04: Domain-fronting tests depend on live DNS despite claiming to be deterministic

**File:** `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift:12-15`, `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift:31-55`, `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift:59-69`, `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift:77-85`, `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift:158-185`
**Issue:** Five tests call `domainIPReplaced()`, which invokes the real `DomainResolver`, and assert that public DNS either resolves `e-hentai.org` or fails for `example.com`. These outcomes depend on the machine's resolver, connectivity, censorship, VPN, and DNS cache. The suite can therefore fail without a code regression and does not satisfy its stated fully deterministic contract.
**Fix:** Inject a resolver dependency and use fixed success/failure responses in these unit tests; keep live DNS behavior in a separately classified integration test.

---

_Reviewed: 2026-07-12T12:01:06Z_
_Reviewer: the agent (gsd-code-reviewer, generic-agent workaround)_
_Depth: standard_
