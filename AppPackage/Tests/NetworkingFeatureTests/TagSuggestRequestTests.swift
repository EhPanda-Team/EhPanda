import AppModels
import Foundation
import NetworkingFeature
import Testing

// The tag suggestion request (G-1 and G-4 of quick 261126-wzg) through a token-isolated URLProtocol session, so it
// never opens a socket and never reaches the site. The answers are in the shapes probed on 2026-11-26, with invented
// ids and tags.
struct TagSuggestRequestTests {
    private static let ehentaiAPIURL = URL(string: "https://e-hentai.org/api.php")
    private static let exhentaiAPIURL = URL(string: "https://exhentai.org/api.php")
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )

    // The question is the method and the query's text, nothing else, posted as JSON to the selected host's API.
    @Test(arguments: [GalleryHost.ehentai, .exhentai])
    func aQuestionPostsTheQuerysTextToTheHostsAPI(host: GalleryHost) async throws {
        let url = try #require(host == .ehentai ? Self.ehentaiAPIURL : Self.exhentaiAPIURL)
        let answer = Data(#"{"tags":{"9001":{"ns":"female","tn":"sample glasses"}}}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: answer)]]))
        defer { cleanUp(session: session, handle: handle) }
        let query = try #require(TagSuggestQuery("f:sample gl"))

        let suggestions = try await suggest(query, host: host, session: session).get()

        #expect(suggestions == [Self.glasses])
        #expect(handle.receivedRequests.count == 1)
        let request = try #require(handle.receivedRequests.first)
        #expect(request.httpMethod == "POST")
        expectEquivalentURL(request.url, url)
        let body = try #require(request.httpBody)
        #expect(try JSONDecoder().decode([String: String].self, from: body) == [
            "method": "tagsuggest", "text": "female:sample gl"
        ])
    }

    @Test
    func anAnswerWithoutAMatchIsNoSuggestion() async throws {
        let url = try #require(Self.ehentaiAPIURL)
        let answer = Data(#"{"tags":[]}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: answer)]]))
        defer { cleanUp(session: session, handle: handle) }
        let query = try #require(TagSuggestQuery("sample gl"))

        let suggestions = try await suggest(query, host: .ehentai, session: session).get()

        #expect(suggestions.isEmpty)
    }

    // A refusal fails the question; the editor shows no rows for a failure, and no alert.
    @Test
    func aRefusalFailsTheQuestion() async throws {
        let url = try #require(Self.ehentaiAPIURL)
        let answer = Data(#"{"error":"Sample refusal"}"#.utf8)
        let (session, handle) = makeStubbedSession(script: StubScript([url: [.http(status: 200, data: answer)]]))
        defer { cleanUp(session: session, handle: handle) }
        let query = try #require(TagSuggestQuery("sample gl"))

        let result = await suggest(query, host: .ehentai, session: session)

        #expect(result == .failure(.unknown))
    }

    private func suggest(
        _ query: TagSuggestQuery,
        host: GalleryHost,
        session: URLSession
    ) async -> Result<[SiteTagSuggestion], AppError> {
        await capture { () async throws(AppError) -> [SiteTagSuggestion] in
            try await TagSuggestRequest(host: host, query: query, urlSession: session).response()
        }
    }

    private func cleanUp(session: URLSession, handle: StubHandle) {
        session.invalidateAndCancel()
        handle.tearDown()
    }
}
