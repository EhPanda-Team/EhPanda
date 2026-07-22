import AppModels
import ComposableArchitecture
import Foundation
import NetworkingFeature

/// The login POST, behind a substitutable seam.
///
/// The Cloudflare flow turns a single request into a small state machine — detect the wall, present the
/// challenge, replay the POST with the captured clearance, and give up after a bounded number of rounds.
/// That machine is worth testing, and it cannot be tested while the reducer reaches for `LoginRequest`
/// directly, because every round would need a live Cloudflare-fronted host to answer it. Injecting the
/// call lets a `TestStore` script the exact sequence of responses each round should see, offline.
///
/// This is substitutability for a side-effecting call, not a rename: `NetworkingFeature` keeps its
/// request structure untouched, and `live` is behaviourally identical to the direct call it replaces.
struct LoginClient: Sendable {
    /// Posts the login form, optionally replaying a clearance earned by a challenge web view.
    ///
    /// Passing `nil` for `clearance` produces the ordinary, byte-identical pre-challenge request.
    let login: @Sendable (
        _ username: String,
        _ password: String,
        _ clearance: CloudflareClearance?
    ) async throws(AppError) -> HTTPURLResponse?
}

extension LoginClient {
    static let live: Self = .init(login: performLogin)

    // Spelled as a function rather than a closure literal so the typed `throws(AppError)` survives:
    // a closure literal infers `any Error` here and loses the request layer's typed failure.
    private static func performLogin(
        username: String,
        password: String,
        clearance: CloudflareClearance?
    ) async throws(AppError) -> HTTPURLResponse? {
        try await LoginRequest(username: username, password: password, clearance: clearance)
            .response()
    }
}

// MARK: API
enum LoginClientKey: DependencyKey {
    static let liveValue = LoginClient.live
    static let testValue = LoginClient.unimplemented
}

extension DependencyValues {
    var loginClient: LoginClient {
        get { self[LoginClientKey.self] }
        set { self[LoginClientKey.self] = newValue }
    }
}

// MARK: Test
extension LoginClient {
    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        login: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
