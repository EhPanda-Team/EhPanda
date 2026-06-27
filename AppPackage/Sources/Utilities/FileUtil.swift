import Foundation
import AppModels

public struct FileUtil {
    public static var logsDirectoryURL: URL {
        .documentsDirectory.appendingPathComponent(Defaults.FilePath.logs)
    }
    public static var downloadsDirectoryURL: URL {
        .documentsDirectory.appendingPathComponent(
            Defaults.FilePath.downloads,
            isDirectory: true
        )
    }
}
