# AGENTS.md

This file gives coding agents a reliable working guide for this repository.

## Programming Instructions

**Reducer naming convention**: Name reducers with a `Feature` suffix, for example `SettingFeature`. This is a project preference that overrides TCA's standard naming convention and any conflicting guidance from skills, training data, or search results. Follow it unless the user directly instructs otherwise.

**SwiftLint coverage for new modules**: When adding a new module, create a `.swiftlint.yml` file at that module's root. Configure it to reference the appropriate parent SwiftLint config with `parent_config` (`parent_config: ../../../.swiftlint.yml` for a module under `AppPackage/Sources`) so the project's SwiftLint rules cover the new module.

**Read SwiftLint rules**: Before writing or changing Swift code, read the root `.swiftlint.yml` to learn the project's lint rules, including the custom regex rules and banned APIs it defines. Write code that conforms to those rules from the start, and resolve every violation at its root. Suppressing a rule, disabling it, adding a `// swiftlint:disable`, or otherwise removing it, is forbidden without the user's explicit permission.

## Project structure

EhPanda is being modularized to match the App-shell + local-package layout:

- `App/` — the thin app-shell target. No business logic; it imports `AppFeature` and renders the root view.
- `AppPackage/` — a local Swift package that holds all logic. Each module is a directory under `AppPackage/Sources/<Module>`, with tests under `AppPackage/Tests/<Module>Tests`.
- `ShareExtension/` — the share extension target.
- `EhPanda.xcodeproj` — references `AppPackage` as a local Swift package (`XCLocalSwiftPackageReference`); the app target links the `AppFeature` product.

All third-party dependencies are declared in `AppPackage/Package.swift`, not in the Xcode project.
