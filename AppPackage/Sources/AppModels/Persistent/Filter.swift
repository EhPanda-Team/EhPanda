import SwiftUI
import Resources

public struct Filter: Codable, Equatable, Sendable {
    public init(
        doujinshi: Bool = false,
        manga: Bool = false,
        artistCG: Bool = false,
        gameCG: Bool = false,
        western: Bool = false,
        nonH: Bool = false,
        imageSet: Bool = false,
        cosplay: Bool = false,
        asianPorn: Bool = false,
        misc: Bool = false,
        advanced: Bool = false,
        galleryName: Bool = true,
        galleryTags: Bool = true,
        galleryDesc: Bool = false,
        torrentFilenames: Bool = false,
        onlyWithTorrents: Bool = false,
        lowPowerTags: Bool = false,
        downvotedTags: Bool = false,
        expungedGalleries: Bool = false,
        minRatingActivated: Bool = false,
        minRating: Int = 2,
        pageRangeActivated: Bool = false,
        pageLowerBound: String = "",
        pageUpperBound: String = "",
        disableLanguage: Bool = false,
        disableUploader: Bool = false,
        disableTags: Bool = false
    ) {
        self.doujinshi = doujinshi
        self.manga = manga
        self.artistCG = artistCG
        self.gameCG = gameCG
        self.western = western
        self.nonH = nonH
        self.imageSet = imageSet
        self.cosplay = cosplay
        self.asianPorn = asianPorn
        self.misc = misc
        self.advanced = advanced
        self.galleryName = galleryName
        self.galleryTags = galleryTags
        self.galleryDesc = galleryDesc
        self.torrentFilenames = torrentFilenames
        self.onlyWithTorrents = onlyWithTorrents
        self.lowPowerTags = lowPowerTags
        self.downvotedTags = downvotedTags
        self.expungedGalleries = expungedGalleries
        self.minRatingActivated = minRatingActivated
        self.minRating = minRating
        self.pageRangeActivated = pageRangeActivated
        self.pageLowerBound = pageLowerBound
        self.pageUpperBound = pageUpperBound
        self.disableLanguage = disableLanguage
        self.disableUploader = disableUploader
        self.disableTags = disableTags
    }
    public var doujinshi = false
    public var manga = false
    public var artistCG = false
    public var gameCG = false
    public var western = false
    public var nonH = false
    public var imageSet = false
    public var cosplay = false
    public var asianPorn = false
    public var misc = false

    public var advanced = false
    public var galleryName = true
    public var galleryTags = true
    public var galleryDesc = false
    public var torrentFilenames = false
    public var onlyWithTorrents = false
    public var lowPowerTags = false {
        didSet {
            if lowPowerTags {
                downvotedTags = false
            }
        }
    }
    public var downvotedTags = false {
        didSet {
            if downvotedTags {
                lowPowerTags = false
            }
        }
    }
    public var expungedGalleries = false

    public var minRatingActivated = false
    public var minRating = 2

    public var pageRangeActivated = false
    public var pageLowerBound = ""
    public var pageUpperBound = ""

    public var disableLanguage = false
    public var disableUploader = false
    public var disableTags = false

    public mutating func fixInvalidData() {
        if !pageLowerBound.isEmpty && Int(pageLowerBound) == nil {
            pageLowerBound = ""
        }
        if !pageUpperBound.isEmpty && Int(pageUpperBound) == nil {
            pageUpperBound = ""
        }
    }
}

// MARK: Manually decode
extension Filter {
    public init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        doujinshi = (try? container?.decodeIfPresent(Bool.self, forKey: .doujinshi)) ?? false
        manga = (try? container?.decodeIfPresent(Bool.self, forKey: .manga)) ?? false
        artistCG = (try? container?.decodeIfPresent(Bool.self, forKey: .artistCG)) ?? false
        gameCG = (try? container?.decodeIfPresent(Bool.self, forKey: .gameCG)) ?? false
        western = (try? container?.decodeIfPresent(Bool.self, forKey: .western)) ?? false
        nonH = (try? container?.decodeIfPresent(Bool.self, forKey: .nonH)) ?? false
        imageSet = (try? container?.decodeIfPresent(Bool.self, forKey: .imageSet)) ?? false
        cosplay = (try? container?.decodeIfPresent(Bool.self, forKey: .cosplay)) ?? false
        asianPorn = (try? container?.decodeIfPresent(Bool.self, forKey: .asianPorn)) ?? false
        misc = (try? container?.decodeIfPresent(Bool.self, forKey: .misc)) ?? false

        advanced = (try? container?.decodeIfPresent(Bool.self, forKey: .advanced)) ?? false
        galleryName = (try? container?.decodeIfPresent(Bool.self, forKey: .galleryName)) ?? false
        galleryTags = (try? container?.decodeIfPresent(Bool.self, forKey: .galleryTags)) ?? false
        galleryDesc = (try? container?.decodeIfPresent(Bool.self, forKey: .galleryDesc)) ?? false
        torrentFilenames = (try? container?.decodeIfPresent(Bool.self, forKey: .torrentFilenames)) ?? false
        onlyWithTorrents = (try? container?.decodeIfPresent(Bool.self, forKey: .onlyWithTorrents)) ?? false
        lowPowerTags = (try? container?.decodeIfPresent(Bool.self, forKey: .lowPowerTags)) ?? false
        downvotedTags = (try? container?.decodeIfPresent(Bool.self, forKey: .downvotedTags)) ?? false
        expungedGalleries = (try? container?.decodeIfPresent(Bool.self, forKey: .expungedGalleries)) ?? false

        minRatingActivated = (try? container?.decodeIfPresent(Bool.self, forKey: .minRatingActivated)) ?? false
        minRating = (try? container?.decodeIfPresent(Int.self, forKey: .minRating)) ?? 2

        pageRangeActivated = (try? container?.decodeIfPresent(Bool.self, forKey: .pageRangeActivated)) ?? false
        pageLowerBound = (try? container?.decodeIfPresent(String.self, forKey: .pageLowerBound)) ?? ""
        pageUpperBound = (try? container?.decodeIfPresent(String.self, forKey: .pageUpperBound)) ?? ""

        disableLanguage = (try? container?.decodeIfPresent(Bool.self, forKey: .disableLanguage)) ?? false
        disableUploader = (try? container?.decodeIfPresent(Bool.self, forKey: .disableUploader)) ?? false
        disableTags = (try? container?.decodeIfPresent(Bool.self, forKey: .disableTags)) ?? false
    }
}

public enum FilterRange: Int, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case search
    case global
    case watched
}
public extension FilterRange {
    var value: LocalizedStringResource {
        switch self {
        case .search:
            return .filterRangeSearch
        case .global:
            return .filterRangeGlobal
        case .watched:
            return .filterRangeWatched
        }
    }
}
