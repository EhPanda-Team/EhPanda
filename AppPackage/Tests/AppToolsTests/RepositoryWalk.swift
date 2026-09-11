import Foundation
import Testing

/// Locates the repository checkout a source-scanning suite runs in.
///
/// Several suites in this target read the live tree rather than the built product — colorset JSON
/// the app resolves from the main bundle, view source whose gating a decision froze — and every one
/// of them needs the same two things: the checkout root, found by walking up from the suite's own
/// `#filePath` until both top-level trees are present, and a path relative to that root for the
/// error messages and pinned tables. They are shared here so the walk cannot drift between suites.
enum RepositoryWalk {
    /// Both directories every checkout carries; a directory holding just one is not the root.
    static let repositoryRootMarkers = ["App", "AppPackage"]

    /// The first ancestor of `filePath` that carries every marker.
    ///
    /// `#filePath` is expanded at the call site, so the default argument makes the walk start from
    /// the calling suite's own file without each caller having to spell it.
    static func repositoryRoot(from filePath: String = #filePath) throws -> URL {
        var directory = URL(filePath: filePath).deletingLastPathComponent()
        var located: URL?

        while located == nil, directory.path != "/" {
            if isRepositoryRoot(directory) {
                located = directory
            } else {
                directory = directory.deletingLastPathComponent()
            }
        }

        return try #require(
            located,
            "Could not locate the repository root; a source walk refuses a vacuous scan."
        )
    }

    static func isRepositoryRoot(_ directory: URL) -> Bool {
        let fileManager = FileManager.default
        return repositoryRootMarkers.allSatisfy({ marker in
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: directory.appending(path: marker).path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue
        })
    }

    /// `url` relative to `root`, or the absolute path when `url` lies outside it.
    static func relativePath(of url: URL, under root: URL) -> String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path + "/"
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count))
    }
}
