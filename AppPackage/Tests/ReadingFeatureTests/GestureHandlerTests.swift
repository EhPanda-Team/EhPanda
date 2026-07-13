import SwiftUI
import Testing
import AppModels
@testable import ReadingFeature

// Wave-0 baseline lock for the reader gesture arithmetic before Plan 05-09 replaces the gesture
// sources. These cases freeze the container-relative clamp, anchor, and tap-zone calculations so
// the source swap cannot introduce coordinate drift.
@MainActor
@Suite
struct GestureHandlerTests {
    private enum TapOutcome: Equatable {
        case pageOffset(Int)
        case panel
    }

    private struct TapZone {
        let fraction: Double
        let leftToRight: TapOutcome
        let rightToLeft: TapOutcome
    }

    private let containerSizes = [
        CGSize(width: 390, height: 844),
        CGSize(width: 844, height: 390),
        CGSize(width: 834, height: 1_194),
        CGSize(width: 1_194, height: 834)
    ]

    @Test
    func panClampUsesContainerSizeAndScaleAnchor() {
        for containerSize in containerSizes {
            for scale in [1.0, 2.0, 3.5] {
                let handler = GestureHandler()
                handler.containerSize = containerSize
                handler.scale = scale
                handler.scaleAnchor = UnitPoint(x: 0.25, y: 0.75)

                let width = Double(containerSize.width)
                let height = Double(containerSize.height)
                let anchorX = Double(handler.scaleAnchor.x)
                let anchorY = Double(handler.scaleAnchor.y)
                let widthMargin = width * (scale - 1) / 2
                let leadingMargin = anchorX / 0.5 * widthMargin
                let trailingMargin = (1 - anchorX) / 0.5 * widthMargin
                let horizontalOverflow = width * scale * 10
                #expect(handler.edgeWidth(xAxis: horizontalOverflow) == leadingMargin)
                #expect(handler.edgeWidth(xAxis: -horizontalOverflow) == -trailingMargin)
                #expect(handler.edgeWidth(xAxis: leadingMargin / 2) == leadingMargin / 2)

                let heightMargin = height * (scale - 1) / 2
                let topMargin = anchorY / 0.5 * heightMargin
                let bottomMargin = (1 - anchorY) / 0.5 * heightMargin
                let verticalOverflow = height * scale * 10
                #expect(handler.edgeHeight(yAxis: verticalOverflow) == topMargin)
                #expect(handler.edgeHeight(yAxis: -verticalOverflow) == -bottomMargin)
                #expect(handler.edgeHeight(yAxis: topMargin / 2) == topMargin / 2)
            }
        }
    }

    @Test
    func scaleAnchorMatchesNormalizedMagnifyStartAnchor() {
        for containerSize in containerSizes {
            let handler = GestureHandler()
            handler.containerSize = containerSize
            let points = [
                CGPoint(x: -containerSize.width, y: -containerSize.height),
                CGPoint(x: containerSize.width * 0.25, y: containerSize.height * 0.75),
                CGPoint(x: containerSize.width * 2, y: containerSize.height * 2)
            ]

            for point in points {
                handler.correctScaleAnchor(point: point)
                let normalizedX = min(1, max(0, point.x / containerSize.width))
                let normalizedY = min(1, max(0, point.y / containerSize.height))
                let magnifyStartAnchor = UnitPoint(x: normalizedX, y: normalizedY)
                #expect(handler.scaleAnchor == magnifyStartAnchor)
            }
        }
    }

    @Test
    func horizontalTapZonesRespectReadingDirection() {
        for containerSize in containerSizes {
            let handler = GestureHandler()
            handler.containerSize = containerSize
            let zones = [
                TapZone(fraction: 0.1, leftToRight: .pageOffset(-1), rightToLeft: .pageOffset(1)),
                TapZone(fraction: 0.5, leftToRight: .panel, rightToLeft: .panel),
                TapZone(fraction: 0.9, leftToRight: .pageOffset(1), rightToLeft: .pageOffset(-1))
            ]

            for zone in zones {
                let location = CGPoint(x: containerSize.width * zone.fraction, y: containerSize.height / 2)
                #expect(
                    tapOutcome(handler: handler, location: location, readingDirection: .leftToRight)
                        == zone.leftToRight
                )
                #expect(
                    tapOutcome(handler: handler, location: location, readingDirection: .rightToLeft)
                        == zone.rightToLeft
                )
            }
        }
    }

    @Test
    func verticalTapTogglesPanel() {
        let handler = GestureHandler()
        handler.containerSize = containerSizes[0]
        #expect(
            tapOutcome(handler: handler, location: .zero, readingDirection: .vertical) == .panel
        )
    }

    private func tapOutcome(
        handler: GestureHandler,
        location: CGPoint,
        readingDirection: ReadingDirection
    ) -> TapOutcome? {
        var outcome: TapOutcome?
        handler.onSingleTapGestureEnded(
            location: location,
            readingDirection: readingDirection,
            setPageIndexOffsetAction: { outcome = .pageOffset($0) },
            toggleShowsPanelAction: { outcome = .panel }
        )
        return outcome
    }
}
