//
//  GalleryState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import Foundation

struct GalleryState: Codable {
    static let empty = GalleryState(gid: "")
    static let preview = GalleryState(gid: "")

    let gid: String
    var tags = [GalleryTag]()
    var readingProgress = 0
    var previews = [Int: String]()
    var previewConfig: PreviewConfig?
    var comments = [GalleryComment]()
    var imageURLs = [Int: String]()
    var originalContents = [Int: String]()
    var thumbnails = [Int: String]()
}

struct GalleryTag: Codable, Equatable, Identifiable {
    var id: String { namespace }

    let namespace: String
    let content: [String]
    let category: TagCategory?

    init(namespace: String = "other", content: [String]) {
        self.namespace = namespace
        self.content = content
        self.category = TagCategory(rawValue: namespace)
    }
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
