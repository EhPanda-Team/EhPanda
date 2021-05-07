//
//  Misc.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import Foundation

typealias FavoritesIndex = Int
typealias Depth = Int
typealias Percentage = Int
typealias Keyword = String
typealias Identity = String
typealias APIKey = String
typealias CurrentGP = String
typealias CurrentCredits = String
typealias Resp = String

struct PageNumber {
    var current = 0
    var maximum = 0
}

struct AssociatedKeyword: Equatable {
    var category: String?
    var content: String?
    var title: String?
}

struct AssociatedItem {
    var keyword = AssociatedKeyword()
    var pageNum = PageNumber()
    var mangas: [Manga]
}

struct Greeting: Identifiable, Codable, Equatable {
    var id = UUID()

    var gainedEXP: Int?
    var gainedCredits: Int?
    var gainedGP: Int?
    var gainedHath: Int?
    var updateTime: Date?

    var gainedNothing: Bool {
        [
            gainedEXP,
            gainedCredits,
            gainedGP,
            gainedHath
        ]
        .compactMap({ $0 })
        .isEmpty
    }
}
