import AppModels
import AppTools
import Foundation
import Testing
@testable import NetworkingFeature

// Wave 0 lock for the gdata transport and decode path. The caller-side 25-pair chunking policy is
// intentionally outside this suite; these tests characterize one concrete gdata request offline.
@Suite
struct GalleriesMetadataBaselineTests {
    @Test
    func successLocksStructuralPOSTAndDecodedGallery() async throws {
        let url = Defaults.URL.api
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .gdataFixture)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let galleries = try await GalleriesMetadataRequest(
            gidList: [(gid: "100", token: "aaa"), (gid: "200", token: "bbb")],
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let gidList = try #require(json["gidlist"] as? [[Any]])

        #expect(request.url == url)
        #expect(request.httpMethod == "POST")
        #expect(json["method"] as? String == "gdata")
        #expect(json["namespace"] as? Int == 1)
        #expect(gidList.count == 2)
        #expect(gidList[0][0] as? Int == 100)
        #expect(gidList[0][1] as? String == "aaa")
        #expect(gidList[1][0] as? Int == 200)
        #expect(gidList[1][1] as? String == "bbb")
        #expect(galleries.map(\.gid) == ["100", "200"])
        #expect(galleries.first?.title == "First & Title")
        #expect(galleries.first?.pageCount == 20)
        #expect(handle.attempts(for: url) == 1)
    }

    @Test
    func malformedJSONMapsParseFailure() async {
        let url = Defaults.URL.api
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: Data("{".utf8))]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await GalleriesMetadataRequest(
            gidList: [(gid: "100", token: "aaa")],
            urlSession: session
        )
        .legacyResponse()

        guard case .failure(let error) = result else {
            Issue.record("Expected malformed gdata JSON to fail.")
            return
        }
        #expect(error == .parseFailed)
        #expect(handle.attempts(for: url) == 1)
    }

    @Test
    func persistentTransportFailureRetriesFourTimes() async {
        let url = Defaults.URL.api
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.transportFailure(.timedOut)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await GalleriesMetadataRequest(
            gidList: [(gid: "100", token: "aaa")],
            urlSession: session
        )
        .legacyResponse()

        guard case .failure(let error) = result else {
            Issue.record("Expected persistent transport failure.")
            return
        }
        #expect(error == .networkingFailed)
        #expect(handle.attempts(for: url) == 4)
    }
}

private func cleanUp(session: URLSession, handle: StubHandle) {
    session.invalidateAndCancel()
    handle.tearDown()
}

private extension Data {
    static let gdataFixture = Data(
        """
        {
          "gmetadata": [
            {
              "gid": 100, "token": "aaa", "title": "First &amp; Title",
              "category": "Doujinshi", "thumb": "https://example.com/1.jpg",
              "uploader": "u1", "posted": "1600000000", "filecount": "20",
              "rating": "4.5", "tags": ["language:japanese", "artist:someone"]
            },
            {
              "gid": 200, "token": "bbb", "title": "Second Title",
              "category": "Manga", "thumb": "https://example.com/2.jpg",
              "uploader": "u2", "posted": "1600000100", "filecount": "30",
              "rating": "3.0", "tags": ["language:english"]
            }
          ]
        }
        """.utf8
    )
}
