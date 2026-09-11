import AppModels
import SwiftUI

// MARK: Gesture
extension ReadingView {
    var tapGesture: some Gesture {
        let singleTap = SpatialTapGesture(count: 1, coordinateSpace: .local)
            .onEnded { value in
                gestureHandler.onSingleTapGestureEnded(
                    location: value.location,
                    readingDirection: store.setting.readingDirection,
                    setPageIndexOffsetAction: {
                        // The offset sign arrives RTL-corrected from GestureHandler
                        // (`onSingleTapGestureEnded`) — no re-inversion here.
                        jump(toPagerIndex: pageModel.index + $0)
                    },
                    toggleShowsPanelAction: { store.send(.toggleShowsPanel) }
                )
            }
        let doubleTap = SpatialTapGesture(count: 2, coordinateSpace: .local)
            .onEnded { value in
                gestureHandler.onDoubleTapGestureEnded(
                    location: value.location,
                    scaleMaximum: store.setting.maximumScaleFactor,
                    doubleTapScale: store.setting.doubleTapScaleFactor
                )
            }
        return ExclusiveGesture(doubleTap, singleTap)
    }
    var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureHandler.onMagnifyGestureChanged(
                    value: value.magnification,
                    anchor: value.startAnchor,
                    scaleMaximum: store.setting.maximumScaleFactor
                )
            }
            .onEnded { value in
                gestureHandler.onMagnifyGestureEnded(
                    value: value.magnification,
                    anchor: value.startAnchor,
                    scaleMaximum: store.setting.maximumScaleFactor
                )
            }
    }
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: .zero, coordinateSpace: .local)
            .onChanged(gestureHandler.onDragGestureChanged)
            .onEnded(gestureHandler.onDragGestureEnded)
    }
    var controlPanelDismissGesture: some Gesture {
        DragGesture().onEnded {
            gestureHandler.onControlPanelDismissGestureEnded(
                value: $0, dismissAction: { store.send(.onPerformDismiss) }
            )
        }
    }

    // The assistive zoom (VoiceOver's zoom rotor, Voice Control's "zoom in / out") is the reader's
    // double tap, which already toggles between 1 and `doubleTapScaleFactor` at a point. The
    // direction guard is what keeps the toggle honest: "zoom in" only fires unzoomed, "zoom out"
    // only zoomed, so neither can land on the opposite side. Continuous pinch steps are not
    // replayed on purpose — stepping the magnify handler would need its own step and clamping
    // arithmetic, a second zoom path beside the gesture's.
    func performAccessibilityZoom(_ action: AccessibilityZoomGestureAction) {
        switch action.direction {
        case .zoomIn:
            guard gestureHandler.scale == 1 else { return }
        case .zoomOut:
            guard gestureHandler.scale > 1 else { return }
        }
        gestureHandler.onDoubleTapGestureEnded(
            location: action.point,
            scaleMaximum: store.setting.maximumScaleFactor,
            doubleTapScale: store.setting.doubleTapScaleFactor
        )
    }
}
