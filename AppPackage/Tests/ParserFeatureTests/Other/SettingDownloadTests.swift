@testable import AppFeature
import AppModels
import AppTools
import DownloadClient
import SwiftUI
import Testing

struct SettingDownloadTests {
    @Test
    func testSettingRoundTripsDownloadFields() throws {
        // Strict decode (#2): a persisted Setting is written whole, so its download fields survive an
        // encode/decode round-trip intact. (A partial blob no longer decodes — it resets to defaults.)
        var setting = Setting()
        setting.downloadThreadLimit = 3
        setting.downloadAllowCellular = false
        setting.downloadAutoRetryFailedPages = false

        let data = try JSONEncoder().encode(setting)
        let decoded = try JSONDecoder().decode(Setting.self, from: data)

        #expect(decoded.downloadThreadLimit == 3)
        #expect(!decoded.downloadAllowCellular)
        #expect(!decoded.downloadAutoRetryFailedPages)
    }

    @Test
    func testDownloadRequestOptionsMatchesSettingValues() {
        var setting = Setting()
        setting.downloadThreadLimit = 4
        setting.downloadAllowCellular = false
        setting.downloadAutoRetryFailedPages = false

        #expect(
            setting.downloadRequestOptions == DownloadRequestOptions(
                threadLimit: 4,
                allowCellular: false,
                autoRetryFailedPages: false
            )
        )
    }

    @Test
    func testDownloadRequestOptionsDefaultsMatchSettingDefaults() {
        #expect(
            Setting().downloadRequestOptions == DownloadRequestOptions()
        )
    }

    @Test
    func testImageCacheKeysPreferStablePathAlias() throws {
        let url = try #require(URL(string: "https://alpha.hath.network/h/123/456/image.webp?download=1"))

        #expect(
            url.imageCacheKeys == [
                "download::h/123/456/image.webp",
                "https://alpha.hath.network/h/123/456/image.webp?download=1"
            ]
        )
    }

    @Test
    func testStableImageCacheKeyIgnoresHostRotationAndQuery() throws {
        let firstURL = try #require(URL(string: "https://alpha.hath.network/h/123/456/image.webp?download=1"))
        let secondURL = try #require(URL(string: "https://beta.hath.network/h/123/456/image.webp?source=viewer"))

        #expect(firstURL.stableImageCacheKey == secondURL.stableImageCacheKey)
    }

    // A served page image carries a time-limited signature in the PATH
    // (`keystamp=<expiry>-<mac>`) that rotates every few minutes and differs per host.
    private static let signedPagePath =
        "h/9dc6713b44a7eafef9f42e831305087ca0898f05-152222-1024-1024-wbp"

    @Test
    func testStableImageCacheKeyIgnoresKeystampAndHost() throws {
        let firstURL = try #require(URL(string: "https://mzinusy.qopwuxqpzbge.hath.network:47800/"
            + "\(Self.signedPagePath)/keystamp=1794510300-c5c7a48fa5;fileindex=279444560;xres=1280/1_Copia.webp"))
        let secondURL = try #require(URL(string: "https://hpqzxeb.pprhnzzvlbth.hath.network:57858/"
            + "\(Self.signedPagePath)/keystamp=1794511500-65aa15ecef;fileindex=279444560;xres=1280/1_Copia.webp"))

        #expect(firstURL.stableImageCacheKey == secondURL.stableImageCacheKey)
        #expect(
            firstURL.stableImageCacheKey
                == "download::\(Self.signedPagePath)/fileindex=279444560;xres=1280/1_Copia.webp"
        )
        // The exact-URL fallback still differs; only the primary alias is stable.
        #expect(firstURL.imageCacheKeys.first == secondURL.imageCacheKeys.first)
        #expect(firstURL.absoluteString != secondURL.absoluteString)
    }

    @Test
    func testStableImageCacheKeyKeepsFileIndexAndResolution() throws {
        let base = "https://a.hath.network/\(Self.signedPagePath)/keystamp=1-aa;"
        let reference = try #require(URL(string: base + "fileindex=10;xres=1280/1.webp"))
        let otherIndex = try #require(URL(string: base + "fileindex=11;xres=1280/1.webp"))
        let otherResolution = try #require(URL(string: base + "fileindex=10;xres=org/1.webp"))

        #expect(reference.stableImageCacheKey != otherIndex.stableImageCacheKey)
        #expect(reference.stableImageCacheKey != otherResolution.stableImageCacheKey)
    }

    @Test
    func testLegacyStableImageCacheKeyKeepsKeystampSoOldEntriesStayReachable() throws {
        let url = try #require(URL(string: "https://a.hath.network/\(Self.signedPagePath)/"
            + "keystamp=1794510300-c5c7a48fa5;fileindex=279444560;xres=1280/1_Copia.webp"))

        // 3.0 wrote reader-cache entries under the whole path, keystamp included.
        #expect(
            url.legacyStableImageCacheKey == "download::\(Self.signedPagePath)/"
                + "keystamp=1794510300-c5c7a48fa5;fileindex=279444560;xres=1280/1_Copia.webp"
        )
        #expect(
            url.imageCacheKeys == [
                url.stableImageCacheKey,
                url.legacyStableImageCacheKey,
                url.absoluteString
            ].compactMap(\.self)
        )
    }

    @Test
    func testLegacyStableImageCacheKeyIsOmittedWhenItEqualsTheStableKey() throws {
        let url = try #require(URL(string: "https://alpha.hath.network/h/123/456/image.webp?download=1"))

        #expect(url.legacyStableImageCacheKey == url.stableImageCacheKey)
        #expect(url.imageCacheKeys.count == 2)
    }

    @Test
    func testStableImageCacheKeyKeepsIdentityQueryForFullImageScript() throws {
        let firstURL = try #require(URL(string: "https://e-hentai.org/fullimg.php?gid=42&page=7&key=alpha"))
        let secondURL = try #require(URL(string: "https://exhentai.org/fullimg.php?page=7&gid=42&key=beta"))

        #expect(firstURL.stableImageCacheKey == "download::fullimg.php?gid=42&key=alpha&page=7")
        #expect(secondURL.stableImageCacheKey == "download::fullimg.php?gid=42&key=beta&page=7")
        #expect(firstURL.stableImageCacheKey != secondURL.stableImageCacheKey)
    }

    @Test
    func testStableImageCacheKeyFallbackRetainsNonIgnoredNonPreferredQueries() throws {
        let url = try #require(URL(string: "https://example.com/h/123/image.webp?custom=abc&dl=1"))

        #expect(url.stableImageCacheKey == "download::h/123/image.webp?custom=abc")
    }

    @Test
    func testCombinedPreviewURLCleanupIncludesPlainPreviewURL() throws {
        let plainURL = try #require(URL(string: "https://ehgt.org/ab/cd/preview.webp"))
        let combinedURL = URLUtil.combinedPreviewURL(
            plainURL: plainURL,
            width: "200",
            height: "300",
            offset: "40"
        )

        #expect(combinedURL.previewCacheCleanupURLs() == [combinedURL, plainURL])
        #expect(plainURL.previewCacheCleanupURLs() == [plainURL])
    }

    @Test
    func testCheckIfMPVURLHandlesHostOnlyURL() throws {
        let url = try #require(URL(string: "https://e-hentai.org"))

        #expect(GalleryURLParser.isMPVURL(url) == false)
    }

    @Test
    func testCheckIfMPVURLDetectsMPVPath() throws {
        let url = try #require(URL(string: "https://e-hentai.org/mpv/123456/token"))

        #expect(GalleryURLParser.isMPVURL(url))
    }
}
