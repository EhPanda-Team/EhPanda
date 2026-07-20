import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Kingfisher
import Resources
import SFSafeSymbolsExt
import SwiftUI
import TagTranslationFeature

// MARK: DescriptionSection
struct DescriptionSection: View {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let navigateGalleryInfosAction: () -> Void

    // 60pt at default (.large); scales with Dynamic Type relative to the row's dominant text style (.title3).
    @ScaledMetric(relativeTo: .title3) private var rowHeight: CGFloat = 60

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
                            Label(.metadataGalleryInfos, systemSymbol: .ellipsis)
                                .labelStyle(.iconOnly)
                                .font(.title3.weight(.bold))
                        }
                        .containerRelativeFrame(.horizontal, itemWidth)
                    }
                }
                .withHorizontalSpacing()
            }
        }
        .frame(height: rowHeight)
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

// Section-scoped previews: the full DetailView preview pays the NavigationStack + ScrollView
// scaffolding cost on every canvas update, so iterate on a single section here instead.
#Preview("Description") {
    DescriptionSection(
        gallery: .preview,
        galleryDetail: .preview,
        navigateGalleryInfosAction: {}
    )
}

// MARK: ActionSection
struct ActionSection: View {
    @SharedReader(.didLogin) private var didLogin: Bool
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
                        Label {
                            Text(.giveARating)
                                .bold()
                        } icon: {
                            Image(systemSymbol: .squareAndPencil)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!didLogin)

                    Button(action: navigateSimilarGalleryAction) {
                        Label {
                            Text(.similarGallery).bold()
                        } icon: {
                            Image(systemSymbol: .photoOnRectangleAngled)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .font(.callout)
                .tint(.primary)
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

@MainActor private func previewActionSection(userRating: Int, showUserRating: Bool) -> some View {
    ActionSection(
        galleryDetail: .preview,
        userRating: userRating,
        showUserRating: showUserRating,
        showUserRatingAction: {},
        updateRatingAction: { _ in },
        confirmRatingAction: { _ in },
        navigateSimilarGalleryAction: {}
    )
}

#Preview("Actions") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(userRating: 0, showUserRating: false)
    }
}

#Preview("Actions (rating shown)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewActionSection(userRating: 7, showUserRating: true)
    }
}

// MARK: TagsSection
struct TagsSection: View {
    let tags: [GalleryTag]
    let showsImages: Bool
    let voteTagAction: (String, Int) -> Void
    let navigateSearchAction: (String) -> Void
    let navigateTagDetailAction: (TagDetail) -> Void
    let translateAction: (String) -> TagTranslationLookup

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
        @SharedReader(.didLogin) private var didLogin: Bool
        @Environment(\.colorScheme) private var colorScheme

        let tag: GalleryTag
        let showsImages: Bool
        let voteTagAction: (String, Int) -> Void
        let navigateSearchAction: (String) -> Void
        let navigateTagDetailAction: (TagDetail) -> Void
        let translateAction: (String) -> TagTranslationLookup

        private var reversedPrimary: Color { colorScheme == .light ? .white : .black }
        private var backgroundColor: Color { Color(.systemGray5) }
        private var padding: EdgeInsets { .init(top: 5, leading: 14, bottom: 5, trailing: 14) }

        var body: some View {
            HStack(alignment: .top) {
                Text(tag.namespace.map({ String(localized: $0.value) }) ?? tag.rawNamespace).font(.subheadline.bold())
                    .foregroundStyle(reversedPrimary).padding(padding)
                    .background(Color(.systemGray)).clipShape(.rect(cornerRadius: 5))
                TagCloudView(data: tag.contents) { content in
                    tagContentView(content: content)
                }
            }
        }

        @ViewBuilder
        private func tagContentView(content: GalleryTag.Content) -> some View {
            let translation = translateAction(content.rawNamespace + content.text).translation
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
            if didLogin {
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

// `translateAction` returns the word unchanged: previewing the tag layout does not need a
// populated TagTranslator, and returning no translation keeps the rows on their raw text.
#Preview("Tags") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        TagsSection(
            tags: [
                .init(rawNamespace: "language", contents: [
                    .init(rawNamespace: "language", text: "japanese", isVotedUp: false, isVotedDown: false),
                    .init(rawNamespace: "language", text: "translated", isVotedUp: true, isVotedDown: false)
                ]),
                .init(rawNamespace: "artist", contents: [
                    .init(rawNamespace: "artist", text: "Anonymous", isVotedUp: false, isVotedDown: false)
                ])
            ],
            showsImages: false,
            voteTagAction: { _, _ in },
            navigateSearchAction: { _ in },
            navigateTagDetailAction: { _ in },
            translateAction: { .init(text: $0, translation: nil) }
        )
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

// The thumbnails are remote, so the canvas shows placeholders — this previews the row layout.
#Preview("Previews row") {
    PreviewsSection(
        pageCount: 114,
        previewURLs: [0: .mock, 1: .mock, 2: .mock, 3: .mock],
        navigatePreviewsAction: {},
        navigateReadingAction: { _ in }
    )
}

// MARK: CommentsSection
struct CommentsSection: View {
    @SharedReader(.didLogin) private var didLogin: Bool

    let comments: [GalleryComment]
    let navigateCommentAction: () -> Void
    let navigatePostCommentAction: () -> Void

    private var backgroundColor: Color { Color(.systemGray5) }

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
                .padding(.horizontal).disabled(!didLogin)
        }
    }
}

private func previewComment(
    id: String, author: String, score: String, votedUp: Bool, text: String
) -> GalleryComment {
    .init(
        votedUp: votedUp, votedDown: false, votable: true, editable: false,
        score: score, author: author,
        contents: [.init(type: .plainText, text: text)],
        commentID: id, commentDate: .now
    )
}

#Preview("Comments") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        CommentsSection(
            comments: [
                previewComment(
                    id: "0", author: "Nreo", score: "+15", votedUp: false,
                    text: "Thanks for the upload, great quality scans!"
                ),
                previewComment(
                    id: "1", author: "Chihchy", score: "+42", votedUp: true,
                    text: "Agreed. The later pages look excellent."
                )
            ],
            navigateCommentAction: {},
            navigatePostCommentAction: {}
        )
    }
}

#Preview("Comments (empty)") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        CommentsSection(
            comments: [],
            navigateCommentAction: {},
            navigatePostCommentAction: {}
        )
    }
}
