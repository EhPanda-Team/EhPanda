//
//  User.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/03.
//

import Foundation

struct User: Codable {
    var displayName: String?
    var avatarURL: String?
    var apikey: String?
    
    var currentGP: String?
    var currentCredits: String?
    
    var apiuid: String {
        getCookieValue(
            url: Defaults.URL.host.safeURL(),
            key: Defaults.Cookie.ipb_member_id
        )
        .rawValue
    }
    
    var favoriteNames: [Int : String]?
    
    func getFavNameFrom(_ index: Int) -> String {
        let name = favoriteNames?[index] ?? ""
        
        let replacedName = name
            .dropLast()
            .replacingOccurrences(
                of: "Favorites ",
                with: "お気に入り名"
            )
        
        if replacedName.hasLString {
            return replacedName.lString() + " \(index)"
        } else {
            return name.lString()
        }
    }
}

enum FavoritesType: String, Codable, CaseIterable {
    static func getTypeFrom(index: Int) -> FavoritesType {
        FavoritesType.allCases
            .filter {
                $0.index == index
            }
            .first ?? .all
    }
    
    var index: Int {
        Int(self.rawValue
            .replacingOccurrences(
                of: "favorite_",
                with: ""
            )
        ) ?? -1
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
