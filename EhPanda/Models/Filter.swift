//
//  Filter.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI
import BetterCodable

struct Filter: Codable {
    var doujinshi = AssociatedCategory(category: .doujinshi, isFiltered: false)
    var manga = AssociatedCategory(category: .manga, isFiltered: false)
    var artistCG = AssociatedCategory(category: .artistCG, isFiltered: false)
    var gameCG = AssociatedCategory(category: .gameCG, isFiltered: false)
    var western = AssociatedCategory(category: .western, isFiltered: false)
    var nonH = AssociatedCategory(category: .nonH, isFiltered: false)
    var imageSet = AssociatedCategory(category: .imageSet, isFiltered: false)
    var cosplay = AssociatedCategory(category: .cosplay, isFiltered: false)
    var asianPorn = AssociatedCategory(category: .asianPorn, isFiltered: false)
    var misc = AssociatedCategory(category: .misc, isFiltered: false)

    @DefaultFalse var advanced = false
    @DefaultTrue var galleryName = true
    @DefaultTrue var galleryTags = true
    @DefaultFalse var galleryDesc = false
    @DefaultFalse var torrentFilenames = false
    @DefaultFalse var onlyWithTorrents = false
    @DefaultFalse var lowPowerTags = false {
        didSet {
            if lowPowerTags {
                downvotedTags = false
            }
        }
    }
    @DefaultFalse var downvotedTags = false {
        didSet {
            if downvotedTags {
                lowPowerTags = false
            }
        }
    }
    @DefaultFalse var expungedGalleries = false

    @DefaultFalse var minRatingActivated = false
    @DefaultIntegerValue var minRating: Int = 2

    @DefaultFalse var pageRangeActivated = false
    @DefaultStringValue var pageLowerBound: String = "" {
        didSet {
            if Int(pageLowerBound) == nil
                && !pageLowerBound.isEmpty
            {
                pageLowerBound = ""
            }
        }
    }
    @DefaultStringValue var pageUpperBound: String = "" {
        didSet {
            if Int(pageUpperBound) == nil
                && !pageUpperBound.isEmpty
            {
                pageUpperBound = ""
            }
        }
    }

    @DefaultFalse var disableLanguage = false
    @DefaultFalse var disableUploader = false
    @DefaultFalse var disableTags = false
}

struct AssociatedCategory: Codable {
    let category: Category
    var isFiltered: Bool
    var color: Color {
        category.color
    }
}
