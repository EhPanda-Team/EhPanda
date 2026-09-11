import CustomDump
import Foundation
import Testing

/// Pins the Reduce Motion gating inventory that Phase 16 D-29 settled.
///
/// D-29 is a judgement made once: motion that changes position or size — slides, scale, rotation,
/// implicit list diffs, height changes — is gated on `accessibilityReduceMotion` and degrades to a
/// dissolve or to nothing, while opacity crossfades, colour changes and `.contentTransition(.numericText)`
/// digit rolls stay ungated, because they are not vestibular triggers and flattening them would remove
/// motion Apple never asked to remove. Nothing in the build enforces that line: an animation added
/// without a gate compiles, and so does a well-meaning gate on a crossfade. Both land silently, and
/// the next person reading the site cannot tell a deliberate omission from an oversight.
///
/// This suite freezes the call as equalities over the live source (plans 16-20 and 16-21): the files
/// that read the environment value and how many times, the ternary predicates per file, the two
/// `withAnimation` gates, every executable line that mentions the gate value at all, and the repo-wide
/// count of `numericText` sites with a check that none of those lines carries the gate. Each table is
/// exact and two-directional — a file that gains or loses a gate fails, and so does a file outside the
/// table that acquires one — so a regression and an over-gate both fail here instead of shipping.
///
/// The pattern is `DownloadSourceInventoryTests`: a repository-root walk (shared `RepositoryWalk`),
/// known members so an enumerator that walked nothing cannot pass vacuously, detection tokens assembled
/// from fragments so a repository grep gate cannot match the suite that pins it, comment lines
/// excluded so a doc that describes a gate is not counted as one, and per-file tables asserted beside
/// separately counted totals.
///
/// Three gate shapes exist in the tree that the ternary token does not see, and the mention census is
/// what pins them: the toast transition's ternary is broken across lines (`reduceMotion` alone, then
/// `? .opacity`), the privacy mask composes the value with `||` before its `?`, and the Detail
/// header composes it with `&&` into `spinsDownloadIcon` and the pulse's `isActive:`. A new gate of
/// any shape still moves its file's mention count, which is the equality that catches it.
@Suite
struct ReduceMotionGatingSourceTests {
    private struct ScannedFile {
        /// Path relative to `sourcesDirectory`, unique across modules.
        let relativePath: String
        let contents: String
    }

    private static let sourcesDirectory = "AppPackage/Sources"

    /// One file from each of three modules the inventory spans, so a walk that silently returned an
    /// empty or partial tree cannot let a table pass vacuously.
    private static let knownMembers = [
        "DownloadsFeature/DownloadsView.swift",
        "ReadingFeature/ReadingView.swift",
        "SystemNotification/View+Toast.swift"
    ]

    // MARK: - Detection tokens, assembled so this file matches none of them

    /// The environment key path's property name.
    private static var environmentReadToken: String { "accessibility" + "ReduceMotion" }
    /// The house predicate shape `reduceMotion ? gated : ungated`.
    private static var ternaryPredicateToken: String { "reduce" + "Motion ?" }
    /// The programmatic-change shape `withAnimation(reduceMotion ? nil : …)`.
    private static var withAnimationGateToken: String { "with" + "Animation(reduce" + "Motion" }
    /// The gate value's name, whatever expression it sits in.
    private static var gateValueToken: String { "reduce" + "Motion" }
    /// The digit-roll transition D-29 keeps ungated.
    private static var numericTextToken: String { ".content" + "Transition(.numeric" + "Text" }

    // MARK: - Pinned inventory

    /// Files reading `\.accessibilityReduceMotion`, with how many views in each read it.
    private static let expectedEnvironmentReads: [String: Int] = [
        "AppComponents/ViewModifiers.swift": 1,
        "DetailFeature/Comments/CommentsView.swift": 1,
        "DetailFeature/DetailView+HeaderSection.swift": 1,
        "DetailFeature/DetailView.swift": 1,
        "DetailFeature/FolderManager/FolderManagerView.swift": 1,
        "DetailFeature/Torrents/TorrentsView.swift": 1,
        "DownloadsFeature/DownloadsView+Subviews.swift": 2,
        "DownloadsFeature/DownloadsView.swift": 1,
        "HomeFeature/GalleryCardCell.swift": 1,
        "HomeFeature/HomeView.swift": 1,
        "QuickSearchFeature/QuickSearchView.swift": 1,
        "ReadingFeature/ReadingView.swift": 1,
        "ReadingFeature/Support/ControlPanel.swift": 1,
        "SearchFeature/SearchRootView.swift": 1,
        "SettingFeature/GeneralSetting/GeneralSettingView.swift": 1,
        "SystemNotification/View+Toast.swift": 1
    ]
    private static let expectedEnvironmentReadTotal = 17

    /// Executable lines carrying the ternary predicate, per file.
    private static let expectedTernaryPredicates: [String: Int] = [
        "DetailFeature/Comments/CommentsView.swift": 1,
        "DetailFeature/DetailView.swift": 3,
        "DetailFeature/FolderManager/FolderManagerView.swift": 1,
        "DetailFeature/Torrents/TorrentsView.swift": 1,
        "DownloadsFeature/DownloadsView+Subviews.swift": 3,
        "DownloadsFeature/DownloadsView.swift": 1,
        "HomeFeature/GalleryCardCell.swift": 2,
        "HomeFeature/HomeView.swift": 1,
        "QuickSearchFeature/QuickSearchView.swift": 1,
        "ReadingFeature/ReadingView.swift": 3,
        "ReadingFeature/Support/ControlPanel.swift": 2,
        "SearchFeature/SearchRootView.swift": 1,
        "SettingFeature/GeneralSetting/GeneralSettingView.swift": 1,
        "SystemNotification/View+Toast.swift": 1
    ]
    private static let expectedTernaryPredicateTotal = 22

    /// The deep-linked comment scroll and the reader's page jump.
    private static let expectedWithAnimationGateTotal = 2

    /// Executable lines mentioning the gate value at all — reads, predicates, compositions, and the
    /// parameter plumbing that hands it to a child — per file.
    private static let expectedGateMentions: [String: Int] = [
        "AppComponents/ViewModifiers.swift": 2,
        "DetailFeature/Comments/CommentsView.swift": 2,
        "DetailFeature/DetailView+HeaderSection.swift": 3,
        "DetailFeature/DetailView.swift": 4,
        "DetailFeature/FolderManager/FolderManagerView.swift": 2,
        "DetailFeature/Torrents/TorrentsView.swift": 2,
        "DownloadsFeature/DownloadsView+Subviews.swift": 8,
        "DownloadsFeature/DownloadsView.swift": 2,
        "HomeFeature/GalleryCardCell.swift": 9,
        "HomeFeature/HomeView.swift": 2,
        "QuickSearchFeature/QuickSearchView.swift": 2,
        "ReadingFeature/ReadingView.swift": 4,
        "ReadingFeature/Support/ControlPanel.swift": 3,
        "SearchFeature/SearchRootView.swift": 2,
        "SettingFeature/GeneralSetting/GeneralSettingView.swift": 2,
        "SystemNotification/View+Toast.swift": 3
    ]
    private static let expectedGateMentionTotal = 52

    /// `.contentTransition(.numericText…)` sites across the tree; every one stays ungated (D-29).
    private static let expectedNumericTextTotal = 11

    // MARK: - Environment reads

    @Test
    func environmentReadsMatchTheRecordedInventory() throws {
        let files = try Self.scannedFiles()

        let reads = Self.census(of: Self.environmentReadToken, in: files)
        #expect(
            reads == Self.expectedEnvironmentReads,
            """
            The set of views reading accessibilityReduceMotion moved. Re-derive the D-29 inventory \
            (position / size motion in, opacity / colour / digits out), then update this table.
            """
        )
        expectNoDifference(
            Self.occurrences(of: Self.environmentReadToken, in: Self.joinedExecutableLines(of: files)),
            Self.expectedEnvironmentReadTotal
        )
    }

    // MARK: - Gate predicates

    @Test
    func ternaryPredicatesMatchTheRecordedInventory() throws {
        let files = try Self.scannedFiles()

        let predicates = Self.census(of: Self.ternaryPredicateToken, in: files)
        #expect(
            predicates == Self.expectedTernaryPredicates,
            """
            The per-file count of `reduceMotion ?` predicates moved. A new gate must be position or \
            size motion and a removed one must have been re-judged; re-derive, then update this table.
            """
        )
        expectNoDifference(
            Self.occurrences(of: Self.ternaryPredicateToken, in: Self.joinedExecutableLines(of: files)),
            Self.expectedTernaryPredicateTotal
        )

        for file in predicates.keys {
            #expect(
                Self.expectedEnvironmentReads[file] != nil,
                "\(file) gates on the value without reading the environment in that file."
            )
        }
    }

    @Test
    func withAnimationGatesMatchTheRecordedTotal() throws {
        let files = try Self.scannedFiles()

        let gates = Self.census(of: Self.withAnimationGateToken, in: files)
        expectNoDifference(gates.values.reduce(0, +), Self.expectedWithAnimationGateTotal)

        for file in gates.keys {
            #expect(
                Self.expectedEnvironmentReads[file] != nil,
                "\(file) wraps a change in a gated withAnimation without reading the environment."
            )
        }
    }

    @Test
    func gateMentionsMatchTheRecordedInventory() throws {
        let files = try Self.scannedFiles()

        let mentions = Self.census(of: Self.gateValueToken, in: files)
        #expect(
            mentions == Self.expectedGateMentions,
            """
            The executable lines mentioning the gate value moved somewhere. This census sees every \
            gate shape, including the composed and line-broken ones the ternary token misses; \
            re-derive the site, judge it under D-29, then update this table.
            """
        )
        expectNoDifference(
            Self.occurrences(of: Self.gateValueToken, in: Self.joinedExecutableLines(of: files)),
            Self.expectedGateMentionTotal
        )
        expectNoDifference(Set(mentions.keys), Set(Self.expectedEnvironmentReads.keys))
    }

    // MARK: - Sites that stay ungated

    @Test
    func numericTextSitesStayUngated() throws {
        let files = try Self.scannedFiles()

        let numericTextLines = files.flatMap({ file in
            Self.executableLines(in: file.contents)
                .filter({ $0.contains(Self.numericTextToken) })
                .map({ (file: file.relativePath, line: $0) })
        })
        expectNoDifference(numericTextLines.count, Self.expectedNumericTextTotal)
        expectNoDifference(
            Self.occurrences(of: Self.numericTextToken, in: Self.joinedExecutableLines(of: files)),
            Self.expectedNumericTextTotal
        )

        for site in numericTextLines {
            #expect(
                site.line.contains(Self.gateValueToken) == false,
                "\(site.file) gates a numericText digit roll on Reduce Motion; D-29 keeps those ungated."
            )
        }
    }
}

// MARK: - Counting

private extension ReduceMotionGatingSourceTests {
    /// Per-file occurrences of `token` on executable lines, listing only the files that carry it.
    ///
    /// Comment lines are skipped because the gates are described BY comments: counting those
    /// mentions would make the doc that explains a gate part of the gate count, so rewording a
    /// sentence would move the number it stands for.
    private static func census(of token: String, in files: [ScannedFile]) -> [String: Int] {
        var counts = [String: Int]()
        for file in files {
            let count = occurrences(of: token, in: executableLines(in: file.contents).joined(separator: "\n"))
            guard count > 0 else { continue }
            counts[file.relativePath] = count
        }
        return counts
    }

    static func executableLines(in contents: String) -> [String] {
        contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter({ $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false })
    }

    private static func joinedExecutableLines(of files: [ScannedFile]) -> String {
        files.map({ executableLines(in: $0.contents).joined(separator: "\n") }).joined(separator: "\n")
    }

    static func occurrences(of token: String, in text: String) -> Int {
        text.components(separatedBy: token).count - 1
    }
}

// MARK: - Scanning

private extension ReduceMotionGatingSourceTests {
    /// Every Swift file under `AppPackage/Sources`, keyed relative to it.
    ///
    /// The walk is scoped to production source: the tokens are assembled from fragments so this
    /// suite would not match itself, but the test trees hold view doubles and fixtures whose gates
    /// are not D-29 sites, and counting them would re-base every table the moment one appeared.
    private static func scannedFiles() throws -> [ScannedFile] {
        let sources = try RepositoryWalk.repositoryRoot().appending(path: sourcesDirectory)
        let enumerator = try #require(
            FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        )
        var files = [ScannedFile]()

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(
                ScannedFile(
                    relativePath: RepositoryWalk.relativePath(of: url, under: sources),
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            )
        }

        try #require(files.isEmpty == false)
        for knownMember in knownMembers {
            try #require(
                files.contains(where: { $0.relativePath == knownMember }),
                "The scan lost its known member \(knownMember); it refuses a vacuous walk."
            )
        }
        return files
    }
}
