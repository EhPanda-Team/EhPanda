//
//  GalleryState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import SwiftUI
import Foundation

struct GalleryState: Codable {
    static let empty = GalleryState(gid: "")
    static let preview = GalleryState(gid: "")

    let gid: String
    var tags = [GalleryTag]()
    var readingProgress = 0
    var previewURLs = [Int: URL]()
    var previewConfig: PreviewConfig?
    var comments = [GalleryComment]()
    var imageURLs = [Int: URL]()
    var originalImageURLs = [Int: URL]()
    var thumbnailURLs = [Int: URL]()
}
extension GalleryState: CustomStringConvertible {
    var description: String {
        let params = String(
            describing: [
                "gid": gid,
                "tagsCount": tags.count,
                "readingProgress": readingProgress,
                "previewURLsCount": previewURLs.count,
                "previewConfig": String(describing: previewConfig),
                "commentsCount": comments.count,
                "imageURLsCount": imageURLs.count,
                "originalImageURLsCount": originalImageURLs.count,
                "thumbnailURLsCount": thumbnailURLs.count
            ]
            as [String: Any]
        )
        return "GalleryState(\(params))"
    }
}

struct GalleryTag: Codable, Equatable, Hashable, Identifiable {
    struct Content: Codable, Equatable, Hashable, Identifiable {
        var id: String { rawNamespace + text }
        var firstLetterCapitalizedText: String {
            text.firstLetterCapitalized
        }
        func voteKeyword(tag: GalleryTag) -> String {
            let namespace = tag.namespace?.abbreviation ?? tag.namespace?.rawValue ?? tag.rawNamespace.lowercased()
            return tag.namespace == .temp ? text : [namespace, text].joined(separator: ":")
        }
        func serachKeyword(tag: GalleryTag) -> String {
            let keyword = text.contains(" ") ? "\"\(text)$\"" : "\(text)$"
            let namespace = tag.namespace?.abbreviation ?? tag.namespace?.rawValue ?? tag.rawNamespace.lowercased()
            return tag.namespace == .temp ? keyword : [namespace, keyword].joined(separator: ":")
        }

        let rawNamespace: String
        let text: String
        let isVotedUp: Bool
        let isVotedDown: Bool
        let textColor: Color?
        let backgroundColor: Color?
    }

    var id: String { rawNamespace }
    var namespace: TagNamespace? {
        .init(rawValue: rawNamespace)
    }

    let rawNamespace: String
    let contents: [Content]
}

enum PreviewConfig: Codable, Equatable {
    case normal(rows: Int)
    case large(rows: Int)
}

extension PreviewConfig {
    var batchSize: Int {
        switch self {
        case .normal(let rows):
            return 10 * rows
        case .large(let rows):
            return 5 * rows
        }
    }

    func pageNumber(index: Int) -> Int {
        index / batchSize
    }
    func batchRange(index: Int) -> ClosedRange<Int> {
        let lowerBound = pageNumber(index: index) * batchSize + 1
        let upperBound = lowerBound + batchSize - 1
        return lowerBound...upperBound
    }
}
