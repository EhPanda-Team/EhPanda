import AppTools
import ComposableArchitecture
import Foundation
import LibraryClient
import Testing

// The capture's diagnostics read the reader's pages through the library client, so the live
// client must see the reader's own byte cache as well as the image libraries'.
struct LibraryClientReaderCacheTests {
    @Test
    func theLiveClientSeesAPageInTheReaderCache() async throws {
        let cache = DataCache(configuration: .init(rootURL: try makeTemporaryDirectory()))
        let key = "https://example.com/reader/\(UUID().uuidString).webp"
        try await withDependencies {
            $0.dataCache = cache
        } operation: {
            #expect(LibraryClient.live.isCached(key) == false)
            try await cache.store(Data([0x01]), forKey: key)
            #expect(LibraryClient.live.isCached(key))
        }
    }
}
