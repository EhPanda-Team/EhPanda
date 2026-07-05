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

    @Test
    func loadCachedTagTranslatorReturnsNilWhenCacheMissing() throws {
        let language = TranslatableLanguage.japanese
        try? FileManager.default.removeItem(
            at: URL.cachesDirectory.appending(component: language.cachedTranslationsFilename)
        )
        #expect(FileClient.live.loadCachedTagTranslator(TagTranslatorInfo(language: language)) == nil)
    }
}
