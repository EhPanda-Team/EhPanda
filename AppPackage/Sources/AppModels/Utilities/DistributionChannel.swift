import Foundation

/// Which release this copy of the app is, as one value of a small fixed set: the channel stamped
/// into the app's Info.plist under ``infoPlistKey`` (Phase 20 D-12; owner msgs 2533, 2537, 2552).
///
/// The release workflows build once, unsigned, and `actions-tool/package-channel.sh` copies the app
/// once per channel and overwrites the stamp in each copy, so the copies differ only in this value.
/// `App/Info.plist` reads the stamp from a build setting that is `source` by default
/// (`Config/Flavor.xcconfig`), so a build that no release workflow made says so.
/// The signed AltStore PAL build cannot be stamped after signing, so its flavor sets the setting
/// instead (`Config/Marketplace.xcconfig`). Only the app carries the stamp; the share extension
/// sends nothing.
///
/// The install signal reports it as `App.distributionChannel` (D-06c). The set is closed on purpose:
/// a stamp that is not one of these raw values, compared exactly, counts as ``source``, so nothing
/// stamped into a copy can put an unbounded or crafted string into an analytics payload (T-18-21).
/// The raw values are dashboard values: a channel may be added, never respelled.
public enum DistributionChannel: String, CaseIterable, Sendable {
    /// `EhPanda-GitHub.ipa` on the GitHub release, installed by hand (`deploy.yml`).
    case github
    /// `EhPanda-AltStore.ipa`, listed on the AltStore Classic source `AltStore.json` (`deploy.yml`).
    case altstore
    /// `EhPanda-SideStore.ipa`, listed on the SideStore source `SideStore.json` (`deploy.yml`).
    case sidestore
    /// The AltStore PAL build (Phase 20), stamped at build time by `Config/Marketplace.xcconfig`.
    case altstorePAL
    /// `EhPanda-Beta.ipa`, the separate beta install listed on `AltStoreBeta.json` (`deploy-beta.yml`).
    case beta
    /// A build that no release workflow made: someone built it from the source code. Also any build
    /// whose stamp is missing or not on the allow-list.
    case source

    /// The Info.plist key the release workflows stamp.
    public static let infoPlistKey = "EhPandaDistributionChannel"

    /// The channel stamped into the running app.
    public static var current: Self {
        Self(infoPlistValue: { Bundle.main.object(forInfoDictionaryKey: $0) })
    }

    /// The channel stamped as `value`; ``source`` when the value is absent, not a string, or not on
    /// the allow-list.
    public init(stampedValue value: Any?) {
        self = (value as? String).flatMap(Self.init(rawValue:)) ?? .source
    }

    /// The channel stamped under ``infoPlistKey`` in the Info.plist that `infoPlistValue` reads.
    public init(infoPlistValue: (String) -> Any?) {
        self.init(stampedValue: infoPlistValue(Self.infoPlistKey))
    }
}
