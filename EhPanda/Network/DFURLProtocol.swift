//
//  DFURLProtocol.swift
//  EhPanda
//

import Foundation

class DFURLProtocol: URLProtocol {
    private var dfRequest: DFRequest?
    static let requestIdentifier = "DomainFrontingRequest"

    override class func canonicalRequest(
        for request: URLRequest) -> URLRequest { request }
    override class func canInit(with request: URLRequest) -> Bool {
        if property(forKey: requestIdentifier, in: request) != nil {
            Logger.error("URLRequest has been initialized.")
            return false
        }
        if !["http", "https"].contains(request.url?.scheme) {
            let scheme = request.url?.scheme ?? "nil"
            Logger.error("URL scheme \"\(scheme)\" is not supported.")
            return false
        }
        return true
    }

    override func startLoading() {
        dfRequest = DFRequest(request, delegate: self)
        let request = request as? NSMutableURLRequest
        DFURLProtocol.setProperty(
            true, forKey: DFURLProtocol.requestIdentifier,
            in: request.forceUnwrapped
        )

        dfRequest?.resume()
    }

    override func stopLoading() {
        dfRequest?.stop()
        dfRequest = nil
    }
}

// MARK: DFRequestDelegate
extension DFURLProtocol: DFRequestDelegate {
    func dfRequestDidFinishLoading(_ request: DFRequest) {
        client?.urlProtocolDidFinishLoading(self)
    }
    func dfRequest(_ request: DFRequest, didLoad data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }
    func dfRequest(_ request: URLRequest, didFailWithError error: Error) {
        client?.urlProtocol(self, didFailWithError: error)
    }
    func dfRequest(
        _ request: DFRequest, wasRedirectedTo urlRequest: URLRequest,
        redirectResponse: URLResponse
    ) {
        client?.urlProtocol(self, wasRedirectedTo: urlRequest, redirectResponse: redirectResponse)
    }
    func dfRequest(
        _ request: DFRequest, didReceive response: URLResponse,
        cacheStoragePolicy policy: URLCache.StoragePolicy
    ) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: policy)
    }
}
