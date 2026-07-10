import AppModels
import Foundation
import ComposableArchitecture

public struct FileClient: Sendable {
    public var createFile: @Sendable (String, Data?) -> Bool
    public var importTagTranslator: @Sendable (URL) async -> Result<TagTranslator, AppError>
    /// Decodes the raw downloaded DB JSON, applies OpenCC conversion for Traditional Chinese, caches
    /// the raw bytes for a launch-time rebuild, and returns the built translator (`nil` on decode
    /// failure). The raw file — not the converted dictionary — is what persists.
    public var cacheAndBuildRemoteTagTranslator: @Sendable (Data, TranslatableLanguage, Date) -> TagTranslator?
    /// Rebuilds the in-memory translator from the cached raw JSON described by `info` — Application
    /// Support for a custom import, Caches for a remote download. `nil` if the cache is missing.
    public var loadCachedTagTranslator: @Sendable (TagTranslatorInfo) -> TagTranslator?
    /// Deletes the imported custom-translations file from Application Support. That directory is not
    /// purgeable, so a removed import must be cleaned up explicitly rather than left on disk forever.
    public var removeCustomTranslations: @Sendable () -> Void
}

// Fixed name for a user-imported table, kept in Application Support because it cannot be
// re-downloaded (unlike a remote table, which lives in purgeable Caches).
private let customTranslationsFilename = "tagTranslations-custom.json"

private var customTranslationsURL: URL {
    .applicationSupportDirectory.appending(component: customTranslationsFilename)
}
private func remoteTranslationsURL(_ language: TranslatableLanguage) -> URL {
    .cachesDirectory.appending(component: language.cachedTranslationsFilename)
}

// Decode raw DB JSON → flatten → OpenCC-convert for Traditional Chinese. `nil` if empty/undecodable.
private func decodeTranslations(
    _ data: Data, applyingChtFor language: TranslatableLanguage?
) -> [String: TagTranslation]? {
    guard var translations = try? JSONDecoder()
        .decode(EhTagTranslationDatabaseResponse.self, from: data).tagTranslations,
          !translations.isEmpty
    else { return nil }
    if language == .traditionalChinese {
        translations = translations.chtConverted
    }
    return translations
}

private func writeTranslations(_ data: Data, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try? data.write(to: url, options: .atomic)
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
                          let translations = decodeTranslations(data, applyingChtFor: nil)
                    else {
                        continuation.resume(returning: .failure(.parseFailed))
                        return
                    }
                    // Persist the raw bytes so a launch-time rebuild can restore the import.
                    writeTranslations(data, to: customTranslationsURL)
                    continuation.resume(
                        returning: .success(.init(hasCustomTranslations: true, translations: translations))
                    )
                }
            }
        },
        cacheAndBuildRemoteTagTranslator: { data, language, date in
            guard let translations = decodeTranslations(data, applyingChtFor: language) else { return nil }
            writeTranslations(data, to: remoteTranslationsURL(language))
            return TagTranslator(language: language, updatedDate: date, translations: translations)
        },
        loadCachedTagTranslator: { info in
            if info.hasCustomTranslations {
                guard let data = try? Data(contentsOf: customTranslationsURL),
                      let translations = decodeTranslations(data, applyingChtFor: nil)
                else { return nil }
                return TagTranslator(hasCustomTranslations: true, translations: translations)
            }
            guard let language = info.language,
                  let data = try? Data(contentsOf: remoteTranslationsURL(language)),
                  let translations = decodeTranslations(data, applyingChtFor: language)
            else { return nil }
            return TagTranslator(
                language: language, updatedDate: info.updatedDate, translations: translations
            )
        },
        removeCustomTranslations: {
            try? FileManager.default.removeItem(at: customTranslationsURL)
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
        importTagTranslator: { _ in .success(.init()) },
        cacheAndBuildRemoteTagTranslator: { _, _, _ in nil },
        loadCachedTagTranslator: { _ in nil },
        removeCustomTranslations: {}
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        createFile: IssueReporting.unimplemented(placeholder: placeholder()),
        importTagTranslator: IssueReporting.unimplemented(placeholder: placeholder()),
        cacheAndBuildRemoteTagTranslator: IssueReporting.unimplemented(placeholder: placeholder()),
        loadCachedTagTranslator: IssueReporting.unimplemented(placeholder: placeholder()),
        removeCustomTranslations: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
