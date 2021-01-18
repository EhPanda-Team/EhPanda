//
//  Setting.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/09.
//

import UIKit
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
    var hideSideBar = false
    var showSummaryRowTags = false
    var summaryRowTagsMaximumActivated = false
    var rawSummaryRowTagsMaximum = ""
    var summaryRowTagsMaximum: Int {
        Int(rawSummaryRowTagsMaximum) ?? .max
    }
    var showContentDividers = false
    var contentDividerHeight: CGFloat = 0
    var contentRetryLimit: Int = 30
}
