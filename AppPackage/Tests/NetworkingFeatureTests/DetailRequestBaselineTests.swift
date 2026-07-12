import AppModels
import AppTools
import Foundation
import Testing
@testable import NetworkingFeature

// Wave 0 lock for every request declared in Request+Detail.swift. The large gallery-detail fixture
// is reused from ParserFeatureTests rather than replaced with a hand-crafted approximation.
@Suite
struct DetailRequestBaselineTests {
    @Test
    func galleryDetailRequestLocksAssemblyAndParsing() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/2725078/baseline/"))
        let requestURL = URLUtil.galleryDetail(url: galleryURL)
        let (session, handle) = makeStubbedSession(
            script: StubScript([requestURL: [.http(status: 200, data: try galleryDetailFixture())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let response = try await GalleryDetailRequest(
            gid: "2725078",
            galleryURL: galleryURL,
            urlSession: session,
            allowsCellular: false
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectEquivalentURL(request.url, requestURL)
        #expect(request.httpMethod == "GET")
        #expect(request.allowsCellularAccess == false)
        #expect(response.galleryDetail.gid == "2725078")
        #expect(response.galleryDetail.title == "[Artist] mks")
        #expect(response.galleryDetail.pageCount == 156)
        #expect(response.galleryState.previewURLs.count == 40)
        #expect(response.apiKey.isEmpty == false)
    }

    @Test
    func galleryVersionMetadataRequestLocksGDataAssemblyAndDecoding() async throws {
        let url = Defaults.URL.api
        let data = Data(
            """
            {"gmetadata":[{"gid":123,"token":"token","current_gid":124,
            "current_key":"current","parent_gid":122,"parent_key":"parent",
            "first_gid":120,"first_key":"first"}]}
            """.utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: data)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let metadata = try await GalleryVersionMetadataRequest(
            gid: "123",
            token: "token",
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let gidList = try #require(json["gidlist"] as? [[Any]])

        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "POST")
        #expect(json["method"] as? String == "gdata")
        #expect(json["namespace"] as? Int == 1)
        #expect(gidList[0][0] as? Int == 123)
        #expect(gidList[0][1] as? String == "token")
        #expect(metadata.gid == "123")
        #expect(metadata.currentGID == "124")
        #expect(metadata.currentKey == "current")
        #expect(metadata.parentGID == "122")
        #expect(metadata.firstGID == "120")
    }

    @Test
    func galleryReverseRequestLocksTwoStepChain() async throws {
        let imagePageURL = try #require(URL(string: "https://e-hentai.org/s/key/2725078-1"))
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/2725078/baseline/"))
        let firstPage = Data(
            "<html><div class='sb'><a href='\(galleryURL.absoluteString)'>Gallery</a></div></html>".utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                imagePageURL: [.http(status: 200, data: firstPage)],
                galleryURL: [.http(status: 200, data: try galleryDetailFixture())]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let gallery = try await GalleryReverseRequest(
            url: imagePageURL,
            isGalleryImageURL: true,
            urlSession: session
        )
        .legacyResponse()
        .get()

        #expect(gallery.gid == "2725078")
        #expect(gallery.title == "[Artist] mks")
        #expect(handle.attempts(for: imagePageURL) == 1)
        #expect(handle.attempts(for: galleryURL) == 1)
    }

    @Test
    func galleryReverseSecondStepFailureIsNotRetried() async throws {
        let imagePageURL = try #require(URL(string: "https://e-hentai.org/s/key/2725078-2"))
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/2725078/baseline/"))
        let firstPage = Data(
            "<html><div class='sb'><a href='\(galleryURL.absoluteString)'>Gallery</a></div></html>".utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                imagePageURL: [.http(status: 200, data: firstPage)],
                galleryURL: [.transportFailure(.timedOut)]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await GalleryReverseRequest(
            url: imagePageURL,
            isGalleryImageURL: true,
            urlSession: session
        )
        .legacyResponse()

        expectFailure(result, error: .networkingFailed)
        #expect(handle.attempts(for: imagePageURL) == 1)
        #expect(handle.attempts(for: galleryURL) == 1)
    }

    @Test
    func galleryArchiveRequestLocksAssemblyArchiveAndFunds() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/archiver.php?gid=123&token=token"))
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .archiveAndFundsFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let response = try await GalleryArchiveRequest(archiveURL: url, urlSession: session)
            .legacyResponse()
            .get()
        let request = try #require(handle.receivedRequests.first)

        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "GET")
        #expect(response.archive.hathArchives.count == 1)
        #expect(response.archive.hathArchives.first?.resolution == .original)
        #expect(response.archive.hathArchives.first?.fileSize == "10 MiB")
        #expect(response.galleryPoints == "1234")
        #expect(response.credits == "5678")
    }

    @Test
    func galleryArchiveFundsRequestLocksTwoStepChain() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/2725078/baseline/"))
        let archiveURL = try #require(
            URL(string: "https://e-hentai.org/archiver.php?gid=3103480&token=0000000000")
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                galleryURL: [.http(status: 200, data: try galleryDetailFixture())],
                archiveURL: [.http(status: 200, data: .fundsFixture)]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let funds = try await GalleryArchiveFundsRequest(
            gid: "2725078",
            galleryURL: galleryURL,
            urlSession: session
        )
        .legacyResponse()
        .get()

        #expect(funds.0 == "1234")
        #expect(funds.1 == "5678")
        #expect(handle.attempts(for: galleryURL) == 1)
        #expect(handle.attempts(for: archiveURL) == 1)
    }

    @Test
    func galleryArchiveFundsSecondStepFailureIsNotRetried() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/2725078/baseline/"))
        let archiveURL = try #require(
            URL(string: "https://e-hentai.org/archiver.php?gid=3103480&token=0000000000")
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                galleryURL: [.http(status: 200, data: try galleryDetailFixture())],
                archiveURL: [.transportFailure(.timedOut)]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await GalleryArchiveFundsRequest(
            gid: "2725078",
            galleryURL: galleryURL,
            urlSession: session
        )
        .legacyResponse()

        expectFailure(result, error: .networkingFailed)
        #expect(handle.attempts(for: galleryURL) == 1)
        #expect(handle.attempts(for: archiveURL) == 1)
    }

    @Test
    func galleryTorrentsRequestLocksAssemblyAndParsing() async throws {
        let url = URLUtil.galleryTorrents(gid: "123", token: "token")
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .torrentFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let torrents = try await GalleryTorrentsRequest(
            gid: "123",
            token: "token",
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "GET")
        #expect(torrents.count == 1)
        #expect(torrents.first?.fileName == "baseline.torrent")
        #expect(torrents.first?.hash == "abcdef")
        #expect(torrents.first?.seedCount == 5)
    }

    @Test
    func galleryPreviewURLsRequestLocksAssemblyAndParsing() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/123/token/"))
        let url = URLUtil.detailPage(url: galleryURL, pageNum: 1)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .previewFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let previews = try await GalleryPreviewURLsRequest(
            galleryURL: galleryURL,
            pageNum: 1,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "GET")
        #expect(previews[1] == URL(string: "https://example.com/preview.jpg"))
    }
}

private func cleanUp(session: URLSession, handle: StubHandle) {
    session.invalidateAndCancel()
    handle.tearDown()
}

private func expectFailure<T>(
    _ result: Result<T, AppError>,
    error: AppError,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard case .failure(let receivedError) = result else {
        Issue.record("Expected request failure.", sourceLocation: sourceLocation)
        return
    }
    #expect(receivedError == error, sourceLocation: sourceLocation)
}

private func galleryDetailFixture() throws -> Data {
    let appPackageURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let fixtureURL = appPackageURL
        .appendingPathComponent("Sources")
        .appendingPathComponent("TestingSupport")
        .appendingPathComponent("Resources")
        .appendingPathComponent("Parser")
        .appendingPathComponent("Gallery")
        .appendingPathComponent("GalleryDetail.html")
    return try Data(contentsOf: fixtureURL)
}

private extension Data {
    static let fundsFixture = Data("<html><p>1,234 GP [?] 5,678 Credits</p></html>".utf8)

    static let archiveAndFundsFixture = Data(
        """
        <html><body>
        <table><tr><td><p>Original</p><p>10 MiB</p><p>100 GP</p></td></tr></table>
        <p>1,234 GP [?] 5,678 Credits</p>
        </body></html>
        """.utf8
    )

    static let torrentFixture = Data(
        """
        <html><body><form><table><tr>
        <td>Posted: 2026-07-12 10:00</td><td>Size: 10 MiB</td>
        <td>Seeds: 5</td><td>Peers: 2</td><td>Downloads: 12</td>
        <td>Uploader: Baseline</td>
        <td><a href='https://example.com/abcdef.torrent'>baseline.torrent</a></td>
        </tr></table></form></body></html>
        """.utf8
    )

    static let previewFixture = Data(
        """
        <html><body><div id='gdt'><a href='#'>
        <div title='Page 1: baseline.jpg' style='background:url(https://example.com/preview.jpg)'>
        </div></a></div></body></html>
        """.utf8
    )
}
