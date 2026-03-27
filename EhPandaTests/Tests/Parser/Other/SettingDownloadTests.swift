//
//  SettingDownloadTests.swift
//  EhPandaTests
//

import SwiftUI
import Testing
@testable import EhPanda

struct SettingDownloadTests {
    @Test
    func testLegacySettingDecodesDownloadDefaults() throws {
        let data = """
        {
          "galleryHost": "E-Hentai",
          "showsNewDawnGreeting": true
        }
        """.data(using: .utf8)!

        let setting = try JSONDecoder().decode(Setting.self, from: data)

        #expect(setting.downloadThreadMode == .single)
        #expect(setting.downloadAllowCellular)
        #expect(setting.downloadAutoRetryFailedPages)
    }

    @Test
    func testDownloadOptionsSnapshotMatchesSettingValues() {
        var setting = Setting()
        setting.downloadThreadMode = .quadruple
        setting.downloadAllowCellular = false
        setting.downloadAutoRetryFailedPages = false

        #expect(
            setting.downloadOptionsSnapshot == DownloadOptionsSnapshot(
                threadMode: .quadruple,
                allowCellular: false,
                autoRetryFailedPages: false
            )
        )
    }

    @Test
    func testLegacyDownloadOptionsSnapshotDecodesWithoutOriginalImageField() throws {
        let data = """
        {
          "threadMode": "triple",
          "useOriginalImages": true,
          "allowCellular": false,
          "autoRetryFailedPages": false
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(DownloadOptionsSnapshot.self, from: data)

        #expect(
            snapshot == DownloadOptionsSnapshot(
                threadMode: .triple,
                allowCellular: false,
                autoRetryFailedPages: false
            )
        )
    }

    @Test
    func testImageCacheKeysPreferStablePathAlias() {
        let url = URL(string: "https://alpha.hath.network/h/123/456/image.webp?download=1")!

        #expect(
            url.imageCacheKeys(includeStableAlias: true) == [
                "download::h/123/456/image.webp",
                "https://alpha.hath.network/h/123/456/image.webp?download=1"
            ]
        )
    }

    @Test
    func testStableImageCacheKeyIgnoresHostRotationAndQuery() {
        let firstURL = URL(string: "https://alpha.hath.network/h/123/456/image.webp?download=1")!
        let secondURL = URL(string: "https://beta.hath.network/h/123/456/image.webp?source=viewer")!

        #expect(firstURL.stableImageCacheKey == secondURL.stableImageCacheKey)
    }

    @Test
    func testStableImageCacheKeyKeepsIdentityQueryForFullImageScript() {
        let firstURL = URL(string: "https://e-hentai.org/fullimg.php?gid=42&page=7&key=alpha")!
        let secondURL = URL(string: "https://exhentai.org/fullimg.php?page=7&gid=42&key=beta")!

        #expect(firstURL.stableImageCacheKey == "download::fullimg.php?gid=42&key=alpha&page=7")
        #expect(secondURL.stableImageCacheKey == "download::fullimg.php?gid=42&key=beta&page=7")
        #expect(firstURL.stableImageCacheKey != secondURL.stableImageCacheKey)
    }

    @Test
    func testCombinedPreviewURLCleanupIncludesPlainPreviewURL() {
        let plainURL = URL(string: "https://ehgt.org/ab/cd/preview.webp")!
        let combinedURL = URLUtil.combinedPreviewURL(
            plainURL: plainURL,
            width: "200",
            height: "300",
            offset: "40"
        )

        #expect(combinedURL.previewCacheCleanupURLs() == [combinedURL, plainURL])
        #expect(plainURL.previewCacheCleanupURLs() == [plainURL])
    }
}
