# Swift 6.4 migration

## Toolchain and scope

Verified with Xcode 27.1 RC (27A9275), Apple Swift 6.4
(`swiftlang-6.4.0.34.1`), and the iOS 27.1 SDK. The deployment target remains iOS 27.0.
`Package.swift` already required tools 6.4; it now explicitly declares Swift 6 language mode.
Xcode's `SWIFT_VERSION = 6.0` is the language mode, not the compiler version, and remains correct.
All package targets (including tests) and native Xcode targets enable the six upcoming language
features available in this toolchain: `ExistentialAny`, `ImmutableWeakCaptures`,
`InferIsolatedConformances`, `InternalImportsByDefault`, `MemberImportVisibility`, and
`NonisolatedNonsendingByDefault`. Existing actor boundaries are preserved. Public API dependencies
use explicit `public import`; files import the modules that define the members they use. Local
module dependencies and declarations for the existing third-party products were also audited. Protocol
existentials use explicit `any`. Native targets inherit the settings from the Xcode project.
Compiler invocations confirm Swift 6 language mode and all six flags in all 73 app-owned modules,
including every test target and the newer Live Text translation module.

## API changes

- Adopt native async `Result(catching:)` with typed `AppError` in request effects. Use the
  `Swift::` module selector to avoid the overlapping ConcurrencyExtras backport. Keep existing
  cancellation identifiers and action payloads; retain explicit error handling where it adds behavior.
- Use async `defer` to finish a download observer notification before its operation returns,
  instead of spawning an unstructured cleanup task.
- Adopt `Data.withBytes` and `RawSpan.load`, including explicit byte order, for animated-image
  detection. Keep malformed-input bounds checks and inspect image headers without copying image data.
- Use native async UIKit, Photos, Kingfisher and SDWebImage APIs for icon changes, photo saving,
  cache clearing, removal, querying and sizing. Preserve cache-miss and best-effort eviction semantics.
- Replace soft-deprecated scroll-indicator initializers, view-argument overlays/backgrounds,
  unlabeled UIKit-to-SwiftUI color initializers and the reader slider initializer.
- Use modern URL path construction, Swift string replacement, predicate counting and direct
  enumerated collection iteration. Use number format styles for rating and reading scale displays;
  decimal separators now follow the user's locale.
- Use native Regex for tag tokenization. This also corrects the previous character-count/UTF-16
  range mismatch when emoji precede a tag. Remove the unused runtime regex factory and its silent
  initialization-failure fallback.
- Repair malformed UTF-8 directly using the standard-library transcoder, preserving embedded NUL
  and subsequent bytes rather than treating the response as a C string.
- Migrate IssueReporting's deprecated `withExpectedIssue` test helper to `expectReportsIssue`
  with a matcher for the expected diagnostic.

- Replace raw bitmap flags with typed `CGBitmapInfo(alpha:byteOrder:)`. Keep the image-color
  sampling buffer inside `withUnsafeMutableBytes` for the entire CGContext drawing lifetime.
- Adopt the URL path/host/fragment accessors in production and test code, preserving decoding
  behavior. Compare normalized path components for download containment: directory hints can
  change a path string's trailing slash. At the symlink metadata boundary, use the URL's filesystem
  representation so a trailing slash cannot make `attributesOfItem` follow the link.
- Move torrent writes into a reducer effect and make the file-writing dependency explicitly
  `@concurrent` and async. Present the share sheet only after a successful write. Existing TCA
  `.run` operations already execute concurrently; no blanket actor or executor changes are needed.

Native navigation titles, search placement, dialog anchors and the soft top scroll-edge policy
remain at their existing presentation roots. No new warning or lint suppressions were introduced.

## Dependencies

Stable upstream tags were checked on 2026-10-14. All 14 direct dependencies have current stable
minimums or exact pins. All 31 resolved packages use the latest stable tags available at the check;
23 resolved entries changed, including two upstream package renames. Both checked-in lockfiles
are synchronized. Existing exact-pin policies remain in place.

| Package | Before | After |
| --- | --- | --- |
| [colorfulx](https://github.com/Lakr233/ColorfulX) | 6.1.0 | 6.2.1 |
| [colorvector](https://github.com/Lakr233/ColorVector) | 1.0.5 | 2.0.0 |
| [combine-schedulers](https://github.com/pointfreeco/combine-schedulers) | 1.2.0 | 1.2.2 |
| [displaylink](https://github.com/Lakr233/DisplayLink) | 2.1.0 (MSDisplayLink) | 3.0.1 |
| [kingfisher](https://github.com/onevcat/Kingfisher) | 8.10.0 | 8.13.0 |
| [libwebp-xcode](https://github.com/SDWebImage/libwebp-Xcode) | 1.5.0 | 1.6.0 |
| [springinterpolation](https://github.com/Lakr233/SpringInterpolation) | 1.4.0 | 3.0.1 |
| [swift-case-paths](https://github.com/pointfreeco/swift-case-paths) | 1.8.0 | 1.10.0 |
| [swift-clocks](https://github.com/pointfreeco/swift-clocks) | 1.1.0 | 1.1.1 |
| [swift-cmark](https://github.com/swiftlang/swift-cmark) | 0.8.0 | 0.9.0 |
| [swift-collections](https://github.com/apple/swift-collections) | 1.6.0 | 1.7.3 |
| [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) | 1.26.0 | 1.26.2 |
| [swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras) | 1.4.0 | 1.4.2 |
| [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump) | 1.6.1 | 1.7.3 |
| [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) | 1.14.1 | 1.17.1 |
| [swift-issue-reporting](https://github.com/pointfreeco/swift-issue-reporting) | 1.10.1 (xctest-dynamic-overlay) | 2.1.2 |
| [swift-markdown](https://github.com/apple/swift-markdown) | 0.8.0 | 0.9.0 |
| [swift-navigation](https://github.com/pointfreeco/swift-navigation) | 2.10.2 | 2.11.2 |
| [swift-perception](https://github.com/pointfreeco/swift-perception) | 2.0.10 | 2.0.12 |
| [swift-sharing](https://github.com/pointfreeco/swift-sharing) | 2.9.0 | 2.10.1 |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | 603.0.2 | 604.0.0 |
| [swiftlintplugins](https://github.com/SimplyDanny/SwiftLintPlugins) | 0.65.0 | 0.65.1 |
| [swiftsdk](https://github.com/TelemetryDeck/SwiftSDK) | 2.14.1 | 2.14.2 |

Already current: Kanna 6.1.0, SDWebImage 5.21.7, SDWebImageSwiftUI 3.1.4,
SDWebImageWebPCoder 0.15.0, SFSafeSymbols 7.0.0, SwiftyOpenCC 2.1.0,
swift-identified-collections 1.1.1 and swift-snapshot-testing 1.19.6.

The dependency workflow now uses the project's Xcode 27 runner and updates the local package
with SwiftPM, then synchronizes and validates both lockfiles. It previously selected Xcode 26.5
and used an Xcode-project update action despite dependencies living in the local package.

## Test execution

`FeatureTests` now excludes the three classes requiring capture configuration in the test plan
itself. `VisualTests` includes the complete app-hosted visual target. The capture, geometry and
regression scripts select `VisualTests` and continue to supply their required environment.

The push workflow runs functional tests without command-line exclusions. A separate manually
triggered visual workflow validates the committed rendering pin before running the existing
32-scene native full-content gate and uploading evidence. It requires the pinned Xcode 27.0
installation and dedicated simulators. The pin is unchanged; Xcode 27.1 cannot substitute for it.
This gate is separate from the full locale/theme/text-size regression matrix.

Python runner contracts now generate deterministic temporary fixtures instead of depending on an
ignored local capture directory. The native fixture-export test checks all 47 generated image
assets; Python integrity tests independently exercise byte counts, hashes and metadata validation.

## Deliberate compatibility boundary

The haptics architecture is intentionally unchanged at the owner's request.

`LegacyCFReadStream` still contains `CFReadStreamCreateForHTTPRequest`. Its existing domain-fronting
contract requires independently controlled connection address, HTTP Host and original-domain trust.
The earlier DEP-06 investigation found no equivalent modern replacement. This migration does not
remove that behavior or widen its pre-existing, module-scoped warning policy. Other callback bridges
remain where framework lifetime/queue requirements still require them (file coordination, background
URLSession delegates, cookie persistence and render settlement).

## Verification

Regression coverage includes malformed/truncated and unaligned GIF/APNG/WebP data, valid and repaired
UTF-8 including embedded NUL, Unicode/quoted tag completion, directory-hint-independent download
containment, symbolic-link preservation, and torrent sharing only after a successful async write.

- Device Release build: passed with the iOS 27.1 SDK and no compiler warnings.
- FeatureTests on iPhone Air / iOS 27.0: 1,356 passed, 10 existing expected failures, zero unexpected
  failures. This includes every package test target and the general app-hosted rendering tests.
- Native visual fixture export: both tests passed through `VisualTests`, including all 47 images,
  repeatable hashes and reader-image pixel dimensions.
- UI test target: compiled with all six feature flags and no compiler warnings.
- Visual runner contracts: all 185 Python tests passed without a pre-existing capture directory.
- Strict SwiftLint 0.65.1: passed across app, extension, package manifest, sources and tests, and UI tests.
- Both dependency lockfiles match; `git diff --check` passes.
- The compiled request-effect object references Swift's native async Result initializer, verified
  from its symbols, rather than ConcurrencyExtras' overlapping backport.

`FullContentFeasibilityTests`, `VisualMatrixTests` and `GeometryTests` require separately supplied
system text sizes, orientations and/or coordinate fixtures through the visual scripts. Their test
plan split is described above. The complete visual matrix was not run as part of this migration;
no capture assertions were weakened. The pinned Xcode 27.0 installation is not available on this
host, so the existing environment contract was preserved rather than redefined for Xcode 27.1.

Native navigation/search verification from the initial migration:

- iPhone Air / iOS 27.0: all seven selected UI tests passed. They cover Detail's standard, AX1,
  AX3 and AX5 titles, partial-header visibility, returning from Search, standard Search audits,
  and AX5 Quick Search, query entry and rotation behavior.
- iPad Pro 11-inch (M5) / iPadOS 27.0: the same seven UI tests passed. Both devices completed
  exactly seven test runs, with no failures, skips or retries.
- Search cold entry and live system Dynamic Type changes were manually checked on the dedicated
  iPhone Air and iPad simulators at standard, AX1, AX3 and AX5, including return to standard size.
  Screenshots confirm the native search field remains visible after live changes even when the
  UI automation tool's accessibility outline omits that field. Native title/search behavior and
  sheet title modes were retained; no accessibility-specific layout branches were added.

Pre-integration follow-up evidence:

- Full functional suite: `/tmp/ehpanda-swift64-followup-feature-final2.xcresult`.
- Native fixture exports: `/tmp/ehpanda-swift64-followup-visual-export.xcresult`.
- Device Release build: `/tmp/ehpanda-swift64-followup-release-final.log`.
- UI test build: `/tmp/ehpanda-swift64-followup-ui-build-final.log`.
- Compiler feature audit: `/tmp/ehpanda-swift64-followup-flag-audit.json`.
- Python contracts: `/tmp/ehpanda-swift64-followup-python-final.log`.
- Strict lint: `/tmp/ehpanda-swift64-followup-lint-final.json`.

The initial migration's navigation/search runs remain available at
`/tmp/ehpanda-swift64-ui-phone-final.xcresult` and `/tmp/ehpanda-swift64-ui-pad-final.xcresult`.

## Integration with the current feature branch

The migration was cherry-picked onto `feature/gsd-phase-17` after its newer Live Text translation
work. The translation module and its tests are included in the 73-module feature-flag audit.
Its public API imports and the reader tests' defining-module imports are explicit; the reader
suite declares its AppComponents dependency. Its bitmap construction uses typed Core Graphics
configuration, and the preview uses `scaledToFit()`. Debug-only download test imports are compiled
only with their declarations, avoiding unused-public-import warnings in Release.

- Full integrated functional suite: 1,356 passed, 10 existing expected failures, zero failures or
  skipped tests (`/tmp/ehpanda-swift64-integration-feature2.xcresult`).
- Device Release: passed with zero compiler warnings
  (`/tmp/ehpanda-swift64-integration-release-final.log`).
- UI test target: compiled with zero warnings (`/tmp/ehpanda-swift64-integration-ui-build.log`).
- Strict SwiftLint: zero violations (`/tmp/ehpanda-swift64-integration-lint-final.json`).
- All 73 app-owned modules use Swift 6 mode and all six feature flags
  (`/tmp/ehpanda-swift64-integration-flag-audit.json`).

## References

- [Swift 6.4 release](https://www.swift.org/blog/swift-6.4-released/)
- [Swift migration guide](https://www.swift.org/migration/documentation/migrationguide/)
- Installed Swift 6.4 standard-library and iOS 27.1 SwiftUI/Foundation interfaces were used to
  verify actual signatures and availability. Dependency repositories above supply the release tags
  and async API source used during migration.
