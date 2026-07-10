# Deferred Items — Phase 01

Out-of-scope discoveries logged during execution. Not fixed in the current plan; tracked for a later plan or milestone pass.

## From 01-05 (DEP-03 markdown migration)

- **Acknowledgements still credit SwiftCommonMark, not swift-markdown.**
  - Files: `AppPackage/Sources/SettingFeature/Components/AboutView.swift` (rows for `acknowledgementSwiftCommonMark` / `acknowledgementSwiftCommonMarkLink`) and `AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings` (keys `acknowledgement.swiftCommonMark`, `acknowledgement.swiftCommonMark_link`).
  - Why deferred: 01-05 Task 3 explicitly scopes attribution/resource changes out unless the build requires them. Removing the SwiftCommonMark package does not break `AboutView` (it references localized strings, not the package symbol), so the build stays green without touching acknowledgements.
  - Follow-up: an acknowledgements pass should replace the SwiftCommonMark credit with an Apple swift-markdown credit (`https://github.com/apple/swift-markdown`), honoring the AGENTS.md `.xcstrings` all-locale rule (fill every supported locale) and the labeled-argument rules. This also applies to the other dependencies removed earlier in Phase 01 (SwiftyOpenCC, UIImageColors) if their acknowledgements remain.
