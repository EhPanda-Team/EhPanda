public import AppModels
public import CoreGraphics
import Dependencies
import Foundation
public import Observation
import OSLogExt
import Translation

private let logger = Logger(category: .init(describing: LiveTextTranslator.self))

/// Queues recognized pages for the reader's SwiftUI translation session, nearest page first.
///
/// Only one page is handed to the session at a time. Its translations are laid out alongside the
/// next page's translation. A session stays available for later pages of the same language pair;
/// only Sendable requests and results cross between its task and this main-actor coordinator.
@Observable
@MainActor
public final class LiveTextTranslator {
    public private(set) var translatedPages = [Int: LiveTextTranslatedPage]()
    public private(set) var failure: LiveTextTranslationFailure?
    @ObservationIgnored public var readingPage = 1

    /// Work for the session owned by `View.liveTextTranslations(for:)`, never the session itself.
    private(set) var session: LiveTextTranslationWork?
    var configuration: TranslationSession.Configuration? {
        session == nil ? nil : lastConfiguration
    }

    private enum PageState {
        case inProgress
        case settled
        case deferred
    }

    // The lookup itself must be observed: before translation a page's view only reads this map.
    private var pageByGroupID = [UUID: Int]()
    @ObservationIgnored private var states = [Int: PageState]()
    @ObservationIgnored private var queue = [Int: PageRequest]()
    @ObservationIgnored private var turn: Task<Void, Never>?
    @ObservationIgnored private var pending: PendingTranslation?
    @ObservationIgnored private var layouts = [Int: Task<Void, Never>]()
    @ObservationIgnored private var requests: AsyncStream<LiveTextTranslationBatch>.Continuation?
    @ObservationIgnored private var lastConfiguration: TranslationSession.Configuration?
    @ObservationIgnored private var deferredPairs = Set<LiveTextLanguagePair>()
    @ObservationIgnored private var reportedFailures = Set<LiveTextTranslationFailure.Kind>()
    @ObservationIgnored @Dependency(\.liveTextTranslationClient) private var client

    public init() {}

    isolated deinit {
        turn?.cancel()
        requests?.finish()
        for task in layouts.values {
            task.cancel()
        }
    }

    public func needsTranslation(page: Int) -> Bool {
        states[page] == nil
    }

    public func translatedPage(of groups: [LiveTextGroup]) -> LiveTextTranslatedPage? {
        groups.first
            .flatMap({ pageByGroupID[$0.id] })
            .flatMap({ translatedPages[$0] })
    }

    /// Queues a page once per reader, or once per activation if its translation failed.
    public func translate(_ groups: [LiveTextGroup], on image: CGImage, page: Int, recognitionLanguages: [String]?) {
        guard needsTranslation(page: page) else { return }
        let texts = groups.compactMap(LiveTextSourceText.init(group:))
        guard !texts.isEmpty else {
            states[page] = .settled
            return
        }
        states[page] = .inProgress
        queue[page] = PageRequest(
            page: page,
            groups: groups,
            texts: texts,
            image: image,
            candidates: (recognitionLanguages ?? []).map(Locale.Language.init(identifier:))
        )
        translateNext()
    }

    public func takeFailure() -> LiveTextTranslationFailure? {
        defer { failure = nil }
        return failure
    }

    /// Stops unfinished work and permits failed pages and language pairs to be tried next time.
    /// Completed pages remain cached while the reader is open.
    public func endActivation() {
        cancel()
        failure = nil
        deferredPairs.removeAll()
        reportedFailures.removeAll()
        states = states.filter({ $0.value != .deferred })
    }

    /// Finishing the stream releases an idle worker and clearing the configuration withdraws its work.
    /// A native request already in progress may finish later; its session and batch IDs reject stale results.
    public func cancel() {
        turn?.cancel()
        turn = nil
        requests?.finish()
        requests = nil
        session = nil
        pending = nil
        for task in layouts.values {
            task.cancel()
        }
        layouts.removeAll()
        queue.removeAll()
        states = states.filter({ $0.value != .inProgress })
    }

    /// Waits for language resolution and layout. Translation itself belongs to the view's worker,
    /// which tests drive through the same request stream and result entry point.
    func waitForTranslations() async {
        while let task = turn ?? layouts.values.first {
            await task.value
        }
    }

    /// Unavailable models leave the pair's pages highlighted until reactivation. This includes a
    /// declined prompt even when the framework reports it as an internal error during translation.
    func modelsUnavailable(in sessionID: UUID, with error: any Error) {
        guard session?.id == sessionID, let pending else { return }
        logger.info("Translation models are unavailable: \(error, privacy: .public)")
        deferredPairs.insert(pending.pair)
        states[pending.request.page] = .deferred
        self.pending = nil
        requests?.finish()
        requests = nil
        session = nil
        translateNext()
    }

    /// Accepts only the outstanding request of the current session, including after rapid reactivation.
    func finish(_ batch: LiveTextTranslationBatch, in sessionID: UUID, with result: Result<[UUID: String], any Error>) {
        guard session?.id == sessionID, let pending, pending.batch.id == batch.id else { return }
        self.pending = nil
        let request = pending.request
        switch result {
        case .success(let translations):
            layouts[request.page] = Task { [weak self] in
                let page = await Self.layOut(pending, translations: translations)
                guard !Task.isCancelled else { return }
                self?.finishLayingOut(request, as: page)
            }
        case .failure(let error):
            states[request.page] = .deferred
            if error is CancellationError || CocoaError.userCancelled ~= error {
                // A declined download must not be offered again for every queued page.
                deferredPairs.insert(pending.pair)
                requests?.finish()
                requests = nil
                session = nil
            } else {
                logger.error("Translating page \(request.page, privacy: .public) failed: \(error, privacy: .public)")
                report(.translationFailed)
            }
        }
        translateNext()
    }

    /// A view-owned task can end without the reader explicitly cancelling it. Release its unfinished
    /// work as well, while ignoring the completion of a task superseded by another language pair.
    func sessionEnded(_ id: UUID) {
        guard session?.id == id else { return }
        cancel()
    }

    private func translateNext() {
        guard turn == nil, pending == nil, let page = nearestQueuedPage(),
              let request = queue.removeValue(forKey: page)
        else { return }
        let client = client
        turn = Task { [weak self] in
            let route = await LiveTextLanguageResolver.route(
                for: request.texts,
                candidates: request.candidates,
                client: client
            )
            guard !Task.isCancelled else { return }
            self?.follow(route, for: request)
        }
    }

    private func nearestQueuedPage() -> Int? {
        func rank(_ page: Int) -> Int {
            abs(page - readingPage) * 2 + (page < readingPage ? 1 : 0)
        }
        return queue.keys.min(by: { rank($0) < rank($1) })
    }

    private func follow(_ route: LiveTextTranslationRoute, for request: PageRequest) {
        turn = nil
        switch route {
        case .translate(let pair):
            guard !deferredPairs.contains(pair) else {
                states[request.page] = .deferred
                translateNext()
                return
            }
            if session?.pair != pair {
                requests?.finish()
                var configuration = lastConfiguration ?? TranslationSession.Configuration()
                configuration.source = pair.source
                configuration.target = pair.target
                // Preserve the version across nil configurations, so off/on in one view update
                // still replaces the old session even when its languages have not changed.
                configuration.invalidate()
                lastConfiguration = configuration
                let stream = AsyncStream<LiveTextTranslationBatch>.makeStream()
                requests = stream.continuation
                session = LiveTextTranslationWork(id: UUID(), pair: pair, requests: stream.stream)
            }
            let batch = LiveTextTranslationBatch(id: UUID(), sources: request.texts.map({ $0.prepared(for: pair) }))
            pending = PendingTranslation(request: request, pair: pair, batch: batch)
            requests?.yield(batch)
        case .untranslated:
            states[request.page] = .settled
        case .failed(let failure):
            states[request.page] = .settled
            report(failure)
        }
        translateNext()
    }

    private func finishLayingOut(_ request: PageRequest, as translatedPage: LiveTextTranslatedPage) {
        layouts[request.page] = nil
        states[request.page] = .settled
        guard !translatedPage.groups.isEmpty else { return }
        for group in request.groups {
            pageByGroupID[group.id] = request.page
        }
        translatedPages[request.page] = translatedPage
    }

    private func report(_ failure: LiveTextTranslationFailure) {
        guard reportedFailures.insert(failure.kind).inserted else { return }
        self.failure = failure
    }

    @concurrent
    private static func layOut(
        _ pending: PendingTranslation,
        translations: [UUID: String]
    ) async -> LiveTextTranslatedPage {
        LiveTextTranslatedPage.layOut(
            groups: pending.request.groups,
            sources: Dictionary(
                pending.batch.sources.map({ ($0.groupID, $0.text) }),
                uniquingKeysWith: { first, _ in first }
            ),
            translations: translations,
            language: pending.pair.target,
            image: pending.request.image
        )
    }
}

struct LiveTextTranslationWork: Sendable {
    let id: UUID
    let pair: LiveTextLanguagePair
    let requests: AsyncStream<LiveTextTranslationBatch>
}

struct LiveTextTranslationBatch: Sendable {
    let id: UUID
    let sources: [LiveTextSourceText]
}

private struct PageRequest: Sendable {
    let page: Int
    let groups: [LiveTextGroup]
    let texts: [LiveTextSourceText]
    let image: CGImage
    let candidates: [Locale.Language]
}

private struct PendingTranslation: Sendable {
    let request: PageRequest
    let pair: LiveTextLanguagePair
    let batch: LiveTextTranslationBatch
}
