import AppModels
import Foundation
import NetworkingFeature
import Testing
import TestingSupport

// The My Tags requests (port of PR 462 item 10) on synthetic pages in the site's markup. Every request runs through a
// token-isolated URLProtocol session, so these tests never open a socket and never reach the site.
struct MyTagsRequestTests: TestHelper {
    private static let tagSet1URL = URL(string: "https://e-hentai.org/mytags")
    private static let tagSet2URL = URL(string: "https://e-hentai.org/mytags?tagset=2")
    private static let apiURL = URL(string: "https://e-hentai.org/api.php")

    @Test
    func formItemsAreEncodedOneByOneInTheirOrder() {
        let items = [
            URLQueryItem(name: "modify_usertags[]", value: "1"),
            URLQueryItem(name: "modify_usertags[]", value: "2"),
            URLQueryItem(name: "tagname_new", value: "a&b=c+d e:f"),
            URLQueryItem(name: "tagcolor_new", value: nil)
        ]
        let expected = "modify_usertags%5B%5D=1&modify_usertags%5B%5D=2"
            + "&tagname_new=a%26b%3Dc%2Bd%20e%3Af&tagcolor_new="

        #expect(items.formURLEncodedString() == expected)
    }

    @Test
    func theFetchReadsEveryTagSetInThePickersOrder() async throws {
        let set1URL = try #require(Self.tagSet1URL)
        let set2URL = try #require(Self.tagSet2URL)
        let page1 = try fixture(.myTagsTagSet1)
        let page2 = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([
            set1URL: [.http(status: 200, data: page1)],
            set2URL: [.http(status: 200, data: page2)]
        ]))
        defer { cleanUp(session: session, handle: handle) }

        let response = try await capture { () async throws(AppError) -> MyTagsResponse in
            try await MyTagsRequest(host: .ehentai, urlSession: session).response()
        }
        .get()

        #expect(response.myTags.tagSets.map(\.id) == [1, 2])
        #expect(response.myTags.tagSets.map(\.name) == ["Tagset #1", "Fixture Picks"])
        #expect(response.myTags.tagSets.map(\.tags.count) == [4, 1])
        #expect(response.apiuid == 1234567)
        #expect(response.apikey == "0123456789abcdef")
        let urls = handle.receivedRequests.compactMap(\.url)
        #expect(urls.count == 2)
        expectEquivalentURL(urls.first, set1URL)
        expectEquivalentURL(urls.last, set2URL)
    }

    @Test
    func aTagSetsPageIsReadAtThePickersAddress() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: page)]]))
        defer { cleanUp(session: session, handle: handle) }

        let answer = try await capture { () async throws(AppError) -> MyTagsPage in
            try await MyTagSetRequest(host: .ehentai, tagSetID: 2, urlSession: session).response()
        }
        .get()

        #expect(answer.tagSet.id == 2)
        let request = try #require(handle.receivedRequests.first)
        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "GET")
    }

    @Test(arguments: MyTagKind.allCases)
    func anAddPostsTheAddRowsFieldsToTheSetsPage(kind: MyTagKind) async throws {
        let url = try #require(Self.tagSet1URL)
        let page = try fixture(.myTagsTagSet1)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: page)]]))
        defer { cleanUp(session: session, handle: handle) }

        let tag = MyTagDraft(
            name: "parody:sample series", kind: kind, color: SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0), weight: -5
        )

        let answer = try await capture { () async throws(AppError) -> MyTagsPage in
            try await AddMyTagRequest(host: .ehentai, tagSetID: 1, tag: tag, urlSession: session).response()
        }
        .get()

        let kindField = switch kind {
        case .flagged: ""
        case .watched: "&tagwatch_new=on"
        case .hidden: "&taghide_new=on"
        }
        #expect(answer.tagSet.id == 1)
        #expect(answer.message == nil)
        #expect(handle.attempts(for: url) == 1)
        let request = try #require(handle.receivedRequests.first)
        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(
            body(of: request) == "usertag_action=add&tagname_new=parody%3Asample%20series"
                + kindField + "&tagcolor_new=%23A0B0C0&tagweight_new=-5&usertag_target=0"
        )
    }

    @Test
    func aRefusedAddAnswersThePageWithTheSitesReason() async throws {
        let url = try #require(Self.tagSet1URL)
        let html = try htmlString(filename: .myTagsTagSet1)
        let target = #"<div class="stuffbox" id="outer">"#
        try #require(html.contains(target))
        let message = #"<div id="msg"><p>No matching tag found</p></div>"#
        let refused = Data(html.replacing(target, with: target + message).utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: refused)]]))
        defer { cleanUp(session: session, handle: handle) }
        let tag = MyTagDraft(name: "artist:no such tag", kind: .flagged, color: nil, weight: 10)

        let answer = try await capture { () async throws(AppError) -> MyTagsPage in
            try await AddMyTagRequest(host: .ehentai, tagSetID: 1, tag: tag, urlSession: session).response()
        }
        .get()

        #expect(answer.message == "No matching tag found")
    }

    @Test
    func aRemovePostsTheMassActionToTheSetsPageOnTheSelectedHost() async throws {
        let url = try #require(URL(string: "https://exhentai.org/mytags?tagset=2"))
        let page = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: page)]]))
        defer { cleanUp(session: session, handle: handle) }

        let answer = try await capture { () async throws(AppError) -> MyTagsPage in
            try await RemoveMyTagsRequest(host: .exhentai, tagSetID: 2, tagIDs: [201, 202], urlSession: session)
                .response()
        }
        .get()

        #expect(answer.tagSet.id == 2)
        let request = try #require(handle.receivedRequests.first)
        expectEquivalentURL(request.url, url)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(
            body(of: request)
                == "usertag_action=mass&modify_usertags%5B%5D=201&modify_usertags%5B%5D=202&usertag_target=0"
        )
    }

    // An unchecked Enabled box sends no field, as a browser does; no colour sends the field empty.
    @Test
    func aTagSetUpdatePostsTheFormsFieldsInOrder() async throws {
        let url = try #require(Self.tagSet2URL)
        let page = try fixture(.myTagsTagSet2)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.http(status: 200, data: page), .http(status: 200, data: page)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)

        #expect(try await updateTagSet(isEnabled: true, color: green, session: session).tagSet.id == 2)
        #expect(try await updateTagSet(isEnabled: false, color: nil, session: session).tagSet.id == 2)

        let requests = handle.receivedRequests
        #expect(requests.map(\.httpMethod) == ["POST", "POST"])
        #expect(requests.map({ body(of: $0) }) == [
            "tagset_action=update&tagset_name=&tagset_enable=on&tagset_color=%2322AA55",
            "tagset_action=update&tagset_name=&tagset_color="
        ])
    }

    @Test
    func anEditPostsSetUserTagWithTheTagsStateColourAndWeight() async throws {
        let url = try #require(Self.apiURL)
        let reply = Data(#"{"tagid":101}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([
            url: [.http(status: 200, data: reply), .http(status: 200, data: reply)]
        ]))
        defer { cleanUp(session: session, handle: handle) }
        let watched = MyTag(
            id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
        )
        let hidden = MyTag(
            id: 101, name: "female:sample glasses", isWatched: false, isHidden: true,
            color: SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0), weight: -5
        )

        #expect(try await update(watched, session: session) == .accepted)
        #expect(try await update(hidden, session: session) == .accepted)

        var bodies = [SetUserTagBody]()
        for request in handle.receivedRequests {
            #expect(request.httpMethod == "POST")
            let data = try #require(request.httpBody)
            let decoded = try JSONDecoder().decode(SetUserTagBody.self, from: data)
            bodies.append(decoded)
        }
        #expect(bodies == [
            SetUserTagBody(tagid: 101, tagwatch: 1, taghide: 0, tagcolor: "", tagweight: "10"),
            SetUserTagBody(tagid: 101, tagwatch: 0, taghide: 1, tagcolor: "#A0B0C0", tagweight: "-5")
        ])
    }

    @Test
    func aRefusedEditAnswersTheSitesReason() async throws {
        let url = try #require(Self.apiURL)
        let reply = Data(#"{"error":"The provided color code is invalid","tagid":101}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: reply)]]))
        defer { cleanUp(session: session, handle: handle) }
        let tag = MyTag(
            id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
        )

        #expect(try await update(tag, session: session) == .refused("The provided color code is invalid"))
    }

    @Test(arguments: ["{}", "<html></html>"])
    func aReplyWithNeitherTheTagNorAReasonIsAParseFailure(reply: String) async throws {
        let url = try #require(Self.apiURL)
        let data = Data(reply.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: data)]]))
        defer { cleanUp(session: session, handle: handle) }
        let tag = MyTag(
            id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
        )

        let result = await capture { () async throws(AppError) -> MyTagEditReply in
            try await UpdateMyTagRequest(
                host: .ehentai, apiuid: 1234567, apikey: "0123456789abcdef", tag: tag, urlSession: session
            )
            .response()
        }

        #expect(result == .failure(.parseFailed))
    }

    /// The edit API's request body; the credentials are the fixtures' invented ones.
    private struct SetUserTagBody: Decodable, Equatable {
        var method = "setusertag"
        var apiuid = 1234567
        var apikey = "0123456789abcdef"
        let tagid: Int
        let tagwatch: Int
        let taghide: Int
        let tagcolor: String
        let tagweight: String
    }

    private func update(_ tag: MyTag, session: URLSession) async throws -> MyTagEditReply {
        try await capture { () async throws(AppError) -> MyTagEditReply in
            try await UpdateMyTagRequest(
                host: .ehentai, apiuid: 1234567, apikey: "0123456789abcdef", tag: tag, urlSession: session
            )
            .response()
        }
        .get()
    }

    private func updateTagSet(isEnabled: Bool, color: SiteColor?, session: URLSession) async throws -> MyTagsPage {
        try await capture { () async throws(AppError) -> MyTagsPage in
            try await UpdateMyTagSetRequest(
                host: .ehentai, tagSetID: 2, isEnabled: isEnabled, color: color, urlSession: session
            )
            .response()
        }
        .get()
    }

    private func fixture(_ filename: HTMLFilename) throws -> Data {
        try Data(htmlString(filename: filename).utf8)
    }

    private func body(of request: URLRequest) -> String? {
        request.httpBody.flatMap({ String(data: $0, encoding: .utf8) })
    }

    private func cleanUp(session: URLSession, handle: StubHandle) {
        session.invalidateAndCancel()
        handle.tearDown()
    }
}
