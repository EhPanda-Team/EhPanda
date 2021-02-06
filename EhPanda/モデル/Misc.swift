//
//  Misc.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

typealias Depth = Int
typealias Percentage = Int
typealias Keyword = String
typealias Identity = String
typealias APIKey = String
typealias CurrentGP = String
typealias CurrentCredits = String

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
