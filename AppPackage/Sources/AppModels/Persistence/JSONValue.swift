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
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        // Each decode below is a deliberate type probe: a mismatch falls through
        // to the next JSON representation, so the thrown error is the control flow.
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        // This type probe intentionally falls through when the value is not an integer.
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        // This type probe intentionally falls through when the value is not a floating-point number.
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        // This type probe intentionally falls through when the value is not a string.
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        // This type probe intentionally falls through when the value is not an array.
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        // This final type probe leaves unsupported values for the structured decoding error below.
        } else if let object = try? container.decode([String: JSONValue].self) {
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
