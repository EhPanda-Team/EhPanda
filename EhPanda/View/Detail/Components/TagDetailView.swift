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
                    LinksSection(links: detail.links).padding(.vertical)
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
            Text(description).foregroundColor(.secondary).font(.headline)
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
        SubSection(title: L10n.Localizable.TagDetailView.Section.Title.images, showAll: false) {
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
    private let links: [URL]

    init(links: [URL]) {
        self.links = links
    }

    var body: some View {
        SubSection(title: L10n.Localizable.TagDetailView.Section.Title.links, showAll: false) {
            HStack {
                if !links.isEmpty {
                    VStack(alignment: .leading) {
                        ForEach(links, id: \.self) { url in
                            Button {
                                UIApplication.shared.open(url, options: [:])
                            } label: {
                                Text(url.absoluteString)
                                    .multilineTextAlignment(.leading)
                                    .font(.callout.bold()).tint(.secondary)
                            }
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
        Color.clear
            .sheet(isPresented: .constant(true)) {
                TagDetailView(
                    detail: .init(
                        title: "Some name",
                        description: "blablablablablablablablablablablablablablablablablablablablablablablabla~",
                        imageURLs: .init(), links: [Defaults.URL.ehentai, Defaults.URL.exhentai]
                    )
                )
                .preferredColorScheme(.dark)
            }
    }
}
