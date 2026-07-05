import Foundation

/// A single browsing-history record, merging what used to be split across
/// `GalleryMO.lastOpenDate` (recency) and `GalleryStateMO.readingProgress` (resume position).
///
/// Only the minimal identity (`gid`/`token`), the recency key and the resume page are
/// persisted — never a gallery snapshot. The History screen re-fetches display metadata
/// from the site's `gdata` API on demand, keeping persisted website content at zero.
///
/// The manual `init(from:)` decodes every field tolerantly (`decodeIfPresent` + default) so
/// that future additive changes to this record never invalidate an existing persisted list.
public struct GalleryHistoryEntry: Codable, Equatable, Identifiable, Sendable {
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
    public var gid: String
    public var token: String
    public var lastOpenDate: Date
    public var readingProgress: Int
}

// MARK: Manually decode
extension GalleryHistoryEntry {
    public init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        gid = (try? container?.decodeIfPresent(String.self, forKey: .gid)) ?? ""
        token = (try? container?.decodeIfPresent(String.self, forKey: .token)) ?? ""
        lastOpenDate = (try? container?.decodeIfPresent(Date.self, forKey: .lastOpenDate)) ?? .distantPast
        readingProgress = (try? container?.decodeIfPresent(Int.self, forKey: .readingProgress)) ?? 0
    }
}
