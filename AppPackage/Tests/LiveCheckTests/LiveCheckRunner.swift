import AppModels
import Foundation
import Kanna
import NetworkingFeature
import ParserFeature
import UIKit

/// What reading one page came to, before it is classified.
enum LiveCheckOutcome: Equatable, Sendable {
    /// The page parsed and met its expectations.
    case passed
    /// The read threw: the request type's own error after its own attempts.
    case failed(AppError)
    /// The page parsed but did not show what it must.
    case unmet(LiveCheckExpectation)
    /// The page was not read because an earlier page it needs ended with this classification.
    case blocked(after: LiveCheckClassification)
}

/// Tells a block from a break (19-CONTEXT D-23; 19-RESEARCH §7), as a pure function of what the page's session saw
/// and what its read came to, so offline tests drive it with saved pages.
///
/// - `unreachable`: a 403 with `cf-mitigated`, an IP ban, a network failure after the read's own attempts, a
///   timeout, a 5xx, any other non-2xx status or no response at all. A block never names an expectation.
/// - `parser`: a 2xx page that the app's parser rejects or that misses an expectation.
enum LiveCheckClassifier {
    static func classify(
        _ page: LiveCheckPage, observation: PageObservation, outcome: LiveCheckOutcome
    ) -> LiveCheckPageResult {
        if case .blocked(let earlier) = outcome {
            return earlier == .unreachable
                ? LiveCheckPageResult(page: page, status: nil, classification: .unreachable)
                : LiveCheckPageResult(page: page, status: nil, classification: .parser, expectation: .earlierPage)
        }
        let status = observation.status
        let unreachable = LiveCheckPageResult(page: page, status: status, classification: .unreachable)
        if case .failed(let error) = outcome, isBlock(error) {
            return unreachable
        }
        guard let status, (200..<300).contains(status), !observation.cfMitigated else {
            return unreachable
        }
        switch outcome {
        case .passed:
            return LiveCheckPageResult(page: page, status: status, classification: .okay)
        case .unmet(let expectation):
            return LiveCheckPageResult(page: page, status: status, classification: .parser, expectation: expectation)
        case .failed, .blocked:
            return LiveCheckPageResult(
                page: page, status: status, classification: .parser, expectation: page.primaryExpectation
            )
        }
    }

    private static func isBlock(_ error: AppError) -> Bool {
        switch error {
        case .ipBanned, .networkingFailed, .cloudflareChallengeFailed:
            return true
        default:
            return false
        }
    }
}

/// Runs the daily check's pages one after another, as a guest, each on its own cookieless GET-only session
/// (19-CONTEXT D-20, D-21; 19-RESEARCH §7). Values one page passes to the next (the gallery, its first page's
/// image address) stay in memory and are never written or logged.
struct LiveCheckRunner {
    /// The pause between pages.
    var pause: Duration = .seconds(5)
    /// URL protocols the sessions consult before the network: offline tests serve saved pages through one.
    var protocolClasses: [AnyClass] = []
    var host: GalleryHost = .ehentai

    func run(mode: LiveCheckMode, date: Date = .now) async -> LiveCheckResults {
        var pages = [LiveCheckPageResult]()
        let filter = Filter()
        for (page, url) in [
            (LiveCheckPage.frontPage, URLUtil.frontPageList(host: host, filter: filter)),
            (.search, URLUtil.searchList(host: host, keyword: LiveCheckPage.searchKeyword, filter: filter)),
            (.popular, URLUtil.popularList(host: host, filter: filter))
        ] {
            pages.append(await list(page, url: url).result)
            await rest()
        }
        let toplists = await list(
            .toplists, url: URLUtil.toplistsList(host: host, catIndex: ToplistsType.yesterday.categoryIndex)
        )
        pages.append(toplists.result)
        await rest()
        let gallery = toplists.value?.first.flatMap { item in
            item.galleryURL.map({ GalleryLink(gid: item.gid, url: $0) })
        }
        let detail = await read(.gallery, needs: gallery, after: toplists.result) { session, gallery in
            await Self.galleryDetail(gid: gallery.gid, url: gallery.url, session: session)
        }
        pages.append(detail.result)
        await rest()
        let galleryURL = detail.result.classification == .okay ? gallery?.url : nil
        let reader = await read(.reader, needs: galleryURL, after: detail.result) { session, url in
            await Self.firstImageURL(galleryURL: url, session: session)
        }
        pages.append(reader.result)
        await rest()
        let image = await read(.readerImage, needs: reader.value, after: reader.result) { session, url in
            await Self.decodeImage(url: url, session: session)
        }
        pages.append(image.result)
        await rest()
        pages.append(await read(.tagSuggestions) { session in await Self.tagDatabase(session: session) }.result)
        await rest()
        let reportURL = galleryURL.flatMap(Self.reportFormURL(galleryURL:))
        let report = await read(.reportForm, needs: reportURL, after: detail.result) { session, url in
            await Self.reportForm(url: url, session: session)
        }
        pages.append(report.result)
        pages += LiveCheckPage.allCases.filter(\.needsSignIn)
            .map({ LiveCheckPageResult(page: $0, status: nil, classification: .skipped) })
        return LiveCheckResults(date: date, mode: mode, pages: pages)
    }

    // MARK: Reading a page

    struct Read<Value> {
        let result: LiveCheckPageResult
        let value: Value?
    }

    /// What a page's read came to, and the value it passes on when it passed.
    struct Step<Value> {
        let outcome: LiveCheckOutcome
        let value: Value?

        static func passed(_ value: Value) -> Self {
            Self(outcome: .passed, value: value)
        }

        static func ended(_ outcome: LiveCheckOutcome) -> Self {
            Self(outcome: outcome, value: nil)
        }
    }

    /// The gallery the gallery page opens: the first Toplists row.
    struct GalleryLink {
        let gid: String
        let url: URL
    }

    private func rest() async {
        do {
            try await Task.sleep(for: pause)
        } catch {
            // A cancelled run stops pausing; the next page read sees the cancellation itself.
        }
    }

    /// Reads one page on a fresh session and classifies it from that session's own observation.
    func read<Value>(
        _ page: LiveCheckPage, body: (URLSession) async -> Step<Value>
    ) async -> Read<Value> {
        let observer = PageObserver()
        let session = observer.makeSession(protocolClasses: protocolClasses)
        defer { session.finishTasksAndInvalidate() }
        let step = await body(session)
        let observation = await observer.settledObservation()
        let result = LiveCheckClassifier.classify(page, observation: observation, outcome: step.outcome)
        return Read(result: result, value: result.classification == .okay ? step.value : nil)
    }

    /// Reads a page that needs a value an earlier page provided; without it the page follows that page's class.
    private func read<Input, Value>(
        _ page: LiveCheckPage, needs input: Input?, after earlier: LiveCheckPageResult,
        body: (URLSession, Input) async -> Step<Value>
    ) async -> Read<Value> {
        guard let input else {
            let outcome = LiveCheckOutcome.blocked(after: earlier.classification)
            return Read(
                result: LiveCheckClassifier.classify(page, observation: .unreached, outcome: outcome), value: nil
            )
        }
        return await read(page, body: { session in await body(session, input) })
    }

    /// A list page: the app's list URL read with GET and parsed by the app's list parser.
    func list(_ page: LiveCheckPage, url: URL) async -> Read<[Gallery]> {
        await read(page) { session in
            do {
                let data = try await Self.get(url, in: session)
                let galleries = try Parser.parseGalleries(doc: Kanna.HTML(html: data, encoding: .utf8))
                guard !galleries.isEmpty else { return .ended(.unmet(page.primaryExpectation ?? .earlierPage)) }
                return .passed(galleries)
            } catch {
                return .ended(.failed(Self.appError(error)))
            }
        }
    }

    /// One GET, put on the wire up to four times as the app's request types do.
    private static func get(_ url: URL, in session: URLSession) async throws -> Data {
        var lastError: any Error = URLError(.unknown)
        for _ in 0..<4 {
            do {
                return try await session.data(for: URLRequest(url: url)).0
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func appError(_ error: any Error) -> AppError {
        switch error {
        case let error as AppError:
            return error
        case is URLError:
            return .networkingFailed
        default:
            return .parseFailed
        }
    }

    private static func galleryDetail(gid: String, url: URL, session: URLSession) async -> Step<Void> {
        do {
            let response = try await GalleryDetailRequest(gid: gid, galleryURL: url, urlSession: session).response()
            return response.galleryState.comments.isEmpty ? .ended(.unmet(.galleryComments)) : .passed(())
        } catch {
            return .ended(.failed(error))
        }
    }

    /// The first preview page's page links, then page 1's reader page for its image address.
    private static func firstImageURL(galleryURL: URL, session: URLSession) async -> Step<URL> {
        do {
            let thumbnails = try await ThumbnailURLsRequest(galleryURL: galleryURL, pageNum: 0, urlSession: session)
                .response()
            guard let first = thumbnails.min(by: { $0.key < $1.key }) else {
                return .ended(.unmet(.readerThumbnails))
            }
            let images = try await GalleryNormalImageURLsRequest(
                thumbnailURLs: [first.key: first.value], urlSession: session
            ).response()
            guard let imageURL = images.imageURLs[first.key] else { return .ended(.unmet(.readerImageURL)) }
            return .passed(imageURL)
        } catch {
            return .ended(.failed(error))
        }
    }

    /// Page 1's image, decoded in memory and discarded.
    private static func decodeImage(url: URL, session: URLSession) async -> Step<Void> {
        do {
            let data = try await DataRequest(url: url, urlSession: session).response()
            return UIImage(data: data) == nil ? .ended(.unmet(.readerImageDecode)) : .passed(())
        } catch {
            return .ended(.failed(error))
        }
    }

    private static func tagDatabase(session: URLSession) async -> Step<Void> {
        do {
            let payload = try await TagTranslatorRequest(language: .english, currentDigest: nil, urlSession: session)
                .response()
            return payload.data.isEmpty ? .ended(.unmet(.tagDatabaseAsset)) : .passed(())
        } catch {
            return .ended(.failed(error))
        }
    }

    private static func reportForm(url: URL, session: URLSession) async -> Step<Void> {
        do {
            _ = try await ReportFormRequest(url: url, urlSession: session).response()
            return .passed(())
        } catch {
            return .ended(.failed(error))
        }
    }

    /// The gallery's `?report=other` page, rebuilt from its gallery URL as the app's report target does.
    static func reportFormURL(galleryURL: URL) -> URL? {
        var parts = galleryURL.pathComponents.dropFirst().makeIterator()
        guard parts.next() == "g", let gid = parts.next(), let token = parts.next(), let host = galleryURL.host()
        else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/g/\(gid)/\(token)/"
        components.queryItems = [URLQueryItem(name: "report", value: "other")]
        return components.url
    }
}
