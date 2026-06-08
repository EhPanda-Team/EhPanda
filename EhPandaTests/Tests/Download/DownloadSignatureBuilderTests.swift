//
//  DownloadSignatureBuilderTests.swift
//  EhPandaTests
//

import Testing
@testable import EhPanda

struct DownloadSignatureBuilderTests {
    @Test
    func testChainVersionIdentifierBuildsChainSignature() {
        #expect(
            DownloadSignatureBuilder.chainVersionIdentifier(
                gid: sampleGID,
                token: sampleToken
            ) == "chain:\(sampleGID):\(sampleToken)"
        )
    }

    @Test
    func testChainVersionIdentifierRejectsEmptyIdentity() {
        #expect(
            DownloadSignatureBuilder.chainVersionIdentifier(
                gid: "",
                token: sampleToken
            ) == nil
        )
        #expect(
            DownloadSignatureBuilder.chainVersionIdentifier(
                gid: sampleGID,
                token: ""
            ) == nil
        )
    }

    @Test
    func testHashAndChainSignaturesAreIncomparableForUpdateCheck() {
        #expect(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:newgid:newtoken",
                gid: sampleGID,
                token: sampleToken
            ) == .incomparable
        )
        #expect(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:newgid:newtoken",
                gid: sampleGID,
                token: sampleToken
            ) == nil
        )
    }

    @Test
    func testCanonicalizeHashToOriginalChainOnlyWhenLatestMatchesOriginalGalleryIdentity() {
        let latestSignature = "chain:\(sampleGID):\(sampleToken)"

        #expect(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: latestSignature,
                gid: sampleGID,
                token: sampleToken
            ) == .same
        )
        #expect(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: latestSignature,
                gid: sampleGID,
                token: sampleToken
            ) == latestSignature
        )
    }

    @Test
    func testDoNotCanonicalizeHashWhenLatestChainPointsToDifferentCurrentGallery() {
        #expect(
            DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:othergid:othertoken",
                gid: sampleGID,
                token: sampleToken
            ) == .incomparable
        )
        #expect(
            DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                remoteVersionSignature: "hash:abc",
                latestRemoteVersionSignature: "chain:othergid:othertoken",
                gid: sampleGID,
                token: sampleToken
            ) == nil
        )
    }
}

private let sampleGID = "1394965"
private let sampleToken = "56c35114b6"
