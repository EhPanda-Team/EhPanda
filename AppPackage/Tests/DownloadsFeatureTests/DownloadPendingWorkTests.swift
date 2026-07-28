import DownloadClient
import Foundation
import Testing

/// Covers the coordinator's schedulable-work predicate against real queue state, so the
/// predicate cannot silently drift from what the scheduler treats as schedulable.
struct DownloadPendingWorkTests: DownloadFeatureTestCase {
    @Test
    func testHasPendingWorkReflectsQueueState() async throws {
        let gid = "210001"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        await manager.reloadDownloadIndex()
        #expect(!(await manager.hasPendingWork()))

        try writeQueuedManifest(storage: storage, gid: gid, title: "Queued")
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])
        #expect(await manager.hasPendingWork())
    }
}

// MARK: - Helpers

private extension DownloadPendingWorkTests {
    func writeQueuedManifest(
        storage: DownloadStore,
        gid: String,
        title: String
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] \(title)")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: title),
            folderURL: folderURL
        )
    }
}
