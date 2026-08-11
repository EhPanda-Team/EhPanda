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
/// it lazily on first write. It never deletes a file, and the only directories it removes are ones
/// it has just emptied — a legacy directory, or a staging directory of its own making. Nothing here
/// throws — every failure becomes an `Outcome` the caller logs, so a migration that cannot run
/// degrades to the previous behavior instead of blocking launch or losing logs.
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
///
/// ## Why the staging name is classified rather than assumed transient
///
/// Not every exit of a staged rename can put the directory back: the second move can fail, its
/// fold-in can leave a collision behind, and the restoring move can fail in turn. Any of those
/// leaves a `Logs-migrating-…` directory standing under `Documents`, which the Files app publishes.
/// So the staging name is a first-class regime rather than an internal detail — see
/// `Regime.recoverStaging(named:)` — and `Outcome.failed`'s promise that "the next launch retries
/// from the state left behind" holds for every state this type can leave.

public enum LogsDirectoryMigration {
    /// The directory name that shipped before the rename.
    ///
    /// Frozen deliberately, and NOT derived from `Defaults.FilePath.logs` (e.g. by lowercasing it):
    /// this is a historical fact about installs in the field. Deriving it would mean that renaming
    /// the current constant again silently redefines which directory this migration reads *from*,
    /// and the previously migrated directory would become the thing left stranded.
    private static let legacyDirectoryName = "logs"

    /// The prefix of the transient name a case-only rename moves through, and the signature by which
    /// a residue left by an interrupted attempt is recognised at the next launch.
    ///
    /// Derived from the CURRENT constant, unlike `legacyDirectoryName`: what this names is not a
    /// historical fact about installs in the field but a residue this type mints itself, always
    /// under the spelling in force when it minted it. Renaming the constant again would need its own
    /// migration pass regardless, exactly as this rename did.
    private static let stagingPrefix = "\(Defaults.FilePath.logs)-migrating-"

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
        /// A directory this type staged during an earlier attempt is still stored, holding logs
        /// under a name nothing reads.
        ///
        /// It outranks every other regime because it is the only one whose subject is data already
        /// in flight: the legacy directory it was moved out of no longer exists, so no other
        /// classification can see it. A legacy directory standing alongside it is left to the next
        /// run, which this one leaves free to classify — the migration is idempotent by design and
        /// runs at every launch.
        case recoverStaging(named: String)
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
        // Ahead of the legacy-name guard, because a residue is precisely the state in which the
        // legacy name is already gone. Sorted first so that which residue is picked is a function of
        // the listing's contents rather than of the order the filesystem happened to report them in.
        if let staged = storedNames.sorted().first(where: { $0.hasPrefix(stagingPrefix) }) {
            return .recoverStaging(named: staged)
        }
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
        // A residue is its own subject and is handled ahead of the guard below, which speaks only
        // for the legacy name: by the time a residue exists, the legacy directory it came from has
        // already been moved out from under that name.
        if case let .recoverStaging(stagedName) = resolvedRegime {
            let staging = documentsURL.appending(component: stagedName, directoryHint: .isDirectory)
            // Same reason as the legacy name below: File Sharing lets the user drop a regular file
            // onto any name in Documents, including one this type would otherwise claim.
            guard isDirectory(staging, fileManager: fileManager) else { return .nothingToMigrate }
            return recoverStaging(staging, to: currentURL, fileManager: fileManager)
        }
        guard resolvedRegime != .nothingToMigrate else { return .nothingToMigrate }

        // The legacy name is stored, but only a DIRECTORY is ours to migrate. File Sharing lets the
        // user drop a regular file called `logs` into Documents, and moving that onto the current
        // name would put a file exactly where `appendToRunFile` needs to create a directory,
        // breaking logging outright. Leave the user's file where they put it.
        guard isDirectory(legacyURL, fileManager: fileManager) else { return .nothingToMigrate }

        switch resolvedRegime {
        case .nothingToMigrate, .recoverStaging:
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
            component: "\(stagingPrefix)\(UUID().uuidString)",
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
            // `mergeContents` removes the directory it merged FROM only when it emptied it, which is
            // exactly `.merged(_, skippedCount: 0)`. Every other outcome — a collision it skipped, a
            // move that failed, a listing it could not take — leaves the staged directory standing,
            // so it goes back under the legacy name rather than being reported away. This arm used
            // to return `.merged` here, leaving the skipped files staged.
            if case .merged(_, 0) = merged { return merged }
            return restore(staging, to: source, fileManager: fileManager, reporting: merged)
        }
    }

    /// Folds a residue from an interrupted staged rename onto the current name.
    ///
    /// Reached only from the `recoverStaging` regime, so the directory it moves is one this type
    /// minted and abandoned rather than anything the user put there. The move is tried first because
    /// it is the case where the destination is free; the fold-in runs only when something stands
    /// there, and it overwrites nothing.
    private static func recoverStaging(_ staging: URL, to destination: URL, fileManager: FileManager) -> Outcome {
        do {
            try fileManager.moveItem(at: staging, to: destination)
            return .renamed
        } catch {
            return mergeContents(of: staging, into: destination, fileManager: fileManager)
        }
    }

    /// Puts a staged directory back under its original name, so that neither a failed rename nor a
    /// partial fold-in leaves the logs under an internal name nobody would look for.
    ///
    /// `outcome` is what the fold-in reported. A restore that succeeds returns it unchanged, because
    /// putting the directory back changes nothing about what the fold-in did; only a restore that
    /// itself fails downgrades the report, and it names the directory the user can see in the Files
    /// app. Either way the residue is now classifiable — see `Regime.recoverStaging(named:)`.
    private static func restore(
        _ staging: URL,
        to source: URL,
        fileManager: FileManager,
        reporting outcome: Outcome
    ) -> Outcome {
        do {
            try fileManager.moveItem(at: staging, to: source)
            return outcome
        } catch {
            let summary = switch outcome {
            case let .failed(reason): reason
            case let .merged(movedCount, skippedCount):
                "Moved \(movedCount) log files and left \(skippedCount) behind"
            case .nothingToMigrate, .renamed: "The staged logs directory could not be put back"
            }
            return .failed(reason: "\(summary). The logs are in \(staging.lastPathComponent)")
        }
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
