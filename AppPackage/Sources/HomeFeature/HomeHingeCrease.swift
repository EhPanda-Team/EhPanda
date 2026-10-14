import SwiftUI

/// A decorative fold that stays centered on the physical boundary without consuming content width.
struct HomeHingeCrease: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.displayScale) private var displayScale

    static let width: CGFloat = 18

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: shadow.opacity(0.04), location: 0.2),
                .init(color: shadow.opacity(0.22), location: 0.5),
                .init(color: shadow.opacity(0.04), location: 0.8),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .overlay {
            if contrast == .increased {
                Rectangle().fill(Color(.separator)).frame(width: 1 / displayScale)
            }
        }
        .frame(width: Self.width)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var shadow: Color { colorScheme == .dark ? .white : .black }
}
