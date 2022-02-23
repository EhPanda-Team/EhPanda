//
//  TagDetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/21.
//

import SwiftUI
import Kingfisher

struct TagDetailView: View {
    private let detail: TagDetail

    init(detail: TagDetail) {
        self.detail = detail
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack {
                    DescriptionSection(description: detail.description)
                    ImagesSection(imageURLs: detail.imageURLs).padding(.vertical)
                    LinksSection(links: detail.externalLinks).padding(.vertical)
                }
            }
            .navigationTitle(detail.title.emojisRipped)
        }
    }
}

private struct DescriptionSection: View {
    private let description: String

    init(description: String) {
        self.description = description
    }

    var body: some View {
        HStack {
            Text(description)
            Spacer()
        }
        .padding(.horizontal)
    }
}

private struct ImagesSection: View {
    private let imageURLs: [URL]

    init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
    }

    private var width: CGFloat {
        Defaults.ImageSize.previewAvgW
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.previewAspect
    }

    var body: some View {
        SubSection(title: "Images", showAll: false) {
            VStack {
                if !imageURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack {
                            ForEach(imageURLs, id: \.self) { imageURL in
                                KFImage(imageURL)
                                    .placeholder {
                                        Placeholder(style: .activity(
                                            ratio: Defaults.ImageSize.previewAspect
                                        ))
                                    }
                                    .defaultModifier().scaledToFit()
                                    .frame(width: width, height: height)
                            }
                            .withHorizontalSpacing(height: height)
                        }
                    }
                } else {
                    ErrorView(error: .notFound).padding()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct LinksSection: View {
    private let links: [ExternalLink]

    init(links: [ExternalLink]) {
        self.links = links
    }

    var body: some View {
        SubSection(title: "Links", showAll: false) {
            HStack {
                if !links.isEmpty {
                    VStack(alignment: .leading) {
                        ForEach(links) { link in
                            Link(link.url.absoluteString, destination: link.url)
                        }
                    }
                    .padding(.vertical)
                } else {
                    Spacer()
                    ErrorView(error: .notFound).padding()
                }
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

struct TagDescriptionView_Previews: PreviewProvider {
    static var previews: some View {
        TagDetailView(
            detail: .init(
                title: .init(), description: .init(),
                imageURLs: .init(), links: .init()
            )
        )
    }
}
