import AppModels
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
    let make: Make
    let prepare: Prepare?
    let interact: Interact?
    /// The fewest identical reads its pictures settle on (``HostedWindowCapture/settle(_:minimumReads:)``).
    let minimumReads: Int

    init(
        signedIn: Bool = true, make: @escaping Make, prepare: Prepare? = nil, interact: Interact? = nil,
        minimumReads: Int = HostedWindowCapture.minimumReads
    ) {
        self.signedIn = signedIn
        self.make = make
        self.prepare = prepare
        self.interact = interact
        self.minimumReads = minimumReads
    }
}

/// One group file's registrations and the plan that fills it (19-02): `ScenarioCatalog+Browsing.swift` (19-05),
/// `+Library.swift` (19-06), `+Gallery.swift` (19-07) and `+Settings.swift` (19-08), so those plans never edit the
/// same file.
struct ScenarioGroup {
    let plan: String
    let factories: [String: ScenarioFactory]
}

/// Scenario ID → factory. Every registered ID must be in `scenarios.json` under the plan of its group file
/// (`ScenarioInventoryTests`).
enum ScenarioCatalog {
    static var groups: [ScenarioGroup] {
        [
            ScenarioGroup(plan: "19-05", factories: browsing),
            ScenarioGroup(plan: "19-06", factories: library),
            ScenarioGroup(plan: "19-07", factories: gallery),
            ScenarioGroup(plan: "19-08", factories: settings)
        ]
    }

    /// Every group's factories. An ID registered twice keeps its first factory; `ScenarioInventoryTests` fails.
    static var factories: [String: ScenarioFactory] {
        groups.reduce(into: [:]) { result, group in
            result.merge(group.factories) { first, _ in first }
        }
    }

    static var registeredIDs: Set<String> {
        Set(factories.keys)
    }

    static func factory(_ id: String) throws -> ScenarioFactory {
        guard let factory = factories[id] else { throw ScenarioCatalogError.unregistered(id) }
        return factory
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
        let factory = try ScenarioCatalog.factory(id)
        try await factory.prepare?()
        try await capture(scenario: id, factory: factory)
    }
}
