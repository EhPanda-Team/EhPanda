//
//  DownloadSignatureBuilderTests.swift
//  EhPandaTests
//

import Testing
import Foundation
@testable import EhPanda

struct DownloadSignatureBuilderTests {
    @Test
    func testVersionIdentifierPrefersGalleryChainMetadata() throws {
        let signature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: try #require(URL(
                    string: "https://alpha.hath.network/c2/token-a/1394965-0.webp"
                        + "?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=0"
                ))
            ],
            versionMetadata: .init(
                gid: "1394965",
                token: "56c35114b6",
                currentGID: "2000000",
                currentKey: "new-chain-key",
                parentGID: "1394965",
                parentKey: "56c35114b6",
                firstGID: "1394965",
                firstKey: "56c35114b6"
            )
        )

        #expect(signature == "chain:2000000:new-chain-key")
    }

    @Test
    func testVersionIdentifierFallsBackToOriginalGalleryIdentityWhenCurrentChainFieldsAreMissing() {
        let signature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [:],
            versionMetadata: .init(
                gid: sampleGallery.gid,
                token: sampleGallery.token,
                currentGID: nil,
                currentKey: nil,
                parentGID: nil,
                parentKey: nil,
                firstGID: nil,
                firstKey: nil
            )
        )

        #expect(signature == "chain:\(sampleGallery.gid):\(sampleGallery.token)")
    }

    @Test
    func testMakeReturnsHashPrefixedFallbackSignature() {
        let signature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [:]
        )

        #expect(signature.hasPrefix("hash:"))
    }

    @Test
    func testHashAndChainSignaturesAreIncomparableForUpdateCheck() {
        #expect(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:newgid:newtoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ) == .incomparable
        )
        #expect(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:newgid:newtoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ) == nil
        )
    }

    @Test
    func testCanonicalizeHashToOriginalChainOnlyWhenLatestMatchesOriginalGalleryIdentity() {
        let latestSignature = "chain:\(sampleGallery.gid):\(sampleGallery.token)"

        #expect(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: latestSignature,
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ) == .same
        )
        #expect(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: latestSignature,
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ) == latestSignature
        )
    }

    @Test
    func testDoNotCanonicalizeHashWhenLatestChainPointsToDifferentCurrentGallery() {
        #expect(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:othergid:othertoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ) == .incomparable
        )
        #expect(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:othergid:othertoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ) == nil
        )
    }

}

private extension DownloadSignatureBuilderTests {
    var sampleGallery: Gallery {
        Gallery(
            gid: "1394965",
            token: "56c35114b6",
            title: "(C95) [Hoshimame (Hoshimame Mana)] Mugyutto Mugyu Gurumi (Summer Pockets)[Chinese] [红茶汉化组]",
            rating: 4.5,
            tags: [],
            category: .nonH,
            uploader: "多路卡",
            pageCount: 26,
            postedDate: samplePostedDate,
            coverURL: URL(string: "https://ehgt.org/cover.webp"),
            galleryURL: URL(string: "https://e-hentai.org/g/1394965/56c35114b6/")
        )
    }

    var sampleDetail: GalleryDetail {
        sampleDetailWithCoverURL("https://ehgt.org/cover.webp")
    }

    func sampleDetailWithCoverURL(_ coverURL: String) -> GalleryDetail {
        GalleryDetail(
            gid: "1394965",
            title: sampleGallery.title,
            jpnTitle: "(C95) [ほしまめ (星豆まな)] むぎゅっとむぎゅぐるみ (Summer Pockets)[中国翻訳]",
            isFavorited: false,
            visibility: .yes,
            rating: 4.5,
            userRating: 0,
            ratingCount: 0,
            category: .nonH,
            language: .chinese,
            uploader: "多路卡",
            postedDate: samplePostedDate,
            coverURL: URL(string: coverURL),
            favoritedCount: 0,
            pageCount: 26,
            sizeCount: 114,
            sizeType: "MB",
            torrentCount: 0
        )
    }

    var samplePostedDate: Date {
        Date(timeIntervalSince1970: 576_346_020)
    }
}
