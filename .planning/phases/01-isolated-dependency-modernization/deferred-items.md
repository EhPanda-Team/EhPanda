# Deferred Items — Phase 01

Out-of-scope discoveries logged during execution. Not fixed in the current plan; tracked for a later plan or milestone pass.

## From 01-05 (DEP-03 markdown migration)

- **Acknowledgements still credit SwiftCommonMark, not swift-markdown.**
  - Files: `AppPackage/Sources/SettingFeature/Components/AboutView.swift` (rows for `acknowledgementSwiftCommonMark` / `acknowledgementSwiftCommonMarkLink`) and `AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings` (keys `acknowledgement.swiftCommonMark`, `acknowledgement.swiftCommonMark_link`).
  - Why deferred: 01-05 Task 3 explicitly scopes attribution/resource changes out unless the build requires them. Removing the SwiftCommonMark package does not break `AboutView` (it references localized strings, not the package symbol), so the build stays green without touching acknowledgements.
  - Follow-up: an acknowledgements pass should replace the SwiftCommonMark credit with an Apple swift-markdown credit (`https://github.com/apple/swift-markdown`), honoring the AGENTS.md `.xcstrings` all-locale rule (fill every supported locale) and the labeled-argument rules. This also applies to the other dependencies removed earlier in Phase 01 (SwiftyOpenCC, UIImageColors) if their acknowledgements remain.

## From 01-07 (DEP-07 Colorful update)

- **`ColorfulView` is deprecated upstream in Colorful 1.1.x with no in-package replacement. — RESOLVED (01-08).**
  - **Resolution (01-08):** the user chose option (a) below. Colorful was removed and the gallery gradient migrated to ColorfulX `6.1.0` (Metal); `HomeFeature` now builds warning-free. See `01-08-SUMMARY.md` and `01-COLORFUL-UAT.md`. Original context retained below.
  - Files: `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` (lines 45 and 72 reference `ColorfulView` / `ColorfulView.defaultColorList`).
  - What happens: building `HomeFeature` on the research-approved latest Colorful (`1.1.1`) emits `'ColorfulView' is deprecated: This library hurts CPU alot, use Metal program from https://github.com/Lakr233/ColorfulX instead.` The build still succeeds (no `-warnings-as-errors`), and the animated gradient renders as before.
  - Why deferred: plan 01-07 explicitly forbids satisfying DEP-07 through another gradient path or deleting Colorful, and the whole `ColorfulView` struct is deprecated (there is no non-deprecated Colorful view API to migrate to), so a fully warning-free adoption is not achievable inside this plan's scope. The residual warning is upstream-sourced, not a project code defect, and it is not suppressed.
  - Follow-up (needs a user decision at `$gsd-verify-work`): either (a) migrate the gallery gradient to the upstream-recommended ColorfulX (Metal) package, (b) implement an app-owned SwiftUI gradient view that reproduces the same animated concept, or (c) accept the deprecation notice and keep Colorful 1.1.1. Option (a)/(b) would remove the warning; both are out of scope for the isolated-dependency-modernization phase.

- **Pre-existing, unrelated compiler warning in `DownloadsFeatureTests`.**
  - File: `AppPackage/Tests/DownloadsFeatureTests/ReadingReducerLocalTests.swift:23` — `variable 'state' was never mutated; consider changing to 'let' constant`.
  - Why deferred: surfaced during the 01-07 build but is unrelated to the Colorful update (a downloads test). Out of scope per the executor scope boundary; left untouched.
