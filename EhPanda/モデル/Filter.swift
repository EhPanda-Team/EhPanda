//
//  Filter.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct Filter: Codable {
    // ブール値が真の場合、検索結果に出すことを意味する
    var doujinshi = AssociatedCategory(category: .Doujinshi, isFiltered: false)
    var manga = AssociatedCategory(category: .Manga, isFiltered: false)
    var artist_CG = AssociatedCategory(category: .Artist_CG, isFiltered: false)
    var game_CG = AssociatedCategory(category: .Game_CG, isFiltered: false)
    var western = AssociatedCategory(category: .Western, isFiltered: false)
    var non_h = AssociatedCategory(category: .Non_H, isFiltered: false)
    var image_set = AssociatedCategory(category: .Image_Set, isFiltered: false)
    var cosplay = AssociatedCategory(category: .Cosplay, isFiltered: false)
    var asian_porn = AssociatedCategory(category: .Asian_Porn, isFiltered: false)
    var misc = AssociatedCategory(category: .Misc, isFiltered: false)
    
    // オフにすると、下にあるすべての関数が無視される
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
    var minRating: Int = -1
    
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
