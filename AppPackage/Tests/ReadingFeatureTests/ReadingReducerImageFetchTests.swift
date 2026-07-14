import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Sharing
import Testing
@testable import ReadingFeature

@MainActor
struct ReadingReducerImageFetchTests {
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
            $setting.withLock { $0.galleryHost = .ehentai }
            let state = ReadingReducer.State(gallery: .preview)
            $setting.withLock { $0.galleryHost = .exhentai }
            return TestStore(
                initialState: state,
                reducer: ReadingReducer.init,
                withDependencies: {
                    $0.cookieClient = cookieClient
                    $0.defaultInMemoryStorage = inMemoryStorage
                }
            )
        }

        await store.send(.refetchNormalImageURLsDone(1, .ehentai, .success(([:], response)))) {
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
