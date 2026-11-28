import CoreGraphics

/// A view's snapshot states, shaped like `PreviewProvider` and read by the snapshot matrix tests (19-18, design
/// section 1). Previews stay `#Preview`; the matrix has its own declarations because each state carries what a
/// preview does not: the scenario ID, the signed-in state, the artwork it loads and the user step that brings the
/// hosted view to its state, together with the committed page heights.
///
/// Each view has one `<View>ViewSnapshot.swift` file under `Snapshots/`, and ``ScenarioCatalog/providers`` lists
/// them: Swift has no type discovery. Test target only, nothing reaches Release.
protocol SnapshotProvider {
    @MainActor static var states: [SnapshotState] { get }
}

/// One scenario: its ID, the page heights its pictures are taken at, and how to build it.
///
/// The stored properties keep this order, so that a tool rewriting the committed heights finds `heights` right
/// after `id`.
struct SnapshotState {
    /// The scenario ID in `scenarios.json`, for example `front-page-list`. Picture keys derive from it.
    let id: String
    /// The height of the window the scenario's pictures are taken in.
    let heights: PageHeights
    /// The real view and store, the signed-in state and the user step, as the scenario has always declared them.
    let factory: ScenarioFactory
}

/// The height, in points, of the window a scenario's pictures are taken in.
enum PageHeights: Equatable {
    /// The pinned device's own height: the page never scrolls (the reader, alerts, full-screen states) or is taken
    /// as the screen shows it.
    case screen
    /// A height that covers the whole page, one value per family, orientation and text size, the tallest of the six
    /// languages (design section 3).
    case committed(iphone: Orientations, ipad: Orientations)
    /// The pinned device's own height, for a page the owner exempted from the full-page rule (19-26): its pictures are
    /// taken as the screen shows it, and the `page-height` check skips it. `reason` is the owner's decision, quoted
    /// and dated; there is no exemption without it.
    case viewport(reason: String)

    /// Whether the `page-height` check holds the scenario's pictures to these heights: every case but
    /// ``viewport(reason:)``.
    var isChecked: Bool {
        if case .viewport = self { false } else { true }
    }

    /// A family's heights in each orientation.
    struct Orientations: Equatable {
        let portrait: Sizes
        let landscape: Sizes
    }

    /// An orientation's heights at the three text sizes the matrix runs.
    struct Sizes: Equatable {
        let xSmall: CGFloat
        let large: CGFloat
        let accessibility5: CGFloat
    }

    /// The window height of one coordinate. `family` is `iphone` or `ipad`, `orientation` `portrait` or `landscape`,
    /// and `size` `xSmall`, `large` or `accessibility5`, as the matrix names them; `screenHeight` is what `.screen`
    /// and `.viewport` stand for.
    func points(family: String, orientation: String, size: String, screenHeight: CGFloat) -> CGFloat {
        guard case .committed(let iphone, let ipad) = self else { return screenHeight }
        let orientations: Orientations
        switch family {
        case "iphone": orientations = iphone
        case "ipad": orientations = ipad
        default: preconditionFailure("Unknown device family \(family)")
        }
        let sizes: Sizes
        switch orientation {
        case "portrait": sizes = orientations.portrait
        case "landscape": sizes = orientations.landscape
        default: preconditionFailure("Unknown orientation \(orientation)")
        }
        switch size {
        case "xSmall": return sizes.xSmall
        case "large": return sizes.large
        case "accessibility5": return sizes.accessibility5
        default: preconditionFailure("Unknown text size \(size)")
        }
    }
}
