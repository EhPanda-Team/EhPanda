//
//  Filter.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

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

    var advanced = false
    var galleryName = true
    var galleryTags = true
    var galleryDesc = false
    var torrentFilenames = false
    var onlyWithTorrents = false
    var lowPowerTags = false {
        didSet {
            if lowPowerTags == true {
                downvotedTags = false
            }
        }
    }
    var downvotedTags = false {
        didSet {
            if downvotedTags == true {
                lowPowerTags = false
            }
        }
    }
    var expungedGalleries = false

    var minRatingActivated = false
    var minRating: Int = 2

    var pageRangeActivated = false
    var pageLowerBound: String = ""
    var pageUpperBound: String = ""

    var disableLanguage = false
    var disableUploader = false
    var disableTags = false
}

struct AssociatedCategory: Codable {
    let category: Category
    var isFiltered: Bool
    var color: Color {
        category.color
    }
}
