import AppModels
import Foundation
import ComposableArchitecture

public struct FileClient: Sendable {
    public let createFile: @Sendable (String, Data?) -> Bool
    public let importTagTranslator: @Sendable (URL) async -> Result<TagTranslator, AppError>
}

extension FileClient {
    public static let live: Self = .init(
        createFile: { path, data in
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        },
        importTagTranslator: { url in
            await withCheckedContinuation { continuation in
                // `.fileImporter` returns a security-scoped URL to the original file; access must be
                // claimed before reading and released afterwards, unlike a copied-in temp file.
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url),
                      let translations = try? JSONDecoder().decode(
                        EhTagTranslationDatabaseResponse.self, from: data
                      ).tagTranslations
                else {
                    continuation.resume(returning: .failure(.parseFailed))
                    return
                }
                guard !translations.isEmpty else {
                    continuation.resume(returning: .failure(.parseFailed))
                    return
                }
                continuation.resume(returning: .success(.init(hasCustomTranslations: true, translations: translations)))
            }
        }
    )

    public func saveTorrent(hash: String, data: Data) -> URL? {
        let torrentDirectory = URL.cachesDirectory.appendingPathComponent("\(hash).torrent")
        return createFile(torrentDirectory.path, data) ? torrentDirectory : nil
    }
}

// MARK: API
public enum FileClientKey: DependencyKey {
    public static let liveValue = FileClient.live
    public static let previewValue = FileClient.noop
    public static let testValue = FileClient.unimplemented
}

extension DependencyValues {
    public var fileClient: FileClient {
        get { self[FileClientKey.self] }
        set { self[FileClientKey.self] = newValue }
    }
}

// MARK: Test
extension FileClient {
    public static let noop: Self = .init(
        createFile: { _, _ in false },
        importTagTranslator: { _ in .success(.init()) }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        createFile: IssueReporting.unimplemented(placeholder: placeholder()),
        importTagTranslator: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
