import AppTools
import Foundation
import Resources

public struct GalleryDetail: Codable, Equatable, Sendable {
    public init(
        gid: String,
        title: String,
        jpnTitle: String? = nil,
        isFavorited: Bool,
        visibility: GalleryVisibility,
        rating: Float,
        userRating: Float,
        ratingCount: Int,
        category: Category,
        language: Language,
        uploader: String,
        postedDate: Date,
        coverURL: URL? = nil,
        archiveURL: URL? = nil,
        parentURL: URL? = nil,
        favoritedCount: Int,
        pageCount: Int,
        sizeCount: Float,
        sizeType: String,
        torrentCount: Int
    ) {
        self.gid = gid
        self.title = title
        self.jpnTitle = jpnTitle
        self.isFavorited = isFavorited
        self.visibility = visibility
        self.rating = rating
        self.userRating = userRating
        self.ratingCount = ratingCount
        self.category = category
        self.language = language
        self.uploader = uploader
        self.postedDate = postedDate
        self.coverURL = coverURL
        self.archiveURL = archiveURL
        self.parentURL = parentURL
        self.favoritedCount = favoritedCount
        self.pageCount = pageCount
        self.sizeCount = sizeCount
        self.sizeType = sizeType
        self.torrentCount = torrentCount
    }
    public static let empty: Self = .init(
        gid: "", title: "", isFavorited: false,
        visibility: .yes, rating: 0, userRating: 0,
        ratingCount: 0, category: .private,
        language: .japanese, uploader: "",
        postedDate: .now, coverURL: nil,
        favoritedCount: 0, pageCount: 0,
        sizeCount: 0, sizeType: "",
        torrentCount: 0
    )
    public static let preview = GalleryDetail(
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
                + "EhPanda-Team/Imageset/blob/"
                + "main/JPGs/2.jpg?raw=true"
        ),
        favoritedCount: 514,
        pageCount: 114,
        sizeCount: 514,
        sizeType: "MB",
        torrentCount: 101
    )

    public var trimmedTitle: String {
        var title = title
        if let range = title.range(of: "|") {
            title = String(title[..<range.lowerBound])
        }
        title = title.barcesAndSpacesRemoved
        return title
    }

    public let gid: String
    public var title: String
    public var jpnTitle: String?
    public var isFavorited: Bool
    public var visibility: GalleryVisibility
    public var rating: Float
    public var userRating: Float
    public var ratingCount: Int
    public let category: Category
    public let language: Language
    public let uploader: String
    public let postedDate: Date
    public let coverURL: URL?
    public var archiveURL: URL?
    public var parentURL: URL?
    public var favoritedCount: Int
    public var pageCount: Int
    public var sizeCount: Float
    public var sizeType: String
    public var torrentCount: Int
}

extension GalleryDetail: DateFormattable {
    public var originalDate: Date {
        postedDate
    }
}

public enum GalleryVisibility: Codable, Equatable, Sendable {
    case yes
    // swiftlint:disable:next identifier_name
    case no(reason: String)
}

extension GalleryVisibility {
    public var value: String {
        switch self {
        case .yes:
            return L10n.Localizable.GalleryVisibility.yes
        case .no(let reason):
            let localizedReason: String
            switch reason {
            case "Expunged":
                localizedReason = L10n.Localizable.GalleryVisibility.expunged
            default:
                localizedReason = reason
            }
            return L10n.Localizable.GalleryVisibility.no(localizedReason)
        }
    }
}
