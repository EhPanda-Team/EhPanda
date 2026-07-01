import SwiftUI
import TTProgressHUD

extension View {
    /// Overlays a progress HUD driven by optional state: a non-`nil` value shows the HUD with that
    /// configuration and `nil` hides it. Auto-hiding HUDs write `nil` back through the binding.
    public func progressHUD(_ config: Binding<ProgressHUDConfigState?>) -> some View {
        modifier(ProgressHUDModifier(config: config))
    }
}

private struct ProgressHUDModifier: ViewModifier {
    @Binding var config: ProgressHUDConfigState?
    // Keeps the last shown configuration alive so the HUD's hide transition doesn't fall back
    // to a default look the moment the state is reset to `nil`.
    @State private var lastConfig: ProgressHUDConfigState = .loading()

    func body(content: Content) -> some View {
        ZStack {
            content
            TTProgressHUD(isVisible, config: (config ?? lastConfig).progressHUDConfig)
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
