import Foundation
import AppModels

public actor DownloadBackgroundTaskStore {
    public struct Record: Codable, Equatable, Sendable {
        public let gid: String
        public let pageIndex: Int
        public init(
            gid: String,
            pageIndex: Int
        ) {
            self.gid = gid
            self.pageIndex = pageIndex
        }
    }

    private let fileURL: URL
    private let fileManager: DownloadFileManager
    private var records: [Int: Record]

    public init(
        fileURL: URL,
        fileManager: sending FileManager = FileManager()
    ) {
        self.fileURL = fileURL
        self.fileManager = DownloadFileManager(fileManager)
        self.records = Self.loadRecords(
            fileURL: fileURL,
            fileManager: self.fileManager
        )
    }

    public func record(
        taskIdentifier: Int,
        gid: String,
        pageIndex: Int
    ) async {
        records[taskIdentifier] = .init(gid: gid, pageIndex: pageIndex)
        await save()
    }

    public func record(taskIdentifier: Int) -> Record? {
        records[taskIdentifier]
    }

    public func records(for gid: String) -> [Int: Record] {
        records.filter { $0.value.gid == gid }
    }

    @discardableResult
    public func remove(taskIdentifier: Int) async -> Record? {
        let record = records.removeValue(forKey: taskIdentifier)
        await save()
        return record
    }

    public func removeAll(for gid: String) async {
        records = records.filter { $0.value.gid != gid }
        await save()
    }

    public func removeAll() async {
        records.removeAll()
        await save()
    }

    private static func loadRecords(
        fileURL: URL,
        fileManager: DownloadFileManager
    ) -> [Int: Record] {
        guard fileManager.operate({ $0.fileExists(atPath: fileURL.path) }) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Int: Record].self, from: data)
        } catch {
            logger.error("\(error, privacy: .public)")
            return [:]
        }
    }

    private func save() async {
        do {
            try fileManager.operate {
                try $0.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            }
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("\(error, privacy: .public)")
        }
    }
}
