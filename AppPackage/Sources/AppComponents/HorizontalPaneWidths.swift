public import CoreGraphics

/// The system can reserve an entire side for vertical bars. Split the enclosing width before
/// removing each side's own inset so that the divider stays on the fold as the bars minimize.
public struct HorizontalPaneWidths: Equatable, Sendable {
    public let contentWidth: CGFloat
    public let leftInset: CGFloat
    public let rightInset: CGFloat

    public init(contentWidth: CGFloat, leftInset: CGFloat, rightInset: CGFloat) {
        self.contentWidth = contentWidth
        self.leftInset = leftInset
        self.rightInset = rightInset
    }

    public var right: CGFloat { contentWidth - left }

    public var left: CGFloat {
        min(contentWidth, max(0, (contentWidth + leftInset + rightInset) / 2 - leftInset))
    }
}
