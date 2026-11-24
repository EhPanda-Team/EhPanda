public import SwiftUI

/// The hover shape of a gallery tile or row that has no background of its own and is led by its cover (a cover wall
/// tile, a Recently Viewed card, a ranking row): the view's rect grown by `outset`, with the cover's continuous
/// corners grown by the same amount.
///
/// Such a tile takes the system highlight, which draws a background behind it, instead of the lift, which only raises
/// what is already drawn (owner, 2026-11-24: "they need background on hover"). The cover sits at the tile's leading
/// top corner, so the background's corner radius is the cover's plus the outset: the two corners stay concentric
/// instead of showing two different radii.
public struct GalleryTileHoverShape: Shape {
    /// How far the background reaches past the tile on every side, in points.
    public let outset: CGFloat

    /// - Parameter outset: The room the tile's surroundings leave: 6 pt where tiles stand 20 pt apart or more, 3 pt in
    ///   the Recently Viewed row, whose cards stand 8 pt apart (owner, 2026-11-24).
    public init(outset: CGFloat) {
        self.outset = outset
    }

    public func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: GalleryCover.cornerRadius + outset, style: .continuous)
            .path(in: rect.insetBy(dx: -outset, dy: -outset))
    }
}
