import Foundation
import Testing
import AppModels

// MARK: - MOCK v2 models — REMOVE when real v2 models land
//
// Every `SchemaVersioned` model is still at schemaVersion 1, so there is no real migration to run yet.
// To exercise the in-decode migration machinery end-to-end, each `<Model>V2` below stands in for a
// hypothetical v2 of the corresponding model: it sets `currentSchemaVersion` to 2 and hand-writes an
// `init(from:)` that switches on the decoded `SchemaVersion` and maps the v1 shape forward. Each mock
// demonstrates a field *rename* — the case that genuinely needs a version switch (a plain additive
// field would be tolerated on decode without one). Each mock reads only the renamed field (plus the
// version); a keyed container ignores the other keys in the real v1 blob.
//
// FUTURE AGENT: when a model gains a REAL v2 (an actual breaking change, with its own `init(from:)`
// version switch on the real type), DELETE that model's `<Model>V2` mock and its tests here, and
// replace them with tests that migrate a real v1 blob to the real v2 shape. Once every model has real
// migration coverage, delete this whole file.

// MOCK — remove with real Setting v2. Renames v1 `galleryHost` → v2 `host`.
private struct SettingV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var host: GalleryHost
    enum CodingKeys: String, CodingKey { case schemaVersion, galleryHost, host }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<SettingV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            host = try container.decode(GalleryHost.self, forKey: .galleryHost)   // migrate old key
        default:
            host = try container.decode(GalleryHost.self, forKey: .host)          // native v2
        }
    }
}

// MOCK — remove with real User v2. Renames v1 `displayName` → v2 `name`.
private struct UserV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var name: String
    enum CodingKeys: String, CodingKey { case schemaVersion, displayName, name }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<UserV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            name = try container.decode(String.self, forKey: .displayName)
        default:
            name = try container.decode(String.self, forKey: .name)
        }
    }
}

// MOCK — remove with real Filter v2. Renames v1 `minRating` → v2 `minimumRating`.
private struct FilterV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var minimumRating: Int
    enum CodingKeys: String, CodingKey { case schemaVersion, minRating, minimumRating }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<FilterV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            minimumRating = try container.decode(Int.self, forKey: .minRating)
        default:
            minimumRating = try container.decode(Int.self, forKey: .minimumRating)
        }
    }
}

// MOCK — remove with real TagTranslatorInfo v2. Renames v1 `hasCustomTranslations` → v2 `custom`.
private struct TagTranslatorInfoV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var custom: Bool
    enum CodingKeys: String, CodingKey { case schemaVersion, hasCustomTranslations, custom }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<TagTranslatorInfoV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            custom = try container.decode(Bool.self, forKey: .hasCustomTranslations)
        default:
            custom = try container.decode(Bool.self, forKey: .custom)
        }
    }
}

// MOCK — remove with real GalleryHistoryEntry v2. Renames v1 `readingProgress` → v2 `progress`.
private struct GalleryHistoryEntryV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var progress: Int
    enum CodingKeys: String, CodingKey { case schemaVersion, readingProgress, progress }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<GalleryHistoryEntryV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            progress = try container.decode(Int.self, forKey: .readingProgress)
        default:
            progress = try container.decode(Int.self, forKey: .progress)
        }
    }
}

// MOCK — remove with real QuickSearchWord v2. Renames v1 `name` → v2 `label`.
private struct QuickSearchWordV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var label: String
    enum CodingKeys: String, CodingKey { case schemaVersion, name, label }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<QuickSearchWordV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            label = try container.decode(String.self, forKey: .name)
        default:
            label = try container.decode(String.self, forKey: .label)
        }
    }
}

// MARK: - Migration tests
//
// Each model: a real v1 blob (what the current code writes) forward-migrates through the mock v2
// decoder, and a native v2 blob decodes through the other branch. The mock's `SchemaVersion` cap is
// covered once, by `aV2ModelRejectsAnUnknownVersion`.
@Suite
struct SchemaMigrationTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Setting
    @Test
    func settingMigratesV1BlobToV2() throws {
        let v1Blob = try JSONEncoder().encode(Setting(galleryHost: .exhentai))
        let migrated = try JSONDecoder().decode(SettingV2.self, from: v1Blob)
        #expect(migrated.host == .exhentai)   // v1 `galleryHost` carried into v2 `host`
    }
    @Test
    func settingV2DecodesNatively() throws {
        let decoded = try decode(SettingV2.self, #"{"schemaVersion": 2, "host": "ExHentai"}"#)
        #expect(decoded.host == .exhentai)
    }

    // MARK: User
    @Test
    func userMigratesV1BlobToV2() throws {
        let v1Blob = try JSONEncoder().encode(User(displayName: "alice"))
        let migrated = try JSONDecoder().decode(UserV2.self, from: v1Blob)
        #expect(migrated.name == "alice")
    }
    @Test
    func userV2DecodesNatively() throws {
        let decoded = try decode(UserV2.self, #"{"schemaVersion": 2, "name": "alice"}"#)
        #expect(decoded.name == "alice")
    }

    // MARK: Filter
    @Test
    func filterMigratesV1BlobToV2() throws {
        let v1Blob = try JSONEncoder().encode(Filter(minRating: 5))
        let migrated = try JSONDecoder().decode(FilterV2.self, from: v1Blob)
        #expect(migrated.minimumRating == 5)
    }
    @Test
    func filterV2DecodesNatively() throws {
        let decoded = try decode(FilterV2.self, #"{"schemaVersion": 2, "minimumRating": 5}"#)
        #expect(decoded.minimumRating == 5)
    }

    // MARK: TagTranslatorInfo
    @Test
    func tagTranslatorInfoMigratesV1BlobToV2() throws {
        let v1Blob = try JSONEncoder().encode(TagTranslatorInfo(hasCustomTranslations: true))
        let migrated = try JSONDecoder().decode(TagTranslatorInfoV2.self, from: v1Blob)
        #expect(migrated.custom)
    }
    @Test
    func tagTranslatorInfoV2DecodesNatively() throws {
        let decoded = try decode(TagTranslatorInfoV2.self, #"{"schemaVersion": 2, "custom": true}"#)
        #expect(decoded.custom)
    }

    // MARK: GalleryHistoryEntry
    @Test
    func galleryHistoryEntryMigratesV1BlobToV2() throws {
        let entry = GalleryHistoryEntry(
            gid: "1", token: "a", lastOpenDate: Date(timeIntervalSince1970: 1), readingProgress: 7
        )
        let migrated = try JSONDecoder().decode(GalleryHistoryEntryV2.self, from: JSONEncoder().encode(entry))
        #expect(migrated.progress == 7)
    }
    @Test
    func galleryHistoryEntryV2DecodesNatively() throws {
        let decoded = try decode(GalleryHistoryEntryV2.self, #"{"schemaVersion": 2, "progress": 7}"#)
        #expect(decoded.progress == 7)
    }

    // MARK: QuickSearchWord
    @Test
    func quickSearchWordMigratesV1BlobToV2() throws {
        let v1Blob = try JSONEncoder().encode(QuickSearchWord(name: "n", content: "c"))
        let migrated = try JSONDecoder().decode(QuickSearchWordV2.self, from: v1Blob)
        #expect(migrated.label == "n")
    }
    @Test
    func quickSearchWordV2DecodesNatively() throws {
        let decoded = try decode(QuickSearchWordV2.self, #"{"schemaVersion": 2, "label": "n"}"#)
        #expect(decoded.label == "n")
    }

    // MARK: Version cap (representative)
    @Test
    func aV2ModelRejectsAnUnknownVersion() {
        // The mock caps `currentSchemaVersion` at 2; a v3 blob is rejected by `SchemaVersion<SettingV2>`.
        #expect(throws: (any Error).self) {
            try decode(SettingV2.self, #"{"schemaVersion": 3, "host": "ExHentai"}"#)
        }
    }
}
