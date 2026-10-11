import CoreGraphics

/// The pixel grid the reader draws its pages on.
enum PixelGrid {
    /// The pixel row an edge at `points` is drawn on, at `displayScale` pixels per point. An edge exactly half a pixel
    /// between two rows goes to the row below it, as the scroll view rounds its offset and the renderer rounds a page's
    /// position (measured 2026-10-10).
    static func row(of points: CGFloat, displayScale: CGFloat) -> CGFloat {
        (points * displayScale + 0.5).rounded(.down)
    }
}
