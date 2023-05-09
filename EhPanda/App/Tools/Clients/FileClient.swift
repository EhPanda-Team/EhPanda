//
//  FileClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import Combine
import Foundation
import ComposableArchitecture

struct FileClient {
    let createFile: (String, Data?) -> Bool
    let fetchLogs: () -> EffectTask<Result<[Log], AppError>>
    let deleteLog: (String) -> EffectTask<Result<String, AppError>>
    let importTagTranslator: (URL) -> EffectTask<Result<TagTranslator, AppError>>
}

extension FileClient {
    static let live: Self = .init(
        createFile: { path, data in
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        },
        fetchLogs: {
            Future { promise in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let path = FileUtil.logsDirectoryURL?.path,
                          let enumerator = FileManager.default.enumerator(atPath: path),
                          let fileNames = (enumerator.allObjects as? [String])?
                            .filter({ $0.contains(Defaults.FilePath.ehpandaLog) })
                    else {
                        promise(.failure(.notFound))
                        return
                    }

                    let logs: [Log] = fileNames.compactMap { name in
                        guard let fileURL = FileUtil.logsDirectoryURL?.appendingPathComponent(name),
                              let content = try? String(contentsOf: fileURL)
                        else { return nil }

                        return Log(
                            fileName: name, contents: content
                                .components(separatedBy: "\n")
                                .filter({ !$0.isEmpty })
                        )
                    }
                    .sorted()
                    promise(.success(logs))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        },
        deleteLog: { fileName in
            Future { promise in
                guard let fileURL = FileUtil.logsDirectoryURL?.appendingPathComponent(fileName)
                else {
                    promise(.failure(.notFound))
                    return
                }

                try? FileManager.default.removeItem(at: fileURL)

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    promise(.failure(.unknown))
                }
                promise(.success(fileName))
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
        },
        importTagTranslator: { url in
            Future { promise in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let data = try? Data(contentsOf: url),
                          let translations = try? JSONDecoder().decode(
                            EhTagTranslationDatabaseResponse.self, from: data
                          ).tagTranslations
                    else {
                        promise(.failure(.parseFailed))
                        return
                    }
                    guard !translations.isEmpty else {
                        promise(.failure(.parseFailed))
                        return
                    }
                    promise(.success(.init(hasCustomTranslations: true, translations: translations)))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .catchToEffect()
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
        fetchLogs: { .none },
        deleteLog: { _ in .none },
        importTagTranslator: { _ in .none }
    )

    static let unimplemented: Self = .init(
        createFile: XCTestDynamicOverlay.unimplemented("\(Self.self).createFile"),
        fetchLogs: XCTestDynamicOverlay.unimplemented("\(Self.self).fetchLogs"),
        deleteLog: XCTestDynamicOverlay.unimplemented("\(Self.self).deleteLog"),
        importTagTranslator: XCTestDynamicOverlay.unimplemented("\(Self.self).importTagTranslator")
    )
}
