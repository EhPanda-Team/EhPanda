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
                            .foregroundStyle(Color.pagePlaceholder)
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

extension Color {
    /// The page number and reload glyph a reader page shows before its image: `.gray` on the
    /// reader's light page background (`systemGray4`, `#D1D1D6`) measured 2.14:1, which the Phase
    /// 16 automated audit reports as a contrast failure (3:1 is the floor for the 34-point bold
    /// number and the 30-point glyph). Light is the system gray darkened by 0.35 — `#5C5C60`,
    /// 4.37:1 — the smallest twentieth that also clears the light Increase Contrast pairing;
    /// that entry is the system's Increase Contrast gray darkened by the same factor (`#464649`
    /// on `#BCBCC0`, 4.97:1). The dark entries keep the gray the system renders (`#8E8E93` on
    /// `#1C1C1E`, 5.22:1; `#AEAEB2` on `#242426`, 7.01:1), so nothing changes where it passed.
    ///
    /// A colorset rather than a `colorScheme` read, as for `ratingStar`: the number is drawn by
    /// this placeholder and by the reader's failed-load page, and the per-scheme and per-contrast
    /// choice belongs in the one asset both name.
    public static let pagePlaceholder = Color("PagePlaceholder", bundle: .module)
}

public enum PlaceholderStyle {
    case activity(ratio: CGFloat, cornerRadius: CGFloat = 5)
    case progress(pageNumber: Int, progress: Progress?, isDualPage: Bool = false, backgroundColor: Color)
}
