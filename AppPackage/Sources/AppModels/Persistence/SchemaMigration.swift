import Foundation
import OSLogExt

private let logger = Logger(category: "SchemaMigration")

/// A single forward step in a model's schema history: it rewrites the raw JSON object of the previous
/// version into the shape of this version — "fetch this key, create that key, set this value".
///
/// The `Model` parameter is a phantom that ties a map list to its model type; the transform itself only
/// touches the JSON. `.passthrough` is the identity map and is only valid at index 0 (the v1 slot),
/// since v1 has no earlier version to migrate from.
public struct SchemaMigration<Model>: Sendable {
    let isPassthrough: Bool
    let transform: @Sendable (inout [String: JSONValue]) throws -> Void

    /// A real migration from the previous version to this one.
    public init(_ transform: @escaping @Sendable (inout [String: JSONValue]) throws -> Void) {
        self.isPassthrough = false
        self.transform = transform
    }

    private init(passthrough: Bool) {
        self.isPassthrough = passthrough
        self.transform = { _ in }
    }

    /// The identity map — no migration. Only valid in the v1 slot (index 0).
    public static var passthrough: Self { Self(passthrough: true) }
}

/// A model that migrates older persisted blobs forward *in decode*.
///
/// Adopt this only once a model gains a real v2 (before that, a v1 model keeps synthesized/identity
/// `Codable` and just lists `migrations = [.passthrough]`). A conformer provides:
///   • `migrations` — the ordered maps (see `SchemaVersioned`),
///   • `init(currentFrom:)` — a decoder for the *current* shape only, and
///   • `init(from:)` as the one-line `self = try SchemaMigrator.migrate(Self.self, from: decoder)`.
/// The engine reads the stored version, applies the chain up to `currentSchemaVersion`, and then decodes
/// the current shape through `init(currentFrom:)`.
public protocol MigratableModel: Codable, SchemaVersioned {
    /// Decode the *current* schema shape. Called by the engine after the blob has been migrated forward;
    /// it must not re-enter migration (do not call `SchemaMigrator.migrate` here).
    init(currentFrom decoder: Decoder) throws
}

/// Applies a model's ordered migration chain to a raw blob, then decodes the migrated result.
public enum SchemaMigrator {
    /// Wraps `init(currentFrom:)` so the engine can decode the current shape without re-entering
    /// `Model.init(from:)` (which would recurse back into migration).
    private struct CurrentShape<Model: MigratableModel>: Decodable {
        let value: Model
        init(from decoder: Decoder) throws {
            value = try Model(currentFrom: decoder)
        }
    }

    /// Decode `Model` from a possibly-older blob: read its `schemaVersion`, apply every map from that
    /// version up to the current one in order, then decode the current shape.
    public static func migrate<Model: MigratableModel>(
        _ type: Model.Type, from decoder: Decoder
    ) throws -> Model {
        var object = try [String: JSONValue](from: decoder)
        let stored = object["schemaVersion"]?.intValue ?? 1
        let current = Model.currentSchemaVersion
        guard (1...current).contains(stored) else {
            let message = "\(Model.self) schemaVersion \(stored) is outside the supported range 1...\(current)"
            logger.error("\(message, privacy: .public)")
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: message))
        }
        // migrations[k] produces version k+1, so migrating stored → current applies migrations[stored..<current].
        for index in stored..<current {
            try Model.migrations[index].transform(&object)
        }
        object["schemaVersion"] = .int(current)
        let migratedData = try JSONEncoder().encode(object)
        return try JSONDecoder().decode(CurrentShape<Model>.self, from: migratedData).value
    }
}
