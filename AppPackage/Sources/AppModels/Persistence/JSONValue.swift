import Foundation

/// A minimal, `Sendable` JSON tree used as the working representation for schema migrations.
///
/// A migration map mutates a `[String: JSONValue]` object — "fetch this key, create that key, set this
/// value" — before the migrated data is decoded into the current model shape. `Int` and `Double` are
/// kept distinct so integer fields (and `Int`-raw enums) round-trip without being widened to `Double`.
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue {
    public var boolValue: Bool? { if case .bool(let value) = self { return value } else { return nil } }
    public var intValue: Int? { if case .int(let value) = self { return value } else { return nil } }
    public var doubleValue: Double? { if case .double(let value) = self { return value } else { return nil } }
    public var stringValue: String? { if case .string(let value) = self { return value } else { return nil } }
}

extension JSONValue: Codable {
    /// Attempts one representation of a single-value container, returning nil on a mismatch.
    ///
    /// Failure is this decoder's control flow rather than an error condition: `init(from:)` walks
    /// the six JSON representations in a fixed order and a mismatch is precisely how it selects the
    /// next one, so the thrown error carries no diagnostic value and is deliberately absorbed. Only
    /// a value matching *none* of the six is an actual failure, and that is thrown at the end of
    /// the chain. The catch is silent for the same reason — a probe miss is the ordinary path, and
    /// logging it would fire on nearly every decoded value.
    private static func probe<Value: Decodable>(
        _ type: Value.Type,
        in container: SingleValueDecodingContainer
    ) -> Value? {
        do {
            return try container.decode(type)
        } catch {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Probe order is load-bearing: `Int` before `Double` keeps integer fields (and Int-raw
        // enums) from widening, and the composite types come last. Persisted `@Shared` models
        // depend on this exact sequence.
        if container.decodeNil() {
            self = .null
        } else if let bool = Self.probe(Bool.self, in: container) {
            self = .bool(bool)
        } else if let int = Self.probe(Int.self, in: container) {
            self = .int(int)
        } else if let double = Self.probe(Double.self, in: container) {
            self = .double(double)
        } else if let string = Self.probe(String.self, in: container) {
            self = .string(string)
        } else if let array = Self.probe([JSONValue].self, in: container) {
            self = .array(array)
        } else if let object = Self.probe([String: JSONValue].self, in: container) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported JSON value"
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
