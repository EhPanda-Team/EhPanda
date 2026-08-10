import Foundation

/// A one-time migration of the user-visible activity-log directory from its legacy lowercase name
/// to `Defaults.FilePath.logs`.
///
/// ## Why the rename needs a migration
///
/// The logs directory sits directly under `Documents`, which the app publishes to the Files app
/// (`UIFileSharingEnabled`), so its name is user-visible. iOS's data volume is case-SENSITIVE APFS:
/// `logs` and `Logs` are two different directories there. Changing the constant alone would
/// therefore leave every existing install's logs in a directory nothing reads any more.
///
/// ## Why it cannot assume one filesystem
///
/// Development hosts are the other way round. The default macOS APFS volume — which backs the
/// simulator container — is case-INSENSITIVE, so `logs` and `Logs` name the same stored directory
/// and a plain `moveItem` between them is refused with "file exists" rather than performing the
/// rename. The migration therefore classifies which regime it is in before acting, and it does so
/// from evidence rather than assumption: `fileExists` is useless on its own here, because on a
/// case-insensitive volume it answers yes for a spelling the volume does not store. The signature
/// that distinguishes the two is the *disagreement* between a directory listing and a path probe —
/// the current spelling resolving to something while no entry with that literal name is stored can
/// only mean both spellings share one directory. See `Regime`.
///
/// ## What it will not do
///
/// It never creates the logs directory: that stays with `LogsClient.appendToRunFile`, which creates
/// it lazily on first write. It never deletes a file, and the only directory it removes is a legacy
/// directory it has just emptied. Nothing here throws — every failure becomes an `Outcome` the
/// caller logs, so a migration that cannot run degrades to the previous behavior instead of
/// blocking launch or losing logs.
///
/// ## Ordering against a concurrent log write
///
/// The caller runs this from an async launch effect, so it is NOT ordered before the launch's first
/// log write, and no such ordering is claimed. It does not need one: a racing write creates `Logs`
/// (the new constant), which puts this migration in the `merge` regime — either immediately, when
/// the write lands before the classification, or at the next launch, when it lands after. On a
/// case-insensitive volume a racing write lands inside the one shared directory and the case-only
/// rename carries it along. The one window it cannot absorb in place is a write arriving between
/// the two halves of a staged rename; `renameThroughStaging` handles that by folding the staged
/// contents into whatever now stands at the destination.
public enum LogsDirectoryMigration {
    /// The directory name that shipped before the rename.
    ///
    /// Frozen deliberately, and NOT derived from `Defaults.FilePath.logs` (e.g. by lowercasing it):
    /// this is a historical fact about installs in the field. Deriving it would mean that renaming
    /// the current constant again silently redefines which directory this migration reads *from*,
    /// and the previously migrated directory would become the thing left stranded.
    private static let legacyDirectoryName = "logs"

    /// What a migration attempt actually did.
    public enum Outcome: Equatable, Sendable {
        /// Nothing was found to migrate, and nothing was created. Every launch after the first
        /// reports this, which is what makes running the migration unconditionally safe.
        case nothingToMigrate
        /// The legacy directory now carries the current name, with all of its contents.
        case renamed
        /// The legacy directory's files were folded into the current one. `skippedCount` counts
        /// names the destination already had; those files stay in the legacy directory, which
        /// therefore survives (it is only removed once empty).
        case merged(movedCount: Int, skippedCount: Int)
        /// The migration could not complete. Logs are wherever they were, minus any files a
        /// partial merge already moved into the destination — never deleted, and the next launch
        /// retries from the state left behind.
        case failed(reason: String)
    }

    /// What the migration must do, classified from what the documents directory says about itself.
    public enum Regime: Equatable, Sendable {
        /// No legacy directory is stored: a fresh install, or one already migrated.
        case nothingToMigrate
        /// Both spellings are stored as distinct entries. Only a case-sensitive volume can
        /// represent this; it is what a device install looks like when a log write raced an earlier
        /// attempt, or when a previous merge stopped part-way.
        case merge
        /// Only the legacy spelling is stored, yet the current spelling resolves to something.
        /// That disagreement is the signature of a case-INSENSITIVE volume: both spellings name the
        /// one stored directory. `moveItem` pre-checks its destination and would refuse with "file
        /// exists", so the case-only rename has to go through a unique staging name.
        case renameThroughStaging
        /// Only the legacy spelling is stored and the current spelling resolves to nothing, so the
        /// destination is genuinely free: one atomic `rename(2)`, with no window in which a crash
        /// could strand the logs under a name nothing reads. This is the device regime.
        case rename
    }

    /// The file-by-file disposition of a merge, decided from names alone so that the decision is
    /// pinnable on a host whose volume cannot even represent the regime that triggers it.
    public struct MergeDecision: Equatable, Sendable {
        /// Names to move out of the legacy directory, in the order they were listed.
        public let moves: [String]
        /// Names the destination already has. The destination copy wins; see `mergeDecision`.
        public let skips: [String]

        public init(moves: [String], skips: [String]) {
            self.moves = moves
            self.skips = skips
        }
    }

    /// Classifies the migration regime from a documents-directory listing and a path probe.
    ///
    /// `currentSpellingResolves` is what `FileManager.fileExists` answers for the current spelling.
    /// Read alone it cannot distinguish "the destination directory exists" from "this volume is
    /// case-insensitive and you are looking at the source"; read *against* `storedNames` it
    /// separates them exactly, because a name that resolves without being stored has to be an
    /// alias for one that is.
    public static func regime(storedNames: [String], currentSpellingResolves: Bool) -> Regime {
        // Should the current constant ever be reverted to the legacy spelling, there is nothing to
        // migrate — and, critically, the merge branch must never see one directory as both its
        // source and its destination.
        guard Defaults.FilePath.logs != legacyDirectoryName else { return .nothingToMigrate }
        guard storedNames.contains(legacyDirectoryName) else { return .nothingToMigrate }
        guard !storedNames.contains(Defaults.FilePath.logs) else { return .merge }
        return currentSpellingResolves ? .renameThroughStaging : .rename
    }

    /// Decides, from names alone, which of `sourceNames` move into a directory holding
    /// `destinationNames` and which are left alone.
    ///
    /// A name present on both sides is skipped and the destination copy is kept. Run-log names
    /// embed day, time-of-day and run count, so two files sharing a name are the same run — and the
    /// destination copy is the one the *current* process may still be appending to, which makes
    /// overwriting it the one disposition that could destroy live data.
    public static func mergeDecision(sourceNames: [String], destinationNames: [String]) -> MergeDecision {
        let existing = Set(destinationNames)
        return .init(
            moves: sourceNames.filter({ !existing.contains($0) }),
            skips: sourceNames.filter({ existing.contains($0) })
        )
    }

    /// Runs the migration against `documentsURL`, reporting what it did.
    ///
    /// Idempotent: a second run finds no legacy directory and reports `nothingToMigrate`.
    public static func run(documentsURL: URL, fileManager: FileManager = .default) -> Outcome {
        let currentURL = documentsURL.appending(component: Defaults.FilePath.logs, directoryHint: .isDirectory)
        let legacyURL = documentsURL.appending(component: legacyDirectoryName, directoryHint: .isDirectory)

        let storedNames: [String]
        do {
            storedNames = try fileManager.contentsOfDirectory(atPath: documentsURL.path)
        } catch {
            // Not "nothing to migrate": a documents directory that cannot be listed may well hold a
            // legacy directory, and reporting success would strand it silently.
            return .failed(reason: "The documents directory could not be listed: \(error.localizedDescription)")
        }

        let resolvedRegime = regime(
            storedNames: storedNames,
            currentSpellingResolves: fileManager.fileExists(atPath: currentURL.path)
        )
        guard resolvedRegime != .nothingToMigrate else { return .nothingToMigrate }

        // The legacy name is stored, but only a DIRECTORY is ours to migrate. File Sharing lets the
        // user drop a regular file called `logs` into Documents, and moving that onto the current
        // name would put a file exactly where `appendToRunFile` needs to create a directory,
        // breaking logging outright. Leave the user's file where they put it.
        guard isDirectory(legacyURL, fileManager: fileManager) else { return .nothingToMigrate }

        switch resolvedRegime {
        case .nothingToMigrate:
            return .nothingToMigrate
        case .merge:
            return mergeContents(of: legacyURL, into: currentURL, fileManager: fileManager)
        case .renameThroughStaging:
            return renameThroughStaging(legacyURL, to: currentURL, fileManager: fileManager)
        case .rename:
            do {
                try fileManager.moveItem(at: legacyURL, to: currentURL)
                return .renamed
            } catch {
                // The destination was free when it was probed and is not now, or this filesystem
                // refuses the move for a reason the classification cannot see. An atomic rename
                // leaves no partial state behind, so staging is safe to try from here.
                return renameThroughStaging(legacyURL, to: currentURL, fileManager: fileManager)
            }
        }
    }

    /// Moves every file of `source` that `destination` does not already have, then removes `source`
    /// if that emptied it.
    ///
    /// Best effort in the moves and honest in the outcome: a move that fails leaves its file in
    /// `source` for the next launch to retry, and the returned outcome is `failed` so the failure is
    /// logged rather than hidden behind a count. Nothing is ever overwritten or deleted.
    public static func mergeContents(
        of source: URL,
        into destination: URL,
        fileManager: FileManager = .default
    ) -> Outcome {
        let sourceNames: [String]
        let destinationNames: [String]
        do {
            sourceNames = try fileManager.contentsOfDirectory(atPath: source.path)
            destinationNames = try fileManager.contentsOfDirectory(atPath: destination.path)
        } catch {
            return .failed(reason: "A logs directory could not be listed for merging: \(error.localizedDescription)")
        }

        let decision = mergeDecision(sourceNames: sourceNames, destinationNames: destinationNames)
        var movedCount = 0
        for name in decision.moves {
            do {
                try fileManager.moveItem(
                    at: source.appending(component: name),
                    to: destination.appending(component: name)
                )
                movedCount += 1
            } catch {
                // Leave it where it is; the next launch sees the same regime and retries.
            }
        }
        guard movedCount == decision.moves.count else {
            return .failed(
                reason: "\(decision.moves.count - movedCount) of \(decision.moves.count) log files could not be moved"
            )
        }

        // Only an emptied directory is removed, so a skipped file is never deleted along with the
        // directory that holds it.
        guard decision.skips.isEmpty else { return .merged(movedCount: movedCount, skippedCount: decision.skips.count) }
        do {
            try fileManager.removeItem(at: source)
        } catch {
            return .failed(
                reason: "The emptied legacy logs directory could not be removed: \(error.localizedDescription)"
            )
        }
        return .merged(movedCount: movedCount, skippedCount: 0)
    }

    /// Performs a case-only rename in two moves, through a uniquely named sibling.
    ///
    /// A direct `moveItem` cannot do this on a case-insensitive volume: its destination check finds
    /// the source itself and refuses. Moving the directory out from under both spellings first frees
    /// the destination name for the second move. The staging name leads with the current spelling so
    /// that even a crash between the two moves leaves a directory that reads correctly in the Files
    /// app rather than a lowercase one — that window exists only on case-insensitive volumes, never
    /// in the atomic device regime.
    private static func renameThroughStaging(_ source: URL, to destination: URL, fileManager: FileManager) -> Outcome {
        let staging = source.deletingLastPathComponent().appending(
            component: "\(Defaults.FilePath.logs)-migrating-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        do {
            try fileManager.moveItem(at: source, to: staging)
        } catch {
            return .failed(reason: "The legacy logs directory could not be staged: \(error.localizedDescription)")
        }

        do {
            try fileManager.moveItem(at: staging, to: destination)
            return .renamed
        } catch {
            // Something stands at the destination now — on this volume that means a log write
            // created it while the directory was staged. Fold the staged contents into it.
            let merged = mergeContents(of: staging, into: destination, fileManager: fileManager)
            guard case let .failed(reason) = merged else { return merged }
            return restore(staging, to: source, fileManager: fileManager, after: reason)
        }
    }

    /// Puts a staged directory back under its original name after a failed rename, so that a failure
    /// never leaves the logs under an internal name nobody would look for.
    private static func restore(
        _ staging: URL,
        to source: URL,
        fileManager: FileManager,
        after reason: String
    ) -> Outcome {
        do {
            try fileManager.moveItem(at: staging, to: source)
            return .failed(reason: reason)
        } catch {
            return .failed(reason: "\(reason). The logs are in \(staging.lastPathComponent)")
        }
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
