//
//  Presents a bottom-anchored Liquid Glass toast, driven by `AppAlertState` presentation state.
//  The presentation model is adapted from Daniel Saidi's SystemNotification (MIT-licensed):
//  https://github.com/danielsaidi/SystemNotification, reduced to a single bottom edge and rebuilt
//  on TCA presentation state and SwiftUI's Liquid Glass (`glassEffect`) instead of a Material chrome.
//

import AppComponents
import AppModels
import ComposableArchitecture
import SwiftUI

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
        _ item: Binding<Store<AppAlertState<Never>, Never>?>,
        onErrorTap: @escaping (ErrorInfo) -> Void = { _ in }
    ) -> some View {
        modifier(ToastViewModifier(item: item, onErrorTap: onErrorTap))
    }
}

private struct ToastViewModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var item: Store<AppAlertState<Never>, Never>?
    let onErrorTap: (ErrorInfo) -> Void
    @AccessibilityFocusState private var focusedToastID: UUID?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let store = item {
                    let toast = store.toastContent
                    // The dismiss timer keys off the state's own UUID. Not `store.id`: TCA declares
                    // `Store: Identifiable`, so that is the Store object's identity, which shadows
                    // the state's UUID and only coincidentally tracks replacement.
                    let id = store.state.id
                    // SwiftUI keeps this conditional child alive through its removal transition, so
                    // the last content stays visible while the toast slides back off-screen — no
                    // manual hold.
                    Group {
                        if store.state.errorInfo != nil {
                            Button {
                                errorButtonTapped(presentedID: id)
                            } label: {
                                ToastMessageView(content: toast)
                                    .frame(minHeight: 44)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityFocused($focusedToastID, equals: id)
                        } else {
                            ToastMessageView(content: toast)
                        }
                    }
                    .glassEffect(.regular, in: .capsule)
                    .id(id)
                    .padding(.horizontal)
                    .padding(.bottom, 64)
                    .gesture(dismissGesture(
                        isDismissible: toast.autoHide || store.state.errorInfo != nil,
                        presentedID: id
                    ))
                    // D-02 exception candidate: `.task(id:)` is used here for its *cancellation*.
                    // The auto-dismiss timer must die the instant the toast is replaced or flicked
                    // away, and keying on the state's id restarts it per toast — that is precisely
                    // `.task(id:)`'s contract. The non-banned alternative (`.onChange(of: id,
                    // initial:)` firing an unstructured `Task`) leaves an orphaned 3-second sleep
                    // per replaced toast, each waking to re-check state it no longer owns.
                    // swiftlint:disable:next lifecycle_modifiers
                    .task(id: id) {
                        await managePresentation(
                            toast,
                            errorInfo: store.state.errorInfo,
                            presentedID: id
                        )
                    }
                    .transition(toastTransition)
                }
            }
            // Scoped inside the overlay: the host view can mutate in the same transaction that
            // presents or clears the toast, and must not inherit this animation.
            .animation(toastAnimation, value: item != nil)
        }
    }

    private var toastAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .bouncy
    }

    private var toastTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .bottom).combined(with: .opacity)
    }

    // Transient and diagnostic toasts can be flicked away; a loading toast stays until its reducer
    // clears the state. The drag must be predominantly vertical, so a sideways flick does nothing.
    private func dismissGesture(isDismissible: Bool, presentedID: UUID) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let translation = value.translation
                guard isDismissible,
                      abs(translation.height) > abs(translation.width),
                      translation.height > 0
                else { return }
                dismiss(presentedID: presentedID)
            }
    }

    // Every interaction is guarded on the presented state's own id, so a toast that is still on
    // screen through its removal transition — replaced or already dismissed — cannot act. Clearing
    // `item` is what invalidates it; there is deliberately no view-local mirror of "which toast is
    // presented", because the presentation binding already is that.
    private func errorButtonTapped(presentedID: UUID) {
        guard let store = item, store.state.id == presentedID,
              let errorInfo = store.state.errorInfo
        else { return }
        item = nil
        onErrorTap(errorInfo)
    }

    private func dismiss(presentedID: UUID) {
        guard item?.state.id == presentedID else { return }
        item = nil
    }

    private func managePresentation(
        _ toast: ToastContent,
        errorInfo: ErrorInfo?,
        presentedID: UUID
    ) async {
        if errorInfo != nil {
            await Task.yield()
            guard !Task.isCancelled, item?.state.id == presentedID else { return }
            focusedToastID = presentedID
            AccessibilityNotification.Announcement(toast.announcement).post()
        } else {
            await autoDismiss(toast, presentedID: presentedID)
        }
    }

    private func autoDismiss(_ toast: ToastContent, presentedID: UUID) async {
        guard toast.autoHide else { return }
        do {
            try await Task.sleep(for: .seconds(3))
        } catch {
            // Replacement or dismissal cancels this task; cancellation is the intended no-op.
            return
        }
        // The task is cancelled when the toast is replaced or dismissed, but a continuation already
        // enqueued when the replacement lands can still run before SwiftUI restarts the task. Only
        // a completed timer whose state is still presented may clear it.
        guard !Task.isCancelled, item?.state.id == presentedID else { return }
        dismiss(presentedID: presentedID)
    }
}

private extension ToastContent {
    var announcement: String {
        [title, subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
