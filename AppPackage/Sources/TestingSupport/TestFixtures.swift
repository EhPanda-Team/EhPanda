import Foundation

/// Accessor for the test fixtures bundled with `TestingSupport`.
///
/// Test targets that depend on `TestingSupport` cannot reach these resources through their own
/// `Bundle.module`, which resolves to the (resource-less) test bundle. Routing through this type
/// resolves `Bundle.module` inside `TestingSupport`, where the fixtures actually live.
public enum TestFixtures {
    public static func url(forResource name: String, withExtension ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
    }
}
