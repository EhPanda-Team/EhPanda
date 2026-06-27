import Foundation

struct FileUtil {
    static var logsDirectoryURL: URL {
        .documentsDirectory.appendingPathComponent(Defaults.FilePath.logs)
    }
    static var downloadsDirectoryURL: URL {
        .documentsDirectory.appendingPathComponent(
            Defaults.FilePath.downloads,
            isDirectory: true
        )
    }
}
