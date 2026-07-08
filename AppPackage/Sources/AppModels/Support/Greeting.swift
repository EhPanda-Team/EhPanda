import Foundation
import Resources

public struct Greeting: Codable, Equatable, Hashable, Identifiable, Sendable {
    public init(
        id: UUID = UUID(),
        gainedEXP: Int? = nil,
        gainedCredits: Int? = nil,
        gainedGP: Int? = nil,
        gainedHath: Int? = nil,
        updateTime: Date? = nil
    ) {
        self.id = id
        self.gainedEXP = gainedEXP
        self.gainedCredits = gainedCredits
        self.gainedGP = gainedGP
        self.gainedHath = gainedHath
        self.updateTime = updateTime
    }
    public static let mock: Self = {
        var greeting = Greeting()
        greeting.gainedEXP = 10
        greeting.gainedCredits = 10000
        greeting.gainedGP = 10000
        greeting.gainedHath = 10
        return greeting
    }()

    public var id = UUID()

    public var gainedEXP: Int?
    public var gainedCredits: Int?
    public var gainedGP: Int?
    public var gainedHath: Int?
    public var updateTime: Date?

    public var rewards: [String] {
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

    public var gainContent: String? {
        let rewards = rewards
        guard !rewards.isEmpty else { return nil }
        let and = String(localized: .greetingAnd)
        let end = String(localized: .greetingEnd)
        let start = String(localized: .greetingStart)
        let separator = String(localized: .greetingSeparator)
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

    public var gainedNothing: Bool {
        [gainedEXP, gainedCredits, gainedGP, gainedHath]
            .compactMap({ $0 }).isEmpty
    }
}

extension Optional where Wrapped == Greeting {
    /// Adopts `greeting` only when it is newer than the one already held (or none is held). Two
    /// features write the session greeting — the Setting daily fetch and the Detail-page parse — so the
    /// "keep the newer" rule lives here, next to the model, rather than at either call site, and a stale
    /// detail-page greeting can't clobber a fresher one.
    public mutating func mergeNewer(_ greeting: Greeting) {
        guard let newDate = greeting.updateTime else { return }
        if let current = self {
            if let currentDate = current.updateTime, currentDate < newDate {
                self = greeting
            }
        } else {
            self = greeting
        }
    }
}
