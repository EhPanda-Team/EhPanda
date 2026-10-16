import AppTools
public import Foundation
import Resources
public import UIKit

public struct Setting: Codable, Equatable, Sendable, MigratableModel {
    public init(
        galleryHost: GalleryHost = .ehentai,
        showNewDawnGreeting: Bool = false,
        enableTagsExtension: Bool = false,
        translateTags: Bool = false,
        showTagsSearchSuggestion: Bool = false,
        showImagesInTags: Bool = false,
        redirectLinksToSelectedHost: Bool = false,
        detectLinksFromClipboard: Bool = false,
        privacyMaskIntensity: Double = 10,
        galleryListPresentation: GalleryListPresentation = .init(),
        appIconType: AppIconType = .default,
        showTagsInList: Bool = false,
        listTagsNumberMaximum: Int = 0,
        displayJapaneseTitle: Bool = true,
        simplifyGalleryTitles: Bool = true,
        readingDirection: ReadingDirection = .vertical,
        readingOrientation: ReadingOrientationPreferences = .init(),
        prefetchLimit: Int = 10,
        enableDualPageMode: Bool = false,
        exceptCover: Bool = false,
        contentDividerHeight: Double = 0,
        maximumScaleFactor: Double = 3,
        doubleTapScaleFactor: Double = 2,
        bypassSNIFiltering: Bool = false
    ) {
        self.galleryHost = galleryHost
        self.showNewDawnGreeting = showNewDawnGreeting
        self.enableTagsExtension = enableTagsExtension
        self.translateTags = translateTags
        self.showTagsSearchSuggestion = showTagsSearchSuggestion
        self.showImagesInTags = showImagesInTags
        self.redirectLinksToSelectedHost = redirectLinksToSelectedHost
        self.detectLinksFromClipboard = detectLinksFromClipboard
        self.privacyMaskIntensity = privacyMaskIntensity
        self.galleryListPresentation = galleryListPresentation
        self.appIconType = appIconType
        self.showTagsInList = showTagsInList
        self.listTagsNumberMaximum = listTagsNumberMaximum
        self.displayJapaneseTitle = displayJapaneseTitle
        self.simplifyGalleryTitles = simplifyGalleryTitles
        self.readingDirection = readingDirection
        self.readingOrientation = readingOrientation
        self.prefetchLimit = prefetchLimit
        self.enableDualPageMode = enableDualPageMode
        self.exceptCover = exceptCover
        self.contentDividerHeight = contentDividerHeight
        self.maximumScaleFactor = maximumScaleFactor
        self.doubleTapScaleFactor = doubleTapScaleFactor
        self.bypassSNIFiltering = bypassSNIFiltering
    }
    /// This model's schema history (oldest → newest); see `SchemaVersioned` / `VersionedSchema`.
    /// `currentSchemaVersion` derives from the head. Append a `VersionedSchema` and adopt
    /// `MigratableModel` when a breaking change lands.
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    /// The v1 base schema. Its `migrate` is empty — nothing precedes v1, and the engine only runs
    /// schemas newer than the stored version, so it exists solely to anchor version 1.
    enum SchemaV1: VersionedSchema {
        static let version = 1
        static func migrate(_ object: inout [String: JSONValue]) throws {}
    }
    enum SchemaV2: VersionedSchema {
        static let version = 2

        static func migrate(_ object: inout [String: JSONValue]) throws {
            guard let rawValue = object["listDisplayMode"]?.intValue else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [], debugDescription: "Setting v1 is missing listDisplayMode"
                ))
            }
            let mode: GalleryListDisplayMode
            switch rawValue {
            case 0: mode = .row
            case 1: mode = .grid
            default:
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [], debugDescription: "Setting v1 has an invalid listDisplayMode"
                ))
            }
            let scopes = GalleryListScope.allCases.reduce(into: [String: JSONValue]()) { result, scope in
                result[scope.rawValue] = .int(scope == .downloads ? GalleryListDisplayMode.row.rawValue : mode.rawValue)
            }
            object["galleryListPresentation"] = .object(scopes)
            object["listDisplayMode"] = nil
        }
    }

    public init(from decoder: any Decoder) throws {
        self = try SchemaMigrator.migrate(Self.self, from: decoder)
    }

    public init(currentFrom decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(SchemaVersion<Setting>.self, forKey: .schemaVersion)
        galleryHost = try container.decode(GalleryHost.self, forKey: .galleryHost)
        showNewDawnGreeting = try container.decode(Bool.self, forKey: .showNewDawnGreeting)
        enableTagsExtension = try container.decode(Bool.self, forKey: .enableTagsExtension)
        translateTags = try container.decode(Bool.self, forKey: .translateTags)
        showTagsSearchSuggestion = try container.decode(Bool.self, forKey: .showTagsSearchSuggestion)
        showImagesInTags = try container.decode(Bool.self, forKey: .showImagesInTags)
        redirectLinksToSelectedHost = try container.decode(Bool.self, forKey: .redirectLinksToSelectedHost)
        detectLinksFromClipboard = try container.decode(Bool.self, forKey: .detectLinksFromClipboard)
        privacyMaskIntensity = try container.decode(Double.self, forKey: .privacyMaskIntensity)
        galleryListPresentation = try container.decode(GalleryListPresentation.self, forKey: .galleryListPresentation)
        preferredColorScheme = try container.decode(PreferredColorScheme.self, forKey: .preferredColorScheme)
        appIconType = try container.decode(AppIconType.self, forKey: .appIconType)
        showTagsInList = try container.decode(Bool.self, forKey: .showTagsInList)
        listTagsNumberMaximum = try container.decode(Int.self, forKey: .listTagsNumberMaximum)
        displayJapaneseTitle = try container.decode(Bool.self, forKey: .displayJapaneseTitle)
        simplifiedGalleryTitles = try container.decodeIfPresent(Bool.self, forKey: .simplifiedGalleryTitles)
        readingDirection = try container.decode(ReadingDirection.self, forKey: .readingDirection)
        prefetchLimit = try container.decode(Int.self, forKey: .prefetchLimit)
        enableDualPageMode = try container.decode(Bool.self, forKey: .enableDualPageMode)
        orientationReadingPreferences = try container.decodeIfPresent(
            ReadingOrientationPreferences.self, forKey: .orientationReadingPreferences
        )
        exceptCover = try container.decode(Bool.self, forKey: .exceptCover)
        contentDividerHeight = try container.decode(Double.self, forKey: .contentDividerHeight)
        maximumScaleFactor = try container.decode(Double.self, forKey: .maximumScaleFactor)
        doubleTapScaleFactor = try container.decode(Double.self, forKey: .doubleTapScaleFactor)
        downloadThreadLimit = try container.decode(Int.self, forKey: .downloadThreadLimit)
        downloadAllowCellular = try container.decode(Bool.self, forKey: .downloadAllowCellular)
        downloadAutoRetryFailedPages = try container.decode(Bool.self, forKey: .downloadAutoRetryFailedPages)
        shareAnalyticsData = try container.decodeIfPresent(Bool.self, forKey: .shareAnalyticsData)
        bypassSNIFiltering = try container.decode(Bool.self, forKey: .bypassSNIFiltering)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, galleryHost, showNewDawnGreeting, enableTagsExtension, translateTags
        case showTagsSearchSuggestion, showImagesInTags, redirectLinksToSelectedHost
        case detectLinksFromClipboard, privacyMaskIntensity, galleryListPresentation, preferredColorScheme
        case appIconType, showTagsInList, listTagsNumberMaximum, displayJapaneseTitle, readingDirection
        case prefetchLimit, enableDualPageMode, orientationReadingPreferences, exceptCover, simplifiedGalleryTitles
        case contentDividerHeight, maximumScaleFactor, doubleTapScaleFactor, downloadThreadLimit
        case downloadAllowCellular, downloadAutoRetryFailedPages, shareAnalyticsData, bypassSNIFiltering
    }
    // A self-validating field: it rejects a newer/downgrade blob on decode (see `SchemaVersion`), which
    // fails the whole decode so Sharing resets to the key default. Synthesized Codable is otherwise
    // untouched, so the `didSet` couplings below and optional-field tolerance still hold; a field added
    // later must stay optional so old blobs keep decoding.
    public var schemaVersion: SchemaVersion<Setting> = 2
    // Account
    public var galleryHost: GalleryHost = .ehentai
    public var showNewDawnGreeting = false

    // General
    public var enableTagsExtension = false {
        didSet {
            if !enableTagsExtension {
                translateTags = false
                showTagsSearchSuggestion = false
                showImagesInTags = false
            }
        }
    }
    public var translateTags = false
    public var showTagsSearchSuggestion = false
    public var showImagesInTags = false
    public var redirectLinksToSelectedHost = false
    public var detectLinksFromClipboard = false
    public var privacyMaskIntensity: Double = 10

    // Appearance
    public var galleryListPresentation = GalleryListPresentation()
    public var preferredColorScheme = PreferredColorScheme.automatic
    public var appIconType: AppIconType = .default
    public var showTagsInList = false
    public var listTagsNumberMaximum = 0
    public var displayJapaneseTitle = true
    // Optional storage preserves settings written before this default-enabled presentation option.
    public var simplifiedGalleryTitles: Bool?

    public var simplifyGalleryTitles: Bool {
        get { simplifiedGalleryTitles ?? true }
        set { simplifiedGalleryTitles = newValue }
    }

    // Reading
    public var readingDirection: ReadingDirection = .vertical
    public var prefetchLimit = 10
    public var enableDualPageMode = false
    // Optional storage keeps settings written before orientation automation decodable.
    public var orientationReadingPreferences: ReadingOrientationPreferences?

    public var readingOrientation: ReadingOrientationPreferences {
        get { orientationReadingPreferences ?? .init() }
        set { orientationReadingPreferences = newValue }
    }

    /// Enabling the toolbar's two-page option also selects a horizontal reading direction.
    public var usesHorizontalDualPages: Bool {
        get { enableDualPageMode && readingDirection != .vertical }
        set {
            enableDualPageMode = newValue
            if newValue && readingDirection == .vertical {
                readingDirection = readingOrientation.landscapeDirection.readingDirection
            }
        }
    }

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

    // Analytics
    // Optional by necessity, not by taste: synthesized `Codable` throws on a missing non-optional key,
    // so a `Setting` blob written before this field existed would fail to decode and reset every other
    // preference to its default. `nil` therefore means "written before the toggle shipped", which is
    // the opt-in state the build already had. Read it through ``isSharingAnalyticsData``, not directly.
    public var shareAnalyticsData: Bool?

    /// Whether analytics may be sent, resolving the pre-toggle `nil` blob to the shipped default.
    ///
    /// Settable so a SwiftUI `Toggle` can bind to a plain `Bool`; writing here is what first pins the
    /// stored value, after which `nil` never reappears.
    public var isSharingAnalyticsData: Bool {
        get { shareAnalyticsData ?? true }
        set { shareAnalyticsData = newValue }
    }

    // Laboratory
    public var bypassSNIFiltering = false
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
