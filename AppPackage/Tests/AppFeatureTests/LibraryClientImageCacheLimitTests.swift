import AppTools
import ComposableArchitecture
import Foundation
import Kingfisher
import LibraryClient
import SDWebImage
import Testing

// Regression: neither image library's disk cache had a size limit, so covers, previews and thumbnails
// could fill the device until the user cleared the cache by hand. Both libraries enforce the limit
// themselves (Kingfisher and SDWebImage trim to it when the app leaves the foreground or ends).
struct LibraryClientImageCacheLimitTests {
    // `initializeWebImage` only configures the two shared libraries (idempotent writes), so running it
    // in parallel with other tests cannot change what they observe. The reader cache is injected so
    // the test never touches the live one.
    @Test
    func initializingTheLiveClientCapsKingfisherAt512MiBAndSDWebImageAt128MiB() throws {
        let rootURL = try makeTemporaryDirectory()
        withDependencies {
            $0.dataCache = DataCache(configuration: .init(rootURL: rootURL))
        } operation: {
            LibraryClient.live.initializeWebImage()
        }

        #expect(KingfisherManager.shared.cache.diskStorage.config.sizeLimit == 512 * 1024 * 1024)
        #expect(SDImageCache.shared.config.maxDiskSize == 128 * 1024 * 1024)
    }
}
