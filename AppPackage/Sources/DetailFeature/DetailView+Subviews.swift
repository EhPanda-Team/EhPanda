import SwiftUI
import AppModels
import TagTranslationFeature
import Resources
import Kingfisher
import AppTools
import AppComponents

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
                                .font(.system(size: 20, weight: .bold))
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
                Text(String(format: "%.2f", rating)).fontWeight(.medium).font(.title3)
                RatingView(rating: rating).font(.system(size: 12)).foregroundStyle(.primary)
            }
        }
    }
}

// MARK: ActionSection
struct ActionSection: View {
    let galleryDetail: GalleryDetail
    let userRating: Int
    let showUserRating: Bool
    let showUserRatingAction: () -> Void
    let updateRatingAction: (DragGesture.Value) -> Void
    let confirmRatingAction: (DragGesture.Value) -> Void
    let navigateSimilarGalleryAction: () -> Void

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
                    .disabled(!CookieUtil.didLogin)
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
                        .font(.system(size: 24))
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
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.inSheet) private var inSheet

        let tag: GalleryTag
        let showsImages: Bool
        let voteTagAction: (String, Int) -> Void
        let navigateSearchAction: (String) -> Void
        let navigateTagDetailAction: (TagDetail) -> Void
        let translateAction: (String) -> (String, TagTranslation?)

        private var reversedPrimary: Color { colorScheme == .light ? .white : .black }
        private var backgroundColor: Color {
            inSheet && colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5)
        }
        private var padding: EdgeInsets { .init(top: 5, leading: 14, bottom: 5, trailing: 14) }

        var body: some View {
            HStack(alignment: .top) {
                Text(tag.namespace.map { String(localized: $0.value) } ?? tag.rawNamespace).font(.subheadline.bold())
                    .foregroundColor(reversedPrimary).padding(padding)
                    .background(Color(.systemGray)).cornerRadius(5)
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
                    Image(systemSymbol: .richtextPage)
                    Text(.RLocalizable.detail)
                }
            }
            if CookieUtil.didLogin {
                tagVoteButtons(content: content)
            }
        }

        @ViewBuilder
        private func tagVoteButtons(content: GalleryTag.Content) -> some View {
            if content.isVotedUp || content.isVotedDown {
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), content.isVotedUp ? -1 : 1)
                } label: {
                    Image(systemSymbol: content.isVotedUp ? .handThumbsup : .handThumbsdown)
                        .symbolVariant(.fill)
                    Text(.withdrawVote)
                }
            } else {
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), 1)
                } label: {
                    Image(systemSymbol: .handThumbsup)
                    Text(.voteUp)
                }
                Button {
                    voteTagAction(content.voteKeyword(tag: tag), -1)
                } label: {
                    Image(systemSymbol: .handThumbsdown)
                    Text(.voteDown)
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.inSheet) private var inSheet

    let comments: [GalleryComment]
    let navigateCommentAction: () -> Void
    let navigatePostCommentAction: () -> Void

    private var backgroundColor: Color {
        inSheet && colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }

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
                .padding(.horizontal).disabled(!CookieUtil.didLogin)
        }
    }
}
