import Testing
import Foundation
import AppModels
import FileClient

// Exercises the live importer's coordinated, security-scoped read (REV-1) against local files;
// the iCloud download that coordination triggers is system behavior, smoke-tested manually.
// Serialized: the tag-translation cache/import endpoints write fixed paths in the real Caches and
// Application Support directories, so parallel cases would race on the same files.
@Suite(.serialized)
struct FileClientTests {
    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "tags-\(UUID().uuidString).json")
        try data.write(to: url)
        return url
    }

    private func sampleResponseData() throws -> Data {
        let response = EhTagTranslationDatabaseResponse(
            data: [.init(namespace: "female", data: ["tag": .init(name: "translated")])]
        )
        return try JSONEncoder().encode(response)
    }

    // Simplified-Chinese source values plus the custom `full color` case, used to prove OpenCC
    // conversion is applied only for `.traditionalChinese`. `简体` traditionalizes to `簡體` under
    // every regional standard, so the expectation is machine-locale-invariant.
    private func chineseResponseData() throws -> Data {
        let response = EhTagTranslationDatabaseResponse(
            data: [.init(namespace: "female", data: [
                "simp": .init(name: "简体"),
                "fc": .init(name: "full color")
            ])]
        )
        return try JSONEncoder().encode(response)
    }

    private func value(forKey key: String, in translator: TagTranslator) -> String? {
        translator.translations.values.first(where: { $0.key == key })?.value
    }

    private var customTranslationsURL: URL {
        .applicationSupportDirectory.appending(component: "tagTranslations-custom.json")
    }

    @Test
    func importsValidTranslationFileViaCoordinatedRead() async throws {
        let url = try writeTemporaryFile(try sampleResponseData())
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: customTranslationsURL)
        }

        let translator = try await FileClient.live.importTagTranslator(url).get()
        #expect(translator.hasCustomTranslations)
        #expect(translator.translations.count == 1)
    }

    @Test
    func undecodableFileFailsWithParseFailed() async throws {
        let url = try writeTemporaryFile(Data("not json".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let result = await FileClient.live.importTagTranslator(url)
        #expect(result == .failure(.parseFailed))
    }

    @Test
    func cachesRemoteTableAndRebuildsItFromMetadata() throws {
        let language = TranslatableLanguage.english
        let cacheURL = URL.cachesDirectory.appending(component: language.cachedTranslationsFilename)
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let built = try #require(
            FileClient.live.cacheAndBuildRemoteTagTranslator(try sampleResponseData(), language, .distantPast)
        )
        #expect(built.language == language)
        #expect(built.translations.count == 1)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))

        // A launch-time rebuild restores the same table from the cached file the metadata points at.
        let rebuilt = try #require(FileClient.live.loadCachedTagTranslator(TagTranslatorInfo(language: language)))
        #expect(rebuilt.language == language)
        #expect(rebuilt.translations.count == 1)
    }

    @Test
    func rebuildsCustomTableFromApplicationSupport() async throws {
        let url = try writeTemporaryFile(try sampleResponseData())
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: customTranslationsURL)
        }

        _ = try await FileClient.live.importTagTranslator(url).get()

        let rebuilt = try #require(
            FileClient.live.loadCachedTagTranslator(TagTranslatorInfo(hasCustomTranslations: true))
        )
        #expect(rebuilt.hasCustomTranslations)
        #expect(rebuilt.translations.count == 1)
    }

    // DEP-01 parity: a remote table built for Traditional Chinese must apply OpenCC conversion
    // (`简体` → `簡體`) and the custom `full color` → `全彩` mapping.
    @Test
    func traditionalChineseAppliesOpenCCConversionAndCustomFullColor() throws {
        let language = TranslatableLanguage.traditionalChinese
        let cacheURL = URL.cachesDirectory.appending(component: language.cachedTranslationsFilename)
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let built = try #require(
            FileClient.live.cacheAndBuildRemoteTagTranslator(try chineseResponseData(), language, .distantPast)
        )
        #expect(value(forKey: "simp", in: built) == "簡體")
        #expect(value(forKey: "fc", in: built) == "全彩")
    }

    // DEP-01 parity: any non-Traditional-Chinese table keeps its raw values untouched — no OpenCC
    // conversion and no custom `full color` remap.
    @Test
    func nonTraditionalChineseLeavesTagValuesUnconverted() throws {
        let language = TranslatableLanguage.simplifiedChinese
        let cacheURL = URL.cachesDirectory.appending(component: language.cachedTranslationsFilename)
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let built = try #require(
            FileClient.live.cacheAndBuildRemoteTagTranslator(try chineseResponseData(), language, .distantPast)
        )
        #expect(value(forKey: "simp", in: built) == "简体")
        #expect(value(forKey: "fc", in: built) == "full color")
    }

    @Test
    func loadCachedTagTranslatorReturnsNilWhenCacheMissing() throws {
        let language = TranslatableLanguage.japanese
        try? FileManager.default.removeItem(
            at: URL.cachesDirectory.appending(component: language.cachedTranslationsFilename)
        )
        #expect(FileClient.live.loadCachedTagTranslator(TagTranslatorInfo(language: language)) == nil)
    }

    // REV-14: removing custom translations must delete the imported file from Application Support so it
    // doesn't linger in non-purgeable storage forever.
    @Test
    func removeCustomTranslationsDeletesTheImportedFile() async throws {
        let url = try writeTemporaryFile(try sampleResponseData())
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: customTranslationsURL)
        }

        _ = try await FileClient.live.importTagTranslator(url).get()
        #expect(FileManager.default.fileExists(atPath: customTranslationsURL.path))

        FileClient.live.removeCustomTranslations()

        #expect(!FileManager.default.fileExists(atPath: customTranslationsURL.path))
        #expect(
            FileClient.live.loadCachedTagTranslator(TagTranslatorInfo(hasCustomTranslations: true)) == nil
        )
    }
}
