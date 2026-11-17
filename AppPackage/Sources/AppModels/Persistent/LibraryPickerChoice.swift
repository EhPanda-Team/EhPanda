import Foundation

/// The group last chosen on the compact Library layout's title-menu picker, held in
/// `@Shared(.libraryPickerChoice)` (quick task 261117-tyj, owner decisions A-1 and A-2).
///
/// A-1 remembers the full group, so the source comes back together with its favorites category or its download
/// folder filter. A-2 limits what is remembered to the compact layout, where the picker shows: the sidebar layout
/// never writes this record and never overwrites it.
///
/// It is a struct, not a bare `LibraryGroup`, so it can carry a `SchemaVersion`, the migration seam if `LibraryGroup`
/// ever changes shape. `group` is non-optional because "nothing remembered" is the absence of the record: the key is
/// optional, and a cleared key (stored as a JSON `null`) reads as nothing remembered.
///
/// The decode is strict, so a blob the picker cannot show (a newer schema, a missing or malformed group, a favorites
/// category the site has no slot for) reads as nothing remembered, and the compact layout opens Favorites as it did
/// before this record existed. Folder existence is not validated here: it is runtime evidence, and the Downloads
/// reducer's fallback to All handles a folder that has vanished.
public struct LibraryPickerChoice: Codable, Equatable, Sendable, SchemaVersioned {
    /// This model's schema history (oldest → newest); see `SchemaVersioned` / `VersionedSchema`.
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    /// The v1 base schema; it exists solely to anchor version 1.
    enum SchemaV1: VersionedSchema {
        static let version = 1
        static func migrate(_ object: inout [String: JSONValue]) throws {}
    }

    /// Self-validating (see `SchemaVersion`): a newer value is rejected on decode, which reads as nothing remembered.
    public var schemaVersion: SchemaVersion<LibraryPickerChoice> = 1
    /// The group the compact picker last showed.
    public let group: LibraryGroup

    public init(group: LibraryGroup) {
        self.group = group
    }
}

// MARK: Manually decode
extension LibraryPickerChoice {
    /// Strict, throwing decode: an unknown `schemaVersion`, a missing or malformed `group`, or a favorites category
    /// outside `FavoritesType`'s indices throws, so Sharing reads the stored data as nothing remembered.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(SchemaVersion<LibraryPickerChoice>.self, forKey: .schemaVersion)
        group = try container.decode(LibraryGroup.self, forKey: .group)
        if case .favorites(let index) = group, !FavoritesType.allCases.contains(where: { $0.index == index }) {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "LibraryPickerChoice has no favorites category with index \(index)"
            ))
        }
    }
}
