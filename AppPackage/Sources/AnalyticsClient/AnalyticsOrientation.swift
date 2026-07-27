import DeviceClient
import Dispatch
import Foundation
import Synchronization
import TelemetryDeck

/// Supplies `TelemetryDeck.Device.orientation`, which the SDK itself reports as `"Unknown"` on
/// every signal this app sends.
///
/// The vendor reads `UIDevice.current.orientation` (SwiftSDK 2.14.1,
/// `Signals/Signal+Helpers.swift`) and maps anything that is not a portrait or landscape case to
/// `"Unknown"`. Apple documents that property as always returning `.unknown` until something calls
/// `beginGeneratingDeviceOrientationNotifications()`; neither the SDK nor this app ever does, so
/// the default arm always wins. The read has been in the SDK since 2024-04-25 and survived four
/// refactors, including the V3 rewrite, so it is not about to change on its own — no issue upstream
/// raises it as of 2026-07-27.
///
/// Enabling those notifications would be the smaller change and is deliberately not what happens
/// here: it powers up motion hardware to feed a metric nobody reads, reverses Phase 5's removal of
/// the app's orientation machinery, and would still answer the wrong question — `UIDevice`
/// orientation is where the *device* is pointing, so a tablet flat on a desk reports `.faceUp` and
/// lands back on `"Unknown"`. ``InterfaceOrientation`` reads the window scene instead.
///
/// A `SignalEnricher` is the seam that works. The SDK assembles each payload as
/// `builtIns.applying(enrichedMetadata).applying(perSignalParameters)` (`SignalManager.swift`), and
/// `applying` lets the argument win, so an enricher overrides a built-in. `Config.defaultParameters`
/// would not: it is screened for the reserved `TelemetryDeck.` prefix and logs an error for any key
/// carrying it.
final class OrientationEnricher: SignalEnricher {
    /// The vendor's own spellings, matched exactly.
    ///
    /// Not this module's usual "raw value equals case name" convention, because these values are
    /// not ours to name: the dashboard has been grouping `"Portrait"` and `"Landscape"` from other
    /// SDKs and platforms all along, and a lowercased spelling here would silently open a second
    /// column beside the first rather than filling in the one that reads `"Unknown"` today.
    static func vendorName(for orientation: InterfaceOrientation) -> String {
        switch orientation {
        case .portrait:
            return "Portrait"
        case .landscape:
            return "Landscape"
        }
    }

    private let read: @MainActor @Sendable () -> InterfaceOrientation?
    private let cached = Mutex<InterfaceOrientation?>(nil)

    init(read: @escaping @MainActor @Sendable () -> InterfaceOrientation?) {
        self.read = read
    }

    /// Reads the scene graph and stores the answer for the next `enrich` call.
    ///
    /// The hop exists because `enrich` is called on a utility queue while the scene graph is
    /// main-actor state, so the value cannot be fetched where it is needed. Refreshing per signal
    /// rather than observing rotation keeps this free of notification plumbing; the cost is that a
    /// device rotated between two signals is reported from the next signal on. In practice even
    /// that gap closes, because the SDK's own payload assembly hops through the main queue after
    /// this refresh is enqueued, and the queue is FIFO.
    func refresh() {
        if Thread.isMainThread {
            MainActor.assumeIsolated({ store() })
        } else {
            DispatchQueue.main.async(execute: { [self] in MainActor.assumeIsolated({ store() }) })
        }
    }

    @MainActor
    private func store() {
        let orientation = read()
        cached.withLock({ $0 = orientation })
    }

    /// Returns no key at all when the orientation is unknown, rather than a `"Unknown"` of its own.
    ///
    /// Staying silent leaves the SDK's built-in value in place, so an absent answer is reported by
    /// exactly one writer instead of two agreeing by coincidence.
    func enrich(signalType: String, for clientUser: String?, floatValue: Double?) -> [String: String] {
        guard let orientation = cached.withLock({ $0 }) else { return [:] }
        return ["TelemetryDeck.Device.orientation": Self.vendorName(for: orientation)]
    }
}
