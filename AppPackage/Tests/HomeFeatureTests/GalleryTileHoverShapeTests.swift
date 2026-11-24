import AppComponents
import SwiftUI
import Testing

/// Pins the hover background of a gallery tile: the tile's rect grown by the outset, with the cover's corners grown by
/// the same amount so the two stay concentric.
@Suite struct GalleryTileHoverShapeTests {
    private static let tolerance: CGFloat = 0.001
    private static let tile = CGRect(x: 10, y: 20, width: 120, height: 220)

    @Test(arguments: [CGFloat(3), 6])
    func backgroundGrowsTheTileByTheOutsetOnEverySide(outset: CGFloat) {
        let bounds = GalleryTileHoverShape(outset: outset).path(in: Self.tile).boundingRect
        let expected = Self.tile.insetBy(dx: -outset, dy: -outset)

        #expect(abs(bounds.minX - expected.minX) < Self.tolerance)
        #expect(abs(bounds.minY - expected.minY) < Self.tolerance)
        #expect(abs(bounds.width - expected.width) < Self.tolerance)
        #expect(abs(bounds.height - expected.height) < Self.tolerance)
    }

    @Test(arguments: [CGFloat(3), 6])
    func cornersAreTheCoversRadiusPlusTheOutset(outset: CGFloat) {
        let grown = Self.tile.insetBy(dx: -outset, dy: -outset)
        let radius = GalleryCover.cornerRadius + outset
        let reference = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: grown)

        let path = GalleryTileHoverShape(outset: outset).path(in: Self.tile)

        let probes = [
            CGPoint(x: grown.minX + 0.5, y: grown.minY + 0.5),
            CGPoint(x: grown.minX + radius * 0.3, y: grown.minY + radius * 0.3),
            CGPoint(x: grown.maxX - 1, y: grown.maxY - 1),
            CGPoint(x: grown.midX, y: grown.minY + 0.5)
        ]
        for point in probes {
            #expect(path.contains(point) == reference.contains(point))
        }
        #expect(!path.contains(CGPoint(x: grown.minX + 0.5, y: grown.minY + 0.5)))
    }

    @Test func coverRadiusIsFive() {
        #expect(GalleryCover.cornerRadius == 5)
    }
}
