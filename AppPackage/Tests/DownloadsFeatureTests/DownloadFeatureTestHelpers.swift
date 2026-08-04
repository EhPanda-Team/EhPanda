@testable import AppFeature
import AppModels
import AppTools
import BackgroundProcessingClient
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
import Kingfisher
import LibraryClient
import Synchronization
import Testing
import TestingSupport
import UIKit

// MARK: - Shared Test Helper Protocol

protocol DownloadFeatureTestCase: TestHelper {
    func expectCachedPlaceholderRejected(url: URL, placeholderData: Data) async throws

    func waitForTaskValue<T>(
        _ task: Task<T, Never>,
        timeout: Duration,
        description: String
    ) async throws -> T

    func sampleGalleryState(gid: String) throws -> GalleryState
    func sampleVersionMetadata(gid: String, token: String) -> DownloadVersionMetadata
    func makeTestingDownloadCoordinator() -> DownloadCoordinator
    func makeResponse(
        url: URL,
        statusCode: Int,
        contentType: String,
        contentLength: Int?,
        headers: [String: String]
    ) throws -> HTTPURLResponse
    func writeFixtureToTemporaryFile(filename: HTMLFilename) throws -> URL
    func writeFixtureToTemporaryFile(resource: String, pathExtension: String) throws -> URL
    func fixtureData(resource: String, pathExtension: String) throws -> Data
    func installGalleryVersionMetadataStub(for gallery: Gallery, sessionID: String) throws
    func uninstallSharedSessionStub(sessionID: String)
    func sampleGallery() -> Gallery
    func sampleGalleryDetail(gid: String, title: String) -> GalleryDetail
    func sampleManifest(
        gid: String,
        title: String,
        pageCount: Int
    ) throws -> DownloadManifest
    func sampleInspection(download: DownloadedGallery) -> DownloadInspection
    func prepareLocalDownloadFiles(
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) throws -> URL
}

// MARK: - Default Implementations

extension DownloadFeatureTestCase {
    /// Primes an isolated `DataCache` with a placeholder body under every cache key of `url`, then
    /// asserts the coordinator refuses to serve it.
    ///
    /// The surrounding assertions are what give the middle one meaning: the first proves the entry
    /// really was cached, the last proves the rejection evicted it — so a `nil` result cannot be a
    /// trivial cache miss. Everything the assertion touches is per-call state: the byte cache the
    /// read path resolves is injected, and `libraryClient: .noop` keeps the eviction off the
    /// process-shared Kingfisher cache, so callers need no serialization.
    func expectCachedPlaceholderRejected(url: URL, placeholderData: Data) async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let dataCache = DataCache(
            configuration: .init(
                rootURL: rootURL.appendingPathComponent("DataCache", isDirectory: true)
            )
        )
        let manager = DownloadCoordinator(
            storage: DownloadStore(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            libraryClient: .noop
        )
        let cacheKeys = url.imageCacheKeys

        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            try await dataCache.store(placeholderData, forKeys: cacheKeys)
            #expect(await dataCache.data(forKeys: cacheKeys) == placeholderData)

            #expect(await manager.validatedCachedAssetData(for: [url]) == nil)

            #expect(await dataCache.data(forKeys: cacheKeys) == nil)
        }
    }

    func waitForTaskValue<T>(
        _ task: Task<T, Never>,
        timeout: Duration = .seconds(1),
        description: String
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                task.cancel()
                throw NSError(
                    domain: "DownloadFeatureReducerTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(description)"]
                )
            }

            let value = try await group.next()
            group.cancelAll()
            return try #require(value, "Expected one task group result for \(description).")
        }
    }

    @MainActor
    func drainDetailMetadataEffects(
        _ store: TestStoreOf<DetailReducer>,
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() && clock.now < deadline {
            await store.skipReceivedActions(strict: false)
            await sleepIgnoringCancellation(for: .milliseconds(10))
        }
        await store.skipReceivedActions(strict: false)
    }

    func sampleGalleryState(gid: String) throws -> GalleryState {
        var galleryState = GalleryState(gid: gid)
        galleryState.previewURLs = [1: try #require(URL(string: "https://example.com/1t.jpg"))]
        galleryState.previewConfig = .normal(rows: 4)
        return galleryState
    }

    func sampleVersionMetadata(
        gid: String,
        token: String
    ) -> DownloadVersionMetadata {
        DownloadVersionMetadata(
            gid: gid,
            token: token,
            currentGID: gid,
            currentKey: "updated-key",
            parentGID: gid,
            parentKey: token,
            firstGID: gid,
            firstKey: token
        )
    }

    func makeTestingDownloadCoordinator() -> DownloadCoordinator {
        makeTestingDownloadCoordinator(storedCookiesProvider: { _ in [] })
    }

    func makeTestingDownloadCoordinator(
        storedCookiesProvider: @escaping @Sendable (URL) -> [HTTPCookie]
    ) -> DownloadCoordinator {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return DownloadCoordinator(
            storage: DownloadStore(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            storedCookiesProvider: storedCookiesProvider
        )
    }

    func makeResponse(
        url: URL,
        statusCode: Int = 200,
        contentType: String,
        contentLength: Int? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPURLResponse {
        var headerFields = headers
        headerFields["Content-Type"] = contentType
        if let contentLength {
            headerFields["Content-Length"] = "\(contentLength)"
        }
        return try #require(HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        ))
    }

    func writeFixtureToTemporaryFile(
        filename: HTMLFilename
    ) throws -> URL {
        try writeFixtureToTemporaryFile(resource: filename.rawValue, pathExtension: "html")
    }

    func writeFixtureToTemporaryFile(
        resource: String,
        pathExtension: String
    ) throws -> URL {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try fixtureData(resource: resource, pathExtension: pathExtension)
            .write(to: temporaryURL, options: .atomic)
        return temporaryURL
    }

    func fixtureData(filename: HTMLFilename) throws -> Data {
        try fixtureData(resource: filename.rawValue, pathExtension: "html")
    }

    func fixtureData(
        resource: String,
        pathExtension: String
    ) throws -> Data {
        let fixtureURL = try #require(
            TestFixtures.url(forResource: resource, withExtension: pathExtension)
        )
        return try Data(contentsOf: fixtureURL)
    }

    func installGalleryVersionMetadataStub(
        for gallery: Gallery,
        sessionID: String
    ) throws {
        let gid = try #require(Int(gallery.gid))
        let payload: [String: Any] = [
            "gmetadata": [[
                "gid": gid,
                "token": gallery.token,
                "current_gid": gid,
                "current_key": "updated-key",
                "parent_gid": gid,
                "parent_key": gallery.token,
                "first_gid": gid,
                "first_key": gallery.token
            ]]
        ]
        let responseData = try JSONSerialization.data(withJSONObject: payload, options: [])
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            let response = try #require(HTTPURLResponse(
                url: request.url ?? Defaults.URL.api(host: .ehentai),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, responseData)
        }
        URLProtocol.registerClass(SharedSessionStubURLProtocol.self)
    }

    func uninstallSharedSessionStub(sessionID: String) {
        SharedSessionStubURLProtocol.removeHandler(for: sessionID)
    }

    func sampleGallery() -> Gallery {
        Gallery(
            gid: "123456",
            token: "token",
            title: "Sample Gallery",
            rating: 4,
            tags: [],
            category: .doujinshi,
            uploader: "Uploader",
            pageCount: 12,
            postedDate: .now,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            galleryURL: URL(string: "https://e-hentai.org/g/123456/token")
        )
    }

    func sampleGalleryDetail(
        gid: String,
        title: String
    ) -> GalleryDetail {
        GalleryDetail(
            gid: gid,
            title: title,
            jpnTitle: nil,
            isFavorited: false,
            visibility: .yes,
            rating: 4,
            userRating: 0,
            ratingCount: 10,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            postedDate: .now,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            favoritedCount: 2,
            pageCount: 12,
            sizeCount: 120,
            sizeType: "MB",
            torrentCount: 0
        )
    }

}

// MARK: - Continued Session Fixtures

/// One gallery to seed on disk. A named value rather than a tuple, so a case that cares only
/// about page counts still reads as page counts at the call site.
struct SessionGallery {
    let gid: String
    let title: String
    let pageCount: Int
    var completedPageCount = 0
}

struct SessionFixture {
    let manager: DownloadCoordinator
    let storage: DownloadStore
    let rootURL: URL
}

extension DownloadFeatureTestCase {
    /// The blocking fixture with its queue cleared, so the single download starts out inactive and
    /// unschedulable. That is the state a resume has to move, which makes the tap under test the
    /// only thing that can produce schedulable work.
    func makeInactiveCoordinator(
        gid: String,
        client: BackgroundProcessingClient,
        galleryTitle: String = "Queued",
        releasesOnCancellation: Bool = true
    ) async throws -> BlockingCoordinatorContext {
        let context = try await makeBlockingCoordinator(
            gid: gid,
            title: galleryTitle,
            backgroundProcessingClient: client,
            releasesOnCancellation: releasesOnCancellation
        )
        await context.manager.testingSetQueuedGalleryIDs([])
        return context
    }

    /// A coordinator holding `galleries` on disk with `queuedGIDs` enqueued, and nothing running.
    ///
    /// Deliberately not the blocking fixture: a queued gallery is schedulable on its own, so this
    /// makes the queue's *shape* the only variable an arithmetic case has to reason about. The
    /// default runner preserves the existing setup behavior: fixture construction never invokes
    /// scheduling, so no download can start underneath an assertion. Tests that need to observe
    /// scheduling without performing a download inject a task runner. The default file manager
    /// preserves every existing caller; removal-failure cases inject one instead of relying on
    /// temporary-directory permissions that vary across machines and sandboxes.
    func makeQueuedCoordinator(
        galleries: [SessionGallery],
        queuedGIDs: [String]? = nil,
        client: BackgroundProcessingClient,
        now: @escaping @Sendable () -> Date = { Date() },
        taskRunner: DownloadTaskRunner = DownloadTaskRunner(),
        fileManager: sending FileManager = FileManager.default
    ) async throws -> SessionFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: fileManager)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundProcessingClient: client,
            taskRunner: taskRunner,
            now: now
        )

        try storage.ensureRootDirectory()
        for gallery in galleries {
            try writeGalleryFolder(storage: storage, gallery: gallery)
        }
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs(queuedGIDs ?? galleries.map(\.gid))
        return SessionFixture(manager: manager, storage: storage, rootURL: rootURL)
    }

    /// Writes one gallery folder whose manifest reports `completedPageCount` finished pages: a
    /// page counts as done when its hash entry is non-empty, which is the same rule the index
    /// derives progress from.
    private func writeGalleryFolder(
        storage: DownloadStore,
        gallery: SessionGallery
    ) throws {
        let folderURL = storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(manifest(for: gallery), folderURL: folderURL)
    }

    /// Writes a real page file for each requested index inside the gallery's fixture folder.
    ///
    /// Fixture manifests carry hash entries but no files, which is enough for arithmetic over the
    /// record alone. It is not enough for the states the production folder contract distinguishes:
    /// a record that reads complete while some of its files are gone is what `storage.validate`
    /// reports as `.missingFiles`, what `resumeMode` resolves to `.repair`, and what the working
    /// seed's reconciliation blanks. Staging those files here is what lets a case reach that state
    /// through the contract instead of patching the index behind it.
    func writePageFiles(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        indices: [Int]
    ) throws {
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
        for index in indices {
            let relativePath = fixture.storage.makePageRelativePath(
                gid: gallery.gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
            try Data("page-\(index)".utf8).write(
                to: folderURL.appendingPathComponent(relativePath),
                options: .atomic
            )
        }
    }

    func manifest(for gallery: SessionGallery) -> DownloadManifest {
        DownloadManifest(
            gid: gallery.gid,
            host: .ehentai,
            token: "token",
            title: gallery.title,
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            rating: 4,
            pages: Dictionary(
                uniqueKeysWithValues: (0..<gallery.pageCount).map { offset in
                    (offset + 1, offset < gallery.completedPageCount ? "sha256:done" : "")
                }
            )
        )
    }
}

// MARK: - Blocking Coordinator Fixture

/// Gives the free functions below a receiver for `DownloadFeatureTestCase`'s shared factories.
/// The protocol declares no requirement without a default implementation, so an empty conformer
/// is a complete witness; it exists only so file-scope code can reach those factories without
/// forcing conformance onto every suite that wants the fixture.
private struct SharedDownloadTestFactories: DownloadFeatureTestCase {}

/// A synchronous, idempotent release token for a runner parked on a checked continuation.
///
/// Started and cancellation rendezvous make the runner's lifecycle observable without polling.
/// Cancellation does not inherently end the park, which lets an interleave case deliberately hold
/// the cancelled runner until it has inspected the coordinator's suspended state.
final class BlockingRunnerControl: Sendable {
    private struct State {
        var isReleased = false
        var didStart = false
        var didObserveCancellation = false
        var parkContinuation: CheckedContinuation<Void, Never>?
        var startedContinuations = [CheckedContinuation<Void, Never>]()
        var cancellationContinuations = [CheckedContinuation<Void, Never>]()
    }

    private let state = Mutex(State())

    func release() {
        let continuation: CheckedContinuation<Void, Never>? = state.withLock {
            guard $0.isReleased == false else { return nil }
            $0.isReleased = true
            let continuation = $0.parkContinuation
            $0.parkContinuation = nil
            return continuation
        }
        continuation?.resume()
    }

    func park() async {
        let startedContinuations = state.withLock {
            $0.didStart = true
            let continuations = $0.startedContinuations
            $0.startedContinuations.removeAll()
            return continuations
        }
        startedContinuations.forEach({ $0.resume() })

        await withCheckedContinuation { continuation in
            let isReleased = state.withLock {
                guard $0.isReleased == false else { return true }
                $0.parkContinuation = continuation
                return false
            }
            if isReleased {
                continuation.resume()
            }
        }
    }

    func started() async {
        await withCheckedContinuation { continuation in
            let didStart = state.withLock {
                guard $0.didStart == false else { return true }
                $0.startedContinuations.append(continuation)
                return false
            }
            if didStart {
                continuation.resume()
            }
        }
    }

    func recordCancellation() {
        let cancellationContinuations = state.withLock {
            $0.didObserveCancellation = true
            let continuations = $0.cancellationContinuations
            $0.cancellationContinuations.removeAll()
            return continuations
        }
        cancellationContinuations.forEach({ $0.resume() })
    }

    func cancellationObserved() async {
        await withCheckedContinuation { continuation in
            let didObserveCancellation = state.withLock {
                guard $0.didObserveCancellation == false else { return true }
                $0.cancellationContinuations.append(continuation)
                return false
            }
            if didObserveCancellation {
                continuation.resume()
            }
        }
    }
}

struct BlockingCoordinatorContext {
    let manager: DownloadCoordinator
    let storage: DownloadStore
    let rootURL: URL
    let control: BlockingRunnerControl

    /// Unblocks the runner before removing the directory it may still touch.
    func cleanUp() {
        control.release()
        removeTemporaryItem(at: rootURL)
    }
}

/// Builds a coordinator whose single queued download parks on a test-owned token once scheduled,
/// so `activeTask` stays installed and queue lifecycle behavior can be observed in flight.
///
/// The default releases the token when cancellation arrives, preserving the existing pause
/// behavior. Passing `false` holds the runner after cancellation for a staged interleave; without a
/// matching `control.release()` that mode hangs by construction, so the control is part of the
/// returned context and `cleanUp()` always releases it.
func makeBlockingCoordinator(
    gid: String,
    title: String,
    backgroundProcessingClient: BackgroundProcessingClient = .noop,
    releasesOnCancellation: Bool = true
) async throws -> BlockingCoordinatorContext {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
    let control = BlockingRunnerControl()
    let taskRunner = DownloadTaskRunner(
        runScheduledDownload: { _, _ in
            await withTaskCancellationHandler {
                await control.park()
            } onCancel: {
                control.recordCancellation()
                if releasesOnCancellation {
                    control.release()
                }
            }
            return .skippedOperation
        }
    )
    let manager = DownloadCoordinator(
        storage: storage,
        urlSession: .shared,
        backgroundProcessingClient: backgroundProcessingClient,
        taskRunner: taskRunner
    )

    try storage.ensureRootDirectory()
    let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] \(title)")
    try FileManager.default.createDirectory(
        at: folderURL,
        withIntermediateDirectories: true
    )
    try storage.writeManifest(
        SharedDownloadTestFactories().sampleManifest(gid: gid, title: title),
        folderURL: folderURL
    )
    await manager.reloadDownloadIndex()
    await manager.testingSetQueuedGalleryIDs([gid])
    return BlockingCoordinatorContext(
        manager: manager,
        storage: storage,
        rootURL: rootURL,
        control: control
    )
}

// The poll returns the moment the condition holds, so the deadline costs nothing on a healthy
// run and only bounds a genuine hang. One second did not survive CI, where the whole target's
// suites run in parallel and a task can sit unscheduled far longer than the work itself takes.
func waitUntil(
    timeout: Duration = .seconds(10),
    _ condition: @Sendable () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while await !condition(), clock.now < deadline {
        await sleepIgnoringCancellation(for: .milliseconds(10))
    }
    try #require(await condition(), "Timed out waiting for condition.")
}
