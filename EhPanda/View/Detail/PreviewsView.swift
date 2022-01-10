//
//  PreviewsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import Kingfisher

private struct MorePreviewView: View {
    @Environment(\.dismiss) var dismissAction

    @State private var isActive = false

    private let gid: String
    private let previews: [Int: String]
    private let pageCount: Int
    private let tapAction: (Int, Bool) -> Void
    private let fetchAction: (Int) -> Void

    init(
        gid: String,
        previews: [Int: String],
        pageCount: Int,
        tapAction: @escaping (Int, Bool) -> Void,
        fetchAction: @escaping (Int) -> Void
    ) {
        self.gid = gid
        self.previews = previews
        self.pageCount = pageCount
        self.tapAction = tapAction
        self.fetchAction = fetchAction
    }

    private var gridItems: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: Defaults.ImageSize.previewMinW,
                maximum: Defaults.ImageSize.previewMaxW
            ),
            spacing: 10
        )]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItems) {
                ForEach(1..<pageCount + 1) { index in
                    VStack {
                        let (url, modifier) =
                        PreviewResolver.getPreviewConfigs(
                            originalURL: previews[index] ?? ""
                        )
                        KFImage.url(URL(string: url), cacheKey: previews[index])
                            .placeholder {
                                Placeholder(style: .activity(
                                    ratio: Defaults.ImageSize
                                        .previewAspect
                                ))
                            }
                            .imageModifier(modifier)
                            .fade(duration: 0.25)
                            .resizable().scaledToFit()
                            .onTapGesture {
                                tapAction(index, false)
                                isActive = true
                            }
                        Text("\(index)")
                            .font(DeviceUtil.isPadWidth ? .callout : .caption)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        guard previews[index] == nil && (index - 1) % 20 == 0 else { return }
                        fetchAction(index)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background {
            NavigationLink(
                "",
                destination: ReadingView(gid: gid),
                isActive: $isActive
            )
        }
    }
}
