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
    var galleryType = GalleryType.eh {
        didSet {
            UserDefaults
                .standard
                .setValue(
                    galleryType
                        .rawValue,
                    forKey: "GalleryType"
                )
        }
    }
    
    var diskImageCacheSize = "0 KB"
    
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
    var appIconType: IconType = .Default
    var closeSlideMenuAfterSelection = true
    var translateCategory = true
    var showSummaryRowTags = false
    var summaryRowTagsMaximumActivated = false
    var rawSummaryRowTagsMaximum = ""
    var summaryRowTagsMaximum: Int {
        Int(rawSummaryRowTagsMaximum) ?? .max
    }
    
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

public enum PreferredColorScheme: String, Codable, CaseIterable, Identifiable {
    public var id: Int { hashValue }
    
    case automatic = "自動"
    case light = "ライト"
    case dark = "ダーク"
}
