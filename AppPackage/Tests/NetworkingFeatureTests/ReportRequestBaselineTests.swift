import AppModels
import Foundation
@testable import NetworkingFeature
import Testing

// The native Report form's two requests (18.1 DD-01 to DD-03, Research F-1). Every request runs through a
// token-isolated URLProtocol session, so these tests never open a socket and never reach the site.
@Suite
struct ReportRequestBaselineTests {
    private static let otherURL = URL(string: "https://e-hentai.org/g/4224857/85b3bd9b6c/?report=other")

    // MARK: SendReportRequest

    @Test(arguments: ReportType.allCases)
    func sendReportRequestPostsTheSitesFormFieldsOnce(type: ReportType) async throws {
        let url = try #require(
            URL(string: "https://exhentai.org/g/4224857/85b3bd9b6c/?report=\(type.rawValue)")
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .sentFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let submission = try await capture { () async throws(AppError) -> ReportSubmission in
            try await SendReportRequest(
                url: url,
                type: type,
                email: "someone+report@example.com",
                details: "Reporting a comment by someone:\n\"a & b = c\"\n\nmore",
                urlSession: session
            )
            .response()
        }
        .get()

        #expect(submission == .sent)
        #expect(handle.receivedRequests.count == 1)
        #expect(handle.attempts(for: url) == 1)
        let request = try #require(handle.receivedRequests.first)
        // The newlines arrive as newlines, and `+`, `&`, `=` and `"` stay inside their fields.
        expectFormRequest(
            request,
            url: url,
            fields: [
                "report_type": type.rawValue,
                "r_email": "someone+report@example.com",
                "r_details": "Reporting a comment by someone:\n\"a & b = c\"\n\nmore",
                "sendreport": "Send Report"
            ]
        )
    }

    @Test
    func sendReportRequestIsNotRetriedAfterATransportFailure() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                url: [.transportFailure(.networkConnectionLost), .http(status: 200, data: .sentFixture)]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> ReportSubmission in
            try await sendOther(url: url, session: session)
        }

        expectFailure(result, error: .networkingFailed)
        #expect(handle.attempts(for: url) == 1)
    }

    @Test
    func sendReportRequestThrowsOnAServerErrorWithoutRetrying() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                url: [.http(status: 503, data: Data()), .http(status: 200, data: .sentFixture)]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> ReportSubmission in
            try await sendOther(url: url, session: session)
        }

        expectFailure(result, error: .networkingFailed)
        #expect(handle.attempts(for: url) == 1)
    }

    @Test
    func sendReportRequestIsRejectedWhenTheReplyStillShowsTheForm() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: try reportFixture("ReportOther"))]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let submission = try await capture { () async throws(AppError) -> ReportSubmission in
            try await sendOther(url: url, session: session)
        }
        .get()

        #expect(submission == .rejected)
        #expect(handle.attempts(for: url) == 1)
    }

    @Test
    func sendReportRequestThrowsWhenTheReplyIsAnErrorPage() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .galleryNotFoundFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> ReportSubmission in
            try await sendOther(url: url, session: session)
        }

        // No form on the page, but it is not a reply to a report either: never "sent".
        expectFailure(result, error: .notFound)
        #expect(handle.attempts(for: url) == 1)
    }

    // MARK: ReportFormRequest

    @Test
    func reportFormRequestGetsAndParsesTheForm() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: try reportFixture("ReportOther"))]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let form = try await capture { () async throws(AppError) -> ReportForm in
            try await ReportFormRequest(url: url, urlSession: session).response()
        }
        .get()

        #expect(form == ReportForm(types: [.child, .other], email: "", hasDetails: true))
        #expect(handle.attempts(for: url) == 1)
        let request = try #require(handle.receivedRequests.first)
        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
    }

    @Test
    func reportFormRequestThrowsOnANotFoundStatus() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 404, data: try reportFixture("ReportOther"))]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> ReportForm in
            try await ReportFormRequest(url: url, urlSession: session).response()
        }

        expectFailure(result, error: .notFound)
        #expect(handle.attempts(for: url) == 1)
    }

    @Test
    func reportFormRequestThrowsOnTheFirstStepPage() async throws {
        let url = try #require(Self.otherURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: try reportFixture("ReportSelect"))]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> ReportForm in
            try await ReportFormRequest(url: url, urlSession: session).response()
        }

        expectFailure(result, error: .parseFailed)
        #expect(handle.attempts(for: url) == 1)
    }

    private func sendOther(url: URL, session: URLSession) async throws(AppError) -> ReportSubmission {
        try await SendReportRequest(
            url: url,
            type: .other,
            email: "someone@example.com",
            details: "details",
            urlSession: session
        )
        .response()
    }
}

private func cleanUp(session: URLSession, handle: StubHandle) {
    session.invalidateAndCancel()
    handle.tearDown()
}

private func expectFailure<T>(
    _ result: Result<T, AppError>,
    error: AppError,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard case .failure(let receivedError) = result else {
        Issue.record("Expected request failure.", sourceLocation: sourceLocation)
        return
    }
    #expect(receivedError == error, sourceLocation: sourceLocation)
}

private func expectFormRequest(
    _ request: URLRequest,
    url: URL,
    fields: [String: String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    expectEquivalentURL(request.url, url, sourceLocation: sourceLocation)
    #expect(request.httpMethod == "POST", sourceLocation: sourceLocation)
    #expect(
        request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded",
        sourceLocation: sourceLocation
    )
    #expect(formFields(from: request) == fields, sourceLocation: sourceLocation)
}

private func formFields(from request: URLRequest) -> [String: String] {
    guard
        let body = request.httpBody,
        let string = String(data: body, encoding: .utf8),
        let items = URLComponents(string: "?\(string)")?.queryItems
    else {
        return [:]
    }
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

/// One of the site's saved report pages from `TestingSupport` (18.1-01 Task 1).
private func reportFixture(_ name: String) throws -> Data {
    let appPackageURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fixtureURL = appPackageURL
        .appending(path: "Sources")
        .appending(path: "TestingSupport")
        .appending(path: "Resources")
        .appending(path: "Parser")
        .appending(path: "Other")
        .appending(path: "\(name).html")
    return try Data(contentsOf: fixtureURL)
}

private extension Data {
    /// A reply without the report form. The site's real reply has never been seen (Research OQ-1).
    static let sentFixture = Data("<html><body><p>Thank you for your report.</p></body></html>".utf8)

    static let galleryNotFoundFixture = Data("<html><body><p>Gallery not found.</p></body></html>".utf8)
}
