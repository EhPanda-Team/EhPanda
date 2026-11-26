public import Foundation

/// A single browsing-history record, pairing a gallery's recency (`lastOpenDate`) with its
/// resume position (`readingProgress`) and its webtoon verdict (`isWebtoon`) in one lightweight value.
///
/// Only the minimal identity (`gid`/`token`), the recency key, the resume page and the webtoon
/// verdict are persisted — never a gallery snapshot. The History screen re-fetches display metadata
/// from the site's `gdata` API on demand, keeping persisted website content at zero.
///
/// `init(from:)` brings an older entry forward through `SchemaMigrator`, and `init(currentFrom:)` then decodes
/// strictly: a blank identity or an unknown `schemaVersion` throws, failing the whole `[GalleryHistoryEntry]` decode
/// so Sharing resets this disposable list to `[]` rather than surfacing a `""`-id Franken-entry that would collide in
/// an `Identifiable` list.
public struct GalleryHistoryEntry: Codable, Equatable, Identifiable, Sendable, MigratableModel {
    /// The most entries kept across launches. Enforced only by a launch-time prune (see
    /// `Array.pruneToHistoryCap`); in-session upserts may temporarily exceed it.
    public static let historyCap = 1000

    public init(
        gid: String,
        token: String,
        lastOpenDate: Date,
        readingProgress: Int = 0,
        isWebtoon: Bool? = nil
    ) {
        self.gid = gid
        self.token = token
        self.lastOpenDate = lastOpenDate
        self.readingProgress = readingProgress
        self.isWebtoon = isWebtoon
    }
    public var id: String { gid }
    /// This model's schema history (oldest → newest); see `SchemaVersioned` / `VersionedSchema`.
    /// `currentSchemaVersion` derives from the head. Append a `VersionedSchema` and adopt
    /// `MigratableModel` when a breaking change lands.
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    /// The v1 base schema. Its `migrate` is empty — nothing precedes v1, and the engine only runs
    /// schemas newer than the stored version, so it exists solely to anchor version 1.
    enum SchemaV1: VersionedSchema {
        static let version = 1
        static func migrate(_ object: inout [String: JSONValue]) throws {}
    }
    /// v2 (W-4 of quick 261126-iq9): the reader now samples the gallery's middle three pages instead of the pages
    /// around the one it opened on, so a "not a webtoon" verdict recorded under v1 may have been decided by a cover,
    /// a title page or an end page. Migrating drops that verdict, once, so the gallery is checked again under the
    /// new rule. A "webtoon" verdict came from three extremely tall pages, which none of those pages are, so it
    /// stays.
    enum SchemaV2: VersionedSchema {
        static let version = 2

        static func migrate(_ object: inout [String: JSONValue]) throws {
            if case .bool(false)? = object["isWebtoon"] {
                object.removeValue(forKey: "isWebtoon")
            }
        }
    }
    /// Self-validating (see `SchemaVersion`): a newer/downgrade value is rejected on decode. The identity guards in
    /// `init(currentFrom:)` below stay hand-written. It defaults to the current version, so an entry made now, a
    /// verdict under the new rule included, is stored at v2 and never migrated again.
    public var schemaVersion: SchemaVersion<GalleryHistoryEntry> = 2
    public var gid: String
    public var token: String
    public var lastOpenDate: Date
    public var readingProgress: Int
    /// Whether the reader found the gallery to be a webtoon, every sampled page extremely tall (D-05, D-07); `nil` =
    /// not checked yet. Recorded once, so a gallery is checked only once while it stays in the history. Optional, so
    /// entries written before it existed decode as not checked; `SchemaV2` drops the negative verdicts v1 recorded
    /// under the old sampling rule.
    public var isWebtoon: Bool?
}

// MARK: Manually decode
extension GalleryHistoryEntry {
    public init(from decoder: any Decoder) throws {
        self = try SchemaMigrator.migrate(Self.self, from: decoder)
    }

    public init(currentFrom decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(SchemaVersion<GalleryHistoryEntry>.self, forKey: .schemaVersion)
        gid = try container.decode(String.self, forKey: .gid)
        token = try container.decode(String.self, forKey: .token)
        lastOpenDate = try container.decode(Date.self, forKey: .lastOpenDate)
        readingProgress = try container.decode(Int.self, forKey: .readingProgress)
        isWebtoon = try container.decodeIfPresent(Bool.self, forKey: .isWebtoon)
        guard !gid.isEmpty, !token.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "GalleryHistoryEntry requires a non-empty gid and token"
            ))
        }
    }
}
