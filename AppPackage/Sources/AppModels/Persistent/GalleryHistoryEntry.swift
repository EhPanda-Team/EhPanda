import Foundation

/// A single browsing-history record, pairing a gallery's recency (`lastOpenDate`) with its
/// resume position (`readingProgress`) in one lightweight value.
///
/// Only the minimal identity (`gid`/`token`), the recency key and the resume page are
/// persisted — never a gallery snapshot. The History screen re-fetches display metadata
/// from the site's `gdata` API on demand, keeping persisted website content at zero.
///
/// The manual `init(from:)` decodes strictly: a blank identity or an unknown `schemaVersion`
/// throws, failing the whole `[GalleryHistoryEntry]` decode so Sharing resets this disposable list
/// to `[]` rather than surfacing a `""`-id Franken-entry that would collide in an `Identifiable` list.
public struct GalleryHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    /// The most entries kept across launches. Enforced only by a launch-time prune (see
    /// `Array.pruneToHistoryCap`); in-session upserts may temporarily exceed it.
    public static let historyCap = 1000

    public init(
        gid: String,
        token: String,
        lastOpenDate: Date,
        readingProgress: Int = 0
    ) {
        self.gid = gid
        self.token = token
        self.lastOpenDate = lastOpenDate
        self.readingProgress = readingProgress
    }
    public var id: String { gid }
    /// Highest `schemaVersion` this build can decode; a blob carrying a newer value (a downgrade)
    /// is rejected rather than half-read. Bump and branch here when a breaking change lands.
    public static let currentSchemaVersion = 1
    public var schemaVersion = 1
    public var gid: String
    public var token: String
    public var lastOpenDate: Date
    public var readingProgress: Int
}

// MARK: Manually decode
extension GalleryHistoryEntry {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard (1...Self.currentSchemaVersion).contains(version) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "Unsupported GalleryHistoryEntry schemaVersion \(version)"
            ))
        }
        schemaVersion = version
        gid = try container.decode(String.self, forKey: .gid)
        token = try container.decode(String.self, forKey: .token)
        lastOpenDate = try container.decode(Date.self, forKey: .lastOpenDate)
        readingProgress = try container.decode(Int.self, forKey: .readingProgress)
        guard !gid.isEmpty, !token.isEmpty else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "GalleryHistoryEntry requires a non-empty gid and token"
            ))
        }
    }
}
