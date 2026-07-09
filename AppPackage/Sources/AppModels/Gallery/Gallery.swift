import AppTools
import SwiftUI

public struct Gallery: Identifiable, Codable, Equatable, Hashable, Sendable {
    public static func == (lhs: Gallery, rhs: Gallery) -> Bool {
        lhs.gid == rhs.gid
    }

    public static func mockGalleries(count: Int, randomID: Bool = true) -> [Gallery] {
        // A blank, fresh-id gallery used only to fill the loading skeleton. `.preview` can't stand in
        // because its `gid` is a fixed constant and the skeleton's `ForEach` is keyed by gallery id,
        // so every row needs a distinct id.
        func blank() -> Gallery {
            .init(
                gid: UUID().uuidString,
                token: "",
                title: "",
                rating: 0.0,
                tags: [],
                category: .doujinshi,
                uploader: "",
                pageCount: 1,
                postedDate: .now,
                coverURL: nil,
                galleryURL: nil
            )
        }
        guard randomID, count > 0 else {
            return Array(repeating: blank(), count: count)
        }
        return (0...count).map { _ in blank() }
    }
    public static let preview = Gallery(
        gid: UUID().uuidString,
        token: "",
        title: "Preview",
        rating: 3.5,
        tags: [],
        category: .doujinshi,
        uploader: "Anonymous",
        pageCount: 1,
        postedDate: .now,
        coverURL: URL(
            string: "https://github.com/"
                + "EhPanda-Team/Imageset/blob/"
                + "main/JPGs/2.jpg?raw=true"
        ),
        galleryURL: nil
    )

    public var trimmedTitle: String {
        var title = title
        if let range = title.range(of: "|") {
            title = String(title[..<range.lowerBound])
        }
        title = title.barcesAndSpacesRemoved
        return title
    }
    public var language: Language? {
        let rawValue = tags
            .first(where: { $0.namespace == .language })?.contents
            .first(where: { Language(rawValue: $0.firstLetterCapitalizedText) != nil })
            .map(\.firstLetterCapitalizedText) ?? ""
        return .init(rawValue: rawValue)
    }
    public func tagContents(maximum: Int) -> [GalleryTag.Content] {
        let tagContents = tags.flatMap(\.contents)
        guard maximum > 0 else { return tagContents }
        return .init(tagContents.prefix(min(tagContents.count, maximum)))
    }

    public var id: String { gid }
    public let gid: String
    public let token: String

    public var title: String
    public var rating: Float
    public var tags: [GalleryTag]
    public let category: Category
    public var uploader: String?
    public var pageCount: Int
    public let postedDate: Date
    public let coverURL: URL?
    public let galleryURL: URL?
    public var lastOpenDate: Date?

    public init(
        gid: String,
        token: String,
        title: String,
        rating: Float,
        tags: [GalleryTag],
        category: Category,
        uploader: String? = nil,
        pageCount: Int,
        postedDate: Date,
        coverURL: URL?,
        galleryURL: URL?,
        lastOpenDate: Date? = nil
    ) {
        self.gid = gid
        self.token = token
        self.title = title
        self.rating = rating
        self.tags = tags
        self.category = category
        self.uploader = uploader
        self.pageCount = pageCount
        self.postedDate = postedDate
        self.coverURL = coverURL
        self.galleryURL = galleryURL
        self.lastOpenDate = lastOpenDate
    }
}

extension Gallery: DateFormattable, CustomStringConvertible {
    public var description: String {
        "Gallery(\(gid))"
    }

    public var filledCount: Int { Int(rating) }
    public var halfFilledCount: Int { Int(rating - 0.5) == filledCount ? 1 : 0 }
    public var notFilledCount: Int { 5 - filledCount - halfFilledCount }

    public func color(host: GalleryHost) -> Color {
        category.color(host: host)
    }
    public var originalDate: Date {
        postedDate
    }
}
