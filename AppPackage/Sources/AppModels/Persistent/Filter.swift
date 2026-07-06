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
    // Version anchor for future breaking migrations; additive changes ride the tolerant decoder.
    public var schemaVersion = 1
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
        schemaVersion = container.decode(.schemaVersion, default: 1)
        doujinshi = container.decode(.doujinshi, default: false)
        manga = container.decode(.manga, default: false)
        artistCG = container.decode(.artistCG, default: false)
        gameCG = container.decode(.gameCG, default: false)
        western = container.decode(.western, default: false)
        nonH = container.decode(.nonH, default: false)
        imageSet = container.decode(.imageSet, default: false)
        cosplay = container.decode(.cosplay, default: false)
        asianPorn = container.decode(.asianPorn, default: false)
        misc = container.decode(.misc, default: false)

        advanced = container.decode(.advanced, default: false)
        galleryName = container.decode(.galleryName, default: false)
        galleryTags = container.decode(.galleryTags, default: false)
        galleryDesc = container.decode(.galleryDesc, default: false)
        torrentFilenames = container.decode(.torrentFilenames, default: false)
        onlyWithTorrents = container.decode(.onlyWithTorrents, default: false)
        lowPowerTags = container.decode(.lowPowerTags, default: false)
        downvotedTags = container.decode(.downvotedTags, default: false)
        expungedGalleries = container.decode(.expungedGalleries, default: false)

        minRatingActivated = container.decode(.minRatingActivated, default: false)
        minRating = container.decode(.minRating, default: 2)

        pageRangeActivated = container.decode(.pageRangeActivated, default: false)
        pageLowerBound = container.decode(.pageLowerBound, default: "")
        pageUpperBound = container.decode(.pageUpperBound, default: "")

        disableLanguage = container.decode(.disableLanguage, default: false)
        disableUploader = container.decode(.disableUploader, default: false)
        disableTags = container.decode(.disableTags, default: false)
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
