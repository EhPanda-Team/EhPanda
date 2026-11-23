import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing
import TestingSupport

/// B-2 and B-5: the reorder operations rewrite the persisted queue's order under the one predicate the menu reads,
/// leave the active gallery running in its slot, and refuse (with nothing moved) what the place no longer allows.
@Suite(.isolatedAppStorage)
struct DownloadQueueReorderTests: DownloadFeatureTestCase {
    private static let active = SessionGallery(gid: "261123200", title: "Active", pageCount: 4)
    private static let first = SessionGallery(gid: "261123201", title: "First", pageCount: 4)
    private static let second = SessionGallery(gid: "261123202", title: "Second", pageCount: 4)
    private static let third = SessionGallery(gid: "261123203", title: "Third", pageCount: 4)
    private static let paused = SessionGallery(gid: "261123204", title: "Paused", pageCount: 4, completedPageCount: 1)
    private static let complete = SessionGallery(
        gid: "261123205",
        title: "Complete",
        pageCount: 4,
        completedPageCount: 4
    )

    struct Accepted: Sendable, CustomTestStringConvertible {
        let operation: DownloadQueueOperation
        let gid: String
        let expectedWaiting: [String]

        var testDescription: String { "\(operation.rawValue) \(gid) → \(expectedWaiting)" }
    }

    struct Refused: Sendable, CustomTestStringConvertible {
        let operation: DownloadQueueOperation
        let gid: String

        var testDescription: String { "\(operation.rawValue) \(gid)" }
    }

    private func makeFixture(
        gate: QueueRunGate,
        client: BackgroundProcessingClient = .noop
    ) async throws -> SessionFixture {
        let fixture = try await makeQueuedCoordinator(
            galleries: [Self.active, Self.first, Self.second, Self.third, Self.paused, Self.complete],
            queuedGIDs: [Self.active, Self.first, Self.second, Self.third].map(\.gid),
            client: client,
            taskRunner: gate.taskRunner
        )
        await fixture.manager.scheduleNextIfNeeded()
        return fixture
    }

    @Test(arguments: [
        Accepted(operation: .downloadNext, gid: "261123203", expectedWaiting: ["261123203", "261123201", "261123202"]),
        Accepted(operation: .downloadNext, gid: "261123202", expectedWaiting: ["261123202", "261123201", "261123203"]),
        Accepted(operation: .moveUp, gid: "261123202", expectedWaiting: ["261123202", "261123201", "261123203"]),
        Accepted(operation: .moveUp, gid: "261123203", expectedWaiting: ["261123201", "261123203", "261123202"]),
        Accepted(operation: .moveDown, gid: "261123201", expectedWaiting: ["261123202", "261123201", "261123203"]),
        Accepted(operation: .moveDown, gid: "261123202", expectedWaiting: ["261123201", "261123203", "261123202"]),
        Accepted(operation: .downloadLast, gid: "261123201", expectedWaiting: ["261123202", "261123203", "261123201"]),
        Accepted(operation: .downloadLast, gid: "261123202", expectedWaiting: ["261123201", "261123203", "261123202"])
    ])
    func testAnAcceptedOperationReordersTheWaitingGroupAndLeavesTheActiveGalleryRunning(
        _ accepted: Accepted
    ) async throws {
        let gate = QueueRunGate()
        let fixture = try await makeFixture(gate: gate)
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        #expect(await manager.testingActiveGalleryID() == Self.active.gid)

        try await manager.performQueueOperation(gid: accepted.gid, operation: accepted.operation).get()

        #expect(await waitingGIDs(in: manager) == accepted.expectedWaiting)
        #expect(await manager.queueStore.gids == [Self.active.gid] + accepted.expectedWaiting)
        #expect(await manager.testingActiveGalleryID() == Self.active.gid)
        #expect(gate.scheduledGIDs == [Self.active.gid])
    }

    @Test(arguments: [
        Refused(operation: .downloadNext, gid: "261123201"),
        Refused(operation: .moveUp, gid: "261123201"),
        Refused(operation: .moveDown, gid: "261123203"),
        Refused(operation: .downloadLast, gid: "261123203"),
        Refused(operation: .downloadNext, gid: "261123200"),
        Refused(operation: .moveUp, gid: "261123200"),
        Refused(operation: .moveDown, gid: "261123200"),
        Refused(operation: .downloadLast, gid: "261123200"),
        Refused(operation: .moveUp, gid: "261123204"),
        Refused(operation: .moveDown, gid: "261123204"),
        Refused(operation: .downloadLast, gid: "261123204"),
        Refused(operation: .downloadNext, gid: "261123205"),
        Refused(operation: .moveUp, gid: "261123205"),
        Refused(operation: .moveDown, gid: "261123205"),
        Refused(operation: .downloadLast, gid: "261123205")
    ])
    func testARefusedOperationChangesNothing(_ refused: Refused) async throws {
        let gate = QueueRunGate()
        let fixture = try await makeFixture(gate: gate)
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }

        await #expect(throws: AppError.unknown) {
            try await manager.performQueueOperation(gid: refused.gid, operation: refused.operation).get()
        }

        #expect(await manager.queueStore.gids == [Self.active, Self.first, Self.second, Self.third].map(\.gid))
        #expect(await manager.testingActiveGalleryID() == Self.active.gid)
        #expect(gate.scheduledGIDs == [Self.active.gid])
    }

    @Test
    func testAnUnknownGalleryIsNotFound() async throws {
        let gate = QueueRunGate()
        let fixture = try await makeFixture(gate: gate)
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }

        await #expect(throws: AppError.notFound) {
            try await fixture.manager.performQueueOperation(gid: "261123299", operation: .downloadNext).get()
        }
    }

    @Test
    func testDownloadNextOnAPausedItemMobilizesItAsResumeDoes() async throws {
        let spy = BackgroundProcessingClientSpy()
        let twinSpy = BackgroundProcessingClientSpy()
        let gate = QueueRunGate()
        let twinGate = QueueRunGate()
        let fixture = try await makeFixture(gate: gate, client: spy.client)
        let twin = try await makeFixture(gate: twinGate, client: twinSpy.client)
        defer {
            gate.stop()
            twinGate.stop()
            removeTemporaryItem(at: fixture.rootURL)
            removeTemporaryItem(at: twin.rootURL)
        }

        try await fixture.manager.performQueueOperation(gid: Self.paused.gid, operation: .downloadNext).get()
        try await twin.manager.togglePause(gid: Self.paused.gid).get()

        #expect(await waitingGIDs(in: fixture.manager) == [Self.paused, Self.first, Self.second, Self.third].map(\.gid))
        #expect(await waitingGIDs(in: twin.manager) == [Self.first, Self.second, Self.third, Self.paused].map(\.gid))
        let intent = await fixture.manager.queueIntentSnapshot(
            gid: Self.paused.gid,
            backgroundSessionStartCount: spy.startCount
        )
        let twinIntent = await twin.manager.queueIntentSnapshot(
            gid: Self.paused.gid,
            backgroundSessionStartCount: twinSpy.startCount
        )
        #expect(intent == twinIntent)
        #expect(gate.scheduledGIDs == [Self.active.gid])
        #expect(twinGate.scheduledGIDs == [Self.active.gid])
    }
}
