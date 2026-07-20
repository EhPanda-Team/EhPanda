import AppModels
import FileClient
import Foundation
import Testing

// Exercises the live importer's coordinated, security-scoped read (REV-1) against local files;
// the iCloud download that coordination triggers is system behavior, smoke-tested manually.
final class FileClientTests {
    // Swift Testing builds one suite instance per case, so this root is unique to a single test.
    // Injecting it into `FileClient.live` is what lets these cases run in parallel: without it they
    // would all write the same two files in the real Caches / Application Support directories.
    private let root = FileManager.default.temporaryDirectory
        .appending(component: UUID().uuidString, directoryHint: .isDirectory)

    private var client: FileClient {
        .live(
            applicationSupportURL: root.appending(component: "ApplicationSupport", directoryHint: .isDirectory),
            cachesURL: root.appending(component: "Caches", directoryHint: .isDirectory)
        )
    }

    private var customTranslationsURL: URL {
        root.appending(path: "ApplicationSupport/tagTranslations-custom.json")
    }

    private func cacheURL(_ language: TranslatableLanguage) -> URL {
        root.appending(path: "Caches/\(language.cachedTranslationsFilename)")
    }

    deinit {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            // A case that wrote nothing leaves no root to remove; the directory is under the
            // system temporary directory either way, so cleanup is housekeeping, not a result.
        }
    }

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(component: "tags.json")
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

    @Test
    func importsValidTranslationFileViaCoordinatedRead() async throws {
        let url = try writeTemporaryFile(try sampleResponseData())

        let translator = try await client.importTagTranslator(url).get()
        #expect(translator.hasCustomTranslations)
        #expect(translator.translations.count == 1)
    }

    @Test
    func undecodableFileFailsWithFileOperationError() async throws {
        let url = try writeTemporaryFile(Data("not json".utf8))

        let result = await client.importTagTranslator(url)
        #expect(result == .failure(.fileOperationFailed("Decode tag translations")))
    }

    @Test
    func cachesRemoteTableAndRebuildsItFromMetadata() throws {
        let language = TranslatableLanguage.english

        let built = try client.cacheAndBuildRemoteTagTranslator(
            try sampleResponseData(), language, .distantPast
        )
        #expect(built.language == language)
        #expect(built.translations.count == 1)
        #expect(FileManager.default.fileExists(atPath: cacheURL(language).path))

        // A launch-time rebuild restores the same table from the cached file the metadata points at.
        let rebuilt = try client.loadCachedTagTranslator(TagTranslatorInfo(language: language))
        #expect(rebuilt.language == language)
        #expect(rebuilt.translations.count == 1)
    }

    @Test
    func rebuildsCustomTableFromApplicationSupport() async throws {
        let url = try writeTemporaryFile(try sampleResponseData())

        _ = try await client.importTagTranslator(url).get()

        let rebuilt = try client.loadCachedTagTranslator(
            TagTranslatorInfo(hasCustomTranslations: true)
        )
        #expect(rebuilt.hasCustomTranslations)
        #expect(rebuilt.translations.count == 1)
    }

    // DEP-01 parity: a remote table built for Traditional Chinese must apply OpenCC conversion
    // (`简体` → `簡體`) and the custom `full color` → `全彩` mapping.
    @Test
    func traditionalChineseAppliesOpenCCConversionAndCustomFullColor() throws {
        let built = try client.cacheAndBuildRemoteTagTranslator(
            try chineseResponseData(), .traditionalChinese, .distantPast
        )
        #expect(value(forKey: "simp", in: built) == "簡體")
        #expect(value(forKey: "fc", in: built) == "全彩")
    }

    // DEP-01 parity: any non-Traditional-Chinese table keeps its raw values untouched — no OpenCC
    // conversion and no custom `full color` remap.
    @Test
    func nonTraditionalChineseLeavesTagValuesUnconverted() throws {
        let built = try client.cacheAndBuildRemoteTagTranslator(
            try chineseResponseData(), .simplifiedChinese, .distantPast
        )
        #expect(value(forKey: "simp", in: built) == "简体")
        #expect(value(forKey: "fc", in: built) == "full color")
    }

    @Test
    func loadCachedTagTranslatorThrowsWhenCacheMissing() throws {
        // The root is fresh per case, so nothing has to be deleted to make the cache missing.
        #expect(throws: AppError.fileOperationFailed("Read cached tag translations")) {
            try client.loadCachedTagTranslator(TagTranslatorInfo(language: .japanese))
        }
    }

    // REV-14: removing custom translations must delete the imported file from Application Support so it
    // doesn't linger in non-purgeable storage forever.
    @Test
    func removeCustomTranslationsDeletesTheImportedFile() async throws {
        let url = try writeTemporaryFile(try sampleResponseData())

        _ = try await client.importTagTranslator(url).get()
        #expect(FileManager.default.fileExists(atPath: customTranslationsURL.path))

        try client.removeCustomTranslations()

        #expect(!FileManager.default.fileExists(atPath: customTranslationsURL.path))
        #expect(throws: AppError.fileOperationFailed("Read imported tag translations")) {
            try client.loadCachedTagTranslator(TagTranslatorInfo(hasCustomTranslations: true))
        }
    }
}
