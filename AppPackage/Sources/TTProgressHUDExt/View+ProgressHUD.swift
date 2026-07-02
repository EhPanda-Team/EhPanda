import SwiftUI
import AppComponents
import ComposableArchitecture
import TTProgressHUD

extension View {
    /// Overlays a progress HUD driven by optional ``AppAlertState`` HUD state: a non-`nil` value shows
    /// the HUD with that configuration and `nil` hides it. Auto-hiding HUDs write `nil` back through
    /// the binding. Build the state with the `.hud`-style factories on `AppAlertState<Never>`
    /// (`.loading()`, `.success(caption:)`, …).
    public func progressHUD(_ config: Binding<AppAlertState<Never>?>) -> some View {
        modifier(ProgressHUDModifier(config: config))
    }
}

private struct ProgressHUDModifier: ViewModifier {
    @Binding var config: AppAlertState<Never>?
    // Keeps the last shown configuration alive so the HUD's hide transition doesn't fall back
    // to a default look the moment the state is reset to `nil`.
    @State private var lastConfig: AppAlertState<Never> = .loading()

    func body(content: Content) -> some View {
        ZStack {
            content
            TTProgressHUD(isVisible, config: (config ?? lastConfig).ttProgressHUDConfig)
        }
        .onChange(of: config) { _, newValue in
            if let newValue {
                lastConfig = newValue
            }
        }
    }

    private var isVisible: Binding<Bool> {
        .init(
            get: { config != nil },
            set: { isPresented, transaction in
                guard !isPresented, config != nil else { return }
                $config.transaction(transaction).wrappedValue = nil
            }
        )
    }
}

private extension AppAlertState where Action == Never {
    // Maps the unified HUD state onto the underlying TTProgressHUD library config. The `.alert` style
    // never reaches a `progressHUD` binding, so it degrades to a plain loading spinner defensively.
    var ttProgressHUDConfig: TTProgressHUDConfig {
        let type: TTProgressHUDType
        let autoHide: Bool
        switch style {
        case .alert:
            type = .loading
            autoHide = false
        case let .toast(icon, shouldAutoHide):
            autoHide = shouldAutoHide
            switch icon {
            case .loading: type = .loading
            case .success: type = .success
            case .error: type = .error
            }
        }
        return .init(
            type: type,
            title: String(state: title),
            caption: message.map { String(state: $0) },
            shouldAutoHide: autoHide,
            autoHideInterval: 1
        )
    }
}
