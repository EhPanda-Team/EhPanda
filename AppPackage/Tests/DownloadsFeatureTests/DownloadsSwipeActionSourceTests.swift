import Foundation
import Testing

/// Pins the downloads row's delete-button roles from BOTH sides, because the fix is an ABSENCE.
///
/// The trailing swipe Delete deliberately carries no destructive role. The role makes SwiftUI play
/// an optimistic row-removal the instant the button is tapped — before, and regardless of, any data
/// mutation — and this button mutates nothing: it only sets `state.alert`. So the row vanished on
/// tap, reappeared behind the alert (the next render diff still contains it, since only the alert
/// changed), and vanished a third time when the real deletion arrived through the observe stream.
/// Dropping the role removes the first two beats; `.tint(.red)` carries the styling the role was
/// providing, which is the only effect Apple documents for it on this surface.
///
/// An unmarked delete button reads as an oversight in source, so a comment alone would not survive
/// the first contributor who "fixes" it back. That is what this suite is for.
///
/// **Why every check is region-scoped, and why that is not fussiness.** The role is correct
/// everywhere else it appears — the alert's Delete `ButtonState` and the context-menu Delete both
/// keep it, because neither surface has the optimistic-removal behavior. A file-wide "no
/// destructive role" sweep would therefore be self-invalidating: deleting the context menu's role
/// would satisfy it, which is the opposite of the intent. Each check extracts its own span by
/// brace-matching from a named anchor, and a fourth check pins that the two extracted spans really
/// are the two the other three name — so a region function that silently returned nothing (which
/// would make the absence assertion pass vacuously) fails instead.
///
/// A failure here does not by itself mean the choreography broke. It means the source the
/// choreography rests on moved, and the reasoning above has to be re-derived before the pin is
/// updated.
@Suite
struct DownloadsSwipeActionSourceTests {
    private static let viewPath = "AppPackage/Sources/DownloadsFeature/DownloadsView.swift"
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    private static let trailingSwipeAnchor = ".swipeActions(edge: .trailing"
    private static let leadingSwipeAnchor = ".swipeActions(edge: .leading"
    private static let contextMenuAnchor = "func downloadContextMenu("

    private static let openingBrace: Character = "{"
    private static let closingBrace: Character = "}"

    /// The detection tokens, assembled from fragments.
    ///
    /// This suite scans one named file rather than a tree, so it cannot count itself the way the
    /// censuses in `DownloadSourceInventoryTests` can. The fragments are still worth their cost:
    /// a repository-wide grep for the destructive role — the sweep a future contributor would run
    /// while auditing exactly this decision — must not have its answer polluted by the check that
    /// forbids it, and the file stays safe if this scan is ever widened to a directory.
    private static var destructiveRoleToken: String { "role: ." + "destructive" }
    private static var redTintToken: String { ".tint(" + ".red)" }
    private static var deleteActionToken: String { "deleteDownload" + "ButtonTapped(" }
}

// MARK: - Roles

extension DownloadsSwipeActionSourceTests {
    /// The observable this whole plan turns on: pre-fix this span held exactly one destructive
    /// role, post-fix it holds none.
    @Test
    func testTheTrailingSwipeDeleteCarriesNoDestructiveRole() throws {
        let region = try Self.trailingSwipeRegion()

        #expect(
            Self.occurrences(of: Self.destructiveRoleToken, in: region) == 0,
            """
            The trailing swipe actions carry a destructive role again. The role plays an optimistic \
            row-removal on tap, and this button only presents a confirmation alert, so the row \
            vanishes, returns behind the alert, and vanishes again once the delete lands.
            """
        )
    }

    /// The styling the role used to supply has to come from somewhere, or dropping it is a
    /// regression of its own.
    @Test
    func testTheTrailingSwipeDeleteIsTintedRed() throws {
        let region = try Self.trailingSwipeRegion()

        #expect(
            Self.occurrences(of: Self.redTintToken, in: region) == 1,
            """
            The trailing swipe Delete is no longer tinted red. Dropping the destructive role also \
            drops the red the role was providing; the tint is what replaces it.
            """
        )
    }

    /// The other side of the pin. Without it, deleting the context menu's role would satisfy a
    /// carelessly-written sweep, and the destructive semantics would be lost on the surface that
    /// can afford to keep them.
    @Test
    func testTheContextMenuDeleteKeepsItsDestructiveRole() throws {
        let region = try Self.contextMenuRegion()

        #expect(
            Self.occurrences(of: Self.destructiveRoleToken, in: region) == 1,
            """
            The context-menu Delete lost its destructive role. Context menus have no \
            optimistic-removal behavior, so the role is correct there and only the swipe button \
            drops it.
            """
        )
    }
}

// MARK: - Region extraction

extension DownloadsSwipeActionSourceTests {
    /// Pins that the spans the three checks above read really are the spans their names claim.
    ///
    /// An absence assertion over a region is only as good as the region: a brace matcher that
    /// returned an empty string, or the whole file, would make
    /// `testTheTrailingSwipeDeleteCarriesNoDestructiveRole` pass for the wrong reason in the first
    /// case and fail for the wrong reason in the second. Each span is therefore required to hold
    /// its own delete action and to hold neither of the other two anchors.
    @Test
    func testTheExtractedRegionsAreTheSpansTheirNamesClaim() throws {
        let contents = try Self.executableText(in: Self.viewContents())
        let trailingSwipe = try Self.trailingSwipeRegion()
        let contextMenu = try Self.contextMenuRegion()

        #expect(Self.occurrences(of: Self.deleteActionToken, in: trailingSwipe) == 1)
        #expect(Self.occurrences(of: Self.deleteActionToken, in: contextMenu) == 1)

        #expect(!trailingSwipe.contains(Self.leadingSwipeAnchor))
        #expect(!trailingSwipe.contains(Self.contextMenuAnchor))
        #expect(!contextMenu.contains(Self.leadingSwipeAnchor))
        #expect(!contextMenu.contains(Self.trailingSwipeAnchor))

        #expect(trailingSwipe.count < contents.count)
        #expect(contextMenu.count < contents.count)
    }

    private static func trailingSwipeRegion() throws -> String {
        try executableText(in: bracedRegion(openingAfter: trailingSwipeAnchor, in: try viewContents()))
    }

    private static func contextMenuRegion() throws -> String {
        try executableText(in: bracedRegion(openingAfter: contextMenuAnchor, in: try viewContents()))
    }

    /// `text` with its comment lines dropped, which is not tidiness but the whole reason this
    /// suite can coexist with the comment it protects.
    ///
    /// The absence being pinned is deliberate and unobvious, so the call site has to say so — and
    /// saying so means naming the role that must not be there. Counted raw, the explanation IS the
    /// violation: the first run after the fix failed on the comment alone, with the button already
    /// role-less. A check that forbids its own documentation is a check nobody can maintain, so the
    /// filter comes from `DownloadSourceInventoryTests.executableLines(in:)`, which drops comment
    /// lines for exactly this reason.
    private static func executableText(in text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter({ $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false })
            .joined(separator: "\n")
    }

    /// The block that opens at the first brace after `anchor`, delimited by brace counting.
    ///
    /// Brace counting is naive — it does not know about braces inside string literals or comments,
    /// and it runs BEFORE `executableText(in:)` strips them, so a comment carrying a lone brace
    /// would mis-close the span. That is a deliberate limit rather than an oversight: both spans it
    /// is pointed at are view-builder bodies of tints, symbols and localized-key references, and
    /// the one comment inside either of them carries no brace. If that stops being true, this
    /// function is the thing to fix, and the region guard above is what will notice.
    private static func bracedRegion(openingAfter anchor: String, in contents: String) throws -> String {
        let anchorRange = try #require(
            contents.range(of: anchor),
            "The anchor \(anchor) is gone from \(viewPath); a region check refuses to read a span it cannot locate."
        )
        let openIndex = try #require(
            contents[anchorRange.upperBound...].firstIndex(of: openingBrace),
            "No block opens after \(anchor) in \(viewPath)."
        )

        var depth = 0
        var closeIndex: String.Index?
        var index = openIndex

        while closeIndex == nil, index < contents.endIndex {
            if contents[index] == openingBrace {
                depth += 1
            } else if contents[index] == closingBrace {
                depth -= 1
                if depth == 0 {
                    closeIndex = index
                }
            }
            index = contents.index(after: index)
        }

        let end = try #require(closeIndex, "The block opened after \(anchor) in \(viewPath) is unbalanced.")
        return String(contents[openIndex...end])
    }

    private static func occurrences(of token: String, in text: String) -> Int {
        text.components(separatedBy: token).count - 1
    }
}

// MARK: - Source access

extension DownloadsSwipeActionSourceTests {
    private static func viewContents() throws -> String {
        let url = try repositoryRoot().appending(path: viewPath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func repositoryRoot() throws -> URL {
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
            "Could not locate the repository root; the source check refuses a vacuous scan."
        )
    }

    private static func isRepositoryRoot(_ directory: URL) -> Bool {
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
}
