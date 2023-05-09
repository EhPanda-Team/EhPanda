//
//  URLClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import SwiftUI
import Dependencies

struct URLClient {
    let checkIfHandleable: (URL) -> Bool
    let checkIfMPVURL: (URL?) -> Bool
    let parseGalleryID: (URL) -> String
}

extension URLClient {
    static let live: Self = .init(
        checkIfHandleable: { url in
            (url.absoluteString.contains(Defaults.URL.ehentai.absoluteString)
             || url.absoluteString.contains(Defaults.URL.exhentai.absoluteString))
                && url.pathComponents.count >= 4 && ["g", "s"].contains(url.pathComponents[1])
                && !url.pathComponents[2].isEmpty && !url.pathComponents[3].isEmpty
        },
        checkIfMPVURL: {
            guard let url = $0 else { return false }
            return url.pathComponents.count >= 1 && url.pathComponents[1] == "mpv"
        },
        parseGalleryID: { url in
            var gid = url.pathComponents[2]
            let token = url.pathComponents[3]
            if let range = token.range(of: "-") {
                gid = String(token[..<range.lowerBound])
            }
            return gid
        }
    )

    func resolveAppSchemeURL(_ url: URL) -> URL? {
        guard url.scheme == "ehpanda",
              let newURL = url.replaceScheme(to: "https")
        else { return url }
        return newURL
    }
    func analyzeURL(_ url: URL) -> (Bool, Int?, String?) {
        guard checkIfHandleable(url) else {
            return (false, nil, nil)
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

        return (isGalleryImageURL, pageIndex, commentID)
    }
}

// MARK: API
enum URLClientKey: DependencyKey {
    static let liveValue = URLClient.live
    static let previewValue = URLClient.noop
    static let testValue = URLClient.unimplemented
}

extension DependencyValues {
    var urlClient: URLClient {
        get { self[URLClientKey.self] }
        set { self[URLClientKey.self] = newValue }
    }
}

// MARK: Test
extension URLClient {
    static let noop: Self = .init(
        checkIfHandleable: { _ in false },
        checkIfMPVURL: { _ in false },
        parseGalleryID: { _ in .init() }
    )

    static let unimplemented: Self = .init(
        checkIfHandleable: XCTestDynamicOverlay.unimplemented("\(Self.self).checkIfHandleable"),
        checkIfMPVURL: XCTestDynamicOverlay.unimplemented("\(Self.self).checkIfMPVURL"),
        parseGalleryID: XCTestDynamicOverlay.unimplemented("\(Self.self).parseGalleryID")
    )
}
