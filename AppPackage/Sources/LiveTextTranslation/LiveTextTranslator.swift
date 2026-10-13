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

    private enum PageState: Equatable {
        /// Being translated, or waiting for its language pair's models.
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
    @ObservationIgnored private var tasks = [Int: Task<Void, Never>]()
    @ObservationIgnored private var awaitingDownload = [LiveTextLanguagePair: [PageRequest]]()
    @ObservationIgnored private var declinedPairs = Set<LiveTextLanguagePair>()
    @ObservationIgnored private var reportedFailures = Set<LiveTextTranslationFailure.Kind>()
    @ObservationIgnored @Dependency(\.liveTextTranslationClient) private var client

    public init() {}

    isolated deinit {
        for task in tasks.values {
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

    /// Starts translating `groups`, recognized on `image` as `page` in `recognitionLanguages`.
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
        let request = PageRequest(page: page, groups: groups, texts: texts, image: image)
        let candidates = (recognitionLanguages ?? []).map(Locale.Language.init(identifier:))
        let client = client
        tasks[page] = Task { [weak self] in
            let route = await LiveTextLanguageResolver.route(for: texts, candidates: candidates, client: client)
            guard !Task.isCancelled else {
                return
            }
            self?.follow(route, for: request)
        }
    }

    /// Takes the failure the reader is to be told about, so it is told once.
    public func takeFailure() -> LiveTextTranslationFailure? {
        defer {
            failure = nil
        }
        return failure
    }

    /// Carries on once the system's download of `pair`'s models is done: the pages waiting for them
    /// are translated when they were downloaded, and deferred when they were not.
    public func finishDownload(of pair: LiveTextLanguagePair, succeeded: Bool) {
        guard download == pair else {
            return
        }
        let requests = awaitingDownload.removeValue(forKey: pair) ?? []
        if succeeded {
            for request in requests {
                startTranslating(request, as: pair)
            }
        } else {
            declinedPairs.insert(pair)
            for request in requests {
                states[request.page] = .deferred
            }
        }
        download = nextDownload()
    }

    /// Ends a period of Live Text being on: the pages not translated this time, including those
    /// waiting for a download, are tried again next time, and each kind of failure may be told again.
    public func endActivation() {
        for request in awaitingDownload.values.joined() {
            states[request.page] = nil
        }
        awaitingDownload.removeAll()
        download = nil
        failure = nil
        declinedPairs.removeAll()
        reportedFailures.removeAll()
        states = states.filter({ $0.value != .deferred })
    }

    /// Stops every translation; a page it stopped is translated when it is next asked for.
    public func cancel() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        awaitingDownload.removeAll()
        download = nil
        states = states.filter({ $0.value != .inProgress })
    }

    /// Waits until no page is being translated, apart from those waiting for a download, so tests can
    /// read a page's outcome.
    func waitForTranslations() async {
        while let task = tasks.values.first {
            await task.value
        }
    }

    private func follow(_ route: LiveTextTranslationRoute, for request: PageRequest) {
        tasks[request.page] = nil
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
    }

    private func startTranslating(_ request: PageRequest, as pair: LiveTextLanguagePair) {
        let client = client
        tasks[request.page] = Task { [weak self] in
            let result: Result<LiveTextTranslatedPage, any Error>
            do {
                let texts = request.texts.map({ $0.prepared(for: pair) })
                let translations = try await client.translate(texts, pair)
                result = .success(await Self.layOut(request, sources: texts, translations: translations, as: pair))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else {
                return
            }
            self?.finishTranslating(request, with: result)
        }
    }

    private func finishTranslating(_ request: PageRequest, with result: Result<LiveTextTranslatedPage, any Error>) {
        tasks[request.page] = nil
        switch result {
        case .success(let translatedPage):
            states[request.page] = .settled
            // A page whose every translation reads as its lettering keeps the highlight.
            guard !translatedPage.groups.isEmpty else {
                return
            }
            for group in request.groups {
                pageByGroupID[group.id] = request.page
            }
            translatedPages[request.page] = translatedPage
        case .failure(let error):
            logger.error("Translating page \(request.page, privacy: .public) failed: \(error, privacy: .public)")
            states[request.page] = .deferred
            report(.translationFailed)
        }
    }

    private func awaitDownload(of pair: LiveTextLanguagePair, for request: PageRequest) {
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
}

private struct PendingDownload {
    let pair: LiveTextLanguagePair
    let firstPage: Int
}
