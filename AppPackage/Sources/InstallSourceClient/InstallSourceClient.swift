public import Dependencies
public import MarketplaceKit

/// Where this copy of the app was installed from, as one value of a small fixed set (D-06c).
///
/// The set is closed on purpose: whatever a distributor reports is reduced to one of these six
/// values before it can travel, so an unbounded or crafted string can never reach an analytics
/// payload (T-18-21). A marketplace's bundle ID names the store, not the user.
public enum InstallSource: Equatable, Sendable {
    case appStore
    case testFlight
    /// An alternative marketplace, by the bundle ID MarketplaceKit reports for it.
    case marketplace(String)
    case web
    case other
    /// MarketplaceKit could not answer, reported a case this build does not know, or reported a
    /// marketplace ID that is not a plausible bundle ID; also every simulator build.
    case unknown

    /// The spelling sent on the wire: `appStore`, `testFlight`, `marketplace:<id>`, `web`, `other`
    /// or `unknown`. These are dashboard values, so a case may be added but never respelled.
    public var wireValue: String {
        switch self {
        case .appStore:
            "appStore"

        case .testFlight:
            "testFlight"

        case .marketplace(let id):
            "marketplace:\(id)"

        case .web:
            "web"

        case .other:
            "other"

        case .unknown:
            "unknown"
        }
    }
}

/// Answers ``InstallSource`` for the running app. The only code in the app that reads MarketplaceKit.
///
/// The install signal (D-06b) asks it once per send. Phase 20's ANALYTICS-02 reuses the same client
/// for the Basic and Full signals and verifies the mapping on the real marketplace build.
public struct InstallSourceClient: Sendable {
    public var current: @Sendable () async -> InstallSource

    public init(current: @escaping @Sendable () async -> InstallSource) {
        self.current = current
    }
}

extension InstallSourceClient {
    /// The longest bundle ID App Store Connect accepts.
    private static let maximumMarketplaceIDLength = 155

    /// Maps a distributor to its ``InstallSource``.
    ///
    /// A marketplace ID is kept only when it is a plausible bundle ID: 1 to 155 characters, each an
    /// ASCII letter, digit, `.` or `-`. Anything else, and any case added in a later SDK, is
    /// ``InstallSource/unknown``.
    public static func map(_ distributor: AppDistributor) -> InstallSource {
        switch distributor {
        case .appStore:
            return .appStore

        case .testFlight:
            return .testFlight

        case .marketplace(let id):
            return isPlausibleBundleID(id) ? .marketplace(id) : .unknown

        case .web:
            return .web

        case .other:
            return .other

        @unknown default:
            return .unknown
        }
    }

    private static func isPlausibleBundleID(_ id: String) -> Bool {
        guard (1...maximumMarketplaceIDLength).contains(id.unicodeScalars.count) else { return false }
        return id.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9", ".", "-":
                true

            default:
                false
            }
        }
    }

    /// The live client. A simulator build answers ``InstallSource/unknown`` and any other DEBUG build
    /// answers ``InstallSource/other``, both without asking MarketplaceKit, so a development install is
    /// never counted as a store install (D-06c). A thrown error is ``InstallSource/unknown``.
    public static let live = Self(current: {
        #if targetEnvironment(simulator)
        return .unknown
        #elseif DEBUG
        return .other
        #else
        do {
            return map(try await AppDistributor.current)
        } catch {
            // MarketplaceKit could not say; the signal still counts the install, from an unknown source.
            return .unknown
        }
        #endif
    })

    /// Always ``InstallSource/unknown``: tests and previews never report a store.
    public static let unknown = Self(current: { .unknown })
}

// MARK: API
extension InstallSourceClient: DependencyKey {
    public static let liveValue = InstallSourceClient.live
    public static let previewValue = InstallSourceClient.unknown
    public static let testValue = InstallSourceClient.unknown
}

extension DependencyValues {
    public var installSourceClient: InstallSourceClient {
        get { self[InstallSourceClient.self] }
        set { self[InstallSourceClient.self] = newValue }
    }
}
