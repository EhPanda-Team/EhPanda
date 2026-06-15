//
//  DownloadClient+Testing.swift
//  EhPanda
//

import Foundation

#if DEBUG
extension DownloadCoordinator {
    func testingInstallActiveTask(
        gid: String,
        task: Task<Void, Never>
    ) {
        activeTaskGeneration += 1
        activeGalleryID = gid
        activeTask = task
    }

    func testingSetActiveGalleryID(_ gid: String?) {
        activeGalleryID = gid
    }

    func testingSetQueuedGalleryIDs(_ gids: [String]) async {
        await queueStore.removeAll()
        for gid in gids {
            await queueStore.enqueue(gid)
        }
    }

    func testingSetDownloadError(
        _ failure: DownloadFailure?,
        gid: String
    ) {
        downloadErrors[gid] = failure
    }

    func testingSetFailedPageErrors(
        _ failures: [PageFailure],
        gid: String
    ) {
        failedPageErrors[gid] = Dictionary(
            uniqueKeysWithValues: failures.map { ($0.index, $0) }
        )
    }

    func testingSetUpdatedGalleryIDs(_ gids: Set<String>) {
        updatedGalleryIDs = gids
    }

    func testingHasActiveTask() -> Bool {
        activeTask != nil
    }

    func testingActiveGalleryID() -> String? {
        activeGalleryID
    }
}
#endif
