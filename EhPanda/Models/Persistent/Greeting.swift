//
//  Greeting.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/01.
//

import Foundation

struct Greeting: Codable, Equatable, Hashable, Identifiable {
    static let mock: Self = {
        var greeting = Greeting()
        greeting.gainedEXP = 10
        greeting.gainedCredits = 10000
        greeting.gainedGP = 10000
        greeting.gainedHath = 10
        return greeting
    }()

    var id = UUID()

    var gainedEXP: Int?
    var gainedCredits: Int?
    var gainedGP: Int?
    var gainedHath: Int?
    var updateTime: Date?

    var rewards: [String] {
        func formatNumber(_ number: Int?) -> String? {
            guard let number = number else { return nil }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: .init(value: number))
        }

        var rewards = [String]()
        if let exp = formatNumber(gainedEXP) {
            rewards.append("\(exp) EXP")
        }
        if let credits = formatNumber(gainedCredits) {
            rewards.append("\(credits) Credits")
        }
        if let galleryPoint = formatNumber(gainedGP) {
            rewards.append("\(galleryPoint) GP")
        }
        if let hath = formatNumber(gainedHath) {
            rewards.append("\(hath) Hath")
        }
        return rewards
    }

    var gainContent: String? {
        let rewards = rewards
        guard !rewards.isEmpty else { return nil }
        let and = L10n.Localizable.Struct.Greeting.Mark.and
        let end = L10n.Localizable.Struct.Greeting.Mark.end
        let start = L10n.Localizable.Struct.Greeting.Mark.start
        let separator = L10n.Localizable.Struct.Greeting.Mark.separator
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
