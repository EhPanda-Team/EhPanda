import Foundation
import Resources

public struct User: Codable, Equatable, Sendable {
    public init(
        displayName: String? = nil,
        avatarURL: URL? = nil,
        apikey: String? = nil,
        credits: String? = nil,
        galleryPoints: String? = nil,
        greeting: Greeting? = nil,
        favoriteCategories: [Int: String]? = nil
    ) {
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.apikey = apikey
        self.credits = credits
        self.galleryPoints = galleryPoints
        self.greeting = greeting
        self.favoriteCategories = favoriteCategories
    }
    public static let empty = User()

    public var displayName: String?
    public var avatarURL: URL?
    public var apikey: String?

    public var credits: String?
    public var galleryPoints: String?

    public var greeting: Greeting?

    public var favoriteCategories: [Int: String]?

    public func getFavoriteCategory(index: Int) -> String {
        guard index != -1 else { return L10n.Localizable.Struct.User.FavoriteCategory.all }
        let defaultCategory = L10n.Localizable.Struct.User.FavoriteCategory.default("\(index)")
        let category = favoriteCategories?[index] ?? defaultCategory
        let isDefault = category == "Favorites \(index)"
        return isDefault ? defaultCategory : category
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
