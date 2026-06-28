import Foundation
import AppModels
import SwiftyBeaverExt

public struct DFRequest {
    public var request: URLRequest
    private let stream: InputStream
    private(set) weak var delegate: DFRequestDelegate?
    private lazy var streamHandler: DFStreamEventHandler?
        = DFStreamEventHandler(request: self)

    public init?(
        _ req: URLRequest,
        delegate: DFRequestDelegate? = nil
    ) {
        self.delegate = delegate
        request = req.domainIPReplaced()

        if let url = req.url,
           let cookies = HTTPCookieStorage
            .shared.cookies(for: url) {
            request.allHTTPHeaderFields = HTTPCookie
                .requestHeaderFields(with: cookies)
        }

        switch InputStream.create(from: request) {
        case .success(let stream):
            self.stream = stream
        case .failure(let error):
            delegate?.dfRequest(
                request, didFailWithError: error
            )
            return nil
        }

        if request.isHTTPS, let host = request.domain {
            stream.invalidatesCertChain(for: host)
        }
    }

    public mutating func resume() {
        if !request.urlContainsImageURL {
            Logger.verbose("Request from: \(request.url?.absoluteString ?? "")")
        }

        stream.schedule(in: RunLoop.current, forMode: .common)
        stream.delegate = streamHandler
        stream.open()
    }

    public mutating func stop() {
        stream.delegate = nil
        streamHandler = nil
        stream.close()
        delegate = nil
    }
}

// MARK: DFRequestDelegate
public protocol DFRequestDelegate: AnyObject {
    func dfRequestDidFinishLoading(_ request: DFRequest)
    func dfRequest(_ request: DFRequest, didLoad data: Data)
    func dfRequest(_ request: URLRequest, didFailWithError error: Error)
    func dfRequest(
        _ request: DFRequest, wasRedirectedTo urlRequest: URLRequest,
        redirectResponse: URLResponse
    )
    func dfRequest(
        _ request: DFRequest, didReceive response: URLResponse,
        cacheStoragePolicy policy: URLCache.StoragePolicy
    )
}
