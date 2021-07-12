//
//  Setting.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/09.
//

import UIKit
import SwiftUI
import Foundation

struct Setting: Codable {
    // Account
    var galleryType = GalleryType.ehentai {
        didSet {
            setGalleryType(with: galleryType)
        }
    }
    var showNewDawnGreeting = false

    // General
    var closesSlideMenuAfterSelection = true
    var redirectsLinksToSelectedHost = false
    var detectsLinksFromPasteboard = false
    var allowsDetectionWhenNoChanges = false
    var diskImageCacheSize = "0 KB"
    var allowsResignActiveBlur = true
    var autoLockPolicy: AutoLockPolicy = .never

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
    var preferredColorScheme: PreferredColorScheme = .automatic
    var accentColor: Color = .blue
    var appIconType: IconType = .default
    var translatesCategory = true
    var showsSummaryRowTags = false
    var summaryRowTagsMaximumActivated = false
    var summaryRowTagsMaximum: Int = 5

    // Reading
    var contentRetryLimit = 10
    var contentDividerHeight: CGFloat = 0
    var maximumScaleFactor: CGFloat = 3 {
        didSet {
            if doubleTapScaleFactor > maximumScaleFactor {
                doubleTapScaleFactor = maximumScaleFactor
            }
        }
    }
    var doubleTapScaleFactor: CGFloat = 2 {
        didSet {
            if maximumScaleFactor < doubleTapScaleFactor {
                maximumScaleFactor = doubleTapScaleFactor
            }
        }
    }
}

enum GalleryType: String, Codable {
    case ehentai = "E-Hentai"
    case exhentai = "ExHentai"

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
