import SwiftUI
import AppModels
import AppTools

// MARK: Gesture
extension ReadingView {
    var tapGesture: some Gesture {
        let singleTap = TapGesture(count: 1)
            .onEnded {
                gestureHandler.onSingleTapGestureEnded(
                    location: TouchHandler.shared.currentPoint ?? .zero,
                    readingDirection: store.setting.readingDirection,
                    setPageIndexOffsetAction: {
                        // The offset sign arrives RTL-corrected from GestureHandler
                        // (`onSingleTapGestureEnded`) — no re-inversion here.
                        jump(toPagerIndex: pageModel.index + $0)
                    },
                    toggleShowsPanelAction: { store.send(.toggleShowsPanel) }
                )
            }
        let doubleTap = TapGesture(count: 2)
            .onEnded {
                gestureHandler.onDoubleTapGestureEnded(
                    location: TouchHandler.shared.currentPoint ?? .zero,
                    scaleMaximum: store.setting.maximumScaleFactor,
                    doubleTapScale: store.setting.doubleTapScaleFactor
                )
            }
        return ExclusiveGesture(doubleTap, singleTap)
    }
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged {
                gestureHandler.onMagnificationGestureChanged(
                    value: $0,
                    location: TouchHandler.shared.currentPoint ?? .zero,
                    scaleMaximum: store.setting.maximumScaleFactor
                )
            }
            .onEnded {
                gestureHandler.onMagnificationGestureEnded(
                    value: $0,
                    location: TouchHandler.shared.currentPoint ?? .zero,
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
}
