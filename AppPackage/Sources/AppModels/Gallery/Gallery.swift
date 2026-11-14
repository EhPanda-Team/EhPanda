import AppTools
public import SwiftUI

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
        return (0...count).map({ _ in blank() })
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
        coverURL: URL(string: "https://picsum.photos/id/1015/400/566"),
        galleryURL: nil
    )

    /// Distinct-id sample galleries with real titles/ratings for populating list & grid previews.
    /// Unlike `mockGalleries` (blank skeleton rows) and `.preview` (a single fixed id), each row
    /// here has a unique id and visible content, so `ForEach`-keyed lists render without collisions.
    public static func previews(count: Int) -> [Gallery] {
        (0..<max(0, count)).map { index in
            .init(
                gid: UUID().uuidString,
                token: "",
                title: "Sample Gallery \(index + 1)",
                rating: Float(index % 5) + 0.5,
                tags: [],
                category: .doujinshi,
                uploader: "Anonymous",
                pageCount: 20 + index * 7,
                postedDate: .now,
                coverURL: nil,
                galleryURL: nil
            )
        }
    }

    /// Resolves the display preference without losing either source title.
    public func displayTitle(prefersJapanese: Bool) -> String {
        guard prefersJapanese, let japanese = jpnTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !japanese.isEmpty else { return title }
        return japanese
    }

    /// Whether a list filter's keyword matches either title, so a Japanese keyword finds the Japanese title
    /// the list may be showing.
    public func titleMatches(_ keyword: String) -> Bool {
        title.caseInsensitiveContains(keyword) || jpnTitle?.caseInsensitiveContains(keyword) == true
    }

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
    public var jpnTitle: String?
    public var rating: Float
    public var tags: [GalleryTag]
    public let category: Category
    public var uploader: String?
    public var pageCount: Int
    public let postedDate: Date
    public let coverURL: URL?
    public let galleryURL: URL?
    public var lastOpenDate: Date?
    /// Whether the site has expunged the gallery: its list rows show the posted date struck through.
    public var isExpunged: Bool = false
    /// Whether the signed-in user has rated the gallery themselves (the list's star class is not plain `ir`).
    public var hasRated: Bool = false
    /// The colour the site draws that rating in (`irr`, `irg`, `irb`); the list's stars take it. `nil` when the
    /// gallery is not rated or the colour is unknown, and for a gallery built from the `gdata` API (History).
    public var userRatingTint: UserRatingTint?
    /// The user's favorites slot (0...9) holding the gallery, `nil` when it is not a favorite or unknown.
    public var favoriteTagIndex: Int?
    /// The name of that favorites slot as the site shows it.
    public var favoriteTagName: String?
    public var isFavorite: Bool {
        favoriteTagIndex != nil || favoriteTagName != nil
    }

    // The marks are newer than the rest of the model, so JSON written without them decodes with them off;
    // everything else stays strict. (`Gallery` is not persisted today, but it is `Codable` and a stored copy
    // must not stop decoding because a field was added.)
    private enum CodingKeys: String, CodingKey {
        case gid, token, title, jpnTitle, rating, tags, category, uploader, pageCount, postedDate
        case coverURL, galleryURL, lastOpenDate
        case isExpunged, hasRated, userRatingTint, favoriteTagIndex, favoriteTagName
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gid = try container.decode(String.self, forKey: .gid)
        token = try container.decode(String.self, forKey: .token)
        title = try container.decode(String.self, forKey: .title)
        jpnTitle = try container.decodeIfPresent(String.self, forKey: .jpnTitle)
        rating = try container.decode(Float.self, forKey: .rating)
        tags = try container.decode([GalleryTag].self, forKey: .tags)
        category = try container.decode(Category.self, forKey: .category)
        uploader = try container.decodeIfPresent(String.self, forKey: .uploader)
        pageCount = try container.decode(Int.self, forKey: .pageCount)
        postedDate = try container.decode(Date.self, forKey: .postedDate)
        coverURL = try container.decodeIfPresent(URL.self, forKey: .coverURL)
        galleryURL = try container.decodeIfPresent(URL.self, forKey: .galleryURL)
        lastOpenDate = try container.decodeIfPresent(Date.self, forKey: .lastOpenDate)
        isExpunged = try container.decodeIfPresent(Bool.self, forKey: .isExpunged) ?? false
        hasRated = try container.decodeIfPresent(Bool.self, forKey: .hasRated) ?? false
        userRatingTint = try container.decodeIfPresent(UserRatingTint.self, forKey: .userRatingTint)
        favoriteTagIndex = try container.decodeIfPresent(Int.self, forKey: .favoriteTagIndex)
        favoriteTagName = try container.decodeIfPresent(String.self, forKey: .favoriteTagName)
    }

    public init(
        gid: String,
        token: String,
        title: String,
        jpnTitle: String? = nil,
        rating: Float,
        tags: [GalleryTag],
        category: Category,
        uploader: String? = nil,
        pageCount: Int,
        postedDate: Date,
        coverURL: URL?,
        galleryURL: URL?,
        lastOpenDate: Date? = nil,
        isExpunged: Bool = false,
        hasRated: Bool = false,
        userRatingTint: UserRatingTint? = nil,
        favoriteTagIndex: Int? = nil,
        favoriteTagName: String? = nil
    ) {
        self.gid = gid
        self.token = token
        self.title = title
        self.jpnTitle = jpnTitle
        self.rating = rating
        self.tags = tags
        self.category = category
        self.uploader = uploader
        self.pageCount = pageCount
        self.postedDate = postedDate
        self.coverURL = coverURL
        self.galleryURL = galleryURL
        self.lastOpenDate = lastOpenDate
        self.isExpunged = isExpunged
        self.hasRated = hasRated
        self.userRatingTint = userRatingTint
        self.favoriteTagIndex = favoriteTagIndex
        self.favoriteTagName = favoriteTagName
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
