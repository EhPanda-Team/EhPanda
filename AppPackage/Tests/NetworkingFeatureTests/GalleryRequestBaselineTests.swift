import AppModels
import AppTools
import Foundation
import Testing
@testable import NetworkingFeature

private let galleryHost: GalleryHost = .ehentai

// Wave 0 lock for the 12 gallery-list requests. The shared compact-list fixture is intentionally
// minimal, and each request still runs through its concrete Combine facade and an isolated stub.
@Suite
struct GalleryRequestBaselineTests {
    @Test
    func searchGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.searchList(host: galleryHost, keyword: "baseline", filter: Filter())
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await SearchGalleriesRequest(
                host: galleryHost,
                keyword: "baseline",
                filter: Filter(),
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(request, path: "/", query: ["f_search": "baseline"])
    }

    @Test
    func moreSearchGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.moreSearchList(
            host: galleryHost,
            keyword: "baseline",
            filter: Filter(),
            lastID: "123"
        )
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await MoreSearchGalleriesRequest(
                host: galleryHost,
                keyword: "baseline",
                filter: Filter(),
                lastID: "123",
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(request, path: "/", query: ["f_search": "baseline", "next": "123"])
    }

    @Test
    func dateSeekGalleriesRequestLocksSuppliedURLAndParsing() async throws {
        let url = galleryHost.url.appending(queryItems: ["seek": "2026-07-12"])
        let (session, handle) = listSession(url: url)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await DateSeekGalleriesRequest(host: galleryHost, url: url, urlSession: session).response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(request, path: "/", query: ["seek": "2026-07-12"])
    }

    @Test
    func frontpageGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.frontpageList(host: galleryHost, filter: Filter())
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await FrontpageGalleriesRequest(
                host: galleryHost,
                filter: Filter(),
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(request, path: "/", query: [:])
    }

    @Test
    func moreFrontpageGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.moreFrontpageList(host: galleryHost, filter: Filter(), lastID: "456")
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await MoreFrontpageGalleriesRequest(
                host: galleryHost,
                filter: Filter(),
                lastID: "456",
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(request, path: "/", query: ["next": "456"])
    }

    @Test
    func popularGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.popularList(host: galleryHost, filter: Filter())
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let galleries = try await capture { () async throws(AppError) -> [Gallery] in
            try await PopularGalleriesRequest(host: galleryHost, filter: Filter(), urlSession: session).response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectGalleries(galleries)
        expectGET(request, path: "/popular", query: [:])
    }

    @Test
    func watchedGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.watchedList(host: galleryHost, filter: Filter(), keyword: "watched")
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await WatchedGalleriesRequest(
                host: galleryHost,
                filter: Filter(),
                keyword: "watched",
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(request, path: "/watched", query: ["f_search": "watched"])
    }

    @Test
    func moreWatchedGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.moreWatchedList(
            host: galleryHost,
            filter: Filter(),
            lastID: "789",
            keyword: "watched"
        )
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture { () async throws(AppError) -> GalleriesResult in
            try await MoreWatchedGalleriesRequest(
                host: galleryHost,
                filter: Filter(),
                lastID: "789",
                keyword: "watched",
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        expectGET(
            request,
            path: "/watched",
            query: ["next": "789", "f_search": "watched"]
        )
    }

    @Test
    func favoritesGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.favoritesList(
            host: galleryHost,
            favIndex: 2,
            keyword: "favorite",
            sortOrder: .favoritedTime
        )
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture {
            () async throws(AppError) -> FavoritesGalleriesResult in
            try await FavoritesGalleriesRequest(
                host: galleryHost,
                favIndex: 2,
                keyword: "favorite",
                sortOrder: .favoritedTime,
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        #expect(result.sortOrder == .favoritedTime)
        expectGET(
            request,
            path: "/favorites.php",
            query: [
                "favcat": "2", "f_search": "favorite", "sn": "on", "st": "on",
                "sf": "on", "inline_set": "fs_f"
            ]
        )
    }

    @Test
    func moreFavoritesGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.moreFavoritesList(
            host: galleryHost,
            favIndex: 2,
            lastID: "100",
            lastTimestamp: "200",
            keyword: "favorite"
        )
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture {
            () async throws(AppError) -> FavoritesGalleriesResult in
            try await MoreFavoritesGalleriesRequest(
                host: galleryHost,
                favIndex: 2,
                lastID: "100",
                lastTimestamp: "200",
                keyword: "favorite",
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.pageNumber, galleries: result.galleries)
        #expect(result.sortOrder == .favoritedTime)
        expectGET(
            request,
            path: "/favorites.php",
            query: [
                "next": "100-200", "favcat": "2", "f_search": "favorite",
                "sn": "on", "st": "on", "sf": "on"
            ]
        )
    }

    @Test
    func toplistsGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.toplistsList(host: galleryHost, catIndex: 1, pageNum: 2)
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture {
            () async throws(AppError) -> (PageNumber, [Gallery]) in
            try await ToplistsGalleriesRequest(
                host: galleryHost,
                catIndex: 1,
                pageNum: 2,
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.0, galleries: result.1)
        expectGET(request, path: "/toplist.php", query: ["tl": "1", "p": "2"])
    }

    @Test
    func moreToplistsGalleriesRequestLocksURLAndParsing() async throws {
        let expectedURL = URLUtil.moreToplistsList(host: galleryHost, catIndex: 1, pageNum: 3)
        let (session, handle) = listSession(url: expectedURL)
        defer { cleanUp(session: session, handle: handle) }

        let result = try await capture {
            () async throws(AppError) -> (PageNumber, [Gallery]) in
            try await MoreToplistsGalleriesRequest(
                host: galleryHost,
                catIndex: 1,
                pageNum: 3,
                urlSession: session
            )
            .response()
        }
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectList(result.0, galleries: result.1)
        expectGET(request, path: "/toplist.php", query: ["tl": "1", "p": "3"])
    }

    @Test
    func galleryListPersistentTransportFailureRetriesFourTimes() async {
        let url = URLUtil.searchList(host: galleryHost, keyword: "retry", filter: Filter())
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.transportFailure(.timedOut)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> GalleriesResult in
            try await SearchGalleriesRequest(
                host: galleryHost,
                keyword: "retry",
                filter: Filter(),
                urlSession: session
            )
            .response()
        }

        guard case .failure(let error) = result else {
            Issue.record("Expected a networking failure.")
            return
        }
        #expect(error == .networkingFailed)
        #expect(handle.attempts(for: url) == 4)
    }
}

private func listSession(url: URL) -> (URLSession, StubHandle) {
    makeStubbedSession(
        script: StubScript([url: [.http(status: 200, data: .compactListFixture)]])
    )
}

private func cleanUp(session: URLSession, handle: StubHandle) {
    session.invalidateAndCancel()
    handle.tearDown()
}

private func expectList(
    _ pageNumber: PageNumber,
    galleries: [Gallery],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(pageNumber.current == 0, sourceLocation: sourceLocation)
    #expect(pageNumber.maximum == 1, sourceLocation: sourceLocation)
    expectGalleries(galleries, sourceLocation: sourceLocation)
}

private func expectGalleries(
    _ galleries: [Gallery],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(galleries.count == 1, sourceLocation: sourceLocation)
    #expect(galleries.first?.gid == "123", sourceLocation: sourceLocation)
    #expect(galleries.first?.token == "token", sourceLocation: sourceLocation)
    #expect(galleries.first?.title == "Baseline Gallery", sourceLocation: sourceLocation)
    #expect(galleries.first?.pageCount == 12, sourceLocation: sourceLocation)
}

private func expectGET(
    _ request: URLRequest,
    path: String,
    query: [String: String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
    let queryItems = components?.queryItems ?? []
    let receivedQuery = Dictionary(
        queryItems.map { ($0.name, $0.value ?? "") },
        uniquingKeysWith: { first, _ in first }
    )

    #expect(components?.scheme == galleryHost.url.scheme, sourceLocation: sourceLocation)
    #expect(components?.host == galleryHost.url.host, sourceLocation: sourceLocation)
    #expect(components?.path == path, sourceLocation: sourceLocation)
    #expect(receivedQuery == query, sourceLocation: sourceLocation)
    #expect(request.httpMethod == "GET", sourceLocation: sourceLocation)
    #expect(request.httpBody == nil, sourceLocation: sourceLocation)
}

private extension Data {
    static let compactListFixture = Data(
        """
        <html><body>
        <div id='dms'><select onchange='inline_set=dm_'>
          <option selected='selected'>Compact</option>
        </select></div>
        <table class='ptt'><tr><td class='ptds'>1</td><td><a>2</a></td></tr></table>
        <div class='ido'><div><div><a>Use Posted</a></div></div></div>
        <table><tr>
          <td class='gl2c'>
            <div><img src='https://example.com/cover.jpg'></div>
            <div>Doujinshi</div>
            <div onclick='return false'>2026-07-12 10:00</div>
            <div>12 pages</div>
            <div class='ir' style='background-position:0px'></div>
          </td>
          <td class='gl3c glname'>
            <a href='https://e-hentai.org/g/123/token/'><div class='glink'>Baseline Gallery</div></a>
          </td>
        </tr></table>
        </body></html>
        """.utf8
    )
}
