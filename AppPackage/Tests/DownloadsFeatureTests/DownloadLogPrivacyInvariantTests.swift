import Foundation
import Testing

/// Keeps gallery-derived values out of public unified-log fields without removing operational logs.
///
/// The scan is intentionally limited to `DownloadClient`, whose sources handle gallery identifiers,
/// title-bearing folder paths, and gallery responses. A whole-tree rule would create exemptions
/// wherever no gallery value can exist instead of strengthening this boundary. In particular,
/// `ContinuedProcessingSession.swift` remains out of scope after auditing its two public fields: its
/// identifier is a bundle identifier plus a minted UUID, and its submission error occurs before any
/// gallery value is in scope.
@Suite
struct DownloadLogPrivacyInvariantTests {
    private struct ScannedFile {
        let relativePath: String
        let contents: String
    }

    private struct ForbiddenInterpolation {
        let description: String
        let token: String
    }

    private static let clientModuleDirectory = "AppPackage/Sources/DownloadClient"
    private static let knownMember = clientModuleDirectory + "/DownloadClient+Execution.swift"
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    /// These tokens are assembled from fragments at run time because spelling a complete banned
    /// shape here would make repository grep gates match the invariant that enforces them.
    private static var forbiddenInterpolations: [ForbiddenInterpolation] {
        let publicClassification = ", privacy: ." + "public"
        return [
            ForbiddenInterpolation(
                description: "a gallery identifier",
                token: "gid" + publicClassification
            ),
            ForbiddenInterpolation(
                description: "a gallery title",
                token: "title" + publicClassification
            ),
            ForbiddenInterpolation(
                description: "a raw error value",
                token: "error" + publicClassification
            ),
            ForbiddenInterpolation(
                description: "a localized error description",
                token: "localizedDescription" + publicClassification
            )
        ]
    }

    private static var hashMaskedClassification: String {
        "privacy: ." + "private(mask: .hash)"
    }

    @Test
    func testNoDownloadLogPublishesGalleryIdentity() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try #require(files.contains(where: { $0.relativePath == Self.knownMember }))

        for forbidden in Self.forbiddenInterpolations {
            let offenders = files
                .filter({ $0.contents.contains(forbidden.token) })
                .map(\.relativePath)
            #expect(
                offenders.isEmpty,
                "A public log interpolation exposes \(forbidden.description) in: \(offenders)"
            )
        }
    }

    @Test
    func testDownloadIdentityLogsStayHashMasked() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try #require(files.contains(where: { $0.relativePath == Self.knownMember }))
        let contents = files.map(\.contents).joined(separator: "\n")

        let maskedCount = contents.components(separatedBy: Self.hashMaskedClassification).count - 1
        #expect(maskedCount >= 8)
        for message in [
            "Download completed",
            "Download enqueued",
            "Download paused",
            "Download resumed"
        ] {
            #expect(contents.contains(message), "The operational log message disappeared: \(message)")
        }
    }
}

// MARK: - Scanning

private extension DownloadLogPrivacyInvariantTests {
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let directory = root.appending(path: clientModuleDirectory)
        let fileManager = FileManager.default
        let enumerator = try #require(
            fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            )
        )
        let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
        var files = [ScannedFile]()

        for case let url as URL in enumerator
        where url.pathExtension == "swift"
            && url.standardizedFileURL.path != invariantFilePath {
            files.append(
                ScannedFile(
                    relativePath: repositoryRelativePath(of: url, under: root),
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            )
        }
        return files
    }

    static func repositoryRoot() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
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
            "Could not locate the repository root; the privacy invariant refuses a vacuous scan."
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

    static func repositoryRelativePath(of url: URL, under root: URL) -> String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path + "/"
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count))
    }
}
