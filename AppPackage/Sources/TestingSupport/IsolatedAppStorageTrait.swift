import ComposableArchitecture
public import Foundation
import Sharing
public import Testing

/// Runs `operation` with a fresh plain-named `UserDefaults` suite, and removes that suite's persistent domain when
/// `operation` returns or throws.
///
/// The `.isolatedAppStorage` trait gives every test case its suite this way. A case that needs a second suite beside
/// its own calls this directly.
public func withIsolatedAppStorage<Result>(
    _ operation: (UserDefaults) async throws -> Result
) async throws -> Result {
    let suiteName = "isolated-app-storage-\(UUID().uuidString)"
    let appStorage = try #require(UserDefaults(suiteName: suiteName))
    defer {
        appStorage.removePersistentDomain(forName: suiteName)
    }
    return try await operation(appStorage)
}

/// Gives each test case its own plain-named `UserDefaults` suite as `defaultAppStorage`, and removes that suite's
/// persistent domain when the case ends (quick task 261123-bcj, D-1).
///
/// Why not Sharing's `UserDefaults.inMemory`, which is also the `defaultAppStorage` dependency's test value: on iOS 17
/// and later it names its suite by a path under `NSTemporaryDirectory()`, which makes the suite file-backed, and in the
/// simulator test process, under parallel load, file-backed suites can stop reflecting new writes. A later read then
/// returns an earlier value, whether it is a fresh `@Shared` reference loading from the suite or the app-storage key's
/// external-change subscription reloading into a live one. A plain-named suite stays read-after-write consistent.
///
/// Applied to a suite, the trait is recursive and scopes each test case: every argument of a parameterized test and
/// every test of a nested suite gets a suite of its own. Everything a case builds inherits it through the task-local
/// dependencies (a `TestStore` or `Store` builds its reducer on them, and a reducer state's `@Shared` property is built
/// on them), unless the case overrides `defaultAppStorage` itself; a case that needs the `UserDefaults` value reads
/// `@Dependency(\.defaultAppStorage)`. Put it once, on the outermost suite type, on every suite whose files import a
/// module that reads app storage or use app storage directly.
///
/// `Scripts/lint/app_storage_isolation.py` states which suites those are, and the lint gate fails on a suite it
/// selects that lacks the trait.
public struct IsolatedAppStorageTrait: SuiteTrait, TestScoping, TestTrait {
    public var isRecursive: Bool { true }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @concurrent () async throws -> Void
    ) async throws {
        try await withIsolatedAppStorage { appStorage in
            try await withDependencies {
                $0.defaultAppStorage = appStorage
            } operation: {
                try await function()
            }
        }
    }
}

extension Trait where Self == IsolatedAppStorageTrait {
    /// Isolates the app storage of every test case in the suite or test it is applied to; see
    /// ``IsolatedAppStorageTrait``.
    public static var isolatedAppStorage: Self { Self() }
}
