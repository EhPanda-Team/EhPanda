import Foundation
import Testing
@testable import EhPanda

struct DownloadBackgroundTaskStoreTests {
    @Test
    func testRecordsPersistByTaskIdentifier() async {
        let fixture = makeStore()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        await fixture.store.record(taskIdentifier: 41, gid: "123", pageIndex: 7)

        let reloadedStore = DownloadBackgroundTaskStore(fileURL: fixture.fileURL)
        #expect(await reloadedStore.record(taskIdentifier: 41) == .init(gid: "123", pageIndex: 7))
        #expect(await reloadedStore.records(for: "123") == [41: .init(gid: "123", pageIndex: 7)])
    }

    @Test
    func testRemoveSingleRecord() async {
        let fixture = makeStore()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        await fixture.store.record(taskIdentifier: 41, gid: "123", pageIndex: 7)
        await fixture.store.record(taskIdentifier: 42, gid: "456", pageIndex: 8)

        let removed = await fixture.store.remove(taskIdentifier: 41)

        #expect(removed == .init(gid: "123", pageIndex: 7))
        #expect(await fixture.store.record(taskIdentifier: 41) == nil)
        #expect(await fixture.store.record(taskIdentifier: 42) == .init(gid: "456", pageIndex: 8))
    }

    @Test
    func testRemoveAllForGallery() async {
        let fixture = makeStore()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        await fixture.store.record(taskIdentifier: 41, gid: "123", pageIndex: 7)
        await fixture.store.record(taskIdentifier: 42, gid: "123", pageIndex: 8)
        await fixture.store.record(taskIdentifier: 43, gid: "456", pageIndex: 9)

        await fixture.store.removeAll(for: "123")

        #expect(await fixture.store.records(for: "123").isEmpty)
        #expect(await fixture.store.record(taskIdentifier: 43) == .init(gid: "456", pageIndex: 9))
    }

    private struct StoreFixture {
        let store: DownloadBackgroundTaskStore
        let rootURL: URL
        let fileURL: URL
    }

    private func makeStore() -> StoreFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = rootURL.appendingPathComponent(".background-tasks.json")
        return .init(
            store: DownloadBackgroundTaskStore(fileURL: fileURL),
            rootURL: rootURL,
            fileURL: fileURL
        )
    }
}
