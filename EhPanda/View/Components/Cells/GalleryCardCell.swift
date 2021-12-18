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
    @State private var animated = false
    @State private var colors = [Color.clear]
    @Binding private var currentID: String

    private let gallery: Gallery

    private let animation: Animation =
        .interpolatingSpring(stiffness: 50, damping: 1).speed(0.2)

    init(gallery: Gallery, currentID: Binding<String>) {
        self.gallery = gallery
        _currentID = currentID
    }

    var title: String {
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
                .id(currentID + String(animated))
            HStack {
                KFImage(URL(string: gallery.coverURL))
                    .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                    .onSuccess(updateColors).defaultModifier().scaledToFill()
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
        .onChange(of: currentID, perform: resyncAnimated)
        .onAppear { resyncAnimated(newID: currentID) }
    }

    func resyncAnimated(newID: String) {
        animated = newID == gallery.gid
    }

    func updateColors(result: RetrieveImageResult) {
        result.image.getColors { newColors in
            guard let newColors = newColors else { return }
            colors = [
                newColors.primary, newColors.secondary,
                newColors.detail, newColors.background
            ]
            .map(Color.init)
        }
    }
}

struct GalleryCardCell_Previews: PreviewProvider {
    static var previews: some View {
        let gallery = Gallery(
            gid: "", token: "",
            title: "[水之色] HoPornLive English (バーチャルYouTuber)",
            rating: 4.59, tags: [], category: .doujinshi, language: .japanese,
            uploader: "nX7UtWS5", pageCount: 49, postedDate: .now,
            coverURL: "https://ehgt.org/t/22/83/2283c41077e002cb062f7b4593961ab674d7670a-847854-2110-3016-jpg_250.jpg",
            galleryURL: "https://e-hentai.org/g/2084129/66b4de10d0/", lastOpenDate: nil
        )
        return GalleryCardCell(gallery: gallery, currentID: .constant(gallery.gid))
            .previewLayout(.fixed(width: 300, height: 206))
            .padding()
    }
}
