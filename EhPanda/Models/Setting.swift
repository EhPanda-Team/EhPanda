//
//  Setting.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/09.
//

import SwiftUI
import Foundation
import ComposableArchitecture

struct Setting: Codable, Equatable {
    // Account
    var galleryHost: GalleryHost = .ehentai
    var showsNewDawnGreeting = false

    // General
    var redirectsLinksToSelectedHost = false
    var detectsLinksFromPasteboard = false
    var backgroundBlurRadius: Double = 10
    var autoLockPolicy: AutoLockPolicy = .never

    // Appearance
    var listMode: ListMode = DeviceUtil.isPadWidth ? .thumbnail : .detail
    var preferredColorScheme = PreferredColorScheme.automatic
    var accentColor: Color = .blue
    var appIconType: AppIconType = .default
    var translatesTags = false
    var showsSummaryRowTags = false
    var summaryRowTagsMaximum = 0

    // Reading
    var readingDirection: ReadingDirection = .vertical
    var prefetchLimit = 10
    var prefersLandscape = false
    var enablesDualPageMode = false
    var exceptCover = false
    var contentDividerHeight: Double = 0
    var maximumScaleFactor: Double = 3
    var doubleTapScaleFactor: Double = 2

    // Laboratory
    var bypassesSNIFiltering = false
}

enum GalleryHost: String, Codable, CaseIterable, Identifiable {
    case ehentai = "E-Hentai"
    case exhentai = "ExHentai"

    var id: Int { hashValue }
    var url: URL {
        switch self {
        case .ehentai:
            return Defaults.URL.ehentai
        case .exhentai:
            return Defaults.URL.exhentai
        }
    }
    var abbr: String {
        switch self {
        case .ehentai:
            return "eh"
        case .exhentai:
            return "ex"
        }
    }
}

enum AutoLockPolicy: Int, Codable, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case never = -1
    case instantly = 0
    case sec15 = 15
    case min1 = 60
    case min5 = 300
    case min10 = 600
    case min30 = 1800
}

extension AutoLockPolicy {
    var descriptionKey: LocalizedStringKey {
        switch self {
        case .never:
            return "Never"
        case .instantly:
            return "Instantly"
        case .sec15:
            return "\(15) seconds"
        case .min1:
            return "\(1) minute"
        case .min5:
            return "\(5) minutes"
        case .min10:
            return "\(10) minute"
        case .min30:
            return "\(30) minute"
        }
    }
}

enum PreferredColorScheme: String, Codable, CaseIterable, Identifiable {
    var id: Int { hashValue }

    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"

    var userInterfaceStyle: UIUserInterfaceStyle {
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

enum ReadingDirection: String, Codable, CaseIterable, Identifiable {
    var id: Int { hashValue }

    case vertical = "READING_DIRECTION_VERTICAL"
    case rightToLeft = "Right-to-left"
    case leftToRight = "Left-to-right"
}

enum ListMode: String, Codable, CaseIterable, Identifiable {
    var id: Int { hashValue }

    case detail = "LIST_DISPLAY_MODE_DETAIL"
    case thumbnail = "LIST_DISPLAY_MODE_THUMBNAIL"
}

// swiftlint:disable line_length
// MARK: Manually decode
extension Setting {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Account
        galleryHost = try container.decodeIfPresent(GalleryHost.self, forKey: .galleryHost) ?? .ehentai
        showsNewDawnGreeting = try container.decodeIfPresent(Bool.self, forKey: .showsNewDawnGreeting) ?? false
        // General
        redirectsLinksToSelectedHost = try container.decodeIfPresent(Bool.self, forKey: .redirectsLinksToSelectedHost) ?? false
        detectsLinksFromPasteboard = try container.decodeIfPresent(Bool.self, forKey: .detectsLinksFromPasteboard) ?? false
        backgroundBlurRadius = try container.decodeIfPresent(Double.self, forKey: .backgroundBlurRadius) ?? 10
        autoLockPolicy = try container.decodeIfPresent(AutoLockPolicy.self, forKey: .autoLockPolicy) ?? .never
        // Appearance
        listMode = try container.decodeIfPresent(ListMode.self, forKey: .listMode) ?? (DeviceUtil.isPadWidth ? .thumbnail : .detail)
        preferredColorScheme = try container.decodeIfPresent(PreferredColorScheme.self, forKey: .preferredColorScheme) ?? .automatic
        accentColor = try container.decodeIfPresent(Color.self, forKey: .accentColor) ?? .blue
        appIconType = try container.decodeIfPresent(AppIconType.self, forKey: .appIconType) ?? .default
        translatesTags = try container.decodeIfPresent(Bool.self, forKey: .translatesTags) ?? false
        showsSummaryRowTags = try container.decodeIfPresent(Bool.self, forKey: .showsSummaryRowTags) ?? false
        summaryRowTagsMaximum = try container.decodeIfPresent(Int.self, forKey: .summaryRowTagsMaximum) ?? 0
        // Reading
        readingDirection = try container.decodeIfPresent(ReadingDirection.self, forKey: .readingDirection) ?? .vertical
        prefetchLimit = try container.decodeIfPresent(Int.self, forKey: .prefetchLimit) ?? 10
        prefersLandscape = try container.decodeIfPresent(Bool.self, forKey: .prefersLandscape) ?? false
        enablesDualPageMode = try container.decodeIfPresent(Bool.self, forKey: .enablesDualPageMode) ?? false
        exceptCover = try container.decodeIfPresent(Bool.self, forKey: .exceptCover) ?? false
        contentDividerHeight = try container.decodeIfPresent(Double.self, forKey: .contentDividerHeight) ?? 0
        maximumScaleFactor = try container.decodeIfPresent(Double.self, forKey: .maximumScaleFactor) ?? 3
        doubleTapScaleFactor = try container.decodeIfPresent(Double.self, forKey: .doubleTapScaleFactor) ?? 2
        // Laboratory
        bypassesSNIFiltering = try container.decodeIfPresent(Bool.self, forKey: .bypassesSNIFiltering) ?? false
    }
}
// swiftlint:enable line_length
