//
//  FileUtil.swift
//  EhPanda
//

import Foundation

struct FileUtil {
    static var documentDirectory: URL {
        .documentsDirectory
    }
    static var cachesDirectory: URL {
        .cachesDirectory
    }
    static var logsDirectoryURL: URL {
        documentDirectory.appendingPathComponent(Defaults.FilePath.logs)
    }
    static var downloadsDirectoryURL: URL {
        documentDirectory.appendingPathComponent(
            Defaults.FilePath.downloads,
            isDirectory: true
        )
    }
    static var temporaryDirectory: URL {
        .init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
}
