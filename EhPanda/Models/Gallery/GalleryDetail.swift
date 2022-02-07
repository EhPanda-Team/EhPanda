//
//  GalleryDetail.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import Foundation

struct GalleryDetail: Codable, Equatable {
    static let empty: Self = .init(
        gid: "", title: "", isFavorited: false,
        visibility: .yes, rating: 0, userRating: 0,
        ratingCount: 0, category: .private,
        language: .japanese, uploader: "",
        postedDate: .now, coverURL: nil,
        favoritedCount: 0, pageCount: 0,
        sizeCount: 0, sizeType: "",
        torrentCount: 0
    )
    static let preview = GalleryDetail(
        gid: "",
        title: "Preview",
        jpnTitle: "プレビュー",
        isFavorited: true,
        visibility: .yes,
        rating: 3.5,
        userRating: 4.0,
        ratingCount: 1919,
        category: .doujinshi,
        language: .japanese,
        uploader: "Anonymous",
        postedDate: .distantPast,
        coverURL: URL(
            string: "https://github.com/"
            + "tatsuz0u/Imageset/blob/"
            + "main/JPGs/2.jpg?raw=true"
        ),
        favoritedCount: 514,
        pageCount: 114,
        sizeCount: 514,
        sizeType: "MB",
        torrentCount: 101
    )

    var trimmedTitle: String {
        var title = title
        if let range = title.range(of: "|") {
            title = String(title[..<range.lowerBound])
        }
        title = title.barcesAndSpacesRemoved
        return title
    }

    let gid: String
    var title: String
    var jpnTitle: String?
    var isFavorited: Bool
    var visibility: GalleryVisibility
    var rating: Float
    var userRating: Float
    var ratingCount: Int
    let category: Category
    let language: Language
    let uploader: String
    let postedDate: Date
    let coverURL: URL?
    var archiveURL: URL?
    var parentURL: URL?
    var favoritedCount: Int
    var pageCount: Int
    var sizeCount: Float
    var sizeType: String
    var torrentCount: Int
}

extension GalleryDetail: DateFormattable {
    var originalDate: Date {
        postedDate
    }
}

enum GalleryVisibility: Codable, Equatable {
    case yes
    case no(reason: String)
}

extension GalleryVisibility {
    var value: String {
        switch self {
        case .yes:
            return R.string.localizable.galleryVisibilityValueYes()
        case .no(let reason):
            let localizedReason: String
            switch reason {
            case "Expunged":
                localizedReason = R.string.localizable.galleryVisibilityValueNoReasonExpunged()
            default:
                localizedReason = reason
            }
            return R.string.localizable.galleryVisibilityValueNo(localizedReason)
        }
    }
}
