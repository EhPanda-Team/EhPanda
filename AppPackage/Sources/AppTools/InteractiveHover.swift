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
