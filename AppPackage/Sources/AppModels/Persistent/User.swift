import Foundation
import Resources

public struct User: Codable, Equatable, Sendable {
    public init(
        displayName: String? = nil,
        avatarURL: URL? = nil,
        credits: String? = nil,
        galleryPoints: String? = nil,
        greeting: Greeting? = nil,
        favoriteCategories: [Int: String]? = nil
    ) {
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.credits = credits
        self.galleryPoints = galleryPoints
        self.greeting = greeting
        self.favoriteCategories = favoriteCategories
    }
    public static let empty = User()

    // Version anchor for future breaking migrations; additive changes ride the tolerant decoder.
    public var schemaVersion = 1
    public var displayName: String?
    public var avatarURL: URL?

    public var credits: String?
    public var galleryPoints: String?

    // Not persisted: `greeting` is the daily "New Dawn" reward — ephemeral session data rather than
    // durable account identity. It is omitted from `CodingKeys` below so persisting `User` (via
    // `@Shared(.user)`) never writes it; it stays live in memory for the session and resets to `nil`
    // on the next launch. See the greeting-fetch throttle in `SettingReducer`.
    public var greeting: Greeting?

    public var favoriteCategories: [Int: String]?

    // `greeting` is intentionally absent so Codable skips it (it keeps its `nil` default on decode).
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, displayName, avatarURL, credits, galleryPoints, favoriteCategories
    }

    public func getFavoriteCategory(index: Int) -> String {
        guard index != -1 else { return String(localized: .favoriteCategoryAll) }
        let defaultCategory = String(localized: .favoriteCategoryDefault(index: index))
        let category = favoriteCategories?[index] ?? defaultCategory
        let isDefault = category == "Favorites \(index)"
        return isDefault ? defaultCategory : category
    }
}

// MARK: Manually decode
extension User {
    // Tolerant decoding keeps an existing persisted value valid across future additive changes; a
    // non-optional field like `schemaVersion` would otherwise fail synthesized decode of an older
    // record. `greeting` is intentionally not decoded (absent from `CodingKeys`) and stays `nil`.
    public init(from decoder: Decoder) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            schemaVersion = 1
            return
        }
        schemaVersion = (try? container.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        displayName = try? container.decodeIfPresent(String.self, forKey: .displayName)
        avatarURL = try? container.decodeIfPresent(URL.self, forKey: .avatarURL)
        credits = try? container.decodeIfPresent(String.self, forKey: .credits)
        galleryPoints = try? container.decodeIfPresent(String.self, forKey: .galleryPoints)
        favoriteCategories = try? container.decodeIfPresent([Int: String].self, forKey: .favoriteCategories)
    }
}

public enum FavoritesType: String, Codable, CaseIterable, Sendable {
    public static func getTypeFrom(index: Int) -> FavoritesType {
        FavoritesType.allCases.filter({ $0.index == index }).first ?? .all
    }

    public var index: Int {
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
