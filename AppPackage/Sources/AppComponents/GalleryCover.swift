import Kingfisher
import SwiftUI

/// Stable artwork geometry for fixed-cover surfaces, including loading and local download covers.
public struct GalleryCover: View {
    /// Shared with artwork verification so its corner coverage follows the production clip.
    public static let clipShape: RoundedRectangle = .rect(cornerRadius: 5, style: .continuous)

    @Environment(\.colorScheme) private var colorScheme
    @GalleryCoverMetrics private var size: CGSize
    private let url: URL?
    private let contentMode: SwiftUI.ContentMode
    private let onSuccess: ((RetrieveImageResult) -> Void)?

    public init(
        url: URL?,
        style: GalleryCoverStyle,
        contentMode: SwiftUI.ContentMode = .fit,
        maximumHeight: CGFloat? = nil,
        onSuccess: ((RetrieveImageResult) -> Void)? = nil
    ) {
        self.url = url
        self._size = GalleryCoverMetrics(style, maximumHeight: maximumHeight)
        self.contentMode = contentMode
        self.onSuccess = onSuccess
    }

    public var body: some View {
        KFImage(url)
            .placeholder {
                Color(.systemGray5)
                    .overlay { ProgressView() }
                    .aspectRatio(size.height > 0 ? size.width / size.height : GalleryCoverStyle.aspectRatio,
                                 contentMode: .fill)
            }
            .onSuccess(onSuccess)
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
            // In dark grouped lists, secondarySystemBackground matches the cell itself.
            .background(Color(colorScheme == .dark ? .systemGray5 : .secondarySystemBackground))
            .clipShape(Self.clipShape)
    }
}
