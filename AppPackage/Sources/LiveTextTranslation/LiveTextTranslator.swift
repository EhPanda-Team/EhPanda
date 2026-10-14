import AppModels
import CoreGraphics
import Dependencies
import Foundation
import Observation
import OSLogExt

private let logger = Logger(category: .init(describing: LiveTextTranslator.self))

/// Translates the pages Live Text recognized and keeps each page's translations laid out for drawing.
///
/// Each page is translated once. A page in the reader's own language, one without letters and one in a
/// language that cannot be identified or translated keep Live Text's highlight for as long as the
/// reader is open. A page whose translation failed, or whose language pair's models were not
/// downloaded, is tried again the next time Live Text is turned on, which also lets each kind of
/// failure be told once more.
///
/// Pages go to the system's translation one at a time, the one nearest ``readingPage`` first, as
/// they wait in a queue. The system translates one request at a time however many it is given, so
/// giving it every recognized page at once only made the page being read wait behind the others.
/// A page's turn covers finding its language pair and translating it; laying the translations out
/// uses only this device's processors, so it runs beside the next page's turn.
@Observable
@MainActor
public final class LiveTextTranslator {
    /// Each page's translations, by page number.
    public private(set) var translatedPages = [Int: LiveTextTranslatedPage]()
    /// The language pair whose models the system is to offer to download, which
    /// `View.liveTextTranslationDownloads(for:)` does.
    public private(set) var download: LiveTextLanguagePair?
    /// A failure the reader has not been told about yet; ``takeFailure()`` takes it.
    public private(set) var failure: LiveTextTranslationFailure?
    /// The page the reader shows; the queued page nearest it is translated next, the one after it
    /// before the one before it.
    @ObservationIgnored public var readingPage = 1

    private enum PageState: Equatable {
        /// Waiting for its turn, being translated, or waiting for its language pair's models.
        case inProgress
        /// Translated, or kept as it is however often it is tried.
        case settled
        /// Not translated this time; tried again the next time Live Text is turned on.
        case deferred
    }

    /// The page each translated group is on, which ``translatedPage(of:)`` looks a page up by.
    /// Observed, as the translations are: a page's view looks its page up while the page is not yet
    /// translated, when the lookup reads nothing else, so it is only told of the translation through
    /// this.
    private var pageByGroupID = [UUID: Int]()
    @ObservationIgnored private var states = [Int: PageState]()
    /// The pages waiting for their turn, by page number.
    @ObservationIgnored private var queue = [Int: QueuedPage]()
    /// The turn of the page with the system now.
    @ObservationIgnored private var turn: Task<Void, Never>?
    /// The translated pages being laid out, by page number.
    @ObservationIgnored private var layouts = [Int: Task<Void, Never>]()
    @ObservationIgnored private var awaitingDownload = [LiveTextLanguagePair: [PageRequest]]()
    /// The pairs whose models the system downloaded while Live Text is on, which a page later found to
    /// need them is translated with rather than offered their download again. The system can still
    /// answer that such a pair's models are missing, as it can for installed models on its first
    /// answers after a launch; and a download offered again as the last one ends could go unnoticed,
    /// as `translationTask` runs again only when it sees its configuration change.
    @ObservationIgnored private var downloadedPairs = Set<LiveTextLanguagePair>()
    @ObservationIgnored private var declinedPairs = Set<LiveTextLanguagePair>()
    @ObservationIgnored private var reportedFailures = Set<LiveTextTranslationFailure.Kind>()
    @ObservationIgnored @Dependency(\.liveTextTranslationClient) private var client

    public init() {}

    isolated deinit {
        turn?.cancel()
        for task in layouts.values {
            task.cancel()
        }
    }

    /// Whether `page` is still to be translated.
    public func needsTranslation(page: Int) -> Bool {
        states[page] == nil
    }

    /// The translations of the page `groups` were recognized on.
    public func translatedPage(of groups: [LiveTextGroup]) -> LiveTextTranslatedPage? {
        groups.first
            .flatMap({ pageByGroupID[$0.id] })
            .flatMap({ translatedPages[$0] })
    }

    /// Queues `groups`, recognized on `image` as `page` in `recognitionLanguages`, to be translated.
    public func translate(_ groups: [LiveTextGroup], on image: CGImage, page: Int, recognitionLanguages: [String]?) {
        guard needsTranslation(page: page) else {
            return
        }
        let texts = groups.compactMap(LiveTextSourceText.init(group:))
        guard !texts.isEmpty else {
            states[page] = .settled
            return
        }
        states[page] = .inProgress
        let request = PageRequest(
            page: page,
            groups: groups,
            texts: texts,
            image: image,
            candidates: (recognitionLanguages ?? []).map(Locale.Language.init(identifier:))
        )
        queue[page] = QueuedPage(request: request, pair: nil)
        translateNext()
    }

    /// Takes the failure the reader is to be told about, so it is told once.
    public func takeFailure() -> LiveTextTranslationFailure? {
        defer {
            failure = nil
        }
        return failure
    }

    /// Carries on once the system's download of `pair`'s models is done: the pages waiting for them
    /// queue to be translated when they were downloaded, and are deferred when they were not.
    public func finishDownload(of pair: LiveTextLanguagePair, succeeded: Bool) {
        guard download == pair else {
            return
        }
        let requests = awaitingDownload.removeValue(forKey: pair) ?? []
        if succeeded {
            downloadedPairs.insert(pair)
            for request in requests {
                queue[request.page] = QueuedPage(request: request, pair: pair)
            }
            translateNext()
        } else {
            declinedPairs.insert(pair)
            for request in requests {
                states[request.page] = .deferred
            }
        }
        download = nextDownload()
    }

    /// Ends a period of Live Text being on: the pages not translated this time, including those
    /// still queued and those waiting for a download, are tried again next time, and each kind of
    /// failure may be told again. Queued pages are dropped rather than left to find their language
    /// pairs, which could have the system offer a download after Live Text is off.
    public func endActivation() {
        for request in queue.values.map(\.request) + awaitingDownload.values.joined() {
            states[request.page] = nil
        }
        queue.removeAll()
        awaitingDownload.removeAll()
        download = nil
        failure = nil
        downloadedPairs.removeAll()
        declinedPairs.removeAll()
        reportedFailures.removeAll()
        states = states.filter({ $0.value != .deferred })
    }

    /// Stops every translation; a page it stopped is translated when it is next asked for.
    public func cancel() {
        turn?.cancel()
        turn = nil
        for task in layouts.values {
            task.cancel()
        }
        layouts.removeAll()
        queue.removeAll()
        awaitingDownload.removeAll()
        download = nil
        states = states.filter({ $0.value != .inProgress })
    }

    /// Waits until no page is queued, translated or laid out, apart from those waiting for a
    /// download, so tests can read a page's outcome.
    func waitForTranslations() async {
        while let task = turn ?? layouts.values.first {
            await task.value
        }
    }

    /// Gives the queued page nearest ``readingPage`` its turn, once the page before it has had its.
    private func translateNext() {
        guard turn == nil, let page = nearestQueuedPage(), let queued = queue.removeValue(forKey: page) else {
            return
        }
        if let pair = queued.pair {
            startTranslating(queued.request, as: pair)
            return
        }
        let request = queued.request
        let client = client
        turn = Task { [weak self] in
            let route = await LiveTextLanguageResolver.route(
                for: request.texts,
                candidates: request.candidates,
                client: client
            )
            guard !Task.isCancelled else {
                return
            }
            self?.follow(route, for: request)
        }
    }

    /// The queued page nearest ``readingPage``, the one after it before the one before it.
    private func nearestQueuedPage() -> Int? {
        // Twice the distance, one more for the page before the reading page than for the one as far
        // after it.
        func rank(_ page: Int) -> Int {
            abs(page - readingPage) * 2 + (page < readingPage ? 1 : 0)
        }
        return queue.keys.min(by: { rank($0) < rank($1) })
    }

    private func follow(_ route: LiveTextTranslationRoute, for request: PageRequest) {
        turn = nil
        switch route {
        case .translate(let pair):
            startTranslating(request, as: pair)
        case .download(let pair):
            awaitDownload(of: pair, for: request)
        case .untranslated:
            states[request.page] = .settled
        case .failed(let failure):
            states[request.page] = .settled
            report(failure)
        }
        translateNext()
    }

    private func startTranslating(_ request: PageRequest, as pair: LiveTextLanguagePair) {
        let client = client
        turn = Task { [weak self] in
            let sources = request.texts.map({ $0.prepared(for: pair) })
            let result: Result<[UUID: String], any Error>
            do {
                result = .success(try await client.translate(sources, pair))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else {
                return
            }
            self?.finishTurn(of: request, sources: sources, as: pair, with: result)
        }
    }

    /// Ends `request`'s turn with its translations, which are laid out beside the next page's turn,
    /// or with the error that kept it from them.
    private func finishTurn(
        of request: PageRequest,
        sources: [LiveTextSourceText],
        as pair: LiveTextLanguagePair,
        with result: Result<[UUID: String], any Error>
    ) {
        turn = nil
        switch result {
        case .success(let translations):
            layouts[request.page] = Task { [weak self] in
                let page = await Self.layOut(request, sources: sources, translations: translations, as: pair)
                guard !Task.isCancelled else {
                    return
                }
                self?.finishLayingOut(request, as: page)
            }
        case .failure(let error):
            logger.error("Translating page \(request.page, privacy: .public) failed: \(error, privacy: .public)")
            states[request.page] = .deferred
            report(.translationFailed)
        }
        translateNext()
    }

    private func finishLayingOut(_ request: PageRequest, as translatedPage: LiveTextTranslatedPage) {
        layouts[request.page] = nil
        states[request.page] = .settled
        // A page whose every translation reads as its lettering keeps the highlight.
        guard !translatedPage.groups.isEmpty else {
            return
        }
        for group in request.groups {
            pageByGroupID[group.id] = request.page
        }
        translatedPages[request.page] = translatedPage
    }

    private func awaitDownload(of pair: LiveTextLanguagePair, for request: PageRequest) {
        guard !downloadedPairs.contains(pair) else {
            queue[request.page] = QueuedPage(request: request, pair: pair)
            return
        }
        guard !declinedPairs.contains(pair) else {
            states[request.page] = .deferred
            return
        }
        awaitingDownload[pair, default: []].append(request)
        if download == nil {
            download = pair
        }
    }

    /// The pair the earliest waiting page needs, so downloads are offered in reading order.
    private func nextDownload() -> LiveTextLanguagePair? {
        awaitingDownload
            .compactMap { pair, requests in
                requests.map(\.page).min().map({ PendingDownload(pair: pair, firstPage: $0) })
            }
            .min(by: { $0.firstPage < $1.firstPage })
            .map(\.pair)
    }

    private func report(_ failure: LiveTextTranslationFailure) {
        guard reportedFailures.insert(failure.kind).inserted else {
            return
        }
        self.failure = failure
    }

    @concurrent
    private static func layOut(
        _ request: PageRequest,
        sources: [LiveTextSourceText],
        translations: [UUID: String],
        as pair: LiveTextLanguagePair
    ) async -> LiveTextTranslatedPage {
        LiveTextTranslatedPage.layOut(
            groups: request.groups,
            sources: Dictionary(sources.map({ ($0.groupID, $0.text) }), uniquingKeysWith: { first, _ in first }),
            translations: translations,
            language: pair.target,
            image: request.image
        )
    }
}

/// A recognized page to be translated.
private struct PageRequest: Sendable {
    let page: Int
    let groups: [LiveTextGroup]
    let texts: [LiveTextSourceText]
    let image: CGImage
    /// The languages the page was recognized in, which its language is found among first.
    let candidates: [Locale.Language]
}

/// A page waiting for its turn, with its language pair once a finished download has decided it.
private struct QueuedPage {
    let request: PageRequest
    let pair: LiveTextLanguagePair?
}

private struct PendingDownload {
    let pair: LiveTextLanguagePair
    let firstPage: Int
}
