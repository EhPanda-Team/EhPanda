//
//  Filter.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/08.
//

import SwiftUI

struct Filter: Codable, Equatable {
    var doujinshi = false
    var manga = false
    var artistCG = false
    var gameCG = false
    var western = false
    var nonH = false
    var imageSet = false
    var cosplay = false
    var asianPorn = false
    var misc = false

    var advanced = false
    var galleryName = true
    var galleryTags = true
    var galleryDesc = false
    var torrentFilenames = false
    var onlyWithTorrents = false
    var lowPowerTags = false {
        didSet {
            if lowPowerTags {
                downvotedTags = false
            }
        }
    }
    var downvotedTags = false {
        didSet {
            if downvotedTags {
                lowPowerTags = false
            }
        }
    }
    var expungedGalleries = false

    var minRatingActivated = false
    var minRating = 2

    var pageRangeActivated = false
    var pageLowerBound = "" {
        didSet {
            if Int(pageLowerBound) == nil && !pageLowerBound.isEmpty {
                pageLowerBound = ""
            }
        }
    }
    var pageUpperBound = "" {
        didSet {
            if Int(pageUpperBound) == nil && !pageUpperBound.isEmpty {
                pageUpperBound = ""
            }
        }
    }

    var disableLanguage = false
    var disableUploader = false
    var disableTags = false
}

// MARK: Manually decode
extension Filter {
    init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        doujinshi = (try? container?.decodeIfPresent(Bool.self, forKey: .doujinshi)) ?? false
        manga = (try? container?.decodeIfPresent(Bool.self, forKey: .manga)) ?? false
        artistCG = (try? container?.decodeIfPresent(Bool.self, forKey: .artistCG)) ?? false
        gameCG = (try? container?.decodeIfPresent(Bool.self, forKey: .gameCG)) ?? false
        western = (try? container?.decodeIfPresent(Bool.self, forKey: .western)) ?? false
        nonH = (try? container?.decodeIfPresent(Bool.self, forKey: .nonH)) ?? false
        imageSet = (try? container?.decodeIfPresent(Bool.self, forKey: .imageSet)) ?? false
        cosplay = (try? container?.decodeIfPresent(Bool.self, forKey: .cosplay)) ?? false
        asianPorn = (try? container?.decodeIfPresent(Bool.self, forKey: .asianPorn)) ?? false
        misc = (try? container?.decodeIfPresent(Bool.self, forKey: .misc)) ?? false

        advanced = (try? container?.decodeIfPresent(Bool.self, forKey: .advanced)) ?? false
        galleryName = (try? container?.decodeIfPresent(Bool.self, forKey: .galleryName)) ?? false
        galleryTags = (try? container?.decodeIfPresent(Bool.self, forKey: .galleryTags)) ?? false
        galleryDesc = (try? container?.decodeIfPresent(Bool.self, forKey: .galleryDesc)) ?? false
        torrentFilenames = (try? container?.decodeIfPresent(Bool.self, forKey: .torrentFilenames)) ?? false
        onlyWithTorrents = (try? container?.decodeIfPresent(Bool.self, forKey: .onlyWithTorrents)) ?? false
        lowPowerTags = (try? container?.decodeIfPresent(Bool.self, forKey: .lowPowerTags)) ?? false
        downvotedTags = (try? container?.decodeIfPresent(Bool.self, forKey: .downvotedTags)) ?? false
        expungedGalleries = (try? container?.decodeIfPresent(Bool.self, forKey: .expungedGalleries)) ?? false

        minRatingActivated = (try? container?.decodeIfPresent(Bool.self, forKey: .minRatingActivated)) ?? false
        minRating = (try? container?.decodeIfPresent(Int.self, forKey: .minRating)) ?? 2

        pageRangeActivated = (try? container?.decodeIfPresent(Bool.self, forKey: .pageRangeActivated)) ?? false
        pageLowerBound = (try? container?.decodeIfPresent(String.self, forKey: .pageLowerBound)) ?? ""
        pageUpperBound = (try? container?.decodeIfPresent(String.self, forKey: .pageUpperBound)) ?? ""

        disableLanguage = (try? container?.decodeIfPresent(Bool.self, forKey: .disableLanguage)) ?? false
        disableUploader = (try? container?.decodeIfPresent(Bool.self, forKey: .disableUploader)) ?? false
        disableTags = (try? container?.decodeIfPresent(Bool.self, forKey: .disableTags)) ?? false
    }
}
