import AppModels
import CryptoKit
import Foundation
import OSLogExt
import Sharing

private let logger = Logger(moduleName: "AnalyticsClient", category: "InstallSignalSender")

/// Sends the one install signal, once per install, at every analytics level (D-06b, D-06c).
///
/// The TelemetryDeck SDK cannot send it: every SDK signal carries the SDK's default payload (device,
/// OS, locale, region, time zone, screen, app version), and under Minimal the SDK is never
/// initialised. So this actor builds the one request itself, in the SDK's wire format, with seven
/// fields and a payload of exactly one key, `App.distributionChannel`. Nothing about the device is in it.
///
/// The format and the response handling are copied from TelemetryDeck SwiftSDK 2.14.2
/// (`Signals/SignalManager.swift` `send`, `getServiceUrl` and `ResponseDisposition`;
/// `Signals/Signal.swift` `SignalPostBody`; `Helpers/CryptoHashing.swift`;
/// `Helpers/JSONFormatting.swift` `telemetryEncoder`). An SDK upgrade must re-read those files
/// (Pitfall P-12); `InstallSignalSenderTests` pins the field list.
///
/// One request is in flight at a time (the actor and `isSending`). Once the server accepts the signal,
/// or rejects it for good, `InstallSignalState.settled` is persisted and nothing is sent again, in this
/// process or after a relaunch. A retryable failure is retried after 10 s, 20 s and 40 s, then waits
/// for the next ``ensureSent()`` (the next `apply`, at the next launch or level change).
actor InstallSignalSender {
    typealias Transport = @Sendable (URLRequest) async throws -> (data: Data, response: URLResponse)

    /// The ingest endpoint the SDK posts to when no namespace is configured.
    static let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")
    static let signalType = "App.installed"
    static let distributionChannelKey = "App.distributionChannel"
    /// The waits before the second, third and fourth attempt.
    static let retryDelays: [Duration] = [.seconds(10), .seconds(20), .seconds(40)]

    private let appID: String?
    private let salt: String
    private let transport: Transport
    private let now: @Sendable () -> Date
    private let uuid: @Sendable () -> UUID
    private let sleep: @Sendable (Duration) async throws -> Void
    private let distributionChannel: @Sendable () -> DistributionChannel
    private var isSending = false

    /// A nil `appID` makes a sender that never calls `transport` (Phase 14 D-13); a nil `salt` hashes
    /// with `""`, as the SDK does.
    init(
        appID: String?,
        salt: String?,
        transport: @escaping Transport,
        now: @escaping @Sendable () -> Date,
        uuid: @escaping @Sendable () -> UUID,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        distributionChannel: @escaping @Sendable () -> DistributionChannel
    ) {
        self.appID = appID
        self.salt = salt ?? ""
        self.transport = transport
        self.now = now
        self.uuid = uuid
        self.sleep = sleep
        self.distributionChannel = distributionChannel
    }

    /// Sends the install signal unless it has settled or a send is already running.
    ///
    /// The state is read from `@Shared(.installSignal)` here, in the caller's dependency context, never
    /// captured when the sender is made.
    func ensureSent() async {
        guard let appID, let endpoint = Self.endpoint, !isSending else { return }
        @Shared(.installSignal) var state
        guard !state.settled else { return }

        isSending = true
        defer { isSending = false }

        let clientUser = state.clientUser ?? Self.sha256Hex(uuid().uuidString + salt)
        if state.clientUser == nil {
            $state.withLock({ $0.clientUser = clientUser })
        }
        // Read once per call; this call's retries reuse it.
        let channel = distributionChannel()

        let body: Data
        do {
            body = try Self.encode(InstallSignalBody(
                receivedDate: now(),
                appID: appID,
                clientUser: clientUser,
                sessionID: uuid().uuidString,
                type: Self.signalType,
                payload: [Self.distributionChannelKey: channel.rawValue],
                isTestMode: Self.isTestMode
            ))
        } catch {
            logger.error("The install signal could not be encoded: \(error, privacy: .public)")
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        // The first attempt goes at once; each retry waits its delay first.
        let waits: [Duration?] = [nil] + Self.retryDelays.map({ $0 })
        for wait in waits {
            if let wait {
                do {
                    try await sleep(wait)
                } catch {
                    // Cancelled while waiting; the next `ensureSent()` tries again with the same user.
                    return
                }
            }

            switch await post(request) {
            case .settled:
                $state.withLock {
                    $0.settled = true
                    $0.clientUser = nil
                }
                return

            case .retry:
                continue
            }
        }
        logger.info("The install signal was not delivered; it is retried at the next apply.")
    }

    private enum Outcome {
        case settled
        case retry
    }

    private func post(_ request: URLRequest) async -> Outcome {
        let response: URLResponse
        do {
            response = try await transport(request).response
        } catch {
            logger.info("The install signal request failed: \(error, privacy: .public)")
            return .retry
        }
        switch Self.disposition(of: response) {
        case .success:
            return .settled

        case .drop:
            // The server refused it and retrying cannot help, so it settles without being counted.
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("The install signal was rejected with status \(status, privacy: .public).")
            return .settled

        case .retry:
            return .retry
        }
    }
}

// MARK: Wire format
extension InstallSignalSender {
    /// The SDK's `isTestMode` default: `"true"` in DEBUG builds, `"false"` in Release.
    static var isTestMode: String {
        #if DEBUG
        "true"
        #else
        "false"
        #endif
    }

    /// A one-element JSON array, dated as the SDK's `telemetryEncoder` dates it.
    static func encode(_ body: InstallSignalBody) throws -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(formatter)
        return try encoder.encode([body])
    }

    /// The SDK's user hash: the lowercase SHA-256 hex of the identifier followed by the salt.
    static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map({ String(format: "%02x", $0) })
            .joined()
    }

    enum Disposition: Equatable {
        case success
        case drop
        case retry
    }

    /// The SDK's response disposition: 2xx succeeds; 400, 401, 403, 404, 413, 422, 501 and 505 are
    /// dropped (the server rejected the signal and a retry cannot help); anything else is retried.
    static func disposition(of response: URLResponse) -> Disposition {
        guard let response = response as? HTTPURLResponse else { return .retry }
        switch response.statusCode {
        case 200...299:
            return .success

        case 400, 401, 403, 404, 413, 422, 501, 505:
            return .drop

        default:
            return .retry
        }
    }
}

/// The SDK's `SignalPostBody` without `floatValue`: exactly these seven fields, so nothing else can
/// be added to the request by accident.
struct InstallSignalBody: Encodable {
    let receivedDate: Date
    let appID: String
    let clientUser: String
    let sessionID: String
    let type: String
    let payload: [String: String]
    let isTestMode: String

    private enum CodingKeys: String, CodingKey {
        case receivedDate = "receivedAt"
        case appID
        case clientUser
        case sessionID
        case type
        case payload
        case isTestMode
    }
}

// MARK: Live
extension InstallSignalSender {
    /// An ephemeral session that keeps no cookies and no cache, so the request carries nothing from
    /// any earlier one.
    static let liveTransport: Transport = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        return { request in
            let (data, response) = try await session.data(for: request)
            return (data: data, response: response)
        }
    }()
}

/// The analytics client's handle on the install signal. `ensureSent` starts a send in the background
/// and returns at once, so `apply` stays synchronous; tests replace it with a recorder.
struct InstallSignalTrigger: Sendable {
    var ensureSent: @Sendable () -> Void
}

extension InstallSignalTrigger {
    static func live(_ sender: InstallSignalSender) -> Self {
        Self(ensureSent: {
            Task {
                await sender.ensureSent()
            }
        })
    }
}
