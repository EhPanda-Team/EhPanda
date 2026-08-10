import Foundation

/// A one-time migration of the user-visible activity-log directory from its legacy lowercase name
/// to `Defaults.FilePath.logs`.
///
/// Signatures only at this point: the bodies land with the implementation, so the suite that pins
/// the migration's regimes compiles and fails against a migration that does nothing.
public enum LogsDirectoryMigration {
    /// What a migration attempt actually did.
    public enum Outcome: Equatable, Sendable {
        case nothingToMigrate
        case renamed
        case merged(movedCount: Int, skippedCount: Int)
        case failed(reason: String)
    }

    /// What the migration must do, classified from what the documents directory says about itself.
    public enum Regime: Equatable, Sendable {
        case nothingToMigrate
        case merge
        case renameThroughStaging
        case rename
    }

    /// The file-by-file disposition of a merge, decided from names alone.
    public struct MergeDecision: Equatable, Sendable {
        public let moves: [String]
        public let skips: [String]

        public init(moves: [String], skips: [String]) {
            self.moves = moves
            self.skips = skips
        }
    }

    public static func regime(storedNames: [String], currentSpellingResolves: Bool) -> Regime {
        .nothingToMigrate
    }

    public static func mergeDecision(sourceNames: [String], destinationNames: [String]) -> MergeDecision {
        .init(moves: [], skips: [])
    }

    public static func mergeContents(
        of source: URL,
        into destination: URL,
        fileManager: FileManager = .default
    ) -> Outcome {
        .nothingToMigrate
    }

    public static func run(documentsURL: URL, fileManager: FileManager = .default) -> Outcome {
        .nothingToMigrate
    }
}
