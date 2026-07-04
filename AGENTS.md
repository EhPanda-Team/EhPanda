# AGENTS.md

This file gives coding agents a reliable working guide for this repository.

## Programming Instructions

**Reducer naming convention**: Name reducers with a `Feature` suffix, for example `SettingFeature`. This is a project preference that overrides TCA's standard naming convention and any conflicting guidance from skills, training data, or search results. Follow it unless the user directly instructs otherwise.

**SwiftLint coverage for new modules**: When adding a new module, create a `.swiftlint.yml` file at that module's root. Configure it to reference the appropriate parent SwiftLint config with `parent_config` (`parent_config: ../../../.swiftlint.yml` for a module under `AppPackage/Sources`) so the project's SwiftLint rules cover the new module.

**Read SwiftLint rules**: Before writing or changing Swift code, read the root `.swiftlint.yml` to learn the project's lint rules, including the custom regex rules and banned APIs it defines. Write code that conforms to those rules from the start, and resolve every violation at its root. Suppressing a rule, disabling it, adding a `// swiftlint:disable`, or otherwise removing it, is forbidden without the user's explicit permission.

**Labeled localized-format arguments**: Surface every *numeric* localized-format argument as a labeled Swift parameter via a named `%#@variable@` substitution: module-local keys generate `func key(variable: Int)`; shared keys carry semantic labels hand-written in `ResourceStringSymbols.swift`. Never put a bare numeric specifier (`%lld`, `%d`, …) in a module-local catalog's outer value or top-level plural variant. Keep *string* (`%@`) arguments positional (auto-generated `func key(_ arg1: String)`); never make a `String` a substitution. Keep substitution plural categories coherent: a variable's `en` category set must equal its `de` set; `ja`/`ko`/`zh-Hans`/`zh-Hant` are `other`-only.

**Confirmation dialog / alert placement**: Attach a `.confirmationDialog`/`.alert` modifier to a UI element that is both **stable** (stays in the hierarchy until the dialog is dismissed — being `.disabled` is fine, being removed or `.opacity`-hidden is not) and the **action source** (the control that triggers it). On iPad these render as popovers anchored to the view the modifier is attached to, so the anchor must be the triggering control for the arrow to point at the right place; and if that view leaves the hierarchy while the dialog is up, the dialog is torn down with it. Do not move such a modifier onto a transient or unrelated container (a whole `Form`/`List`, or a view gated by a condition) for convenience — keep it on the triggering button/row. When the trigger lives inside a subview, thread the store-scoped dialog binding into that subview and attach it there rather than hoisting the modifier to an ancestor. Exception: for a per-row destructive action whose row can scroll out of view, the stable action-source is the enclosing list container, so attach it there.

## Project structure

EhPanda is being modularized to match the App-shell + local-package layout:

- `App/` — the thin app-shell target. No business logic; it imports `AppFeature` and renders the root view.
- `AppPackage/` — a local Swift package that holds all logic. Each module is a directory under `AppPackage/Sources/<Module>`, with tests under `AppPackage/Tests/<Module>Tests`.
- `ShareExtension/` — the share extension target.
- `EhPanda.xcodeproj` — references `AppPackage` as a local Swift package (`XCLocalSwiftPackageReference`); the app target links the `AppFeature` product.

All third-party dependencies are declared in `AppPackage/Package.swift`, not in the Xcode project.
