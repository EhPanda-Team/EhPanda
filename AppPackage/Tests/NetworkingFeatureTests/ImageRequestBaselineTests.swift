import AppModels
import AppTools
import Foundation
import Testing
@testable import NetworkingFeature

// Wave 0 lock for every request declared in Request+Image.swift, including the fan-out and the
// whole-chain retry behavior of the refetch pipeline.
@Suite
struct ImageRequestBaselineTests {
    @Test
    func mpvKeysRequestLocksAssemblyAndParsing() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/mpv/123/token/"))
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .mpvKeysFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = try await MPVKeysRequest(
            mpvURL: url,
            urlSession: session,
            allowsCellular: false
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.allowsCellularAccess == false)
        #expect(result.0 == "baseline-mpv-key")
        #expect(result.1 == [1: "first-image-key", 2: "second-image-key"])
    }

    @Test
    func thumbnailURLsRequestLocksAssemblyAndParsing() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/123/token/"))
        let url = URLUtil.detailPage(url: galleryURL, pageNum: 2)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .thumbnailFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let thumbnails = try await ThumbnailURLsRequest(
            galleryURL: galleryURL,
            pageNum: 2,
            urlSession: session,
            allowsCellular: false
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.allowsCellularAccess == false)
        #expect(thumbnails[1] == URL(string: "https://e-hentai.org/s/first/123-1"))
        #expect(thumbnails[2] == URL(string: "https://e-hentai.org/s/second/123-2"))
    }

    @Test
    func normalImageFanOutRestoresOriginalIndexes() async throws {
        let first = try #require(URL(string: "https://e-hentai.org/s/first/123-1"))
        let second = try #require(URL(string: "https://e-hentai.org/s/second/123-2"))
        let third = try #require(URL(string: "https://e-hentai.org/s/third/123-3"))
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                first: [.http(status: 200, data: normalImageFixture(index: 1))],
                second: [.http(status: 200, data: normalImageFixture(index: 2))],
                third: [.http(status: 200, data: normalImageFixture(index: 3))]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = try await GalleryNormalImageURLsRequest(
            thumbnailURLs: [30: third, 10: first, 20: second],
            urlSession: session,
            allowsCellular: false
        )
        .legacyResponse()
        .get()

        #expect(result.0[10] == URL(string: "https://images.example.com/1.jpg"))
        #expect(result.0[20] == URL(string: "https://images.example.com/2.jpg"))
        #expect(result.0[30] == URL(string: "https://images.example.com/3.jpg"))
        #expect(result.1[10] == URL(string: "https://e-hentai.org/fullimg.php?page=1"))
        #expect(result.1[20] == URL(string: "https://e-hentai.org/fullimg.php?page=2"))
        #expect(result.1[30] == URL(string: "https://e-hentai.org/fullimg.php?page=3"))
        #expect(handle.attempts(for: first) == 1)
        #expect(handle.attempts(for: second) == 1)
        #expect(handle.attempts(for: third) == 1)
    }

    @Test
    func normalImageFanOutRetriesOnlyFailingChildAndFailsWholeRequest() async throws {
        let healthyA = try #require(URL(string: "https://e-hentai.org/s/healthy-a/123-1"))
        let failing = try #require(URL(string: "https://e-hentai.org/s/failing/123-2"))
        let healthyB = try #require(URL(string: "https://e-hentai.org/s/healthy-b/123-3"))
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                healthyA: [.http(status: 200, data: normalImageFixture(index: 1))],
                failing: [.transportFailure(.timedOut)],
                healthyB: [.http(status: 200, data: normalImageFixture(index: 3))]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await GalleryNormalImageURLsRequest(
            thumbnailURLs: [1: healthyA, 2: failing, 3: healthyB],
            urlSession: session
        )
        .legacyResponse()

        expectFailure(result, error: .networkingFailed)
        #expect(handle.attempts(for: failing) == 4)
        #expect(handle.attempts(for: healthyA) == 1)
        #expect(handle.attempts(for: healthyB) == 1)
    }

    @Test
    func normalImageRefetchLocksThreeStepAssemblyAndResponse() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/123/token/"))
        let storedThumbnail = try #require(URL(string: "https://e-hentai.org/s/stored/123-1"))
        let storedImage = try #require(URL(string: "https://images.example.com/stored.jpg"))
        let renewedThumbnail = storedThumbnail.appending(queryItems: [.skipServerIdentifier: "server-1"])
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                storedThumbnail: [.http(status: 200, data: .refetchRenewalFixture)],
                renewedThumbnail: [.http(status: 206, data: normalImageFixture(index: 99))]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = try await GalleryNormalImageURLRefetchRequest(
            index: 7,
            pageNum: 0,
            galleryURL: galleryURL,
            thumbnailURL: storedThumbnail,
            storedImageURL: storedImage,
            urlSession: session,
            allowsCellular: false
        )
        .legacyResponse()
        .get()

        #expect(result.0[7] == URL(string: "https://images.example.com/renewed.jpg"))
        #expect(result.1?.statusCode == 206)
        #expect(handle.attempts(for: storedThumbnail) == 1)
        #expect(handle.attempts(for: renewedThumbnail) == 1)
        #expect(handle.receivedRequests.allSatisfy { $0.allowsCellularAccess == false })
    }

    @Test
    func normalImageRefetchRetriesTheWholeChainFourTimes() async throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/123/token/"))
        let storedThumbnail = try #require(URL(string: "https://e-hentai.org/s/stored/123-2"))
        let storedImage = try #require(URL(string: "https://images.example.com/stored.jpg"))
        let renewedThumbnail = storedThumbnail.appending(queryItems: [.skipServerIdentifier: "server-1"])
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                storedThumbnail: [.http(status: 200, data: .refetchRenewalFixture)],
                renewedThumbnail: [.transportFailure(.timedOut)]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await GalleryNormalImageURLRefetchRequest(
            index: 7,
            pageNum: 0,
            galleryURL: galleryURL,
            thumbnailURL: storedThumbnail,
            storedImageURL: storedImage,
            urlSession: session
        )
        .legacyResponse()

        expectFailure(result, error: .networkingFailed)
        #expect(handle.attempts(for: storedThumbnail) == 4)
        #expect(handle.attempts(for: renewedThumbnail) == 4)
    }

    @Test
    func mpvImageURLRequestLocksJSONAssemblyAndParsing() async throws {
        let apiURL = try #require(URL(string: "https://e-hentai.org/api.php"))
        let responseData = Data(
            """
            {"i":"https://images.example.com/mpv.jpg","s":42,
            "lf":"fullimg.php?gid=123&page=4&key=original"}
            """.utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([apiURL: [.http(status: 200, data: responseData)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = try await GalleryMPVImageURLRequest(
            gid: 123,
            index: 4,
            mpvKey: "mpv-key",
            mpvImageKey: "image-key",
            skipServerIdentifier: "old-server",
            apiURL: apiURL,
            urlSession: session,
            allowsCellular: false
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(request.url == apiURL)
        #expect(request.httpMethod == "POST")
        #expect(request.allowsCellularAccess == false)
        #expect(json["method"] as? String == "imagedispatch")
        #expect(json["gid"] as? Int == 123)
        #expect(json["page"] as? Int == 4)
        #expect(json["imgkey"] as? String == "image-key")
        #expect(json["mpvkey"] as? String == "mpv-key")
        #expect(json["nl"] as? String == "old-server")
        #expect(result.imageURL == URL(string: "https://images.example.com/mpv.jpg"))
        #expect(result.skipServerIdentifier == "42")
        #expect(result.originalImageURL?.absoluteString.contains("fullimg.php") == true)
    }

    @Test
    func dataRequestLocksRawPayloadAndRetryScope() async throws {
        let url = try #require(URL(string: "https://images.example.com/raw.bin"))
        let payload = Data([0, 1, 2, 3, 255])
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: payload)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = try await DataRequest(url: url, urlSession: session).legacyResponse().get()
        let request = try #require(handle.receivedRequests.first)

        #expect(result == payload)
        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(handle.attempts(for: url) == 1)
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

private func normalImageFixture(index: Int) -> Data {
    Data(
        """
        <html><body>
        <div id='i3'><img src='https://images.example.com/\(index).jpg'></div>
        <div id='i7'><a href='https://e-hentai.org/fullimg.php?page=\(index)'>Original</a></div>
        </body></html>
        """.utf8
    )
}

private extension Data {
    static let mpvKeysFixture = Data(
        """
        <html><body><script type='text/javascript'>
        var mpvkey = "baseline-mpv-key";
        var imagelist = [{"k":"first-image-key"},{"k":"second-image-key"}]
        </script></body></html>
        """.utf8
    )

    static let thumbnailFixture = Data(
        """
        <html><body><div id='gdt'>
        <a href='https://e-hentai.org/s/first/123-1'>
          <div title='Page 1: first.jpg' style='width:100px'></div>
        </a>
        <a href='https://e-hentai.org/s/second/123-2'>
          <div title='Page 2: second.jpg' style='width:100px'></div>
        </a>
        </div></body></html>
        """.utf8
    )

    static let refetchRenewalFixture = Data(
        """
        <html><body>
        <div id='i6'><a id='loadfail' onclick="return nl('server-1')">Retry</a></div>
        <div id='i3'><img src='https://images.example.com/renewed.jpg'></div>
        </body></html>
        """.utf8
    )
}
