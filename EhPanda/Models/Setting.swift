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
    var galleryType = GalleryType.eh {
        didSet {
            setGalleryType(galleryType)
        }
    }
    
    // General
    var detectGalleryFromPasteboard = false
    var allowsDetectionWhenNoChange = false
    var closeSlideMenuAfterSelection = true
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
    var appIconType: IconType = .Default
    var translateCategory = true
    var showSummaryRowTags = false
    var summaryRowTagsMaximumActivated = false
    var summaryRowTagsMaximum: Int = 5
    
    // Reading
    var contentRetryLimit = 10
    var showContentDividers = false
    var contentDividerHeight: CGFloat = 0
}


public enum GalleryType: String, Codable {
    case eh = "E-Hentai"
    case ex = "ExHentai"
    
    var abbr: String {
        switch self {
        case .eh:
            return "eh"
        case .ex:
            return "ex"
        }
    }
}

public enum AutoLockPolicy: String, Codable, CaseIterable, Identifiable {
    public var id: Int { hashValue }
    var value: Int {
        switch self {
        case .never:
            return -1
        case .instantly:
            return 0
        case .s15:
            return 15
        case .m1:
            return 60
        case .m5:
            return 300
        case .m10:
            return 600
        case .m30:
            return 1800
        }
    }
    
    case never = "Never"
    case instantly = "Instantly"
    case s15 = "15 seconds"
    case m1 = "1 minute"
    case m5 = "5 minutes"
    case m10 = "10 minutes"
    case m30 = "30 minutes"
}

public enum PreferredColorScheme: String, Codable, CaseIterable, Identifiable {
    public var id: Int { hashValue }
    
    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"
}
