import Foundation
import Testing
import AppModels

// MARK: - MOCK v2 models — REMOVE when real v2 models land
//
// Every `SchemaVersioned` model is still at schemaVersion 1, so there is no real migration to run yet.
// To exercise the in-decode migration machinery, each `<Model>V2` below stands in for a hypothetical v2
// of the corresponding model: it sets `currentSchemaVersion` to 2 and hand-writes the `init(from:)`
// version switch a real migration would use. Collectively they span the common schema-change shapes:
//
//   • Setting             RENAME  — galleryHost → host
//   • User                ADD     — new required `region`, defaulted when migrating from v1
//   • Filter              REMOVE  — drops `minRating` (a v1 blob still carrying it decodes)
//   • TagTranslatorInfo   TYPE    — hasCustomTranslations: Bool → customTranslations: Int
//   • GalleryHistoryEntry DERIVE  — new `started: Bool` computed from v1 `readingProgress`
//   • QuickSearchWord     MERGE   — `name` + `content` → `combined`
//
// Each test feeds a REAL v1 blob (what the current code writes) through the mock and asserts the forward
// map; a native v2 blob covers the other branch. RENAME/ADD/TYPE/DERIVE/MERGE need the version switch;
// REMOVE is decode-forward-compatible (a dropped key is simply ignored), so its mock only validates the
// version and has no branch.
//
// FUTURE AGENT: when a model gains a REAL v2 (an actual breaking change, with its own `init(from:)`
// version switch on the real type), DELETE that model's `<Model>V2` mock and its tests here, and replace
// them with tests that migrate a real v1 blob to the real v2 shape. Delete this whole file once every
// model has real migration coverage.

// MOCK — remove with real Setting v2. RENAME: v1 `galleryHost` → v2 `host`.
private struct SettingV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var host: GalleryHost
    enum CodingKeys: String, CodingKey { case schemaVersion, galleryHost, host }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<SettingV2>.self, forKey: .schemaVersion).value
        switch version {
        case 1:
            host = try container.decode(GalleryHost.self, forKey: .galleryHost)   // read the old key
        default:
            host = try container.decode(GalleryHost.self, forKey: .host)          // native v2
        }
    }
}

// MOCK — remove with real User v2. ADD: v2 introduces a required `region`, defaulted when migrating.
private struct UserV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var displayName: String?
    var region: String   // NEW in v2 and REQUIRED there; a v1 blob has no such key
    enum CodingKeys: String, CodingKey { case schemaVersion, displayName, region }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<UserV2>.self, forKey: .schemaVersion).value
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        switch version {
        case 1:
            region = ""   // migration supplies the default for a field v1 never had
        default:
            region = try container.decode(String.self, forKey: .region)   // required in v2
        }
    }
}

// MOCK — remove with real Filter v2. REMOVE: v2 drops `minRating`; a v1 blob still carrying it decodes.
private struct FilterV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var doujinshi: Bool   // retained field; `minRating` was dropped in v2 and is simply not read
    enum CodingKeys: String, CodingKey { case schemaVersion, doujinshi }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(SchemaVersion<FilterV2>.self, forKey: .schemaVersion)   // validate range
        doujinshi = try container.decode(Bool.self, forKey: .doujinshi)   // unchanged v1 → v2, no branch
    }
}

// MOCK — remove with real TagTranslatorInfo v2. TYPE: v1 `hasCustomTranslations: Bool` → v2 Int.
private struct TagTranslatorInfoV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var customTranslations: Int   // was `hasCustomTranslations: Bool` in v1
    enum CodingKeys: String, CodingKey { case schemaVersion, hasCustomTranslations, customTranslations }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<TagTranslatorInfoV2>.self, forKey: .schemaVersion)
        switch version.value {
        case 1:
            let old = try container.decode(Bool.self, forKey: .hasCustomTranslations)
            customTranslations = old ? 1 : 0   // convert the old Bool to the new Int
        default:
            customTranslations = try container.decode(Int.self, forKey: .customTranslations)
        }
    }
}

// MOCK — remove with real GalleryHistoryEntry v2. DERIVE: v2 `started` computed from v1 `readingProgress`.
private struct GalleryHistoryEntryV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var started: Bool   // NEW in v2, computed from v1 `readingProgress`
    enum CodingKeys: String, CodingKey { case schemaVersion, readingProgress, started }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<GalleryHistoryEntryV2>.self, forKey: .schemaVersion)
        switch version.value {
        case 1:
            let progress = try container.decode(Int.self, forKey: .readingProgress)
            started = progress > 0   // derive the new field from old data
        default:
            started = try container.decode(Bool.self, forKey: .started)
        }
    }
}

// MOCK — remove with real QuickSearchWord v2. MERGE: v1 `name` + `content` → v2 `combined`.
private struct QuickSearchWordV2: Decodable, SchemaVersioned {
    static let currentSchemaVersion = 2
    var combined: String   // v2 merges v1 `name` and `content`
    enum CodingKeys: String, CodingKey { case schemaVersion, name, content, combined }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(SchemaVersion<QuickSearchWordV2>.self, forKey: .schemaVersion)
        switch version.value {
        case 1:
            let name = try container.decode(String.self, forKey: .name)
            let content = try container.decode(String.self, forKey: .content)
            combined = "\(name): \(content)"   // merge two fields into one
        default:
            combined = try container.decode(String.self, forKey: .combined)
        }
    }
}

// MARK: - Migration tests
//
// Per model: a real v1 blob (what the current code writes) forward-migrates through the mock v2 decoder,
// and a native v2 blob decodes through the other branch. The `SchemaVersion` cap is covered once, by
// `aV2ModelRejectsAnUnknownVersion`.
@Suite
struct SchemaMigrationTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Setting — RENAME
    @Test
    func settingMigratesRenamedField() throws {
        let v1Blob = try JSONEncoder().encode(Setting(galleryHost: .exhentai))
        let migrated = try JSONDecoder().decode(SettingV2.self, from: v1Blob)
        #expect(migrated.host == .exhentai)   // v1 `galleryHost` carried into v2 `host`
    }
    @Test
    func settingV2DecodesNatively() throws {
        let decoded = try decode(SettingV2.self, #"{"schemaVersion": 2, "host": "ExHentai"}"#)
        #expect(decoded.host == .exhentai)
    }

    // MARK: User — ADD
    @Test
    func userMigratesAddedField() throws {
        // v1 has no `region`; a plain strict decode of a required field would fail — the switch defaults it.
        let v1Blob = try JSONEncoder().encode(User(displayName: "alice"))
        let migrated = try JSONDecoder().decode(UserV2.self, from: v1Blob)
        #expect(migrated.displayName == "alice")   // existing field preserved
        #expect(migrated.region == "")             // new field defaulted by the migration
    }
    @Test
    func userV2DecodesNatively() throws {
        let decoded = try decode(UserV2.self, #"{"schemaVersion": 2, "displayName": "bob", "region": "eu"}"#)
        #expect(decoded.region == "eu")
    }

    // MARK: Filter — REMOVE
    @Test
    func filterMigratesRemovedField() throws {
        // The v1 blob still carries `minRating`; v2 ignores the dropped key and decodes cleanly.
        let v1Blob = try JSONEncoder().encode(Filter(doujinshi: true, minRating: 5))
        let migrated = try JSONDecoder().decode(FilterV2.self, from: v1Blob)
        #expect(migrated.doujinshi)
    }
    @Test
    func filterV2DecodesNatively() throws {
        let decoded = try decode(FilterV2.self, #"{"schemaVersion": 2, "doujinshi": true}"#)
        #expect(decoded.doujinshi)
    }

    // MARK: TagTranslatorInfo — TYPE CHANGE
    @Test
    func tagTranslatorInfoMigratesChangedType() throws {
        let v1Blob = try JSONEncoder().encode(TagTranslatorInfo(hasCustomTranslations: true))
        let migrated = try JSONDecoder().decode(TagTranslatorInfoV2.self, from: v1Blob)
        #expect(migrated.customTranslations == 1)   // old Bool `true` converted to Int 1
    }
    @Test
    func tagTranslatorInfoV2DecodesNatively() throws {
        let decoded = try decode(TagTranslatorInfoV2.self, #"{"schemaVersion": 2, "customTranslations": 5}"#)
        #expect(decoded.customTranslations == 5)
    }

    // MARK: GalleryHistoryEntry — DERIVE
    @Test
    func galleryHistoryEntryDerivesField() throws {
        let started = GalleryHistoryEntry(
            gid: "1", token: "a", lastOpenDate: Date(timeIntervalSince1970: 1), readingProgress: 7
        )
        let unstarted = GalleryHistoryEntry(
            gid: "2", token: "b", lastOpenDate: Date(timeIntervalSince1970: 1), readingProgress: 0
        )
        let migratedStarted = try JSONDecoder().decode(
            GalleryHistoryEntryV2.self, from: JSONEncoder().encode(started)
        )
        let migratedUnstarted = try JSONDecoder().decode(
            GalleryHistoryEntryV2.self, from: JSONEncoder().encode(unstarted)
        )
        #expect(migratedStarted.started)      // readingProgress 7 → started
        #expect(!migratedUnstarted.started)   // readingProgress 0 → not started
    }
    @Test
    func galleryHistoryEntryV2DecodesNatively() throws {
        let decoded = try decode(GalleryHistoryEntryV2.self, #"{"schemaVersion": 2, "started": true}"#)
        #expect(decoded.started)
    }

    // MARK: QuickSearchWord — MERGE
    @Test
    func quickSearchWordMergesFields() throws {
        let v1Blob = try JSONEncoder().encode(QuickSearchWord(name: "n", content: "c"))
        let migrated = try JSONDecoder().decode(QuickSearchWordV2.self, from: v1Blob)
        #expect(migrated.combined == "n: c")   // v1 `name` + `content` merged
    }
    @Test
    func quickSearchWordV2DecodesNatively() throws {
        let decoded = try decode(QuickSearchWordV2.self, #"{"schemaVersion": 2, "combined": "x"}"#)
        #expect(decoded.combined == "x")
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
