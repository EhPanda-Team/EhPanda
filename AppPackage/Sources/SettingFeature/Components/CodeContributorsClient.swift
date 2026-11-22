import AppModels
import ComposableArchitecture
import Foundation
import NetworkingFeature

/// The About page's one call to GitHub, behind a substitutable seam.
///
/// The reducer's fetch state machine (loading, failure, retry, the once-only guard) cannot be tested while it
/// reaches for `GitHubContributorsRequest` directly, because the test network guard fails every unstubbed
/// request. Injecting the call lets a `TestStore` script success and failure offline.
///
/// This is substitutability for a side-effecting call, not a rename: `live` is the request unchanged.
struct CodeContributorsClient: Sendable {
    /// Fetches GitHub's contributor list for the repository, unfiltered.
    var fetch: @Sendable () async throws(AppError) -> [GitHubContributor]
}

extension CodeContributorsClient {
    static let live = Self(fetch: fetchContributors)

    // Spelled as a function rather than a closure literal so the typed `throws(AppError)` survives:
    // a closure literal infers `any Error` here and loses the request layer's typed failure.
    private static func fetchContributors() async throws(AppError) -> [GitHubContributor] {
        try await GitHubContributorsRequest().response()
    }
}

// MARK: API
enum CodeContributorsClientKey: DependencyKey {
    static let liveValue = CodeContributorsClient.live
    static let testValue = CodeContributorsClient.unimplemented
}

extension DependencyValues {
    var codeContributorsClient: CodeContributorsClient {
        get { self[CodeContributorsClientKey.self] }
        set { self[CodeContributorsClientKey.self] = newValue }
    }
}

// MARK: Test
extension CodeContributorsClient {
    /// Reports an issue and throws, so a test that reaches a fetch it did not override fails that
    /// test without ending the test process.
    static let unimplemented = Self(
        fetch: IssueReporting.unimplemented(throwing: AppError.unknown)
    )
}
