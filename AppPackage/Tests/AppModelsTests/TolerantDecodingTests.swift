import Foundation
import Testing
import AppModels

// REV-24: every persisted model decodes tolerantly through one shared helper
// (`Optional<KeyedDecodingContainer>.decode(_:default:)`). These pin the guarantees that helper must
// keep — a missing key, a wrong-typed value, and even a whole non-object payload each fall back to the
// field's own default instead of throwing, while well-formed values still round-trip intact.
@Suite
struct TolerantDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test
    func missingKeysFallBackToPerFieldDefaults() throws {
        let filter = try decode(Filter.self, "{}")
        #expect(filter.schemaVersion == 1)
        #expect(filter.minRating == 2)
        #expect(filter.doujinshi == false)
        // The decoder default here intentionally differs from the constructed default (`true`).
        #expect(filter.galleryName == false)
    }

    @Test
    func aWrongTypedValueFallsBackWithoutFailingItsSiblings() throws {
        let filter = try decode(Filter.self, #"{"minRating": "not-an-int", "doujinshi": true}"#)
        #expect(filter.minRating == 2)    // wrong type → default
        #expect(filter.doujinshi == true) // a valid sibling still decodes
    }

    @Test
    func aNonObjectPayloadDecodesToDefaultsRatherThanThrowing() throws {
        // The container itself is absent (top-level array, not a dictionary); every field must still
        // fall back to its default, identical to the empty-object case above.
        let filter = try decode(Filter.self, "[]")
        #expect(filter.schemaVersion == 1)
        #expect(filter.minRating == 2)
        #expect(filter.galleryName == false)
    }

    @Test
    func wellFormedValuesRoundTrip() throws {
        var original = Filter(minRating: 5, pageLowerBound: "10")
        original.doujinshi = true
        let decoded = try JSONDecoder().decode(Filter.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test
    func requiredStringFieldsDecodePartially() throws {
        let entry = try decode(GalleryHistoryEntry.self, #"{"gid": "123", "token": "abc", "readingProgress": 5}"#)
        #expect(entry.gid == "123")
        #expect(entry.token == "abc")
        #expect(entry.readingProgress == 5)
        #expect(entry.lastOpenDate == .distantPast) // missing → default
    }
}
