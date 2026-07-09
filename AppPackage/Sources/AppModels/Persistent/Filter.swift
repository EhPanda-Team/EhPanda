import SwiftUI
import Resources

public struct Filter: Codable, Equatable, Sendable, SchemaVersioned {
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
    /// Migration maps, one slot per schema version (index 0 = v1 = `.passthrough`). `currentSchemaVersion`
    /// is derived from the count; append a map and adopt `MigratableModel` when a breaking v2 lands.
    public static let migrations: [SchemaMigration<Filter>] = [.passthrough]
    // A self-validating field: it rejects a newer/downgrade blob on decode (see `SchemaVersion`), which
    // fails the whole decode so Sharing resets to the key default. Synthesized Codable is otherwise
    // untouched, so the `didSet` couplings below and optional-field tolerance still hold; a field added
    // later must stay optional so old blobs keep decoding.
    public var schemaVersion: SchemaVersion<Filter> = 1
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
