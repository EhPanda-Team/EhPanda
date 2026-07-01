import SwiftUI

/// The shared chrome behind every app alert: a dimmed backdrop, a centered scrollable glass card,
/// a header title, an optional message, an optional accessory slot (e.g. a toggle), and a
/// caller-provided actions row. The `appAlert(_:accessory:)` modifier (see ``AppAlertState``)
/// builds on it to present a state-driven alert from a reducer.
struct AppAlertCard<Accessory: View, Actions: View>: View {
    private let title: Text
    private let message: Text?
    private let titleFocus: AccessibilityFocusState<Bool>.Binding
    private let onEscape: () -> Void
    private let accessory: Accessory
    private let actions: Actions

    @State private var availableHeight: CGFloat = 0

    init(
        title: Text,
        message: Text?,
        titleFocus: AccessibilityFocusState<Bool>.Binding,
        onEscape: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.titleFocus = titleFocus
        self.onEscape = onEscape
        self.accessory = accessory()
        self.actions = actions()
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(0.42)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Center the card while still letting it scroll at the largest accessibility
            // text sizes, where the content can otherwise exceed the screen height.
            ScrollView {
                card
                    .frame(maxWidth: 380)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: availableHeight)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                availableHeight = height
            }
        }
        // Custom overlays aren't real modals, so wire up the VoiceOver / Full Keyboard
        // Access escape gesture to dismiss the notice the same way the primary action does.
        .accessibilityAction(.escape) {
            onEscape()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                title
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(titleFocus)

                if let message {
                    message
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            accessory

            actions
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .contain)
    }
}
