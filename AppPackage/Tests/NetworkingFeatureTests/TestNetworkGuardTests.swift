import Foundation
import Testing

/// The test network guard that `Package.swift` links into every package test target: in a test process, a request no
/// test stubbed fails at once, offline, instead of reaching the site (18-UAT gap: FeatureTests reached e-hentai.org).
///
/// It covers the shared session, which every request type uses unless handed another, and every session built from the
/// default or the ephemeral configuration, as the download client, the image cache and the analytics SDK build theirs.
/// The probe's host is a reserved `.invalid` name, so the case cannot reach a server even where the guard is missing.
struct TestNetworkGuardTests {
    enum SessionKind: String, CaseIterable, Sendable {
        case shared
        case defaultConfiguration
        case ephemeralConfiguration

        var session: URLSession {
            switch self {
            case .shared: .shared
            case .defaultConfiguration: URLSession(configuration: .default)
            case .ephemeralConfiguration: URLSession(configuration: .ephemeral)
            }
        }
    }

    @Test(arguments: SessionKind.allCases)
    func anUnstubbedRequestFailsOfflineInsteadOfReachingTheNetwork(kind: SessionKind) async throws {
        let url = try #require(URL(string: "https://guard-probe.invalid/g/1/token/"))

        let error = await #expect(throws: URLError.self) {
            _ = try await kind.session.data(from: url)
        }

        #expect(error?.code == .notConnectedToInternet)
        #expect(
            error?.userInfo[Self.guardKey] as? Bool == true,
            "Not failed by the guard: \(String(describing: error))"
        )
    }

    /// The `userInfo` key the guard marks its failures with.
    private static let guardKey = "EhPandaTestNetworkGuard"
}
