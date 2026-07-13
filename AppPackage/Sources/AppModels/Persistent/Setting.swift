import AppTools
import SwiftUI
import Resources
import Foundation

public struct Setting: Codable, Equatable, Sendable, SchemaVersioned {
    public init(
        galleryHost: GalleryHost = .ehentai,
        showsNewDawnGreeting: Bool = false,
        enablesTagsExtension: Bool = false,
        translatesTags: Bool = false,
        showsTagsSearchSuggestion: Bool = false,
        showsImagesInTags: Bool = false,
        redirectsLinksToSelectedHost: Bool = false,
        detectsLinksFromClipboard: Bool = false,
        privacyMaskIntensity: Double = 10,
        listDisplayMode: ListDisplayMode = .detail,
        accentColor: Color = .blue,
        appIconType: AppIconType = .default,
        showsTagsInList: Bool = false,
        listTagsNumberMaximum: Int = 0,
        displaysJapaneseTitle: Bool = true,
        readingDirection: ReadingDirection = .vertical,
        prefetchLimit: Int = 10,
        enablesDualPageMode: Bool = false,
        exceptCover: Bool = false,
        contentDividerHeight: Double = 0,
        maximumScaleFactor: Double = 3,
        doubleTapScaleFactor: Double = 2,
        bypassesSNIFiltering: Bool = false
    ) {
        self.galleryHost = galleryHost
        self.showsNewDawnGreeting = showsNewDawnGreeting
        self.enablesTagsExtension = enablesTagsExtension
        self.translatesTags = translatesTags
        self.showsTagsSearchSuggestion = showsTagsSearchSuggestion
        self.showsImagesInTags = showsImagesInTags
        self.redirectsLinksToSelectedHost = redirectsLinksToSelectedHost
        self.detectsLinksFromClipboard = detectsLinksFromClipboard
        self.privacyMaskIntensity = privacyMaskIntensity
        self.listDisplayMode = listDisplayMode
        self.accentColor = accentColor
        self.appIconType = appIconType
        self.showsTagsInList = showsTagsInList
        self.listTagsNumberMaximum = listTagsNumberMaximum
        self.displaysJapaneseTitle = displaysJapaneseTitle
        self.readingDirection = readingDirection
        self.prefetchLimit = prefetchLimit
        self.enablesDualPageMode = enablesDualPageMode
        self.exceptCover = exceptCover
        self.contentDividerHeight = contentDividerHeight
        self.maximumScaleFactor = maximumScaleFactor
        self.doubleTapScaleFactor = doubleTapScaleFactor
        self.bypassesSNIFiltering = bypassesSNIFiltering
    }
    /// This model's schema history (oldest → newest); see `SchemaVersioned` / `VersionedSchema`.
    /// `currentSchemaVersion` derives from the head. Append a `VersionedSchema` and adopt
    /// `MigratableModel` when a breaking change lands.
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    /// The v1 base schema. Its `migrate` is empty — nothing precedes v1, and the engine only runs
    /// schemas newer than the stored version, so it exists solely to anchor version 1.
    enum SchemaV1: VersionedSchema {
        static let version = 1
        static func migrate(_ object: inout [String: JSONValue]) throws {}
    }
    // A self-validating field: it rejects a newer/downgrade blob on decode (see `SchemaVersion`), which
    // fails the whole decode so Sharing resets to the key default. Synthesized Codable is otherwise
    // untouched, so the `didSet` couplings below and optional-field tolerance still hold; a field added
    // later must stay optional so old blobs keep decoding.
    public var schemaVersion: SchemaVersion<Setting> = 1
    // Account
    public var galleryHost: GalleryHost = .ehentai
    public var showsNewDawnGreeting = false

    // General
    public var enablesTagsExtension = false {
        didSet {
            if !enablesTagsExtension {
                translatesTags = false
                showsTagsSearchSuggestion = false
                showsImagesInTags = false
            }
        }
    }
    public var translatesTags = false
    public var showsTagsSearchSuggestion = false
    public var showsImagesInTags = false
    public var redirectsLinksToSelectedHost = false
    public var detectsLinksFromClipboard = false
    public var privacyMaskIntensity: Double = 10

    // Appearance
    public var listDisplayMode: ListDisplayMode = .detail
    public var preferredColorScheme = PreferredColorScheme.automatic
    public var accentColor: Color = .blue
    public var appIconType: AppIconType = .default
    public var showsTagsInList = false
    public var listTagsNumberMaximum = 0
    public var displaysJapaneseTitle = true

    // Reading
    public var readingDirection: ReadingDirection = .vertical
    public var prefetchLimit = 10
    public var enablesDualPageMode = false
    public var exceptCover = false
    public var contentDividerHeight: Double = 0
    // The two scale factors are mutually clamped so `doubleTapScaleFactor <= maximumScaleFactor`
    // always holds, regardless of the write path — SettingReducer's editor or the reader sheet's
    // direct `@Shared(.setting)` binding. Keeping the invariant on the model (not in a reducer's
    // `BindingReducer`) is what lets a write skip the reducer and still stay consistent.
    public var maximumScaleFactor: Double = 3 {
        didSet {
            if doubleTapScaleFactor > maximumScaleFactor {
                doubleTapScaleFactor = maximumScaleFactor
            }
        }
    }
    public var doubleTapScaleFactor: Double = 2 {
        didSet {
            if maximumScaleFactor < doubleTapScaleFactor {
                maximumScaleFactor = doubleTapScaleFactor
            }
        }
    }

    // Downloads
    public static let downloadThreadLimitDefaultValue = 1
    public static let downloadAllowCellularDefaultValue = true
    public static let downloadAutoRetryFailedPagesDefaultValue = true

    public var downloadThreadLimit = Self.downloadThreadLimitDefaultValue
    public var downloadAllowCellular = Self.downloadAllowCellularDefaultValue
    public var downloadAutoRetryFailedPages = Self.downloadAutoRetryFailedPagesDefaultValue

    // Laboratory
    public var bypassesSNIFiltering = false
}

extension Setting {
    public var downloadRequestOptions: DownloadRequestOptions {
        .init(
            threadLimit: downloadThreadLimit,
            allowCellular: downloadAllowCellular,
            autoRetryFailedPages: downloadAutoRetryFailedPages
        )
    }
}

public enum GalleryHost: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case ehentai = "E-Hentai"
    case exhentai = "ExHentai"

    public var id: Int { hashValue }
    public var url: URL {
        switch self {
        case .ehentai:
            return Defaults.URL.ehentai
        case .exhentai:
            return Defaults.URL.exhentai
        }
    }
    public var cookieURLs: [URL] {
        switch self {
        case .ehentai:
            return [Defaults.URL.ehentai]

        case .exhentai:
            return [Defaults.URL.exhentai, Defaults.URL.sexhentai]
        }
    }
    public var abbr: String {
        switch self {
        case .ehentai:
            return "eh"
        case .exhentai:
            return "ex"
        }
    }
}

public enum PreferredColorScheme: Int, Codable, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case automatic
    case light
    case dark
}
extension PreferredColorScheme {
    public var value: LocalizedStringResource {
        switch self {
        case .automatic:
            return .preferredColorSchemeAutomatic
        case .light:
            return .preferredColorSchemeLight
        case .dark:
            return .preferredColorSchemeDark
        }
    }
    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .automatic:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

public enum ReadingDirection: Int, Codable, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case vertical
    case rightToLeft
    case leftToRight
}
extension ReadingDirection {
    public var value: LocalizedStringResource {
        switch self {
        case .vertical:
            return .readingDirectionVertical
        case .rightToLeft:
            return .readingDirectionRightToLeft
        case .leftToRight:
            return .readingDirectionLeftToRight
        }
    }
}

public enum ListDisplayMode: Int, Codable, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case detail
    case thumbnail
}
extension ListDisplayMode {
    public var value: LocalizedStringResource {
        switch self {
        case .detail:
            return .listDisplayModeDetail
        case .thumbnail:
            return .listDisplayModeThumbnail
        }
    }
}
