//
//  GalleryComment.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import Foundation

struct GalleryComment: Identifiable, Equatable, Codable {
    var id: String { commentID }

    var votedUp: Bool
    var votedDown: Bool
    let votable: Bool
    let editable: Bool

    let score: String?
    let author: String
    let contents: [CommentContent]
    let commentID: String
    let commentDate: Date

    var plainTextContent: String {
        contents
            .filter { [.plainText, .linkedText, .singleLink].contains($0.type) }
            .compactMap { $0.type == .singleLink ? $0.link?.absoluteString : $0.text }.joined()
    }
}

extension GalleryComment: DateFormattable {
    var originalDate: Date {
        commentDate
    }
}

struct CommentContent: Identifiable, Equatable, Codable {
    var id: UUID = .init()
    let type: CommentContentType
    var text: String?
    var link: URL?
    var imgURL: URL?

    var secondLink: URL?
    var secondImgURL: URL?
}

enum CommentContentType: Int, Codable {
    case singleImg
    case doubleImg
    case linkedImg
    case doubleLinkedImg

    case plainText
    case linkedText

    case singleLink
}
