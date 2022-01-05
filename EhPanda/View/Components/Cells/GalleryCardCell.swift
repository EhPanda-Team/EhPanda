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
    private let currentID: String
    @Binding private var colors: [Color]?
    private let webImageSuccessAction: (RetrieveImageResult) -> Void

    private let gallery: Gallery

    private let animation: Animation =
        .interpolatingSpring(stiffness: 50, damping: 1).speed(0.2)

    init(
        gallery: Gallery, currentID: String, colors: Binding<[Color]?>,
        webImageSuccessAction: @escaping (RetrieveImageResult) -> Void
    ) {
        self.gallery = gallery
        self.currentID = currentID
        _colors = colors
        self.webImageSuccessAction = webImageSuccessAction
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
            ColorfulView(animated: gallery.gid == currentID, animation: animation, colors: colors ?? [.clear])
                .id(gallery.gid + currentID + (colors?.description ?? ""))
            HStack {
                KFImage(URL(string: gallery.coverURL))
                    .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                    .onSuccess(webImageSuccessAction).defaultModifier().scaledToFill()
                    .frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)
                    .cornerRadius(5)
                VStack(alignment: .leading) {
                    Text(title).font(.title3.bold()).lineLimit(4).shadow(radius: 5)
                    Spacer()
                    RatingView(rating: gallery.rating).foregroundColor(.yellow).shadow(radius: 2)
                }
                .padding(.leading, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(width: DeviceUtil.windowW * 0.8).cornerRadius(15)
    }
}

struct GalleryCardCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryCardCell(
            gallery: .preview, currentID: Gallery.preview.gid,
            colors: .constant(ColorfulView.defaultColorList),
            webImageSuccessAction: { _ in }
        )
        .previewLayout(.fixed(width: 300, height: 206)).padding()
    }
}
