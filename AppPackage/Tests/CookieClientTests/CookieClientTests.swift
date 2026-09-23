import AppModels
import CookieClient
import Foundation
import Testing

struct CookieClientTests {
    @Test
    func preparesAllLaunchCookiesBeforeReturning() async throws {
        let client = CookieClient.testing()
        let siblingURL = try #require(GalleryHost.exhentai.cookieURLs.last)
        seedCredentials(in: client, for: .exhentai, igneous: "igneous-fixture")
        for url in [GalleryHost.exhentai.url, siblingURL] {
            client.setOrEditCookie(for: url, key: "yay", value: "stale")
        }

        await client.prepareForLaunch()

        for url in [GalleryHost.ehentai.url, GalleryHost.exhentai.url, siblingURL] {
            #expect(cookieValue(in: client, url: url, name: CookieName.memberID) == "member-fixture")
            #expect(cookieValue(in: client, url: url, name: CookieName.passHash) == "pass-fixture")
        }
        for url in [GalleryHost.exhentai.url, siblingURL] {
            #expect(cookieValue(in: client, url: url, name: "yay").isEmpty)
            #expect(cookieValue(in: client, url: url, name: CookieName.igneous) == "igneous-fixture")
        }
        for url in [GalleryHost.ehentai.url, GalleryHost.exhentai.url] {
            #expect(cookieValue(in: client, url: url, name: "nw") == "1")
        }
    }

    @Test
    func recognizesEhentaiCredentialsWithoutExhentaiCredentials() {
        let client = CookieClient.testing()
        seedCredentials(in: client, for: .ehentai)

        #expect(client.didLogin)
    }

    @Test
    func recognizesExhentaiCredentialsWithIgneous() {
        let client = CookieClient.testing()
        seedCredentials(in: client, for: .exhentai, igneous: "igneous-fixture")

        #expect(client.didLogin)
    }

    @Test
    func rejectsExhentaiCredentialsWithMysteryIgneous() {
        let client = CookieClient.testing()
        seedCredentials(in: client, for: .exhentai, igneous: CookieName.mystery)

        #expect(client.didLogin == false)
    }

    @Test
    func rejectsExhentaiCredentialsWithoutIgneous() {
        let client = CookieClient.testing()
        seedCredentials(in: client, for: .exhentai)

        #expect(client.didLogin == false)
    }

    @Test
    func rejectsEmptyCookieStore() {
        #expect(CookieClient.testing().didLogin == false)
    }

    @Test
    func rejectsExpiredCredentials() throws {
        let storage = makeCookieStorage()
        let client = CookieClient.live(cookieStorage: storage)
        defer { client.clearAll() }
        let expiredDate = Date(timeIntervalSince1970: 1)
        storage.setCookie(try makeCookie(
            url: GalleryHost.ehentai.url,
            name: CookieName.memberID,
            value: "member-fixture",
            expiresDate: expiredDate
        ))
        storage.setCookie(try makeCookie(
            url: GalleryHost.ehentai.url,
            name: CookieName.passHash,
            value: "pass-fixture",
            expiresDate: expiredDate
        ))

        #expect(client.didLogin == false)
    }

    @Test
    func parsesCredentialResponseCookiesByHost() throws {
        let storage = makeCookieStorage()
        let client = CookieClient.live(cookieStorage: storage)
        defer { client.clearAll() }
        let response = try makeResponse(
            url: GalleryHost.ehentai.url,
            setCookie: "ipb_member_id=member-fixture; Path=/, "
                + "ipb_pass_hash=pass-fixture; Path=/, igneous=igneous-fixture; Path=/"
        )

        client.setCredentials(response: response)

        #expect(cookieValue(in: client, url: GalleryHost.ehentai.url, name: CookieName.memberID) == "member-fixture")
        #expect(cookieValue(in: client, url: GalleryHost.ehentai.url, name: CookieName.passHash) == "pass-fixture")
        #expect(cookieValue(in: client, url: GalleryHost.ehentai.url, name: CookieName.igneous).isEmpty)
        #expect(cookieValue(in: client, url: GalleryHost.exhentai.url, name: CookieName.memberID) == "member-fixture")
        #expect(cookieValue(in: client, url: GalleryHost.exhentai.url, name: CookieName.passHash) == "pass-fixture")
        #expect(cookieValue(in: client, url: GalleryHost.exhentai.url, name: CookieName.igneous) == "igneous-fixture")
    }

    @Test
    func parsesSkipServerResponseForSelectedHost() throws {
        let storage = makeCookieStorage()
        let client = CookieClient.live(cookieStorage: storage)
        defer { client.clearAll() }
        let response = try makeResponse(
            url: GalleryHost.exhentai.url,
            setCookie: "skipserver=server-fixture; Path=/s/; Secure"
        )

        client.setSkipServer(response: response, host: .exhentai)

        let skipServerURL = GalleryHost.exhentai.url.appendingPathComponent("s/")
        let cookie = try #require(
            client.cookies(for: skipServerURL).first(where: { $0.name == CookieName.skipServer })
        )
        #expect(cookie.value == "server-fixture")
        #expect(cookie.path == "/s/")
        let ehentaiSkipServerURL = GalleryHost.ehentai.url.appendingPathComponent("s/")
        let ehentaiCookies = client.cookies(for: ehentaiSkipServerURL)
        #expect(ehentaiCookies.contains(where: { $0.name == CookieName.skipServer }) == false)
    }

    @Test
    func editingCookiePreservesEachMatchingScopeAndAttributes() throws {
        let storage = makeCookieStorage()
        let client = CookieClient.live(cookieStorage: storage)
        defer { client.clearAll() }
        let url = GalleryHost.ehentai.url.appendingPathComponent("s/page")
        let domain = try #require(url.host)
        let expiry = Date(timeIntervalSinceNow: 86_400)
        for path in ["/", "/s/"] {
            storage.setCookie(try #require(HTTPCookie(properties: [
                .domain: domain,
                .path: path,
                .name: CookieName.memberID,
                .value: "old-member",
                .expires: expiry,
                .secure: "TRUE"
            ])))
        }
        client.setOrEditCookie(for: url, key: CookieName.passHash, value: "unchanged-pass")
        let originals = client.cookies(for: url).filter({ $0.name == CookieName.memberID })

        client.editCookie(for: url, key: CookieName.memberID, value: "new-member")

        let edited = client.cookies(for: url).filter({ $0.name == CookieName.memberID })
        #expect(Set(edited.map(\.path)) == ["/", "/s/"])
        for cookie in edited {
            let original = try #require(originals.first(where: { $0.path == cookie.path }))
            #expect(cookie.value == "new-member")
            #expect(cookie.domain == domain)
            #expect(cookie.expiresDate == original.expiresDate)
            #expect(cookie.isSecure)
        }
        #expect(cookieValue(in: client, url: url, name: CookieName.passHash) == "unchanged-pass")
    }

    @Test
    func syncsExhentaiCookiesWithoutClobberingSourceHost() throws {
        let client = CookieClient.testing()
        let sourceURL = GalleryHost.exhentai.url
        let siblingURL = try #require(GalleryHost.exhentai.cookieURLs.last)
        seedCredentials(in: client, for: .exhentai, igneous: "source-igneous")
        client.setOrEditCookie(for: siblingURL, key: CookieName.memberID, value: "sibling-member")
        client.setOrEditCookie(for: siblingURL, key: CookieName.passHash, value: "sibling-pass")
        client.setOrEditCookie(for: siblingURL, key: CookieName.igneous, value: "sibling-igneous")

        client.syncExCookies()

        #expect(cookieValue(in: client, url: sourceURL, name: CookieName.memberID) == "member-fixture")
        #expect(cookieValue(in: client, url: sourceURL, name: CookieName.passHash) == "pass-fixture")
        #expect(cookieValue(in: client, url: sourceURL, name: CookieName.igneous) == "source-igneous")
        #expect(cookieValue(in: client, url: siblingURL, name: CookieName.memberID) == "member-fixture")
        #expect(cookieValue(in: client, url: siblingURL, name: CookieName.passHash) == "pass-fixture")
        #expect(cookieValue(in: client, url: siblingURL, name: CookieName.igneous) == "source-igneous")
    }

    @Test
    func backfillsCredentialsInEitherDirection() {
        let ehentaiSource = CookieClient.testing()
        seedCredentials(in: ehentaiSource, for: .ehentai)

        ehentaiSource.fulfillAnotherHostField()

        #expect(cookieValue(
            in: ehentaiSource,
            url: GalleryHost.exhentai.url,
            name: CookieName.memberID
        ) == "member-fixture")
        #expect(cookieValue(
            in: ehentaiSource,
            url: GalleryHost.exhentai.url,
            name: CookieName.passHash
        ) == "pass-fixture")

        let exhentaiSource = CookieClient.testing()
        seedCredentials(in: exhentaiSource, for: .exhentai)

        exhentaiSource.fulfillAnotherHostField()

        #expect(cookieValue(
            in: exhentaiSource,
            url: GalleryHost.ehentai.url,
            name: CookieName.memberID
        ) == "member-fixture")
        #expect(cookieValue(
            in: exhentaiSource,
            url: GalleryHost.ehentai.url,
            name: CookieName.passHash
        ) == "pass-fixture")
    }

    @Test
    func testingClientStreamsElementOnMutation() async {
        let client = CookieClient.testing()
        var iterator = client.cookiesDidChange().makeAsyncIterator()

        seedCredentials(in: client, for: .ehentai)

        #expect(await iterator.next() != nil)
    }

    @Test
    func liveClientStreamsElementOnCookieChange() async {
        let storage = makeCookieStorage()
        let client = CookieClient.live(cookieStorage: storage)
        defer { client.clearAll() }
        let stream = client.cookiesDidChange()

        // The stream's notification observer registers asynchronously, so keep mutating until an
        // element lands; the mutator doubles as the timeout so a regression fails instead of hanging.
        let received = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await stream.first(where: { _ in true }) != nil
            }
            group.addTask {
                for attempt in 0..<200 {
                    client.setOrEditCookie(
                        for: GalleryHost.ehentai.url,
                        key: CookieName.memberID,
                        value: "member-\(attempt)"
                    )
                    do {
                        try await Task.sleep(for: .milliseconds(10))
                    } catch {
                        // Cancellation is the designed exit: the sibling task cancels the group as
                        // soon as an element lands, so stop mutating rather than unwind.
                        return false
                    }
                }
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        #expect(received)
    }

    @Test
    func importsAutomationCredentialsAcrossCookieHosts() throws {
        let client = CookieClient.testing()
        let ehentaiURL = GalleryHost.ehentai.url
        let exhentaiURL = GalleryHost.exhentai.url
        let siblingURL = try #require(GalleryHost.exhentai.cookieURLs.last)

        client.importAutomationCookies(
            memberID: "member-fixture",
            passHash: "pass-fixture",
            igneous: "igneous-fixture"
        )

        for url in [ehentaiURL, exhentaiURL, siblingURL] {
            #expect(cookieValue(in: client, url: url, name: CookieName.memberID) == "member-fixture")
            #expect(cookieValue(in: client, url: url, name: CookieName.passHash) == "pass-fixture")
        }
        #expect(cookieValue(in: client, url: ehentaiURL, name: CookieName.igneous).isEmpty)
        #expect(cookieValue(in: client, url: exhentaiURL, name: CookieName.igneous) == "igneous-fixture")
        #expect(cookieValue(in: client, url: siblingURL, name: CookieName.igneous) == "igneous-fixture")
    }
}

private enum CookieName {
    static let igneous = "igneous"
    static let memberID = "ipb_member_id"
    static let mystery = "mystery"
    static let passHash = "ipb_pass_hash"
    static let skipServer = "skipserver"
}

private func makeCookieStorage() -> HTTPCookieStorage {
    HTTPCookieStorage.sharedCookieStorage(
        forGroupContainerIdentifier: "CookieClientTests-\(UUID().uuidString)"
    )
}

private func seedCredentials(
    in client: CookieClient,
    for host: GalleryHost,
    igneous: String? = nil
) {
    client.setOrEditCookie(for: host.url, key: CookieName.memberID, value: "member-fixture")
    client.setOrEditCookie(for: host.url, key: CookieName.passHash, value: "pass-fixture")
    if let igneous {
        client.setOrEditCookie(for: host.url, key: CookieName.igneous, value: igneous)
    }
}

private func cookieValue(in client: CookieClient, url: URL, name: String) -> String {
    client.cookies(for: url).first(where: { $0.name == name })?.value ?? ""
}

private func makeCookie(
    url: URL,
    name: String,
    value: String,
    expiresDate: Date
) throws -> HTTPCookie {
    let domain = try #require(url.host)
    return try #require(HTTPCookie(properties: [
        .domain: domain,
        .path: "/",
        .name: name,
        .value: value,
        .expires: expiresDate
    ]))
}

private func makeResponse(url: URL, setCookie: String) throws -> HTTPURLResponse {
    try #require(HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: "HTTP/1.1",
        headerFields: ["Set-Cookie": setCookie]
    ))
}
