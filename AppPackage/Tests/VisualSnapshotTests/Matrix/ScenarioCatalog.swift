import AppModels
import CookieClient
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport

/// One scenario's real view: how to build it, whether it is signed in, what it loads before hosting (synthetic
/// artwork into the image cache), and the user step, if any, that brings the hosted view to its state.
struct ScenarioFactory {
    typealias Make = @MainActor () throws -> AnyView
    typealias Prepare = @MainActor () async throws -> Void
    typealias Interact = @MainActor (UIWindow) async throws -> Void

    let signedIn: Bool
    /// The cookie jar the scenario reads, when its cookies are themselves on screen; otherwise a signed-in scenario
    /// reads the preview client and a signed-out one an empty jar.
    let cookies: CookieClient?
    let make: Make
    let prepare: Prepare?
    let interact: Interact?
    /// The fewest identical reads its pictures settle on (``HostedWindowCapture/settle(_:minimumReads:)``).
    let minimumReads: Int

    init(
        signedIn: Bool = true, cookies: CookieClient? = nil, make: @escaping Make, prepare: Prepare? = nil,
        interact: Interact? = nil, minimumReads: Int = HostedWindowCapture.minimumReads
    ) {
        self.signedIn = signedIn
        self.cookies = cookies
        self.make = make
        self.prepare = prepare
        self.interact = interact
        self.minimumReads = minimumReads
    }
}

/// One group file's registrations and the plan that fills it (19-02): `ScenarioCatalog+Browsing.swift` (19-05),
/// `+Library.swift` (19-06), `+Gallery.swift` (19-07) and `+Settings.swift` (19-08), so those plans never edit the
/// same file. The states not yet moved into a `Snapshots/` provider (19-18) are still registered here.
struct ScenarioGroup {
    let plan: String
    let factories: [String: ScenarioFactory]
}

/// Scenario ID → state. Every registered ID must be in `scenarios.json` (`ScenarioInventoryTests`).
enum ScenarioCatalog {
    /// Every view's snapshot provider (19-18), one line each. Swift has no type discovery, so a new provider is
    /// listed here; `ScenarioInventoryTests` fails until the inventory and the list agree.
    static var providers: [any SnapshotProvider.Type] {
        [
            SettingViewSnapshot.self
        ]
    }

    static var groups: [ScenarioGroup] {
        [
            ScenarioGroup(plan: "19-05", factories: browsing),
            ScenarioGroup(plan: "19-06", factories: library),
            ScenarioGroup(plan: "19-07", factories: gallery),
            ScenarioGroup(plan: "19-08", factories: settings)
        ]
    }

    /// Every provider's states, then the group registrations not yet moved, each with the screen's own height. An ID
    /// declared twice appears twice: ``state(_:)`` keeps the first, and `ScenarioInventoryTests` fails.
    @MainActor
    static var states: [SnapshotState] {
        providers.flatMap({ $0.states }) + groups.flatMap({ group in
            group.factories.map({ SnapshotState(id: $0.key, heights: .screen, factory: $0.value) })
        })
    }

    @MainActor
    static var registeredIDs: Set<String> {
        Set(states.map(\.id))
    }

    @MainActor
    static func state(_ id: String) throws -> SnapshotState {
        guard let state = states.first(where: { $0.id == id }) else { throw ScenarioCatalogError.unregistered(id) }
        return state
    }
}

enum ScenarioCatalogError: Error, Equatable {
    case unregistered(String)
    case missingFixture(String)
}

extension SnapshotMatrixCase {
    /// Captures the catalog's scenario `id`.
    @MainActor
    func capture(scenario id: String) async throws {
        let factory = try ScenarioCatalog.state(id).factory
        try await factory.prepare?()
        try await capture(scenario: id, factory: factory)
    }
}
