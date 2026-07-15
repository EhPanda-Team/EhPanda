import AppModels
import Foundation
import ComposableArchitecture

public struct FileClient: Sendable {
    public var createFile: @Sendable (String, Data?) -> Bool
    public var importTagTranslator: @Sendable (URL) async -> Result<TagTranslator, AppError>
    /// Decodes the raw downloaded DB JSON, applies OpenCC conversion for Traditional Chinese, caches
    /// the raw bytes for a launch-time rebuild, and returns the built translator (`nil` on decode
    /// failure throws a file-operation error). The raw file — not the converted dictionary — is
    /// what persists.
    public var cacheAndBuildRemoteTagTranslator: @Sendable (
        Data, TranslatableLanguage, Date
    ) throws(AppError) -> TagTranslator
    /// Rebuilds the in-memory translator from the cached raw JSON described by `info` — Application
    /// Support for a custom import, Caches for a remote download. A missing cache throws a
    /// file-operation error so the caller can choose whether to recover by downloading it again.
    public var loadCachedTagTranslator: @Sendable (TagTranslatorInfo) throws(AppError) -> TagTranslator
    /// Deletes the imported custom-translations file from Application Support. That directory is not
    /// purgeable, so a removed import must be cleaned up explicitly rather than left on disk forever.
    public var removeCustomTranslations: @Sendable () throws(AppError) -> Void
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

// Decode raw DB JSON → flatten → OpenCC-convert for Traditional Chinese.
private func decodeTranslations(
    _ data: Data, applyingChtFor language: TranslatableLanguage?
) throws(AppError) -> [String: TagTranslation] {
    let decodedTranslations: [String: TagTranslation]
    do {
        decodedTranslations = try JSONDecoder()
            .decode(EhTagTranslationDatabaseResponse.self, from: data).tagTranslations
    } catch {
        throw .fileOperationFailed("Decode tag translations")
    }
    guard !decodedTranslations.isEmpty else {
        throw .fileOperationFailed("Decode tag translations")
    }
    var translations = decodedTranslations
    if language == .traditionalChinese {
        translations = translations.chtConverted
    }
    return translations
}

private func writeTranslations(_ data: Data, to url: URL) throws(AppError) {
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    } catch {
        throw .fileOperationFailed("Write tag translations")
    }
}

private func buildAndCacheTranslations(
    data: Data,
    language: TranslatableLanguage,
    date: Date
) throws(AppError) -> TagTranslator {
    let translations = try decodeTranslations(data, applyingChtFor: language)
    try writeTranslations(data, to: remoteTranslationsURL(language))
    return TagTranslator(language: language, updatedDate: date, translations: translations)
}

private func loadCachedTranslations(info: TagTranslatorInfo) throws(AppError) -> TagTranslator {
    if info.hasCustomTranslations {
        let data: Data
        do {
            data = try Data(contentsOf: customTranslationsURL)
        } catch {
            throw .fileOperationFailed("Read imported tag translations")
        }
        let translations = try decodeTranslations(data, applyingChtFor: nil)
        return TagTranslator(hasCustomTranslations: true, translations: translations)
    }
    guard let language = info.language else {
        throw .fileOperationFailed("Resolve cached tag translations")
    }
    let data: Data
    do {
        data = try Data(contentsOf: remoteTranslationsURL(language))
    } catch {
        throw .fileOperationFailed("Read cached tag translations")
    }
    let translations = try decodeTranslations(data, applyingChtFor: language)
    return TagTranslator(
        language: language, updatedDate: info.updatedDate, translations: translations
    )
}

private func removeCustomTranslationsFile() throws(AppError) {
    do {
        try FileManager.default.removeItem(at: customTranslationsURL)
    } catch {
        throw .fileOperationFailed("Remove imported tag translations")
    }
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
                    do throws(AppError) {
                        guard error == nil else {
                            throw .fileOperationFailed("Coordinate tag translations import")
                        }
                        let data: Data
                        do {
                            data = try Data(contentsOf: intent.url)
                        } catch {
                            throw .fileOperationFailed("Read imported tag translations")
                        }
                        let translations = try decodeTranslations(data, applyingChtFor: nil)
                        // Persist the raw bytes so a launch-time rebuild can restore the import.
                        try writeTranslations(data, to: customTranslationsURL)
                        continuation.resume(
                            returning: .success(
                                .init(hasCustomTranslations: true, translations: translations)
                            )
                        )
                    } catch {
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        },
        cacheAndBuildRemoteTagTranslator: buildAndCacheTranslations,
        loadCachedTagTranslator: loadCachedTranslations,
        removeCustomTranslations: removeCustomTranslationsFile
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
        cacheAndBuildRemoteTagTranslator: { (_: Data, _: TranslatableLanguage, _: Date) throws(AppError) in
            throw .fileOperationFailed("Cache tag translations")
        },
        loadCachedTagTranslator: { (_: TagTranslatorInfo) throws(AppError) -> TagTranslator in
            throw .fileOperationFailed("Load cached tag translations")
        },
        removeCustomTranslations: { () throws(AppError) in
            throw .fileOperationFailed("Remove imported tag translations")
        }
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
