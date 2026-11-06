public import AppModels
public import Foundation
import ParserFeature

/// Reads the site's report form for a gallery (18.1 DD-01).
///
/// `url` is the gallery's `?report=other` page, rebuilt from the validated gallery URL by the caller. The page carries
/// the type picker and the shared email and details fields, so one load covers both comment reasons. A non-2xx status
/// or a page that is not a usable form throws. The request carries the app session's cookies like any other page load
/// and logs nothing.
public struct ReportFormRequest: Request {
    public init(url: URL, urlSession: URLSession = .shared) {
        self.url = url
        self.urlSession = urlSession
    }
    public let url: URL
    public let urlSession: URLSession

    public func response() async throws(AppError) -> ReportForm {
        let (data, response) = try await fetch(URLRequest(url: url), in: urlSession)
        try requireSuccessStatus(response)
        do {
            let document = try htmlDocument(data: data)
            return try parseResponse(doc: document, Parser.parseReportForm)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

/// Sends a report exactly as the site's own form does (18.1 DD-02, DD-03).
///
/// The body holds the site's fields, `report_type`, `r_email`, `r_details` and `sendreport=Send Report`, posted to
/// `url`: the gallery's `?report=<type>` page rebuilt from the validated gallery URL, never the `action` a page names
/// (T-18.1-01). The site may have filed the report before a reply went missing, so the request is put on the wire
/// once and never retried automatically (Research F-1, T-18.1-02). A transport error or a non-2xx status throws. A
/// 2xx reply is `.sent` only when it no longer shows the report form; a reply that is one of the site's error pages
/// throws, so it is never taken as sent. Neither the email nor the details are logged (T-18.1-03).
public struct SendReportRequest: Request {
    public init(url: URL, type: ReportType, email: String, details: String, urlSession: URLSession = .shared) {
        self.url = url
        self.type = type
        self.email = email
        self.details = details
        self.urlSession = urlSession
    }
    public let url: URL
    public let type: ReportType
    public let email: String
    public let details: String
    public let urlSession: URLSession

    public func response() async throws(AppError) -> ReportSubmission {
        // `dictString()` percent-encodes each value, so newlines in the details arrive as newlines.
        let params: [String: String] = [
            "report_type": type.rawValue,
            "r_email": email,
            "r_details": details,
            "sendreport": "Send Report"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = params.dictString().data(using: .utf8)
        request.setURLEncodedContentType()

        let (data, response) = try await fetch(request, in: urlSession, attempts: 1)
        try requireSuccessStatus(response)
        do {
            let document = try htmlDocument(data: data)
            if let responseError = Parser.parseResponseError(doc: document) {
                throw responseError
            }
            return Parser.parseReportSubmission(doc: document)
        } catch {
            throw mapAppError(error: error)
        }
    }
}

private extension Request {
    /// Accepts a 2xx HTTP response only: a missing page is `.notFound`, anything else `.networkingFailed`.
    func requireSuccessStatus(_ response: URLResponse) throws(AppError) {
        guard let httpResponse = response as? HTTPURLResponse else { throw .networkingFailed }
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 404:
            throw .notFound
        default:
            throw .networkingFailed
        }
    }
}
