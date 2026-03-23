//
//  DownloadSignatureBuilderTests.swift
//  EhPandaTests
//

import XCTest
@testable import EhPanda

final class DownloadSignatureBuilderTests: XCTestCase {
    func testVersionIdentifierPrefersGalleryChainMetadata() {
        let signature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=0")!
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

        XCTAssertEqual(signature, "chain:2000000:new-chain-key")
    }

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

        XCTAssertEqual(signature, "chain:\(sampleGallery.gid):\(sampleGallery.token)")
    }

    func testMakeReturnsHashPrefixedFallbackSignature() {
        let signature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [:]
        )

        XCTAssertTrue(signature.hasPrefix("hash:"))
    }

    func testHashAndChainSignaturesAreIncomparableForUpdateCheck() {
        XCTAssertEqual(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:newgid:newtoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ),
            .incomparable
        )
        XCTAssertNil(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:newgid:newtoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            )
        )
    }

    func testCanonicalizeHashToOriginalChainOnlyWhenLatestMatchesOriginalGalleryIdentity() {
        let latestSignature = "chain:\(sampleGallery.gid):\(sampleGallery.token)"

        XCTAssertEqual(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: latestSignature,
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ),
            .same
        )
        XCTAssertEqual(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: latestSignature,
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ),
            latestSignature
        )
    }

    func testDoNotCanonicalizeHashWhenLatestChainPointsToDifferentCurrentGallery() {
        XCTAssertEqual(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:othergid:othertoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            ),
            .incomparable
        )
        XCTAssertNil(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:othergid:othertoken",
                gid: sampleGallery.gid,
                token: sampleGallery.token
            )
        )
    }

    func testSignatureIgnoresPreviewHostRotationAndLayoutChanges() {
        let firstSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=0")!,
                2: URL(string: "https://alpha.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=200")!
            ]
        )

        let secondSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://beta.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=250&ehpandaHeight=366&ehpandaOffset=0")!,
                2: URL(string: "https://beta.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=250&ehpandaHeight=366&ehpandaOffset=250")!
            ]
        )

        XCTAssertEqual(firstSignature, secondSignature)
    }

    func testSignatureChangesWhenCombinedPreviewAtlasChanges() {
        let firstSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=0")!
            ]
        )

        let secondSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.hath.network/c2/token-a/1394965-1.webp?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=0")!
            ]
        )

        XCTAssertNotEqual(firstSignature, secondSignature)
    }

    func testSignatureIgnoresCombinedPreviewTokenRotation() {
        let firstSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.hath.network/c2/token-a/1394965-0.webp?ehpandaWidth=200&ehpandaHeight=293&ehpandaOffset=0")!
            ]
        )

        let secondSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://beta.hath.network/c2/token-b/1394965-0.webp?ehpandaWidth=250&ehpandaHeight=366&ehpandaOffset=0")!
            ]
        )

        XCTAssertEqual(firstSignature, secondSignature)
    }

    func testSignatureIgnoresHostRotationForStandalonePreviewURLs() {
        let firstSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.ehgt.org/t/12/34/preview-1.webp")!,
                2: URL(string: "https://alpha.ehgt.org/t/56/78/preview-2.webp")!
            ]
        )

        let secondSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://beta.ehgt.org/t/12/34/preview-1.webp")!,
                2: URL(string: "https://beta.ehgt.org/t/56/78/preview-2.webp")!
            ]
        )

        XCTAssertEqual(firstSignature, secondSignature)
    }

    func testSignatureIgnoresCoverHostAndQueryChanges() {
        let firstSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetailWithCoverURL("https://ehgt.org/w/00/686/86308-b7cs0xve.webp?dl=1"),
            host: .ehentai,
            previewURLs: [:]
        )

        let secondSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetailWithCoverURL("https://mirror.ehgt.org/w/00/686/86308-b7cs0xve.webp?source=thumb"),
            host: .ehentai,
            previewURLs: [:]
        )

        XCTAssertEqual(firstSignature, secondSignature)
    }

    func testSignatureIgnoresGalleryHostTransitions() {
        let ehSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .ehentai,
            previewURLs: [
                1: URL(string: "https://alpha.ehgt.org/t/12/34/preview-1.webp")!
            ]
        )

        let exSignature = DownloadSignatureBuilder.make(
            gallery: sampleGallery,
            detail: sampleDetail,
            host: .exhentai,
            previewURLs: [
                1: URL(string: "https://alpha.ehgt.org/t/12/34/preview-1.webp")!
            ]
        )

        XCTAssertEqual(ehSignature, exSignature)
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
