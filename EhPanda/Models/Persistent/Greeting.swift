//
//  Greeting.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import Foundation

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

    var rewards: [String] {
        var rewards = [String]()
        if let exp = gainedEXP {
            rewards.append("\(exp) EXP")
        }
        if let credits = gainedCredits {
            rewards.append("\(credits) Credits")
        }
        if let galleryPoint = gainedGP {
            rewards.append("\(galleryPoint) GP")
        }
        if let hath = gainedHath {
            rewards.append("\(hath) Hath")
        }
        return rewards
    }

    var gainContent: String? {
        let rewards = rewards
        guard !rewards.isEmpty else { return nil }
        let and = R.string.localizable.structGreetingMarkAnd()
        let end = R.string.localizable.structGreetingMarkEnd()
        let start = R.string.localizable.structGreetingMarkStart()
        let separator = R.string.localizable.structGreetingMarkSeparator()
        let rewardDescription = rewards.enumerated().map { (offset, element) in
            if offset == 0 {
                return element
            } else if offset == rewards.count - 1 {
                return [rewards.count > 2 ? and : separator, element].joined()
            } else {
                return [separator, element].joined()
            }
        }
        .joined()
        return [start, rewardDescription, end].joined()
    }

    var gainedNothing: Bool {
        [gainedEXP, gainedCredits, gainedGP, gainedHath]
            .compactMap({ $0 }).isEmpty
    }
}
