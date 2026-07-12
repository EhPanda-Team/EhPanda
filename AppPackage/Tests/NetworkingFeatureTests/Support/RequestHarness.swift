import AppModels
import Foundation
import Testing

/// Captures a concrete request's typed-throws response as a `Result` for parity assertions.
///
/// The operation is deliberately supplied as a closure. A generic helper constrained to `Request`
/// would dispatch a protocol-extension implementation statically, so after a concrete request gains
/// its async response method the test could silently keep exercising the legacy Combine facade.
/// Forming the call on the concrete request inside this closure guarantees the intended path runs.
func capture<T: Sendable>(
    _ operation: () async throws(AppError) -> T
) async -> Result<T, AppError> {
    do throws(AppError) {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

/// Compares complete URL semantics without treating query-item ordering as significant.
func expectEquivalentURL(
    _ actual: URL?,
    _ expected: URL,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let actualComponents = actual.flatMap {
        URLComponents(url: $0, resolvingAgainstBaseURL: false)
    }
    let expectedComponents = URLComponents(
        url: expected,
        resolvingAgainstBaseURL: false
    )

    #expect(actualComponents?.scheme == expectedComponents?.scheme, sourceLocation: sourceLocation)
    #expect(actualComponents?.user == expectedComponents?.user, sourceLocation: sourceLocation)
    #expect(actualComponents?.password == expectedComponents?.password, sourceLocation: sourceLocation)
    #expect(actualComponents?.host == expectedComponents?.host, sourceLocation: sourceLocation)
    #expect(actualComponents?.port == expectedComponents?.port, sourceLocation: sourceLocation)
    #expect(actualComponents?.path == expectedComponents?.path, sourceLocation: sourceLocation)
    #expect(actualComponents?.fragment == expectedComponents?.fragment, sourceLocation: sourceLocation)
    #expect(
        sortedQueryItems(actualComponents) == sortedQueryItems(expectedComponents),
        sourceLocation: sourceLocation
    )
}

private func sortedQueryItems(_ components: URLComponents?) -> [URLQueryItem] {
    (components?.queryItems ?? []).sorted {
        ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "")
    }
}
