import XCTest

// The report model `AccessibilityAuditUITests` judges every audit issue with, and the pre-audit
// frame inventory it logs beside a failing report.

/// One allow-listed audit issue. `matches` is deliberately narrow — it identifies one element
/// and one audit type — so an entry can never silence a neighbouring finding.
struct AuditExclusion {
    let id: String
    let reason: String
    let matches: (AuditReport) -> Bool
}

/// One audit report, read once in the handler so every exclusion judges the same values.
struct AuditReport {
    let surface: String
    let auditType: XCUIAccessibilityAuditType
    let element: AuditElement?
    let elementDescription: String

    init(surface: String, issue: XCUIAccessibilityAuditIssue) {
        self.surface = surface
        auditType = issue.auditType
        let description = issue.element?.description
        elementDescription = description ?? "<no element>"
        element = AuditElement(description: description)
    }
}

/// The frames of the exposed hierarchy, captured in one snapshot before the audit: what occludes
/// scrolled content (tab bar, navigation bar, the toast card), what is shown (the presented
/// sheet, else the window) and where each named element lies, logged beside a report no
/// allow-list claims. Taken before the audit, never inside the handler, so the engine's
/// identity-bound elements are not re-resolved while the reports arrive.
struct SurfaceInventory {
    /// The Liquid Glass tab bar blurs a band of content above its own frame (the scroll-edge
    /// effect), so the band counts as occluded; Home's Toplists heading row sits 9 points above
    /// the bar on the iPhone 17e, inside it. The band is the largest gap measured, rounded up.
    private static let scrollEdgeBand: CGFloat = 24

    /// The identifier UIKit gives the dimming view of a sheet or popover presentation ("dismiss
    /// popup"). The presented container is its sibling; the presenting content stays exposed
    /// beneath it (the iPad dumps of 16-24 `diag-26`).
    private static let dismissRegionIdentifier = "PopoverDismissRegion"

    private let occludingFrames: [CGRect]
    private let visibleBounds: CGRect
    private let framesByName: [String: [CGRect]]

    @MainActor init(app: XCUIApplication) throws {
        let root = try app.snapshot()
        var occludingFrames: [CGRect] = []
        var framesByName: [String: [CGRect]] = [:]
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            switch node.elementType {
            case .tabBar:
                var band = node.frame
                band.origin.y -= Self.scrollEdgeBand
                band.size.height += Self.scrollEdgeBand
                occludingFrames.append(band)
            case .navigationBar:
                occludingFrames.append(node.frame)
            default:
                break
            }
            if node.identifier == "toast_message" { occludingFrames.append(node.frame) }
            // XCTest describes an element by its identifier when it has one, else by its label.
            let name = node.identifier.isEmpty ? node.label : node.identifier
            if !name.isEmpty { framesByName[name, default: []].append(node.frame) }
        }
        self.occludingFrames = occludingFrames
        self.visibleBounds = Self.visibleBounds(in: root)
        self.framesByName = framesByName
    }

    /// The frame of what is shown: the topmost presented sheet — the sibling of a presentation's
    /// dimming view that is smaller than the window (the iPad form sheet, `{120, 260, 580, 650}`
    /// in an 820 × 1180 window) — or the window when nothing is presented.
    static func visibleBounds(in root: XCUIElementSnapshot) -> CGRect {
        let window = root.children.first(where: { $0.elementType == .window })?.frame ?? root.frame
        var bounds = window
        // Depth-first in document order, so the last presentation found is the topmost one.
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children.reversed())
            guard node.children.contains(where: { $0.identifier == dismissRegionIdentifier }) else { continue }
            let presented = node.children.last { child in
                child.identifier != dismissRegionIdentifier && !child.frame.isEmpty
                    && window.contains(child.frame) && child.frame != window
            }
            if let presented { bounds = presented.frame }
        }
        return bounds
    }

    /// The pre-audit frames an element name had, with what was shown and what occluded it, for
    /// the log line of a report no rule claimed.
    func geometry(of name: String?) -> String {
        let frames = name.flatMap({ framesByName[$0] }) ?? []
        return "frames \(frames) | shown \(visibleBounds) | occluders \(occludingFrames)"
    }
}

/// The element a report names, taken from the description XCTest prints for it: `"name" Type`,
/// where the name is the identifier when the element has one and the label otherwise, or the
/// bare type for an unlabelled element (`ActivityIndicator`).
///
/// Only the description is read: it names the element and its type, which is all the exclusions
/// need, and it is resolved once per report — nothing in the handler queries the app again, so
/// the engine's identity-bound elements are never re-resolved mid-audit (reading a frame there
/// re-queries the element by description; 16-24 diag-9 lost the later reports of a surface that
/// way). A report whose element the engine withholds (`issue.element == nil`) has no
/// `AuditElement`, matches no element-scoped exclusion, and so fails the test.
struct AuditElement {
    let name: String
    let type: String

    init?(description: String?) {
        guard let description, let typeStart = description.lastIndex(of: " ") else {
            // No space: the bare type of an unlabelled element, or nothing at all.
            guard let description, !description.isEmpty else { return nil }
            name = ""
            type = description
            return
        }
        type = String(description[description.index(after: typeStart)...])
        let quoted = description[..<typeStart]
        guard quoted.hasPrefix("\""), quoted.hasSuffix("\""), quoted.count >= 2 else { return nil }
        name = String(quoted.dropFirst().dropLast())
    }
}
