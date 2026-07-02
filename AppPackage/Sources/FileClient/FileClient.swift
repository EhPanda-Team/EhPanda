import AppModels
import Foundation
import ComposableArchitecture

public struct FileClient: Sendable {
    public var createFile: @Sendable (String, Data?) -> Bool
    public var importTagTranslator: @Sendable (URL) async -> Result<TagTranslator, AppError>
}

extension FileClient {
    public static let live: Self = .init(
        createFile: { path, data in
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        },
        importTagTranslator: { url in
            await withCheckedContinuation { continuation in
                // `.fileImporter` returns a security-scoped URL to the original file, which for an
                // iCloud item may not be downloaded yet. A coordinated read triggers the download and
                // runs the accessor only once the bytes are local. The security scope is released
                // inside the accessor: `coordinate(with:queue:)` returns immediately, so a `defer`
                // in this outer closure would drop the scope before the accessor ever reads.
                let didAccess = url.startAccessingSecurityScopedResource()
                let intent = NSFileAccessIntent.readingIntent(with: url, options: .withoutChanges)
                NSFileCoordinator().coordinate(with: [intent], queue: .init()) { error in
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    guard error == nil,
                          let data = try? Data(contentsOf: intent.url),
                          let translations = try? JSONDecoder().decode(
                            EhTagTranslationDatabaseResponse.self, from: data
                          ).tagTranslations,
                          !translations.isEmpty
                    else {
                        continuation.resume(returning: .failure(.parseFailed))
                        return
                    }
                    continuation.resume(
                        returning: .success(.init(hasCustomTranslations: true, translations: translations))
                    )
                }
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
