import SwiftUI
import Resources
import ComposableArchitecture

/// Describes an app alert to present, modeled directly on TCA's `AlertState`: the dialog's content
/// lives in your feature's state, so presentation and the buttons' actions stay in the reducer and
/// remain testable. Its initializer mirrors `AlertState` exactly — a `title`, a `ButtonStateBuilder`
/// of `actions`, and an optional `message` — so migrating a call site is a pure rename.
///
/// It reuses TCA's own `TextState` and `ButtonState` for content, which means runtime strings,
/// localized keys, and button roles (`.cancel`, `.destructive`) all work the same way they do with
/// `AlertState`. The only reason it isn't `AlertState` itself: this state is rendered by a consumer
/// view (``AppAlertCard``) rather than internally by the framework, so it must be `@ObservableState`
/// for the presentation store to expose its content without the deprecated `Store.withState`.
@ObservableState
public struct AppAlertState<Action>: Identifiable {
    public let id: UUID
    public var title: TextState
    public var message: TextState?
    public var buttons: [ButtonState<Action>]

    public init(
        title: () -> TextState,
        @ButtonStateBuilder<Action> actions: () -> [ButtonState<Action>] = { [] },
        message: (() -> TextState)? = nil
    ) {
        self.id = UUID()
        self.title = title()
        self.buttons = actions()
        self.message = message?()
    }
}

extension AppAlertState: Equatable where Action: Equatable {
    // Mirrors `AlertState`: identity is excluded so two states with equal content compare equal,
    // which keeps reducer tests asserting on freshly-constructed states straightforward.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
            && lhs.message == rhs.message
            && lhs.buttons == rhs.buttons
    }
}

extension AppAlertState: Hashable where Action: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(message)
        hasher.combine(buttons)
    }
}

extension AppAlertState: Sendable where Action: Sendable {}

// Marks the dialog as ephemeral, exactly as `AlertState`/`ConfirmationDialogState` do, so a plain
// `.ifLet(_:action:)` (no child reducer) drives it and it auto-dismisses when a button is tapped.
extension AppAlertState: _EphemeralState {}

extension View {
    /// Presents an ``AppAlertCard``-style glass card when presentation state held in a store becomes
    /// non-`nil`, mirroring TCA's `.alert(_:)`. Drive it with a presented store scope:
    ///
    /// ```swift
    /// .appAlert($store.scope(state: \.alert, action: \.alert))
    /// ```
    ///
    /// Tapping a button sends that button's action through the presentation store and dismisses the
    /// dialog automatically — ``AppAlertState`` is ephemeral, just like a system alert.
    ///
    /// Pass an `accessory` view builder for dialogs that need richer content than buttons — such as a
    /// "Don't show again" toggle bound to your feature's state — rendered between the message and the
    /// buttons:
    ///
    /// ```swift
    /// .appAlert($store.scope(state: \.alert, action: \.alert)) {
    ///     Toggle("Don't show again", isOn: $store.suppress)
    /// }
    /// ```
    @MainActor
    public func appAlert<Action, Accessory: View>(
        _ item: Binding<Store<AppAlertState<Action>, Action>?>,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) -> some View {
        modifier(AppAlertModifier(item: item, accessory: accessory))
    }
}

private struct AppAlertModifier<Action, Accessory: View>: ViewModifier {
    @Binding var item: Store<AppAlertState<Action>, Action>?
    let accessory: () -> Accessory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isTitleFocused: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
                .accessibilityHidden(item != nil)

            if let store = item {
                AppAlertCard(
                    title: Text(store.title),
                    message: store.message.map(Text.init),
                    titleFocus: $isTitleFocused,
                    onEscape: dismiss,
                    accessory: accessory
                ) {
                    actions(for: store)
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onChange(of: item != nil) { _, isPresented in
            // Move VoiceOver focus onto the dialog when it appears; the background is hidden.
            if isPresented {
                isTitleFocused = true
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.12) : .smooth(duration: 0.2),
            value: item != nil
        )
    }

    @ViewBuilder
    private func actions(for store: Store<AppAlertState<Action>, Action>) -> some View {
        let buttons = resolvedButtons(store.buttons)
        let primaryID = buttons.last(where: { $0.role != .cancel })?.id

        if buttons.count > 2 {
            VStack(spacing: 10) {
                ForEach(buttons) { button in
                    alertButton(button, store: store, isProminent: button.id == primaryID, fillWidth: true)
                }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(buttons) { button in
                    let isProminent = button.id == primaryID
                    let fillWidth = !(buttons.count == 2 && isProminent)
                    alertButton(button, store: store, isProminent: isProminent, fillWidth: fillWidth)
                }
            }
        }
    }

    @ViewBuilder
    private func alertButton(
        _ button: ResolvedButton,
        store: Store<AppAlertState<Action>, Action>,
        isProminent: Bool,
        fillWidth: Bool
    ) -> some View {
        let action = Button(role: button.role.map(ButtonRole.init)) {
            if let state = button.state {
                state.withAction { sentAction in
                    if let sentAction {
                        store.send(sentAction)
                    } else {
                        dismiss()
                    }
                }
            } else {
                dismiss()
            }
        } label: {
            if fillWidth {
                Text(button.label)
                    .frame(maxWidth: .infinity)
            } else {
                Text(button.label)
                    .frame(minWidth: 72)
            }
        }

        if isProminent {
            // A prominent destructive button is tinted red by SwiftUI from its role; otherwise
            // the button inherits the app's accent color from the environment.
            action.buttonStyle(.borderedProminent)
        } else {
            action.buttonStyle(.bordered)
        }
    }

    private func dismiss() {
        item = nil
    }

    /// Resolves the buttons to render, reproducing SwiftUI's `.alert` semantics: with no buttons the
    /// alert offers a single "OK", and an alert that declares no `.cancel`-role button gets one added
    /// so it stays dismissable. A `nil` ``ResolvedButton/state`` is such a synthesized button — it
    /// carries no action and only dismisses.
    private func resolvedButtons(_ buttons: [ButtonState<Action>]) -> [ResolvedButton] {
        var resolved = [ResolvedButton]()

        if buttons.isEmpty {
            resolved.append(
                ResolvedButton(id: 0, label: TextState(L10n.Localizable.Common.Button.ok), role: nil, state: nil)
            )
        } else {
            for (index, button) in buttons.enumerated() {
                resolved.append(
                    ResolvedButton(id: index, label: button.label, role: button.role, state: button)
                )
            }
            if !buttons.contains(where: { $0.role == .cancel }) {
                resolved.append(
                    ResolvedButton(
                        id: buttons.count,
                        label: TextState(L10n.Localizable.Common.Button.cancel),
                        role: .cancel,
                        state: nil
                    )
                )
            }
        }

        return ordered(resolved)
    }

    /// Moves the prominent (primary) button to the trailing position, matching the
    /// bordered-leading / prominent-trailing layout the app uses elsewhere.
    private func ordered(_ buttons: [ResolvedButton]) -> [ResolvedButton] {
        guard let primaryIndex = buttons.lastIndex(where: { $0.role != .cancel }) else {
            return buttons
        }
        var result = buttons
        let primary = result.remove(at: primaryIndex)
        result.append(primary)
        return result
    }

    private struct ResolvedButton: Identifiable {
        let id: Int
        let label: TextState
        let role: ButtonStateRole?
        // The originating button state, or `nil` for a synthesized OK / Cancel that only dismisses.
        let state: ButtonState<Action>?
    }
}
