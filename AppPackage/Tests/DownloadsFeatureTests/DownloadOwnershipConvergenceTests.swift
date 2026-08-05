import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// Pins ACTIVE-OWNERSHIP CONVERGENCE across the removal exits and the folder-move exits.
///
/// The removal regression is deliberately parameterized: CR-02 identified one branch, while the
/// same defect was live in a second entry point. Before the production fix, every argument fails
/// both the scheduling and post-failure observer assertions; a branch-only case would preserve only
/// the path the review happened to report. The move cases below extend the same invariant to the
/// one family member the phase's convergence rounds never swept.
@Suite
struct DownloadOwnershipConvergenceTests: DownloadFeatureTestCase {
    @Test(arguments: RemovalFailureCase.all)
    func testAFailedRemovalStillConvergesTheQueue(
        failureCase: RemovalFailureCase
    ) async throws {
        let firstGallery = SessionGallery(
            gid: "failed-first",
            title: "Failed First",
            pageCount: 2
        )
        let secondGallery = SessionGallery(
            gid: "queued-second",
            title: "Queued Second",
            pageCount: 2
        )
        let clientSpy = BackgroundProcessingClientSpy()
        defer { clientSpy.expire() }
        let scheduledGalleryRecorder = ScheduledGalleryRecorder()
        let taskRunner = DownloadTaskRunner(
            recordScheduledGallery: { gid in
                scheduledGalleryRecorder.record(gid)
            },
            runScheduledDownload: { _, _ in
                .skippedOperation
            }
        )
        let fileManager = FailingRemovalFileManager(
            pathFragment: failureCase.removalPathFragment(gid: firstGallery.gid),
            error: failureCase.error
        )
        let fixture = try await makeQueuedCoordinator(
            galleries: [firstGallery, secondGallery],
            client: clientSpy.client,
            taskRunner: taskRunner,
            fileManager: fileManager
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        #expect(await fixture.manager.testingHasContinuedSession())
        let activeTask = Task<Void, Never> {
            await sleepIgnoringCancellation(for: .seconds(60))
        }
        defer { activeTask.cancel() }
        await fixture.manager.testingInstallActiveTask(
            gid: firstGallery.gid,
            task: activeTask
        )

        let downloads = await fixture.manager.observeDownloads()
        let observerTask = Task { () -> [[DownloadedGallery]] in
            var emissions = [[DownloadedGallery]]()
            for await snapshot in downloads {
                emissions.append(snapshot)
                if emissions.count == 2 {
                    return emissions
                }
            }
            return emissions
        }
        defer { observerTask.cancel() }

        let result = await failureCase.invoke(
            manager: fixture.manager,
            gid: firstGallery.gid
        )
        // This awaits the collector rather than polling. The deadline only turns a missing
        // notification into a named failure instead of a hung suite.
        let emissions = try await waitForTaskValue(
            observerTask,
            timeout: .seconds(1),
            description: "\(failureCase) post-failure observer emission"
        )

        guard case .failure = result else {
            Issue.record("Expected \(failureCase) removal to fail.")
            return
        }
        let retainedDownload = await fixture.manager.fetchDownload(gid: firstGallery.gid)
        #expect(retainedDownload != nil)
        #expect(retainedDownload?.isQueuedWorkItem == true)
        #expect(scheduledGalleryRecorder.snapshot().isEmpty == false)
        #expect(emissions.count == 2)
        #expect(await fixture.manager.testingHasContinuedSession())
        #expect(clientSpy.finishRecords.isEmpty)
    }

    /// G-15-8, the success exit: `moveDownload` is the one ACTIVE-OWNERSHIP CONVERGENCE family
    /// member the phase's convergence rounds never swept. It blocked its gid, suspended three
    /// times, and returned on every exit without scheduling — so a move that fully succeeded left
    /// the moved gallery queued and idle until some unrelated mutation happened to converge. With
    /// D-03's fallback tier deleted, nothing restarts that work without a fresh qualifying tap.
    ///
    /// The scheduling assertion is deterministic rather than polled: `scheduleNextIfNeeded` is
    /// awaited inside the operation and the runner records its selection synchronously within it,
    /// so the recorder is authoritative the moment `moveDownload` returns. Nothing else in the
    /// fixture schedules — construction deliberately does not, and `createFolder` does not — so an
    /// empty recorder means the move alone failed to converge.
    @Test
    func testAMoveLeavesTheGalleryUnblockedAndTheQueueConverged() async throws {
        let gallery = MoveConvergenceGallery.fixtureGallery(gid: "210380")
        let scheduledGalleryRecorder = ScheduledGalleryRecorder()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            client: .noop,
            taskRunner: MoveConvergenceGallery.inertRunner(recording: scheduledGalleryRecorder)
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        try await fixture.manager
            .createFolder(name: MoveConvergenceGallery.destinationFolderName)
            .get()

        let result = await fixture.manager.moveDownload(
            gid: gallery.gid,
            toFolderName: MoveConvergenceGallery.destinationFolderName
        )

        try result.get()
        #expect(await fixture.manager.testingIsSchedulingBlocked(gallery.gid) == false)
        #expect(scheduledGalleryRecorder.snapshot() == [gallery.gid])
    }

    /// G-15-8, a failure exit: the destination-exists guard returns before the move is attempted,
    /// with the block still held and nothing converged. The gallery never left its folder, so it is
    /// precisely the still-queued work the exit must hand back to the scheduler.
    ///
    /// The occupied destination is staged on disk rather than through a second download, so the
    /// guard is reached by its own condition and no second gallery can supply the scheduling the
    /// assertion looks for.
    @Test
    func testAFailedMoveReleasesTheBlockAndConverges() async throws {
        let gallery = MoveConvergenceGallery.fixtureGallery(gid: "210390")
        let scheduledGalleryRecorder = ScheduledGalleryRecorder()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            client: .noop,
            taskRunner: MoveConvergenceGallery.inertRunner(recording: scheduledGalleryRecorder)
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        try await fixture.manager
            .createFolder(name: MoveConvergenceGallery.destinationFolderName)
            .get()
        try FileManager.default.createDirectory(
            at: MoveConvergenceGallery.destinationGalleryURL(for: gallery, in: fixture),
            withIntermediateDirectories: true
        )

        let result = await fixture.manager.moveDownload(
            gid: gallery.gid,
            toFolderName: MoveConvergenceGallery.destinationFolderName
        )

        guard case .failure = result else {
            Issue.record("Expected the occupied destination to fail the move.")
            return
        }
        #expect(await fixture.manager.testingIsSchedulingBlocked(gallery.gid) == false)
        #expect(scheduledGalleryRecorder.snapshot() == [gallery.gid])
    }
}

// MARK: - Move Convergence Fixture

/// The shared staging for the move-exit cases: one incomplete queued gallery, a runner that
/// records what the scheduler picked without performing any download, and the destination folder
/// both exits target.
private enum MoveConvergenceGallery {
    static let destinationFolderName = "Destination"

    /// Strictly between zero and `pageCount` finished pages, so the gallery is genuinely
    /// incomplete work the scheduler must still want after the move settles.
    static func fixtureGallery(gid: String) -> SessionGallery {
        SessionGallery(
            gid: gid,
            title: "Moved",
            pageCount: 4,
            completedPageCount: 1
        )
    }

    static func inertRunner(
        recording recorder: ScheduledGalleryRecorder
    ) -> DownloadTaskRunner {
        DownloadTaskRunner(
            recordScheduledGallery: { gid in
                recorder.record(gid)
            },
            runScheduledDownload: { _, _ in
                .skippedOperation
            }
        )
    }

    /// The exact path `moveDownload` computes for its destination, so occupying it reaches the
    /// destination-exists guard rather than merely resembling it.
    static func destinationGalleryURL(
        for gallery: SessionGallery,
        in fixture: SessionFixture
    ) -> URL {
        fixture.storage
            .userFolderURL(name: destinationFolderName)
            .appendingPathComponent(
                "[\(gallery.gid)_token] \(gallery.title)",
                isDirectory: true
            )
    }
}

struct RemovalFailureCase: Sendable, CustomTestStringConvertible {
    enum EntryPoint: String, Sendable {
        case deleteGallery
        case deleteUserFolder
    }

    enum ErrorShape: String, Sendable {
        case application
        case foundation
    }

    let entryPoint: EntryPoint
    let errorShape: ErrorShape

    static let all = [
        Self(entryPoint: .deleteGallery, errorShape: .application),
        Self(entryPoint: .deleteGallery, errorShape: .foundation),
        Self(entryPoint: .deleteUserFolder, errorShape: .application),
        Self(entryPoint: .deleteUserFolder, errorShape: .foundation)
    ]

    var testDescription: String {
        "\(entryPoint.rawValue)-\(errorShape.rawValue)"
    }

    var error: any Error & Sendable {
        switch errorShape {
        case .application:
            AppError.fileOperationFailed("Injected typed removal failure")
        case .foundation:
            InjectedRemovalError.failure
        }
    }

    func removalPathFragment(gid: String) -> String {
        switch entryPoint {
        case .deleteGallery:
            "[\(gid)_token]"
        case .deleteUserFolder:
            "Folder"
        }
    }

    func invoke(
        manager: DownloadCoordinator,
        gid: String
    ) async -> Result<Void, AppError> {
        switch entryPoint {
        case .deleteGallery:
            await manager.delete(gid: gid)
        case .deleteUserFolder:
            await manager.deleteFolder(name: "Folder")
        }
    }
}

private enum InjectedRemovalError: LocalizedError, Sendable {
    case failure

    var errorDescription: String? {
        "Injected untyped removal failure"
    }
}
