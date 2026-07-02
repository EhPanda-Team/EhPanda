import SwiftUI
import Resources
import ComposableArchitecture

/// The app's single presentation-state type. It backs both button dialogs and progress HUDs, so a
/// feature models any transient presentation with one `@ObservableState` value:
///
/// - ``Style/alert`` renders through ``SwiftUICore/View/appAlert(_:)`` as a **native** system alert,
///   with `buttons` wired to your reducer's actions (mirroring `AlertState`'s ergonomics).
/// - ``Style/hud(icon:autoHide:)`` renders through `View.progressHUD(_:)` (in `TTProgressHUDExt`) as
///   a `TTProgressHUD` toast; the button-less HUD factories live on `AppAlertState<Never>`.
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
        case hud(icon: HUDIcon, autoHide: Bool)
    }

    /// The glyph a ``Style/hud(icon:autoHide:)`` presentation shows; maps to a `TTProgressHUDType`.
    public enum HUDIcon: Equatable, Hashable, Sendable {
        case loading, success, error
    }

    public let id: UUID
    public var style: Style
    public var title: TextState
    public var message: TextState?
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

    // Builds a button-less HUD presentation; used by the `Action == Never` factories below.
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
            && lhs.buttons == rhs.buttons
    }
}

extension AppAlertState: Hashable where Action: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(style)
        hasher.combine(title)
        hasher.combine(message)
        hasher.combine(buttons)
    }
}

extension AppAlertState: Sendable where Action: Sendable {}

// Marks the dialog as ephemeral, exactly as `AlertState`/`ConfirmationDialogState` do, so a plain
// `.ifLet(_:action:)` (no child reducer) drives it and it auto-dismisses when a button is tapped.
extension AppAlertState: _EphemeralState {}

// MARK: - HUD presentations
// These mirror the old `ProgressHUDConfigState` cases one-for-one, so migrating a HUD assignment is a
// pure type change; `TTProgressHUDExt` maps `HUDIcon` + `title`/`message` onto a `TTProgressHUDConfig`.
extension AppAlertState where Action == Never {
    public static func loading(title: String? = nil) -> Self {
        .init(
            style: .hud(icon: .loading, autoHide: false),
            title: TextState(title ?? L10n.Localizable.Hud.Title.loading)
        )
    }
    public static var communicating: Self {
        .init(
            style: .hud(icon: .loading, autoHide: false),
            title: TextState(L10n.Localizable.Hud.Title.communicating)
        )
    }
    public static func error(caption: String? = nil) -> Self {
        .init(
            style: .hud(icon: .error, autoHide: true),
            title: TextState(L10n.Localizable.Hud.Title.error),
            message: caption.map { TextState($0) }
        )
    }
    public static func success(caption: String? = nil) -> Self {
        .init(
            style: .hud(icon: .success, autoHide: true),
            title: TextState(L10n.Localizable.Hud.Title.success),
            message: caption.map { TextState($0) }
        )
    }
    public static var savedToPhotoLibrary: Self {
        .success(caption: L10n.Localizable.Hud.Caption.savedToPhotoLibrary)
    }
    public static var copiedToClipboardSucceeded: Self {
        .success(caption: L10n.Localizable.Hud.Caption.copiedToClipboard)
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
        modifier(AppAlertViewModifier(item: item))
    }
}

private struct AppAlertViewModifier<Action>: ViewModifier {
    @Binding var item: Store<AppAlertState<Action>, Action>?

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
