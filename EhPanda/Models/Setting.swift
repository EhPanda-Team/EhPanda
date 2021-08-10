//
//  Setting.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/09.
//

import SwiftUI
import Foundation
import BetterCodable

struct Setting: Codable {
    // Account
    @DefaultGalleryHost var galleryHost = GalleryHost.ehentai {
        didSet {
            setGalleryHost(with: galleryHost)
        }
    }
    @DefaultFalse var showNewDawnGreeting = false

    // General
    @DefaultFalse var redirectsLinksToSelectedHost = false
    @DefaultFalse var detectsLinksFromPasteboard = false
    @DefaultStringValue var diskImageCacheSize = "0 KB"
    @DefaultTrue var allowsResignActiveBlur = true
    @DefaultAutoLockPolicy var autoLockPolicy: AutoLockPolicy = .never

    // Appearance
    var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil
        }
    }
    @DefaultListMode var listMode: ListMode = isPadWidth ? .thumbnail : .detail
    @DefaultPreferredColorScheme var preferredColorScheme =
        PreferredColorScheme.automatic
    @DefaultColorValue var accentColor: Color = .blue
    @DefaultIconType var appIconType: IconType = .default
    @DefaultFalse var translatesTags = false
    @DefaultFalse var showsSummaryRowTags = false
    @DefaultIntegerValue var summaryRowTagsMaximum = 0

    // Reading
    @DefaultReadingDirection var readingDirection: ReadingDirection = .vertical
    @DefaultIntegerValue var prefetchLimit = 10
    @DefaultIntegerValue var contentRetryLimit = 10
    @DefaultFalse var enablesDualPageMode = false
    @DefaultFalse var exceptCover = false
    @DefaultDoubleValue var contentDividerHeight: Double = 0
    @DefaultDoubleValue var maximumScaleFactor: Double = 3 {
        didSet {
            if doubleTapScaleFactor > maximumScaleFactor {
                doubleTapScaleFactor = maximumScaleFactor
            }
        }
    }
    @DefaultDoubleValue var doubleTapScaleFactor: Double = 2 {
        didSet {
            if maximumScaleFactor < doubleTapScaleFactor {
                maximumScaleFactor = doubleTapScaleFactor
            }
        }
    }

    // Laboratory
    @DefaultFalse var bypassSNIFiltering = false {
        didSet {
            postBypassSNIFilteringDidChangeNotification()
        }
    }
}

enum GalleryHost: String, Codable, CaseIterable, Identifiable {
    case ehentai = "E-Hentai"
    case exhentai = "ExHentai"

    var id: Int { hashValue }
    var abbr: String {
        switch self {
        case .ehentai:
            return "eh"
        case .exhentai:
            return "ex"
        }
    }
}

enum AutoLockPolicy: String, Codable, CaseIterable, Identifiable {
    var id: Int { hashValue }
    var value: Int {
        switch self {
        case .never:
            return -1
        case .instantly:
            return 0
        case .sec15:
            return 15
        case .min1:
            return 60
        case .min5:
            return 300
        case .min10:
            return 600
        case .min30:
            return 1800
        }
    }

    case never = "Never"
    case instantly = "Instantly"
    case sec15 = "15 seconds"
    case min1 = "1 minute"
    case min5 = "5 minutes"
    case min10 = "10 minutes"
    case min30 = "30 minutes"
}

enum PreferredColorScheme: String, Codable, CaseIterable, Identifiable {
    var id: Int { hashValue }

    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"
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
