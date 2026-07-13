import SwiftUI
import AppModels
import Observation

@Observable
@MainActor
final class GestureHandler {
    var containerSize: CGSize = .zero
    var scaleAnchor: UnitPoint = .center
    var scale: Double = 1
    var offset: CGSize = .zero
    @ObservationIgnored
    private var baseScale: Double = 1
    @ObservationIgnored
    private var newOffset: CGSize = .zero

    func edgeWidth(xAxis: Double) -> Double {
        let marginW = containerSize.width * (scale - 1) / 2
        let leadingMargin = scaleAnchor.x / 0.5 * marginW
        let trailingMargin = (1 - scaleAnchor.x) / 0.5 * marginW
        return min(max(xAxis, -trailingMargin), leadingMargin)
    }
    func edgeHeight(yAxis: Double) -> Double {
        let marginH = containerSize.height * (scale - 1) / 2
        let topMargin = scaleAnchor.y / 0.5 * marginH
        let bottomMargin = (1 - scaleAnchor.y) / 0.5 * marginH
        return min(max(yAxis, -bottomMargin), topMargin)
    }
    private func correctOffset() {
        offset.width = edgeWidth(xAxis: offset.width)
        offset.height = edgeHeight(yAxis: offset.height)
    }
    func correctScaleAnchor(point: CGPoint) {
        let xAxis = min(1, max(0, point.x / containerSize.width))
        let yAxis = min(1, max(0, point.y / containerSize.height))
        scaleAnchor = .init(x: xAxis, y: yAxis)
    }
    private func setOffset(_ offset: CGSize) {
        self.offset = offset
        correctOffset()
    }
    private func setScale(scale: Double, maximum: Double) {
        guard scale >= 1 && scale <= maximum else { return }
        self.scale = scale
        correctOffset()
    }

    func onSingleTapGestureEnded(
        location: CGPoint,
        readingDirection: ReadingDirection,
        setPageIndexOffsetAction: @escaping (Int) -> Void,
        toggleShowsPanelAction: @escaping () -> Void
    ) {
        guard readingDirection != .vertical else {
            toggleShowsPanelAction()
            return
        }
        let rightToLeft = readingDirection == .rightToLeft
        if location.x < containerSize.width * 0.2 {
            setPageIndexOffsetAction(rightToLeft ? 1 : -1)
        } else if location.x > containerSize.width * (1 - 0.2) {
            setPageIndexOffsetAction(rightToLeft ? -1 : 1)
        } else {
            toggleShowsPanelAction()
        }
    }

    func onDoubleTapGestureEnded(location: CGPoint, scaleMaximum: Double, doubleTapScale: Double) {
        let newScale = scale == 1 ? doubleTapScale : 1
        correctScaleAnchor(point: location)
        setOffset(.zero)
        setScale(scale: newScale, maximum: scaleMaximum)
    }

    func onMagnifyGestureChanged(value: Double, anchor: UnitPoint, scaleMaximum: Double) {
        if value == 1 {
            baseScale = scale
        }
        scaleAnchor = anchor
        setScale(scale: value * baseScale, maximum: scaleMaximum)
    }

    func onMagnifyGestureEnded(value: Double, anchor: UnitPoint, scaleMaximum: Double) {
        onMagnifyGestureChanged(value: value, anchor: anchor, scaleMaximum: scaleMaximum)
        if value * baseScale - 1 < 0.01 {
            setScale(scale: 1, maximum: scaleMaximum)
        }
        baseScale = scale
    }

    func onDragGestureChanged(value: DragGesture.Value) {
        guard scale > 1 else { return }
        let newX = value.translation.width + newOffset.width
        let newY = value.translation.height + newOffset.height
        let newOffsetW = edgeWidth(xAxis: newX)
        let newOffsetH = edgeHeight(yAxis: newY)
        setOffset(.init(width: newOffsetW, height: newOffsetH))
    }

    func onDragGestureEnded(value: DragGesture.Value) {
        onDragGestureChanged(value: value)
        if scale > 1 {
            newOffset.width = offset.width
            newOffset.height = offset.height
        }
    }

    func onControlPanelDismissGestureEnded(value: DragGesture.Value, dismissAction: @escaping () -> Void) {
        if value.predictedEndTranslation.height > 30 {
            dismissAction()
        }
    }
}
