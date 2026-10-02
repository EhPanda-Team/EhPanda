import Foundation

public struct PublicFixtureExport: Sendable {
    public let aggregateDigest: String
    public let manifestURL: URL
}

public enum PublicVisualFixtures {
    public static let schemaVersion = 1
    public static let fixtureVersion = "phase17-finite-v1"

    @MainActor
    public static func export(
        to directory: URL,
        scenarios: Data? = nil
    ) throws -> PublicFixtureExport {
        throw PublicFixtureError.exportNotImplemented
    }
}

public enum PublicFixtureError: Error {
    case exportNotImplemented
    case unknownFixture(String)
    case missingAsset(String)
    case missingRoute(String)
    case invalidScenarioCatalog
    case destinationNotEmpty
    case invalidSourceProvenance
    case imageEncodingFailed
}
