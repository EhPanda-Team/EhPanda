//
//  Misc.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/15.
//

import Foundation
import SwiftyBeaver

typealias Percentage = Int
typealias Keyword = String
typealias Identity = String
typealias APIKey = String
typealias GalleryPoints = String
typealias Credits = String
typealias ReloadToken = Any
typealias Logger = SwiftyBeaver
typealias FavoritesSortOrder = EhSetting.FavoritesSortOrder

struct PageNumber: Equatable {
    var current = 0
    var maximum = 0

    var isSinglePage: Bool {
        current == 0 && maximum == 0
    }
}

struct Greeting: Codable, Equatable, Hashable {
    static let mock: Self = {
        var greeting = Greeting()
        greeting.gainedEXP = 10
        greeting.gainedCredits = 10000
        greeting.gainedGP = 10000
        greeting.gainedHath = 10
        return greeting
    }()

    var gainedEXP: Int?
    var gainedCredits: Int?
    var gainedGP: Int?
    var gainedHath: Int?
    var updateTime: Date?

    var strings: [String] {
        var strings = [String]()

        if let exp = gainedEXP {
            strings.append("\(exp) EXP")
        }
        if let credits = gainedCredits {
            strings.append("\(credits) Credits")
        }
        if let galleryPoint = gainedGP {
            strings.append("\(galleryPoint) GP")
        }
        if let hath = gainedHath {
            strings.append("\(hath) Hath")
        }

        return strings
    }

    var gainContent: String? {
        guard !strings.isEmpty else { return nil }
        var base = R.string.localizable.structGreetingMarkStart()

        if strings.count == 1 {
            base += strings[0]
        } else {
            let stringsToJoin = strings.count > 2 ? strings.dropLast() : strings
            base += stringsToJoin.joined(separator: R.string.localizable.structGreetingMarkSeparator())
            if strings.count > 2 {
                base += R.string.localizable.structGreetingMarkAnd()
                base += strings[strings.count - 1]
            }
        }
        return base + R.string.localizable.structGreetingMarkEnd()
    }

    var gainedNothing: Bool {
        [gainedEXP, gainedCredits, gainedGP, gainedHath]
            .compactMap({ $0 }).isEmpty
    }
}

struct QuickSearchWord: Codable, Equatable, Identifiable {
    static var empty: Self { .init(name: "", content: "") }

    var id: UUID = .init()
    var name: String
    var content: String
}
