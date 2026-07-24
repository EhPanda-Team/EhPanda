import AnalyticsClient
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
@testable import ReadingFeature
import Sharing
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct ReadingReducerImageFetchTests {
    @MainActor
    @Test
    func refetchResponseWritesSkipServerToOriginatingHost() async throws {
        let cookieClient = CookieClient.testing()
        let response = try #require(HTTPURLResponse(
            url: GalleryHost.ehentai.url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "skipserver=origin-server; Path=/s/; Secure"]
        ))
        let inMemoryStorage = InMemoryStorage()
        let store = withDependencies {
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock({ $0.galleryHost = .ehentai })
            let state = ReadingReducer.State(gallery: .preview)
            $setting.withLock({ $0.galleryHost = .exhentai })
            return TestStore(
                initialState: state,
                reducer: ReadingReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.cookieClient = cookieClient
                    $0.defaultInMemoryStorage = inMemoryStorage
                }
            )
        }

        await store.send(
            .refetchNormalImageURLsDone(
                index: 1, host: .ehentai, result: .success((imageURLs: [:], response: response))
            )
        ) {
            $0.imageURLLoadingStates[1] = .failed(.notFound)
        }
        await store.finish()

        let ehentaiSkipServerURL = GalleryHost.ehentai.url.appendingPathComponent("s/")
        let exhentaiSkipServerURL = GalleryHost.exhentai.url.appendingPathComponent("s/")
        #expect(skipServerValue(in: cookieClient, url: ehentaiSkipServerURL) == "origin-server")
        #expect(skipServerValue(in: cookieClient, url: exhentaiSkipServerURL) == nil)
    }
}

private func skipServerValue(in client: CookieClient, url: URL) -> String? {
    client.cookies(for: url).first { $0.name == "skipserver" }?.value
}
