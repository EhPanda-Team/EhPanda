import AppTools
import Foundation
import Testing

/// Whether the volume backing the system temporary directory can store two directory names that
/// differ only in case as two distinct entries.
///
/// That is the precondition the both-exist regime needs, and it is measured by staging it rather
/// than inferred from `volumeSupportsCaseSensitiveNames` or from a `fileExists` probe. The
/// inference is not equivalent here: inside the simulator, `fileExists` answers NO for a case
/// variant — case-sensitive lookup semantics — while the macOS volume underneath is
/// case-insensitive and refuses to create the second entry at all. A probe that asked about lookups
/// would enable a case whose fixture cannot be built, which is how this was found.
///
/// A probe that cannot run answers `false`, which only ever SKIPS a gated case; it can never turn a
/// case-sensitive host into a silent pass.
private let hostCanStoreBothSpellings: Bool = {
    let fileManager = FileManager.default
    let probeRoot = fileManager.temporaryDirectory
        .appending(component: "logs-case-probe-" + UUID().uuidString, directoryHint: .isDirectory)
    defer {
        do {
            try fileManager.removeItem(at: probeRoot)
        } catch {
            // Housekeeping under the system temporary directory; a leftover probe changes no result.
        }
    }
    do {
        for name in ["logs", "Logs"] {
            try fileManager.createDirectory(
                at: probeRoot.appending(component: name, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }
        return try fileManager.contentsOfDirectory(atPath: probeRoot.path).count == 2
    } catch {
        return false
    }
}()

/// Exercises `LogsDirectoryMigration` against per-case temporary documents directories.
///
/// The suite is deliberately piecewise over the host volume, because the migration's regimes are not
/// all representable on one volume. iOS's data volume is case-SENSITIVE APFS, so `logs` and `Logs`
/// can be two distinct directories there; the volume backing the simulator container cannot store
/// both, so the both-exist regime cannot be staged here at all.
///
/// The split is drawn so that only the *filesystem staging* of that one regime is host-dependent:
///
/// - `regime(storedNames:currentSpellingResolves:)` classifies every regime from observations alone,
///   so all four — including the merge and the case-insensitive signature — are pinned on any host.
/// - `mergeDecision(sourceNames:destinationNames:)` pins the collision disposition from both sides.
/// - `mergeContents(of:into:)` is driven with arbitrary directory names, so the merge's file-by-file
///   application runs everywhere rather than only where two case variants can coexist.
/// - Only `bothStoredSpellingsRouteToAMerge`, which needs two literal entries, is gated on
///   `hostCanStoreBothSpellings`; on this host it is skipped and the three cases above carry it.
///
/// `theLegacyDirectoryIsRenamedToTheUppercaseStoredName` runs in both regimes, and on a
/// case-insensitive host it is precisely the case that makes the case-only rename observable —
/// because it asserts the LITERAL stored name from a directory listing rather than asking
/// `fileExists`, which answers yes for either spelling.
final class LogsDirectoryMigrationTests {
    // Swift Testing builds one suite instance per case, so this root belongs to a single case and
    // the suite is parallel-safe. Nothing here touches the process documents directory.
    private let root = FileManager.default.temporaryDirectory
        .appending(component: UUID().uuidString, directoryHint: .isDirectory)

    deinit {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            // A case that wrote nothing leaves no root to remove; the directory is under the
            // system temporary directory either way, so cleanup is housekeeping, not a result.
        }
    }

    // MARK: - The owner's requirement

    @Test
    func theLogsDirectoryNameBeginsWithAnUppercaseLetter() throws {
        // The requirement, as asked: the folder's displayed name starts with a capital letter.
        let initial = try #require(Defaults.FilePath.logs.first)
        #expect(initial.isUppercase)
        // The spelling chosen to satisfy it, pinned so a later edit cannot drift the migration's
        // destination away from what the tests below assert literally.
        #expect(Defaults.FilePath.logs == "Logs")
    }

    // MARK: - Regime classification (pure, host-independent)

    @Test
    func noStoredLegacyDirectoryIsNothingToMigrate() {
        #expect(
            LogsDirectoryMigration.regime(
                storedNames: [],
                currentSpellingResolves: false
            ) == .nothingToMigrate
        )
        #expect(
            LogsDirectoryMigration.regime(
                storedNames: ["Logs"],
                currentSpellingResolves: true
            ) == .nothingToMigrate
        )
    }

    @Test
    func aDestinationThatResolvesToNothingIsAnAtomicRename() {
        // The device regime: a case-sensitive volume, so the current spelling names nothing yet.
        #expect(
            LogsDirectoryMigration.regime(
                storedNames: ["logs"],
                currentSpellingResolves: false
            ) == .rename
        )
    }

    @Test
    func aDestinationThatResolvesWithoutBeingStoredIsTheCaseInsensitiveSignature() {
        // A name cannot resolve without being stored unless it is an alias for one that is, which
        // is the whole basis on which the case-insensitive volume is detected.
        #expect(
            LogsDirectoryMigration.regime(
                storedNames: ["logs"],
                currentSpellingResolves: true
            ) == .renameThroughStaging
        )
    }

    @Test
    func twoStoredSpellingsAreAMerge() {
        #expect(
            LogsDirectoryMigration.regime(
                storedNames: ["logs", "Logs"],
                currentSpellingResolves: true
            ) == .merge
        )
    }

    // MARK: - Whole-migration regimes

    @Test
    func theLegacyDirectoryIsRenamedToTheUppercaseStoredName() throws {
        let documents = try makeDocuments()
        let legacy = try makeDirectory(named: "logs", in: documents)
        let firstRun = runLogFileName(day: "20260101", time: "090000", runCount: 1)
        let secondRun = runLogFileName(day: "20260101", time: "101500", runCount: 2)
        try write("first-run", to: legacy.appending(component: firstRun))
        try write("second-run", to: legacy.appending(component: secondRun))

        #expect(LogsDirectoryMigration.run(documentsURL: documents) == .renamed)

        // The literal stored name is the assertion that matters: it is what the Files app shows,
        // and on a case-insensitive host it is the only way to see that the rename happened at all.
        let documentsNames = try storedNames(in: documents)
        #expect(documentsNames == ["Logs"])

        let migrated = documents.appending(component: "Logs", directoryHint: .isDirectory)
        let migratedNames = try storedNames(in: migrated)
        #expect(migratedNames == [firstRun, secondRun].sorted())
        #expect(try contents(of: migrated.appending(component: firstRun)) == "first-run")
        #expect(try contents(of: migrated.appending(component: secondRun)) == "second-run")
    }

    @Test
    func aSecondRunFindsNothingToMigrateAndLeavesTheMigratedLogsIntact() throws {
        let documents = try makeDocuments()
        let legacy = try makeDirectory(named: "logs", in: documents)
        let runFile = runLogFileName(day: "20260101", time: "090000", runCount: 1)
        try write("first-run", to: legacy.appending(component: runFile))

        #expect(LogsDirectoryMigration.run(documentsURL: documents) == .renamed)
        #expect(LogsDirectoryMigration.run(documentsURL: documents) == .nothingToMigrate)

        let documentsNames = try storedNames(in: documents)
        #expect(documentsNames == ["Logs"])
        let migrated = documents.appending(component: "Logs", directoryHint: .isDirectory)
        #expect(try contents(of: migrated.appending(component: runFile)) == "first-run")
    }

    @Test
    func aFreshInstallWithOnlyTheNewDirectoryIsNothingToMigrate() throws {
        let documents = try makeDocuments()
        let current = try makeDirectory(named: "Logs", in: documents)
        let runFile = runLogFileName(day: "20260101", time: "090000", runCount: 1)
        try write("untouched", to: current.appending(component: runFile))

        #expect(LogsDirectoryMigration.run(documentsURL: documents) == .nothingToMigrate)

        let documentsNames = try storedNames(in: documents)
        #expect(documentsNames == ["Logs"])
        #expect(try contents(of: current.appending(component: runFile)) == "untouched")
    }

    @Test
    func emptyDocumentsIsNothingToMigrateAndMintsNoDirectory() throws {
        let documents = try makeDocuments()

        #expect(LogsDirectoryMigration.run(documentsURL: documents) == .nothingToMigrate)

        // Directory creation stays with `LogsClient.appendToRunFile`; the migration only ever moves
        // what already exists, so a fresh install must come out of this untouched.
        let documentsNames = try storedNames(in: documents)
        #expect(documentsNames.isEmpty)
    }

    @Test
    func aRegularFileNamedLikeTheLegacyDirectoryIsLeftAlone() throws {
        // File Sharing lets the user drop anything into Documents. Moving such a file onto the
        // current name would put a file where `appendToRunFile` needs to create a directory.
        let documents = try makeDocuments()
        try write("not a logs directory", to: documents.appending(component: "logs"))

        #expect(LogsDirectoryMigration.run(documentsURL: documents) == .nothingToMigrate)

        let documentsNames = try storedNames(in: documents)
        #expect(documentsNames == ["logs"])
        #expect(try contents(of: documents.appending(component: "logs")) == "not a logs directory")
    }

    @Test
    func anUnreadableDocumentsDirectoryReportsFailureRatherThanNothingToMigrate() {
        // "Nothing to migrate" would be an unbacked claim here: an unreadable documents directory
        // may well hold a legacy `logs` folder, and reporting success would strand it silently.
        let outcome = LogsDirectoryMigration.run(
            documentsURL: root.appending(component: "missing", directoryHint: .isDirectory)
        )

        #expect(isFailure(outcome))
    }

    @Test(
        .enabled(
            if: hostCanStoreBothSpellings,
            "Two directories differing only in case cannot be stored on this host's volume."
        )
    )
    func bothStoredSpellingsRouteToAMerge() throws {
        let documents = try makeDocuments()
        let legacy = try makeDirectory(named: "logs", in: documents)
        let current = try makeDirectory(named: "Logs", in: documents)
        let movedRun = runLogFileName(day: "20260101", time: "090000", runCount: 1)
        let collidingRun = runLogFileName(day: "20260101", time: "101500", runCount: 2)
        try write("legacy-only", to: legacy.appending(component: movedRun))
        try write("legacy-copy", to: legacy.appending(component: collidingRun))
        try write("destination-copy", to: current.appending(component: collidingRun))

        let outcome = LogsDirectoryMigration.run(documentsURL: documents)

        #expect(outcome == .merged(movedCount: 1, skippedCount: 1))
        #expect(try contents(of: current.appending(component: movedRun)) == "legacy-only")
        #expect(try contents(of: current.appending(component: collidingRun)) == "destination-copy")
        // The skipped file keeps the legacy directory non-empty, so it survives by design rather
        // than being deleted with its contents.
        #expect(try contents(of: legacy.appending(component: collidingRun)) == "legacy-copy")
    }

    // MARK: - Merge decision (pure, host-independent)

    @Test
    func everyDisjointNameIsMoved() {
        let decision = LogsDirectoryMigration.mergeDecision(
            sourceNames: ["a.jsonl", "b.jsonl", "c.jsonl"],
            destinationNames: ["z.jsonl"]
        )

        #expect(decision.moves == ["a.jsonl", "b.jsonl", "c.jsonl"])
        #expect(decision.skips.isEmpty)
    }

    @Test
    func aNameAlreadyInTheDestinationIsSkipped() {
        let decision = LogsDirectoryMigration.mergeDecision(
            sourceNames: ["a.jsonl", "b.jsonl", "c.jsonl"],
            destinationNames: ["b.jsonl", "z.jsonl"]
        )

        #expect(decision.moves == ["a.jsonl", "c.jsonl"])
        #expect(decision.skips == ["b.jsonl"])
    }

    // MARK: - Merge application (filesystem, host-independent)

    @Test
    func aFullyDisjointMergeMovesEveryFileAndRemovesTheEmptiedSource() throws {
        let documents = try makeDocuments()
        let source = try makeDirectory(named: "source", in: documents)
        let destination = try makeDirectory(named: "destination", in: documents)
        try write("one", to: source.appending(component: "a.jsonl"))
        try write("two", to: source.appending(component: "b.jsonl"))
        try write("kept", to: destination.appending(component: "z.jsonl"))

        let outcome = LogsDirectoryMigration.mergeContents(of: source, into: destination)

        #expect(outcome == .merged(movedCount: 2, skippedCount: 0))
        let documentsNames = try storedNames(in: documents)
        #expect(documentsNames == ["destination"])
        let destinationNames = try storedNames(in: destination)
        #expect(destinationNames == ["a.jsonl", "b.jsonl", "z.jsonl"])
        #expect(try contents(of: destination.appending(component: "a.jsonl")) == "one")
        #expect(try contents(of: destination.appending(component: "b.jsonl")) == "two")
        #expect(try contents(of: destination.appending(component: "z.jsonl")) == "kept")
    }

    @Test
    func aCollidingNameIsSkippedAndTheDestinationBytesSurvive() throws {
        let documents = try makeDocuments()
        let source = try makeDirectory(named: "source", in: documents)
        let destination = try makeDirectory(named: "destination", in: documents)
        try write("moved", to: source.appending(component: "a.jsonl"))
        try write("source-copy", to: source.appending(component: "b.jsonl"))
        try write("destination-copy", to: destination.appending(component: "b.jsonl"))

        let outcome = LogsDirectoryMigration.mergeContents(of: source, into: destination)

        #expect(outcome == .merged(movedCount: 1, skippedCount: 1))
        #expect(try contents(of: destination.appending(component: "a.jsonl")) == "moved")
        #expect(try contents(of: destination.appending(component: "b.jsonl")) == "destination-copy")
        // Nothing is deleted: the source survives holding exactly the file that was skipped.
        let sourceNames = try storedNames(in: source)
        #expect(sourceNames == ["b.jsonl"])
        #expect(try contents(of: source.appending(component: "b.jsonl")) == "source-copy")
    }

    @Test
    func anUnreadableSourceFailsWithoutTouchingTheDestination() throws {
        let documents = try makeDocuments()
        let destination = try makeDirectory(named: "destination", in: documents)
        try write("kept", to: destination.appending(component: "z.jsonl"))

        let outcome = LogsDirectoryMigration.mergeContents(
            of: documents.appending(component: "missing", directoryHint: .isDirectory),
            into: destination
        )

        #expect(isFailure(outcome))
        let destinationNames = try storedNames(in: destination)
        #expect(destinationNames == ["z.jsonl"])
        #expect(try contents(of: destination.appending(component: "z.jsonl")) == "kept")
    }

    // MARK: - Fixtures

    private func makeDocuments() throws -> URL {
        let documents = root.appending(component: "Documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        return documents
    }

    private func makeDirectory(named name: String, in parent: URL) throws -> URL {
        let url = parent.appending(component: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A real run-log file name, `ehpanda-<yyyyMMdd>-<HHmmss>-<runCount>.jsonl`, composed from the
    /// same `Defaults.FilePath` constants the production namer uses. Built here rather than through
    /// `RunLogFile.fileName` so `AppToolsTests` keeps its single `AppTools` dependency.
    private func runLogFileName(day: String, time: String, runCount: Int) -> String {
        let base = [Defaults.FilePath.activityLogPrefix, day, time, String(runCount)]
            .joined(separator: "-")
        return [base, Defaults.FilePath.activityLogExtension].joined(separator: ".")
    }

    private func write(_ contents: String, to url: URL) throws {
        try Data(contents.utf8).write(to: url, options: .atomic)
    }

    /// Decodes failably rather than through `String(decoding:as:)`, so a file that came back as
    /// something other than the UTF-8 that was written fails the case instead of quietly decoding
    /// to replacement characters and comparing unequal for an unexplained reason.
    private func contents(of url: URL) throws -> String {
        try #require(String(bytes: try Data(contentsOf: url), encoding: .utf8))
    }

    /// The LITERAL stored names in `url`, sorted. Never `fileExists`, which on a case-insensitive
    /// volume answers yes for a spelling the volume does not store.
    private func storedNames(in url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    }

    /// A function rather than a computed `Bool` property, so it does not read as the case-check
    /// property shape the project's lint rules reject. `failed`'s reason embeds an underlying error
    /// description, so only the case is asserted.
    private func isFailure(_ outcome: LogsDirectoryMigration.Outcome) -> Bool {
        if case .failed = outcome { true } else { false }
    }
}
