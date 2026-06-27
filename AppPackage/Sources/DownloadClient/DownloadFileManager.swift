import Foundation
import Synchronization

public final class DownloadFileManager: Sendable {
    private let fileManager: Mutex<FileManager>

    public init(_ fileManager: sending FileManager) {
        self.fileManager = Mutex(fileManager)
    }

    public func operate<T>(
        _ body: (inout sending FileManager) throws -> sending T
    ) rethrows -> sending T {
        try fileManager.withLock(body)
    }
}
