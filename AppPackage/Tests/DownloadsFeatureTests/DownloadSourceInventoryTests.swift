import Foundation
import Testing

/// Fails the build when a source inventory a load-bearing doc comment cites moves.
///
/// This module's docs carry several censuses of source — "the writers this re-clears", "the only
/// sites that take a scheduling block", "five writers, verified exhaustive at this HEAD" — because
/// the invariants they state are not derivable from the one function a reader is looking at. Such an
/// inventory is correct on the day it is written and unowned forever after: nothing fails when a
/// sixth site appears, so the comment silently becomes a false premise, and a later fix reasoning
/// from it lands wrong. That is not hypothetical here. It is the recorded generator of G-15-3,
/// G-15-7, G-15-13 and G-15-19, and of the five doc-vs-source contradictions of G-15-20 — three of
/// which were written by the doc-correction work of the round before.
///
/// A corrected comment alone therefore closes nothing; it only resets the clock. So every inventory
/// that survives in a doc is paired here with an equality that a drift breaks, on the pattern
/// `DownloadLogPrivacyInvariantTests.expectedHashMaskedCounts` already establishes: a repository-root
/// walk, a known-member guard so a walk that found nothing cannot pass vacuously, detection tokens
/// assembled from fragments so a repository grep gate cannot match the check that enforces it, and a
/// per-file table asserted alongside a separately-counted joined total, which no two same-named
/// files can collapse.
///
/// A failure here is not a defect by itself. It means source moved and a doc that cites it must be
/// re-read and re-derived before the table is updated — which is the whole point.
@Suite
struct DownloadSourceInventoryTests {
    private struct ScannedFile {
        let relativePath: String
        let contents: String

        var fileName: String {
            relativePath.split(separator: "/").last.map(String.init) ?? relativePath
        }
    }

    private static let clientModuleDirectory = "AppPackage/Sources/DownloadClient"
    /// One file per scanned directory, so an enumerator that silently walked nothing cannot let a
    /// test pass vacuously.
    private static let knownMembers = [
        clientModuleDirectory + "/DownloadClient+Manager.swift"
    ]
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    /// The scanner's own detection tokens, assembled from fragments so a repository grep gate
    /// counting either inventory cannot match the suite that pins it.
    private static var schedulingBlockCallToken: String { "block" + "Scheduling(" }
    private static var schedulableReadToken: String { "schedulable" + "Downloads()" }
    private static var floorPropertyName: String { "lastPushed" + "CompletedPageCount" }
    private static var pendingPageListToken: String { "pendingPage" + "Indices(" }
    private static var runProofPropertyName: String { "provenPageWork" + "RunGIDs" }
    private static var declarationPrefix: String { "func" + " " }
    private static var storedDeclarationPrefix: String { "var" + " " }
    private static var mutationOperators: [String] { ["=", "+=", "-=", "*=", "/="] }

    /// Every site that takes a gallery's scheduling block, named per file.
    ///
    /// This is the census `writeSettledPauseRecord`'s doc reasons from: it states that no
    /// queue-mobilizing entry point takes a block, and the way that invariant can rot is a mobilizer
    /// quietly gaining one, or a new blocking operation appearing that nobody dispositioned against
    /// G-15-8's release-then-converge rule. Both move a number here.
    ///
    /// Derived from source rather than copied: `commitPause` (`+Scheduling.swift`), `delete`
    /// (`+PublicAPI.swift`), `deleteFolder` and `moveDownload` (`+Folders.swift`), and the testing
    /// forwarder (`+Testing.swift`) that lets a suite stage two overlapping holders without racing
    /// two real operations. The declaration itself is excluded, as are doc-comment mentions — the
    /// count is of calls.
    private static let expectedSchedulingBlockCallSites = [
        "DownloadClient+Folders.swift": 2,
        "DownloadClient+PublicAPI.swift": 1,
        "DownloadClient+Scheduling.swift": 1,
        "DownloadClient+Testing.swift": 1
    ]

    /// The table's sum, asserted separately against a count taken over the joined scanned text.
    ///
    /// The table is keyed by file name, so two same-named files anywhere under the module would
    /// collapse into one entry and hide a site. The joined count cannot collapse.
    private static let expectedSchedulingBlockCallTotal = 5

    /// Every mutation of the monotonic floor under the numerator a session pushes, named per file.
    ///
    /// This is the inventory `lastPushedCompletedPageCount`'s own doc carries, and that doc used to
    /// close by asking the reader to re-run the grep it was derived from. It now names this table
    /// instead. The four in `+ContinuedSession.swift` are the session-start reset, the seed merge
    /// after the client start returns, the teardown zero and the per-push re-latch; the one in
    /// `+ExecutionSupport.swift` is D-G7-01's withdrawal, whose single implementation serves both of
    /// its call sites — which is why one rule counts once here.
    private static let expectedFloorWriters = [
        "DownloadClient+ContinuedSession.swift": 4,
        "DownloadClient+ExecutionSupport.swift": 1
    ]

    /// The floor table's sum, asserted the same way and for the same reason.
    private static let expectedFloorWriterTotal = 5

    /// Every call of the shared schedulable-work read, named per file.
    ///
    /// This is the caller list the read's own header carries and the G-15-8 paragraph in
    /// `+Manager.swift` repeats: the pending-work gate in `+PendingWork.swift`, and the session
    /// snapshot plus the expiration sweep in `+ContinuedSession.swift`. Both docs also state what is
    /// deliberately NOT in it — `scheduleNextIfNeededCore`, which shares only the predicate and reads
    /// its own queue-scoped set — so those sentences rot in three ways: a fourth reader appearing, a
    /// reader being removed, or the scheduler gaining this call. Each moves a number here, and the
    /// last one moves it into a file the table does not list at all.
    ///
    /// That is not a hypothetical rot path. The single-authority sentence was false in two files at
    /// once, uncaught across five rounds, and the second of them was written by a round whose job was
    /// correcting the first (G-15-24). Nothing counted it until this table.
    ///
    /// Derived from source rather than copied. The declaration is excluded, as are doc-comment
    /// mentions — this function has more of those than calls — because the count is of calls.
    private static let expectedSchedulableReadCallSites = [
        "DownloadClient+ContinuedSession.swift": 2,
        "DownloadClient+PendingWork.swift": 1
    ]

    /// The read table's sum, asserted the same way and for the same reason.
    private static let expectedSchedulableReadCallTotal = 3

    /// Every evaluation of the run's pending page list, named per file.
    ///
    /// This is the inventory `prepareWorkingSeedAnnouncingProgress`'s doc reasons from, and it is
    /// the one census whose expected value is a rule rather than a tally: the list must be derived
    /// EXACTLY ONCE per run, inside the preparation, and handed to `performDownload` for the page
    /// loop. Two evaluations is how G-15-27 could recur — the announcement's gate and the loop would
    /// each hold their own answer, and a later fix moving one and not the other grants trust for
    /// work the loop never does (T-15-47-03). `performDownload` held the second evaluation until
    /// this round; nothing failed when it did.
    ///
    /// Derived from source rather than copied. The declaration is excluded, as are doc-comment
    /// mentions and the `pendingPageIndices:` argument labels the page loop is threaded through,
    /// which carry a colon rather than a paren — the count is of calls.
    private static let expectedPendingPageIndicesCallSites = [
        "DownloadClient+ExecutionSupport.swift": 1
    ]

    /// The pending-list table's sum, asserted the same way and for the same reason.
    private static let expectedPendingPageIndicesCallTotal = 1

    /// Every site naming the run-scoped proof of page work, named per file.
    ///
    /// This is the census the property's own declaration reasons from, and the claim it owns is a
    /// LIFETIME: the proof is recorded at the run's preparation, read by every session start, retired
    /// at the run's end, and touched nowhere else. Each of the four entries is exactly one of those
    /// roles — the declaration in `+Manager.swift`, the recording in `+ExecutionSupport.swift`, the
    /// session-start seed in `+ContinuedSession.swift`, and the retirement in `+Execution.swift`.
    ///
    /// It is a whole-name count rather than a mutation count on purpose, because the way this
    /// invariant rots is a READ or a CLEAR appearing rather than an assignment. The specific rot this
    /// pins against is a clear being added to `markContinuedSessionEnded` or to
    /// `ensureContinuedSession`'s reset — conflating a session boundary with a run boundary, which is
    /// precisely the defect G-15-26 recorded — and either would take `+ContinuedSession.swift` from
    /// one to two. Nothing counted the equivalent claim about the session-scoped set, and it was
    /// stated in a doc for five rounds while source disagreed.
    ///
    /// Derived from source rather than copied. Doc-comment mentions are excluded, as everywhere else
    /// here — this property has more of those than uses.
    private static let expectedRunProofSites = [
        "DownloadClient+ContinuedSession.swift": 1,
        "DownloadClient+Execution.swift": 1,
        "DownloadClient+ExecutionSupport.swift": 1,
        "DownloadClient+Manager.swift": 1
    ]

    /// The run-proof table's sum, asserted the same way and for the same reason.
    private static let expectedRunProofSiteTotal = 4

    @Test
    func testSchedulingBlockCallSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        var callSites = [String: Int]()
        for file in files {
            let count = Self.callSiteCount(of: Self.schedulingBlockCallToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedSchedulingBlockCallSites,
            """
            The scheduling-block census moved. Re-derive which operations now take a block, \
            re-read the invariant in writeSettledPauseRecord's doc against them, and only then \
            update this table.
            """
        )

        let joined = files.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.schedulingBlockCallToken, in: joined)
                == Self.expectedSchedulingBlockCallTotal
        )
    }

    @Test
    func testFloorWriterAssignmentsMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        var writers = [String: Int]()
        for file in files {
            let count = Self.mutationCount(of: Self.floorPropertyName, in: file.contents)
            guard count > 0 else { continue }
            writers[file.fileName, default: 0] += count
        }
        #expect(
            writers == Self.expectedFloorWriters,
            """
            The monotonic-floor writer census moved. Re-derive the writers, re-read the inventory \
            on the property's own declaration against them, and only then update this table.
            """
        )

        let joined = files.map(\.contents).joined(separator: "\n")
        #expect(
            Self.mutationCount(of: Self.floorPropertyName, in: joined) == Self.expectedFloorWriterTotal
        )
    }

    @Test
    func testSchedulableDownloadsCallSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        var callSites = [String: Int]()
        for file in files {
            let count = Self.callSiteCount(of: Self.schedulableReadToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedSchedulableReadCallSites,
            """
            The schedulable-read caller census moved. Re-derive who reads through the shared \
            schedulable-work function and whether the scheduler now does, re-read that function's \
            own header and the G-15-8 paragraph in +Manager.swift against them, and only then \
            update this table.
            """
        )

        let joined = files.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.schedulableReadToken, in: joined)
                == Self.expectedSchedulableReadCallTotal
        )
    }

    @Test
    func testPendingPageListEvaluationsMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        var callSites = [String: Int]()
        for file in files {
            let count = Self.callSiteCount(of: Self.pendingPageListToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedPendingPageIndicesCallSites,
            """
            The pending-page-list census moved. A run derives that list exactly once, inside \
            prepareWorkingSeedAnnouncingProgress, and hands it to performDownload; a second \
            evaluation lets the announcement's gate and the page loop disagree about what this run \
            will fetch. Re-derive who evaluates it and why before updating this table.
            """
        )

        let joined = files.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.pendingPageListToken, in: joined)
                == Self.expectedPendingPageIndicesCallTotal
        )
    }

    @Test
    func testRunScopedPageWorkProofSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        var sites = [String: Int]()
        for file in files {
            let count = Self.callSiteCount(of: Self.runProofPropertyName, in: file.contents)
            guard count > 0 else { continue }
            sites[file.fileName, default: 0] += count
        }
        #expect(
            sites == Self.expectedRunProofSites,
            """
            The run-scoped page-work proof census moved. That proof has exactly four roles — its \
            declaration, the recording at the run's own preparation, the seed every session start \
            takes from it, and the retirement at the run's end — and a fifth site is almost always a \
            clear added at a SESSION boundary, which is the G-15-26 defect: a session ending is not \
            the run ending, and erasing the proof there leaves an in-flight repair contributing zero \
            for the rest of its re-download. Re-derive the lifetime against the property's own \
            declaration before updating this table.
            """
        )

        let joined = files.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.runProofPropertyName, in: joined)
                == Self.expectedRunProofSiteTotal
        )
    }
}

// MARK: - Census Scanning

private extension DownloadSourceInventoryTests {
    /// Calls of `token`, excluding the declaration that introduces it and every comment line.
    ///
    /// Comments are skipped because both censuses are cited BY comments: counting those mentions
    /// would make a doc that describes the inventory part of the inventory, so correcting a sentence
    /// would move the number it stands for.
    static func callSiteCount(of token: String, in contents: String) -> Int {
        executableLines(in: contents).reduce(into: 0) { total, line in
            guard line.contains(declarationPrefix + token) == false else { return }
            total += occurrences(of: token, in: line)
        }
    }

    /// Mutations of the stored property `name`, excluding its own declaration and every comment line.
    ///
    /// Every mutating form is counted, not just plain assignment: the floor is decremented by
    /// D-G7-01's withdrawal, and a writer that reached it through a compound operator would
    /// otherwise be invisible to the census that claims to name them all.
    static func mutationCount(of name: String, in contents: String) -> Int {
        executableLines(in: contents).reduce(into: 0) { total, line in
            guard line.contains(storedDeclarationPrefix + name) == false else { return }
            for mutation in mutationOperators {
                total += occurrences(of: name + " " + mutation + " ", in: line)
            }
        }
    }

    static func executableLines(in contents: String) -> [String] {
        contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter({ $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false })
    }

    static func occurrences(of token: String, in text: String) -> Int {
        text.components(separatedBy: token).count - 1
    }
}

// MARK: - Scanning

private extension DownloadSourceInventoryTests {
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let fileManager = FileManager.default
        let directory = root.appending(path: clientModuleDirectory)
        let enumerator = try #require(
            fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
        )
        var files = [ScannedFile]()

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(
                ScannedFile(
                    relativePath: repositoryRelativePath(of: url, under: root),
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            )
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
            "Could not locate the repository root; the source census refuses a vacuous scan."
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
