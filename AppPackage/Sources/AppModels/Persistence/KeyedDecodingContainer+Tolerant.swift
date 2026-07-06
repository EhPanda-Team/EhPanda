import Foundation

extension Optional {
    /// Tolerant keyed decode: returns the decoded value, or `defaultValue` when the key is absent, its
    /// value is `null`, decoding it throws (a per-field type mismatch), or the container itself is
    /// absent. This is the single home for the read-and-default idiom every persisted model's
    /// hand-written `init(from:)` repeats per field, so a new persisted field costs one short line
    /// instead of a `(try? container?.decodeIfPresent(…)) ?? default` one. Forgiving a per-field
    /// decode failure is what lets an existing persisted value stay valid across future additive
    /// changes (see `AppSharedKeys` for the whole-struct persistence rationale).
    ///
    /// Defined on the *optional* container because those decoders acquire it with
    /// `try? decoder.container(keyedBy:)` — which yields `nil` on a shape mismatch rather than
    /// throwing — and each field must still fall back to its own default independently, exactly as the
    /// per-field `?? default` did.
    func decode<Value: Decodable, Key: CodingKey>(_ key: Key, `default` defaultValue: Value) -> Value
    where Wrapped == KeyedDecodingContainer<Key> {
        guard let container = self,
              let value = try? container.decodeIfPresent(Value.self, forKey: key)
        else { return defaultValue }
        return value
    }
}
