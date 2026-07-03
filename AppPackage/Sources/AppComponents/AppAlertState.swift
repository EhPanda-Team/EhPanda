import SwiftUI
import Resources
import ComposableArchitecture

/// The app's single presentation-state type. It backs both button dialogs and toasts, so a
/// feature models any transient presentation with one `@ObservableState` value:
///
/// - ``Style/alert`` renders through ``SwiftUICore/View/appAlert(_:)`` as a **native** system alert,
///   with `buttons` wired to your reducer's actions (mirroring `AlertState`'s ergonomics).
/// - ``Style/toast(icon:autoHide:)`` renders through `View.toast(_:)` (in `SystemNotificationExt`)
///   as a bottom Liquid Glass toast; the button-less toast factories live on `AppAlertState<Never>`.
///
/// Its alert initializer mirrors `AlertState` exactly — a `title`, a `ButtonStateBuilder` of
/// `actions`, and an optional `message` — so migrating an alert call site is a pure rename. It reuses
/// TCA's `TextState`/`ButtonState`, so localized keys and button roles behave identically. It isn't
/// `AlertState` itself because it is rendered by a consumer view rather than the framework, so it
/// must be `@ObservableState` for the presentation store to expose its content.
@ObservableState
public struct AppAlertState<Action>: Identifiable {
    /// How a value is presented. See ``AppAlertState`` for which modifier renders each style.
    public enum Style: Equatable, Hashable, Sendable {
        case alert
        case toast(icon: ToastIcon, autoHide: Bool)
    }

    /// The glyph a ``Style/toast(icon:autoHide:)`` presentation shows.
    public enum ToastIcon: Equatable, Hashable, Sendable {
        case loading, success, error
    }

    public let id: UUID
    public var style: Style
    public var title: TextState
    public var message: TextState?
    public var textField: AppAlertTextFieldState?
    public var buttons: [ButtonState<Action>]

    public init(
        title: () -> TextState,
        @ButtonStateBuilder<Action> actions: () -> [ButtonState<Action>] = { [] },
        message: (() -> TextState)? = nil
    ) {
        self.id = UUID()
        self.style = .alert
        self.title = title()
        self.buttons = actions()
        self.message = message?()
    }

    /// Builds an alert that includes a single text field. `textField` sits between `title` and
    /// `actions` so the trailing `actions`/`message` closures read exactly like the plain alert init.
    public init(
        title: () -> TextState,
        textField: AppAlertTextFieldState,
        @ButtonStateBuilder<Action> actions: () -> [ButtonState<Action>] = { [] },
        message: (() -> TextState)? = nil
    ) {
        self.init(title: title, actions: actions, message: message)
        self.textField = textField
    }

    // Builds a button-less toast presentation; used by the `Action == Never` factories below.
    init(style: Style, title: TextState, message: TextState? = nil) {
        self.id = UUID()
        self.style = style
        self.title = title
        self.message = message
        self.buttons = []
    }
}

extension AppAlertState: Equatable where Action: Equatable {
    // Mirrors `AlertState`: identity is excluded so two states with equal content compare equal,
    // which keeps reducer tests asserting on freshly-constructed states straightforward.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.style == rhs.style
            && lhs.title == rhs.title
            && lhs.message == rhs.message
            && lhs.textField == rhs.textField
            && lhs.buttons == rhs.buttons
    }
}

extension AppAlertState: Hashable where Action: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(style)
        hasher.combine(title)
        hasher.combine(message)
        hasher.combine(textField)
        hasher.combine(buttons)
    }
}

extension AppAlertState: Sendable where Action: Sendable {}

// Marks the dialog as ephemeral, exactly as `AlertState`/`ConfirmationDialogState` do, so a plain
// `.ifLet(_:action:)` (no child reducer) drives it and it auto-dismisses when a button is tapped.
extension AppAlertState: _EphemeralState {}

/// Describes a single text field shown inside an ``AppAlertState`` alert. The field's *value* is not
/// stored here: it binds to the host reducer's own state, supplied at the call site through
/// ``SwiftUICore/View/appAlert(_:text:)``. That keeps the alert ephemeral — keystrokes never have to
/// round-trip through a reducer — while still letting a feature declare the field declaratively. It's a
/// top-level type (not nested in ``AppAlertState``) because it's independent of the alert's `Action`.
public struct AppAlertTextFieldState: Equatable, Hashable, Sendable {
    /// The kind of keyboard the field raises. Kept host-agnostic (no `UIKit` type) so the state stays
    /// `Sendable`; ``SwiftUICore/View/appAlert(_:text:)`` maps it to a `UIKeyboardType`.
    public enum Keyboard: Equatable, Hashable, Sendable {
        case `default`, numberPad
    }

    public var placeholder: TextState
    public var keyboard: Keyboard

    public init(placeholder: TextState, keyboard: Keyboard = .default) {
        self.placeholder = placeholder
        self.keyboard = keyboard
    }
}

// MARK: - Toast presentations
// Button-less toast presentations. `SystemNotificationExt` maps `ToastIcon` + `title`/`message`
// onto the rendered Liquid Glass toast content.
extension AppAlertState where Action == Never {
    public static func loading(title: String? = nil) -> Self {
        .init(
            style: .toast(icon: .loading, autoHide: false),
            title: TextState(title ?? L10n.Localizable.Toast.loading)
        )
    }
    public static var communicating: Self {
        .init(
            style: .toast(icon: .loading, autoHide: false),
            title: TextState(L10n.Localizable.Toast.communicating)
        )
    }
    public static func error(caption: String? = nil) -> Self {
        .init(
            style: .toast(icon: .error, autoHide: true),
            title: TextState(L10n.Localizable.Toast.error),
            message: caption.map { TextState($0) }
        )
    }
    public static func success(caption: String? = nil) -> Self {
        .init(
            style: .toast(icon: .success, autoHide: true),
            title: TextState(L10n.Localizable.Toast.success),
            message: caption.map { TextState($0) }
        )
    }
    public static var savedToPhotoLibrary: Self {
        .success(caption: L10n.Localizable.Toast.savedToPhotoLibrary)
    }
    public static var copiedToClipboardSucceeded: Self {
        .success(caption: L10n.Localizable.Toast.copiedToClipboard)
    }
}

// MARK: - Native alert presentation
extension View {
    /// Presents a **native** system alert when presentation state held in a store becomes non-`nil`,
    /// mirroring TCA's `.alert(_:)`. Drive it with a presented store scope:
    ///
    /// ```swift
    /// .appAlert($store.scope(state: \.alert, action: \.alert))
    /// ```
    ///
    /// Tapping a button sends that button's action through the presentation store and dismisses the
    /// alert automatically — ``AppAlertState`` is ephemeral, just like a system alert. With no
    /// buttons, SwiftUI adds its own system-localized "OK".
    @MainActor
    public func appAlert<Action>(
        _ item: Binding<Store<AppAlertState<Action>, Action>?>
    ) -> some View {
        modifier(AppAlertViewModifier(item: item, text: nil))
    }

    /// Same as ``appAlert(_:)`` but also renders the alert's ``AppAlertState/TextFieldState`` (if any),
    /// binding it to `text` and auto-focusing it so the keyboard is up the moment the alert appears —
    /// native `.alert` no longer focuses its first field on its own. `text` lives in the host reducer's
    /// state, e.g. `.appAlert($store.scope(state: \.alert, action: \.alert), text: $store.pageIndex)`.
    @MainActor
    public func appAlert<Action>(
        _ item: Binding<Store<AppAlertState<Action>, Action>?>,
        text: Binding<String>
    ) -> some View {
        modifier(AppAlertViewModifier(item: item, text: text))
    }
}

private struct AppAlertViewModifier<Action>: ViewModifier {
    @Binding var item: Store<AppAlertState<Action>, Action>?
    let text: Binding<String>?
    @FocusState private var isFieldFocused: Bool

    func body(content: Content) -> some View {
        content.alert(
            item.map { Text($0.title) } ?? Text(verbatim: ""),
            isPresented: Binding(
                get: { item != nil },
                set: { isPresented, transaction in
                    guard !isPresented, item != nil else { return }
                    $item.transaction(transaction).wrappedValue = nil
                }
            ),
            presenting: item,
            actions: { store in
                if let textField = store.textField, let text {
                    TextField(String(state: textField.placeholder), text: text)
                        .keyboardType(textField.keyboard == .numberPad ? .numberPad : .default)
                        .focused($isFieldFocused)
                        .onAppear {
                            // The field isn't in the responder chain the instant it appears, so a
                            // synchronous focus is dropped; hop to the next runloop to make it stick.
                            DispatchQueue.main.async { isFieldFocused = true }
                        }
                }
                ForEach(store.buttons) { button in
                    Button(role: button.role.map(ButtonRole.init)) {
                        button.withAction { action in
                            if let action { store.send(action) }
                        }
                    } label: {
                        Text(button.label)
                    }
                }
            },
            message: { store in
                if let message = store.message {
                    Text(message)
                }
            }
        )
    }
}
