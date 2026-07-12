import AppModels
import AppTools
import Foundation
import Testing
@testable import NetworkingFeature

// Wave 0 request-layer lock for CONC-01 (D-05/D-06). Every request runs through a
// token-isolated URLProtocol session, so these characterization tests never open a socket.
@Suite
struct AccountRequestBaselineTests {
    @Test
    func loginRequestLocksFormAssemblyAndHTTPResponse() async throws {
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 204, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let response = try await LoginRequest(
            username: "baseline-user",
            password: "dummy-password",
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        #expect(response?.statusCode == 204)
        #expect(response?.url == Defaults.URL.login)
        expectFormRequest(
            request,
            url: Defaults.URL.login,
            fields: [
                "b": "d",
                "bt": "1-1",
                "CookieDate": "1",
                "UserName": "baseline-user",
                "PassWord": "dummy-password",
                "ipb_login_submit": "Login!"
            ]
        )
    }

    @Test
    func igneousRequestLocksEmptyPublisherMapping() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NonHTTPResponseProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let result = await IgneousRequest(urlSession: session).legacyResponse()

        #expect(result == .failure(.unknown))
    }

    @Test
    func verifyEhProfileRequestLocksGETAssemblyAndParsing() async throws {
        let data = Data(
            "<html><select name='profile_set'><option value='2'>EhPanda</option></select></html>".utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.uConfig: [.http(status: 200, data: data)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let response = try await VerifyEhProfileRequest(urlSession: session).legacyResponse().get()
        let request = try #require(handle.receivedRequests.first)

        #expect(response == VerifyEhProfileResponse(profileValue: 2, isProfileNotFound: false))
        expectGETRequest(request, url: Defaults.URL.uConfig)
    }

    @Test
    func ehProfileRequestLocksFormAssemblyAndParsing() async throws {
        let data = makeEhSettingFixture()
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.uConfig: [.http(status: 200, data: data)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let setting = try await EhProfileRequest(
            action: .rename,
            name: "Baseline Profile",
            set: 2,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        #expect(setting.ehProfiles.first?.name == "EhPanda")
        expectFormRequest(
            request,
            url: Defaults.URL.uConfig,
            fields: [
                "profile_action": "rename",
                "profile_name": "Baseline Profile",
                "profile_set": "2"
            ]
        )
    }

    @Test
    func ehSettingRequestLocksGETAssemblyAndParsing() async throws {
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                Defaults.URL.uConfig: [.http(status: 200, data: makeEhSettingFixture())]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let setting = try await EhSettingRequest(urlSession: session).legacyResponse().get()
        let request = try #require(handle.receivedRequests.first)

        #expect(setting.ehProfiles.first?.value == 1)
        #expect(setting.favoriteCategories == Array(repeating: "", count: 10))
        expectGETRequest(request, url: Defaults.URL.uConfig)
    }

    @Test
    func submitEhSettingChangesRequestLocksCompleteFormAndParsing() async throws {
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                Defaults.URL.uConfig: [.http(status: 200, data: makeEhSettingFixture())]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let setting = try await SubmitEhSettingChangesRequest(
            ehSetting: .empty,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)
        var expectedFields = [
            "uh": "0", "co": "-", "xr": "0", "rx": "0", "ry": "0", "tl": "0",
            "ar": "3", "dm": "0", "pp": "0", "fs": "1", "ru": "", "ft": "0",
            "wt": "0", "tf": "0", "xu": "", "rc": "1", "lt": "1", "tr": "1",
            "tp": "0", "vp": "0", "cs": "1", "sc": "1", "tb": "0", "pn": "0",
            "apply": "Apply", "ts": "1"
        ]
        for name in EhSetting.categoryNames {
            expectedFields["ct_\(name)"] = "0"
        }
        for index in 0...9 {
            expectedFields["favorite_\(index)"] = ""
        }

        #expect(setting.ehProfiles.first?.name == "EhPanda")
        expectFormRequest(request, url: Defaults.URL.uConfig, fields: expectedFields)
    }

    @Test
    func favorGalleryRequestLocksFormAssemblyAndVoidMapping() async throws {
        let url = URLUtil.addFavorite(gid: "101", token: "token")
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await FavorGalleryRequest(
            gid: "101",
            token: "token",
            favIndex: 4,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectFormRequest(
            request,
            url: url,
            fields: ["favcat": "4", "favnote": "", "apply": "Add to Favorites", "update": "1"]
        )
    }

    @Test
    func unfavorGalleryRequestLocksFormAssemblyAndVoidMapping() async throws {
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.favorites: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await UnfavorGalleryRequest(gid: "202", urlSession: session).legacyResponse().get()
        let request = try #require(handle.receivedRequests.first)

        expectFormRequest(
            request,
            url: Defaults.URL.favorites,
            fields: ["ddact": "delete", "modifygids[]": "202", "apply": "Apply"]
        )
    }

    @Test
    func sendDownloadCommandRequestLocksFormAssemblyAndParsing() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/archiver.php?gid=303"))
        let data = Data(
            """
            <html><div id='db'><p>
            A Original resolution archive was requested for client Baseline Downloads
            </p></div></html>
            """.utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: data)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let response = try await SendDownloadCommandRequest(
            archiveURL: url,
            resolution: "org",
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        #expect(response == "Original -> Baseline")
        expectFormRequest(request, url: url, fields: ["hathdl_xres": "org"])
    }

    @Test
    func rateGalleryRequestLocksJSONAssemblyAndVoidMapping() async throws {
        let expected = [
            "method": "rategallery", "apiuid": "11", "apikey": "dummy-key",
            "gid": "404", "token": "token", "rating": "9"
        ]
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.api: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await RateGalleryRequest(
            apiuid: 11,
            apikey: "dummy-key",
            gid: 404,
            token: "token",
            rating: 9,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectJSONRequest(request, url: Defaults.URL.api, fields: expected)
    }

    @Test
    func commentGalleryRequestLocksFormAssemblyAndVoidMapping() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/g/505/token/"))
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await CommentGalleryRequest(
            content: "first\nsecond",
            galleryURL: url,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectFormRequest(request, url: url, fields: ["commenttext_new": "first%0Asecond"])
    }

    @Test
    func editGalleryCommentRequestLocksFormAssemblyAndVoidMapping() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/g/606/token/"))
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await EditGalleryCommentRequest(
            commentID: "707",
            content: "edited\ntext",
            galleryURL: url,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectFormRequest(
            request,
            url: url,
            fields: ["edit_comment": "707", "commenttext_edit": "edited%0Atext"]
        )
    }

    @Test
    func voteGalleryCommentRequestLocksJSONAssemblyAndVoidMapping() async throws {
        let expected = [
            "method": "votecomment", "apiuid": "12", "apikey": "dummy-key",
            "gid": "808", "token": "token", "comment_id": "909", "comment_vote": "-1"
        ]
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.api: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await VoteGalleryCommentRequest(
            apiuid: 12,
            apikey: "dummy-key",
            gid: 808,
            token: "token",
            commentID: 909,
            commentVote: -1,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectJSONRequest(request, url: Defaults.URL.api, fields: expected)
    }

    @Test
    func voteGalleryTagRequestLocksJSONAssemblyAndVoidMapping() async throws {
        let expected = [
            "method": "taggallery", "apiuid": "13", "apikey": "dummy-key",
            "gid": "1001", "token": "token", "tags": "artist:baseline", "vote": "1"
        ]
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.api: [.http(status: 200, data: Data())]])
        )
        defer { cleanUp(session: session, handle: handle) }

        _ = try await VoteGalleryTagRequest(
            apiuid: 13,
            apikey: "dummy-key",
            gid: 1001,
            token: "token",
            tag: "artist:baseline",
            vote: 1,
            urlSession: session
        )
        .legacyResponse()
        .get()
        let request = try #require(handle.receivedRequests.first)

        expectJSONRequest(request, url: Defaults.URL.api, fields: expected)
    }

    @Test
    func accountPOSTPersistentTransportFailureRetriesFourTimes() async {
        let url = Defaults.URL.login
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.transportFailure(.timedOut)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await LoginRequest(
            username: "baseline-user",
            password: "dummy-password",
            urlSession: session
        )
        .legacyResponse()

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: url) == 4)
    }
}

private func cleanUp(session: URLSession, handle: StubHandle) {
    session.invalidateAndCancel()
    handle.tearDown()
}

private func expectGETRequest(
    _ request: URLRequest,
    url: URL,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    expectEquivalentURL(request.url, url, sourceLocation: sourceLocation)
    #expect(request.httpMethod == "GET", sourceLocation: sourceLocation)
    #expect(request.httpBody == nil, sourceLocation: sourceLocation)
}

private func expectFormRequest(
    _ request: URLRequest,
    url: URL,
    fields: [String: String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    expectEquivalentURL(request.url, url, sourceLocation: sourceLocation)
    #expect(request.httpMethod == "POST", sourceLocation: sourceLocation)
    #expect(
        request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded",
        sourceLocation: sourceLocation
    )
    #expect(formFields(from: request) == fields, sourceLocation: sourceLocation)
}

private func expectJSONRequest(
    _ request: URLRequest,
    url: URL,
    fields: [String: String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    expectEquivalentURL(request.url, url, sourceLocation: sourceLocation)
    #expect(request.httpMethod == "POST", sourceLocation: sourceLocation)
    #expect(jsonFields(from: request) == fields, sourceLocation: sourceLocation)
}

private func formFields(from request: URLRequest) -> [String: String] {
    guard
        let body = request.httpBody,
        let string = String(data: body, encoding: .utf8),
        let items = URLComponents(string: "?\(string)")?.queryItems
    else {
        return [:]
    }
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

private func jsonFields(from request: URLRequest) -> [String: String] {
    guard
        let body = request.httpBody,
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    else {
        return [:]
    }
    return object.mapValues { String(describing: $0) }
}

private func makeEhSettingFixture() -> Data {
    let categories = EhSetting.categoryNames.map { name in
        "<input name='ct_\(name)' value='0'>"
    }
    .joined()
    let favorites = (0...9).map { index in
        "<input name='favorite_\(index)' value=''>"
    }
    .joined()
    let languages = EhSetting.languageValues.map { value in
        "<input name='xl_\(value)' type='checkbox'>"
    }
    .joined()
    return Data(
        """
        <html><body>
        <div id='profile_outer'>
          <select name='profile_set'><option value='1' selected='selected'>EhPanda</option></select>
          <input type='button' value='Create New'>
        </div>
        <form method='post'>
          <div class='optouter'><input name='uh' value='0' checked='checked'></div>
          <div class='optouter'><select name='co'><option value='' selected='selected'>Auto</option></select>
            <p>You appear to be browsing the site from Japan or use a VPN or proxy in this country</p></div>
          <div class='optouter'><input name='xr' value='0' checked='checked'></div>
          <div class='optouter'><input name='rx' value='0'></div>
          <div class='optouter'><input name='ry' value='0'></div>
          <div class='optouter'><input name='tl' value='0' checked='checked'></div>
          <div class='optouter'><input name='ar' value='3' checked='checked'></div>
          <div class='optouter'><input name='dm' value='0' checked='checked'></div>
          <div class='optouter'><input name='pp' value='0' checked='checked'></div>
          <div class='optouter'><input name='xn_0' type='checkbox'></div>
          <div class='optouter'><div id='catsel'>\(categories)</div></div>
          <div class='optouter'><div id='favsel'>\(favorites)</div></div>
          <div class='optouter'><input name='fs' value='1' checked='checked'></div>
          <div class='optouter'><input name='ru' value=''></div>
          <div class='optouter'><input name='ft' value='0'></div>
          <div class='optouter'><input name='wt' value='0'></div>
          <div class='optouter'><input name='tf' value='0' checked='checked'></div>
          <div class='optouter'><div id='xlasel'>\(languages)</div></div>
          <div class='optouter'><textarea name='xu'></textarea></div>
          <div class='optouter'><input name='rc' value='1' checked='checked'></div>
          <div class='optouter'><input name='lt' value='0' checked='checked'></div>
          <div class='optouter'><input name='ts' value='1' checked='checked'></div>
          <div class='optouter'><input name='tr' value='2' checked='checked'></div>
          <div class='optouter'><input name='tp' value='0'></div>
          <div class='optouter'><input name='vp' value='0'></div>
          <div class='optouter'><input name='cs' value='1' checked='checked'></div>
          <div class='optouter'><input name='sc' value='1' checked='checked'></div>
          <div class='optouter'><input name='tb' value='0' checked='checked'></div>
          <div class='optouter'><input name='pn' value='0' checked='checked'></div>
        </form>
        </body></html>
        """.utf8
    )
}

private final class NonHTTPResponseProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = URLResponse(
            url: request.url ?? Defaults.URL.exhentai,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
