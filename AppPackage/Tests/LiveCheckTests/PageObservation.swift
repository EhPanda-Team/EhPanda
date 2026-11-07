import Foundation
import Synchronization

/// The only facts a live page fetch records (19-CONTEXT D-22, D-25): its HTTP status and whether Cloudflare
/// answered with a `cf-mitigated` header. The URL, every other header and the body are never read.
struct PageObservation: Equatable, Sendable {
    let status: Int?
    let cfMitigated: Bool

    init(status: Int?, cfMitigated: Bool) {
        self.status = status
        self.cfMitigated = cfMitigated
    }

    init(response: URLResponse?) {
        let response = response as? HTTPURLResponse
        status = response?.statusCode
        cfMitigated = response?.value(forHTTPHeaderField: "cf-mitigated") != nil
    }

    /// A page that was not fetched, or whose fetch got no response.
    static let unreached = Self(status: nil, cfMitigated: false)
}

/// Collects the `URLSessionTaskMetrics` of one page's session. The page's observation comes from its last
/// transaction with a response, which is the one the parser read.
final class PageObserver: NSObject, URLSessionTaskDelegate, Sendable {
    private let observations = Mutex([PageObservation]())

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let reached = metrics.transactionMetrics
            .filter({ $0.response != nil })
            .map({ PageObservation(response: $0.response) })
        observations.withLock({ $0 += reached })
    }

    var observation: PageObservation {
        observations.withLock({ $0.last }) ?? .unreached
    }

    /// One page's session: ephemeral, with no cookies and no cache, sending GET requests only.
    func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.protocolClasses = [GetOnlyURLProtocol.self] + (configuration.protocolClasses ?? [])
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
}

/// Fails, offline, any request in a live check session that is not a GET (19-CONTEXT D-21 as narrowed at
/// planning): the check reads pages and never sends anything else.
final class GetOnlyURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        (request.httpMethod ?? "GET").uppercased() != "GET"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }

    override func stopLoading() {}
}
