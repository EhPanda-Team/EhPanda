//
//  Presents a bottom-anchored Liquid Glass toast, driven by `AppAlertState` presentation state.
//  The presentation model is adapted from Daniel Saidi's SystemNotification (MIT-licensed):
//  https://github.com/danielsaidi/SystemNotification, reduced to a single bottom edge and rebuilt
//  on TCA presentation state and SwiftUI's Liquid Glass (`glassEffect`) instead of a Material chrome.
//

import SwiftUI
import AppComponents
import ComposableArchitecture

extension View {
    /// Overlays a bottom-anchored Liquid Glass toast driven by presentation state, mirroring
    /// ``SwiftUICore/View/appAlert(_:)``. A non-`nil` store presents the toast; auto-hiding toasts
    /// dismiss themselves after a short delay, and a downward swipe dismisses an auto-hiding toast
    /// early. Both paths clear the presentation binding, sending `.dismiss` through the store.
    ///
    /// Drive it with a presented store scope, exactly like `appAlert`:
    ///
    /// ```swift
    /// .toast($store.scope(state: \.toast, action: \.toast))
    /// ```
    @MainActor
    public func toast(
        _ item: Binding<Store<AppAlertState<Never>, Never>?>
    ) -> some View {
        modifier(ToastViewModifier(item: item))
    }
}

private struct ToastViewModifier: ViewModifier {
    @Binding var item: Store<AppAlertState<Never>, Never>?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let store = item {
                    let toast = store.toastContent
                    // SwiftUI keeps this conditional child alive through its removal transition, so
                    // the last content stays visible while the toast slides back off-screen — no
                    // manual hold.
                    ToastMessageView(content: toast)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .gesture(dismissGesture(autoHide: toast.autoHide))
                        // The timer must restart whenever the presented state is replaced. That id
                        // is `store.state.id`; `store.id` is the Store object's own identity (TCA
                        // declares `Store: Identifiable`), which shadows the state's UUID.
                        .task(id: store.state.id) { await autoDismiss(toast) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Scoped inside the overlay: the host view can mutate in the same transaction that
            // presents or clears the toast, and must not inherit this animation.
            .animation(.bouncy, value: item != nil)
        }
    }

    // Only auto-hiding toasts (success / error) can be flicked away; a loading toast stays until
    // its reducer clears the state, so a downward drag on it is ignored.
    private func dismissGesture(autoHide: Bool) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard autoHide, value.translation.height > 0 else { return }
                item = nil
            }
    }

    private func autoDismiss(_ toast: ToastContent) async {
        guard toast.autoHide else { return }
        try? await Task.sleep(for: .seconds(3))
        // The task is cancelled when the toast is replaced or dismissed; only a timer that ran to
        // completion should clear the state, so bail out on cancellation.
        guard !Task.isCancelled else { return }
        item = nil
    }
}
