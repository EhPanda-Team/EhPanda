import AppModels
public import SwiftUI

public struct Placeholder: View {
    private let style: PlaceholderStyle

    public init(style: PlaceholderStyle) {
        self.style = style
    }

    public var body: some View {
        switch style {
        case .activity(let ratio, let cornerRadius):
            Color(uiColor: .systemGray5)
                .overlay {
                    ProgressView()
                }
                .aspectRatio(ratio, contentMode: .fill)
                .clipShape(.rect(cornerRadius: cornerRadius))
        }
    }
}

public enum PlaceholderStyle {
    case activity(ratio: CGFloat, cornerRadius: CGFloat = 5)
}
