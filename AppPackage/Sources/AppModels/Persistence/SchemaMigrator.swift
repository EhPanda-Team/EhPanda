import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: SchemaMigrator.self))

/// A model that migrates older persisted blobs forward *in decode*.
///
/// Adopt this only once a model gains a real v2 (before that, a v1 model keeps synthesized/identity
/// `Codable` and just lists `schemas = [SchemaV1.self]`). A conformer provides:
///   • `schemas` — the ordered schema history (see `SchemaVersioned` / `VersionedSchema`),
///   • `init(currentFrom:)` — a decoder for the *current* shape only, and
///   • `init(from:)` as the one-line `self = try SchemaMigrator.migrate(Self.self, from: decoder)`.
/// The engine reads the stored version, walks every schema newer than it up to `currentSchemaVersion`,
/// then decodes the current shape through `init(currentFrom:)`.
public protocol MigratableModel: Codable, SchemaVersioned {
    /// Decode the *current* schema shape. Called by the engine after the blob has been migrated forward;
    /// it must not re-enter migration (do not call `SchemaMigrator.migrate` here).
    init(currentFrom decoder: Decoder) throws
}

/// Walks a model's ordered schema history over a raw blob, then decodes the migrated result.
public enum SchemaMigrator {
    /// Wraps `init(currentFrom:)` so the engine can decode the current shape without re-entering
    /// `Model.init(from:)` (which would recurse back into migration).
    private struct CurrentShape<Model: MigratableModel>: Decodable {
        let value: Model
        init(from decoder: Decoder) throws {
            value = try Model(currentFrom: decoder)
        }
    }

    /// Decode `Model` from a possibly-older blob: read its `schemaVersion`, ask every schema newer than
    /// it to migrate the object forward in order, then decode the current shape.
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
        // `schemas` is ordered v1…vN; each newer than `stored` maps the previous version into itself, so
        // walking them in order chains stored → current (v1→v2→v3…).
        for schema in Model.schemas where schema.version > stored {
            try schema.migrate(&object)
        }
        object["schemaVersion"] = .int(current)
        let migratedData = try JSONEncoder().encode(object)
        return try JSONDecoder().decode(CurrentShape<Model>.self, from: migratedData).value
    }
}
