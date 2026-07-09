import Foundation

/// One schema version of a persisted model: its version number and how the *previous* version's raw
/// JSON becomes this one.
///
/// Declared oldest → newest in `SchemaVersioned.schemas`; the `SchemaMigrator` engine walks them to
/// bring an old blob forward one hop at a time. This is the raw-JSON analog of SwiftData's
/// `VersionedSchema` fused with a `.custom` migration stage — we migrate a JSON blob rather than a
/// typed store, so a schema carries just its version and its map (no per-version model snapshot, and
/// no lightweight/auto-inferred stage, because there is no typed store to infer against).
public protocol VersionedSchema {
    /// This schema's version number. Across a model's `schemas`, versions run `1, 2, … n` — ascending,
    /// contiguous, starting at 1.
    static var version: Int { get }

    /// Rewrite the previous version's decoded object into this version's shape — "fetch this key,
    /// create that key, set this value". The base schema (version 1) has nothing before it, so its
    /// body is empty and the engine never invokes it (it only runs schemas whose `version` exceeds the
    /// stored one).
    static func migrate(_ object: inout [String: JSONValue]) throws
}
