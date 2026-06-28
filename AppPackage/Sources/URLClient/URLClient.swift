import SwiftUI
import AppModels
import Dependencies
import AppTools

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

extension URLClient {
    public static func isMPVURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.pathComponents.count >= 2 && url.pathComponents[1] == "mpv"
    }

    public static let live: Self = .init(
        checkIfHandleable: { url in
            (url.absoluteString.contains(Defaults.URL.ehentai.absoluteString)
                || url.absoluteString.contains(Defaults.URL.exhentai.absoluteString))
                && url.pathComponents.count >= 4 && ["g", "s"].contains(url.pathComponents[1])
                && !url.pathComponents[2].isEmpty && !url.pathComponents[3].isEmpty
        },
        checkIfMPVURL: Self.isMPVURL,
        parseGalleryID: { url in
            var gid = url.pathComponents[2]
            let token = url.pathComponents[3]
            if let range = token.range(of: "-") {
                gid = String(token[..<range.lowerBound])
            }
            return gid
        }
    )

    public func resolveAppSchemeURL(_ url: URL) -> URL? {
        guard url.scheme == "ehpanda",
              let newURL = url.replaceScheme(to: "https")
        else { return url }
        return newURL
    }
    public func analyzeURL(_ url: URL) -> URLAnalysisResult {
        guard checkIfHandleable(url) else {
            return URLAnalysisResult(isGalleryImageURL: false, pageIndex: nil, commentID: nil)
        }
        var isGalleryImageURL = false
        var commentID: String?
        var pageIndex: Int?

        let token = url.pathComponents[3]
        if let range = token.range(of: "-") {
            pageIndex = Int(token[range.upperBound...])
            isGalleryImageURL = true
        }

        if let range = url.absoluteString.range(of: url.pathComponents[3] + "/") {
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
