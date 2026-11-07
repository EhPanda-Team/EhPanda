import AppModels
import Foundation
import SwiftUI
import UIKit

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

    init(signedIn: Bool = true, make: @escaping Make, prepare: Prepare? = nil, interact: Interact? = nil) {
        self.signedIn = signedIn
        self.make = make
        self.prepare = prepare
        self.interact = interact
    }
}

/// Scenario ID → factory. Every registered ID must be in `scenarios.json` (`ScenarioInventoryTests`).
enum ScenarioCatalog {
    static var factories: [String: ScenarioFactory] {
        tracer
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
