import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import Kingfisher
import ComposableArchitecture
import AppTools
import AppComponents
import CookieClient

// MARK: DescriptionSection
struct DescriptionSection: View {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let navigateGalleryInfosAction: () -> Void

    private var infos: [DescScrollInfo] {[
        DescScrollInfo(
            title: .favorited,
            description: String(localized: .favoritedUnit),
            value: .init(galleryDetail.favoritedCount)
        ),
        DescScrollInfo(
            title: .RLocalizable.language,
            description: String(localized: galleryDetail.language.value),
            value: galleryDetail.language.abbreviation
        ),
        DescScrollInfo(
            title: .ratingsCount(count: galleryDetail.ratingCount),
            description: .init(), value: .init(), rating: galleryDetail.rating, isRating: true
        ),
        DescScrollInfo(
            title: .pageCount,
            description: String(localized: .pageCountUnit),
            value: .init(galleryDetail.pageCount)
        ),
        DescScrollInfo(
            title: .fileSize,
            description: galleryDetail.sizeType, value: .init(galleryDetail.sizeCount)
        )
    ]}
    var body: some View {
        let itemWidth: (CGFloat, Axis) -> CGFloat = { width, _ in
            max(width / 5, 80)
        }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(infos) { info in
                    Group {
                        if info.isRating {
                            DescScrollRatingItem(title: info.title, rating: info.rating)
                        } else {
                            DescScrollItem(title: info.title, value: info.value, description: info.description)
                        }
                    }
                    .containerRelativeFrame(.horizontal, itemWidth)
                    .drawingGroup()
                    Divider()
                    if info == infos.last {
                        Button(action: navigateGalleryInfosAction) {
                            Image(systemSymbol: .ellipsis)
                                .font(.title3.weight(.bold))
                        }
                        .containerRelativeFrame(.horizontal, itemWidth)
                    }
                }
                .withHorizontalSpacing()
            }
        }
        .frame(height: 60)
    }
}

extension DescriptionSection {
    struct DescScrollInfo: Identifiable, Equatable {
        var id: String { String(localized: title) }
        let title: LocalizedStringResource
        let description: String
        let value: String
        var rating: Float = 0
        var isRating = false
    }
    struct DescScrollItem: View {
        let title: LocalizedStringResource
        let value: String
        let description: String

        var body: some View {
            VStack(spacing: 3) {
                Text(title).textCase(.uppercase).font(.caption)
                Text(value).fontWeight(.medium).font(.title3).lineLimit(1)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: value)
                Text(description).font(.caption)
            }
        }
    }
    struct DescScrollRatingItem: View {
        let title: LocalizedStringResource
        let rating: Float

        var body: some View {
            VStack(spacing: 3) {
                Text(title).textCase(.uppercase).font(.caption).lineLimit(1)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: title)
                Text(String(format: "%.2f", rating)).fontWeight(.medium).font(.title3)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(rating)))
                    .animation(.default, value: rating)
                RatingView(rating: rating).font(.caption).foregroundStyle(.primary)
            }
        }
    }
}

// MARK: ActionSection
struct ActionSection: View {
    @Dependency(\.cookieClient) private var cookieClient
    let galleryDetail: GalleryDetail
    let userRating: Int
    let showUserRating: Bool
    let showUserRatingAction: () -> Void
    let updateRatingAction: (DragGesture.Value) -> Void
    let confirmRatingAction: (DragGesture.Value) -> Void
    let navigateSimilarGalleryAction: () -> Void
    // 24pt at default (.large); scales with Dynamic Type relative to the nearest text style (.title2, 22pt).
    @ScaledMetric(relativeTo: .title2) private var userRatingSymbolSize: CGFloat = 24

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button(action: showUserRatingAction) {
                        Spacer()
                        Image(systemSymbol: .squareAndPencil)
                        Text(.giveARating).bold()
                        Spacer()
                    }
                    .disabled(!cookieClient.didLogin)
                    Button(action: navigateSimilarGalleryAction) {
                        Spacer()
                        Image(systemSymbol: .photoOnRectangleAngled)
                        Text(.similarGallery).bold()
                        Spacer()
                    }
                }
                .font(.callout).foregroundStyle(.primary)
            }
            if showUserRating {
                HStack {
                    RatingView(rating: Float(userRating) / 2)
                        .font(.system(size: userRatingSymbolSize))
                        .foregroundStyle(.yellow)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged(updateRatingAction)
                                .onEnded(confirmRatingAction)
                        )
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: TagsSection
struct TagsSection: View {
    let tags: [GalleryTag]
    let showsImages: Bool
    let voteTagAction: (String, Int) -> Void
    let navigateSearchAction: (String) -> Void
    let navigateTagDetailAction: (TagDetail) -> Void
    let translateAction: (String) -> (String, TagTranslation?)

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(
                    tag: tag, showsImages: showsImages,
                    voteTagAction: voteTagAction,
                    navigateSearchAction: navigateSearchAction,
                    navigateTagDetailAction: navigateTagDetailAction,
                    translateAction: translateAction
                )
            }
        }
        .padding(.horizontal)
    }
}

extension TagsSection {
    struct TagRow: View {
        @Dependency(\.cookieClient) private var cookieClient
        @Environment(\.colorScheme) private var colorScheme

        let tag: GalleryTag
        let showsImages: Bool
        let voteTagAction: (String, Int) -> Void
        let navigateSearchAction: (String) -> Void
        let navigateTagDetailAction: (TagDetail) -> Void
        let translateAction: (String) -> (String, TagTranslation?)

        private var reversedPrimary: Color { colorScheme == .light ? .white : .black }
        private var backgroundColor: Color { Color(.systemGray5) }
        private var padding: EdgeInsets { .init(top: 5, leading: 14, bottom: 5, trailing: 14) }

        var body: some View {
            HStack(alignment: .top) {
                Text(tag.namespace.map { String(localized: $0.value) } ?? tag.rawNamespace).font(.subheadline.bold())
                    .foregroundStyle(reversedPrimary).padding(padding)
                    .background(Color(.systemGray)).clipShape(.rect(cornerRadius: 5))
                TagCloudView(data: tag.contents) { content in
                    tagContentView(content: content)
                }
            }
        }

        @ViewBuilder
        private func tagContentView(content: GalleryTag.Content) -> some View {
            let (_, translation) = translateAction(content.rawNamespace + content.text)
            Button {
                navigateSearchAction(content.serachKeyword(tag: tag))
            } label: {
                TagCloudCell(
                    text: translation?.displayValue ?? content.text,
                    imageURL: translation?.valueImageURL,
                    showsImages: showsImages,
                    font: .subheadline, padding: padding, textColor: .primary,
                    backgroundColor: backgroundColor
                )
            }
            .contextMenu {
                tagContextMenu(content: content, translation: translation)
            }
        }

        @ViewBuilder
        private func tagContextMenu(
            content: GalleryTag.Content,
            translation: TagTranslation?
        ) -> some View {
            if let translation = translation,
               let description = translation.descriptionPlainText,
               !description.isEmpty {
                Button {
                    navigateTagDetailAction(.init(
                        title: translation.displayValue, description: description,
                        imageURLs: translation.descriptionImageURLs,
                        links: translation.links
                    ))
                } label: {
                    Label(.RLocalizable.detail, systemSymbol: .richtextPage)
                }
            }
            if cookieClient.didLogin {
                tagVoteButtons(content: content)
            }
        }

        @ViewBuilder
        private func tagVoteButtons(content: GalleryTag.Content) -> some View {
            if content.isVotedUp || content.isVotedDown {
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), content.isVotedUp ? -1 : 1)
                } label: {
                    Label(.withdrawVote, systemSymbol: content.isVotedUp ? .handThumbsup : .handThumbsdown)
                        .symbolVariant(.fill)
                }
            } else {
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), 1)
                } label: {
                    Label(.voteUp, systemSymbol: .handThumbsup)
                }
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), -1)
                } label: {
                    Label(.voteDown, systemSymbol: .handThumbsdown)
                }
            }
        }
    }
}

// MARK: PreviewsSection
struct PreviewsSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let pageCount: Int
    let previewURLs: [Int: URL]
    let navigatePreviewsAction: () -> Void
    let navigateReadingAction: (Int) -> Void

    private var width: CGFloat {
        DetailLayout.previewWidth(regular: horizontalSizeClass == .regular)
    }
    private var height: CGFloat { width / Defaults.ImageSize.previewAspect }

    var body: some View {
        SubSection(
            title: .previews,
            showAll: pageCount > 20, showAllAction: navigatePreviewsAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(previewURLs.tuples.sorted(by: { $0.0 < $1.0 }), id: \.0) { index, previewURL in
                        Button {
                            navigateReadingAction(index)
                        } label: {
                            PreviewImageView(originalURL: previewURL)
                                .frame(width: width, height: height)
                        }
                    }
                    .withHorizontalSpacing(height: height)
                }
            }
        }
    }
}

// MARK: CommentsSection
struct CommentsSection: View {
    @Dependency(\.cookieClient) private var cookieClient

    let comments: [GalleryComment]
    let navigateCommentAction: () -> Void
    let navigatePostCommentAction: () -> Void

    private var backgroundColor: Color { Color(.systemGray6) }

    var body: some View {
        SubSection(
            title: .comments,
            showAll: !comments.isEmpty, showAllAction: navigateCommentAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(min(comments.count, 6))) { comment in
                        DetailView.CommentCell(comment: comment, backgroundColor: backgroundColor)
                    }
                    .withHorizontalSpacing()
                }
                .drawingGroup()
            }
            CommentButton(backgroundColor: backgroundColor, action: navigatePostCommentAction)
                .padding(.horizontal).disabled(!cookieClient.didLogin)
        }
    }
}
