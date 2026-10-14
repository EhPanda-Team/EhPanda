import DownloadClient
import Foundation
import Testing

struct DownloadPathContainmentTests {
    @Test(arguments: [URL.DirectoryHint.isDirectory, .notDirectory])
    func relativePathsIgnoreDirectoryHints(_ hint: URL.DirectoryHint) {
        let root = URL(filePath: "/tmp/Downloads", directoryHint: hint)
        let store = DownloadStore(rootURL: root)
        let folder = root.appending(path: "收藏/%2F title", directoryHint: .isDirectory)

        #expect(store.rootRelativePath(forFolderURL: folder) == "收藏/%2F title")
        #expect(store.parentFolderName(forFolderURL: folder) == "收藏")
        #expect(store.rootRelativePath(forFolderURL: root) == nil)
        #expect(store.rootRelativePath(forFolderURL: URL(filePath: "/tmp/Downloads-other/gallery")) == nil)
    }

    @Test(arguments: ["..", "../Downloads-other/gallery", "gallery/../../outside", "."])
    func rejectsPathsOutsideTheRoot(_ path: String) {
        let root = URL(filePath: "/tmp/Downloads", directoryHint: .isDirectory)
        let store = DownloadStore(rootURL: root)

        #expect(store.validatedChildURL(root: root, relativePath: path) == nil)
    }

    @Test(arguments: [URL.DirectoryHint.isDirectory, .notDirectory])
    func deletionKeepsTheRootAndSiblingFolders(_ hint: URL.DirectoryHint) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: temporary)
            } catch {
                Issue.record(error)
            }
        }
        let root = URL(filePath: temporary.appending(component: "Downloads").path(percentEncoded: false),
                       directoryHint: hint)
        let child = root.appending(component: "Gallery", directoryHint: .isDirectory)
        let sibling = temporary.appending(component: "Downloads-other", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let store = DownloadStore(rootURL: root)

        #expect(throws: (any Error).self) { try store.removeFolder(at: root) }
        #expect(throws: (any Error).self) { try store.removeFolder(at: sibling) }
        try store.removeFolder(at: child)
        #expect(FileManager.default.fileExists(atPath: root.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: sibling.path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: child.path(percentEncoded: false)))
    }
}
