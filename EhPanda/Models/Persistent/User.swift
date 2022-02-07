//
//  User.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/03.
//

import Foundation

struct User: Codable, Equatable {
    static let empty = User()

    var displayName: String?
    var avatarURL: URL?
    var apikey: String?

    var credits: String?
    var galleryPoints: String?

    var greeting: Greeting?

    var favoriteCategories: [Int: String]?

    func getFavoriteCategory(index: Int) -> String {
        guard index != -1 else { return R.string.localizable.favoriteCategoryAll() }
        let defaultCategory = R.string.localizable.favoriteCategoryDefault("\(index)")
        let category = favoriteCategories?[index] ?? defaultCategory
        let isDefault = category == "Favorites \(index)"
        return isDefault ? defaultCategory : category
    }
}

enum FavoritesType: String, Codable, CaseIterable {
    static func getTypeFrom(index: Int) -> FavoritesType {
        FavoritesType.allCases.filter({ $0.index == index }).first ?? .all
    }

    var index: Int {
        Int(rawValue.replacingOccurrences(of: "favorite_", with: "")) ?? -1
    }

    case all = "all"
    case favorite0 = "favorite_0"
    case favorite1 = "favorite_1"
    case favorite2 = "favorite_2"
    case favorite3 = "favorite_3"
    case favorite4 = "favorite_4"
    case favorite5 = "favorite_5"
    case favorite6 = "favorite_6"
    case favorite7 = "favorite_7"
    case favorite8 = "favorite_8"
    case favorite9 = "favorite_9"
}
