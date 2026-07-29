import AppModels
import DownloadClient
import Foundation
import Testing

/// Pins ACTIVE-OWNERSHIP CONVERGENCE across the ownership-clearing removal exits.
///
/// The regression is deliberately parameterized: CR-02 identified one branch, while the same
/// defect was live in a second entry point. Before the production fix, every argument fails both
/// the scheduling and post-failure observer assertions; a branch-only case would preserve only the
/// path the review happened to report.
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

        await fixture.manager.ensureContinuedSession()
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
