import Kingfisher
import SwiftUI

/// Stable artwork geometry for fixed-cover surfaces, including loading and local download covers.
public struct GalleryCover: View {
    @GalleryCoverMetrics private var size: CGSize
    private let maximumHeight: CGFloat?
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
        self.maximumHeight = maximumHeight
        self.url = url
        self._size = GalleryCoverMetrics(style)
        self.contentMode = contentMode
        self.onSuccess = onSuccess
    }

    public var body: some View {
        let height = min(size.height, max(0, maximumHeight ?? size.height))
        KFImage(url)
            .placeholder {
                Color(.systemGray5)
                    .overlay { ProgressView() }
            }
            .onSuccess(onSuccess)
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: height * size.width / size.height, height: height)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 5))
    }
}
