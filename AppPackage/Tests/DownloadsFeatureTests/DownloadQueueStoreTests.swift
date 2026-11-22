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

    @Test
    func testReorderMovesTheNamedGIDsWithinTheirOwnSlots() async {
        let (store, rootURL) = makeStore()
        defer { removeTemporaryItem(at: rootURL) }
        for gid in ["a", "b", "c", "d", "e"] {
            await store.enqueue(gid)
        }

        await store.reorder(["d", "b"])

        #expect(store.gids == ["a", "d", "c", "b", "e"])
    }

    @Test
    func testReorderIgnoresAbsentGIDsAndKeepsTheFirstOfADuplicate() async {
        let (store, rootURL) = makeStore()
        defer { removeTemporaryItem(at: rootURL) }
        for gid in ["a", "b", "c"] {
            await store.enqueue(gid)
        }

        await store.reorder(["c", "x", "a", "c"])

        #expect(store.gids == ["c", "b", "a"])
    }

    @Test
    func testAnEmptyReorderChangesNothing() async {
        let (store, rootURL) = makeStore()
        defer { removeTemporaryItem(at: rootURL) }
        for gid in ["a", "b", "c"] {
            await store.enqueue(gid)
        }

        await store.reorder([])

        #expect(store.gids == ["a", "b", "c"])
    }

    @Test
    func testASecondStoreOverTheSameFileReadsTheReorderedQueue() async {
        let (store, rootURL) = makeStore()
        defer { removeTemporaryItem(at: rootURL) }
        for gid in ["a", "b", "c"] {
            await store.enqueue(gid)
        }

        await store.reorder(["c", "a"])

        let reopened = DownloadQueueStore(fileURL: rootURL.appending(path: ".queue.json"))
        #expect(reopened.gids == ["c", "b", "a"])
    }
}

private extension DownloadQueueStoreTests {
    func makeStore() -> (store: DownloadQueueStore, rootURL: URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = rootURL.appending(path: ".queue.json")
        return (DownloadQueueStore(fileURL: fileURL), rootURL)
    }
}
