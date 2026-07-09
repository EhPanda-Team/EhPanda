import Foundation
import Resources

public struct User: Codable, Equatable, Sendable, SchemaVersioned {
    public init(
        displayName: String? = nil,
        avatarURL: URL? = nil,
        credits: String? = nil,
        galleryPoints: String? = nil,
        favoriteCategories: [Int: String]? = nil
    ) {
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.credits = credits
        self.galleryPoints = galleryPoints
        self.favoriteCategories = favoriteCategories
    }
    public static let empty = User()

    /// Migration maps, one slot per schema version (index 0 = v1 = `.passthrough`). `currentSchemaVersion`
    /// is derived from the count; append a map and adopt `MigratableModel` when a breaking v2 lands.
    public static let migrations: [SchemaMigration<User>] = [.passthrough]
    // A self-validating field: it rejects a newer/downgrade blob on decode (see `SchemaVersion`), which
    // fails the whole decode so Sharing resets to the key default. Synthesized Codable is otherwise
    // untouched, so optional-field tolerance still holds; a field added later must stay optional so old
    // blobs keep decoding.
    public var schemaVersion: SchemaVersion<User> = 1
    public var displayName: String?
    public var avatarURL: URL?

    public var credits: String?
    public var galleryPoints: String?

    public var favoriteCategories: [Int: String]?

    public func getFavoriteCategory(index: Int) -> String {
        guard index != -1 else { return String(localized: .favoriteCategoryAll) }
        let defaultCategory = String(localized: .favoriteCategoryDefault(index: index))
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
