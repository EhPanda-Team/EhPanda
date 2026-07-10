import Synchronization

/// Process-wide cache of loaded base dictionaries, keyed by their bundle path.
///
/// Dictionaries are immutable once loaded and safe to read from multiple threads, so a
/// single `Mutex`-guarded map lets concurrently-created converters reuse them without
/// re-reading `.ocd2` data. This replaces the upstream lock-based weak cache: EhPanda
/// builds few converters from a small, fixed set of dictionaries, so a strong
/// process-lifetime cache is both simpler and safely bounded.
final class DictionaryStore: Sendable {
    static let shared = DictionaryStore()

    private let cache = Mutex<[String: ConversionDictionary]>([:])

    private init() {}

    /// Returns the dictionary for `path`, loading and caching it on first request.
    /// - Throws: ``ConversionError`` if the dictionary cannot be loaded.
    func dictionary(atPath path: String) throws -> ConversionDictionary {
        try cache.withLock { storage in
            if let cached = storage[path] {
                return cached
            }
            let dictionary = try ConversionDictionary(path: path)
            storage[path] = dictionary
            return dictionary
        }
    }
}
