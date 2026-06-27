import Foundation
import Synchronization

final class DownloadFileManager: Sendable {
    private let fileManager: Mutex<FileManager>

    init(_ fileManager: sending FileManager) {
        self.fileManager = Mutex(fileManager)
    }

    func operate<T>(
        _ body: (inout sending FileManager) throws -> sending T
    ) rethrows -> sending T {
        try fileManager.withLock(body)
    }
}
