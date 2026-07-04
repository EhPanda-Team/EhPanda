import AppTools
import SwiftUI
import Resources
import Foundation

public struct Setting: Codable, Equatable, Sendable {
    public init(
        galleryHost: GalleryHost = .ehentai,
        showsNewDawnGreeting: Bool = false,
        enablesTagsExtension: Bool = false,
        translatesTags: Bool = false,
        showsTagsSearchSuggestion: Bool = false,
        showsImagesInTags: Bool = false,
        redirectsLinksToSelectedHost: Bool = false,
        detectsLinksFromClipboard: Bool = false,
        backgroundBlurRadius: Double = 10,
        autoLockPolicy: AutoLockPolicy = .never,
        listDisplayMode: ListDisplayMode = .detail,
        accentColor: Color = .blue,
        appIconType: AppIconType = .default,
        showsTagsInList: Bool = false,
        listTagsNumberMaximum: Int = 0,
        displaysJapaneseTitle: Bool = true,
        readingDirection: ReadingDirection = .vertical,
        prefetchLimit: Int = 10,
        enablesLandscape: Bool = false,
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
        self.backgroundBlurRadius = backgroundBlurRadius
        self.autoLockPolicy = autoLockPolicy
        self.listDisplayMode = listDisplayMode
        self.accentColor = accentColor
        self.appIconType = appIconType
        self.showsTagsInList = showsTagsInList
        self.listTagsNumberMaximum = listTagsNumberMaximum
        self.displaysJapaneseTitle = displaysJapaneseTitle
        self.readingDirection = readingDirection
        self.prefetchLimit = prefetchLimit
        self.enablesLandscape = enablesLandscape
        self.enablesDualPageMode = enablesDualPageMode
        self.exceptCover = exceptCover
        self.contentDividerHeight = contentDividerHeight
        self.maximumScaleFactor = maximumScaleFactor
        self.doubleTapScaleFactor = doubleTapScaleFactor
        self.bypassesSNIFiltering = bypassesSNIFiltering
    }
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
    public var backgroundBlurRadius: Double = 10
    public var autoLockPolicy: AutoLockPolicy = .never

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
    public var enablesLandscape = false
    public var enablesDualPageMode = false
    public var exceptCover = false
    public var contentDividerHeight: Double = 0
    public var maximumScaleFactor: Double = 3
    public var doubleTapScaleFactor: Double = 2

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

public enum AutoLockPolicy: Int, Codable, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case never = -1
    case instantly = 0
    case sec15 = 15
    case min1 = 60
    case min5 = 300
    case min10 = 600
    case min30 = 1800
}

extension AutoLockPolicy {
    public var value: LocalizedStringResource {
        switch self {
        case .never:
            return .autoLockPolicyNever
        case .instantly:
            return .autoLockPolicyInstantly
        case .sec15:
            return .RLocalizable.seconds(count: rawValue)
        case .min1, .min5, .min10, .min30:
            return .RLocalizable.minutes(count: rawValue / 60)
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

// reason: the manual Decodable initializer has long per-key decode/default lines
// swiftlint:disable line_length
// MARK: Manually decode
extension Setting {
    public init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        // Account
        galleryHost = (try? container?.decodeIfPresent(GalleryHost.self, forKey: .galleryHost)) ?? .ehentai
        showsNewDawnGreeting = (try? container?.decodeIfPresent(Bool.self, forKey: .showsNewDawnGreeting)) ?? false
        // General
        enablesTagsExtension = (try? container?.decodeIfPresent(Bool.self, forKey: .enablesTagsExtension)) ?? false
        translatesTags = (try? container?.decodeIfPresent(Bool.self, forKey: .translatesTags)) ?? false
        showsTagsSearchSuggestion = (try? container?.decodeIfPresent(Bool.self, forKey: .showsTagsSearchSuggestion)) ?? false
        showsImagesInTags = (try? container?.decodeIfPresent(Bool.self, forKey: .showsImagesInTags)) ?? false
        redirectsLinksToSelectedHost = (try? container?.decodeIfPresent(Bool.self, forKey: .redirectsLinksToSelectedHost)) ?? false
        detectsLinksFromClipboard = (try? container?.decodeIfPresent(Bool.self, forKey: .detectsLinksFromClipboard)) ?? false
        backgroundBlurRadius = (try? container?.decodeIfPresent(Double.self, forKey: .backgroundBlurRadius)) ?? 10
        autoLockPolicy = (try? container?.decodeIfPresent(AutoLockPolicy.self, forKey: .autoLockPolicy)) ?? .never
        // Appearance
        listDisplayMode = (try? container?.decodeIfPresent(ListDisplayMode.self, forKey: .listDisplayMode)) ?? .detail
        preferredColorScheme = (try? container?.decodeIfPresent(PreferredColorScheme.self, forKey: .preferredColorScheme)) ?? .automatic
        accentColor = (try? container?.decodeIfPresent(Color.self, forKey: .accentColor)) ?? .blue
        appIconType = (try? container?.decodeIfPresent(AppIconType.self, forKey: .appIconType)) ?? .default
        showsTagsInList = (try? container?.decodeIfPresent(Bool.self, forKey: .showsTagsInList)) ?? false
        listTagsNumberMaximum = (try? container?.decodeIfPresent(Int.self, forKey: .listTagsNumberMaximum)) ?? 0
        displaysJapaneseTitle = (try? container?.decodeIfPresent(Bool.self, forKey: .displaysJapaneseTitle)) ?? true
        // Reading
        readingDirection = (try? container?.decodeIfPresent(ReadingDirection.self, forKey: .readingDirection)) ?? .vertical
        prefetchLimit = (try? container?.decodeIfPresent(Int.self, forKey: .prefetchLimit)) ?? 10
        enablesLandscape = (try? container?.decodeIfPresent(Bool.self, forKey: .enablesLandscape)) ?? false
        enablesDualPageMode = (try? container?.decodeIfPresent(Bool.self, forKey: .enablesDualPageMode)) ?? false
        exceptCover = (try? container?.decodeIfPresent(Bool.self, forKey: .exceptCover)) ?? false
        contentDividerHeight = (try? container?.decodeIfPresent(Double.self, forKey: .contentDividerHeight)) ?? 0
        maximumScaleFactor = (try? container?.decodeIfPresent(Double.self, forKey: .maximumScaleFactor)) ?? 3
        doubleTapScaleFactor = (try? container?.decodeIfPresent(Double.self, forKey: .doubleTapScaleFactor)) ?? 2
        // Downloads
        downloadThreadLimit = (try? container?.decodeIfPresent(Int.self, forKey: .downloadThreadLimit)) ?? 1
        downloadAllowCellular = (try? container?.decodeIfPresent(Bool.self, forKey: .downloadAllowCellular)) ?? true
        downloadAutoRetryFailedPages = (
            try? container?.decodeIfPresent(Bool.self, forKey: .downloadAutoRetryFailedPages)
        ) ?? true
        // Laboratory
        bypassesSNIFiltering = (try? container?.decodeIfPresent(Bool.self, forKey: .bypassesSNIFiltering)) ?? false
    }
}
// swiftlint:enable line_length
