public import Foundation

public struct FileUtil {
    public static var logsDirectoryURL: URL {
        .documentsDirectory.appending(path: Defaults.FilePath.logs)
    }
    public static var downloadsDirectoryURL: URL {
        .documentsDirectory.appending(
            path: Defaults.FilePath.downloads,
            directoryHint: .isDirectory
        )
    }
}
