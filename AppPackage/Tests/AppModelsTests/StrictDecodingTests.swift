import Foundation
import Testing
import AppModels

// #2: persisted models decode *strictly* — the blanket-tolerant decoder is gone. A corrupt or
// shape-incompatible blob fails to decode so Sharing resets the key to its default (a clean, coherent
// value) instead of surfacing a partially-filled Franken-value. Identity-bearing array elements
// (`GalleryHistoryEntry`, `QuickSearchWord`) validate their identity and reject an unknown
// `schemaVersion`; whole-struct models (`Filter`, `Setting`, …) keep synthesized strict Codable and
// reject an unknown `schemaVersion` through a self-validating `SchemaVersion` field.
@Suite
struct StrictDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test
    func wellFormedValuesRoundTrip() throws {
        var original = Filter(minRating: 5, pageLowerBound: "10")
        original.doujinshi = true
        let decoded = try JSONDecoder().decode(Filter.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test
    func aWholeStructModelRejectsAPartialBlob() {
        // Missing required keys → synthesized decode throws → Sharing falls back to the key default.
        #expect(throws: (any Error).self) {
            try decode(Filter.self, "{}")
        }
    }

    @Test
    func aWholeStructModelRejectsAWrongTypedValue() {
        // Previously "not-an-int" silently defaulted `minRating` to 2; now the whole decode fails.
        #expect(throws: (any Error).self) {
            try decode(Filter.self, #"{"minRating": "not-an-int"}"#)
        }
    }

    @Test
    func galleryHistoryEntryRoundTrips() throws {
        let entry = GalleryHistoryEntry(
            gid: "123", token: "abc", lastOpenDate: Date(timeIntervalSince1970: 1), readingProgress: 5
        )
        let decoded = try JSONDecoder().decode(
            GalleryHistoryEntry.self, from: JSONEncoder().encode(entry)
        )
        #expect(decoded == entry)
    }

    @Test
    func galleryHistoryEntryRejectsABlankIdentity() {
        // A blank gid/token is unresolvable; strict decode throws rather than yielding a `""`-id entry
        // that would collide with every other corrupt entry in an `Identifiable` list.
        let json = #"{"schemaVersion": 1, "gid": "", "token": "", "lastOpenDate": 0, "readingProgress": 0}"#
        #expect(throws: (any Error).self) {
            try decode(GalleryHistoryEntry.self, json)
        }
    }

    @Test
    func galleryHistoryEntryRejectsAMissingField() {
        // `lastOpenDate` absent → strict decode throws (previously it silently defaulted to distantPast).
        let json = #"{"schemaVersion": 1, "gid": "1", "token": "a", "readingProgress": 0}"#
        #expect(throws: (any Error).self) {
            try decode(GalleryHistoryEntry.self, json)
        }
    }

    @Test
    func galleryHistoryEntryRejectsAnUnknownSchemaVersion() {
        let json = #"{"schemaVersion": 2, "gid": "1", "token": "a", "lastOpenDate": 0, "readingProgress": 0}"#
        #expect(throws: (any Error).self) {
            try decode(GalleryHistoryEntry.self, json)
        }
    }

    @Test
    func aSingleBadElementFailsTheWholeHistoryArray() {
        // One malformed element fails the array decode; Sharing then resets `galleryHistory` to [].
        let json = """
        [
          {"schemaVersion": 1, "gid": "1", "token": "a", "lastOpenDate": 0, "readingProgress": 0},
          {"schemaVersion": 1, "gid": "", "token": "", "lastOpenDate": 0, "readingProgress": 0}
        ]
        """
        #expect(throws: (any Error).self) {
            try decode([GalleryHistoryEntry].self, json)
        }
    }

    @Test
    func quickSearchWordPreservesItsPersistedIdentity() throws {
        let id = UUID()
        let json = #"{"schemaVersion": 1, "id": "\#(id.uuidString)", "name": "n", "content": "c"}"#
        let word = try decode(QuickSearchWord.self, json)
        #expect(word.id == id)   // decoded, never a fresh random UUID
        #expect(word.name == "n")
    }

    @Test
    func quickSearchWordRejectsAMissingIdentity() {
        // Previously a missing `id` fabricated a fresh UUID() on every decode; now it throws.
        #expect(throws: (any Error).self) {
            try decode(QuickSearchWord.self, #"{"schemaVersion": 1, "name": "n", "content": "c"}"#)
        }
    }

    @Test
    func quickSearchWordRejectsAnUnknownSchemaVersion() {
        // The version now validates through the shared `SchemaVersion` field, like the whole-struct
        // models; a newer value throws, failing the (array) decode even when the identity is valid.
        let json = """
        {"schemaVersion": 2, "id": "00000000-0000-0000-0000-000000000000", "name": "n", "content": "c"}
        """
        #expect(throws: (any Error).self) {
            try decode(QuickSearchWord.self, json)
        }
    }

    // MARK: schemaVersion gating

    @Test
    func schemaVersionAcceptsTheCurrentVersion() throws {
        let version = try decode(SchemaVersion<Filter>.self, "1")
        #expect(version.value == 1)
    }

    @Test
    func schemaVersionRejectsANewerVersion() {
        // A blob written by a newer build (a downgrade) is rejected rather than half-read.
        #expect(throws: (any Error).self) {
            try decode(SchemaVersion<Filter>.self, "2")
        }
    }

    @Test
    func schemaVersionRejectsACorruptVersion() {
        // 0 / negative is outside the 1...current range.
        #expect(throws: (any Error).self) {
            try decode(SchemaVersion<Filter>.self, "0")
        }
    }

    @Test
    func aWholeStructModelRejectsANewerSchemaVersion() throws {
        // An otherwise-valid blob whose schemaVersion is newer than this build supports fails the whole
        // decode, so Sharing falls back to the key default instead of dropping the new fields.
        let data = try JSONEncoder().encode(Filter())
        let json = try JSONSerialization.jsonObject(with: data)
        var object = try #require(json as? [String: Any])
        object["schemaVersion"] = 2
        let tampered = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Filter.self, from: tampered)
        }
    }

    @Test
    func schemaVersionEncodesAsABareInteger() throws {
        // The persisted shape must stay `"schemaVersion": 1` (a bare int, not a wrapper object) so
        // blobs written before this type existed keep decoding.
        let data = try JSONEncoder().encode(Filter())
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])
        #expect(object["schemaVersion"] as? Int == 1)
    }

    @Test
    func aWholeStructModelStillToleratesAnAbsentOptionalField() throws {
        // Optional-field tolerance survives the switch to a `SchemaVersion` field: a blob carrying only
        // the version still decodes, with the absent optionals left nil.
        let user = try decode(User.self, #"{"schemaVersion": 1}"#)
        #expect(user.displayName == nil)
        #expect(user.favoriteCategories == nil)
    }
}
