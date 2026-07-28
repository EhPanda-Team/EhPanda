import Foundation
import Testing

/// Locks this phase's topology decision into a check the build can make: the app keeps exactly one
/// background-execution mechanism, and every symbol of the two it replaced is gone from the tree.
///
/// The decision was a deletion, and a deletion leaves behind no symbol to hang an ordinary unit
/// test on. Without this suite the only thing standing between the repository and a quietly
/// reintroduced second tier is a planning document, which no build reads. So the suite reads the
/// sources themselves: it walks the app target, the package sources, the package tests and the
/// extension, and fails if any deleted spelling comes back.
@Suite
struct BackgroundExecutionInvariantTests {
    /// One scanned file, read once and carried with the path a failure should name.
    private struct ScannedFile {
        let relativePath: String
        let contents: String
    }

    /// One banned spelling, paired with prose a failure can print.
    ///
    /// The description deliberately never spells its token out. This file is itself covered by the
    /// repository's grep gates, and those gates must read zero.
    private struct ForbiddenToken {
        let description: String
        let token: String
    }

    // MARK: - Scan scope

    /// Directories, relative to the repository root, whose Swift sources are in scope.
    private static let scannedDirectories = [
        "App",
        "AppPackage/Sources",
        "AppPackage/Tests",
        "ShareExtension"
    ]

    /// The one non-Swift file in scope.
    ///
    /// It is scanned for the forbidden tokens alongside every Swift source, because the two deleted
    /// task-identifier strings are exactly the kind of thing that would reappear here first.
    /// Dropping the plist from that scan would open the very hole the scan exists to close.
    private static let infoPlistRelativePath = "App/Info.plist"

    /// The only module permitted to name the system task scheduler.
    private static let clientModuleDirectory = "AppPackage/Sources/BackgroundProcessingClient/"

    /// Directories that must both exist for a candidate directory to be the repository root.
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    /// Files exempt from the scheduler-scope assertion, and from that assertion only.
    ///
    /// `App/Info.plist` declares a system-defined key whose *name* contains the scheduler type name
    /// as a substring by construction. That substring is a plist key name, not a code reference to
    /// the scheduler, and the key is required for this phase's capability to work at all — it
    /// outlives the phase. Deleting this exemption would therefore not make the assertion stricter;
    /// it would make the assertion permanently unsatisfiable, no matter how correct the code was.
    ///
    /// The exemption is paid for rather than waived. The same test requires that every line of that
    /// plist mentioning the scheduler name is that one key declaration, so a second, different
    /// scheduler mention makes the counts diverge and fails. The plist also stays fully in scope for
    /// the forbidden-token scan. The exemption narrows what is checked in that file; it never
    /// removes the file from checking.
    private static let schedulerScopeExemptions: Set<String> = [infoPlistRelativePath]

    // MARK: - Banned spellings

    /// The spellings that must not reappear anywhere in scope.
    ///
    /// Every token is assembled from fragments at run time rather than written as a literal. This
    /// is mechanical rather than clever: a literal here would be a self-match, so the invariant
    /// would fail the moment it was written and the repository-wide grep gates could never read
    /// zero. The same reason applies to the scheduler name below.
    private static var forbiddenTokens: [ForbiddenToken] {
        [
            ForbiddenToken(
                description: "the deleted discretionary processing-task class name",
                token: "BG" + "Processing" + "Task"
            ),
            ForbiddenToken(
                description: "the deleted UIKit execution-assertion method name",
                token: "begin" + "Background" + "Task"
            ),
            ForbiddenToken(
                description: "the deleted execution-assertion client type name",
                token: "Background" + "Task" + "Client"
            ),
            ForbiddenToken(
                description: "the deleted queue drain method name",
                token: "run" + "Queue" + "Until" + "Idle"
            ),
            ForbiddenToken(
                description: "the deleted discretionary task identifier",
                token: "downloads" + "." + "processing"
            ),
            ForbiddenToken(
                description: "the deleted execution-assertion identifier",
                token: "downloads" + "." + "assertion"
            ),
            ForbiddenToken(
                description: "the unchecked concurrency conformance banned by the linter",
                token: "@unchecked" + " " + "Sendable"
            ),
            ForbiddenToken(
                description: "the unsafe-nonisolated annotation banned by the linter",
                token: "nonisolated" + "(" + "unsafe" + ")"
            )
        ]
    }

    /// The system task scheduler's type name, assembled for the same self-match reason.
    private static var systemSchedulerName: String {
        "BG" + "Task" + "Scheduler"
    }

    /// The permitted-identifiers plist key, built from the same fragments.
    private static var permittedIdentifiersKey: String {
        systemSchedulerName + "Permitted" + "Identifiers"
    }

    // MARK: - Tests

    /// Neither deleted background-execution mechanism may leave a trace anywhere in scope.
    @Test
    func testNoDeletedBackgroundExecutionSpellingSurvivesAnywhere() throws {
        let root = try Self.repositoryRoot()
        let files = try Self.scannedFiles(under: root)

        // A scan that silently finds nothing to read is worse than no scan, so the shape of the
        // input is asserted before anything is asserted about its contents.
        try #require(!files.isEmpty)
        #expect(
            files.contains(where: { $0.relativePath == Self.infoPlistRelativePath }),
            "The plist fell out of the forbidden-token scan; the deleted identifiers would return there first."
        )

        for forbidden in Self.forbiddenTokens {
            let offenders = files
                .filter({ $0.contents.contains(forbidden.token) })
                .map(\.relativePath)
            #expect(
                offenders.isEmpty,
                "\(forbidden.description) reappeared in: \(offenders.joined(separator: ", "))"
            )
        }
    }

    /// The system task scheduler is reachable from exactly one module: the client seam.
    ///
    /// The plist is exempt from the scope half of this test and held to a stricter count instead;
    /// see `schedulerScopeExemptions` for why that narrows the check rather than relaxing it.
    @Test
    func testTheSystemSchedulerIsNamedOnlyByTheClientSeam() throws {
        let root = try Self.repositoryRoot()
        let files = try Self.scannedFiles(under: root)
        try #require(!files.isEmpty)

        let schedulerName = Self.systemSchedulerName
        let outOfScope = files
            .filter({ !Self.schedulerScopeExemptions.contains($0.relativePath) })
            .filter({ $0.contents.contains(schedulerName) })
            .filter({ !$0.relativePath.hasPrefix(Self.clientModuleDirectory) })
            .map(\.relativePath)
        #expect(
            outOfScope.isEmpty,
            "The system task scheduler is named outside the client seam in: \(outOfScope.joined(separator: ", "))"
        )

        let plist = try #require(
            files.first(where: { $0.relativePath == Self.infoPlistRelativePath })
        )
        let lines = plist.contents.split(separator: "\n", omittingEmptySubsequences: false)
        let schedulerLines = lines.filter({ $0.contains(schedulerName) }).count
        let permittedKeyLines = lines.filter({ $0.contains(Self.permittedIdentifiersKey) }).count
        #expect(
            schedulerLines == permittedKeyLines,
            "The plist mentions the scheduler somewhere other than the permitted-identifiers key."
        )
        #expect(permittedKeyLines == 1)
    }
}

// MARK: - Scanning

private extension BackgroundExecutionInvariantTests {
    /// Walks up from this file's own compile-time path until it finds the directory holding both
    /// repository markers, so the scan works from any contributor's checkout.
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
            """
            Could not locate the repository root by walking up from this file. The invariant would \
            scan nothing in that state, so it fails loudly here rather than passing vacuously.
            """
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

    /// Every Swift source under the scanned directories, plus the one auxiliary file, minus this
    /// file itself.
    ///
    /// Excluding this file by path is a second line of defence behind the assembled tokens: even if
    /// a future edit spelled one out, the scan would not read it back as a violation of itself.
    private static func scannedFiles(under root: URL) throws -> [ScannedFile] {
        let fileManager = FileManager.default
        var urls = [URL]()

        for directory in scannedDirectories {
            let directoryURL = root.appending(path: directory)
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                urls.append(url)
            }
        }
        urls.append(root.appending(path: infoPlistRelativePath))

        let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
        var files = [ScannedFile]()
        for url in urls where url.standardizedFileURL.path != invariantFilePath {
            files.append(
                ScannedFile(
                    relativePath: repositoryRelativePath(of: url, under: root),
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            )
        }
        return files
    }

    static func repositoryRelativePath(of url: URL, under root: URL) -> String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path + "/"
        guard path.hasPrefix(rootPath) else {
            return path
        }
        return String(path.dropFirst(rootPath.count))
    }
}
