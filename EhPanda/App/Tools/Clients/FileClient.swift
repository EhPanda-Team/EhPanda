//
//  FileClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import Combine
import ComposableArchitecture

struct FileClient {
    let createFile: (String, Data?) -> Bool
    let fetchLogs: () -> Effect<Result<[Log], AppError>, Never>
    let deleteLog: (String) -> Effect<Result<String, AppError>, Never>
}

extension FileClient {
    static let live: Self = .init(
        createFile: { path, data in
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        },
        fetchLogs: {
            Future { promise in
                DispatchQueue.global().async {
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
            .subscribe(on: DispatchQueue.global())
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
