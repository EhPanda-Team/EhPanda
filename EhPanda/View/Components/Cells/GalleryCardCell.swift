//
//  GalleryCardCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/13.
//

import SwiftUI
import Colorful
import Kingfisher
import UIImageColors

struct GalleryCardCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let currentID: String
    private let colors: [Color]
    private let webImageSuccessAction: (RetrieveImageResult) -> Void

    private let gallery: Gallery

    private let animation: Animation =
        .interpolatingSpring(stiffness: 50, damping: 1).speed(0.2)

    init(
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

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            ColorfulView(animated: animated, animation: animation, colors: colors)
                .id(currentID + animated.description)
            HStack {
                KFImage(URL(string: gallery.coverURL))
                    .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                    .onSuccess({ if colorScheme == .dark { webImageSuccessAction($0) } }).defaultModifier()
                    .scaledToFill().frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)
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
            colors: ColorfulView.defaultColorList,
            webImageSuccessAction: { _ in }
        )
        .previewLayout(.fixed(width: 300, height: 206)).padding()
    }
}
