# Testing Patterns

**Analysis Date:** 2026-07-09

## Test Framework

**Runner:**
- **Swift Testing** (`import Testing`) — `@Suite` / `@Test` / `#expect`. NOT XCTest.
- TCA `TestStore` from ComposableArchitecture for reducer assertions.
- Config: driven by SPM test targets in `AppPackage/Package.swift`; no separate runner config file.

**Assertion Library:**
- Swift Testing `#expect(...)` / `#require(...)`.
- TCA exhaustive state assertions via `TestStore.send`/`receive` trailing mutation closures.

**Run Commands (Xcode-only — bare `swift build`/`swift test` fail; memory):**
```bash
# Run all package tests (use the AppPackage-Package scheme)
xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16'
# Run ONE test invocation at a time — never run overlapping xcodebuild test (wedges testmanagerd; memory)
```

## Test File Organization

**Location:**
- Separate test targets under `AppPackage/Tests/<Module>Tests/`, mirroring
  `AppPackage/Sources/<Module>`. 87 test files across 7 test targets.
- Existing test targets: `SettingFeatureTests`, `FileClientTests`, `DetailFeatureTests`,
  `DownloadsFeatureTests`, `AppModelsTests`, `ParserFeatureTests`, `NetworkingFeatureTests`.

**Naming:**
- `<Subject>Tests.swift`, e.g. `CommentsReducerTests.swift`, `DownloadProcessTests.swift`.
- Shared helpers/factories per target: `DownloadFeatureTestHelpers.swift`,
  `DownloadFeatureTestFactories.swift`.

**Lint:** each test target has its own `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml`.

## Test Structure

**Suite Organization (actual pattern from `CommentsReducerTests.swift`):**
```swift
import Testing
import Foundation
import AppModels
import HapticsClient
@testable import DetailFeature
import ComposableArchitecture

@Suite
struct CommentsReducerTests {
    @MainActor
    @Test
    func presentingPostCommentResetsStaleComposeState() async {
        let store = TestStore(
            initialState: CommentsReducer.State(galleryURL: .mock),
            reducer: CommentsReducer.init          // Reducer.init shorthand (lint-enforced)
        ) {
            $0.hapticsClient = .noop               // override dependencies in trailing closure
        }

        await store.send(.presentPostComment(commentID: "42", content: "existing text")) {
            $0.commentContent = "existing text"    // exhaustive expected state mutation
            $0.destination = .postComment("42")
        }
    }
}
```

**Patterns:**
- Reducers under test are `TestStore`-driven with **exhaustive** state assertions.
- Tests are `@MainActor @Test`, `async`.
- Regression tests carry a comment describing the bug they lock down.
- The subject module is imported `@testable`; sibling modules imported normally.

## Mocking

**Framework:** TCA Dependencies — override on the `TestStore` init trailing closure.

**Patterns:**
```swift
// Override each client used by the reducer:
TestStore(initialState: ..., reducer: Feature.init) {
    $0.hapticsClient = .noop
    $0.fileClient = .testValue
}
```
- Clients expose `liveValue`, `testValue` (usually `.unimplemented`, which fails on
  unexpected calls), and `.noop` (see `AppPackage/Sources/HapticsClient/HapticsClient.swift`).
- `withDependencies { } operation:` used where a `Store` isn't the entry point
  (~26 test files use `withDependencies`).
- `.mock` static fixtures on model types (e.g. `.mock` galleryURL) supply sample values.

**What to Mock:**
- All injected `@Dependency` clients (network, file, haptics, clipboard, etc.).
- Override `testValue`'s unimplemented endpoints only for the calls a test expects.

**What NOT to Mock:**
- Don't use the live `dataCache` dependency in image tests — it causes cross-test
  pollution; inject a per-test `DataCache` and compare pixel dims, not point size
  (`DataCacheTests.swift`).
- Fix parallel-test pollution by **injecting** the global dependency (e.g. host param),
  not by `.serialized` (memory: "Inject over serialize").

## Fixtures and Factories

**Test data:**
- `TestingSupport` module bundles HTML/resource fixtures. Access via `TestFixtures.url(...)`
  and the `TestHelper` protocol's `htmlDocument(filename:)` — routing through
  `TestingSupport`'s own `Bundle.module` (a plain test bundle's `Bundle.module` is
  resource-less). See `AppPackage/Sources/TestingSupport/`:
  `TestFixtures.swift`, `TestHelper.swift`, `HTMLFilename.swift`, `TestError.swift`, `Resources/`.
- Per-target factory files build domain objects: `DownloadFeatureTestFactories.swift`.
- `.mock` static properties on models for inline sample values.

**Location:**
- Shared, reusable fixtures: `AppPackage/Sources/TestingSupport/`.
- Target-local helpers/factories: alongside the tests in `AppPackage/Tests/<Module>Tests/`.

## Coverage

**Requirements:** none enforced in config. Coverage is behavioral/regression-driven —
new tests are added to lock down specific fixed bugs and migration paths.

**Notable suites:**
- Schema migration engine: `SchemaMigrationTests.swift` (54 tests incl. nested-schema
  mocks + `ProgressiveMock`; delete mocks when a real v2 schema lands — memory).
- Model migration: `mock-v2` migration tests across all models (`AppModelsTests`).

## Test Types

**Unit / reducer tests:**
- Dominant style — `TestStore` exhaustive assertions per reducer action.

**Integration tests:**
- Multi-reducer/flow tests in `DownloadsFeatureTests` (background processing, coordinator
  capture/storage, enqueue manifest, reading dismiss flows).
- Parser tests exercise real HTML fixtures via `TestHelper`/`TestFixtures`.

**E2E / UI tests:** not used (no XCUITest target found).

## Common Patterns

**Async testing:**
```swift
@MainActor @Test
func example() async {
    await store.send(.action) { $0.field = expected }
    await store.receive(\.delegate.something)
}
```

**Determinism:**
- A previously flaky suite (`DownloadSchedulingTests`) was made deterministic
  (commit 557b0425); a failure there now signals a REAL regression, not flake (memory).
- Never run overlapping `xcodebuild test`; run one invocation at a time (memory).

---

*Testing analysis: 2026-07-09*
