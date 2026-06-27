import Foundation

actor DownloadBackgroundTaskStore {
    struct Record: Codable, Equatable, Sendable {
        let gid: String
        let pageIndex: Int
    }

    private let fileURL: URL
    private let fileManager: DownloadFileManager
    private var records: [Int: Record]

    init(
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

    func record(
        taskIdentifier: Int,
        gid: String,
        pageIndex: Int
    ) async {
        records[taskIdentifier] = .init(gid: gid, pageIndex: pageIndex)
        await save()
    }

    func record(taskIdentifier: Int) -> Record? {
        records[taskIdentifier]
    }

    func records(for gid: String) -> [Int: Record] {
        records.filter { $0.value.gid == gid }
    }

    @discardableResult
    func remove(taskIdentifier: Int) async -> Record? {
        let record = records.removeValue(forKey: taskIdentifier)
        await save()
        return record
    }

    func removeAll(for gid: String) async {
        records = records.filter { $0.value.gid != gid }
        await save()
    }

    func removeAll() async {
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
            Logger.error(error)
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
            Logger.error(error)
        }
    }
}
