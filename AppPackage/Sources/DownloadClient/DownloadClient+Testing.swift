import Foundation
import AppModels

#if DEBUG
extension DownloadCoordinator {
    public func testingInstallActiveTask(
        gid: String,
        task: Task<Void, Never>
    ) {
        activeTaskGeneration += 1
        activeGalleryID = gid
        activeTask = task
    }

    public func testingSetActiveGalleryID(_ gid: String?) {
        activeGalleryID = gid
    }

    public func testingSetQueuedGalleryIDs(_ gids: [String]) async {
        await queueStore.removeAll()
        for gid in gids {
            await queueStore.enqueue(gid)
        }
    }

    public func testingSetDownloadError(
        _ failure: DownloadFailure?,
        gid: String
    ) {
        downloadErrors[gid] = failure
    }

    public func testingSetFailedPageErrors(
        _ failures: [PageFailure],
        gid: String
    ) {
        failedPageErrors[gid] = Dictionary(
            uniqueKeysWithValues: failures.map { ($0.index, $0) }
        )
    }

    public func testingSetUpdatedGalleryIDs(_ gids: Set<String>) {
        updatedGalleryIDs = gids
    }

    public func testingHasActiveTask() -> Bool {
        activeTask != nil
    }

    public func testingActiveGalleryID() -> String? {
        activeGalleryID
    }

    public func testingHasBackgroundAssertion() -> Bool {
        backgroundAssertionToken != nil
    }
}
#endif
