import CustomDump
import Foundation
import Testing

/// One audited site (or group of sites in a file) that is allowed to carry no hover helper, and why.
///
/// The count is exact: a site added to the file fails the audit until the entry is raised, and a site removed from
/// it fails until the entry is lowered, so an entry can neither silently cover a new control nor outlive its own.
struct HoverAuditAllowance: Sendable {
    /// Path relative to the repository root.
    let file: String
    let kind: PointerHoverScanner.SiteKind
    let count: Int
    let reason: String
}

/// D-08: every plain or unhighlighted button, tap gesture and custom button style in the app's iOS code carries a
/// hover helper after it, or is one of a few allowlisted sites whose reason is written down.
///
/// A plain style or a tap gesture strips the system's pointer response from a control, and nothing in the build
/// notices that a control lost it: the control still works with touch and still draws, and the first person to see
/// the missing hover is one with a pointer. This suite reads the live source through ``PointerHoverScanner`` and
/// fails the moment a control lands without one, so the next plain button is audited by the test run instead of by
/// somebody's memory.
///
/// The walk covers `App/` and `AppPackage/Sources/`: the share extension and the test targets lie outside both
/// roots, and the preview and snapshot support directories draw fixtures, not the app's controls (D-01).
@Suite
struct PointerHoverAuditTests {
    struct AuditedFile {
        /// Path relative to the repository root.
        let path: String
        let sites: [PointerHoverScanner.Site]
        let setsIconTapShape: Bool
    }

    private static let walkedRoots = ["App", "AppPackage/Sources"]
    private static let excludedDirectories: Set<String> = ["PreviewSupport", "VisualSnapshotSupport"]
    private static let excludedFileSuffix = "_Snapshots.swift"

    /// One file from each root and from the modules the audit is about, so a walk that silently returned an empty
    /// or partial tree cannot let the audit pass vacuously.
    private static let knownMembers = [
        "App/EhPandaApp.swift",
        "AppPackage/Sources/AppTools/InteractiveHover.swift",
        "AppPackage/Sources/AppComponents/GalleryReadInteraction.swift",
        "AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift"
    ]

    /// The fewest sites the live tree can hold and still be a real scan. The census at the time of writing is 21, so
    /// the floor is about half of it: removing a control does not fail the vacuity test, while a broken walk does.
    private static let siteFloor = 10

    private static let helperFile = "AppPackage/Sources/AppTools/InteractiveHover.swift"

    /// The double-tap read and the single-tap detail (a spatial tap, so a tap on the cover reads) are one arbitration.
    private static let galleryReadInteractionReason = "Not a control of its own (D-07): the double-tap read and the "
        + "single-tap detail arbitrate inside the Button that is the control, in one shared modifier used by list "
        + "rows (rule R) and grid tiles (their own shape), so the hover belongs to each call site (D-04, D-11 G1)."

    /// Every site without a helper in the tree, and the one reason each is right to stay without.
    private static let allowances = [
        HoverAuditAllowance(
            file: "AppPackage/Sources/AppComponents/GalleryReadInteraction.swift",
            kind: .tapGesture,
            count: 1,
            reason: Self.galleryReadInteractionReason
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/AppComponents/GalleryReadInteraction.swift",
            kind: .spatialTapGesture,
            count: 1,
            reason: Self.galleryReadInteractionReason
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift",
            kind: .spatialTapGesture,
            count: 2,
            reason: "The reader's full-surface page zones are a gesture area, not a control (D-02 E0, D-07)."
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/AppComponents/UnhighlightedButtonStyle.swift",
            kind: .buttonStyleConformance,
            count: 1,
            reason: "Draws the label alone by owner decision (2026-09-15); the hover belongs to each call site in "
                + "its own shape (D-06)."
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift",
            kind: .plainButtonStyle,
            count: 1,
            reason: "The move-controls button's interactive glass draws its own pointer response (D-11 G3); "
                + "hoverShape gives it the glass's 16 pt corners."
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift",
            kind: .buttonStyleConformance,
            count: 1,
            reason: "DownloadBannerStyle's interactive glass draws its own pointer response (D-11 G3); "
                + "hoverShape gives it the glass capsule."
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/DetailFeature/Moderation/CommentModerationMenu.swift",
            kind: .plainButtonStyle,
            count: 1,
            reason: "The pointer hover is on the Menu's label, after the label's frame, not after the plain style: "
                + "on the Menu it redrew the ellipsis of the second row at the extra-small size in iPhone landscape."
        ),
        HoverAuditAllowance(
            file: "AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift",
            kind: .unhighlightedButtonStyle,
            count: 1,
            reason: "The cell's interactive glass draws its own pointer response (D-11 G3); hoverShape gives it the "
                + "glass's 15 pt corners."
        )
    ]

    @Test
    func everyAuditedSiteHasAHoverOrAnAllowance() throws {
        let files = try Self.auditedFiles()
        let sitesByFile = Dictionary(uniqueKeysWithValues: files.map({ ($0.path, $0.sites) }))

        expectNoDifference(
            PointerHoverScanner.unmetCounts(in: sitesByFile),
            PointerHoverScanner.allowedCounts(Self.allowances)
        )
    }

    @Test
    func everyAllowanceCarriesAReason() {
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: [:], allowances: Self.allowances)

        expectNoDifference(evaluation.reasonless, [])
    }

    @Test
    func scanIsNotVacuous() throws {
        let files = try Self.auditedFiles()

        let siteCount = files.reduce(0, { $0 + $1.sites.count })
        #expect(
            siteCount >= Self.siteFloor,
            "The scan found \(siteCount) audited sites, under the floor of \(Self.siteFloor): a vacuous walk."
        )
        let paths = Set(files.map(\.path))
        for member in Self.knownMembers {
            #expect(paths.contains(member), "The scan lost its known member \(member).")
        }
    }

    @Test
    func onlyTheHelperSetsTheIconTapShape() throws {
        let files = try Self.auditedFiles()

        let writers = files.filter(\.setsIconTapShape).map(\.path)
        expectNoDifference(writers, [Self.helperFile])
    }
}

// MARK: - Scanning

private extension PointerHoverAuditTests {
    /// Every Swift file under the walked roots that draws the app's controls, with its sites.
    static func auditedFiles() throws -> [AuditedFile] {
        let root = try RepositoryWalk.repositoryRoot()
        var files = [AuditedFile]()

        for walkedRoot in walkedRoots {
            let directory = root.appending(path: walkedRoot)
            let enumerator = try #require(
                FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
            )
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let path = RepositoryWalk.relativePath(of: url, under: root)
                guard isAudited(path) else { continue }
                let processed = PointerHoverScanner.preprocessed(try String(contentsOf: url, encoding: .utf8))
                files.append(
                    AuditedFile(
                        path: path,
                        sites: PointerHoverScanner.sites(in: processed),
                        setsIconTapShape: PointerHoverScanner.setsIconTapShape(processed)
                    )
                )
            }
        }

        try #require(files.isEmpty == false)
        return files.sorted(by: { $0.path < $1.path })
    }

    static func isAudited(_ path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        return excludedDirectories.isDisjoint(with: components) && !path.hasSuffix(excludedFileSuffix)
    }
}
