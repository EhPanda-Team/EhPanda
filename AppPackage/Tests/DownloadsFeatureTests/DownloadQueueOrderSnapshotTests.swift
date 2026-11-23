import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing
import TestingSupport

/// A-1: within the waiting group the coordinator's snapshot lists galleries in the persisted queue's run order, the
/// next to start first, while the active gallery stays on top and every other group keeps status priority, then
/// newest folder first. Every consumer of the snapshot (the list, the grid, a single fetch) reads the same order.
@Suite(.isolatedAppStorage)
struct DownloadQueueOrderSnapshotTests: DownloadFeatureTestCase {
    private static let active = SessionGallery(gid: "261123100", title: "Active", pageCount: 4)
    private static let first = SessionGallery(gid: "261123101", title: "First", pageCount: 4)
    private static let second = SessionGallery(gid: "261123102", title: "Second", pageCount: 4)
    private static let third = SessionGallery(gid: "261123103", title: "Third", pageCount: 4)
    private static let paused = SessionGallery(gid: "261123104", title: "Paused", pageCount: 4, completedPageCount: 1)
    private static let otherPaused = SessionGallery(
        gid: "261123105",
        title: "OtherPaused",
        pageCount: 4,
        completedPageCount: 1
    )
    private static let complete = SessionGallery(
        gid: "261123106",
        title: "Complete",
        pageCount: 4,
        completedPageCount: 4
    )

    /// Dates every folder, so the folder order runs against the queue order, then reloads the index.
    private func makeFixture(gate: QueueRunGate) async throws -> SessionFixture {
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                Self.active, Self.first, Self.second, Self.third, Self.paused, Self.otherPaused, Self.complete
            ],
            queuedGIDs: [Self.active, Self.first, Self.second, Self.third].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner
        )
        let dates: [(SessionGallery, TimeInterval)] = [
            (Self.active, 500), (Self.first, 1000), (Self.second, 2000), (Self.third, 3000),
            (Self.paused, 4000), (Self.otherPaused, 4500), (Self.complete, 5000)
        ]
        for (gallery, seconds) in dates {
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: seconds)],
                ofItemAtPath: galleryFolderURL(for: gallery, in: fixture).path(percentEncoded: false)
            )
        }
        await fixture.manager.reloadDownloadIndex()
        return fixture
    }

    @Test
    func testTheWaitingGroupFollowsTheQueueRatherThanFolderDates() async throws {
        let gate = QueueRunGate()
        let fixture = try await makeFixture(gate: gate)
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let firstDate = try #require(await manager.fetchDownload(gid: Self.first.gid)?.lastDownloadedDate)
        let thirdDate = try #require(await manager.fetchDownload(gid: Self.third.gid)?.lastDownloadedDate)
        #expect(thirdDate > firstDate)

        let beforeScheduling = await manager.indexedDownloads()
        #expect(beforeScheduling.map(\.gid) == [
            Self.active, Self.first, Self.second, Self.third, Self.otherPaused, Self.paused, Self.complete
        ].map(\.gid))
        #expect(beforeScheduling.map(\.queuePlace) == [
            DownloadQueuePlace(position: 1, waitingCount: 4),
            DownloadQueuePlace(position: 2, waitingCount: 4),
            DownloadQueuePlace(position: 3, waitingCount: 4),
            DownloadQueuePlace(position: 4, waitingCount: 4),
            nil, nil, nil
        ])

        await manager.scheduleNextIfNeeded()

        #expect(await manager.testingActiveGalleryID() == Self.active.gid)
        let scheduled = await manager.indexedDownloads()
        #expect(scheduled.map(\.gid) == beforeScheduling.map(\.gid))
        #expect(scheduled.map(\.queuePlace) == [
            nil,
            DownloadQueuePlace(position: 1, waitingCount: 3),
            DownloadQueuePlace(position: 2, waitingCount: 3),
            DownloadQueuePlace(position: 3, waitingCount: 3),
            nil, nil, nil
        ])
        let fetched = await manager.fetchDownload(gid: Self.second.gid)
        #expect(fetched?.queuePlace == DownloadQueuePlace(position: 2, waitingCount: 3))
        #expect(fetched?.badge.waitingPosition == 2)
        #expect(gate.scheduledGIDs == [Self.active.gid])
    }

    @Test
    func testPauseThenResumeMovesAGalleryToTheEndOfTheWaitingGroup() async throws {
        let gate = QueueRunGate()
        let fixture = try await makeFixture(gate: gate)
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()

        try await manager.togglePause(gid: Self.first.gid).get()
        try await manager.togglePause(gid: Self.first.gid).get()

        #expect(await waitingGIDs(in: manager) == [Self.second, Self.third, Self.first].map(\.gid))
        let places = await manager.indexedDownloads().compactMap(\.queuePlace)
        #expect(places == [
            DownloadQueuePlace(position: 1, waitingCount: 3),
            DownloadQueuePlace(position: 2, waitingCount: 3),
            DownloadQueuePlace(position: 3, waitingCount: 3)
        ])
        #expect(await manager.queueStore.gids == [Self.active, Self.second, Self.third, Self.first].map(\.gid))
    }
}
