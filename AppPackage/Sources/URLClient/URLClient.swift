import AppModels
import AppTools
import Dependencies
import SwiftUI

public struct URLAnalysisResult: Sendable {
    public let isGalleryImageURL: Bool
    public let pageIndex: Int?
    public let commentID: String?
}

public struct URLClient: Sendable {
    public let checkIfHandleable: @Sendable (URL) -> Bool
    public let checkIfMPVURL: @Sendable (URL?) -> Bool
    public let parseGalleryID: @Sendable (URL) -> String

    public init(
        checkIfHandleable: @escaping @Sendable (URL) -> Bool,
        checkIfMPVURL: @escaping @Sendable (URL?) -> Bool,
        parseGalleryID: @escaping @Sendable (URL) -> String
    ) {
        self.checkIfHandleable = checkIfHandleable
        self.checkIfMPVURL = checkIfMPVURL
        self.parseGalleryID = parseGalleryID
    }
}

/// The `/<kind>/<gid>/<token>` route an E-Hentai gallery (`g`) or single-page (`s`) URL carries.
private struct GalleryRoute {
    let kind: String
    let gid: String
    /// Absent for a bare `/<kind>/<gid>` path that stops before the token.
    let token: String?
}

private extension URL {
    /// The gallery route this URL names, or `nil` when the path is too short to name one.
    var galleryRoute: GalleryRoute? {
        var components = pathComponents.dropFirst()
        guard let kind = components.popFirst(), let gid = components.popFirst() else { return nil }
        return GalleryRoute(kind: kind, gid: gid, token: components.first)
    }
}

extension URLClient {
    public static func isMPVURL(_ url: URL?) -> Bool {
        url?.pathComponents.dropFirst().first == "mpv"
    }

    public static let live: Self = .init(
        checkIfHandleable: { url in
            guard url.absoluteString.contains(Defaults.URL.ehentai.absoluteString)
                    || url.absoluteString.contains(Defaults.URL.exhentai.absoluteString),
                  let route = url.galleryRoute, let token = route.token
            else { return false }
            return ["g", "s"].contains(route.kind) && !route.gid.isEmpty && !token.isEmpty
        },
        checkIfMPVURL: Self.isMPVURL,
        parseGalleryID: { url in
            guard let route = url.galleryRoute else { return .init() }
            // A single-page token is "<gid>-<page>", so it carries the gallery id the route's own
            // slot does not hold for that shape.
            guard let token = route.token, let range = token.range(of: "-") else { return route.gid }
            return String(token[..<range.lowerBound])
        }
    )

    public func resolveAppSchemeURL(_ url: URL) -> URL? {
        guard url.scheme == "ehpanda",
              let newURL = url.replaceScheme(to: "https")
        else { return url }
        return newURL
    }
    public func analyzeURL(_ url: URL) -> URLAnalysisResult {
        guard checkIfHandleable(url), let token = url.galleryRoute?.token else {
            return URLAnalysisResult(isGalleryImageURL: false, pageIndex: nil, commentID: nil)
        }
        var isGalleryImageURL = false
        var commentID: String?
        var pageIndex: Int?

        if let range = token.range(of: "-") {
            pageIndex = Int(token[range.upperBound...])
            isGalleryImageURL = true
        }

        if let range = url.absoluteString.range(of: token + "/") {
            let commentField = String(url.absoluteString[range.upperBound...])
            if let range = commentField.range(of: "#c") {
                commentID = String(commentField[range.upperBound...])
                isGalleryImageURL = false
            }
        }

        return URLAnalysisResult(isGalleryImageURL: isGalleryImageURL, pageIndex: pageIndex, commentID: commentID)
    }
}

// MARK: API
public enum URLClientKey: DependencyKey {
    public static let liveValue = URLClient.live
    public static let previewValue = URLClient.noop
    public static let testValue = URLClient.unimplemented
}

extension DependencyValues {
    public var urlClient: URLClient {
        get { self[URLClientKey.self] }
        set { self[URLClientKey.self] = newValue }
    }
}

// MARK: Test
extension URLClient {
    public static let noop: Self = .init(
        checkIfHandleable: { _ in false },
        checkIfMPVURL: { _ in false },
        parseGalleryID: { _ in .init() }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        checkIfHandleable: IssueReporting.unimplemented(placeholder: placeholder()),
        checkIfMPVURL: IssueReporting.unimplemented(placeholder: placeholder()),
        parseGalleryID: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
