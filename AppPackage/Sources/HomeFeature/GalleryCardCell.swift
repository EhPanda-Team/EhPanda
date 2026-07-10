import SwiftUI
import AppModels
import AppComponents
import ColorfulX
import Kingfisher
import AppTools

public struct GalleryCardCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let currentID: String
    private let colors: [Color]
    private let webImageSuccessAction: (RetrieveImageResult) -> Void

    private let gallery: Gallery

    // ColorfulX renders the gradient with Metal and animates continuously; `speed`
    // scales that motion and `0` freezes it. Driving `speed` off `animated` keeps only
    // the focused dark-mode card moving — preserving Colorful's former `animated` flag.
    // The value is a subjective, user-tunable choice (see 01-COLORFUL-UAT.md, D-19).
    private let animationSpeed: Double = 0.5

    public init(
        gallery: Gallery, currentID: String, colors: [Color],
        webImageSuccessAction: @escaping (RetrieveImageResult) -> Void
    ) {
        self.gallery = gallery
        self.currentID = currentID
        self.colors = colors
        self.webImageSuccessAction = webImageSuccessAction
    }

    private var animated: Bool {
        guard colorScheme == .dark else { return false }
        return gallery.gid == currentID
    }
    private var title: String {
        let trimmedTitle = gallery.trimmedTitle
        guard !DeviceUtil.isPad, trimmedTitle.count > 20 else {
            return gallery.title
        }
        return trimmedTitle
    }

    public var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            ColorfulView(color: colors, speed: .constant(animated ? animationSpeed : 0))
                .id(currentID + animated.description)
            HStack {
                KFImage(gallery.coverURL)
                    .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                    .onSuccess(webImageSuccessAction).defaultModifier().scaledToFill()
                    .frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)
                    .cornerRadius(5)
                VStack(alignment: .leading) {
                    Text(title).font(.title3.bold()).lineLimit(4)
                    Spacer()
                    RatingView(rating: gallery.rating).foregroundColor(.yellow)
                }
                .padding(.leading, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(width: Defaults.FrameSize.cardCellWidth).cornerRadius(15)
    }
}

struct GalleryCardCell_Previews: PreviewProvider {
    static var previews: some View {
        let gallery = Gallery.preview
        GalleryCardCell(
            gallery: gallery, currentID: gallery.gid,
            colors: ColorfulPreset.aurora.colors.map { Color($0) },
            webImageSuccessAction: { _ in }
        )
        .previewLayout(.fixed(width: 300, height: 206)).padding()
    }
}
