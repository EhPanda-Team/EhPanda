import Foundation
import AppModels
import OSLogExt

private let logger = Logger(category: .init(describing: DFStreamEventHandler.self))

public class DFStreamEventHandler: NSObject {
    private var request: DFRequest
    private var receivedResponse = false
    private var hasEvaluated = false

    public init(request: DFRequest) {
        self.request = request
    }
}

// MARK: Handlers
private extension DFStreamEventHandler {
    func readIfHasBytesAvailable(_ stream: InputStream) {
        let message = stream.httpMessage()
        guard message?.isCompleted == true else { return }

        if request.request.isHTTPS, hasEvaluated == false {
            let domain = request.request.domain
            if evaluate(stream.trust, domain: domain) {
                hasEvaluated = true
            } else {
                let err = NSError(
                    domain: "CFNetwork SSLHandshake failed",
                    code: -9870, userInfo: nil
                )
                request.delegate?.dfRequest(
                    request.request,
                    didFailWithError: err
                )
            }
        }

        if receivedResponse == false,
           let resp = message?.httpResponse() {
            receivedResponse = true
            request.delegate?.dfRequest(
                request, didReceive: resp,
                cacheStoragePolicy: .notAllowed
            )
        }

        guard stream.hasBytesAvailable else { return }
        let data = readData(from: stream)

        request.delegate?.dfRequest(request, didLoad: data)
    }

    func readData(from stream: InputStream) -> Data {
        var data = Data()

        let bufferSize = 1024 * 16
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        let readCount = stream.read(buffer, maxLength: bufferSize)
        if readCount > 0 { data.append(buffer, count: readCount) }

        buffer.deallocate()
        buffer.deinitialize(count: bufferSize)
        return data
    }

    func evaluate(_ serverTrust: SecTrust?, domain: String?) -> Bool {
        guard let serverTrust = serverTrust else { return false }

        var policies: [SecPolicy] = []
        if let domain = domain {
            policies.append(SecPolicyCreateSSL(true, domain as CFString))
        } else {
            policies.append(SecPolicyCreateBasicX509())
        }
        SecTrustSetPolicies(serverTrust, policies as CFArray)

        var error: CFError?
        if SecTrustEvaluateWithError(serverTrust, &error) {
            return true
        } else {
            logger.error("\(String(describing: error), privacy: .public)")
            return false
        }
    }
}

// MARK: StreamDelegate
extension DFStreamEventHandler: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard let input = aStream as? InputStream else {
            logger.error("Unexpected stream, should be a InputStream, but \(aStream, privacy: .public).")
            return
        }

        autoreleasepool {
            switch eventCode {
            case .openCompleted:
                openCompleted()
            case .hasBytesAvailable:
                readIfHasBytesAvailable(input)
            case .endEncountered:
                endEncountered(input)
            case .errorOccurred:
                errorOccurred(input)
            default:
                defaultHandle(event: eventCode)
            }
        }
    }
}

private extension DFStreamEventHandler {
    func openCompleted() {
        if !request.request.urlContainsImageURL {
            let urlString = request.request.url?.absoluteString ?? ""
            logger.debug("Stream open completed for: \(urlString).")
        }
    }

    func endEncountered(_ stream: InputStream) {
        if !request.request.urlContainsImageURL {
            let urlString = request.request.url?.absoluteString ?? ""
            logger.debug("Stream end off for: \(urlString).")
        }

        let message = stream.httpMessage()

        let finish = {
            if stream.streamError != nil {
                self.errorOccurred(stream)
            } else {
                if !self.request.request.urlContainsImageURL {
                    let urlString = self.request.request.url?.absoluteString ?? ""
                    logger.debug("Request loading finished for: \(urlString).")
                }
                self.request.delegate?.dfRequestDidFinishLoading(self.request)
            }
        }

        guard let resp = message?.httpResponse() else {
            finish()
            return
        }
        let statusCode = resp.statusCode

        if statusCode >= 300 && statusCode < 400 {
            guard let headerFields = message?.allHeaderFields,
                  let hostKey = headerFields.keys
                    .first(where: { $0.lowercased() == "location" }),
                  let loction = headerFields[hostKey],
                  var url = URL(string: loction)
            else {
                finish()
                return
            }

            if ["/", "/popular", "/watched"].contains(url.absoluteString)
                || ["/?f_search"].contains(where: url.absoluteString.contains),
               let domain = request.request.domainWithScheme,
               let originalURL = URL(string: domain) {
                url = originalURL.appendingPathComponent(url.absoluteString)
            }

            logger.warning("Request redirected to: \(url.absoluteString).")

            var req = URLRequest(url: url)
            req.httpMethod = "GET"

            request.delegate?.dfRequest(
                request,
                wasRedirectedTo: req,
                redirectResponse: resp
            )
        } else {
            finish()
        }
    }

    func errorOccurred(_ stream: Stream) {
        if let err = stream.streamError as NSError? {
            if !request.request.urlContainsImageURL {
                let urlString = request.request.url?.absoluteString ?? ""
                logger.error("\(stream, privacy: .public) Occurred error: \(err, privacy: .public) for: \(urlString).")
            }
            request.delegate?.dfRequest(
                request.request,
                didFailWithError: err
            )
        }
        request.stop()
    }

    func defaultHandle(event: Stream.Event) {
        logger.error("An unexpected event: \(String(describing: event), privacy: .public) occurred.")
    }
}
