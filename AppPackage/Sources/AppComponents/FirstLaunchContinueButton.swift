import Resources
public import SwiftUI

/// The Continue button shared by both first-launch screens (UI-SPEC C-1): a full-width, large, accent-filled glass
/// button that the hardware Return key triggers while it is enabled.
///
/// The label is white on the light accent and black on the dark one (UI-SPEC Color: white on #96D35F would be 1.8:1).
/// While the button is disabled the system's dimmed colours apply unchanged, so the label is coloured only when
/// enabled. Each screen sets `.disabled(...)` itself.
public struct FirstLaunchContinueButton: View {
    @Environment(\.isEnabled) private var isEnabled

    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(.RLocalizable.ageWallContinue)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isEnabled ? Self.onAccentLabel : Color.secondary)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .keyboardShortcut(.defaultAction)
    }

    /// The label colour on the accent fill: white in light mode, black in dark mode.
    private static let onAccentLabel = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
}

#Preview("Light") {
    VStack(spacing: 16) {
        FirstLaunchContinueButton {}
        FirstLaunchContinueButton {}
            .disabled(true)
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark") {
    VStack(spacing: 16) {
        FirstLaunchContinueButton {}
        FirstLaunchContinueButton {}
            .disabled(true)
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("AX5") {
    FirstLaunchContinueButton {}
        .padding(24)
        .background(Color(.systemGroupedBackground))
        .environment(\.dynamicTypeSize, .accessibility5)
}
