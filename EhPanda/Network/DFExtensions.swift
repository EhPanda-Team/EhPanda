//
//  DFExtensions.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/13.
//

import Foundation
import SwiftyBeaver

// MARK: Global
private func forceDowncast<T>(object: Any) -> T {
    if let downcastedValue = object as? T {
        return downcastedValue
    }
    fatalError()
}

// MARK: URL
extension URL {
    func replaceHost(to newHost: String) -> URL? {
        guard let originalHost = host else { return nil }
        return URL(string: absoluteString.replacingOccurrences(
            of: originalHost, with: newHost
        ))
    }
}

// MARK: URLRequest
extension URLRequest {
    var urlContainsImageURL: Bool {
        var containsTarget = false
        ["jpg", "jpeg", "png", "gif", "bmp"].forEach { type in
            if url?.absoluteString.contains(type) == true {
                containsTarget = true
            }
        }
        return containsTarget
    }
}

// MARK: URLSessionConfiguration
extension URLSessionConfiguration {
    static var domainFronting: URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [DFURLProtocol.self]
        return config
    }
}

// MARK: CFHTTPMessage
extension CFHTTPMessage {
    var isCompleted: Bool {
        CFHTTPMessageIsHeaderComplete(self)
    }
    var url: URL? {
        CFHTTPMessageCopyRequestURL(self)?.autorelease()
            .takeUnretainedValue() as URL?
    }
    var allHeaderFields: [String: String] {
        CFHTTPMessageCopyAllHeaderFields(self)?.autorelease()
            .takeUnretainedValue() as? [String: String] ?? [String: String]()
    }
    func httpResponse() -> HTTPURLResponse? {
        guard let url = url as URL? else { return nil }
        let version = CFHTTPMessageCopyVersion(self)
            .autorelease().takeUnretainedValue() as String
        let code = CFHTTPMessageGetResponseStatusCode(self) as Int

        return HTTPURLResponse(
            url: url,
            statusCode: code,
            httpVersion: version,
            headerFields: allHeaderFields
        )
    }
}

// MARK: URLRequest
extension URLRequest {
    var isHTTPS: Bool { url?.scheme == "https" }
    var hasHostField: Bool { hostKey?.count ?? 0 > 0 }
    var hostKey: Dictionary<String, String>.Keys.Element? {
        allHTTPHeaderFields?.keys.first(where: { $0.lowercased() == "host" })
    }
    var domain: String? {
        var domain: String? = url?.host

        if let allFields = allHTTPHeaderFields, let hostKey = hostKey {
            domain = allFields[hostKey]
        }

        return domain
    }
    var domainWithScheme: String? {
        if let scheme = url?.scheme, let domain = domain {
            return scheme + "://" + domain
        } else {
            return nil
        }
    }
    func domainIPReplaced() -> URLRequest {
        var request: URLRequest = self

        guard let domain = domain,
              let resolvedIP = DomainResolver
                .resolve(domain: domain),
              let url = request.url?.replaceHost(
                to: resolvedIP
              )
        else { return request }

        request.url = url

        if hasHostField == false {
            request.addValue(domain, forHTTPHeaderField: "Host")
        }
        return request
    }
    func HTTPBody() -> Data? {
        if httpMethod != "POST" ||
            httpBody != nil { return httpBody }

        guard let stream = httpBodyStream
        else { return nil }

        stream.open()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>
            .allocate(capacity: bufferSize)
        defer {
            stream.close()
            buffer.deallocate()
            buffer.deinitialize(count: bufferSize)
        }

        var body = Data()
        var readSize = 0
        while readSize > 0 {
            if stream.hasBytesAvailable == false { break }

            readSize = stream.read(buffer, maxLength: bufferSize)
            if readSize > 0 {
                body.append(buffer, count: readSize)
            } else if readSize == 0 {
                SwiftyBeaver.verbose("HTTPBodyStream read EOF.")
            } else {
                if let error = stream.streamError as Error? {
                    SwiftyBeaver.error("HTTPBodyStream read Error: \(error).")
                }
            }
        }

        return body
    }
}

// MARK: InputStream
extension InputStream {
    enum CreateStreamError: Error {
        case methodNotFound(msg: String)
        case urlNotFound(msg: String)
        case createStream(msg: String)
    }

    var trust: SecTrust? {
        let key = Stream.PropertyKey(kCFStreamPropertySSLPeerTrust as String)
        guard let value = property(forKey: key) else { return nil }
        return forceDowncast(object: value) as SecTrust
    }
    func invalidatesCertChain(for host: String) {
        guard host.count > 0 else { return }
        let settings: [AnyHashable: Any] = [
            kCFStreamSSLValidatesCertificateChain: kCFBooleanFalse as Any
        ]

        let key = kCFStreamPropertySSLSettings as String
        setProperty(settings, forKey: Stream.PropertyKey(key))
    }
    func httpMessage() -> CFHTTPMessage? {
        let stream = self as CFReadStream

        let key = "kCFStreamPropertyHTTPResponseHeader" as CFString
        guard let value = CFReadStreamCopyProperty(
            stream, CFStreamPropertyKey(rawValue: key)
        ) else { return nil }

        return forceDowncast(object: value) as CFHTTPMessage
    }

    static func create(from request: URLRequest) -> Result<InputStream, CreateStreamError> {
        guard let method = request.httpMethod as CFString? else {
            return .failure(.methodNotFound(
                msg: "HTTPMethod not found: \(request.httpMethod ?? "nil")."
            ))
        }
        guard let url = request.url as CFURL? else {
            return .failure(.urlNotFound(
                msg: "URL not found: \(request.url?.absoluteString ?? "nil")."
            ))
        }

        let message = CFHTTPMessageCreateRequest(
            kCFAllocatorDefault, method,
            url, kCFHTTPVersion1_1
        )
        .autorelease()
        .takeUnretainedValue()

        request.allHTTPHeaderFields?.forEach { field, value in
            CFHTTPMessageSetHeaderFieldValue(
                message, field as CFString,
                value as CFString
            )
        }

        if request.hasHostField == false {
            CFHTTPMessageSetHeaderFieldValue(
                message, "host" as CFString,
                request.domain as CFString?
            )
        }

        if let body = request.HTTPBody() as CFData? {
            CFHTTPMessageSetBody(message, body)
        }

        guard let stream = CFReadStreamCreateForHTTPRequest(
            kCFAllocatorDefault, message
        )
        .autorelease()
        .takeUnretainedValue() as InputStream? else {
            return .failure(.createStream(msg: "Create Stream error."))
        }

        let key = "kCFStreamPropertyHTTPAttemptPersistentConnection" as CFString
        stream.setProperty(true, forKey: key as Stream.PropertyKey)

        return .success(stream)
    }
}
