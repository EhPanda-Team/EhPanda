import AppModels
@testable import BackgroundProcessingClient
import DownloadClient
import Foundation
import Kanna
import ParserFeature
import Synchronization
import Testing
import TestingSupport

@MainActor
private final class HeldSubmissionCoordinatorClient {
    let session: ContinuedProcessingSession
    private(set) var latestSessionID: UUID?
    private(set) var progressReports = [ContinuedSubunitReport]()
    private var progressWaiters = [CheckedContinuation<Void, Never>]()

    init(scheduling: ContinuedTaskScheduling) {
        session = ContinuedProcessingSession(scheduling: scheduling)
    }

    func client() -> BackgroundProcessingClient {
        BackgroundProcessingClient(
            start: { [self] title, subtitle, completedUnitCount, totalUnitCount in
                await Task.yield()
                return await start(
                    title: title,
                    subtitle: subtitle,
                    completedUnitCount: completedUnitCount,
                    totalUnitCount: totalUnitCount
                )
            },
            updateProgress: { [self] sessionID, completed, total, subunits, subtitle in
                await Task.yield()
                await updateProgress(
                    sessionID: sessionID,
                    completedUnitCount: completed,
                    totalUnitCount: total,
                    subunits: subunits,
                    subtitle: subtitle
                )
            },
            finish: { [self] sessionID, success in
                await Task.yield()
                await finish(sessionID: sessionID, success: success)
            }
        )
    }

    func start(
        title: String,
        subtitle: String,
        completedUnitCount: Int64,
        totalUnitCount: Int64
    ) -> BackgroundProcessingSession? {
        let result = session.start(
            title: title,
            subtitle: subtitle,
            completedUnitCount: completedUnitCount,
            totalUnitCount: totalUnitCount
        )
        latestSessionID = result?.id
        return result
    }

    func updateProgress(
        sessionID: UUID,
        completedUnitCount: Int64,
        totalUnitCount: Int64,
        subunits: ContinuedSubunitReport,
        subtitle: String
    ) {
        progressReports.append(subunits)
        if subunits.inFlightSubunitCount > 0 {
            progressWaiters.forEach({ $0.resume() })
            progressWaiters.removeAll()
        }
        session.updateProgress(
            sessionID: sessionID,
            completedUnitCount: completedUnitCount,
            totalUnitCount: totalUnitCount,
            subunits: subunits,
            subtitle: subtitle
        )
    }

    func waitForInFlightProgress() async {
        if progressReports.contains(where: { $0.inFlightSubunitCount > 0 }) {
            return
        }
        await withCheckedContinuation { continuation in
            progressWaiters.append(continuation)
        }
    }

    func finish(sessionID: UUID, success: Bool) {
        session.finish(sessionID: sessionID, success: success)
    }
}

private final class HeldCoordinatorDate: Sendable {
    private let value: Mutex<Date>

    init(_ date: Date) {
        value = Mutex(date)
    }

    var current: Date {
        value.withLock({ $0 })
    }

    func advance(by seconds: TimeInterval) {
        value.withLock({ $0 = $0.addingTimeInterval(seconds) })
    }
}

private actor TransferProbe {
    private var started = false
    private var operationFinished = false
    private var bytesReleased = false
    private var completionReleased = false
    private var startWaiters = [CheckedContinuation<Bool, Never>]()
    private var byteWaiters = [CheckedContinuation<Void, Never>]()
    private var completionWaiters = [CheckedContinuation<Void, Never>]()

    func markStarted() {
        started = true
        startWaiters.forEach({ $0.resume(returning: true) })
        startWaiters.removeAll()
    }

    func markOperationFinished() {
        operationFinished = true
        startWaiters.forEach({ $0.resume(returning: false) })
        startWaiters.removeAll()
    }

    func waitForStart() async -> Bool {
        if started { return true }
        if operationFinished { return false }
        return await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func waitForByteRelease() async {
        if bytesReleased { return }
        await withCheckedContinuation { continuation in
            byteWaiters.append(continuation)
        }
    }

    func releaseBytes() {
        bytesReleased = true
        byteWaiters.forEach({ $0.resume() })
        byteWaiters.removeAll()
    }

    func waitForCompletionRelease() async {
        if completionReleased { return }
        await withCheckedContinuation { continuation in
            completionWaiters.append(continuation)
        }
    }

    func releaseCompletion() {
        completionReleased = true
        completionWaiters.forEach({ $0.resume() })
        completionWaiters.removeAll()
    }
}

@MainActor
@Suite
struct HeldSubmissionCoordinatorTests: DownloadFeatureTestCase {
    /// A public resume drives a real scheduled operation through a controlled page downloader while
    /// native submission is suspended. Transfer start and byte progress must reach the session's
    /// in-flight accounting before submission is released; a queued-session seed alone would miss
    /// this ordering entirely.
    @Test
    func testCoordinatorResumeAndTransferProgressContinueDuringHeldSubmission() async throws {
        let schedulingSpy = ContinuedTaskSchedulingSpy()
        schedulingSpy.holdSubmissions = true
        let clientBox = HeldSubmissionCoordinatorClient(scheduling: schedulingSpy.scheduling)
        let transferProbe = TransferProbe()
        let gid = "210240"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let sessionID = UUID().uuidString
        let urlSession = makeStubbedURLSession(stubSessionID: sessionID)
        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        let mpvHTML = try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html")
        let metadataResponse = try makeMetadataResponseData(gid: gid)
        let document = try htmlDocument(filename: .galleryDetail)
        let (detail, _) = try Parser.parseGalleryDetail(doc: document, gid: gid)
        let coverURL = try #require(detail.coverURL)
        installDownloadStubHandler(
            sessionID: sessionID,
            gid: gid,
            pageIndex: 156,
            content: StubHandlerContent(
                detailHTML: detailHTML,
                mpvHTML: mpvHTML,
                metadataResponse: metadataResponse
            ),
            allowedImageURLs: [coverURL.absoluteString]
        )
        defer { uninstallSharedSessionStub(sessionID: sessionID) }

        let pageDownloader = DownloadPageDownloader { _, _, onBytesWritten in
            await transferProbe.markStarted()
            await transferProbe.waitForByteRelease()
            onBytesWritten(500, 1_000)
            await transferProbe.waitForCompletionRelease()
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: fileURL, options: .atomic)
            let pageURL = try #require(URL(string: "https://example.com/page.jpg"))
            let response = try #require(HTTPURLResponse(
                url: pageURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"]
            ))
            return DownloadPageTransfer(fileURL: fileURL, response: response)
        }
        let taskRunner = DownloadTaskRunner(
            runScheduledDownload: { _, operation in
                await operation()
                await transferProbe.markOperationFinished()
                return .ranOperation
            }
        )
        let currentDate = HeldCoordinatorDate(Date(timeIntervalSince1970: 1_700_000_000))
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: urlSession,
            pageDownloader: pageDownloader,
            backgroundProcessingClient: clientBox.client(),
            taskRunner: taskRunner,
            now: { currentDate.current }
        )
        let gallery = SessionGallery(
            gid: gid,
            title: "Held submission",
            pageCount: 156,
            completedPageCount: 155
        )
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(
            relativePath: "Folder/[\(gid)_token] \(gallery.title)"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            try sampleManifest(gid: gid, title: gallery.title, pageCount: 155),
            folderURL: folderURL
        )
        let fixture = SessionFixture(manager: manager, storage: storage, rootURL: rootURL)
        try writePageFiles(for: gallery, in: fixture, indices: Array(1...155))
        let hashedManifest = try storage.addingCurrentFileHashes(
            to: try storage.readManifest(folderURL: folderURL),
            folderURL: folderURL
        )
        var stagedManifest = hashedManifest
        stagedManifest.pages[156] = ""
        try storage.writeManifest(stagedManifest, folderURL: folderURL)
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([])

        let actionTask = Task { await manager.togglePause(gid: gid) }
        let cleanup = { @MainActor in
            let submissionTask = clientBox.session.submission?.task
            let eventTask = await manager.testingContinuedSessionTask()
            if let sessionID = clientBox.latestSessionID {
                clientBox.session.finish(sessionID: sessionID, success: false)
            }
            schedulingSpy.releaseSubmission()
            await transferProbe.releaseBytes()
            await transferProbe.releaseCompletion()
            _ = await actionTask.value
            _ = await manager.pause(gid: gid)
            await submissionTask?.value
            if let sessionID = await manager.testingContinuedSessionID() {
                await manager.testingMarkContinuedSessionEnded(sessionID: sessionID)
            }
            await eventTask?.value
        }
        do {
            await schedulingSpy.waitForSubmissionEntry()
            try #require(
                await transferProbe.waitForStart(),
                "Scheduled operation ended before starting the controlled page transfer."
            )
            let toggleResult = await actionTask.value
            try toggleResult.get()
            currentDate.advance(by: DownloadCoordinator.intraPageProgressPushMinimumInterval + 1)
            await transferProbe.releaseBytes()
            await clientBox.waitForInFlightProgress()
            #expect(clientBox.progressReports.contains(where: { $0.inFlightSubunitCount > 0 }))
            #expect(schedulingSpy.submissions.isEmpty)

            let submissionTask = try #require(clientBox.session.submission?.task)
            schedulingSpy.releaseSubmission()
            await submissionTask.value
            let identifier = try #require(schedulingSpy.registeredIdentifiers.first)
            let task = ContinuedTaskSpy()
            schedulingSpy.launch(identifier, with: task)
            #expect(task.progress.completedUnitCount > 0)
        } catch {
            await cleanup()
            throw error
        }
        await cleanup()
    }
}
