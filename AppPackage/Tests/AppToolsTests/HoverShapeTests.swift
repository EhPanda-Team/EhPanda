@testable import AppTools
import SwiftUI
import Testing

/// Pins the geometry of the hover shapes the interactive-hover helpers draw: the 44 pt minimum of the icon circle,
/// the longer side winning, each clipped edge stopping at the view's bounds, and the capsule's outsets.
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

    @Test func clippedLeadingEdgeStopsAtTheViewsMinX() {
        let bounds = HoverTargetCircle(clippedAt: .leading).path(in: Self.square).boundingRect
        #expect(abs(bounds.minX - 0) < Self.tolerance)
        #expect(abs(bounds.maxX - 32) < Self.tolerance)
    }

    @Test func clippedTrailingEdgeStopsAtTheViewsMaxX() {
        let bounds = HoverTargetCircle(clippedAt: .trailing).path(in: Self.square).boundingRect
        #expect(abs(bounds.maxX - 20) < Self.tolerance)
        #expect(abs(bounds.minX - -12) < Self.tolerance)
    }

    @Test func clippedTopEdgeStopsAtTheViewsMinY() {
        let bounds = HoverTargetCircle(clippedAt: .top).path(in: Self.square).boundingRect
        #expect(abs(bounds.minY - 0) < Self.tolerance)
        #expect(abs(bounds.maxY - 32) < Self.tolerance)
    }

    @Test func clippedBottomEdgeStopsAtTheViewsMaxY() {
        let bounds = HoverTargetCircle(clippedAt: .bottom).path(in: Self.square).boundingRect
        #expect(abs(bounds.maxY - 20) < Self.tolerance)
        #expect(abs(bounds.minY - -12) < Self.tolerance)
    }

    @Test func clippingBothSidesKeepsTheViewsWidthAndTheCirclesFullHeight() {
        let bounds = HoverTargetCircle(clippedAt: [.leading, .trailing]).path(in: Self.square).boundingRect
        #expect(abs(bounds.width - 20) < Self.tolerance)
        #expect(abs(bounds.height - 44) < Self.tolerance)
    }

    @Test func noPointLiesBeyondAClippedEdge() {
        let beyondLeading = CGPoint(x: -0.5, y: 10)
        #expect(HoverTargetCircle().path(in: Self.square).contains(beyondLeading))
        #expect(!HoverTargetCircle(clippedAt: .leading).path(in: Self.square).contains(beyondLeading))
        let beyondTrailing = CGPoint(x: 20.5, y: 10)
        #expect(HoverTargetCircle().path(in: Self.square).contains(beyondTrailing))
        #expect(!HoverTargetCircle(clippedAt: .trailing).path(in: Self.square).contains(beyondTrailing))
    }

    @Test func circleMirrorsForARightToLeftLayout() {
        guard case .mirrors(in: .rightToLeft) = HoverTargetCircle().layoutDirectionBehavior else {
            Issue.record("HoverTargetCircle must mirror in a right-to-left layout")
            return
        }
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

    private func expectEqual(_ actual: CGRect, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(actual.minX - expected.minX) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.minY - expected.minY) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.width - expected.width) < Self.tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.height - expected.height) < Self.tolerance, sourceLocation: sourceLocation)
    }
}
