import AppModels
import CookieClient
import Foundation
import Testing

struct CookieClientTests {
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
            client.cookies(for: skipServerURL).first { $0.name == CookieName.skipServer }
        )
        #expect(cookie.value == "server-fixture")
        #expect(cookie.path == "/s/")
        let ehentaiSkipServerURL = GalleryHost.ehentai.url.appendingPathComponent("s/")
        #expect(client.cookies(for: ehentaiSkipServerURL).contains { $0.name == CookieName.skipServer } == false)
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
    client.cookies(for: url).first { $0.name == name }?.value ?? ""
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
