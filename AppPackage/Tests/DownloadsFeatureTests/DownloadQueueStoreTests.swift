@testable import AppFeature
import DownloadClient
import Foundation
import Testing

struct DownloadQueueStoreTests {
    @Test
    func testEnqueueDeduplicatesAndPreservesOrder() async {
        let (store, rootURL) = makeStore()
        defer { removeTemporaryItem(at: rootURL) }

        await store.enqueue("123")
        await store.enqueue("456")
        await store.enqueue("123")

        #expect(store.gids == ["123", "456"])
    }

    @Test
    func testRemoveAndRemoveAllUpdateQueue() async {
        let (store, rootURL) = makeStore()
        defer { removeTemporaryItem(at: rootURL) }

        await store.enqueue("123")
        await store.enqueue("456")
        await store.remove("123")

        #expect(store.gids == ["456"])

        await store.removeAll()

        #expect(store.gids.isEmpty)
    }
}

private extension DownloadQueueStoreTests {
    func makeStore() -> (store: DownloadQueueStore, rootURL: URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appendingPathComponent(".queue.json")
        return (DownloadQueueStore(fileURL: fileURL), rootURL)
    }
}
