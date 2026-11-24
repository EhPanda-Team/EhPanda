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
    /// Apply it directly after the control's button style, whatever that style is. On iPadOS 27.2 the system draws a
    /// pointer effect only for toolbar items and tab bar tabs: a default, `.borderless`, `.plain` or glass Button, a
    /// `Menu`, a `Link`, a `Slider`, a row's Button and interactive glass draw none of their own (measured under Device
    /// Hub's pointer, 2026-11-24), so every other control gets its single effect here. On a `Menu` it goes on the Menu
    /// itself: written on the Menu's label, it draws nothing either. Never add one to a toolbar item or a
    /// tab, which would stack a second effect on the system's.
    public func interactiveHover(_ effect: InteractiveHoverEffect, in shape: some Shape) -> some View {
        modifier(InteractiveHoverModifier(effect: effect, shape: shape))
    }

    /// Gives an icon-only button the system highlight in a ``HoverTargetCircle``.
    ///
    /// The same circle is the tap area (`.interaction`) and the hover area at once, so the two can never drift. Only
    /// this helper sets that tap shape; no call site writes it by hand. The view's frame does not change: the circle
    /// grows the hit region, not the layout. The circle is sized by the view it is applied to, so apply it to the
    /// control's own view (the glyph), never to a flexible cell around it.
    public func interactiveIconHover() -> some View {
        contentShape(.interaction, HoverTargetCircle())
            .interactiveHover(.highlight, in: HoverTargetCircle())
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
/// The circle is symmetric, so it needs no mirroring for a right-to-left layout.
public struct HoverTargetCircle: Shape {
    /// The smallest circle diameter, in points.
    public static let minimumDiameter: CGFloat = 44

    public init() {}

    public func path(in rect: CGRect) -> Path {
        let diameter = max(Self.minimumDiameter, rect.width, rect.height)
        return Circle().path(in: CGRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        ))
    }
}

/// The hover shape of content with no background of its own that is more than one short label: an 8 pt continuous
/// rounded rect around it, grown by 6 pt on every side.
///
/// A search keyword row or a gallery title that wraps over several lines draws nothing behind its content, so the
/// highlight needs a shape that stands clear of the glyphs and images; a capsule around a block of lines would cut
/// across their corners. A single-line text button takes ``HoverTextCapsule`` instead. The size lives in this one type
/// so these controls cannot drift apart.
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

/// The hover shape of a short text button, one label on one line (Show All, Remove All, Find Similar, a link): a
/// capsule around the text, grown by 10 pt at the sides and 6 pt above and below (owner, 2026-11-24).
///
/// The ends need more room than the top and bottom: a capsule 6 pt clear of the text on every side would pass about
/// 2 pt from the first and last glyphs' corners, while 10 pt at the sides keeps those corners about 4 pt inside the
/// round ends. A label that wraps keeps the capsule, whose ends then grow with it. Rows and multi-line content keep
/// ``HoverTextButtonShape``.
public struct HoverTextCapsule: Shape {
    /// How far the capsule reaches past the text at each side, in points.
    public static let horizontalOutset: CGFloat = 10
    /// How far the capsule reaches above and below the text, in points.
    public static let verticalOutset: CGFloat = 6

    public init() {}

    public func path(in rect: CGRect) -> Path {
        HoverCapsule(horizontalOutset: Self.horizontalOutset, verticalOutset: Self.verticalOutset).path(in: rect)
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
    /// and right edges and 6 pt inside its top and bottom edges, with 20 pt corners.
    case cardRow
    /// A card row while its list shows the delete control before and the reorder control after the content: the
    /// highlight stands 8 pt inside the content view's leading and trailing edges and 6 pt inside its top and bottom
    /// edges, with 20 pt corners.
    case cardRowEditing
    /// A row of a sidebar list: the highlight covers the whole cell, in the corner radius of the system's own
    /// selection.
    case sidebarSelection

    /// How far the row's view grows past its content on each side, so that its highlight reaches the place inside the
    /// cell the case describes.
    ///
    /// Each value is a measured content margin minus the gap the highlight keeps from the cell edge: 20 - 8 and
    /// 15 - 6 for a card row, 16 - 8 and 8 - 8 for the editing leading and trailing sides, 16 and 11 for a sidebar
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
            EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        case .cardRowEditing:
            EdgeInsets(top: 9, leading: 8, bottom: 9, trailing: 0)
        case .sidebarSelection:
            EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16)
        }
    }

    /// The growth taken back, so that the row's layout size is its content's own.
    var shrink: EdgeInsets {
        EdgeInsets(top: -growth.top, leading: -growth.leading, bottom: -growth.bottom, trailing: -growth.trailing)
    }

    /// How far the highlight stands inside the cell's top and bottom edges, in points.
    ///
    /// For a card row it is 6 pt, against 8 pt at the sides, because the system's highlight scales the row up by a
    /// share of its size, which on a wide, short row takes about 3 pt from the sides and under 1 pt from the top and
    /// bottom: hovered, the gap reads about 5 pt on every side (a Downloads row on the iPad, 2026-11-24). The even gap
    /// is what lets ``shape``'s corners sit concentric with the card's.
    var verticalGap: CGFloat {
        switch self {
        case .cardRow, .cardRowEditing: 6
        case .sidebarSelection: 0
        }
    }

    /// The hover shape: the whole grown view, with continuous corners of ``cornerRadius``.
    var shape: RoundedRectangle {
        .rect(cornerRadius: cornerRadius, style: .continuous)
    }

    /// The corner radius of the highlight, in points.
    ///
    /// A card row takes 20 pt on all four corners: the card's own corners are 26 pt (traced from the pixels of an
    /// iPad Downloads card, 2026-11-24), so a highlight about 5 pt inside one is concentric with it at 20 to 21 pt. A
    /// smaller radius showed two different curves side by side (owner, 2026-11-24: "double corner radius"). The owner
    /// chose the same 20 pt on the corners that meet a separator rather than the card, so a one-line row reads as a
    /// capsule, like a sidebar selection (2026-11-24). `ConcentricRectangle`, which takes its radii from the cell's
    /// card, is not used: on iOS 27.2 the highlight it draws on a section's second row sits about 6 pt up and to the
    /// left, over the separator and the card's leading edge (General settings, App Activity Logs, 2026-11-24).
    ///
    /// A sidebar row takes 26 pt, the system's own selection shape.
    var cornerRadius: CGFloat {
        switch self {
        case .cardRow, .cardRowEditing: 20
        case .sidebarSelection: 26
        }
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
            .interactiveHover(.highlight, in: fill.shape)
            .padding(fill.shrink)
    }
}

/// The hover shape of a switch: its track, grown by 6 pt on every side.
///
/// Measured on iOS 27.2 (iPad Pro 11-inch (M5) simulator, General settings, 2026-11-24): the drawn track is 63 x 28
/// pt, centred vertically, and runs from 61 pt before the Toggle's trailing edge to 2 pt past it (the pixels give the
/// track; the old 61 pt shape, ending at the trailing edge, cleared it by 6 pt before and 4.5 pt after). The shape
/// follows the drawn track, so the highlight stands 6 pt clear of it on both sides.
///
/// It goes on the whole Toggle, as the reference project's toggle style does (owner decision, 2026-11-24): the
/// system's highlight then also scales the label by about 1 pt while the track is hovered, which is accepted. Every
/// way to keep the label still rebuilt the Form's switch row and changed its height at rest.
public struct SwitchTrackHoverShape: Shape {
    /// How far before the Toggle's trailing edge the track starts, in points.
    public static let trackStart: CGFloat = 61
    /// The drawn track's width, in points.
    public static let trackWidth: CGFloat = 63
    /// The drawn track's height, in points.
    public static let trackHeight: CGFloat = 28
    /// How far the highlight stands clear of the track on every side, in points.
    public static let outset: CGFloat = 6

    public init() {}

    public var layoutDirectionBehavior: LayoutDirectionBehavior {
        .mirrors
    }

    public func path(in rect: CGRect) -> Path {
        let track = CGRect(
            x: rect.maxX - Self.trackStart, y: rect.midY - Self.trackHeight / 2,
            width: Self.trackWidth, height: Self.trackHeight
        )
        return Capsule(style: .continuous).path(in: track.insetBy(dx: -Self.outset, dy: -Self.outset))
    }
}

/// The hover shape of a `Slider`: the slider's own frame, grown by 6 pt on every side, with fully rounded ends.
///
/// A slider draws no pointer effect of its own on iPadOS 27.2 (Appearance's Privacy Mask and the reader's page
/// slider, Device Hub's pointer, 2026-11-24), so it takes the highlight like any flat system control. Measured on the
/// Privacy Mask slider: the drawn track spans the whole frame, 6 pt tall and centred, and the thumb, about 38 x 26
/// pt, reaches the frame's ends at the extreme values. Grown by the switch's 6 pt, the capsule stands clear of the
/// thumb at either end. A slider's end marks belong to the control, so the capsule takes them in: the value labels a
/// Slider carries inside it (the Reading and EhSetting rows), or the marks written beside it, where the helper goes
/// on their stack (Appearance's eyes, which the capsule ran into when it was on the Slider alone).
public struct SliderHoverShape: Shape {
    /// How far the highlight stands clear of the slider's frame on every side, in points.
    public static let outset: CGFloat = 6

    public init() {}

    public func path(in rect: CGRect) -> Path {
        Capsule(style: .continuous).path(in: rect.insetBy(dx: -Self.outset, dy: -Self.outset))
    }
}
