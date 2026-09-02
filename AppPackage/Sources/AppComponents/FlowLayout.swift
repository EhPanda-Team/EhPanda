import SwiftUI

/// A layout that fills a line with as many subviews as it holds and wraps the rest onto the next
/// one, left to right, top to bottom.
///
/// Unlike an `HStack` — which keeps every subview on the one line it has and squeezes them until
/// they truncate — a flow measures each subview against the width actually offered and starts a
/// new line as soon as the next one would not fit. That is what makes it the right container for a
/// run of intrinsically sized members whose count is fixed but whose width grows with Dynamic
/// Type: tag chips, or a row of glyph-and-number pairs.
///
/// The two spacings are separate because a caller's horizontal rhythm and its vertical rhythm are
/// usually set by different neighbours — the gap between two members of a run on one side, the gap
/// between the stacked lines of the surrounding column on the other. `lineSpacing` defaults to
/// `spacing`, so a caller that wants one uniform gap still passes a single value.
public struct FlowLayout: Layout {
    private let spacing: Double
    private let lineSpacing: Double

    /// - Parameters:
    ///   - spacing: The gap between two subviews sharing a line.
    ///   - lineSpacing: The gap between two lines. Defaults to `spacing`.
    public init(spacing: Double, lineSpacing: Double? = nil) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let frames = frames(
            for: subviews,
            maxWidth: proposal.width ?? .infinity
        )
        let size = frames.reduce(CGSize.zero) { size, frame in
            CGSize(
                width: max(size.width, frame.maxX),
                height: max(size.height, frame.maxY)
            )
        }
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let frames = frames(for: subviews, maxWidth: bounds.width)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(for subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
        var frames = [CGRect]()
        var origin = CGPoint.zero
        var rowHeight = CGFloat.zero
        let maxWidth = maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude
        let spacing = CGFloat(spacing)
        let lineSpacing = CGFloat(lineSpacing)

        for subview in subviews {
            let size = fittingSize(for: subview, maxWidth: maxWidth)
            if origin.x > 0, origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += rowHeight + lineSpacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }

    /// A subview is measured at its ideal size, which is what lets the cloud break a row exactly
    /// where its chips end.
    ///
    /// A subview whose ideal width exceeds the whole row has no such ideal to honour: placed at it,
    /// it is drawn past the container's trailing edge and cut mid-glyph, with no ellipsis to say so.
    /// Re-measuring that one against the row's own width is what confines it — the chip then wraps
    /// inside its background, or ellipsises, according to the line limit it carries. Every subview
    /// that already fits is measured exactly as before, so this cannot move a chip that was placed
    /// correctly.
    private func fittingSize(for subview: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let idealSize = subview.sizeThatFits(.unspecified)
        guard maxWidth > 0, idealSize.width > maxWidth else { return idealSize }
        return subview.sizeThatFits(.init(width: maxWidth, height: nil))
    }
}
