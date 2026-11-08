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

/// Watches one page's session. The page's observation is the final response (after redirects) of the last task the
/// session created that got one, which is the response the parser read. It is taken from the task when the task
/// finishes, so it holds whether the response came from the network or, in the offline tests, from a URL protocol
/// (whose responses have no transaction in the task metrics).
final class PageObserver: NSObject, URLSessionTaskDelegate, Sendable {
    private struct Seen {
        var observations = [Int: PageObservation]()
        var created = 0
        var finished = Set<Int>()
    }

    private let seen = Mutex(Seen())

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        seen.withLock({ $0.created += 1 })
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let response = task.response ?? metrics.transactionMetrics.last(where: { $0.response != nil })?.response
        record(task, response: response)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        record(task, response: task.response)
    }

    private func record(_ task: URLSessionTask, response: URLResponse?) {
        let identifier = task.taskIdentifier
        seen.withLock { seen in
            seen.finished.insert(identifier)
            if let response {
                seen.observations[identifier] = PageObservation(response: response)
            }
        }
    }

    var observation: PageObservation {
        seen.withLock({ seen in seen.observations.max(by: { $0.key < $1.key })?.value }) ?? .unreached
    }

    /// The observation once every task the session created has finished, which the delegate can hear after the
    /// task's data was returned; waits at most two seconds.
    func settledObservation() async -> PageObservation {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while seen.withLock({ $0.finished.count < $0.created }), clock.now < deadline {
            do {
                try await clock.sleep(for: .milliseconds(20))
            } catch {
                break
            }
        }
        return observation
    }

    /// One page's session: ephemeral, with no cookies and no cache, sending GET requests only. `protocolClasses`
    /// come after the GET-only check: offline tests serve saved pages through one, so no test reaches a host.
    func makeSession(protocolClasses: [AnyClass] = []) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 30
        let system = configuration.protocolClasses ?? []
        configuration.protocolClasses = [GetOnlyURLProtocol.self] + protocolClasses + system
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
}

/// Fails, offline, any request in a live check session that is not a GET (19-CONTEXT D-21 as narrowed at
/// planning): the check reads pages and never sends anything else.
final class GetOnlyURLProtocol: URLProtocol {
    private static let refusals = Mutex(0)

    /// How many requests this process has refused; the offline tests require that a run refuses none.
    static var refused: Int {
        refusals.withLock({ $0 })
    }

    override static func canInit(with request: URLRequest) -> Bool {
        (request.httpMethod ?? "GET").uppercased() != "GET"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.refusals.withLock({ $0 += 1 })
        client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
    }

    override func stopLoading() {}
}
