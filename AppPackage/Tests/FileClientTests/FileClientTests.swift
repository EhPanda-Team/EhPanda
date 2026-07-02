import Testing
import Foundation
import AppModels
import FileClient

// Exercises the live importer's coordinated, security-scoped read (REV-1) against local files;
// the iCloud download that coordination triggers is system behavior, smoke-tested manually.
@Suite
struct FileClientTests {
    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "tags-\(UUID().uuidString).json")
        try data.write(to: url)
        return url
    }

    @Test
    func importsValidTranslationFileViaCoordinatedRead() async throws {
        let response = EhTagTranslationDatabaseResponse(
            data: [.init(namespace: "female", data: ["tag": .init(name: "translated")])]
        )
        let url = try writeTemporaryFile(JSONEncoder().encode(response))
        defer { try? FileManager.default.removeItem(at: url) }

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
}
