public import AppModels
public import ComposableArchitecture
import NetworkingFeature

/// The three requests of the E-Hentai Settings page, one closure per request.
///
/// A reducer that builds its request inside an effect leaves a test no way to choose the outcome. Through this
/// dependency a test states each answer, and the unimplemented test value reports any request a test did not stub.
///
/// `live` builds exactly the requests the reducer built before. The EhPanda profile request in
/// `SettingReducer+Body.swift` is not part of this client.
public struct EhSettingClient: Sendable {
    /// The site's settings page: the page's first load, and the refetch after a save that failed.
    public var fetchSettings: @Sendable (
        _ host: GalleryHost
    ) async throws(AppError) -> EhSetting
    /// Posts the whole form and answers the site's settings page after the change.
    public var submitChanges: @Sendable (
        _ host: GalleryHost,
        _ ehSetting: EhSetting
    ) async throws(AppError) -> EhSetting
    /// Creates, renames, deletes or selects a profile and answers the site's settings page after the action.
    public var performProfileAction: @Sendable (
        _ host: GalleryHost,
        _ action: EhProfileAction?,
        _ name: String?,
        _ set: Int
    ) async throws(AppError) -> EhSetting
}

extension EhSettingClient {
    /// Each closure forwards its arguments, in order and unchanged, to the request it is named after.
    public static let live = Self(
        fetchSettings: settings,
        submitChanges: changes,
        performProfileAction: profileAction
    )

    private static func settings(
        host: GalleryHost
    ) async throws(AppError) -> EhSetting {
        try await EhSettingRequest(host: host).response()
    }

    private static func changes(
        host: GalleryHost,
        ehSetting: EhSetting
    ) async throws(AppError) -> EhSetting {
        try await SubmitEhSettingChangesRequest(host: host, ehSetting: ehSetting).response()
    }

    private static func profileAction(
        host: GalleryHost,
        action: EhProfileAction?,
        name: String?,
        set: Int
    ) async throws(AppError) -> EhSetting {
        try await EhProfileRequest(host: host, action: action, name: name, set: set).response()
    }
}

// MARK: API
public enum EhSettingClientKey: DependencyKey {
    public static let liveValue = EhSettingClient.live
    public static let previewValue = EhSettingClient.noop
    public static let testValue = EhSettingClient.unimplemented
}

extension DependencyValues {
    public var ehSettingClient: EhSettingClient {
        get { self[EhSettingClientKey.self] }
        set { self[EhSettingClientKey.self] = newValue }
    }
}

// MARK: Test
extension EhSettingClient {
    /// A site that accepts every change: a save answers the form it was given, and the other requests answer an empty
    /// settings page.
    public static let noop = Self(
        fetchSettings: { (_: GalleryHost) async throws(AppError) -> EhSetting in
            .empty
        },
        submitChanges: { (_: GalleryHost, ehSetting: EhSetting) async throws(AppError) -> EhSetting in
            ehSetting
        },
        performProfileAction: { (_, _, _, _) async throws(AppError) -> EhSetting in
            .empty
        }
    )

    /// Reports an issue that names the closure and throws, so a test that reaches a request it did not stub fails
    /// without ending the test process.
    public static let unimplemented = Self(
        fetchSettings: IssueReporting.unimplemented(
            "EhSettingClient.fetchSettings", throwing: AppError.unknown
        ),
        submitChanges: IssueReporting.unimplemented(
            "EhSettingClient.submitChanges", throwing: AppError.unknown
        ),
        performProfileAction: IssueReporting.unimplemented(
            "EhSettingClient.performProfileAction", throwing: AppError.unknown
        )
    )

    /// Fails every request with `error` and reports nothing. Use it for a request a test starts but does not care
    /// about, failed the way an offline device would fail it.
    public static func failing(_ error: AppError) -> Self {
        Self(
            fetchSettings: { (_: GalleryHost) async throws(AppError) -> EhSetting in
                throw error
            },
            submitChanges: { (_: GalleryHost, _: EhSetting) async throws(AppError) -> EhSetting in
                throw error
            },
            performProfileAction: { (_, _, _, _) async throws(AppError) -> EhSetting in
                throw error
            }
        )
    }
}
