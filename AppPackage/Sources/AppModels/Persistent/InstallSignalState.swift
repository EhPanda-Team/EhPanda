/// Whether the one install signal has been delivered, and the user hash its retries reuse (D-06b).
///
/// Persisted under its own key (`installSignal`), never on `Setting`, so resetting the settings can
/// never send the signal a second time. Decoding is tolerant: a missing or wrongly typed field reads as
/// its default rather than failing the decode, because a failed decode would fall back to the key's
/// default, and a default of "not settled" means sending again.
public struct InstallSignalState: Codable, Equatable, Sendable {
    /// `true` once the ingest server accepted the signal or rejected it for good; it is never sent again.
    public var settled: Bool
    /// The hashed user identifier, created before the first attempt and reused by every retry, so a
    /// retry after a lost response counts as the same install. Cleared once settled.
    public var clientUser: String?

    public init(settled: Bool = false, clientUser: String? = nil) {
        self.settled = settled
        self.clientUser = clientUser
    }

    private enum CodingKeys: String, CodingKey {
        case settled
        case clientUser
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settled = Self.decodeTolerantly(Bool.self, forKey: .settled, in: container) ?? false
        clientUser = Self.decodeTolerantly(String.self, forKey: .clientUser, in: container)
    }

    private static func decodeTolerantly<Value: Decodable>(
        _ type: Value.Type,
        forKey key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) -> Value? {
        do {
            return try container.decodeIfPresent(type, forKey: key)
        } catch {
            // A wrongly typed field reads as absent; the other field keeps its stored value.
            return nil
        }
    }
}
