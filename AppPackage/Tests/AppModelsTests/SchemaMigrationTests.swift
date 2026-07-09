import Foundation
import Testing
import AppModels

// MARK: - MOCK migratable models — REMOVE when real v2 models land
//
// No real model has a breaking change yet, so these mocks exercise the migration engine
// (`SchemaMigrator` + `SchemaMigration` maps + progressive chaining). Each conforms to `MigratableModel`,
// declares an ordered `migrations` list (index 0 = v1 = `.passthrough`), and provides `init(currentFrom:)`
// for its current shape. A v1→v2 map is a raw-JSON transform; the engine reads a stored blob's version
// and applies every map from there up to `currentSchemaVersion`, in order.
//
// Shapes covered, one per model: RENAME, ADD, REMOVE, TYPE, DERIVE, MERGE. `ProgressiveMock` covers a
// multi-step chain (v1 → v2 → v3).
//
// FUTURE AGENT: when a model gains a REAL v2 (it adopts `MigratableModel` and appends a real map to its
// `migrations`), DELETE that model's mock + its tests here and replace them with tests over the real
// migration. Delete this whole file once every model has real migration coverage.

// MOCK — remove with real Setting v2. RENAME: v1 `galleryHost` → v2 `host`.
private struct SettingMock: MigratableModel {
    var host: GalleryHost
    static let migrations: [SchemaMigration<SettingMock>] = [
        .passthrough,
        SchemaMigration { object in
            object["host"] = object["galleryHost"]
            object["galleryHost"] = nil
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(GalleryHost.self, forKey: .host)
    }
}

// MOCK — remove with real User v2. ADD: v2 introduces a required `region`, defaulted when migrating.
private struct UserMock: MigratableModel {
    var displayName: String?
    var region: String
    static let migrations: [SchemaMigration<UserMock>] = [
        .passthrough,
        SchemaMigration { object in
            object["region"] = .string("")
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        region = try container.decode(String.self, forKey: .region)
    }
}

// MOCK — remove with real Filter v2. REMOVE: v2 drops `minRating`; a v1 blob still carrying it decodes.
private struct FilterMock: MigratableModel {
    var doujinshi: Bool
    static let migrations: [SchemaMigration<FilterMock>] = [
        .passthrough,
        SchemaMigration { object in
            object["minRating"] = nil
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        doujinshi = try container.decode(Bool.self, forKey: .doujinshi)
    }
}

// MOCK — remove with real TagTranslatorInfo v2. TYPE: v1 `hasCustomTranslations: Bool` → v2 Int.
private struct TagTranslatorInfoMock: MigratableModel {
    var customTranslations: Int
    static let migrations: [SchemaMigration<TagTranslatorInfoMock>] = [
        .passthrough,
        SchemaMigration { object in
            let flag = object["hasCustomTranslations"]?.boolValue ?? false
            object["customTranslations"] = .int(flag ? 1 : 0)
            object["hasCustomTranslations"] = nil
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customTranslations = try container.decode(Int.self, forKey: .customTranslations)
    }
}

// MOCK — remove with real GalleryHistoryEntry v2. DERIVE: v2 `started` computed from v1 `readingProgress`.
private struct GalleryHistoryEntryMock: MigratableModel {
    var started: Bool
    static let migrations: [SchemaMigration<GalleryHistoryEntryMock>] = [
        .passthrough,
        SchemaMigration { object in
            let progress = object["readingProgress"]?.intValue ?? 0
            object["started"] = .bool(progress > 0)
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        started = try container.decode(Bool.self, forKey: .started)
    }
}

// MOCK — remove with real QuickSearchWord v2. MERGE: v1 `name` + `content` → v2 `combined`.
private struct QuickSearchWordMock: MigratableModel {
    var combined: String
    static let migrations: [SchemaMigration<QuickSearchWordMock>] = [
        .passthrough,
        SchemaMigration { object in
            let name = object["name"]?.stringValue ?? ""
            let content = object["content"]?.stringValue ?? ""
            object["combined"] = .string("\(name): \(content)")
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        combined = try container.decode(String.self, forKey: .combined)
    }
}

// MOCK — progressive chain across three versions. v1 field `a` → v2 `b` (doubled) → v3 `value` (plus one).
private struct ProgressiveMock: MigratableModel {
    var value: Int
    static let migrations: [SchemaMigration<ProgressiveMock>] = [
        .passthrough,
        SchemaMigration { object in
            let old = object["a"]?.intValue ?? 0
            object["b"] = .int(old * 2)
            object["a"] = nil
        },
        SchemaMigration { object in
            let old = object["b"]?.intValue ?? 0
            object["value"] = .int(old + 1)
            object["b"] = nil
        }
    ]
    init(from decoder: Decoder) throws { self = try SchemaMigrator.migrate(Self.self, from: decoder) }
    init(currentFrom decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(Int.self, forKey: .value)
    }
}

// MARK: - Migration tests
@Suite
struct SchemaMigrationTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: Progressive chaining (the headline)
    @Test
    func aV1BlobChainsThroughEveryStep() throws {
        // a=5 → v1→v2 doubles to b=10 → v2→v3 adds one to value=11. Both steps run, in order.
        let migrated = try decode(ProgressiveMock.self, #"{"schemaVersion": 1, "a": 5}"#)
        #expect(migrated.value == 11)
    }
    @Test
    func aMidVersionBlobRunsOnlyTheRemainingSteps() throws {
        // Starting at v2 (b=10) runs only v2→v3: value = 11.
        let migrated = try decode(ProgressiveMock.self, #"{"schemaVersion": 2, "b": 10}"#)
        #expect(migrated.value == 11)
    }
    @Test
    func aCurrentVersionBlobDecodesWithNoSteps() throws {
        let decoded = try decode(ProgressiveMock.self, #"{"schemaVersion": 3, "value": 11}"#)
        #expect(decoded.value == 11)
    }
    @Test
    func aNewerVersionBlobIsRejected() {
        // currentSchemaVersion is 3 (migrations.count); a v4 blob is a downgrade and throws.
        #expect(throws: (any Error).self) {
            try decode(ProgressiveMock.self, #"{"schemaVersion": 4, "value": 11}"#)
        }
    }

    // MARK: Per-shape maps, fed a REAL v1 blob
    @Test
    func settingRenamesAField() throws {
        let v1Blob = try JSONEncoder().encode(Setting(galleryHost: .exhentai))
        let migrated = try JSONDecoder().decode(SettingMock.self, from: v1Blob)
        #expect(migrated.host == .exhentai)
    }
    @Test
    func settingMockDecodesNatively() throws {
        let decoded = try decode(SettingMock.self, #"{"schemaVersion": 2, "host": "ExHentai"}"#)
        #expect(decoded.host == .exhentai)
    }

    @Test
    func userAddsARequiredField() throws {
        let v1Blob = try JSONEncoder().encode(User(displayName: "alice"))
        let migrated = try JSONDecoder().decode(UserMock.self, from: v1Blob)
        #expect(migrated.displayName == "alice")   // existing field preserved
        #expect(migrated.region == "")             // new field defaulted by the map
    }
    @Test
    func userMockDecodesNatively() throws {
        let decoded = try decode(UserMock.self, #"{"schemaVersion": 2, "displayName": "bob", "region": "eu"}"#)
        #expect(decoded.region == "eu")
    }

    @Test
    func filterRemovesAField() throws {
        // The v1 blob still carries `minRating`; the map drops it and the current shape decodes.
        let v1Blob = try JSONEncoder().encode(Filter(doujinshi: true, minRating: 5))
        let migrated = try JSONDecoder().decode(FilterMock.self, from: v1Blob)
        #expect(migrated.doujinshi)
    }
    @Test
    func filterMockDecodesNatively() throws {
        let decoded = try decode(FilterMock.self, #"{"schemaVersion": 2, "doujinshi": true}"#)
        #expect(decoded.doujinshi)
    }

    @Test
    func tagTranslatorInfoChangesAFieldType() throws {
        let v1Blob = try JSONEncoder().encode(TagTranslatorInfo(hasCustomTranslations: true))
        let migrated = try JSONDecoder().decode(TagTranslatorInfoMock.self, from: v1Blob)
        #expect(migrated.customTranslations == 1)   // Bool true → Int 1
    }
    @Test
    func tagTranslatorInfoMockDecodesNatively() throws {
        let decoded = try decode(TagTranslatorInfoMock.self, #"{"schemaVersion": 2, "customTranslations": 5}"#)
        #expect(decoded.customTranslations == 5)
    }

    @Test
    func galleryHistoryEntryDerivesAField() throws {
        let started = GalleryHistoryEntry(
            gid: "1", token: "a", lastOpenDate: Date(timeIntervalSince1970: 1), readingProgress: 7
        )
        let unstarted = GalleryHistoryEntry(
            gid: "2", token: "b", lastOpenDate: Date(timeIntervalSince1970: 1), readingProgress: 0
        )
        let migratedStarted = try JSONDecoder().decode(
            GalleryHistoryEntryMock.self, from: JSONEncoder().encode(started)
        )
        let migratedUnstarted = try JSONDecoder().decode(
            GalleryHistoryEntryMock.self, from: JSONEncoder().encode(unstarted)
        )
        #expect(migratedStarted.started)
        #expect(!migratedUnstarted.started)
    }
    @Test
    func galleryHistoryEntryMockDecodesNatively() throws {
        let decoded = try decode(GalleryHistoryEntryMock.self, #"{"schemaVersion": 2, "started": true}"#)
        #expect(decoded.started)
    }

    @Test
    func quickSearchWordMergesFields() throws {
        let v1Blob = try JSONEncoder().encode(QuickSearchWord(name: "n", content: "c"))
        let migrated = try JSONDecoder().decode(QuickSearchWordMock.self, from: v1Blob)
        #expect(migrated.combined == "n: c")
    }
    @Test
    func quickSearchWordMockDecodesNatively() throws {
        let decoded = try decode(QuickSearchWordMock.self, #"{"schemaVersion": 2, "combined": "x"}"#)
        #expect(decoded.combined == "x")
    }

    // MARK: Invariant — passthrough only at v1
    @Test
    func everyModelDeclaresWellFormedMigrations() {
        #expect(Setting.hasWellFormedMigrations)
        #expect(User.hasWellFormedMigrations)
        #expect(Filter.hasWellFormedMigrations)
        #expect(TagTranslatorInfo.hasWellFormedMigrations)
        #expect(GalleryHistoryEntry.hasWellFormedMigrations)
        #expect(QuickSearchWord.hasWellFormedMigrations)
        #expect(ProgressiveMock.hasWellFormedMigrations)   // 3 slots, passthrough only at index 0
    }
}
