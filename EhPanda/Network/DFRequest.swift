//
//  DFRequest.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/13.
//

import Foundation

struct DFRequest {
    var request: URLRequest
    private let stream: InputStream
    private(set) weak var delegate: DFRequestDelegate?
    private lazy var streamHandler: DFStreamEventHandler?
        = DFStreamEventHandler(request: self)

    init?(
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

    mutating func resume() {
        print("Request from: \(request.url?.absoluteString ?? "")")

        stream.schedule(in: RunLoop.current, forMode: .common)
        stream.delegate = streamHandler
        stream.open()
    }

    mutating func stop() {
        stream.delegate = nil
        streamHandler = nil
        stream.close()
        delegate = nil
    }
}

// MARK: DFRequestDelegate
protocol DFRequestDelegate: AnyObject {
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
