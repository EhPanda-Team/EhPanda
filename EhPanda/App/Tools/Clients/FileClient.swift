//
//  FileClient.swift
//  EhPanda
//

import Combine
import Foundation
import ComposableArchitecture

struct FileClient {
    let createFile: (String, Data?) -> Bool
    let fetchLogs: () async -> Result<[Log], AppError>
    let deleteLog: (String) async -> Result<String, AppError>
    let importTagTranslator: (URL) async -> Result<TagTranslator, AppError>
}

extension FileClient {
    static let live: Self = .init(
        createFile: { path, data in
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        },
        fetchLogs: {
            await withCheckedContinuation { continuation in
                guard let path = FileUtil.logsDirectoryURL?.path,
                      let enumerator = FileManager.default.enumerator(atPath: path),
                      let fileNames = (enumerator.allObjects as? [String])?
                        .filter({ $0.contains(Defaults.FilePath.ehpandaLog) })
                else {
                    continuation.resume(returning: .failure(.notFound))
                    return
                }

                let logs: [Log] = fileNames.compactMap { name in
                    guard let fileURL = FileUtil.logsDirectoryURL?.appendingPathComponent(name),
                          let content = try? String(contentsOf: fileURL, encoding: .utf8)
                    else { return nil }

                    return Log(
                        fileName: name, contents: content
                            .components(separatedBy: "\n")
                            .filter({ !$0.isEmpty })
                    )
                }
                .sorted()
                continuation.resume(returning: .success(logs))
            }
        },
        deleteLog: { fileName in
            await withCheckedContinuation { continuation in
                guard let fileURL = FileUtil.logsDirectoryURL?.appendingPathComponent(fileName)
                else {
                continuation.resume(returning: .failure(.notFound))
                    return
                }

                try? FileManager.default.removeItem(at: fileURL)

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    continuation.resume(returning: .failure(.unknown))
                }
                continuation.resume(returning: .success(fileName))
            }
        },
        importTagTranslator: { url in
            await withCheckedContinuation { continuation in
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

    func saveTorrent(hash: String, data: Data) -> URL? {
        if let cachesDirectory = FileUtil.cachesDirectory {
            let torrentDirectory = cachesDirectory.appendingPathComponent("\(hash).torrent")
            return createFile(torrentDirectory.path, data) ? torrentDirectory : nil
        } else {
            return nil
        }
    }
}

// MARK: API
enum FileClientKey: DependencyKey {
    static let liveValue = FileClient.live
    static let previewValue = FileClient.noop
    static let testValue = FileClient.unimplemented
}

extension DependencyValues {
    var fileClient: FileClient {
        get { self[FileClientKey.self] }
        set { self[FileClientKey.self] = newValue }
    }
}

// MARK: Test
extension FileClient {
    static let noop: Self = .init(
        createFile: { _, _ in false },
        fetchLogs: { .success([]) },
        deleteLog: { _ in .success("") },
        importTagTranslator: { _ in .success(.init()) }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        createFile: IssueReporting.unimplemented(placeholder: placeholder()),
        fetchLogs: IssueReporting.unimplemented(placeholder: placeholder()),
        deleteLog: IssueReporting.unimplemented(placeholder: placeholder()),
        importTagTranslator: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
