public import SwiftUI

// The one home of every pointer hover in the app (iPad, iPhone Duo, the app run on a Mac as an iPad app).
//
// The rules, which the call sites rely on:
// - Only the system effects draw a hover: `contentShape(.hoverEffect, …)`, `hoverEffect(_:)` and
//   `hoverEffectDisabled(_:)`. The system owns the timing, the motion settings, Increase Contrast and Dark Mode, so
//   nothing here fills, animates or observes the pointer itself.
// - Nothing here asks for the idiom, the device or a size class. Hover follows the input: wherever iOS sends a
//   pointer, the same code lights up.
// - The package is iOS-only, so there is no macOS branch.

/// The system pointer effect a control draws while a pointer is over it.
public enum InteractiveHoverEffect: Sendable {
    /// The system highlight, drawn in the control's hover shape. For icon buttons without a background, rows, text
    /// buttons, chips, and any control inside a bar or a list, including glass or tinted controls that already draw
    /// their own fill.
    case highlight
    /// The system lift, drawn in the view's own clip shape. For a standalone card or tile with its own background
    /// that is narrower than the full content width.
    case lift

    var hoverEffect: HoverEffect {
        switch self {
        case .highlight: .highlight
        case .lift: .lift
        }
    }
}

extension View {
    /// Gives a control the system pointer `effect` in `shape`, which must equal the control's visible shape: the same
    /// corner radius, and `.continuous` where the visible clip is continuous. The default hover shape is a rectangle,
    /// which looks wrong on any rounded view.
    ///
    /// The effect turns itself off while the control is disabled, because the helper reads `isEnabled` from the
    /// environment. Apply it before any `.disabled(_:)` written on the same control, so the read sees that state.
    /// A dimmed or locked control that still opens something is not disabled and keeps its hover.
    ///
    /// Apply it to a `.plain`, `.unhighlighted` or custom-styled control, directly after its button style. For a
    /// system-styled control, whose own hover is already drawn, use ``hoverShape(_:)`` instead: a second effect on the
    /// same view would stack on the system's.
    public func interactiveHover(_ effect: InteractiveHoverEffect, in shape: some Shape) -> some View {
        modifier(InteractiveHoverModifier(effect: effect, shape: shape))
    }

    /// Sets only the shape of the system's own hover on a system-styled control, such as an interactive glass button,
    /// whose own effect has the wrong shape.
    ///
    /// It never adds an effect: the control keeps the system's single response and only its outline changes. It
    /// exists so that every hover shape in the app goes through this one vocabulary instead of a hand-written
    /// `contentShape(.hoverEffect, …)` at each site.
    public func hoverShape(_ shape: some Shape) -> some View {
        contentShape(.hoverEffect, shape)
    }

    /// Gives an icon-only button the system highlight in a ``HoverTargetCircle``, with `edges` cut at the view's own
    /// bounds where the enlarged circle would reach a neighbouring control.
    ///
    /// The same circle is the tap area (`.interaction`) and the hover area at once, so the two can never drift. Only
    /// this helper sets that tap shape; no call site writes it by hand. The view's frame does not change: the circle
    /// grows the hit region, not the layout.
    public func interactiveIconHover(clippedAt edges: Edge.Set = []) -> some View {
        contentShape(.interaction, HoverTargetCircle(clippedAt: edges))
            .interactiveHover(.highlight, in: HoverTargetCircle(clippedAt: edges))
    }
}

private struct InteractiveHoverModifier<HoverShape: Shape>: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let effect: InteractiveHoverEffect
    let shape: HoverShape

    func body(content: Content) -> some View {
        content
            .contentShape(.hoverEffect, shape)
            .hoverEffect(effect.hoverEffect)
            .hoverEffectDisabled(!isEnabled)
    }
}

/// The hover and tap circle of an icon-only button: centred on the view, with a diameter of the larger of 44 pt and
/// the view's longer side.
///
/// 44 pt is the minimum comfortable pointer and touch target, so a small glyph still gets a full circle. A view
/// longer than 44 pt keeps its own length as the diameter, so the circle never falls inside the view it belongs to.
///
/// Where the enlarged circle would reach a neighbouring control, `clippedAt` cuts it with a straight line at the
/// view's own bounds on that side: the circle never takes a neighbour's tap or hover. A clipped side keeps the
/// view's own edge, and the opposite side still reaches the circle, so clipping both sides keeps the view's width and
/// the circle's full height. The geometry is written left to right, `.leading` is the minimum x, and the shape
/// mirrors for a right-to-left layout so `.leading` stays the reading-order side.
public struct HoverTargetCircle: Shape {
    /// The smallest circle diameter, in points.
    public static let minimumDiameter: CGFloat = 44

    /// The edges where the circle stops at the view's bounds.
    public let clippedEdges: Edge.Set

    public init(clippedAt edges: Edge.Set = []) {
        clippedEdges = edges
    }

    public var layoutDirectionBehavior: LayoutDirectionBehavior {
        .mirrors
    }

    public func path(in rect: CGRect) -> Path {
        let diameter = max(Self.minimumDiameter, rect.width, rect.height)
        let circleBounds = CGRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        let circle = Circle().path(in: circleBounds)
        guard !clippedEdges.isEmpty else { return circle }
        let minX = clippedEdges.contains(.leading) ? rect.minX : circleBounds.minX
        let maxX = clippedEdges.contains(.trailing) ? rect.maxX : circleBounds.maxX
        let minY = clippedEdges.contains(.top) ? rect.minY : circleBounds.minY
        let maxY = clippedEdges.contains(.bottom) ? rect.maxY : circleBounds.maxY
        let clip = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return circle.intersection(Path(clip))
    }
}

/// The hover shape of a text button: an 8 pt continuous rounded rect around the text, grown by 6 pt on every side.
///
/// A text button has no background of its own, so the highlight needs a shape that stands clear of the glyphs. The
/// size lives in this one type so the app's text buttons cannot drift apart.
public struct HoverTextButtonShape: Shape {
    /// The corner radius of the highlight, in points.
    public static let cornerRadius: CGFloat = 8
    /// How far the highlight stands clear of the text on every side, in points.
    public static let outset: CGFloat = 6

    public init() {}

    public func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .path(in: rect.insetBy(dx: -Self.outset, dy: -Self.outset))
    }
}

/// The hover capsule of a control that shows an icon and a label: the content's rect grown by `horizontalOutset` and
/// `verticalOutset` on every side, with fully rounded ends.
///
/// With an outset of 8 pt on every side the capsule stands 8 pt clear of the content, including past its rounded
/// ends, where a capsule of the content's own rect would cut the corners of the glyphs. The two outsets differ when
/// the rounded ends need more room than the top and bottom do.
public struct HoverCapsule: Shape {
    public let horizontalOutset: CGFloat
    public let verticalOutset: CGFloat

    public init(horizontalOutset: CGFloat, verticalOutset: CGFloat) {
        self.horizontalOutset = horizontalOutset
        self.verticalOutset = verticalOutset
    }

    public func path(in rect: CGRect) -> Path {
        Capsule(style: .continuous).path(in: rect.insetBy(dx: -horizontalOutset, dy: -verticalOutset))
    }
}

/// Which row shape a ``View/cellRowHover(_:)`` highlight takes.
public enum CellHoverFill: Sendable {
    /// A row of an inset card list (`Form`, `List`, `.insetGrouped`): the highlight stands 8 pt inside the cell's left
    /// and right edges and 3 pt inside its top and bottom edges, with rounded corners.
    case cardRow
    /// A card row while its list shows the delete control before and the reorder control after the content: the
    /// highlight stands 8 pt inside the content view's leading and trailing edges and 3 pt inside its top and bottom
    /// edges.
    case cardRowEditing
    /// A row of a sidebar list: the highlight covers the whole cell, in the corner radius of the system's own
    /// selection.
    case sidebarSelection

    /// How far the row's view grows past its content on each side, so that its highlight reaches the place inside the
    /// cell the case describes.
    ///
    /// Each value is a measured content margin minus the gap the highlight keeps from the cell edge: 20 - 8 and
    /// 15 - 3 for a card row, 16 - 8 and 8 - 8 for the editing leading and trailing sides, 16 and 11 for a sidebar
    /// row. The margins were measured on iOS 27 in the iPhone Air and iPad Pro 11-inch (M5) simulators at the
    /// extra-small, large and accessibility-5 content sizes, from the edge of the cell's content view to the edge of
    /// a row's content, in points:
    ///
    /// | Quantity | Value | Where measured |
    /// | --- | --- | --- |
    /// | Card rows, leading and trailing | 20 | iPhone portrait, iPad landscape window |
    /// | Card rows, top and bottom, a row taller than the minimum | 15 | iPhone portrait, iPad landscape window |
    /// | Editing rows, leading, after the delete control | 16 | iPhone portrait, iPad landscape window |
    /// | Editing rows, trailing, before the reorder control | 8 | iPhone portrait, iPad landscape window |
    /// | iPad sidebar rows, leading and trailing | 16 | iPad landscape window |
    /// | iPad sidebar rows, top and bottom, a row taller than the minimum | 11 | iPad landscape window |
    /// | Selected iPad sidebar row, corner radius; background insets | 26; 0 on every side | iPad landscape window |
    ///
    /// The row height follows the content size (49, 52 and 59 pt at the three sizes) and is published as
    /// `defaultMinListRowHeight`, which ``View/cellRowHover(_:)`` reads.
    ///
    /// Why a row grows and shrinks instead of clearing the list's row insets and padding its content by these
    /// margins: the card margin is not the same in every window. With the insets cleared and the content padded by 20
    /// and 15, the content sat 4 pt further inward on both sides than a row without the helper (label at x=104
    /// against 100) on the iPhone Air in landscape, in the `settings-pages-reading` and `reader-settings-sheet`
    /// snapshots at the large size, and in the iPad settings sheet (x=163 against 159). The side margin in those
    /// windows is read off the pictures as 16 pt; what the system derives it from is not established. Growing the
    /// row's own view and taking the growth back leaves the layout size at the content's own size in every window,
    /// and the list's row insets are not touched. With the 16 pt side margin the highlight still lies inside the
    /// cell.
    var growth: EdgeInsets {
        switch self {
        case .cardRow:
            EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        case .cardRowEditing:
            EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0)
        case .sidebarSelection:
            EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16)
        }
    }

    /// The growth taken back, so that the row's layout size is its content's own.
    var shrink: EdgeInsets {
        EdgeInsets(top: -growth.top, leading: -growth.leading, bottom: -growth.bottom, trailing: -growth.trailing)
    }

    /// How far the highlight stands inside the cell's top and bottom edges, in points.
    var verticalGap: CGFloat {
        switch self {
        case .cardRow, .cardRowEditing: 3
        case .sidebarSelection: 0
        }
    }

    /// The corner radius of the highlight, in points.
    var cornerRadius: CGFloat {
        switch self {
        case .cardRow, .cardRowEditing: 10
        case .sidebarSelection: 26
        }
    }
}

/// The hover shape of a list row: the view's whole rect, which ``View/cellRowHover(_:)`` has grown past the row's
/// content.
public struct CellHoverShape: Shape {
    public let fill: CellHoverFill

    public init(fill: CellHoverFill) {
        self.fill = fill
    }

    public func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: fill.cornerRadius, style: .continuous).path(in: rect)
    }
}

extension View {
    /// Fills a list row with the system pointer highlight, in the row's own shape, while leaving the content exactly
    /// where the list had put it.
    ///
    /// The system draws no pointer highlight on a plain row on iPadOS. The row's view grows by a fixed amount, carries
    /// the hover, and takes the same amount back with negative padding, so its layout size is its content's own. Apply
    /// it to the row's root view, before any `.disabled(_:)` written on the same control, so a disabled row stays flat.
    public func cellRowHover(_ fill: CellHoverFill = .cardRow) -> some View {
        modifier(CellRowHoverModifier(fill: fill))
    }
}

private struct CellRowHoverModifier: ViewModifier {
    /// The system's row height at the current content size. The highlight stands `verticalGap` inside the cell at the
    /// top and the bottom, so the grown view needs that much less to span a row that is shorter than one line.
    @Environment(\.defaultMinListRowHeight) private var minimumRowHeight

    let fill: CellHoverFill

    func body(content: Content) -> some View {
        content
            .padding(fill.growth)
            .frame(
                maxWidth: .infinity, minHeight: max(0, minimumRowHeight - 2 * fill.verticalGap), alignment: .leading
            )
            .contentShape(.rect)
            .interactiveHover(.highlight, in: CellHoverShape(fill: fill))
            .padding(fill.shrink)
    }
}

/// The hover shape of a switch: its track, grown by 6 pt on every side.
///
/// The track is a fixed 61 x 28 pt at the trailing edge, centred vertically (measured on iOS 27: the intrinsic size
/// of a `UISwitch`). Tapping a switch's label does not flip it, so the highlight covers the track only and the label
/// stays flat.
public struct SwitchTrackHoverShape: Shape {
    /// The track's width, in points.
    public static let trackWidth: CGFloat = 61
    /// The track's height, in points.
    public static let trackHeight: CGFloat = 28
    /// How far the highlight stands clear of the track on every side, in points.
    public static let outset: CGFloat = 6

    public init() {}

    public var layoutDirectionBehavior: LayoutDirectionBehavior {
        .mirrors
    }

    public func path(in rect: CGRect) -> Path {
        let track = CGRect(
            x: rect.maxX - Self.trackWidth, y: rect.midY - Self.trackHeight / 2,
            width: Self.trackWidth, height: Self.trackHeight
        )
        return Capsule(style: .continuous).path(in: track.insetBy(dx: -Self.outset, dy: -Self.outset))
    }
}
