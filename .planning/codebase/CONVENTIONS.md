# Coding Conventions

**Analysis Date:** 2026-07-09

EhPanda is a Swift/SwiftUI + Composable Architecture (TCA) app, modularized into a
thin app-shell (`App/`) plus a local Swift package (`AppPackage/`) holding all logic.
Conventions are enforced at build time by SwiftLint (`.swiftlint.yml` at repo root,
inherited by every module via `parent_config`). Treat lint rules as authoritative:
suppressing, disabling, or `// swiftlint:disable` is forbidden without explicit user
permission (`CLAUDE.md`).

## Naming Patterns

**Files:**
- One primary type per file, filename matches the type: `AppearanceSettingReducer.swift`,
  `HapticsClient.swift`, `CommentsReducerTests.swift`.
- Reducer bodies/helpers split via extension files with `+` suffix:
  `SettingReducer+Body.swift`, `SettingReducer+Helpers.swift`.
- Extension-only support files use `+.swift`: `Logger+.swift`.

**Reducers:**
- **Reducers use the `Feature`/`Reducer` suffix per the domain.** Project override in
  `CLAUDE.md`: name reducers with a `Feature` suffix (e.g. `SettingFeature`) — this
  overrides TCA's standard naming and any conflicting skill/search guidance. Existing
  code uses both `...Reducer` (e.g. `AppearanceSettingReducer`, `AppReducer`) and
  `...Feature`; follow the module's local suffix, and prefer `Feature` for new reducers
  unless the user says otherwise.
- Module directories under `AppPackage/Sources/` end in `Feature` (UI/logic) or `Client`
  (dependency wrappers): `DetailFeature`, `SettingFeature`, `HapticsClient`, `FileClient`.

**Functions / Variables:**
- Standard Swift lowerCamelCase functions, UpperCamelCase types.
- **Date properties must use a noun form, never an `At` suffix** (custom lint rule
  `date_property_at_suffix`): use `creationDate`, not `createdAt`.
- Localized-format numeric arguments are surfaced as labeled Swift params via named
  `%#@variable@` substitutions; string (`%@`) args stay positional (`CLAUDE.md`).

**Types:**
- Reducers annotated `@Reducer`, marked `public struct ... : Sendable`.
- Nested `State` is `@ObservableState public struct State: Equatable, Sendable`.
- Nested `Action` is `public enum Action: Equatable, Sendable`.
- **`Delegate` enum is a sibling of `Action`, not nested inside it** (max 1 level of
  nesting; TCA convention noted in memory). See `AppearanceSettingReducer.swift`.

## Code Style

**Formatting:**
- Enforced by SwiftLint (`.swiftlint.yml`), run as a build-tool plugin
  (`SwiftLintBuildToolPlugin`, declared in `AppPackage/Package.swift`).
- `line_length`: 120 (warning AND error at 120 — hard limit).
- `file_length`: 1000 (warning AND error).
- `opening_brace`, `type_body_length`, `function_body_length`, `cyclomatic_complexity`,
  `multiple_closures_with_trailing_closure` are disabled.

**Linting — opt-in strict rules (severity: error):**
- `force_try` — banned.
- `force_unwrapping` — banned.

**Custom regex rules (all severity: error) — write conforming code from the start:**
- `no_nslock` — use `Mutex` (Synchronization), not `NSLock`.
- `no_preconcurrency` — `@preconcurrency` banned; fix the real Sendable issue.
- `no_unchecked_sendable` — `@unchecked Sendable` banned; use a real value type, actor, or Mutex.
- `system_name_image_parameter` — use `systemSymbol:`, never `systemName:`/`systemImage:` (SFSafeSymbols).
- `shape_initializer_argument` — use SwiftUI shape shorthand for standalone shape args.
- `label_text_image_shorthand` — use `Label(_ titleResource:systemSymbol:)`.
- `accessibility_empty_string` — never pass `""`/`Text(verbatim: "")` to accessibility modifiers.
- `accessibility_text_argument` — pass a `LocalizedStringResource`/`String` to accessibility
  modifiers, not `Text(...)`.
- `no_case_check_property` — don't add a computed `Bool` that only wraps an `if case` enum
  check; check the case at the call site (`value.is(\.case)` for `@CasePathable`).
- `child_reducer_shorthand_scope` — use `Scope(state:action:child: Reducer.init)`.
- `child_reducer_shorthand_foreach` — use `.forEach(_:action:element: Reducer.init)`.
- `child_reducer_shorthand_store` — use `Store/TestStore(initialState:reducer: Reducer.init)`.
- `swiftlint_disable_requires_reason` — any `swiftlint:disable` needs a preceding `// reason:` comment.

**New module setup:** add a `.swiftlint.yml` at the module root referencing the parent
config (`parent_config: ../../../.swiftlint.yml` for a module under `AppPackage/Sources`).
See `CLAUDE.md` and existing per-module configs.

## Import Organization

Imports are grouped loosely by dependency kind; no strict alphabetization enforced. Common order:
1. System / framework (`import Foundation`, `import SwiftUI`)
2. Third-party (`import ComposableArchitecture`, `import Kanna`)
3. Local modules (`import AppModels`, `import ApplicationClient`)

**Path aliases:** none (no `@` TS-style aliases — this is Swift). Cross-module access is
via explicit `import <ModuleName>`. Package products are aliased in `Package.swift`
(`static let composableArchitecture: Self = ...`).

## Error Handling

- `force_try` and `force_unwrapping` are lint errors — handle every error explicitly.
- Throwing APIs use typed error enums (e.g. `TestError` in `TestingSupport`) with `guard ... else { throw }`.
- Reducer side effects run in `.run { }` closures; async work uses `await`.
- No `@unchecked Sendable` / `@preconcurrency` escape hatches (banned).

## Logging

**Framework:** OSLog via a project `Logger` wrapper (`OSLogExt` module, `Logger+.swift`).

**Patterns (per memory + code):**
- `Logger+.swift` is init-only; declare a `private let logger` at the top of *each file*
  that logs: `private let logger = Logger(category: .init(describing: SettingReducer.self))`.
- Do not share one logger across files.

## Comments

**When to Comment:**
- Explain the WHY of non-obvious deliberate designs — their absence makes intentional
  designs read as bugs (memory: "Document deliberate designs"). See the header comment in
  `AppearanceSettingReducer.swift` explaining the `@Shared` write-through.
- Regression tests carry a comment explaining the bug they guard against
  (`CommentsReducerTests.swift`).

**DocC:** `///` doc comments used on public helpers/types (e.g. `TestFixtures`).

## Function / Reducer Design

- Reducer `body` is `public var body: some Reducer<State, Action>` composing
  `Reduce { state, action in switch action { ... } }` plus child `Scope`/`forEach` via
  `Reducer.init` shorthand.
- Bind case payloads with `case .x(let value):` inside the switch.
- Empty/no-effect branches `return .none`; side effects `return .run { ... }`.
- **Don't leave empty TCA action stubs** — delete the case and all its call sites when a
  behavior is removed (memory: "Remove emptied actions").
- Extract duplicated state+actions across reducers into a self-contained sub-reducer
  (memory: "Extract duplicated reducer logic").

## Module Design

- **Exports:** all cross-module types/members are explicitly `public`; `init()` is `public`.
  Extracting a module triggers a public/Sendable/init cascade (memory).
- **Dependencies** injected via `@Dependency(\.someClient) private var someClient` (TCA
  Dependencies). Clients live in their own `...Client` module with `liveValue`,
  `testValue` (usually `.unimplemented`), and a `.noop` (see `HapticsClient.swift`);
  some use `@DependencyClient`.
- All third-party deps declared once in `AppPackage/Package.swift`, never in the Xcode project.
- Concurrency posture: `InferIsolatedConformances` + `NonisolatedNonsendingByDefault`
  upcoming features enabled (`sharedSwiftSettings` in `Package.swift`); write Swift-6-clean code.

---

*Convention analysis: 2026-07-09*
