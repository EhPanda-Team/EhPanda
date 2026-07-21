import AppComponents
import AppModels
import AppTools
import Kingfisher
import Resources
import SwiftUI

struct TagDetailView: View {
    private let detail: TagDetail

    init(detail: TagDetail) {
        self.detail = detail
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack {
                    TagDescriptionSection(description: detail.description)
                    ImagesSection(imageURLs: detail.imageURLs).padding(.vertical)
                    LinksSection(links: detail.links).padding(.vertical)
                }
            }
            .navigationTitle(detail.title.emojisRipped)
        }
    }
}

private struct TagDescriptionSection: View {
    private let description: String

    init(description: String) {
        self.description = description
    }

    var body: some View {
        Text(description)
            .foregroundStyle(.secondary)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}

private struct ImagesSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let imageURLs: [URL]

    init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
    }

    private var width: CGFloat {
        DetailLayout.previewWidth(regular: horizontalSizeClass == .regular)
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.previewAspect
    }

    var body: some View {
        SubSection(title: .images, showAll: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(imageURLs, id: \.self) { imageURL in
                        KFImage(imageURL)
                            .placeholder {
                                Placeholder(style: .activity(
                                    ratio: Defaults.ImageSize.previewAspect
                                ))
                            }
                            .defaultModifier()
                            .scaledToFit()
                            .frame(width: width, height: height)
                    }
                    .withHorizontalSpacing(height: height)
                }
            }
            .animation(.default) {
                $0.opacity(imageURLs.isEmpty ? 0 : 1)
            }
            .overlay {
                ErrorView(error: .notFound)
                    .padding()
                    .animation(.default) {
                        $0.opacity(imageURLs.isEmpty ? 1 : 0)
                    }
            }
        }
    }
}

private struct LinksSection: View {
    private let links: [URL]

    init(links: [URL]) {
        self.links = links
    }

    var body: some View {
        SubSection(title: .links, showAll: false) {
            VStack(alignment: .leading) {
                ForEach(links, id: \.self) { url in
                    Button {
                        UIApplication.shared.open(url, options: [:])
                    } label: {
                        Text(url.absoluteString)
                            .multilineTextAlignment(.leading)
                            .font(.callout.bold())
                            .tint(.secondary)
                    }
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.default) {
                $0.opacity(links.isEmpty ? 0 : 1)
            }
            .overlay {
                ErrorView(error: .notFound)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .animation(.default) {
                        $0.opacity(links.isEmpty ? 1 : 0)
                    }
            }
            .padding(.horizontal)
        }
    }
}

#Preview("Loaded") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TagDetailView(
                detail: .init(
                    title: "Some name",
                    description: "blablablablablablablablablablablablablablablablablablablablablablablabla~",
                    imageURLs: .init(), links: [Defaults.URL.ehentai, Defaults.URL.exhentai]
                )
            )
        }
}
