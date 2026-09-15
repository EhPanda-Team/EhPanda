import AppModels
import SwiftUI

public struct Placeholder: View {
    private let style: PlaceholderStyle

    public init(style: PlaceholderStyle) {
        self.style = style
    }

    public var body: some View {
        switch style {
        case .activity(let ratio, let cornerRadius):
            Color(.systemGray5)
                .overlay {
                    ProgressView()
                }
                .aspectRatio(ratio, contentMode: .fill)
                .clipShape(.rect(cornerRadius: cornerRadius))

        case .progress(let pageNumber, let progress, let isDualPage, let backgroundColor):
            backgroundColor
                .overlay {
                    VStack {
                        Text(String(pageNumber))
                            .font(.largeTitle.bold())
                            .foregroundStyle(.gray)
                            .padding(.bottom, 30)

                        if let progress {
                            ProgressView(progress)
                                .progressViewStyle(.plainLinear)
                                .containerRelativeFrame(.horizontal) { width, _ in
                                    width * (isDualPage ? 0.25 : 0.5)
                                }
                        } else {
                            ProgressView()
                        }
                    }
                }
        }
    }
}

public enum PlaceholderStyle {
    case activity(ratio: CGFloat, cornerRadius: CGFloat = 5)
    case progress(pageNumber: Int, progress: Progress?, isDualPage: Bool = false, backgroundColor: Color)
}
