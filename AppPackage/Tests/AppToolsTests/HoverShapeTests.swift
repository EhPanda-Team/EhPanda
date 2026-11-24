@testable import AppTools
import SwiftUI
import Testing

/// Pins the geometry of the hover shapes the interactive-hover helpers draw: the 44 pt minimum of the icon circle,
/// the longer side winning, and the capsule's outsets.
@Suite struct HoverShapeTests {
    private static let tolerance: CGFloat = 0.001
    private static let square = CGRect(x: 0, y: 0, width: 20, height: 20)

    @Test func circleOfASmallViewHasTheMinimumDiameterCentredOnIt() {
        let bounds = HoverTargetCircle().path(in: Self.square).boundingRect
        expectEqual(bounds, CGRect(x: -12, y: -12, width: 44, height: 44))
    }

    @Test func circleOfALongViewTakesTheLongerSide() {
        let bounds = HoverTargetCircle().path(in: CGRect(x: 0, y: 0, width: 60, height: 30)).boundingRect
        expectEqual(bounds, CGRect(x: 0, y: -15, width: 60, height: 60))
    }

    @Test func capsuleGrowsItsRectByTheOutsets() {
        let capsule = HoverCapsule(horizontalOutset: 11, verticalOutset: 8)
        let bounds = capsule.path(in: CGRect(x: 0, y: 0, width: 100, height: 20)).boundingRect
        expectEqual(bounds, CGRect(x: -11, y: -8, width: 122, height: 36))
    }

    @Test func textButtonShapeGrowsItsRectBySixOnEverySide() {
        let bounds = HoverTextButtonShape().path(in: CGRect(x: 0, y: 0, width: 40, height: 20)).boundingRect
        expectEqual(bounds, CGRect(x: -6, y: -6, width: 52, height: 32))
    }

    @Test func textButtonShapeMatchesAContinuousRoundedRectOfRadiusEight() {
        let grown = CGRect(x: -6, y: -6, width: 52, height: 32)
        let expected = RoundedRectangle(cornerRadius: 8, style: .continuous).path(in: grown)
        let actual = HoverTextButtonShape().path(in: CGRect(x: 0, y: 0, width: 40, height: 20))
        expectEqual(actual.boundingRect, expected.boundingRect)
        for point in [CGPoint(x: -5.5, y: -5.5), CGPoint(x: 20, y: 10)] {
            #expect(actual.contains(point) == expected.contains(point))
        }
    }

    @Test func rowHighlightIsTheViewsWholeRectForEveryFill() {
        let row = CGRect(x: 0, y: 0, width: 300, height: 52)
        for fill in [CellHoverFill.cardRow, .cardRowEditing, .sidebarSelection] {
            expectEqual(CellHoverShape(fill: fill).path(in: row).boundingRect, row)
        }
    }

    @Test func cardAndEditingRowsHaveContinuousCornersOfRadiusTen() {
        let row = CGRect(x: 0, y: 0, width: 300, height: 52)
        let reference = RoundedRectangle(cornerRadius: 10, style: .continuous).path(in: row)
        for fill in [CellHoverFill.cardRow, .cardRowEditing] {
            let path = CellHoverShape(fill: fill).path(in: row)
            for point in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 5, y: 26), CGPoint(x: 150, y: 0.5)] {
                #expect(path.contains(point) == reference.contains(point))
            }
        }
        #expect(!CellHoverShape(fill: .cardRow).path(in: row).contains(CGPoint(x: 0.5, y: 0.5)))
        #expect(CellHoverShape(fill: .cardRow).path(in: row).contains(CGPoint(x: 5, y: 26)))
    }

    @Test func sidebarSelectionHasContinuousCornersOfRadiusTwentySix() {
        let row = CGRect(x: 0, y: 0, width: 300, height: 52)
        let reference = RoundedRectangle(cornerRadius: 26, style: .continuous).path(in: row)
        let path = CellHoverShape(fill: .sidebarSelection).path(in: row)
        for point in [CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 26), CGPoint(x: 8, y: 8), CGPoint(x: 150, y: 26)] {
            #expect(path.contains(point) == reference.contains(point))
        }
        #expect(!path.contains(CGPoint(x: 1, y: 1)))
    }

    @Test func growthPlusTheHighlightGapIsTheMeasuredMargin() {
        // Card rows: margin 20 side, 15 top and bottom; the highlight keeps 8 and 3 from the cell edge.
        let card = CellHoverFill.cardRow
        #expect(card.growth == EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        #expect(20 - card.growth.leading == 8)
        #expect(15 - card.growth.top == card.verticalGap)
        // Editing rows: margin 16 leading and 8 trailing; the highlight keeps 8 from each content view edge.
        let editing = CellHoverFill.cardRowEditing
        #expect(editing.growth == EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 0))
        #expect(16 - editing.growth.leading == 8)
        #expect(8 - editing.growth.trailing == 8)
        // Sidebar rows: margin 16 side and 11 top and bottom; the highlight is the whole cell.
        let sidebar = CellHoverFill.sidebarSelection
        #expect(sidebar.growth == EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
        #expect(sidebar.verticalGap == 0)
    }

    @Test func shrinkIsTheNegatedGrowth() {
        for fill in [CellHoverFill.cardRow, .cardRowEditing, .sidebarSelection] {
            #expect(fill.shrink.top == -fill.growth.top)
            #expect(fill.shrink.leading == -fill.growth.leading)
            #expect(fill.shrink.bottom == -fill.growth.bottom)
            #expect(fill.shrink.trailing == -fill.growth.trailing)
        }
    }

    @Test func switchTrackHighlightGrowsTheDrawnTrackBySix() {
        let row = CGRect(x: 0, y: 0, width: 300, height: 44)
        let path = SwitchTrackHoverShape().path(in: row)
        // The drawn track is the measured 63 x 28 pt, from 61 pt before the frame's trailing edge to 2 pt past it,
        // centred vertically.
        expectEqual(path.boundingRect, CGRect(x: 300 - 61 - 6, y: 22 - 14 - 6, width: 63 + 12, height: 28 + 12))
        #expect(!path.contains(CGPoint(x: 10, y: 22)))
        #expect(path.contains(CGPoint(x: 300 - 61 + 63 / 2, y: 22)))
    }

    @Test func switchTrackHighlightMirrorsForARightToLeftLayout() {
        guard case .mirrors(in: .rightToLeft) = SwitchTrackHoverShape().layoutDirectionBehavior else {
            Issue.record("SwitchTrackHoverShape must mirror in a right-to-left layout")
            return
        }
    }

    @Test func sliderHighlightIsACapsuleSixPointsClearOfTheFrame() {
        let slider = CGRect(x: 20, y: 10, width: 300, height: 31)

        let path = SliderHoverShape().path(in: slider)

        expectEqual(path.boundingRect, slider.insetBy(dx: -6, dy: -6))
        #expect(path.contains(CGPoint(x: slider.minX - 6 + 1, y: slider.midY)))
        // Fully rounded ends: the corner of the grown rect lies outside the capsule.
        #expect(!path.contains(CGPoint(x: slider.minX - 5, y: slider.minY - 5)))
    }

    private func expectEqual(_ actual: CGRect, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(actual.minX - expected.minX) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.minY - expected.minY) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.width - expected.width) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.height - expected.height) < Self.tolerance, sourceLocation: sourceLocation)
    }
}
