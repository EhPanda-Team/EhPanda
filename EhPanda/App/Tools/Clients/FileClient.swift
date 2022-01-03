//
//  FileClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture
import Combine

struct FileClient {
    let fetchLogs: () -> Effect<Result<[Log], AppError>, Never>
    let deleteLog: (String) -> Effect<Result<String, AppError>, Never>
}

extension FileClient {
    static let live: Self = .init(
        fetchLogs: {
            Future { promise in
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
            .eraseToAnyPublisher()
            .subscribe(on: DispatchQueue.global())
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
}
