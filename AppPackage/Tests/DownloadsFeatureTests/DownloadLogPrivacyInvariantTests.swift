import Foundation
import Testing

/// Keeps gallery-derived values out of public unified-log fields without removing operational logs.
///
/// The scan covers two modules: `DownloadClient`, whose sources handle gallery identifiers,
/// title-bearing folder paths and gallery responses, and `BackgroundProcessingClient`, which
/// publishes log lines adjacent to system submission where scheduler errors flow. A whole-tree rule
/// would create exemptions wherever no gallery value can exist instead of strengthening this
/// boundary, and that rationale still governs everything outside these two directories.
///
/// The background-processing module was previously out of scope on a point-in-time audit of its two
/// public fields. That audit was accurate about the identifier — a bundle identifier plus a minted
/// UUID — and wrong about the other field: the submission failure logged its raw `Error` value
/// public, and a scheduler error may embed arbitrary system strings. IN-04 retires the audit
/// sentence in favor of this scan, so the module now passes the same rules the download client
/// passes, with no allowlist entry and no line-level exemption.
@Suite
struct DownloadLogPrivacyInvariantTests {
    private struct ScannedFile {
        let relativePath: String
        let contents: String

        var fileName: String {
            relativePath.split(separator: "/").last.map(String.init) ?? relativePath
        }
    }

    private struct ForbiddenInterpolation {
        let description: String
        let token: String
    }

    private static let clientModuleDirectory = "AppPackage/Sources/DownloadClient"
    private static let sessionModuleDirectory = "AppPackage/Sources/BackgroundProcessingClient"
    private static let scannedDirectories = [clientModuleDirectory, sessionModuleDirectory]
    /// One file per scanned directory, so an enumerator that silently walked nothing cannot let a
    /// test pass vacuously — for either root.
    private static let knownMembers = [
        clientModuleDirectory + "/DownloadClient+Execution.swift",
        sessionModuleDirectory + "/ContinuedProcessingSession.swift"
    ]
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

    /// The scanner's own detection tokens, assembled from fragments for the same reason the
    /// forbidden shapes are: a repository grep gate counting a log classification must not match
    /// the invariant that enforces it.
    private static var loggerCallPrefix: String { "logger" + "." }
    private static var interpolationOpening: String { "\\" + "(" }
    private static var classificationLabel: String { "privacy" + ":" }

    /// Every hash-masked interpolation the scanned modules carry, named per file.
    ///
    /// The background-processing module contributes no entry: it masks nothing, because it holds no
    /// value whose identity a device archive would need to correlate.
    ///
    /// The former bare lower-bound threshold pinned nothing derivable: it could not say which sites
    /// it stood for, so a masked log added or removed anywhere moved the real count while the
    /// assertion kept passing. An equality against this table makes every such change a deliberate,
    /// visible edit here — including the working-manifest reconciliation notice, whose whole purpose
    /// is to leave a blanking trail a device archive can show.
    /// The `+PersistenceNormalize.swift` entry is the validate-time recovery's forensic line, added
    /// deliberately rather than inherited: where a reconciliation removed refuted page files and then
    /// could not make the matching blank durable — twice, counting its single retry — the record
    /// describes files this app deleted, and that divergence outlives the session while the transient
    /// entry marking it does not. The removed page indices are operational scalars and go out
    /// `public`; the gid follows the module's masked identity pattern, so cross-line correlation
    /// survives without disclosure.
    private static let expectedHashMaskedCounts = [
        "DownloadClient+Execution.swift": 3,
        "DownloadClient+Manager.swift": 1,
        "DownloadClient+PersistenceNormalize.swift": 1,
        "DownloadClient+PublicAPI.swift": 2,
        "DownloadClient+Scheduling.swift": 3,
        "DownloadClient+WorkingManifestReconciliation.swift": 1
    ]

    /// The table's sum, asserted separately against a count taken over the joined scanned text.
    ///
    /// The table is keyed by file name, so two same-named files anywhere under the module would
    /// collapse into one entry and hide a site. The joined count cannot collapse.
    private static let expectedHashMaskedTotal = 11

    @Test
    func testNoDownloadLogPublishesGalleryIdentity() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

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

    /// An interpolation with no classification at all is invisible to the check above, which can
    /// only match a classification that is written down.
    ///
    /// Such a site is not wrong today — the unified log defaults a dynamic string to private — but
    /// its correctness rests on a default rather than on an authored decision, and the boundary
    /// this suite guards cannot see it either way. Requiring the classification at every
    /// interpolation is what removes that blind spot.
    @Test
    func testEveryDownloadLogInterpolationCarriesAnExplicitPrivacyClassification() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let unclassified = files.flatMap({ file in
            Self.unclassifiedInterpolations(in: file.contents)
                .map({ "\(file.relativePath): \($0)" })
        })
        #expect(
            unclassified.isEmpty,
            "A log interpolation carries no explicit privacy classification: \(unclassified)"
        )
    }

    @Test
    func testDownloadIdentityLogsStayHashMasked() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)
        let contents = files.map(\.contents).joined(separator: "\n")

        var maskedCounts = [String: Int]()
        for file in files {
            let count = Self.hashMaskedCount(in: file.contents)
            guard count > 0 else { continue }
            maskedCounts[file.fileName, default: 0] += count
        }
        #expect(
            maskedCounts == Self.expectedHashMaskedCounts,
            "The scanned hash-masked log inventory moved; update the table deliberately."
        )
        #expect(Self.hashMaskedCount(in: contents) == Self.expectedHashMaskedTotal)
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

// MARK: - Interpolation Scanning

private extension DownloadLogPrivacyInvariantTests {
    static func hashMaskedCount(in contents: String) -> Int {
        contents.components(separatedBy: hashMaskedClassification).count - 1
    }

    /// Every interpolation inside a logger call that carries no explicit classification argument.
    static func unclassifiedInterpolations(in contents: String) -> [String] {
        loggerCallSpans(in: contents).flatMap({ span in
            interpolations(in: span).filter({ $0.contains(classificationLabel) == false })
        })
    }

    /// Each logger call's argument list, from its opening parenthesis to the balanced closing one.
    ///
    /// Balancing rather than reading to the end of the line is what lets the scan see the module's
    /// multi-line messages, where every classified interpolation this suite cares about lives.
    static func loggerCallSpans(in contents: String) -> [Substring] {
        var spans = [Substring]()
        var searchStart = contents.startIndex

        while let prefix = contents.range(
            of: loggerCallPrefix,
            range: searchStart..<contents.endIndex
        ) {
            searchStart = prefix.upperBound
            guard let openIndex = contents[prefix.upperBound...].firstIndex(of: "("),
                  let closeIndex = balancedClosingIndex(in: contents, openedAt: openIndex)
            else { continue }
            spans.append(contents[openIndex...closeIndex])
            searchStart = contents.index(after: closeIndex)
        }
        return spans
    }

    /// Each interpolation in `span`, spelled from its own opening parenthesis to the balanced
    /// closing one, so a nested call inside an interpolation cannot end it early.
    static func interpolations(in span: Substring) -> [String] {
        var results = [String]()
        var searchStart = span.startIndex

        while let opening = span.range(
            of: interpolationOpening,
            range: searchStart..<span.endIndex
        ) {
            let openIndex = span.index(before: opening.upperBound)
            guard let closeIndex = balancedClosingIndex(in: span, openedAt: openIndex) else {
                searchStart = opening.upperBound
                continue
            }
            results.append(String(span[openIndex...closeIndex]))
            searchStart = span.index(after: closeIndex)
        }
        return results
    }

    static func balancedClosingIndex<Text: StringProtocol>(
        in text: Text,
        openedAt openIndex: Text.Index
    ) -> Text.Index? {
        var depth = 0
        var index = openIndex

        while index < text.endIndex {
            switch text[index] {
            case "(":
                depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return index }
            default:
                break
            }
            index = text.index(after: index)
        }
        return nil
    }
}

// MARK: - Scanning

private extension DownloadLogPrivacyInvariantTests {
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let fileManager = FileManager.default
        let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
        var files = [ScannedFile]()

        for scannedDirectory in scannedDirectories {
            let directory = root.appending(path: scannedDirectory)
            let enumerator = try #require(
                fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: nil
                )
            )
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
        }
        return files
    }

    /// Requires every scanned directory to have contributed its named file.
    private static func requireKnownMembers(in files: [ScannedFile]) throws {
        for knownMember in knownMembers {
            try #require(
                files.contains(where: { $0.relativePath == knownMember }),
                "The scan lost its known member \(knownMember); it refuses a vacuous walk."
            )
        }
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
