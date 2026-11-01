import AppModels
import AppTools
import Foundation
import Kanna
@testable import NetworkingFeature
import Testing

// Wave 0 request-layer lock for CONC-01 (D-05/D-06). These fixtures freeze routine request
// assembly, parsing, retry scope, multi-step behavior, and AppError mapping before Combine is
// replaced. Every request uses a token-isolated stubbed session, so this suite never opens a socket.
@Suite
struct RoutineRequestBaselineTests {
    // MARK: Routine request assembly and parsing

    /// GreetingRequest stays a body-less GET and parses the deterministic event-pane rewards.
    @Test
    func greetingRequestLocksAssemblyParsingAndSuccessfulAttemptCount() async throws {
        let url = Defaults.URL.news
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .greetingFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let greeting = try await capture { () async throws(AppError) -> Greeting in
            try await GreetingRequest(urlSession: session).response()
        }
        .get()
        let received = try #require(handle.receivedRequests.first)

        #expect(received.url == url)
        #expect(received.httpMethod == "GET")
        #expect(received.httpBody == nil)
        #expect(greeting.gainedEXP == 30)
        #expect(greeting.gainedCredits == 329)
        #expect(greeting.gainedGP == nil)
        #expect(greeting.gainedHath == nil)
        #expect(handle.attempts(for: url) == 1)
    }

    /// UserInfoRequest preserves its query URL and maps the profile name and avatar.
    @Test
    func userInfoRequestLocksAssemblyAndParsing() async throws {
        let uid = "12345"
        let url = URLUtil.userInfo(uid: uid)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .userInfoFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let user = try await capture { () async throws(AppError) -> User in
            try await UserInfoRequest(uid: uid, urlSession: session).response()
        }
        .get()
        let received = try #require(handle.receivedRequests.first)

        #expect(received.url == url)
        #expect(received.httpMethod == "GET")
        #expect(received.httpBody == nil)
        #expect(user.displayName == "Baseline User")
        #expect(user.avatarURL == URL(string: "https://forums.e-hentai.org/uploads/baseline.png"))
    }

    /// FavoriteCategoriesRequest stays a body-less GET and preserves category indexes and names.
    @Test
    func favoriteCategoriesRequestLocksAssemblyAndParsing() async throws {
        let host = GalleryHost.ehentai
        let url = Defaults.URL.uConfig(host: host)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .favoriteCategoriesFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let categories = try await capture { () async throws(AppError) -> [Int: String] in
            try await FavoriteCategoriesRequest(host: host, urlSession: session).response()
        }
        .get()
        let received = try #require(handle.receivedRequests.first)

        #expect(received.url == url)
        #expect(received.httpMethod == "GET")
        #expect(received.httpBody == nil)
        #expect(categories == [0: "Favorites Zero", 3: "Baseline Three"])
    }

    // MARK: Retry policy

    /// The Combine retry(3) contract performs four total transport attempts before mapping failure.
    @Test
    func greetingPersistentTransportFailureRetriesFourTimes() async {
        let url = Defaults.URL.news
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.transportFailure(.timedOut)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = await capture { () async throws(AppError) -> Greeting in
            try await GreetingRequest(urlSession: session).response()
        }

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: url) == 4)
    }

    // MARK: Tag translator chain

    /// A changed digest fetches metadata once, then downloads the exact payload once.
    @Test
    func tagTranslatorChangedDigestDownloadsPayload() async throws {
        let apiURL = URLUtil.githubAPI(repoName: TranslatableLanguage.repoName)
        let downloadURL = try #require(URL(string: Data.englishDatabaseURL))
        let payload = Data(#"{"baseline":true}"#.utf8)
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                apiURL: [.http(status: 200, data: .tagDatabaseReleaseFixture)],
                downloadURL: [.http(status: 200, data: payload)]
            ])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = try await capture { () async throws(AppError) -> TagTranslatorPayload in
            try await TagTranslatorRequest(
                language: .english,
                currentDigest: "sha256:previous",
                urlSession: session
            )
            .response()
        }
        .get()

        #expect(result == TagTranslatorPayload(data: payload, digest: "sha256:english"))
        #expect(handle.attempts(for: apiURL) == 1)
        #expect(handle.attempts(for: downloadURL) == 1)
    }

    /// With no table loaded, such as after the system purged the cache, the current asset downloads.
    @Test
    func tagTranslatorWithNoLoadedTableDownloadsPayload() async throws {
        let apiURL = URLUtil.githubAPI(repoName: TranslatableLanguage.repoName)
        let downloadURL = try #require(URL(string: Data.englishDatabaseURL))
        let payload = Data(#"{"baseline":true}"#.utf8)
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                apiURL: [.http(status: 200, data: .tagDatabaseReleaseFixture)],
                downloadURL: [.http(status: 200, data: payload)]
            ])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = try await capture { () async throws(AppError) -> TagTranslatorPayload in
            try await TagTranslatorRequest(language: .english, currentDigest: nil, urlSession: session).response()
        }
        .get()

        #expect(result.digest == "sha256:english")
        #expect(handle.attempts(for: downloadURL) == 1)
    }

    /// A matching digest exits with noUpdates, whatever changed for the release's other languages.
    @Test
    func tagTranslatorMatchingDigestSkipsDownload() async throws {
        let apiURL = URLUtil.githubAPI(repoName: TranslatableLanguage.repoName)
        let downloadURL = try #require(URL(string: Data.englishDatabaseURL))
        let (session, handle) = makeStubbedSession(
            script: StubScript([apiURL: [.http(status: 200, data: .tagDatabaseReleaseFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = await capture { () async throws(AppError) -> TagTranslatorPayload in
            try await TagTranslatorRequest(
                language: .english,
                currentDigest: "sha256:english",
                urlSession: session
            )
            .response()
        }

        #expect(result == .failure(.noUpdates))
        #expect(handle.attempts(for: apiURL) == 1)
        #expect(handle.attempts(for: downloadURL) == 0)
    }

    /// Malformed release metadata maps to parseFailed and never reaches the download step.
    @Test
    func tagTranslatorMalformedMetadataMapsParseFailure() async throws {
        let apiURL = URLUtil.githubAPI(repoName: TranslatableLanguage.repoName)
        let downloadURL = try #require(URL(string: Data.englishDatabaseURL))
        let (session, handle) = makeStubbedSession(
            script: StubScript([apiURL: [.http(status: 200, data: Data("{}".utf8))]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = await capture { () async throws(AppError) -> TagTranslatorPayload in
            try await TagTranslatorRequest(language: .english, currentDigest: nil, urlSession: session).response()
        }

        #expect(result == .failure(.parseFailed))
        #expect(handle.attempts(for: apiURL) == 1)
        #expect(handle.attempts(for: downloadURL) == 0)
    }

    /// A release missing the language's asset, or its digest, maps to parseFailed without downloading.
    @Test(arguments: [TranslatableLanguage.korean, .japanese])
    func tagTranslatorUnusableAssetMapsParseFailure(language: TranslatableLanguage) async throws {
        let apiURL = URLUtil.githubAPI(repoName: TranslatableLanguage.repoName)
        let (session, handle) = makeStubbedSession(
            script: StubScript([apiURL: [.http(status: 200, data: .tagDatabaseReleaseFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = await capture { () async throws(AppError) -> TagTranslatorPayload in
            try await TagTranslatorRequest(language: language, currentDigest: nil, urlSession: session).response()
        }

        #expect(result == .failure(.parseFailed))
    }

    /// The second fetch remains un-retried even though the metadata fetch uses the generic retry policy.
    @Test
    func tagTranslatorDownloadTransportFailureIsNotRetried() async throws {
        let apiURL = URLUtil.githubAPI(repoName: TranslatableLanguage.repoName)
        let downloadURL = try #require(URL(string: Data.englishDatabaseURL))
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                apiURL: [.http(status: 200, data: .tagDatabaseReleaseFixture)],
                downloadURL: [.transportFailure(.timedOut)]
            ])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = await capture { () async throws(AppError) -> TagTranslatorPayload in
            try await TagTranslatorRequest(language: .english, currentDigest: nil, urlSession: session).response()
        }

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: apiURL) == 1)
        #expect(handle.attempts(for: downloadURL) == 1)
    }

    // MARK: Error mapping

    /// mapAppError preserves the complete pre-migration classification table.
    @Test
    func mapAppErrorTableIsFrozen() {
        let request = GreetingRequest()
        let decodingError = DecodingError.typeMismatch(
            Int.self,
            .init(codingPath: [], debugDescription: "Characterization fixture")
        )

        #expect(request.mapAppError(error: URLError(.notConnectedToInternet)) == .networkingFailed)
        #expect(request.mapAppError(error: ParseError.EncodingMismatch) == .parseFailed)
        #expect(request.mapAppError(error: decodingError) == .parseFailed)
        #expect(request.mapAppError(error: AppError.quotaExceeded) == .quotaExceeded)
        #expect(request.mapAppError(error: RoutineBaselineError.arbitrary) == .unknown)
    }

    /// Parser failure on a ban page preserves the parsed server error instead of flattening it.
    @Test
    func favoriteCategoriesServerTextMapsIPBan() async {
        let host = GalleryHost.ehentai
        let url = Defaults.URL.uConfig(host: host)
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: .ipBanFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let result = await capture { () async throws(AppError) -> [Int: String] in
            try await FavoriteCategoriesRequest(host: host, urlSession: session).response()
        }

        #expect(result == .failure(.ipBanned(.minutes(minutes: 59, seconds: 48))))
        #expect(handle.attempts(for: url) == 1)
    }
}

private enum RoutineBaselineError: Error {
    case arbitrary
}

private extension Data {
    static let greetingFixture = Data(
        """
        <html><body><div id="eventpane">
        <p>You gain <strong>30</strong> EXP and <strong>329</strong> Credits</p>
        </div></body></html>
        """.utf8
    )

    static let userInfoFixture = Data(
        """
        <html><body><table class="ipbtable"><tr><td>
        <div id="profilename">Baseline User</div>
        <img src="https://forums.e-hentai.org/uploads/baseline.png">
        </td></tr></table></body></html>
        """.utf8
    )

    static let favoriteCategoriesFixture = Data(
        """
        <html><body><div id="favsel">
        <input name="favorite_0" value="Favorites Zero">
        <input name="favorite_3" value="Baseline Three">
        </div></body></html>
        """.utf8
    )

    static let englishDatabaseURL = "https://example.com/db-1/en.json"

    // Japanese has no digest yet, and Korean has no asset at all.
    static let tagDatabaseReleaseFixture = Data(
        #"""
        {"assets":[
          {"name":"en.json","digest":"sha256:english","browser_download_url":"\#(englishDatabaseURL)"},
          {"name":"ja.json","digest":null,"browser_download_url":"https://example.com/ja.json"},
          {"name":"sources.json","digest":"sha256:sources","browser_download_url":"https://example.com/sources.json"}
        ]}
        """#.utf8
    )

    static let ipBanFixture = Data(
        """
        Your IP address has been temporarily banned for excessive pageloads which indicates that
        you are using automated mirroring/harvesting software. The ban expires in 59 minutes and 48 seconds
        """.utf8
    )
}
