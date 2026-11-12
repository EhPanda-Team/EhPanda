public import AppModels
public import ComposableArchitecture
public import Foundation
import NetworkingFeature

/// The Report form's two calls to the site (18.1 DD-01 to DD-03), a dependency so tests never reach it.
///
/// The live value uses 18.1-01's requests on the app's shared URL session, so a report carries the same sign-in as
/// posting a comment. The test value is unimplemented: a test that loads or sends must say what the site answers.
@DependencyClient
public struct ReportFormClient: Sendable {
    /// Reads the site's report form at `url` (the gallery's `?report=other` page).
    public var load: @Sendable (_ url: URL) async throws -> ReportForm
    /// Posts one report to `url` (the gallery's `?report=<type>` page), once, never retried.
    public var send: @Sendable (
        _ url: URL, _ type: ReportType, _ email: String, _ details: String
    ) async throws -> ReportSubmission
}

extension ReportFormClient: DependencyKey {
    public static let liveValue = Self(
        load: { url in
            try await ReportFormRequest(url: url).response()
        },
        send: { url, type, email, details in
            try await SendReportRequest(url: url, type: type, email: email, details: details).response()
        }
    )
    public static let testValue = Self()
}

extension DependencyValues {
    public var reportFormClient: ReportFormClient {
        get { self[ReportFormClient.self] }
        set { self[ReportFormClient.self] = newValue }
    }
}
