import SwiftUI
import AppModels
import AppTools

public struct Placeholder: View {
    @Environment(\.inSheet) private var inSheet
    private let style: PlaceholderStyle

    public init(style: PlaceholderStyle) {
        self.style = style
    }

    public var body: some View {
        switch style {
        case .activity(let ratio, let cornerRadius):
            ZStack {
                Color(inSheet ? .systemGray4 : .systemGray5)

                ProgressView()
            }
            .aspectRatio(ratio, contentMode: .fill)
            .cornerRadius(cornerRadius)

        case .progress(let pageNumber, let progress, let isDualPage, let backgroundColor):
            ZStack {
                backgroundColor
                VStack {
                    Text(String(pageNumber))
                        .font(.largeTitle.bold())
                        .foregroundColor(.gray)
                        .padding(.bottom, 30)

                    if let progress {
                        ProgressView(progress)
                            .progressViewStyle(.plainLinear)
                            .frame(width: DeviceUtil.absWindowW * (isDualPage ? 0.25 : 0.5))
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
