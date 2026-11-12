import ComposableArchitecture
@testable import DetailFeature
import FileClient
import Foundation
import HapticsClient
import Testing

struct TorrentsFeatureTests {
    @MainActor
    @Test
    func presentsTheShareSheetAfterWritingTheTorrent() async {
        let data = Data("torrent bytes".utf8)
        let expectedURL = URL.cachesDirectory.appending(component: "test-hash.torrent")
        let (writes, writeStarted) = AsyncStream<Void>.makeStream()
        let (results, writeCompleted) = AsyncStream<Bool>.makeStream()
        defer {
            writeStarted.finish()
            writeCompleted.finish()
        }
        let store = TestStore(initialState: TorrentsReducer.State(), reducer: TorrentsReducer.init) {
            $0.hapticsClient = .noop
            $0.fileClient.createFile = { path, contents in
                #expect(path == expectedURL.path(percentEncoded: false))
                #expect(contents == data)
                writeStarted.yield()
                var iterator = results.makeAsyncIterator()
                return await iterator.next() ?? false
            }
        }

        await store.send(.presentTorrentActivity(hash: "test-hash", data: data))
        var iterator = writes.makeAsyncIterator()
        _ = await iterator.next()
        #expect(store.state.destination == nil)
        writeCompleted.yield(true)
        await store.receive(.presentShare(expectedURL)) {
            $0.destination = .share(expectedURL)
        }
        await store.finish()
    }

    @MainActor
    @Test
    func aFailedWriteDoesNotPresentAShareSheet() async {
        let store = TestStore(initialState: TorrentsReducer.State(), reducer: TorrentsReducer.init) {
            $0.fileClient.createFile = { _, _ in false }
        }

        await store.send(.presentTorrentActivity(hash: "test-hash", data: Data("torrent bytes".utf8)))
        await store.finish()
        #expect(store.state.destination == nil)
    }
}
