import Foundation
import OSLogExt

private let logger = Logger(category: "SchemaVersion")

/// A model whose persisted blob carries a `schemaVersion` and knows the newest version this build can
/// decode. Adopt it together with a `SchemaVersion<Self>` field so the version validates itself on
/// decode.
public protocol SchemaVersioned {
    /// The newest `schemaVersion` this build understands. A stored blob carrying a larger value is a
    /// downgrade and is rejected on decode.
    static var currentSchemaVersion: Int { get }
}

/// A self-validating `schemaVersion` field.
///
/// On decode it accepts `1...Model.currentSchemaVersion` and throws on anything else — a newer
/// (downgrade) value, or a corrupt `0`/negative — logging the rejected version via OSLog first. The
/// throw fails the whole model decode, so `Sharing` falls back to the key's default rather than
/// half-reading an unknown shape. It encodes as a bare integer, so the persisted JSON is unchanged
/// (`"schemaVersion": 1`).
///
/// This is the lightweight, in-decode migration seam. It gives every persisted model uniform
/// downgrade rejection *without* a hand-written `init(from:)`, so synthesized `Codable` — and with it
/// each model's `didSet` invariants and optional-field tolerance — stays untouched. When a real
/// breaking change lands for a model, that model gains a custom `init(from:)` that switches on this
/// version to map the older shape forward.
public struct SchemaVersion<Model: SchemaVersioned>: Hashable, Sendable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }
}

extension SchemaVersion: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension SchemaVersion: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode(Int.self)
        guard (1...Model.currentSchemaVersion).contains(decoded) else {
            let message = "\(Model.self) schemaVersion \(decoded) is outside the "
                + "supported range 1...\(Model.currentSchemaVersion)"
            logger.error("\(message, privacy: .public)")
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: message
            ))
        }
        value = decoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
