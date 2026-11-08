public import Dependencies
import Foundation
public import MarketplaceKit

/// Where this copy of the app was installed from, as one value of a small fixed set (D-06c).
///
/// The set is closed on purpose: whatever a distributor reports, and whatever is stamped into the
/// app's Info.plist, is reduced to one of these values before it can travel, so an unbounded or
/// crafted string can never reach an analytics payload (T-18-21). A marketplace's bundle ID names the
/// store, not the user.
public enum InstallSource: Equatable, Sendable {
    case appStore
    case testFlight
    /// An alternative marketplace, by the bundle ID MarketplaceKit reports for it. AltStore PAL is one.
    case marketplace(String)
    case web
    /// MarketplaceKit's `other`. The live client no longer reports it: it asks the app's
    /// ``DistributionChannel`` instead. The value stays, because the dashboard has it.
    case other
    /// The IPA from the GitHub release, installed by hand (`EhPanda-GitHub.ipa`).
    case github
    /// The IPA listed on the AltStore Classic source, `AltStore.json` (`EhPanda-AltStore.ipa`).
    case altstore
    /// The IPA listed on the SideStore source, `SideStore.json` (`EhPanda-SideStore.ipa`).
    case sidestore
    /// The beta build, a separate install listed on the beta AltStore source (`EhPanda-Beta.ipa`).
    case beta
    /// A build that no release workflow made: someone built it from the source code.
    case source
    /// MarketplaceKit could not answer, reported a case this build does not know, or reported a
    /// marketplace ID that is not a plausible bundle ID, and no channel named the build; also every
    /// simulator build.
    case unknown

    /// The spelling sent on the wire: `appStore`, `testFlight`, `marketplace:<id>`, `web`, `other`,
    /// `github`, `altstore`, `sidestore`, `beta`, `source` or `unknown`. These are dashboard values,
    /// so a case may be added but never respelled.
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

        case .github:
            "github"

        case .altstore:
            "altstore"

        case .sidestore:
            "sidestore"

        case .beta:
            "beta"

        case .source:
            "source"

        case .unknown:
            "unknown"
        }
    }
}

/// The distribution channel stamped into the app's Info.plist under ``infoPlistKey``. One unsigned
/// build is copied once per channel and each copy is stamped, so the copies differ only in this value
/// (owner msgs 2533, 2537).
///
/// The committed `App/Info.plist` says `source`, so a build that no release workflow made says so;
/// the workflows overwrite it in the packaged app (`actions-tool/package-channel.sh`). Only the app
/// carries it: the share extension never reports an install source.
///
/// A closed allow-list: a value that is not one of these raw values, compared exactly, is ignored as
/// if the key were absent, so nothing stamped into a copy can widen ``InstallSource``. A channel may
/// be added; a raw value is never respelled.
public enum DistributionChannel: String, CaseIterable, Sendable {
    /// `EhPanda-GitHub.ipa` on the GitHub release (`deploy.yml`).
    case github
    /// `EhPanda-AltStore.ipa`, listed on `AltStore.json` (`deploy.yml`).
    case altstore
    /// `EhPanda-SideStore.ipa`, listed on `SideStore.json` (`deploy.yml`).
    case sidestore
    /// The AltStore PAL build (Phase 20). MarketplaceKit names a PAL install itself, as
    /// `marketplace:<id>`; the stamp is only a cross-check and never overrides it.
    case altstorePAL
    /// `EhPanda-Beta.ipa`, listed on `altstore-beta.json` (`deploy-pre-release.yml`).
    case beta
    /// The committed value: any build that no release workflow stamped.
    case source

    /// The Info.plist key the workflows stamp.
    public static let infoPlistKey = "EhPandaDistributionChannel"

    /// The channel stamped as `value`, or nil when the value is absent, not a string, or not on the
    /// allow-list.
    public init?(stampedValue value: Any?) {
        guard let value = value as? String else { return nil }
        self.init(rawValue: value)
    }

    /// What this channel reports when MarketplaceKit says `other` or cannot answer.
    var installSource: InstallSource {
        switch self {
        case .github:
            .github

        case .altstore:
            .altstore

        case .sidestore:
            .sidestore

        case .beta:
            .beta

        case .source:
            .source

        case .altstorePAL:
            // A PAL install that MarketplaceKit does not name as a marketplace one is not trusted.
            .unknown
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

    /// The answer on a device, DEBUG and release builds alike, from what MarketplaceKit reported.
    ///
    /// Apple wins: a store MarketplaceKit names (the App Store, TestFlight, a marketplace, the web) is
    /// the answer, whatever the app is stamped with. When MarketplaceKit reports `other`, as it does
    /// for a sideloaded install such as AltStore Classic's, or throws, the ``DistributionChannel`` in the
    /// Info.plist names the build; a missing or unknown stamp is ``InstallSource/unknown``, and so is
    /// the `altstorePAL` stamp, which only MarketplaceKit can confirm.
    ///
    /// - Parameters:
    ///   - marketplaceKit: ``map(_:)`` of `AppDistributor.current`, or nil when it threw.
    ///   - infoPlistValue: reads a key from the app's Info.plist; asked only when MarketplaceKit
    ///     names no store.
    public static func deviceSource(
        marketplaceKit: InstallSource?,
        infoPlistValue: (String) -> Any?
    ) -> InstallSource {
        if let marketplaceKit, marketplaceKit != .other {
            return marketplaceKit
        }
        let channel = DistributionChannel(stampedValue: infoPlistValue(DistributionChannel.infoPlistKey))
        return channel?.installSource ?? .unknown
    }

    /// The live client. A simulator build answers ``InstallSource/unknown`` without asking
    /// MarketplaceKit, so a development install is never counted as a store install (D-06c). On a
    /// device it answers ``deviceSource(marketplaceKit:infoPlistValue:)``, so an Xcode install reports
    /// `source` from the committed stamp unless MarketplaceKit names a store for it.
    public static let live = Self(current: {
        #if targetEnvironment(simulator)
        return .unknown
        #else
        return deviceSource(
            marketplaceKit: await marketplaceKitSource(),
            infoPlistValue: { Bundle.main.object(forInfoDictionaryKey: $0) }
        )
        #endif
    })

    /// ``map(_:)`` of `AppDistributor.current`, or nil when MarketplaceKit could not say.
    ///
    /// `@concurrent`, like the property it reads: `AppDistributor` is not `Sendable`, so it is mapped
    /// where it is read and only the `Sendable` result returns to the caller.
    @concurrent
    private static func marketplaceKitSource() async -> InstallSource? {
        do {
            return map(try await AppDistributor.current)
        } catch {
            // MarketplaceKit could not say; the stamp may still name the build.
            return nil
        }
    }

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
