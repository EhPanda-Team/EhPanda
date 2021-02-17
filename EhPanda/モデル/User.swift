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
        // ⚠️
        getCookieValue(
            url: Defaults.URL.ehentai.safeURL(),
            key: Defaults.Cookie.ipb_member_id
        )
        .rawValue
    }
}
